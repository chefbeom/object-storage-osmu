package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsHandoffPackageResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        int passedCount,
        int failureCount,
        int plannedCount,
        int checkCount,
        Map<String, Boolean> confirmations,
        Map<String, String> evidenceRefs,
        DashboardOperationsHandoffPackageReadinessSnapshotResponse operationsReadinessSnapshot,
        DashboardOperationsHandoffPackageConvergenceSnapshotResponse operationsConvergenceSnapshot,
        DashboardDataFlowStoragePlanResponse dataFlowStoragePlanSnapshot,
        List<DashboardOperationsHandoffPackageCheckResponse> checks,
        String decisionRule,
        String scopePolicy,
        String secretPolicy
) {
    public static DashboardOperationsHandoffPackageResponse empty() {
        return new DashboardOperationsHandoffPackageResponse(
                "",
                "",
                "",
                "",
                "",
                0,
                0,
                0,
                0,
                Map.of(),
                Map.of(),
                null,
                null,
                null,
                List.of(),
                "",
                "",
                ""
        );
    }
}
