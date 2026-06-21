package com.example.osmu.monitoring;

import java.time.OffsetDateTime;
import java.util.List;

public record DataFlowMonthlyRollupMaterializationResponse(
        String mode,
        String rollupSource,
        String granularity,
        int monthWindow,
        int pointLimit,
        int pointCount,
        int storedPointCount,
        List<DataFlowMonthlyRollupPointResponse> points,
        OffsetDateTime generatedAt,
        String scopePolicy,
        String storagePolicy,
        String note
) {
}
