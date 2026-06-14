package com.example.osmu.object;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import com.example.osmu.object.repository.ObjectRetentionPolicyRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.object.repository.ObjectVersionRepository.VersionCandidate;
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
public class ObjectVersionRetentionPurgeJob {

    private static final Logger log = LoggerFactory.getLogger(ObjectVersionRetentionPurgeJob.class);
    private static final String SYSTEM_ACTOR = "system";

    private final ObjectRetentionPolicyRepository retentionPolicyRepository;
    private final ObjectLifecycleRuleRepository lifecycleRuleRepository;
    private final ObjectVersionRepository objectVersionRepository;
    private final ObjectStorageAdapter storageAdapter;
    private final BucketService bucketService;
    private final AuditLogService auditLogService;
    private final Counter purgeSuccessCounter;
    private final Counter purgeFailureCounter;
    private final Counter purgeRunFailureCounter;

    public ObjectVersionRetentionPurgeJob(
            ObjectRetentionPolicyRepository retentionPolicyRepository,
            ObjectLifecycleRuleRepository lifecycleRuleRepository,
            ObjectVersionRepository objectVersionRepository,
            ObjectStorageAdapter storageAdapter,
            BucketService bucketService,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry
    ) {
        this.retentionPolicyRepository = retentionPolicyRepository;
        this.lifecycleRuleRepository = lifecycleRuleRepository;
        this.objectVersionRepository = objectVersionRepository;
        this.storageAdapter = storageAdapter;
        this.bucketService = bucketService;
        this.auditLogService = auditLogService;
        this.purgeSuccessCounter = purgeVersionCounter(meterRegistry, "success");
        this.purgeFailureCounter = purgeVersionCounter(meterRegistry, "failure");
        this.purgeRunFailureCounter = Counter.builder("osmu.object.version.retention.purge.runs")
                .description("Object version retention purge scheduler run count")
                .tag("result", "failure")
                .register(meterRegistry);
    }

    @Scheduled(
            initialDelayString = "${osmu.object.version-retention.initial-delay-ms:180000}",
            fixedDelayString = "${osmu.object.version-retention.fixed-delay-ms:3600000}"
    )
    public void purgeExpiredVersions() {
        try {
            runNow(OffsetDateTime.now());
        } catch (RuntimeException exception) {
            purgeRunFailureCounter.increment();
            log.warn("Object version retention purge failed.", exception);
        }
    }

    public int runNow(OffsetDateTime now) {
        ObjectRetentionPolicy policy = retentionPolicyRepository.getPolicy();
        if (!policy.enabled()) {
            return 0;
        }
        OffsetDateTime cutoff = now.minusDays(policy.versionRetentionDays());
        List<VersionCandidate> candidates = objectVersionRepository.findCreatedBefore(cutoff, policy.versionBatchSize());
        int purged = 0;
        for (VersionCandidate candidate : candidates) {
            if (purgeVersion(candidate)) {
                purged++;
            }
        }
        for (ObjectLifecycleRule rule : lifecycleRuleRepository.findAll()) {
            if (rule.matchesTarget(ObjectLifecycleRule.TARGET_OBJECT_VERSION)) {
                purged += purgeRule(now, rule);
            }
        }
        return purged;
    }

    private int purgeRule(OffsetDateTime now, ObjectLifecycleRule rule) {
        OffsetDateTime cutoff = now.minusDays(rule.retentionDays());
        List<VersionCandidate> candidates = objectVersionRepository.findCreatedBefore(
                cutoff,
                rule.batchSize(),
                rule.bucketName(),
                rule.prefix(),
                rule.tags()
        );
        int purged = 0;
        for (VersionCandidate candidate : candidates) {
            if (purgeVersion(candidate)) {
                purged++;
            }
        }
        return purged;
    }

    private boolean purgeVersion(VersionCandidate candidate) {
        ObjectVersionRecord version = candidate.version();
        String targetId = candidate.bucketName() + "/" + version.key() + "#" + version.versionId();
        try {
            deleteVersionStorage(candidate.bucketName(), version);
            objectVersionRepository.delete(candidate.bucketName(), version.key(), version.versionId());
            bucketService.applyObjectChange(candidate.bucketName(), -version.sizeBytes(), -1L);
            recordAudit(targetId, "SUCCESS", "Object version purged by retention policy");
            purgeSuccessCounter.increment();
            return true;
        } catch (RuntimeException exception) {
            log.warn("Failed to purge object version {}.", targetId, exception);
            recordAudit(targetId, "FAIL", "Object version retention purge failed: " + exception.getMessage());
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

    private Counter purgeVersionCounter(MeterRegistry meterRegistry, String result) {
        return Counter.builder("osmu.object.version.retention.purge.versions")
                .description("Object version retention purge version results")
                .tag("result", result)
                .register(meterRegistry);
    }

    private void recordAudit(String targetId, String result, String message) {
        try {
            auditLogService.record(
                    "OBJECT_VERSION_RETENTION_PURGE",
                    SYSTEM_ACTOR,
                    "OBJECT_VERSION",
                    targetId,
                    result,
                    message
            );
        } catch (RuntimeException exception) {
            log.warn("Failed to record object version retention purge audit log for {}.", targetId, exception);
        }
    }
}
