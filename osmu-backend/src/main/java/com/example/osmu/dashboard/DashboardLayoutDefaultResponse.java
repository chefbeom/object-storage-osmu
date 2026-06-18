package com.example.osmu.dashboard;

import java.time.OffsetDateTime;

public record DashboardLayoutDefaultResponse(
        String targetType,
        String targetId,
        String presetId,
        String presetName,
        boolean presetCustom,
        OffsetDateTime updatedAt
) {
}
