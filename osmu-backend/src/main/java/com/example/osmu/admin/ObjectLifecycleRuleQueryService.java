package com.example.osmu.admin;

import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectLifecycleRule;
import com.example.osmu.object.ObjectLifecycleRulePageCursor;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class ObjectLifecycleRuleQueryService {

    private static final int DEFAULT_LIST_LIMIT = 50;
    private static final int MAX_LIST_LIMIT = 200;

    private final ObjectLifecycleRuleRepository lifecycleRuleRepository;
    private final ObjectLifecycleS3XmlService lifecycleS3XmlService;

    public ObjectLifecycleRuleQueryService(
            ObjectLifecycleRuleRepository lifecycleRuleRepository,
            ObjectLifecycleS3XmlService lifecycleS3XmlService
    ) {
        this.lifecycleRuleRepository = lifecycleRuleRepository;
        this.lifecycleS3XmlService = lifecycleS3XmlService;
    }

    public ListResponse<ObjectLifecycleRule> list(
            String status,
            String targetType,
            String cursor,
            Integer limit
    ) {
        int pageSize = normalizeLimit(limit);
        List<ObjectLifecycleRule> matchedRules = lifecycleRuleRepository.findPage(
                normalizeStatus(status),
                normalizeTargetType(targetType),
                parseCursor(cursor),
                pageSize + 1
        );
        boolean hasNextPage = matchedRules.size() > pageSize;
        List<ObjectLifecycleRule> items = hasNextPage
                ? matchedRules.subList(0, pageSize).stream().toList()
                : List.copyOf(matchedRules);
        String nextCursor = hasNextPage
                ? ObjectLifecycleRulePageCursor.fromRule(items.get(items.size() - 1)).encode()
                : null;
        return ListResponse.of(items, nextCursor);
    }

    public ObjectLifecycleRuleConflictReportResponse conflicts() {
        List<ObjectLifecycleRule> trashRules = lifecycleRuleRepository.findEnabledByTargetType(
                ObjectLifecycleRule.TARGET_TRASH_OBJECT
        );
        List<ObjectLifecycleRule> versionRules = lifecycleRuleRepository.findEnabledByTargetType(
                ObjectLifecycleRule.TARGET_OBJECT_VERSION
        );
        List<ObjectLifecycleRuleConflictResponse> conflicts = new ArrayList<>();
        conflicts.addAll(lifecycleRuleConflicts(trashRules));
        conflicts.addAll(lifecycleRuleConflicts(versionRules));
        return new ObjectLifecycleRuleConflictReportResponse(
                trashRules.size() + versionRules.size(),
                conflicts.size(),
                List.copyOf(conflicts)
        );
    }

    public ObjectLifecycleS3XmlResponse exportS3Xml() {
        List<ObjectLifecycleRule> rules = lifecycleRuleRepository.findAllForExport();
        return new ObjectLifecycleS3XmlResponse(rules.size(), lifecycleS3XmlService.exportRules(rules));
    }

    private Boolean normalizeStatus(String status) {
        String normalized = normalizeFilter(status);
        return switch (normalized) {
            case "ALL" -> null;
            case "ENABLED" -> true;
            case "DISABLED" -> false;
            default -> throw validationError("status must be ALL, ENABLED, or DISABLED.");
        };
    }

    private String normalizeTargetType(String targetType) {
        String normalized = normalizeFilter(targetType);
        return switch (normalized) {
            case "ALL" -> null;
            case ObjectLifecycleRule.TARGET_TRASH_OBJECT, ObjectLifecycleRule.TARGET_OBJECT_VERSION -> normalized;
            default -> throw validationError("targetType must be ALL, TRASH_OBJECT, or OBJECT_VERSION.");
        };
    }

    private String normalizeFilter(String value) {
        if (value == null || value.isBlank()) {
            return "ALL";
        }
        return value.trim().toUpperCase(Locale.ROOT);
    }

    private ObjectLifecycleRulePageCursor parseCursor(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            return ObjectLifecycleRulePageCursor.decode(cursor.trim());
        } catch (IllegalArgumentException exception) {
            throw validationError("cursor is invalid.");
        }
    }

    private int normalizeLimit(Integer limit) {
        int normalized = limit == null ? DEFAULT_LIST_LIMIT : limit;
        if (normalized < 1 || normalized > MAX_LIST_LIMIT) {
            throw validationError("limit must be between 1 and 200.");
        }
        return normalized;
    }

    private List<ObjectLifecycleRuleConflictResponse> lifecycleRuleConflicts(List<ObjectLifecycleRule> rules) {
        List<ObjectLifecycleRuleConflictResponse> conflicts = new ArrayList<>();
        for (int firstIndex = 0; firstIndex < rules.size(); firstIndex++) {
            for (int secondIndex = firstIndex + 1; secondIndex < rules.size(); secondIndex++) {
                ObjectLifecycleRule first = rules.get(firstIndex);
                ObjectLifecycleRule second = rules.get(secondIndex);
                if (!bucketScopesOverlap(first.bucketName(), second.bucketName())
                        || !prefixesOverlap(first.prefix(), second.prefix())
                        || !tagsCompatible(first.tags(), second.tags())) {
                    continue;
                }
                conflicts.add(toLifecycleRuleConflict(first, second));
            }
        }
        return conflicts;
    }

    private ObjectLifecycleRuleConflictResponse toLifecycleRuleConflict(
            ObjectLifecycleRule first,
            ObjectLifecycleRule second
    ) {
        boolean samePriority = first.priority() == second.priority();
        boolean differentRetention = first.retentionDays() != second.retentionDays();
        String conflictType = samePriority ? "SAME_PRIORITY_OVERLAP" : "OVERLAPPING_SCOPE";
        String severity = samePriority || differentRetention ? "WARNING" : "INFO";
        String reason = samePriority
                ? "Rules have the same priority and overlapping scope; createdAt/ruleId decides final order."
                : "Earlier priority rule can purge shared candidates before later rule.";
        return new ObjectLifecycleRuleConflictResponse(
                conflictType,
                severity,
                first.targetType(),
                first,
                second,
                reason
        );
    }

    private boolean bucketScopesOverlap(String firstBucketName, String secondBucketName) {
        String first = firstBucketName == null ? "" : firstBucketName;
        String second = secondBucketName == null ? "" : secondBucketName;
        return first.isBlank() || second.isBlank() || first.equals(second);
    }

    private boolean prefixesOverlap(String firstPrefix, String secondPrefix) {
        String first = firstPrefix == null ? "" : firstPrefix;
        String second = secondPrefix == null ? "" : secondPrefix;
        return first.startsWith(second) || second.startsWith(first);
    }

    private boolean tagsCompatible(Map<String, String> firstTags, Map<String, String> secondTags) {
        Map<String, String> first = firstTags == null ? Map.of() : firstTags;
        Map<String, String> second = secondTags == null ? Map.of() : secondTags;
        for (Map.Entry<String, String> entry : first.entrySet()) {
            String otherValue = second.get(entry.getKey());
            if (otherValue != null && !otherValue.equals(entry.getValue())) {
                return false;
            }
        }
        return true;
    }

    private ApiException validationError(String message) {
        return new ApiException(ApiErrorCode.VALIDATION_ERROR, message);
    }
}
