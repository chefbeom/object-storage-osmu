package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardKubernetesOperationsReportSyncCheckResponse(
        String name,
        boolean passed,
        String summary,
        String command,
        int exitCode
) {
}
