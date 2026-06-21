package com.example.osmu.monitoring;

import java.time.OffsetDateTime;

public record DataFlowRetentionRunResponse(
        String mode,
        int deletedEventCount,
        int deletedDailyRollupCount,
        int deletedMonthlyRollupCount,
        DataFlowRetentionStatusResponse status,
        OffsetDateTime generatedAt,
        String note
) {
}
