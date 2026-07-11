package com.example.osmu.organization;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketOwnerUsageSummary;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.bucket.repository.BucketPermissionRepository;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.dashboard.repository.DashboardLayoutDefaultRepository;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.quota.QuotaPolicyService;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/organizations")
public class AdminOrganizationController {

    private static final long DEFAULT_QUOTA_BYTES = 10L * 1024L * 1024L * 1024L * 1024L;

    private final OrganizationRepository organizationRepository;
    private final BucketService bucketService;
    private final BucketPermissionRepository bucketPermissionRepository;
    private final UserRepository userRepository;
    private final TeamRepository teamRepository;
    private final DashboardLayoutDefaultRepository dashboardLayoutDefaultRepository;
    private final QuotaPolicyService quotaPolicyService;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;

    public AdminOrganizationController(
            OrganizationRepository organizationRepository,
            BucketService bucketService,
            BucketPermissionRepository bucketPermissionRepository,
            UserRepository userRepository,
            TeamRepository teamRepository,
            DashboardLayoutDefaultRepository dashboardLayoutDefaultRepository,
            QuotaPolicyService quotaPolicyService,
            AuditLogService auditLogService,
            AuthContext authContext
    ) {
        this.organizationRepository = organizationRepository;
        this.bucketService = bucketService;
        this.bucketPermissionRepository = bucketPermissionRepository;
        this.userRepository = userRepository;
        this.teamRepository = teamRepository;
        this.dashboardLayoutDefaultRepository = dashboardLayoutDefaultRepository;
        this.quotaPolicyService = quotaPolicyService;
        this.auditLogService = auditLogService;
        this.authContext = authContext;
    }

    @GetMapping
    public ListResponse<OrganizationRecord> list(HttpServletRequest request) {
        AuthenticatedUser actor = authContext.currentUser(request);
        return ListResponse.of(visibleOrganizations(actor));
    }

    @GetMapping("/usage")
    public ListResponse<OrganizationUsageResponse> usage(HttpServletRequest request) {
        AuthenticatedUser actor = authContext.currentUser(request);
        List<OrganizationRecord> organizations = visibleOrganizations(actor);
        Map<Long, BucketOwnerUsageSummary> usageByOrganization = bucketService.summarizeUsageByOwners(
                        "ORG",
                        organizations.stream().map(OrganizationRecord::id).toList()
                ).stream()
                .collect(Collectors.toMap(BucketOwnerUsageSummary::ownerId, summary -> summary));
        List<OrganizationUsageResponse> usage = organizations.stream()
                .map(organization -> usageOf(
                        organization,
                        usageByOrganization.getOrDefault(
                                organization.id(),
                                BucketOwnerUsageSummary.empty(organization.id())
                        )
                ))
                .toList();
        return ListResponse.of(usage);
    }

    @PostMapping
    public ApiResponse<OrganizationRecord> create(
            @Valid @RequestBody CreateOrganizationRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser actor = authContext.currentUser(httpRequest);
        if (!actor.isAdmin()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Organization create denied.");
        }
        String name = request.name().trim();
        if (organizationRepository.existsByName(name)) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Organization already exists.");
        }
        OrganizationRecord organization = new OrganizationRecord(
                organizationRepository.nextId(),
                name,
                request.description() == null ? "" : request.description().trim(),
                request.defaultQuotaBytes() == null ? DEFAULT_QUOTA_BYTES : request.defaultQuotaBytes(),
                OffsetDateTime.now()
        );
        OrganizationRecord saved = organizationRepository.save(organization);
        auditLogService.record("ORGANIZATION_CREATE", actor.loginId(), "ORGANIZATION", saved.name(), "SUCCESS", "Organization created", httpRequest);
        return ApiResponse.of(saved);
    }

    @DeleteMapping("/{organizationId}")
    public ResponseEntity<Void> delete(
            @PathVariable("organizationId") long organizationId,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        if (!actor.isAdmin()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Organization delete denied.");
        }
        OrganizationRecord organization = organizationRepository.findById(organizationId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Organization not found."));
        if (bucketService.hasBucketsOwnedBy("ORG", organization.id())) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Organization has buckets.");
        }
        if (userRepository.existsByOrganizationId(organization.id())) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Organization has users.");
        }
        if (teamRepository.existsByOrganizationId(organization.id())) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Organization has teams.");
        }
        organizationRepository.deleteById(organization.id());
        boolean defaultRemoved = dashboardLayoutDefaultRepository.deleteByTarget("ORGANIZATION", String.valueOf(organization.id()));
        if (defaultRemoved) {
            auditLogService.record("DASHBOARD_LAYOUT_DEFAULT_DELETE", actor.loginId(), "DASHBOARD_LAYOUT_DEFAULT", "ORGANIZATION:" + organization.id(), "SUCCESS", "Organization dashboard default deleted", request);
        }
        deleteOrganizationQuotaPolicy(actor, organization);
        int permissionsRemoved = bucketPermissionRepository.deleteBySubject("ORGANIZATION", organization.id());
        if (permissionsRemoved > 0) {
            auditLogService.record("BUCKET_PERMISSION_SUBJECT_CLEANUP", actor.loginId(), "ORGANIZATION", String.valueOf(organization.id()), "SUCCESS", "Organization bucket permissions deleted: " + permissionsRemoved, request);
        }
        auditLogService.record("ORGANIZATION_DELETE", actor.loginId(), "ORGANIZATION", organization.name(), "SUCCESS", "Organization deleted", request);
        return ResponseEntity.noContent().build();
    }

    private void deleteOrganizationQuotaPolicy(AuthenticatedUser actor, OrganizationRecord organization) {
        try {
            quotaPolicyService.delete("ORGANIZATION", organization.id(), actor.loginId(), "Organization deleted");
        } catch (ApiException exception) {
            if (exception.code() != ApiErrorCode.NOT_FOUND) {
                throw exception;
            }
        }
    }

    private List<OrganizationRecord> visibleOrganizations(AuthenticatedUser actor) {
        if (actor.isAdmin()) {
            return organizationRepository.findAll();
        }
        if (actor.isOrgAdmin() && actor.organizationId() != null) {
            OrganizationRecord organization = organizationRepository.findById(actor.organizationId())
                    .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Organization access denied."));
            return List.of(organization);
        }
        throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Organization access denied.");
    }

    private OrganizationUsageResponse usageOf(
            OrganizationRecord organization,
            BucketOwnerUsageSummary bucketUsage
    ) {
        long quotaLimit = organization.defaultQuotaBytes() > 0
                ? organization.defaultQuotaBytes()
                : bucketUsage.totalQuotaBytes();
        return new OrganizationUsageResponse(
                organization.id(),
                organization.name(),
                organization.defaultQuotaBytes(),
                bucketUsage.totalQuotaBytes(),
                bucketUsage.totalUsedBytes(),
                Math.max(0L, quotaLimit - bucketUsage.totalUsedBytes()),
                bucketUsage.bucketCount(),
                bucketUsage.totalObjectCount()
        );
    }
}
