package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackPaymentProviderAdapterReadinessResponse(
        String mode,
        String status,
        boolean nativeApiSupported,
        boolean nativeApiReady,
        int profileCount,
        int webhookReadyProfileCount,
        int nativeApiReadyProfileCount,
        List<ChargebackPaymentProviderAdapterProfileResponse> profiles,
        OffsetDateTime generatedAt,
        String scopePolicy,
        String secretPolicy,
        String note
) {
}
