package com.example.osmu.billing;

import java.math.BigDecimal;

public record ChargebackRateResponse(
        BigDecimal storageGbMonthRate,
        BigDecimal ingressGbRate,
        BigDecimal egressGbRate,
        BigDecimal internalGbRate,
        BigDecimal operationThousandRate
) {
}
