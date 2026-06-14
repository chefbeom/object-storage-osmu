package com.example.osmu.organization;

public record OrganizationUsageResponse(
        long id,
        String name,
        long defaultQuotaBytes,
        long bucketQuotaBytes,
        long usedBytes,
        long remainingBytes,
        long bucketCount,
        long objectCount
) {
}
