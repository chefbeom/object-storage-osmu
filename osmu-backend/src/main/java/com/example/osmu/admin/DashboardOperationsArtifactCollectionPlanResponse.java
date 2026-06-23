package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsArtifactCollectionPlanResponse(
        String result,
        String sourceInvocationReport,
        String invocationResult,
        String invocationSummary,
        int artifactCount,
        int requiredArtifactCount,
        int readyArtifactCount,
        int missingRequiredArtifactCount,
        String securityEvidenceFinalizerCommand,
        String operationsArtifactFinalizerCommand,
        String dataFlowStoragePlanInputNote,
        String dataFlowStorageTransitionRunbookInputNote,
        String minioBucketCorsInputNote,
        String localImportCommand,
        String decisionRule,
        List<DashboardOperationsArtifactCollectionArtifactResponse> artifacts
) {
    public static DashboardOperationsArtifactCollectionPlanResponse empty() {
        return new DashboardOperationsArtifactCollectionPlanResponse("", "", "", "", 0, 0, 0, 0, "", "", "", "", "", "", "", List.of());
    }
}
