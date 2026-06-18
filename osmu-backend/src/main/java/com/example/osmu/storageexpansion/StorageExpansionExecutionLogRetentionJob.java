package com.example.osmu.storageexpansion;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.storageexpansion.repository.StorageExpansionExecutionRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.OffsetDateTime;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "osmu.storage-expansion.execution-log.retention",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = true
)
public class StorageExpansionExecutionLogRetentionJob {

    static final String REDACTED_OUTPUT_PREFIX = "[redacted by execution log retention policy]";

    private static final Logger log = LoggerFactory.getLogger(StorageExpansionExecutionLogRetentionJob.class);
    private static final String SYSTEM_ACTOR = "system";

    private final StorageExpansionExecutionRepository executionRepository;
    private final AuditLogService auditLogService;
    private final Counter redactedOutputCounter;
    private final Counter failedRunCounter;
    private final int retentionDays;
    private final int batchSize;

    public StorageExpansionExecutionLogRetentionJob(
            StorageExpansionExecutionRepository executionRepository,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry,
            @Value("${osmu.storage-expansion.execution-log.retention.retention-days:90}") int retentionDays,
            @Value("${osmu.storage-expansion.execution-log.retention.batch-size:100}") int batchSize
    ) {
        this.executionRepository = executionRepository;
        this.auditLogService = auditLogService;
        this.retentionDays = clamp(retentionDays, 1, 3650);
        this.batchSize = clamp(batchSize, 1, 1000);
        this.redactedOutputCounter = Counter.builder("osmu.storage.expansion.execution.log.retention.outputs")
                .description("Storage expansion execution outputs redacted by retention policy")
                .tag("result", "success")
                .register(meterRegistry);
        this.failedRunCounter = Counter.builder("osmu.storage.expansion.execution.log.retention.runs")
                .description("Storage expansion execution log retention run count")
                .tag("result", "failure")
                .register(meterRegistry);
    }

    @Scheduled(
            initialDelayString = "${osmu.storage-expansion.execution-log.retention.initial-delay-ms:180000}",
            fixedDelayString = "${osmu.storage-expansion.execution-log.retention.fixed-delay-ms:3600000}"
    )
    public void redactExpiredOutputs() {
        try {
            runNow(OffsetDateTime.now());
        } catch (RuntimeException exception) {
            failedRunCounter.increment();
            log.warn("Storage expansion execution log retention failed.", exception);
        }
    }

    public StorageExpansionExecutionLogRetentionRunResponse runNow(OffsetDateTime now) {
        OffsetDateTime cutoff = cutoff(now);
        int redactedCount = executionRepository.redactOutputsBefore(cutoff, batchSize, redactedOutput(now, cutoff));
        if (redactedCount > 0) {
            redactedOutputCounter.increment(redactedCount);
            recordAudit(redactedCount);
        }
        return new StorageExpansionExecutionLogRetentionRunResponse(redactedCount, status(now));
    }

    public StorageExpansionExecutionLogRetentionStatusResponse status(OffsetDateTime now) {
        return new StorageExpansionExecutionLogRetentionStatusResponse(
                true,
                retentionDays,
                batchSize,
                executionRepository.countOutputsBefore(cutoff(now)),
                redactedOutputCounter.count(),
                failedRunCounter.count()
        );
    }

    private OffsetDateTime cutoff(OffsetDateTime now) {
        return now.minusDays(retentionDays);
    }

    private String redactedOutput(OffsetDateTime now, OffsetDateTime cutoff) {
        return """
                %s
                redactedAt: %s
                cutoffBefore: %s
                """.formatted(REDACTED_OUTPUT_PREFIX, now, cutoff).trim();
    }

    private void recordAudit(int redactedCount) {
        try {
            auditLogService.record(
                    "STORAGE_EXPANSION_EXECUTION_LOG_RETENTION",
                    SYSTEM_ACTOR,
                    "STORAGE_EXPANSION_EXECUTION",
                    "all-requests",
                    "SUCCESS",
                    "Storage expansion execution outputs redacted by retention policy: " + redactedCount
            );
        } catch (RuntimeException exception) {
            log.warn("Failed to record storage expansion execution log retention audit log.", exception);
        }
    }

    private int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }
}
