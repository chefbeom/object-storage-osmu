package com.example.osmu.admin;

public record DashboardDataFlowStoragePlanCandidateDecisionResponse(
        String candidateStore,
        String decision,
        String evidenceModel,
        boolean requiresMariaDbQueryEvidence,
        boolean requiresTargetStoreEvidence,
        boolean queryPlanEvidenceRequired,
        boolean queryPlanEvidencePassed,
        boolean targetStoreEvidenceConfirmed,
        String safeDataPolicy,
        String nextAction
) {
    public static DashboardDataFlowStoragePlanCandidateDecisionResponse empty() {
        return new DashboardDataFlowStoragePlanCandidateDecisionResponse(
                "",
                "",
                "",
                false,
                false,
                false,
                false,
                false,
                "",
                ""
        );
    }
}