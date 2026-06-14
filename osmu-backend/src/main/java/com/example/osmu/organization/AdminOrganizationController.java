package com.example.osmu.organization;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.OffsetDateTime;
import java.util.List;
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
    private final UserRepository userRepository;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;

    public AdminOrganizationController(
            OrganizationRepository organizationRepository,
            BucketService bucketService,
            UserRepository userRepository,
            AuditLogService auditLogService,
            AuthContext authContext
    ) {
        this.organizationRepository = organizationRepository;
        this.bucketService = bucketService;
        this.userRepository = userRepository;
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
        List<BucketRecord> buckets = bucketService.list();
        List<OrganizationUsageResponse> usage = visibleOrganizations(actor).stream()
                .map(organization -> usageOf(organization, buckets))
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
        boolean hasBuckets = bucketService.list().stream()
                .anyMatch(bucket -> "ORG".equals(bucket.ownerType()) && bucket.ownerId() == organization.id());
        if (hasBuckets) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Organization has buckets.");
        }
        boolean hasUsers = userRepository.findAll().stream()
                .anyMatch(user -> user.organizationId() != null && user.organizationId().longValue() == organization.id());
        if (hasUsers) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Organization has users.");
        }
        organizationRepository.deleteById(organization.id());
        auditLogService.record("ORGANIZATION_DELETE", actor.loginId(), "ORGANIZATION", organization.name(), "SUCCESS", "Organization deleted", request);
        return ResponseEntity.noContent().build();
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

    private OrganizationUsageResponse usageOf(OrganizationRecord organization, List<BucketRecord> buckets) {
        List<BucketRecord> organizationBuckets = buckets.stream()
                .filter(bucket -> "ORG".equals(bucket.ownerType()) && bucket.ownerId() == organization.id())
                .toList();
        long bucketQuotaBytes = organizationBuckets.stream().mapToLong(BucketRecord::quotaBytes).sum();
        long usedBytes = organizationBuckets.stream().mapToLong(BucketRecord::usedBytes).sum();
        long objectCount = organizationBuckets.stream().mapToLong(BucketRecord::objectCount).sum();
        long quotaLimit = organization.defaultQuotaBytes() > 0 ? organization.defaultQuotaBytes() : bucketQuotaBytes;
        return new OrganizationUsageResponse(
                organization.id(),
                organization.name(),
                organization.defaultQuotaBytes(),
                bucketQuotaBytes,
                usedBytes,
                Math.max(0L, quotaLimit - usedBytes),
                organizationBuckets.size(),
                objectCount
        );
    }
}
