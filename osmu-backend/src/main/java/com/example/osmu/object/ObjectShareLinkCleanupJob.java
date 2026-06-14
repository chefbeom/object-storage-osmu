package com.example.osmu.object;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.object.repository.ObjectShareLinkRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.OffsetDateTime;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.object.share-link.cleanup", name = "enabled", havingValue = "true", matchIfMissing = true)
public class ObjectShareLinkCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(ObjectShareLinkCleanupJob.class);
    private static final String SYSTEM_ACTOR = "system";

    private final ObjectShareLinkRepository shareLinkRepository;
    private final AuditLogService auditLogService;
    private final Counter cleanupSuccessCounter;
    private final Counter cleanupRunFailureCounter;

    public ObjectShareLinkCleanupJob(
            ObjectShareLinkRepository shareLinkRepository,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry
    ) {
        this.shareLinkRepository = shareLinkRepository;
        this.auditLogService = auditLogService;
        this.cleanupSuccessCounter = Counter.builder("osmu.object.share.cleanup.links")
                .description("Expired object share link cleanup results")
                .tag("result", "success")
                .register(meterRegistry);
        this.cleanupRunFailureCounter = Counter.builder("osmu.object.share.cleanup.runs")
                .description("Object share link cleanup scheduler run count")
                .tag("result", "failure")
                .register(meterRegistry);
    }

    @Scheduled(
            initialDelayString = "${osmu.object.share-link.cleanup.initial-delay-ms:180000}",
            fixedDelayString = "${osmu.object.share-link.cleanup.fixed-delay-ms:3600000}"
    )
    public void cleanupExpiredShareLinks() {
        try {
            cleanupExpiredShareLinks(OffsetDateTime.now());
        } catch (RuntimeException exception) {
            cleanupRunFailureCounter.increment();
            log.warn("Expired object share link cleanup failed.", exception);
        }
    }

    int cleanupExpiredShareLinks(OffsetDateTime now) {
        int expiredCount = shareLinkRepository.expireActiveBefore(now);
        if (expiredCount > 0) {
            cleanupSuccessCounter.increment(expiredCount);
            recordCleanupAudit(expiredCount);
        }
        return expiredCount;
    }

    private void recordCleanupAudit(int expiredCount) {
        try {
            auditLogService.record(
                    "OBJECT_SHARE_LINK_CLEANUP",
                    SYSTEM_ACTOR,
                    "OBJECT_SHARE_LINK",
                    "all-buckets",
                    "SUCCESS",
                    "Expired object share links cleaned by scheduler: " + expiredCount
            );
        } catch (RuntimeException exception) {
            log.warn("Failed to record object share link cleanup audit log.", exception);
        }
    }
}
