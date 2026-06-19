package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record BillingPricingPolicyProposalCreateResponse(
        String status,
        boolean approvedPriceList,
        BillingPricingPolicyProposalResponse proposal,
        OffsetDateTime generatedAt,
        String note
) {
}
