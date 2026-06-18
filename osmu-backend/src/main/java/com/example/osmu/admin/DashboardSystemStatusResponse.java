package com.example.osmu.admin;

public record DashboardSystemStatusResponse(
        String backend,
        String database,
        String storage,
        String accessKeyProvisioner,
        String metadataEngine,
        String storageEngine
) {
}
