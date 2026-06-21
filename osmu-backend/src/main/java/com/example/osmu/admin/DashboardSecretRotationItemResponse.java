package com.example.osmu.admin;

public record DashboardSecretRotationItemResponse(
        String id,
        String name,
        boolean core,
        boolean rotated,
        String note
) {
}
