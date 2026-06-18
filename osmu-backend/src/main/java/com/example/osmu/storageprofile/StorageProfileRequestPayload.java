package com.example.osmu.storageprofile;

public record StorageProfileRequestPayload(
        String requestedProfile,
        String reason
) {
}
