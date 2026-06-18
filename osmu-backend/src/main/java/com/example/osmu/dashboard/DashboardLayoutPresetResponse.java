package com.example.osmu.dashboard;

import java.util.List;

public record DashboardLayoutPresetResponse(
        String id,
        String name,
        String description,
        List<DashboardWidgetLayout> widgets,
        List<DashboardSectionLayout> sections,
        String schemaVersion,
        boolean custom
) {
    public DashboardLayoutPresetResponse {
        sections = sections == null ? List.of() : List.copyOf(sections);
    }

    public DashboardLayoutPresetResponse(
            String id,
            String name,
            String description,
            List<DashboardWidgetLayout> widgets,
            boolean custom
    ) {
        this(id, name, description, widgets, List.of(), null, custom);
    }

    public DashboardLayoutPresetResponse(
            String id,
            String name,
            String description,
            List<DashboardWidgetLayout> widgets,
            List<DashboardSectionLayout> sections,
            boolean custom
    ) {
        this(id, name, description, widgets, sections, null, custom);
    }
}
