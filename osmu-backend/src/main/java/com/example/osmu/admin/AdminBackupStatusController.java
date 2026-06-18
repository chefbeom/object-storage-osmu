package com.example.osmu.admin;

import com.example.osmu.accesskey.S3AccessPolicyProvisioner;
import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.accesskey.repository.AccessKeyRepository;
import com.example.osmu.audit.repository.AuditLogRepository;
import com.example.osmu.admin.repository.BackupRestoreDrillEvidenceRepository;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.auth.repository.RefreshTokenRepository;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectSharePolicyService;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectRetentionPolicyRepository;
import com.example.osmu.object.repository.ObjectShareLinkRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.object.repository.PresignedUploadSessionRepository;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/backup")
public class AdminBackupStatusController {

    private static final String RESTORE_DRILL_EVENT_TYPE = "BACKUP_RESTORE_DRILL_EVIDENCE";
    private static final String RESTORE_DRILL_TARGET_TYPE = "BACKUP_RESTORE_DRILL";
    private static final int MAX_TEXT_LENGTH = 160;
    private static final int MAX_GAP_COUNT = 20;
    private static final Pattern SECRET_VALUE_PATTERN = Pattern.compile(
            "(?i)(password|passwd|secret|token|access[_-]?key|private[_-]?key)\\s*[:=]|-----BEGIN [A-Z ]*PRIVATE KEY-----|aws_secret_access_key"
    );
    private static final Set<String> DRILL_RESULTS = Set.of("SUCCESS", "FAILED", "PARTIAL");

    private final BucketRepository bucketRepository;
    private final UserRepository userRepository;
    private final OrganizationRepository organizationRepository;
    private final AuditLogRepository auditLogRepository;
    private final AuditLogService auditLogService;
    private final BackupRestoreDrillEvidenceRepository restoreDrillEvidenceRepository;
    private final AuthContext authContext;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AccessKeyRepository accessKeyRepository;
    private final ObjectMetadataRepository objectMetadataRepository;
    private final ObjectLifecycleRuleRepository lifecycleRuleRepository;
    private final ObjectRetentionPolicyRepository retentionPolicyRepository;
    private final ObjectVersionRepository objectVersionRepository;
    private final ObjectShareLinkRepository shareLinkRepository;
    private final PresignedUploadSessionRepository uploadSessionRepository;
    private final ObjectSharePolicyService sharePolicyService;
    private final S3AccessPolicyProvisioner policyProvisioner;
    private final ObjectStorageAdapter storageAdapter;
    private final String metadataMode;
    private final String storageMode;
    private final boolean restoreDrillExecuted;
    private final String lastBackupAt;
    private final String lastRestoreDrillAt;

    public AdminBackupStatusController(
            BucketRepository bucketRepository,
            UserRepository userRepository,
            OrganizationRepository organizationRepository,
            AuditLogRepository auditLogRepository,
            AuditLogService auditLogService,
            BackupRestoreDrillEvidenceRepository restoreDrillEvidenceRepository,
            AuthContext authContext,
            RefreshTokenRepository refreshTokenRepository,
            AccessKeyRepository accessKeyRepository,
            ObjectMetadataRepository objectMetadataRepository,
            ObjectLifecycleRuleRepository lifecycleRuleRepository,
            ObjectRetentionPolicyRepository retentionPolicyRepository,
            ObjectVersionRepository objectVersionRepository,
            ObjectShareLinkRepository shareLinkRepository,
            PresignedUploadSessionRepository uploadSessionRepository,
            ObjectSharePolicyService sharePolicyService,
            S3AccessPolicyProvisioner policyProvisioner,
            ObjectStorageAdapter storageAdapter,
            @Value("${osmu.metadata.mode:in-memory}") String metadataMode,
            @Value("${osmu.storage.mode:in-memory}") String storageMode,
            @Value("${osmu.backup.restore-drill-executed:false}") boolean restoreDrillExecuted,
            @Value("${osmu.backup.last-backup-at:}") String lastBackupAt,
            @Value("${osmu.backup.last-restore-drill-at:}") String lastRestoreDrillAt
    ) {
        this.bucketRepository = bucketRepository;
        this.userRepository = userRepository;
        this.organizationRepository = organizationRepository;
        this.auditLogRepository = auditLogRepository;
        this.auditLogService = auditLogService;
        this.restoreDrillEvidenceRepository = restoreDrillEvidenceRepository;
        this.authContext = authContext;
        this.refreshTokenRepository = refreshTokenRepository;
        this.accessKeyRepository = accessKeyRepository;
        this.objectMetadataRepository = objectMetadataRepository;
        this.lifecycleRuleRepository = lifecycleRuleRepository;
        this.retentionPolicyRepository = retentionPolicyRepository;
        this.objectVersionRepository = objectVersionRepository;
        this.shareLinkRepository = shareLinkRepository;
        this.uploadSessionRepository = uploadSessionRepository;
        this.sharePolicyService = sharePolicyService;
        this.policyProvisioner = policyProvisioner;
        this.storageAdapter = storageAdapter;
        this.metadataMode = metadataMode;
        this.storageMode = storageMode;
        this.restoreDrillExecuted = restoreDrillExecuted;
        this.lastBackupAt = blankToNull(lastBackupAt);
        this.lastRestoreDrillAt = blankToNull(lastRestoreDrillAt);
    }

    @GetMapping("/status")
    public ApiResponse<BackupStatusResponse> status() {
        boolean databaseHealthy = bucketRepository.isHealthy()
                && userRepository.isHealthy()
                && organizationRepository.isHealthy()
                && auditLogRepository.isHealthy()
                && restoreDrillEvidenceRepository.isHealthy()
                && refreshTokenRepository.isHealthy()
                && accessKeyRepository.isHealthy()
                && objectMetadataRepository.isHealthy()
                && lifecycleRuleRepository.isHealthy()
                && retentionPolicyRepository.isHealthy()
                && objectVersionRepository.isHealthy()
                && shareLinkRepository.isHealthy()
                && uploadSessionRepository.isHealthy()
                && sharePolicyService.isHealthy()
                && policyProvisioner.isHealthy();
        boolean storageHealthy = storageAdapter.isHealthy();
        String normalizedMetadataMode = mode(metadataMode);
        String normalizedStorageMode = mode(storageMode);
        BackupRestoreDrillEvidenceResponse latestSuccessfulDrill = latestRestoreDrillEvidence("SUCCESS");
        BackupRestoreDrillEvidenceResponse latestAnyDrill = latestRestoreDrillEvidence(null);
        boolean successfulRestoreDrillExecuted = restoreDrillExecuted || latestSuccessfulDrill != null;
        String effectiveLastRestoreDrillAt = firstPresent(
                lastRestoreDrillAt,
                latestSuccessfulDrill == null ? null : latestSuccessfulDrill.recordedAt(),
                latestAnyDrill == null ? null : latestAnyDrill.recordedAt()
        );
        List<String> pendingGates = new ArrayList<>();
        if (!"mariadb".equals(normalizedMetadataMode)) {
            pendingGates.add("MariaDB metadata mode is not enabled.");
        }
        if (!"minio".equals(normalizedStorageMode)) {
            pendingGates.add("MinIO object storage mode is not enabled.");
        }
        if (!successfulRestoreDrillExecuted) {
            pendingGates.add("Successful restore drill evidence has not been recorded.");
        }
        return ApiResponse.of(new BackupStatusResponse(
                pendingGates.isEmpty() && databaseHealthy && storageHealthy ? "READY" : "DRILL_PENDING",
                normalizedMetadataMode,
                normalizedStorageMode,
                databaseHealthy,
                storageHealthy,
                "24h",
                "4h",
                true,
                successfulRestoreDrillExecuted,
                lastBackupAt,
                effectiveLastRestoreDrillAt,
                latestSuccessfulDrill == null ? latestAnyDrill : latestSuccessfulDrill,
                List.copyOf(pendingGates)
        ));
    }

    @GetMapping("/restore-drill-evidence")
    public ListResponse<BackupRestoreDrillEvidenceResponse> listRestoreDrillEvidence(
            @RequestParam(name = "result", required = false) String result,
            @RequestParam(name = "limit", defaultValue = "20") int limit
    ) {
        return ListResponse.of(restoreDrillEvidenceRepository.findRecent(normalizeOptionalResult(result), boundedLimit(limit)));
    }

    @PostMapping("/restore-drill-evidence")
    public ApiResponse<BackupRestoreDrillEvidenceResponse> recordRestoreDrillEvidence(
            @RequestBody(required = false) BackupRestoreDrillEvidenceRequest payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        BackupRestoreDrillEvidenceResponse response = normalizeRestoreDrillEvidence(payload, user.loginId(), null);
        String message = limitText(
                "restoreDrill result=%s env=%s duration=%dm rpo=%sh rtoMet=%s manifest=%s gaps=%d".formatted(
                        response.result(),
                        response.environment(),
                        response.restoreDurationMinutes(),
                        response.observedRpoHours(),
                        response.rtoTargetMet(),
                        response.backupManifestSha256() == null ? "-" : response.backupManifestSha256(),
                        response.gaps().size()
                ),
                480,
                "audit message"
        );
        AuditLogEntry entry = auditLogService.record(
                RESTORE_DRILL_EVENT_TYPE,
                user.loginId(),
                RESTORE_DRILL_TARGET_TYPE,
                response.environment(),
                response.result(),
                message,
                request
        );
        BackupRestoreDrillEvidenceResponse storedEvidence = restoreDrillEvidenceRepository.save(new BackupRestoreDrillEvidenceResponse(
                entry.id(),
                response.environment(),
                response.operator(),
                response.result(),
                response.startedAt(),
                response.completedAt(),
                response.backupTimestamp(),
                response.restoreDurationMinutes(),
                response.observedRpoHours(),
                response.rpoTargetMet(),
                response.rtoTargetMet(),
                response.metadataRowCount(),
                response.objectCount(),
                response.objectBytes(),
                response.backupManifestSha256(),
                response.evidenceUri(),
                response.gaps(),
                response.statusImpact(),
                entry.createdAt().toString()
        ));
        return ApiResponse.of(storedEvidence);
    }

    private BackupRestoreDrillEvidenceResponse latestRestoreDrillEvidence(String result) {
        return restoreDrillEvidenceRepository.findLatestByResult(result).orElse(null);
    }

    private BackupRestoreDrillEvidenceResponse normalizeRestoreDrillEvidence(
            BackupRestoreDrillEvidenceRequest payload,
            String authenticatedLoginId,
            Long auditLogId
    ) {
        if (payload == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "restore drill evidence payload is required.");
        }
        String environment = requiredText(payload.environment(), "environment");
        String operator = requiredText(firstPresent(payload.operator(), authenticatedLoginId), "operator");
        String result = normalizeResult(payload.result());
        OffsetDateTime startedAt = parseTime(payload.startedAt(), "startedAt");
        OffsetDateTime completedAt = parseTime(payload.completedAt(), "completedAt");
        OffsetDateTime backupTimestamp = parseTime(payload.backupTimestamp(), "backupTimestamp");
        if (completedAt.isBefore(startedAt)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "completedAt must be after startedAt.");
        }
        if (backupTimestamp.isAfter(completedAt)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "backupTimestamp must be before or equal to completedAt.");
        }
        long restoreDurationMinutes = Math.max(1L, Duration.between(startedAt, completedAt).toMinutes());
        long observedRpoHours = Math.max(0L, Duration.between(backupTimestamp, completedAt).toHours());
        long metadataRowCount = nonNegative(payload.metadataRowCount(), "metadataRowCount");
        long objectCount = nonNegative(payload.objectCount(), "objectCount");
        long objectBytes = nonNegative(payload.objectBytes(), "objectBytes");
        String backupManifestSha256 = optionalSha256(payload.backupManifestSha256(), "backupManifestSha256");
        String evidenceUri = optionalText(payload.evidenceUri(), 255, "evidenceUri");
        List<String> gaps = normalizeGaps(payload.gaps());
        boolean rpoTargetMet = observedRpoHours <= 24L;
        boolean rtoTargetMet = restoreDurationMinutes <= 240L;
        String statusImpact = "SUCCESS".equals(result) && rpoTargetMet && rtoTargetMet
                ? "READY_GATE_SATISFIED"
                : "REVIEW_REQUIRED";
        return new BackupRestoreDrillEvidenceResponse(
                auditLogId == null ? 0L : auditLogId,
                environment,
                operator,
                result,
                startedAt.toString(),
                completedAt.toString(),
                backupTimestamp.toString(),
                restoreDurationMinutes,
                observedRpoHours,
                rpoTargetMet,
                rtoTargetMet,
                metadataRowCount,
                objectCount,
                objectBytes,
                backupManifestSha256,
                evidenceUri,
                gaps,
                statusImpact,
                null
        );
    }

    private String mode(String value) {
        return value == null || value.isBlank() ? "in-memory" : value.trim().toLowerCase(Locale.ROOT);
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private String normalizeResult(String value) {
        String normalized = requiredText(value, "result").toUpperCase(Locale.ROOT);
        if (!DRILL_RESULTS.contains(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "result must be one of SUCCESS, FAILED, or PARTIAL.");
        }
        return normalized;
    }

    private String normalizeOptionalResult(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String normalized = value.trim().toUpperCase(Locale.ROOT);
        if (!DRILL_RESULTS.contains(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "result must be one of SUCCESS, FAILED, or PARTIAL.");
        }
        return normalized;
    }

    private int boundedLimit(int limit) {
        if (limit < 1 || limit > 100) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "limit must be between 1 and 100.");
        }
        return limit;
    }

    private OffsetDateTime parseTime(String value, String fieldName) {
        String normalized = requiredText(value, fieldName);
        try {
            return OffsetDateTime.parse(normalized);
        } catch (DateTimeParseException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be ISO-8601 offset date time.");
        }
    }

    private long nonNegative(Long value, String fieldName) {
        if (value == null || value < 0L) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be zero or greater.");
        }
        return value;
    }

    private String requiredText(String value, String fieldName) {
        String normalized = optionalText(value, MAX_TEXT_LENGTH, fieldName);
        if (normalized == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " is required.");
        }
        return normalized;
    }

    private String optionalText(String value, int maxLength, String fieldName) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String normalized = value.trim();
        return limitText(rejectSecretValue(normalized, fieldName), maxLength, fieldName);
    }

    private String limitText(String value, int maxLength, String fieldName) {
        if (value.length() > maxLength) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be " + maxLength + " characters or fewer.");
        }
        return value;
    }

    private String rejectSecretValue(String value, String fieldName) {
        if (SECRET_VALUE_PATTERN.matcher(value).find()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must not contain secret values.");
        }
        return value;
    }

    private String optionalSha256(String value, String fieldName) {
        String normalized = optionalText(value, 64, fieldName);
        if (normalized == null) {
            return null;
        }
        if (!normalized.matches("[0-9a-fA-F]{64}")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be a 64-character SHA-256 hex string.");
        }
        return normalized.toLowerCase(Locale.ROOT);
    }

    private List<String> normalizeGaps(List<String> values) {
        if (values == null) {
            return List.of();
        }
        if (values.size() > MAX_GAP_COUNT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "gaps must contain at most 20 items.");
        }
        return values.stream()
                .map(value -> optionalText(value, MAX_TEXT_LENGTH, "gaps"))
                .filter(value -> value != null)
                .toList();
    }

    private String firstPresent(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value.trim();
            }
        }
        return null;
    }
}
