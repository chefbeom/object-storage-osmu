package com.example.osmu.monitoring;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.http.HttpServletRequest;
import java.time.OffsetDateTime;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/monitoring/data-flow/retention")
public class AdminDataFlowRetentionController {

    private static final String MODE = "DATA_FLOW_RETENTION";

    private final ObjectProvider<DataFlowEventRetentionJob> eventRetentionJobProvider;
    private final ObjectProvider<DataFlowDailyRollupRetentionJob> dailyRollupRetentionJobProvider;
    private final ObjectProvider<DataFlowMonthlyRollupRetentionJob> monthlyRollupRetentionJobProvider;
    private final MeterRegistry meterRegistry;
    private final AuthContext authContext;
    private final AuditLogService auditLogService;
    private final boolean eventRetentionEnabled;
    private final int eventRetentionDays;
    private final int eventRetentionBatchSize;
    private final boolean dailyRollupRetentionEnabled;
    private final int dailyRollupRetentionDays;
    private final int dailyRollupRetentionBatchSize;
    private final boolean monthlyRollupRetentionEnabled;
    private final int monthlyRollupRetentionDays;
    private final int monthlyRollupRetentionBatchSize;

    public AdminDataFlowRetentionController(
            ObjectProvider<DataFlowEventRetentionJob> eventRetentionJobProvider,
            ObjectProvider<DataFlowDailyRollupRetentionJob> dailyRollupRetentionJobProvider,
            ObjectProvider<DataFlowMonthlyRollupRetentionJob> monthlyRollupRetentionJobProvider,
            MeterRegistry meterRegistry,
            AuthContext authContext,
            AuditLogService auditLogService,
            @Value("${osmu.monitoring.data-flow.retention.enabled:true}") boolean eventRetentionEnabled,
            @Value("${osmu.monitoring.data-flow.retention.retention-days:90}") int eventRetentionDays,
            @Value("${osmu.monitoring.data-flow.retention.batch-size:1000}") int eventRetentionBatchSize,
            @Value("${osmu.monitoring.data-flow.daily-rollup.retention.enabled:true}") boolean dailyRollupRetentionEnabled,
            @Value("${osmu.monitoring.data-flow.daily-rollup.retention.retention-days:1095}") int dailyRollupRetentionDays,
            @Value("${osmu.monitoring.data-flow.daily-rollup.retention.batch-size:1000}") int dailyRollupRetentionBatchSize,
            @Value("${osmu.monitoring.data-flow.monthly-rollup.retention.enabled:true}") boolean monthlyRollupRetentionEnabled,
            @Value("${osmu.monitoring.data-flow.monthly-rollup.retention.retention-days:1825}") int monthlyRollupRetentionDays,
            @Value("${osmu.monitoring.data-flow.monthly-rollup.retention.batch-size:1000}") int monthlyRollupRetentionBatchSize
    ) {
        this.eventRetentionJobProvider = eventRetentionJobProvider;
        this.dailyRollupRetentionJobProvider = dailyRollupRetentionJobProvider;
        this.monthlyRollupRetentionJobProvider = monthlyRollupRetentionJobProvider;
        this.meterRegistry = meterRegistry;
        this.authContext = authContext;
        this.auditLogService = auditLogService;
        this.eventRetentionEnabled = eventRetentionEnabled;
        this.eventRetentionDays = clamp(eventRetentionDays, 1, 3650);
        this.eventRetentionBatchSize = clamp(eventRetentionBatchSize, 1, 10_000);
        this.dailyRollupRetentionEnabled = dailyRollupRetentionEnabled;
        this.dailyRollupRetentionDays = clamp(dailyRollupRetentionDays, 1, 3650);
        this.dailyRollupRetentionBatchSize = clamp(dailyRollupRetentionBatchSize, 1, 10_000);
        this.monthlyRollupRetentionEnabled = monthlyRollupRetentionEnabled;
        this.monthlyRollupRetentionDays = clamp(monthlyRollupRetentionDays, 1, 3650);
        this.monthlyRollupRetentionBatchSize = clamp(monthlyRollupRetentionBatchSize, 1, 10_000);
    }

    @GetMapping("/status")
    public ApiResponse<DataFlowRetentionStatusResponse> status() {
        return ApiResponse.of(status(OffsetDateTime.now()));
    }

    @PostMapping("/run")
    public ApiResponse<DataFlowRetentionRunResponse> run(
            @RequestParam(name = "includeEvents", defaultValue = "true") boolean includeEvents,
            @RequestParam(name = "includeDailyRollups", defaultValue = "true") boolean includeDailyRollups,
            @RequestParam(name = "includeMonthlyRollups", defaultValue = "true") boolean includeMonthlyRollups,
            HttpServletRequest request
    ) {
        if (!includeEvents && !includeDailyRollups && !includeMonthlyRollups) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "At least one data-flow retention target must be selected.");
        }
        DataFlowEventRetentionJob eventJob = includeEvents ? availableEventJob() : null;
        DataFlowDailyRollupRetentionJob dailyRollupJob = includeDailyRollups ? availableDailyRollupJob() : null;
        DataFlowMonthlyRollupRetentionJob monthlyRollupJob = includeMonthlyRollups ? availableMonthlyRollupJob() : null;

        OffsetDateTime now = OffsetDateTime.now();
        int deletedEventCount = eventJob == null ? 0 : eventJob.runNow(now);
        int deletedDailyRollupCount = dailyRollupJob == null ? 0 : dailyRollupJob.runNow(now);
        int deletedMonthlyRollupCount = monthlyRollupJob == null ? 0 : monthlyRollupJob.runNow(now);
        DataFlowRetentionStatusResponse status = status(now);
        DataFlowRetentionRunResponse response = new DataFlowRetentionRunResponse(
                MODE,
                deletedEventCount,
                deletedDailyRollupCount,
                deletedMonthlyRollupCount,
                status,
                now,
                "Manual ADMIN data-flow retention run. Detailed event retention is shorter; materialized daily and monthly rollup retention is longer for aggregate analytics."
        );
        AuthenticatedUser user = authContext.currentUser(request);
        auditLogService.record(
                "DATA_FLOW_RETENTION_RUN",
                user.loginId(),
                "DATA_FLOW_RETENTION",
                "all-targets",
                "SUCCESS",
                "Data-flow retention manual run: events=" + deletedEventCount + ", dailyRollups=" + deletedDailyRollupCount
                        + ", monthlyRollups=" + deletedMonthlyRollupCount,
                request
        );
        return ApiResponse.of(response);
    }

    private DataFlowEventRetentionJob availableEventJob() {
        DataFlowEventRetentionJob job = eventRetentionJobProvider.getIfAvailable();
        if (!eventRetentionEnabled || job == null) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Data-flow event retention is disabled.");
        }
        return job;
    }

    private DataFlowDailyRollupRetentionJob availableDailyRollupJob() {
        DataFlowDailyRollupRetentionJob job = dailyRollupRetentionJobProvider.getIfAvailable();
        if (!dailyRollupRetentionEnabled || job == null) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Data-flow daily rollup retention is disabled.");
        }
        return job;
    }

    private DataFlowMonthlyRollupRetentionJob availableMonthlyRollupJob() {
        DataFlowMonthlyRollupRetentionJob job = monthlyRollupRetentionJobProvider.getIfAvailable();
        if (!monthlyRollupRetentionEnabled || job == null) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Data-flow monthly rollup retention is disabled.");
        }
        return job;
    }

    private DataFlowRetentionStatusResponse status(OffsetDateTime generatedAt) {
        DataFlowEventRetentionJob eventJob = eventRetentionJobProvider.getIfAvailable();
        DataFlowDailyRollupRetentionJob dailyRollupJob = dailyRollupRetentionJobProvider.getIfAvailable();
        DataFlowMonthlyRollupRetentionJob monthlyRollupJob = monthlyRollupRetentionJobProvider.getIfAvailable();
        return new DataFlowRetentionStatusResponse(
                MODE,
                eventRetentionStatus(eventJob),
                dailyRollupRetentionStatus(dailyRollupJob),
                monthlyRollupRetentionStatus(monthlyRollupJob),
                generatedAt,
                "OSMU data-flow retention status for detailed events, materialized daily rollups, and stored monthly rollups. This is operational analytics retention, not AWS billing parity."
        );
    }

    private DataFlowRetentionPolicyStatusResponse eventRetentionStatus(DataFlowEventRetentionJob job) {
        return new DataFlowRetentionPolicyStatusResponse(
                eventRetentionEnabled,
                job != null,
                job == null ? eventRetentionDays : job.retentionDays(),
                job == null ? eventRetentionBatchSize : job.batchSize(),
                counterValue("osmu.data.flow.retention.events", "success"),
                counterValue("osmu.data.flow.retention.runs", "failure")
        );
    }

    private DataFlowRetentionPolicyStatusResponse dailyRollupRetentionStatus(DataFlowDailyRollupRetentionJob job) {
        return new DataFlowRetentionPolicyStatusResponse(
                dailyRollupRetentionEnabled,
                job != null,
                job == null ? dailyRollupRetentionDays : job.retentionDays(),
                job == null ? dailyRollupRetentionBatchSize : job.batchSize(),
                counterValue("osmu.data.flow.daily.rollup.retention.rows", "success"),
                counterValue("osmu.data.flow.daily.rollup.retention.runs", "failure")
        );
    }

    private DataFlowRetentionPolicyStatusResponse monthlyRollupRetentionStatus(DataFlowMonthlyRollupRetentionJob job) {
        return new DataFlowRetentionPolicyStatusResponse(
                monthlyRollupRetentionEnabled,
                job != null,
                job == null ? monthlyRollupRetentionDays : job.retentionDays(),
                job == null ? monthlyRollupRetentionBatchSize : job.batchSize(),
                counterValue("osmu.data.flow.monthly.rollup.retention.rows", "success"),
                counterValue("osmu.data.flow.monthly.rollup.retention.runs", "failure")
        );
    }

    private double counterValue(String name, String result) {
        Counter counter = meterRegistry.find(name).tag("result", result).counter();
        return counter == null ? 0.0 : counter.count();
    }

    private int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }
}
