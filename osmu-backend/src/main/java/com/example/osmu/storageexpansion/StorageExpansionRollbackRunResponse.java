package com.example.osmu.storageexpansion;

public record StorageExpansionRollbackRunResponse(
        StorageExpansionExecutionResponse execution,
        StorageExpansionRequestResponse request
) {
}
