package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceInvocationResponse(
        String result,
        String sourceSummary,
        String sourcePlan,
        String commandMode,
        String executionMode,
        int selectedActionCount,
        int plannedCount,
        int blockedCount,
        int executedCount,
        int failedCount,
        List<DashboardOperationsEvidenceInvocationActionResponse> actions
) {
    public static DashboardOperationsEvidenceInvocationResponse empty() {
        return new DashboardOperationsEvidenceInvocationResponse("", "", "", "", "", 0, 0, 0, 0, 0, List.of());
    }
}
