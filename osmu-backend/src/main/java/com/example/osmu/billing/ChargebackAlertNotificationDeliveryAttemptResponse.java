package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record ChargebackAlertNotificationDeliveryAttemptResponse(
        String mode,
        String status,
        boolean externalDeliveryEnabled,
        ChargebackAlertNotificationDeliveryResponse delivery,
        OffsetDateTime recordedAt,
        String note
) {
}
