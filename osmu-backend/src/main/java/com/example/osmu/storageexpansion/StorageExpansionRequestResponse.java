package com.example.osmu.storageexpansion;

import java.time.OffsetDateTime;

public record StorageExpansionRequestResponse(
        long id,
        String poolName,
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
    public static StorageExpansionRequestResponse of(StorageExpansionRequestRecord record) {
        return new StorageExpansionRequestResponse(
                record.id(),
                "pool-" + record.id(),
                record.requestedCapacityBytes(),
                record.serverCount(),
                record.volumesPerServer(),
                record.volumeSizeBytes(),
                record.estimatedRawCapacityBytes(),
                record.estimatedUsableCapacityBytes(),
                record.status(),
                record.reason(),
                record.createdBy(),
                record.appliedBy(),
                record.appliedAt(),
                record.appliedEvidence(),
                record.createdAt(),
                record.updatedAt()
        );
    }
}
