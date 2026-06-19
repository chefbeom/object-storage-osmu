package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record BillingPricingPolicyProposalListResponse(
        long proposalCount,
        List<BillingPricingPolicyProposalResponse> proposals,
        OffsetDateTime generatedAt
) {
}
