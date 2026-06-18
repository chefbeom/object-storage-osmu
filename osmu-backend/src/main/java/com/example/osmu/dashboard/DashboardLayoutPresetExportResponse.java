package com.example.osmu.dashboard;

import java.time.OffsetDateTime;

public record DashboardLayoutPresetExportResponse(
        String formatVersion,
        OffsetDateTime exportedAt,
        DashboardLayoutPresetResponse preset
) {
}
