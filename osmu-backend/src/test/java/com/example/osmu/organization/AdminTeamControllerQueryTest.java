package com.example.osmu.organization;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.accesskey.AccessKeyService;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.repository.BucketPermissionRepository;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class AdminTeamControllerQueryTest {

    private final TeamRepository teamRepository = mock(TeamRepository.class);
    private final OrganizationRepository organizationRepository = mock(OrganizationRepository.class);
    private final UserRepository userRepository = mock(UserRepository.class);
    private final BucketPermissionRepository bucketPermissionRepository = mock(BucketPermissionRepository.class);
    private final AccessKeyService accessKeyService = mock(AccessKeyService.class);
    private final AuditLogService auditLogService = mock(AuditLogService.class);
    private final AuthContext authContext = mock(AuthContext.class);
    private final HttpServletRequest request = mock(HttpServletRequest.class);
    private AdminTeamController controller;

    @BeforeEach
    void setUp() {
        controller = new AdminTeamController(
                teamRepository,
                organizationRepository,
                userRepository,
                bucketPermissionRepository,
                accessKeyService,
                auditLogService,
                authContext
        );
    }

    @Test
    void listUsesOrganizationScopeAndOneBulkMemberQuery() {
        AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        List<TeamRecord> teams = List.of(
                new TeamRecord(10L, 100L, "Alpha", "", now, now),
                new TeamRecord(20L, 100L, "Beta", "", now, now),
                new TeamRecord(30L, 100L, "Gamma", "", now, now)
        );
        when(authContext.currentUser(request)).thenReturn(admin);
        when(teamRepository.findPage(100L, null, 3)).thenReturn(teams);
        when(teamRepository.findMemberIdsByTeamIds(List.of(10L, 20L))).thenReturn(Map.of(
                10L, List.of(1L, 2L),
                20L, List.of(3L)
        ));

        ListResponse<TeamResponse> response = controller.list(100L, 2, null, request);

        assertThat(response.items())
                .extracting(TeamResponse::memberIds)
                .containsExactly(List.of(1L, 2L), List.of(3L));
        assertThat(response.nextCursor()).isEqualTo("20");
        verify(teamRepository).findPage(100L, null, 3);
        verify(teamRepository).findMemberIdsByTeamIds(List.of(10L, 20L));

        verify(teamRepository, never()).findMemberIds(anyLong());
    }

    @Test
    void organizationAdminListUsesOwnOrganizationScope() {
        AuthenticatedUser orgAdmin = new AuthenticatedUser(7L, "org-admin", "ORG_ADMIN", 700L);
        when(authContext.currentUser(request)).thenReturn(orgAdmin);
        when(teamRepository.findPage(700L, null, 51)).thenReturn(List.of());

        assertThat(controller.list(null, null, null, request).items()).isEmpty();

        verify(teamRepository).findPage(700L, null, 51);
        verify(teamRepository, never()).findMemberIdsByTeamIds(anyList());

    }

    @Test
    void listRejectsInvalidCursorBeforeQueryingTheRepository() {
        AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);
        when(authContext.currentUser(request)).thenReturn(admin);

        assertThatThrownBy(() -> controller.list(null, null, "not-a-team-id", request))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));

        verify(teamRepository, never()).findPage(any(), any(), anyInt());
    }

    @Test
    void updateMembersUsesOneBulkUserQueryAndPreservesRequestOrder() {
        AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        TeamRecord team = new TeamRecord(10L, 100L, "Alpha", "", now, now);
        UserAccount member20 = user(20L, 100L);
        UserAccount member30 = user(30L, 100L);
        when(authContext.currentUser(request)).thenReturn(admin);
        when(teamRepository.findById(10L)).thenReturn(Optional.of(team));
        when(teamRepository.findMemberIds(10L)).thenReturn(List.of(40L));
        when(userRepository.findByIds(List.of(30L, 20L))).thenReturn(List.of(member20, member30));

        ApiResponse<TeamResponse> response = controller.updateMembers(
                10L,
                new UpdateTeamMembersRequest(List.of(30L, 20L, 30L)),
                request
        );

        assertThat(response.data().memberIds()).containsExactly(30L, 20L);
        verify(userRepository).findByIds(List.of(30L, 20L));
        verify(userRepository, never()).findById(anyLong());
        verify(teamRepository).replaceMembers(10L, List.of(30L, 20L));
        verify(accessKeyService).reconcileActiveKeysForOwners(List.of(40L, 30L, 20L));
    }

    @Test
    void createValidatesMembersBeforePersistingTheTeam() {
        AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        when(authContext.currentUser(request)).thenReturn(admin);
        when(organizationRepository.findById(100L)).thenReturn(Optional.of(
                new OrganizationRecord(100L, "Organization", "", 0L, now)
        ));
        when(teamRepository.existsByOrganizationIdAndName(100L, "Alpha")).thenReturn(false);
        when(userRepository.findByIds(List.of(999L))).thenReturn(List.of());

        assertThatThrownBy(() -> controller.create(
                new CreateTeamRequest(100L, "Alpha", "", List.of(999L)),
                request
        )).isInstanceOfSatisfying(ApiException.class, exception ->
                assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));

        verify(userRepository).findByIds(List.of(999L));
        verify(teamRepository, never()).nextId();
        verify(teamRepository, never()).save(any(TeamRecord.class));
        verify(teamRepository, never()).replaceMembers(anyLong(), anyList());
    }

    private UserAccount user(long id, long organizationId) {
        return new UserAccount(
                id,
                "member-" + id,
                "member-" + id + "@example.com",
                "Member " + id,
                "hash",
                "USER",
                "ACTIVE",
                organizationId
        );
    }
}