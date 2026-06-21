package com.example.osmu.admin;

public record DashboardOperationsGateCheckResponse(
        String name,
        String category,
        boolean passed,
        String summary,
        int exitCode
) {
}
