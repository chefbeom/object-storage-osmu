package com.example.osmu.storageprofile;

import java.time.OffsetDateTime;

public record StorageProfileAssignmentRecord(
        String bucketName,
        String profileCode,
        String appliedBy,
        OffsetDateTime appliedAt,
        OffsetDateTime updatedAt
) {
}
