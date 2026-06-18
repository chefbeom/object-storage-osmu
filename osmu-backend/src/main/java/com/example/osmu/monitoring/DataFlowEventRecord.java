package com.example.osmu.monitoring;

import java.time.OffsetDateTime;

public record DataFlowEventRecord(
        Long id,
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

    public DataFlowEventRecord withId(long nextId) {
        return new DataFlowEventRecord(
                nextId,
                eventType,
                operation,
                direction,
                bucketName,
                objectKey,
                actorId,
                status,
                sizeBytes,
                message,
                source,
                createdAt
        );
    }

    public DataFlowEventRecord withCreatedAt(OffsetDateTime timestamp) {
        return new DataFlowEventRecord(
                id,
                eventType,
                operation,
                direction,
                bucketName,
                objectKey,
                actorId,
                status,
                sizeBytes,
                message,
                source,
                timestamp
        );
    }

    public DataFlowRecentEventResponse toRecentEvent() {
        return new DataFlowRecentEventResponse(
                eventType,
                operation,
                direction,
                bucketName,
                objectKey,
                actorId,
                status,
                sizeBytes,
                message,
                source,
                createdAt
        );
    }
}
