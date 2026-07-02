package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessSummaryResponse(
        String result,
        String summary,
        String reportPath,
        String generatedAt,
        int passedCount,
        int pendingCount,
        int totalCount,
        int checkCount,
        String pendingCategorySummary,
        List<DashboardOperationsReadinessCategoryCountResponse> pendingCategoryCounts,
        int pendingRemediationCount,
        List<DashboardOperationsReadinessRemediationResponse> pendingRemediations,
        String decisionRule
) {
    public static DashboardOperationsReadinessSummaryResponse empty() {
        return new DashboardOperationsReadinessSummaryResponse(
                "",
                "",
                "",
                "",
                0,
                0,
                0,
                0,
                "",
                List.of(),
                0,
                List.of(),
                ""
        );
    }
}