package com.example.osmu.storageprofile;

import java.util.List;
import java.util.Map;

public final class StorageProfileCatalog {

    private static final Map<StorageProfileCode, StorageProfileResponse> PROFILES = Map.of(
            StorageProfileCode.PERFORMANCE,
            new StorageProfileResponse(
                    "PERFORMANCE",
                    "Performance",
                    "RAID0-like",
                    "Speed first, shard across performance pool",
                    "HIGH",
                    "PERFORMANCE",
                    "Lowest allowed parity or dedicated low-parity pool",
                    "osmu.storage-profile=performance",
                    "Large sequential writes, temp media, render cache.",
                    "Video ingest, temporary processing, cache buckets"
            ),
            StorageProfileCode.STANDARD,
            new StorageProfileResponse(
                    "STANDARD",
                    "Standard",
                    "Erasure Coding",
                    "Balanced throughput and durability",
                    "MEDIUM",
                    "STANDARD",
                    "Default erasure coding parity",
                    "osmu.storage-profile=standard",
                    "General object storage profile.",
                    "Team files, service assets, normal app data"
            ),
            StorageProfileCode.DURABLE,
            new StorageProfileResponse(
                    "DURABLE",
                    "Durable",
                    "High Parity",
                    "Durability first, higher parity and stricter pool",
                    "LOW",
                    "DURABLE",
                    "Higher parity or dedicated high-durability pool",
                    "osmu.storage-profile=durable",
                    "Important originals and backup objects.",
                    "Backups, source media, legal/archive data"
            )
    );

    private StorageProfileCatalog() {
    }

    public static List<StorageProfileResponse> list() {
        return List.of(
                get(StorageProfileCode.PERFORMANCE),
                get(StorageProfileCode.STANDARD),
                get(StorageProfileCode.DURABLE)
        );
    }

    public static StorageProfileResponse get(StorageProfileCode code) {
        return PROFILES.get(code);
    }
}
