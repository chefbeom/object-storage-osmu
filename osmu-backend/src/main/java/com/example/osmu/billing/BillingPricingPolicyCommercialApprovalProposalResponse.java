package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record BillingPricingPolicyCommercialApprovalProposalResponse(
        long id,
        String status,
        boolean approvedPriceList,
        String currency,
        String requestedBy,
        String approvedBy,
        String commercialApprovedBy,
        String commercialApprovalReference,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        OffsetDateTime approvedAt,
        OffsetDateTime appliedAt,
        OffsetDateTime commercialApprovedAt,
        OffsetDateTime commercialEffectiveFrom
) {
}
