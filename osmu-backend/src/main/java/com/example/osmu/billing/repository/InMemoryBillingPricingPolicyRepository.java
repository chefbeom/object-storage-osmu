package com.example.osmu.billing.repository;

import com.example.osmu.billing.BillingPricingPolicy;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryBillingPricingPolicyRepository implements BillingPricingPolicyRepository {

    private volatile BillingPricingPolicy policy = BillingPricingPolicy.defaults();

    @Override
    public BillingPricingPolicy get() {
        return policy;
    }

    @Override
    public BillingPricingPolicy save(BillingPricingPolicy policy) {
        this.policy = policy;
        return policy;
    }
}
