package com.example.osmu.bucket.repository;

import com.example.osmu.bucket.BucketRecord;
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
