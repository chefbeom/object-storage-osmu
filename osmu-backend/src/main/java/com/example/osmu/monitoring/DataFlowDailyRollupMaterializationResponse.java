package com.example.osmu.monitoring;

import java.time.OffsetDateTime;
import java.util.List;

public record DataFlowDailyRollupMaterializationResponse(
        String mode,
        String granularity,
        int dayWindow,
        int pointLimit,
        int pointCount,
        int storedPointCount,
        List<DataFlowDailyRollupPointResponse> points,
        OffsetDateTime generatedAt,
        String scopePolicy,
        String storagePolicy,
        String note
) {
}
