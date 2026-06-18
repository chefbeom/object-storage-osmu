package com.example.osmu.storageprofile.repository;

import com.example.osmu.storageprofile.StorageProfileRequestRecord;
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
public class InMemoryStorageProfileRequestRepository implements StorageProfileRequestRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<Long, StorageProfileRequestRecord> requests = new ConcurrentHashMap<>();

    @Override
    public List<StorageProfileRequestRecord> findAll() {
        return requests.values().stream()
                .sorted(Comparator.comparingLong(StorageProfileRequestRecord::id).reversed())
                .toList();
    }

    @Override
    public List<StorageProfileRequestRecord> findByBucketName(String bucketName) {
        return requests.values().stream()
                .filter(request -> request.bucketName().equals(bucketName))
                .sorted(Comparator.comparingLong(StorageProfileRequestRecord::id).reversed())
                .toList();
    }

    @Override
    public Optional<StorageProfileRequestRecord> findLatestByBucketName(String bucketName) {
        return requests.values().stream()
                .filter(request -> request.bucketName().equals(bucketName))
                .max(Comparator.comparingLong(StorageProfileRequestRecord::id));
    }

    @Override
    public Optional<StorageProfileRequestRecord> findById(long id) {
        return Optional.ofNullable(requests.get(id));
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public StorageProfileRequestRecord save(StorageProfileRequestRecord request) {
        requests.put(request.id(), request);
        return request;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
