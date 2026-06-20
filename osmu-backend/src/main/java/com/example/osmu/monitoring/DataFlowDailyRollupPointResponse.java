package com.example.osmu.monitoring;

import java.time.LocalDate;

public record DataFlowDailyRollupPointResponse(
        LocalDate day,
        String bucketName,
        String source,
        String operation,
        long successCount,
        long failureCount,
        long cancelCount,
        long totalCount,
        long uploadedBytes,
        long downloadedBytes,
        long copiedBytes,
        long totalBytes
) {
}
