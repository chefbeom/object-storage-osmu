package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceActionResponse(
        int order,
        String name,
        String category,
        String actionType,
        String evidencePath,
        String requiredEvidence,
        String currentDetail,
        String localCommand,
        String workflow,
        String workflowCommand,
        String dispatchUrl,
        String recommendedCommand,
        List<String> operatorInputs,
        boolean hasPlaceholders,
        boolean requiresOperatorApproval,
        boolean requiresKubeconfigSecret,
        String note
) {
}
