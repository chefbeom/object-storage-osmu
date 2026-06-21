package com.example.osmu.monitoring;

public record DataFlowMonthlyRollupPointResponse(
        String month,
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
