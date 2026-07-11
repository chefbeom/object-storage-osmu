package com.example.osmu.organization;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketOwnerUsageSummary;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.bucket.repository.BucketPermissionRepository;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.dashboard.repository.DashboardLayoutDefaultRepository;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.quota.QuotaPolicyService;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class AdminOrganizationControllerQueryTest {

    private final OrganizationRepository organizationRepository = mock(OrganizationRepository.class);
    private final BucketService bucketService = mock(BucketService.class);
    private final BucketPermissionRepository bucketPermissionRepository = mock(BucketPermissionRepository.class);
    private final UserRepository userRepository = mock(UserRepository.class);
    private final TeamRepository teamRepository = mock(TeamRepository.class);
    private final DashboardLayoutDefaultRepository dashboardLayoutDefaultRepository =
            mock(DashboardLayoutDefaultRepository.class);
    private final QuotaPolicyService quotaPolicyService = mock(QuotaPolicyService.class);
    private final AuditLogService auditLogService = mock(AuditLogService.class);
    private final AuthContext authContext = mock(AuthContext.class);
    private final HttpServletRequest request = mock(HttpServletRequest.class);
    private final AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);
    private AdminOrganizationController controller;

    @BeforeEach
    void setUp() {
        controller = new AdminOrganizationController(
                organizationRepository,
                bucketService,
                bucketPermissionRepository,
                userRepository,
                teamRepository,
                dashboardLayoutDefaultRepository,
                quotaPolicyService,
                auditLogService,
                authContext
        );
        when(authContext.currentUser(request)).thenReturn(admin);
    }

    @Test
    void usageUsesOneOwnerAggregateInsteadOfLoadingAllBuckets() {
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        OrganizationRecord first = new OrganizationRecord(10L, "First", "", 2_000L, now);
        OrganizationRecord second = new OrganizationRecord(20L, "Second", "", 3_000L, now);
        when(organizationRepository.findAll()).thenReturn(List.of(first, second));
        when(bucketService.summarizeUsageByOwners("ORG", List.of(10L, 20L))).thenReturn(List.of(
                new BucketOwnerUsageSummary(10L, 2L, 1_000L, 600L, 6L)
        ));

        ListResponse<OrganizationUsageResponse> response = controller.usage(request);

        assertThat(response.items()).containsExactly(
                new OrganizationUsageResponse(10L, "First", 2_000L, 1_000L, 600L, 1_400L, 2L, 6L),
                new OrganizationUsageResponse(20L, "Second", 3_000L, 0L, 0L, 3_000L, 0L, 0L)
        );
        verify(bucketService).summarizeUsageByOwners("ORG", List.of(10L, 20L));
        verify(bucketService, never()).list();
    }

    @Test
    void deleteUsesIndexedExistenceChecksInsteadOfLoadingCollections() {
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        OrganizationRecord organization = new OrganizationRecord(30L, "Delete", "", 1_000L, now);
        when(organizationRepository.findById(30L)).thenReturn(Optional.of(organization));

        assertThat(controller.delete(30L, request).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        verify(bucketService).hasBucketsOwnedBy("ORG", 30L);
        verify(userRepository).existsByOrganizationId(30L);
        verify(teamRepository).existsByOrganizationId(30L);
        verify(bucketService, never()).list();

    }
}