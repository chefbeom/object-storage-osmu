package com.example.osmu.admin;

public record DashboardDataFlowStoragePlanCheckResponse(
        String id,
        String title,
        String status,
        String detail,
        String nextAction
) {
}
