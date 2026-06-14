package com.example.osmu.system;

import com.example.osmu.accesskey.S3AccessPolicyProvisioner;
import com.example.osmu.accesskey.repository.AccessKeyRepository;
import com.example.osmu.audit.repository.AuditLogRepository;
import com.example.osmu.auth.repository.RefreshTokenRepository;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.PresignedUploadSessionRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.user.repository.UserRepository;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class HealthController {

    private final ObjectStorageAdapter storageAdapter;
    private final BucketRepository bucketRepository;
    private final UserRepository userRepository;
    private final AuditLogRepository auditLogRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AccessKeyRepository accessKeyRepository;
    private final ObjectMetadataRepository objectMetadataRepository;
    private final PresignedUploadSessionRepository uploadSessionRepository;
    private final S3AccessPolicyProvisioner policyProvisioner;

    public HealthController(
            ObjectStorageAdapter storageAdapter,
            BucketRepository bucketRepository,
            UserRepository userRepository,
            AuditLogRepository auditLogRepository,
            RefreshTokenRepository refreshTokenRepository,
            AccessKeyRepository accessKeyRepository,
            ObjectMetadataRepository objectMetadataRepository,
            PresignedUploadSessionRepository uploadSessionRepository,
            S3AccessPolicyProvisioner policyProvisioner
    ) {
        this.storageAdapter = storageAdapter;
        this.bucketRepository = bucketRepository;
        this.userRepository = userRepository;
        this.auditLogRepository = auditLogRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.accessKeyRepository = accessKeyRepository;
        this.objectMetadataRepository = objectMetadataRepository;
        this.uploadSessionRepository = uploadSessionRepository;
        this.policyProvisioner = policyProvisioner;
    }

    @GetMapping("/health")
    public ApiResponse<Map<String, String>> health() {
        return ApiResponse.of(Map.of(
                "status", "UP",
                "service", "osmu-backend"
        ));
    }

    @GetMapping("/storage/health")
    public ApiResponse<Map<String, String>> storageHealth() {
        return ApiResponse.of(Map.of(
                "status", storageAdapter.isHealthy() ? "UP" : "DOWN",
                "engine", "in-memory-minio-adapter",
                "accessKeyProvisioner", policyProvisioner.isHealthy() ? "UP" : "DOWN"
        ));
    }

    @GetMapping("/database/health")
    public ApiResponse<Map<String, String>> databaseHealth() {
        boolean healthy = bucketRepository.isHealthy()
                && userRepository.isHealthy()
                && auditLogRepository.isHealthy()
                && refreshTokenRepository.isHealthy()
                && accessKeyRepository.isHealthy()
                && objectMetadataRepository.isHealthy()
                && uploadSessionRepository.isHealthy();
        return ApiResponse.of(Map.of(
                "status", healthy ? "UP" : "DOWN",
                "engine", "metadata-repositories"
        ));
    }
}
