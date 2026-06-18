package com.example.osmu.dashboard;

import java.time.OffsetDateTime;
import java.util.List;

public record DashboardLayoutResponse(
        String scope,
        List<DashboardWidgetLayout> widgets,
        List<DashboardSectionLayout> sections,
        String schemaVersion,
        String source,
        OffsetDateTime updatedAt
) {
    public DashboardLayoutResponse {
        sections = sections == null ? List.of() : List.copyOf(sections);
    }

    public DashboardLayoutResponse(
            String scope,
            List<DashboardWidgetLayout> widgets,
            String source,
            OffsetDateTime updatedAt
    ) {
        this(scope, widgets, List.of(), null, source, updatedAt);
    }

    public DashboardLayoutResponse(
            String scope,
            List<DashboardWidgetLayout> widgets,
            List<DashboardSectionLayout> sections,
            String source,
            OffsetDateTime updatedAt
    ) {
        this(scope, widgets, sections, null, source, updatedAt);
    }
}
