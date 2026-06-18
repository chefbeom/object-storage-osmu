package com.example.osmu.storageexpansion;

public record StorageExpansionManifestResponse(
        long requestId,
        String poolName,
        String status,
        boolean referenceOnly,
        String tenantPatchYaml,
        String helmValuesPatchYaml
) {
}
