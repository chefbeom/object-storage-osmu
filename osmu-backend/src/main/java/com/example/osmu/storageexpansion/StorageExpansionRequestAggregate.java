package com.example.osmu.storageexpansion;

public record StorageExpansionRequestAggregate(
        long requestCount,
        long openRequestCount,
        long plannedRequestCount,
        long approvedRequestCount,
        long appliedRequestCount,
        long rejectedRequestCount,
        long totalRequestedCapacityBytes,
        long openRequestedCapacityBytes,
        long totalEstimatedUsableCapacityBytes,
        long openEstimatedUsableCapacityBytes
) {
}
