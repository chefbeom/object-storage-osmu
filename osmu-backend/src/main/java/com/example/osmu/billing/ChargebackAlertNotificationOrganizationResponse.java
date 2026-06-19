package com.example.osmu.billing;

import java.math.BigDecimal;
import java.util.Map;

public record ChargebackAlertNotificationOrganizationResponse(
        long organizationId,
        String organizationName,
        String severity,
        BigDecimal estimatedTotalCost,
        BigDecimal warningAmount,
        BigDecimal criticalAmount,
        String subject,
        String message,
        Map<String, Object> payload
) {
}
