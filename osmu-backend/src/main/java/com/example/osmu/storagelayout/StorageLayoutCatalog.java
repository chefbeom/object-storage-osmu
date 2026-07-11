package com.example.osmu.storagelayout;

import java.util.List;
import java.util.Map;

public final class StorageLayoutCatalog {

    private static final Map<StorageLayoutCode, StorageLayoutDefinition> DEFINITIONS = Map.of(
            StorageLayoutCode.JBOD,
            new StorageLayoutDefinition(
                    "JBOD",
                    "JBOD",
                    "Independent PVC set without cross-PVC redundancy.",
                    1,
                    false,
                    "None across PVCs",
                    "HIGH"
            ),
            StorageLayoutCode.RAID0,
            new StorageLayoutDefinition(
                    "RAID0",
                    "RAID 0-like",
                    "Performance-oriented PVC layout with no cross-PVC fault tolerance.",
                    2,
                    false,
                    "None",
                    "HIGH"
            ),
            StorageLayoutCode.RAID1,
            new StorageLayoutDefinition(
                    "RAID1",
                    "RAID 1-like",
                    "Mirrored-capacity intent for a replicated StorageClass or storage backend.",
                    2,
                    true,
                    "One PVC in each mirror pair",
                    "LOW"
            ),
            StorageLayoutCode.RAID5,
            new StorageLayoutDefinition(
                    "RAID5",
                    "RAID 5-like",
                    "Single-parity capacity intent for a Kubernetes PVC and MinIO pool plan.",
                    3,
                    false,
                    "One PVC",
                    "MEDIUM"
            ),
            StorageLayoutCode.RAID6,
            new StorageLayoutDefinition(
                    "RAID6",
                    "RAID 6-like",
                    "Dual-parity capacity intent for a Kubernetes PVC and MinIO pool plan.",
                    4,
                    false,
                    "Two PVCs",
                    "LOW"
            ),
            StorageLayoutCode.RAID10,
            new StorageLayoutDefinition(
                    "RAID10",
                    "RAID 10-like",
                    "Mirrored-stripe capacity intent for a replicated PVC layout.",
                    4,
                    true,
                    "One PVC in each mirror pair",
                    "LOW"
            )
    );

    private StorageLayoutCatalog() {
    }

    public static List<StorageLayoutDefinition> list() {
        return List.of(
                definition(StorageLayoutCode.JBOD),
                definition(StorageLayoutCode.RAID0),
                definition(StorageLayoutCode.RAID1),
                definition(StorageLayoutCode.RAID5),
                definition(StorageLayoutCode.RAID6),
                definition(StorageLayoutCode.RAID10)
        );
    }

    public static StorageLayoutDefinition definition(StorageLayoutCode code) {
        return DEFINITIONS.get(code);
    }

    public static long estimatedUsableCapacityBytes(StorageLayoutCode code, int pvcCount, long rawCapacityBytes) {
        return switch (code) {
            case JBOD, RAID0 -> rawCapacityBytes;
            case RAID1, RAID10 -> rawCapacityBytes / 2;
            case RAID5 -> perPvcCapacity(rawCapacityBytes, pvcCount) * (pvcCount - 1L);
            case RAID6 -> perPvcCapacity(rawCapacityBytes, pvcCount) * (pvcCount - 2L);
        };
    }

    private static long perPvcCapacity(long rawCapacityBytes, int pvcCount) {
        return rawCapacityBytes / pvcCount;
    }
}
