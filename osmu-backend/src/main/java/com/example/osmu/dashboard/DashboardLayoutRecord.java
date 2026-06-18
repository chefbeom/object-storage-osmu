package com.example.osmu.dashboard;

import java.time.OffsetDateTime;
import java.util.List;

public record DashboardLayoutRecord(
        long userId,
        String scope,
        List<DashboardWidgetLayout> widgets,
        List<DashboardSectionLayout> sections,
        String schemaVersion,
        OffsetDateTime updatedAt
) {
    public DashboardLayoutRecord {
        sections = sections == null ? List.of() : List.copyOf(sections);
    }

    public DashboardLayoutRecord(
            long userId,
            String scope,
            List<DashboardWidgetLayout> widgets,
            OffsetDateTime updatedAt
    ) {
        this(userId, scope, widgets, List.of(), null, updatedAt);
    }

    public DashboardLayoutRecord(
            long userId,
            String scope,
            List<DashboardWidgetLayout> widgets,
            List<DashboardSectionLayout> sections,
            OffsetDateTime updatedAt
    ) {
        this(userId, scope, widgets, sections, null, updatedAt);
    }
}
