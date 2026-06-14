package com.example.osmu.audit;

import java.time.OffsetDateTime;

public record AuditLogEntry(
        long id,
        String eventType,
        String actorId,
        String targetType,
        String targetId,
        String result,
        String message,
        String ipAddress,
        String userAgent,
        String requestId,
        OffsetDateTime createdAt
) {
}
