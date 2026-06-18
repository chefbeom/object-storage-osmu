package com.example.osmu.dashboard;

import java.util.List;

public record DashboardLayoutRequest(
        List<DashboardWidgetLayout> widgets,
        List<DashboardSectionLayout> sections,
        String schemaVersion
) {
    public DashboardLayoutRequest {
        sections = sections == null ? List.of() : List.copyOf(sections);
    }

    public DashboardLayoutRequest(List<DashboardWidgetLayout> widgets) {
        this(widgets, List.of(), null);
    }

    public DashboardLayoutRequest(List<DashboardWidgetLayout> widgets, List<DashboardSectionLayout> sections) {
        this(widgets, sections, null);
    }
}
