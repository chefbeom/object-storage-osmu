package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record BillingPricingPolicyCommercialApprovalSummaryResponse(
        String mode,
        int proposalCount,
        int approvedPriceListCount,
        int commercialApprovedCount,
        OffsetDateTime latestCommercialApprovedAt,
        List<BillingPricingPolicyCommercialApprovalProposalResponse> proposals,
        OffsetDateTime generatedAt,
        String scopePolicy,
        String secretPolicy,
        String note
) {
}
