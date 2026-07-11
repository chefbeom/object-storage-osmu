package com.example.osmu.storageprofile;

import java.time.OffsetDateTime;

public record StorageProfileAssignmentRecord(
        String bucketName,
        String profileCode,
        Long storageLayoutPlanId,
        String storagePoolName,
        String storageLayoutCode,
        String appliedBy,
        OffsetDateTime appliedAt,
        OffsetDateTime updatedAt
) {
    public StorageProfileAssignmentRecord(
            String bucketName,
            String profileCode,
            String appliedBy,
            OffsetDateTime appliedAt,
            OffsetDateTime updatedAt
    ) {
        this(bucketName, profileCode, null, null, null, appliedBy, appliedAt, updatedAt);
    }
}
