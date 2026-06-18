package com.example.osmu.monitoring;

import java.time.OffsetDateTime;
import java.util.List;

public record DataFlowMonitoringResponse(
        DataFlowTrafficSummaryResponse traffic,
        DataFlowOperationSummaryResponse operations,
        List<DataFlowBucketMetricResponse> topBuckets,
        List<DataFlowTrendPointResponse> trendPoints,
        List<DataFlowRecentEventResponse> recentEvents,
        OffsetDateTime generatedAt
) {
}
