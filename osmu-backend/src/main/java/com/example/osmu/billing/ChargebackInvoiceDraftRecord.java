package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ChargebackInvoiceDraftRecord(
        Long id,
        String invoiceNumber,
        String status,
        long organizationId,
        String organizationName,
        String currency,
        OffsetDateTime from,
        OffsetDateTime to,
        OffsetDateTime previewGeneratedAt,
        int eventScanLimit,
        BigDecimal storageGbMonthRate,
        BigDecimal ingressGbRate,
        BigDecimal egressGbRate,
        BigDecimal internalGbRate,
        BigDecimal operationThousandRate,
        long bucketCount,
        long objectCount,
        long usedBytes,
        BigDecimal storageCost,
        BigDecimal trafficCost,
        BigDecimal operationCost,
        BigDecimal estimatedTotalCost,
        String requestedBy,
        String approvedBy,
        String reason,
        String approvalNote,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        OffsetDateTime approvedAt,
        String note
) {
}
