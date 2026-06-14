package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectRetentionPolicy;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryObjectRetentionPolicyRepository implements ObjectRetentionPolicyRepository {

    private final AtomicReference<ObjectRetentionPolicy> policy;

    public InMemoryObjectRetentionPolicyRepository(boolean enabled, int retentionDays, int batchSize) {
        this(enabled, retentionDays, batchSize, 90, batchSize);
    }

    @org.springframework.beans.factory.annotation.Autowired
    public InMemoryObjectRetentionPolicyRepository(
            @Value("${osmu.object.retention.enabled:true}") boolean enabled,
            @Value("${osmu.object.retention.days:30}") int retentionDays,
            @Value("${osmu.object.retention.batch-size:100}") int batchSize,
            @Value("${osmu.object.version-retention.days:90}") int versionRetentionDays,
            @Value("${osmu.object.version-retention.batch-size:100}") int versionBatchSize
    ) {
        this.policy = new AtomicReference<>(ObjectRetentionPolicy.initial(
                enabled,
                retentionDays,
                batchSize,
                versionRetentionDays,
                versionBatchSize
        ));
    }

    @Override
    public ObjectRetentionPolicy getPolicy() {
        return policy.get();
    }

    @Override
    public ObjectRetentionPolicy save(ObjectRetentionPolicy nextPolicy) {
        policy.set(nextPolicy);
        return nextPolicy;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
