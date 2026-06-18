package com.example.osmu.monitoring;

import java.time.OffsetDateTime;

public record DataFlowBucketMetricResponse(
        String bucketName,
        long uploadedBytes,
        long downloadedBytes,
        long totalBytes,
        long uploadCount,
        long downloadCount,
        long listCount,
        long deleteCount,
        long cancelCount,
        long failureCount,
        OffsetDateTime lastEventAt
) {
}
