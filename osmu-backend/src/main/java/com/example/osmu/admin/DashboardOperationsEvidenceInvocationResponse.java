package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceInvocationResponse(
        String result,
        String sourceSummary,
        String sourcePlan,
        int sourcePassedCount,
        int sourcePendingCount,
        int sourceTotalCount,
        int sourceCheckCount,
        String commandMode,
        String executionMode,
        int selectedActionCount,
        List<Integer> selectedActionOrders,
        int plannedCount,
        int blockedCount,
        int executedCount,
        int failedCount,
        List<DashboardOperationsEvidenceInvocationActionResponse> actions
) {
    public static DashboardOperationsEvidenceInvocationResponse empty() {
        return new DashboardOperationsEvidenceInvocationResponse("", "", "", 0, 0, 0, 0, "", "", 0, List.of(), 0, 0, 0, 0, List.of());
    }
}
