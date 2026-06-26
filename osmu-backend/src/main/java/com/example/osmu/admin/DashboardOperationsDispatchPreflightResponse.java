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
        int readyActionCount,
        List<Integer> readyActionOrders,
        int blockedActionCount,
        List<Integer> blockedActionOrders,
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
        String githubCliPath,
        List<DashboardOperationsDispatchPreflightWorkflowFileResponse> workflowFiles,
        List<DashboardOperationsDispatchPreflightCheckResponse> checks,
        String readyPlanCommand,
        String executeCommand,
        String readySubsetPlanCommand,
        String readySubsetExecuteCommand,
        List<DashboardOperationsDispatchPreflightInputResponse> requiredInputs,
        List<DashboardOperationsDispatchPreflightInputTemplateResponse> inputTemplates,
        String decisionRule
) {
    public static DashboardOperationsDispatchPreflightResponse empty() {
        return new DashboardOperationsDispatchPreflightResponse(
                "",
                "",
                "",
                0,
                List.of(),
                0,
                List.of(),
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
                "",
                List.of(),
                List.of(),
                "",
                "",
                "",
                "",
                List.of(),
                List.of(),
                ""
        );
    }
}
