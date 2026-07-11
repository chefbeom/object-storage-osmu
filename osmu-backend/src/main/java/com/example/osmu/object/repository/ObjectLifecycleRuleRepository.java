package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectLifecycleRule;
import com.example.osmu.object.ObjectLifecycleRulePageCursor;
import java.util.List;
import java.util.Optional;

public interface ObjectLifecycleRuleRepository {

    List<ObjectLifecycleRule> findPage(
            Boolean enabled,
            String targetType,
            ObjectLifecycleRulePageCursor cursor,
            int limit
    );

    List<ObjectLifecycleRule> findAllForExport();

    List<ObjectLifecycleRule> findEnabledByTargetType(String targetType);

    List<ObjectLifecycleRule> findByBucketName(String bucketName);

    Optional<ObjectLifecycleRule> findById(String ruleId);

    ObjectLifecycleRule save(ObjectLifecycleRule rule);

    void delete(String ruleId);

    boolean isHealthy();
}
