package com.example.osmu.quota;

import java.time.OffsetDateTime;

public record QuotaPolicyResponse(
        long id,
        String targetType,
        long targetId,
        long quotaBytes,
        long usedBytes,
        long remainingBytes,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
    public static QuotaPolicyResponse of(QuotaPolicy policy, long usedBytes) {
        return new QuotaPolicyResponse(
                policy.id(),
                policy.targetType(),
                policy.targetId(),
                policy.quotaBytes(),
                usedBytes,
                Math.max(0L, policy.quotaBytes() - usedBytes),
                policy.createdAt(),
                policy.updatedAt()
        );
    }
}
