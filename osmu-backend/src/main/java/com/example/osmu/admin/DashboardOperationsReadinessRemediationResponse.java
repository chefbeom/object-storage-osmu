package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessRemediationResponse(
        String name,
        String category,
        String evidencePath,
        String requiredEvidence,
        String detail,
        String command,
        String workflow,
        String workflowCommand,
        String note
) {
}
