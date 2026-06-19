package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackAlertNotificationDispatchResponse(
        String mode,
        String status,
        boolean externalDeliveryEnabled,
        long queuedCount,
        List<ChargebackAlertNotificationDeliveryResponse> deliveries,
        OffsetDateTime generatedAt,
        String note
) {
}
