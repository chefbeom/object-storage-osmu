package com.example.osmu.storageexpansion;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storageexpansion.repository.StorageExpansionExecutionRepository;
import com.example.osmu.storageexpansion.repository.StorageExpansionRequestRepository;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class StorageExpansionService {

    private static final long GIB = 1024L * 1024L * 1024L;
    private static final long MIN_VOLUME_SIZE_BYTES = 10L * GIB;
    private static final long MAX_REQUESTED_CAPACITY_BYTES = 1024L * 1024L * GIB;
    private static final int DEFAULT_SERVER_COUNT = 4;
    private static final int DEFAULT_VOLUMES_PER_SERVER = 1;
    private static final int MIN_SERVER_COUNT = 4;
    private static final int MAX_SERVER_COUNT = 32;
    private static final int MAX_VOLUMES_PER_SERVER = 16;
    private static final int MAX_REASON_LENGTH = 512;
    private static final int MAX_APPLIED_EVIDENCE_LENGTH = 512;
    private static final int MAX_EXECUTION_COMMAND_LENGTH = 1024;
    private static final int MAX_EXECUTION_OUTPUT_LENGTH = 16384;
    private static final int MAX_EXECUTION_URL_LENGTH = 1024;
    private static final int MAX_EXECUTION_NOTES_LENGTH = 1024;
    private static final int DEFAULT_LIST_LIMIT = 50;
    private static final int MAX_LIST_LIMIT = 200;
    private static final Set<String> STATUSES = Set.of("PLANNED", "APPROVED", "REJECTED", "APPLIED");
    private static final Set<String> EXECUTION_TYPES = Set.of("DRY_RUN", "GITOPS_PR", "HELM_DIFF", "KUBECTL_DIFF", "APPLY", "ROLLBACK");
    private static final Set<String> EXECUTION_RESULTS = Set.of("SUCCESS", "FAILED", "SKIPPED");

    private final StorageExpansionRequestRepository repository;
    private final StorageExpansionExecutionRepository executionRepository;
    private final StorageExpansionDryRunRunner dryRunRunner;
    private final StorageExpansionApplyRunner applyRunner;
    private final StorageExpansionRollbackRunner rollbackRunner;
    private final StorageExpansionGitOpsPrRunner gitOpsPrRunner;
    private final StorageExpansionPostRunVerifier postRunVerifier;
    private final StorageExpansionExecutionLogSanitizer executionLogSanitizer;
    private final ObjectProvider<StorageExpansionExecutionLogRetentionJob> executionLogRetentionJobProvider;
    private final StorageExpansionRunnerPreflightService runnerPreflightService;
    private final boolean executionLogRetentionEnabled;
    private final int executionLogRetentionDays;
    private final int executionLogRetentionBatchSize;

    public StorageExpansionService(
            StorageExpansionRequestRepository repository,
            StorageExpansionExecutionRepository executionRepository,
            StorageExpansionDryRunRunner dryRunRunner,
            StorageExpansionApplyRunner applyRunner,
            StorageExpansionRollbackRunner rollbackRunner,
            StorageExpansionGitOpsPrRunner gitOpsPrRunner,
            StorageExpansionPostRunVerifier postRunVerifier,
            StorageExpansionExecutionLogSanitizer executionLogSanitizer,
            ObjectProvider<StorageExpansionExecutionLogRetentionJob> executionLogRetentionJobProvider,
            StorageExpansionRunnerPreflightService runnerPreflightService,
            @Value("${osmu.storage-expansion.execution-log.retention.enabled:true}") boolean executionLogRetentionEnabled,
            @Value("${osmu.storage-expansion.execution-log.retention.retention-days:90}") int executionLogRetentionDays,
            @Value("${osmu.storage-expansion.execution-log.retention.batch-size:100}") int executionLogRetentionBatchSize
    ) {
        this.repository = repository;
        this.executionRepository = executionRepository;
        this.dryRunRunner = dryRunRunner;
        this.applyRunner = applyRunner;
        this.rollbackRunner = rollbackRunner;
        this.gitOpsPrRunner = gitOpsPrRunner;
        this.postRunVerifier = postRunVerifier;
        this.executionLogSanitizer = executionLogSanitizer;
        this.executionLogRetentionJobProvider = executionLogRetentionJobProvider;
        this.runnerPreflightService = runnerPreflightService;
        this.executionLogRetentionEnabled = executionLogRetentionEnabled;
        this.executionLogRetentionDays = clamp(executionLogRetentionDays, 1, 3650);
        this.executionLogRetentionBatchSize = clamp(executionLogRetentionBatchSize, 1, 1000);
    }

    public ListResponse<StorageExpansionRequestResponse> list(
            AuthenticatedUser user,
            String status,
            String cursor,
            Integer limit
    ) {
        requireAdmin(user);
        int pageSize = normalizeListLimit(limit);
        List<StorageExpansionRequestRecord> matchedRequests = repository.findPage(
                normalizeListStatuses(status),
                parseListCursor(cursor),
                pageSize + 1
        );
        boolean hasNextPage = matchedRequests.size() > pageSize;
        List<StorageExpansionRequestRecord> page = hasNextPage
                ? matchedRequests.subList(0, pageSize)
                : matchedRequests;
        List<StorageExpansionRequestResponse> items = page.stream()
                .map(StorageExpansionRequestResponse::of)
                .toList();
        String nextCursor = hasNextPage ? String.valueOf(page.get(page.size() - 1).id()) : null;
        return ListResponse.of(items, nextCursor);
    }

    public StorageExpansionSummaryResponse summary(AuthenticatedUser user) {
        requireAdmin(user);
        StorageExpansionRequestAggregate requestAggregate = repository.aggregate();
        StorageExpansionRequestResponse latestRequest = repository.findLatest()
                .map(StorageExpansionRequestResponse::of)
                .orElse(null);
        StorageExpansionExecutionResponse latestExecution = executionRepository.findLatest()
                .map(StorageExpansionExecutionResponse::of)
                .orElse(null);
        List<StorageExpansionExecutionResponse> recentExecutions = executionRepository.findRecent(5).stream()
                .map(StorageExpansionExecutionResponse::of)
                .toList();
        return new StorageExpansionSummaryResponse(
                requestAggregate.requestCount(),
                requestAggregate.openRequestCount(),
                requestAggregate.plannedRequestCount(),
                requestAggregate.approvedRequestCount(),
                requestAggregate.appliedRequestCount(),
                requestAggregate.rejectedRequestCount(),
                requestAggregate.totalRequestedCapacityBytes(),
                requestAggregate.openRequestedCapacityBytes(),
                requestAggregate.totalEstimatedUsableCapacityBytes(),
                requestAggregate.openEstimatedUsableCapacityBytes(),
                executionRepository.countAll(),
                executionRepository.countByResult("SUCCESS"),
                executionRepository.countByResult("FAILED"),
                executionRepository.countByResult("SKIPPED"),
                executionRepository.countTimedOut(),
                latestRequest,
                latestExecution,
                recentExecutions
        );
    }

    public StorageExpansionExecutionLogRetentionStatusResponse executionLogRetentionStatus(AuthenticatedUser user) {
        requireAdmin(user);
        StorageExpansionExecutionLogRetentionJob job = executionLogRetentionJobProvider.getIfAvailable();
        if (executionLogRetentionEnabled && job != null) {
            return job.status(OffsetDateTime.now());
        }
        OffsetDateTime cutoff = OffsetDateTime.now().minusDays(executionLogRetentionDays);
        return new StorageExpansionExecutionLogRetentionStatusResponse(
                false,
                executionLogRetentionDays,
                executionLogRetentionBatchSize,
                executionRepository.countOutputsBefore(cutoff),
                0.0,
                0.0
        );
    }

    public StorageExpansionRunnerPreflightResponse runnerPreflight(AuthenticatedUser user) {
        requireAdmin(user);
        return runnerPreflightService.preflight();
    }

    public StorageExpansionExecutionLogRetentionRunResponse runExecutionLogRetention(AuthenticatedUser user) {
        requireAdmin(user);
        StorageExpansionExecutionLogRetentionJob job = executionLogRetentionJobProvider.getIfAvailable();
        if (!executionLogRetentionEnabled || job == null) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Storage expansion execution log retention is disabled.");
        }
        return job.runNow(OffsetDateTime.now());
    }

    public StorageExpansionRequestResponse create(AuthenticatedUser user, StorageExpansionRequestPayload payload) {
        requireAdmin(user);
        long requestedCapacityBytes = normalizeRequestedCapacity(payload == null ? null : payload.requestedCapacityBytes());
        int serverCount = normalizeServerCount(payload == null ? null : payload.serverCount());
        int volumesPerServer = normalizeVolumesPerServer(payload == null ? null : payload.volumesPerServer());
        String reason = normalizeReason(payload == null ? null : payload.reason());
        long rawCapacityBytes = multiplyExact(requestedCapacityBytes, 2L);
        long volumeSizeBytes = roundUpToGiB(Math.max(
                MIN_VOLUME_SIZE_BYTES,
                ceilDiv(rawCapacityBytes, (long) serverCount * volumesPerServer)
        ));
        long estimatedRawCapacityBytes = multiplyExact(multiplyExact(volumeSizeBytes, serverCount), volumesPerServer);
        long estimatedUsableCapacityBytes = estimatedRawCapacityBytes / 2L;
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionRequestRecord saved = repository.save(new StorageExpansionRequestRecord(
                repository.nextId(),
                requestedCapacityBytes,
                serverCount,
                volumesPerServer,
                volumeSizeBytes,
                estimatedRawCapacityBytes,
                estimatedUsableCapacityBytes,
                "PLANNED",
                reason,
                user.loginId(),
                null,
                null,
                null,
                now,
                now
        ));
        return StorageExpansionRequestResponse.of(saved);
    }

    public StorageExpansionRequestResponse updateStatus(AuthenticatedUser user, long requestId, StorageExpansionStatusRequest request) {
        requireAdmin(user);
        String status = normalizeStatus(request == null ? null : request.status());
        StorageExpansionRequestRecord existing = repository.findById(requestId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Storage expansion request not found."));
        validateTransition(existing.status(), status);
        String appliedEvidence = normalizeAppliedEvidence(request == null ? null : request.appliedEvidence(), status);
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionRequestRecord saved = repository.save(new StorageExpansionRequestRecord(
                existing.id(),
                existing.requestedCapacityBytes(),
                existing.serverCount(),
                existing.volumesPerServer(),
                existing.volumeSizeBytes(),
                existing.estimatedRawCapacityBytes(),
                existing.estimatedUsableCapacityBytes(),
                status,
                existing.reason(),
                existing.createdBy(),
                "APPLIED".equals(status) ? user.loginId() : existing.appliedBy(),
                "APPLIED".equals(status) ? now : existing.appliedAt(),
                "APPLIED".equals(status) ? appliedEvidence : existing.appliedEvidence(),
                existing.createdAt(),
                now
        ));
        return StorageExpansionRequestResponse.of(saved);
    }

    public StorageExpansionManifestResponse manifest(AuthenticatedUser user, long requestId) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = repository.findById(requestId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Storage expansion request not found."));
        String poolName = StorageExpansionRequestResponse.of(request).poolName();
        String volumeSize = formatGi(request.volumeSizeBytes());
        return new StorageExpansionManifestResponse(
                request.id(),
                poolName,
                request.status(),
                true,
                tenantPatchYaml(request, poolName, volumeSize),
                helmValuesPatchYaml(request, poolName, volumeSize)
        );
    }

    public StorageExpansionManifestArtifact manifestArtifact(AuthenticatedUser user, long requestId, String artifact) {
        requireAdmin(user);
        String value = artifact == null ? "" : artifact.trim().toLowerCase(Locale.ROOT);
        if (!Set.of("tenant", "helm", "bundle").contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion manifest artifact is invalid.");
        }
        StorageExpansionManifestResponse manifest = manifest(user, requestId);
        String fileName = switch (value) {
            case "tenant" -> "osmu-storage-expansion-%s-tenant.yaml".formatted(manifest.poolName());
            case "helm" -> "osmu-storage-expansion-%s-helm-values.yaml".formatted(manifest.poolName());
            default -> "osmu-storage-expansion-%s-bundle.yaml".formatted(manifest.poolName());
        };
        String content = switch (value) {
            case "tenant" -> manifest.tenantPatchYaml();
            case "helm" -> manifest.helmValuesPatchYaml();
            default -> manifestBundleYaml(manifest);
        };
        return new StorageExpansionManifestArtifact(manifest.requestId(), value, fileName, content);
    }

    public StorageExpansionExecutionPlanResponse executionPlan(AuthenticatedUser user, long requestId) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = repository.findById(requestId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Storage expansion request not found."));
        if (!"APPROVED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion execution plan requires APPROVED status.");
        }
        StorageExpansionManifestResponse manifest = manifest(user, requestId);
        String bundle = manifestBundleYaml(manifest);
        String bundleSha256 = sha256(bundle);
        String fileName = "osmu-storage-expansion-%s-bundle.yaml".formatted(manifest.poolName());
        return new StorageExpansionExecutionPlanResponse(
                request.id(),
                manifest.poolName(),
                request.status(),
                true,
                true,
                bundleSha256,
                "dry-run bundle %s sha256:%s".formatted(fileName, bundleSha256),
                List.of(
                        "Confirm StorageClass osmu-storage exists and supports requested PV size.",
                        "Confirm namespace osmu and Tenant osmu-minio exist before patch.",
                        "Confirm MinIO Operator Tenant CRD schema matches apiVersion minio.min.io/v2.",
                        "Run kubectl diff or helm diff before live apply.",
                        "Capture GitOps PR, Helm release revision, or kubectl apply log as appliedEvidence."
                ),
                List.of(
                        "kubectl -n osmu diff -f %s".formatted(fileName),
                        "kubectl -n osmu apply --server-side --dry-run=server -f %s".formatted(fileName),
                        "helm diff upgrade osmu-minio ./infra/helm/osmu -f %s".formatted(fileName),
                        "helm upgrade osmu-minio ./infra/helm/osmu -f %s --dry-run".formatted(fileName)
                )
        );
    }

    public StorageExpansionGitOpsPlanResponse gitOpsPlan(AuthenticatedUser user, long requestId) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = repository.findById(requestId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Storage expansion request not found."));
        if (!"APPROVED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion GitOps plan requires APPROVED status.");
        }
        StorageExpansionManifestResponse manifest = manifest(user, requestId);
        String bundleSha256 = sha256(manifestBundleYaml(manifest));
        String basePath = "infra/gitops/storage-expansion/%s".formatted(manifest.poolName());
        String manifestPath = "%s/tenant-patch.yaml".formatted(basePath);
        String valuesPath = "%s/helm-values.yaml".formatted(basePath);
        List<String> reviewChecklist = gitOpsReviewChecklist();
        List<String> changedFiles = gitOpsArtifactFiles(request, manifest, bundleSha256, reviewChecklist).stream()
                .map(GitOpsArtifactFile::path)
                .toList();
        String reviewChecklistMarkdown = String.join("\n", reviewChecklist.stream()
                .map(item -> "- [ ] " + item)
                .toList());
        String changedFilesMarkdown = String.join("\n", changedFiles.stream()
                .map(item -> "- " + item)
                .toList());
        String pullRequestTitle = "[I] Storage expansion %s GitOps draft".formatted(manifest.poolName());
        String pullRequestBody = """
                Storage expansion GitOps draft.

                Request: %d
                Pool: %s
                Status: %s
                Requested capacity: %s
                Estimated raw capacity: %s
                Estimated usable capacity: %s
                Bundle sha256: %s

                Changed files:
                %s

                Review checklist:
                %s

                Dry-run commands:
                - kubectl -n osmu diff -f %s
                - helm upgrade osmu-minio ./infra/helm/osmu -f %s --dry-run
                """.formatted(
                request.id(),
                manifest.poolName(),
                request.status(),
                formatGi(request.requestedCapacityBytes()),
                formatGi(request.estimatedRawCapacityBytes()),
                formatGi(request.estimatedUsableCapacityBytes()),
                bundleSha256,
                changedFilesMarkdown,
                reviewChecklistMarkdown,
                manifestPath,
                valuesPath
        );
        return new StorageExpansionGitOpsPlanResponse(
                request.id(),
                manifest.poolName(),
                request.status(),
                true,
                true,
                "storage-expansion/%s".formatted(manifest.poolName()),
                "[Feat][I] : storage expansion %s GitOps manifest draft".formatted(manifest.poolName()),
                pullRequestTitle,
                pullRequestBody,
                manifestPath,
                valuesPath,
                bundleSha256,
                changedFiles,
                reviewChecklist
        );
    }

    public StorageExpansionGitOpsArtifactBundle gitOpsArtifactBundle(AuthenticatedUser user, long requestId) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = repository.findById(requestId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Storage expansion request not found."));
        if (!"APPROVED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion GitOps artifact bundle requires APPROVED status.");
        }
        StorageExpansionManifestResponse manifest = manifest(user, requestId);
        String bundleSha256 = sha256(manifestBundleYaml(manifest));
        List<String> reviewChecklist = gitOpsReviewChecklist();
        List<GitOpsArtifactFile> files = gitOpsArtifactFiles(request, manifest, bundleSha256, reviewChecklist);
        return new StorageExpansionGitOpsArtifactBundle(
                request.id(),
                manifest.poolName(),
                "osmu-storage-expansion-%s-gitops.zip".formatted(manifest.poolName()),
                zipGitOpsArtifacts(files)
        );
    }

    public StorageExpansionExecutionResponse runGitOpsPrExecution(AuthenticatedUser user, long requestId) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = requireExistingRequest(requestId);
        if (!"APPROVED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion GitOps PR runner requires APPROVED status.");
        }
        StorageExpansionManifestResponse manifest = manifest(user, requestId);
        String bundleSha256 = sha256(manifestBundleYaml(manifest));
        List<String> reviewChecklist = gitOpsReviewChecklist();
        List<GitOpsArtifactFile> artifactFiles = gitOpsArtifactFiles(request, manifest, bundleSha256, reviewChecklist);
        StorageExpansionGitOpsPlanResponse plan = gitOpsPlan(user, requestId);
        List<StorageExpansionGitOpsPrRunner.ArtifactFile> runnerFiles = artifactFiles.stream()
                .map(file -> new StorageExpansionGitOpsPrRunner.ArtifactFile(file.path(), file.content()))
                .toList();
        StorageExpansionGitOpsPrRunner.Result runnerResult = gitOpsPrRunner.run(plan, runnerFiles);
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionExecutionRecord saved = executionRepository.save(new StorageExpansionExecutionRecord(
                executionRepository.nextId(),
                request.id(),
                "GITOPS_PR",
                runnerResult.result(),
                sanitizeCommand(runnerResult.command()),
                sanitizeOutput(runnerResult.output()),
                normalizeOptionalHttpUrl(runnerResult.externalUrl(), "gitOps PR runner externalUrl"),
                bundleSha256,
                runnerResult.exitCode(),
                runnerResult.timedOut(),
                sanitizeNotes(gitOpsPrRunnerNotes(runnerResult)),
                user.loginId(),
                now
        ));
        return StorageExpansionExecutionResponse.of(saved);
    }

    public StorageExpansionExecutionResponse runDryRunExecution(
            AuthenticatedUser user,
            long requestId,
            StorageExpansionDryRunRunPayload payload
    ) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = requireExistingRequest(requestId);
        if (!"APPROVED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion dry-run runner requires APPROVED status.");
        }
        String executionType = normalizeDryRunExecutionType(payload == null ? null : payload.executionType());
        StorageExpansionManifestResponse manifest = manifest(user, requestId);
        String bundle = manifestBundleYaml(manifest);
        String bundleSha256 = sha256(bundle);
        StorageExpansionDryRunRunner.Result runnerResult = dryRunRunner.run(executionType, manifest, bundle);
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionExecutionRecord saved = executionRepository.save(new StorageExpansionExecutionRecord(
                executionRepository.nextId(),
                request.id(),
                executionType,
                runnerResult.result(),
                sanitizeCommand(runnerResult.command()),
                sanitizeOutput(runnerResult.output()),
                null,
                bundleSha256,
                runnerResult.exitCode(),
                runnerResult.timedOut(),
                sanitizeNotes(runnerNotes(runnerResult)),
                user.loginId(),
                now
        ));
        return StorageExpansionExecutionResponse.of(saved);
    }

    public StorageExpansionApplyRunResponse runApplyExecution(
            AuthenticatedUser user,
            long requestId,
            StorageExpansionApplyRunPayload payload
    ) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = requireExistingRequest(requestId);
        if (!"APPROVED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion apply runner requires APPROVED status.");
        }
        String applyType = normalizeApplyRunType(payload == null ? null : payload.applyType());
        StorageExpansionManifestResponse manifest = manifest(user, requestId);
        String bundle = manifestBundleYaml(manifest);
        String bundleSha256 = sha256(bundle);
        StorageExpansionApplyRunner.Result runnerResult = applyRunner.run(applyType, manifest, bundle);
        StorageExpansionPostRunVerification verification = verifyAfterSuccessfulRun("APPLY", request.id(), runnerResult.result());
        String finalResult = finalRunnerResult(runnerResult.result(), verification);
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionExecutionRecord savedExecution = executionRepository.save(new StorageExpansionExecutionRecord(
                executionRepository.nextId(),
                request.id(),
                "APPLY",
                finalResult,
                sanitizeCommand(runnerResult.command()),
                sanitizeOutput(appendPostRunVerification(runnerResult.output(), verification)),
                null,
                bundleSha256,
                runnerResult.exitCode(),
                runnerResult.timedOut(),
                sanitizeNotes(appendPostRunNotes(applyRunnerNotes(applyType, runnerResult), verification)),
                user.loginId(),
                now
        ));
        StorageExpansionRequestResponse requestResponse = "SUCCESS".equals(savedExecution.result())
                ? saveAppliedFromExecution(user, request, savedExecution)
                : StorageExpansionRequestResponse.of(request);
        return new StorageExpansionApplyRunResponse(
                StorageExpansionExecutionResponse.of(savedExecution),
                requestResponse
        );
    }

    public StorageExpansionRollbackRunResponse runRollbackExecution(
            AuthenticatedUser user,
            long requestId,
            StorageExpansionRollbackRunPayload payload
    ) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = requireExistingRequest(requestId);
        if (!"APPLIED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion rollback runner requires APPLIED status.");
        }
        String rollbackType = normalizeRollbackRunType(payload == null ? null : payload.rollbackType());
        Integer helmRevision = normalizeHelmRevision(payload == null ? null : payload.helmRevision());
        String kubectlTarget = normalizeKubectlRollbackTarget(payload == null ? null : payload.kubectlTarget());
        StorageExpansionManifestResponse manifest = manifest(user, requestId);
        String bundleSha256 = sha256(manifestBundleYaml(manifest));
        StorageExpansionRollbackRunner.Result runnerResult = rollbackRunner.run(rollbackType, helmRevision, kubectlTarget);
        StorageExpansionPostRunVerification verification = verifyAfterSuccessfulRun("ROLLBACK", request.id(), runnerResult.result());
        String finalResult = finalRunnerResult(runnerResult.result(), verification);
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionExecutionRecord savedExecution = executionRepository.save(new StorageExpansionExecutionRecord(
                executionRepository.nextId(),
                request.id(),
                "ROLLBACK",
                finalResult,
                sanitizeCommand(runnerResult.command()),
                sanitizeOutput(appendPostRunVerification(runnerResult.output(), verification)),
                null,
                bundleSha256,
                runnerResult.exitCode(),
                runnerResult.timedOut(),
                sanitizeNotes(appendPostRunNotes(rollbackRunnerNotes(rollbackType, helmRevision, kubectlTarget, runnerResult), verification)),
                user.loginId(),
                now
        ));
        return new StorageExpansionRollbackRunResponse(
                StorageExpansionExecutionResponse.of(savedExecution),
                StorageExpansionRequestResponse.of(request)
        );
    }

    public StorageExpansionExecutionResponse recordDryRunExecution(
            AuthenticatedUser user,
            long requestId,
            StorageExpansionDryRunExecutionPayload payload
    ) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = requireExistingRequest(requestId);
        if (!"APPROVED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion dry-run execution requires APPROVED status.");
        }
        StorageExpansionExecutionPlanResponse plan = executionPlan(user, requestId);
        String executionType = normalizeDryRunExecutionType(payload == null ? null : payload.executionType());
        String result = normalizeExecutionResult(payload == null ? null : payload.result());
        String output = normalizeDryRunOutput(payload == null ? null : payload.output(), result);
        String externalUrl = normalizeOptionalHttpUrl(payload == null ? null : payload.externalUrl(), "dry-run externalUrl");
        String notes = normalizeOptionalText(payload == null ? null : payload.notes(), MAX_EXECUTION_NOTES_LENGTH, "dry-run notes");
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionExecutionRecord saved = executionRepository.save(new StorageExpansionExecutionRecord(
                executionRepository.nextId(),
                request.id(),
                executionType,
                result,
                sanitizeCommand(dryRunCommand(plan, executionType)),
                sanitizeOutput(dryRunOutput(plan, output)),
                externalUrl,
                plan.artifactSha256(),
                null,
                false,
                sanitizeNotes(notes),
                user.loginId(),
                now
        ));
        return StorageExpansionExecutionResponse.of(saved);
    }

    public StorageExpansionExecutionResponse recordGitOpsPrExecution(
            AuthenticatedUser user,
            long requestId,
            StorageExpansionGitOpsPrExecutionPayload payload
    ) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = requireExistingRequest(requestId);
        if (!"APPROVED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion GitOps PR execution requires APPROVED status.");
        }
        StorageExpansionGitOpsPlanResponse plan = gitOpsPlan(user, requestId);
        String externalUrl = normalizeRequiredHttpUrl(payload == null ? null : payload.externalUrl(), "gitOps externalUrl");
        String mergeSha = normalizeMergeSha(payload == null ? null : payload.mergeSha());
        String pipelineUrl = normalizeOptionalHttpUrl(payload == null ? null : payload.pipelineUrl(), "gitOps pipelineUrl");
        String operatorNotes = normalizeOptionalText(payload == null ? null : payload.notes(), 512, "gitOps notes");
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionExecutionRecord saved = executionRepository.save(new StorageExpansionExecutionRecord(
                executionRepository.nextId(),
                request.id(),
                "GITOPS_PR",
                "SUCCESS",
                sanitizeCommand(gitOpsPrCommand(plan)),
                sanitizeOutput(gitOpsPrOutput(plan, externalUrl, mergeSha, pipelineUrl)),
                externalUrl,
                plan.artifactSha256(),
                null,
                false,
                sanitizeNotes(gitOpsPrNotes(mergeSha, pipelineUrl, operatorNotes)),
                user.loginId(),
                now
        ));
        return StorageExpansionExecutionResponse.of(saved);
    }

    public ListResponse<StorageExpansionExecutionResponse> listExecutions(
            AuthenticatedUser user,
            long requestId,
            String cursor,
            Integer limit
    ) {
        requireAdmin(user);
        requireExistingRequest(requestId);
        int pageSize = normalizeListLimit(limit);
        List<StorageExpansionExecutionRecord> matchedExecutions = executionRepository.findPageByRequestId(
                requestId,
                parseListCursor(cursor),
                pageSize + 1
        );
        boolean hasNextPage = matchedExecutions.size() > pageSize;
        List<StorageExpansionExecutionRecord> page = hasNextPage
                ? matchedExecutions.subList(0, pageSize)
                : matchedExecutions;
        List<StorageExpansionExecutionResponse> items = page.stream()
                .map(StorageExpansionExecutionResponse::of)
                .toList();
        String nextCursor = hasNextPage ? String.valueOf(page.get(page.size() - 1).id()) : null;
        return ListResponse.of(items, nextCursor);
    }

    public StorageExpansionExecutionResponse createExecution(
            AuthenticatedUser user,
            long requestId,
            StorageExpansionExecutionPayload payload
    ) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = requireExistingRequest(requestId);
        if (!Set.of("APPROVED", "APPLIED").contains(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion execution history requires APPROVED or APPLIED status.");
        }
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionExecutionRecord saved = executionRepository.save(new StorageExpansionExecutionRecord(
                executionRepository.nextId(),
                request.id(),
                normalizeExecutionType(payload == null ? null : payload.executionType()),
                normalizeExecutionResult(payload == null ? null : payload.result()),
                sanitizeCommand(normalizeOptionalText(payload == null ? null : payload.command(), MAX_EXECUTION_COMMAND_LENGTH, "execution command")),
                sanitizeOutput(normalizeOptionalText(payload == null ? null : payload.output(), MAX_EXECUTION_OUTPUT_LENGTH, "execution output")),
                normalizeOptionalText(payload == null ? null : payload.externalUrl(), MAX_EXECUTION_URL_LENGTH, "execution externalUrl"),
                normalizeArtifactSha256(payload == null ? null : payload.artifactSha256()),
                null,
                false,
                sanitizeNotes(normalizeOptionalText(payload == null ? null : payload.notes(), MAX_EXECUTION_NOTES_LENGTH, "execution notes")),
                user.loginId(),
                now
        ));
        return StorageExpansionExecutionResponse.of(saved);
    }

    public StorageExpansionRequestResponse applyFromExecution(AuthenticatedUser user, long requestId, long executionId) {
        requireAdmin(user);
        StorageExpansionRequestRecord request = requireExistingRequest(requestId);
        if (!"APPROVED".equals(request.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion apply from execution requires APPROVED status.");
        }
        StorageExpansionExecutionRecord execution = executionRepository.findById(executionId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Storage expansion execution record not found."));
        if (execution.requestId() != request.id()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion execution record does not belong to this request.");
        }
        if (!"SUCCESS".equals(execution.result())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion apply from execution requires SUCCESS result.");
        }
        if (!Set.of("APPLY", "GITOPS_PR").contains(execution.executionType())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion apply from execution requires APPLY or GITOPS_PR execution type.");
        }
        return saveAppliedFromExecution(user, request, execution);
    }

    private void requireAdmin(AuthenticatedUser user) {
        if (!user.isAdmin()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Storage expansion management requires ADMIN role.");
        }
    }

    private List<String> normalizeListStatuses(String status) {
        String normalized = status == null ? "ALL" : status.trim().toUpperCase(Locale.ROOT);
        if (normalized.isBlank() || "ALL".equals(normalized)) {
            return List.of();
        }
        if ("OPEN".equals(normalized)) {
            return List.of("PLANNED", "APPROVED");
        }
        if (!STATUSES.contains(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion request status filter is invalid.");
        }
        return List.of(normalized);
    }

    private int normalizeListLimit(Integer limit) {
        if (limit == null) {
            return DEFAULT_LIST_LIMIT;
        }
        if (limit < 1 || limit > MAX_LIST_LIMIT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion page limit must be between 1 and 200.");
        }
        return limit;
    }

    private Long parseListCursor(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            long parsed = Long.parseLong(cursor.trim());
            if (parsed < 1) {
                throw new NumberFormatException("cursor must be positive");
            }
            return parsed;
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion page cursor is invalid.");
        }
    }

    private StorageExpansionRequestRecord requireExistingRequest(long requestId) {
        return repository.findById(requestId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Storage expansion request not found."));
    }

    private long normalizeRequestedCapacity(Long requestedCapacityBytes) {
        if (requestedCapacityBytes == null || requestedCapacityBytes <= 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "requestedCapacityBytes must be positive.");
        }
        if (requestedCapacityBytes > MAX_REQUESTED_CAPACITY_BYTES) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "requestedCapacityBytes exceeds the limit.");
        }
        return requestedCapacityBytes;
    }

    private int normalizeServerCount(Integer serverCount) {
        int value = serverCount == null ? DEFAULT_SERVER_COUNT : serverCount;
        if (value < MIN_SERVER_COUNT || value > MAX_SERVER_COUNT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "serverCount must be between 4 and 32.");
        }
        return value;
    }

    private int normalizeVolumesPerServer(Integer volumesPerServer) {
        int value = volumesPerServer == null ? DEFAULT_VOLUMES_PER_SERVER : volumesPerServer;
        if (value < 1 || value > MAX_VOLUMES_PER_SERVER) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "volumesPerServer must be between 1 and 16.");
        }
        return value;
    }

    private String normalizeStatus(String status) {
        String value = status == null ? "" : status.trim().toUpperCase(Locale.ROOT);
        if (!STATUSES.contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion status is invalid.");
        }
        return value;
    }

    private String normalizeExecutionType(String executionType) {
        String value = executionType == null ? "" : executionType.trim().toUpperCase(Locale.ROOT);
        if (!EXECUTION_TYPES.contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion executionType is invalid.");
        }
        return value;
    }

    private String normalizeExecutionResult(String result) {
        String value = result == null ? "" : result.trim().toUpperCase(Locale.ROOT);
        if (!EXECUTION_RESULTS.contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion execution result is invalid.");
        }
        return value;
    }

    private String normalizeDryRunExecutionType(String executionType) {
        String value = normalizeExecutionType(executionType);
        if (!Set.of("HELM_DIFF", "KUBECTL_DIFF").contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion dry-run executionType must be HELM_DIFF or KUBECTL_DIFF.");
        }
        return value;
    }

    private String normalizeApplyRunType(String applyType) {
        String value = applyType == null ? "" : applyType.trim().toUpperCase(Locale.ROOT);
        if (!Set.of("KUBECTL_APPLY", "HELM_UPGRADE").contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion applyType must be KUBECTL_APPLY or HELM_UPGRADE.");
        }
        return value;
    }

    private String normalizeRollbackRunType(String rollbackType) {
        String value = rollbackType == null ? "" : rollbackType.trim().toUpperCase(Locale.ROOT);
        if (!Set.of("KUBECTL_ROLLOUT_UNDO", "HELM_ROLLBACK").contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion rollbackType must be KUBECTL_ROLLOUT_UNDO or HELM_ROLLBACK.");
        }
        return value;
    }

    private Integer normalizeHelmRevision(Integer revision) {
        if (revision == null) {
            return null;
        }
        if (revision < 1 || revision > 999999) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "rollback helmRevision must be between 1 and 999999.");
        }
        return revision;
    }

    private String normalizeKubectlRollbackTarget(String target) {
        String normalized = normalizeOptionalText(target, 128, "rollback kubectlTarget");
        if (normalized == null) {
            return "statefulset/osmu-minio";
        }
        if (!normalized.matches("[A-Za-z0-9._/-]+")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "rollback kubectlTarget contains unsupported characters.");
        }
        return normalized;
    }

    private String sanitizeCommand(String command) {
        return executionLogSanitizer.command(command);
    }

    private String sanitizeOutput(String output) {
        return executionLogSanitizer.output(output);
    }

    private String sanitizeNotes(String notes) {
        return executionLogSanitizer.notes(notes);
    }

    private String normalizeDryRunOutput(String output, String result) {
        String normalized = normalizeOptionalText(output, MAX_EXECUTION_OUTPUT_LENGTH, "dry-run output");
        if (!"SKIPPED".equals(result) && normalized == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "dry-run output is required unless result is SKIPPED.");
        }
        return normalized;
    }

    private String normalizeOptionalText(String value, int maxLength, String fieldName) {
        String normalized = value == null ? "" : value.trim();
        if (normalized.isBlank()) {
            return null;
        }
        if (normalized.length() > maxLength) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "%s must be %d characters or fewer.".formatted(fieldName, maxLength));
        }
        return normalized;
    }

    private String normalizeArtifactSha256(String value) {
        String normalized = normalizeOptionalText(value, 128, "execution artifactSha256");
        if (normalized == null) {
            return null;
        }
        if (!normalized.matches("[0-9a-fA-F]{64}")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "execution artifactSha256 must be a 64-character SHA-256 hex string.");
        }
        return normalized.toLowerCase(Locale.ROOT);
    }

    private String normalizeRequiredHttpUrl(String value, String fieldName) {
        String normalized = normalizeOptionalHttpUrl(value, fieldName);
        if (normalized == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "%s is required.".formatted(fieldName));
        }
        return normalized;
    }

    private String normalizeOptionalHttpUrl(String value, String fieldName) {
        String normalized = normalizeOptionalText(value, MAX_EXECUTION_URL_LENGTH, fieldName);
        if (normalized == null) {
            return null;
        }
        String lower = normalized.toLowerCase(Locale.ROOT);
        if (!lower.startsWith("https://") && !lower.startsWith("http://")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "%s must be an HTTP(S) URL.".formatted(fieldName));
        }
        return normalized;
    }

    private String normalizeMergeSha(String value) {
        String normalized = normalizeOptionalText(value, 64, "gitOps mergeSha");
        if (normalized == null) {
            return null;
        }
        if (!normalized.matches("[0-9a-fA-F]{7,64}")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "gitOps mergeSha must be a 7 to 64 character Git SHA.");
        }
        return normalized.toLowerCase(Locale.ROOT);
    }

    private String gitOpsPrCommand(StorageExpansionGitOpsPlanResponse plan) {
        return "git checkout -b %s && git add %s && git commit -m \"%s\" && gh pr create --title \"%s\""
                .formatted(
                        plan.branchName(),
                        String.join(" ", plan.changedFiles()),
                        plan.commitMessage(),
                        plan.pullRequestTitle()
                );
    }

    private String dryRunCommand(StorageExpansionExecutionPlanResponse plan, String executionType) {
        if ("HELM_DIFF".equals(executionType)) {
            return plan.suggestedCommands().stream()
                    .filter(command -> command.startsWith("helm diff "))
                    .findFirst()
                    .orElse("helm diff upgrade osmu-minio ./infra/helm/osmu -f osmu-storage-expansion-%s-bundle.yaml".formatted(plan.poolName()));
        }
        return plan.suggestedCommands().stream()
                .filter(command -> command.startsWith("kubectl -n osmu diff "))
                .findFirst()
                .orElse("kubectl -n osmu diff -f osmu-storage-expansion-%s-bundle.yaml".formatted(plan.poolName()));
    }

    private String dryRunOutput(StorageExpansionExecutionPlanResponse plan, String operatorOutput) {
        return """
                Storage expansion dry-run evidence.
                Pool: %s
                Artifact sha256: %s
                Reference only: %s

                Output:
                %s
                """.formatted(
                plan.poolName(),
                plan.artifactSha256(),
                plan.referenceOnly(),
                operatorOutput == null ? "SKIPPED" : operatorOutput
        );
    }

    private String runnerNotes(StorageExpansionDryRunRunner.Result result) {
        String exitCode = result.exitCode() == null ? "-" : String.valueOf(result.exitCode());
        return "runner=%s, exitCode=%s, timedOut=%s".formatted(result.result(), exitCode, result.timedOut());
    }

    private String applyRunnerNotes(String applyType, StorageExpansionApplyRunner.Result result) {
        String exitCode = result.exitCode() == null ? "-" : String.valueOf(result.exitCode());
        return "applyType=%s, runner=%s, exitCode=%s, timedOut=%s".formatted(applyType, result.result(), exitCode, result.timedOut());
    }

    private String rollbackRunnerNotes(
            String rollbackType,
            Integer helmRevision,
            String kubectlTarget,
            StorageExpansionRollbackRunner.Result result
    ) {
        String exitCode = result.exitCode() == null ? "-" : String.valueOf(result.exitCode());
        String target = "HELM_ROLLBACK".equals(rollbackType)
                ? "helmRevision=" + (helmRevision == null ? "-" : helmRevision)
                : "kubectlTarget=" + kubectlTarget;
        return "rollbackType=%s, %s, runner=%s, exitCode=%s, timedOut=%s"
                .formatted(rollbackType, target, result.result(), exitCode, result.timedOut());
    }

    private String gitOpsPrRunnerNotes(StorageExpansionGitOpsPrRunner.Result result) {
        String exitCode = result.exitCode() == null ? "-" : String.valueOf(result.exitCode());
        String externalUrl = result.externalUrl() == null ? "-" : result.externalUrl();
        String failureReason = result.failureReason() == null ? "-" : result.failureReason();
        return "gitOpsPrRunner=%s, exitCode=%s, timedOut=%s, externalUrl=%s, failureReason=%s"
                .formatted(result.result(), exitCode, result.timedOut(), externalUrl, failureReason);
    }

    private StorageExpansionPostRunVerification verifyAfterSuccessfulRun(String phase, long requestId, String runnerResult) {
        if (!"SUCCESS".equals(runnerResult)) {
            return null;
        }
        return postRunVerifier.verify(phase, requestId, repository.isHealthy() && executionRepository.isHealthy());
    }

    private String finalRunnerResult(String runnerResult, StorageExpansionPostRunVerification verification) {
        if (verification != null && !verification.success()) {
            return "FAILED";
        }
        return runnerResult;
    }

    private String appendPostRunVerification(String output, StorageExpansionPostRunVerification verification) {
        if (verification == null) {
            return output;
        }
        String base = output == null || output.isBlank() ? "" : output.stripTrailing() + "\n\n";
        return base + verification.summary();
    }

    private String appendPostRunNotes(String notes, StorageExpansionPostRunVerification verification) {
        if (verification == null) {
            return notes;
        }
        String base = notes == null || notes.isBlank() ? "" : notes.stripTrailing() + "\n";
        return limitExecutionNotes(base + verification.notes());
    }

    private String gitOpsPrOutput(
            StorageExpansionGitOpsPlanResponse plan,
            String externalUrl,
            String mergeSha,
            String pipelineUrl
    ) {
        String changedFiles = String.join("\n", plan.changedFiles().stream()
                .map(file -> "- " + file)
                .toList());
        String reviewChecklist = String.join("\n", plan.reviewChecklist().stream()
                .map(item -> "- " + item)
                .toList());
        return """
                GitOps PR evidence recorded.
                PR: %s
                Pipeline: %s
                Merge SHA: %s
                Artifact sha256: %s
                Branch: %s
                Commit: %s

                Changed files:
                %s

                Review checklist:
                %s
                """.formatted(
                externalUrl,
                pipelineUrl == null ? "-" : pipelineUrl,
                mergeSha == null ? "-" : mergeSha,
                plan.artifactSha256(),
                plan.branchName(),
                plan.commitMessage(),
                changedFiles,
                reviewChecklist
        );
    }

    private String gitOpsPrNotes(String mergeSha, String pipelineUrl, String operatorNotes) {
        StringBuilder notes = new StringBuilder();
        if (mergeSha != null) {
            notes.append("mergeSha=").append(mergeSha);
        }
        if (pipelineUrl != null) {
            if (!notes.isEmpty()) {
                notes.append('\n');
            }
            notes.append("pipelineUrl=").append(pipelineUrl);
        }
        if (operatorNotes != null) {
            if (!notes.isEmpty()) {
                notes.append('\n');
            }
            notes.append(operatorNotes);
        }
        return notes.isEmpty() ? null : limitExecutionNotes(notes.toString());
    }

    private String limitExecutionNotes(String value) {
        if (value.length() > MAX_EXECUTION_NOTES_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "gitOps notes must be %d characters or fewer after evidence fields.".formatted(MAX_EXECUTION_NOTES_LENGTH));
        }
        return value;
    }

    private String appliedEvidenceFromExecution(StorageExpansionExecutionRecord execution) {
        String source = firstPresent(execution.externalUrl(), execution.command(), execution.artifactSha256(), execution.notes(), "execution-" + execution.id());
        String evidence = "execution %s #%d: %s".formatted(execution.executionType(), execution.id(), source);
        return evidence.length() <= MAX_APPLIED_EVIDENCE_LENGTH
                ? evidence
                : evidence.substring(0, MAX_APPLIED_EVIDENCE_LENGTH);
    }

    private StorageExpansionRequestResponse saveAppliedFromExecution(
            AuthenticatedUser user,
            StorageExpansionRequestRecord request,
            StorageExpansionExecutionRecord execution
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        StorageExpansionRequestRecord saved = repository.save(new StorageExpansionRequestRecord(
                request.id(),
                request.requestedCapacityBytes(),
                request.serverCount(),
                request.volumesPerServer(),
                request.volumeSizeBytes(),
                request.estimatedRawCapacityBytes(),
                request.estimatedUsableCapacityBytes(),
                "APPLIED",
                request.reason(),
                request.createdBy(),
                user.loginId(),
                now,
                appliedEvidenceFromExecution(execution),
                request.createdAt(),
                now
        ));
        return StorageExpansionRequestResponse.of(saved);
    }

    private String firstPresent(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value.trim();
            }
        }
        return "-";
    }

    private void validateTransition(String currentStatus, String nextStatus) {
        if (currentStatus.equals(nextStatus)) {
            return;
        }
        if ("PLANNED".equals(currentStatus) && ("APPROVED".equals(nextStatus) || "REJECTED".equals(nextStatus))) {
            return;
        }
        if ("APPROVED".equals(currentStatus) && ("APPLIED".equals(nextStatus) || "REJECTED".equals(nextStatus))) {
            return;
        }
        throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion status transition is invalid.");
    }

    private String normalizeReason(String reason) {
        String value = reason == null ? "" : reason.trim();
        if (value.isBlank()) {
            return null;
        }
        if (value.length() > MAX_REASON_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion reason must be 512 characters or fewer.");
        }
        return value;
    }

    private String normalizeAppliedEvidence(String evidence, String status) {
        String value = evidence == null ? "" : evidence.trim();
        if (!"APPLIED".equals(status)) {
            return value.isBlank() ? null : limitAppliedEvidence(value);
        }
        if (value.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "appliedEvidence is required when marking storage expansion APPLIED.");
        }
        return limitAppliedEvidence(value);
    }

    private String limitAppliedEvidence(String value) {
        if (value.length() > MAX_APPLIED_EVIDENCE_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "appliedEvidence must be 512 characters or fewer.");
        }
        return value;
    }

    private long roundUpToGiB(long bytes) {
        return ceilDiv(bytes, GIB) * GIB;
    }

    private int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private String formatGi(long bytes) {
        return (bytes / GIB) + "Gi";
    }

    private String tenantPatchYaml(StorageExpansionRequestRecord request, String poolName, String volumeSize) {
        return """
                # Reference only. Validate MinIO Operator Tenant CRD schema before apply.
                # Generated from OSMU storage expansion request %d.
                # Status: %s
                # Estimated raw capacity: %s
                # Estimated usable capacity: %s
                apiVersion: minio.min.io/v2
                kind: Tenant
                metadata:
                  name: osmu-minio
                  namespace: osmu
                spec:
                  pools:
                    - name: %s
                      servers: %d
                      volumesPerServer: %d
                      volumeClaimTemplate:
                        metadata:
                          name: data
                        spec:
                          accessModes:
                            - ReadWriteOnce
                          resources:
                            requests:
                              storage: %s
                          storageClassName: osmu-storage
                """.formatted(
                request.id(),
                request.status(),
                formatGi(request.estimatedRawCapacityBytes()),
                formatGi(request.estimatedUsableCapacityBytes()),
                poolName,
                request.serverCount(),
                request.volumesPerServer(),
                volumeSize
        );
    }

    private String helmValuesPatchYaml(StorageExpansionRequestRecord request, String poolName, String volumeSize) {
        return """
                # Reference only. Requires MinIO Operator and target Tenant CRD schema validation before apply.
                # OSMU Helm chart renders this topology when minio.tenant.enabled=true.
                minio:
                  tenant:
                    enabled: true
                  pools:
                    - name: %s
                      servers: %d
                      volumesPerServer: %d
                      size: %s
                      storageClassName: osmu-storage
                      estimatedRawCapacity: %s
                      estimatedUsableCapacity: %s
                """.formatted(
                poolName,
                request.serverCount(),
                request.volumesPerServer(),
                volumeSize,
                formatGi(request.estimatedRawCapacityBytes()),
                formatGi(request.estimatedUsableCapacityBytes())
        );
    }

    private String manifestBundleYaml(StorageExpansionManifestResponse manifest) {
        return """
                # OSMU storage expansion manifest bundle.
                # Request: %d
                # Pool: %s
                # Status: %s
                # Reference only. Review before GitOps, Helm, or kubectl apply.
                ---
                %s
                ---
                %s
                """.formatted(
                manifest.requestId(),
                manifest.poolName(),
                manifest.status(),
                manifest.tenantPatchYaml().stripTrailing(),
                manifest.helmValuesPatchYaml().stripTrailing()
        );
    }

    private List<String> gitOpsReviewChecklist() {
        return List.of(
                "Confirm StorageClass osmu-storage and PV quota before merge.",
                "Confirm MinIO Operator Tenant CRD apiVersion minio.min.io/v2 in target cluster.",
                "Run kubectl diff against tenant-patch.yaml.",
                "Run helm diff or helm upgrade --dry-run with helm-values.yaml.",
                "Attach GitOps PR URL, merge SHA, or pipeline log as appliedEvidence before APPLIED."
        );
    }

    private List<GitOpsArtifactFile> gitOpsArtifactFiles(
            StorageExpansionRequestRecord request,
            StorageExpansionManifestResponse manifest,
            String bundleSha256,
            List<String> reviewChecklist
    ) {
        String basePath = "infra/gitops/storage-expansion/%s".formatted(manifest.poolName());
        return List.of(
                new GitOpsArtifactFile("%s/tenant-patch.yaml".formatted(basePath), manifest.tenantPatchYaml()),
                new GitOpsArtifactFile("%s/helm-values.yaml".formatted(basePath), manifest.helmValuesPatchYaml()),
                new GitOpsArtifactFile("%s/README.md".formatted(basePath), gitOpsReadmeMarkdown(request, manifest, bundleSha256, reviewChecklist))
        );
    }

    private String gitOpsReadmeMarkdown(
            StorageExpansionRequestRecord request,
            StorageExpansionManifestResponse manifest,
            String bundleSha256,
            List<String> reviewChecklist
    ) {
        String checklist = String.join("\n", reviewChecklist.stream()
                .map(item -> "- [ ] " + item)
                .toList());
        return """
                # OSMU Storage Expansion %s

                Request ID: %d
                Status: %s
                Requested usable capacity: %s
                Estimated raw capacity: %s
                Estimated usable capacity: %s
                Servers: %d
                Volumes per server: %d
                PV size: %s
                Bundle sha256: %s

                ## Review

                %s

                ## Dry Run

                ```bash
                kubectl -n osmu diff -f tenant-patch.yaml
                helm upgrade osmu-minio ./infra/helm/osmu -f helm-values.yaml --dry-run
                ```

                ## Evidence

                After merge or dry-run approval, attach the GitOps PR URL, merge SHA, pipeline log, or helm/kubectl output as appliedEvidence before marking the request APPLIED.
                """.formatted(
                manifest.poolName(),
                request.id(),
                request.status(),
                formatGi(request.requestedCapacityBytes()),
                formatGi(request.estimatedRawCapacityBytes()),
                formatGi(request.estimatedUsableCapacityBytes()),
                request.serverCount(),
                request.volumesPerServer(),
                formatGi(request.volumeSizeBytes()),
                bundleSha256,
                checklist
        );
    }

    private byte[] zipGitOpsArtifacts(List<GitOpsArtifactFile> files) {
        try (ByteArrayOutputStream output = new ByteArrayOutputStream();
             ZipOutputStream zip = new ZipOutputStream(output, StandardCharsets.UTF_8)) {
            for (GitOpsArtifactFile file : files) {
                ZipEntry entry = new ZipEntry(file.path());
                entry.setTime(0L);
                zip.putNextEntry(entry);
                zip.write(file.content().getBytes(StandardCharsets.UTF_8));
                zip.closeEntry();
            }
            zip.finish();
            return output.toByteArray();
        } catch (IOException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Storage expansion GitOps artifact bundle could not be generated.");
        }
    }

    private record GitOpsArtifactFile(String path, String content) {
    }

    private long ceilDiv(long value, long divisor) {
        return (value + divisor - 1L) / divisor;
    }

    private long multiplyExact(long left, long right) {
        try {
            return Math.multiplyExact(left, right);
        } catch (ArithmeticException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage expansion capacity plan exceeds the limit.");
        }
    }

    private String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "SHA-256 digest is unavailable.");
        }
    }
}
