package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsWorkflowRunResponse(
        String workflow,
        int sourceActionCount,
        int primaryActionOrder,
        String primaryActionName,
        String primaryActionStatus,
        List<Integer> actionOrders,
        List<String> actionNames,
        List<String> actionStatuses,
        List<String> actionCategories,
        List<String> actionTypes,
        String group,
        String queryCommand,
        String queryMode,
        int candidateCount,
        String latestRunId,
        String latestStatus,
        String latestConclusion,
        String latestCreatedAt,
        String latestHeadSha,
        String latestUrl,
        String recommendedRunId,
        String recommendedHeadSha,
        String recommendedCreatedAt,
        String recommendedUrl,
        boolean latestRunIsRecommended,
        boolean readyForArtifactDownload,
        boolean requiredForReadiness,
        String runIdParameter,
        String artifactName,
        String note
) {
}
