package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessFinalizeResponse(
        String result,
        String status,
        String readinessResult,
        String readinessSummary,
        String namespace,
        String sourceNamespace,
        String restoreNamespace,
        String backupTimestamp,
        String powerShellCommand,
        int failedCount,
        Map<String, Boolean> selectedSteps,
        Map<String, String> paths,
        List<DashboardOperationsReadinessFinalizeCommandResponse> commands,
        List<DashboardOperationsReadinessFinalizeStepResponse> steps,
        List<String> gaps,
        String secretPolicy
) {
    public static DashboardOperationsReadinessFinalizeResponse empty() {
        return new DashboardOperationsReadinessFinalizeResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                0,
                Map.of(),
                Map.of(),
                List.of(),
                List.of(),
                List.of(),
                ""
        );
    }
}
