package com.example.osmu.bucket;

public record BucketOwnerUsageSummary(
        long ownerId,
        long bucketCount,
        long totalQuotaBytes,
        long totalUsedBytes,
        long totalObjectCount
) {

    public static BucketOwnerUsageSummary empty(long ownerId) {
        return new BucketOwnerUsageSummary(ownerId, 0L, 0L, 0L, 0L);
    }
}