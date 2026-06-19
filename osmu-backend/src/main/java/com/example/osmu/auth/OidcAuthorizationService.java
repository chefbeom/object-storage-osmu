package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class OidcAuthorizationService {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();

    private final Map<String, OidcAuthorizationState> states = new ConcurrentHashMap<>();
    private final boolean authorizationEnabled;
    private final String issuerUri;
    private final String clientId;
    private final String authorizationUri;
    private final String redirectUri;
    private final List<String> scopes;
    private final long stateTtlSeconds;

    public OidcAuthorizationService(
            @Value("${osmu.enterprise-auth.oidc.authorization-enabled:false}") boolean authorizationEnabled,
            @Value("${osmu.enterprise-auth.oidc.issuer-uri:}") String issuerUri,
            @Value("${osmu.enterprise-auth.oidc.client-id:}") String clientId,
            @Value("${osmu.enterprise-auth.oidc.authorization-uri:}") String authorizationUri,
            @Value("${osmu.enterprise-auth.oidc.redirect-uri:}") String redirectUri,
            @Value("${osmu.enterprise-auth.oidc.scopes:openid,profile,email}") String scopes,
            @Value("${osmu.enterprise-auth.oidc.state-ttl-seconds:300}") long stateTtlSeconds
    ) {
        this.authorizationEnabled = authorizationEnabled;
        this.issuerUri = clean(issuerUri);
        this.clientId = clean(clientId);
        this.authorizationUri = clean(authorizationUri);
        this.redirectUri = clean(redirectUri);
        this.scopes = parseScopes(scopes);
        this.stateTtlSeconds = Math.max(60L, stateTtlSeconds);
    }

    public OidcAuthorizationResponse beginAuthorization() {
        validateConfiguration();
        cleanupExpiredStates();
        String state = randomToken(32);
        String nonce = randomToken(32);
        String codeVerifier = randomToken(64);
        String codeChallenge = sha256Base64Url(codeVerifier);
        OffsetDateTime expiresAt = OffsetDateTime.now().plusSeconds(stateTtlSeconds);
        states.put(state, new OidcAuthorizationState(state, nonce, codeVerifier, redirectUri, expiresAt));
        return new OidcAuthorizationResponse(
                authorizationUrl(state, nonce, codeChallenge),
                state,
                nonce,
                codeChallenge,
                "S256",
                redirectUri,
                scopes,
                expiresAt
        );
    }

    public Optional<OidcAuthorizationState> findState(String state) {
        if (state == null || state.isBlank()) {
            return Optional.empty();
        }
        cleanupExpiredStates();
        return Optional.ofNullable(states.get(state));
    }

    public Optional<OidcAuthorizationState> consumeState(String state) {
        if (state == null || state.isBlank()) {
            return Optional.empty();
        }
        cleanupExpiredStates();
        return Optional.ofNullable(states.remove(state));
    }

    private void validateConfiguration() {
        if (!authorizationEnabled) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "OIDC authorization is not enabled.");
        }
        require(issuerUri, "osmu.enterprise-auth.oidc.issuer-uri");
        require(clientId, "osmu.enterprise-auth.oidc.client-id");
        require(authorizationUri, "osmu.enterprise-auth.oidc.authorization-uri");
        require(redirectUri, "osmu.enterprise-auth.oidc.redirect-uri");
        if (scopes.isEmpty() || !scopes.contains("openid")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "OIDC scopes must include openid.");
        }
    }

    private String authorizationUrl(String state, String nonce, String codeChallenge) {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("response_type", "code");
        params.put("client_id", clientId);
        params.put("redirect_uri", redirectUri);
        params.put("scope", String.join(" ", scopes));
        params.put("state", state);
        params.put("nonce", nonce);
        params.put("code_challenge", codeChallenge);
        params.put("code_challenge_method", "S256");
        StringBuilder builder = new StringBuilder(authorizationUri);
        builder.append(authorizationUri.contains("?") ? "&" : "?");
        boolean first = true;
        for (Map.Entry<String, String> entry : params.entrySet()) {
            if (!first) {
                builder.append("&");
            }
            first = false;
            builder.append(urlEncode(entry.getKey()))
                    .append("=")
                    .append(urlEncode(entry.getValue()));
        }
        return builder.toString();
    }

    private void cleanupExpiredStates() {
        OffsetDateTime now = OffsetDateTime.now();
        states.entrySet().removeIf(entry -> !entry.getValue().expiresAt().isAfter(now));
    }

    private static void require(String value, String propertyName) {
        if (value == null || value.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, propertyName + " is required for OIDC authorization.");
        }
    }

    private static String sha256Base64Url(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.US_ASCII));
            return BASE64_URL_ENCODER.encodeToString(digest);
        } catch (Exception exception) {
            throw new IllegalStateException("Failed to build OIDC PKCE challenge.", exception);
        }
    }

    private static String randomToken(int byteLength) {
        byte[] bytes = new byte[byteLength];
        SECURE_RANDOM.nextBytes(bytes);
        return BASE64_URL_ENCODER.encodeToString(bytes);
    }

    private static List<String> parseScopes(String value) {
        if (value == null || value.isBlank()) {
            return List.of("openid", "profile", "email");
        }
        return Arrays.stream(value.split("[,\\s]+"))
                .map(OidcAuthorizationService::clean)
                .filter(scope -> !scope.isBlank())
                .distinct()
                .toList();
    }

    private static String urlEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    private static String clean(String value) {
        return value == null ? "" : value.trim();
    }
}
