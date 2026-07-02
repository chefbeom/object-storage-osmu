package com.example.osmu.admin;

public record DashboardSupportEscalationHandoffCheckResponse(
        String id,
        String name,
        String status,
        boolean passed,
        String detail,
        String evidenceRef
) {
}
