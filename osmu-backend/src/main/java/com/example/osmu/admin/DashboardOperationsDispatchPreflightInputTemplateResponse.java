package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsDispatchPreflightInputTemplateResponse(
        int actionOrder,
        String name,
        String category,
        String actionType,
        String commandMode,
        String workflow,
        String dispatchUrl,
        boolean needsOperatorApprovalConfirmation,
        boolean needsKubeconfigSecretConfirmation,
        List<String> requiredSecrets,
        List<String> workflowInputNames,
        boolean readyToDispatch,
        int missingInputCount,
        int unsafeInputCount,
        int invalidInputCount,
        int ambiguousInputCount,
        List<String> missingInputParameters,
        List<String> unsafeInputParameters,
        List<String> invalidInputParameters,
        List<DashboardOperationsDispatchPreflightInputResponse> inputs,
        List<String> operatorChecklist
) {
}