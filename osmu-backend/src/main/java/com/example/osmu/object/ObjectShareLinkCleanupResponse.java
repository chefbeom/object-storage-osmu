package com.example.osmu.object;

public record ObjectShareLinkCleanupResponse(
        String bucketName,
        int expiredCount
) {
}
