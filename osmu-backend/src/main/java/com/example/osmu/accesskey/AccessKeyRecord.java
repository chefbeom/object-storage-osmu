package com.example.osmu.accesskey;

import java.time.OffsetDateTime;
import java.util.List;

public record AccessKeyRecord(
        long id,
        long ownerId,
        String name,
        String accessKey,
        String policyName,
        List<String> allowedBuckets,
        List<String> permissions,
        List<AccessKeyBucketScope> bucketScopes,
        String status,
        OffsetDateTime createdAt,
        OffsetDateTime expiresAt,
        OffsetDateTime lastUsedAt
) {
}
