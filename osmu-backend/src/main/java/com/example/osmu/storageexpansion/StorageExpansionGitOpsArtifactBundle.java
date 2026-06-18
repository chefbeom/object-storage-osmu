package com.example.osmu.storageexpansion;

public record StorageExpansionGitOpsArtifactBundle(
        long requestId,
        String poolName,
        String fileName,
        byte[] content
) {
}
