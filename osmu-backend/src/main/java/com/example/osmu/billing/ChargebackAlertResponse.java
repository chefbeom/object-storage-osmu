package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackAlertResponse(
        String currency,
        BigDecimal warningAmount,
        BigDecimal criticalAmount,
        long alertCount,
        long warningCount,
        long criticalCount,
        List<ChargebackAlertOrganizationResponse> organizations,
        OffsetDateTime generatedAt
) {
}
