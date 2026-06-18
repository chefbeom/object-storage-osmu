package com.example.osmu.object;

import java.time.OffsetDateTime;
import java.util.Map;

public record ObjectVersionRecord(
        String versionId,
        String key,
        String storageKey,
        long sizeBytes,
        String contentType,
        OffsetDateTime objectLastModifiedAt,
        OffsetDateTime createdAt,
        Map<String, String> tags,
        Map<String, String> userMetadata
) {
    public ObjectVersionRecord {
        tags = tags == null ? Map.of() : Map.copyOf(tags);
        userMetadata = userMetadata == null ? Map.of() : Map.copyOf(userMetadata);
    }

    public ObjectVersionRecord(
            String versionId,
            String key,
            String storageKey,
            long sizeBytes,
            String contentType,
            OffsetDateTime objectLastModifiedAt,
            OffsetDateTime createdAt,
            Map<String, String> tags
    ) {
        this(versionId, key, storageKey, sizeBytes, contentType, objectLastModifiedAt, createdAt, tags, Map.of());
    }
}
