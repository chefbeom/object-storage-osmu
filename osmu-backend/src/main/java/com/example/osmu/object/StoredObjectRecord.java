package com.example.osmu.object;

import java.time.OffsetDateTime;
import java.util.Map;

public record StoredObjectRecord(
        String key,
        long sizeBytes,
        String contentType,
        OffsetDateTime lastModifiedAt,
        Map<String, String> tags,
        OffsetDateTime deletedAt,
        String etag,
        Map<String, String> checksums
) {
    public StoredObjectRecord {
        tags = tags == null ? Map.of() : Map.copyOf(tags);
        etag = etag == null ? "" : etag.trim();
        checksums = checksums == null ? Map.of() : Map.copyOf(checksums);
    }

    public StoredObjectRecord(
            String key,
            long sizeBytes,
            String contentType,
            OffsetDateTime lastModifiedAt,
            Map<String, String> tags,
            OffsetDateTime deletedAt,
            String etag
    ) {
        this(key, sizeBytes, contentType, lastModifiedAt, tags, deletedAt, etag, Map.of());
    }

    public StoredObjectRecord(
            String key,
            long sizeBytes,
            String contentType,
            OffsetDateTime lastModifiedAt,
            Map<String, String> tags,
            OffsetDateTime deletedAt
    ) {
        this(key, sizeBytes, contentType, lastModifiedAt, tags, deletedAt, "");
    }

    public StoredObjectRecord(
            String key,
            long sizeBytes,
            String contentType,
            OffsetDateTime lastModifiedAt,
            Map<String, String> tags
    ) {
        this(key, sizeBytes, contentType, lastModifiedAt, tags, null);
    }

    public StoredObjectRecord(String key, long sizeBytes, String contentType, OffsetDateTime lastModifiedAt) {
        this(key, sizeBytes, contentType, lastModifiedAt, Map.of(), null);
    }

    public boolean isDeleted() {
        return deletedAt != null;
    }

    public StoredObjectRecord withDeletedAt(OffsetDateTime nextDeletedAt) {
        return new StoredObjectRecord(key, sizeBytes, contentType, lastModifiedAt, tags, nextDeletedAt, etag, checksums);
    }

    public StoredObjectRecord withChecksums(Map<String, String> nextChecksums) {
        return new StoredObjectRecord(key, sizeBytes, contentType, lastModifiedAt, tags, deletedAt, etag, nextChecksums);
    }
}
