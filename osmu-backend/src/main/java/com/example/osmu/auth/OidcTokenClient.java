package com.example.osmu.auth;

public interface OidcTokenClient {

    OidcTokenResponse exchangeAuthorizationCode(OidcTokenExchangeRequest request);
}
