package com.example.osmu.dashboard;

import java.time.OffsetDateTime;
import java.util.List;

public record DashboardLayoutPresetRecord(
        String id,
        long createdByUserId,
        String name,
        String description,
        List<DashboardWidgetLayout> widgets,
        List<DashboardSectionLayout> sections,
        String schemaVersion,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
    public DashboardLayoutPresetRecord {
        sections = sections == null ? List.of() : List.copyOf(sections);
    }

    public DashboardLayoutPresetRecord(
            String id,
            long createdByUserId,
            String name,
            String description,
            List<DashboardWidgetLayout> widgets,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
        this(id, createdByUserId, name, description, widgets, List.of(), null, createdAt, updatedAt);
    }

    public DashboardLayoutPresetRecord(
            String id,
            long createdByUserId,
            String name,
            String description,
            List<DashboardWidgetLayout> widgets,
            List<DashboardSectionLayout> sections,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
        this(id, createdByUserId, name, description, widgets, sections, null, createdAt, updatedAt);
    }
}
