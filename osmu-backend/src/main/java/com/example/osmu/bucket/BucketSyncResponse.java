package com.example.osmu.bucket;

import java.time.OffsetDateTime;

public record BucketSyncResponse(
        long id,
        String name,
        String ownerType,
        long ownerId,
        long quotaBytes,
        long usedBytes,
        long objectCount,
        OffsetDateTime createdAt,
        long previousUsedBytes,
        long previousObjectCount,
        long storageObjectCount,
        long visibleStorageObjectCount,
        long internalStorageObjectCount,
        long stagingStorageObjectCount,
        long metadataObjectCountBefore,
        long metadataObjectCountAfter,
        long metadataAddedCount,
        long metadataUpdatedCount,
        long metadataRemovedCount,
        long deletedObjectMetadataRetainedCount
) {
    public static BucketSyncResponse of(
            BucketRecord current,
            BucketRecord synced,
            long storageObjectCount,
            long visibleStorageObjectCount,
            long internalStorageObjectCount,
            long stagingStorageObjectCount,
            long metadataObjectCountBefore,
            long metadataObjectCountAfter,
            long metadataAddedCount,
            long metadataUpdatedCount,
            long metadataRemovedCount,
            long deletedObjectMetadataRetainedCount
    ) {
        return new BucketSyncResponse(
                synced.id(),
                synced.name(),
                synced.ownerType(),
                synced.ownerId(),
                synced.quotaBytes(),
                synced.usedBytes(),
                synced.objectCount(),
                synced.createdAt(),
                current.usedBytes(),
                current.objectCount(),
                storageObjectCount,
                visibleStorageObjectCount,
                internalStorageObjectCount,
                stagingStorageObjectCount,
                metadataObjectCountBefore,
                metadataObjectCountAfter,
                metadataAddedCount,
                metadataUpdatedCount,
                metadataRemovedCount,
                deletedObjectMetadataRetainedCount
        );
    }
}
