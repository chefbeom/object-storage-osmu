package com.example.osmu.bucket;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.repository.BucketTagRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;

@Service
public class BucketTagService {

    private static final int MAX_TAG_COUNT = 50;
    private static final int MAX_TAG_KEY_LENGTH = 128;
    private static final int MAX_TAG_VALUE_LENGTH = 256;
    private static final Pattern TAG_KEY_PATTERN = Pattern.compile("^[A-Za-z0-9_.:/@+-]+$");

    private final BucketService bucketService;
    private final BucketTagRepository bucketTagRepository;
    private final AuditLogService auditLogService;

    public BucketTagService(
            BucketService bucketService,
            BucketTagRepository bucketTagRepository,
            AuditLogService auditLogService
    ) {
        this.bucketService = bucketService;
        this.bucketTagRepository = bucketTagRepository;
        this.auditLogService = auditLogService;
    }

    public Map<String, String> getTags(String bucketName, AuthenticatedUser user, HttpServletRequest request) {
        return getTags(bucketName, user, request, "S3_BUCKET_TAGGING_GET", "S3-style bucket tags read");
    }

    public Map<String, String> getTagsForRest(String bucketName, AuthenticatedUser user, HttpServletRequest request) {
        return getTags(bucketName, user, request, "BUCKET_TAGS_GET", "Bucket tags read");
    }

    private Map<String, String> getTags(
            String bucketName,
            AuthenticatedUser user,
            HttpServletRequest request,
            String eventType,
            String message
    ) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanManage(user, bucket);
        auditLogService.record(eventType, user.loginId(), "BUCKET", bucket.name(), "SUCCESS", message, request);
        return bucketTagRepository.findByBucketName(bucket.name());
    }

    public Map<String, String> replaceTags(
            String bucketName,
            Map<String, String> tags,
            AuthenticatedUser user,
            HttpServletRequest request
    ) {
        return replaceTags(bucketName, tags, user, request, "S3_BUCKET_TAGGING_PUT", "S3-style bucket tags replaced");
    }

    public Map<String, String> replaceTagsForRest(
            String bucketName,
            Map<String, String> tags,
            AuthenticatedUser user,
            HttpServletRequest request
    ) {
        return replaceTags(bucketName, tags, user, request, "BUCKET_TAGS_PUT", "Bucket tags replaced");
    }

    private Map<String, String> replaceTags(
            String bucketName,
            Map<String, String> tags,
            AuthenticatedUser user,
            HttpServletRequest request,
            String eventType,
            String message
    ) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanManage(user, bucket);
        Map<String, String> normalizedTags = normalizeTags(tags);
        Map<String, String> savedTags = bucketTagRepository.replace(bucket.name(), normalizedTags);
        auditLogService.record(eventType, user.loginId(), "BUCKET", bucket.name(), "SUCCESS", message, request);
        return savedTags;
    }

    public void deleteTags(String bucketName, AuthenticatedUser user, HttpServletRequest request) {
        deleteTags(bucketName, user, request, "S3_BUCKET_TAGGING_DELETE", "S3-style bucket tags deleted");
    }

    public void deleteTagsForRest(String bucketName, AuthenticatedUser user, HttpServletRequest request) {
        deleteTags(bucketName, user, request, "BUCKET_TAGS_DELETE", "Bucket tags deleted");
    }

    private void deleteTags(
            String bucketName,
            AuthenticatedUser user,
            HttpServletRequest request,
            String eventType,
            String message
    ) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanManage(user, bucket);
        bucketTagRepository.delete(bucket.name());
        auditLogService.record(eventType, user.loginId(), "BUCKET", bucket.name(), "SUCCESS", message, request);
    }

    private Map<String, String> normalizeTags(Map<String, String> tags) {
        if (tags == null || tags.isEmpty()) {
            return Map.of();
        }
        if (tags.size() > MAX_TAG_COUNT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket tags can contain at most 50 pairs.");
        }
        Map<String, String> normalizedTags = new LinkedHashMap<>();
        for (Map.Entry<String, String> tag : tags.entrySet()) {
            String key = tag.getKey() == null ? "" : tag.getKey().trim();
            String value = tag.getValue() == null ? "" : tag.getValue().trim();
            validateTagKey(key);
            validateTagValue(value);
            if (normalizedTags.put(key, value) != null) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Duplicate bucket tag key is not allowed.");
            }
        }
        return Map.copyOf(normalizedTags);
    }

    private void validateTagKey(String key) {
        if (key.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket tag key is required.");
        }
        if (key.length() > MAX_TAG_KEY_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket tag keys can be at most 128 characters.");
        }
        if (!TAG_KEY_PATTERN.matcher(key).matches()) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    "Bucket tag keys can contain letters, digits, '.', '_', ':', '/', '@', '+', '-'."
            );
        }
    }

    private void validateTagValue(String value) {
        if (value.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket tag value is required.");
        }
        if (value.length() > MAX_TAG_VALUE_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket tag values can be at most 256 characters.");
        }
        if (value.chars().anyMatch(Character::isISOControl)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket tag values cannot contain control characters.");
        }
    }
}
