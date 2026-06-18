package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceHandoffNextStepResponse(
        String code,
        String title,
        String command,
        String reason,
        String note
) {
    public static DashboardOperationsEvidenceHandoffNextStepResponse empty() {
        return new DashboardOperationsEvidenceHandoffNextStepResponse("", "", "", "", "");
    }
}
