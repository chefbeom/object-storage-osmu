package com.example.osmu.storageexpansion;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.audit.repository.InMemoryAuditLogRepository;
import com.example.osmu.storageexpansion.repository.InMemoryStorageExpansionExecutionRepository;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class StorageExpansionExecutionLogRetentionJobTest {

    private final InMemoryStorageExpansionExecutionRepository repository =
            new InMemoryStorageExpansionExecutionRepository();
    private final InMemoryAuditLogRepository auditLogRepository = new InMemoryAuditLogRepository();
    private final AuditLogService auditLogService = new AuditLogService(auditLogRepository);
    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final StorageExpansionExecutionLogRetentionJob retentionJob =
            new StorageExpansionExecutionLogRetentionJob(repository, auditLogService, meterRegistry, 30, 100);

    @Test
    void redactsOnlyExpiredRetainedOutputsAndKeepsExecutionRecord() {
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionExecutionRecord oldExecution = saveExecution(1L, "raw old output", now.minusDays(31));
        StorageExpansionExecutionRecord newExecution = saveExecution(2L, "raw new output", now.minusDays(2));
        StorageExpansionExecutionRecord alreadyRedacted = saveExecution(
                3L,
                StorageExpansionExecutionLogRetentionJob.REDACTED_OUTPUT_PREFIX,
                now.minusDays(40)
        );

        StorageExpansionExecutionLogRetentionRunResponse response = retentionJob.runNow(now);

        assertThat(response.redactedOutputCount()).isEqualTo(1);
        assertThat(repository.findById(oldExecution.id()).orElseThrow().output())
                .startsWith(StorageExpansionExecutionLogRetentionJob.REDACTED_OUTPUT_PREFIX)
                .doesNotContain("raw old output");
        assertThat(repository.findById(newExecution.id()).orElseThrow().output()).isEqualTo("raw new output");
        assertThat(repository.findById(alreadyRedacted.id()).orElseThrow().output())
                .isEqualTo(StorageExpansionExecutionLogRetentionJob.REDACTED_OUTPUT_PREFIX);
        assertThat(response.status().pendingOutputCount()).isZero();
        assertThat(meterRegistry.counter(
                "osmu.storage.expansion.execution.log.retention.outputs",
                "result",
                "success"
        ).count()).isEqualTo(1.0);
        AuditLogEntry audit = auditLogRepository.findRecent(1).get(0);
        assertThat(audit.eventType()).isEqualTo("STORAGE_EXPANSION_EXECUTION_LOG_RETENTION");
        assertThat(audit.actorId()).isEqualTo("system");
        assertThat(audit.result()).isEqualTo("SUCCESS");
    }

    @Test
    void statusCountsPendingExpiredOutputs() {
        OffsetDateTime now = OffsetDateTime.now();
        saveExecution(1L, "old output", now.minusDays(31));
        saveExecution(2L, "new output", now.minusDays(1));

        StorageExpansionExecutionLogRetentionStatusResponse status = retentionJob.status(now);

        assertThat(status.enabled()).isTrue();
        assertThat(status.retentionDays()).isEqualTo(30);
        assertThat(status.batchSize()).isEqualTo(100);
        assertThat(status.pendingOutputCount()).isEqualTo(1);
    }

    private StorageExpansionExecutionRecord saveExecution(long id, String output, OffsetDateTime createdAt) {
        return repository.save(new StorageExpansionExecutionRecord(
                id,
                1L,
                "APPLY",
                "SUCCESS",
                "kubectl apply",
                output,
                null,
                "a".repeat(64),
                0,
                false,
                "retention test",
                "admin",
                createdAt
        ));
    }
}
