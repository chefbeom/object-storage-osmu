package com.example.osmu.quota.repository;

import com.example.osmu.quota.QuotaPolicy;
import com.example.osmu.quota.QuotaPolicyHistory;
import com.example.osmu.quota.QuotaPolicyPageCursor;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryQuotaPolicyRepository implements QuotaPolicyRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final AtomicLong historyIdSequence = new AtomicLong(1);
    private final ConcurrentMap<String, QuotaPolicy> policies = new ConcurrentHashMap<>();
    private final CopyOnWriteArrayList<QuotaPolicyHistory> history = new CopyOnWriteArrayList<>();

    @Override
    public List<QuotaPolicy> findPage(QuotaPolicyPageCursor cursor, int limit) {
        return orderedPolicies().stream()
                .filter(policy -> cursor == null || isAfter(policy, cursor))
                .limit(limit)
                .toList();
    }

    @Override
    public List<QuotaPolicy> findAllForDashboardSummary() {
        return orderedPolicies();
    }

    private List<QuotaPolicy> orderedPolicies() {
        return policies.values().stream()
                .sorted(Comparator.comparing(QuotaPolicy::targetType).thenComparingLong(QuotaPolicy::targetId))
                .toList();
    }

    private boolean isAfter(QuotaPolicy policy, QuotaPolicyPageCursor cursor) {
        int targetTypeComparison = policy.targetType().compareTo(cursor.targetType());
        return targetTypeComparison > 0
                || (targetTypeComparison == 0 && policy.targetId() > cursor.targetId());
    }

    @Override
    public Optional<QuotaPolicy> findByTarget(String targetType, long targetId) {
        return Optional.ofNullable(policies.get(key(targetType, targetId)));
    }

    @Override
    public List<QuotaPolicyHistory> findHistory(int limit) {
        return history.stream()
                .sorted(Comparator.comparing(QuotaPolicyHistory::id).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public long nextHistoryId() {
        return historyIdSequence.getAndIncrement();
    }

    @Override
    public QuotaPolicy save(QuotaPolicy policy) {
        policies.put(key(policy.targetType(), policy.targetId()), policy);
        return policy;
    }

    @Override
    public QuotaPolicyHistory saveHistory(QuotaPolicyHistory entry) {
        history.add(entry);
        return entry;
    }

    @Override
    public void deleteByTarget(String targetType, long targetId) {
        policies.remove(key(targetType, targetId));
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private String key(String targetType, long targetId) {
        return targetType + ":" + targetId;
    }
}
