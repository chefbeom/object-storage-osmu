package com.example.osmu.quota;

import com.example.osmu.bucket.BucketOwnerUsageSummary;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.quota.repository.QuotaPolicyRepository;
import com.example.osmu.user.repository.UserRepository;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;

@Service
public class QuotaPolicyService {

    private static final Set<String> TARGET_TYPES = Set.of("USER", "ORGANIZATION", "BUCKET");
    private static final int MAX_REASON_LENGTH = 512;
    private static final int DEFAULT_LIST_LIMIT = 50;
    private static final int MAX_LIST_LIMIT = 200;

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

    public ListResponse<QuotaPolicyResponse> list(String cursor, Integer limit) {
        int pageSize = normalizeListLimit(limit);
        List<QuotaPolicy> page = quotaPolicyRepository.findPage(parseCursor(cursor), pageSize + 1);
        boolean hasNextPage = page.size() > pageSize;
        List<QuotaPolicy> policies = hasNextPage
                ? page.subList(0, pageSize).stream().toList()
                : List.copyOf(page);
        String nextCursor = hasNextPage
                ? QuotaPolicyPageCursor.fromPolicy(policies.get(policies.size() - 1)).encode()
                : null;
        return ListResponse.of(responses(policies), nextCursor);
    }

    public List<QuotaPolicyResponse> listAllForDashboardSummary() {
        return responses(quotaPolicyRepository.findAllForDashboardSummary());
    }

    private List<QuotaPolicyResponse> responses(List<QuotaPolicy> policies) {
        Map<TargetKey, Long> usedBytesByTarget = usedBytesByTargets(policies);
        return policies.stream()
                .map(policy -> QuotaPolicyResponse.of(
                        policy,
                        usedBytesByTarget.getOrDefault(new TargetKey(policy.targetType(), policy.targetId()), 0L)
                ))
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

    private QuotaPolicyPageCursor parseCursor(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            return QuotaPolicyPageCursor.decode(cursor.trim());
        } catch (IllegalArgumentException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "cursor is invalid.");
        }
    }

    private int normalizeListLimit(Integer limit) {
        int normalized = limit == null ? DEFAULT_LIST_LIMIT : limit;
        if (normalized < 1 || normalized > MAX_LIST_LIMIT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "limit must be between 1 and 200.");
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
        if ("BUCKET".equals(targetType) && bucketRepository.findById(targetId).isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Quota policy bucket target not found.");
        }
    }

    private Map<TargetKey, Long> usedBytesByTargets(List<QuotaPolicy> policies) {
        Map<TargetKey, Long> result = new HashMap<>();
        addOwnerUsage(result, policies, "USER", "USER");
        addOwnerUsage(result, policies, "ORGANIZATION", "ORG");

        List<Long> bucketIds = targetIds(policies, "BUCKET");
        if (!bucketIds.isEmpty()) {
            for (BucketRecord bucket : bucketRepository.findByIds(bucketIds)) {
                result.put(new TargetKey("BUCKET", bucket.id()), bucket.usedBytes());
            }
        }
        return result;
    }

    private void addOwnerUsage(
            Map<TargetKey, Long> result,
            List<QuotaPolicy> policies,
            String targetType,
            String ownerType
    ) {
        List<Long> targetIds = targetIds(policies, targetType);
        if (targetIds.isEmpty()) {
            return;
        }
        for (BucketOwnerUsageSummary summary : bucketRepository.summarizeUsageByOwners(ownerType, targetIds)) {
            result.put(new TargetKey(targetType, summary.ownerId()), summary.totalUsedBytes());
        }
    }

    private List<Long> targetIds(List<QuotaPolicy> policies, String targetType) {
        return policies.stream()
                .filter(policy -> targetType.equals(policy.targetType()))
                .map(QuotaPolicy::targetId)
                .distinct()
                .toList();
    }

    private long usedBytes(String targetType, long targetId) {
        return switch (targetType) {
            case "USER" -> bucketRepository.sumUsedBytesByOwner("USER", targetId);
            case "ORGANIZATION" -> bucketRepository.sumUsedBytesByOwner("ORG", targetId);
            case "BUCKET" -> bucketRepository.findById(targetId)
                    .map(BucketRecord::usedBytes)
                    .orElse(0L);
            default -> 0L;
        };
    }

    private record TargetKey(String targetType, long targetId) {
    }
}
