package com.example.osmu.admin;

import java.time.OffsetDateTime;
import java.util.List;

public record StorageBackendMetricsSnapshot(
        boolean configured,
        boolean ready,
        String source,
        long totalBytes,
        long freeBytes,
        String status,
        String detail,
        List<String> metricNames,
        OffsetDateTime collectedAt
) {

    public static StorageBackendMetricsSnapshot disabled() {
        return new StorageBackendMetricsSnapshot(
                false,
                false,
                "disabled",
                0,
                0,
                "DISABLED",
                "Direct MinIO capacity metrics are disabled.",
                List.of(),
                OffsetDateTime.now()
        );
    }

    public static StorageBackendMetricsSnapshot unavailable(String source, String detail) {
        return new StorageBackendMetricsSnapshot(
                true,
                false,
                source,
                0,
                0,
                "UNAVAILABLE",
                detail,
                List.of(),
                OffsetDateTime.now()
        );
    }

    public static StorageBackendMetricsSnapshot ready(String source, long totalBytes, long freeBytes, List<String> metricNames) {
        long normalizedTotal = Math.max(0L, totalBytes);
        long normalizedFree = Math.max(0L, Math.min(freeBytes, normalizedTotal));
        return new StorageBackendMetricsSnapshot(
                true,
                true,
                source,
                normalizedTotal,
                normalizedFree,
                "READY",
                "Direct MinIO capacity metrics collected from Prometheus-compatible metrics endpoint.",
                List.copyOf(metricNames),
                OffsetDateTime.now()
        );
    }
}
