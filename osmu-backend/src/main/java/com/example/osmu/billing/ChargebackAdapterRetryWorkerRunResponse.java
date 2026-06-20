package com.example.osmu.billing;

import java.time.OffsetDateTime;
import java.util.List;

public record ChargebackAdapterRetryWorkerRunResponse(
        String mode,
        boolean enabled,
        boolean dryRun,
        boolean externalAdaptersEnabled,
        int scanLimit,
        int notificationCandidateCount,
        int paymentCandidateCount,
        int updatedCount,
        List<ChargebackAdapterRetryWorkerItemResponse> items,
        OffsetDateTime generatedAt,
        String note
) {
}
