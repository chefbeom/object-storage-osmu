package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackInvoiceDraftListResponse(
        long invoiceCount,
        List<ChargebackInvoiceDraftResponse> invoices,
        OffsetDateTime generatedAt
) {
}
