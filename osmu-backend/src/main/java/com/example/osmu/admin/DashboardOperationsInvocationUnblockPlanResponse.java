package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsInvocationUnblockPlanResponse(
        String result,
        String sourceInvocationReport,
        String sourceResult,
        String sourceSummary,
        int sourcePassedCount,
        int sourcePendingCount,
        int sourceTotalCount,
        int sourceCheckCount,
        int selectedActionCount,
        int plannedCount,
        int blockedCount,
        int failedCount,
        boolean needsKubeconfigSecretConfirmation,
        boolean needsOperatorApprovalConfirmation,
        int requiredPlaceholderCount,
        int ambiguousRepeatedPlaceholderCount,
        int confirmationGroupCount,
        int requiredInputGroupCount,
        List<Integer> blockedActionOrders,
        List<Integer> plannedActionOrders,
        String confirmedPlanCommand,
        String blockedOnlyPlanCommand,
        String plannedOnlyCommand,
        String decisionRule,
        List<DashboardOperationsInvocationUnblockConfirmationGroupResponse> confirmationGroups,
        List<DashboardOperationsInvocationUnblockInputGroupResponse> requiredInputGroups,
        List<DashboardOperationsInvocationUnblockActionResponse> actions
) {
    public static DashboardOperationsInvocationUnblockPlanResponse empty() {
        return new DashboardOperationsInvocationUnblockPlanResponse(
                "",
                "",
                "",
                "",
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                false,
                false,
                0,
                0,
                0,
                0,
                List.of(),
                List.of(),
                "",
                "",
                "",
                "",
                List.of(),
                List.of(),
                List.of()
        );
    }
}
