package com.example.osmu.quota;

import java.time.OffsetDateTime;

public record QuotaPolicyHistory(
        long id,
        String targetType,
        long targetId,
        String action,
        Long previousQuotaBytes,
        Long newQuotaBytes,
        String actorId,
        String reason,
        OffsetDateTime createdAt
) {
}
