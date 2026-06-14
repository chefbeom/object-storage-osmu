package com.example.osmu.admin;

import com.example.osmu.accesskey.S3AccessPolicyProvisioner;
import com.example.osmu.accesskey.repository.AccessKeyRepository;
import com.example.osmu.audit.repository.AuditLogRepository;
import com.example.osmu.auth.repository.RefreshTokenRepository;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.common.api.ApiResponse;
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
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/backup")
public class AdminBackupStatusController {

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
        List<String> pendingGates = new ArrayList<>();
        if (!"mariadb".equals(normalizedMetadataMode)) {
            pendingGates.add("MariaDB metadata mode is not enabled.");
        }
        if (!"minio".equals(normalizedStorageMode)) {
            pendingGates.add("MinIO object storage mode is not enabled.");
        }
        if (!restoreDrillExecuted) {
            pendingGates.add("Restore drill has not been executed in this runtime.");
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
                restoreDrillExecuted,
                lastBackupAt,
                lastRestoreDrillAt,
                List.copyOf(pendingGates)
        ));
    }

    private String mode(String value) {
        return value == null || value.isBlank() ? "in-memory" : value.trim().toLowerCase(Locale.ROOT);
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
