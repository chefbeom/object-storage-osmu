param(
    [string] $OutputDirectory = ".\.osmu-run\operations-handoff-package-self-test"
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

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-NotContains([string] $text, [string] $unexpected, [string] $label) {
    if ($text.Contains($unexpected)) {
        throw "$label contains unexpected credential text: $unexpected"
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-operations-handoff-package.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-operations-handoff-package.md"
$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-handoff-package.ps1"
$readinessSnapshotPath = Join-Path $resolvedOutputDirectory "latest-operations-readiness.json"
$convergenceSnapshotPath = Join-Path $resolvedOutputDirectory "latest-operations-readiness-convergence.json"
$dataFlowStoragePlanPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-plan.json"
$dataFlowStorageTransitionRunbookPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-transition-runbook-evidence.json"
$secretRotationPath = Join-Path $resolvedOutputDirectory "latest-secret-rotation-evidence.json"
$commercialIntegrationPath = Join-Path $resolvedOutputDirectory "latest-commercial-integration-evidence.json"
$commercialApprovalPath = Join-Path $resolvedOutputDirectory "latest-commercial-approval-evidence.json"
$enterpriseAuthPath = Join-Path $resolvedOutputDirectory "latest-enterprise-auth-smoke.json"
$monitoringThresholdPath = Join-Path $resolvedOutputDirectory "latest-monitoring-threshold-evidence.json"

[ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "ready"
    passedCount = 66
    pendingCount = 0
    summary = "passed=66 pending=0"
    checks = @(
        [ordered]@{
            name = "Operations handoff package target evidence"
            category = "operations-handoff-package"
            status = "PASS"
            passed = $true
            detail = "result=passed"
            evidencePath = ".osmu-run/latest-operations-handoff-package.json"
            requiredEvidence = "operations handoff package result=passed from target environment"
        }
    )
    decisionRule = "Production/B2B operations readiness is ready only when every listed check is PASS."
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $readinessSnapshotPath -Encoding UTF8

[ordered]@{
    formatVersion = "osmu.operations-readiness-convergence.v1"
    result = "ready"
    readinessResult = "ready"
    readinessSummary = "passed=66 pending=0"
    finalizerResult = "ready"
    finalizerReadinessResult = "ready"
    finalizerFailedCount = 0
    kubernetesReportSyncReady = $true
    kubernetesReportSyncResult = "applied"
    kubernetesReportSyncFailedCount = 0
    kubernetesReportSyncSourceReportResult = "ready"
    stageCount = 7
    readyStageCount = 7
    finalizerGapCount = 0
    currentBottleneck = [ordered]@{
        code = "none"
        title = "None"
        reason = "All target operations evidence is converged."
    }
    recommendedCommands = @()
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $convergenceSnapshotPath -Encoding UTF8

[ordered]@{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "passed"
    environmentName = "pilot-prod-self-test"
    targetCluster = "customer-cluster-a"
    operator = "ops-self-test"
    evidenceRef = "latest-data-flow-storage-plan-passed-20260620"
    candidateStore = "MARIADB_PARTITION"
    expectedPeakEventsPerDay = 100000
    expectedQueryWindowDays = 180
    targetP95QueryLatencyMs = 500
    eventRetentionDays = 90
    dailyRollupRetentionDays = 730
    monthlyRollupRetentionMonths = 36
    queryPlanEvidence = [ordered]@{
        provided = $true
        formatVersion = "osmu.mariadb-query-plan-evidence.v1"
        expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
        validFormatVersion = $true
        result = "passed"
        mode = "fixture"
        checkCount = 3
        passedCount = 3
        failedCount = 0
        failedChecks = @()
        detail = "formatVersion=osmu.mariadb-query-plan-evidence.v1; result=passed; mode=fixture; passed=3; failed=0; checks=3"
    }
    scopePolicy = "OSMU operations analytics only. This plan is not AWS billing parity and aggregate stores must not include object keys or raw event messages."
    checkCount = 10
    passedCount = 10
    pendingCount = 0
    checks = @(
        [ordered]@{
            id = "mariadb_query_plan_evidence"
            title = "MariaDB query plan evidence passed"
            status = "passed"
            detail = "fixture passed"
            nextAction = ""
        }
    )
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $dataFlowStoragePlanPath -Encoding UTF8

[ordered]@{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    generatedAt = "2026-06-20T02:05:00Z"
    result = "passed"
    environmentName = "pilot-prod-self-test"
    targetCluster = "customer-cluster-a"
    operatorName = "ops-self-test"
    evidenceRef = "latest-data-flow-storage-transition-runbook-passed-20260620"
    dataFlowStoragePlanSnapshot = [ordered]@{
        provided = $true
        parsed = $true
        formatVersion = "osmu.data-flow-storage-plan.v1"
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        targetP95QueryLatencyMs = 500
        pendingCount = 0
        checkCount = 10
    }
    evidenceRefs = [ordered]@{
        changeApproval = "CHG-2026-DATA-FLOW-STORAGE-RUNBOOK"
        dataFlowStoragePlan = "latest-data-flow-storage-plan-passed-20260620"
        backfill = "data-flow-backfill-rehearsal-20260620"
        dualWriteOrPartitionToggle = "data-flow-dual-write-toggle-review-20260620"
        rollback = "data-flow-rollback-rehearsal-20260620"
        reconciliation = "data-flow-reconciliation-20260620"
        dashboardCutover = "dashboard-cutover-review-20260620"
        retentionDryRun = "retention-dry-run-20260620"
    }
    confirmations = [ordered]@{
        backfillRehearsed = $true
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
    summary = [ordered]@{
        failureCount = 0
        checkCount = 24
    }
    checks = @(
        [ordered]@{
            id = "data-flow-storage-plan-passed"
            name = "Data-flow storage plan snapshot passed"
            status = "PASS"
            passed = $true
            detail = "formatVersion=osmu.data-flow-storage-plan.v1; result=passed; candidateStore=MARIADB_PARTITION; pending=0; targetP95QueryLatencyMs=500"
        }
    )
    decisionRule = "Production/B2B analytics storage transition requires result=passed."
    scopePolicy = "OSMU operations analytics storage transition only. This is not AWS billing parity."
    secretPolicy = "Evidence stores only external references and reduced summaries."
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $dataFlowStorageTransitionRunbookPath -Encoding UTF8

[ordered]@{
    formatVersion = "osmu.secret-rotation-evidence.v1"
    generatedAt = "2026-06-20T02:08:00Z"
    result = "passed"
    environmentName = "pilot-prod-self-test"
    targetCluster = "customer-cluster-a"
    operatorName = "ops-self-test"
    rotationWindow = [ordered]@{
        startedAt = "2026-06-20T01:00:00Z"
        completedAt = "2026-06-20T01:30:00Z"
    }
    evidenceRefs = [ordered]@{
        changeApproval = "CHG-2026-SECRET-ROTATION-SELF-TEST"
        secretManagerAudit = "vault-audit-run-20260620"
        workloadRestart = "rollout-status-run-20260620"
        smoke = "post-rotation-smoke-20260620"
        artifactLeakReview = "artifact-leak-review-20260620"
        accessKeyEncryptionDecision = "access-key-encryption-key-reissue-deferred-20260620"
    }
    confirmations = [ordered]@{
        noSecretValues = $true
        workloadRestart = $true
        smokePassed = $true
        artifactLeakReview = $true
        requireAllCoreSecrets = $true
    }
    rotations = @(
        [ordered]@{
            id = "admin-password"
            name = "Admin password"
            core = $true
            rotated = $true
            note = "rotated"
        },
        [ordered]@{
            id = "jwt-signing-secret"
            name = "JWT signing secret"
            core = $true
            rotated = $true
            note = "rotated"
        },
        [ordered]@{
            id = "database-credentials"
            name = "MariaDB credentials"
            core = $true
            rotated = $true
            note = "rotated"
        },
        [ordered]@{
            id = "minio-root-credentials"
            name = "MinIO root credentials"
            core = $true
            rotated = $true
            note = "rotated"
        },
        [ordered]@{
            id = "tls-certificate"
            name = "TLS certificate"
            core = $true
            rotated = $true
            note = "rotated"
        }
    )
    summary = [ordered]@{
        rotatedCount = 5
        coreRotatedCount = 5
        coreRequiredCount = 5
        failureCount = 0
        plannedCount = 0
    }
    checks = @(
        [ordered]@{
            id = "core-secret-rotation-coverage"
            name = "Core secret/certificate rotation coverage"
            status = "PASS"
            passed = $true
            detail = "rotatedCore=5/5"
        }
    )
    decisionRule = "Production/B2B readiness requires result=passed from the target environment after core secret/certificate rotation, workload restart, post-rotation smoke, and artifact leak review are confirmed."
    secretPolicy = "Evidence stores only environment labels, operator/change references, timestamps, booleans, and external evidence references."
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $secretRotationPath -Encoding UTF8

[ordered]@{
    formatVersion = "osmu.commercial-integration-evidence.v1"
    generatedAt = "2026-06-20T02:10:00Z"
    result = "passed"
    environmentName = "pilot-prod-self-test"
    targetCluster = "customer-cluster-a"
    operatorName = "ops-self-test"
    summary = [ordered]@{
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
    checks = @(
        [ordered]@{
            id = "integration-payment-erp"
            name = "ERP payment webhook profile verified"
            status = "PASS"
            passed = $true
            detail = "required=true verified=true evidenceRef=payment-erp-profile-20260620"
            evidenceRef = "payment-erp-profile-20260620"
        }
    )
    decisionRule = "Production/B2B commercial integration readiness requires result=passed."
    scopePolicy = "This evidence covers configured webhook/Slack/EMAIL SMTP relay and payment webhook profile handoff verification without claiming native processor API support."
    secretPolicy = "Evidence stores references only and does not contain webhook URLs with credentials, SMTP passwords, payment provider credentials, signing secrets, bearer tokens, private keys, raw provider responses, or customer payment data."
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $commercialIntegrationPath -Encoding UTF8

[ordered]@{
    formatVersion = "osmu.commercial-approval-evidence.v1"
    generatedAt = "2026-06-20T02:20:00Z"
    result = "passed"
    productVersion = "osmu-mvp-0.1"
    approvedBy = "commercial-board"
    approvedAt = "2026-06-20T02:15:00Z"
    evidenceRefs = [ordered]@{
        approval = "commercial-approval-board-20260620"
        pricing = "pricing-approval-20260620"
        terms = "terms-approval-20260620"
        supportSla = "support-sla-approval-20260620"
        licenseAgreement = "license-approval-20260620"
        legal = "legal-approval-20260620"
        pilotContract = "pilot-contract-boundary-20260620"
        pricingPolicyProposal = "pricing-policy-proposal-price-list-approved-20260620"
    }
    confirmations = [ordered]@{
        pricingApproved = $true
        termsApproved = $true
        supportSlaApproved = $true
        licenseApproved = $true
        legalApproved = $true
        pricingPolicyProposalCommercialApproval = $true
        noSecretValues = $true
    }
    summary = [ordered]@{
        passedCount = 12
        failureCount = 0
        checkCount = 12
        pricingPolicyProposalCommercialApproved = $true
        pricingPolicyProposalCommercialApprovedCount = 1
        pricingPolicyProposalApprovedPriceListCount = 1
    }
    checks = @(
        [ordered]@{
            id = "legal-approval-confirmed"
            name = "Legal approval confirmed"
            status = "PASS"
            passed = $true
            detail = "legalApprovalRef=legal-approval-20260620"
            evidenceRef = "legal-approval-20260620"
        }
    )
    decisionRule = "Production/B2B sale commercial approval requires result=passed."
    scopePolicy = "This evidence records commercial/legal approval references and sanitized billing pricing policy proposal approval status only."
    secretPolicy = "Evidence stores only sanitized approval references and must not contain passwords, tokens, private keys, license keys, signing secrets, customer payment data, raw price tables, or raw contract text."
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $commercialApprovalPath -Encoding UTF8

[ordered]@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    generatedAt = "2026-06-20T02:25:00Z"
    result = "scope-out"
    executionMode = "scope-out"
    apiBase = "http://localhost:8080/api"
    requireOidc = $true
    requireLdap = $true
    requireAuditEvents = $false
    scopeOut = [ordered]@{
        confirmed = $true
        reference = "enterprise-auth-contract-scope-out-20260620"
        reason = "Pilot contract excludes SSO until customer IdP onboarding."
        accepted = $true
    }
    inputs = [ordered]@{
        adminPasswordProvided = $false
        oidcCallbackCodeProvided = $false
        oidcCallbackStateProvided = $false
        oidcClaimPreviewJsonPathProvided = $false
        oidcJitProvisionJsonPathProvided = $false
        confirmJitProvision = $false
        ldapLoginIdProvided = $false
        ldapPasswordProvided = $false
        expectedEmailProvided = $false
    }
    summary = [ordered]@{
        passCount = 0
        failCount = 0
        blockedCount = 0
        plannedCount = 0
        skippedCount = 6
    }
    checks = @(
        [ordered]@{
            id = "enterprise-auth-scope-out"
            name = "Enterprise auth commercial scope-out"
            category = "scope-out"
            endpoint = ""
            status = "SKIPPED"
            detail = "Accepted commercial scope-out reference recorded."
            requiredInputs = @()
        }
    )
    decisionRule = "Paid/production pilot requires result=passed from the target IdP/directory, or result=scope-out with an explicit non-secret commercial approval reference and reason."
    secretPolicy = "Admin password, LDAP password, access/refresh tokens, OIDC authorization code/state, client secrets, and raw OIDC claim JSON are never written to this evidence."
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $enterpriseAuthPath -Encoding UTF8

[ordered]@{
    formatVersion = "osmu.monitoring-threshold-evidence.v1"
    generatedAt = "2026-06-20T02:28:00Z"
    result = "passed"
    environmentName = "pilot-prod-self-test"
    targetCluster = "customer-cluster-a"
    operatorName = "ops-self-test"
    evidenceRef = "prometheus-alertmanager-grafana-review-20260620"
    thresholdTargetSummary = [ordered]@{
        requiredAlertCount = 11
        mappedAlertCount = 11
        missingAlerts = @()
        routeCount = 3
        routes = @("osmu-backend", "osmu-data-flow", "osmu-backup")
        grafanaPanelCount = 11
        tuningEvidenceCount = 11
    }
    confirmations = [ordered]@{
        prometheusRulesLoaded = $true
        grafanaDashboardImported = $true
        alertmanagerRoutesReviewed = $true
        targetBaselinesReviewed = $true
        incidentRoutingReviewed = $true
        noSecretValues = $true
    }
    summary = [ordered]@{
        failureCount = 0
        checkCount = 24
    }
    checks = @(
        [ordered]@{
            id = "prometheus-rules-loaded-confirmed"
            name = "Prometheus rules loaded confirmation"
            status = "PASS"
            passed = $true
            detail = "Rules were loaded into target Prometheus or PrometheusRule."
        }
    )
    decisionRule = "Production/B2B monitoring readiness requires result=passed."
    secretPolicy = "Evidence stores only references and booleans."
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $monitoringThresholdPath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "ops-self-test" `
    -HandoffStartedAt "2026-06-20T02:00:00Z" `
    -HandoffCompletedAt "2026-06-20T02:30:00Z" `
    -ChangeApprovalRef "CHG-2026-OPERATIONS-HANDOFF-SELF-TEST" `
    -DeploymentEvidenceRef "deployment-release-run-20260620" `
    -OperationsReadinessRef "latest-operations-readiness-ready-20260620" `
    -OperationsConvergenceRef "latest-operations-readiness-convergence-ready-20260620" `
    -DataFlowStoragePlanEvidenceRef "latest-data-flow-storage-plan-passed-20260620" `
    -DataFlowStorageTransitionRunbookEvidenceRef "latest-data-flow-storage-transition-runbook-passed-20260620" `
    -OperationsReadinessJsonPath $readinessSnapshotPath `
    -OperationsConvergenceJsonPath $convergenceSnapshotPath `
    -DataFlowStoragePlanJsonPath $dataFlowStoragePlanPath `
    -DataFlowStorageTransitionRunbookJsonPath $dataFlowStorageTransitionRunbookPath `
    -SecretRotationEvidenceRef "latest-secret-rotation-evidence-passed-20260620" `
    -SecretRotationJsonPath $secretRotationPath `
    -CommercialIntegrationEvidenceRef "latest-commercial-integration-evidence-passed-20260620" `
    -CommercialApprovalEvidenceRef "latest-commercial-approval-evidence-passed-20260620" `
    -CommercialIntegrationJsonPath $commercialIntegrationPath `
    -CommercialApprovalJsonPath $commercialApprovalPath `
    -EnterpriseAuthEvidenceRef "latest-enterprise-auth-smoke-passed-20260620" `
    -EnterpriseAuthJsonPath $enterpriseAuthPath `
    -BackupRestoreEvidenceRef "latest-kubernetes-dr-finalize-ready-20260620" `
    -HaDrEvidenceRef "latest-kubernetes-ha-dr-readiness-passed-20260620" `
    -MonitoringEvidenceRef "prometheus-alertmanager-grafana-review-20260620" `
    -MonitoringThresholdJsonPath $monitoringThresholdPath `
    -SecurityEvidenceRef "latest-security-evidence-finalize-passed-20260620" `
    -IamRbacEvidenceRef "latest-iam-rbac-finalize-passed-20260620" `
    -RunbookReviewRef "operator-runbook-review-20260620" `
    -TroubleshootingReviewRef "troubleshooting-review-20260620" `
    -SupportEscalationRef "support-escalation-ticket-20260620" `
    -SupportSlaRef "support-sla-contract-20260620" `
    -KnownGapsRef "known-gaps-acceptance-20260620" `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -ConfirmRunbookReviewed `
    -ConfirmTroubleshootingReviewed `
    -ConfirmRollbackReviewed `
    -ConfirmSupportEscalationReviewed `
    -ConfirmKnownGapsAccepted `
    -ConfirmOperationsReadinessSnapshotReviewed `
    -ConfirmOperationsConvergenceSnapshotReviewed `
    -ConfirmDataFlowStoragePlanReviewed `
    -ConfirmDataFlowStorageTransitionRunbookReviewed `
    -ConfirmSecretRotationSnapshotReviewed `
    -ConfirmCommercialIntegrationSnapshotReviewed `
    -ConfirmCommercialApprovalSnapshotReviewed `
    -ConfirmEnterpriseAuthSmokeSnapshotReviewed `
    -ConfirmMonitoringThresholdReviewed `
    -ConfirmNoSecretValues `
    -RequireProductionEvidence `
    -RequireOperationsSnapshotEvidence `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-handoff-package.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Operations handoff package JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Operations handoff package markdown missing."

$reportText = Get-Content -Raw -LiteralPath $jsonOutputPath
$markdown = Get-Content -Raw -LiteralPath $markdownOutputPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)

Assert-True ($report.formatVersion -eq "osmu.operations-handoff-package.v1") "Unexpected operations handoff package formatVersion."
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.summary.plannedCount -eq 0) "Expected zero planned checks when production evidence is required."
Assert-True ($checks.Count -ge 35) "Expected operations handoff package checks."
Assert-True (@($checks | Where-Object { $_.id -eq "handoff-window-order" -and $_.passed }).Count -eq 1) "Expected handoff window order check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "commercial-approval-evidence" -and $_.passed }).Count -eq 1) "Expected commercial approval evidence check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "operations-readiness-snapshot-parsed" -and $_.passed }).Count -eq 1) "Expected operations readiness snapshot parsed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "operations-readiness-snapshot-ready" -and $_.passed }).Count -eq 1) "Expected operations readiness snapshot ready check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "operations-convergence-snapshot-ready" -and $_.passed }).Count -eq 1) "Expected operations convergence snapshot ready check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-plan-evidence" -and $_.passed }).Count -eq 1) "Expected data-flow storage plan evidence check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-plan-snapshot-parsed" -and $_.passed }).Count -eq 1) "Expected data-flow storage plan snapshot parsed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-plan-snapshot-passed" -and $_.passed }).Count -eq 1) "Expected data-flow storage plan snapshot passed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-plan-reviewed" -and $_.passed }).Count -eq 1) "Expected data-flow storage plan reviewed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-transition-runbook-evidence" -and $_.passed }).Count -eq 1) "Expected data-flow storage transition runbook evidence check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-transition-runbook-snapshot-parsed" -and $_.passed }).Count -eq 1) "Expected data-flow storage transition runbook snapshot parsed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-transition-runbook-snapshot-passed" -and $_.passed }).Count -eq 1) "Expected data-flow storage transition runbook snapshot passed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-transition-runbook-reviewed" -and $_.passed }).Count -eq 1) "Expected data-flow storage transition runbook reviewed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "secret-rotation-snapshot-parsed" -and $_.passed }).Count -eq 1) "Expected secret rotation snapshot parsed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "secret-rotation-snapshot-passed" -and $_.passed }).Count -eq 1) "Expected secret rotation snapshot passed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "secret-rotation-snapshot-reviewed" -and $_.passed }).Count -eq 1) "Expected secret rotation snapshot reviewed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "commercial-integration-snapshot-parsed" -and $_.passed }).Count -eq 1) "Expected commercial integration snapshot parsed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "commercial-integration-snapshot-passed" -and $_.passed }).Count -eq 1) "Expected commercial integration snapshot passed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "commercial-integration-snapshot-reviewed" -and $_.passed }).Count -eq 1) "Expected commercial integration snapshot reviewed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "commercial-approval-snapshot-parsed" -and $_.passed }).Count -eq 1) "Expected commercial approval snapshot parsed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "commercial-approval-snapshot-passed" -and $_.passed }).Count -eq 1) "Expected commercial approval snapshot passed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "commercial-approval-snapshot-reviewed" -and $_.passed }).Count -eq 1) "Expected commercial approval snapshot reviewed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "enterprise-auth-smoke-snapshot-parsed" -and $_.passed }).Count -eq 1) "Expected enterprise auth smoke snapshot parsed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "enterprise-auth-smoke-snapshot-accepted" -and $_.passed }).Count -eq 1) "Expected enterprise auth smoke snapshot accepted check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "enterprise-auth-smoke-snapshot-reviewed" -and $_.passed }).Count -eq 1) "Expected enterprise auth smoke snapshot reviewed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "monitoring-threshold-snapshot-parsed" -and $_.passed }).Count -eq 1) "Expected monitoring threshold snapshot parsed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "monitoring-threshold-snapshot-passed" -and $_.passed }).Count -eq 1) "Expected monitoring threshold snapshot passed check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "monitoring-threshold-reviewed" -and $_.passed }).Count -eq 1) "Expected monitoring threshold reviewed check to pass."
Assert-True ($report.confirmations.noSecretValues) "Expected no-secret-values confirmation."
Assert-True ($report.confirmations.runbookReviewed) "Expected runbook reviewed confirmation."
Assert-True ($report.confirmations.troubleshootingReviewed) "Expected troubleshooting reviewed confirmation."
Assert-True ($report.confirmations.rollbackReviewed) "Expected rollback reviewed confirmation."
Assert-True ($report.confirmations.supportEscalationReviewed) "Expected support escalation reviewed confirmation."
Assert-True ($report.confirmations.knownGapsAccepted) "Expected known gaps accepted confirmation."
Assert-True ($report.confirmations.operationsReadinessSnapshotReviewed) "Expected operations readiness snapshot reviewed confirmation."
Assert-True ($report.confirmations.operationsConvergenceSnapshotReviewed) "Expected operations convergence snapshot reviewed confirmation."
Assert-True ($report.confirmations.dataFlowStoragePlanReviewed) "Expected data-flow storage plan reviewed confirmation."
Assert-True ($report.confirmations.dataFlowStorageTransitionRunbookReviewed) "Expected data-flow storage transition runbook reviewed confirmation."
Assert-True ($report.confirmations.secretRotationSnapshotReviewed) "Expected secret rotation snapshot reviewed confirmation."
Assert-True ($report.confirmations.commercialIntegrationSnapshotReviewed) "Expected commercial integration snapshot reviewed confirmation."
Assert-True ($report.confirmations.commercialApprovalSnapshotReviewed) "Expected commercial approval snapshot reviewed confirmation."
Assert-True ($report.confirmations.enterpriseAuthSmokeSnapshotReviewed) "Expected enterprise auth smoke snapshot reviewed confirmation."
Assert-True ($report.confirmations.monitoringThresholdReviewed) "Expected monitoring threshold reviewed confirmation."
Assert-True ($report.confirmations.requireProductionEvidence) "Expected production evidence requirement."
Assert-True ($report.confirmations.requireOperationsSnapshotEvidence) "Expected operations snapshot evidence requirement."
Assert-True ($report.operationsSnapshots.readiness.result -eq "ready") "Expected operations readiness snapshot result=ready."
Assert-True ($report.operationsSnapshots.convergence.result -eq "ready") "Expected operations convergence snapshot result=ready."
Assert-True ($report.operationsSnapshots.convergence.finalizerFailedCount -eq 0) "Expected convergence snapshot finalizerFailedCount=0."
Assert-True ($report.operationsSnapshots.convergence.finalizerGapCount -eq 0) "Expected convergence snapshot finalizerGapCount=0."
Assert-True ($report.operationsSnapshots.convergence.kubernetesReportSyncReady) "Expected convergence snapshot Kubernetes report sync ready."
Assert-True ($report.operationsSnapshots.convergence.kubernetesReportSyncSourceReportResult -eq "ready") "Expected convergence snapshot Kubernetes report sync source result=ready."
Assert-True ($report.summary.operationsConvergenceFinalizerFailedCount -eq 0) "Expected summary convergence finalizer failed count."
Assert-True ($report.summary.operationsConvergenceFinalizerGapCount -eq 0) "Expected summary convergence finalizer gap count."
Assert-True ($report.summary.operationsConvergenceKubernetesReportSyncSourceReportResult -eq "ready") "Expected summary convergence sync source report result."
Assert-True ($report.targetEvidenceSnapshots.dataFlowStoragePlan.result -eq "passed") "Expected data-flow storage plan snapshot result=passed."
Assert-True ($report.targetEvidenceSnapshots.dataFlowStoragePlan.targetP95QueryLatencyMs -eq 500) "Expected data-flow storage plan snapshot target p95 query latency budget."
Assert-True ($report.targetEvidenceSnapshots.dataFlowStoragePlan.queryPlanEvidence.result -eq "passed") "Expected data-flow query-plan snapshot result=passed."
Assert-True ($report.targetEvidenceSnapshots.dataFlowStorageTransitionRunbook.result -eq "passed") "Expected data-flow storage transition runbook snapshot result=passed."
Assert-True ($report.targetEvidenceSnapshots.dataFlowStorageTransitionRunbook.storagePlanResult -eq "passed") "Expected data-flow storage transition runbook storage plan result=passed."
Assert-True ($report.targetEvidenceSnapshots.dataFlowStorageTransitionRunbook.confirmations.backfillRehearsed) "Expected data-flow storage transition runbook backfill confirmation."
Assert-True ($report.targetEvidenceSnapshots.dataFlowStorageTransitionRunbook.confirmations.rollbackRehearsed) "Expected data-flow storage transition runbook rollback confirmation."
Assert-True ($report.targetEvidenceSnapshots.secretRotation.result -eq "passed") "Expected secret rotation snapshot result=passed."
Assert-True ($report.targetEvidenceSnapshots.secretRotation.coreRotatedCount -eq 5) "Expected secret rotation coreRotatedCount=5."
Assert-True ($report.targetEvidenceSnapshots.secretRotation.confirmations.smokePassed) "Expected secret rotation smoke confirmation."
Assert-True ($report.targetEvidenceSnapshots.commercialIntegration.result -eq "passed") "Expected commercial integration snapshot result=passed."
Assert-True ($report.targetEvidenceSnapshots.commercialIntegration.requiredVerifiedCount -eq 8) "Expected commercial integration requiredVerifiedCount=8."
Assert-True ($report.targetEvidenceSnapshots.commercialApproval.result -eq "passed") "Expected commercial approval snapshot result=passed."
Assert-True ($report.targetEvidenceSnapshots.commercialApproval.pricingPolicyProposalApprovedPriceListCount -eq 1) "Expected commercial approval price-list approval count."
Assert-True ($report.targetEvidenceSnapshots.enterpriseAuthSmoke.result -eq "scope-out") "Expected enterprise auth smoke snapshot result=scope-out."
Assert-True ($report.targetEvidenceSnapshots.enterpriseAuthSmoke.scopeOutAccepted) "Expected enterprise auth scope-out accepted."
Assert-True ($report.targetEvidenceSnapshots.monitoringThreshold.result -eq "passed") "Expected monitoring threshold snapshot result=passed."
Assert-True ($report.targetEvidenceSnapshots.monitoringThreshold.mappedAlertCount -eq 11) "Expected monitoring threshold mapped alert count."
Assert-True ($report.targetEvidenceSnapshots.monitoringThreshold.complete) "Expected monitoring threshold complete snapshot."
Assert-True ($report.evidenceRefs.dataFlowStoragePlan -eq "latest-data-flow-storage-plan-passed-20260620") "Expected data-flow storage plan evidence reference."
Assert-True ($report.evidenceRefs.dataFlowStorageTransitionRunbook -eq "latest-data-flow-storage-transition-runbook-passed-20260620") "Expected data-flow storage transition runbook evidence reference."

Assert-Contains $markdown "# OSMU Operations Handoff Package" "operations handoff package markdown"
Assert-Contains $markdown "Record passed target package" "operations handoff package markdown"
Assert-Contains $markdown "Operations Snapshots" "operations handoff package markdown"
Assert-Contains $markdown "Target Evidence Snapshots" "operations handoff package markdown"
Assert-Contains $markdown "finalizerFailed=0" "operations handoff package markdown"
Assert-Contains $markdown "sourceReportResult=ready" "operations handoff package markdown"
Assert-Contains $markdown "targetP95QueryLatencyMs=500" "operations handoff package markdown"
Assert-Contains $markdown "Data-flow storage transition runbook" "operations handoff package markdown"
Assert-Contains $markdown "Monitoring threshold" "operations handoff package markdown"
Assert-Contains $report.decisionRule "Production/B2B operations handoff package readiness requires result=passed" "operations handoff package JSON"
Assert-Contains $report.decisionRule "data-flow storage transition" "operations handoff package JSON"
Assert-Contains $report.decisionRule "data-flow storage transition runbook" "operations handoff package JSON"
Assert-Contains $report.decisionRule "commercial approval" "operations handoff package JSON"
Assert-Contains $report.decisionRule "commercial integration" "operations handoff package JSON"
Assert-Contains $report.decisionRule "enterprise auth smoke snapshot" "operations handoff package JSON"
Assert-Contains $report.decisionRule "monitoring threshold snapshots" "operations handoff package JSON"
Assert-Contains $report.decisionRule "typed boolean Kubernetes report sync ready=true" "operations handoff package JSON"
Assert-Contains $report.decisionRule "typed integer finalizer failed/gap counts at zero" "operations handoff package JSON"
Assert-Contains $report.decisionRule "sourceReportResult=ready" "operations handoff package JSON"
Assert-Contains $report.scopePolicy "does not execute kubectl, gh, provider APIs" "operations handoff package JSON"
Assert-Contains $report.secretPolicy "must not contain passwords, bearer tokens, kubeconfig values" "operations handoff package JSON"
Assert-Contains $report.secretPolicy "raw SQL, raw EXPLAIN JSON" "operations handoff package JSON"
Assert-Contains $report.secretPolicy "object keys, raw event messages" "operations handoff package JSON"
Assert-Contains $report.secretPolicy "raw identity claims" "operations handoff package JSON"
Assert-Contains $report.secretPolicy "raw Alertmanager receiver secrets" "operations handoff package JSON"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----", "rawProviderResponse", "customer@example.com", "contractText", "rawClaimJson")) {
    Assert-NotContains $reportText $unexpected "operations handoff package JSON"
    Assert-NotContains $markdown $unexpected "operations handoff package markdown"
}

$missingQueryPlanDataFlowStoragePlanPath = Join-Path $resolvedOutputDirectory "missing-query-plan-data-flow-storage-plan.json"
$missingQueryPlanDataFlowStoragePlan = Get-Content -Raw -LiteralPath $dataFlowStoragePlanPath | ConvertFrom-Json
$missingQueryPlanDataFlowStoragePlan.PSObject.Properties.Remove("queryPlanEvidence")
$missingQueryPlanDataFlowStoragePlan | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $missingQueryPlanDataFlowStoragePlanPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingQueryPlanOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -DataFlowStoragePlanEvidenceRef "latest-data-flow-storage-plan-passed-20260620" `
        -DataFlowStoragePlanJsonPath $missingQueryPlanDataFlowStoragePlanPath `
        -ConfirmDataFlowStoragePlanReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $missingQueryPlanExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingQueryPlanExitCode -ne 0) "MariaDB data-flow storage plan without query-plan evidence should be rejected."
Assert-Contains ($missingQueryPlanOutput | Out-String) "queryPlanEvidenceRequired=True; queryPlanEvidencePassed=False" "missing query-plan data-flow storage plan output"

$stringCountQueryPlanDataFlowStoragePlanPath = Join-Path $resolvedOutputDirectory "string-count-query-plan-data-flow-storage-plan.json"
$stringCountQueryPlanDataFlowStoragePlan = Get-Content -Raw -LiteralPath $dataFlowStoragePlanPath | ConvertFrom-Json
$stringCountQueryPlanDataFlowStoragePlan.queryPlanEvidence.checkCount = "3"
$stringCountQueryPlanDataFlowStoragePlan | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stringCountQueryPlanDataFlowStoragePlanPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringCountQueryPlanOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -DataFlowStoragePlanEvidenceRef "latest-data-flow-storage-plan-passed-20260620" `
        -DataFlowStoragePlanJsonPath $stringCountQueryPlanDataFlowStoragePlanPath `
        -ConfirmDataFlowStoragePlanReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringCountQueryPlanExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringCountQueryPlanExitCode -ne 0) "Data-flow query-plan evidence string count should be rejected."
Assert-Contains ($stringCountQueryPlanOutput | Out-String) "queryPlanEvidenceRequired=True; queryPlanEvidencePassed=False" "string query-plan count output"

$stringBoolDataFlowRunbookPath = Join-Path $resolvedOutputDirectory "string-bool-data-flow-storage-transition-runbook.json"
$stringBoolDataFlowRunbook = Get-Content -Raw -LiteralPath $dataFlowStorageTransitionRunbookPath | ConvertFrom-Json
$stringBoolDataFlowRunbook.confirmations.backfillRehearsed = "true"
$stringBoolDataFlowRunbook | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stringBoolDataFlowRunbookPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolDataFlowRunbookOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -DataFlowStorageTransitionRunbookEvidenceRef "latest-data-flow-storage-transition-runbook-passed-20260620" `
        -DataFlowStorageTransitionRunbookJsonPath $stringBoolDataFlowRunbookPath `
        -ConfirmDataFlowStorageTransitionRunbookReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringBoolDataFlowRunbookExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolDataFlowRunbookExitCode -ne 0) "Data-flow storage transition runbook string confirmation boolean should be rejected."
Assert-Contains ($stringBoolDataFlowRunbookOutput | Out-String) "confirmationsValid=False" "string data-flow runbook confirmation output"

$stringBoolSecretRotationPath = Join-Path $resolvedOutputDirectory "string-bool-secret-rotation.json"
$stringBoolSecretRotation = Get-Content -Raw -LiteralPath $secretRotationPath | ConvertFrom-Json
$stringBoolSecretRotation.confirmations.smokePassed = "true"
$stringBoolSecretRotation | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stringBoolSecretRotationPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolSecretRotationOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -SecretRotationEvidenceRef "latest-secret-rotation-evidence-passed-20260620" `
        -SecretRotationJsonPath $stringBoolSecretRotationPath `
        -ConfirmSecretRotationSnapshotReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringBoolSecretRotationExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolSecretRotationExitCode -ne 0) "Secret rotation string confirmation boolean should be rejected."
Assert-Contains ($stringBoolSecretRotationOutput | Out-String) "confirmationsValid=False" "string secret rotation confirmation output"

$stringBoolEnterpriseAuthPath = Join-Path $resolvedOutputDirectory "string-bool-enterprise-auth-scope-out.json"
$stringBoolEnterpriseAuth = Get-Content -Raw -LiteralPath $enterpriseAuthPath | ConvertFrom-Json
$stringBoolEnterpriseAuth.scopeOut.accepted = "true"
$stringBoolEnterpriseAuth | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stringBoolEnterpriseAuthPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolEnterpriseAuthOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnterpriseAuthEvidenceRef "latest-enterprise-auth-smoke-passed-20260620" `
        -EnterpriseAuthJsonPath $stringBoolEnterpriseAuthPath `
        -ConfirmEnterpriseAuthSmokeSnapshotReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringBoolEnterpriseAuthExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolEnterpriseAuthExitCode -ne 0) "Enterprise auth scope-out string accepted boolean should be rejected."
Assert-Contains ($stringBoolEnterpriseAuthOutput | Out-String) "scopeOutAccepted=true(valid=False)" "string enterprise auth scope-out output"

$stringBoolMonitoringThresholdPath = Join-Path $resolvedOutputDirectory "string-bool-monitoring-threshold.json"
$stringBoolMonitoringThreshold = Get-Content -Raw -LiteralPath $monitoringThresholdPath | ConvertFrom-Json
$stringBoolMonitoringThreshold.confirmations.prometheusRulesLoaded = "true"
$stringBoolMonitoringThreshold | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stringBoolMonitoringThresholdPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolMonitoringThresholdOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -MonitoringEvidenceRef "prometheus-alertmanager-grafana-review-20260620" `
        -MonitoringThresholdJsonPath $stringBoolMonitoringThresholdPath `
        -ConfirmMonitoringThresholdReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringBoolMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolMonitoringThresholdExitCode -ne 0) "Monitoring threshold string confirmation boolean should be rejected."
Assert-Contains ($stringBoolMonitoringThresholdOutput | Out-String) "confirmationsValid=False" "string monitoring threshold confirmation output"

$stringCountCommercialIntegrationPath = Join-Path $resolvedOutputDirectory "string-count-commercial-integration.json"
$stringCountCommercialIntegration = Get-Content -Raw -LiteralPath $commercialIntegrationPath | ConvertFrom-Json
$stringCountCommercialIntegration.summary.requiredCount = "8"
$stringCountCommercialIntegration | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stringCountCommercialIntegrationPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringCountCommercialIntegrationOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -CommercialIntegrationEvidenceRef "latest-commercial-integration-evidence-passed-20260620" `
        -CommercialIntegrationJsonPath $stringCountCommercialIntegrationPath `
        -ConfirmCommercialIntegrationSnapshotReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringCountCommercialIntegrationExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringCountCommercialIntegrationExitCode -ne 0) "Commercial integration string count should be rejected."
Assert-Contains ($stringCountCommercialIntegrationOutput | Out-String) "countsValid=False" "string commercial integration count output"

$stringBoolCommercialIntegrationPath = Join-Path $resolvedOutputDirectory "string-bool-commercial-integration.json"
$stringBoolCommercialIntegration = Get-Content -Raw -LiteralPath $commercialIntegrationPath | ConvertFrom-Json
$stringBoolCommercialIntegration.summary.paymentProviderAdapterReadinessReviewed = "true"
$stringBoolCommercialIntegration | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stringBoolCommercialIntegrationPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolCommercialIntegrationOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -CommercialIntegrationEvidenceRef "latest-commercial-integration-evidence-passed-20260620" `
        -CommercialIntegrationJsonPath $stringBoolCommercialIntegrationPath `
        -ConfirmCommercialIntegrationSnapshotReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringBoolCommercialIntegrationExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolCommercialIntegrationExitCode -ne 0) "Commercial integration string readiness-review boolean should be rejected."
Assert-Contains ($stringBoolCommercialIntegrationOutput | Out-String) "paymentProviderAdapterReadinessReviewed=true(valid=False)" "string commercial integration boolean output"

$stringBoolCommercialApprovalPath = Join-Path $resolvedOutputDirectory "string-bool-commercial-approval.json"
$stringBoolCommercialApproval = Get-Content -Raw -LiteralPath $commercialApprovalPath | ConvertFrom-Json
$stringBoolCommercialApproval.summary.pricingPolicyProposalCommercialApproved = "true"
$stringBoolCommercialApproval | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stringBoolCommercialApprovalPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolCommercialApprovalOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -CommercialApprovalEvidenceRef "latest-commercial-approval-evidence-passed-20260620" `
        -CommercialApprovalJsonPath $stringBoolCommercialApprovalPath `
        -ConfirmCommercialApprovalSnapshotReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringBoolCommercialApprovalExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolCommercialApprovalExitCode -ne 0) "Commercial approval string pricing approval boolean should be rejected."
Assert-Contains ($stringBoolCommercialApprovalOutput | Out-String) "pricingPolicyProposalCommercialApproved=true(valid=False)" "string commercial approval boolean output"

$missingCountCommercialApprovalPath = Join-Path $resolvedOutputDirectory "missing-count-commercial-approval.json"
$missingCountCommercialApproval = Get-Content -Raw -LiteralPath $commercialApprovalPath | ConvertFrom-Json
$missingCountCommercialApproval.summary.PSObject.Properties.Remove("pricingPolicyProposalApprovedPriceListCount")
$missingCountCommercialApproval | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $missingCountCommercialApprovalPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingCountCommercialApprovalOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -CommercialApprovalEvidenceRef "latest-commercial-approval-evidence-passed-20260620" `
        -CommercialApprovalJsonPath $missingCountCommercialApprovalPath `
        -ConfirmCommercialApprovalSnapshotReviewed `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $missingCountCommercialApprovalExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingCountCommercialApprovalExitCode -ne 0) "Commercial approval missing price-list count should be rejected."
Assert-Contains ($missingCountCommercialApprovalOutput | Out-String) "countsValid=False" "missing commercial approval count output"

$failedFinalizerConvergenceSnapshotPath = Join-Path $resolvedOutputDirectory "failed-finalizer-operations-readiness-convergence.json"
[ordered]@{
    formatVersion = "osmu.operations-readiness-convergence.v1"
    result = "ready"
    readinessResult = "ready"
    readinessSummary = "passed=66 pending=0"
    finalizerResult = "ready"
    finalizerReadinessResult = "ready"
    finalizerFailedCount = 1
    kubernetesReportSyncReady = $true
    kubernetesReportSyncResult = "applied"
    kubernetesReportSyncFailedCount = 0
    kubernetesReportSyncSourceReportResult = "ready"
    stageCount = 7
    readyStageCount = 7
    finalizerGapCount = 0
    currentBottleneck = [ordered]@{
        code = "none"
        title = "None"
        reason = "Tampered fixture claims ready despite finalizer failure."
    }
    recommendedCommands = @()
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $failedFinalizerConvergenceSnapshotPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $failedFinalizerOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -HandoffStartedAt "2026-06-20T02:00:00Z" `
        -HandoffCompletedAt "2026-06-20T02:30:00Z" `
        -ChangeApprovalRef "CHG-2026-OPERATIONS-HANDOFF-SELF-TEST" `
        -DeploymentEvidenceRef "deployment-release-run-20260620" `
        -OperationsReadinessRef "latest-operations-readiness-ready-20260620" `
        -OperationsConvergenceRef "latest-operations-readiness-convergence-ready-20260620" `
        -OperationsReadinessJsonPath $readinessSnapshotPath `
        -OperationsConvergenceJsonPath $failedFinalizerConvergenceSnapshotPath `
        -RunbookReviewRef "operator-runbook-review-20260620" `
        -TroubleshootingReviewRef "troubleshooting-review-20260620" `
        -SupportEscalationRef "support-escalation-ticket-20260620" `
        -SupportSlaRef "support-sla-contract-20260620" `
        -KnownGapsRef "known-gaps-acceptance-20260620" `
        -ConfirmRunbookReviewed `
        -ConfirmTroubleshootingReviewed `
        -ConfirmRollbackReviewed `
        -ConfirmSupportEscalationReviewed `
        -ConfirmKnownGapsAccepted `
        -ConfirmOperationsReadinessSnapshotReviewed `
        -ConfirmOperationsConvergenceSnapshotReviewed `
        -ConfirmNoSecretValues `
        -RequireOperationsSnapshotEvidence `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $failedFinalizerExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($failedFinalizerExitCode -ne 0) "Convergence snapshot with finalizer failures should be rejected."
Assert-Contains ($failedFinalizerOutput | Out-String) "finalizerFailed=1" "failed finalizer convergence output"

$notReadySyncConvergenceSnapshotPath = Join-Path $resolvedOutputDirectory "not-ready-sync-operations-readiness-convergence.json"
[ordered]@{
    formatVersion = "osmu.operations-readiness-convergence.v1"
    result = "ready"
    readinessResult = "ready"
    readinessSummary = "passed=66 pending=0"
    finalizerResult = "ready"
    finalizerReadinessResult = "ready"
    finalizerFailedCount = 0
    kubernetesReportSyncReady = $true
    kubernetesReportSyncResult = "applied"
    kubernetesReportSyncFailedCount = 0
    kubernetesReportSyncSourceReportResult = "action-required"
    stageCount = 7
    readyStageCount = 7
    finalizerGapCount = 0
    currentBottleneck = [ordered]@{
        code = "none"
        title = "None"
        reason = "Tampered fixture claims ready despite non-ready sync source."
    }
    recommendedCommands = @()
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $notReadySyncConvergenceSnapshotPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $notReadySyncOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -HandoffStartedAt "2026-06-20T02:00:00Z" `
        -HandoffCompletedAt "2026-06-20T02:30:00Z" `
        -ChangeApprovalRef "CHG-2026-OPERATIONS-HANDOFF-SELF-TEST" `
        -DeploymentEvidenceRef "deployment-release-run-20260620" `
        -OperationsReadinessRef "latest-operations-readiness-ready-20260620" `
        -OperationsConvergenceRef "latest-operations-readiness-convergence-ready-20260620" `
        -OperationsReadinessJsonPath $readinessSnapshotPath `
        -OperationsConvergenceJsonPath $notReadySyncConvergenceSnapshotPath `
        -RunbookReviewRef "operator-runbook-review-20260620" `
        -TroubleshootingReviewRef "troubleshooting-review-20260620" `
        -SupportEscalationRef "support-escalation-ticket-20260620" `
        -SupportSlaRef "support-sla-contract-20260620" `
        -KnownGapsRef "known-gaps-acceptance-20260620" `
        -ConfirmRunbookReviewed `
        -ConfirmTroubleshootingReviewed `
        -ConfirmRollbackReviewed `
        -ConfirmSupportEscalationReviewed `
        -ConfirmKnownGapsAccepted `
        -ConfirmOperationsReadinessSnapshotReviewed `
        -ConfirmOperationsConvergenceSnapshotReviewed `
        -ConfirmNoSecretValues `
        -RequireOperationsSnapshotEvidence `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $notReadySyncExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($notReadySyncExitCode -ne 0) "Convergence snapshot with non-ready sync source should be rejected."
Assert-Contains ($notReadySyncOutput | Out-String) "sourceReportResult=action-required" "not-ready sync convergence output"

$stringBoolSyncConvergenceSnapshotPath = Join-Path $resolvedOutputDirectory "string-bool-sync-operations-readiness-convergence.json"
[ordered]@{
    formatVersion = "osmu.operations-readiness-convergence.v1"
    result = "ready"
    readinessResult = "ready"
    readinessSummary = "passed=66 pending=0"
    finalizerResult = "ready"
    finalizerReadinessResult = "ready"
    finalizerFailedCount = 0
    kubernetesReportSyncReady = "true"
    kubernetesReportSyncResult = "applied"
    kubernetesReportSyncFailedCount = 0
    kubernetesReportSyncSourceReportResult = "ready"
    stageCount = 7
    readyStageCount = 7
    finalizerGapCount = 0
    currentBottleneck = [ordered]@{
        code = "none"
        title = "None"
        reason = "Tampered fixture uses string sync boolean."
    }
    recommendedCommands = @()
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stringBoolSyncConvergenceSnapshotPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringBoolSyncOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -HandoffStartedAt "2026-06-20T02:00:00Z" `
        -HandoffCompletedAt "2026-06-20T02:30:00Z" `
        -ChangeApprovalRef "CHG-2026-OPERATIONS-HANDOFF-SELF-TEST" `
        -DeploymentEvidenceRef "deployment-release-run-20260620" `
        -OperationsReadinessRef "latest-operations-readiness-ready-20260620" `
        -OperationsConvergenceRef "latest-operations-readiness-convergence-ready-20260620" `
        -OperationsReadinessJsonPath $readinessSnapshotPath `
        -OperationsConvergenceJsonPath $stringBoolSyncConvergenceSnapshotPath `
        -RunbookReviewRef "operator-runbook-review-20260620" `
        -TroubleshootingReviewRef "troubleshooting-review-20260620" `
        -SupportEscalationRef "support-escalation-ticket-20260620" `
        -SupportSlaRef "support-sla-contract-20260620" `
        -KnownGapsRef "known-gaps-acceptance-20260620" `
        -ConfirmRunbookReviewed `
        -ConfirmTroubleshootingReviewed `
        -ConfirmRollbackReviewed `
        -ConfirmSupportEscalationReviewed `
        -ConfirmKnownGapsAccepted `
        -ConfirmOperationsReadinessSnapshotReviewed `
        -ConfirmOperationsConvergenceSnapshotReviewed `
        -ConfirmNoSecretValues `
        -RequireOperationsSnapshotEvidence `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringBoolSyncExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringBoolSyncExitCode -ne 0) "Convergence snapshot with string Kubernetes sync boolean should be rejected."
Assert-Contains ($stringBoolSyncOutput | Out-String) "kubernetesReportSyncReady=true(valid=False)" "string sync boolean convergence output"

$missingGapConvergencePayload = [ordered]@{
    formatVersion = "osmu.operations-readiness-convergence.v1"
    result = "ready"
    readinessResult = "ready"
    readinessSummary = "passed=66 pending=0"
    finalizerResult = "ready"
    finalizerReadinessResult = "ready"
    finalizerFailedCount = 0
    kubernetesReportSyncReady = $true
    kubernetesReportSyncResult = "applied"
    kubernetesReportSyncFailedCount = 0
    kubernetesReportSyncSourceReportResult = "ready"
    stageCount = 7
    readyStageCount = 7
    finalizerGapCount = 0
    currentBottleneck = [ordered]@{
        code = "none"
        title = "None"
        reason = "Tampered fixture omits finalizer gap count after object creation."
    }
    recommendedCommands = @()
}
$missingGapConvergencePayload.Remove("finalizerGapCount")
$missingGapConvergenceSnapshotPath = Join-Path $resolvedOutputDirectory "missing-gap-operations-readiness-convergence.json"
$missingGapConvergencePayload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $missingGapConvergenceSnapshotPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingGapOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -HandoffStartedAt "2026-06-20T02:00:00Z" `
        -HandoffCompletedAt "2026-06-20T02:30:00Z" `
        -ChangeApprovalRef "CHG-2026-OPERATIONS-HANDOFF-SELF-TEST" `
        -DeploymentEvidenceRef "deployment-release-run-20260620" `
        -OperationsReadinessRef "latest-operations-readiness-ready-20260620" `
        -OperationsConvergenceRef "latest-operations-readiness-convergence-ready-20260620" `
        -OperationsReadinessJsonPath $readinessSnapshotPath `
        -OperationsConvergenceJsonPath $missingGapConvergenceSnapshotPath `
        -RunbookReviewRef "operator-runbook-review-20260620" `
        -TroubleshootingReviewRef "troubleshooting-review-20260620" `
        -SupportEscalationRef "support-escalation-ticket-20260620" `
        -SupportSlaRef "support-sla-contract-20260620" `
        -KnownGapsRef "known-gaps-acceptance-20260620" `
        -ConfirmRunbookReviewed `
        -ConfirmTroubleshootingReviewed `
        -ConfirmRollbackReviewed `
        -ConfirmSupportEscalationReviewed `
        -ConfirmKnownGapsAccepted `
        -ConfirmOperationsReadinessSnapshotReviewed `
        -ConfirmOperationsConvergenceSnapshotReviewed `
        -ConfirmNoSecretValues `
        -RequireOperationsSnapshotEvidence `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $missingGapExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingGapExitCode -ne 0) "Convergence snapshot with missing finalizer gap count should be rejected."
Assert-Contains ($missingGapOutput | Out-String) "finalizerGaps=<missing>(valid=False)" "missing finalizer gap convergence output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -KnownGapsRef "password=super-secret" `
        -NoWrite 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Credential-like evidence reference should be rejected."

$unsafeReadinessSnapshotPath = Join-Path $resolvedOutputDirectory "unsafe-operations-readiness.json"
'{"formatVersion":"osmu.operations-readiness.v1","result":"ready","password":"super-secret"}' | Set-Content -LiteralPath $unsafeReadinessSnapshotPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeSnapshotOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -OperationsReadinessJsonPath $unsafeReadinessSnapshotPath `
        -RequireOperationsSnapshotEvidence `
        -NoWrite 2>&1
    $unsafeSnapshotExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeSnapshotExitCode -ne 0) "Credential-like operations readiness snapshot should be rejected."
Assert-Contains ($unsafeSnapshotOutput | Out-String) "credential material" "unsafe snapshot output"

$unsafeRawReadinessSnapshotPath = Join-Path $resolvedOutputDirectory "unsafe-raw-operations-readiness.json"
[ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "ready"
    rawProviderResponse = [ordered]@{
        statusCode = 200
        body = "customer@example.com approved contractText"
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $unsafeRawReadinessSnapshotPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeRawSnapshotOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -OperationsReadinessJsonPath $unsafeRawReadinessSnapshotPath `
        -RequireOperationsSnapshotEvidence `
        -NoWrite 2>&1
    $unsafeRawSnapshotExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeRawSnapshotExitCode -ne 0) "Raw provider/customer operations readiness snapshot should be rejected."
Assert-Contains ($unsafeRawSnapshotOutput | Out-String) "raw remediation, provider, customer" "unsafe raw snapshot output"

$unsafeDataFlowStoragePlanPath = Join-Path $resolvedOutputDirectory "unsafe-data-flow-storage-plan.json"
'{"formatVersion":"osmu.data-flow-storage-plan.v1","result":"passed","rawSql":"SELECT * FROM data_flow_events"}' | Set-Content -LiteralPath $unsafeDataFlowStoragePlanPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeDataFlowStoragePlanOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -DataFlowStoragePlanEvidenceRef "latest-data-flow-storage-plan-passed-20260620" `
        -DataFlowStoragePlanJsonPath $unsafeDataFlowStoragePlanPath `
        -ConfirmDataFlowStoragePlanReviewed `
        -NoWrite 2>&1
    $unsafeDataFlowStoragePlanExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeDataFlowStoragePlanExitCode -ne 0) "Raw SQL data-flow storage plan snapshot should be rejected."
Assert-Contains ($unsafeDataFlowStoragePlanOutput | Out-String) "raw SQL" "unsafe data-flow storage plan output"

$unsafeDataFlowStorageTransitionRunbookPath = Join-Path $resolvedOutputDirectory "unsafe-data-flow-storage-transition-runbook.json"
'{"formatVersion":"osmu.data-flow-storage-transition-runbook-evidence.v1","result":"passed","summary":{"failureCount":0},"rawSql":"SELECT * FROM data_flow_events"}' | Set-Content -LiteralPath $unsafeDataFlowStorageTransitionRunbookPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeDataFlowStorageTransitionRunbookOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -DataFlowStorageTransitionRunbookEvidenceRef "latest-data-flow-storage-transition-runbook-passed-20260620" `
        -DataFlowStorageTransitionRunbookJsonPath $unsafeDataFlowStorageTransitionRunbookPath `
        -ConfirmDataFlowStorageTransitionRunbookReviewed `
        -NoWrite 2>&1
    $unsafeDataFlowStorageTransitionRunbookExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeDataFlowStorageTransitionRunbookExitCode -ne 0) "Raw SQL data-flow storage transition runbook snapshot should be rejected."
Assert-Contains ($unsafeDataFlowStorageTransitionRunbookOutput | Out-String) "raw SQL" "unsafe data-flow storage transition runbook output"

$unsafeSecretRotationPath = Join-Path $resolvedOutputDirectory "unsafe-secret-rotation.json"
'{"formatVersion":"osmu.secret-rotation-evidence.v1","result":"passed","secretValue":"super-secret"}' | Set-Content -LiteralPath $unsafeSecretRotationPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeSecretRotationOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -SecretRotationEvidenceRef "latest-secret-rotation-evidence-passed-20260620" `
        -SecretRotationJsonPath $unsafeSecretRotationPath `
        -ConfirmSecretRotationSnapshotReviewed `
        -NoWrite 2>&1
    $unsafeSecretRotationExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeSecretRotationExitCode -ne 0) "Raw secret rotation snapshot should be rejected."
Assert-Contains ($unsafeSecretRotationOutput | Out-String) "raw secret" "unsafe secret rotation output"

$unsafeCommercialApprovalPath = Join-Path $resolvedOutputDirectory "unsafe-commercial-approval.json"
'{"formatVersion":"osmu.commercial-approval-evidence.v1","result":"passed","rawPriceTable":{"enterprise":"1000000"},"checks":[]}' | Set-Content -LiteralPath $unsafeCommercialApprovalPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeCommercialApprovalOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -CommercialApprovalEvidenceRef "latest-commercial-approval-evidence-passed-20260620" `
        -CommercialApprovalJsonPath $unsafeCommercialApprovalPath `
        -NoWrite 2>&1
    $unsafeCommercialApprovalExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeCommercialApprovalExitCode -ne 0) "Raw price table commercial approval snapshot should be rejected."
Assert-Contains ($unsafeCommercialApprovalOutput | Out-String) "raw remediation, provider, customer" "unsafe commercial approval output"

$unsafeEnterpriseAuthPath = Join-Path $resolvedOutputDirectory "unsafe-enterprise-auth-smoke.json"
'{"formatVersion":"osmu.enterprise-auth-smoke.v1","result":"passed","rawClaimJson":{"email":"user@example.com"},"summary":{"passCount":1},"checks":[]}' | Set-Content -LiteralPath $unsafeEnterpriseAuthPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeEnterpriseAuthOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnterpriseAuthEvidenceRef "latest-enterprise-auth-smoke-passed-20260620" `
        -EnterpriseAuthJsonPath $unsafeEnterpriseAuthPath `
        -NoWrite 2>&1
    $unsafeEnterpriseAuthExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeEnterpriseAuthExitCode -ne 0) "Raw claim enterprise auth smoke snapshot should be rejected."
Assert-Contains ($unsafeEnterpriseAuthOutput | Out-String) "identity, or credential" "unsafe enterprise auth output"

$unsafeMonitoringThresholdPath = Join-Path $resolvedOutputDirectory "unsafe-monitoring-threshold.json"
'{"formatVersion":"osmu.monitoring-threshold-evidence.v1","result":"passed","receiverSecret":"webhook_secret=super-secret","summary":{"failureCount":0},"checks":[]}' | Set-Content -LiteralPath $unsafeMonitoringThresholdPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeMonitoringThresholdOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -MonitoringEvidenceRef "prometheus-alertmanager-grafana-review-20260620" `
        -MonitoringThresholdJsonPath $unsafeMonitoringThresholdPath `
        -NoWrite 2>&1
    $unsafeMonitoringThresholdExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeMonitoringThresholdExitCode -ne 0) "Raw receiver secret monitoring threshold snapshot should be rejected."
Assert-Contains ($unsafeMonitoringThresholdOutput | Out-String) "credential material" "unsafe monitoring threshold output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingSnapshotOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -HandoffStartedAt "2026-06-20T02:00:00Z" `
        -HandoffCompletedAt "2026-06-20T02:30:00Z" `
        -ChangeApprovalRef "CHG-2026-OPERATIONS-HANDOFF-SELF-TEST" `
        -DeploymentEvidenceRef "deployment-release-run-20260620" `
        -OperationsReadinessRef "latest-operations-readiness-ready-20260620" `
        -OperationsConvergenceRef "latest-operations-readiness-convergence-ready-20260620" `
        -RunbookReviewRef "operator-runbook-review-20260620" `
        -TroubleshootingReviewRef "troubleshooting-review-20260620" `
        -SupportEscalationRef "support-escalation-ticket-20260620" `
        -SupportSlaRef "support-sla-contract-20260620" `
        -KnownGapsRef "known-gaps-acceptance-20260620" `
        -ConfirmRunbookReviewed `
        -ConfirmTroubleshootingReviewed `
        -ConfirmRollbackReviewed `
        -ConfirmSupportEscalationReviewed `
        -ConfirmKnownGapsAccepted `
        -ConfirmNoSecretValues `
        -RequireOperationsSnapshotEvidence `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $missingSnapshotExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingSnapshotExitCode -ne 0) "Required operations snapshots should fail when absent."
Assert-Contains ($missingSnapshotOutput | Out-String) "Operations readiness snapshot parsed" "missing snapshot output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidWindowOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -HandoffStartedAt "2026-06-20T02:30:00Z" `
        -HandoffCompletedAt "2026-06-20T02:00:00Z" `
        -ChangeApprovalRef "CHG-2026-OPERATIONS-HANDOFF-SELF-TEST" `
        -DeploymentEvidenceRef "deployment-release-run-20260620" `
        -OperationsReadinessRef "latest-operations-readiness-ready-20260620" `
        -OperationsConvergenceRef "latest-operations-readiness-convergence-ready-20260620" `
        -DataFlowStoragePlanEvidenceRef "latest-data-flow-storage-plan-passed-20260620" `
        -DataFlowStorageTransitionRunbookEvidenceRef "latest-data-flow-storage-transition-runbook-passed-20260620" `
        -DataFlowStoragePlanJsonPath $dataFlowStoragePlanPath `
        -DataFlowStorageTransitionRunbookJsonPath $dataFlowStorageTransitionRunbookPath `
        -SecretRotationEvidenceRef "latest-secret-rotation-evidence-passed-20260620" `
        -SecretRotationJsonPath $secretRotationPath `
        -CommercialIntegrationEvidenceRef "latest-commercial-integration-evidence-passed-20260620" `
        -CommercialApprovalEvidenceRef "latest-commercial-approval-evidence-passed-20260620" `
        -CommercialIntegrationJsonPath $commercialIntegrationPath `
        -CommercialApprovalJsonPath $commercialApprovalPath `
        -EnterpriseAuthEvidenceRef "latest-enterprise-auth-smoke-passed-20260620" `
        -EnterpriseAuthJsonPath $enterpriseAuthPath `
        -BackupRestoreEvidenceRef "latest-kubernetes-dr-finalize-ready-20260620" `
        -HaDrEvidenceRef "latest-kubernetes-ha-dr-readiness-passed-20260620" `
        -MonitoringEvidenceRef "prometheus-alertmanager-grafana-review-20260620" `
        -MonitoringThresholdJsonPath $monitoringThresholdPath `
        -SecurityEvidenceRef "latest-security-evidence-finalize-passed-20260620" `
        -IamRbacEvidenceRef "latest-iam-rbac-finalize-passed-20260620" `
        -RunbookReviewRef "operator-runbook-review-20260620" `
        -TroubleshootingReviewRef "troubleshooting-review-20260620" `
        -SupportEscalationRef "support-escalation-ticket-20260620" `
        -SupportSlaRef "support-sla-contract-20260620" `
        -KnownGapsRef "known-gaps-acceptance-20260620" `
        -ConfirmRunbookReviewed `
        -ConfirmTroubleshootingReviewed `
        -ConfirmRollbackReviewed `
        -ConfirmSupportEscalationReviewed `
        -ConfirmKnownGapsAccepted `
        -ConfirmDataFlowStoragePlanReviewed `
        -ConfirmDataFlowStorageTransitionRunbookReviewed `
        -ConfirmSecretRotationSnapshotReviewed `
        -ConfirmCommercialIntegrationSnapshotReviewed `
        -ConfirmCommercialApprovalSnapshotReviewed `
        -ConfirmEnterpriseAuthSmokeSnapshotReviewed `
        -ConfirmMonitoringThresholdReviewed `
        -ConfirmNoSecretValues `
        -RequireProductionEvidence `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidWindowExitCode -ne 0) "Reversed handoff window should be rejected."
Assert-Contains ($invalidWindowOutput | Out-String) "Handoff window order valid" "invalid handoff window output"

Write-Host "Operations handoff package writer verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
