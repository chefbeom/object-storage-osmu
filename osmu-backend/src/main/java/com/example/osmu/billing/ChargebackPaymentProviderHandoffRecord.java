package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ChargebackPaymentProviderHandoffRecord(
        Long id,
        long finalInvoiceId,
        String invoiceNumber,
        long organizationId,
        String organizationName,
        String currency,
        BigDecimal amount,
        String provider,
        String targetAccount,
        String status,
        int attemptCount,
        OffsetDateTime nextAttemptAt,
        String payloadJson,
        String requestedBy,
        String reason,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        String lastError
) {
}
