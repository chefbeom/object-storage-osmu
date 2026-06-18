package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsArtifactCollectionArtifactResponse(
        String group,
        String workflow,
        String runId,
        String runIdInput,
        String artifactName,
        String artifactNameInput,
        String downloadPath,
        String downloadCommand,
        boolean requiredForReadiness,
        boolean ready,
        String note
) {
}
