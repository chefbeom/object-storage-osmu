package com.example.osmu.storagelayout;

import java.time.OffsetDateTime;

public record StorageLayoutPlanRecord(
        long id,
        String layoutCode,
        String storageClassName,
        int serverCount,
        int volumesPerServer,
        long volumeSizeGiB,
        String status,
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
