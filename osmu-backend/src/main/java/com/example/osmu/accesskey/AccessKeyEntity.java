package com.example.osmu.accesskey;

import java.time.OffsetDateTime;
import java.util.List;

public record AccessKeyEntity(
        long id,
        long ownerId,
        String name,
        String accessKey,
        String secretKeyHash,
        String secretKeyCiphertext,
        List<String> allowedBuckets,
        List<String> permissions,
        List<AccessKeyBucketScope> bucketScopes,
        String status,
        OffsetDateTime createdAt,
        OffsetDateTime expiresAt
) {

    public AccessKeyRecord toRecord() {
        return new AccessKeyRecord(
                id,
                ownerId,
                name,
                accessKey,
                AccessKeyPolicyNames.policyName(id),
                allowedBuckets,
                permissions,
                bucketScopes,
                status,
                createdAt,
                expiresAt
        );
    }
}
