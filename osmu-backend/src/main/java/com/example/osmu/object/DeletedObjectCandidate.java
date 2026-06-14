package com.example.osmu.object;

import java.time.OffsetDateTime;

public record DeletedObjectCandidate(
        String bucketName,
        String key,
        long sizeBytes,
        OffsetDateTime deletedAt
) {
}
