package com.example.osmu.monitoring;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.monitoring.repository.DataFlowEventRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "osmu.monitoring.data-flow.daily-rollup.retention",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = true
)
public class DataFlowDailyRollupRetentionJob {

    private static final Logger log = LoggerFactory.getLogger(DataFlowDailyRollupRetentionJob.class);
    private static final String SYSTEM_ACTOR = "system";

    private final DataFlowEventRepository eventRepository;
    private final AuditLogService auditLogService;
    private final Counter deletedRollupCounter;
    private final Counter failedRunCounter;
    private final int retentionDays;
    private final int batchSize;

    public DataFlowDailyRollupRetentionJob(
            DataFlowEventRepository eventRepository,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry,
            @Value("${osmu.monitoring.data-flow.daily-rollup.retention.retention-days:1095}") int retentionDays,
            @Value("${osmu.monitoring.data-flow.daily-rollup.retention.batch-size:1000}") int batchSize
    ) {
        this.eventRepository = eventRepository;
        this.auditLogService = auditLogService;
        this.retentionDays = clamp(retentionDays, 1, 3650);
        this.batchSize = clamp(batchSize, 1, 10_000);
        this.deletedRollupCounter = Counter.builder("osmu.data.flow.daily.rollup.retention.rows")
                .description("Data flow daily rollup rows deleted by retention policy")
                .tag("result", "success")
                .register(meterRegistry);
        this.failedRunCounter = Counter.builder("osmu.data.flow.daily.rollup.retention.runs")
                .description("Data flow daily rollup retention scheduler run count")
                .tag("result", "failure")
                .register(meterRegistry);
    }

    @Scheduled(
            initialDelayString = "${osmu.monitoring.data-flow.daily-rollup.retention.initial-delay-ms:360000}",
            fixedDelayString = "${osmu.monitoring.data-flow.daily-rollup.retention.fixed-delay-ms:21600000}"
    )
    public void cleanupExpiredRollups() {
        try {
            runNow(OffsetDateTime.now(ZoneOffset.UTC));
        } catch (RuntimeException exception) {
            failedRunCounter.increment();
            log.warn("Data flow daily rollup retention cleanup failed.", exception);
        }
    }

    public int runNow(OffsetDateTime now) {
        LocalDate cutoffDay = now.withOffsetSameInstant(ZoneOffset.UTC).toLocalDate().minusDays(retentionDays);
        int deletedCount = eventRepository.deleteMaterializedRollupsBefore(cutoffDay, batchSize);
        if (deletedCount > 0) {
            deletedRollupCounter.increment(deletedCount);
            recordAudit(deletedCount, cutoffDay);
        }
        return deletedCount;
    }

    private void recordAudit(int deletedCount, LocalDate cutoffDay) {
        try {
            auditLogService.record(
                    "DATA_FLOW_DAILY_ROLLUP_RETENTION",
                    SYSTEM_ACTOR,
                    "DATA_FLOW_DAILY_ROLLUP",
                    "materialized",
                    "SUCCESS",
                    "Data flow daily rollup rows deleted by retention policy: " + deletedCount + ", cutoffDayBefore=" + cutoffDay
            );
        } catch (RuntimeException exception) {
            log.warn("Failed to record data flow daily rollup retention audit log.", exception);
        }
    }

    private int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }
}
