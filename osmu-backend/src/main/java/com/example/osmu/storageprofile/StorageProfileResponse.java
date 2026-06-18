package com.example.osmu.storageprofile;

public record StorageProfileResponse(
        String code,
        String name,
        String alias,
        String strategy,
        String riskLevel,
        String minioStorageClassHint,
        String parityHint,
        String poolSelector,
        String description,
        String useCase
) {
}
