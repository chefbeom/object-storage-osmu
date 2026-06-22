package com.example.osmu.admin;

public record DashboardDataFlowStorageTransitionRunbookCheckResponse(
        String id,
        String name,
        String status,
        boolean passed,
        String detail
) {
}
