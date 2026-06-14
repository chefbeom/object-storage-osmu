package com.example.osmu.admin;

public record ObjectRetentionStatusResponse(
        boolean enabled,
        int retentionDays,
        int batchSize,
        int versionRetentionDays,
        int versionBatchSize,
        double purgedObjectCount,
        double failedObjectCount,
        double failedRunCount,
        double purgedVersionCount,
        double failedVersionCount,
        double failedVersionRunCount
) {
}
