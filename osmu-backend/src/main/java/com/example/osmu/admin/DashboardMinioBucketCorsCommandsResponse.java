package com.example.osmu.admin;

public record DashboardMinioBucketCorsCommandsResponse(
        String collectWithMc,
        String verifyFromFile,
        String collectAndVerify
) {
    public static DashboardMinioBucketCorsCommandsResponse empty() {
        return new DashboardMinioBucketCorsCommandsResponse("", "", "");
    }
}
