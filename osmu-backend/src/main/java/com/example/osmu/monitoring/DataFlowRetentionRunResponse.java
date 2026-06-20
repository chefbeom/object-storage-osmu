package com.example.osmu.monitoring;

import java.time.OffsetDateTime;

public record DataFlowRetentionRunResponse(
        String mode,
        int deletedEventCount,
        int deletedDailyRollupCount,
        DataFlowRetentionStatusResponse status,
        OffsetDateTime generatedAt,
        String note
) {
}
