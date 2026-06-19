package com.example.osmu.billing;

import java.math.BigDecimal;

public record ChargebackAlertOrganizationResponse(
        long organizationId,
        String organizationName,
        String severity,
        BigDecimal estimatedTotalCost,
        BigDecimal warningAmount,
        BigDecimal criticalAmount
) {
}
