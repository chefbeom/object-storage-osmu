param(
    [string] $OutputDirectory = ".\.osmu-run\operations-readiness-artifact-import-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Write-JsonEvidence([string] $Path, [hashtable] $Data) {
    $resolvedPath = Resolve-ProjectPath $Path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedPath) | Out-Null
    $Data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
}

function New-PassedOperationsHandoffPackageSnapshots(
    [string] $ConvergenceSourceReportResult = "ready",
    [int] $FinalizerFailedCount = 0
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
            finalizerGapCount = 0
            kubernetesReportSyncReady = $true
            kubernetesReportSyncResult = "applied"
            kubernetesReportSyncFailedCount = 0
            kubernetesReportSyncSourceReportResult = $ConvergenceSourceReportResult
        }
    }
}

function Write-TextEvidence([string] $Path, [string] $Content) {
    $resolvedPath = Resolve-ProjectPath $Path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedPath) | Out-Null
    $Content | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$sourceRoot = Join-Path $resolvedOutputDirectory "source"
$promotedRoot = Join-Path $resolvedOutputDirectory "promoted"
$invalidRoot = Join-Path $resolvedOutputDirectory "invalid-source"
$invalidDataFlowRoot = Join-Path $resolvedOutputDirectory "invalid-data-flow-source"
$unsafeDataFlowRoot = Join-Path $resolvedOutputDirectory "unsafe-data-flow-source"
$unsafeDataFlowRunbookRoot = Join-Path $resolvedOutputDirectory "unsafe-data-flow-runbook-source"
$unsafeMonitoringThresholdRoot = Join-Path $resolvedOutputDirectory "unsafe-monitoring-threshold-source"
$staleOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "stale-operations-handoff-package-source"
$badConvergenceOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "bad-convergence-operations-handoff-package-source"

$storageSource = Join-Path $sourceRoot "storage-expansion"
$haDrSource = Join-Path $sourceRoot "ha-dr-readiness"
$kubernetesDrSource = Join-Path $sourceRoot "kubernetes-dr"
$iamSource = Join-Path $sourceRoot "iam-rbac"
$securitySource = Join-Path $sourceRoot "security-evidence"
$storageBackendTelemetrySource = Join-Path $sourceRoot "storage-backend-telemetry"
$monitoringThresholdSource = Join-Path $sourceRoot "monitoring-threshold"
$secretRotationSource = Join-Path $sourceRoot "secret-rotation"
$commercialIntegrationSource = Join-Path $sourceRoot "commercial-integration"
$commercialApprovalSource = Join-Path $sourceRoot "commercial-approval"
$enterpriseAuthSource = Join-Path $sourceRoot "enterprise-auth"
$operationsHandoffPackageSource = Join-Path $sourceRoot "operations-handoff-package"
$kubernetesOperationsReportSyncSource = Join-Path $sourceRoot "kubernetes-operations-report-sync"
$directDataFlowStoragePlanSource = Join-Path $sourceRoot "data-flow-storage-plan"
$dataFlowStorageTransitionRunbookSource = Join-Path $sourceRoot "data-flow-storage-transition-runbook"

Write-JsonEvidence (Join-Path $storageSource "latest-storage-expansion-finalize.json") @{
    formatVersion = "osmu.storage-expansion-finalize.v1"
    result = "passed"
}
Write-TextEvidence (Join-Path $storageSource "latest-storage-expansion-finalize.md") "# Storage expansion"
Write-JsonEvidence (Join-Path $haDrSource "latest-kubernetes-ha-dr-readiness.json") @{
    formatVersion = "osmu.kubernetes-ha-dr-readiness.v1"
    result = "passed"
}
Write-JsonEvidence (Join-Path $kubernetesDrSource "nested\latest-kubernetes-dr-finalize.json") @{
    formatVersion = "osmu.kubernetes-dr-finalize.v1"
    result = "ready"
}
Write-TextEvidence (Join-Path $kubernetesDrSource "latest-kubernetes-dr-finalize.md") "# Kubernetes DR"
Write-JsonEvidence (Join-Path $iamSource "latest-iam-rbac-finalize.json") @{
    formatVersion = "osmu.iam-rbac-finalize.v1"
    result = "passed"
}
Write-TextEvidence (Join-Path $iamSource "latest-iam-rbac-finalize.md") "# IAM/RBAC"
Write-JsonEvidence (Join-Path $securitySource "latest-security-evidence-finalize.json") @{
    formatVersion = "osmu.security-evidence-finalize.v1"
    result = "passed"
}
Write-JsonEvidence (Join-Path $securitySource "latest-image-signing-evidence.json") @{
    formatVersion = "osmu.image-signing-evidence.v1"
    result = "passed"
}
Write-JsonEvidence (Join-Path $securitySource "latest-container-security-evidence.json") @{
    formatVersion = "osmu.container-security-evidence.v1"
    result = "passed"
}
Write-JsonEvidence (Join-Path $storageBackendTelemetrySource "latest-storage-backend-telemetry.json") @{
    formatVersion = "osmu.storage-backend-telemetry.v1"
    result = "passed"
    source = @{
        rawAdminInfoStored = $false
    }
    summary = @{
        capacityKnown = $true
        totalBytes = 1024
        usedBytes = 256
        freeBytes = 768
    }
}
Write-TextEvidence (Join-Path $storageBackendTelemetrySource "latest-storage-backend-telemetry.md") "# Storage backend telemetry"
Write-JsonEvidence (Join-Path $monitoringThresholdSource "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    result = "passed"
    thresholdTargetSummary = @{
        requiredAlertCount = 11
        mappedAlertCount = 11
        missingAlerts = @()
        routeCount = 3
        routes = @("osmu-backend", "osmu-data-flow", "osmu-backup")
        grafanaPanelCount = 11
        tuningEvidenceCount = 11
    }
    confirmations = @{
        prometheusRulesLoaded = $true
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
}
Write-TextEvidence (Join-Path $monitoringThresholdSource "latest-monitoring-threshold-evidence.md") "# Monitoring threshold"
Write-JsonEvidence (Join-Path $secretRotationSource "latest-secret-rotation-evidence.json") @{
    formatVersion = "osmu.secret-rotation-evidence.v1"
    result = "passed"
}
Write-TextEvidence (Join-Path $secretRotationSource "latest-secret-rotation-evidence.md") "# Secret rotation"
Write-JsonEvidence (Join-Path $commercialIntegrationSource "latest-commercial-integration-evidence.json") @{
    formatVersion = "osmu.commercial-integration-evidence.v1"
    result = "passed"
}
Write-TextEvidence (Join-Path $commercialIntegrationSource "latest-commercial-integration-evidence.md") "# Commercial integration"
Write-JsonEvidence (Join-Path $commercialApprovalSource "latest-commercial-approval-evidence.json") @{
    formatVersion = "osmu.commercial-approval-evidence.v1"
    result = "passed"
}
Write-TextEvidence (Join-Path $commercialApprovalSource "latest-commercial-approval-evidence.md") "# Commercial approval"
Write-JsonEvidence (Join-Path $enterpriseAuthSource "latest-enterprise-auth-smoke.json") @{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "scope-out"
    scopeOut = @{
        confirmed = $true
        reference = "pilot-contract-enterprise-auth-deferred-20260620"
        reason = "Pilot phase uses local password login."
        accepted = $true
    }
}
Write-TextEvidence (Join-Path $enterpriseAuthSource "latest-enterprise-auth-smoke.md") "# Enterprise auth smoke"
Write-JsonEvidence (Join-Path $operationsHandoffPackageSource "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
    confirmations = [ordered]@{
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
Write-TextEvidence (Join-Path $operationsHandoffPackageSource "latest-operations-handoff-package.md") "# Operations handoff package"
Write-JsonEvidence (Join-Path $dataFlowStorageTransitionRunbookSource "latest-data-flow-storage-transition-runbook-evidence.json") @{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    result = "passed"
    dataFlowStoragePlanSnapshot = @{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        targetP95QueryLatencyMs = 500
    }
    summary = @{
        failureCount = 0
        checkCount = 24
    }
    confirmations = @{
        backfillRehearsed = $true
        rollbackRehearsed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
}
Write-TextEvidence (Join-Path $dataFlowStorageTransitionRunbookSource "latest-data-flow-storage-transition-runbook-evidence.md") "# Data-flow storage transition runbook"
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = 0
}
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-kubernetes-operations-report-sync-plan.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "planned"
}
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-kubernetes-operations-report-sync-server-dry-run.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "server-dry-run-passed"
}
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    candidateStore = "MARIADB_PARTITION"
    pendingCount = 1
    queryPlanEvidence = @{
        provided = $false
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
        validFormatVersion = $false
        result = ""
        mode = ""
        checkCount = 0
        passedCount = 0
        failedCount = 0
        failedChecks = @()
        detail = "No MariaDB query plan evidence JSON supplied."
    }
}

$importScript = Resolve-ProjectPath ".\scripts\import-operations-readiness-artifacts.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
    -StorageExpansionArtifactPath $storageSource `
    -HaDrReadinessArtifactPath $haDrSource `
    -KubernetesDrArtifactPath $kubernetesDrSource `
    -IamRbacArtifactPath $iamSource `
    -SecurityEvidenceArtifactPath $securitySource `
    -StorageBackendTelemetryArtifactPath $storageBackendTelemetrySource `
    -MonitoringThresholdArtifactPath $monitoringThresholdSource `
    -SecretRotationArtifactPath $secretRotationSource `
    -CommercialIntegrationArtifactPath $commercialIntegrationSource `
    -CommercialApprovalArtifactPath $commercialApprovalSource `
    -EnterpriseAuthArtifactPath $enterpriseAuthSource `
    -OperationsHandoffPackageArtifactPath $operationsHandoffPackageSource `
    -DataFlowStorageTransitionRunbookArtifactPath $dataFlowStorageTransitionRunbookSource `
    -KubernetesOperationsReportSyncArtifactPath $kubernetesOperationsReportSyncSource `
    -OutputDirectory $promotedRoot `
    -JsonOutputPath (Join-Path $resolvedOutputDirectory "latest-operations-readiness-artifact-import.json") `
    -MarkdownOutputPath (Join-Path $resolvedOutputDirectory "latest-operations-readiness-artifact-import.md") | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "import-operations-readiness-artifacts.ps1 failed with exit code $LASTEXITCODE."
}

$reportPath = Join-Path $resolvedOutputDirectory "latest-operations-readiness-artifact-import.json"
$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
Assert-True ($report.formatVersion -eq "osmu.operations-readiness-artifact-import.v1") "Unexpected import report formatVersion."
Assert-True ($report.result -eq "passed") "Expected import report result=passed."
Assert-True ($report.status -eq "artifact-imported") "Expected import report status=artifact-imported."
Assert-True ($report.importedCount -ge 19) "Expected imported evidence files."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-storage-expansion-finalize.json")) "Promoted storage expansion evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-ha-dr-readiness.json")) "Promoted HA/DR readiness evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-dr-finalize.json")) "Promoted Kubernetes DR evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-iam-rbac-finalize.json")) "Promoted IAM/RBAC evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-security-evidence-finalize.json")) "Promoted security finalizer evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-image-signing-evidence.json")) "Promoted image signing evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-container-security-evidence.json")) "Promoted container security evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-storage-backend-telemetry.json")) "Promoted storage backend telemetry evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-storage-backend-telemetry.md")) "Promoted storage backend telemetry markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-monitoring-threshold-evidence.json")) "Promoted monitoring threshold evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-monitoring-threshold-evidence.md")) "Promoted monitoring threshold markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-secret-rotation-evidence.json")) "Promoted secret rotation evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-secret-rotation-evidence.md")) "Promoted secret rotation markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-commercial-integration-evidence.json")) "Promoted commercial integration evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-commercial-integration-evidence.md")) "Promoted commercial integration markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-commercial-approval-evidence.json")) "Promoted commercial approval evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-commercial-approval-evidence.md")) "Promoted commercial approval markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-enterprise-auth-smoke.json")) "Promoted enterprise auth smoke evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-operations-handoff-package.json")) "Promoted operations handoff package evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-operations-handoff-package.md")) "Promoted operations handoff package markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-transition-runbook-evidence.json")) "Promoted data-flow storage transition runbook evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-transition-runbook-evidence.md")) "Promoted data-flow storage transition runbook markdown missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-operations-report-sync.json")) "Promoted Kubernetes operations report sync evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-plan.json")) "Promoted data-flow storage plan evidence missing."
$promotedCommercialApproval = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-commercial-approval-evidence.json") | ConvertFrom-Json
$promotedStorageBackendTelemetry = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-storage-backend-telemetry.json") | ConvertFrom-Json
$promotedMonitoringThreshold = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-monitoring-threshold-evidence.json") | ConvertFrom-Json
$promotedSecretRotation = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-secret-rotation-evidence.json") | ConvertFrom-Json
$promotedCommercialIntegration = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-commercial-integration-evidence.json") | ConvertFrom-Json
Assert-True ($promotedStorageBackendTelemetry.result -eq "passed") "Promoted storage backend telemetry evidence should preserve result=passed."
Assert-True ($promotedStorageBackendTelemetry.source.rawAdminInfoStored -eq $false) "Promoted storage backend telemetry evidence should preserve rawAdminInfoStored=false."
Assert-True ($promotedMonitoringThreshold.result -eq "passed") "Promoted monitoring threshold evidence should preserve result=passed."
Assert-True ($promotedMonitoringThreshold.confirmations.noSecretValues) "Promoted monitoring threshold evidence should preserve no-secret confirmation."
Assert-True ($promotedSecretRotation.result -eq "passed") "Promoted secret rotation evidence should preserve result=passed."
Assert-True ($promotedCommercialIntegration.result -eq "passed") "Promoted commercial integration evidence should preserve result=passed."
Assert-True ($promotedCommercialApproval.result -eq "passed") "Promoted commercial approval evidence should preserve result=passed."
$promotedEnterpriseAuth = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-enterprise-auth-smoke.json") | ConvertFrom-Json
Assert-True ($promotedEnterpriseAuth.result -eq "scope-out") "Promoted enterprise auth scope-out evidence should be preserved."
$enterpriseAuthImportEntry = @($report.entries | Where-Object { $_.group -eq "enterprise-auth" -and $_.fileName -eq "latest-enterprise-auth-smoke.json" })
Assert-True ($enterpriseAuthImportEntry.Count -eq 1) "Enterprise auth import entry missing."
Assert-True (([string] $enterpriseAuthImportEntry[0].detail).Contains("expected=passed|scope-out")) "Enterprise auth import entry should document passed or scope-out acceptance."
$promotedOperationsHandoffPackage = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-operations-handoff-package.json") | ConvertFrom-Json
Assert-True ($promotedOperationsHandoffPackage.result -eq "passed") "Promoted operations handoff package evidence should preserve result=passed."
Assert-True ($promotedOperationsHandoffPackage.confirmations.noSecretValues) "Promoted operations handoff package should preserve no-secret confirmation."
Assert-True ($promotedOperationsHandoffPackage.confirmations.secretRotationSnapshotReviewed) "Promoted operations handoff package should preserve secret rotation snapshot review confirmation."
Assert-True ($promotedOperationsHandoffPackage.confirmations.commercialApprovalSnapshotReviewed) "Promoted operations handoff package should preserve commercial approval snapshot review confirmation."
Assert-True ($promotedOperationsHandoffPackage.confirmations.enterpriseAuthSmokeSnapshotReviewed) "Promoted operations handoff package should preserve enterprise auth smoke snapshot review confirmation."
$operationsHandoffPackageEntry = @($report.entries | Where-Object { $_.group -eq "operations-handoff-package" -and $_.fileName -eq "latest-operations-handoff-package.json" })
Assert-True ($operationsHandoffPackageEntry.Count -eq 1) "Operations handoff package import entry missing."
Assert-True (([string] $operationsHandoffPackageEntry[0].detail).Contains("requiredConfirmations=17") -and ([string] $operationsHandoffPackageEntry[0].detail).Contains("sourceReportResult=ready")) "Operations handoff package import entry should include required confirmation and strict snapshot validation detail."
$promotedDataFlowRunbook = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-transition-runbook-evidence.json") | ConvertFrom-Json
Assert-True ($promotedDataFlowRunbook.result -eq "passed") "Promoted data-flow storage transition runbook evidence should preserve result=passed."
Assert-True ($promotedDataFlowRunbook.dataFlowStoragePlanSnapshot.result -eq "passed") "Promoted data-flow storage transition runbook evidence should preserve passed storage plan snapshot."
$dataFlowRunbookEntry = @($report.entries | Where-Object { $_.group -eq "data-flow-storage-transition-runbook" -and $_.fileName -eq "latest-data-flow-storage-transition-runbook-evidence.json" })
Assert-True ($dataFlowRunbookEntry.Count -eq 1) "Data-flow storage transition runbook import entry missing."
Assert-True (([string] $dataFlowRunbookEntry[0].detail).Contains("storagePlanResult=passed")) "Data-flow storage transition runbook import entry should include storage plan validation detail."
$monitoringThresholdEntry = @($report.entries | Where-Object { $_.group -eq "monitoring-threshold" -and $_.fileName -eq "latest-monitoring-threshold-evidence.json" })
Assert-True ($monitoringThresholdEntry.Count -eq 1) "Monitoring threshold import entry missing."
Assert-True (([string] $monitoringThresholdEntry[0].detail).Contains("requiredAlerts=11")) "Monitoring threshold import entry should include threshold mapping validation detail."
$promotedDataFlowStoragePlan = Get-Content -Raw -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-plan.json") | ConvertFrom-Json
Assert-True ($promotedDataFlowStoragePlan.formatVersion -eq "osmu.data-flow-storage-plan.v1") "Promoted data-flow storage plan evidence should preserve formatVersion."
Assert-True ($promotedDataFlowStoragePlan.candidateStore -eq "MARIADB_PARTITION") "Promoted data-flow storage plan evidence should preserve candidateStore."
Assert-True ($promotedDataFlowStoragePlan.queryPlanEvidence.expectedFormatVersion -eq "osmu.mariadb-query-plan-evidence.v1") "Promoted data-flow storage plan evidence should preserve query plan expected format."

Write-JsonEvidence (Join-Path $invalidRoot "latest-kubernetes-ha-dr-readiness.json") @{
    formatVersion = "osmu.kubernetes-ha-dr-readiness.v1"
    result = "failed"
}
$invalidOutput = Join-Path $resolvedOutputDirectory "invalid-promoted"
$invalidJson = Join-Path $resolvedOutputDirectory "invalid-import.json"
$invalidMarkdown = Join-Path $resolvedOutputDirectory "invalid-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -HaDrReadinessArtifactPath $invalidRoot `
        -OutputDirectory $invalidOutput `
        -JsonOutputPath $invalidJson `
        -MarkdownOutputPath $invalidMarkdown 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Invalid HA/DR evidence import should fail."
Assert-True (Test-Path -LiteralPath $invalidJson) "Invalid import report should still be written."
$invalidReport = Get-Content -Raw -LiteralPath $invalidJson | ConvertFrom-Json
Assert-True ($invalidReport.result -eq "failed") "Invalid import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $invalidOutput "latest-kubernetes-ha-dr-readiness.json"))) "Invalid evidence must not be promoted."

Write-JsonEvidence (Join-Path $invalidDataFlowRoot "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = 0
}
Write-JsonEvidence (Join-Path $invalidDataFlowRoot "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    candidateStore = "MARIADB_PARTITION"
    pendingCount = 1
}
$invalidDataFlowOutput = Join-Path $resolvedOutputDirectory "invalid-data-flow-promoted"
$invalidDataFlowJson = Join-Path $resolvedOutputDirectory "invalid-data-flow-import.json"
$invalidDataFlowMarkdown = Join-Path $resolvedOutputDirectory "invalid-data-flow-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidDataFlowOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -KubernetesOperationsReportSyncArtifactPath $invalidDataFlowRoot `
        -OutputDirectory $invalidDataFlowOutput `
        -JsonOutputPath $invalidDataFlowJson `
        -MarkdownOutputPath $invalidDataFlowMarkdown 2>&1
    $invalidDataFlowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidDataFlowExitCode -ne 0) "Data-flow storage plan without required query plan summary should fail import."
Assert-True (Test-Path -LiteralPath $invalidDataFlowJson) "Invalid data-flow import report should still be written."
$invalidDataFlowReport = Get-Content -Raw -LiteralPath $invalidDataFlowJson | ConvertFrom-Json
Assert-True ($invalidDataFlowReport.result -eq "failed") "Invalid data-flow import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $invalidDataFlowOutput "latest-data-flow-storage-plan.json"))) "Invalid data-flow storage plan must not be promoted."
Assert-True (($invalidDataFlowReport.entries | ConvertTo-Json -Depth 8).Contains("requires queryPlanEvidence summary")) "Invalid data-flow report should describe missing query plan summary."

Write-JsonEvidence (Join-Path $unsafeDataFlowRoot "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = 0
}
Write-JsonEvidence (Join-Path $unsafeDataFlowRoot "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    candidateStore = "MARIADB_PARTITION"
    pendingCount = 1
    queryPlanEvidence = @{
        provided = $true
        expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
        result = "passed"
        failedCount = 0
        rawSql = "SELECT id FROM data_flow_events"
    }
}
$unsafeDataFlowOutput = Join-Path $resolvedOutputDirectory "unsafe-data-flow-promoted"
$unsafeDataFlowJson = Join-Path $resolvedOutputDirectory "unsafe-data-flow-import.json"
$unsafeDataFlowMarkdown = Join-Path $resolvedOutputDirectory "unsafe-data-flow-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeDataFlowOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -KubernetesOperationsReportSyncArtifactPath $unsafeDataFlowRoot `
        -OutputDirectory $unsafeDataFlowOutput `
        -JsonOutputPath $unsafeDataFlowJson `
        -MarkdownOutputPath $unsafeDataFlowMarkdown 2>&1
    $unsafeDataFlowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeDataFlowExitCode -ne 0) "Data-flow storage plan with unsafe query plan summary should fail import."
Assert-True (Test-Path -LiteralPath $unsafeDataFlowJson) "Unsafe data-flow import report should still be written."
$unsafeDataFlowReport = Get-Content -Raw -LiteralPath $unsafeDataFlowJson | ConvertFrom-Json
Assert-True ($unsafeDataFlowReport.result -eq "failed") "Unsafe data-flow import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $unsafeDataFlowOutput "latest-data-flow-storage-plan.json"))) "Unsafe data-flow storage plan must not be promoted."
Assert-True (($unsafeDataFlowReport.entries | ConvertTo-Json -Depth 8).Contains("raw SQL")) "Unsafe data-flow report should describe sanitized summary failure."

Write-JsonEvidence (Join-Path $unsafeDataFlowRunbookRoot "latest-data-flow-storage-transition-runbook-evidence.json") @{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    result = "passed"
    dataFlowStoragePlanSnapshot = @{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
    }
    rawSql = "SELECT id FROM data_flow_events"
}
$unsafeDataFlowRunbookOutput = Join-Path $resolvedOutputDirectory "unsafe-data-flow-runbook-promoted"
$unsafeDataFlowRunbookJson = Join-Path $resolvedOutputDirectory "unsafe-data-flow-runbook-import.json"
$unsafeDataFlowRunbookMarkdown = Join-Path $resolvedOutputDirectory "unsafe-data-flow-runbook-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeDataFlowRunbookOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -DataFlowStorageTransitionRunbookArtifactPath $unsafeDataFlowRunbookRoot `
        -OutputDirectory $unsafeDataFlowRunbookOutput `
        -JsonOutputPath $unsafeDataFlowRunbookJson `
        -MarkdownOutputPath $unsafeDataFlowRunbookMarkdown 2>&1
    $unsafeDataFlowRunbookExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeDataFlowRunbookExitCode -ne 0) "Data-flow storage transition runbook with unsafe raw SQL should fail import."
Assert-True (Test-Path -LiteralPath $unsafeDataFlowRunbookJson) "Unsafe data-flow runbook import report should still be written."
$unsafeDataFlowRunbookReport = Get-Content -Raw -LiteralPath $unsafeDataFlowRunbookJson | ConvertFrom-Json
Assert-True ($unsafeDataFlowRunbookReport.result -eq "failed") "Unsafe data-flow runbook import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $unsafeDataFlowRunbookOutput "latest-data-flow-storage-transition-runbook-evidence.json"))) "Unsafe data-flow storage transition runbook must not be promoted."
Assert-True (($unsafeDataFlowRunbookReport.entries | ConvertTo-Json -Depth 8).Contains("raw SQL")) "Unsafe data-flow runbook report should describe sanitized summary failure."

Write-JsonEvidence (Join-Path $unsafeMonitoringThresholdRoot "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    result = "passed"
    webhookSecret = "password=super-secret"
    thresholdTargetSummary = @{
        requiredAlertCount = 11
        mappedAlertCount = 11
        missingAlerts = @()
    }
    confirmations = @{
        prometheusRulesLoaded = $true
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
}
$unsafeMonitoringThresholdOutput = Join-Path $resolvedOutputDirectory "unsafe-monitoring-threshold-promoted"
$unsafeMonitoringThresholdJson = Join-Path $resolvedOutputDirectory "unsafe-monitoring-threshold-import.json"
$unsafeMonitoringThresholdMarkdown = Join-Path $resolvedOutputDirectory "unsafe-monitoring-threshold-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeMonitoringThresholdOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MonitoringThresholdArtifactPath $unsafeMonitoringThresholdRoot `
        -OutputDirectory $unsafeMonitoringThresholdOutput `
        -JsonOutputPath $unsafeMonitoringThresholdJson `
        -MarkdownOutputPath $unsafeMonitoringThresholdMarkdown 2>&1
    $unsafeMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeMonitoringThresholdExitCode -ne 0) "Monitoring threshold evidence with credential-shaped content should fail import."
Assert-True (Test-Path -LiteralPath $unsafeMonitoringThresholdJson) "Unsafe monitoring threshold import report should still be written."
$unsafeMonitoringThresholdReport = Get-Content -Raw -LiteralPath $unsafeMonitoringThresholdJson | ConvertFrom-Json
Assert-True ($unsafeMonitoringThresholdReport.result -eq "failed") "Unsafe monitoring threshold import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $unsafeMonitoringThresholdOutput "latest-monitoring-threshold-evidence.json"))) "Unsafe monitoring threshold evidence must not be promoted."
Assert-True (($unsafeMonitoringThresholdReport.entries | ConvertTo-Json -Depth 8).Contains("credential-shaped content")) "Unsafe monitoring threshold report should describe credential-shaped content."

Write-JsonEvidence (Join-Path $staleOperationsHandoffPackageRoot "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
    confirmations = [ordered]@{
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
        commercialApprovalSnapshotReviewed = $false
        enterpriseAuthSmokeSnapshotReviewed = $true
        monitoringThresholdReviewed = $true
        requireProductionEvidence = $true
        requireOperationsSnapshotEvidence = $true
    }
}
$staleOperationsHandoffPackageOutput = Join-Path $resolvedOutputDirectory "stale-operations-handoff-package-promoted"
$staleOperationsHandoffPackageJson = Join-Path $resolvedOutputDirectory "stale-operations-handoff-package-import.json"
$staleOperationsHandoffPackageMarkdown = Join-Path $resolvedOutputDirectory "stale-operations-handoff-package-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $staleOperationsHandoffPackageOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -OperationsHandoffPackageArtifactPath $staleOperationsHandoffPackageRoot `
        -OutputDirectory $staleOperationsHandoffPackageOutput `
        -JsonOutputPath $staleOperationsHandoffPackageJson `
        -MarkdownOutputPath $staleOperationsHandoffPackageMarkdown 2>&1
    $staleOperationsHandoffPackageExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($staleOperationsHandoffPackageExitCode -ne 0) "Operations handoff package without required review confirmations should fail import."
Assert-True (Test-Path -LiteralPath $staleOperationsHandoffPackageJson) "Stale operations handoff package import report should still be written."
$staleOperationsHandoffPackageReport = Get-Content -Raw -LiteralPath $staleOperationsHandoffPackageJson | ConvertFrom-Json
Assert-True ($staleOperationsHandoffPackageReport.result -eq "failed") "Stale operations handoff package import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $staleOperationsHandoffPackageOutput "latest-operations-handoff-package.json"))) "Stale operations handoff package must not be promoted."
Assert-True (($staleOperationsHandoffPackageReport.entries | ConvertTo-Json -Depth 8).Contains("commercialApprovalSnapshotReviewed")) "Stale operations handoff package report should describe missing required review confirmation."

Write-JsonEvidence (Join-Path $badConvergenceOperationsHandoffPackageRoot "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots -ConvergenceSourceReportResult "action-required")
    confirmations = [ordered]@{
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
$badConvergenceOperationsHandoffPackageOutput = Join-Path $resolvedOutputDirectory "bad-convergence-operations-handoff-package-promoted"
$badConvergenceOperationsHandoffPackageJson = Join-Path $resolvedOutputDirectory "bad-convergence-operations-handoff-package-import.json"
$badConvergenceOperationsHandoffPackageMarkdown = Join-Path $resolvedOutputDirectory "bad-convergence-operations-handoff-package-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $badConvergenceOperationsHandoffPackageOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -OperationsHandoffPackageArtifactPath $badConvergenceOperationsHandoffPackageRoot `
        -OutputDirectory $badConvergenceOperationsHandoffPackageOutput `
        -JsonOutputPath $badConvergenceOperationsHandoffPackageJson `
        -MarkdownOutputPath $badConvergenceOperationsHandoffPackageMarkdown 2>&1
    $badConvergenceOperationsHandoffPackageExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($badConvergenceOperationsHandoffPackageExitCode -ne 0) "Operations handoff package with non-ready convergence source should fail import."
Assert-True (Test-Path -LiteralPath $badConvergenceOperationsHandoffPackageJson) "Bad convergence handoff package import report should still be written."
$badConvergenceOperationsHandoffPackageReport = Get-Content -Raw -LiteralPath $badConvergenceOperationsHandoffPackageJson | ConvertFrom-Json
Assert-True ($badConvergenceOperationsHandoffPackageReport.result -eq "failed") "Bad convergence handoff package import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $badConvergenceOperationsHandoffPackageOutput "latest-operations-handoff-package.json"))) "Bad convergence handoff package must not be promoted."
Assert-True (($badConvergenceOperationsHandoffPackageReport.entries | ConvertTo-Json -Depth 8).Contains("sourceReportResult=action-required")) "Bad convergence handoff package report should describe non-ready source report result."

Write-JsonEvidence (Join-Path $directDataFlowStoragePlanSource "latest-data-flow-storage-plan.json") @{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "passed"
    candidateStore = "EXTERNAL_TIME_SERIES"
    pendingCount = 0
    queryPlanEvidence = $null
}
$directDataFlowOutput = Join-Path $resolvedOutputDirectory "direct-data-flow-promoted"
$directDataFlowJson = Join-Path $resolvedOutputDirectory "direct-data-flow-import.json"
$directDataFlowMarkdown = Join-Path $resolvedOutputDirectory "direct-data-flow-import.md"
& powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
    -DataFlowStoragePlanArtifactPath $directDataFlowStoragePlanSource `
    -OutputDirectory $directDataFlowOutput `
    -JsonOutputPath $directDataFlowJson `
    -MarkdownOutputPath $directDataFlowMarkdown | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Direct data-flow storage plan import failed with exit code $LASTEXITCODE."
}
$directDataFlowReport = Get-Content -Raw -LiteralPath $directDataFlowJson | ConvertFrom-Json
Assert-True ($directDataFlowReport.result -eq "passed") "Direct data-flow import report should pass."
Assert-True ($directDataFlowReport.selectedGroupCount -eq 1) "Direct data-flow import should select one group."
Assert-True (Test-Path -LiteralPath (Join-Path $directDataFlowOutput "latest-data-flow-storage-plan.json")) "Direct data-flow storage plan must be promoted."
$directDataFlowEntry = @($directDataFlowReport.entries | Where-Object { $_.group -eq "data-flow-storage-plan" -and $_.fileName -eq "latest-data-flow-storage-plan.json" })
Assert-True ($directDataFlowEntry.Count -eq 1) "Direct data-flow import entry missing."
Assert-True (([string] $directDataFlowEntry[0].detail).Contains("candidateStore=EXTERNAL_TIME_SERIES")) "Direct data-flow import entry should include candidate store validation detail."

Write-Host "Operations readiness artifact import verified."
Write-Host "Report: $reportPath"
