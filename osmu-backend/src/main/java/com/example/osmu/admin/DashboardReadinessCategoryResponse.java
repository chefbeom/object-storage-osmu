package com.example.osmu.admin;

public record DashboardReadinessCategoryResponse(
        String category,
        int totalCount,
        int blockerCount,
        int warningCount
) {
}
