package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record BillingPricingPolicyProposalResponse(
        long id,
        String status,
        boolean approvedPriceList,
        String currency,
        BigDecimal storageGbMonthRate,
        BigDecimal ingressGbRate,
        BigDecimal egressGbRate,
        BigDecimal internalGbRate,
        BigDecimal operationThousandRate,
        BigDecimal warningAmount,
        BigDecimal criticalAmount,
        int eventScanLimit,
        String requestedBy,
        String approvedBy,
        String reason,
        String approvalNote,
        String commercialApprovedBy,
        String commercialApprovalReference,
        String commercialApprovalNote,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        OffsetDateTime approvedAt,
        OffsetDateTime appliedAt,
        OffsetDateTime commercialApprovedAt,
        OffsetDateTime commercialEffectiveFrom
) {
}
