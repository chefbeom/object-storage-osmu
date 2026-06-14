package com.example.osmu.admin;

public record UsageResponse(
        long totalQuotaBytes,
        long usedBytes,
        long remainingBytes,
        long bucketCount,
        long objectCount
) {
}
