package com.example.osmu.storageexpansion;

public record StorageExpansionDryRunExecutionPayload(
        String executionType,
        String result,
        String output,
        String externalUrl,
        String notes
) {
}
