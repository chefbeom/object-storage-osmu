package com.example.osmu.billing.repository;

import com.example.osmu.billing.BillingPricingPolicy;

public interface BillingPricingPolicyRepository {

    BillingPricingPolicy get();

    BillingPricingPolicy save(BillingPricingPolicy policy);
}
