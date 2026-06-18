package com.example.osmu.dashboard;

import java.util.List;

public record DashboardWidgetCatalogItem(
        String id,
        String title,
        String description,
        String category,
        boolean adminOnly,
        List<String> allowedRoles,
        String accessMode,
        List<DashboardWidgetConfigOption> configOptions
) {
    public DashboardWidgetCatalogItem {
        allowedRoles = allowedRoles == null ? List.of() : List.copyOf(allowedRoles);
        accessMode = accessMode == null || accessMode.isBlank() ? "read-only" : accessMode;
        configOptions = configOptions == null ? List.of() : List.copyOf(configOptions);
    }
}
