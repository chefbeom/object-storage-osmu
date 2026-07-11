package com.example.osmu.storagelayout;

public record StorageLayoutPlanPayload(
        String layoutCode,
        String storageClassName,
        Integer serverCount,
        Integer volumesPerServer,
        Long volumeSizeGiB,
        String reason
) {
}
