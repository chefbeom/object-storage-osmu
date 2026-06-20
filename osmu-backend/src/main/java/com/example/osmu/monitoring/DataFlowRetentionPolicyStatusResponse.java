package com.example.osmu.monitoring;

public record DataFlowRetentionPolicyStatusResponse(
        boolean enabled,
        boolean jobAvailable,
        int retentionDays,
        int batchSize,
        double deletedCount,
        double failedRunCount
) {
}
