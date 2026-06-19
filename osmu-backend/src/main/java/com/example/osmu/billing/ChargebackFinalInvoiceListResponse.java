package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackFinalInvoiceListResponse(
        long invoiceCount,
        List<ChargebackFinalInvoiceResponse> invoices,
        OffsetDateTime generatedAt
) {
}
