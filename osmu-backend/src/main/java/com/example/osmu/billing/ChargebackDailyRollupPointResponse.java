package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ChargebackDailyRollupPointResponse(
        LocalDate day,
        long organizationId,
        String organizationName,
        long bucketCount,
        long objectCount,
        long usedBytes,
        long ingressBytes,
        long egressBytes,
        long internalBytes,
        long billableOperationCount,
        long failedOperationCount,
        long cancelledOperationCount,
        BigDecimal projectedStorageCost,
        BigDecimal ingressCost,
        BigDecimal egressCost,
        BigDecimal internalCost,
        BigDecimal operationCost,
        BigDecimal estimatedTotalCost
) {
}
