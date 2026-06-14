package com.example.osmu.object.repository;

import com.example.osmu.object.StoredObjectPage;
import com.example.osmu.object.StoredObjectRecord;
import com.example.osmu.object.DeletedObjectCandidate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public interface ObjectMetadataRepository {

    StoredObjectPage listObjects(
            String bucketName,
            String prefix,
            String delimiter,
            String search,
            Map<String, String> tagFilter,
            String cursor,
            int limit
    );

    StoredObjectPage listDeletedObjects(
            String bucketName,
            String prefix,
            String search,
            Map<String, String> tagFilter,
            String cursor,
            int limit
    );

    Optional<StoredObjectRecord> findByKey(String bucketName, String objectKey);

    default List<DeletedObjectCandidate> findDeletedBefore(OffsetDateTime cutoff, int limit) {
        return findDeletedBefore(cutoff, limit, "", "", Map.of());
    }

    default List<DeletedObjectCandidate> findDeletedBefore(
            OffsetDateTime cutoff,
            int limit,
            String prefix,
            Map<String, String> tagFilter
    ) {
        return findDeletedBefore(cutoff, limit, "", prefix, tagFilter);
    }

    List<DeletedObjectCandidate> findDeletedBefore(
            OffsetDateTime cutoff,
            int limit,
            String bucketName,
            String prefix,
            Map<String, String> tagFilter
    );

    StoredObjectRecord save(String bucketName, StoredObjectRecord object);

    void delete(String bucketName, String objectKey);

    void replaceBucketObjects(String bucketName, List<StoredObjectRecord> objects);

    void deleteByBucketName(String bucketName);

    boolean isHealthy();
}
