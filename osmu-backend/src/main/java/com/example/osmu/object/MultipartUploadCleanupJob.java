package com.example.osmu.object;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.object.repository.InMemoryMultipartUploadPartChecksumRepository;
import com.example.osmu.object.repository.MultipartUploadPartChecksumRepository;
import com.example.osmu.object.repository.PresignedUploadSessionRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.OffsetDateTime;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.upload.cleanup", name = "enabled", havingValue = "true", matchIfMissing = true)
public class MultipartUploadCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(MultipartUploadCleanupJob.class);
    private static final String ACTIVE = "ACTIVE";
    private static final String EXPIRED = "EXPIRED";
    private static final String SYSTEM_ACTOR = "system";

    private final PresignedUploadSessionRepository uploadSessionRepository;
    private final MultipartUploadPartChecksumRepository partChecksumRepository;
    private final ObjectStorageAdapter storageAdapter;
    private final AuditLogService auditLogService;
    private final int batchSize;
    private final Counter cleanupSuccessCounter;
    private final Counter cleanupSkippedCounter;
    private final Counter cleanupFailureCounter;
    private final Counter cleanupRunFailureCounter;

    public MultipartUploadCleanupJob(
            PresignedUploadSessionRepository uploadSessionRepository,
            ObjectStorageAdapter storageAdapter,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry,
            @Value("${osmu.upload.cleanup.batch-size:100}") int batchSize
    ) {
        this(
                uploadSessionRepository,
                new InMemoryMultipartUploadPartChecksumRepository(),
                storageAdapter,
                auditLogService,
                meterRegistry,
                batchSize
        );
    }

    @Autowired
    public MultipartUploadCleanupJob(
            PresignedUploadSessionRepository uploadSessionRepository,
            MultipartUploadPartChecksumRepository partChecksumRepository,
            ObjectStorageAdapter storageAdapter,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry,
            @Value("${osmu.upload.cleanup.batch-size:100}") int batchSize
    ) {
        this.uploadSessionRepository = uploadSessionRepository;
        this.partChecksumRepository = partChecksumRepository;
        this.storageAdapter = storageAdapter;
        this.auditLogService = auditLogService;
        this.batchSize = Math.max(1, batchSize);
        this.cleanupSuccessCounter = cleanupSessionCounter(meterRegistry, "success");
        this.cleanupSkippedCounter = cleanupSessionCounter(meterRegistry, "skipped");
        this.cleanupFailureCounter = cleanupSessionCounter(meterRegistry, "failure");
        this.cleanupRunFailureCounter = Counter.builder("osmu.multipart.cleanup.runs")
                .description("Multipart cleanup scheduler run count")
                .tag("result", "failure")
                .register(meterRegistry);
    }

    @Scheduled(
            initialDelayString = "${osmu.upload.cleanup.initial-delay-ms:60000}",
            fixedDelayString = "${osmu.upload.cleanup.fixed-delay-ms:300000}"
    )
    public void cleanupExpiredMultipartUploads() {
        try {
            cleanupExpiredMultipartUploads(OffsetDateTime.now());
        } catch (RuntimeException exception) {
            cleanupRunFailureCounter.increment();
            log.warn("Expired multipart upload cleanup failed.", exception);
        }
    }

    int cleanupExpiredMultipartUploads(OffsetDateTime now) {
        List<PresignedUploadSession> expiredSessions =
                uploadSessionRepository.findExpiredActiveMultipartUploads(now, batchSize);
        int cleaned = 0;
        for (PresignedUploadSession session : expiredSessions) {
            if (cleanupExpiredMultipartUpload(session, now)) {
                cleaned++;
            }
        }
        return cleaned;
    }

    private boolean cleanupExpiredMultipartUpload(PresignedUploadSession session, OffsetDateTime completedAt) {
        try {
            storageAdapter.abortMultipartUpload(
                    session.bucketName(),
                    session.objectKey(),
                    session.storageUploadId()
            );
            boolean expired = uploadSessionRepository.updateStatusIfCurrent(
                    session.uploadId(),
                    ACTIVE,
                    EXPIRED,
                    completedAt
            );
            if (expired) {
                deletePartChecksums(session);
                recordCleanupAudit(session, "SUCCESS", "Expired multipart upload aborted");
                cleanupSuccessCounter.increment();
            } else {
                recordCleanupAudit(session, "SKIPPED", "Expired multipart upload cleanup skipped because session state changed");
                cleanupSkippedCounter.increment();
            }
            return expired;
        } catch (RuntimeException exception) {
            log.warn("Failed to cleanup expired multipart upload session {}.", session.uploadId(), exception);
            recordCleanupAudit(session, "FAIL", "Expired multipart upload cleanup failed: " + exception.getMessage());
            cleanupFailureCounter.increment();
            return false;
        }
    }

    private void deletePartChecksums(PresignedUploadSession session) {
        try {
            partChecksumRepository.deleteByUploadId(session.uploadId());
        } catch (RuntimeException exception) {
            log.warn("Failed to delete multipart part checksums for session {}.", session.uploadId(), exception);
        }
    }

    private Counter cleanupSessionCounter(MeterRegistry meterRegistry, String result) {
        return Counter.builder("osmu.multipart.cleanup.sessions")
                .description("Expired multipart upload cleanup session results")
                .tag("result", result)
                .register(meterRegistry);
    }

    private void recordCleanupAudit(PresignedUploadSession session, String result, String message) {
        try {
            auditLogService.record(
                    "OBJECT_MULTIPART_UPLOAD_CLEANUP",
                    SYSTEM_ACTOR,
                    "OBJECT",
                    session.bucketName() + "/" + session.objectKey(),
                    result,
                    message
            );
        } catch (RuntimeException exception) {
            log.warn("Failed to record multipart cleanup audit log for session {}.", session.uploadId(), exception);
        }
    }
}
