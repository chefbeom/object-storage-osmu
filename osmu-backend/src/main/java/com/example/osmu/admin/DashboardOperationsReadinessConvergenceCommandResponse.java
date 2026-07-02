package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessConvergenceCommandResponse(
        int order,
        String name,
        String command,
        String reason,
        String note,
        List<String> dispatchUrls
) {
}
