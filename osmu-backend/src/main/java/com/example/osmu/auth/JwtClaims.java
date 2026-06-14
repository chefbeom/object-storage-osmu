package com.example.osmu.auth;

public record JwtClaims(
        String subject,
        String loginId,
        String role,
        String tokenType,
        long expiresAt
) {
}
