package com.example.osmu.storageprofile;

import java.time.OffsetDateTime;

public record StorageProfileAssignmentResponse(
        String bucketName,
        StorageProfileResponse profile,
        Long storageLayoutPlanId,
        String storagePoolName,
        String storageLayoutCode,
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
                record.storageLayoutPlanId(),
                record.storagePoolName(),
                record.storageLayoutCode(),
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
                null,
                null,
                null,
                "system",
                null,
                null,
                true
        );
    }
}
