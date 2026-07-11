package com.example.osmu.storageexpansion.repository;

import com.example.osmu.storageexpansion.StorageExpansionRequestAggregate;
import com.example.osmu.storageexpansion.StorageExpansionRequestRecord;
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
public class InMemoryStorageExpansionRequestRepository implements StorageExpansionRequestRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<Long, StorageExpansionRequestRecord> requests = new ConcurrentHashMap<>();

    @Override
    public List<StorageExpansionRequestRecord> findPage(List<String> statuses, Long cursorId, int limit) {
        java.util.Set<String> statusFilter = new java.util.HashSet<>(statuses == null ? List.of() : statuses);
        statusFilter.remove(null);
        return requests.values().stream()
                .filter(request -> statusFilter.isEmpty() || statusFilter.contains(request.status()))
                .filter(request -> cursorId == null || request.id() < cursorId)
                .sorted(Comparator.comparingLong(StorageExpansionRequestRecord::id).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public StorageExpansionRequestAggregate aggregate() {
        List<StorageExpansionRequestRecord> records = requests.values().stream().toList();
        long plannedRequestCount = countByStatus(records, "PLANNED");
        long approvedRequestCount = countByStatus(records, "APPROVED");
        long appliedRequestCount = countByStatus(records, "APPLIED");
        long rejectedRequestCount = countByStatus(records, "REJECTED");
        return new StorageExpansionRequestAggregate(
                records.size(),
                plannedRequestCount + approvedRequestCount,
                plannedRequestCount,
                approvedRequestCount,
                appliedRequestCount,
                rejectedRequestCount,
                records.stream().mapToLong(StorageExpansionRequestRecord::requestedCapacityBytes).sum(),
                records.stream().filter(this::isOpen).mapToLong(StorageExpansionRequestRecord::requestedCapacityBytes).sum(),
                records.stream().mapToLong(StorageExpansionRequestRecord::estimatedUsableCapacityBytes).sum(),
                records.stream().filter(this::isOpen).mapToLong(StorageExpansionRequestRecord::estimatedUsableCapacityBytes).sum()
        );
    }

    @Override
    public Optional<StorageExpansionRequestRecord> findLatest() {
        return requests.values().stream()
                .max(Comparator.comparingLong(StorageExpansionRequestRecord::id));
    }

    @Override
    public Optional<StorageExpansionRequestRecord> findById(long id) {
        return Optional.ofNullable(requests.get(id));
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public StorageExpansionRequestRecord save(StorageExpansionRequestRecord request) {
        requests.put(request.id(), request);
        return request;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private long countByStatus(List<StorageExpansionRequestRecord> records, String status) {
        return records.stream()
                .filter(record -> status.equals(record.status()))
                .count();
    }

    private boolean isOpen(StorageExpansionRequestRecord record) {
        return "PLANNED".equals(record.status()) || "APPROVED".equals(record.status());
    }
}
