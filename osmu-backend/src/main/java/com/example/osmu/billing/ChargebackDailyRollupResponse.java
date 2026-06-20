package com.example.osmu.billing;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackDailyRollupResponse(
        String mode,
        String rollupSource,
        String granularity,
        String currency,
        int days,
        int limit,
        int inputPointCount,
        int pointCount,
        BigDecimal totalEstimatedCost,
        List<ChargebackDailyRollupPointResponse> points,
        OffsetDateTime generatedAt,
        String note,
        String storageCostPolicy
) {
}
