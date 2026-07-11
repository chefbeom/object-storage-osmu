package com.example.osmu.bucket.repository;

import com.example.osmu.bucket.BucketOwnerUsageSummary;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.BucketUsageSummary;
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
public class InMemoryBucketRepository implements BucketRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<String, BucketRecord> buckets = new ConcurrentHashMap<>();

    @Override
    public List<BucketRecord> findAll() {
        return buckets.values().stream()
                .sorted(Comparator.comparing(BucketRecord::name))
                .toList();
    }

    @Override
    public List<BucketRecord> findAccessible(long userId, Long organizationId, List<Long> explicitBucketIds) {
        java.util.Set<Long> explicitIds = explicitBucketIds == null
                ? java.util.Set.of()
                : new java.util.HashSet<>(explicitBucketIds);
        return buckets.values().stream()
                .filter(bucket -> ("USER".equals(bucket.ownerType()) && bucket.ownerId() == userId)
                        || ("ORG".equals(bucket.ownerType())
                        && organizationId != null
                        && bucket.ownerId() == organizationId)
                        || explicitIds.contains(bucket.id()))
                .sorted(Comparator.comparing(BucketRecord::name))
                .toList();
    }

    @Override
    public List<BucketRecord> findByIds(List<Long> bucketIds) {
        java.util.Set<Long> ids = bucketIds == null
                ? java.util.Set.of()
                : new java.util.HashSet<>(bucketIds);
        if (ids.isEmpty()) {
            return List.of();
        }
        return buckets.values().stream()
                .filter(bucket -> ids.contains(bucket.id()))
                .sorted(Comparator.comparingLong(BucketRecord::id))
                .toList();
    }

    @Override
    public List<BucketRecord> findByOwners(String ownerType, List<Long> ownerIds) {
        java.util.Set<Long> ids = ownerIds == null
                ? java.util.Set.of()
                : new java.util.HashSet<>(ownerIds);
        ids.remove(null);
        if (ids.isEmpty()) {
            return List.of();
        }
        return buckets.values().stream()
                .filter(bucket -> ownerType.equals(bucket.ownerType()) && ids.contains(bucket.ownerId()))
                .sorted(Comparator.comparingLong(BucketRecord::id))
                .toList();
    }

    @Override
    public BucketUsageSummary summarizeUsage() {
        long bucketCount = 0L;
        long totalQuotaBytes = 0L;
        long totalUsedBytes = 0L;
        long totalObjectCount = 0L;
        for (BucketRecord bucket : buckets.values()) {
            bucketCount += 1L;
            totalQuotaBytes += bucket.quotaBytes();
            totalUsedBytes += bucket.usedBytes();
            totalObjectCount += bucket.objectCount();
        }
        return new BucketUsageSummary(bucketCount, totalQuotaBytes, totalUsedBytes, totalObjectCount);
    }

    @Override
    public long sumUsedBytesByOwner(String ownerType, long ownerId) {
        return buckets.values().stream()
                .filter(bucket -> ownerType.equals(bucket.ownerType()) && ownerId == bucket.ownerId())
                .mapToLong(BucketRecord::usedBytes)
                .sum();
    }

    @Override
    public List<BucketOwnerUsageSummary> summarizeUsageByOwners(String ownerType, List<Long> ownerIds) {
        java.util.Set<Long> ids = ownerIds == null
                ? java.util.Set.of()
                : new java.util.HashSet<>(ownerIds);
        if (ids.isEmpty()) {
            return List.of();
        }
        java.util.Map<Long, long[]> totalsByOwner = new java.util.TreeMap<>();
        for (BucketRecord bucket : buckets.values()) {
            if (!ownerType.equals(bucket.ownerType()) || !ids.contains(bucket.ownerId())) {
                continue;
            }
            long[] totals = totalsByOwner.computeIfAbsent(bucket.ownerId(), ignored -> new long[4]);
            totals[0] += 1L;
            totals[1] += bucket.quotaBytes();
            totals[2] += bucket.usedBytes();
            totals[3] += bucket.objectCount();
        }
        return totalsByOwner.entrySet().stream()
                .map(entry -> new BucketOwnerUsageSummary(
                        entry.getKey(),
                        entry.getValue()[0],
                        entry.getValue()[1],
                        entry.getValue()[2],
                        entry.getValue()[3]
                ))
                .toList();
    }

    @Override
    public boolean existsByOwner(String ownerType, long ownerId) {
        return buckets.values().stream()
                .anyMatch(bucket -> ownerType.equals(bucket.ownerType()) && ownerId == bucket.ownerId());
    }

    @Override
    public Optional<BucketRecord> findById(long bucketId) {
        return buckets.values().stream()
                .filter(bucket -> bucket.id() == bucketId)
                .findFirst();
    }

    @Override
    public Optional<BucketRecord> findByName(String bucketName) {
        return Optional.ofNullable(buckets.get(bucketName));
    }

    @Override
    public boolean existsByName(String bucketName) {
        return buckets.containsKey(bucketName);
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public BucketRecord save(BucketRecord bucket) {
        buckets.put(bucket.name(), bucket);
        return bucket;
    }

    @Override
    public void deleteByName(String bucketName) {
        buckets.remove(bucketName);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
