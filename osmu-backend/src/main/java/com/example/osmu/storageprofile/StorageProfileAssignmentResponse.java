package com.example.osmu.storageprofile;

import java.time.OffsetDateTime;

public record StorageProfileAssignmentResponse(
        String bucketName,
        StorageProfileResponse profile,
        String appliedBy,
        OffsetDateTime appliedAt,
        OffsetDateTime updatedAt,
        boolean defaultProfile
) {
    public static StorageProfileAssignmentResponse of(StorageProfileAssignmentRecord record) {
        StorageProfileCode code = StorageProfileCode.parse(record.profileCode());
        return new StorageProfileAssignmentResponse(
                record.bucketName(),
                StorageProfileCatalog.get(code),
                record.appliedBy(),
                record.appliedAt(),
                record.updatedAt(),
                false
        );
    }

    public static StorageProfileAssignmentResponse defaultFor(String bucketName) {
        return new StorageProfileAssignmentResponse(
                bucketName,
                StorageProfileCatalog.get(StorageProfileCode.STANDARD),
                "system",
                null,
                null,
                true
        );
    }
}
