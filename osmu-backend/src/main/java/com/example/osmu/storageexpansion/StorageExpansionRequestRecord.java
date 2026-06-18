package com.example.osmu.storageexpansion;

import java.time.OffsetDateTime;

public record StorageExpansionRequestRecord(
        long id,
        long requestedCapacityBytes,
        int serverCount,
        int volumesPerServer,
        long volumeSizeBytes,
        long estimatedRawCapacityBytes,
        long estimatedUsableCapacityBytes,
        String status,
        String reason,
        String createdBy,
        String appliedBy,
        OffsetDateTime appliedAt,
        String appliedEvidence,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
