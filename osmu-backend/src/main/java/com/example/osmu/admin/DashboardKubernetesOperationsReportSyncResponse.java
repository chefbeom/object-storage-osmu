package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardKubernetesOperationsReportSyncResponse(
        String result,
        String generatedAt,
        String namespace,
        String configMapName,
        String configMapKey,
        String sourceReportPath,
        String sourceReportFormatVersion,
        String sourceReportResult,
        long sourceReportBytes,
        String sourceReportSha256,
        String clientDryRunCommand,
        String serverDryRunCommand,
        String applyCommand,
        int checkCount,
        int failedCount,
        List<DashboardKubernetesOperationsReportSyncCheckResponse> checks,
        String safetyPolicy
) {
    public static DashboardKubernetesOperationsReportSyncResponse empty() {
        return new DashboardKubernetesOperationsReportSyncResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                0L,
                "",
                "",
                "",
                "",
                0,
                0,
                List.of(),
                ""
        );
    }
}
