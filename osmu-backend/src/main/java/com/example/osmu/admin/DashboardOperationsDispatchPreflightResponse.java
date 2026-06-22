package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsDispatchPreflightResponse(
        String result,
        String sourceUnblockPlan,
        String sourceResult,
        int selectedActionCount,
        List<Integer> selectedActionOrders,
        boolean needsKubeconfigSecretConfirmation,
        boolean needsOperatorApprovalConfirmation,
        int requiredInputCount,
        int missingInputCount,
        int ambiguousInputCount,
        int unsafeInputCount,
        int invalidInputCount,
        int failedCheckCount,
        int warningCheckCount,
        List<String> requiredGitHubSecrets,
        List<DashboardOperationsDispatchPreflightWorkflowFileResponse> workflowFiles,
        List<DashboardOperationsDispatchPreflightCheckResponse> checks,
        String readyPlanCommand,
        String executeCommand,
        List<DashboardOperationsDispatchPreflightInputResponse> requiredInputs,
        String decisionRule
) {
    public static DashboardOperationsDispatchPreflightResponse empty() {
        return new DashboardOperationsDispatchPreflightResponse(
                "",
                "",
                "",
                0,
                List.of(),
                false,
                false,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                "",
                "",
                List.of(),
                ""
        );
    }
}
