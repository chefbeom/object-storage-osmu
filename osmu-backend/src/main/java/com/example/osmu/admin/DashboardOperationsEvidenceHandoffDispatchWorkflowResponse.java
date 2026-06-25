package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceHandoffDispatchWorkflowResponse(
        int actionOrder,
        String name,
        String category,
        String actionType,
        String commandMode,
        String workflow,
        boolean readyToDispatch,
        int missingInputCount,
        int unsafeInputCount,
        int invalidInputCount,
        int ambiguousInputCount,
        List<String> requiredSecrets,
        List<String> workflowInputNames,
        List<String> missingInputParameters,
        List<String> operatorChecklist
) {
}
