package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsArtifactCollectionPlanResponse(
        String result,
        String sourceInvocationReport,
        String invocationResult,
        String sourceSummary,
        int sourcePassedCount,
        int sourcePendingCount,
        int sourceTotalCount,
        int sourceCheckCount,
        List<Integer> selectedActionOrders,
        String invocationSummary,
        int artifactCount,
        int requiredArtifactCount,
        int readyArtifactCount,
        int missingRequiredArtifactCount,
        int securitySourceArtifactCount,
        int readySecuritySourceArtifactCount,
        int missingSecuritySourceArtifactCount,
        boolean securityEvidenceFinalizerReady,
        List<DashboardOperationsArtifactCollectionSecurityInputResponse> securityEvidenceFinalizerInputs,
        List<String> securityEvidenceFinalizerMissingRunIdInputs,
        String securityEvidenceFinalizerCommand,
        String operationsArtifactFinalizerCommand,
        String dataFlowStoragePlanInputNote,
        String dataFlowQueryRetentionBudgetInputNote,
        String dataFlowStorageTransitionRunbookInputNote,
        String minioBucketCorsInputNote,
        String localImportCommand,
        String decisionRule,
        List<DashboardOperationsArtifactCollectionArtifactResponse> artifacts
) {
    public static DashboardOperationsArtifactCollectionPlanResponse empty() {
        return new DashboardOperationsArtifactCollectionPlanResponse("", "", "", "", 0, 0, 0, 0, List.of(), "", 0, 0, 0, 0, 0, 0, 0, false, List.of(), List.of(), "", "", "", "", "", "", "", "", List.of());
    }
}
