package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record ChargebackPaymentProviderAdapterResult(
        String result,
        String lastError,
        OffsetDateTime nextAttemptAt
) {

    public static ChargebackPaymentProviderAdapterResult success() {
        return new ChargebackPaymentProviderAdapterResult("SUCCESS", null, null);
    }

    public static ChargebackPaymentProviderAdapterResult retry(String lastError) {
        return new ChargebackPaymentProviderAdapterResult("RETRY", lastError, null);
    }

    public static ChargebackPaymentProviderAdapterResult blocked(String lastError) {
        return new ChargebackPaymentProviderAdapterResult("BLOCKED_CREDENTIAL", lastError, null);
    }
}
