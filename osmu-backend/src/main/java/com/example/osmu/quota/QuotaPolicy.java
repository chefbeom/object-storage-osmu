package com.example.osmu.quota;

import java.time.OffsetDateTime;

public record QuotaPolicy(
        long id,
        String targetType,
        long targetId,
        long quotaBytes,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
