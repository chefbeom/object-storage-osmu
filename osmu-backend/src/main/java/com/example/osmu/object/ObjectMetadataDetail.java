package com.example.osmu.object;

import java.time.OffsetDateTime;
import java.util.Map;

public record ObjectMetadataDetail(
        String key,
        long sizeBytes,
        String contentType,
        OffsetDateTime lastModifiedAt,
        Map<String, String> tags,
        OffsetDateTime deletedAt,
        String etag,
        Map<String, String> checksums,
        String syncStatus,
        Long storageSizeBytes,
        String storageContentType,
        OffsetDateTime storageLastModifiedAt,
        Map<String, String> storageTags,
        String storageEtag,
        Map<String, String> storageChecksums
) {
    public ObjectMetadataDetail {
        tags = tags == null ? Map.of() : Map.copyOf(tags);
        checksums = checksums == null ? Map.of() : Map.copyOf(checksums);
        storageTags = storageTags == null ? Map.of() : Map.copyOf(storageTags);
        etag = etag == null ? "" : etag.trim();
        storageEtag = storageEtag == null ? "" : storageEtag.trim();
        storageChecksums = storageChecksums == null ? Map.of() : Map.copyOf(storageChecksums);
    }

    public static ObjectMetadataDetail of(StoredObjectRecord indexed, StoredObjectRecord actual, String syncStatus) {
        String actualEtag = actual == null ? "" : actual.etag();
        return new ObjectMetadataDetail(
                indexed.key(),
                indexed.sizeBytes(),
                indexed.contentType(),
                indexed.lastModifiedAt(),
                indexed.tags(),
                indexed.deletedAt(),
                indexed.etag().isBlank() ? actualEtag : indexed.etag(),
                indexed.checksums(),
                syncStatus,
                actual == null ? null : actual.sizeBytes(),
                actual == null ? null : actual.contentType(),
                actual == null ? null : actual.lastModifiedAt(),
                actual == null ? Map.of() : actual.tags(),
                actualEtag,
                actual == null ? Map.of() : actual.checksums()
        );
    }
}
