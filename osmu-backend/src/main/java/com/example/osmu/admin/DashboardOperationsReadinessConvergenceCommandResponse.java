package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessConvergenceCommandResponse(
        int order,
        String name,
        String command,
        String reason
) {
}
