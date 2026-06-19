package com.example.osmu.auth;

import com.example.osmu.auth.OidcClaimPreviewResponse.ExistingUser;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.UserRepository;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class OidcClaimPreviewService {

    private final UserRepository userRepository;
    private final String subjectClaim;
    private final String emailClaim;
    private final String nameClaim;
    private final String roleClaim;
    private final String organizationClaim;
    private final String teamClaim;
    private final List<String> allowedDomains;

    public OidcClaimPreviewService(
            UserRepository userRepository,
            @Value("${osmu.enterprise-auth.claims.subject:sub}") String subjectClaim,
            @Value("${osmu.enterprise-auth.claims.email:email}") String emailClaim,
            @Value("${osmu.enterprise-auth.claims.name:name}") String nameClaim,
            @Value("${osmu.enterprise-auth.claims.roles:osmu_roles}") String roleClaim,
            @Value("${osmu.enterprise-auth.claims.organization:osmu_org}") String organizationClaim,
            @Value("${osmu.enterprise-auth.claims.teams:osmu_teams}") String teamClaim,
            @Value("${osmu.enterprise-auth.allowed-domains:}") String allowedDomains
    ) {
        this.userRepository = userRepository;
        this.subjectClaim = fallback(subjectClaim, "sub");
        this.emailClaim = fallback(emailClaim, "email");
        this.nameClaim = fallback(nameClaim, "name");
        this.roleClaim = fallback(roleClaim, "osmu_roles");
        this.organizationClaim = fallback(organizationClaim, "osmu_org");
        this.teamClaim = fallback(teamClaim, "osmu_teams");
        this.allowedDomains = splitCsv(allowedDomains);
    }

    public OidcClaimPreviewResponse preview(Map<String, Object> claims) {
        if (claims == null || claims.isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "OIDC claims are required.");
        }
        List<String> warnings = new ArrayList<>();
        String subject = stringClaim(claims, subjectClaim);
        String email = normalizeEmail(stringClaim(claims, emailClaim));
        String name = stringClaim(claims, nameClaim);
        List<String> roleClaimValues = listClaim(claims.get(roleClaim));
        List<String> mappedRoles = mappedRoles(roleClaimValues);
        String primaryRole = primaryRole(mappedRoles);
        String organization = stringClaim(claims, organizationClaim);
        List<String> teams = listClaim(claims.get(teamClaim));
        boolean allowedDomainMatched = allowedDomainMatched(email);
        ExistingUser existingUser = existingUser(email);

        if (!hasText(subject)) {
            warnings.add("Missing subject claim: " + subjectClaim);
        }
        if (!hasText(email)) {
            warnings.add("Missing email claim: " + emailClaim);
        } else if (!allowedDomainMatched) {
            warnings.add("Email domain is not in OSMU enterprise auth allowlist.");
        }
        if (roleClaimValues.isEmpty()) {
            warnings.add("Missing role claim values; USER role would be used.");
        }
        if (existingUser == null && allowedDomainMatched && hasText(email)) {
            warnings.add("No ACTIVE local user matches this email; JIT provisioning would require admin approval.");
        }

        boolean jitRequired = existingUser == null && allowedDomainMatched && hasText(email);
        boolean approvalRequired = jitRequired;
        String status = status(subject, email, allowedDomainMatched, existingUser, jitRequired);
        return new OidcClaimPreviewResponse(
                status,
                subject,
                email,
                name,
                roleClaimValues,
                mappedRoles,
                primaryRole,
                organization,
                teams,
                allowedDomainMatched,
                existingUser,
                jitRequired,
                approvalRequired,
                List.copyOf(warnings),
                OffsetDateTime.now(),
                0L
        );
    }

    private String status(String subject, String email, boolean allowedDomainMatched, ExistingUser existingUser, boolean jitRequired) {
        if (!hasText(subject) || !hasText(email)) {
            return "MISSING_REQUIRED_CLAIM";
        }
        if (!allowedDomainMatched) {
            return "REJECTED_DOMAIN";
        }
        if (existingUser != null) {
            return "MATCHED_EXISTING_USER";
        }
        if (jitRequired) {
            return "REQUIRES_ADMIN_APPROVAL";
        }
        return "REVIEW";
    }

    private ExistingUser existingUser(String email) {
        if (!hasText(email)) {
            return null;
        }
        Optional<UserAccount> user = userRepository.findByEmail(email)
                .or(() -> userRepository.findAll().stream()
                        .filter(account -> email.equalsIgnoreCase(account.email()))
                        .findFirst());
        return user.filter(account -> "ACTIVE".equals(account.status()))
                .map(account -> new ExistingUser(account.id(), account.loginId(), account.role(), account.status()))
                .orElse(null);
    }

    private List<String> mappedRoles(List<String> externalValues) {
        Set<String> roles = new LinkedHashSet<>();
        for (String externalValue : externalValues) {
            switch (externalValue) {
                case "osmu-admins" -> roles.add("ADMIN");
                case "osmu-org-admins" -> roles.add("ORG_ADMIN");
                case "osmu-auditors" -> roles.add("AUDITOR");
                default -> {
                    if (!externalValue.isBlank()) {
                        roles.add("USER");
                    }
                }
            }
        }
        if (roles.isEmpty()) {
            roles.add("USER");
        }
        return List.copyOf(roles);
    }

    private String primaryRole(List<String> mappedRoles) {
        for (String role : List.of("ADMIN", "ORG_ADMIN", "AUDITOR", "USER")) {
            if (mappedRoles.contains(role)) {
                return role;
            }
        }
        return "USER";
    }

    private boolean allowedDomainMatched(String email) {
        if (!hasText(email) || allowedDomains.isEmpty()) {
            return true;
        }
        int separator = email.lastIndexOf('@');
        String domain = separator >= 0 ? email.substring(separator + 1).toLowerCase(Locale.ROOT) : "";
        return allowedDomains.contains(domain);
    }

    private String stringClaim(Map<String, Object> claims, String key) {
        Object value = claims.get(key);
        if (value instanceof String text && hasText(text)) {
            return text.trim();
        }
        return "";
    }

    private String normalizeEmail(String value) {
        return hasText(value) ? value.trim().toLowerCase(Locale.ROOT) : "";
    }

    private List<String> listClaim(Object value) {
        if (value instanceof String text && hasText(text)) {
            return List.of(text.trim());
        }
        if (value instanceof Collection<?> values) {
            return values.stream()
                    .filter(item -> item instanceof String)
                    .map(item -> ((String) item).trim())
                    .filter(OidcClaimPreviewService::hasText)
                    .distinct()
                    .toList();
        }
        return List.of();
    }

    private static List<String> splitCsv(String value) {
        if (!hasText(value)) {
            return List.of();
        }
        return Arrays.stream(value.split(","))
                .map(OidcClaimPreviewService::clean)
                .filter(OidcClaimPreviewService::hasText)
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
