package com.example.osmu.monitoring;

import java.time.OffsetDateTime;
import java.util.List;

public record DataFlowDailyRollupResponse(
        String mode,
        String granularity,
        int dayWindow,
        int pointLimit,
        int pointCount,
        List<DataFlowDailyRollupPointResponse> points,
        OffsetDateTime generatedAt,
        String scopePolicy,
        String storagePolicy,
        String note
) {
}
