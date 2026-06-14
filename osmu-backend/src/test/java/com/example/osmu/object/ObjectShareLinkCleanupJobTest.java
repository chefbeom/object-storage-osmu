package com.example.osmu.object;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;

import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.audit.repository.InMemoryAuditLogRepository;
import com.example.osmu.object.repository.InMemoryObjectShareLinkRepository;
import com.example.osmu.object.repository.ObjectShareLinkRepository;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class ObjectShareLinkCleanupJobTest {

    private final InMemoryObjectShareLinkRepository repository = new InMemoryObjectShareLinkRepository();
    private final InMemoryAuditLogRepository auditLogRepository = new InMemoryAuditLogRepository();
    private final AuditLogService auditLogService = new AuditLogService(auditLogRepository);
    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final ObjectShareLinkCleanupJob cleanupJob =
            new ObjectShareLinkCleanupJob(repository, auditLogService, meterRegistry);

    @Test
    void cleanupExpiredShareLinksMarksActiveExpiredLinksAndRecordsMetricAndAudit() {
        OffsetDateTime now = OffsetDateTime.now();
        ObjectShareLink expired = repository.save(link("bucket-a", "docs/old.txt", "ACTIVE", now.minusSeconds(1)));
        ObjectShareLink future = repository.save(link("bucket-a", "docs/future.txt", "ACTIVE", now.plusMinutes(5)));
        ObjectShareLink revoked = repository.save(link("bucket-b", "docs/revoked.txt", "REVOKED", now.minusSeconds(1)));

        int cleaned = cleanupJob.cleanupExpiredShareLinks(now);

        assertThat(cleaned).isEqualTo(1);
        assertThat(repository.findById(expired.id()).orElseThrow().status()).isEqualTo("EXPIRED");
        assertThat(repository.findById(future.id()).orElseThrow().status()).isEqualTo("ACTIVE");
        assertThat(repository.findById(revoked.id()).orElseThrow().status()).isEqualTo("REVOKED");
        assertThat(cleanupLinkCount()).isEqualTo(1.0);
        AuditLogEntry audit = auditLogRepository.findRecent(1).get(0);
        assertThat(audit.eventType()).isEqualTo("OBJECT_SHARE_LINK_CLEANUP");
        assertThat(audit.actorId()).isEqualTo("system");
        assertThat(audit.targetType()).isEqualTo("OBJECT_SHARE_LINK");
        assertThat(audit.targetId()).isEqualTo("all-buckets");
        assertThat(audit.result()).isEqualTo("SUCCESS");
    }

    @Test
    void scheduledCleanupRecordsRunFailureMetricWhenRepositoryFails() {
        ObjectShareLinkRepository failingRepository = mock(ObjectShareLinkRepository.class);
        SimpleMeterRegistry failureRegistry = new SimpleMeterRegistry();
        ObjectShareLinkCleanupJob failingJob =
                new ObjectShareLinkCleanupJob(failingRepository, auditLogService, failureRegistry);
        doThrow(new IllegalStateException("db down"))
                .when(failingRepository)
                .expireActiveBefore(org.mockito.ArgumentMatchers.any(OffsetDateTime.class));

        failingJob.cleanupExpiredShareLinks();

        assertThat(failureRegistry.counter("osmu.object.share.cleanup.runs", "result", "failure").count())
                .isEqualTo(1.0);
    }

    private double cleanupLinkCount() {
        return meterRegistry.counter("osmu.object.share.cleanup.links", "result", "success").count();
    }

    private ObjectShareLink link(String bucketName, String objectKey, String status, OffsetDateTime expiresAt) {
        long id = repository.nextId();
        return new ObjectShareLink(
                id,
                "token-hash-" + id,
                "",
                "",
                bucketName,
                objectKey,
                1L,
                status,
                expiresAt,
                "cleanup test",
                null,
                0L,
                null,
                expiresAt.minusHours(1),
                null
        );
    }
}
