package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record BillingPricingPolicy(
        String currency,
        BigDecimal storageGbMonthRate,
        BigDecimal ingressGbRate,
        BigDecimal egressGbRate,
        BigDecimal internalGbRate,
        BigDecimal operationThousandRate,
        BigDecimal warningAmount,
        BigDecimal criticalAmount,
        int eventScanLimit,
        OffsetDateTime updatedAt
) {
    public static BillingPricingPolicy defaults() {
        return new BillingPricingPolicy(
                "USD",
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                10_000,
                null
        );
    }
}
