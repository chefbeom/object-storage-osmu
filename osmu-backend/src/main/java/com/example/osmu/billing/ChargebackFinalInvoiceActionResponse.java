package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record ChargebackFinalInvoiceActionResponse(
        String mode,
        String status,
        String paymentStatus,
        boolean finalInvoice,
        boolean paymentRequest,
        ChargebackFinalInvoiceResponse invoice,
        OffsetDateTime generatedAt,
        String note
) {
}
