package com.example.osmu.monitoring;

import java.time.OffsetDateTime;

public record DataFlowRetentionStatusResponse(
        String mode,
        DataFlowRetentionPolicyStatusResponse eventRetention,
        DataFlowRetentionPolicyStatusResponse dailyRollupRetention,
        OffsetDateTime generatedAt,
        String note
) {
}
