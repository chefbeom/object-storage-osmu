package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardEnterpriseAuthJitRollbackSmokeSummaryResponse(
        boolean provided,
        boolean parsed,
        String formatVersion,
        String result,
        String executionMode,
        int passCount,
        int failCount,
        int blockedCount,
        int plannedCount,
        boolean scopeOutAccepted,
        String detail
) {
    public static DashboardEnterpriseAuthJitRollbackSmokeSummaryResponse empty() {
        return new DashboardEnterpriseAuthJitRollbackSmokeSummaryResponse(
                false,
                false,
                "",
                "",
                "",
                0,
                0,
                0,
                0,
                false,
                ""
        );
    }
}
