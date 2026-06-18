package com.example.osmu.dashboard;

import java.time.OffsetDateTime;

public record DashboardLayoutDefaultRecord(
        String targetType,
        String targetId,
        String presetId,
        long updatedByUserId,
        OffsetDateTime updatedAt
) {
}
