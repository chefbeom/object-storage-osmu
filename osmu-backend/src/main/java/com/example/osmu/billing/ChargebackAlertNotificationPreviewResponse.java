package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackAlertNotificationPreviewResponse(
        String mode,
        String channel,
        String target,
        boolean externalDeliveryEnabled,
        String currency,
        long notificationCount,
        List<ChargebackAlertNotificationOrganizationResponse> notifications,
        OffsetDateTime generatedAt,
        String note
) {
}
