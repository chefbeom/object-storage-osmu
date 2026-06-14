package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectLifecycleRule;
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
    public List<ObjectLifecycleRule> findAll() {
        return rulesById.values().stream()
                .sorted(Comparator.comparingInt(ObjectLifecycleRule::priority)
                        .thenComparing(ObjectLifecycleRule::createdAt)
                        .thenComparing(ObjectLifecycleRule::ruleId))
                .toList();
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
