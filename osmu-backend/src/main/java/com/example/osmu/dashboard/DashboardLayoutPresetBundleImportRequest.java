package com.example.osmu.dashboard;

import java.util.List;

public record DashboardLayoutPresetBundleImportRequest(
        String formatVersion,
        List<DashboardLayoutPresetRequest> presets
) {
    public DashboardLayoutPresetBundleImportRequest {
        presets = presets == null ? List.of() : List.copyOf(presets);
    }
}
