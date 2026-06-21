package com.example.osmu.admin;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.example.osmu.accesskey.S3AccessPolicyProvisioner;
import com.example.osmu.accesskey.repository.AccessKeyRepository;
import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.audit.repository.AuditLogRepository;
import com.example.osmu.admin.repository.BackupRestoreDrillEvidenceRepository;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.auth.repository.RefreshTokenRepository;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.dashboard.repository.DashboardLayoutRepository;
import com.example.osmu.object.DeletedObjectCandidate;
import com.example.osmu.object.ObjectLifecycleRule;
import com.example.osmu.object.ObjectRetentionPolicy;
import com.example.osmu.object.ObjectRetentionPurgeJob;
import com.example.osmu.object.ObjectShareLink;
import com.example.osmu.object.ObjectShareLinkResponse;
import com.example.osmu.object.ObjectSharePolicyService;
import com.example.osmu.object.ObjectVersionRetentionPurgeJob;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import com.example.osmu.object.repository.ObjectRetentionPolicyRepository;
import com.example.osmu.object.repository.ObjectShareLinkRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.object.repository.ObjectVersionRepository.VersionCandidate;
import com.example.osmu.object.repository.PresignedUploadSessionRepository;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.monitoring.DataFlowDailyRollupResponse;
import com.example.osmu.monitoring.DataFlowDailyRollupMaterializationResponse;
import com.example.osmu.monitoring.DataFlowEventFilter;
import com.example.osmu.monitoring.DataFlowMonitoringResponse;
import com.example.osmu.monitoring.DataFlowMonitoringService;
import com.example.osmu.monitoring.DataFlowMonthlyRollupMaterializationResponse;
import com.example.osmu.monitoring.DataFlowMonthlyRollupResponse;
import com.example.osmu.monitoring.DataFlowStorageStatusResponse;
import com.example.osmu.quota.QuotaPolicyResponse;
import com.example.osmu.quota.QuotaPolicyService;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.user.repository.UserRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.Comparator;
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
    private static final ObjectMapper JSON_MAPPER = new ObjectMapper();

    private final BucketService bucketService;
    private final BucketRepository bucketRepository;
    private final UserRepository userRepository;
    private final DashboardLayoutRepository dashboardLayoutRepository;
    private final OrganizationRepository organizationRepository;
    private final AuditLogRepository auditLogRepository;
    private final BackupRestoreDrillEvidenceRepository restoreDrillEvidenceRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AccessKeyRepository accessKeyRepository;
    private final ObjectMetadataRepository objectMetadataRepository;
    private final ObjectLifecycleRuleRepository lifecycleRuleRepository;
    private final ObjectRetentionPolicyRepository retentionPolicyRepository;
    private final ObjectVersionRepository objectVersionRepository;
    private final PresignedUploadSessionRepository uploadSessionRepository;
    private final ObjectShareLinkRepository shareLinkRepository;
    private final ObjectSharePolicyService sharePolicyService;
    private final QuotaPolicyService quotaPolicyService;
    private final S3AccessPolicyProvisioner policyProvisioner;
    private final AuditLogService auditLogService;
    private final ObjectLifecycleS3XmlService lifecycleS3XmlService;
    private final AuthContext authContext;
    private final ObjectStorageAdapter storageAdapter;
    private final ObjectProvider<ObjectRetentionPurgeJob> retentionPurgeJobProvider;
    private final ObjectProvider<ObjectVersionRetentionPurgeJob> versionRetentionPurgeJobProvider;
    private final DataFlowMonitoringService dataFlowMonitoringService;
    private final StorageBackendMetricsProvider storageBackendMetricsProvider;
    private final MeterRegistry meterRegistry;
    private final boolean objectRetentionEnabled;
    private final String storageMode;
    private final String metadataMode;
    private final boolean restoreDrillExecuted;
    private final String lastBackupAt;
    private final String lastRestoreDrillAt;
    private final String operationsReadinessReportPath;
    private final String operationsReadinessFinalizeReportPath;
    private final String operationsReadinessArtifactImportReportPath;
    private final String operationsEvidencePlanReportPath;
    private final String operationsEvidencePlanInvocationReportPath;
    private final String operationsInvocationUnblockPlanReportPath;
    private final String operationsDispatchPreflightReportPath;
    private final String operationsWorkflowRunIdPlanReportPath;
    private final String operationsArtifactCollectionPlanReportPath;
    private final String operationsEvidenceHandoffReportPath;
    private final String operationsHandoffPackageReportPath;
    private final String dataFlowStoragePlanReportPath;
    private final String storageBackendTelemetryReportPath;
    private final String operationsReadinessConvergenceReportPath;
    private final String kubernetesOperationsReportSyncReportPath;

    public AdminController(
            BucketService bucketService,
            BucketRepository bucketRepository,
            UserRepository userRepository,
            DashboardLayoutRepository dashboardLayoutRepository,
            OrganizationRepository organizationRepository,
            AuditLogRepository auditLogRepository,
            BackupRestoreDrillEvidenceRepository restoreDrillEvidenceRepository,
            RefreshTokenRepository refreshTokenRepository,
            AccessKeyRepository accessKeyRepository,
            ObjectMetadataRepository objectMetadataRepository,
            ObjectLifecycleRuleRepository lifecycleRuleRepository,
            ObjectRetentionPolicyRepository retentionPolicyRepository,
            ObjectVersionRepository objectVersionRepository,
            PresignedUploadSessionRepository uploadSessionRepository,
            ObjectShareLinkRepository shareLinkRepository,
            ObjectSharePolicyService sharePolicyService,
            QuotaPolicyService quotaPolicyService,
            S3AccessPolicyProvisioner policyProvisioner,
            AuditLogService auditLogService,
            ObjectLifecycleS3XmlService lifecycleS3XmlService,
            AuthContext authContext,
            ObjectStorageAdapter storageAdapter,
            ObjectProvider<ObjectRetentionPurgeJob> retentionPurgeJobProvider,
            ObjectProvider<ObjectVersionRetentionPurgeJob> versionRetentionPurgeJobProvider,
            DataFlowMonitoringService dataFlowMonitoringService,
            StorageBackendMetricsProvider storageBackendMetricsProvider,
            MeterRegistry meterRegistry,
            @Value("${osmu.object.retention.enabled:true}") boolean objectRetentionEnabled,
            @Value("${osmu.storage.mode:in-memory}") String storageMode,
            @Value("${osmu.metadata.mode:in-memory}") String metadataMode,
            @Value("${osmu.backup.restore-drill-executed:false}") boolean restoreDrillExecuted,
            @Value("${osmu.backup.last-backup-at:}") String lastBackupAt,
            @Value("${osmu.backup.last-restore-drill-at:}") String lastRestoreDrillAt,
            @Value("${osmu.operations.readiness.report-path:.osmu-run/latest-operations-readiness.json}") String operationsReadinessReportPath,
            @Value("${osmu.operations.readiness.finalize-report-path:.osmu-run/latest-operations-readiness-finalize.json}") String operationsReadinessFinalizeReportPath,
            @Value("${osmu.operations.readiness.artifact-import-report-path:.osmu-run/latest-operations-readiness-artifact-import.json}") String operationsReadinessArtifactImportReportPath,
            @Value("${osmu.operations.readiness.evidence-plan-report-path:.osmu-run/latest-operations-evidence-plan.json}") String operationsEvidencePlanReportPath,
            @Value("${osmu.operations.readiness.evidence-plan-invocation-report-path:.osmu-run/latest-operations-evidence-plan-invocation.json}") String operationsEvidencePlanInvocationReportPath,
            @Value("${osmu.operations.readiness.invocation-unblock-plan-report-path:.osmu-run/latest-operations-invocation-unblock-plan.json}") String operationsInvocationUnblockPlanReportPath,
            @Value("${osmu.operations.readiness.dispatch-preflight-report-path:.osmu-run/latest-operations-dispatch-preflight.json}") String operationsDispatchPreflightReportPath,
            @Value("${osmu.operations.readiness.workflow-run-id-plan-report-path:.osmu-run/latest-operations-workflow-run-ids.json}") String operationsWorkflowRunIdPlanReportPath,
            @Value("${osmu.operations.readiness.artifact-collection-plan-report-path:.osmu-run/latest-operations-artifact-collection-plan.json}") String operationsArtifactCollectionPlanReportPath,
            @Value("${osmu.operations.readiness.evidence-handoff-report-path:.osmu-run/latest-operations-evidence-handoff.json}") String operationsEvidenceHandoffReportPath,
            @Value("${osmu.operations.readiness.handoff-package-report-path:.osmu-run/latest-operations-handoff-package.json}") String operationsHandoffPackageReportPath,
            @Value("${osmu.operations.readiness.data-flow-storage-plan-report-path:.osmu-run/latest-data-flow-storage-plan.json}") String dataFlowStoragePlanReportPath,
            @Value("${osmu.operations.readiness.storage-backend-telemetry-report-path:.osmu-run/latest-storage-backend-telemetry.json}") String storageBackendTelemetryReportPath,
            @Value("${osmu.operations.readiness.convergence-report-path:.osmu-run/latest-operations-readiness-convergence.json}") String operationsReadinessConvergenceReportPath,
            @Value("${osmu.operations.readiness.kubernetes-report-sync-report-path:.osmu-run/latest-kubernetes-operations-report-sync.json}") String kubernetesOperationsReportSyncReportPath
    ) {
        this.bucketService = bucketService;
        this.bucketRepository = bucketRepository;
        this.userRepository = userRepository;
        this.dashboardLayoutRepository = dashboardLayoutRepository;
        this.organizationRepository = organizationRepository;
        this.auditLogRepository = auditLogRepository;
        this.restoreDrillEvidenceRepository = restoreDrillEvidenceRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.accessKeyRepository = accessKeyRepository;
        this.objectMetadataRepository = objectMetadataRepository;
        this.lifecycleRuleRepository = lifecycleRuleRepository;
        this.retentionPolicyRepository = retentionPolicyRepository;
        this.objectVersionRepository = objectVersionRepository;
        this.uploadSessionRepository = uploadSessionRepository;
        this.shareLinkRepository = shareLinkRepository;
        this.sharePolicyService = sharePolicyService;
        this.quotaPolicyService = quotaPolicyService;
        this.policyProvisioner = policyProvisioner;
        this.auditLogService = auditLogService;
        this.lifecycleS3XmlService = lifecycleS3XmlService;
        this.authContext = authContext;
        this.storageAdapter = storageAdapter;
        this.retentionPurgeJobProvider = retentionPurgeJobProvider;
        this.versionRetentionPurgeJobProvider = versionRetentionPurgeJobProvider;
        this.dataFlowMonitoringService = dataFlowMonitoringService;
        this.storageBackendMetricsProvider = storageBackendMetricsProvider;
        this.meterRegistry = meterRegistry;
        this.objectRetentionEnabled = objectRetentionEnabled;
        this.storageMode = storageMode;
        this.metadataMode = metadataMode;
        this.restoreDrillExecuted = restoreDrillExecuted;
        this.lastBackupAt = blankToNull(lastBackupAt);
        this.lastRestoreDrillAt = blankToNull(lastRestoreDrillAt);
        this.operationsReadinessReportPath = blankToNull(operationsReadinessReportPath);
        this.operationsReadinessFinalizeReportPath = blankToNull(operationsReadinessFinalizeReportPath);
        this.operationsReadinessArtifactImportReportPath = blankToNull(operationsReadinessArtifactImportReportPath);
        this.operationsEvidencePlanReportPath = blankToNull(operationsEvidencePlanReportPath);
        this.operationsEvidencePlanInvocationReportPath = blankToNull(operationsEvidencePlanInvocationReportPath);
        this.operationsInvocationUnblockPlanReportPath = blankToNull(operationsInvocationUnblockPlanReportPath);
        this.operationsDispatchPreflightReportPath = blankToNull(operationsDispatchPreflightReportPath);
        this.operationsWorkflowRunIdPlanReportPath = blankToNull(operationsWorkflowRunIdPlanReportPath);
        this.operationsArtifactCollectionPlanReportPath = blankToNull(operationsArtifactCollectionPlanReportPath);
        this.operationsEvidenceHandoffReportPath = blankToNull(operationsEvidenceHandoffReportPath);
        this.operationsHandoffPackageReportPath = blankToNull(operationsHandoffPackageReportPath);
        this.dataFlowStoragePlanReportPath = blankToNull(dataFlowStoragePlanReportPath);
        this.storageBackendTelemetryReportPath = blankToNull(storageBackendTelemetryReportPath);
        this.operationsReadinessConvergenceReportPath = blankToNull(operationsReadinessConvergenceReportPath);
        this.kubernetesOperationsReportSyncReportPath = blankToNull(kubernetesOperationsReportSyncReportPath);
    }

    @GetMapping("/dashboard/summary")
    public ApiResponse<DashboardSummaryResponse> dashboardSummary() {
        UsageResponse usage = usageSnapshot();
        DashboardSystemStatusResponse system = systemStatusSnapshot();
        BackupStatusResponse backup = backupStatusSnapshot();
        ObjectRetentionStatusResponse retention = retentionStatus();
        ObjectShareAnalyticsResponse shareAnalytics = shareAnalyticsSnapshot(10);
        DashboardQuotaSummaryResponse quota = quotaSummarySnapshot();
        DashboardReadinessResponse readiness = readinessSnapshot(usage, system, backup, shareAnalytics, quota);
        DataFlowMonitoringResponse dataFlow = dataFlowMonitoringService.snapshot();
        ListResponse<AuditLogEntry> recentAuditLogs = auditLogService.list(
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                10
        );
        return ApiResponse.of(new DashboardSummaryResponse(
                usage,
                system,
                backup,
                retention,
                shareAnalytics,
                quota,
                readiness,
                dataFlow,
                recentAuditLogs,
                OffsetDateTime.now()
        ));
    }

    @GetMapping("/monitoring/data-flow")
    public ApiResponse<DataFlowMonitoringResponse> dataFlowMonitoring(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        return ApiResponse.of(dataFlowMonitoringService.snapshot(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                normalizeDataFlowLimit(limit)
        ));
    }

    @GetMapping("/monitoring/data-flow/storage-status")
    public ApiResponse<DataFlowStorageStatusResponse> dataFlowStorageStatus() {
        return ApiResponse.of(dataFlowMonitoringService.storageStatus());
    }

    @GetMapping(value = "/monitoring/data-flow/export.csv", produces = "text/csv")
    public ResponseEntity<String> exportDataFlowMonitoringCsv(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        String csv = dataFlowMonitoringService.exportCsv(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                normalizeDataFlowLimit(limit)
        );
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow.csv\"")
                .body(csv);
    }

    @GetMapping("/monitoring/data-flow/daily-rollup")
    public ApiResponse<DataFlowDailyRollupResponse> dataFlowDailyRollup(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "days", required = false) Integer days,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        return ApiResponse.of(dataFlowMonitoringService.dailyRollup(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                days,
                limit
        ));
    }

    @PostMapping("/monitoring/data-flow/daily-rollup/materialize")
    public ApiResponse<DataFlowDailyRollupMaterializationResponse> materializeDataFlowDailyRollup(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "days", required = false) Integer days,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        return ApiResponse.of(dataFlowMonitoringService.materializeDailyRollup(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                days,
                limit
        ));
    }

    @GetMapping("/monitoring/data-flow/daily-rollup/materialized")
    public ApiResponse<DataFlowDailyRollupResponse> materializedDataFlowDailyRollup(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "days", required = false) Integer days,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        return ApiResponse.of(dataFlowMonitoringService.materializedDailyRollup(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                days,
                limit
        ));
    }

    @GetMapping(value = "/monitoring/data-flow/daily-rollup/export.csv", produces = "text/csv")
    public ResponseEntity<String> exportDataFlowDailyRollupCsv(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "days", required = false) Integer days,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        String csv = dataFlowMonitoringService.exportDailyRollupCsv(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                days,
                limit
        );
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow-daily-rollup.csv\"")
                .body(csv);
    }

    @GetMapping(value = "/monitoring/data-flow/daily-rollup/materialized/export.csv", produces = "text/csv")
    public ResponseEntity<String> exportMaterializedDataFlowDailyRollupCsv(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "days", required = false) Integer days,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        String csv = dataFlowMonitoringService.exportMaterializedDailyRollupCsv(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                days,
                limit
        );
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow-daily-rollup-materialized.csv\"")
                .body(csv);
    }

    @GetMapping("/monitoring/data-flow/monthly-rollup")
    public ApiResponse<DataFlowMonthlyRollupResponse> dataFlowMonthlyRollup(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "months", required = false) Integer months,
            @RequestParam(name = "limit", required = false) Integer limit,
            @RequestParam(name = "materialized", required = false) Boolean materialized
    ) {
        return ApiResponse.of(dataFlowMonitoringService.monthlyRollup(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                months,
                limit,
                Boolean.TRUE.equals(materialized)
        ));
    }

    @PostMapping("/monitoring/data-flow/monthly-rollup/materialize")
    public ApiResponse<DataFlowMonthlyRollupMaterializationResponse> materializeDataFlowMonthlyRollup(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "months", required = false) Integer months,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        return ApiResponse.of(dataFlowMonitoringService.materializeMonthlyRollup(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                months,
                limit
        ));
    }

    @GetMapping("/monitoring/data-flow/monthly-rollup/materialized")
    public ApiResponse<DataFlowMonthlyRollupResponse> materializedDataFlowMonthlyRollup(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "months", required = false) Integer months,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        return ApiResponse.of(dataFlowMonitoringService.storedMonthlyRollup(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                months,
                limit
        ));
    }

    @GetMapping(value = "/monitoring/data-flow/monthly-rollup/export.csv", produces = "text/csv")
    public ResponseEntity<String> exportDataFlowMonthlyRollupCsv(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "months", required = false) Integer months,
            @RequestParam(name = "limit", required = false) Integer limit,
            @RequestParam(name = "materialized", required = false) Boolean materialized
    ) {
        String csv = dataFlowMonitoringService.exportMonthlyRollupCsv(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                months,
                limit,
                Boolean.TRUE.equals(materialized)
        );
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow-monthly-rollup.csv\"")
                .body(csv);
    }

    @GetMapping(value = "/monitoring/data-flow/monthly-rollup/materialized/export.csv", produces = "text/csv")
    public ResponseEntity<String> exportMaterializedDataFlowMonthlyRollupCsv(
            @RequestParam(name = "bucketName", required = false) String bucketName,
            @RequestParam(name = "actorId", required = false) String actorId,
            @RequestParam(name = "source", required = false) String source,
            @RequestParam(name = "operation", required = false) String operation,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "months", required = false) Integer months,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        String csv = dataFlowMonitoringService.exportStoredMonthlyRollupCsv(
                dataFlowFilter(bucketName, actorId, source, operation, status, from, to),
                months,
                limit
        );
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow-monthly-rollup-materialized.csv\"")
                .body(csv);
    }

    private DataFlowEventFilter dataFlowFilter(
            String bucketName,
            String actorId,
            String source,
            String operation,
            String status,
            String from,
            String to
    ) {
        return new DataFlowEventFilter(
                bucketName,
                actorId,
                source,
                operation,
                status,
                parseOptionalOffsetDateTime(from, "from"),
                parseOptionalOffsetDateTime(to, "to")
        );
    }

    @GetMapping("/usage")
    public ApiResponse<UsageResponse> usage() {
        return ApiResponse.of(usageSnapshot());
    }

    @GetMapping("/dashboard/readiness")
    public ApiResponse<DashboardReadinessResponse> dashboardReadiness() {
        UsageResponse usage = usageSnapshot();
        DashboardSystemStatusResponse system = systemStatusSnapshot();
        BackupStatusResponse backup = backupStatusSnapshot();
        ObjectShareAnalyticsResponse shareAnalytics = shareAnalyticsSnapshot(10);
        DashboardQuotaSummaryResponse quota = quotaSummarySnapshot();
        return ApiResponse.of(readinessSnapshot(usage, system, backup, shareAnalytics, quota));
    }

    private UsageResponse usageSnapshot() {
        long quotaBytes = bucketService.totalQuotaBytes();
        long usedBytes = bucketService.totalUsedBytes();
        return new UsageResponse(
                quotaBytes,
                usedBytes,
                Math.max(0L, quotaBytes - usedBytes),
                bucketService.list().size(),
                bucketService.totalObjectCount()
        );
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
        DashboardSystemStatusResponse status = systemStatusSnapshot();
        return ApiResponse.of(Map.of(
                "backend", status.backend(),
                "database", status.database(),
                "storage", status.storage(),
                "accessKeyProvisioner", status.accessKeyProvisioner(),
                "metadataEngine", status.metadataEngine(),
                "storageEngine", status.storageEngine()
        ));
    }

    @GetMapping("/storage/backend-status")
    public ApiResponse<StorageBackendStatusResponse> storageBackendStatus() {
        return ApiResponse.of(storageBackendStatusSnapshot());
    }

    private StorageBackendStatusResponse storageBackendStatusSnapshot() {
        String normalizedStorageMode = mode(storageMode);
        String normalizedMetadataMode = mode(metadataMode);
        boolean storageHealthy = storageAdapter.isHealthy();
        boolean accessKeyProvisionerHealthy = policyProvisioner.isHealthy();
        long quotaBytes = bucketService.totalQuotaBytes();
        long usedBytes = bucketService.totalUsedBytes();
        long bucketCount = bucketRepository.findAll().size();
        long objectCount = bucketService.totalObjectCount();
        StorageBackendMetricsSnapshot directMetrics = storageBackendMetricsProvider.snapshot();
        boolean directMetricsReady = directMetrics.ready();
        boolean minioMode = "minio".equals(normalizedStorageMode);
        DashboardStorageBackendTelemetryEvidenceResponse telemetry = storageBackendTelemetryEvidenceSnapshot();
        boolean telemetryCapacityReady = minioMode
                && "passed".equalsIgnoreCase(telemetry.result())
                && telemetry.capacityKnown()
                && telemetry.totalBytes() > 0L;
        long effectiveQuotaBytes = directMetricsReady
                ? directMetrics.totalBytes()
                : telemetryCapacityReady ? telemetry.totalBytes() : quotaBytes;
        long effectiveRemainingBytes = directMetricsReady
                ? directMetrics.freeBytes()
                : telemetryCapacityReady ? telemetry.freeBytes() : Math.max(0L, quotaBytes - usedBytes);
        long effectiveUsedBytes = directMetricsReady
                ? Math.max(0L, directMetrics.totalBytes() - directMetrics.freeBytes())
                : telemetryCapacityReady ? telemetry.usedBytes() : usedBytes;
        String capacitySource = directMetricsReady
                ? directMetrics.source()
                : telemetryCapacityReady ? "storage_backend_telemetry_evidence" : "bucket_metadata_usage";
        List<String> pendingGates = new java.util.ArrayList<>();
        if (!storageHealthy) {
            pendingGates.add("Object storage health check is DOWN.");
        }
        if (!accessKeyProvisionerHealthy) {
            pendingGates.add("Access key policy provisioner health check is DOWN.");
        }
        if (!minioMode) {
            pendingGates.add("MinIO object storage mode is not enabled.");
        } else if (!directMetrics.ready() && !telemetryCapacityReady) {
            pendingGates.add("Direct MinIO capacity metrics are not ready: " + directMetrics.detail());
        }
        String readiness;
        if (!storageHealthy) {
            readiness = "UNHEALTHY";
        } else if (!minioMode) {
            readiness = "DEMO_ONLY";
        } else if (!accessKeyProvisionerHealthy) {
            readiness = "PROVISIONER_ATTENTION";
        } else if (directMetricsReady) {
            readiness = "DIRECT_METRICS_READY";
        } else if (telemetryCapacityReady) {
            readiness = "TELEMETRY_EVIDENCE_READY";
        } else {
            readiness = "METADATA_USAGE_READY";
        }
        return new StorageBackendStatusResponse(
                normalizedStorageMode,
                normalizedMetadataMode,
                storageHealthy,
                accessKeyProvisionerHealthy,
                bucketCount,
                objectCount,
                effectiveUsedBytes,
                effectiveQuotaBytes,
                effectiveRemainingBytes,
                directMetrics.totalBytes(),
                directMetrics.freeBytes(),
                capacitySource,
                directMetricsReady,
                directMetricsReady && "minio_prometheus_metrics".equals(directMetrics.source()),
                directMetrics.status(),
                directMetrics.source(),
                directMetrics.detail(),
                directMetrics.metricNames(),
                readiness,
                List.copyOf(pendingGates),
                OffsetDateTime.now(),
                directMetricsReady
                        ? "OSMU storage backend status uses direct MinIO capacity metrics with metadata counts for buckets and objects."
                        : telemetryCapacityReady
                        ? "OSMU storage backend status uses the latest passed MinIO admin info telemetry evidence for capacity with metadata counts for buckets and objects."
                        : "OSMU storage backend status uses bucket metadata usage and health probes until direct MinIO capacity metrics or storage backend telemetry evidence are ready."
        );
    }

    private DashboardSystemStatusResponse systemStatusSnapshot() {
        boolean databaseHealthy = bucketRepository.isHealthy()
                && userRepository.isHealthy()
                && dashboardLayoutRepository.isHealthy()
                && organizationRepository.isHealthy()
                && auditLogRepository.isHealthy()
                && restoreDrillEvidenceRepository.isHealthy()
                && refreshTokenRepository.isHealthy()
                && accessKeyRepository.isHealthy()
                && objectMetadataRepository.isHealthy()
                && lifecycleRuleRepository.isHealthy()
                && retentionPolicyRepository.isHealthy()
                && objectVersionRepository.isHealthy()
                && uploadSessionRepository.isHealthy()
                && shareLinkRepository.isHealthy()
                && sharePolicyService.isHealthy();
        return new DashboardSystemStatusResponse(
                "UP",
                databaseHealthy ? "UP" : "DOWN",
                storageAdapter.isHealthy() ? "UP" : "DOWN",
                policyProvisioner.isHealthy() ? "UP" : "DOWN",
                mode(metadataMode),
                mode(storageMode)
        );
    }

    private BackupStatusResponse backupStatusSnapshot() {
        boolean databaseHealthy = bucketRepository.isHealthy()
                && userRepository.isHealthy()
                && dashboardLayoutRepository.isHealthy()
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
        List<String> pendingGates = new java.util.ArrayList<>();
        if (!"mariadb".equals(normalizedMetadataMode)) {
            pendingGates.add("MariaDB metadata mode is not enabled.");
        }
        if (!"minio".equals(normalizedStorageMode)) {
            pendingGates.add("MinIO object storage mode is not enabled.");
        }
        BackupRestoreDrillEvidenceResponse latestSuccessfulDrill = latestRestoreDrillEvidence("SUCCESS");
        BackupRestoreDrillEvidenceResponse latestAnyDrill = latestRestoreDrillEvidence(null);
        boolean successfulRestoreDrillExecuted = restoreDrillExecuted || latestSuccessfulDrill != null;
        String effectiveLastRestoreDrillAt = lastRestoreDrillAt;
        if (effectiveLastRestoreDrillAt == null && latestSuccessfulDrill != null) {
            effectiveLastRestoreDrillAt = latestSuccessfulDrill.recordedAt();
        }
        if (effectiveLastRestoreDrillAt == null && latestAnyDrill != null) {
            effectiveLastRestoreDrillAt = latestAnyDrill.recordedAt();
        }
        if (!successfulRestoreDrillExecuted) {
            pendingGates.add("Successful restore drill evidence has not been recorded.");
        }
        return new BackupStatusResponse(
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
        );
    }

    private BackupRestoreDrillEvidenceResponse latestRestoreDrillEvidence(String result) {
        return restoreDrillEvidenceRepository.findLatestByResult(result).orElse(null);
    }

    private ObjectShareAnalyticsResponse shareAnalyticsSnapshot(int limit) {
        List<ObjectShareLink> links = shareLinkRepository.findAll();
        List<ObjectShareLinkResponse> recentLinks = links.stream()
                .sorted(Comparator.comparing(ObjectShareLink::id).reversed())
                .limit(limit)
                .map(link -> ObjectShareLinkResponse.of(link, null, null))
                .toList();
        return new ObjectShareAnalyticsResponse(
                links.size(),
                countStatus(links, "ACTIVE"),
                countStatus(links, "EXPIRED"),
                countStatus(links, "REVOKED"),
                countStatus(links, "LIMIT_REACHED"),
                links.stream().filter(ObjectShareLink::passwordProtected).count(),
                links.stream().filter(ObjectShareLink::ipRestricted).count(),
                links.stream().mapToLong(ObjectShareLink::downloadCount).sum(),
                links.stream()
                        .map(ObjectShareLink::lastAccessedAt)
                        .filter(value -> value != null)
                        .max(OffsetDateTime::compareTo)
                        .orElse(null),
                recentLinks
        );
    }

    private DashboardQuotaSummaryResponse quotaSummarySnapshot() {
        List<QuotaPolicyResponse> policies = quotaPolicyService.list();
        List<QuotaPolicyResponse> topPolicies = policies.stream()
                .sorted(Comparator.comparingDouble(this::quotaUsageRatio).reversed()
                        .thenComparingLong(QuotaPolicyResponse::remainingBytes))
                .limit(5)
                .toList();
        return new DashboardQuotaSummaryResponse(
                policies.size(),
                policies.stream().filter(this::isQuotaWarning).count(),
                policies.stream().filter(this::isQuotaExhausted).count(),
                policies.stream().mapToLong(QuotaPolicyResponse::quotaBytes).sum(),
                policies.stream().mapToLong(QuotaPolicyResponse::usedBytes).sum(),
                policies.stream().mapToLong(QuotaPolicyResponse::remainingBytes).sum(),
                topPolicies
        );
    }

    private DashboardReadinessResponse readinessSnapshot(
            UsageResponse usage,
            DashboardSystemStatusResponse system,
            BackupStatusResponse backup,
            ObjectShareAnalyticsResponse shareAnalytics,
            DashboardQuotaSummaryResponse quota
    ) {
        java.util.ArrayList<DashboardReadinessItemResponse> items = new java.util.ArrayList<>();
        addBlockerIfNotUp(items, "SYSTEM", "BACKEND_DOWN", "Backend API", system.backend(), "dashboard", "status-list", "상태 확인");
        addBlockerIfNotUp(items, "SYSTEM", "DATABASE_DOWN", "Metadata database", system.database(), "dashboard", "status-list", "DB 확인");
        addBlockerIfNotUp(items, "SYSTEM", "STORAGE_DOWN", "Object storage", system.storage(), "dashboard", "status-list", "스토리지 확인");
        addBlockerIfNotUp(items, "SECURITY", "ACCESS_KEY_PROVISIONER_DOWN", "Access key provisioner", system.accessKeyProvisioner(), "admin", "admin-access-keys", "Access key 확인");

        String metadataEngine = mode(system.metadataEngine());
        String storageEngine = mode(system.storageEngine());
        if (!"mariadb".equals(metadataEngine)) {
            addReadinessItem(items, "WARNING", "RUNTIME", "METADATA_ENGINE", "MariaDB metadata mode is not enabled.", "dashboard", "dashboard-widget-runtime", "런타임 확인");
        }
        if (!"minio".equals(storageEngine)) {
            addReadinessItem(items, "WARNING", "RUNTIME", "STORAGE_ENGINE", "MinIO object storage mode is not enabled.", "dashboard", "dashboard-widget-runtime", "런타임 확인");
        }
        backup.pendingGates().stream()
                .forEach(gate -> addUniqueReadinessItem(items, "WARNING", "BACKUP", "BACKUP_GATE", gate, "dashboard", "backup-status-panel", "백업 확인"));
        addOperationsReadinessItems(items);
        if (usage.bucketCount() == 0) {
            addReadinessItem(items, "WARNING", "STORAGE", "NO_BUCKET", "No bucket exists for a demo workflow.", "storage", "storage-buckets", "버킷 생성");
        }
        if (quota.exhaustedPolicyCount() > 0) {
            addReadinessItem(items, "WARNING", "QUOTA", "QUOTA_EXHAUSTED", "%d quota policies are exhausted.".formatted(quota.exhaustedPolicyCount()), "admin", "admin-quota-policies", "쿼터 확인");
        } else if (quota.warningPolicyCount() > 0) {
            addReadinessItem(items, "WARNING", "QUOTA", "QUOTA_WARNING", "%d quota policies are near limit.".formatted(quota.warningPolicyCount()), "admin", "admin-quota-policies", "쿼터 확인");
        }
        if (shareAnalytics.expiredLinks() > 0) {
            addReadinessItem(items, "WARNING", "SHARING", "EXPIRED_SHARE_LINKS", "%d expired share links need cleanup.".formatted(shareAnalytics.expiredLinks()), "admin", "admin-object-share", "공유 정리");
        }

        List<String> blockers = items.stream()
                .filter(item -> "BLOCKER".equals(item.severity()))
                .map(DashboardReadinessItemResponse::message)
                .toList();
        List<String> warnings = items.stream()
                .filter(item -> "WARNING".equals(item.severity()))
                .map(DashboardReadinessItemResponse::message)
                .toList();
        DashboardOperationsEvidencePlanResponse operationsEvidencePlan = operationsEvidencePlanSnapshot();
        DashboardOperationsEvidenceInvocationResponse operationsEvidenceInvocation = operationsEvidenceInvocationSnapshot();
        DashboardOperationsInvocationUnblockPlanResponse operationsInvocationUnblockPlan = operationsInvocationUnblockPlanSnapshot();
        DashboardOperationsDispatchPreflightResponse operationsDispatchPreflight = operationsDispatchPreflightSnapshot();
        DashboardOperationsWorkflowRunIdPlanResponse operationsWorkflowRunIdPlan = operationsWorkflowRunIdPlanSnapshot();
        DashboardOperationsArtifactCollectionPlanResponse operationsArtifactCollectionPlan = operationsArtifactCollectionPlanSnapshot();
        DashboardOperationsReadinessArtifactImportResponse operationsReadinessArtifactImport = operationsReadinessArtifactImportSnapshot();
        DashboardOperationsReadinessFinalizeResponse operationsReadinessFinalize = operationsReadinessFinalizeSnapshot();
        DashboardOperationsHandoffPackageResponse operationsHandoffPackage = operationsHandoffPackageSnapshot();
        DashboardDataFlowStoragePlanResponse dataFlowStoragePlan = dataFlowStoragePlanSnapshot();
        DashboardStorageBackendTelemetryEvidenceResponse storageBackendTelemetryEvidence = storageBackendTelemetryEvidenceSnapshot();
        DashboardOperationsEvidenceHandoffResponse operationsEvidenceHandoff = operationsEvidenceHandoffSnapshot();
        DashboardOperationsReadinessConvergenceResponse operationsReadinessConvergence = operationsReadinessConvergenceSnapshot();
        DashboardKubernetesOperationsReportSyncResponse kubernetesOperationsReportSync = kubernetesOperationsReportSyncSnapshot();
        String status = !blockers.isEmpty()
                ? "ACTION_REQUIRED"
                : warnings.isEmpty() ? "READY" : "REVIEW";
        return new DashboardReadinessResponse(
                status,
                runtimeProfile(metadataEngine, storageEngine),
                blockers.size(),
                warnings.size(),
                List.copyOf(blockers),
                List.copyOf(warnings),
                readinessSeveritySummaries(items),
                readinessCategorySummaries(items),
                List.copyOf(items),
                operationsEvidencePlan,
                operationsEvidenceInvocation,
                operationsInvocationUnblockPlan,
                operationsDispatchPreflight,
                operationsWorkflowRunIdPlan,
                operationsArtifactCollectionPlan,
                operationsReadinessArtifactImport,
                operationsReadinessFinalize,
                operationsHandoffPackage,
                dataFlowStoragePlan,
                storageBackendTelemetryEvidence,
                operationsEvidenceHandoff,
                operationsReadinessConvergence,
                kubernetesOperationsReportSync,
                OffsetDateTime.now()
        );
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
        String bucketName = normalizeLifecycleBucketName(
                request.bucketName(),
                current == null ? "" : current.bucketName()
        );
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
                bucketName,
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

    private String normalizeLifecycleBucketName(String value, String fallback) {
        String normalized = value == null ? fallback : value.trim();
        if (normalized == null) {
            return "";
        }
        return normalized.toLowerCase(Locale.ROOT);
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

    private String mode(String value) {
        return value == null || value.isBlank() ? "in-memory" : value.trim().toLowerCase(Locale.ROOT);
    }

    private void addBlockerIfNotUp(
            java.util.ArrayList<DashboardReadinessItemResponse> items,
            String category,
            String code,
            String label,
            String status,
            String targetPage,
            String targetPanel,
            String actionLabel
    ) {
        if (!"UP".equalsIgnoreCase(status)) {
            addReadinessItem(
                    items,
                    "BLOCKER",
                    category,
                    code,
                    "%s is %s.".formatted(label, status == null || status.isBlank() ? "UNKNOWN" : status),
                    targetPage,
                    targetPanel,
                    actionLabel
            );
        }
    }

    private List<DashboardReadinessCategoryResponse> readinessCategorySummaries(List<DashboardReadinessItemResponse> items) {
        Map<String, List<DashboardReadinessItemResponse>> grouped = items.stream()
                .collect(java.util.stream.Collectors.groupingBy(
                        item -> item.category() == null || item.category().isBlank() ? "GENERAL" : item.category(),
                        LinkedHashMap::new,
                        java.util.stream.Collectors.toList()
                ));
        return grouped.entrySet().stream()
                .map(entry -> new DashboardReadinessCategoryResponse(
                        entry.getKey(),
                        entry.getValue().size(),
                        (int) entry.getValue().stream().filter(item -> "BLOCKER".equals(item.severity())).count(),
                        (int) entry.getValue().stream().filter(item -> "WARNING".equals(item.severity())).count()
                ))
                .toList();
    }

    private List<DashboardReadinessSeverityResponse> readinessSeveritySummaries(List<DashboardReadinessItemResponse> items) {
        Map<String, List<DashboardReadinessItemResponse>> grouped = items.stream()
                .collect(java.util.stream.Collectors.groupingBy(
                        item -> item.severity() == null || item.severity().isBlank() ? "UNKNOWN" : item.severity(),
                        LinkedHashMap::new,
                        java.util.stream.Collectors.toList()
                ));
        return grouped.entrySet().stream()
                .map(entry -> new DashboardReadinessSeverityResponse(entry.getKey(), entry.getValue().size()))
                .toList();
    }

    private void addUniqueReadinessItem(
            java.util.ArrayList<DashboardReadinessItemResponse> items,
            String severity,
            String category,
            String code,
            String message,
            String targetPage,
            String targetPanel,
            String actionLabel
    ) {
        boolean exists = items.stream().anyMatch(item -> item.message().equals(message));
        if (!exists) {
            addReadinessItem(items, severity, category, code, message, targetPage, targetPanel, actionLabel);
        }
    }

    private void addReadinessItem(
            java.util.ArrayList<DashboardReadinessItemResponse> items,
            String severity,
            String category,
            String code,
            String message,
            String targetPage,
            String targetPanel,
            String actionLabel
    ) {
        addReadinessItem(items, severity, category, code, message, targetPage, targetPanel, actionLabel, "", "", "", "", "");
    }

    private void addReadinessItem(
            java.util.ArrayList<DashboardReadinessItemResponse> items,
            String severity,
            String category,
            String code,
            String message,
            String targetPage,
            String targetPanel,
            String actionLabel,
            String evidencePath,
            String remediationCommand,
            String remediationWorkflow,
            String remediationWorkflowCommand,
            String remediationNote
    ) {
        items.add(new DashboardReadinessItemResponse(
                severity,
                category,
                code,
                message,
                targetPage,
                targetPanel,
                actionLabel,
                evidencePath,
                remediationCommand,
                remediationWorkflow,
                remediationWorkflowCommand,
                remediationNote
        ));
    }

    private void addOperationsReadinessItems(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        JsonNode readinessReport = readOptionalJsonReport(operationsReadinessReportPath);
        if (readinessReport != null) {
            String result = jsonText(readinessReport, "result");
            String summary = jsonText(readinessReport, "summary");
            if (!"ready".equalsIgnoreCase(result)) {
                addReadinessItem(
                        items,
                        "WARNING",
                        "OPERATIONS",
                        "OPERATIONS_READINESS_PENDING",
                        "Operations readiness remains %s%s.".formatted(
                                result.isBlank() ? "unknown" : result,
                                summary.isBlank() ? "" : ": " + summary
                        ),
                        "dashboard",
                        "dashboard-readiness-panel",
                        "Operations readiness"
                );
            }
            addOperationsEvidencePlanItem(items);
            addOperationsEvidenceInvocationItem(items);
            addOperationsInvocationUnblockPlanItem(items);
            addOperationsDispatchPreflightItem(items);
            addOperationsWorkflowRunIdPlanItem(items);
            addOperationsArtifactCollectionPlanItem(items);
            addPendingOperationsReadinessChecks(items, readinessReport);
        }

        addOperationsEvidenceHandoffItem(items);
        addOperationsHandoffPackageItem(items);
        addDataFlowStoragePlanItem(items);
        addStorageBackendTelemetryEvidenceItem(items);

        addOperationsReadinessArtifactImportItem(items);
        addOperationsReadinessFinalizeItem(items);
        addOperationsReadinessConvergenceItem(items);
        addKubernetesOperationsReportSyncItem(items);
    }

    private void addOperationsEvidencePlanItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsEvidencePlanResponse evidencePlan = operationsEvidencePlanSnapshot();
        if (evidencePlan.result().isBlank()) {
            return;
        }
        String result = evidencePlan.result();
        if ("ready".equalsIgnoreCase(result)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_EVIDENCE_PLAN",
                "Operations evidence plan is %s%s%s.".formatted(
                        result.isBlank() ? "available" : result,
                        ": actionCount=" + evidencePlan.actionCount(),
                        ", unplannedCount=" + evidencePlan.unplannedCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Evidence plan",
                operationsEvidencePlanReportPath == null ? "" : operationsEvidencePlanReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-evidence-plan.ps1",
                "",
                "",
                "Review the ordered evidence plan before running live Kubernetes or security evidence workflows."
        );
    }

    private DashboardOperationsEvidencePlanResponse operationsEvidencePlanSnapshot() {
        JsonNode evidencePlanReport = readOptionalJsonReport(operationsEvidencePlanReportPath);
        if (evidencePlanReport == null) {
            return DashboardOperationsEvidencePlanResponse.empty();
        }
        java.util.ArrayList<DashboardOperationsEvidenceActionResponse> actions = new java.util.ArrayList<>();
        JsonNode actionNodes = evidencePlanReport.path("actions");
        if (actionNodes.isArray()) {
            for (JsonNode action : actionNodes) {
                actions.add(new DashboardOperationsEvidenceActionResponse(
                        jsonInt(action, "order"),
                        jsonText(action, "name"),
                        jsonText(action, "category"),
                        jsonText(action, "actionType"),
                        jsonText(action, "evidencePath"),
                        jsonText(action, "requiredEvidence"),
                        jsonText(action, "localCommand"),
                        jsonText(action, "workflow"),
                        jsonText(action, "workflowCommand"),
                        jsonText(action, "recommendedCommand"),
                        jsonTextList(action, "operatorInputs"),
                        jsonBoolean(action, "hasPlaceholders"),
                        jsonBoolean(action, "requiresOperatorApproval"),
                        jsonBoolean(action, "requiresKubeconfigSecret"),
                        jsonText(action, "note")
                ));
            }
        }
        return new DashboardOperationsEvidencePlanResponse(
                jsonText(evidencePlanReport, "result"),
                jsonText(evidencePlanReport, "sourceSummary"),
                jsonText(evidencePlanReport, "sourceReport"),
                jsonInt(evidencePlanReport, "pendingCount"),
                jsonInt(evidencePlanReport, "actionCount"),
                jsonInt(evidencePlanReport, "unplannedCount"),
                List.copyOf(actions)
        );
    }

    private void addOperationsEvidenceInvocationItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsEvidenceInvocationResponse invocation = operationsEvidenceInvocationSnapshot();
        if (invocation.result().isBlank()) {
            return;
        }
        String result = invocation.result();
        if ("ready".equalsIgnoreCase(result)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_EVIDENCE_PLAN_INVOCATION",
                "Operations evidence invocation is %s%s%s%s.".formatted(
                        result.isBlank() ? "available" : result,
                        ": selectedActionCount=" + invocation.selectedActionCount(),
                        ", plannedCount=" + invocation.plannedCount(),
                        ", blockedCount=" + invocation.blockedCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Evidence invocation",
                operationsEvidencePlanInvocationReportPath == null ? "" : operationsEvidencePlanInvocationReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1",
                "",
                "",
                "Review blocked/planned invocation actions before dispatching live Kubernetes or security evidence workflows."
        );
    }

    private DashboardOperationsEvidenceInvocationResponse operationsEvidenceInvocationSnapshot() {
        JsonNode invocationReport = readOptionalJsonReport(operationsEvidencePlanInvocationReportPath);
        if (invocationReport == null) {
            return DashboardOperationsEvidenceInvocationResponse.empty();
        }
        java.util.ArrayList<DashboardOperationsEvidenceInvocationActionResponse> actions = new java.util.ArrayList<>();
        JsonNode actionNodes = invocationReport.path("actions");
        if (actionNodes.isArray()) {
            for (JsonNode action : actionNodes) {
                actions.add(new DashboardOperationsEvidenceInvocationActionResponse(
                        jsonInt(action, "order"),
                        jsonText(action, "name"),
                        jsonText(action, "category"),
                        jsonText(action, "actionType"),
                        jsonText(action, "evidencePath"),
                        jsonText(action, "commandMode"),
                        jsonText(action, "command"),
                        jsonText(action, "status"),
                        jsonTextList(action, "blockReasons"),
                        jsonTextList(action, "unresolvedPlaceholders"),
                        jsonBoolean(action, "requiresOperatorApproval"),
                        jsonBoolean(action, "requiresKubeconfigSecret"),
                        jsonNullableInt(action, "exitCode")
                ));
            }
        }
        return new DashboardOperationsEvidenceInvocationResponse(
                jsonText(invocationReport, "result"),
                jsonText(invocationReport, "sourceSummary"),
                jsonText(invocationReport, "sourcePlan"),
                jsonText(invocationReport, "commandMode"),
                jsonText(invocationReport, "executionMode"),
                jsonInt(invocationReport, "selectedActionCount"),
                jsonInt(invocationReport, "plannedCount"),
                jsonInt(invocationReport, "blockedCount"),
                jsonInt(invocationReport, "executedCount"),
                jsonInt(invocationReport, "failedCount"),
                List.copyOf(actions)
        );
    }

    private void addOperationsInvocationUnblockPlanItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsInvocationUnblockPlanResponse unblockPlan = operationsInvocationUnblockPlanSnapshot();
        if (unblockPlan.result().isBlank()) {
            return;
        }
        String result = unblockPlan.result();
        if ("ready".equalsIgnoreCase(result)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_INVOCATION_UNBLOCK_PLAN",
                "Operations invocation unblock plan is %s%s%s%s.".formatted(
                        result.isBlank() ? "available" : result,
                        ": blockedActions=" + unblockPlan.blockedCount(),
                        ", requiredPlaceholders=" + unblockPlan.requiredPlaceholderCount(),
                        ", ambiguousPlaceholders=" + unblockPlan.ambiguousRepeatedPlaceholderCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Invocation unblock",
                operationsInvocationUnblockPlanReportPath == null ? "" : operationsInvocationUnblockPlanReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1",
                "",
                unblockPlan.confirmedPlanCommand(),
                unblockPlan.decisionRule()
        );
    }

    private DashboardOperationsInvocationUnblockPlanResponse operationsInvocationUnblockPlanSnapshot() {
        JsonNode unblockPlanReport = readOptionalJsonReport(operationsInvocationUnblockPlanReportPath);
        if (unblockPlanReport == null) {
            return DashboardOperationsInvocationUnblockPlanResponse.empty();
        }
        java.util.ArrayList<DashboardOperationsInvocationUnblockActionResponse> actions = new java.util.ArrayList<>();
        JsonNode actionNodes = unblockPlanReport.path("actions");
        if (actionNodes.isArray()) {
            for (JsonNode action : actionNodes) {
                java.util.ArrayList<DashboardOperationsInvocationUnblockInputResponse> requiredInputs = new java.util.ArrayList<>();
                JsonNode inputNodes = action.path("requiredInputs");
                if (inputNodes.isArray()) {
                    for (JsonNode input : inputNodes) {
                        requiredInputs.add(new DashboardOperationsInvocationUnblockInputResponse(
                                jsonText(input, "placeholder"),
                                jsonText(input, "parameter"),
                                jsonText(input, "valueTemplate"),
                                jsonInt(input, "occurrenceCount"),
                                jsonBoolean(input, "ambiguousRepeatedPlaceholder"),
                                jsonText(input, "note")
                        ));
                    }
                }
                actions.add(new DashboardOperationsInvocationUnblockActionResponse(
                        jsonInt(action, "order"),
                        jsonText(action, "name"),
                        jsonText(action, "category"),
                        jsonText(action, "actionType"),
                        jsonText(action, "evidencePath"),
                        jsonText(action, "status"),
                        jsonText(action, "commandMode"),
                        jsonText(action, "command"),
                        jsonTextList(action, "blockReasons"),
                        jsonTextList(action, "unresolvedPlaceholders"),
                        jsonBoolean(action, "requiresOperatorApproval"),
                        jsonBoolean(action, "requiresKubeconfigSecret"),
                        jsonBoolean(action, "needsOperatorApprovalConfirmation"),
                        jsonBoolean(action, "needsKubeconfigSecretConfirmation"),
                        List.copyOf(requiredInputs),
                        jsonBoolean(action, "ambiguousRepeatedPlaceholders"),
                        jsonText(action, "planCommand")
                ));
            }
        }
        return new DashboardOperationsInvocationUnblockPlanResponse(
                jsonText(unblockPlanReport, "result"),
                jsonText(unblockPlanReport, "sourceInvocationReport"),
                jsonText(unblockPlanReport, "sourceResult"),
                jsonText(unblockPlanReport, "sourceSummary"),
                jsonInt(unblockPlanReport, "selectedActionCount"),
                jsonInt(unblockPlanReport, "plannedCount"),
                jsonInt(unblockPlanReport, "blockedCount"),
                jsonInt(unblockPlanReport, "failedCount"),
                jsonBoolean(unblockPlanReport, "needsKubeconfigSecretConfirmation"),
                jsonBoolean(unblockPlanReport, "needsOperatorApprovalConfirmation"),
                jsonInt(unblockPlanReport, "requiredPlaceholderCount"),
                jsonInt(unblockPlanReport, "ambiguousRepeatedPlaceholderCount"),
                jsonIntList(unblockPlanReport, "blockedActionOrders"),
                jsonIntList(unblockPlanReport, "plannedActionOrders"),
                jsonText(unblockPlanReport, "confirmedPlanCommand"),
                jsonText(unblockPlanReport, "blockedOnlyPlanCommand"),
                jsonText(unblockPlanReport, "plannedOnlyCommand"),
                jsonText(unblockPlanReport, "decisionRule"),
                List.copyOf(actions)
        );
    }

    private void addOperationsDispatchPreflightItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsDispatchPreflightResponse preflight = operationsDispatchPreflightSnapshot();
        if (preflight.result().isBlank()) {
            return;
        }
        String result = preflight.result();
        if ("ready".equalsIgnoreCase(result)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_DISPATCH_PREFLIGHT",
                "Operations dispatch preflight is %s%s%s%s.".formatted(
                        result.isBlank() ? "available" : result,
                        ": failedChecks=" + preflight.failedCheckCount(),
                        ", missingInputs=" + preflight.missingInputCount(),
                        ", warnings=" + preflight.warningCheckCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Dispatch preflight",
                operationsDispatchPreflightReportPath == null ? "" : operationsDispatchPreflightReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-dispatch-preflight.ps1",
                "",
                preflight.readyPlanCommand(),
                preflight.decisionRule()
        );
    }

    private DashboardOperationsDispatchPreflightResponse operationsDispatchPreflightSnapshot() {
        JsonNode preflightReport = readOptionalJsonReport(operationsDispatchPreflightReportPath);
        if (preflightReport == null) {
            return DashboardOperationsDispatchPreflightResponse.empty();
        }
        java.util.ArrayList<DashboardOperationsDispatchPreflightWorkflowFileResponse> workflowFiles = new java.util.ArrayList<>();
        JsonNode workflowNodes = preflightReport.path("workflowFiles");
        if (workflowNodes.isArray()) {
            for (JsonNode workflow : workflowNodes) {
                workflowFiles.add(new DashboardOperationsDispatchPreflightWorkflowFileResponse(
                        jsonInt(workflow, "actionOrder"),
                        jsonText(workflow, "workflow"),
                        jsonText(workflow, "path"),
                        jsonBoolean(workflow, "exists"),
                        jsonTextList(workflow, "requiredSecrets")
                ));
            }
        }
        java.util.ArrayList<DashboardOperationsDispatchPreflightCheckResponse> checks = new java.util.ArrayList<>();
        JsonNode checkNodes = preflightReport.path("checks");
        if (checkNodes.isArray()) {
            for (JsonNode check : checkNodes) {
                checks.add(new DashboardOperationsDispatchPreflightCheckResponse(
                        jsonText(check, "code"),
                        jsonText(check, "status"),
                        jsonText(check, "message")
                ));
            }
        }
        java.util.ArrayList<DashboardOperationsDispatchPreflightInputResponse> requiredInputs = new java.util.ArrayList<>();
        JsonNode inputNodes = preflightReport.path("requiredInputs");
        if (inputNodes.isArray()) {
            for (JsonNode input : inputNodes) {
                requiredInputs.add(new DashboardOperationsDispatchPreflightInputResponse(
                        jsonInt(input, "actionOrder"),
                        jsonText(input, "placeholder"),
                        jsonText(input, "parameter"),
                        jsonBoolean(input, "supplied"),
                        jsonText(input, "valuePreview"),
                        jsonBoolean(input, "ambiguousRepeatedPlaceholder"),
                        jsonText(input, "note")
                ));
            }
        }
        return new DashboardOperationsDispatchPreflightResponse(
                jsonText(preflightReport, "result"),
                jsonText(preflightReport, "sourceUnblockPlan"),
                jsonText(preflightReport, "sourceResult"),
                jsonInt(preflightReport, "selectedActionCount"),
                jsonIntList(preflightReport, "selectedActionOrders"),
                jsonBoolean(preflightReport, "needsKubeconfigSecretConfirmation"),
                jsonBoolean(preflightReport, "needsOperatorApprovalConfirmation"),
                jsonInt(preflightReport, "requiredInputCount"),
                jsonInt(preflightReport, "missingInputCount"),
                jsonInt(preflightReport, "ambiguousInputCount"),
                jsonInt(preflightReport, "failedCheckCount"),
                jsonInt(preflightReport, "warningCheckCount"),
                jsonTextList(preflightReport, "requiredGitHubSecrets"),
                List.copyOf(workflowFiles),
                List.copyOf(checks),
                jsonText(preflightReport, "readyPlanCommand"),
                jsonText(preflightReport, "executeCommand"),
                List.copyOf(requiredInputs),
                jsonText(preflightReport, "decisionRule")
        );
    }

    private void addOperationsWorkflowRunIdPlanItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsWorkflowRunIdPlanResponse runIdPlan = operationsWorkflowRunIdPlanSnapshot();
        if (runIdPlan.result().isBlank()) {
            return;
        }
        String result = runIdPlan.result();
        if ("ready".equalsIgnoreCase(result)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_WORKFLOW_RUN_ID_PLAN",
                "Operations workflow run id plan is %s%s%s.".formatted(
                        result.isBlank() ? "available" : result,
                        ": workflows=" + runIdPlan.workflowCount(),
                        ", missingRuns=" + runIdPlan.missingWorkflowCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Workflow run ids",
                operationsWorkflowRunIdPlanReportPath == null ? "" : operationsWorkflowRunIdPlanReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1",
                "",
                "",
                "Use the generated gh run list commands after workflow dispatch, then regenerate the artifact collection plan with recommended run ids."
        );
    }

    private DashboardOperationsWorkflowRunIdPlanResponse operationsWorkflowRunIdPlanSnapshot() {
        JsonNode runIdPlanReport = readOptionalJsonReport(operationsWorkflowRunIdPlanReportPath);
        if (runIdPlanReport == null) {
            return DashboardOperationsWorkflowRunIdPlanResponse.empty();
        }
        java.util.ArrayList<DashboardOperationsWorkflowRunResponse> workflows = new java.util.ArrayList<>();
        JsonNode workflowNodes = runIdPlanReport.path("workflows");
        if (workflowNodes.isArray()) {
            for (JsonNode workflow : workflowNodes) {
                workflows.add(new DashboardOperationsWorkflowRunResponse(
                        jsonText(workflow, "workflow"),
                        jsonText(workflow, "group"),
                        jsonText(workflow, "queryCommand"),
                        jsonText(workflow, "queryMode"),
                        jsonInt(workflow, "candidateCount"),
                        jsonText(workflow, "latestRunId"),
                        jsonText(workflow, "latestStatus"),
                        jsonText(workflow, "latestConclusion"),
                        jsonText(workflow, "latestCreatedAt"),
                        jsonText(workflow, "latestHeadSha"),
                        jsonText(workflow, "latestUrl"),
                        jsonText(workflow, "recommendedRunId"),
                        jsonText(workflow, "recommendedHeadSha"),
                        jsonText(workflow, "recommendedCreatedAt"),
                        jsonText(workflow, "recommendedUrl"),
                        jsonBoolean(workflow, "latestRunIsRecommended"),
                        jsonBoolean(workflow, "readyForArtifactDownload"),
                        jsonBoolean(workflow, "requiredForReadiness"),
                        jsonText(workflow, "runIdParameter"),
                        jsonText(workflow, "artifactName"),
                        jsonText(workflow, "note")
                ));
            }
        }
        return new DashboardOperationsWorkflowRunIdPlanResponse(
                jsonText(runIdPlanReport, "result"),
                jsonText(runIdPlanReport, "sourceInvocationReport"),
                jsonText(runIdPlanReport, "invocationResult"),
                jsonText(runIdPlanReport, "branch"),
                jsonText(runIdPlanReport, "queryMode"),
                jsonInt(runIdPlanReport, "limit"),
                jsonInt(runIdPlanReport, "workflowCount"),
                jsonInt(runIdPlanReport, "readyWorkflowCount"),
                jsonInt(runIdPlanReport, "missingWorkflowCount"),
                jsonInt(runIdPlanReport, "staleWorkflowCount"),
                jsonText(runIdPlanReport, "imageSigningVersion"),
                jsonText(runIdPlanReport, "commitSha"),
                jsonText(runIdPlanReport, "artifactCollectionPlanCommand"),
                jsonText(runIdPlanReport, "securityEvidenceFinalizerCommand"),
                jsonText(runIdPlanReport, "decisionRule"),
                List.copyOf(workflows)
        );
    }

    private void addOperationsArtifactCollectionPlanItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsArtifactCollectionPlanResponse collectionPlan = operationsArtifactCollectionPlanSnapshot();
        if (collectionPlan.result().isBlank()) {
            return;
        }
        String result = collectionPlan.result();
        if ("ready".equalsIgnoreCase(result)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_ARTIFACT_COLLECTION_PLAN",
                "Operations artifact collection plan is %s%s%s.".formatted(
                        result.isBlank() ? "available" : result,
                        ": artifacts=" + collectionPlan.artifactCount(),
                        ", missingRequired=" + collectionPlan.missingRequiredArtifactCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Artifact collection",
                operationsArtifactCollectionPlanReportPath == null ? "" : operationsArtifactCollectionPlanReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1",
                ".github/workflows/operations-readiness-artifact-finalizer-ci.yml",
                collectionPlan.operationsArtifactFinalizerCommand(),
                "Fill workflow run ids after evidence workflow dispatch, then import artifacts locally or through the operations artifact finalizer workflow."
        );
    }

    private DashboardOperationsArtifactCollectionPlanResponse operationsArtifactCollectionPlanSnapshot() {
        JsonNode collectionPlanReport = readOptionalJsonReport(operationsArtifactCollectionPlanReportPath);
        if (collectionPlanReport == null) {
            return DashboardOperationsArtifactCollectionPlanResponse.empty();
        }
        java.util.ArrayList<DashboardOperationsArtifactCollectionArtifactResponse> artifacts = new java.util.ArrayList<>();
        JsonNode artifactNodes = collectionPlanReport.path("artifacts");
        if (artifactNodes.isArray()) {
            for (JsonNode artifact : artifactNodes) {
                artifacts.add(new DashboardOperationsArtifactCollectionArtifactResponse(
                        jsonText(artifact, "group"),
                        jsonText(artifact, "workflow"),
                        jsonText(artifact, "runId"),
                        jsonText(artifact, "runIdInput"),
                        jsonText(artifact, "artifactName"),
                        jsonText(artifact, "artifactNameInput"),
                        jsonText(artifact, "downloadPath"),
                        jsonText(artifact, "downloadCommand"),
                        jsonBoolean(artifact, "requiredForReadiness"),
                        jsonBoolean(artifact, "ready"),
                        jsonText(artifact, "note")
                ));
            }
        }
        return new DashboardOperationsArtifactCollectionPlanResponse(
                jsonText(collectionPlanReport, "result"),
                jsonText(collectionPlanReport, "sourceInvocationReport"),
                jsonText(collectionPlanReport, "invocationResult"),
                jsonText(collectionPlanReport, "invocationSummary"),
                jsonInt(collectionPlanReport, "artifactCount"),
                jsonInt(collectionPlanReport, "requiredArtifactCount"),
                jsonInt(collectionPlanReport, "readyArtifactCount"),
                jsonInt(collectionPlanReport, "missingRequiredArtifactCount"),
                jsonText(collectionPlanReport, "securityEvidenceFinalizerCommand"),
                jsonText(collectionPlanReport, "operationsArtifactFinalizerCommand"),
                jsonText(collectionPlanReport, "dataFlowStoragePlanInputNote"),
                jsonText(collectionPlanReport, "localImportCommand"),
                jsonText(collectionPlanReport, "decisionRule"),
                List.copyOf(artifacts)
        );
    }

    private void addOperationsReadinessArtifactImportItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsReadinessArtifactImportResponse artifactImport = operationsReadinessArtifactImportSnapshot();
        if (artifactImport.result().isBlank()) {
            return;
        }
        String result = artifactImport.result();
        if ("passed".equalsIgnoreCase(result)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_READINESS_ARTIFACT_IMPORT",
                "Operations readiness artifact import is %s%s%s.".formatted(
                        result.isBlank() ? "unknown" : result,
                        artifactImport.status().isBlank() ? "" : ": status=" + artifactImport.status(),
                        ", failedCount=" + artifactImport.failedCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Evidence artifacts",
                operationsReadinessArtifactImportReportPath == null ? "" : operationsReadinessArtifactImportReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\import-operations-readiness-artifacts.ps1",
                ".github/workflows/operations-readiness-artifact-finalizer-ci.yml",
                "",
                artifactImport.secretPolicy()
        );
    }

    private DashboardOperationsReadinessArtifactImportResponse operationsReadinessArtifactImportSnapshot() {
        JsonNode importReport = readOptionalJsonReport(operationsReadinessArtifactImportReportPath);
        if (importReport == null) {
            return DashboardOperationsReadinessArtifactImportResponse.empty();
        }
        java.util.ArrayList<DashboardOperationsReadinessArtifactImportEntryResponse> entries = new java.util.ArrayList<>();
        JsonNode entryNodes = importReport.path("entries");
        if (entryNodes.isArray()) {
            for (JsonNode entry : entryNodes) {
                entries.add(new DashboardOperationsReadinessArtifactImportEntryResponse(
                        jsonText(entry, "group"),
                        jsonText(entry, "fileName"),
                        jsonText(entry, "status"),
                        jsonBoolean(entry, "passed"),
                        jsonText(entry, "detail"),
                        jsonText(entry, "sourcePath"),
                        jsonText(entry, "destinationPath")
                ));
            }
        }
        return new DashboardOperationsReadinessArtifactImportResponse(
                jsonText(importReport, "result"),
                jsonText(importReport, "status"),
                jsonInt(importReport, "selectedGroupCount"),
                jsonInt(importReport, "importedCount"),
                jsonInt(importReport, "failedCount"),
                jsonText(importReport, "outputDirectory"),
                jsonText(importReport, "secretPolicy"),
                List.copyOf(entries)
        );
    }

    private void addOperationsReadinessFinalizeItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsReadinessFinalizeResponse finalizeReport = operationsReadinessFinalizeSnapshot();
        if (finalizeReport.result().isBlank()) {
            return;
        }
        String result = finalizeReport.result();
        if ("ready".equalsIgnoreCase(result)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_READINESS_FINALIZER",
                "Operations readiness finalizer is %s%s%s.".formatted(
                        result.isBlank() ? "unknown" : result,
                        finalizeReport.readinessResult().isBlank() ? "" : ": readinessResult=" + finalizeReport.readinessResult(),
                        ", failedCount=" + finalizeReport.failedCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Operations finalizer",
                operationsReadinessFinalizeReportPath == null ? "" : operationsReadinessFinalizeReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\finalize-operations-readiness.ps1",
                ".github/workflows/operations-readiness-finalizer-ci.yml",
                "",
                finalizeReport.secretPolicy().isBlank()
                        ? "Run selected evidence finalizers, then regenerate operations readiness."
                        : finalizeReport.secretPolicy()
        );
    }

    private DashboardOperationsReadinessFinalizeResponse operationsReadinessFinalizeSnapshot() {
        JsonNode finalizeReport = readOptionalJsonReport(operationsReadinessFinalizeReportPath);
        if (finalizeReport == null) {
            return DashboardOperationsReadinessFinalizeResponse.empty();
        }
        java.util.LinkedHashMap<String, Boolean> selectedSteps = new java.util.LinkedHashMap<>();
        JsonNode selectedStepNodes = finalizeReport.path("selectedSteps");
        if (selectedStepNodes.isObject()) {
            selectedStepNodes.fields().forEachRemaining(entry -> selectedSteps.put(entry.getKey(), entry.getValue().asBoolean(false)));
        }
        java.util.LinkedHashMap<String, String> paths = new java.util.LinkedHashMap<>();
        JsonNode pathNodes = finalizeReport.path("paths");
        if (pathNodes.isObject()) {
            pathNodes.fields().forEachRemaining(entry -> paths.put(entry.getKey(), entry.getValue().asText("")));
        }
        java.util.ArrayList<DashboardOperationsReadinessFinalizeCommandResponse> commands = new java.util.ArrayList<>();
        JsonNode commandNodes = finalizeReport.path("commands");
        if (commandNodes.isArray()) {
            for (JsonNode command : commandNodes) {
                commands.add(new DashboardOperationsReadinessFinalizeCommandResponse(
                        jsonText(command, "name"),
                        jsonText(command, "script"),
                        jsonTextList(command, "arguments"),
                        jsonText(command, "command")
                ));
            }
        }
        java.util.ArrayList<DashboardOperationsReadinessFinalizeStepResponse> steps = new java.util.ArrayList<>();
        JsonNode stepNodes = finalizeReport.path("steps");
        if (stepNodes.isArray()) {
            for (JsonNode step : stepNodes) {
                steps.add(new DashboardOperationsReadinessFinalizeStepResponse(
                        jsonText(step, "name"),
                        jsonText(step, "script"),
                        jsonTextList(step, "arguments"),
                        jsonText(step, "command"),
                        jsonText(step, "result"),
                        jsonInt(step, "exitCode"),
                        jsonText(step, "output"),
                        jsonText(step, "notes")
                ));
            }
        }
        return new DashboardOperationsReadinessFinalizeResponse(
                jsonText(finalizeReport, "result"),
                jsonText(finalizeReport, "status"),
                jsonText(finalizeReport, "readinessResult"),
                jsonText(finalizeReport, "readinessSummary"),
                jsonText(finalizeReport, "namespace"),
                jsonText(finalizeReport, "sourceNamespace"),
                jsonText(finalizeReport, "restoreNamespace"),
                jsonText(finalizeReport, "backupTimestamp"),
                jsonText(finalizeReport, "powerShellCommand"),
                jsonInt(finalizeReport, "failedCount"),
                Map.copyOf(selectedSteps),
                Map.copyOf(paths),
                List.copyOf(commands),
                List.copyOf(steps),
                jsonTextList(finalizeReport, "gaps"),
                jsonText(finalizeReport, "secretPolicy")
        );
    }

    private void addOperationsHandoffPackageItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsHandoffPackageResponse handoffPackage = operationsHandoffPackageSnapshot();
        if (handoffPackage.result().isBlank()) {
            return;
        }
        String result = handoffPackage.result();
        if ("passed".equalsIgnoreCase(result)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_HANDOFF_PACKAGE",
                "Operations handoff package is %s: failures=%d, planned=%d, checks=%d.".formatted(
                        result.isBlank() ? "available" : result,
                        handoffPackage.failureCount(),
                        handoffPackage.plannedCount(),
                        handoffPackage.checkCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Handoff package",
                operationsHandoffPackageReportPath == null ? "" : operationsHandoffPackageReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-handoff-package.ps1",
                "",
                "",
                handoffPackage.secretPolicy().isBlank()
                        ? "Record target handoff package evidence after runbook, troubleshooting, rollback, support, and known-gap review."
                        : handoffPackage.secretPolicy()
        );
    }

    private DashboardOperationsHandoffPackageResponse operationsHandoffPackageSnapshot() {
        JsonNode packageReport = readOptionalJsonReport(operationsHandoffPackageReportPath);
        if (packageReport == null) {
            return DashboardOperationsHandoffPackageResponse.empty();
        }
        java.util.LinkedHashMap<String, Boolean> confirmations = new java.util.LinkedHashMap<>();
        JsonNode confirmationNodes = packageReport.path("confirmations");
        if (confirmationNodes.isObject()) {
            confirmationNodes.fields().forEachRemaining(entry -> confirmations.put(entry.getKey(), entry.getValue().asBoolean(false)));
        }
        java.util.ArrayList<DashboardOperationsHandoffPackageCheckResponse> checks = new java.util.ArrayList<>();
        JsonNode checkNodes = packageReport.path("checks");
        if (checkNodes.isArray()) {
            for (JsonNode check : checkNodes) {
                checks.add(new DashboardOperationsHandoffPackageCheckResponse(
                        jsonText(check, "id"),
                        jsonText(check, "name"),
                        jsonText(check, "status"),
                        jsonBoolean(check, "passed"),
                        jsonText(check, "detail"),
                        jsonText(check, "evidenceRef")
                ));
            }
        }
        JsonNode summary = packageReport.path("summary");
        return new DashboardOperationsHandoffPackageResponse(
                jsonText(packageReport, "result"),
                jsonText(packageReport, "generatedAt"),
                jsonText(packageReport, "environmentName"),
                jsonText(packageReport, "targetCluster"),
                jsonText(packageReport, "operatorName"),
                jsonInt(summary, "passedCount"),
                jsonInt(summary, "failureCount"),
                jsonInt(summary, "plannedCount"),
                jsonInt(summary, "checkCount"),
                Map.copyOf(confirmations),
                List.copyOf(checks),
                jsonText(packageReport, "decisionRule"),
                jsonText(packageReport, "scopePolicy"),
                jsonText(packageReport, "secretPolicy")
        );
    }

    private void addDataFlowStoragePlanItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardDataFlowStoragePlanResponse plan = dataFlowStoragePlanSnapshot();
        if (plan.result().isBlank() || "passed".equalsIgnoreCase(plan.result())) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "DATA_FLOW_STORAGE_PLAN",
                "Data-flow storage plan is %s: store=%s, pending=%d/%d.".formatted(
                        plan.result(),
                        plan.candidateStore().isBlank() ? "unknown" : plan.candidateStore(),
                        plan.pendingCount(),
                        plan.checkCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Data-flow plan",
                dataFlowStoragePlanReportPath == null ? "" : dataFlowStoragePlanReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-data-flow-storage-plan.ps1 -CandidateStore <store> -ExpectedPeakEventsPerDay <n> -ExpectedQueryWindowDays <days> -ConfirmNoObjectKeyInAggregates -ConfirmBackfillPlan -ConfirmRollbackPlan -ConfirmDashboardCutoverPlan -ConfirmRetentionJobBudget -ConfirmExplainEvidence -QueryPlanEvidenceJsonPath .\\.osmu-run\\latest-mariadb-query-plan-evidence.json -RequireQueryPlanEvidence",
                "",
                "",
                plan.scopePolicy()
        );
    }

    private DashboardDataFlowStoragePlanResponse dataFlowStoragePlanSnapshot() {
        JsonNode planReport = readOptionalJsonReport(dataFlowStoragePlanReportPath);
        if (planReport == null) {
            return DashboardDataFlowStoragePlanResponse.empty();
        }
        java.util.ArrayList<DashboardDataFlowStoragePlanCheckResponse> checks = new java.util.ArrayList<>();
        JsonNode checkNodes = planReport.path("checks");
        if (checkNodes.isArray()) {
            for (JsonNode check : checkNodes) {
                checks.add(new DashboardDataFlowStoragePlanCheckResponse(
                        jsonText(check, "id"),
                        jsonText(check, "title"),
                        jsonText(check, "status"),
                        jsonText(check, "detail"),
                        jsonText(check, "nextAction")
                ));
            }
        }
        DashboardDataFlowQueryPlanEvidenceResponse queryPlanEvidence =
                dataFlowQueryPlanEvidenceSnapshot(planReport.path("queryPlanEvidence"));
        return new DashboardDataFlowStoragePlanResponse(
                jsonText(planReport, "result"),
                jsonText(planReport, "recordedAt"),
                jsonText(planReport, "environmentName"),
                jsonText(planReport, "targetCluster"),
                jsonText(planReport, "operator"),
                jsonText(planReport, "evidenceRef"),
                jsonText(planReport, "candidateStore"),
                jsonInt(planReport, "expectedPeakEventsPerDay"),
                jsonInt(planReport, "expectedQueryWindowDays"),
                jsonInt(planReport, "eventRetentionDays"),
                jsonInt(planReport, "dailyRollupRetentionDays"),
                jsonInt(planReport, "monthlyRollupRetentionMonths"),
                jsonInt(planReport, "checkCount"),
                jsonInt(planReport, "passedCount"),
                jsonInt(planReport, "pendingCount"),
                List.copyOf(checks),
                queryPlanEvidence,
                jsonText(planReport, "scopePolicy")
        );
    }

    private DashboardDataFlowQueryPlanEvidenceResponse dataFlowQueryPlanEvidenceSnapshot(JsonNode evidence) {
        if (evidence == null || evidence.isMissingNode() || evidence.isNull()) {
            return DashboardDataFlowQueryPlanEvidenceResponse.empty();
        }
        java.util.ArrayList<DashboardDataFlowQueryPlanFailedCheckResponse> failedChecks = new java.util.ArrayList<>();
        JsonNode failedCheckNodes = evidence.path("failedChecks");
        if (failedCheckNodes.isArray()) {
            for (JsonNode failedCheck : failedCheckNodes) {
                failedChecks.add(new DashboardDataFlowQueryPlanFailedCheckResponse(
                        jsonText(failedCheck, "id"),
                        jsonText(failedCheck, "table"),
                        jsonText(failedCheck, "queryPath"),
                        jsonText(failedCheck, "expectedIndex"),
                        jsonText(failedCheck, "status"),
                        jsonBoolean(failedCheck, "usesExpectedIndex"),
                        jsonText(failedCheck, "errorMessage")
                ));
            }
        }
        return new DashboardDataFlowQueryPlanEvidenceResponse(
                jsonBoolean(evidence, "provided"),
                jsonText(evidence, "path"),
                jsonBoolean(evidence, "parsed"),
                jsonText(evidence, "formatVersion"),
                jsonText(evidence, "expectedFormatVersion"),
                jsonBoolean(evidence, "validFormatVersion"),
                jsonText(evidence, "result"),
                jsonText(evidence, "mode"),
                jsonInt(evidence, "checkCount"),
                jsonInt(evidence, "passedCount"),
                jsonInt(evidence, "failedCount"),
                List.copyOf(failedChecks),
                jsonText(evidence, "detail")
        );
    }

    private void addStorageBackendTelemetryEvidenceItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardStorageBackendTelemetryEvidenceResponse telemetry = storageBackendTelemetryEvidenceSnapshot();
        if (telemetry.result().isBlank() || "passed".equalsIgnoreCase(telemetry.result())) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "STORAGE_BACKEND_TELEMETRY_EVIDENCE",
                "Storage backend telemetry evidence is %s: pools=%d, servers=%d, offline=%d, drives=%d.".formatted(
                        telemetry.result(),
                        telemetry.poolCount(),
                        telemetry.serverCount(),
                        telemetry.offlineServerCount(),
                        telemetry.driveCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Storage telemetry",
                storageBackendTelemetryReportPath == null ? "" : storageBackendTelemetryReportPath,
                "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-storage-backend-telemetry-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -MinioAlias <alias> -EvidenceRef <run-ref> -AdminInfoJsonPath .\\.osmu-run\\minio-admin-info.json -FailIfNotPassed",
                "",
                "",
                telemetry.scopePolicy()
        );
    }

    private DashboardStorageBackendTelemetryEvidenceResponse storageBackendTelemetryEvidenceSnapshot() {
        JsonNode telemetryReport = readOptionalJsonReport(storageBackendTelemetryReportPath);
        if (telemetryReport == null) {
            return DashboardStorageBackendTelemetryEvidenceResponse.empty();
        }
        JsonNode source = telemetryReport.path("source");
        JsonNode summary = telemetryReport.path("summary");
        return new DashboardStorageBackendTelemetryEvidenceResponse(
                jsonText(telemetryReport, "result"),
                jsonText(telemetryReport, "generatedAt"),
                jsonText(telemetryReport, "environmentName"),
                jsonText(telemetryReport, "targetCluster"),
                jsonText(telemetryReport, "operatorName"),
                jsonText(source, "mode"),
                jsonText(source, "minioAlias"),
                jsonText(source, "evidenceRef"),
                jsonText(source, "adminInfoJsonSha256"),
                jsonBoolean(source, "rawAdminInfoStored"),
                jsonInt(summary, "poolCount"),
                jsonInt(summary, "serverCount"),
                jsonInt(summary, "onlineServerCount"),
                jsonInt(summary, "offlineServerCount"),
                jsonInt(summary, "driveCount"),
                jsonLong(summary, "totalBytes"),
                jsonLong(summary, "usedBytes"),
                jsonLong(summary, "freeBytes"),
                jsonBoolean(summary, "capacityKnown"),
                jsonInt(summary, "failureCount"),
                jsonInt(summary, "plannedCount"),
                jsonText(telemetryReport, "decisionRule"),
                jsonText(telemetryReport, "scopePolicy")
        );
    }

    private void addOperationsEvidenceHandoffItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsEvidenceHandoffResponse handoff = operationsEvidenceHandoffSnapshot();
        if (handoff.result().isBlank()) {
            return;
        }
        String result = handoff.result();
        String nextCode = handoff.nextStep().code();
        if ("ready".equalsIgnoreCase(result) || "none".equalsIgnoreCase(nextCode)) {
            return;
        }
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_EVIDENCE_HANDOFF",
                "Operations evidence handoff is %s%s%s%s%s%s.".formatted(
                        result.isBlank() ? "available" : result,
                        nextCode.isBlank() ? "" : ": next=" + nextCode,
                        ", blockedActions=" + handoff.blockedActionCount(),
                        ", missingRuns=" + handoff.missingWorkflowRunCount(),
                        ", missingArtifacts=" + handoff.missingRequiredArtifactCount(),
                        handoff.finalizerGapCount() == 0 ? "" : ", finalizerGaps=" + handoff.finalizerGapCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Evidence handoff",
                operationsEvidenceHandoffReportPath == null ? "" : operationsEvidenceHandoffReportPath,
                handoff.nextStep().command(),
                "",
                "",
                "%s%s".formatted(
                        handoff.nextStep().reason(),
                        handoff.nextStep().note().isBlank() ? "" : " " + handoff.nextStep().note()
                ).trim()
        );
    }

    private DashboardOperationsEvidenceHandoffResponse operationsEvidenceHandoffSnapshot() {
        JsonNode handoffReport = readOptionalJsonReport(operationsEvidenceHandoffReportPath);
        if (handoffReport == null) {
            return DashboardOperationsEvidenceHandoffResponse.empty();
        }
        java.util.ArrayList<DashboardOperationsEvidenceHandoffStageResponse> stages = new java.util.ArrayList<>();
        JsonNode stageNodes = handoffReport.path("stages");
        if (stageNodes.isArray()) {
            for (JsonNode stage : stageNodes) {
                stages.add(new DashboardOperationsEvidenceHandoffStageResponse(
                        jsonText(stage, "name"),
                        jsonText(stage, "reportPath"),
                        jsonBoolean(stage, "exists"),
                        jsonText(stage, "result"),
                        jsonText(stage, "summary"),
                        jsonBoolean(stage, "ready"),
                        jsonText(stage, "command"),
                        jsonText(stage, "note")
                ));
            }
        }
        JsonNode nextStep = handoffReport.path("nextStep");
        return new DashboardOperationsEvidenceHandoffResponse(
                jsonText(handoffReport, "result"),
                jsonText(handoffReport, "generatedAt"),
                new DashboardOperationsEvidenceHandoffNextStepResponse(
                        jsonText(nextStep, "code"),
                        jsonText(nextStep, "title"),
                        jsonText(nextStep, "command"),
                        jsonText(nextStep, "reason"),
                        jsonText(nextStep, "note")
                ),
                jsonInt(handoffReport, "stageCount"),
                jsonInt(handoffReport, "readyStageCount"),
                jsonInt(handoffReport, "blockedActionCount"),
                jsonInt(handoffReport, "missingWorkflowRunCount"),
                jsonInt(handoffReport, "missingRequiredArtifactCount"),
                jsonInt(handoffReport, "failedImportCount"),
                jsonInt(handoffReport, "finalizerFailedCount"),
                jsonInt(handoffReport, "finalizerGapCount"),
                List.copyOf(stages)
        );
    }

    private void addOperationsReadinessConvergenceItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardOperationsReadinessConvergenceResponse convergence = operationsReadinessConvergenceSnapshot();
        if (convergence.result().isBlank()) {
            return;
        }
        String result = convergence.result();
        if ("ready".equalsIgnoreCase(result)) {
            return;
        }
        String bottleneckCode = convergence.currentBottleneck().code();
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "OPERATIONS_READINESS_CONVERGENCE",
                "Operations readiness convergence is %s%s%s%s.".formatted(
                        result.isBlank() ? "available" : result,
                        bottleneckCode.isBlank() ? "" : ": bottleneck=" + bottleneckCode,
                        ", stages=" + convergence.readyStageCount() + "/" + convergence.stageCount(),
                        convergence.finalizerGapCount() == 0 ? "" : ", finalizerGaps=" + convergence.finalizerGapCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Convergence",
                operationsReadinessConvergenceReportPath == null ? "" : operationsReadinessConvergenceReportPath,
                convergence.currentBottleneck().command(),
                "",
                "",
                "%s%s".formatted(
                        convergence.currentBottleneck().reason(),
                        convergence.safetyPolicy().isBlank() ? "" : " " + convergence.safetyPolicy()
                ).trim()
        );
    }

    private DashboardOperationsReadinessConvergenceResponse operationsReadinessConvergenceSnapshot() {
        JsonNode convergenceReport = readOptionalJsonReport(operationsReadinessConvergenceReportPath);
        if (convergenceReport == null) {
            return DashboardOperationsReadinessConvergenceResponse.empty();
        }
        JsonNode bottleneck = convergenceReport.path("currentBottleneck");
        java.util.ArrayList<DashboardOperationsReadinessConvergenceCommandResponse> recommendedCommands = new java.util.ArrayList<>();
        JsonNode commandNodes = convergenceReport.path("recommendedCommands");
        if (commandNodes.isArray()) {
            for (JsonNode command : commandNodes) {
                recommendedCommands.add(new DashboardOperationsReadinessConvergenceCommandResponse(
                        jsonInt(command, "order"),
                        jsonText(command, "name"),
                        jsonText(command, "command"),
                        jsonText(command, "reason")
                ));
            }
        }
        return new DashboardOperationsReadinessConvergenceResponse(
                jsonText(convergenceReport, "result"),
                jsonText(convergenceReport, "generatedAt"),
                jsonText(convergenceReport, "handoffReportPath"),
                jsonText(convergenceReport, "readinessReportPath"),
                jsonText(convergenceReport, "operationsReadinessFinalizeReportPath"),
                jsonBoolean(convergenceReport, "handoffExists"),
                jsonText(convergenceReport, "handoffResult"),
                jsonBoolean(convergenceReport, "readinessExists"),
                jsonText(convergenceReport, "readinessResult"),
                jsonText(convergenceReport, "readinessSummary"),
                jsonBoolean(convergenceReport, "finalizerExists"),
                jsonText(convergenceReport, "finalizerResult"),
                jsonText(convergenceReport, "finalizerReadinessResult"),
                jsonInt(convergenceReport, "finalizerFailedCount"),
                jsonText(convergenceReport, "kubernetesOperationsReportSyncReportPath"),
                jsonBoolean(convergenceReport, "kubernetesReportSyncExists"),
                jsonText(convergenceReport, "kubernetesReportSyncResult"),
                jsonInt(convergenceReport, "kubernetesReportSyncFailedCount"),
                jsonText(convergenceReport, "kubernetesReportSyncConfigMapName"),
                jsonText(convergenceReport, "kubernetesReportSyncConfigMapKey"),
                jsonText(convergenceReport, "kubernetesReportSyncSourceReportResult"),
                jsonText(convergenceReport, "kubernetesReportSyncWorkflowCommand"),
                jsonText(convergenceReport, "kubernetesReportSyncWorkflowNote"),
                jsonBoolean(convergenceReport, "kubernetesReportSyncReady"),
                jsonInt(convergenceReport, "finalizerGapCount"),
                jsonInt(convergenceReport, "stageCount"),
                jsonInt(convergenceReport, "readyStageCount"),
                jsonInt(convergenceReport, "blockedActionCount"),
                jsonInt(convergenceReport, "missingWorkflowRunCount"),
                jsonInt(convergenceReport, "missingRequiredArtifactCount"),
                jsonInt(convergenceReport, "failedImportCount"),
                new DashboardOperationsReadinessConvergenceBottleneckResponse(
                        jsonText(bottleneck, "code"),
                        jsonText(bottleneck, "title"),
                        jsonText(bottleneck, "reason"),
                        jsonText(bottleneck, "command")
                ),
                List.copyOf(recommendedCommands),
                jsonText(convergenceReport, "decisionRule"),
                jsonText(convergenceReport, "safetyPolicy")
        );
    }

    private void addKubernetesOperationsReportSyncItem(java.util.ArrayList<DashboardReadinessItemResponse> items) {
        DashboardKubernetesOperationsReportSyncResponse reportSync = kubernetesOperationsReportSyncSnapshot();
        if (reportSync.result().isBlank()) {
            return;
        }
        String result = reportSync.result();
        if ("applied".equalsIgnoreCase(result) && reportSync.failedCount() == 0) {
            return;
        }
        String remediationCommand = switch (result.toLowerCase(Locale.ROOT)) {
            case "planned" -> reportSync.serverDryRunCommand();
            case "server-dry-run-passed" -> reportSync.applyCommand();
            default -> reportSync.clientDryRunCommand();
        };
        addReadinessItem(
                items,
                "WARNING",
                "OPERATIONS",
                "KUBERNETES_OPERATIONS_REPORT_SYNC",
                "Kubernetes operations report sync is %s: namespace=%s, configMap=%s, failedCount=%d.".formatted(
                        result,
                        reportSync.namespace().isBlank() ? "unknown" : reportSync.namespace(),
                        reportSync.configMapName().isBlank() ? "unknown" : reportSync.configMapName(),
                        reportSync.failedCount()
                ),
                "dashboard",
                "dashboard-readiness-panel",
                "Kubernetes sync",
                kubernetesOperationsReportSyncReportPath == null ? "" : kubernetesOperationsReportSyncReportPath,
                remediationCommand,
                ".github/workflows/kubernetes-operations-report-sync-ci.yml",
                reportSync.applyCommand(),
                reportSync.safetyPolicy()
        );
    }

    private DashboardKubernetesOperationsReportSyncResponse kubernetesOperationsReportSyncSnapshot() {
        JsonNode report = readOptionalJsonReport(kubernetesOperationsReportSyncReportPath);
        if (report == null) {
            return DashboardKubernetesOperationsReportSyncResponse.empty();
        }
        java.util.ArrayList<DashboardKubernetesOperationsReportSyncCheckResponse> checks = new java.util.ArrayList<>();
        JsonNode checkNodes = report.path("checks");
        if (checkNodes.isArray()) {
            for (JsonNode check : checkNodes) {
                checks.add(new DashboardKubernetesOperationsReportSyncCheckResponse(
                        jsonText(check, "name"),
                        jsonBoolean(check, "passed"),
                        jsonText(check, "summary"),
                        jsonText(check, "command"),
                        jsonInt(check, "exitCode")
                ));
            }
        }
        return new DashboardKubernetesOperationsReportSyncResponse(
                jsonText(report, "result"),
                jsonText(report, "generatedAt"),
                jsonText(report, "namespace"),
                jsonText(report, "configMapName"),
                jsonText(report, "configMapKey"),
                jsonText(report, "sourceReportPath"),
                jsonText(report, "sourceReportFormatVersion"),
                jsonText(report, "sourceReportResult"),
                jsonLong(report, "sourceReportBytes"),
                jsonText(report, "sourceReportSha256"),
                jsonText(report, "clientDryRunCommand"),
                jsonText(report, "serverDryRunCommand"),
                jsonText(report, "applyCommand"),
                jsonInt(report, "checkCount"),
                jsonInt(report, "failedCount"),
                List.copyOf(checks),
                jsonText(report, "safetyPolicy")
        );
    }

    private void addPendingOperationsReadinessChecks(
            java.util.ArrayList<DashboardReadinessItemResponse> items,
            JsonNode readinessReport
    ) {
        JsonNode checks = readinessReport.path("checks");
        if (!checks.isArray()) {
            return;
        }
        int count = 0;
        for (JsonNode check : checks) {
            if (check.path("passed").asBoolean(false)) {
                continue;
            }
            String name = jsonText(check, "name");
            String category = jsonText(check, "category");
            String detail = jsonText(check, "detail");
            String evidencePath = jsonText(check, "evidencePath");
            JsonNode remediation = check.path("remediation");
            String remediationCommand = jsonText(remediation, "command");
            String remediationWorkflow = jsonText(remediation, "workflow");
            String remediationWorkflowCommand = jsonText(remediation, "workflowCommand");
            String remediationNote = jsonText(remediation, "note");
            addReadinessItem(
                    items,
                    "WARNING",
                    "OPERATIONS",
                    "OPERATIONS_READINESS_CHECK",
                    "Operations readiness pending: %s%s%s.".formatted(
                            name.isBlank() ? "unnamed check" : name,
                            category.isBlank() ? "" : " / " + category,
                            detail.isBlank() ? "" : " - " + detail
                    ),
                    "dashboard",
                    "dashboard-readiness-panel",
                    "Evidence",
                    evidencePath,
                    remediationCommand,
                    remediationWorkflow,
                    remediationWorkflowCommand,
                    remediationNote
            );
            count++;
            if (count >= 8) {
                return;
            }
        }
    }

    private JsonNode readOptionalJsonReport(String reportPath) {
        if (reportPath == null || reportPath.isBlank()) {
            return null;
        }
        Path path = Path.of(reportPath).toAbsolutePath().normalize();
        if (!Files.isRegularFile(path)) {
            return null;
        }
        try {
            return JSON_MAPPER.readTree(path.toFile());
        } catch (IOException exception) {
            return null;
        }
    }

    private String jsonText(JsonNode node, String fieldName) {
        JsonNode value = node.path(fieldName);
        if (value.isMissingNode() || value.isNull()) {
            return "";
        }
        return value.asText("");
    }

    private int jsonInt(JsonNode node, String fieldName) {
        JsonNode value = node.path(fieldName);
        return value.isNumber() ? value.asInt(0) : 0;
    }

    private long jsonLong(JsonNode node, String fieldName) {
        JsonNode value = node.path(fieldName);
        return value.isNumber() ? value.asLong(0L) : 0L;
    }

    private Integer jsonNullableInt(JsonNode node, String fieldName) {
        JsonNode value = node.path(fieldName);
        return value.isNumber() ? value.asInt() : null;
    }

    private boolean jsonBoolean(JsonNode node, String fieldName) {
        JsonNode value = node.path(fieldName);
        return value.isBoolean() && value.asBoolean(false);
    }

    private List<String> jsonTextList(JsonNode node, String fieldName) {
        JsonNode value = node.path(fieldName);
        if (!value.isArray()) {
            return List.of();
        }
        java.util.ArrayList<String> values = new java.util.ArrayList<>();
        for (JsonNode item : value) {
            if (!item.isNull()) {
                String text = item.asText("");
                if (!text.isBlank()) {
                    values.add(text);
                }
            }
        }
        return List.copyOf(values);
    }

    private List<Integer> jsonIntList(JsonNode node, String fieldName) {
        JsonNode value = node.path(fieldName);
        if (!value.isArray()) {
            return List.of();
        }
        java.util.ArrayList<Integer> values = new java.util.ArrayList<>();
        for (JsonNode item : value) {
            if (item.isNumber()) {
                values.add(item.asInt());
            }
        }
        return List.copyOf(values);
    }

    private String runtimeProfile(String metadataEngine, String storageEngine) {
        if ("mariadb".equals(metadataEngine) && "minio".equals(storageEngine)) {
            return "MariaDB + MinIO";
        }
        if ("in-memory".equals(metadataEngine) || "in-memory".equals(storageEngine)) {
            return "Local demo runtime";
        }
        return "%s + %s".formatted(metadataEngine, storageEngine);
    }

    private boolean isQuotaWarning(QuotaPolicyResponse policy) {
        return policy.quotaBytes() > 0
                && !isQuotaExhausted(policy)
                && policy.usedBytes() * 100.0 / policy.quotaBytes() >= 80.0;
    }

    private boolean isQuotaExhausted(QuotaPolicyResponse policy) {
        return policy.quotaBytes() > 0 && policy.remainingBytes() <= 0;
    }

    private double quotaUsageRatio(QuotaPolicyResponse policy) {
        if (policy.quotaBytes() <= 0) {
            return 0.0;
        }
        return (double) policy.usedBytes() / (double) policy.quotaBytes();
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private OffsetDateTime parseOptionalOffsetDateTime(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return OffsetDateTime.parse(value.trim());
        } catch (DateTimeParseException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be an ISO-8601 offset datetime.");
        }
    }

    private int normalizeDataFlowLimit(Integer limit) {
        if (limit == null || limit <= 0) {
            return 50;
        }
        return Math.min(500, limit);
    }

    private double counterValue(String name, String tagName, String tagValue) {
        Counter counter = meterRegistry.find(name).tag(tagName, tagValue).counter();
        return counter == null ? 0.0 : counter.count();
    }
}
