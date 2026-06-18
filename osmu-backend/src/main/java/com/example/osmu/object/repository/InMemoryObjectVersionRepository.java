package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectVersionRecord;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryObjectVersionRepository implements ObjectVersionRepository {

    private final ConcurrentMap<String, ConcurrentMap<String, ConcurrentMap<String, ObjectVersionRecord>>> versionsByBucket =
            new ConcurrentHashMap<>();

    @Override
    public List<ObjectVersionRecord> findByObjectKey(String bucketName, String objectKey) {
        return objectVersions(bucketName, objectKey)
                .values()
                .stream()
                .sorted(Comparator.comparing(ObjectVersionRecord::createdAt).reversed())
                .toList();
    }

    @Override
    public List<VersionCandidate> findCreatedBefore(OffsetDateTime cutoff, int limit) {
        return findCreatedBefore(cutoff, limit, "", "", Map.of());
    }

    @Override
    public List<VersionCandidate> findCreatedBefore(
            OffsetDateTime cutoff,
            int limit,
            String prefix,
            Map<String, String> tagFilter
    ) {
        return findCreatedBefore(cutoff, limit, "", prefix, tagFilter);
    }

    @Override
    public List<VersionCandidate> findCreatedBefore(
            OffsetDateTime cutoff,
            int limit,
            String bucketName,
            String prefix,
            Map<String, String> tagFilter
    ) {
        String normalizedBucketName = bucketName == null ? "" : bucketName.trim();
        String normalizedPrefix = prefix == null ? "" : prefix;
        Map<String, String> normalizedTagFilter = tagFilter == null ? Map.of() : tagFilter;
        return versionsByBucket.entrySet().stream()
                .filter(bucketEntry -> normalizedBucketName.isBlank() || bucketEntry.getKey().equals(normalizedBucketName))
                .flatMap(bucketEntry -> bucketEntry.getValue().values().stream()
                        .flatMap(objectVersions -> objectVersions.values().stream()
                                .map(version -> new VersionCandidate(bucketEntry.getKey(), version))))
                .filter(candidate -> candidate.version().createdAt().isBefore(cutoff)
                        || candidate.version().createdAt().isEqual(cutoff))
                .filter(candidate -> candidate.version().key().startsWith(normalizedPrefix))
                .filter(candidate -> matchesTags(candidate.version(), normalizedTagFilter))
                .sorted(Comparator.comparing(candidate -> candidate.version().createdAt()))
                .limit(Math.max(0, limit))
                .toList();
    }

    @Override
    public Optional<ObjectVersionRecord> findByVersionId(String bucketName, String objectKey, String versionId) {
        return Optional.ofNullable(objectVersions(bucketName, objectKey).get(versionId));
    }

    @Override
    public boolean existsByBucketName(String bucketName) {
        ConcurrentMap<String, ConcurrentMap<String, ObjectVersionRecord>> bucketVersions = versionsByBucket.get(bucketName);
        return bucketVersions != null && bucketVersions.values().stream().anyMatch(versions -> !versions.isEmpty());
    }

    @Override
    public ObjectVersionRecord save(String bucketName, ObjectVersionRecord version) {
        objectVersions(bucketName, version.key()).put(version.versionId(), version);
        return version;
    }

    @Override
    public void delete(String bucketName, String objectKey, String versionId) {
        objectVersions(bucketName, objectKey).remove(versionId);
    }

    @Override
    public void deleteByObjectKey(String bucketName, String objectKey) {
        bucketVersions(bucketName).remove(objectKey);
    }

    @Override
    public void deleteByBucketName(String bucketName) {
        versionsByBucket.remove(bucketName);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private ConcurrentMap<String, ConcurrentMap<String, ObjectVersionRecord>> bucketVersions(String bucketName) {
        return versionsByBucket.computeIfAbsent(bucketName, ignored -> new ConcurrentHashMap<>());
    }

    private ConcurrentMap<String, ObjectVersionRecord> objectVersions(String bucketName, String objectKey) {
        return bucketVersions(bucketName).computeIfAbsent(objectKey, ignored -> new ConcurrentHashMap<>());
    }

    private boolean matchesTags(ObjectVersionRecord version, Map<String, String> tagFilter) {
        if (tagFilter.isEmpty()) {
            return true;
        }
        return tagFilter.entrySet().stream()
                .allMatch(entry -> entry.getValue().equals(version.tags().get(entry.getKey())));
    }
}
