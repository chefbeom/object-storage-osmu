package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ChargebackAlertNotificationDeliveryRecord(
        Long id,
        long organizationId,
        String organizationName,
        String severity,
        BigDecimal estimatedTotalCost,
        BigDecimal warningAmount,
        BigDecimal criticalAmount,
        String channel,
        String target,
        String status,
        int attemptCount,
        OffsetDateTime nextAttemptAt,
        String subject,
        String message,
        String payloadJson,
        String requestedBy,
        String reason,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        String lastError
) {
}
