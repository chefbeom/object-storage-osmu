package com.example.osmu.admin;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;

import com.example.osmu.object.ObjectSharePolicy;
import com.example.osmu.object.ObjectSharePolicyRequest;
import com.example.osmu.object.ObjectSharePolicyService;
import com.example.osmu.object.repository.ObjectShareLinkRepository;
import jakarta.servlet.http.HttpServletRequest;

import java.util.Locale;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin")
public class AdminObjectSharePolicyController {

    private final ObjectSharePolicyService sharePolicyService;
    private final ObjectShareLinkRepository shareLinkRepository;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;

    public AdminObjectSharePolicyController(
            ObjectSharePolicyService sharePolicyService,
            ObjectShareLinkRepository shareLinkRepository,
            AuditLogService auditLogService,
            AuthContext authContext
    ) {
        this.sharePolicyService = sharePolicyService;
        this.shareLinkRepository = shareLinkRepository;
        this.auditLogService = auditLogService;
        this.authContext = authContext;
    }

    @GetMapping("/object-share-policy")
    public ApiResponse<ObjectSharePolicy> currentPolicy() {
        return ApiResponse.of(sharePolicyService.current());
    }

    @PutMapping("/object-share-policy")
    public ApiResponse<ObjectSharePolicy> savePolicy(
            @RequestBody ObjectSharePolicyRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        ObjectSharePolicy saved = sharePolicyService.save(request);
        auditLogService.record(
                "OBJECT_SHARE_POLICY_SAVE",
                user.loginId(),
                "OBJECT_SHARE_POLICY",
                "global",
                "SUCCESS",
                request == null || request.reason() == null || request.reason().isBlank()
                        ? "Object share policy saved"
                        : request.reason().trim(),
                httpRequest
        );
        return ApiResponse.of(saved);
    }

    @GetMapping("/object-share-analytics")
    public ApiResponse<ObjectShareAnalyticsResponse> analytics(
            @RequestParam(name = "limit", defaultValue = "10") int limit,
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "status", required = false) String status
    ) {
        int normalizedLimit = normalizeLimit(limit);
        String normalizedBucketName = optionalBucketName(bucketName);
        String normalizedStatus = optionalStatus(status);
        return ApiResponse.of(ObjectShareAnalyticsResponse.of(
                shareLinkRepository.analytics(normalizedBucketName, normalizedStatus, normalizedLimit)
        ));
    }

    private int normalizeLimit(int limit) {
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

    private String optionalStatus(String value) {
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
}
