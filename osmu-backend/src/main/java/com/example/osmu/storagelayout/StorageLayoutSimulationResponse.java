package com.example.osmu.storagelayout;

public record StorageLayoutSimulationResponse(
        StorageLayoutPlanResponse plan,
        String mode,
        String manifestPreview,
        String message
) {
}
