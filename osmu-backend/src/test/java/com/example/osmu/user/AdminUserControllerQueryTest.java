package com.example.osmu.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.accesskey.AccessKeyService;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.auth.PasswordService;
import com.example.osmu.auth.RefreshTokenService;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class AdminUserControllerQueryTest {

    private final UserRepository userRepository = mock(UserRepository.class);
    private final OrganizationRepository organizationRepository = mock(OrganizationRepository.class);
    private final PasswordService passwordService = mock(PasswordService.class);
    private final AccessKeyService accessKeyService = mock(AccessKeyService.class);
    private final RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
    private final AuditLogService auditLogService = mock(AuditLogService.class);
    private final AuthContext authContext = mock(AuthContext.class);
    private final HttpServletRequest request = mock(HttpServletRequest.class);
    private AdminUserController controller;

    @BeforeEach
    void setUp() {
        controller = new AdminUserController(
                userRepository,
                organizationRepository,
                passwordService,
                accessKeyService,
                refreshTokenService,
                auditLogService,
                authContext
        );
    }

    @Test
    void adminListPushesFiltersCursorAndLimitIntoRepository() {
        AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);
        when(authContext.currentUser(request)).thenReturn(admin);
        when(userRepository.findPage(null, "alpha", "ACTIVE", 50L, 2)).thenReturn(List.of(
                user(49L, "alpha-two", "ACTIVE", null),
                user(48L, "alpha-one", "ACTIVE", null)
        ));

        ListResponse<UserProfile> response = controller.list(" alpha ", "ACTIVE", 1, "50", request);

        assertThat(response.items()).extracting(UserProfile::id).containsExactly(49L);
        assertThat(response.nextCursor()).isEqualTo("49");
        verify(userRepository).findPage(null, "alpha", "ACTIVE", 50L, 2);

    }

    @Test
    void organizationAdminListPushesOrganizationScopeIntoRepository() {
        AuthenticatedUser orgAdmin = new AuthenticatedUser(7L, "org-admin", "ORG_ADMIN", 70L);
        when(authContext.currentUser(request)).thenReturn(orgAdmin);
        when(userRepository.findPage(70L, null, null, null, 201)).thenReturn(List.of(
                user(8L, "org-user", "ACTIVE", 70L)
        ));

        ListResponse<UserProfile> response = controller.list(null, " ", null, null, request);

        assertThat(response.items()).extracting(UserProfile::loginId).containsExactly("org-user");
        assertThat(response.nextCursor()).isNull();
        verify(userRepository).findPage(70L, null, null, null, 201);

    }

    private UserAccount user(long id, String loginId, String status, Long organizationId) {
        return new UserAccount(
                id,
                loginId,
                loginId + "@example.com",
                loginId,
                "password-hash",
                "USER",
                status,
                organizationId
        );
    }
}