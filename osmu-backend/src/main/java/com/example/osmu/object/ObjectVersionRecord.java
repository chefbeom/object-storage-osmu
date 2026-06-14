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
        Map<String, String> tags
) {
    public ObjectVersionRecord {
        tags = tags == null ? Map.of() : Map.copyOf(tags);
    }
}
