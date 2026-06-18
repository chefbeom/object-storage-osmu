package com.example.osmu.monitoring;

public record DataFlowTrafficSummaryResponse(
        long uploadedBytes,
        long downloadedBytes,
        long totalBytes,
        long ingressBytes,
        long egressBytes
) {
}
