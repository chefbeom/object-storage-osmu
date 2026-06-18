package com.example.osmu.storageexpansion;

public record StorageExpansionExecutionLogRetentionRunResponse(
        int redactedOutputCount,
        StorageExpansionExecutionLogRetentionStatusResponse status
) {
}
