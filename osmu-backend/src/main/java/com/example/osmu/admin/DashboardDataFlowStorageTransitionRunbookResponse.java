package com.example.osmu.admin;

import java.util.List;
import java.util.Map;

public record DashboardDataFlowStorageTransitionRunbookResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        String evidenceRef,
        String storagePlanResult,
        String candidateStore,
        int targetP95QueryLatencyMs,
        int failureCount,
        int checkCount,
        Map<String, Boolean> confirmations,
        List<DashboardDataFlowStorageTransitionRunbookCheckResponse> topFailedChecks,
        String scopePolicy
) {
    public static DashboardDataFlowStorageTransitionRunbookResponse empty() {
        return new DashboardDataFlowStorageTransitionRunbookResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                0,
                0,
                0,
                Map.of(),
                List.of(),
                ""
        );
    }
}
