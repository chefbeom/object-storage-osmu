package com.example.osmu.storagelayout.repository;

import com.example.osmu.storagelayout.StorageLayoutPlanRecord;
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
public class InMemoryStorageLayoutPlanRepository implements StorageLayoutPlanRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<Long, StorageLayoutPlanRecord> plans = new ConcurrentHashMap<>();

    @Override
    public List<StorageLayoutPlanRecord> findPage(List<String> statuses, Long cursorId, int limit) {
        Set<String> statusFilter = new HashSet<>(statuses == null ? List.of() : statuses);
        statusFilter.remove(null);
        return plans.values().stream()
                .filter(plan -> statusFilter.isEmpty() || statusFilter.contains(plan.status()))
                .filter(plan -> cursorId == null || plan.id() < cursorId)
                .sorted(Comparator.comparingLong(StorageLayoutPlanRecord::id).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public Optional<StorageLayoutPlanRecord> findById(long id) {
        return Optional.ofNullable(plans.get(id));
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public StorageLayoutPlanRecord save(StorageLayoutPlanRecord plan) {
        plans.put(plan.id(), plan);
        idSequence.accumulateAndGet(plan.id() + 1, Math::max);
        return plan;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
