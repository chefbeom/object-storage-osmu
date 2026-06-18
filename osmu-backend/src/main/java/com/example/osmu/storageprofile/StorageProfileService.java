package com.example.osmu.storageprofile;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storageprofile.repository.StorageProfileAssignmentRepository;
import com.example.osmu.storageprofile.repository.StorageProfileRequestRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.stereotype.Service;

@Service
public class StorageProfileService {

    private static final int MAX_REASON_LENGTH = 512;
    private static final Set<String> ADMIN_STATUSES = Set.of("APPROVED", "REJECTED");

    private final StorageProfileAssignmentRepository assignmentRepository;
    private final StorageProfileRequestRepository requestRepository;
    private final BucketService bucketService;

    public StorageProfileService(
            StorageProfileAssignmentRepository assignmentRepository,
            StorageProfileRequestRepository requestRepository,
            BucketService bucketService
    ) {
        this.assignmentRepository = assignmentRepository;
        this.requestRepository = requestRepository;
        this.bucketService = bucketService;
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

    public List<StorageProfileRequestResponse> listVisibleRequests(AuthenticatedUser user) {
        if (user.isAdmin()) {
            return listAllRequests(user);
        }
        Set<String> visibleBuckets = bucketService.list(user).stream()
                .map(BucketRecord::name)
                .collect(java.util.stream.Collectors.toSet());
        return requestRepository.findAll().stream()
                .filter(request -> visibleBuckets.contains(request.bucketName()))
                .map(StorageProfileRequestResponse::of)
                .toList();
    }

    public List<StorageProfileRequestResponse> listAllRequests(AuthenticatedUser user) {
        requireAdmin(user);
        return requestRepository.findAll().stream()
                .map(StorageProfileRequestResponse::of)
                .toList();
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
                normalizeOptionalText(statusRequest == null ? null : statusRequest.adminNote()),
                existing.createdAt(),
                now
        ));
        return StorageProfileRequestResponse.of(saved);
    }

    public StorageProfileRequestResponse apply(AuthenticatedUser user, long requestId) {
        requireAdmin(user);
        StorageProfileRequestRecord existing = requireRequest(requestId);
        if (!"APPROVED".equals(existing.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage profile request must be APPROVED before apply.");
        }
        bucketService.get(existing.bucketName());
        OffsetDateTime now = OffsetDateTime.now();
        assignmentRepository.save(new StorageProfileAssignmentRecord(
                existing.bucketName(),
                existing.requestedProfileCode(),
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
