package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsWorkflowRunIdInputResponse(
        String workflow,
        String group,
        List<Integer> actionOrders,
        String runIdParameter,
        String recommendedRunId,
        String artifactName,
        boolean requiredForReadiness,
        boolean readyForArtifactDownload,
        String runsUrl,
        String runListJsonPath,
        String queryCommand,
        String gitHubApiQueryUrl,
        boolean sourceSelected,
        boolean supplementalForSecurityFinalizer
) {
}