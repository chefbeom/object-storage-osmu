package com.example.osmu.bucket;

public record BucketUsageSummary(
        long bucketCount,
        long totalQuotaBytes,
        long totalUsedBytes,
        long totalObjectCount
) {
}
