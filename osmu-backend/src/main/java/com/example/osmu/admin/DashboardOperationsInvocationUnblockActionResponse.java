package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsInvocationUnblockActionResponse(
        int order,
        String name,
        String category,
        String actionType,
        String evidencePath,
        String status,
        String commandMode,
        String command,
        List<String> blockReasons,
        List<String> unresolvedPlaceholders,
        List<String> invalidPlaceholders,
        boolean requiresOperatorApproval,
        boolean requiresKubeconfigSecret,
        boolean needsOperatorApprovalConfirmation,
        boolean needsKubeconfigSecretConfirmation,
        List<DashboardOperationsInvocationUnblockInputResponse> requiredInputs,
        boolean ambiguousRepeatedPlaceholders,
        String planCommand
) {
}
