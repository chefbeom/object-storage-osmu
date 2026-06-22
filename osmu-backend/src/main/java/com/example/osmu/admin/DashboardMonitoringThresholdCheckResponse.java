package com.example.osmu.admin;

public record DashboardMonitoringThresholdCheckResponse(
        String id,
        String name,
        String status,
        boolean passed,
        String detail
) {
}
