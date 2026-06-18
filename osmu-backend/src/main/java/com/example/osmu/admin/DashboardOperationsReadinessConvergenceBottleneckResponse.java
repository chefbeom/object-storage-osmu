package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessConvergenceBottleneckResponse(
        String code,
        String title,
        String reason,
        String command
) {
    public static DashboardOperationsReadinessConvergenceBottleneckResponse empty() {
        return new DashboardOperationsReadinessConvergenceBottleneckResponse("", "", "", "");
    }
}
