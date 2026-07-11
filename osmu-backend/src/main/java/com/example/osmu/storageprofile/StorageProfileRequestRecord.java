package com.example.osmu.storageprofile;

import java.time.OffsetDateTime;

public record StorageProfileRequestRecord(
        long id,
        String bucketName,
        String currentProfileCode,
        String requestedProfileCode,
        String status,
        String reason,
        String requestedBy,
        String approvedBy,
        OffsetDateTime approvedAt,
        String appliedBy,
        OffsetDateTime appliedAt,
        Long storageLayoutPlanId,
        String storagePoolName,
        String storageLayoutCode,
        String adminNote,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
    public StorageProfileRequestRecord(
            long id,
            String bucketName,
            String currentProfileCode,
            String requestedProfileCode,
            String status,
            String reason,
            String requestedBy,
            String approvedBy,
            OffsetDateTime approvedAt,
            String appliedBy,
            OffsetDateTime appliedAt,
            String adminNote,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
        this(id, bucketName, currentProfileCode, requestedProfileCode, status, reason, requestedBy,
                approvedBy, approvedAt, appliedBy, appliedAt, null, null, null, adminNote, createdAt, updatedAt);
    }
}
