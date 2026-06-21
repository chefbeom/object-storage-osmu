package com.example.osmu.admin;

public record DashboardSecretRotationCheckResponse(
        String id,
        String name,
        String status,
        boolean passed,
        String detail
) {
}
