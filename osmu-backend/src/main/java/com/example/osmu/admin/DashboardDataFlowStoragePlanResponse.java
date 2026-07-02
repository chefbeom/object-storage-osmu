package com.example.osmu.admin;

import java.util.List;

public record DashboardDataFlowStoragePlanResponse(
        String result,
        String recordedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        String evidenceRef,
        String candidateStore,
        int expectedPeakEventsPerDay,
        int expectedQueryWindowDays,
        int targetP95QueryLatencyMs,
        int eventRetentionDays,
        int dailyRollupRetentionDays,
        int monthlyRollupRetentionMonths,
        int checkCount,
        int passedCount,
        int pendingCount,
        List<DashboardDataFlowStoragePlanCheckResponse> checks,
        DashboardDataFlowStoragePlanCandidateDecisionResponse candidateDecision,
        DashboardDataFlowQueryPlanEvidenceResponse queryPlanEvidence,
        String scopePolicy
) {
    public static DashboardDataFlowStoragePlanResponse empty() {
        return new DashboardDataFlowStoragePlanResponse(
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
                List.of(),
                DashboardDataFlowStoragePlanCandidateDecisionResponse.empty(),
                DashboardDataFlowQueryPlanEvidenceResponse.empty(),
                ""
        );
    }
}
