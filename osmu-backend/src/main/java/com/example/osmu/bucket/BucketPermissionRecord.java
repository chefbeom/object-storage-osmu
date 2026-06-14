package com.example.osmu.bucket;

import java.time.OffsetDateTime;

public record BucketPermissionRecord(
        long id,
        long bucketId,
        String subjectType,
        long subjectId,
        String permission,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
