package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessConvergenceBottleneckResponse(
        String code,
        String title,
        String reason,
        String command,
        String note,
        List<String> dispatchUrls
) {
    public static DashboardOperationsReadinessConvergenceBottleneckResponse empty() {
        return new DashboardOperationsReadinessConvergenceBottleneckResponse("", "", "", "", "", List.of());
    }
}
