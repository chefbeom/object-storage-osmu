package com.example.osmu.object;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.audit.repository.InMemoryAuditLogRepository;
import com.example.osmu.object.repository.InMemoryPresignedUploadSessionRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class MultipartUploadCleanupJobTest {

    private final InMemoryPresignedUploadSessionRepository repository =
            new InMemoryPresignedUploadSessionRepository();
    private final InMemoryAuditLogRepository auditLogRepository = new InMemoryAuditLogRepository();
    private final AuditLogService auditLogService = new AuditLogService(auditLogRepository);
    private final ObjectStorageAdapter storageAdapter = mock(ObjectStorageAdapter.class);
    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final MultipartUploadCleanupJob cleanupJob =
            new MultipartUploadCleanupJob(repository, storageAdapter, auditLogService, meterRegistry, 100);

    @Test
    void cleanupExpiredMultipartUploadsAbortsStorageAndMarksSessionExpired() {
        OffsetDateTime now = OffsetDateTime.now();
        repository.save(session("upload-1", now.minusSeconds(1)));

        int cleaned = cleanupJob.cleanupExpiredMultipartUploads(now);

        assertThat(cleaned).isEqualTo(1);
        verify(storageAdapter).abortMultipartUpload("bucket", "videos/input.mp4", "storage-upload-1");
        PresignedUploadSession saved = repository.findByUploadId("upload-1").orElseThrow();
        assertThat(saved.status()).isEqualTo("EXPIRED");
        assertThat(saved.completedAt()).isEqualTo(now);
        AuditLogEntry audit = auditLogRepository.findRecent(1).get(0);
        assertThat(audit.eventType()).isEqualTo("OBJECT_MULTIPART_UPLOAD_CLEANUP");
        assertThat(audit.actorId()).isEqualTo("system");
        assertThat(audit.targetId()).isEqualTo("bucket/videos/input.mp4");
        assertThat(audit.result()).isEqualTo("SUCCESS");
        assertThat(cleanupSessionCount("success")).isEqualTo(1.0);
        assertThat(cleanupSessionCount("failure")).isZero();
    }

    @Test
    void cleanupExpiredMultipartUploadsKeepsActiveStatusWhenAbortFails() {
        OffsetDateTime now = OffsetDateTime.now();
        repository.save(session("upload-1", now.minusSeconds(1)));
        doThrow(new IllegalStateException("abort failed"))
                .when(storageAdapter)
                .abortMultipartUpload("bucket", "videos/input.mp4", "storage-upload-1");

        int cleaned = cleanupJob.cleanupExpiredMultipartUploads(now);

        assertThat(cleaned).isZero();
        PresignedUploadSession saved = repository.findByUploadId("upload-1").orElseThrow();
        assertThat(saved.status()).isEqualTo("ACTIVE");
        assertThat(saved.completedAt()).isNull();
        AuditLogEntry audit = auditLogRepository.findRecent(1).get(0);
        assertThat(audit.eventType()).isEqualTo("OBJECT_MULTIPART_UPLOAD_CLEANUP");
        assertThat(audit.actorId()).isEqualTo("system");
        assertThat(audit.result()).isEqualTo("FAIL");
        assertThat(cleanupSessionCount("failure")).isEqualTo(1.0);
        assertThat(cleanupSessionCount("success")).isZero();
    }

    private double cleanupSessionCount(String result) {
        return meterRegistry.counter("osmu.multipart.cleanup.sessions", "result", result).count();
    }

    private PresignedUploadSession session(String uploadId, OffsetDateTime expiresAt) {
        return new PresignedUploadSession(
                uploadId,
                1L,
                "bucket",
                "videos/input.mp4",
                "project=osmu,stage=raw",
                "MULTIPART",
                "storage-upload-1",
                10485760L,
                5242880L,
                2,
                "ACTIVE",
                0L,
                false,
                expiresAt,
                expiresAt.minusMinutes(15),
                null
        );
    }
}
