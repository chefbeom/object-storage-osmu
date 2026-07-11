package com.example.osmu.storageprofile;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storageprofile.repository.StorageProfileAssignmentRepository;
import com.example.osmu.storageprofile.repository.StorageProfileRequestRepository;
import com.example.osmu.storagelayout.StorageLayoutPlanResponse;
import com.example.osmu.storagelayout.StorageLayoutService;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class StorageProfileService {

    private static final int MAX_REASON_LENGTH = 512;
    private static final int DEFAULT_LIST_LIMIT = 50;
    private static final int MAX_LIST_LIMIT = 200;
    private static final Set<String> ADMIN_STATUSES = Set.of("APPROVED", "REJECTED");
    private static final Set<String> REQUEST_STATUSES = Set.of("PENDING", "APPROVED", "REJECTED", "APPLIED");

    private final StorageProfileAssignmentRepository assignmentRepository;
    private final StorageProfileRequestRepository requestRepository;
    private final BucketService bucketService;
    private final StorageLayoutService storageLayoutService;

    @Autowired
    public StorageProfileService(
            StorageProfileAssignmentRepository assignmentRepository,
            StorageProfileRequestRepository requestRepository,
            BucketService bucketService,
            StorageLayoutService storageLayoutService
    ) {
        this.assignmentRepository = assignmentRepository;
        this.requestRepository = requestRepository;
        this.bucketService = bucketService;
        this.storageLayoutService = storageLayoutService;
    }

    StorageProfileService(
            StorageProfileAssignmentRepository assignmentRepository,
            StorageProfileRequestRepository requestRepository,
            BucketService bucketService
    ) {
        this(assignmentRepository, requestRepository, bucketService, null);
    }

    public List<StorageProfileResponse> profiles() {
        return StorageProfileCatalog.list();
    }

    public StorageProfileCurrentResponse current(AuthenticatedUser user, String bucketName) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        StorageProfileAssignmentResponse assignment = assignment(bucket.name());
        StorageProfileRequestResponse latestRequest = requestRepository.findLatestByBucketName(bucket.name())
                .map(StorageProfileRequestResponse::of)
                .orElse(null);
        return new StorageProfileCurrentResponse(bucket.name(), assignment, latestRequest);
    }

    public ListResponse<StorageProfileRequestResponse> listVisibleRequests(
            AuthenticatedUser user,
            String bucketName,
            String cursor,
            Integer limit
    ) {
        int pageSize = normalizeListLimit(limit);
        Long cursorId = parseListCursor(cursor);
        String normalizedBucketName = bucketName == null ? "" : bucketName.trim();
        List<StorageProfileRequestRecord> matchedRequests;
        if (!normalizedBucketName.isBlank()) {
            BucketRecord bucket = bucketService.get(normalizedBucketName, user);
            matchedRequests = requestRepository.findPageByBucketName(bucket.name(), cursorId, pageSize + 1);
        } else if (user.isAdmin()) {
            matchedRequests = requestRepository.findPage(List.of(), cursorId, pageSize + 1);
        } else {
            List<String> visibleBuckets = bucketService.list(user).stream()
                    .map(BucketRecord::name)
                    .toList();
            if (visibleBuckets.isEmpty()) {
                return ListResponse.of(List.of(), null);
            }
            matchedRequests = requestRepository.findPageByBucketNames(visibleBuckets, cursorId, pageSize + 1);
        }
        return pageResponse(matchedRequests, pageSize);
    }

    public ListResponse<StorageProfileRequestResponse> listAdminRequests(
            AuthenticatedUser user,
            String status,
            String cursor,
            Integer limit
    ) {
        requireAdmin(user);
        int pageSize = normalizeListLimit(limit);
        List<StorageProfileRequestRecord> matchedRequests = requestRepository.findPage(
                normalizeListStatuses(status),
                parseListCursor(cursor),
                pageSize + 1
        );
        return pageResponse(matchedRequests, pageSize);
    }

    private ListResponse<StorageProfileRequestResponse> pageResponse(
            List<StorageProfileRequestRecord> matchedRequests,
            int pageSize
    ) {
        boolean hasNextPage = matchedRequests.size() > pageSize;
        List<StorageProfileRequestRecord> page = hasNextPage
                ? matchedRequests.subList(0, pageSize)
                : matchedRequests;
        List<StorageProfileRequestResponse> items = page.stream()
                .map(StorageProfileRequestResponse::of)
                .toList();
        String nextCursor = hasNextPage ? String.valueOf(page.get(page.size() - 1).id()) : null;
        return ListResponse.of(items, nextCursor);
    }

    public StorageProfileRequestResponse createRequest(
            AuthenticatedUser user,
            String bucketName,
            StorageProfileRequestPayload payload
    ) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanManage(user, bucket);
        StorageProfileCode requestedProfile = StorageProfileCode.parse(payload == null ? null : payload.requestedProfile());
        StorageProfileCode currentProfile = activeProfileCode(bucket.name());
        if (requestedProfile == currentProfile) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile is already active.");
        }
        String reason = normalizeReason(payload == null ? null : payload.reason(), requestedProfile);
        OffsetDateTime now = OffsetDateTime.now();
        StorageProfileRequestRecord saved = requestRepository.save(new StorageProfileRequestRecord(
                requestRepository.nextId(),
                bucket.name(),
                currentProfile.name(),
                requestedProfile.name(),
                "PENDING",
                reason,
                user.loginId(),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                now,
                now
        ));
        return StorageProfileRequestResponse.of(saved);
    }

    public StorageProfileRequestResponse updateStatus(
            AuthenticatedUser user,
            long requestId,
            StorageProfileStatusRequest statusRequest
    ) {
        requireAdmin(user);
        StorageProfileRequestRecord existing = requireRequest(requestId);
        String status = normalizeStatus(statusRequest == null ? null : statusRequest.status());
        if (!ADMIN_STATUSES.contains(status)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile request status must be APPROVED or REJECTED.");
        }
        if (!"PENDING".equals(existing.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile request status can change only from PENDING.");
        }
        OffsetDateTime now = OffsetDateTime.now();
        StorageProfileRequestRecord saved = requestRepository.save(new StorageProfileRequestRecord(
                existing.id(),
                existing.bucketName(),
                existing.currentProfileCode(),
                existing.requestedProfileCode(),
                status,
                existing.reason(),
                existing.requestedBy(),
                user.loginId(),
                now,
                null,
                null,
                existing.storageLayoutPlanId(),
                existing.storagePoolName(),
                existing.storageLayoutCode(),
                normalizeOptionalText(statusRequest == null ? null : statusRequest.adminNote()),
                existing.createdAt(),
                now
        ));
        return StorageProfileRequestResponse.of(saved);
    }

    public StorageProfileRequestResponse apply(
            AuthenticatedUser user,
            long requestId,
            StorageProfileApplyRequest applyRequest
    ) {
        requireAdmin(user);
        StorageProfileRequestRecord existing = requireRequest(requestId);
        if (!"APPROVED".equals(existing.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile request must be APPROVED before apply.");
        }
        bucketService.get(existing.bucketName());
        if (applyRequest == null || applyRequest.storageLayoutPlanId() == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage layout plan ID is required for apply.");
        }
        StorageProfileCode requestedProfile = StorageProfileCode.parse(existing.requestedProfileCode());
        StorageLayoutPlanResponse layoutPlan = storageLayoutService.requireApplicablePlan(
                user,
                applyRequest.storageLayoutPlanId(),
                requestedProfile
        );
        OffsetDateTime now = OffsetDateTime.now();
        assignmentRepository.save(new StorageProfileAssignmentRecord(
                existing.bucketName(),
                existing.requestedProfileCode(),
                layoutPlan.id(),
                layoutPlan.poolName(),
                layoutPlan.layout().code(),
                user.loginId(),
                now,
                now
        ));
        StorageProfileRequestRecord saved = requestRepository.save(new StorageProfileRequestRecord(
                existing.id(),
                existing.bucketName(),
                existing.currentProfileCode(),
                existing.requestedProfileCode(),
                "APPLIED",
                existing.reason(),
                existing.requestedBy(),
                existing.approvedBy(),
                existing.approvedAt(),
                user.loginId(),
                now,
                layoutPlan.id(),
                layoutPlan.poolName(),
                layoutPlan.layout().code(),
                existing.adminNote(),
                existing.createdAt(),
                now
        ));
        return StorageProfileRequestResponse.of(saved);
    }

    public StorageProfileAssignmentResponse assignment(String bucketName) {
        return assignmentRepository.findByBucketName(bucketName)
                .map(StorageProfileAssignmentResponse::of)
                .orElseGet(() -> StorageProfileAssignmentResponse.defaultFor(bucketName));
    }

    private StorageProfileCode activeProfileCode(String bucketName) {
        return assignmentRepository.findByBucketName(bucketName)
                .map(StorageProfileAssignmentRecord::profileCode)
                .map(StorageProfileCode::parse)
                .orElse(StorageProfileCode.STANDARD);
    }

    private StorageProfileRequestRecord requireRequest(long requestId) {
        return requestRepository.findById(requestId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Storage profile request not found."));
    }

    private String normalizeStatus(String rawStatus) {
        String status = rawStatus == null ? "" : rawStatus.trim().toUpperCase(Locale.ROOT);
        if (status.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile request status is required.");
        }
        return status;
    }

    private List<String> normalizeListStatuses(String status) {
        String normalized = status == null ? "OPEN" : status.trim().toUpperCase(Locale.ROOT);
        if (normalized.isBlank() || "OPEN".equals(normalized)) {
            return List.of("PENDING", "APPROVED");
        }
        if ("ALL".equals(normalized)) {
            return List.of();
        }
        if (!REQUEST_STATUSES.contains(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile request status filter is invalid.");
        }
        return List.of(normalized);
    }

    private int normalizeListLimit(Integer limit) {
        if (limit == null) {
            return DEFAULT_LIST_LIMIT;
        }
        if (limit < 1 || limit > MAX_LIST_LIMIT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile page limit must be between 1 and 200.");
        }
        return limit;
    }

    private Long parseListCursor(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            long parsed = Long.parseLong(cursor.trim());
            if (parsed < 1) {
                throw new NumberFormatException("cursor must be positive");
            }
            return parsed;
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile page cursor is invalid.");
        }
    }

    private String normalizeReason(String rawReason, StorageProfileCode requestedProfile) {
        String reason = normalizeOptionalText(rawReason);
        if (reason.isBlank() && requestedProfile == StorageProfileCode.PERFORMANCE) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Performance profile request requires reason.");
        }
        return reason;
    }

    private String normalizeOptionalText(String rawValue) {
        String value = rawValue == null ? "" : rawValue.trim();
        if (value.length() > MAX_REASON_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile text is too long.");
        }
        return value;
    }

    private void requireAdmin(AuthenticatedUser user) {
        if (!user.isAdmin()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Storage profile management requires ADMIN role.");
        }
    }
}
