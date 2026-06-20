package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record ChargebackNotificationDeliveryAdapterResult(
        String result,
        String lastError,
        OffsetDateTime nextAttemptAt
) {

    public static ChargebackNotificationDeliveryAdapterResult success() {
        return new ChargebackNotificationDeliveryAdapterResult("SUCCESS", null, null);
    }

    public static ChargebackNotificationDeliveryAdapterResult retry(String lastError) {
        return new ChargebackNotificationDeliveryAdapterResult("RETRY", lastError, null);
    }

    public static ChargebackNotificationDeliveryAdapterResult blocked(String lastError) {
        return new ChargebackNotificationDeliveryAdapterResult("BLOCKED_CREDENTIAL", lastError, null);
    }
}
