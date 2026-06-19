package com.example.osmu.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.osmu.auth.repository.InMemoryRefreshTokenRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.BootstrapAdminProperties;
import com.example.osmu.user.repository.InMemoryUserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.security.interfaces.RSAPublicKey;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;

class OidcLoginServiceTest {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final String ISSUER = "https://idp.example.com/realms/osmu";
    private static final String CLIENT_ID = "osmu-web";
    private static final String AUTHORIZATION_URI = ISSUER + "/protocol/openid-connect/auth";
    private static final String TOKEN_URI = ISSUER + "/protocol/openid-connect/token";
    private static final String JWKS_URI = ISSUER + "/protocol/openid-connect/certs";
    private static final String REDIRECT_URI = "http://localhost:5173/auth/oidc/callback";

    @Test
    void callbackExchangesCodeVerifiesIdTokenAndIssuesOsmuTokensForExistingUser() throws Exception {
        KeyPair keyPair = rsaKeyPair();
        OidcAuthorizationService authorizationService = authorizationService();
        OidcAuthorizationResponse authorization = authorizationService.beginAuthorization();
        OidcAuthorizationState storedState = authorizationService.findState(authorization.state()).orElseThrow();
        String idToken = idToken(keyPair, "kid-1", storedState.nonce(), "admin@example.com");
        AtomicReference<OidcTokenExchangeRequest> exchangeRequest = new AtomicReference<>();
        OidcLoginService service = loginService(
                authorizationService,
                request -> {
                    exchangeRequest.set(request);
                    return new OidcTokenResponse(null, idToken, "Bearer", 300L, null, "openid profile email");
                },
                uri -> jwks(keyPair, "kid-1"),
                "example.com"
        );

        LoginResponse response = service.completeAuthorization("auth-code", authorization.state());

        assertThat(response.user().loginId()).isEqualTo("admin");
        assertThat(response.user().role()).isEqualTo("ADMIN");
        assertThat(response.accessToken()).isNotBlank();
        assertThat(response.refreshToken()).isNotBlank();
        assertThat(exchangeRequest.get().code()).isEqualTo("auth-code");
        assertThat(exchangeRequest.get().codeVerifier()).isEqualTo(storedState.codeVerifier());
        assertThat(authorizationService.findState(authorization.state())).isEmpty();
    }

    @Test
    void callbackRejectsReplayStateAfterSuccessfulConsume() throws Exception {
        KeyPair keyPair = rsaKeyPair();
        OidcAuthorizationService authorizationService = authorizationService();
        OidcAuthorizationResponse authorization = authorizationService.beginAuthorization();
        OidcAuthorizationState storedState = authorizationService.findState(authorization.state()).orElseThrow();
        String idToken = idToken(keyPair, "kid-1", storedState.nonce(), "admin@example.com");
        OidcLoginService service = loginService(
                authorizationService,
                request -> new OidcTokenResponse(null, idToken, "Bearer", 300L, null, "openid profile email"),
                uri -> jwks(keyPair, "kid-1"),
                "example.com"
        );

        service.completeAuthorization("auth-code", authorization.state());

        assertThatThrownBy(() -> service.completeAuthorization("auth-code", authorization.state()))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.AUTHENTICATION_REQUIRED));
    }

    @Test
    void callbackRejectsDisallowedEmailDomain() throws Exception {
        KeyPair keyPair = rsaKeyPair();
        OidcAuthorizationService authorizationService = authorizationService();
        OidcAuthorizationResponse authorization = authorizationService.beginAuthorization();
        OidcAuthorizationState storedState = authorizationService.findState(authorization.state()).orElseThrow();
        String idToken = idToken(keyPair, "kid-1", storedState.nonce(), "admin@example.com");
        OidcLoginService service = loginService(
                authorizationService,
                request -> new OidcTokenResponse(null, idToken, "Bearer", 300L, null, "openid profile email"),
                uri -> jwks(keyPair, "kid-1"),
                "corp.example.com"
        );

        assertThatThrownBy(() -> service.completeAuthorization("auth-code", authorization.state()))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.AUTHENTICATION_REQUIRED));
    }

    private OidcLoginService loginService(
            OidcAuthorizationService authorizationService,
            OidcTokenClient tokenClient,
            OidcJwksClient jwksClient,
            String allowedDomains
    ) {
        JwtTokenService jwtTokenService = new JwtTokenService(
                "0123456789abcdef0123456789abcdef",
                "osmu",
                3600,
                604800
        );
        RefreshTokenService refreshTokenService = new RefreshTokenService(
                new InMemoryRefreshTokenRepository(),
                jwtTokenService
        );
        InMemoryUserRepository userRepository = new InMemoryUserRepository(
                new PasswordService(),
                new BootstrapAdminProperties(true, true, "admin", "password", "admin@example.com", "Admin")
        );
        return new OidcLoginService(
                authorizationService,
                tokenClient,
                new OidcIdTokenVerifier(OBJECT_MAPPER, jwksClient),
                jwtTokenService,
                refreshTokenService,
                userRepository,
                true,
                ISSUER,
                CLIENT_ID,
                "client-secret",
                TOKEN_URI,
                JWKS_URI,
                REDIRECT_URI,
                "email",
                allowedDomains
        );
    }

    private OidcAuthorizationService authorizationService() {
        return new OidcAuthorizationService(
                true,
                ISSUER,
                CLIENT_ID,
                AUTHORIZATION_URI,
                REDIRECT_URI,
                "openid profile email",
                300
        );
    }

    private KeyPair rsaKeyPair() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        return generator.generateKeyPair();
    }

    private Map<String, Object> jwks(KeyPair keyPair, String kid) {
        RSAPublicKey publicKey = (RSAPublicKey) keyPair.getPublic();
        return Map.of("keys", List.of(Map.of(
                "kty", "RSA",
                "kid", kid,
                "alg", "RS256",
                "use", "sig",
                "n", base64Url(unsigned(publicKey.getModulus())),
                "e", base64Url(unsigned(publicKey.getPublicExponent()))
        )));
    }

    private String idToken(KeyPair keyPair, String kid, String nonce, String email) throws Exception {
        Map<String, Object> header = Map.of(
                "alg", "RS256",
                "typ", "JWT",
                "kid", kid
        );
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("iss", ISSUER);
        payload.put("sub", "oidc-admin-1");
        payload.put("aud", CLIENT_ID);
        payload.put("email", email);
        payload.put("name", "Admin");
        payload.put("nonce", nonce);
        payload.put("iat", Instant.now().getEpochSecond());
        payload.put("exp", Instant.now().plusSeconds(300).getEpochSecond());
        String unsignedToken = encodeJson(header) + "." + encodeJson(payload);
        Signature signature = Signature.getInstance("SHA256withRSA");
        signature.initSign(keyPair.getPrivate());
        signature.update(unsignedToken.getBytes(StandardCharsets.US_ASCII));
        return unsignedToken + "." + BASE64_URL_ENCODER.encodeToString(signature.sign());
    }

    private String encodeJson(Map<String, Object> value) throws Exception {
        return BASE64_URL_ENCODER.encodeToString(OBJECT_MAPPER.writeValueAsBytes(value));
    }

    private String base64Url(byte[] value) {
        return BASE64_URL_ENCODER.encodeToString(value);
    }

    private byte[] unsigned(BigInteger value) {
        byte[] bytes = value.toByteArray();
        if (bytes.length > 1 && bytes[0] == 0) {
            return java.util.Arrays.copyOfRange(bytes, 1, bytes.length);
        }
        return bytes;
    }
}
