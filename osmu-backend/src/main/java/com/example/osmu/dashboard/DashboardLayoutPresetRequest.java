package com.example.osmu.dashboard;

import java.util.List;

public record DashboardLayoutPresetRequest(
        String name,
        String description,
        List<DashboardWidgetLayout> widgets,
        List<DashboardSectionLayout> sections,
        String schemaVersion
) {
    public DashboardLayoutPresetRequest {
        sections = sections == null ? List.of() : List.copyOf(sections);
    }

    public DashboardLayoutPresetRequest(
            String name,
            String description,
            List<DashboardWidgetLayout> widgets
    ) {
        this(name, description, widgets, List.of(), null);
    }

    public DashboardLayoutPresetRequest(
            String name,
            String description,
            List<DashboardWidgetLayout> widgets,
            List<DashboardSectionLayout> sections
    ) {
        this(name, description, widgets, sections, null);
    }
}
