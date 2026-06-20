package com.example.osmu.monitoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;

import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.audit.repository.InMemoryAuditLogRepository;
import com.example.osmu.monitoring.repository.DataFlowEventRepository;
import com.example.osmu.monitoring.repository.InMemoryDataFlowEventRepository;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class DataFlowDailyRollupRetentionJobTest {

    private final InMemoryDataFlowEventRepository eventRepository = new InMemoryDataFlowEventRepository();
    private final InMemoryAuditLogRepository auditLogRepository = new InMemoryAuditLogRepository();
    private final AuditLogService auditLogService = new AuditLogService(auditLogRepository);
    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final DataFlowDailyRollupRetentionJob retentionJob =
            new DataFlowDailyRollupRetentionJob(eventRepository, auditLogService, meterRegistry, 365, 100);

    @Test
    void deletesExpiredMaterializedRollupRowsAndRecordsMetricAndAudit() {
        OffsetDateTime now = OffsetDateTime.of(2026, 6, 20, 12, 0, 0, 0, ZoneOffset.UTC);
        eventRepository.save(event("old.bin", now.minusDays(500)));
        eventRepository.save(event("new.bin", now.minusDays(30)));
        eventRepository.refreshDailyRollup(
                new DataFlowEventFilter("media", null, "rest", "upload", "SUCCESS", now.minusDays(600), now.plusDays(1)),
                10
        );

        int deletedCount = retentionJob.runNow(now);

        assertThat(deletedCount).isEqualTo(1);
        assertThat(eventRepository.materializedDailyRollup(
                new DataFlowEventFilter("media", null, "rest", "upload", "SUCCESS", now.minusDays(600), now.plusDays(1)),
                10
        ))
                .extracting(DataFlowDailyRollupPointResponse::day)
                .containsExactly(now.minusDays(30).toLocalDate());
        assertThat(meterRegistry.counter("osmu.data.flow.daily.rollup.retention.rows", "result", "success").count())
                .isEqualTo(1.0);
        AuditLogEntry audit = auditLogRepository.findRecent(1).get(0);
        assertThat(audit.eventType()).isEqualTo("DATA_FLOW_DAILY_ROLLUP_RETENTION");
        assertThat(audit.actorId()).isEqualTo("system");
        assertThat(audit.targetType()).isEqualTo("DATA_FLOW_DAILY_ROLLUP");
        assertThat(audit.result()).isEqualTo("SUCCESS");
    }

    @Test
    void scheduledCleanupRecordsRunFailureMetricWhenRepositoryFails() {
        DataFlowEventRepository failingRepository = mock(DataFlowEventRepository.class);
        SimpleMeterRegistry failureRegistry = new SimpleMeterRegistry();
        DataFlowDailyRollupRetentionJob failingJob =
                new DataFlowDailyRollupRetentionJob(failingRepository, auditLogService, failureRegistry, 365, 100);
        doThrow(new IllegalStateException("db down"))
                .when(failingRepository)
                .deleteMaterializedRollupsBefore(org.mockito.ArgumentMatchers.any(LocalDate.class), org.mockito.ArgumentMatchers.anyInt());

        failingJob.cleanupExpiredRollups();

        assertThat(failureRegistry.counter("osmu.data.flow.daily.rollup.retention.runs", "result", "failure").count())
                .isEqualTo(1.0);
    }

    private DataFlowEventRecord event(String objectKey, OffsetDateTime createdAt) {
        return new DataFlowEventRecord(
                null,
                "UPLOAD",
                "upload",
                "INGRESS",
                "media",
                objectKey,
                "admin",
                "SUCCESS",
                1L,
                "rollup retention test",
                "rest",
                createdAt
        );
    }
}
