package com.example.osmu.monitoring;

import java.time.OffsetDateTime;
import java.util.Locale;

public record DataFlowEventFilter(
        String bucketName,
        String actorId,
        String source,
        String operation,
        String status,
        OffsetDateTime from,
        OffsetDateTime to
) {

    public DataFlowEventFilter {
        bucketName = blankToNull(bucketName);
        actorId = blankToNull(actorId);
        source = lower(blankToNull(source));
        operation = lower(blankToNull(operation));
        status = upper(blankToNull(status));
    }

    public static DataFlowEventFilter empty() {
        return new DataFlowEventFilter(null, null, null, null, null, null, null);
    }

    public boolean matches(DataFlowEventRecord event) {
        return (bucketName == null || bucketName.equals(event.bucketName()))
                && (actorId == null || actorId.equals(event.actorId()))
                && (source == null || source.equalsIgnoreCase(event.source()))
                && (operation == null || operation.equalsIgnoreCase(event.operation()))
                && (status == null || status.equalsIgnoreCase(event.status()))
                && (from == null || !event.createdAt().isBefore(from))
                && (to == null || !event.createdAt().isAfter(to));
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private static String lower(String value) {
        return value == null ? null : value.toLowerCase(Locale.ROOT);
    }

    private static String upper(String value) {
        return value == null ? null : value.toUpperCase(Locale.ROOT);
    }
}
