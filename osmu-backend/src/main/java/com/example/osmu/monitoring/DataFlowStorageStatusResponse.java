package com.example.osmu.monitoring;

import java.time.OffsetDateTime;

public record DataFlowStorageStatusResponse(
        String mode,
        String metadataMode,
        boolean repositoryHealthy,
        long eventRowCount,
        long dailyRollupRowCount,
        long monthlyRollupRowCount,
        int summaryEventScanLimit,
        int dailyRollupWindowLimitDays,
        int monthlyRollupWindowLimitMonths,
        boolean aggregateStoreReady,
        boolean partitionedOrTimeSeriesStoreEnabled,
        String readiness,
        OffsetDateTime generatedAt,
        String note
) {
}
