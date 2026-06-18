package com.example.osmu.dashboard;

import java.time.OffsetDateTime;
import java.util.List;

public record DashboardLayoutPresetBundleExportResponse(
        String formatVersion,
        OffsetDateTime exportedAt,
        List<DashboardLayoutPresetResponse> presets
) {
    public DashboardLayoutPresetBundleExportResponse {
        presets = presets == null ? List.of() : List.copyOf(presets);
    }
}
