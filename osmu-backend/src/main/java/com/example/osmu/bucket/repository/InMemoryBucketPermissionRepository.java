package com.example.osmu.bucket.repository;

import com.example.osmu.bucket.BucketPermissionRecord;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryBucketPermissionRepository implements BucketPermissionRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<Long, BucketPermissionRecord> permissions = new ConcurrentHashMap<>();

    @Override
    public List<BucketPermissionRecord> findByBucketId(long bucketId) {
        return permissions.values().stream()
                .filter(permission -> permission.bucketId() == bucketId)
                .sorted(Comparator.comparing(BucketPermissionRecord::id))
                .toList();
    }

    @Override
    public List<Long> findBucketIdsBySubjects(long userId, Long organizationId, List<Long> teamIds) {
        java.util.Set<Long> teamIdSet = teamIds == null
                ? java.util.Set.of()
                : new java.util.HashSet<>(teamIds);
        return permissions.values().stream()
                .filter(permission -> ("USER".equals(permission.subjectType()) && permission.subjectId() == userId)
                        || ("ORGANIZATION".equals(permission.subjectType())
                        && organizationId != null
                        && permission.subjectId() == organizationId)
                        || ("TEAM".equals(permission.subjectType()) && teamIdSet.contains(permission.subjectId())))
                .map(BucketPermissionRecord::bucketId)
                .distinct()
                .sorted()
                .toList();
    }

    @Override
    public Optional<BucketPermissionRecord> findById(long id) {
        return Optional.ofNullable(permissions.get(id));
    }

    @Override
    public boolean exists(long bucketId, String subjectType, long subjectId, String permission) {
        return permissions.values().stream()
                .anyMatch(record -> record.bucketId() == bucketId
                        && record.subjectType().equals(subjectType)
                        && record.subjectId() == subjectId
                        && record.permission().equals(permission));
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public BucketPermissionRecord save(BucketPermissionRecord permission) {
        permissions.put(permission.id(), permission);
        return permission;
    }

    @Override
    public void deleteById(long id) {
        permissions.remove(id);
    }

    @Override
    public void deleteByBucketId(long bucketId) {
        permissions.values().removeIf(permission -> permission.bucketId() == bucketId);
    }

    @Override
    public int deleteBySubject(String subjectType, long subjectId) {
        int before = permissions.size();
        permissions.values().removeIf(permission -> permission.subjectType().equals(subjectType)
                && permission.subjectId() == subjectId);
        return before - permissions.size();
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
