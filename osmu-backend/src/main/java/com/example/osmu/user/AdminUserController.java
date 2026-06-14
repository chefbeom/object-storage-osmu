package com.example.osmu.user;

import com.example.osmu.auth.PasswordService;
import com.example.osmu.accesskey.AccessKeyService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.auth.RefreshTokenService;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {

    private final UserRepository userRepository;
    private final OrganizationRepository organizationRepository;
    private final PasswordService passwordService;
    private final AccessKeyService accessKeyService;
    private final RefreshTokenService refreshTokenService;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;

    public AdminUserController(
            UserRepository userRepository,
            OrganizationRepository organizationRepository,
            PasswordService passwordService,
            AccessKeyService accessKeyService,
            RefreshTokenService refreshTokenService,
            AuditLogService auditLogService,
            AuthContext authContext
    ) {
        this.userRepository = userRepository;
        this.organizationRepository = organizationRepository;
        this.passwordService = passwordService;
        this.accessKeyService = accessKeyService;
        this.refreshTokenService = refreshTokenService;
        this.auditLogService = auditLogService;
        this.authContext = authContext;
    }

    @GetMapping
    public ListResponse<UserProfile> list(HttpServletRequest httpRequest) {
        AuthenticatedUser actor = authContext.currentUser(httpRequest);
        List<UserProfile> users = userRepository.findAll().stream()
                .filter(user -> canView(actor, user))
                .map(UserAccount::toProfile)
                .toList();
        return ListResponse.of(users);
    }

    @PostMapping
    public ApiResponse<UserProfile> create(@Valid @RequestBody CreateUserRequest request, HttpServletRequest httpRequest) {
        AuthenticatedUser actor = authContext.currentUser(httpRequest);
        if (userRepository.existsByLoginId(request.loginId())) {
            throw new ApiException(ApiErrorCode.CONFLICT, "User loginId already exists.");
        }
        if (userRepository.existsByEmail(request.email())) {
            throw new ApiException(ApiErrorCode.CONFLICT, "User email already exists.");
        }
        Long organizationId = resolveCreateOrganization(actor, request);
        validateCreateRole(actor, request.role());

        UserAccount user = new UserAccount(
                userRepository.nextId(),
                request.loginId(),
                request.email(),
                request.name(),
                passwordService.hash(request.password()),
                request.role(),
                "ACTIVE",
                organizationId
        );
        UserProfile profile = userRepository.save(user).toProfile();
        auditLogService.record("USER_CREATE", actor.loginId(), "USER", profile.loginId(), "SUCCESS", "User created", httpRequest);
        return ApiResponse.of(profile);
    }

    @PatchMapping("/{userId}/status")
    public ApiResponse<UserProfile> updateStatus(
            @PathVariable("userId") long userId,
            @Valid @RequestBody UpdateUserStatusRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser actor = authContext.currentUser(httpRequest);
        UserAccount user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "User not found."));
        assertCanManage(actor, user);
        int deactivatedAccessKeys = 0;
        if (!"ACTIVE".equals(request.status())) {
            deactivatedAccessKeys = accessKeyService.deactivateByOwnerId(user.id());
            refreshTokenService.revokeAll(user.id());
        }
        UserAccount updated = new UserAccount(
                user.id(),
                user.loginId(),
                user.email(),
                user.name(),
                user.passwordHash(),
                user.role(),
                request.status(),
                user.organizationId()
        );
        UserProfile profile = userRepository.save(updated).toProfile();
        String message = request.status() + "; deactivatedAccessKeys=" + deactivatedAccessKeys;
        auditLogService.record("USER_STATUS_UPDATE", actor.loginId(), "USER", profile.loginId(), "SUCCESS", message, httpRequest);
        return ApiResponse.of(profile);
    }

    private void validateOrganization(Long organizationId) {
        if (organizationId == null) {
            return;
        }
        if (organizationRepository.findById(organizationId).isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Organization not found.");
        }
    }

    private Long resolveCreateOrganization(AuthenticatedUser actor, CreateUserRequest request) {
        if (actor.isAdmin()) {
            validateOrganization(request.organizationId());
            return request.organizationId();
        }
        if (!actor.isOrgAdmin() || actor.organizationId() == null) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "User management denied.");
        }
        if (request.organizationId() != null && request.organizationId().longValue() != actor.organizationId()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Organization access denied.");
        }
        validateOrganization(actor.organizationId());
        return actor.organizationId();
    }

    private void validateCreateRole(AuthenticatedUser actor, String role) {
        if (actor.isAdmin()) {
            return;
        }
        if (!"USER".equals(role)) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Organization admin can create USER only.");
        }
    }

    private boolean canView(AuthenticatedUser actor, UserAccount user) {
        if (actor.isAdmin()) {
            return true;
        }
        return actor.isOrgAdmin()
                && actor.organizationId() != null
                && user.organizationId() != null
                && actor.organizationId().equals(user.organizationId());
    }

    private void assertCanManage(AuthenticatedUser actor, UserAccount user) {
        if (actor.isAdmin()) {
            return;
        }
        if (!actor.isOrgAdmin()
                || actor.organizationId() == null
                || user.organizationId() == null
                || !actor.organizationId().equals(user.organizationId())
                || actor.id() == user.id()
                || "ADMIN".equals(user.role())
                || "ORG_ADMIN".equals(user.role())) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "User management denied.");
        }
    }
}
