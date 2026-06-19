package com.example.osmu.auth;

import java.util.Map;

public record OidcIdTokenClaims(
        String subject,
        String issuer,
        String email,
        String name,
        String nonce,
        Map<String, Object> claims
) {
}
