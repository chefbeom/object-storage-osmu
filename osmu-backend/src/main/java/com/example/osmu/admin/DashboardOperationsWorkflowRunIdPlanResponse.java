package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsWorkflowRunIdPlanResponse(
        String result,
        String sourceInvocationReport,
        String invocationResult,
        String branch,
        String queryMode,
        int limit,
        int workflowCount,
        int readyWorkflowCount,
        int missingWorkflowCount,
        int staleWorkflowCount,
        String imageSigningVersion,
        String commitSha,
        String artifactCollectionPlanCommand,
        String securityEvidenceFinalizerCommand,
        String decisionRule,
        List<DashboardOperationsWorkflowRunResponse> workflows
) {
    public static DashboardOperationsWorkflowRunIdPlanResponse empty() {
        return new DashboardOperationsWorkflowRunIdPlanResponse("", "", "", "", "", 0, 0, 0, 0, 0, "", "", "", "", "", List.of());
    }
}
