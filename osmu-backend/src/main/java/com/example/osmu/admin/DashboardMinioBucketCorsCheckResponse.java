package com.example.osmu.admin;

public record DashboardMinioBucketCorsCheckResponse(
        String id,
        String name,
        boolean passed,
        String detail
) {
}
