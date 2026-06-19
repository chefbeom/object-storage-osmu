package com.example.osmu.auth;

import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.common.api.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/security")
public class AdminEnterpriseAuthPlanController {

    private final AuthContext authContext;
    private final AuditLogService auditLogService;
    private final EnterpriseAuthPlanService enterpriseAuthPlanService;
    private final OidcClaimPreviewService oidcClaimPreviewService;
    private final OidcJitProvisioningService oidcJitProvisioningService;

    public AdminEnterpriseAuthPlanController(
            AuthContext authContext,
            AuditLogService auditLogService,
            EnterpriseAuthPlanService enterpriseAuthPlanService,
            OidcClaimPreviewService oidcClaimPreviewService,
            OidcJitProvisioningService oidcJitProvisioningService
    ) {
        this.authContext = authContext;
        this.auditLogService = auditLogService;
        this.enterpriseAuthPlanService = enterpriseAuthPlanService;
        this.oidcClaimPreviewService = oidcClaimPreviewService;
        this.oidcJitProvisioningService = oidcJitProvisioningService;
    }

    @GetMapping("/enterprise-auth-plan")
    public ApiResponse<EnterpriseAuthPlanResponse> enterpriseAuthPlan() {
        return ApiResponse.of(enterpriseAuthPlanService.plan());
    }

    @PostMapping("/enterprise-auth/claim-preview")
    public ApiResponse<OidcClaimPreviewResponse> previewOidcClaims(
            @Valid @RequestBody OidcClaimPreviewRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        OidcClaimPreviewResponse preview = oidcClaimPreviewService.preview(request.claims());
        AuditLogEntry auditLog = auditLogService.record(
                "OIDC_CLAIM_PREVIEW",
                user.loginId(),
                "OIDC_CLAIM",
                preview.email().isBlank() ? preview.subject() : preview.email(),
                preview.status().startsWith("MATCHED") || preview.status().startsWith("REQUIRES") ? "SUCCESS" : "REVIEW",
                "OIDC claim preview: status=%s, primaryRole=%s, jitRequired=%s"
                        .formatted(preview.status(), preview.primaryRole(), preview.jitProvisioningRequired()),
                httpRequest
        );
        return ApiResponse.of(preview.withAuditLogId(auditLog.id()));
    }

    @PostMapping("/enterprise-auth/jit-provision")
    public ApiResponse<OidcJitProvisionResponse> provisionOidcUser(
            @Valid @RequestBody OidcJitProvisionRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        OidcJitProvisionResponse provision = oidcJitProvisioningService.provision(request);
        AuditLogEntry auditLog = auditLogService.record(
                "OIDC_JIT_PROVISION",
                user.loginId(),
                "USER",
                provision.user().loginId(),
                "SUCCESS",
                "OIDC JIT provision: status=%s, approvedRole=%s, organizationId=%s, privilegedApproved=%s"
                        .formatted(
                                provision.status(),
                                provision.approvedRole(),
                                provision.organizationId(),
                                provision.privilegedRoleApproved()
                        ),
                httpRequest
        );
        return ApiResponse.of(provision.withAuditLogId(auditLog.id()));
    }
}
