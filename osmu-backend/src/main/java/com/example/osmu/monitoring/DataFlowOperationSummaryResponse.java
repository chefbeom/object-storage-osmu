package com.example.osmu.monitoring;

public record DataFlowOperationSummaryResponse(
        long uploadCount,
        long downloadCount,
        long copyCount,
        long listCount,
        long deleteCount,
        long cancelCount,
        long failureCount,
        long totalCount
) {
}
