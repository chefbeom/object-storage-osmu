package com.example.osmu.admin;

import java.util.List;

public record DashboardDataFlowQueryPlanEvidenceResponse(
        boolean provided,
        String path,
        boolean parsed,
        String formatVersion,
        String expectedFormatVersion,
        boolean validFormatVersion,
        String result,
        String mode,
        int checkCount,
        int passedCount,
        int failedCount,
        List<DashboardDataFlowQueryPlanFailedCheckResponse> failedChecks,
        String detail
) {
    public static DashboardDataFlowQueryPlanEvidenceResponse empty() {
        return new DashboardDataFlowQueryPlanEvidenceResponse(
                false,
                "",
                false,
                "",
                "",
                false,
                "",
                "",
                0,
                0,
                0,
                List.of(),
                ""
        );
    }
}
