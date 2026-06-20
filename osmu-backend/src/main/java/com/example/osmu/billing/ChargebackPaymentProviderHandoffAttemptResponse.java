package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record ChargebackPaymentProviderHandoffAttemptResponse(
        String mode,
        String status,
        boolean externalPaymentEnabled,
        ChargebackPaymentProviderHandoffResponse handoff,
        OffsetDateTime recordedAt,
        String note
) {
}
