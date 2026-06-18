package com.example.osmu.monitoring;

import java.time.OffsetDateTime;

public record DataFlowRecentEventResponse(
        String eventType,
        String operation,
        String direction,
        String bucketName,
        String objectKey,
        String actorId,
        String status,
        long sizeBytes,
        String message,
        String source,
        OffsetDateTime createdAt
) {
}
