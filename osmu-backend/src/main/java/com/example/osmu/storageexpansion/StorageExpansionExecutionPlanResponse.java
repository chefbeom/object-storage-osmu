package com.example.osmu.storageexpansion;

import java.util.List;

public record StorageExpansionExecutionPlanResponse(
        long requestId,
        String poolName,
        String status,
        boolean ready,
        boolean referenceOnly,
        String artifactSha256,
        String evidenceTemplate,
        List<String> preflightChecks,
        List<String> suggestedCommands
) {
}
