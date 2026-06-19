package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.Map;

public record ChargebackPaymentProviderHandoffPreviewResponse(
        String mode,
        String provider,
        String targetAccount,
        boolean externalPaymentEnabled,
        ChargebackFinalInvoiceResponse invoice,
        Map<String, Object> payload,
        OffsetDateTime generatedAt,
        String note
) {
}
