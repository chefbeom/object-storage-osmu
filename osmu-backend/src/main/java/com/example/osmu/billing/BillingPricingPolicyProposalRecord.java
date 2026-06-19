package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record BillingPricingPolicyProposalRecord(
        Long id,
        String status,
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
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        OffsetDateTime approvedAt,
        OffsetDateTime appliedAt
) {
}
