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
        OffsetDateTime expiresAt,
        OffsetDateTime lastUsedAt,
        long usageCount
) {
    @Override
    public String toString() {
        return "AccessKeyEntity["
                + "id=" + id
                + ", ownerId=" + ownerId
                + ", name=" + name
                + ", accessKey=" + accessKey
                + ", secretKeyHash=<redacted>"
                + ", secretKeyCiphertext=<redacted>"
                + ", allowedBuckets=" + allowedBuckets
                + ", permissions=" + permissions
                + ", bucketScopes=" + bucketScopes
                + ", status=" + status
                + ", createdAt=" + createdAt
                + ", expiresAt=" + expiresAt
                + ", lastUsedAt=" + lastUsedAt
                + ", usageCount=" + usageCount
                + "]";
    }

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
                expiresAt,
                lastUsedAt,
                usageCount
        );
    }
}
