package com.example.osmu.admin;

import java.util.List;
import java.util.Map;

public record DashboardDataFlowQueryRetentionBudgetResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        String evidenceRef,
        String storagePlanResult,
        String candidateStore,
        int targetP95QueryLatencyMs,
        int observedP95QueryLatencyMs,
        int observedP99QueryLatencyMs,
        int querySampleCount,
        int observedQueryWindowDays,
        int retentionBudgetSeconds,
        int detailedRetentionObservedSeconds,
        int dailyRollupRetentionObservedSeconds,
        int monthlyRollupRetentionObservedSeconds,
        int detailedRetentionDeletedRows,
        int dailyRollupRetentionDeletedRows,
        int monthlyRollupRetentionDeletedRows,
        boolean queryLatencyWithinBudget,
        boolean retentionJobsWithinBudget,
        int failureCount,
        int checkCount,
        Map<String, Boolean> confirmations,
        List<DashboardDataFlowQueryRetentionBudgetCheckResponse> topFailedChecks,
        String scopePolicy
) {
    public static DashboardDataFlowQueryRetentionBudgetResponse empty() {
        return new DashboardDataFlowQueryRetentionBudgetResponse(
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
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                false,
                false,
                0,
                0,
                Map.of(),
                List.of(),
                ""
        );
    }
}