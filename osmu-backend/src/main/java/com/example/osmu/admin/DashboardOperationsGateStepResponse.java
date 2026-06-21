package com.example.osmu.admin;

public record DashboardOperationsGateStepResponse(
        String name,
        String result,
        int exitCode,
        String notes
) {
}
