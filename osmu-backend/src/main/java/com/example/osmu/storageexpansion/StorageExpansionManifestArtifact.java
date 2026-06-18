package com.example.osmu.storageexpansion;

public record StorageExpansionManifestArtifact(
        long requestId,
        String artifact,
        String fileName,
        String content
) {
}
