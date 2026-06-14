package com.example.osmu.object;

import java.time.OffsetDateTime;

public record ObjectRetentionPolicy(
        boolean enabled,
        int retentionDays,
        int batchSize,
        int versionRetentionDays,
        int versionBatchSize,
        OffsetDateTime updatedAt
) {
    public ObjectRetentionPolicy {
        retentionDays = Math.max(1, retentionDays);
        batchSize = Math.max(1, batchSize);
        versionRetentionDays = Math.max(1, versionRetentionDays);
        versionBatchSize = Math.max(1, versionBatchSize);
        updatedAt = updatedAt == null ? OffsetDateTime.now() : updatedAt;
    }

    public ObjectRetentionPolicy(boolean enabled, int retentionDays, int batchSize, OffsetDateTime updatedAt) {
        this(enabled, retentionDays, batchSize, 90, batchSize, updatedAt);
    }

    public static ObjectRetentionPolicy initial(boolean enabled, int retentionDays, int batchSize) {
        return initial(enabled, retentionDays, batchSize, 90, batchSize);
    }

    public static ObjectRetentionPolicy initial(
            boolean enabled,
            int retentionDays,
            int batchSize,
            int versionRetentionDays,
            int versionBatchSize
    ) {
        return new ObjectRetentionPolicy(
                enabled,
                retentionDays,
                batchSize,
                versionRetentionDays,
                versionBatchSize,
                OffsetDateTime.now()
        );
    }
}
