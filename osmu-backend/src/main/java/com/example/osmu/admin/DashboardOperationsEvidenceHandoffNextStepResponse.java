package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceHandoffNextStepResponse(
        String code,
        String title,
        String command,
        String reason,
        String note,
        List<String> dispatchUrls
) {
    public static DashboardOperationsEvidenceHandoffNextStepResponse empty() {
        return new DashboardOperationsEvidenceHandoffNextStepResponse("", "", "", "", "", List.of());
    }
}
