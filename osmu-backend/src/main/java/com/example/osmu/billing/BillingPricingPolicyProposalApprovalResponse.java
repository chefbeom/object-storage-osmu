package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record BillingPricingPolicyProposalApprovalResponse(
        String status,
        boolean approvedPriceList,
        BillingPricingPolicyProposalResponse proposal,
        BillingPricingPolicy appliedPolicy,
        OffsetDateTime generatedAt,
        String note
) {
}
