package com.example.osmu.object;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import com.example.osmu.object.repository.ObjectRetentionPolicyRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.OffsetDateTime;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.object.retention", name = "enabled", havingValue = "true", matchIfMissing = true)
public class ObjectRetentionPurgeJob {

    private static final Logger log = LoggerFactory.getLogger(ObjectRetentionPurgeJob.class);
    private static final String SYSTEM_ACTOR = "system";

    private final ObjectMetadataRepository objectMetadataRepository;
    private final ObjectLifecycleRuleRepository lifecycleRuleRepository;
    private final ObjectRetentionPolicyRepository retentionPolicyRepository;
    private final ObjectVersionRepository objectVersionRepository;
    private final ObjectStorageAdapter storageAdapter;
    private final BucketService bucketService;
    private final AuditLogService auditLogService;
    private final Counter purgeSuccessCounter;
    private final Counter purgeFailureCounter;
    private final Counter purgeRunFailureCounter;

    public ObjectRetentionPurgeJob(
            ObjectMetadataRepository objectMetadataRepository,
            ObjectLifecycleRuleRepository lifecycleRuleRepository,
            ObjectRetentionPolicyRepository retentionPolicyRepository,
            ObjectVersionRepository objectVersionRepository,
            ObjectStorageAdapter storageAdapter,
            BucketService bucketService,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry
    ) {
        this.objectMetadataRepository = objectMetadataRepository;
        this.lifecycleRuleRepository = lifecycleRuleRepository;
        this.retentionPolicyRepository = retentionPolicyRepository;
        this.objectVersionRepository = objectVersionRepository;
        this.storageAdapter = storageAdapter;
        this.bucketService = bucketService;
        this.auditLogService = auditLogService;
        this.purgeSuccessCounter = purgeObjectCounter(meterRegistry, "success");
        this.purgeFailureCounter = purgeObjectCounter(meterRegistry, "failure");
        this.purgeRunFailureCounter = Counter.builder("osmu.object.retention.purge.runs")
                .description("Object retention purge scheduler run count")
                .tag("result", "failure")
                .register(meterRegistry);
    }

    @Scheduled(
            initialDelayString = "${osmu.object.retention.initial-delay-ms:120000}",
            fixedDelayString = "${osmu.object.retention.fixed-delay-ms:3600000}"
    )
    public void purgeExpiredDeletedObjects() {
        try {
            runNow(OffsetDateTime.now());
        } catch (RuntimeException exception) {
            purgeRunFailureCounter.increment();
            log.warn("Object retention purge failed.", exception);
        }
    }

    public int runNow(OffsetDateTime now) {
        ObjectRetentionPolicy policy = retentionPolicyRepository.getPolicy();
        if (!policy.enabled()) {
            return 0;
        }
        OffsetDateTime cutoff = now.minusDays(policy.retentionDays());
        List<DeletedObjectCandidate> candidates = objectMetadataRepository.findDeletedBefore(cutoff, policy.batchSize());
        int purged = 0;
        for (DeletedObjectCandidate candidate : candidates) {
            if (purgeDeletedObject(candidate)) {
                purged++;
            }
        }
        for (ObjectLifecycleRule rule : lifecycleRuleRepository.findAll()) {
            if (rule.matchesTarget(ObjectLifecycleRule.TARGET_TRASH_OBJECT)) {
                purged += purgeRule(now, rule);
            }
        }
        return purged;
    }

    public int retentionDays() {
        return retentionPolicyRepository.getPolicy().retentionDays();
    }

    private int purgeRule(OffsetDateTime now, ObjectLifecycleRule rule) {
        OffsetDateTime cutoff = now.minusDays(rule.retentionDays());
        List<DeletedObjectCandidate> candidates = objectMetadataRepository.findDeletedBefore(
                cutoff,
                rule.batchSize(),
                rule.bucketName(),
                rule.prefix(),
                rule.tags()
        );
        int purged = 0;
        for (DeletedObjectCandidate candidate : candidates) {
            if (purgeDeletedObject(candidate)) {
                purged++;
            }
        }
        return purged;
    }

    public int batchSize() {
        return retentionPolicyRepository.getPolicy().batchSize();
    }

    private boolean purgeDeletedObject(DeletedObjectCandidate candidate) {
        String targetId = candidate.bucketName() + "/" + candidate.key();
        try {
            long purgedSizeBytes = candidate.sizeBytes();
            long purgedObjectCount = 1L;
            try {
                purgedSizeBytes = storageAdapter.deleteObject(candidate.bucketName(), candidate.key()).sizeBytes();
            } catch (ApiException exception) {
                if (exception.code() != ApiErrorCode.NOT_FOUND) {
                    throw exception;
                }
            }
            List<ObjectVersionRecord> versions = objectVersionRepository.findByObjectKey(candidate.bucketName(), candidate.key());
            for (ObjectVersionRecord version : versions) {
                deleteVersionStorage(candidate.bucketName(), version);
                purgedSizeBytes += version.sizeBytes();
                purgedObjectCount++;
            }
            objectVersionRepository.deleteByObjectKey(candidate.bucketName(), candidate.key());
            objectMetadataRepository.delete(candidate.bucketName(), candidate.key());
            bucketService.applyObjectChange(candidate.bucketName(), -purgedSizeBytes, -purgedObjectCount);
            recordAudit(targetId, "SUCCESS", "Deleted object purged by retention policy");
            purgeSuccessCounter.increment();
            return true;
        } catch (RuntimeException exception) {
            log.warn("Failed to purge deleted object {}.", targetId, exception);
            recordAudit(targetId, "FAIL", "Deleted object retention purge failed: " + exception.getMessage());
            purgeFailureCounter.increment();
            return false;
        }
    }

    private boolean deleteVersionStorage(String bucketName, ObjectVersionRecord version) {
        try {
            storageAdapter.deleteObject(bucketName, version.storageKey());
            return true;
        } catch (ApiException exception) {
            if (exception.code() == ApiErrorCode.NOT_FOUND) {
                return false;
            }
            throw exception;
        }
    }

    private Counter purgeObjectCounter(MeterRegistry meterRegistry, String result) {
        return Counter.builder("osmu.object.retention.purge.objects")
                .description("Object retention purge object results")
                .tag("result", result)
                .register(meterRegistry);
    }

    private void recordAudit(String targetId, String result, String message) {
        try {
            auditLogService.record(
                    "OBJECT_RETENTION_PURGE",
                    SYSTEM_ACTOR,
                    "OBJECT",
                    targetId,
                    result,
                    message
            );
        } catch (RuntimeException exception) {
            log.warn("Failed to record object retention purge audit log for {}.", targetId, exception);
        }
    }
}
