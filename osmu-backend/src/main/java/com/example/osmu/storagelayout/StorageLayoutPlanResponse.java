package com.example.osmu.storagelayout;

import java.time.OffsetDateTime;

public record StorageLayoutPlanResponse(
        long id,
        StorageLayoutDefinition layout,
        String poolName,
        String storageClassName,
        int serverCount,
        int volumesPerServer,
        int pvcCount,
        long volumeSizeGiB,
        long estimatedRawCapacityBytes,
        long estimatedUsableCapacityBytes,
        String status,
        boolean simulationOnly,
        StorageLayoutPreflightResponse preflight,
        String reason,
        String createdBy,
        String approvedBy,
        OffsetDateTime approvedAt,
        String simulatedBy,
        OffsetDateTime simulatedAt,
        String adminNote,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
