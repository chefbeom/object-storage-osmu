package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackPaymentProviderHandoffListResponse(
        long handoffCount,
        List<ChargebackPaymentProviderHandoffResponse> handoffs,
        OffsetDateTime generatedAt
) {
}
