package com.example.osmu.dashboard;

import java.util.List;

public record DashboardWidgetCatalogItem(
        String id,
        String title,
        String description,
        String category,
        boolean adminOnly,
        List<DashboardWidgetConfigOption> configOptions
) {
    public DashboardWidgetCatalogItem {
        configOptions = configOptions == null ? List.of() : List.copyOf(configOptions);
    }
}
