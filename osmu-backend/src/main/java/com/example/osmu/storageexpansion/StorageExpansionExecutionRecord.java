package com.example.osmu.storageexpansion;

import java.time.OffsetDateTime;

public record StorageExpansionExecutionRecord(
        long id,
        long requestId,
        String executionType,
        String result,
        String command,
        String output,
        String externalUrl,
        String artifactSha256,
        Integer exitCode,
        boolean timedOut,
        String notes,
        String createdBy,
        OffsetDateTime createdAt
) {
}
