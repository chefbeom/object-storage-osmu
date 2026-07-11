package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.UserProfile;
import com.example.osmu.user.repository.UserRepository;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Locale;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
public class OidcJitProvisioningService {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final OidcClaimPreviewService claimPreviewService;
    private final UserRepository userRepository;
    private final OrganizationRepository organizationRepository;
    private final PasswordService passwordService;

    public OidcJitProvisioningService(
            OidcClaimPreviewService claimPreviewService,
            UserRepository userRepository,
            OrganizationRepository organizationRepository,
            PasswordService passwordService
    ) {
        this.claimPreviewService = claimPreviewService;
        this.userRepository = userRepository;
        this.organizationRepository = organizationRepository;
        this.passwordService = passwordService;
    }

    public OidcJitProvisionResponse provision(OidcJitProvisionRequest request) {
        if (request == null || request.claims() == null || request.claims().isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "OIDC claims are required.");
        }
        String approvedRole = normalizeRole(request.approvedRole());
        OidcClaimPreviewResponse preview = claimPreviewService.preview(request.claims());
        assertPreviewCanProvision(preview);
        UserAccount existingUser = existingUser(preview);
        if (existingUser != null) {
            return response("ALREADY_PROVISIONED", existingUser.toProfile(), preview, approvedRole, request, existingUser.organizationId());
        }
        assertEmailNotAssignedToInactiveUser(preview.email());
        assertRoleApproved(preview, approvedRole, Boolean.TRUE.equals(request.approvePrivilegedRole()));
        Long organizationId = validatedOrganizationId(approvedRole, request.organizationId());
        String loginId = uniqueLoginId(preview.email());
        String displayName = hasText(preview.name()) ? preview.name() : loginId;
        UserAccount user = new UserAccount(
                userRepository.nextId(),
                loginId,
                preview.email(),
                displayName,
                passwordService.hash(randomPassword()),
                approvedRole,
                "ACTIVE",
                organizationId
        );
        UserProfile profile = userRepository.save(user).toProfile();
        return response("PROVISIONED", profile, preview, approvedRole, request, organizationId);
    }

    private void assertPreviewCanProvision(OidcClaimPreviewResponse preview) {
        if ("MISSING_REQUIRED_CLAIM".equals(preview.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "OIDC required claims are missing.");
        }
        if (!preview.allowedDomainMatched()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "OIDC email domain is not allowed.");
        }
        if (!hasText(preview.email())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "OIDC email claim is required.");
        }
    }

    private UserAccount existingUser(OidcClaimPreviewResponse preview) {
        if (preview.existingUser() != null) {
            return userRepository.findById(preview.existingUser().id()).orElse(null);
        }
        return findByEmailIgnoreCase(preview.email())
                .filter(user -> "ACTIVE".equals(user.status()))
                .orElse(null);
    }

    private void assertEmailNotAssignedToInactiveUser(String email) {
        findByEmailIgnoreCase(email)
                .filter(user -> !"ACTIVE".equals(user.status()))
                .ifPresent(user -> {
                    throw new ApiException(ApiErrorCode.CONFLICT, "OIDC email is already assigned to a non-active local user.");
                });
    }

    private Optional<UserAccount> findByEmailIgnoreCase(String email) {
        return userRepository.findByEmail(email);
    }

    private void assertRoleApproved(OidcClaimPreviewResponse preview, String approvedRole, boolean approvePrivilegedRole) {
        if (!hasText(approvedRole)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Approved role is required.");
        }
        if (!isSupportedRole(approvedRole)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Approved role is invalid.");
        }
        if (!"USER".equals(approvedRole) && !preview.mappedRoles().contains(approvedRole)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Approved role must be USER or one of the mapped OIDC roles.");
        }
        if (!"USER".equals(approvedRole) && !approvePrivilegedRole) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Privileged OIDC role provisioning requires explicit approval.");
        }
    }

    private Long validatedOrganizationId(String approvedRole, Long organizationId) {
        if ("ORG_ADMIN".equals(approvedRole) && organizationId == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Organization is required for ORG_ADMIN provisioning.");
        }
        if (organizationId == null) {
            return null;
        }
        if (organizationRepository.findById(organizationId).isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Organization not found.");
        }
        return organizationId;
    }

    private OidcJitProvisionResponse response(
            String status,
            UserProfile profile,
            OidcClaimPreviewResponse preview,
            String approvedRole,
            OidcJitProvisionRequest request,
            Long organizationId
    ) {
        return new OidcJitProvisionResponse(
                status,
                profile,
                preview,
                approvedRole,
                organizationId,
                Boolean.TRUE.equals(request.approvePrivilegedRole()),
                0L
        );
    }

    private String uniqueLoginId(String email) {
        String base = normalizeLoginId(email);
        String candidate = base;
        int suffix = 2;
        while (userRepository.existsByLoginId(candidate)) {
            String suffixText = "-" + suffix++;
            candidate = trimForSuffix(base, suffixText) + suffixText;
        }
        return candidate;
    }

    private String normalizeLoginId(String email) {
        String localPart = email;
        int separator = email.indexOf('@');
        if (separator > 0) {
            localPart = email.substring(0, separator);
        }
        String normalized = localPart.toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9._-]", ".")
                .replaceAll("\\.+", ".")
                .replaceAll("^[._-]+|[._-]+$", "");
        if (!hasText(normalized)) {
            normalized = "oidc-user";
        }
        return normalized.length() > 100 ? normalized.substring(0, 100) : normalized;
    }

    private String trimForSuffix(String base, String suffix) {
        int maxBaseLength = Math.max(1, 100 - suffix.length());
        return base.length() > maxBaseLength ? base.substring(0, maxBaseLength) : base;
    }

    private String randomPassword() {
        byte[] bytes = new byte[32];
        SECURE_RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String normalizeRole(String role) {
        return role == null ? "" : role.trim().toUpperCase(Locale.ROOT);
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private static boolean isSupportedRole(String role) {
        return "ADMIN".equals(role)
                || "ORG_ADMIN".equals(role)
                || "AUDITOR".equals(role)
                || "USER".equals(role);
    }
}
