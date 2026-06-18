package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceHandoffStageResponse(
        String name,
        String reportPath,
        boolean exists,
        String result,
        String summary,
        boolean ready,
        String command,
        String note
) {
}
