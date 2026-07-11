package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.UserProfile;
import com.example.osmu.user.repository.UserRepository;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class OidcLoginService {

    private final OidcAuthorizationService authorizationService;
    private final OidcTokenClient tokenClient;
    private final OidcIdTokenVerifier idTokenVerifier;
    private final JwtTokenService jwtTokenService;
    private final RefreshTokenService refreshTokenService;
    private final UserRepository userRepository;
    private final boolean callbackEnabled;
    private final String issuerUri;
    private final String clientId;
    private final String clientSecret;
    private final String tokenUri;
    private final String jwksUri;
    private final String redirectUri;
    private final String emailClaim;
    private final List<String> allowedDomains;

    public OidcLoginService(
            OidcAuthorizationService authorizationService,
            OidcTokenClient tokenClient,
            OidcIdTokenVerifier idTokenVerifier,
            JwtTokenService jwtTokenService,
            RefreshTokenService refreshTokenService,
            UserRepository userRepository,
            @Value("${osmu.enterprise-auth.oidc.callback-enabled:false}") boolean callbackEnabled,
            @Value("${osmu.enterprise-auth.oidc.issuer-uri:}") String issuerUri,
            @Value("${osmu.enterprise-auth.oidc.client-id:}") String clientId,
            @Value("${osmu.enterprise-auth.oidc.client-secret:}") String clientSecret,
            @Value("${osmu.enterprise-auth.oidc.token-uri:}") String tokenUri,
            @Value("${osmu.enterprise-auth.oidc.jwks-uri:}") String jwksUri,
            @Value("${osmu.enterprise-auth.oidc.redirect-uri:}") String redirectUri,
            @Value("${osmu.enterprise-auth.claims.email:email}") String emailClaim,
            @Value("${osmu.enterprise-auth.allowed-domains:}") String allowedDomains
    ) {
        this.authorizationService = authorizationService;
        this.tokenClient = tokenClient;
        this.idTokenVerifier = idTokenVerifier;
        this.jwtTokenService = jwtTokenService;
        this.refreshTokenService = refreshTokenService;
        this.userRepository = userRepository;
        this.callbackEnabled = callbackEnabled;
        this.issuerUri = clean(issuerUri);
        this.clientId = clean(clientId);
        this.clientSecret = clean(clientSecret);
        this.tokenUri = clean(tokenUri);
        this.jwksUri = clean(jwksUri);
        this.redirectUri = clean(redirectUri);
        this.emailClaim = fallback(emailClaim, "email");
        this.allowedDomains = splitCsv(allowedDomains);
    }

    public LoginResponse completeAuthorization(String code, String state) {
        validateConfiguration();
        if (!hasText(code) || !hasText(state)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "OIDC code and state are required.");
        }
        OidcAuthorizationState storedState = authorizationService.consumeState(state)
                .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid OIDC state."));
        OidcTokenResponse tokenResponse = tokenClient.exchangeAuthorizationCode(new OidcTokenExchangeRequest(
                tokenUri,
                clientId,
                clientSecret,
                redirectUri,
                code,
                storedState.codeVerifier()
        ));
        OidcIdTokenClaims idTokenClaims = idTokenVerifier.verify(
                tokenResponse.idToken(),
                jwksUri,
                issuerUri,
                clientId,
                storedState.nonce()
        );
        UserProfile profile = findActiveUser(idTokenClaims).toProfile();
        return new LoginResponse(
                jwtTokenService.createAccessToken(profile),
                refreshTokenService.issue(profile),
                profile
        );
    }

    private UserAccount findActiveUser(OidcIdTokenClaims claims) {
        String email = emailFromClaims(claims);
        validateAllowedDomain(email);
        return findUserByEmail(email)
                .filter(user -> "ACTIVE".equals(user.status()))
                .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "OIDC user is not provisioned."));
    }

    private Optional<UserAccount> findUserByEmail(String email) {
        return userRepository.findByEmail(email);
    }

    private String emailFromClaims(OidcIdTokenClaims claims) {
        Object rawEmail = claims.claims().get(emailClaim);
        if (rawEmail instanceof String email && hasText(email)) {
            return email.trim().toLowerCase(Locale.ROOT);
        }
        throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "OIDC email claim is required.");
    }

    private void validateAllowedDomain(String email) {
        if (allowedDomains.isEmpty()) {
            return;
        }
        int separator = email.lastIndexOf('@');
        String domain = separator >= 0 ? email.substring(separator + 1).toLowerCase(Locale.ROOT) : "";
        if (!allowedDomains.contains(domain)) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "OIDC email domain is not allowed.");
        }
    }

    private void validateConfiguration() {
        if (!callbackEnabled) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "OIDC callback is not enabled.");
        }
        require(issuerUri, "osmu.enterprise-auth.oidc.issuer-uri");
        require(clientId, "osmu.enterprise-auth.oidc.client-id");
        require(tokenUri, "osmu.enterprise-auth.oidc.token-uri");
        require(jwksUri, "osmu.enterprise-auth.oidc.jwks-uri");
        require(redirectUri, "osmu.enterprise-auth.oidc.redirect-uri");
    }

    private void require(String value, String propertyName) {
        if (!hasText(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, propertyName + " is required for OIDC callback.");
        }
    }

    private static List<String> splitCsv(String value) {
        if (!hasText(value)) {
            return List.of();
        }
        return Arrays.stream(value.split(","))
                .map(OidcLoginService::clean)
                .filter(OidcLoginService::hasText)
                .map(item -> item.toLowerCase(Locale.ROOT))
                .distinct()
                .toList();
    }

    private static String fallback(String value, String fallback) {
        String cleaned = clean(value);
        return cleaned.isBlank() ? fallback : cleaned;
    }

    private static String clean(String value) {
        return value == null ? "" : value.trim();
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
