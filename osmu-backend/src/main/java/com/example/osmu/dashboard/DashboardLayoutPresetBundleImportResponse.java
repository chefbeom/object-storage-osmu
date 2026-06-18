package com.example.osmu.dashboard;

import java.util.List;

public record DashboardLayoutPresetBundleImportResponse(
        int importedCount,
        List<DashboardLayoutPresetResponse> presets
) {
    public DashboardLayoutPresetBundleImportResponse {
        presets = presets == null ? List.of() : List.copyOf(presets);
    }
}
