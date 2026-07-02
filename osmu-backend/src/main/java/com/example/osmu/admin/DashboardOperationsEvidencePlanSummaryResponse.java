package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidencePlanSummaryResponse(
        int totalActions,
        int kubernetesLiveActions,
        int securityCiActions,
        int operatorRemediationActions,
        int requiresOperatorApprovalCount,
        int requiresKubeconfigSecretCount,
        int actionsWithPlaceholdersCount,
        int unplannedCheckCount
) {
    public static DashboardOperationsEvidencePlanSummaryResponse empty() {
        return new DashboardOperationsEvidencePlanSummaryResponse(0, 0, 0, 0, 0, 0, 0, 0);
    }
}