package com.example.osmu.admin;

import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.monitoring.DataFlowMonitoringResponse;
import java.time.OffsetDateTime;

public record DashboardSummaryResponse(
        UsageResponse usage,
        DashboardSystemStatusResponse system,
        BackupStatusResponse backup,
        ObjectRetentionStatusResponse retention,
        ObjectShareAnalyticsResponse shareAnalytics,
        DashboardQuotaSummaryResponse quota,
        DashboardReadinessResponse readiness,
        DataFlowMonitoringResponse dataFlow,
        ListResponse<AuditLogEntry> recentAuditLogs,
        OffsetDateTime generatedAt
) {
}
