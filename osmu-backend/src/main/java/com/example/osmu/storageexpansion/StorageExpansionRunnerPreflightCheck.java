package com.example.osmu.storageexpansion;

import java.util.List;

public record StorageExpansionRunnerPreflightCheck(
        String id,
        String label,
        boolean enabled,
        String status,
        String detail,
        String remediation,
        List<String> commands
) {
}
