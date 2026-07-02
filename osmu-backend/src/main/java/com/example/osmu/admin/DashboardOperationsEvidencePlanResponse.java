package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidencePlanResponse(
        String result,
        String sourceSummary,
        String sourceReport,
        int sourcePassedCount,
        int sourcePendingCount,
        int sourceTotalCount,
        int sourceCheckCount,
        int sourcePendingRemediationCount,
        int sourcePendingRemediationEntryCount,
        int sourcePendingRemediationActionCount,
        int sourcePendingRemediationMissingActionCount,
        boolean sourcePendingRemediationCoverageReady,
        int pendingCount,
        int actionCount,
        int unplannedCount,
        String pendingCategorySummary,
        List<DashboardOperationsEvidencePlanCategoryCountResponse> pendingCategoryCounts,
        DashboardOperationsEvidencePlanSummaryResponse actionSummary,
        List<DashboardOperationsEvidenceActionResponse> actions
) {
    public static DashboardOperationsEvidencePlanResponse empty() {
        return new DashboardOperationsEvidencePlanResponse(
                "",
                "",
                "",
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                false,
                0,
                0,
                0,
                "",
                List.of(),
                DashboardOperationsEvidencePlanSummaryResponse.empty(),
                List.of()
        );
    }
}