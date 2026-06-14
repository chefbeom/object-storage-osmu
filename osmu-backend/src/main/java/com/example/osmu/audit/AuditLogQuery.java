package com.example.osmu.audit;

import java.time.OffsetDateTime;

public record AuditLogQuery(
        String eventType,
        String actorId,
        String requestId,
        String targetType,
        String targetId,
        String result,
        Long cursor,
        OffsetDateTime from,
        OffsetDateTime to,
        int limit
) {
}
