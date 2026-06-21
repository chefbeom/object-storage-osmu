package com.example.osmu.admin;

import java.time.OffsetDateTime;
import java.util.List;

public record StorageBackendStatusResponse(
        String mode,
        String metadataMode,
        boolean storageHealthy,
        boolean accessKeyProvisionerHealthy,
        long bucketCount,
        long objectCount,
        long usedBytes,
        long quotaBytes,
        long remainingBytes,
        String capacitySource,
        boolean directStorageMetricsEnabled,
        boolean minioAdminMetricsEnabled,
        String readiness,
        List<String> pendingGates,
        OffsetDateTime generatedAt,
        String note
) {
}
