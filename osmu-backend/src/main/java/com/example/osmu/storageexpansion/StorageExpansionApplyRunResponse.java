package com.example.osmu.storageexpansion;

public record StorageExpansionApplyRunResponse(
        StorageExpansionExecutionResponse execution,
        StorageExpansionRequestResponse request
) {
}
