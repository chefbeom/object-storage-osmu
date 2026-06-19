package com.example.osmu.auth;

import java.time.OffsetDateTime;

public record OidcAuthorizationState(
        String state,
        String nonce,
        String codeVerifier,
        String redirectUri,
        OffsetDateTime expiresAt
) {
}
