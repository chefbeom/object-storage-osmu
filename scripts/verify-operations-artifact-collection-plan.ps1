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

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
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
$securityOnlyFixturePath = Join-Path $resolvedOutputDirectory "fixture-security-source-only-invocation.json"
$securityOnlyJsonOutputPath = Join-Path $resolvedOutputDirectory "security-source-only-operations-artifact-collection-plan.json"
$securityOnlyMarkdownOutputPath = Join-Path $resolvedOutputDirectory "security-source-only-operations-artifact-collection-plan.md"

$commands = @(
    "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true",
    "gh workflow run kubernetes-ha-dr-readiness-ci.yml -f run_live=true",
    "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true",
    "gh workflow run image-publish-sign-ci.yml -f version=v0.1.0-rc.1 -f publish=true",
    "gh workflow run container-security-ci.yml",
    "gh workflow run security-evidence-finalizer-ci.yml -f fail_if_not_passed=true",
    "gh workflow run manual-storage-backend-telemetry-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f minio_alias=osmu-minio -f evidence_ref=storage-telemetry-20260620 -f fail_if_not_passed=true",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-minio-bucket-cors.ps1 -BucketName osmu-prod -MinioAlias osmu-minio -CorsXmlPath .\.osmu-run\minio-bucket-cors.xml -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-monitoring-threshold-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -ReviewStartedAt 2026-06-20T03:00:00Z -ReviewCompletedAt 2026-06-20T03:20:00Z -ChangeApprovalRef monitoring-threshold-change-20260620 -PrometheusRulesEvidenceRef prometheus-rules-20260620 -GrafanaDashboardEvidenceRef grafana-dashboard-20260620 -AlertmanagerRouteEvidenceRef alertmanager-route-20260620 -TargetBaselineEvidenceRef target-baseline-20260620 -IncidentRoutingEvidenceRef incident-routing-20260620 -EvidenceRef monitoring-threshold-20260620 -ConfirmPrometheusRulesLoaded -ConfirmGrafanaDashboardImported -ConfirmAlertmanagerRoutesReviewed -ConfirmTargetBaselinesReviewed -ConfirmIncidentRoutingReviewed -ConfirmNoSecretValues -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-cluster-network-access-review-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -ReviewStartedAt 2026-06-20T04:00:00Z -ReviewCompletedAt 2026-06-20T04:20:00Z -ChangeApprovalRef cluster-network-review-change-20260620 -DnsEgressReviewRef dns-egress-review-20260620 -MariaDbAccessReviewRef mariadb-access-review-20260620 -MinioAccessReviewRef minio-access-review-20260620 -BackupAccessReviewRef backup-access-review-20260620 -PublicIngressReviewRef public-ingress-review-20260620 -DefaultDenyReviewRef default-deny-review-20260620 -ObservabilityScrapeReviewRef observability-scrape-review-20260620 -K8sVerifierEvidenceRef k8s-verifier-20260620 -HelmVerifierEvidenceRef helm-verifier-20260620 -EvidenceRef cluster-network-access-review-20260620 -ConfirmBackendOnlyMariaDb -ConfirmBackendOnlyMinio -ConfirmBackupOnlyMariaDbMinio -ConfirmDnsEgressScoped -ConfirmMariaDbIngressBackendBackupOnly -ConfirmMinioIngressBackendBackupOnly -ConfirmPublicIngressLimited -ConfirmNamespaceDefaultDenyReviewed -ConfirmObservabilityScrapeReviewed -ConfirmHelmNetworkPolicyEnabled -ConfirmNoCredentialValues -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-helm-values-hardening-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -ReviewStartedAt 2026-06-20T04:20:00Z -ReviewCompletedAt 2026-06-20T04:40:00Z -ChangeApprovalRef helm-values-hardening-change-20260620 -HelmVerifierEvidenceRef helm-verifier-20260620 -KubernetesVerifierEvidenceRef k8s-verifier-20260620 -ContainerHardeningEvidenceRef container-hardening-20260620 -ClusterNetworkAccessReviewEvidenceRef cluster-network-access-review-20260620 -EvidenceRef helm-values-hardening-20260620 -ConfirmSecretsExternalized -ConfirmDefaultSecretPlaceholdersNotUsed -ConfirmHaReplicasReviewed -ConfirmResourcesBounded -ConfirmSecurityContextsReviewed -ConfirmNetworkPolicyEnabled -ConfirmTlsIngressReviewed -ConfirmOperationsReportsReadOnly -ConfirmStorageExpansionRbacDisabledByDefault -ConfirmNoCredentialValues -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-support-escalation-handoff-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -ReviewStartedAt 2026-06-20T04:40:00Z -ReviewCompletedAt 2026-06-20T05:00:00Z -ChangeApprovalRef support-handoff-change-20260620 -OperationsHandoffPackageRef operations-handoff-package-20260620 -RunbookReviewRef runbook-20260620 -TroubleshootingReviewRef troubleshooting-20260620 -RollbackReviewRef rollback-20260620 -SupportEscalationRef support-escalation-20260620 -SupportSlaRef support-sla-20260620 -KnownGapsRef known-gaps-20260620 -EvidenceRef support-escalation-handoff-20260620 -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackPathReviewed -ConfirmSupportEscalationReviewed -ConfirmSupportSlaReviewed -ConfirmKnownGapsAccepted -ConfirmOperationsHandoffReferenceReady -ConfirmNoCredentialValues -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-secret-rotation-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -RotationStartedAt 2026-06-20T00:00:00Z -RotationCompletedAt 2026-06-20T00:30:00Z -ChangeApprovalRef secret-rotation-20260620 -SecretManagerEvidenceRef vault-audit-20260620 -WorkloadRestartEvidenceRef rollout-20260620 -SmokeEvidenceRef smoke-20260620 -ArtifactLeakReviewEvidenceRef leak-review-20260620 -AccessKeyEncryptionDecisionRef access-key-decision-20260620 -RotateAdminPassword -RotateJwtSigningSecret -RotateDatabaseCredentials -RotateMinioRootCredentials -RotateTlsCertificate -ConfirmNoSecretValues -ConfirmWorkloadRestart -ConfirmSmokePassed -ConfirmArtifactLeakReview -RequireAllCoreSecrets -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-integration-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -VerificationStartedAt 2026-06-20T00:30:00Z -VerificationCompletedAt 2026-06-20T01:00:00Z -ChangeApprovalRef commercial-integration-20260620 -NotificationWebhookEvidenceRef notification-webhook-20260620 -SlackWebhookEvidenceRef slack-webhook-20260620 -EmailSmtpEvidenceRef email-smtp-20260620 -PaymentGenericWebhookEvidenceRef payment-generic-20260620 -PaymentCardProfileEvidenceRef payment-card-20260620 -PaymentBankProfileEvidenceRef payment-bank-20260620 -PaymentTaxProfileEvidenceRef payment-tax-20260620 -PaymentErpProfileEvidenceRef payment-erp-20260620 -PaymentProviderAdapterReadinessEvidenceRef payment-adapter-readiness-20260620 -PaymentProviderAdapterReadinessJsonPath .\.osmu-run\payment-provider-adapter-readiness.json -AdapterRetryWorkerEvidenceRef adapter-retry-20260620 -PayloadReviewEvidenceRef payload-review-20260620 -PrivateNetworkBlockEvidenceRef private-block-20260620 -HmacSignatureEvidenceRef hmac-review-20260620 -VerifiedNotificationWebhook -VerifiedSlackWebhook -VerifiedEmailSmtp -VerifiedPaymentGenericWebhook -VerifiedPaymentCardProfile -VerifiedPaymentBankProfile -VerifiedPaymentTaxProfile -VerifiedPaymentErpProfile -ConfirmPaymentProviderAdapterReadinessReviewed -ConfirmAdapterRetryWorkerRun -ConfirmPayloadSizeCaps -ConfirmPrivateNetworkBlocking -ConfirmHmacSignatureHeaders -ConfirmNoSecretValues -ConfirmNoRawProviderResponses -RequireAllImplementedAdapters -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-approval-evidence.ps1 -ProductVersion v0.1.0-rc.1 -ApprovalRef approval-20260620 -ApprovedBy commercial-owner -ApprovedAt 2026-06-20T00:00:00Z -PricingApprovalRef pricing-20260620 -TermsApprovalRef terms-20260620 -SupportSlaApprovalRef sla-20260620 -LicenseAgreementRef license-20260620 -LegalApprovalRef legal-20260620 -PilotContractRef pilot-contract-20260620 -PricingPolicyProposalEvidenceRef pricing-proposal-commercial-approval-20260620 -PricingPolicyProposalJsonPath .\.osmu-run\billing-pricing-policy-proposals.json -ConfirmPricingApproved -ConfirmTermsApproved -ConfirmSupportSlaApproved -ConfirmLicenseApproved -ConfirmLegalApproved -ConfirmPricingPolicyProposalCommercialApproval -RequirePricingPolicyProposalApprovalSnapshot -ConfirmNoSecretValues -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-chargeback-closeout-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -BillingPeriod 2026-06 -CloseoutStartedAt 2026-06-30T01:00:00Z -CloseoutCompletedAt 2026-06-30T01:45:00Z -ChangeApprovalRef chargeback-closeout-change-20260630 -PricingPolicyEvidenceRef pricing-policy-run-20260630 -PricingProposalApprovalRef pricing-proposal-approval-run-20260630 -ChargebackPreviewEvidenceRef chargeback-preview-run-20260630 -ChargebackTrendExportEvidenceRef chargeback-trend-export-run-20260630 -InvoiceDraftEvidenceRef invoice-draft-run-20260630 -InvoiceFinalizationEvidenceRef invoice-finalization-run-20260630 -PaymentRequestEvidenceRef payment-request-run-20260630 -PaymentProviderHandoffEvidenceRef payment-provider-handoff-run-20260630 -PaymentProviderAdapterReadinessEvidenceRef payment-adapter-readiness-run-20260630 -PaymentProviderAdapterReadinessJsonPath .\.osmu-run\payment-provider-adapter-readiness.json -NotificationDeliveryEvidenceRef notification-delivery-run-20260630 -AdapterRetryWorkerEvidenceRef adapter-retry-worker-run-20260630 -ReconciliationEvidenceRef chargeback-reconciliation-run-20260630 -CommercialIntegrationEvidenceRef commercial-integration-run-20260630 -CommercialApprovalEvidenceRef commercial-approval-run-20260630 -ChargebackCloseoutSnapshotJsonPath .\.osmu-run\chargeback-closeout-summary.json -ConfirmPricingPolicyReviewed -ConfirmPriceListApproved -ConfirmUsageWindowReviewed -ConfirmChargebackPreviewReviewed -ConfirmTrendExportReviewed -ConfirmInvoiceDraftReviewed -ConfirmInvoiceFinalized -ConfirmPaymentRequestReviewed -ConfirmPaymentProviderHandoffReviewed -ConfirmPaymentProviderAdapterReadinessReviewed -ConfirmNotificationDeliveryReviewed -ConfirmAdapterRetryReviewed -ConfirmReconciliationReviewed -ConfirmCommercialIntegrationReviewed -ConfirmCommercialApprovalReviewed -ConfirmNoRawCustomerPaymentData -ConfirmNoRawProviderResponses -ConfirmNoSecretValues -RequirePaymentProviderAdapterReadinessSnapshot -FailIfNotPassed",
    "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f require_oidc=true -f require_ldap=true",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-jit-rollback-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -ReviewStartedAt 2026-06-20T01:10:00Z -ReviewCompletedAt 2026-06-20T01:40:00Z -ChangeApprovalRef enterprise-auth-jit-change-20260620 -EnterpriseAuthSmokeJsonPath .\.osmu-run\latest-enterprise-auth-smoke.json -RequireEnterpriseAuthSmokeEvidence -JitProvisionEvidenceRef jit-provision-20260620 -JitRollbackRunbookRef jit-rollback-runbook-20260620 -UserDisableRollbackEvidenceRef jit-user-disable-20260620 -RoleMappingRollbackEvidenceRef role-org-team-rollback-20260620 -LocalLoginFallbackEvidenceRef local-login-fallback-20260620 -AuditReviewEvidenceRef jit-audit-review-20260620 -EvidenceRef enterprise-auth-jit-rollback-20260620 -ConfirmAdminApprovalRequired -ConfirmCallbackAutoJitDisabled -ConfirmJitUserDisableOrLockRollbackReviewed -ConfirmRoleOrgTeamRollbackReviewed -ConfirmLocalPasswordFallbackValidated -ConfirmAuditEventsReviewed -ConfirmNoRawClaims -ConfirmNoSecretValues -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-handoff-package.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -HandoffStartedAt 2026-06-20T01:00:00Z -HandoffCompletedAt 2026-06-20T02:00:00Z -ChangeApprovalRef change-20260620 -DeploymentEvidenceRef deploy-20260620 -OperationsReadinessRef readiness-20260620 -OperationsConvergenceRef convergence-20260620 -OperationsReadinessJsonPath .\.osmu-run\latest-operations-readiness.json -OperationsConvergenceJsonPath .\.osmu-run\latest-operations-readiness-convergence.json -SecretRotationEvidenceRef secret-rotation-20260620 -CommercialIntegrationEvidenceRef commercial-integration-20260620 -CommercialApprovalEvidenceRef commercial-approval-20260620 -EnterpriseAuthEvidenceRef enterprise-auth-20260620 -BackupRestoreEvidenceRef backup-restore-20260620 -HaDrEvidenceRef ha-dr-20260620 -MonitoringEvidenceRef monitoring-20260620 -SecurityEvidenceRef security-20260620 -IamRbacEvidenceRef iam-rbac-20260620 -RunbookReviewRef runbook-20260620 -TroubleshootingReviewRef troubleshooting-20260620 -SupportEscalationRef support-escalation-20260620 -SupportSlaRef support-sla-20260620 -KnownGapsRef known-gaps-20260620 -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackReviewed -ConfirmSupportEscalationReviewed -ConfirmKnownGapsAccepted -ConfirmOperationsReadinessSnapshotReviewed -ConfirmOperationsConvergenceSnapshotReviewed -ConfirmNoSecretValues -RequireProductionEvidence -RequireOperationsSnapshotEvidence -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-storage-plan.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -CandidateStore MARIADB_PARTITION -ExpectedPeakEventsPerDay 100000 -ExpectedQueryWindowDays 180 -TargetP95QueryLatencyMs 500 -EvidenceRef data-flow-plan-20260620 -ConfirmNoObjectKeyInAggregates -ConfirmBackfillPlan -ConfirmRollbackPlan -ConfirmDashboardCutoverPlan -ConfirmRetentionJobBudget -ConfirmExplainEvidence -QueryPlanEvidenceJsonPath .\.osmu-run\latest-mariadb-query-plan-evidence.json -RequireQueryPlanEvidence -FailIfNotPassed",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-query-retention-budget-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -StoragePlanEvidenceRef data-flow-plan-20260620 -StoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -QueryP95LatencyMs 420 -QueryP99LatencyMs 470 -TargetP95QueryLatencyMs 500 -QuerySampleCount 120 -RetentionDetailedSeconds 20 -RetentionDailySeconds 18 -RetentionMonthlySeconds 12 -RetentionBudgetSeconds 30 -EvidenceRef data-flow-query-retention-20260620 -ConfirmStoragePlanReviewed -ConfirmRetentionJobsReviewed -ConfirmNoRawSql -ConfirmNoObjectKeysInEvidence -ConfirmNoRawEventMessages -ConfirmNoSecretValues -FailIfNotPassed",
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
    sourcePassedCount = 36
    sourcePendingCount = 6
    sourceTotalCount = 42
    sourceCheckCount = 42
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

$missingReport = Read-Utf8Text $missingJsonOutputPath | ConvertFrom-Json
$missingMarkdown = Read-Utf8Text $missingMarkdownOutputPath
Assert-True ($missingReport.formatVersion -eq "osmu.operations-artifact-collection-plan.v1") "Unexpected collection plan formatVersion."
Assert-True ($missingReport.result -eq "action-required") "Expected action-required result without run ids."
Assert-True ($missingReport.artifactCount -eq 23) "Expected twenty-three inferred artifacts."
Assert-True ($missingReport.requiredArtifactCount -eq 20) "Expected twenty required readiness/convergence artifacts."
Assert-True ($missingReport.missingRequiredArtifactCount -eq 20) "Expected twenty missing required artifacts."
Assert-True ($missingReport.securitySourceArtifactCount -eq 2) "Expected two inferred security source artifacts."
Assert-True ($missingReport.readySecuritySourceArtifactCount -eq 0) "Expected no ready security source artifacts without run ids."
Assert-True ($missingReport.missingSecuritySourceArtifactCount -eq 2) "Expected two missing security source artifacts without run ids."
Assert-True (-not [bool] $missingReport.securityEvidenceFinalizerReady) "Expected security evidence finalizer to wait for source artifacts."
Assert-True (@($missingReport.securityEvidenceFinalizerMissingRunIdInputs) -contains "ImageSigningRunId") "Expected missing image signing run id input."
Assert-True (@($missingReport.securityEvidenceFinalizerMissingRunIdInputs) -contains "ContainerSecurityRunId") "Expected missing container security run id input."
$missingFinalizerInputs = @($missingReport.securityEvidenceFinalizerInputs)
$missingImageInput = @($missingFinalizerInputs | Where-Object { $_.name -eq "ImageSigningRunId" } | Select-Object -First 1)
$missingContainerInput = @($missingFinalizerInputs | Where-Object { $_.name -eq "ContainerSecurityRunId" } | Select-Object -First 1)
Assert-True ($missingFinalizerInputs.Count -eq 2) "Expected both security finalizer inputs to be modeled."
Assert-True ($missingImageInput.Count -eq 1) "Expected image signing finalizer input metadata."
Assert-True ($missingContainerInput.Count -eq 1) "Expected container security finalizer input metadata."
Assert-True ($missingImageInput[0].runIdParameter -eq "image_signing_run_id") "Expected image signing run id parameter metadata."
Assert-True ($missingContainerInput[0].runIdParameter -eq "container_security_run_id") "Expected container security run id parameter metadata."
Assert-True (-not [bool] $missingImageInput[0].ready) "Expected image signing finalizer input to need a run id."
Assert-True (-not [bool] $missingContainerInput[0].ready) "Expected container security finalizer input to need a run id."
Assert-True ($missingImageInput[0].artifactName -eq "osmu-image-signing-v0.1.0-rc.1-<commit-sha>") "Expected image signing artifact name metadata."
Assert-True ($missingContainerInput[0].artifactName -eq "osmu-container-security-<commit-sha>") "Expected container security artifact name metadata."
Assert-True ($missingReport.sourceActionCount -eq $actions.Count) "Expected source action count to match invocation actions."
Assert-True ($missingReport.sourceSummary -eq "passed=36 pending=6") "Expected missing report source summary to match invocation."
Assert-True ($missingReport.sourcePassedCount -eq 36) "Expected missing report source passed count."
Assert-True ($missingReport.sourcePendingCount -eq 6) "Expected missing report source pending count."
Assert-True ($missingReport.sourceTotalCount -eq 42) "Expected missing report source total count."
Assert-True ($missingReport.sourceCheckCount -eq 42) "Expected missing report source check count."
Assert-Contains $missingMarkdown "Source summary: passed=36 pending=6" "missing collection markdown source summary"
Assert-Contains $missingMarkdown "Source counts: passed=36 pending=6 total=42 checks=42" "missing collection markdown source counts"
Assert-Contains $missingMarkdown "Security source artifacts: ready=0 total=2 missing=2" "missing collection markdown security source counts"
Assert-Contains $missingMarkdown "Security evidence finalizer ready: False" "missing collection markdown security finalizer readiness"
Assert-Contains $missingMarkdown "Security evidence finalizer input count: 2" "missing collection markdown security finalizer input count"
Assert-Contains $missingMarkdown "Security evidence finalizer missing run id inputs: ImageSigningRunId, ContainerSecurityRunId" "missing collection markdown security finalizer missing inputs"
Assert-Contains $missingMarkdown "ImageSigningRunId: workflow=image-publish-sign-ci.yml; runId=<image-signing-run-id>; runIdParameter=image_signing_run_id" "missing collection markdown image signing input metadata"
Assert-Contains $missingMarkdown "ContainerSecurityRunId: workflow=container-security-ci.yml; runId=<container-security-run-id>; runIdParameter=container_security_run_id" "missing collection markdown container security input metadata"
Assert-True (@($missingReport.sourceActionOrders) -contains 1) "Expected source action orders to include first action."
Assert-True (@($missingReport.selectedActionOrders) -contains 1) "Expected selected action orders to include first action."
Assert-Contains $missingMarkdown "Source action orders: 1, 2" "missing collection markdown source action orders"
Assert-Contains $missingMarkdown "Selected action orders: 1, 2" "missing collection markdown selected action orders"
$missingCorsArtifact = @($missingReport.artifacts | Where-Object { $_.group -eq "minio-bucket-cors" } | Select-Object -First 1)
Assert-True ($missingCorsArtifact.Count -eq 1) "Expected MinIO bucket CORS artifact to be inferred."
Assert-True (-not [bool] $missingCorsArtifact[0].requiredForReadiness) "MinIO bucket CORS artifact must remain optional."
Assert-Contains $missingMarkdown "storage-expansion-finalizer-<storage-expansion-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "storage-backend-telemetry-evidence-<storage-backend-telemetry-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-storage-backend-telemetry-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "minio-bucket-cors-verification-<minio-bucket-cors-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-minio-bucket-cors-verification.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "minio_bucket_cors_run_id=<minio-bucket-cors-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "not a readiness gate or AWS S3 parity work" "missing collection markdown"
Assert-Contains $missingMarkdown "monitoring-threshold-evidence-<monitoring-threshold-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-monitoring-threshold-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-cluster-network-access-review-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "cluster-network-access-review-evidence-<cluster-network-access-review-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "cluster_network_access_review_run_id=<cluster-network-access-review-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-helm-values-hardening-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "helm-values-hardening-evidence-<helm-values-hardening-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "helm_values_hardening_run_id=<helm-values-hardening-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-support-escalation-handoff-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "support-escalation-handoff-evidence-<support-escalation-handoff-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "support_escalation_handoff_run_id=<support-escalation-handoff-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "secret-rotation-evidence-<secret-rotation-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-secret-rotation-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-commercial-integration-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-commercial-approval-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-chargeback-closeout-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "chargeback-closeout-evidence-<chargeback-closeout-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-operations-handoff-package.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "commercial-integration-evidence-<commercial-integration-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "commercial-approval-evidence-<commercial-approval-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "enterprise-auth-smoke-<enterprise-auth-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-enterprise-auth-jit-rollback-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "enterprise-auth-jit-rollback-evidence-<enterprise-auth-jit-rollback-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "contractual scope-out evidence" "missing collection markdown"
Assert-Contains $missingMarkdown "operations-handoff-package-<operations-handoff-package-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "data-flow-storage-plan-evidence-<data-flow-storage-plan-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-data-flow-storage-plan-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "data-flow-query-retention-budget-evidence-<data-flow-query-retention-budget-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-data-flow-query-retention-budget-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "data-flow-storage-transition-runbook-evidence-<data-flow-storage-transition-runbook-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "manual-data-flow-storage-transition-runbook-evidence.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "operations-readiness-artifact-finalizer-ci.yml" "missing collection markdown"
Assert-Contains $missingMarkdown "optional latest-data-flow-storage-plan.json" "missing collection markdown"
Assert-Contains $missingMarkdown "data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>" "missing collection markdown"
Assert-Contains $missingMarkdown "data_flow_query_retention_budget_json_base64=<base64-latest-data-flow-query-retention-budget-json>" "missing collection markdown"
Assert-Contains $missingMarkdown "data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>" "missing collection markdown"
Assert-Contains $missingMarkdown "sanitized query-plan evidence summary" "missing collection markdown"
Assert-Contains $missingMarkdown ".\.osmu-run\operations-readiness-artifacts\storage-expansion" "missing collection markdown"
Assert-True (-not $missingMarkdown.Contains("OrderedDictionary.downloadPath")) "Local import command should render concrete download paths."

$securityOnlyAction = [ordered]@{
    order = 6
    name = "Container scan/SBOM evidence"
    category = "security-hardening"
    actionType = "workflow"
    evidencePath = ".osmu-run/latest-container-security-evidence.json"
    commandMode = "Workflow"
    command = "gh workflow run container-security-ci.yml"
    status = "planned"
    blockReasons = @()
    unresolvedPlaceholders = @()
    requiresOperatorApproval = $false
    requiresKubeconfigSecret = $false
}
$securityOnlyFixture = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = "planned"
    sourcePlan = ".osmu-run/security-source-only-operations-evidence-plan.json"
    sourceSummary = "passed=82 pending=20"
    sourcePassedCount = 82
    sourcePendingCount = 20
    sourceTotalCount = 102
    sourceCheckCount = 102
    commandMode = "Workflow"
    executionMode = "plan-only"
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 0
    failedCount = 0
    actions = @($securityOnlyAction)
}
$securityOnlyFixture | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $securityOnlyFixturePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $securityOnlyFixturePath `
    -JsonOutputPath $securityOnlyJsonOutputPath `
    -MarkdownOutputPath $securityOnlyMarkdownOutputPath `
    -ContainerSecurityRunId "https://github.com/chefbeom/object-storage-osmu/actions/runs/777" `
    -ImageSigningVersion "v0.1.0-rc.1" `
    -CommitSha "abc123" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-artifact-collection-plan.ps1 security-source-only check failed with exit code $LASTEXITCODE."
}

$securityOnlyReport = Read-Utf8Text $securityOnlyJsonOutputPath | ConvertFrom-Json
$securityOnlyMarkdown = Read-Utf8Text $securityOnlyMarkdownOutputPath
Assert-True ($securityOnlyReport.result -eq "security-source-action-required") "Expected security-source-action-required when only container source is selected and image signing run id is missing."
Assert-True ($securityOnlyReport.requiredArtifactCount -eq 0) "Expected no required readiness artifacts for security source-only selection."
Assert-True ($securityOnlyReport.securitySourceArtifactCount -eq 1) "Expected one security source artifact for container-only selection."
Assert-True ($securityOnlyReport.readySecuritySourceArtifactCount -eq 1) "Expected container security source URL to normalize to a ready source artifact."
Assert-True ($securityOnlyReport.missingSecuritySourceArtifactCount -eq 0) "Expected no missing selected security source artifact after container URL input."
Assert-True (-not [bool] $securityOnlyReport.securityEvidenceFinalizerReady) "Expected security finalizer to wait for image signing run id."
Assert-True (@($securityOnlyReport.securityEvidenceFinalizerMissingRunIdInputs) -contains "ImageSigningRunId") "Expected image signing run id to remain missing."
Assert-True (-not (@($securityOnlyReport.securityEvidenceFinalizerMissingRunIdInputs) -contains "ContainerSecurityRunId")) "Expected container URL to satisfy container run id."
$securityOnlyFinalizerInputs = @($securityOnlyReport.securityEvidenceFinalizerInputs)
$securityOnlyImageInput = @($securityOnlyFinalizerInputs | Where-Object { $_.name -eq "ImageSigningRunId" } | Select-Object -First 1)
$securityOnlyContainerInput = @($securityOnlyFinalizerInputs | Where-Object { $_.name -eq "ContainerSecurityRunId" } | Select-Object -First 1)
Assert-True ($securityOnlyFinalizerInputs.Count -eq 2) "Expected both security finalizer inputs for the finalizer command."
Assert-True (-not [bool] $securityOnlyImageInput[0].ready) "Expected image signing input to stay pending."
Assert-True (-not [bool] $securityOnlyImageInput[0].sourceArtifactSelected) "Expected image signing source artifact to be unselected in container-only scope."
Assert-True ([bool] $securityOnlyContainerInput[0].ready) "Expected container security input to be ready after URL normalization."
Assert-True ([bool] $securityOnlyContainerInput[0].sourceArtifactSelected) "Expected container security source artifact to be selected."
Assert-True ($securityOnlyContainerInput[0].runId -eq "777") "Expected container security finalizer input run id to normalize to 777."
Assert-Contains $securityOnlyMarkdown "Result: security-source-action-required" "security source-only markdown result"
Assert-Contains $securityOnlyMarkdown "Security evidence finalizer input count: 2" "security source-only markdown finalizer input count"
Assert-Contains $securityOnlyMarkdown "Security evidence finalizer missing run id inputs: ImageSigningRunId" "security source-only markdown missing finalizer input"
Assert-Contains $securityOnlyMarkdown "ImageSigningRunId: workflow=image-publish-sign-ci.yml; runId=<image-signing-run-id>; runIdParameter=image_signing_run_id" "security source-only markdown image signing input metadata"
Assert-Contains $securityOnlyMarkdown "ContainerSecurityRunId: workflow=container-security-ci.yml; runId=777; runIdParameter=container_security_run_id" "security source-only markdown container input metadata"
Assert-Contains $securityOnlyMarkdown "container_security_run_id=777" "security source-only markdown normalized container run id"
Assert-Contains $securityOnlyMarkdown "image_signing_run_id=<image-signing-run-id>" "security source-only markdown image signing placeholder"
$directManualCommands = @(
    "gh workflow run manual-secret-rotation-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-commercial-integration-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-commercial-approval-evidence.yml -f product_version=v0.1.0-rc.1 -f approval_ref=approval-20260620 -f approved_by=commercial-owner -f fail_if_not_passed=true",
    "gh workflow run manual-chargeback-closeout-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f billing_period=2026-06 -f fail_if_not_passed=true",
    "gh workflow run manual-enterprise-auth-jit-rollback-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-operations-handoff-package.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-data-flow-query-retention-budget-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-data-flow-storage-transition-runbook-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-monitoring-threshold-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-cluster-network-access-review-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-helm-values-hardening-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-support-escalation-handoff-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f fail_if_not_passed=true",
    "gh workflow run manual-minio-bucket-cors-verification.yml -f bucket_name=osmu-prod -f minio_alias=osmu-minio -f fail_if_not_passed=false"
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
    sourcePassedCount = 36
    sourcePendingCount = 4
    sourceTotalCount = 40
    sourceCheckCount = 40
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

$directManualReport = Read-Utf8Text $directManualJsonOutputPath | ConvertFrom-Json
$directManualMarkdown = Read-Utf8Text $directManualMarkdownOutputPath
Assert-True ($directManualReport.result -eq "action-required") "Expected action-required result for direct manual workflow dispatches without run ids."
Assert-True ($directManualReport.artifactCount -eq 13) "Expected thirteen artifacts from direct manual workflow dispatches."
Assert-True ($directManualReport.requiredArtifactCount -eq 12) "Expected twelve required artifacts from direct manual workflow dispatches."
Assert-True ($directManualReport.missingRequiredArtifactCount -eq 12) "Expected twelve missing direct manual workflow artifacts."
Assert-True ($directManualReport.securitySourceArtifactCount -eq 0) "Expected no security source artifacts for direct manual workflows."
Assert-True ($directManualReport.readySecuritySourceArtifactCount -eq 0) "Expected no ready security source artifacts for direct manual workflows."
Assert-True ($directManualReport.missingSecuritySourceArtifactCount -eq 0) "Expected no missing security source artifacts for direct manual workflows."
Assert-True (-not [bool] $directManualReport.securityEvidenceFinalizerReady) "Expected no security finalizer readiness for direct manual workflows."
Assert-True (@($directManualReport.securityEvidenceFinalizerInputs).Count -eq 0) "Expected no security finalizer input metadata for direct manual workflows."
Assert-True (@($directManualReport.securityEvidenceFinalizerMissingRunIdInputs).Count -eq 0) "Expected no missing security finalizer inputs for direct manual workflows."
Assert-True ($directManualReport.sourceActionCount -eq $directManualActions.Count) "Expected direct manual source action count to match invocation actions."
Assert-True ($directManualReport.sourcePassedCount -eq 36) "Expected direct manual source passed count."
Assert-True ($directManualReport.sourcePendingCount -eq 4) "Expected direct manual source pending count."
Assert-True ($directManualReport.sourceTotalCount -eq 40) "Expected direct manual source total count."
Assert-True ($directManualReport.sourceCheckCount -eq 40) "Expected direct manual source check count."
Assert-Contains $directManualMarkdown "Source counts: passed=36 pending=4 total=40 checks=40" "direct manual collection markdown source counts"
Assert-Contains $directManualMarkdown "Security source artifacts: ready=0 total=0 missing=0" "direct manual collection markdown security source counts"
Assert-Contains $directManualMarkdown "Security evidence finalizer ready: False" "direct manual collection markdown security finalizer readiness"
Assert-Contains $directManualMarkdown "Security evidence finalizer input count: 0" "direct manual collection markdown security finalizer input count"
Assert-True (@($directManualReport.sourceActionOrders) -contains 1) "Expected direct manual source action orders to include first action."
Assert-True (@($directManualReport.selectedActionOrders) -contains 1) "Expected direct manual selected action orders to include first action."
Assert-Contains $directManualMarkdown "Source action orders: 1, 2" "direct manual collection markdown source action orders"
Assert-Contains $directManualMarkdown "Selected action orders: 1, 2" "direct manual collection markdown selected action orders"
Assert-Contains $directManualMarkdown "manual-secret-rotation-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "secret_rotation_run_id=<secret-rotation-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-commercial-integration-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "commercial_integration_run_id=<commercial-integration-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-commercial-approval-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "commercial_approval_run_id=<commercial-approval-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-chargeback-closeout-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "chargeback_closeout_run_id=<chargeback-closeout-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-enterprise-auth-jit-rollback-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "enterprise_auth_jit_rollback_run_id=<enterprise-auth-jit-rollback-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-operations-handoff-package.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "operations_handoff_package_run_id=<operations-handoff-package-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-data-flow-storage-transition-runbook-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-data-flow-query-retention-budget-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "data_flow_query_retention_budget_run_id=<data-flow-query-retention-budget-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "data_flow_storage_transition_runbook_run_id=<data-flow-storage-transition-runbook-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-monitoring-threshold-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "monitoring_threshold_run_id=<monitoring-threshold-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-cluster-network-access-review-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "cluster_network_access_review_run_id=<cluster-network-access-review-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-helm-values-hardening-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "helm_values_hardening_run_id=<helm-values-hardening-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-support-escalation-handoff-evidence.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "support_escalation_handoff_run_id=<support-escalation-handoff-run-id>" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "manual-minio-bucket-cors-verification.yml" "direct manual collection markdown"
Assert-Contains $directManualMarkdown "minio_bucket_cors_run_id=<minio-bucket-cors-run-id>" "direct manual collection markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $fixturePath `
    -JsonOutputPath $readyJsonOutputPath `
    -MarkdownOutputPath $readyMarkdownOutputPath `
    -StorageExpansionRunId "101" `
    -HaDrReadinessRunId "102" `
    -KubernetesDrRunId "103" `
    -ImageSigningRunId "104" `
    -ContainerSecurityRunId "https://github.com/chefbeom/object-storage-osmu/actions/runs/105" `
    -SecurityEvidenceRunId "106" `
    -StorageBackendTelemetryRunId "107" `
    -MinioBucketCorsRunId "118" `
    -MonitoringThresholdRunId "116" `
    -ClusterNetworkAccessReviewRunId "122" `
    -HelmValuesHardeningRunId "123" `
    -SupportEscalationHandoffRunId "124" `
    -SecretRotationRunId "108" `
    -CommercialIntegrationRunId "109" `
    -CommercialApprovalRunId "110" `
    -ChargebackCloseoutRunId "120" `
    -EnterpriseAuthRunId "111" `
    -EnterpriseAuthJitRollbackRunId "121" `
    -OperationsHandoffPackageRunId "112" `
    -DataFlowStoragePlanRunId "113" `
    -DataFlowQueryRetentionBudgetRunId "119" `
    -DataFlowStorageTransitionRunbookRunId "114" `
    -KubernetesOperationsReportSyncRunId "115" `
    -ImageSigningVersion "v0.1.0-rc.1" `
    -CommitSha "abc123" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-artifact-collection-plan.ps1 ready check failed with exit code $LASTEXITCODE."
}

$readyReport = Read-Utf8Text $readyJsonOutputPath | ConvertFrom-Json
$readyMarkdown = Read-Utf8Text $readyMarkdownOutputPath
Assert-True ($readyReport.result -eq "ready") "Expected ready result when all required run ids are supplied."
Assert-Contains $readyReport.decisionRule "paste GitHub Actions run URLs" "ready collection decision rule should mention run URL input"
Assert-True ($readyReport.missingRequiredArtifactCount -eq 0) "Expected no missing required artifacts."
Assert-True ($readyReport.readyArtifactCount -eq 23) "Expected all artifacts to be concrete."
Assert-True ($readyReport.securitySourceArtifactCount -eq 2) "Expected two ready-case security source artifacts."
Assert-True ($readyReport.readySecuritySourceArtifactCount -eq 2) "Expected both security source artifacts to be ready."
Assert-True ($readyReport.missingSecuritySourceArtifactCount -eq 0) "Expected no missing security source artifacts."
Assert-True ([bool] $readyReport.securityEvidenceFinalizerReady) "Expected security finalizer source inputs to be ready."
Assert-True (@($readyReport.securityEvidenceFinalizerInputs).Count -eq 2) "Expected both security finalizer input metadata rows in ready report."
Assert-True (@($readyReport.securityEvidenceFinalizerMissingRunIdInputs).Count -eq 0) "Expected no missing security finalizer run id inputs when image and container run ids are supplied."
$readyContainerInput = @($readyReport.securityEvidenceFinalizerInputs | Where-Object { $_.name -eq "ContainerSecurityRunId" } | Select-Object -First 1)
Assert-True ($readyContainerInput.Count -eq 1) "Expected ready container security finalizer input metadata."
Assert-True ([bool] $readyContainerInput[0].ready) "Expected ready container security finalizer input."
Assert-True ($readyContainerInput[0].runId -eq "105") "Expected ready container security URL to normalize to 105 in input metadata."
Assert-True ($readyReport.sourcePassedCount -eq 36) "Expected ready report source passed count."
Assert-True ($readyReport.sourcePendingCount -eq 6) "Expected ready report source pending count."
Assert-True ($readyReport.sourceTotalCount -eq 42) "Expected ready report source total count."
Assert-True ($readyReport.sourceCheckCount -eq 42) "Expected ready report source check count."
Assert-True (@($readyReport.selectedActionOrders) -contains 23) "Expected ready selected action orders to include last action."
Assert-Contains $readyMarkdown "Source counts: passed=36 pending=6 total=42 checks=42" "ready collection markdown source counts"
Assert-Contains $readyMarkdown "Selected action orders: 1" "ready collection markdown selected action order"
Assert-Contains $readyMarkdown "Security source artifacts: ready=2 total=2 missing=0" "ready collection markdown security source counts"
Assert-Contains $readyMarkdown "Security evidence finalizer ready: True" "ready collection markdown security finalizer readiness"
Assert-Contains $readyMarkdown "Security evidence finalizer input count: 2" "ready collection markdown security finalizer input count"
Assert-Contains $readyMarkdown "Security evidence finalizer missing run id inputs: none" "ready collection markdown security finalizer missing inputs"
Assert-Contains $readyMarkdown "ImageSigningRunId: workflow=image-publish-sign-ci.yml; runId=104; runIdParameter=image_signing_run_id" "ready collection markdown image signing input metadata"
Assert-Contains $readyMarkdown "ContainerSecurityRunId: workflow=container-security-ci.yml; runId=105; runIdParameter=container_security_run_id" "ready collection markdown container security input metadata"
$readyCorsArtifact = @($readyReport.artifacts | Where-Object { $_.group -eq "minio-bucket-cors" } | Select-Object -First 1)
Assert-True ($readyCorsArtifact.Count -eq 1) "Expected ready MinIO bucket CORS artifact to be inferred."
Assert-True (-not [bool] $readyCorsArtifact[0].requiredForReadiness) "Ready MinIO bucket CORS artifact must remain optional."
Assert-Contains $readyMarkdown "storage_expansion_run_id=101" "ready collection markdown"
Assert-Contains $readyMarkdown "security_evidence_run_id=106" "ready collection markdown"
Assert-Contains $readyMarkdown "storage_backend_telemetry_run_id=107" "ready collection markdown"
Assert-Contains $readyMarkdown "minio_bucket_cors_run_id=118" "ready collection markdown"
Assert-Contains $readyMarkdown "monitoring_threshold_run_id=116" "ready collection markdown"
Assert-Contains $readyMarkdown "cluster_network_access_review_run_id=122" "ready collection markdown"
Assert-Contains $readyMarkdown "helm_values_hardening_run_id=123" "ready collection markdown"
Assert-Contains $readyMarkdown "support_escalation_handoff_run_id=124" "ready collection markdown"
Assert-Contains $readyMarkdown "secret_rotation_run_id=108" "ready collection markdown"
Assert-Contains $readyMarkdown "commercial_integration_run_id=109" "ready collection markdown"
Assert-Contains $readyMarkdown "commercial_approval_run_id=110" "ready collection markdown"
Assert-Contains $readyMarkdown "chargeback_closeout_run_id=120" "ready collection markdown"
Assert-Contains $readyMarkdown "enterprise_auth_run_id=111" "ready collection markdown"
Assert-Contains $readyMarkdown "enterprise_auth_jit_rollback_run_id=121" "ready collection markdown"
Assert-Contains $readyMarkdown "operations_handoff_package_run_id=112" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_storage_plan_run_id=113" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_query_retention_budget_run_id=119" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_storage_transition_runbook_run_id=114" "ready collection markdown"
Assert-Contains $readyMarkdown "kubernetes_operations_report_sync_run_id=115" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_query_retention_budget_json_base64=<base64-latest-data-flow-query-retention-budget-json>" "ready collection markdown"
Assert-Contains $readyMarkdown "data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>" "ready collection markdown"
Assert-Contains $readyMarkdown "osmu-image-signing-v0.1.0-rc.1-abc123" "ready collection markdown"
Assert-Contains $readyMarkdown "osmu-container-security-abc123" "ready collection markdown"
Assert-Contains $readyMarkdown "container_security_run_id=105" "ready collection markdown normalized container security URL run id"
Assert-Contains $readyMarkdown "gh run download 105 -n osmu-container-security-abc123" "ready collection markdown normalized container security URL download"
Assert-Contains $readyReport.securityEvidenceFinalizerCommand "container_security_run_id=105" "ready collection JSON normalized container security URL finalizer command"
Assert-Contains $readyMarkdown "gh run download 106 -n security-evidence-finalizer-106" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 107 -n storage-backend-telemetry-evidence-107" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 118 -n minio-bucket-cors-verification-118" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 116 -n monitoring-threshold-evidence-116" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 122 -n cluster-network-access-review-evidence-122" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 123 -n helm-values-hardening-evidence-123" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 124 -n support-escalation-handoff-evidence-124" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 108 -n secret-rotation-evidence-108" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 109 -n commercial-integration-evidence-109" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 110 -n commercial-approval-evidence-110" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 120 -n chargeback-closeout-evidence-120" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 111 -n enterprise-auth-smoke-111" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 121 -n enterprise-auth-jit-rollback-evidence-121" "ready collection markdown"
Assert-Contains $readyMarkdown "contractual scope-out evidence" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 112 -n operations-handoff-package-112" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 113 -n data-flow-storage-plan-evidence-113" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 119 -n data-flow-query-retention-budget-evidence-119" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 114 -n data-flow-storage-transition-runbook-evidence-114" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 115 -n kubernetes-operations-report-sync-115" "ready collection markdown"
Assert-Contains $readyMarkdown "-StorageBackendTelemetryArtifactPath .\.osmu-run\operations-readiness-artifacts\storage-backend-telemetry" "ready collection markdown"
Assert-Contains $readyMarkdown "-MinioBucketCorsArtifactPath .\.osmu-run\operations-readiness-artifacts\minio-bucket-cors" "ready collection markdown"
Assert-Contains $readyMarkdown "-MonitoringThresholdArtifactPath .\.osmu-run\operations-readiness-artifacts\monitoring-threshold" "ready collection markdown"
Assert-Contains $readyMarkdown "-ClusterNetworkAccessReviewArtifactPath .\.osmu-run\operations-readiness-artifacts\cluster-network-access-review" "ready collection markdown"
Assert-Contains $readyMarkdown "-HelmValuesHardeningArtifactPath .\.osmu-run\operations-readiness-artifacts\helm-values-hardening" "ready collection markdown"
Assert-Contains $readyMarkdown "-SupportEscalationHandoffArtifactPath .\.osmu-run\operations-readiness-artifacts\support-escalation-handoff" "ready collection markdown"
Assert-Contains $readyMarkdown "-SecretRotationArtifactPath .\.osmu-run\operations-readiness-artifacts\secret-rotation" "ready collection markdown"
Assert-Contains $readyMarkdown "-CommercialIntegrationArtifactPath .\.osmu-run\operations-readiness-artifacts\commercial-integration" "ready collection markdown"
Assert-Contains $readyMarkdown "-CommercialApprovalArtifactPath .\.osmu-run\operations-readiness-artifacts\commercial-approval" "ready collection markdown"
Assert-Contains $readyMarkdown "-ChargebackCloseoutArtifactPath .\.osmu-run\operations-readiness-artifacts\chargeback-closeout" "ready collection markdown"
Assert-Contains $readyMarkdown "-EnterpriseAuthJitRollbackArtifactPath .\.osmu-run\operations-readiness-artifacts\enterprise-auth-jit-rollback" "ready collection markdown"
Assert-Contains $readyMarkdown "-OperationsHandoffPackageArtifactPath .\.osmu-run\operations-readiness-artifacts\operations-handoff-package" "ready collection markdown"
Assert-Contains $readyMarkdown "-DataFlowStoragePlanArtifactPath .\.osmu-run\operations-readiness-artifacts\data-flow-storage-plan" "ready collection markdown"
Assert-Contains $readyMarkdown "-DataFlowQueryRetentionBudgetArtifactPath .\.osmu-run\operations-readiness-artifacts\data-flow-query-retention-budget" "ready collection markdown"
Assert-Contains $readyMarkdown "-DataFlowStorageTransitionRunbookArtifactPath .\.osmu-run\operations-readiness-artifacts\data-flow-storage-transition-runbook" "ready collection markdown"

Write-Host "Operations artifact collection plan verified."
Write-Host "Missing report: $missingJsonOutputPath"
Write-Host "Ready report: $readyJsonOutputPath"
