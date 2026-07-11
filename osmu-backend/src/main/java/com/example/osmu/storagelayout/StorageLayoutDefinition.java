package com.example.osmu.storagelayout;

public record StorageLayoutDefinition(
        String code,
        String name,
        String description,
        int minimumPvcCount,
        boolean requiresEvenPvcCount,
        String faultTolerance,
        String riskLevel
) {
}
