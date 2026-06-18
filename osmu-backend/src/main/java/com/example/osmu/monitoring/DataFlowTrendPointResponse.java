package com.example.osmu.monitoring;

import java.time.OffsetDateTime;

public record DataFlowTrendPointResponse(
        OffsetDateTime bucketStartAt,
        String source,
        String operation,
        long successCount,
        long failureCount,
        long cancelCount,
        long totalCount,
        long bytes
) {
}
