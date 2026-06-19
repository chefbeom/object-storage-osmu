package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackInvoiceDraftCreateResponse(
        String mode,
        String status,
        boolean finalInvoice,
        boolean paymentRequest,
        long persistedCount,
        List<ChargebackInvoiceDraftResponse> invoices,
        OffsetDateTime generatedAt,
        String note
) {
}
