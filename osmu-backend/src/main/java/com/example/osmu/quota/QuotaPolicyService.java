package com.example.osmu.quota;

import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.quota.repository.QuotaPolicyRepository;
import com.example.osmu.user.repository.UserRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.stereotype.Service;

@Service
public class QuotaPolicyService {

    private static final Set<String> TARGET_TYPES = Set.of("USER", "ORGANIZATION", "BUCKET");
    private static final int MAX_REASON_LENGTH = 512;

    private final QuotaPolicyRepository quotaPolicyRepository;
    private final BucketRepository bucketRepository;
    private final UserRepository userRepository;
    private final OrganizationRepository organizationRepository;

    public QuotaPolicyService(
            QuotaPolicyRepository quotaPolicyRepository,
            BucketRepository bucketRepository,
            UserRepository userRepository,
            OrganizationRepository organizationRepository
    ) {
        this.quotaPolicyRepository = quotaPolicyRepository;
        this.bucketRepository = bucketRepository;
        this.userRepository = userRepository;
        this.organizationRepository = organizationRepository;
    }

    public List<QuotaPolicyResponse> list() {
        return quotaPolicyRepository.findAll().stream()
                .map(policy -> QuotaPolicyResponse.of(policy, usedBytes(policy.targetType(), policy.targetId())))
                .toList();
    }

    public List<QuotaPolicyHistoryResponse> history(int limit) {
        int normalizedLimit = Math.max(1, Math.min(limit, 200));
        return quotaPolicyRepository.findHistory(normalizedLimit).stream()
                .map(QuotaPolicyHistoryResponse::of)
                .toList();
    }

    public QuotaPolicyResponse save(String targetType, long targetId, QuotaPolicyRequest request, String actorId) {
        String normalizedTargetType = normalizeTargetType(targetType);
        validateTarget(normalizedTargetType, targetId);
        long quotaBytes = normalizeQuotaBytes(request);
        String reason = normalizeReason(request.reason());
        OffsetDateTime now = OffsetDateTime.now();
        QuotaPolicy current = quotaPolicyRepository.findByTarget(normalizedTargetType, targetId).orElse(null);
        QuotaPolicy saved = quotaPolicyRepository.save(new QuotaPolicy(
                current == null ? quotaPolicyRepository.nextId() : current.id(),
                normalizedTargetType,
                targetId,
                quotaBytes,
                current == null ? now : current.createdAt(),
                now
        ));
        quotaPolicyRepository.saveHistory(new QuotaPolicyHistory(
                quotaPolicyRepository.nextHistoryId(),
                saved.targetType(),
                saved.targetId(),
                current == null ? "CREATE" : "UPDATE",
                current == null ? null : current.quotaBytes(),
                saved.quotaBytes(),
                normalizeActorId(actorId),
                reason,
                now
        ));
        return QuotaPolicyResponse.of(saved, usedBytes(saved.targetType(), saved.targetId()));
    }

    public void delete(String targetType, long targetId, String actorId, String reason) {
        String normalizedTargetType = normalizeTargetType(targetType);
        QuotaPolicy current = quotaPolicyRepository.findByTarget(normalizedTargetType, targetId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Quota policy not found."));
        String normalizedReason = normalizeReason(reason);
        quotaPolicyRepository.deleteByTarget(normalizedTargetType, targetId);
        quotaPolicyRepository.saveHistory(new QuotaPolicyHistory(
                quotaPolicyRepository.nextHistoryId(),
                current.targetType(),
                current.targetId(),
                "DELETE",
                current.quotaBytes(),
                null,
                normalizeActorId(actorId),
                normalizedReason,
                OffsetDateTime.now()
        ));
    }

    private long normalizeQuotaBytes(QuotaPolicyRequest request) {
        if (request == null || request.quotaBytes() == null || request.quotaBytes() <= 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "quotaBytes must be positive.");
        }
        return request.quotaBytes();
    }

    private String normalizeTargetType(String targetType) {
        String normalized = targetType == null ? "" : targetType.trim().toUpperCase(Locale.ROOT);
        if (!TARGET_TYPES.contains(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid quota policy target type.");
        }
        return normalized;
    }

    private String normalizeActorId(String actorId) {
        String normalized = actorId == null ? "" : actorId.trim();
        return normalized.isBlank() ? "system" : normalized;
    }

    private String normalizeReason(String reason) {
        String normalized = reason == null ? "" : reason.trim();
        if (normalized.isBlank()) {
            return null;
        }
        if (normalized.length() > MAX_REASON_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Quota policy reason must be 512 characters or fewer.");
        }
        return normalized;
    }

    private void validateTarget(String targetType, long targetId) {
        if (targetId <= 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "targetId must be positive.");
        }
        if ("USER".equals(targetType) && userRepository.findById(targetId).isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Quota policy user target not found.");
        }
        if ("ORGANIZATION".equals(targetType) && organizationRepository.findById(targetId).isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Quota policy organization target not found.");
        }
        if ("BUCKET".equals(targetType) && bucketRepository.findAll().stream().noneMatch(bucket -> bucket.id() == targetId)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Quota policy bucket target not found.");
        }
    }

    private long usedBytes(String targetType, long targetId) {
        return switch (targetType) {
            case "USER" -> bucketRepository.findAll().stream()
                    .filter(bucket -> "USER".equals(bucket.ownerType()) && bucket.ownerId() == targetId)
                    .mapToLong(BucketRecord::usedBytes)
                    .sum();
            case "ORGANIZATION" -> bucketRepository.findAll().stream()
                    .filter(bucket -> "ORG".equals(bucket.ownerType()) && bucket.ownerId() == targetId)
                    .mapToLong(BucketRecord::usedBytes)
                    .sum();
            case "BUCKET" -> bucketRepository.findAll().stream()
                    .filter(bucket -> bucket.id() == targetId)
                    .mapToLong(BucketRecord::usedBytes)
                    .sum();
            default -> 0L;
        };
    }
}
