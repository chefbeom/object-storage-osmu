package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsHandoffPackageReadinessSnapshotResponse(
        boolean provided,
        boolean parsed,
        String result,
        boolean ready,
        String summary,
        int passedCount,
        int pendingCount,
        int checkCount
) {
}
