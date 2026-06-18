package com.example.osmu.storageexpansion;

public record StorageExpansionPostRunVerification(
        boolean success,
        String summary,
        String notes
) {
}
