package com.example.osmu.admin;

import java.util.List;

public record DashboardEnterpriseAuthSmokeCheckResponse(
        String id,
        String name,
        String category,
        String endpoint,
        String status,
        String detail,
        List<String> requiredInputs
) {
}
