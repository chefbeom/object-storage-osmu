package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ChargebackPreviewRequest(
        OffsetDateTime from,
        OffsetDateTime to,
        String currency,
        BigDecimal storageGbMonthRate,
        BigDecimal ingressGbRate,
        BigDecimal egressGbRate,
        BigDecimal internalGbRate,
        BigDecimal operationThousandRate,
        int eventScanLimit
) {
}
