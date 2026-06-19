package com.example.osmu.auth;

import java.time.OffsetDateTime;
import java.util.List;

public record OidcAuthorizationResponse(
        String authorizationUrl,
        String state,
        String nonce,
        String codeChallenge,
        String codeChallengeMethod,
        String redirectUri,
        List<String> scopes,
        OffsetDateTime expiresAt
) {
}
