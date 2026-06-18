package com.example.osmu.storageexpansion;

import java.time.OffsetDateTime;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public record StorageExpansionExecutionResponse(
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
        String failureReason,
        String createdBy,
        OffsetDateTime createdAt
) {
    private static final Pattern FAILURE_REASON_PATTERN = Pattern.compile("(?:^|[,\\s])failureReason=([A-Z_]+)");

    public static StorageExpansionExecutionResponse of(StorageExpansionExecutionRecord record) {
        return new StorageExpansionExecutionResponse(
                record.id(),
                record.requestId(),
                record.executionType(),
                record.result(),
                record.command(),
                record.output(),
                record.externalUrl(),
                record.artifactSha256(),
                record.exitCode(),
                record.timedOut(),
                record.notes(),
                extractFailureReason(record.notes()),
                record.createdBy(),
                record.createdAt()
        );
    }

    private static String extractFailureReason(String notes) {
        if (notes == null || notes.isBlank()) {
            return null;
        }
        Matcher matcher = FAILURE_REASON_PATTERN.matcher(notes);
        if (!matcher.find()) {
            return null;
        }
        String reason = matcher.group(1);
        if (reason == null || reason.isBlank() || "NONE".equals(reason) || "NULL".equals(reason)) {
            return null;
        }
        return reason;
    }
}
