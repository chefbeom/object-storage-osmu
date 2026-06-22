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
$stringBoolMonitoringThresholdRoot = Join-Path $resolvedOutputDirectory "string-bool-monitoring-threshold-source"
$stringCountMonitoringThresholdRoot = Join-Path $resolvedOutputDirectory "string-count-monitoring-threshold-source"
$missingCountMonitoringThresholdRoot = Join-Path $resolvedOutputDirectory "missing-count-monitoring-threshold-source"
$weakSecretRotationRoot = Join-Path $resolvedOutputDirectory "weak-secret-rotation-source"
$weakCommercialIntegrationRoot = Join-Path $resolvedOutputDirectory "weak-commercial-integration-source"
$weakCommercialApprovalRoot = Join-Path $resolvedOutputDirectory "weak-commercial-approval-source"
$invalidEnterpriseAuthRoot = Join-Path $resolvedOutputDirectory "invalid-enterprise-auth-source"
$stringCountEnterpriseAuthRoot = Join-Path $resolvedOutputDirectory "string-count-enterprise-auth-source"
$staleOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "stale-operations-handoff-package-source"
$badConvergenceOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "bad-convergence-operations-handoff-package-source"
$stringBoolOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "string-bool-operations-handoff-package-source"
$missingCountOperationsHandoffPackageRoot = Join-Path $resolvedOutputDirectory "missing-count-operations-handoff-package-source"

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
    summary = @{
        failureCount = 0
        checkCount = 24
    }
}
Write-TextEvidence (Join-Path $monitoringThresholdSource "latest-monitoring-threshold-evidence.md") "# Monitoring threshold"
Write-JsonEvidence (Join-Path $secretRotationSource "latest-secret-rotation-evidence.json") @{
    formatVersion = "osmu.secret-rotation-evidence.v1"
    result = "passed"
    confirmations = @{
        noSecretValues = $true
        workloadRestart = $true
        smokePassed = $true
        artifactLeakReview = $true
        requireAllCoreSecrets = $false
    }
    rotations = @(
        @{ id = "admin-password"; core = $true; rotated = $true },
        @{ id = "jwt-signing-secret"; core = $true; rotated = $true },
        @{ id = "database-credentials"; core = $true; rotated = $true },
        @{ id = "minio-root-credentials"; core = $true; rotated = $true },
        @{ id = "tls-certificate"; core = $true; rotated = $true }
    )
    summary = @{
        rotatedCount = 5
        coreRotatedCount = 5
        coreRequiredCount = 5
        failureCount = 0
        plannedCount = 0
    }
}
Write-TextEvidence (Join-Path $secretRotationSource "latest-secret-rotation-evidence.md") "# Secret rotation"
Write-JsonEvidence (Join-Path $commercialIntegrationSource "latest-commercial-integration-evidence.json") @{
    formatVersion = "osmu.commercial-integration-evidence.v1"
    result = "passed"
    confirmations = @{
        noSecretValues = $true
        noRawProviderResponses = $true
        payloadSizeCaps = $true
        privateNetworkBlocking = $true
        hmacSignatureHeaders = $true
        paymentProviderAdapterReadinessReviewed = $true
        adapterRetryWorkerRun = $true
        requireAllImplementedAdapters = $true
        requirePaymentProviderAdapterReadinessReview = $true
    }
    paymentProviderAdapterReadiness = @{
        required = $true
        reviewed = $true
        evidenceRef = "payment-adapter-readiness-run-20260620"
        snapshot = @{
            provided = $true
            parsed = $true
            validMode = $true
            status = "WEBHOOK_PROFILE_READY"
            nativeApiSupported = $false
            nativeApiReady = $false
            profileCount = 5
            webhookReadyProfileCount = 5
            nativeApiReadyProfileCount = 0
            countsValid = $true
            booleansValid = $true
            profiles = @(
                @{ providerProfile = "GENERIC"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "CARD"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "BANK"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "TAX"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
                @{ providerProfile = "ERP"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false }
            )
        }
    }
    summary = @{
        integrationCount = 8
        verifiedCount = 8
        requiredCount = 8
        requiredVerifiedCount = 8
        paymentProviderAdapterReadinessReviewed = $true
        paymentProviderAdapterReadinessStatus = "WEBHOOK_PROFILE_READY"
        paymentProviderAdapterWebhookReadyProfileCount = 5
        paymentProviderAdapterNativeReadyProfileCount = 0
        failureCount = 0
        plannedCount = 0
    }
}
Write-TextEvidence (Join-Path $commercialIntegrationSource "latest-commercial-integration-evidence.md") "# Commercial integration"
Write-JsonEvidence (Join-Path $commercialApprovalSource "latest-commercial-approval-evidence.json") @{
    formatVersion = "osmu.commercial-approval-evidence.v1"
    result = "passed"
    confirmations = @{
        pricingApproved = $true
        termsApproved = $true
        supportSlaApproved = $true
        licenseApproved = $true
        legalApproved = $true
        pricingPolicyProposalCommercialApproval = $true
        requirePricingPolicyProposalApprovalSnapshot = $true
        noSecretValues = $true
    }
    pricingPolicyProposalApproval = @{
        required = $true
        reviewed = $true
        evidenceRef = "pricing-policy-proposal-commercial-approval-20260620"
        snapshot = @{
            provided = $true
            parsed = $true
            proposalCount = 2
            approvedPriceListCount = 1
            commercialApprovedCount = 1
            approvalFlagsValid = $true
            proposals = @(
                @{
                    id = 101
                    status = "PRICE_LIST_APPROVED"
                    approvedPriceList = $true
                    commercialApprovalReference = "commercial-approval-board-20260620"
                    commercialApprovedAt = "2026-06-20T05:10:00Z"
                }
            )
        }
    }
    summary = @{
        passedCount = 13
        failureCount = 0
        checkCount = 13
        pricingPolicyProposalCommercialApproved = $true
        pricingPolicyProposalCommercialApprovedCount = 1
        pricingPolicyProposalApprovedPriceListCount = 1
        pricingPolicyProposalApprovalFlagsValid = $true
    }
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
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-data-flow-storage-transition-runbook-evidence.json") @{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    result = "passed"
    dataFlowStoragePlanSnapshot = @{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        targetP95QueryLatencyMs = 500
    }
    summary = @{
        failureCount = 0
        checkCount = 8
    }
    confirmations = @{
        backfillRehearsed = $true
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
    topFailedChecks = @()
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
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-data-flow-storage-transition-runbook-evidence.json")) "Promoted data-flow storage transition runbook evidence missing."
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
$secretRotationEntry = @($report.entries | Where-Object { $_.group -eq "secret-rotation" -and $_.fileName -eq "latest-secret-rotation-evidence.json" })
Assert-True ($secretRotationEntry.Count -eq 1) "Secret rotation import entry missing."
Assert-True (([string] $secretRotationEntry[0].detail).Contains("coreRotated=5/5")) "Secret rotation import entry should include core rotation validation detail."
$commercialIntegrationEntry = @($report.entries | Where-Object { $_.group -eq "commercial-integration" -and $_.fileName -eq "latest-commercial-integration-evidence.json" })
Assert-True ($commercialIntegrationEntry.Count -eq 1) "Commercial integration import entry missing."
Assert-True (([string] $commercialIntegrationEntry[0].detail).Contains("requiredVerified=8/8")) "Commercial integration import entry should include required adapter validation detail."
$commercialApprovalEntry = @($report.entries | Where-Object { $_.group -eq "commercial-approval" -and $_.fileName -eq "latest-commercial-approval-evidence.json" })
Assert-True ($commercialApprovalEntry.Count -eq 1) "Commercial approval import entry missing."
Assert-True (([string] $commercialApprovalEntry[0].detail).Contains("commercialApproved=1")) "Commercial approval import entry should include commercial approval validation detail."
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
$kubernetesSyncRunbookEntry = @($report.entries | Where-Object { $_.group -eq "kubernetes-operations-report-sync" -and $_.fileName -eq "latest-data-flow-storage-transition-runbook-evidence.json" })
Assert-True ($kubernetesSyncRunbookEntry.Count -eq 1) "Kubernetes sync data-flow storage transition runbook import entry missing."
Assert-True (([string] $kubernetesSyncRunbookEntry[0].detail).Contains("storagePlanResult=passed")) "Kubernetes sync runbook import entry should include storage plan validation detail."
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

Write-JsonEvidence (Join-Path $stringBoolMonitoringThresholdRoot "latest-monitoring-threshold-evidence.json") @{
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
    summary = @{
        failureCount = 0
        checkCount = 24
    }
    confirmations = @{
        prometheusRulesLoaded = "false"
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
}
$stringBoolMonitoringThresholdOutput = Join-Path $resolvedOutputDirectory "string-bool-monitoring-threshold-promoted"
$stringBoolMonitoringThresholdJson = Join-Path $resolvedOutputDirectory "string-bool-monitoring-threshold-import.json"
$stringBoolMonitoringThresholdMarkdown = Join-Path $resolvedOutputDirectory "string-bool-monitoring-threshold-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolMonitoringThresholdOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MonitoringThresholdArtifactPath $stringBoolMonitoringThresholdRoot `
        -OutputDirectory $stringBoolMonitoringThresholdOutput `
        -JsonOutputPath $stringBoolMonitoringThresholdJson `
        -MarkdownOutputPath $stringBoolMonitoringThresholdMarkdown 2>&1
    $stringBoolMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolMonitoringThresholdExitCode -ne 0) "Monitoring threshold evidence with string confirmation should fail import."
Assert-True (Test-Path -LiteralPath $stringBoolMonitoringThresholdJson) "String-bool monitoring threshold import report should still be written."
$stringBoolMonitoringThresholdReport = Get-Content -Raw -LiteralPath $stringBoolMonitoringThresholdJson | ConvertFrom-Json
Assert-True ($stringBoolMonitoringThresholdReport.result -eq "failed") "String-bool monitoring threshold import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringBoolMonitoringThresholdOutput "latest-monitoring-threshold-evidence.json"))) "String-bool monitoring threshold evidence must not be promoted."
Assert-True (($stringBoolMonitoringThresholdReport.entries | ConvertTo-Json -Depth 8).Contains("confirmation prometheusRulesLoaded=false expected boolean true")) "String-bool monitoring threshold report should describe invalid confirmation."

Write-JsonEvidence (Join-Path $stringCountMonitoringThresholdRoot "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    result = "passed"
    thresholdTargetSummary = @{
        requiredAlertCount = "11"
        mappedAlertCount = 11
        missingAlerts = @()
        routeCount = 3
        routes = @("osmu-backend", "osmu-data-flow", "osmu-backup")
        grafanaPanelCount = 11
        tuningEvidenceCount = 11
    }
    summary = @{
        failureCount = 0
        checkCount = 24
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
$stringCountMonitoringThresholdOutput = Join-Path $resolvedOutputDirectory "string-count-monitoring-threshold-promoted"
$stringCountMonitoringThresholdJson = Join-Path $resolvedOutputDirectory "string-count-monitoring-threshold-import.json"
$stringCountMonitoringThresholdMarkdown = Join-Path $resolvedOutputDirectory "string-count-monitoring-threshold-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringCountMonitoringThresholdOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MonitoringThresholdArtifactPath $stringCountMonitoringThresholdRoot `
        -OutputDirectory $stringCountMonitoringThresholdOutput `
        -JsonOutputPath $stringCountMonitoringThresholdJson `
        -MarkdownOutputPath $stringCountMonitoringThresholdMarkdown 2>&1
    $stringCountMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringCountMonitoringThresholdExitCode -ne 0) "Monitoring threshold evidence with string count should fail import."
Assert-True (Test-Path -LiteralPath $stringCountMonitoringThresholdJson) "String-count monitoring threshold import report should still be written."
$stringCountMonitoringThresholdReport = Get-Content -Raw -LiteralPath $stringCountMonitoringThresholdJson | ConvertFrom-Json
Assert-True ($stringCountMonitoringThresholdReport.result -eq "failed") "String-count monitoring threshold import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringCountMonitoringThresholdOutput "latest-monitoring-threshold-evidence.json"))) "String-count monitoring threshold evidence must not be promoted."
Assert-True (($stringCountMonitoringThresholdReport.entries | ConvertTo-Json -Depth 8).Contains("requiredAlertCount=11(valid=False) expected integer")) "String-count monitoring threshold report should describe invalid typed count."

Write-JsonEvidence (Join-Path $missingCountMonitoringThresholdRoot "latest-monitoring-threshold-evidence.json") @{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    result = "passed"
    thresholdTargetSummary = @{
        requiredAlertCount = 11
        mappedAlertCount = 11
        missingAlerts = @()
        routeCount = 3
        routes = @("osmu-backend", "osmu-data-flow", "osmu-backup")
        grafanaPanelCount = 11
    }
    summary = @{
        failureCount = 0
        checkCount = 24
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
$missingCountMonitoringThresholdOutput = Join-Path $resolvedOutputDirectory "missing-count-monitoring-threshold-promoted"
$missingCountMonitoringThresholdJson = Join-Path $resolvedOutputDirectory "missing-count-monitoring-threshold-import.json"
$missingCountMonitoringThresholdMarkdown = Join-Path $resolvedOutputDirectory "missing-count-monitoring-threshold-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingCountMonitoringThresholdOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -MonitoringThresholdArtifactPath $missingCountMonitoringThresholdRoot `
        -OutputDirectory $missingCountMonitoringThresholdOutput `
        -JsonOutputPath $missingCountMonitoringThresholdJson `
        -MarkdownOutputPath $missingCountMonitoringThresholdMarkdown 2>&1
    $missingCountMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingCountMonitoringThresholdExitCode -ne 0) "Monitoring threshold evidence with missing count should fail import."
Assert-True (Test-Path -LiteralPath $missingCountMonitoringThresholdJson) "Missing-count monitoring threshold import report should still be written."
$missingCountMonitoringThresholdReport = Get-Content -Raw -LiteralPath $missingCountMonitoringThresholdJson | ConvertFrom-Json
Assert-True ($missingCountMonitoringThresholdReport.result -eq "failed") "Missing-count monitoring threshold import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $missingCountMonitoringThresholdOutput "latest-monitoring-threshold-evidence.json"))) "Missing-count monitoring threshold evidence must not be promoted."
$missingCountMonitoringThresholdEntry = @($missingCountMonitoringThresholdReport.entries | Where-Object { $_.group -eq "monitoring-threshold" -and $_.fileName -eq "latest-monitoring-threshold-evidence.json" })
Assert-True ($missingCountMonitoringThresholdEntry.Count -eq 1) "Missing-count monitoring threshold failed entry missing."
Assert-True (([string] $missingCountMonitoringThresholdEntry[0].detail).Contains("tuningEvidenceCount=<missing>(valid=False) expected integer")) "Missing-count monitoring threshold report should describe missing typed count."

Write-JsonEvidence (Join-Path $weakSecretRotationRoot "latest-secret-rotation-evidence.json") @{
    formatVersion = "osmu.secret-rotation-evidence.v1"
    result = "passed"
}
$weakSecretRotationOutput = Join-Path $resolvedOutputDirectory "weak-secret-rotation-promoted"
$weakSecretRotationJson = Join-Path $resolvedOutputDirectory "weak-secret-rotation-import.json"
$weakSecretRotationMarkdown = Join-Path $resolvedOutputDirectory "weak-secret-rotation-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakSecretRotationOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -SecretRotationArtifactPath $weakSecretRotationRoot `
        -OutputDirectory $weakSecretRotationOutput `
        -JsonOutputPath $weakSecretRotationJson `
        -MarkdownOutputPath $weakSecretRotationMarkdown 2>&1
    $weakSecretRotationExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakSecretRotationExitCode -ne 0) "Secret rotation evidence without typed summary and confirmations should fail import."
Assert-True (Test-Path -LiteralPath $weakSecretRotationJson) "Weak secret rotation import report should still be written."
$weakSecretRotationReport = Get-Content -Raw -LiteralPath $weakSecretRotationJson | ConvertFrom-Json
Assert-True ($weakSecretRotationReport.result -eq "failed") "Weak secret rotation import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakSecretRotationOutput "latest-secret-rotation-evidence.json"))) "Weak secret rotation evidence must not be promoted."
$weakSecretRotationEntry = @($weakSecretRotationReport.entries | Where-Object { $_.group -eq "secret-rotation" -and $_.fileName -eq "latest-secret-rotation-evidence.json" })
Assert-True ($weakSecretRotationEntry.Count -eq 1) "Weak secret rotation failed entry missing."
Assert-True (([string] $weakSecretRotationEntry[0].detail).Contains("rotatedCount=<missing>(valid=False) expected integer")) "Weak secret rotation report should describe missing typed summary count."

Write-JsonEvidence (Join-Path $weakCommercialIntegrationRoot "latest-commercial-integration-evidence.json") @{
    formatVersion = "osmu.commercial-integration-evidence.v1"
    result = "passed"
}
$weakCommercialIntegrationOutput = Join-Path $resolvedOutputDirectory "weak-commercial-integration-promoted"
$weakCommercialIntegrationJson = Join-Path $resolvedOutputDirectory "weak-commercial-integration-import.json"
$weakCommercialIntegrationMarkdown = Join-Path $resolvedOutputDirectory "weak-commercial-integration-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakCommercialIntegrationOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -CommercialIntegrationArtifactPath $weakCommercialIntegrationRoot `
        -OutputDirectory $weakCommercialIntegrationOutput `
        -JsonOutputPath $weakCommercialIntegrationJson `
        -MarkdownOutputPath $weakCommercialIntegrationMarkdown 2>&1
    $weakCommercialIntegrationExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakCommercialIntegrationExitCode -ne 0) "Commercial integration evidence without typed adapter summary and confirmations should fail import."
Assert-True (Test-Path -LiteralPath $weakCommercialIntegrationJson) "Weak commercial integration import report should still be written."
$weakCommercialIntegrationReport = Get-Content -Raw -LiteralPath $weakCommercialIntegrationJson | ConvertFrom-Json
Assert-True ($weakCommercialIntegrationReport.result -eq "failed") "Weak commercial integration import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakCommercialIntegrationOutput "latest-commercial-integration-evidence.json"))) "Weak commercial integration evidence must not be promoted."
$weakCommercialIntegrationEntry = @($weakCommercialIntegrationReport.entries | Where-Object { $_.group -eq "commercial-integration" -and $_.fileName -eq "latest-commercial-integration-evidence.json" })
Assert-True ($weakCommercialIntegrationEntry.Count -eq 1) "Weak commercial integration failed entry missing."
Assert-True (([string] $weakCommercialIntegrationEntry[0].detail).Contains("integrationCount=<missing>(valid=False) expected integer")) "Weak commercial integration report should describe missing typed summary count."

Write-JsonEvidence (Join-Path $weakCommercialApprovalRoot "latest-commercial-approval-evidence.json") @{
    formatVersion = "osmu.commercial-approval-evidence.v1"
    result = "passed"
}
$weakCommercialApprovalOutput = Join-Path $resolvedOutputDirectory "weak-commercial-approval-promoted"
$weakCommercialApprovalJson = Join-Path $resolvedOutputDirectory "weak-commercial-approval-import.json"
$weakCommercialApprovalMarkdown = Join-Path $resolvedOutputDirectory "weak-commercial-approval-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $weakCommercialApprovalOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -CommercialApprovalArtifactPath $weakCommercialApprovalRoot `
        -OutputDirectory $weakCommercialApprovalOutput `
        -JsonOutputPath $weakCommercialApprovalJson `
        -MarkdownOutputPath $weakCommercialApprovalMarkdown 2>&1
    $weakCommercialApprovalExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($weakCommercialApprovalExitCode -ne 0) "Commercial approval evidence without typed approval summary and confirmations should fail import."
Assert-True (Test-Path -LiteralPath $weakCommercialApprovalJson) "Weak commercial approval import report should still be written."
$weakCommercialApprovalReport = Get-Content -Raw -LiteralPath $weakCommercialApprovalJson | ConvertFrom-Json
Assert-True ($weakCommercialApprovalReport.result -eq "failed") "Weak commercial approval import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $weakCommercialApprovalOutput "latest-commercial-approval-evidence.json"))) "Weak commercial approval evidence must not be promoted."
$weakCommercialApprovalEntry = @($weakCommercialApprovalReport.entries | Where-Object { $_.group -eq "commercial-approval" -and $_.fileName -eq "latest-commercial-approval-evidence.json" })
Assert-True ($weakCommercialApprovalEntry.Count -eq 1) "Weak commercial approval failed entry missing."
Assert-True (([string] $weakCommercialApprovalEntry[0].detail).Contains("confirmation pricingApproved=<missing> expected boolean true")) "Weak commercial approval report should describe missing approval confirmations."

Write-JsonEvidence (Join-Path $invalidEnterpriseAuthRoot "latest-enterprise-auth-smoke.json") @{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "scope-out"
    scopeOut = @{
        confirmed = $true
        reference = "pilot-contract-enterprise-auth-deferred-20260620"
        reason = "Pilot phase uses local password login."
        accepted = "false"
    }
}
$invalidEnterpriseAuthOutput = Join-Path $resolvedOutputDirectory "invalid-enterprise-auth-promoted"
$invalidEnterpriseAuthJson = Join-Path $resolvedOutputDirectory "invalid-enterprise-auth-import.json"
$invalidEnterpriseAuthMarkdown = Join-Path $resolvedOutputDirectory "invalid-enterprise-auth-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidEnterpriseAuthOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -EnterpriseAuthArtifactPath $invalidEnterpriseAuthRoot `
        -OutputDirectory $invalidEnterpriseAuthOutput `
        -JsonOutputPath $invalidEnterpriseAuthJson `
        -MarkdownOutputPath $invalidEnterpriseAuthMarkdown 2>&1
    $invalidEnterpriseAuthExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidEnterpriseAuthExitCode -ne 0) "Enterprise auth scope-out evidence with string accepted=false should fail import."
Assert-True (Test-Path -LiteralPath $invalidEnterpriseAuthJson) "Invalid enterprise auth import report should still be written."
$invalidEnterpriseAuthReport = Get-Content -Raw -LiteralPath $invalidEnterpriseAuthJson | ConvertFrom-Json
Assert-True ($invalidEnterpriseAuthReport.result -eq "failed") "Invalid enterprise auth import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $invalidEnterpriseAuthOutput "latest-enterprise-auth-smoke.json"))) "Invalid enterprise auth evidence must not be promoted."
$invalidEnterpriseAuthEntry = @($invalidEnterpriseAuthReport.entries | Where-Object { $_.group -eq "enterprise-auth" -and $_.fileName -eq "latest-enterprise-auth-smoke.json" })
Assert-True ($invalidEnterpriseAuthEntry.Count -eq 1) "Invalid enterprise auth import entry missing."
Assert-True (([string] $invalidEnterpriseAuthEntry[0].detail).Contains("accepted=false(valid=False)")) "Invalid enterprise auth report should describe invalid accepted value."

Write-JsonEvidence (Join-Path $stringCountEnterpriseAuthRoot "latest-enterprise-auth-smoke.json") @{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "passed"
    summary = @{
        passCount = 4
        failCount = "0"
        blockedCount = 0
        plannedCount = 0
        skippedCount = 0
    }
}
$stringCountEnterpriseAuthOutput = Join-Path $resolvedOutputDirectory "string-count-enterprise-auth-promoted"
$stringCountEnterpriseAuthJson = Join-Path $resolvedOutputDirectory "string-count-enterprise-auth-import.json"
$stringCountEnterpriseAuthMarkdown = Join-Path $resolvedOutputDirectory "string-count-enterprise-auth-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringCountEnterpriseAuthOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -EnterpriseAuthArtifactPath $stringCountEnterpriseAuthRoot `
        -OutputDirectory $stringCountEnterpriseAuthOutput `
        -JsonOutputPath $stringCountEnterpriseAuthJson `
        -MarkdownOutputPath $stringCountEnterpriseAuthMarkdown 2>&1
    $stringCountEnterpriseAuthExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringCountEnterpriseAuthExitCode -ne 0) "Enterprise auth passed evidence with string count should fail import."
Assert-True (Test-Path -LiteralPath $stringCountEnterpriseAuthJson) "String-count enterprise auth import report should still be written."
$stringCountEnterpriseAuthReport = Get-Content -Raw -LiteralPath $stringCountEnterpriseAuthJson | ConvertFrom-Json
Assert-True ($stringCountEnterpriseAuthReport.result -eq "failed") "String-count enterprise auth import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringCountEnterpriseAuthOutput "latest-enterprise-auth-smoke.json"))) "String-count enterprise auth evidence must not be promoted."
$stringCountEnterpriseAuthEntry = @($stringCountEnterpriseAuthReport.entries | Where-Object { $_.group -eq "enterprise-auth" -and $_.fileName -eq "latest-enterprise-auth-smoke.json" })
Assert-True ($stringCountEnterpriseAuthEntry.Count -eq 1) "String-count enterprise auth import entry missing."
Assert-True (([string] $stringCountEnterpriseAuthEntry[0].detail).Contains("failCount=0(valid=False)")) "String-count enterprise auth report should describe invalid typed count."

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

Write-JsonEvidence (Join-Path $stringBoolOperationsHandoffPackageRoot "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots -KubernetesReportSyncReady "false")
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
$stringBoolOperationsHandoffPackageOutput = Join-Path $resolvedOutputDirectory "string-bool-operations-handoff-package-promoted"
$stringBoolOperationsHandoffPackageJson = Join-Path $resolvedOutputDirectory "string-bool-operations-handoff-package-import.json"
$stringBoolOperationsHandoffPackageMarkdown = Join-Path $resolvedOutputDirectory "string-bool-operations-handoff-package-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolOperationsHandoffPackageOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -OperationsHandoffPackageArtifactPath $stringBoolOperationsHandoffPackageRoot `
        -OutputDirectory $stringBoolOperationsHandoffPackageOutput `
        -JsonOutputPath $stringBoolOperationsHandoffPackageJson `
        -MarkdownOutputPath $stringBoolOperationsHandoffPackageMarkdown 2>&1
    $stringBoolOperationsHandoffPackageExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolOperationsHandoffPackageExitCode -ne 0) "Operations handoff package with string sync boolean should fail import."
Assert-True (Test-Path -LiteralPath $stringBoolOperationsHandoffPackageJson) "String-bool handoff package import report should still be written."
$stringBoolOperationsHandoffPackageReport = Get-Content -Raw -LiteralPath $stringBoolOperationsHandoffPackageJson | ConvertFrom-Json
Assert-True ($stringBoolOperationsHandoffPackageReport.result -eq "failed") "String-bool handoff package import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stringBoolOperationsHandoffPackageOutput "latest-operations-handoff-package.json"))) "String-bool handoff package must not be promoted."
Assert-True (($stringBoolOperationsHandoffPackageReport.entries | ConvertTo-Json -Depth 8).Contains("kubernetesReportSyncReady=false")) "String-bool handoff package report should describe invalid sync ready value."

$missingCountSnapshots = New-PassedOperationsHandoffPackageSnapshots
$missingCountSnapshots["convergence"].Remove("finalizerGapCount")
Write-JsonEvidence (Join-Path $missingCountOperationsHandoffPackageRoot "latest-operations-handoff-package.json") @{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    operationsSnapshots = $missingCountSnapshots
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
$missingCountOperationsHandoffPackageOutput = Join-Path $resolvedOutputDirectory "missing-count-operations-handoff-package-promoted"
$missingCountOperationsHandoffPackageJson = Join-Path $resolvedOutputDirectory "missing-count-operations-handoff-package-import.json"
$missingCountOperationsHandoffPackageMarkdown = Join-Path $resolvedOutputDirectory "missing-count-operations-handoff-package-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingCountOperationsHandoffPackageOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -OperationsHandoffPackageArtifactPath $missingCountOperationsHandoffPackageRoot `
        -OutputDirectory $missingCountOperationsHandoffPackageOutput `
        -JsonOutputPath $missingCountOperationsHandoffPackageJson `
        -MarkdownOutputPath $missingCountOperationsHandoffPackageMarkdown 2>&1
    $missingCountOperationsHandoffPackageExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingCountOperationsHandoffPackageExitCode -ne 0) "Operations handoff package with missing finalizer gap count should fail import."
Assert-True (Test-Path -LiteralPath $missingCountOperationsHandoffPackageJson) "Missing-count handoff package import report should still be written."
$missingCountOperationsHandoffPackageReport = Get-Content -Raw -LiteralPath $missingCountOperationsHandoffPackageJson | ConvertFrom-Json
Assert-True ($missingCountOperationsHandoffPackageReport.result -eq "failed") "Missing-count handoff package import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $missingCountOperationsHandoffPackageOutput "latest-operations-handoff-package.json"))) "Missing-count handoff package must not be promoted."
$missingCountOperationsHandoffPackageEntry = @($missingCountOperationsHandoffPackageReport.entries | Where-Object { $_.group -eq "operations-handoff-package" -and $_.fileName -eq "latest-operations-handoff-package.json" })
Assert-True ($missingCountOperationsHandoffPackageEntry.Count -eq 1) "Missing-count handoff package failed entry missing."
Assert-True (([string] $missingCountOperationsHandoffPackageEntry[0].detail).Contains("finalizerGapCount=<missing>")) "Missing-count handoff package report should describe missing finalizer gap count."

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
