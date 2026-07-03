package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsHandoffInputFreeBlockedActionResponse(
        int actionOrder,
        String name,
        String status,
        int blockReasonCount,
        List<String> blockReasons,
        int requiredInputCount,
        int requiredSecretCount,
        List<String> requiredSecrets,
        boolean needsOperatorApprovalConfirmation,
        boolean needsKubeconfigSecretConfirmation,
        boolean defaultBranchWorkflowMissing,
        String reviewCommand,
        String confirmedPlanCommand,
        String planCommand
) {
}
