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
        boolean needsOperatorApprovalConfirmation,
        boolean needsKubeconfigSecretConfirmation,
        List<String> requiredSecrets,
        int missingInputCount,
        int ambiguousInputCount,
        List<DashboardOperationsDispatchPreflightInputResponse> inputs,
        List<String> operatorChecklist
) {
}