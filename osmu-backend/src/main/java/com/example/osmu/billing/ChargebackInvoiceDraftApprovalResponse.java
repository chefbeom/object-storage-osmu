package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record ChargebackInvoiceDraftApprovalResponse(
        String status,
        boolean finalInvoice,
        boolean paymentRequest,
        ChargebackInvoiceDraftResponse invoice,
        OffsetDateTime generatedAt,
        String note
) {
}
