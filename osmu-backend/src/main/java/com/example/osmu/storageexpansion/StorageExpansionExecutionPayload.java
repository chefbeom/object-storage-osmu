package com.example.osmu.storageexpansion;

public record StorageExpansionExecutionPayload(
        String executionType,
        String result,
        String command,
        String output,
        String externalUrl,
        String artifactSha256,
        String notes
) {
}
