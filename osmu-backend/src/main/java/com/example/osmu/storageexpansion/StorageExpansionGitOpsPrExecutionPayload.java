package com.example.osmu.storageexpansion;

public record StorageExpansionGitOpsPrExecutionPayload(
        String externalUrl,
        String mergeSha,
        String pipelineUrl,
        String notes
) {
}
