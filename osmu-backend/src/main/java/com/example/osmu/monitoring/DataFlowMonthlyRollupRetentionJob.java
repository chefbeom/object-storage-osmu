package com.example.osmu.monitoring;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.monitoring.repository.DataFlowEventRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.time.ZoneOffset;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "osmu.monitoring.data-flow.monthly-rollup.retention",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = true
)
public class DataFlowMonthlyRollupRetentionJob {

    private static final Logger log = LoggerFactory.getLogger(DataFlowMonthlyRollupRetentionJob.class);
    private static final String SYSTEM_ACTOR = "system";

    private final DataFlowEventRepository eventRepository;
    private final AuditLogService auditLogService;
    private final Counter deletedRollupCounter;
    private final Counter failedRunCounter;
    private final int retentionDays;
    private final int batchSize;

    public DataFlowMonthlyRollupRetentionJob(
            DataFlowEventRepository eventRepository,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry,
            @Value("${osmu.monitoring.data-flow.monthly-rollup.retention.retention-days:1825}") int retentionDays,
            @Value("${osmu.monitoring.data-flow.monthly-rollup.retention.batch-size:1000}") int batchSize
    ) {
        this.eventRepository = eventRepository;
        this.auditLogService = auditLogService;
        this.retentionDays = clamp(retentionDays, 1, 3650);
        this.batchSize = clamp(batchSize, 1, 10_000);
        this.deletedRollupCounter = Counter.builder("osmu.data.flow.monthly.rollup.retention.rows")
                .description("Data flow monthly rollup rows deleted by retention policy")
                .tag("result", "success")
                .register(meterRegistry);
        this.failedRunCounter = Counter.builder("osmu.data.flow.monthly.rollup.retention.runs")
                .description("Data flow monthly rollup retention scheduler run count")
                .tag("result", "failure")
                .register(meterRegistry);
    }

    @Scheduled(
            initialDelayString = "${osmu.monitoring.data-flow.monthly-rollup.retention.initial-delay-ms:420000}",
            fixedDelayString = "${osmu.monitoring.data-flow.monthly-rollup.retention.fixed-delay-ms:21600000}"
    )
    public void cleanupExpiredRollups() {
        try {
            runNow(OffsetDateTime.now(ZoneOffset.UTC));
        } catch (RuntimeException exception) {
            failedRunCounter.increment();
            log.warn("Data flow monthly rollup retention cleanup failed.", exception);
        }
    }

    public int runNow(OffsetDateTime now) {
        LocalDate cutoffMonth = YearMonth.from(now.withOffsetSameInstant(ZoneOffset.UTC).minusDays(retentionDays)).atDay(1);
        int deletedCount = eventRepository.deleteMonthlyRollupsBefore(cutoffMonth, batchSize);
        if (deletedCount > 0) {
            deletedRollupCounter.increment(deletedCount);
            recordAudit(deletedCount, cutoffMonth);
        }
        return deletedCount;
    }

    public int retentionDays() {
        return retentionDays;
    }

    public int batchSize() {
        return batchSize;
    }

    private void recordAudit(int deletedCount, LocalDate cutoffMonth) {
        try {
            auditLogService.record(
                    "DATA_FLOW_MONTHLY_ROLLUP_RETENTION",
                    SYSTEM_ACTOR,
                    "DATA_FLOW_MONTHLY_ROLLUP",
                    "materialized",
                    "SUCCESS",
                    "Data flow monthly rollup rows deleted by retention policy: " + deletedCount + ", cutoffMonthBefore=" + cutoffMonth
            );
        } catch (RuntimeException exception) {
            log.warn("Failed to record data flow monthly rollup retention audit log.", exception);
        }
    }

    private int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }
}
