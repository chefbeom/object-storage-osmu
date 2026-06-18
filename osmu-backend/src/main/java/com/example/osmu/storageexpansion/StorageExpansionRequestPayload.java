package com.example.osmu.storageexpansion;

public record StorageExpansionRequestPayload(
        Long requestedCapacityBytes,
        Integer serverCount,
        Integer volumesPerServer,
        String reason
) {
}
