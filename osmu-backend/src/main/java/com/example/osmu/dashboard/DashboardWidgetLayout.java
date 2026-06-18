package com.example.osmu.dashboard;

import java.util.Map;

public record DashboardWidgetLayout(
        String id,
        boolean enabled,
        String size,
        String section,
        Map<String, String> options
) {
    public DashboardWidgetLayout {
        section = section == null || section.isBlank() ? "overview" : section;
        options = options == null ? Map.of() : Map.copyOf(options);
    }

    public DashboardWidgetLayout(String id, boolean enabled, String size) {
        this(id, enabled, size, "overview", Map.of());
    }

    public DashboardWidgetLayout(String id, boolean enabled, String size, String section) {
        this(id, enabled, size, section, Map.of());
    }

    public DashboardWidgetLayout(String id, boolean enabled, String size, Map<String, String> options) {
        this(id, enabled, size, "overview", options);
    }
}
