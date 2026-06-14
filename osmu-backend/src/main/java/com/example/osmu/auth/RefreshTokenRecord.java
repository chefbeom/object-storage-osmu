package com.example.osmu.auth;

import java.time.OffsetDateTime;

public record RefreshTokenRecord(
        long id,
        long userId,
        String tokenHash,
        String status,
        OffsetDateTime expiresAt,
        OffsetDateTime createdAt,
        OffsetDateTime revokedAt
) {
}
