package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackPreviewResponse(
        String currency,
        OffsetDateTime from,
        OffsetDateTime to,
        ChargebackRateResponse rates,
        int eventScanLimit,
        int scannedEventCount,
        long organizationCount,
        long bucketCount,
        long usedBytes,
        long ingressBytes,
        long egressBytes,
        long internalBytes,
        long billableOperationCount,
        long failedOperationCount,
        long cancelledOperationCount,
        BigDecimal estimatedTotalCost,
        List<ChargebackOrganizationPreviewResponse> organizations,
        OffsetDateTime generatedAt
) {
}
