package com.example.osmu.bucket;

import java.time.OffsetDateTime;

public record BucketRecord(
        long id,
        String name,
        String ownerType,
        long ownerId,
        long quotaBytes,
        long usedBytes,
        long objectCount,
        OffsetDateTime createdAt
) {
}
