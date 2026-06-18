package com.example.osmu.accesskey;

import java.time.OffsetDateTime;
import java.util.List;

public record AccessKeyCredential(
        long id,
        long ownerId,
        String accessKey,
        String secretKeyHash,
        String secretKeyCiphertext,
        String previousSecretKeyHash,
        String previousSecretKeyCiphertext,
        OffsetDateTime previousSecretKeyExpiresAt,
        List<AccessKeyBucketScope> bucketScopes,
        String status,
        OffsetDateTime expiresAt
) {
    @Override
    public String toString() {
        return "AccessKeyCredential["
                + "id=" + id
                + ", ownerId=" + ownerId
                + ", accessKey=" + accessKey
                + ", secretKeyHash=<redacted>"
                + ", secretKeyCiphertext=<redacted>"
                + ", previousSecretKeyHash=<redacted>"
                + ", previousSecretKeyCiphertext=<redacted>"
                + ", previousSecretKeyExpiresAt=" + previousSecretKeyExpiresAt
                + ", bucketScopes=" + bucketScopes
                + ", status=" + status
                + ", expiresAt=" + expiresAt
                + "]";
    }
}
