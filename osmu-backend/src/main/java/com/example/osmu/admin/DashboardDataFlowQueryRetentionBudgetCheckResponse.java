package com.example.osmu.admin;

public record DashboardDataFlowQueryRetentionBudgetCheckResponse(
        String id,
        String name,
        String status,
        boolean passed,
        String detail
) {
}