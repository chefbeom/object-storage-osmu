package com.example.osmu.dashboard;

import java.util.List;

public record DashboardLayoutPresetImportRequest(
        String formatVersion,
        DashboardLayoutPresetRequest preset,
        String name,
        String description,
        List<DashboardWidgetLayout> widgets,
        List<DashboardSectionLayout> sections,
        String schemaVersion
) {
    public DashboardLayoutPresetImportRequest {
        sections = sections == null ? List.of() : List.copyOf(sections);
    }
}
