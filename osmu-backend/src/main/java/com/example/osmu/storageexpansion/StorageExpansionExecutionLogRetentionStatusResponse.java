package com.example.osmu.storageexpansion;

public record StorageExpansionExecutionLogRetentionStatusResponse(
        boolean enabled,
        int retentionDays,
        int batchSize,
        long pendingOutputCount,
        double redactedOutputCount,
        double failedRunCount
) {
}
