package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidencePlanResponse(
        String result,
        String sourceSummary,
        String sourceReport,
        int pendingCount,
        int actionCount,
        int unplannedCount,
        List<DashboardOperationsEvidenceActionResponse> actions
) {
    public static DashboardOperationsEvidencePlanResponse empty() {
        return new DashboardOperationsEvidencePlanResponse("", "", "", 0, 0, 0, List.of());
    }
}
