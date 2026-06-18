package com.example.osmu.monitoring;

public record DataFlowTrafficSummaryResponse(
        long uploadedBytes,
        long downloadedBytes,
        long copiedBytes,
        long totalBytes,
        long ingressBytes,
        long egressBytes,
        long internalBytes
) {
}
