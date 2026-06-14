package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectSharePolicy;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryObjectSharePolicyRepository implements ObjectSharePolicyRepository {

    private volatile ObjectSharePolicy policy = ObjectSharePolicy.defaults();

    @Override
    public ObjectSharePolicy get() {
        return policy;
    }

    @Override
    public ObjectSharePolicy save(ObjectSharePolicy policy) {
        this.policy = policy;
        return policy;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
