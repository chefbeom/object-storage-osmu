package com.example.osmu.admin;

public record DashboardDataFlowQueryPlanFailedCheckResponse(
        String id,
        String table,
        String queryPath,
        String expectedIndex,
        String status,
        boolean usesExpectedIndex,
        String errorMessage
) {
}
