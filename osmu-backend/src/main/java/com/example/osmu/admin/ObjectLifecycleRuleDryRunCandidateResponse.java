package com.example.osmu.admin;

import java.time.OffsetDateTime;

public record ObjectLifecycleRuleDryRunCandidateResponse(
        String targetId,
        String bucketName,
        String objectKey,
        String versionId,
        long sizeBytes,
        OffsetDateTime matchedAt
) {
}
