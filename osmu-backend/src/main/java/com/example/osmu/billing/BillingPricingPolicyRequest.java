package com.example.osmu.billing;

import java.math.BigDecimal;

public record BillingPricingPolicyRequest(
        String currency,
        BigDecimal storageGbMonthRate,
        BigDecimal ingressGbRate,
        BigDecimal egressGbRate,
        BigDecimal internalGbRate,
        BigDecimal operationThousandRate,
        BigDecimal warningAmount,
        BigDecimal criticalAmount,
        Integer eventScanLimit,
        String reason
) {
}
