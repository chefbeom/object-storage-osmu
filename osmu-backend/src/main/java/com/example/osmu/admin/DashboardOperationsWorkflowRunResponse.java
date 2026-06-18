package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsWorkflowRunResponse(
        String workflow,
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
