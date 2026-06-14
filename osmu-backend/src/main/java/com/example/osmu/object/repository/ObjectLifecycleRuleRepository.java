package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectLifecycleRule;
import java.util.List;
import java.util.Optional;

public interface ObjectLifecycleRuleRepository {

    List<ObjectLifecycleRule> findAll();

    Optional<ObjectLifecycleRule> findById(String ruleId);

    ObjectLifecycleRule save(ObjectLifecycleRule rule);

    void delete(String ruleId);

    boolean isHealthy();
}
