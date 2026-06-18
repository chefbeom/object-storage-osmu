package com.example.osmu.storageprofile;

import java.time.OffsetDateTime;

public record StorageProfileRequestResponse(
        long id,
        String bucketName,
        StorageProfileResponse currentProfile,
        StorageProfileResponse requestedProfile,
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
    public static StorageProfileRequestResponse of(StorageProfileRequestRecord record) {
        return new StorageProfileRequestResponse(
                record.id(),
                record.bucketName(),
                StorageProfileCatalog.get(StorageProfileCode.parse(record.currentProfileCode())),
                StorageProfileCatalog.get(StorageProfileCode.parse(record.requestedProfileCode())),
                record.status(),
                record.reason(),
                record.requestedBy(),
                record.approvedBy(),
                record.approvedAt(),
                record.appliedBy(),
                record.appliedAt(),
                record.adminNote(),
                record.createdAt(),
                record.updatedAt()
        );
    }
}
