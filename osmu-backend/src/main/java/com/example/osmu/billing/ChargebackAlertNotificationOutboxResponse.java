package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackAlertNotificationOutboxResponse(
        long deliveryCount,
        List<ChargebackAlertNotificationDeliveryResponse> deliveries,
        OffsetDateTime generatedAt
) {
}
