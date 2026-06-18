package com.example.osmu.dashboard;

import java.util.List;

public record DashboardWidgetConfigOption(
        String key,
        String label,
        String type,
        List<String> values,
        String defaultValue
) {
    public DashboardWidgetConfigOption {
        values = values == null ? List.of() : List.copyOf(values);
    }
}
