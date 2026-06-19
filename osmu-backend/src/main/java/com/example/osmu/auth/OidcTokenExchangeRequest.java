package com.example.osmu.auth;

public record OidcTokenExchangeRequest(
        String tokenUri,
        String clientId,
        String clientSecret,
        String redirectUri,
        String code,
        String codeVerifier
) {
}
