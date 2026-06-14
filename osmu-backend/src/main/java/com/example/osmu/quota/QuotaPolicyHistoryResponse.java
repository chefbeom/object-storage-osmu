package com.example.osmu.quota;

import java.time.OffsetDateTime;

public record QuotaPolicyHistoryResponse(
        long id,
        String targetType,
        long targetId,
        String action,
        Long previousQuotaBytes,
        Long newQuotaBytes,
        String actorId,
        String reason,
        OffsetDateTime createdAt
) {
    public static QuotaPolicyHistoryResponse of(QuotaPolicyHistory history) {
        return new QuotaPolicyHistoryResponse(
                history.id(),
                history.targetType(),
                history.targetId(),
                history.action(),
                history.previousQuotaBytes(),
                history.newQuotaBytes(),
                history.actorId(),
                history.reason(),
                history.createdAt()
        );
    }
}
