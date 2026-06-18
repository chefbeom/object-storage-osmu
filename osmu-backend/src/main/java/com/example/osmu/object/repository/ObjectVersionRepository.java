package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectVersionRecord;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public interface ObjectVersionRepository {

    List<ObjectVersionRecord> findByObjectKey(String bucketName, String objectKey);

    default List<VersionCandidate> findCreatedBefore(OffsetDateTime cutoff, int limit) {
        return findCreatedBefore(cutoff, limit, "", "", Map.of());
    }

    default List<VersionCandidate> findCreatedBefore(
            OffsetDateTime cutoff,
            int limit,
            String prefix,
            Map<String, String> tagFilter
    ) {
        return findCreatedBefore(cutoff, limit, "", prefix, tagFilter);
    }

    List<VersionCandidate> findCreatedBefore(
            OffsetDateTime cutoff,
            int limit,
            String bucketName,
            String prefix,
            Map<String, String> tagFilter
    );

    Optional<ObjectVersionRecord> findByVersionId(String bucketName, String objectKey, String versionId);

    boolean existsByBucketName(String bucketName);

    ObjectVersionRecord save(String bucketName, ObjectVersionRecord version);

    void delete(String bucketName, String objectKey, String versionId);

    void deleteByObjectKey(String bucketName, String objectKey);

    void deleteByBucketName(String bucketName);

    boolean isHealthy();

    record VersionCandidate(String bucketName, ObjectVersionRecord version) {
    }
}
