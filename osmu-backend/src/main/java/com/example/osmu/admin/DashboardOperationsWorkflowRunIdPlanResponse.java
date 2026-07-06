package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsWorkflowRunIdPlanResponse(
        String result,
        String sourceInvocationReport,
        String invocationResult,
        String sourceSummary,
        int sourcePassedCount,
        int sourcePendingCount,
        int sourceTotalCount,
        int sourceCheckCount,
        List<Integer> selectedActionOrders,
        String branch,
        String githubRepository,
        String queryMode,
        boolean githubApiTokenPresent,
        boolean githubApiUnauthenticated,
        boolean queryExecuted,
        int queryExecutedCount,
        int queryWorkflowCount,
        int querySucceededCount,
        int queryErrorCount,
        int candidateCount,
        String runListJsonDirectory,
        String runListJsonDirectoryCommand,
        String githubApiRunListCommand,
        String githubApiBaseUrl,
        String runListJsonFilePattern,
        String runListJsonHandoffNote,
        List<String> browserWorkflowRunsUrls,
        List<DashboardOperationsWorkflowRunIdInputResponse> workflowRunIdInputs,
        List<DashboardOperationsReadinessConvergenceCommandResponse> recommendedCommands,
        int limit,
        int workflowCount,
        int readyWorkflowCount,
        int missingWorkflowCount,
        int staleWorkflowCount,
        String imageSigningVersion,
        String commitSha,
        String artifactCollectionPlanCommand,
        boolean securityEvidenceFinalizerReady,
        List<String> securityEvidenceFinalizerRunIdInputs,
        List<DashboardOperationsWorkflowRunIdInputResponse> securityEvidenceFinalizerRunIdInputHints,
        List<String> securityEvidenceFinalizerMissingRunIdInputs,
        String securityEvidenceFinalizerDependencyNote,
        String securityEvidenceFinalizerCommand,
        String decisionRule,
        List<DashboardOperationsWorkflowRunResponse> workflows
) {
    public static DashboardOperationsWorkflowRunIdPlanResponse empty() {
        return new DashboardOperationsWorkflowRunIdPlanResponse("", "", "", "", 0, 0, 0, 0, List.of(), "", "", "", false, false, false, 0, 0, 0, 0, 0, "", "", "", "", "", "", List.of(), List.of(), List.of(), 0, 0, 0, 0, 0, "", "", "", false, List.of(), List.of(), List.of(), "", "", "", List.of());
    }
}
