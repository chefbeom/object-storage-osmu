package com.example.osmu.storageprofile.repository;

import com.example.osmu.storageprofile.StorageProfileRequestRecord;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
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
    public List<StorageProfileRequestRecord> findPage(List<String> statuses, Long cursorId, int limit) {
        Set<String> statusFilter = new HashSet<>(statuses == null ? List.of() : statuses);
        statusFilter.remove(null);
        return requests.values().stream()
                .filter(request -> statusFilter.isEmpty() || statusFilter.contains(request.status()))
                .filter(request -> cursorId == null || request.id() < cursorId)
                .sorted(Comparator.comparingLong(StorageProfileRequestRecord::id).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public List<StorageProfileRequestRecord> findPageByBucketName(String bucketName, Long cursorId, int limit) {
        return requests.values().stream()
                .filter(request -> request.bucketName().equals(bucketName))
                .filter(request -> cursorId == null || request.id() < cursorId)
                .sorted(Comparator.comparingLong(StorageProfileRequestRecord::id).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public List<StorageProfileRequestRecord> findPageByBucketNames(
            List<String> bucketNames,
            Long cursorId,
            int limit
    ) {
        Set<String> requestedBucketNames = new HashSet<>(bucketNames == null ? List.of() : bucketNames);
        requestedBucketNames.remove(null);
        return requests.values().stream()
                .filter(request -> requestedBucketNames.contains(request.bucketName()))
                .filter(request -> cursorId == null || request.id() < cursorId)
                .sorted(Comparator.comparingLong(StorageProfileRequestRecord::id).reversed())
                .limit(limit)
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
