package com.example.osmu.storageexpansion;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/storage-expansion")
public class AdminStorageExpansionController {

    private final StorageExpansionService storageExpansionService;
    private final AuthContext authContext;
    private final AuditLogService auditLogService;

    public AdminStorageExpansionController(
            StorageExpansionService storageExpansionService,
            AuthContext authContext,
            AuditLogService auditLogService
    ) {
        this.storageExpansionService = storageExpansionService;
        this.authContext = authContext;
        this.auditLogService = auditLogService;
    }

    @GetMapping("/requests")
    public ListResponse<StorageExpansionRequestResponse> list(
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "cursor", required = false) String cursor,
            @RequestParam(value = "limit", required = false) Integer limit,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        return storageExpansionService.list(user, status, cursor, limit);
    }

    @GetMapping("/summary")
    public ApiResponse<StorageExpansionSummaryResponse> summary(HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(storageExpansionService.summary(user));
    }

    @GetMapping("/runner-preflight")
    public ApiResponse<StorageExpansionRunnerPreflightResponse> runnerPreflight(HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(storageExpansionService.runnerPreflight(user));
    }

    @GetMapping("/execution-log-retention/status")
    public ApiResponse<StorageExpansionExecutionLogRetentionStatusResponse> executionLogRetentionStatus(
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(storageExpansionService.executionLogRetentionStatus(user));
    }

    @PostMapping("/execution-log-retention/run")
    public ApiResponse<StorageExpansionExecutionLogRetentionRunResponse> runExecutionLogRetention(
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionExecutionLogRetentionRunResponse response = storageExpansionService.runExecutionLogRetention(user);
        auditLogService.record(
                "STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_RUN",
                user.loginId(),
                "STORAGE_EXPANSION_EXECUTION",
                "all-requests",
                "SUCCESS",
                "Storage expansion execution log retention run: " + response.redactedOutputCount(),
                request
        );
        return ApiResponse.of(response);
    }

    @PostMapping("/requests")
    public ApiResponse<StorageExpansionRequestResponse> create(
            @RequestBody(required = false) StorageExpansionRequestPayload payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionRequestResponse response = storageExpansionService.create(user, payload);
        auditLogService.record("STORAGE_EXPANSION_REQUEST_CREATE", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.id()), "SUCCESS", "Storage expansion request created", request);
        return ApiResponse.of(response);
    }

    @GetMapping("/requests/{requestId}/manifest")
    public ApiResponse<StorageExpansionManifestResponse> manifest(
            @PathVariable long requestId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionManifestResponse response = storageExpansionService.manifest(user, requestId);
        auditLogService.record("STORAGE_EXPANSION_REQUEST_MANIFEST", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion manifest preview generated", request);
        return ApiResponse.of(response);
    }

    @GetMapping(value = "/requests/{requestId}/manifest/{artifact}", produces = "application/x-yaml")
    public ResponseEntity<byte[]> downloadManifestArtifact(
            @PathVariable long requestId,
            @PathVariable String artifact,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionManifestArtifact response = storageExpansionService.manifestArtifact(user, requestId, artifact);
        auditLogService.record("STORAGE_EXPANSION_REQUEST_MANIFEST_DOWNLOAD", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion manifest downloaded: " + response.artifact(), request);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("application/x-yaml"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + response.fileName() + "\"")
                .body(response.content().getBytes(StandardCharsets.UTF_8));
    }

    @PostMapping("/requests/{requestId}/execution-plan")
    public ApiResponse<StorageExpansionExecutionPlanResponse> executionPlan(
            @PathVariable long requestId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionExecutionPlanResponse response = storageExpansionService.executionPlan(user, requestId);
        auditLogService.record("STORAGE_EXPANSION_REQUEST_EXECUTION_PLAN", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion execution plan generated", request);
        return ApiResponse.of(response);
    }

    @PostMapping("/requests/{requestId}/gitops-plan")
    public ApiResponse<StorageExpansionGitOpsPlanResponse> gitOpsPlan(
            @PathVariable long requestId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionGitOpsPlanResponse response = storageExpansionService.gitOpsPlan(user, requestId);
        auditLogService.record("STORAGE_EXPANSION_REQUEST_GITOPS_PLAN", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion GitOps plan generated", request);
        return ApiResponse.of(response);
    }

    @GetMapping(value = "/requests/{requestId}/gitops-artifacts/bundle", produces = "application/zip")
    public ResponseEntity<byte[]> downloadGitOpsArtifactBundle(
            @PathVariable long requestId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionGitOpsArtifactBundle response = storageExpansionService.gitOpsArtifactBundle(user, requestId);
        auditLogService.record("STORAGE_EXPANSION_REQUEST_GITOPS_ARTIFACT_DOWNLOAD", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion GitOps artifact bundle downloaded", request);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("application/zip"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + response.fileName() + "\"")
                .body(response.content());
    }

    @PostMapping("/requests/{requestId}/dry-run-execution")
    public ApiResponse<StorageExpansionExecutionResponse> recordDryRunExecution(
            @PathVariable long requestId,
            @RequestBody(required = false) StorageExpansionDryRunExecutionPayload payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionExecutionResponse response = storageExpansionService.recordDryRunExecution(user, requestId, payload);
        auditLogService.record("STORAGE_EXPANSION_DRY_RUN_EXECUTION", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion dry-run execution recorded: " + response.executionType(), request);
        return ApiResponse.of(response);
    }

    @PostMapping("/requests/{requestId}/dry-run-runner")
    public ApiResponse<StorageExpansionExecutionResponse> runDryRunExecution(
            @PathVariable long requestId,
            @RequestBody(required = false) StorageExpansionDryRunRunPayload payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionExecutionResponse response = storageExpansionService.runDryRunExecution(user, requestId, payload);
        auditLogService.record("STORAGE_EXPANSION_DRY_RUN_RUNNER", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion dry-run runner completed: " + response.executionType() + " " + response.result(), request);
        return ApiResponse.of(response);
    }

    @PostMapping("/requests/{requestId}/apply-runner")
    public ApiResponse<StorageExpansionApplyRunResponse> runApplyExecution(
            @PathVariable long requestId,
            @RequestBody(required = false) StorageExpansionApplyRunPayload payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionApplyRunResponse response = storageExpansionService.runApplyExecution(user, requestId, payload);
        auditLogService.record("STORAGE_EXPANSION_APPLY_RUNNER", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.request().id()), "SUCCESS", "Storage expansion apply runner completed: " + response.execution().result(), request);
        return ApiResponse.of(response);
    }

    @PostMapping("/requests/{requestId}/rollback-runner")
    public ApiResponse<StorageExpansionRollbackRunResponse> runRollbackExecution(
            @PathVariable long requestId,
            @RequestBody(required = false) StorageExpansionRollbackRunPayload payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionRollbackRunResponse response = storageExpansionService.runRollbackExecution(user, requestId, payload);
        auditLogService.record("STORAGE_EXPANSION_ROLLBACK_RUNNER", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.request().id()), "SUCCESS", "Storage expansion rollback runner completed: " + response.execution().result(), request);
        return ApiResponse.of(response);
    }

    @PostMapping("/requests/{requestId}/gitops-pr-execution")
    public ApiResponse<StorageExpansionExecutionResponse> recordGitOpsPrExecution(
            @PathVariable long requestId,
            @RequestBody(required = false) StorageExpansionGitOpsPrExecutionPayload payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionExecutionResponse response = storageExpansionService.recordGitOpsPrExecution(user, requestId, payload);
        auditLogService.record("STORAGE_EXPANSION_GITOPS_PR_EXECUTION", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion GitOps PR execution recorded", request);
        return ApiResponse.of(response);
    }

    @PostMapping("/requests/{requestId}/gitops-pr-runner")
    public ApiResponse<StorageExpansionExecutionResponse> runGitOpsPrExecution(
            @PathVariable long requestId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionExecutionResponse response = storageExpansionService.runGitOpsPrExecution(user, requestId);
        auditLogService.record("STORAGE_EXPANSION_GITOPS_PR_RUNNER", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion GitOps PR runner completed: " + response.result(), request);
        return ApiResponse.of(response);
    }

    @GetMapping("/requests/{requestId}/executions")
    public ListResponse<StorageExpansionExecutionResponse> executions(
            @PathVariable long requestId,
            @RequestParam(value = "cursor", required = false) String cursor,
            @RequestParam(value = "limit", required = false) Integer limit,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        return storageExpansionService.listExecutions(user, requestId, cursor, limit);
    }

    @PostMapping("/requests/{requestId}/executions")
    public ApiResponse<StorageExpansionExecutionResponse> createExecution(
            @PathVariable long requestId,
            @RequestBody(required = false) StorageExpansionExecutionPayload payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionExecutionResponse response = storageExpansionService.createExecution(user, requestId, payload);
        auditLogService.record("STORAGE_EXPANSION_EXECUTION_RECORD_CREATE", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.requestId()), "SUCCESS", "Storage expansion execution history recorded: " + response.executionType(), request);
        return ApiResponse.of(response);
    }

    @PostMapping("/requests/{requestId}/executions/{executionId}/apply")
    public ApiResponse<StorageExpansionRequestResponse> applyFromExecution(
            @PathVariable long requestId,
            @PathVariable long executionId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionRequestResponse response = storageExpansionService.applyFromExecution(user, requestId, executionId);
        auditLogService.record("STORAGE_EXPANSION_EXECUTION_APPLY", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.id()), "SUCCESS", "Storage expansion applied from execution record " + executionId, request);
        return ApiResponse.of(response);
    }

    @PatchMapping("/requests/{requestId}/status")
    public ApiResponse<StorageExpansionRequestResponse> updateStatus(
            @PathVariable long requestId,
            @RequestBody(required = false) StorageExpansionStatusRequest statusRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageExpansionRequestResponse response = storageExpansionService.updateStatus(user, requestId, statusRequest);
        auditLogService.record("STORAGE_EXPANSION_REQUEST_STATUS", user.loginId(), "STORAGE_EXPANSION_REQUEST", String.valueOf(response.id()), "SUCCESS", "Storage expansion request status updated to " + response.status(), request);
        return ApiResponse.of(response);
    }
}
