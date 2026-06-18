package com.example.osmu.dashboard;

public record DashboardLayoutDefaultRequest(
        String targetType,
        String targetId,
        String presetId
) {
}
