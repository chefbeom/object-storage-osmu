param(
    [string] $OutputDirectory = ".\.osmu-run\operations-artifact-collection-plan-self-test"
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

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$fixturePath = Join-Path $resolvedOutputDirectory "fixture-operations-evidence-plan-invocation.json"
$missingJsonOutputPath = Join-Path $resolvedOutputDirectory "missing-operations-artifact-collection-plan.json"
$missingMarkdownOutputPath = Join-Path $resolvedOutputDirectory "missing-operations-artifact-collection-plan.md"
$directManualFixturePath = Join-Path $resolvedOutputDirectory "fixture-direct-manual-workflows-invocation.json"
$directManualJsonOutputPath = Join-Path $resolvedOutputDirectory "direct-manual-operations-artifact-collection-plan.json"
$directManualMarkdownOutputPath = Join-Path $resolvedOutputDirectory "direct-manual-operations-artifact-collection-plan.md"
$readyJsonOutputPath = Join-Path $resolvedOutputDirectory "ready-operations-artifact-collection-plan.json"
$readyMarkdownOutputPath = Join-Path $resolvedOutputDirectory "ready-operations-artifact-collection-plan.md"

$commands = @(
    "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true",
    "gh workflow run kubernetes-ha-dr-readiness-ci.yml -f run_live=true",
    "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true",
    "gh workflow run image-publish-sign-ci.yml -f version=v0.1.0-rc.1 -f publish=true",
    "gh workflow run container-security-ci.yml",
    "gh workflow run security-evidence-finalizer-ci.yml -f fail_if_not_passed=true",
    "gh workflow run manual-storage-backend-telemetry-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f minio_alias=osmu-minio -f evidence_ref=storage-telemetry-20260620 -f fail_if_not_passed=true",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-secret-rotation-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -RotationStartedAt 2026-06-20T00:00:00Z -RotationCompletedAt 2026-06-20T00:30:00Z -ChangeApprovalRef secret-rotation-20260620 -SecretManagerEvidenceRef vault-audit-20260620 -WorkloadRestartEvidenceRef rollout-20260620 -SmokeEvidenceRef smoke-20260620 -ArtifactLeakReviewEvidenceRef leak-review-20260620 -AccessKeyEncryptionDecisionRef access-key-decision-20260620 -RotateAdminPassword -RotateJwtSigningSecret -RotateDatabaseCredentials -RotateMinioRootCredentials -RotateTlsCertificate -ConfirmNoSecretValues -ConfirmWorkloadRestart -ConfirmSmokePassed -ConfirmArtifactLeakReview -RequireAllCoreSecrets -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-integration-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -VerificationStartedAt 2026-06-20T00:30:00Z -VerificationCompletedAt 2026-06-20T01:00:00Z -ChangeApprovalRef commercial-integration-20260620 -NotificationWebhookEvidenceRef notification-webhook-20260620 -SlackWebhookEvidenceRef slack-webhook-20260620 -EmailSmtpEvidenceRef email-smtp-20260620 -PaymentGenericWebhookEvidenceRef payment-generic-20260620 -PaymentCardProfileEvidenceRef payment-card-20260620 -PaymentBankProfileEvidenceRef payment-bank-20260620 -PaymentTaxProfileEvidenceRef payment-tax-20260620 -PaymentErpProfileEvidenceRef payment-erp-20260620 -PaymentProviderAdapterReadinessEvidenceRef payment-adapter-readiness-20260620 -PaymentProviderAdapterReadinessJsonPath .\.osmu-run\payment-provider-adapter-readiness.json -AdapterRetryWorkerEvidenceRef adapter-retry-20260620 -PayloadReviewEvidenceRef payload-review-20260620 -PrivateNetworkBlockEvidenceRef private-block-20260620 -HmacSignatureEvidenceRef hmac-review-20260620 -VerifiedNotificationWebhook -VerifiedSlackWebhook -VerifiedEmailSmtp -VerifiedPaymentGenericWebhook -VerifiedPaymentCardProfile -VerifiedPaymentBankProfile -VerifiedPaymentTaxProfile -VerifiedPaymentErpProfile -ConfirmPaymentProviderAdapterReadinessReviewed -ConfirmAdapterRetryWorkerRun -ConfirmPayloadSizeCaps -ConfirmPrivateNetworkBlocking -ConfirmHmacSignatureHeaders -ConfirmNoSecretValues -ConfirmNoRawProviderResponses -RequireAllImplementedAdapters -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-approval-evidence.ps1 -ProductVersion v0.1.0-rc.1 -ApprovalRef approval-20260620 -ApprovedBy commercial-owner -ApprovedAt 2026-06-20T00:00:00Z -PricingApprovalRef pricing-20260620 -TermsApprovalRef terms-20260620 -SupportSlaApprovalRef sla-20260620 -LicenseAgreementRef license-20260620 -LegalApprovalRef legal-20260620 -PilotContractRef pilot-contract-20260620 -PricingPolicyProposalEvidenceRef pricing-proposal-commercial-approval-20260620 -PricingPolicyProposalJsonPath .\.osmu-run\billing-pricing-policy-proposals.json -ConfirmPricingApproved -ConfirmTermsApproved -ConfirmSupportSlaApproved -ConfirmLicenseApproved -ConfirmLegalApproved -ConfirmPricingPolicyProposalCommercialApproval -RequirePricingPolicyProposalApprovalSnapshot -ConfirmNoSecretValues -FailIfNotPassed",
    "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f require_oidc=true -f require_ldap=true",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-handoff-package.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -HandoffStartedAt 2026-06-20T01:00:00Z -HandoffCompletedAt 2026-06-20T02:00:00Z -ChangeApprovalRef change-20260620 -DeploymentEvidenceRef deploy-20260620 -OperationsReadinessRef readiness-20260620 -OperationsConvergenceRef convergence-20260620 -OperationsReadinessJsonPath .\.osmu-run\latest-operations-readiness.json -OperationsConvergenceJsonPath .\.osmu-run\latest-operations-readiness-convergence.json -SecretRotationEvidenceRef secret-rotation-20260620 -CommercialIntegrationEvidenceRef commercial-integration-20260620 -CommercialApprovalEvidenceRef commercial-approval-20260620 -EnterpriseAuthEvidenceRef enterprise-auth-20260620 -BackupRestoreEvidenceRef backup-restore-20260620 -HaDrEvidenceRef ha-dr-20260620 -MonitoringEvidenceRef monitoring-20260620 -SecurityEvidenceRef security-20260620 -IamRbacEvidenceRef iam-rbac-20260620 -RunbookReviewRef runbook-20260620 -TroubleshootingReviewRef troubleshooting-20260620 -SupportEscalationRef support-escalation-20260620 -SupportSlaRef support-sla-20260620 -KnownGapsRef known-gaps-20260620 -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackReviewed -ConfirmSupportEscalationReviewed -ConfirmKnownGapsAccepted -ConfirmOperationsReadinessSnapshotReviewed -ConfirmOperationsConvergenceSnapshotReviewed -ConfirmNoSecretValues -RequireProductionEvidence -RequireOperationsSnapshotEvidence -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-storage-plan.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -CandidateStore MARIADB_PARTITION -ExpectedPeakEventsPerDay 100000 -ExpectedQueryWindowDays 180 -TargetP95QueryLatencyMs 500 -EvidenceRef data-flow-plan-20260620 -ConfirmNoObjectKeyInAggregates -ConfirmBackfillPlan -ConfirmRollbackPlan -ConfirmDashboardCutoverPlan -ConfirmRetentionJobBudget -ConfirmExplainEvidence -QueryPlanEvidenceJsonPath .\.osmu-run\latest-mariadb-query-plan-evidence.json -RequireQueryPlanEvidence -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-storage-transition-runbook-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -ReviewStartedAt 2026-06-20T02:00:00Z -ReviewCompletedAt 2026-06-20T02:30:00Z -ChangeApprovalRef data-flow-runbook-change-20260620 -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -DataFlowStoragePlanEvidenceRef data-flow-plan-20260620 -BackfillEvidenceRef backfill-20260620 -DualWriteOrPartitionToggleEvidenceRef dual-write-20260620 -RollbackEvidenceRef rollback-20260620 -ReconciliationEvidenceRef reconciliation-20260620 -DashboardCutoverEvidenceRef dashboard-cutover-20260620 -RetentionDryRunEvidenceRef retention-dry-run-20260620 -EvidenceRef data-flow-runbook-20260620 -ConfirmBackfillRehearsed -ConfirmDualWriteOrPartitionToggleReviewed -ConfirmRollbackRehearsed -ConfirmReconciliationPassed -ConfirmDashboardCutoverReviewed -ConfirmRetentionDryRunReviewed -ConfirmNoObjectKeysInAggregates -ConfirmNoSecretValues -FailIfNotPassed",
    "gh workflow run kubernetes-operations-report-sync-ci.yml -f run_live=true -f apply=true"
)
$actions = New-Object System.Collections.Generic.List[object]
$order = 1
foreach ($command in $commands) {
    $actions.Add([ordered]@{
        order = $order
        name = "Action $order"
        category = "operations"
        actionType = "workflow"
        evidencePath = ".osmu-run/action-$order.json"
        commandMode = "Workflow"
        command = $command
        status = "planned"
        blockReasons = @()
        unresolvedPlaceholders = @()
        requiresOperatorApproval = $false
        requiresKubeconfigSecret = $false
    })
    $order++
}

$fixture = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = "planned"
    sourcePlan = ".osmu-run/latest-operations-evidence-plan.json"
    sourceSummary = "passed=36 pending=6"
    commandMode = "Workflow"
    executionMode = "plan-only"
    selectedActionCount = $actions.Count
    plannedCount = $actions.Count
    blockedCount = 0
    executedCount = 0
    failedCount = 0
    actions = @($actions | ForEach-Object { $_ })
}
$fixture | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $fixturePath -Encoding UTF8

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-artifact-collection-plan.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $fixturePath `
    -JsonOutputPath $missingJsonOutputPath `
    -MarkdownOutputPath $missingMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-artifact-collection-plan.ps1 missing-run-id check failed with exit code $LASTEXITCODE."
}

$missingReport = Get-Content -Raw -LiteralPath $missingJsonOutputPath | ConvertFrom-Json
$missingMarkdown = Get-Content -Raw -LiteralPath $missingMarkdownOutputPath
Assert-True ($missingReport.formatVersion -eq "osmu.operations-artifact-collection-plan.v1") "Unexpected collection plan formatVersion."
Assert-True ($missingReport.result -eq "action-required") "Expected action-required result without run ids."
Assert-True ($missingReport.artifactCount -eq 15) "Expected fifteen inferred artifacts."
Assert-True ($missingReport.requiredArtifactCount -eq 13) "Expected thirteen required readiness/convergence artifacts."
Assert-True ($missingReport.missingRequiredArtifactCount -eq 13) "Expected thirteen missing required artifacts."
Assert-Contains $missingMarkdown "storage-expansion-finalizer-<storage-expansion-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "storage-backend-telemetry-evidence-<storage-backend-telemetry-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-storage-backend-telemetry-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "secret-rotation-evidence-<secret-rotation-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-secret-rotation-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-commercial-integration-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-commercial-approval-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-operations-handoff-package.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "commercial-integration-evidence-<commercial-integration-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "commercial-approval-evidence-<commercial-approval-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "enterprise-auth-smoke-<enterprise-auth-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "contractual scope-out evidence" "missing collection markdown"
Assert-Contains $missingMarkdown "operations-handoff-package-<operations-handoff-package-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "data-flow-storage-plan-evidence-<data-flow-storage-plan-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-data-flow-storage-plan-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "data-flow-storage-transition-runbook-evidence-<data-flow-storage-transition-runbook-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-data-flow-storage-transition-runbook-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "operations-readiness-artifact-finalizer-ci.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "optional latest-data-flow-storage-plan.json" "missing collection markdown"
Assert-Contains $missingMarkdown "data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>" "missing collection markdown"
Assert-Contains $missingMarkdown "data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>" "missing collection markdown"
Assert-Contains $missingMarkdown "sanitized query-plan evidence summary" "missing collection markdown"
Assert-Contains $missingMarkdown ".\.osmu-run\operations-readiness-artifacts\storage-expansion" "missing collection markdown"
Assert-True (-not $missingMarkdown.Contains("OrderedDictionary.downloadPath")) "Local import command should render concrete download paths."

$directManualCommands = @(
    "gh workflow run manual-secret-rotation-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-commercial-integration-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-commercial-approval-evidence.yml -f product_version=v0.1.0-rc.1 -f approval_ref=approval-20260620 -f approved_by=commercial-owner -f fail_if_not_passed=true",
    "gh workflow run manual-operations-handoff-package.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-data-flow-storage-transition-runbook-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true"
)
$directManualActions = New-Object System.Collections.Generic.List[object]
$directManualOrder = 1
foreach ($command in $directManualCommands) {
    $directManualActions.Add([ordered]@{
        order = $directManualOrder
        name = "Direct manual workflow $directManualOrder"
        category = "operations"
        actionType = "workflow"
        evidencePath = ".osmu-run/direct-manual-$directManualOrder.json"
        commandMode = "Workflow"
        command = $command
        status = "planned"
        blockReasons = @()
        unresolvedPlaceholders = @()
        requiresOperatorApproval = $false
        requiresKubeconfigSecret = $false
    })
    $directManualOrder++
}
$directManualFixture = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = "planned"
    sourcePlan = ".osmu-run/direct-manual-operations-evidence-plan.json"
    sourceSummary = "passed=36 pending=4"
    commandMode = "Workflow"
    executionMode = "plan-only"
    selectedActionCount = $directManualActions.Count
    plannedCount = $directManualActions.Count
    blockedCount = 0
    executedCount = 0
    failedCount = 0
    actions = @($directManualActions | ForEach-Object { $_ })
}
$directManualFixture | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $directManualFixturePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $directManualFixturePath `
    -JsonOutputPath $directManualJsonOutputPath `
    -MarkdownOutputPath $directManualMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-artifact-collection-plan.ps1 direct-manual-workflow check failed with exit code $LASTEXITCODE."
}

$directManualReport = Get-Content -Raw -LiteralPath $directManualJsonOutputPath | ConvertFrom-Json
$directManualMarkdown = Get-Content -Raw -LiteralPath $directManualMarkdownOutputPath
Assert-True ($directManualReport.result -eq "action-required") "Expected action-required result for direct manual workflow dispatches without run ids."
Assert-True ($directManualReport.artifactCount -eq 5) "Expected five artifacts from direct manual workflow dispatches."
Assert-True ($directManualReport.requiredArtifactCount -eq 5) "Expected five required artifacts from direct manual workflow dispatches."
Assert-True ($directManualReport.missingRequiredArtifactCount -eq 5) "Expected five missing direct manual workflow artifacts."
Assert-Contains $directManualMarkdown "manual-secret-rotation-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "secret_rotation_run_id=<secret-rotation-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-commercial-integration-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "commercial_integration_run_id=<commercial-integration-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-commercial-approval-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "commercial_approval_run_id=<commercial-approval-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-operations-handoff-package.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "operations_handoff_package_run_id=<operations-handoff-package-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-data-flow-storage-transition-runbook-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "data_flow_storage_transition_runbook_run_id=<data-flow-storage-transition-runbook-run-id>" "direct manual collection markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $fixturePath `
    -JsonOutputPath $readyJsonOutputPath `
    -MarkdownOutputPath $readyMarkdownOutputPath `
    -StorageExpansionRunId "101" `
    -HaDrReadinessRunId "102" `
    -KubernetesDrRunId "103" `
    -ImageSigningRunId "104" `
    -ContainerSecurityRunId "105" `
    -SecurityEvidenceRunId "106" `
    -StorageBackendTelemetryRunId "107" `
    -SecretRotationRunId "108" `
    -CommercialIntegrationRunId "109" `
    -CommercialApprovalRunId "110" `
    -EnterpriseAuthRunId "111" `
    -OperationsHandoffPackageRunId "112" `
    -DataFlowStoragePlanRunId "113" `
    -DataFlowStorageTransitionRunbookRunId "114" `
    -KubernetesOperationsReportSyncRunId "115" `
    -ImageSigningVersion "v0.1.0-rc.1" `
    -CommitSha "abc123" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-artifact-collection-plan.ps1 ready check failed with exit code $LASTEXITCODE."
}

$readyReport = Get-Content -Raw -LiteralPath $readyJsonOutputPath | ConvertFrom-Json
$readyMarkdown = Get-Content -Raw -LiteralPath $readyMarkdownOutputPath
Assert-True ($readyReport.result -eq "ready") "Expected ready result when all required run ids are supplied."
Assert-True ($readyReport.missingRequiredArtifactCount -eq 0) "Expected no missing required artifacts."
Assert-True ($readyReport.readyArtifactCount -eq 15) "Expected all artifacts to be concrete."
Assert-Contains $readyMarkdown "storage_expansion_run_id=101" "ready collection markdown"
Assert-Contains $readyMarkdown "security_evidence_run_id=106" "ready collection markdown"
Assert-Contains $readyMarkdown "storage_backend_telemetry_run_id=107" "ready collection markdown"
Assert-Contains $readyMarkdown "secret_rotation_run_id=108" "ready collection markdown"
Assert-Contains $readyMarkdown "commercial_integration_run_id=109" "ready collection markdown"
Assert-Contains $readyMarkdown "commercial_approval_run_id=110" "ready collection markdown"
Assert-Contains $readyMarkdown "enterprise_auth_run_id=111" "ready collection markdown"
Assert-Contains $readyMarkdown "operations_handoff_package_run_id=112" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_storage_plan_run_id=113" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_storage_transition_runbook_run_id=114" "ready collection markdown"
Assert-Contains $readyMarkdown "kubernetes_operations_report_sync_run_id=115" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>" "ready collection markdown"
Assert-Contains $readyMarkdown "osmu-image-signing-v0.1.0-rc.1-abc123" "ready collection markdown"
Assert-Contains $readyMarkdown "osmu-container-security-abc123" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 106 -n security-evidence-finalizer-106" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 107 -n storage-backend-telemetry-evidence-107" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 108 -n secret-rotation-evidence-108" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 109 -n commercial-integration-evidence-109" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 110 -n commercial-approval-evidence-110" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 111 -n enterprise-auth-smoke-111" "ready collection markdown"
Assert-Contains $readyMarkdown "contractual scope-out evidence" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 112 -n operations-handoff-package-112" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 113 -n data-flow-storage-plan-evidence-113" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 114 -n data-flow-storage-transition-runbook-evidence-114" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 115 -n kubernetes-operations-report-sync-115" "ready collection markdown"
Assert-Contains $readyMarkdown "-StorageBackendTelemetryArtifactPath .\.osmu-run\operations-readiness-artifacts\storage-backend-telemetry" "ready collection markdown"
Assert-Contains $readyMarkdown "-SecretRotationArtifactPath .\.osmu-run\operations-readiness-artifacts\secret-rotation" "ready collection markdown"
Assert-Contains $readyMarkdown "-CommercialIntegrationArtifactPath .\.osmu-run\operations-readiness-artifacts\commercial-integration" "ready collection markdown"
Assert-Contains $readyMarkdown "-CommercialApprovalArtifactPath .\.osmu-run\operations-readiness-artifacts\commercial-approval" "ready collection markdown"
Assert-Contains $readyMarkdown "-OperationsHandoffPackageArtifactPath .\.osmu-run\operations-readiness-artifacts\operations-handoff-package" "ready collection markdown"
Assert-Contains $readyMarkdown "-DataFlowStoragePlanArtifactPath .\.osmu-run\operations-readiness-artifacts\data-flow-storage-plan" "ready collection markdown"
Assert-Contains $readyMarkdown "-DataFlowStorageTransitionRunbookArtifactPath .\.osmu-run\operations-readiness-artifacts\data-flow-storage-transition-runbook" "ready collection markdown"

Write-Host "Operations artifact collection plan verified."
Write-Host "Missing report: $missingJsonOutputPath"
Write-Host "Ready report: $readyJsonOutputPath"
