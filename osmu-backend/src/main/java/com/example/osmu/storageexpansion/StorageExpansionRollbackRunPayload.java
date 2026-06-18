package com.example.osmu.storageexpansion;

public record StorageExpansionRollbackRunPayload(
        String rollbackType,
        Integer helmRevision,
        String kubectlTarget
) {
}
