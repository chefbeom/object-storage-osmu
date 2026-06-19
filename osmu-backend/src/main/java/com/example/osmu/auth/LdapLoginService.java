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
public class LdapLoginService {

    private final LdapClient ldapClient;
    private final JwtTokenService jwtTokenService;
    private final RefreshTokenService refreshTokenService;
    private final UserRepository userRepository;
    private final boolean loginEnabled;
    private final String url;
    private final String bindDn;
    private final String bindPassword;
    private final String baseDn;
    private final String userSearchFilter;
    private final String emailAttribute;
    private final String displayNameAttribute;
    private final int connectTimeoutMs;
    private final int readTimeoutMs;
    private final List<String> allowedDomains;

    public LdapLoginService(
            LdapClient ldapClient,
            JwtTokenService jwtTokenService,
            RefreshTokenService refreshTokenService,
            UserRepository userRepository,
            @Value("${osmu.enterprise-auth.ldap.login-enabled:false}") boolean loginEnabled,
            @Value("${osmu.enterprise-auth.ldap.url:}") String url,
            @Value("${osmu.enterprise-auth.ldap.bind-dn:}") String bindDn,
            @Value("${osmu.enterprise-auth.ldap.bind-password:}") String bindPassword,
            @Value("${osmu.enterprise-auth.ldap.base-dn:}") String baseDn,
            @Value("${osmu.enterprise-auth.ldap.user-search-filter:}") String userSearchFilter,
            @Value("${osmu.enterprise-auth.ldap.email-attribute:mail}") String emailAttribute,
            @Value("${osmu.enterprise-auth.ldap.display-name-attribute:displayName}") String displayNameAttribute,
            @Value("${osmu.enterprise-auth.ldap.connect-timeout-ms:3000}") int connectTimeoutMs,
            @Value("${osmu.enterprise-auth.ldap.read-timeout-ms:3000}") int readTimeoutMs,
            @Value("${osmu.enterprise-auth.allowed-domains:}") String allowedDomains
    ) {
        this.ldapClient = ldapClient;
        this.jwtTokenService = jwtTokenService;
        this.refreshTokenService = refreshTokenService;
        this.userRepository = userRepository;
        this.loginEnabled = loginEnabled;
        this.url = clean(url);
        this.bindDn = clean(bindDn);
        this.bindPassword = bindPassword == null ? "" : bindPassword;
        this.baseDn = clean(baseDn);
        this.userSearchFilter = fallback(userSearchFilter, "(&(objectClass=person)(|(uid={0})(sAMAccountName={0})(mail={0})))");
        this.emailAttribute = fallback(emailAttribute, "mail");
        this.displayNameAttribute = fallback(displayNameAttribute, "displayName");
        this.connectTimeoutMs = normalizeTimeout(connectTimeoutMs);
        this.readTimeoutMs = normalizeTimeout(readTimeoutMs);
        this.allowedDomains = splitCsv(allowedDomains);
    }

    public LoginResponse login(LdapLoginRequest request) {
        validateConfiguration();
        if (request == null || !hasText(request.loginId()) || !hasText(request.password())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "LDAP loginId and password are required.");
        }
        String loginId = request.loginId().trim();
        LdapUserRecord ldapUser = ldapClient.searchUser(new LdapSearchRequest(
                url,
                bindDn,
                bindPassword,
                baseDn,
                userSearchFilter,
                loginId,
                emailAttribute,
                displayNameAttribute,
                connectTimeoutMs,
                readTimeoutMs
        ));
        ldapClient.bind(new LdapBindRequest(
                url,
                ldapUser.dn(),
                request.password(),
                connectTimeoutMs,
                readTimeoutMs
        ));
        UserProfile profile = findActiveUser(ldapUser).toProfile();
        return new LoginResponse(
                jwtTokenService.createAccessToken(profile),
                refreshTokenService.issue(profile),
                profile
        );
    }

    private UserAccount findActiveUser(LdapUserRecord ldapUser) {
        String email = normalizedEmail(ldapUser.email());
        validateAllowedDomain(email);
        return findUserByEmail(email)
                .filter(user -> "ACTIVE".equals(user.status()))
                .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "LDAP user is not provisioned."));
    }

    private Optional<UserAccount> findUserByEmail(String email) {
        return userRepository.findByEmail(email)
                .or(() -> userRepository.findAll().stream()
                        .filter(user -> email.equalsIgnoreCase(user.email()))
                        .findFirst());
    }

    private String normalizedEmail(String email) {
        if (!hasText(email)) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "LDAP email attribute is required.");
        }
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private void validateAllowedDomain(String email) {
        if (allowedDomains.isEmpty()) {
            return;
        }
        int separator = email.lastIndexOf('@');
        String domain = separator >= 0 ? email.substring(separator + 1).toLowerCase(Locale.ROOT) : "";
        if (!allowedDomains.contains(domain)) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "LDAP email domain is not allowed.");
        }
    }

    private void validateConfiguration() {
        if (!loginEnabled) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "LDAP login is not enabled.");
        }
        require(url, "osmu.enterprise-auth.ldap.url");
        require(baseDn, "osmu.enterprise-auth.ldap.base-dn");
        require(userSearchFilter, "osmu.enterprise-auth.ldap.user-search-filter");
        require(emailAttribute, "osmu.enterprise-auth.ldap.email-attribute");
        if (!userSearchFilter.contains("{0}")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "LDAP user search filter must include {0}.");
        }
    }

    private void require(String value, String propertyName) {
        if (!hasText(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, propertyName + " is required for LDAP login.");
        }
    }

    private static int normalizeTimeout(int timeoutMs) {
        if (timeoutMs < 500) {
            return 500;
        }
        return Math.min(timeoutMs, 30000);
    }

    private static List<String> splitCsv(String value) {
        if (!hasText(value)) {
            return List.of();
        }
        return Arrays.stream(value.split(","))
                .map(LdapLoginService::clean)
                .filter(LdapLoginService::hasText)
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
