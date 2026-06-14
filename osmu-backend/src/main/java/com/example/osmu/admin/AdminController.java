package com.example.osmu.admin;

import com.example.osmu.accesskey.S3AccessPolicyProvisioner;
import com.example.osmu.accesskey.repository.AccessKeyRepository;
import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.audit.repository.AuditLogRepository;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.auth.repository.RefreshTokenRepository;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.DeletedObjectCandidate;
import com.example.osmu.object.ObjectLifecycleRule;
import com.example.osmu.object.ObjectRetentionPolicy;
import com.example.osmu.object.ObjectRetentionPurgeJob;
import com.example.osmu.object.ObjectShareLink;
import com.example.osmu.object.ObjectVersionRetentionPurgeJob;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import com.example.osmu.object.repository.ObjectRetentionPolicyRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.object.repository.ObjectVersionRepository.VersionCandidate;
import com.example.osmu.object.repository.PresignedUploadSessionRepository;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.user.repository.UserRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.http.HttpServletRequest;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private static final Pattern TAG_KEY_PATTERN = Pattern.compile("^[A-Za-z0-9_.:/@+-]+$");

    private final BucketService bucketService;
    private final BucketRepository bucketRepository;
    private final UserRepository userRepository;
    private final OrganizationRepository organizationRepository;
    private final AuditLogRepository auditLogRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AccessKeyRepository accessKeyRepository;
    private final ObjectMetadataRepository objectMetadataRepository;
    private final ObjectLifecycleRuleRepository lifecycleRuleRepository;
    private final ObjectRetentionPolicyRepository retentionPolicyRepository;
    private final ObjectVersionRepository objectVersionRepository;
    private final PresignedUploadSessionRepository uploadSessionRepository;
    private final S3AccessPolicyProvisioner policyProvisioner;
    private final AuditLogService auditLogService;
    private final ObjectLifecycleS3XmlService lifecycleS3XmlService;
    private final AuthContext authContext;
    private final ObjectStorageAdapter storageAdapter;
    private final ObjectProvider<ObjectRetentionPurgeJob> retentionPurgeJobProvider;
    private final ObjectProvider<ObjectVersionRetentionPurgeJob> versionRetentionPurgeJobProvider;
    private final MeterRegistry meterRegistry;
    private final boolean objectRetentionEnabled;

    public AdminController(
            BucketService bucketService,
            BucketRepository bucketRepository,
            UserRepository userRepository,
            OrganizationRepository organizationRepository,
            AuditLogRepository auditLogRepository,
            RefreshTokenRepository refreshTokenRepository,
            AccessKeyRepository accessKeyRepository,
            ObjectMetadataRepository objectMetadataRepository,
            ObjectLifecycleRuleRepository lifecycleRuleRepository,
            ObjectRetentionPolicyRepository retentionPolicyRepository,
            ObjectVersionRepository objectVersionRepository,
            PresignedUploadSessionRepository uploadSessionRepository,
            S3AccessPolicyProvisioner policyProvisioner,
            AuditLogService auditLogService,
            ObjectLifecycleS3XmlService lifecycleS3XmlService,
            AuthContext authContext,
            ObjectStorageAdapter storageAdapter,
            ObjectProvider<ObjectRetentionPurgeJob> retentionPurgeJobProvider,
            ObjectProvider<ObjectVersionRetentionPurgeJob> versionRetentionPurgeJobProvider,
            MeterRegistry meterRegistry,
            @Value("${osmu.object.retention.enabled:true}") boolean objectRetentionEnabled
    ) {
        this.bucketService = bucketService;
        this.bucketRepository = bucketRepository;
        this.userRepository = userRepository;
        this.organizationRepository = organizationRepository;
        this.auditLogRepository = auditLogRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.accessKeyRepository = accessKeyRepository;
        this.objectMetadataRepository = objectMetadataRepository;
        this.lifecycleRuleRepository = lifecycleRuleRepository;
        this.retentionPolicyRepository = retentionPolicyRepository;
        this.objectVersionRepository = objectVersionRepository;
        this.uploadSessionRepository = uploadSessionRepository;
        this.policyProvisioner = policyProvisioner;
        this.auditLogService = auditLogService;
        this.lifecycleS3XmlService = lifecycleS3XmlService;
        this.authContext = authContext;
        this.storageAdapter = storageAdapter;
        this.retentionPurgeJobProvider = retentionPurgeJobProvider;
        this.versionRetentionPurgeJobProvider = versionRetentionPurgeJobProvider;
        this.meterRegistry = meterRegistry;
        this.objectRetentionEnabled = objectRetentionEnabled;
    }

    @GetMapping("/usage")
    public ApiResponse<UsageResponse> usage() {
        long quotaBytes = bucketService.totalQuotaBytes();
        long usedBytes = bucketService.totalUsedBytes();
        return ApiResponse.of(new UsageResponse(
                quotaBytes,
                usedBytes,
                Math.max(0L, quotaBytes - usedBytes),
                bucketService.list().size(),
                bucketService.totalObjectCount()
        ));
    }

    @GetMapping("/audit-logs")
    public ListResponse<AuditLogEntry> auditLogs(
            @RequestParam(name = "eventType", required = false) String eventType,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "requestId", required = false) String requestId,
            @RequestParam(name = "targetType", required = false) String targetType,
            @RequestParam(name = "targetId", required = false) String targetId,
            @RequestParam(name = "result", required = false) String result,
            @RequestParam(name = "cursor", required = false) String cursor,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        return auditLogService.list(eventType, actorId, requestId, targetType, targetId, result, cursor, from, to, limit);
    }

    @GetMapping(value = "/audit-logs/export.csv", produces = "text/csv")
    public ResponseEntity<String> exportAuditLogsCsv(
            @RequestParam(name = "eventType", required = false) String eventType,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "requestId", required = false) String requestId,
            @RequestParam(name = "targetType", required = false) String targetType,
            @RequestParam(name = "targetId", required = false) String targetId,
            @RequestParam(name = "result", required = false) String result,
            @RequestParam(name = "cursor", required = false) String cursor,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        String csv = auditLogService.exportCsv(eventType, actorId, requestId, targetType, targetId, result, cursor, from, to, limit);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-audit-logs.csv\"")
                .body(csv);
    }

    @GetMapping("/system/status")
    public ApiResponse<Map<String, String>> systemStatus() {
        boolean databaseHealthy = bucketRepository.isHealthy()
                && userRepository.isHealthy()
                && organizationRepository.isHealthy()
                && auditLogRepository.isHealthy()
                && refreshTokenRepository.isHealthy()
                && accessKeyRepository.isHealthy()
                && objectMetadataRepository.isHealthy()
                && lifecycleRuleRepository.isHealthy()
                && retentionPolicyRepository.isHealthy()
                && objectVersionRepository.isHealthy()
                && uploadSessionRepository.isHealthy();
        return ApiResponse.of(Map.of(
                "backend", "UP",
                "database", databaseHealthy ? "UP" : "DOWN",
                "storage", storageAdapter.isHealthy() ? "UP" : "DOWN",
                "accessKeyProvisioner", policyProvisioner.isHealthy() ? "UP" : "DOWN"
        ));
    }

    @GetMapping("/object-retention/status")
    public ApiResponse<ObjectRetentionStatusResponse> objectRetentionStatus() {
        return ApiResponse.of(retentionStatus());
    }

    @GetMapping("/object-lifecycle/rules")
    public ApiResponse<List<ObjectLifecycleRule>> objectLifecycleRules() {
        return ApiResponse.of(lifecycleRuleRepository.findAll());
    }

    @GetMapping("/object-lifecycle/conflicts")
    public ApiResponse<ObjectLifecycleRuleConflictReportResponse> objectLifecycleRuleConflicts() {
        List<ObjectLifecycleRule> enabledRules = lifecycleRuleRepository.findAll()
                .stream()
                .filter(ObjectLifecycleRule::enabled)
                .toList();
        List<ObjectLifecycleRuleConflictResponse> conflicts = lifecycleRuleConflicts(enabledRules);
        return ApiResponse.of(new ObjectLifecycleRuleConflictReportResponse(
                enabledRules.size(),
                conflicts.size(),
                conflicts
        ));
    }

    @GetMapping("/object-lifecycle/s3-xml")
    public ApiResponse<ObjectLifecycleS3XmlResponse> exportObjectLifecycleS3Xml() {
        List<ObjectLifecycleRule> rules = lifecycleRuleRepository.findAll();
        return ApiResponse.of(new ObjectLifecycleS3XmlResponse(
                rules.size(),
                lifecycleS3XmlService.exportRules(rules)
        ));
    }

    @PostMapping("/object-lifecycle/s3-xml")
    public ApiResponse<ObjectLifecycleS3XmlImportResponse> importObjectLifecycleS3Xml(
            @RequestBody ObjectLifecycleS3XmlRequest request,
            HttpServletRequest httpRequest
    ) {
        if (request == null || request.xml() == null || request.xml().isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Lifecycle XML is required.");
        }
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        List<ObjectLifecycleRule> importedRules = lifecycleS3XmlService.importRules(request.xml(), OffsetDateTime.now())
                .stream()
                .map(lifecycleRuleRepository::save)
                .toList();
        auditLogService.record(
                "OBJECT_LIFECYCLE_S3_XML_IMPORT",
                user.loginId(),
                "OBJECT_LIFECYCLE_RULE",
                "s3-xml",
                "SUCCESS",
                "Object lifecycle S3 XML imported",
                httpRequest
        );
        return ApiResponse.of(new ObjectLifecycleS3XmlImportResponse(importedRules.size(), importedRules));
    }

    @GetMapping("/object-lifecycle/rules/{ruleId}/dry-run")
    public ApiResponse<ObjectLifecycleRuleDryRunResponse> dryRunObjectLifecycleRule(
            @PathVariable("ruleId") String ruleId,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        ObjectLifecycleRule rule = lifecycleRuleRepository.findById(ruleId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object lifecycle rule not found."));
        int previewLimit = policyNumber(limit, 50, "limit", 1, 500);
        int queryLimit = previewLimit + 1;
        OffsetDateTime cutoff = OffsetDateTime.now().minusDays(rule.retentionDays());
        List<ObjectLifecycleRuleDryRunCandidateResponse> candidates;
        if (ObjectLifecycleRule.TARGET_TRASH_OBJECT.equals(rule.targetType())) {
            List<DeletedObjectCandidate> deletedCandidates = objectMetadataRepository.findDeletedBefore(
                    cutoff,
                    queryLimit,
                    rule.prefix(),
                    rule.tags()
            );
            candidates = deletedCandidates.stream()
                    .limit(previewLimit)
                    .map(this::toDryRunCandidate)
                    .toList();
            return ApiResponse.of(toDryRunResponse(rule, cutoff, previewLimit, deletedCandidates.size() > previewLimit, candidates));
        }
        List<VersionCandidate> versionCandidates = objectVersionRepository.findCreatedBefore(
                cutoff,
                queryLimit,
                rule.prefix(),
                rule.tags()
        );
        candidates = versionCandidates.stream()
                .limit(previewLimit)
                .map(this::toDryRunCandidate)
                .toList();
        return ApiResponse.of(toDryRunResponse(rule, cutoff, previewLimit, versionCandidates.size() > previewLimit, candidates));
    }

    @PostMapping("/object-lifecycle/rules")
    public ApiResponse<ObjectLifecycleRule> saveObjectLifecycleRule(
            @RequestBody ObjectLifecycleRuleRequest request,
            HttpServletRequest httpRequest
    ) {
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Object lifecycle rule body is required.");
        }
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        String ruleId = request.ruleId() == null || request.ruleId().isBlank()
                ? UUID.randomUUID().toString()
                : request.ruleId().trim();
        ObjectLifecycleRule current = lifecycleRuleRepository.findById(ruleId).orElse(null);
        String name = requiredText(request.name(), current == null ? "" : current.name(), "name", 128);
        String targetType = targetType(request.targetType(), current == null ? "" : current.targetType());
        boolean enabled = request.enabled() == null ? current == null || current.enabled() : request.enabled();
        int priority = policyNumber(
                request.priority(),
                current == null ? ObjectLifecycleRule.DEFAULT_PRIORITY : current.priority(),
                "priority",
                1,
                10000
        );
        String prefix = normalizeRulePrefix(request.prefix(), current == null ? "" : current.prefix());
        Map<String, String> tags = request.tags() == null
                ? current == null ? Map.of() : current.tags()
                : parseTags(request.tags());
        int retentionDays = policyNumber(
                request.retentionDays(),
                current == null ? 30 : current.retentionDays(),
                "retentionDays",
                1,
                3650
        );
        int batchSize = policyNumber(
                request.batchSize(),
                current == null ? 100 : current.batchSize(),
                "batchSize",
                1,
                10000
        );
        OffsetDateTime now = OffsetDateTime.now();
        ObjectLifecycleRule rule = lifecycleRuleRepository.save(new ObjectLifecycleRule(
                ruleId,
                name,
                enabled,
                priority,
                targetType,
                prefix,
                tags,
                retentionDays,
                batchSize,
                current == null ? now : current.createdAt(),
                now
        ));
        auditLogService.record(
                "OBJECT_LIFECYCLE_RULE_SAVE",
                user.loginId(),
                "OBJECT_LIFECYCLE_RULE",
                rule.ruleId(),
                "SUCCESS",
                "Object lifecycle rule saved",
                httpRequest
        );
        return ApiResponse.of(rule);
    }

    @DeleteMapping("/object-lifecycle/rules/{ruleId}")
    public ResponseEntity<Void> deleteObjectLifecycleRule(
            @PathVariable("ruleId") String ruleId,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        lifecycleRuleRepository.findById(ruleId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object lifecycle rule not found."));
        lifecycleRuleRepository.delete(ruleId);
        auditLogService.record(
                "OBJECT_LIFECYCLE_RULE_DELETE",
                user.loginId(),
                "OBJECT_LIFECYCLE_RULE",
                ruleId,
                "SUCCESS",
                "Object lifecycle rule deleted",
                httpRequest
        );
        return ResponseEntity.noContent().build();
    }

    private ObjectLifecycleRuleDryRunResponse toDryRunResponse(
            ObjectLifecycleRule rule,
            OffsetDateTime cutoff,
            int previewLimit,
            boolean truncated,
            List<ObjectLifecycleRuleDryRunCandidateResponse> candidates
    ) {
        long candidateBytes = candidates.stream()
                .mapToLong(ObjectLifecycleRuleDryRunCandidateResponse::sizeBytes)
                .sum();
        return new ObjectLifecycleRuleDryRunResponse(
                rule,
                cutoff,
                previewLimit,
                rule.batchSize(),
                candidates.size(),
                candidateBytes,
                truncated,
                candidates
        );
    }

    private ObjectLifecycleRuleDryRunCandidateResponse toDryRunCandidate(DeletedObjectCandidate candidate) {
        String targetId = candidate.bucketName() + "/" + candidate.key();
        return new ObjectLifecycleRuleDryRunCandidateResponse(
                targetId,
                candidate.bucketName(),
                candidate.key(),
                null,
                candidate.sizeBytes(),
                candidate.deletedAt()
        );
    }

    private ObjectLifecycleRuleDryRunCandidateResponse toDryRunCandidate(VersionCandidate candidate) {
        String targetId = candidate.bucketName() + "/" + candidate.version().key() + "#" + candidate.version().versionId();
        return new ObjectLifecycleRuleDryRunCandidateResponse(
                targetId,
                candidate.bucketName(),
                candidate.version().key(),
                candidate.version().versionId(),
                candidate.version().sizeBytes(),
                candidate.version().createdAt()
        );
    }

    private List<ObjectLifecycleRuleConflictResponse> lifecycleRuleConflicts(List<ObjectLifecycleRule> rules) {
        List<ObjectLifecycleRuleConflictResponse> conflicts = new java.util.ArrayList<>();
        for (int firstIndex = 0; firstIndex < rules.size(); firstIndex++) {
            for (int secondIndex = firstIndex + 1; secondIndex < rules.size(); secondIndex++) {
                ObjectLifecycleRule first = rules.get(firstIndex);
                ObjectLifecycleRule second = rules.get(secondIndex);
                if (!first.targetType().equals(second.targetType())) {
                    continue;
                }
                if (!prefixesOverlap(first.prefix(), second.prefix()) || !tagsCompatible(first.tags(), second.tags())) {
                    continue;
                }
                conflicts.add(toLifecycleRuleConflict(first, second));
            }
        }
        return conflicts;
    }

    private ObjectLifecycleRuleConflictResponse toLifecycleRuleConflict(ObjectLifecycleRule first, ObjectLifecycleRule second) {
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

    @PutMapping("/object-retention/policy")
    public ApiResponse<ObjectRetentionStatusResponse> updateObjectRetentionPolicy(
            @RequestBody UpdateObjectRetentionPolicyRequest request,
            HttpServletRequest httpRequest
    ) {
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Object retention policy body is required.");
        }
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        ObjectRetentionPolicy current = retentionPolicyRepository.getPolicy();
        boolean enabled = request.enabled() == null ? current.enabled() : request.enabled();
        int retentionDays = policyNumber(request.retentionDays(), current.retentionDays(), "retentionDays", 1, 3650);
        int batchSize = policyNumber(request.batchSize(), current.batchSize(), "batchSize", 1, 10000);
        int versionRetentionDays = policyNumber(
                request.versionRetentionDays(),
                current.versionRetentionDays(),
                "versionRetentionDays",
                1,
                3650
        );
        int versionBatchSize = policyNumber(
                request.versionBatchSize(),
                current.versionBatchSize(),
                "versionBatchSize",
                1,
                10000
        );
        retentionPolicyRepository.save(new ObjectRetentionPolicy(
                enabled,
                retentionDays,
                batchSize,
                versionRetentionDays,
                versionBatchSize,
                java.time.OffsetDateTime.now()
        ));
        auditLogService.record(
                "OBJECT_RETENTION_POLICY_UPDATE",
                user.loginId(),
                "OBJECT_RETENTION_POLICY",
                "default",
                "SUCCESS",
                "Object retention policy updated",
                httpRequest
        );
        return ApiResponse.of(retentionStatus());
    }

    @PostMapping("/object-retention/purge")
    public ApiResponse<ObjectRetentionRunResponse> runObjectRetentionPurge() {
        ObjectRetentionPurgeJob purgeJob = retentionPurgeJobProvider.getIfAvailable();
        ObjectVersionRetentionPurgeJob versionPurgeJob = versionRetentionPurgeJobProvider.getIfAvailable();
        ObjectRetentionPolicy policy = retentionPolicyRepository.getPolicy();
        if (!objectRetentionEnabled || purgeJob == null || versionPurgeJob == null || !policy.enabled()) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Object retention purge is disabled.");
        }
        int purgedCount = purgeJob.runNow(java.time.OffsetDateTime.now());
        int purgedVersionCount = versionPurgeJob.runNow(java.time.OffsetDateTime.now());
        return ApiResponse.of(new ObjectRetentionRunResponse(purgedCount, purgedVersionCount, retentionStatus()));
    }

    private ObjectRetentionStatusResponse retentionStatus() {
        ObjectRetentionPurgeJob purgeJob = retentionPurgeJobProvider.getIfAvailable();
        ObjectVersionRetentionPurgeJob versionPurgeJob = versionRetentionPurgeJobProvider.getIfAvailable();
        ObjectRetentionPolicy policy = retentionPolicyRepository.getPolicy();
        return new ObjectRetentionStatusResponse(
                objectRetentionEnabled && purgeJob != null && versionPurgeJob != null && policy.enabled(),
                policy.retentionDays(),
                policy.batchSize(),
                policy.versionRetentionDays(),
                policy.versionBatchSize(),
                counterValue("osmu.object.retention.purge.objects", "result", "success"),
                counterValue("osmu.object.retention.purge.objects", "result", "failure"),
                counterValue("osmu.object.retention.purge.runs", "result", "failure"),
                counterValue("osmu.object.version.retention.purge.versions", "result", "success"),
                counterValue("osmu.object.version.retention.purge.versions", "result", "failure"),
                counterValue("osmu.object.version.retention.purge.runs", "result", "failure")
        );
    }

    private String requiredText(String value, String fallback, String fieldName, int maxLength) {
        String normalized = value == null ? fallback : value.trim();
        if (normalized == null || normalized.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " is required.");
        }
        if (normalized.length() > maxLength) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " can be at most " + maxLength + " characters.");
        }
        return normalized;
    }

    private String targetType(String value, String fallback) {
        String normalized = value == null || value.isBlank() ? fallback : value.trim();
        if (!ObjectLifecycleRule.TARGET_TRASH_OBJECT.equals(normalized)
                && !ObjectLifecycleRule.TARGET_OBJECT_VERSION.equals(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "targetType must be TRASH_OBJECT or OBJECT_VERSION.");
        }
        return normalized;
    }

    private String normalizeRulePrefix(String value, String fallback) {
        String normalized = value == null ? fallback : value.trim();
        if (normalized == null) {
            return "";
        }
        if (normalized.startsWith("/")) {
            normalized = normalized.substring(1);
        }
        if (normalized.length() > 1024) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "prefix can be at most 1024 characters.");
        }
        return normalized;
    }

    private Map<String, String> parseTags(String tags) {
        if (tags == null || tags.isBlank()) {
            return Map.of();
        }
        Map<String, String> parsedTags = new LinkedHashMap<>();
        for (String rawPair : tags.split(",")) {
            String pair = rawPair.trim();
            if (pair.isBlank()) {
                continue;
            }
            int separatorIndex = pair.indexOf('=');
            if (separatorIndex <= 0 || separatorIndex == pair.length() - 1) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tags must use key=value pairs.");
            }
            String key = pair.substring(0, separatorIndex).trim();
            String value = pair.substring(separatorIndex + 1).trim();
            if (key.isBlank() || value.isBlank()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tags must use key=value pairs.");
            }
            if (key.length() > 128 || !TAG_KEY_PATTERN.matcher(key).matches()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tag keys are invalid.");
            }
            if (value.length() > 256 || value.chars().anyMatch(Character::isISOControl)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tag values are invalid.");
            }
            parsedTags.put(key, value);
        }
        if (parsedTags.size() > 10) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tags can contain at most 10 pairs.");
        }
        return Map.copyOf(parsedTags);
    }

    private int policyNumber(Integer value, int fallback, String fieldName, int min, int max) {
        if (value == null) {
            return fallback;
        }
        if (value < min || value > max) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be between " + min + " and " + max + ".");
        }
        return value;
    }

    private long countStatus(List<ObjectShareLink> links, String status) {
        return links.stream()
                .filter(link -> status.equals(link.status()))
                .count();
    }

    private int normalizeObjectShareAnalyticsLimit(int limit) {
        if (limit < 1 || limit > 50) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "limit must be between 1 and 50.");
        }
        return limit;
    }

    private String optionalBucketName(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        String normalized = value.trim().toLowerCase(Locale.ROOT);
        if (normalized.length() > 63) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "bucketName can be at most 63 characters.");
        }
        return normalized;
    }

    private String optionalShareLinkStatus(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        String normalized = value.trim().toUpperCase(Locale.ROOT);
        if (!"ACTIVE".equals(normalized)
                && !"EXPIRED".equals(normalized)
                && !"REVOKED".equals(normalized)
                && !"LIMIT_REACHED".equals(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "status must be ACTIVE, EXPIRED, REVOKED, or LIMIT_REACHED.");
        }
        return normalized;
    }

    private double counterValue(String name, String tagName, String tagValue) {
        Counter counter = meterRegistry.find(name).tag(tagName, tagValue).counter();
        return counter == null ? 0.0 : counter.count();
    }
}
