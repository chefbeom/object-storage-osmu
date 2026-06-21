package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardStorageExpansionFinalizeResponse(
        String result,
        String generatedAt,
        String startedAt,
        String completedAt,
        String namespace,
        String tenantName,
        String serviceAccount,
        boolean impersonateRunner,
        boolean runBackendDryRunRunner,
        boolean runBackendApply,
        boolean confirmApply,
        boolean runStorageBackendTelemetry,
        int failedCount,
        Map<String, String> evidence,
        List<String> gaps,
        List<DashboardOperationsGateStepResponse> steps,
        String secretPolicy
) {
    public static DashboardStorageExpansionFinalizeResponse empty() {
        return new DashboardStorageExpansionFinalizeResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                false,
                false,
                false,
                false,
                false,
                0,
                Map.of(),
                List.of(),
                List.of(),
                ""
        );
    }
}
