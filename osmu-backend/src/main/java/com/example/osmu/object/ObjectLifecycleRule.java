package com.example.osmu.object;

import java.time.OffsetDateTime;
import java.util.Locale;
import java.util.Map;

public record ObjectLifecycleRule(
        String ruleId,
        String name,
        boolean enabled,
        int priority,
        String bucketName,
        String targetType,
        String prefix,
        Map<String, String> tags,
        int retentionDays,
        int batchSize,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
    public static final String TARGET_TRASH_OBJECT = "TRASH_OBJECT";
    public static final String TARGET_OBJECT_VERSION = "OBJECT_VERSION";
    public static final int DEFAULT_PRIORITY = 100;

    public ObjectLifecycleRule(
            String ruleId,
            String name,
            boolean enabled,
            String targetType,
            String prefix,
            Map<String, String> tags,
            int retentionDays,
            int batchSize,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
        this(
                ruleId,
                name,
                enabled,
                DEFAULT_PRIORITY,
                "",
                targetType,
                prefix,
                tags,
                retentionDays,
                batchSize,
                createdAt,
                updatedAt
        );
    }

    public ObjectLifecycleRule(
            String ruleId,
            String name,
            boolean enabled,
            int priority,
            String targetType,
            String prefix,
            Map<String, String> tags,
            int retentionDays,
            int batchSize,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
        this(
                ruleId,
                name,
                enabled,
                priority,
                "",
                targetType,
                prefix,
                tags,
                retentionDays,
                batchSize,
                createdAt,
                updatedAt
        );
    }

    public ObjectLifecycleRule {
        ruleId = ruleId == null ? "" : ruleId.trim();
        name = name == null ? "" : name.trim();
        priority = Math.max(1, priority);
        bucketName = bucketName == null ? "" : bucketName.trim().toLowerCase(Locale.ROOT);
        targetType = targetType == null ? "" : targetType.trim();
        prefix = prefix == null ? "" : prefix.trim();
        tags = tags == null ? Map.of() : Map.copyOf(tags);
        retentionDays = Math.max(1, retentionDays);
        batchSize = Math.max(1, batchSize);
        createdAt = createdAt == null ? OffsetDateTime.now() : createdAt;
        updatedAt = updatedAt == null ? createdAt : updatedAt;
    }

    public boolean matchesTarget(String expectedTargetType) {
        return enabled && targetType.equals(expectedTargetType);
    }
}
