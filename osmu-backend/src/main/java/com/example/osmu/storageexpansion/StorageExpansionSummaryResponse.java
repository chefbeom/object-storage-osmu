package com.example.osmu.storageexpansion;

import java.util.List;

public record StorageExpansionSummaryResponse(
        long requestCount,
        long openRequestCount,
        long plannedRequestCount,
        long approvedRequestCount,
        long appliedRequestCount,
        long rejectedRequestCount,
        long totalRequestedCapacityBytes,
        long openRequestedCapacityBytes,
        long totalEstimatedUsableCapacityBytes,
        long openEstimatedUsableCapacityBytes,
        long executionCount,
        long successExecutionCount,
        long failedExecutionCount,
        long skippedExecutionCount,
        long timedOutExecutionCount,
        StorageExpansionRequestResponse latestRequest,
        StorageExpansionExecutionResponse latestExecution,
        List<StorageExpansionExecutionResponse> recentExecutions
) {
}
