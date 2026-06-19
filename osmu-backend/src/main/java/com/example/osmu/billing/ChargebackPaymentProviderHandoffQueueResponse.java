package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record ChargebackPaymentProviderHandoffQueueResponse(
        String mode,
        String status,
        boolean externalPaymentEnabled,
        ChargebackPaymentProviderHandoffResponse handoff,
        OffsetDateTime generatedAt,
        String note
) {
}
