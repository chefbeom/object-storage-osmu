param(
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-readiness.md"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-CheckExists([object] $report, [string] $name, [string] $category) {
    $match = @($report.checks | Where-Object { $_.name -eq $name -and $_.category -eq $category })
    if ($match.Count -ne 1) {
        throw "Operations readiness report must contain one check named '$name' in category '$category'."
    }
}

function Assert-CheckRemediation(
    [object] $report,
    [string] $name,
    [string] $commandFragment,
    [string] $workflowPath,
    [string] $workflowCommandFragment
) {
    $match = @($report.checks | Where-Object { $_.name -eq $name })
    if ($match.Count -ne 1) {
        throw "Operations readiness report must contain one check named '$name'."
    }
    $remediation = $match[0].remediation
    if ($null -eq $remediation) {
        throw "Operations readiness check '$name' must include remediation metadata."
    }
    if (-not ([string] $remediation.command).Contains($commandFragment)) {
        throw "Operations readiness check '$name' remediation command must contain '$commandFragment'. Actual: $($remediation.command)"
    }
    if ($remediation.workflow -ne $workflowPath) {
        throw "Operations readiness check '$name' remediation workflow must be '$workflowPath'. Actual: $($remediation.workflow)"
    }
    if (-not ([string] $remediation.workflowCommand).Contains($workflowCommandFragment)) {
        throw "Operations readiness check '$name' remediation workflow command must contain '$workflowCommandFragment'. Actual: $($remediation.workflowCommand)"
    }
}

function New-PassedOperationsHandoffPackageConfirmations() {
    return [ordered]@{
        noSecretValues = $true
        runbookReviewed = $true
        troubleshootingReviewed = $true
        rollbackReviewed = $true
        supportEscalationReviewed = $true
        knownGapsAccepted = $true
        operationsReadinessSnapshotReviewed = $true
        operationsConvergenceSnapshotReviewed = $true
        dataFlowStoragePlanReviewed = $true
        dataFlowStorageTransitionRunbookReviewed = $true
        secretRotationSnapshotReviewed = $true
        commercialIntegrationSnapshotReviewed = $true
        commercialApprovalSnapshotReviewed = $true
        enterpriseAuthSmokeSnapshotReviewed = $true
        monitoringThresholdReviewed = $true
        requireProductionEvidence = $true
        requireOperationsSnapshotEvidence = $true
    }
}

function New-PassedOperationsHandoffPackageSnapshots(
    [string] $ConvergenceSourceReportResult = "ready",
    [object] $FinalizerFailedCount = 0,
    [object] $FinalizerGapCount = 0,
    [object] $KubernetesReportSyncReady = $true
) {
    return [ordered]@{
        readiness = [ordered]@{
            provided = $true
            parsed = $true
            result = "ready"
            ready = $true
            passedCount = 42
            pendingCount = 0
            checkCount = 42
        }
        convergence = [ordered]@{
            provided = $true
            parsed = $true
            result = "ready"
            ready = $true
            readinessResult = "ready"
            readinessSummary = "passed=42 pending=0"
            finalizerResult = "ready"
            finalizerReadinessResult = "ready"
            finalizerFailedCount = $FinalizerFailedCount
            finalizerGapCount = $FinalizerGapCount
            kubernetesReportSyncReady = $KubernetesReportSyncReady
            kubernetesReportSyncResult = "applied"
            kubernetesReportSyncFailedCount = 0
            kubernetesReportSyncSourceReportResult = $ConvergenceSourceReportResult
        }
    }
}

$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-readiness.ps1"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -JsonOutputPath $resolvedJsonOutputPath -MarkdownOutputPath $resolvedMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $resolvedJsonOutputPath)) {
    throw "Operations readiness JSON missing: $resolvedJsonOutputPath"
}
if (-not (Test-Path -LiteralPath $resolvedMarkdownOutputPath)) {
    throw "Operations readiness markdown missing: $resolvedMarkdownOutputPath"
}

$report = Get-Content -Raw -LiteralPath $resolvedJsonOutputPath | ConvertFrom-Json
$markdown = Get-Content -Raw -LiteralPath $resolvedMarkdownOutputPath

if ($report.formatVersion -ne "osmu.operations-readiness.v1") {
    throw "Unexpected operations readiness formatVersion: $($report.formatVersion)"
}
if ($report.result -notin @("ready", "pending")) {
    throw "Unexpected operations readiness result: $($report.result)"
}
if ($report.checks.Count -lt 20) {
    throw "Operations readiness report has too few checks: $($report.checks.Count)"
}

Assert-CheckExists $report "Release report available" "release"
Assert-CheckExists $report "Kubernetes manifest draft" "static-infra"
Assert-CheckExists $report "Helm chart draft" "static-infra"
Assert-CheckExists $report "NetworkPolicy draft" "security-hardening"
Assert-CheckExists $report "Container hardening draft" "security-hardening"
Assert-CheckExists $report "TLS ingress draft" "security-hardening"
Assert-CheckExists $report "Secret rotation policy draft" "security-hardening"
Assert-CheckExists $report "IAM/RBAC matrix verifier" "iam-rbac"
Assert-CheckExists $report "IAM/RBAC finalizer" "iam-rbac"
Assert-CheckExists $report "IAM/RBAC finalizer self-test" "iam-rbac"
Assert-CheckExists $report "IAM/RBAC finalizer workflow" "iam-rbac"
Assert-CheckExists $report "Kubernetes RBAC matrix verifier" "kubernetes-rbac"
Assert-CheckExists $report "Storage expansion finalizer workflow" "automation"
Assert-CheckExists $report "Kubernetes HA/DR readiness workflow" "ha-dr"
Assert-CheckExists $report "Kubernetes DR finalizer workflow" "automation"
Assert-CheckExists $report "Operations readiness finalizer workflow" "automation"
Assert-CheckExists $report "Operations readiness finalizer" "automation"
Assert-CheckExists $report "Operations readiness finalizer self-test" "automation"
Assert-CheckExists $report "Operations readiness artifact importer" "automation"
Assert-CheckExists $report "Operations readiness artifact importer self-test" "automation"
Assert-CheckExists $report "Operations readiness artifact finalizer workflow" "automation"
Assert-CheckExists $report "Container security evidence writer" "security-hardening"
Assert-CheckExists $report "Image signing evidence writer" "security-hardening"
Assert-CheckExists $report "Security evidence writer self-test" "security-hardening"
Assert-CheckExists $report "Storage backend telemetry evidence writer" "storage-backend"
Assert-CheckExists $report "Storage backend telemetry evidence writer self-test" "storage-backend"
Assert-CheckExists $report "MariaDB query plan evidence writer" "data-flow"
Assert-CheckExists $report "MariaDB query plan evidence self-test" "data-flow"
Assert-CheckExists $report "Data-flow storage plan writer" "data-flow"
Assert-CheckExists $report "Data-flow storage plan self-test" "data-flow"
Assert-CheckExists $report "Data-flow storage transition runbook writer" "data-flow"
Assert-CheckExists $report "Data-flow storage transition runbook self-test" "data-flow"
Assert-CheckExists $report "Data-flow storage transition runbook workflow" "data-flow"
Assert-CheckExists $report "Monitoring threshold evidence writer" "monitoring"
Assert-CheckExists $report "Monitoring threshold evidence writer self-test" "monitoring"
Assert-CheckExists $report "Monitoring threshold evidence workflow" "monitoring"
Assert-CheckExists $report "Secret rotation evidence writer" "security-hardening"
Assert-CheckExists $report "Secret rotation evidence writer self-test" "security-hardening"
Assert-CheckExists $report "Secret rotation evidence workflow" "security-hardening"
Assert-CheckExists $report "Commercial integration evidence writer" "commercial-integration"
Assert-CheckExists $report "Commercial integration evidence writer self-test" "commercial-integration"
Assert-CheckExists $report "Commercial integration evidence workflow" "commercial-integration"
Assert-CheckExists $report "Commercial approval evidence writer" "commercial-approval"
Assert-CheckExists $report "Commercial approval evidence writer self-test" "commercial-approval"
Assert-CheckExists $report "Commercial approval evidence workflow" "commercial-approval"
Assert-CheckExists $report "Chargeback closeout evidence writer" "chargeback-closeout"
Assert-CheckExists $report "Chargeback closeout evidence writer self-test" "chargeback-closeout"
Assert-CheckExists $report "Chargeback closeout target evidence" "chargeback-closeout"
Assert-CheckExists $report "Operations handoff package writer" "operations-handoff-package"
Assert-CheckExists $report "Operations handoff package writer self-test" "operations-handoff-package"
Assert-CheckExists $report "Operations handoff package workflow" "operations-handoff-package"
Assert-CheckExists $report "Security evidence finalizer" "security-hardening"
Assert-CheckExists $report "Security evidence finalizer self-test" "security-hardening"
Assert-CheckExists $report "Security evidence finalizer workflow" "security-hardening"
Assert-CheckExists $report "Enterprise auth smoke workflow" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth smoke evidence helper" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth smoke evidence helper self-test" "enterprise-auth"
Assert-CheckExists $report "Storage expansion finalizer live evidence" "storage-expansion"
Assert-CheckExists $report "Kubernetes HA/DR readiness live evidence" "ha-dr"
Assert-CheckExists $report "Kubernetes DR finalizer live evidence" "ha-dr"
Assert-CheckExists $report "IAM/RBAC finalizer report" "iam-rbac"
Assert-CheckExists $report "Security evidence finalizer report" "security-hardening"
Assert-CheckExists $report "Signed image evidence" "security-hardening"
Assert-CheckExists $report "Container scan/SBOM evidence" "security-hardening"
Assert-CheckExists $report "Storage backend telemetry target evidence" "storage-backend"
Assert-CheckExists $report "Data-flow storage transition target evidence" "data-flow"
Assert-CheckExists $report "Data-flow storage transition runbook target evidence" "data-flow"
Assert-CheckExists $report "Monitoring threshold target evidence" "monitoring"
Assert-CheckExists $report "Secret/certificate rotation target evidence" "security-hardening"
Assert-CheckExists $report "Commercial integration target evidence" "commercial-integration"
Assert-CheckExists $report "Commercial approval target evidence" "commercial-approval"
Assert-CheckExists $report "Enterprise auth target smoke evidence" "enterprise-auth"
Assert-CheckExists $report "Operations handoff package target evidence" "operations-handoff-package"

Assert-CheckRemediation $report "Storage expansion finalizer live evidence" "finalize-storage-expansion.ps1" ".github/workflows/storage-expansion-finalizer-ci.yml" "gh workflow run storage-expansion-finalizer-ci.yml"
Assert-CheckRemediation $report "Kubernetes HA/DR readiness live evidence" "verify-kubernetes-ha-dr-readiness.ps1" ".github/workflows/kubernetes-ha-dr-readiness-ci.yml" "gh workflow run kubernetes-ha-dr-readiness-ci.yml"
Assert-CheckRemediation $report "Kubernetes DR finalizer live evidence" "finalize-kubernetes-dr-drill.ps1" ".github/workflows/kubernetes-dr-finalizer-ci.yml" "gh workflow run kubernetes-dr-finalizer-ci.yml"
Assert-CheckRemediation $report "Security evidence finalizer report" "finalize-security-evidence.ps1" ".github/workflows/security-evidence-finalizer-ci.yml" "gh workflow run security-evidence-finalizer-ci.yml"
Assert-CheckRemediation $report "Signed image evidence" "image-publish-sign-ci.yml" ".github/workflows/image-publish-sign-ci.yml" "gh workflow run image-publish-sign-ci.yml"
Assert-CheckRemediation $report "Container scan/SBOM evidence" "container-security-ci.yml" ".github/workflows/container-security-ci.yml" "gh workflow run container-security-ci.yml"
$securityFinalizeCheck = @($report.checks | Where-Object { $_.name -eq "Security evidence finalizer report" })
if ($securityFinalizeCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Security evidence finalizer report check."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.workflowCommand).Contains("image_signing_artifact_name=<artifact-name>")) {
    throw "Security evidence finalizer workflow command must include image signing artifact name input."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.workflowCommand).Contains("container_security_artifact_name=<artifact-name>")) {
    throw "Security evidence finalizer workflow command must include container security artifact name input."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.workflowCommand).Contains("fail_if_not_passed=true")) {
    throw "Security evidence finalizer workflow command must fail if promoted evidence is not passed."
}
if (-not ([string] $securityFinalizeCheck[0].requiredEvidence).Contains("strict image signing and container SBOM import validation")) {
    throw "Security evidence finalizer required evidence must mention strict image signing and container SBOM import validation."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.note).Contains("GitHub OIDC keyless signing")) {
    throw "Security evidence finalizer remediation note must mention GitHub OIDC keyless signing."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.note).Contains("SPDX SBOM")) {
    throw "Security evidence finalizer remediation note must mention SPDX SBOM validation."
}
$imageSigningCheck = @($report.checks | Where-Object { $_.name -eq "Signed image evidence" })
if ($imageSigningCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Signed image evidence check."
}
if (-not ([string] $imageSigningCheck[0].remediation.command).Contains("publish=true")) {
    throw "Signed image evidence remediation command must require publish=true."
}
if (-not ([string] $imageSigningCheck[0].remediation.workflowCommand).Contains("-f version=v0.1.0-rc.1")) {
    throw "Signed image evidence workflow command must include a release version input example."
}
if (-not ([string] $imageSigningCheck[0].remediation.workflowCommand).Contains("-f publish=true")) {
    throw "Signed image evidence workflow command must publish images."
}
if (-not ([string] $imageSigningCheck[0].requiredEvidence).Contains("GitHub OIDC keyless Cosign verification")) {
    throw "Signed image evidence must require GitHub OIDC keyless Cosign verification."
}
if (-not ([string] $imageSigningCheck[0].requiredEvidence).Contains("release-version and commit-SHA tags")) {
    throw "Signed image evidence must require release-version and commit-SHA tags."
}
if (-not ([string] $imageSigningCheck[0].remediation.note).Contains("commit-SHA tag verification")) {
    throw "Signed image evidence remediation note must mention commit-SHA tag verification."
}
$containerSecurityCheck = @($report.checks | Where-Object { $_.name -eq "Container scan/SBOM evidence" })
if ($containerSecurityCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Container scan/SBOM evidence check."
}
if (-not ([string] $containerSecurityCheck[0].requiredEvidence).Contains("Trivy CRITICAL,HIGH")) {
    throw "Container scan/SBOM evidence must require Trivy CRITICAL,HIGH scan evidence."
}
if (-not ([string] $containerSecurityCheck[0].requiredEvidence).Contains("commit-SHA image tag")) {
    throw "Container scan/SBOM evidence must require commit-SHA image tag evidence."
}
if (-not ([string] $containerSecurityCheck[0].requiredEvidence).Contains("backend/frontend SPDX SBOM")) {
    throw "Container scan/SBOM evidence must require backend/frontend SPDX SBOM evidence."
}
if (-not ([string] $containerSecurityCheck[0].remediation.note).Contains("ignore-unfixed policy")) {
    throw "Container scan/SBOM remediation note must mention ignore-unfixed policy recording."
}
if (-not ([string] $containerSecurityCheck[0].remediation.note).Contains("commit-SHA image tag")) {
    throw "Container scan/SBOM remediation note must mention commit-SHA image tag capture."
}
if (-not ([string] $containerSecurityCheck[0].remediation.note).Contains("SPDX SBOM metadata")) {
    throw "Container scan/SBOM remediation note must mention SPDX SBOM metadata generation."
}
$storageBackendTelemetryCheck = @($report.checks | Where-Object { $_.name -eq "Storage backend telemetry target evidence" })
if ($storageBackendTelemetryCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Storage backend telemetry target evidence check."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.command).Contains("write-storage-backend-telemetry-evidence.ps1")) {
    throw "Storage backend telemetry target evidence remediation must point to write-storage-backend-telemetry-evidence.ps1."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.workflow).Contains("manual-storage-backend-telemetry-evidence.yml")) {
    throw "Storage backend telemetry target evidence remediation workflow must point to manual-storage-backend-telemetry-evidence.yml."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-storage-backend-telemetry-evidence.yml")) {
    throw "Storage backend telemetry target evidence remediation workflow command must dispatch manual-storage-backend-telemetry-evidence.yml."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.workflowCommand).Contains("collection_mode=live")) {
    throw "Storage backend telemetry target evidence remediation workflow command must select live collection mode."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.workflowCommand).Contains("minio_endpoint=<minio-endpoint>")) {
    throw "Storage backend telemetry target evidence remediation workflow command must include target MinIO endpoint input."
}
if (-not ([string] $storageBackendTelemetryCheck[0].requiredEvidence).Contains("target MinIO admin info evidence")) {
    throw "Storage backend telemetry target evidence must require target MinIO admin info evidence."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.note).Contains("mc admin info --json")) {
    throw "Storage backend telemetry target evidence remediation note must mention mc admin info --json."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.note).Contains("OSMU_MINIO_ACCESS_KEY")) {
    throw "Storage backend telemetry target evidence remediation note must mention OSMU_MINIO_ACCESS_KEY."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.note).Contains("OSMU_MINIO_SECRET_KEY")) {
    throw "Storage backend telemetry target evidence remediation note must mention OSMU_MINIO_SECRET_KEY."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.note).Contains("OSMU_MINIO_ADMIN_INFO_JSON_BASE64")) {
    throw "Storage backend telemetry target evidence remediation note must mention OSMU_MINIO_ADMIN_INFO_JSON_BASE64."
}
$dataFlowStoragePlanCheck = @($report.checks | Where-Object { $_.name -eq "Data-flow storage transition target evidence" })
if ($dataFlowStoragePlanCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Data-flow storage transition target evidence check."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.command).Contains("write-data-flow-storage-plan.ps1")) {
    throw "Data-flow storage transition target evidence remediation must point to write-data-flow-storage-plan.ps1."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.command).Contains("QueryPlanEvidenceJsonPath")) {
    throw "Data-flow storage transition target evidence remediation must include QueryPlanEvidenceJsonPath."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.command).Contains("RequireQueryPlanEvidence")) {
    throw "Data-flow storage transition target evidence remediation must require query-plan evidence for the MariaDB candidate."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.command).Contains("TargetP95QueryLatencyMs")) {
    throw "Data-flow storage transition target evidence remediation must include TargetP95QueryLatencyMs."
}
if ($dataFlowStoragePlanCheck[0].remediation.workflow -ne ".github/workflows/manual-data-flow-storage-plan-evidence.yml") {
    throw "Data-flow storage transition target evidence remediation must point to the manual data-flow storage plan workflow."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.workflowCommand).Contains("manual-data-flow-storage-plan-evidence.yml")) {
    throw "Data-flow storage transition target evidence remediation workflow command must dispatch manual-data-flow-storage-plan-evidence.yml."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.workflowCommand).Contains("query_plan_evidence_json_base64")) {
    throw "Data-flow storage transition target evidence workflow command must include query_plan_evidence_json_base64."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.workflowCommand).Contains("target_p95_query_latency_ms")) {
    throw "Data-flow storage transition target evidence workflow command must include target_p95_query_latency_ms."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].requiredEvidence).Contains("target query-plan evidence")) {
    throw "Data-flow storage transition target evidence must require target query-plan evidence."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].requiredEvidence).Contains("target p95 query latency budget")) {
    throw "Data-flow storage transition target evidence must require target p95 query latency budget."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("write-mariadb-query-plan-evidence.ps1")) {
    throw "Data-flow storage transition target evidence remediation note must mention write-mariadb-query-plan-evidence.ps1."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("raw SQL")) {
    throw "Data-flow storage transition target evidence remediation note must mention raw SQL exclusion."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("raw EXPLAIN")) {
    throw "Data-flow storage transition target evidence remediation note must mention raw EXPLAIN exclusion."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("credentials")) {
    throw "Data-flow storage transition target evidence remediation note must mention credential exclusion."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("object keys")) {
    throw "Data-flow storage transition target evidence remediation note must mention object-key exclusion."
}
$dataFlowStorageTransitionRunbookCheck = @($report.checks | Where-Object { $_.name -eq "Data-flow storage transition runbook target evidence" })
if ($dataFlowStorageTransitionRunbookCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Data-flow storage transition runbook target evidence check."
}
if (-not ([string] $report.inputs.dataFlowStorageTransitionRunbookEvidence).Contains("latest-data-flow-storage-transition-runbook-evidence.json")) {
    throw "Operations readiness report inputs must include data-flow storage transition runbook evidence path."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.command).Contains("write-data-flow-storage-transition-runbook-evidence.ps1")) {
    throw "Data-flow storage transition runbook target evidence remediation must point to write-data-flow-storage-transition-runbook-evidence.ps1."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.command).Contains("DataFlowStoragePlanJsonPath")) {
    throw "Data-flow storage transition runbook target evidence remediation must include data-flow storage plan JSON input."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.command).Contains("ConfirmBackfillRehearsed")) {
    throw "Data-flow storage transition runbook target evidence remediation must confirm backfill rehearsal."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.command).Contains("ConfirmReconciliationPassed")) {
    throw "Data-flow storage transition runbook target evidence remediation must confirm reconciliation."
}
if ($dataFlowStorageTransitionRunbookCheck[0].remediation.workflow -ne ".github/workflows/manual-data-flow-storage-transition-runbook-evidence.yml") {
    throw "Data-flow storage transition runbook target evidence remediation must point to the manual data-flow transition runbook workflow."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.workflowCommand).Contains("manual-data-flow-storage-transition-runbook-evidence.yml")) {
    throw "Data-flow storage transition runbook target evidence remediation workflow command must dispatch manual-data-flow-storage-transition-runbook-evidence.yml."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.workflowCommand).Contains("data_flow_storage_plan_json_base64")) {
    throw "Data-flow storage transition runbook target evidence workflow command must include data_flow_storage_plan_json_base64."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.workflowCommand).Contains("confirm_rollback_rehearsed=true")) {
    throw "Data-flow storage transition runbook target evidence workflow command must confirm rollback rehearsal."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].requiredEvidence).Contains("target backfill")) {
    throw "Data-flow storage transition runbook target evidence must require target backfill evidence."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].requiredEvidence).Contains("retention dry-run")) {
    throw "Data-flow storage transition runbook target evidence must require retention dry-run evidence."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.note).Contains("raw SQL")) {
    throw "Data-flow storage transition runbook remediation note must mention raw SQL exclusion."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.note).Contains("raw EXPLAIN")) {
    throw "Data-flow storage transition runbook remediation note must mention raw EXPLAIN exclusion."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.note).Contains("object keys")) {
    throw "Data-flow storage transition runbook remediation note must mention object-key exclusion."
}
$monitoringThresholdCheck = @($report.checks | Where-Object { $_.name -eq "Monitoring threshold target evidence" })
if ($monitoringThresholdCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Monitoring threshold target evidence check."
}
if (-not ([string] $report.inputs.monitoringThresholdEvidence).Contains("latest-monitoring-threshold-evidence.json")) {
    throw "Operations readiness report inputs must include monitoring threshold evidence path."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.command).Contains("write-monitoring-threshold-evidence.ps1")) {
    throw "Monitoring threshold target evidence remediation must point to write-monitoring-threshold-evidence.ps1."
}
if ($monitoringThresholdCheck[0].remediation.workflow -ne ".github/workflows/manual-monitoring-threshold-evidence.yml") {
    throw "Monitoring threshold target evidence remediation workflow must point to manual-monitoring-threshold-evidence.yml."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-monitoring-threshold-evidence.yml")) {
    throw "Monitoring threshold target evidence remediation workflow command must dispatch manual-monitoring-threshold-evidence.yml."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.workflowCommand).Contains("confirm_alertmanager_routes_reviewed=true")) {
    throw "Monitoring threshold target evidence workflow command must confirm Alertmanager route review."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.workflowCommand).Contains("confirm_target_baselines_reviewed=true")) {
    throw "Monitoring threshold target evidence workflow command must confirm target baseline review."
}
if (-not ([string] $monitoringThresholdCheck[0].requiredEvidence).Contains("target Prometheus/Grafana/Alertmanager/tenant baseline review")) {
    throw "Monitoring threshold target evidence must require target monitoring stack review."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.note).Contains("ReviewCompletedAt")) {
    throw "Monitoring threshold target evidence remediation note must mention review window ordering."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.note).Contains("typed counts")) {
    throw "Monitoring threshold target evidence remediation note must mention typed counts."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.note).Contains("Alertmanager receiver secrets")) {
    throw "Monitoring threshold target evidence remediation note must mention Alertmanager receiver secret exclusion."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.note).Contains("raw tenant object keys")) {
    throw "Monitoring threshold target evidence remediation note must mention raw tenant object key exclusion."
}
$secretRotationCheck = @($report.checks | Where-Object { $_.name -eq "Secret/certificate rotation target evidence" })
if ($secretRotationCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Secret/certificate rotation target evidence check."
}
if (-not ([string] $secretRotationCheck[0].remediation.command).Contains("write-secret-rotation-evidence.ps1")) {
    throw "Secret/certificate rotation target evidence remediation must point to write-secret-rotation-evidence.ps1."
}
if ($secretRotationCheck[0].remediation.workflow -ne ".github/workflows/manual-secret-rotation-evidence.yml") {
    throw "Secret/certificate rotation target evidence remediation workflow must point to manual-secret-rotation-evidence.yml."
}
if (-not ([string] $secretRotationCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-secret-rotation-evidence.yml")) {
    throw "Secret/certificate rotation target evidence remediation workflow command must dispatch manual-secret-rotation-evidence.yml."
}
if (-not ([string] $secretRotationCheck[0].requiredEvidence).Contains("target environment")) {
    throw "Secret/certificate rotation target evidence must require target environment evidence."
}
$commercialIntegrationCheck = @($report.checks | Where-Object { $_.name -eq "Commercial integration target evidence" })
if ($commercialIntegrationCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Commercial integration target evidence check."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.command).Contains("write-commercial-integration-evidence.ps1")) {
    throw "Commercial integration target evidence remediation must point to write-commercial-integration-evidence.ps1."
}
if ($commercialIntegrationCheck[0].remediation.workflow -ne ".github/workflows/manual-commercial-integration-evidence.yml") {
    throw "Commercial integration target evidence remediation workflow must point to manual-commercial-integration-evidence.yml."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-commercial-integration-evidence.yml")) {
    throw "Commercial integration target evidence remediation workflow command must dispatch manual-commercial-integration-evidence.yml."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.command).Contains("PaymentProviderAdapterReadinessJsonPath")) {
    throw "Commercial integration target evidence remediation must include payment-provider adapter readiness JSON input."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.workflowCommand).Contains("payment_provider_adapter_readiness_json_base64=<base64-json>")) {
    throw "Commercial integration target evidence workflow command must include payment-provider adapter readiness base64 input."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.workflowCommand).Contains("confirm_payment_provider_adapter_readiness_reviewed=true")) {
    throw "Commercial integration target evidence workflow command must confirm payment-provider adapter readiness review."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.note).Contains("GET /api/admin/billing/payment-provider-adapter-readiness")) {
    throw "Commercial integration target evidence remediation note must mention the payment-provider adapter readiness API."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.note).Contains("does not claim or require native card/bank/tax/ERP processor API support")) {
    throw "Commercial integration target evidence remediation note must preserve native provider scope boundary."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.note).Contains("decoded workflow input is deleted before artifact upload")) {
    throw "Commercial integration target evidence remediation note must mention decoded workflow input cleanup."
}
if (-not ([string] $commercialIntegrationCheck[0].requiredEvidence).Contains("target environment")) {
    throw "Commercial integration target evidence must require target environment evidence."
}
$commercialApprovalCheck = @($report.checks | Where-Object { $_.name -eq "Commercial approval target evidence" })
if ($commercialApprovalCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Commercial approval target evidence check."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.command).Contains("write-commercial-approval-evidence.ps1")) {
    throw "Commercial approval target evidence remediation must point to write-commercial-approval-evidence.ps1."
}
if ($commercialApprovalCheck[0].remediation.workflow -ne ".github/workflows/manual-commercial-approval-evidence.yml") {
    throw "Commercial approval target evidence remediation workflow must point to manual-commercial-approval-evidence.yml."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-commercial-approval-evidence.yml")) {
    throw "Commercial approval target evidence remediation workflow command must dispatch manual-commercial-approval-evidence.yml."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.command).Contains("PricingPolicyProposalJsonPath")) {
    throw "Commercial approval target evidence remediation must include pricing policy proposal JSON input."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.workflowCommand).Contains("pricing_policy_proposal_json_base64=<base64-json>")) {
    throw "Commercial approval target evidence workflow command must include pricing policy proposal base64 input."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.workflowCommand).Contains("confirm_pricing_policy_proposal_commercial_approval=true")) {
    throw "Commercial approval target evidence workflow command must confirm pricing policy proposal commercial approval."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.note).Contains("GET /api/admin/billing/pricing-policy-proposals?status=PRICE_LIST_APPROVED")) {
    throw "Commercial approval target evidence remediation note must mention the pricing policy proposal API."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.note).Contains("sanitized status/reference metadata")) {
    throw "Commercial approval target evidence remediation note must mention sanitized status/reference metadata."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.note).Contains("decoded workflow input is deleted before artifact upload")) {
    throw "Commercial approval target evidence remediation note must mention decoded workflow input cleanup."
}
if (-not ([string] $commercialApprovalCheck[0].requiredEvidence).Contains("final pricing") -or -not ([string] $commercialApprovalCheck[0].requiredEvidence).Contains("legal approval")) {
    throw "Commercial approval target evidence must require final pricing and legal approval evidence."
}
$chargebackCloseoutCheck = @($report.checks | Where-Object { $_.name -eq "Chargeback closeout target evidence" })
if ($chargebackCloseoutCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Chargeback closeout target evidence check."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.command).Contains("write-chargeback-closeout-evidence.ps1")) {
    throw "Chargeback closeout target evidence remediation must point to write-chargeback-closeout-evidence.ps1."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.command).Contains("ChargebackCloseoutSnapshotJsonPath")) {
    throw "Chargeback closeout target evidence remediation must include sanitized closeout snapshot JSON input."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.command).Contains("ConfirmReconciliationReviewed")) {
    throw "Chargeback closeout target evidence remediation must require reconciliation review confirmation."
}
if (-not [string]::IsNullOrWhiteSpace([string] $chargebackCloseoutCheck[0].remediation.workflow)) {
    throw "Chargeback closeout target evidence remediation should stay local until a manual workflow is explicitly added."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.note).Contains("sanitized closeout snapshot")) {
    throw "Chargeback closeout target evidence remediation note must mention sanitized closeout snapshot."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.note).Contains("raw customer/payment/provider data")) {
    throw "Chargeback closeout target evidence remediation note must mention raw customer/payment/provider data exclusion."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.note).Contains("does not claim native card/bank/tax/ERP provider implementation")) {
    throw "Chargeback closeout target evidence remediation note must preserve native provider scope boundary."
}
if (-not ([string] $chargebackCloseoutCheck[0].requiredEvidence).Contains("target billing period")) {
    throw "Chargeback closeout target evidence must require target billing period evidence."
}
$enterpriseAuthCheck = @($report.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($enterpriseAuthCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Enterprise auth target smoke evidence check."
}
if (-not ([string] $enterpriseAuthCheck[0].remediation.command).Contains("write-enterprise-auth-smoke-plan.ps1")) {
    throw "Enterprise auth target smoke evidence remediation must point to write-enterprise-auth-smoke-plan.ps1."
}
if ($enterpriseAuthCheck[0].remediation.workflow -ne ".github/workflows/enterprise-auth-smoke-ci.yml") {
    throw "Enterprise auth target smoke evidence remediation workflow must point to enterprise-auth-smoke-ci.yml."
}
if (-not ([string] $enterpriseAuthCheck[0].remediation.workflowCommand).Contains("gh workflow run enterprise-auth-smoke-ci.yml")) {
    throw "Enterprise auth target smoke evidence remediation workflow command must dispatch enterprise-auth-smoke-ci.yml."
}
if (-not ([string] $enterpriseAuthCheck[0].requiredEvidence).Contains("target IdP/directory") -or -not ([string] $enterpriseAuthCheck[0].requiredEvidence).Contains("scope-out")) {
    throw "Enterprise auth target smoke evidence must require target IdP/directory evidence or scope-out evidence."
}
if (-not ([string] $enterpriseAuthCheck[0].remediation.note).Contains("typed integer summary counts")) {
    throw "Enterprise auth target smoke remediation note must mention typed integer summary counts."
}
$operationsHandoffPackageCheck = @($report.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($operationsHandoffPackageCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Operations handoff package target evidence check."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("write-operations-handoff-package.ps1")) {
    throw "Operations handoff package target evidence remediation must point to write-operations-handoff-package.ps1."
}
if ($operationsHandoffPackageCheck[0].remediation.workflow -ne ".github/workflows/manual-operations-handoff-package.yml") {
    throw "Operations handoff package target evidence remediation workflow must point to manual-operations-handoff-package.yml."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-operations-handoff-package.yml")) {
    throw "Operations handoff package target evidence remediation workflow command must dispatch manual-operations-handoff-package.yml."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("-CommercialApprovalEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include CommercialApprovalEvidenceRef."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("CommercialIntegrationJsonPath")) {
    throw "Operations handoff package target evidence remediation must include commercial integration JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("CommercialApprovalJsonPath")) {
    throw "Operations handoff package target evidence remediation must include commercial approval JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("EnterpriseAuthJsonPath")) {
    throw "Operations handoff package target evidence remediation must include enterprise auth smoke JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("MonitoringThresholdJsonPath")) {
    throw "Operations handoff package target evidence remediation must include monitoring threshold JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmCommercialIntegrationSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm commercial integration snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmCommercialApprovalSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm commercial approval snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmEnterpriseAuthSmokeSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm enterprise auth smoke snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmMonitoringThresholdReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm monitoring threshold review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("OperationsReadinessJsonPath")) {
    throw "Operations handoff package target evidence remediation must include operations readiness JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("OperationsConvergenceJsonPath")) {
    throw "Operations handoff package target evidence remediation must include operations convergence JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStoragePlanEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage plan evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStorageTransitionRunbookEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage transition runbook evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStoragePlanJsonPath")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage plan JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStorageTransitionRunbookJsonPath")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage transition runbook JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("SecretRotationJsonPath")) {
    throw "Operations handoff package target evidence remediation must include secret rotation JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmSecretRotationSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm secret rotation snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("RequireOperationsSnapshotEvidence")) {
    throw "Operations handoff package target evidence remediation must require operations snapshot evidence."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("operations_readiness_json_base64=<base64-json>")) {
    throw "Operations handoff package target evidence workflow command must include operations readiness snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("operations_convergence_json_base64=<base64-json>")) {
    throw "Operations handoff package target evidence workflow command must include operations convergence snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_plan_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage plan evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_transition_runbook_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage transition runbook evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage plan snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage transition runbook snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("secret_rotation_json_base64=<base64-latest-secret-rotation-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include secret rotation snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("commercial_integration_json_base64=<base64-latest-commercial-integration-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include commercial integration snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("commercial_approval_json_base64=<base64-latest-commercial-approval-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include commercial approval snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("enterprise_auth_json_base64=<base64-latest-enterprise-auth-smoke-json>")) {
    throw "Operations handoff package target evidence workflow command must include enterprise auth smoke snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("monitoring_threshold_json_base64=<base64-latest-monitoring-threshold-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include monitoring threshold snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_operations_readiness_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm operations readiness snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_operations_convergence_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm operations convergence snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_data_flow_storage_plan_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm data-flow storage plan review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_data_flow_storage_transition_runbook_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm data-flow storage transition runbook review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_secret_rotation_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm secret rotation snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_commercial_integration_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm commercial integration snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_commercial_approval_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm commercial approval snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_enterprise_auth_smoke_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm enterprise auth smoke snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_monitoring_threshold_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm monitoring threshold review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("require_operations_snapshot_evidence=true")) {
    throw "Operations handoff package target evidence workflow command must require operations snapshot evidence."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-operations-readiness.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-operations-readiness-convergence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-data-flow-storage-plan.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-data-flow-storage-transition-runbook-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-secret-rotation-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-commercial-integration-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-commercial-approval-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-enterprise-auth-smoke.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-monitoring-threshold-evidence.json")) {
    throw "Operations handoff package target evidence remediation note must mention readiness/convergence/data-flow plan/data-flow runbook/secret rotation/commercial/enterprise auth/monitoring threshold snapshots."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("enterprise auth smoke")) {
    throw "Operations handoff package target evidence remediation note must mention enterprise auth smoke review confirmation."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("reduced to sanitized result/count/sync/query-plan/runbook/secret-rotation/commercial/enterprise auth scope-out/monitoring threshold summary fields")) {
    throw "Operations handoff package target evidence remediation note must describe sanitized snapshot reduction."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("object keys")) {
    throw "Operations handoff package target evidence remediation note must mention object-key exclusion."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("raw event messages")) {
    throw "Operations handoff package target evidence remediation note must mention raw event message exclusion."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("raw Alertmanager receiver secrets")) {
    throw "Operations handoff package target evidence remediation note must mention raw Alertmanager receiver secret exclusion."
}
if (-not ([string] $operationsHandoffPackageCheck[0].requiredEvidence).Contains("target environment")) {
    throw "Operations handoff package target evidence must require target environment evidence."
}
if (-not ([string] $operationsHandoffPackageCheck[0].requiredEvidence).Contains("required handoff review/production/snapshot confirmations")) {
    throw "Operations handoff package target evidence must require handoff review/production/snapshot confirmations."
}

Assert-Contains $markdown "# OSMU Operations Readiness" "Operations readiness markdown"
Assert-Contains $markdown "Production/B2B operations readiness" "Operations readiness markdown"
Assert-Contains $markdown "Storage expansion finalizer live evidence" "Operations readiness markdown"
Assert-Contains $markdown "Kubernetes DR finalizer live evidence" "Operations readiness markdown"
Assert-Contains $markdown "Security evidence finalizer report" "Operations readiness markdown"
Assert-Contains $markdown "Storage backend telemetry target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Monitoring threshold target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Secret/certificate rotation target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Commercial integration target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Commercial approval target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Chargeback closeout target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Enterprise auth target smoke evidence" "Operations readiness markdown"
Assert-Contains $markdown "Operations handoff package target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Required Next Evidence" "Operations readiness markdown"
Assert-Contains $markdown "Remediation command" "Operations readiness markdown"
Assert-Contains $markdown "Workflow" "Operations readiness markdown"
Assert-Contains $markdown "Workflow command" "Operations readiness markdown"

$scopeOutFixtureDirectory = Resolve-ProjectPath ".\.osmu-run\operations-readiness-enterprise-auth-scope-out-self-test"
New-Item -ItemType Directory -Force -Path $scopeOutFixtureDirectory | Out-Null
$scopeOutEvidencePath = Join-Path $scopeOutFixtureDirectory "latest-enterprise-auth-smoke.json"
$scopeOutJsonOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness.json"
$scopeOutMarkdownOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness.md"
@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "scope-out"
    scopeOut = @{
        confirmed = $true
        reference = "pilot-contract-enterprise-auth-deferred-20260620"
        reason = "Pilot phase uses local password login."
        accepted = $true
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $scopeOutEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnterpriseAuthSmokeEvidencePath $scopeOutEvidencePath `
    -JsonOutputPath $scopeOutJsonOutputPath `
    -MarkdownOutputPath $scopeOutMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for enterprise auth scope-out fixture with exit code $LASTEXITCODE."
}
$scopeOutReport = Get-Content -Raw -LiteralPath $scopeOutJsonOutputPath | ConvertFrom-Json
$scopeOutEnterpriseAuthCheck = @($scopeOutReport.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($scopeOutEnterpriseAuthCheck.Count -ne 1 -or -not $scopeOutEnterpriseAuthCheck[0].passed) {
    throw "Enterprise auth scope-out evidence must satisfy the operations readiness enterprise-auth check."
}
if (-not ([string] $scopeOutEnterpriseAuthCheck[0].detail).Contains("result=scope-out")) {
    throw "Enterprise auth scope-out readiness detail must preserve result=scope-out."
}

$stringAcceptedScopeOutEvidencePath = Join-Path $scopeOutFixtureDirectory "latest-enterprise-auth-smoke-string-accepted.json"
$stringAcceptedScopeOutJsonOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-string-accepted.json"
$stringAcceptedScopeOutMarkdownOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-string-accepted.md"
@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "scope-out"
    scopeOut = @{
        confirmed = $true
        reference = "pilot-contract-enterprise-auth-deferred-20260620"
        reason = "Pilot phase uses local password login."
        accepted = "false"
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $stringAcceptedScopeOutEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnterpriseAuthSmokeEvidencePath $stringAcceptedScopeOutEvidencePath `
    -JsonOutputPath $stringAcceptedScopeOutJsonOutputPath `
    -MarkdownOutputPath $stringAcceptedScopeOutMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for string-accepted enterprise auth scope-out fixture with exit code $LASTEXITCODE."
}
$stringAcceptedScopeOutReport = Get-Content -Raw -LiteralPath $stringAcceptedScopeOutJsonOutputPath | ConvertFrom-Json
$stringAcceptedEnterpriseAuthCheck = @($stringAcceptedScopeOutReport.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($stringAcceptedEnterpriseAuthCheck.Count -ne 1 -or $stringAcceptedEnterpriseAuthCheck[0].passed) {
    throw "Enterprise auth scope-out evidence with string accepted=false must not satisfy the operations readiness enterprise-auth check."
}
if (-not ([string] $stringAcceptedEnterpriseAuthCheck[0].detail).Contains("scopeOut.accepted=false(valid=False)")) {
    throw "Enterprise auth string accepted readiness detail must name invalid accepted value."
}

$stringCountPassedEnterpriseAuthEvidencePath = Join-Path $scopeOutFixtureDirectory "latest-enterprise-auth-smoke-passed-string-count.json"
$stringCountPassedEnterpriseAuthJsonOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-passed-string-count.json"
$stringCountPassedEnterpriseAuthMarkdownOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-passed-string-count.md"
@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "passed"
    summary = @{
        passCount = 4
        failCount = "0"
        blockedCount = 0
        plannedCount = 0
        skippedCount = 0
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $stringCountPassedEnterpriseAuthEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnterpriseAuthSmokeEvidencePath $stringCountPassedEnterpriseAuthEvidencePath `
    -JsonOutputPath $stringCountPassedEnterpriseAuthJsonOutputPath `
    -MarkdownOutputPath $stringCountPassedEnterpriseAuthMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for string-count passed enterprise auth fixture with exit code $LASTEXITCODE."
}
$stringCountPassedEnterpriseAuthReport = Get-Content -Raw -LiteralPath $stringCountPassedEnterpriseAuthJsonOutputPath | ConvertFrom-Json
$stringCountPassedEnterpriseAuthCheck = @($stringCountPassedEnterpriseAuthReport.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($stringCountPassedEnterpriseAuthCheck.Count -ne 1 -or $stringCountPassedEnterpriseAuthCheck[0].passed) {
    throw "Enterprise auth passed evidence with string count must not satisfy the operations readiness enterprise-auth check."
}
if (-not ([string] $stringCountPassedEnterpriseAuthCheck[0].detail).Contains("failCount=0(valid=False)")) {
    throw "Enterprise auth string count readiness detail must name invalid count value."
}

$handoffFixtureDirectory = Resolve-ProjectPath ".\.osmu-run\operations-readiness-handoff-package-self-test"
New-Item -ItemType Directory -Force -Path $handoffFixtureDirectory | Out-Null
$validHandoffEvidencePath = Join-Path $handoffFixtureDirectory "valid-operations-handoff-package.json"
$validHandoffJsonOutputPath = Join-Path $handoffFixtureDirectory "valid-operations-readiness.json"
$validHandoffMarkdownOutputPath = Join-Path $handoffFixtureDirectory "valid-operations-readiness.md"
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $validHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $validHandoffEvidencePath `
    -JsonOutputPath $validHandoffJsonOutputPath `
    -MarkdownOutputPath $validHandoffMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for valid operations handoff package fixture with exit code $LASTEXITCODE."
}
$validHandoffReport = Get-Content -Raw -LiteralPath $validHandoffJsonOutputPath | ConvertFrom-Json
$validHandoffCheck = @($validHandoffReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($validHandoffCheck.Count -ne 1 -or -not $validHandoffCheck[0].passed) {
    throw "Operations readiness must accept a passed handoff package only when required confirmations are present."
}
if (-not ([string] $validHandoffCheck[0].detail).Contains("requiredConfirmations=17") -or -not ([string] $validHandoffCheck[0].detail).Contains("sourceReportResult=ready")) {
    throw "Operations handoff package readiness detail must record required confirmation and strict snapshot validation."
}

$staleHandoffEvidencePath = Join-Path $handoffFixtureDirectory "stale-operations-handoff-package.json"
$staleHandoffJsonOutputPath = Join-Path $handoffFixtureDirectory "stale-operations-readiness.json"
$staleHandoffMarkdownOutputPath = Join-Path $handoffFixtureDirectory "stale-operations-readiness.md"
$staleConfirmations = New-PassedOperationsHandoffPackageConfirmations
$staleConfirmations["commercialApprovalSnapshotReviewed"] = $false
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = $staleConfirmations
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $staleHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $staleHandoffEvidencePath `
    -JsonOutputPath $staleHandoffJsonOutputPath `
    -MarkdownOutputPath $staleHandoffMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for stale operations handoff package fixture with exit code $LASTEXITCODE."
}
$staleHandoffReport = Get-Content -Raw -LiteralPath $staleHandoffJsonOutputPath | ConvertFrom-Json
$staleHandoffCheck = @($staleHandoffReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($staleHandoffCheck.Count -ne 1 -or $staleHandoffCheck[0].passed) {
    throw "Operations readiness must not accept a passed handoff package when required confirmations are missing."
}
if (-not ([string] $staleHandoffCheck[0].detail).Contains("commercialApprovalSnapshotReviewed")) {
    throw "Operations readiness stale handoff package detail must name the missing confirmation."
}

$badConvergenceHandoffEvidencePath = Join-Path $handoffFixtureDirectory "bad-convergence-operations-handoff-package.json"
$badConvergenceJsonOutputPath = Join-Path $handoffFixtureDirectory "bad-convergence-operations-readiness.json"
$badConvergenceMarkdownOutputPath = Join-Path $handoffFixtureDirectory "bad-convergence-operations-readiness.md"
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots -ConvergenceSourceReportResult "action-required")
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $badConvergenceHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $badConvergenceHandoffEvidencePath `
    -JsonOutputPath $badConvergenceJsonOutputPath `
    -MarkdownOutputPath $badConvergenceMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for bad convergence handoff package fixture with exit code $LASTEXITCODE."
}
$badConvergenceReport = Get-Content -Raw -LiteralPath $badConvergenceJsonOutputPath | ConvertFrom-Json
$badConvergenceCheck = @($badConvergenceReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($badConvergenceCheck.Count -ne 1 -or $badConvergenceCheck[0].passed) {
    throw "Operations readiness must reject a handoff package whose convergence sync source is not ready."
}
if (-not ([string] $badConvergenceCheck[0].detail).Contains("sourceReportResult=action-required")) {
    throw "Operations readiness bad convergence handoff detail must name the non-ready source report result."
}

$stringBoolHandoffEvidencePath = Join-Path $handoffFixtureDirectory "string-bool-operations-handoff-package.json"
$stringBoolJsonOutputPath = Join-Path $handoffFixtureDirectory "string-bool-operations-readiness.json"
$stringBoolMarkdownOutputPath = Join-Path $handoffFixtureDirectory "string-bool-operations-readiness.md"
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots -KubernetesReportSyncReady "false")
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $stringBoolHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $stringBoolHandoffEvidencePath `
    -JsonOutputPath $stringBoolJsonOutputPath `
    -MarkdownOutputPath $stringBoolMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for string-bool handoff package fixture with exit code $LASTEXITCODE."
}
$stringBoolReport = Get-Content -Raw -LiteralPath $stringBoolJsonOutputPath | ConvertFrom-Json
$stringBoolCheck = @($stringBoolReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($stringBoolCheck.Count -ne 1 -or $stringBoolCheck[0].passed) {
    throw "Operations readiness must reject a handoff package whose convergence sync boolean is a string."
}
if (-not ([string] $stringBoolCheck[0].detail).Contains("kubernetesReportSyncReady=false")) {
    throw "Operations readiness string-bool handoff detail must name the invalid sync ready value."
}

$missingCountHandoffEvidencePath = Join-Path $handoffFixtureDirectory "missing-count-operations-handoff-package.json"
$missingCountJsonOutputPath = Join-Path $handoffFixtureDirectory "missing-count-operations-readiness.json"
$missingCountMarkdownOutputPath = Join-Path $handoffFixtureDirectory "missing-count-operations-readiness.md"
$missingCountSnapshots = New-PassedOperationsHandoffPackageSnapshots
$missingCountSnapshots["convergence"].Remove("finalizerGapCount")
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    operationsSnapshots = $missingCountSnapshots
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $missingCountHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $missingCountHandoffEvidencePath `
    -JsonOutputPath $missingCountJsonOutputPath `
    -MarkdownOutputPath $missingCountMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for missing-count handoff package fixture with exit code $LASTEXITCODE."
}
$missingCountReport = Get-Content -Raw -LiteralPath $missingCountJsonOutputPath | ConvertFrom-Json
$missingCountCheck = @($missingCountReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($missingCountCheck.Count -ne 1 -or $missingCountCheck[0].passed) {
    throw "Operations readiness must reject a handoff package whose convergence finalizer gap count is missing."
}
if (-not ([string] $missingCountCheck[0].detail).Contains("finalizerGapCount=<missing>")) {
    throw "Operations readiness missing-count handoff detail must name the missing finalizer gap count."
}

Write-Host "Operations readiness artifact verified."
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"
