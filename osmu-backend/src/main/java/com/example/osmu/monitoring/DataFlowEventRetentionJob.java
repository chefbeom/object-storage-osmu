package com.example.osmu.monitoring;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.monitoring.repository.DataFlowEventRepository;
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
        prefix = "osmu.monitoring.data-flow.retention",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = true
)
public class DataFlowEventRetentionJob {

    private static final Logger log = LoggerFactory.getLogger(DataFlowEventRetentionJob.class);
    private static final String SYSTEM_ACTOR = "system";

    private final DataFlowEventRepository eventRepository;
    private final AuditLogService auditLogService;
    private final Counter deletedEventCounter;
    private final Counter failedRunCounter;
    private final int retentionDays;
    private final int batchSize;

    public DataFlowEventRetentionJob(
            DataFlowEventRepository eventRepository,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry,
            @Value("${osmu.monitoring.data-flow.retention.retention-days:90}") int retentionDays,
            @Value("${osmu.monitoring.data-flow.retention.batch-size:1000}") int batchSize
    ) {
        this.eventRepository = eventRepository;
        this.auditLogService = auditLogService;
        this.retentionDays = clamp(retentionDays, 1, 3650);
        this.batchSize = clamp(batchSize, 1, 10_000);
        this.deletedEventCounter = Counter.builder("osmu.data.flow.retention.events")
                .description("Data flow events deleted by retention policy")
                .tag("result", "success")
                .register(meterRegistry);
        this.failedRunCounter = Counter.builder("osmu.data.flow.retention.runs")
                .description("Data flow event retention scheduler run count")
                .tag("result", "failure")
                .register(meterRegistry);
    }

    @Scheduled(
            initialDelayString = "${osmu.monitoring.data-flow.retention.initial-delay-ms:300000}",
            fixedDelayString = "${osmu.monitoring.data-flow.retention.fixed-delay-ms:21600000}"
    )
    public void cleanupExpiredEvents() {
        try {
            runNow(OffsetDateTime.now());
        } catch (RuntimeException exception) {
            failedRunCounter.increment();
            log.warn("Data flow event retention cleanup failed.", exception);
        }
    }

    public int runNow(OffsetDateTime now) {
        OffsetDateTime cutoff = now.minusDays(retentionDays);
        int deletedCount = eventRepository.deleteBefore(cutoff, batchSize);
        if (deletedCount > 0) {
            deletedEventCounter.increment(deletedCount);
            recordAudit(deletedCount, cutoff);
        }
        return deletedCount;
    }

    private void recordAudit(int deletedCount, OffsetDateTime cutoff) {
        try {
            auditLogService.record(
                    "DATA_FLOW_EVENT_RETENTION",
                    SYSTEM_ACTOR,
                    "DATA_FLOW_EVENT",
                    "all-events",
                    "SUCCESS",
                    "Data flow events deleted by retention policy: " + deletedCount + ", cutoffBefore=" + cutoff
            );
        } catch (RuntimeException exception) {
            log.warn("Failed to record data flow event retention audit log.", exception);
        }
    }

    private int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }
}
