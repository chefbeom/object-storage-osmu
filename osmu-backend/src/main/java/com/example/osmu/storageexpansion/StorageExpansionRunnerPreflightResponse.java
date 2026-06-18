package com.example.osmu.storageexpansion;

import java.util.List;

public record StorageExpansionRunnerPreflightResponse(
        String status,
        boolean ready,
        int enabledRunnerCount,
        int failedCheckCount,
        List<StorageExpansionRunnerPreflightCheck> checks
) {
}
