package com.example.osmu.accesskey;

import java.time.OffsetDateTime;
import java.util.List;

public record AccessKeyCredential(
        long id,
        long ownerId,
        String accessKey,
        String secretKeyHash,
        String secretKeyCiphertext,
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
                + ", bucketScopes=" + bucketScopes
                + ", status=" + status
                + ", expiresAt=" + expiresAt
                + "]";
    }
}
