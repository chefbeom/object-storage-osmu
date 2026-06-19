package com.example.osmu.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import org.junit.jupiter.api.Test;

class OidcAuthorizationServiceTest {

    @Test
    void disabledAuthorizationEndpointFailsClosed() {
        OidcAuthorizationService service = new OidcAuthorizationService(
                false,
                "https://idp.example.com/realms/osmu",
                "osmu-web",
                "https://idp.example.com/realms/osmu/protocol/openid-connect/auth",
                "http://localhost:5173/auth/oidc/callback",
                "openid profile email",
                300
        );

        assertThatThrownBy(service::beginAuthorization)
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));
    }

    @Test
    void beginAuthorizationBuildsStateNonceAndPkceChallenge() {
        OidcAuthorizationService service = new OidcAuthorizationService(
                true,
                "https://idp.example.com/realms/osmu",
                "osmu-web",
                "https://idp.example.com/realms/osmu/protocol/openid-connect/auth",
                "http://localhost:5173/auth/oidc/callback",
                "openid,profile,email",
                300
        );

        OidcAuthorizationResponse response = service.beginAuthorization();
        OidcAuthorizationState storedState = service.findState(response.state()).orElseThrow();

        assertThat(response.authorizationUrl())
                .startsWith("https://idp.example.com/realms/osmu/protocol/openid-connect/auth?")
                .contains("response_type=code")
                .contains("client_id=osmu-web")
                .contains("redirect_uri=http%3A%2F%2Flocalhost%3A5173%2Fauth%2Foidc%2Fcallback")
                .contains("scope=openid+profile+email")
                .contains("state=" + response.state())
                .contains("nonce=" + response.nonce())
                .contains("code_challenge=" + response.codeChallenge())
                .contains("code_challenge_method=S256");
        assertThat(response.codeChallengeMethod()).isEqualTo("S256");
        assertThat(response.scopes()).containsExactly("openid", "profile", "email");
        assertThat(storedState.nonce()).isEqualTo(response.nonce());
        assertThat(storedState.redirectUri()).isEqualTo("http://localhost:5173/auth/oidc/callback");
        assertThat(storedState.codeVerifier()).isNotBlank();
        assertThat(response.codeChallenge()).isNotEqualTo(storedState.codeVerifier());
    }
}
