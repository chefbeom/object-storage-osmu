package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record ChargebackAdapterRetryWorkerItemResponse(
        String itemType,
        long id,
        String fromStatus,
        String toStatus,
        int attemptCount,
        OffsetDateTime nextAttemptAt,
        String note
) {
}
