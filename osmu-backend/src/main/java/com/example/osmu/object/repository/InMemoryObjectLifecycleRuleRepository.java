package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectLifecycleRule;
import com.example.osmu.object.ObjectLifecycleRulePageCursor;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryObjectLifecycleRuleRepository implements ObjectLifecycleRuleRepository {

    private final ConcurrentMap<String, ObjectLifecycleRule> rulesById = new ConcurrentHashMap<>();

    @Override
    public List<ObjectLifecycleRule> findPage(
            Boolean enabled,
            String targetType,
            ObjectLifecycleRulePageCursor cursor,
            int limit
    ) {
        return rulesById.values().stream()
                .filter(rule -> enabled == null || rule.enabled() == enabled)
                .filter(rule -> targetType == null || targetType.equals(rule.targetType()))
                .filter(rule -> cursor == null || isAfter(rule, cursor))
                .sorted(ruleOrder())
                .limit(limit)
                .toList();
    }

    @Override
    public List<ObjectLifecycleRule> findAllForExport() {
        return rulesById.values().stream()
                .sorted(ruleOrder())
                .toList();
    }

    @Override
    public List<ObjectLifecycleRule> findEnabledByTargetType(String targetType) {
        return rulesById.values().stream()
                .filter(rule -> rule.enabled() && targetType.equals(rule.targetType()))
                .sorted(ruleOrder())
                .toList();
    }

    @Override
    public List<ObjectLifecycleRule> findByBucketName(String bucketName) {
        return rulesById.values().stream()
                .filter(rule -> bucketName.equals(rule.bucketName()))
                .sorted(ruleOrder())
                .toList();
    }

    private Comparator<ObjectLifecycleRule> ruleOrder() {
        return Comparator.comparingInt(ObjectLifecycleRule::priority)
                .thenComparing(ObjectLifecycleRule::createdAt)
                .thenComparing(ObjectLifecycleRule::ruleId);
    }

    private boolean isAfter(ObjectLifecycleRule rule, ObjectLifecycleRulePageCursor cursor) {
        int comparison = Integer.compare(rule.priority(), cursor.priority());
        if (comparison == 0) {
            comparison = rule.createdAt().compareTo(cursor.createdAt());
        }
        if (comparison == 0) {
            comparison = rule.ruleId().compareTo(cursor.ruleId());
        }
        return comparison > 0;
    }

    @Override
    public Optional<ObjectLifecycleRule> findById(String ruleId) {
        return Optional.ofNullable(rulesById.get(ruleId));
    }

    @Override
    public ObjectLifecycleRule save(ObjectLifecycleRule rule) {
        rulesById.put(rule.ruleId(), rule);
        return rule;
    }

    @Override
    public void delete(String ruleId) {
        rulesById.remove(ruleId);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
