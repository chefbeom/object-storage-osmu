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
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class DataFlowEventRetentionJobTest {

    private final InMemoryDataFlowEventRepository eventRepository = new InMemoryDataFlowEventRepository();
    private final InMemoryAuditLogRepository auditLogRepository = new InMemoryAuditLogRepository();
    private final AuditLogService auditLogService = new AuditLogService(auditLogRepository);
    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final DataFlowEventRetentionJob retentionJob =
            new DataFlowEventRetentionJob(eventRepository, auditLogService, meterRegistry, 30, 100);

    @Test
    void deletesExpiredEventsAndRecordsMetricAndAudit() {
        OffsetDateTime now = OffsetDateTime.now();
        eventRepository.save(event("old-a", now.minusDays(31)));
        eventRepository.save(event("old-b", now.minusDays(45)));
        eventRepository.save(event("new", now.minusDays(2)));

        int deletedCount = retentionJob.runNow(now);

        assertThat(deletedCount).isEqualTo(2);
        assertThat(eventRepository.find(DataFlowEventFilter.empty(), 10))
                .extracting(DataFlowEventRecord::objectKey)
                .containsExactly("new");
        assertThat(meterRegistry.counter("osmu.data.flow.retention.events", "result", "success").count())
                .isEqualTo(2.0);
        AuditLogEntry audit = auditLogRepository.findRecent(1).get(0);
        assertThat(audit.eventType()).isEqualTo("DATA_FLOW_EVENT_RETENTION");
        assertThat(audit.actorId()).isEqualTo("system");
        assertThat(audit.targetType()).isEqualTo("DATA_FLOW_EVENT");
        assertThat(audit.result()).isEqualTo("SUCCESS");
    }

    @Test
    void scheduledCleanupRecordsRunFailureMetricWhenRepositoryFails() {
        DataFlowEventRepository failingRepository = mock(DataFlowEventRepository.class);
        SimpleMeterRegistry failureRegistry = new SimpleMeterRegistry();
        DataFlowEventRetentionJob failingJob =
                new DataFlowEventRetentionJob(failingRepository, auditLogService, failureRegistry, 30, 100);
        doThrow(new IllegalStateException("db down"))
                .when(failingRepository)
                .deleteBefore(org.mockito.ArgumentMatchers.any(OffsetDateTime.class), org.mockito.ArgumentMatchers.anyInt());

        failingJob.cleanupExpiredEvents();

        assertThat(failureRegistry.counter("osmu.data.flow.retention.runs", "result", "failure").count())
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
                "retention test",
                "rest",
                createdAt
        );
    }
}
