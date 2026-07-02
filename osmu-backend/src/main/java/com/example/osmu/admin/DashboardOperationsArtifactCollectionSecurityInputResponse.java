package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsArtifactCollectionSecurityInputResponse(
        String name,
        String runIdParameter,
        String workflow,
        String artifactName,
        String artifactNameParameter,
        String runId,
        boolean ready,
        boolean sourceArtifactSelected,
        boolean sourceArtifactReady,
        boolean requiredForSecurityFinalizer,
        String note
) {
}