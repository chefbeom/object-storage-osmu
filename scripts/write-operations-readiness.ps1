param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $StorageExpansionFinalizeReportPath = ".\.osmu-run\latest-storage-expansion-finalize.json",
    [string] $KubernetesHaDrReadinessReportPath = ".\.osmu-run\latest-kubernetes-ha-dr-readiness.json",
    [string] $KubernetesDrFinalizeReportPath = ".\.osmu-run\latest-kubernetes-dr-finalize.json",
    [string] $IamRbacFinalizeReportPath = ".\.osmu-run\latest-iam-rbac-finalize.json",
    [string] $SecurityEvidenceFinalizeReportPath = ".\.osmu-run\latest-security-evidence-finalize.json",
    [string] $ImageSigningEvidencePath = ".\.osmu-run\latest-image-signing-evidence.json",
    [string] $ContainerSecurityEvidencePath = ".\.osmu-run\latest-container-security-evidence.json",
    [string] $StorageBackendTelemetryEvidencePath = ".\.osmu-run\latest-storage-backend-telemetry.json",
    [string] $SecretRotationEvidencePath = ".\.osmu-run\latest-secret-rotation-evidence.json",
    [string] $CommercialIntegrationEvidencePath = ".\.osmu-run\latest-commercial-integration-evidence.json",
    [string] $CommercialApprovalEvidencePath = ".\.osmu-run\latest-commercial-approval-evidence.json",
    [string] $EnterpriseAuthSmokeEvidencePath = ".\.osmu-run\latest-enterprise-auth-smoke.json",
    [string] $OperationsHandoffPackagePath = ".\.osmu-run\latest-operations-handoff-package.json",
    [string] $DataFlowStoragePlanPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-readiness.md",
    [switch] $FailIfNotReady,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Get-ObjectProperty($object, [string] $name) {
    if ($null -eq $object) {
        return $null
    }
    $property = $object.PSObject.Properties[$name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-ObjectInt($object, [string] $name) {
    $value = Get-ObjectProperty $object $name
    if ($null -eq $value) {
        return 0
    }
    $parsed = 0
    if ([int]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return 0
}

function Read-JsonReport([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            label = $label
            path = $resolvedPath
            exists = $false
            parsed = $false
            data = $null
            detail = "report not found"
        }
    }

    try {
        return [pscustomobject]@{
            label = $label
            path = $resolvedPath
            exists = $true
            parsed = $true
            data = (Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json)
            detail = "report parsed"
        }
    }
    catch {
        return [pscustomobject]@{
            label = $label
            path = $resolvedPath
            exists = $true
            parsed = $false
            data = $null
            detail = $_.Exception.Message
        }
    }
}

function Add-Check(
    [string] $Name,
    [string] $Category,
    [bool] $Passed,
    [string] $Detail,
    [string] $EvidencePath = "",
    [string] $RequiredEvidence = "",
    [object] $Remediation = $null
) {
    $check = [ordered]@{
        name = $Name
        category = $Category
        status = if ($Passed) { "PASS" } else { "PENDING" }
        passed = $Passed
        detail = $Detail
        evidencePath = $EvidencePath
        requiredEvidence = $RequiredEvidence
    }
    if ($null -ne $Remediation) {
        $check.remediation = $Remediation
    }
    $script:checks += $check
}

function New-Remediation([string] $Command, [string] $Workflow, [string] $WorkflowCommand, [string] $Note) {
    return [ordered]@{
        command = $Command
        workflow = $Workflow
        workflowCommand = $WorkflowCommand
        note = $Note
    }
}

function Get-ScopeValue([object] $ReleaseReport, [string] $Name) {
    $scope = Get-ObjectProperty $ReleaseReport.data "scope"
    $value = Get-ObjectProperty $scope $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Add-ScopeCheck([object] $ReleaseReport, [string] $ScopeName, [string] $Label, [string] $Category) {
    $value = Get-ScopeValue $ReleaseReport $ScopeName
    Add-Check $Label $Category ($value -eq "included") "scope.$ScopeName=$value" $ReleaseReport.path "latest release report with scope.$ScopeName=included"
}

function Test-FileExists([string] $path) {
    return Test-Path -LiteralPath (Resolve-ProjectPath $path)
}

function Add-FileCheck([string] $Name, [string] $Category, [string] $Path, [string] $RequiredEvidence) {
    $resolvedPath = Resolve-ProjectPath $Path
    Add-Check $Name $Category (Test-Path -LiteralPath $resolvedPath) "path=$resolvedPath" $resolvedPath $RequiredEvidence
}

function Get-StorageExpansionDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $backend = Get-ObjectProperty $Report.data "backend"
    return "result=$($Report.data.result), namespace=$($Report.data.namespace), tenant=$($Report.data.tenantName), runDryRunRunner=$($backend.runDryRunRunner), runApply=$($backend.runApply)"
}

function Get-HaDrReadinessDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    return "result=$($Report.data.result), namespace=$($Report.data.namespace), failureCount=$($Report.data.failureCount)"
}

function Get-KubernetesDrFinalizeDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    return "result=$($Report.data.result), status=$($Report.data.status), sourceNamespace=$($Report.data.sourceNamespace), restoreNamespace=$($Report.data.restoreNamespace), backupTimestamp=$($Report.data.backupTimestamp), serverDryRunOnly=$($Report.data.serverDryRunOnly), confirmRestore=$($Report.data.confirmRestore), submitEvidence=$($Report.data.submitEvidence)"
}

function Get-GenericResultDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $result = Get-ObjectProperty $Report.data "result"
    if (-not $result) {
        $result = Get-ObjectProperty $Report.data "status"
    }
    return "result=$result"
}

function Get-StorageBackendTelemetryDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $summary = Get-ObjectProperty $Report.data "summary"
    return "result=$($Report.data.result), poolCount=$($summary.poolCount), serverCount=$($summary.serverCount), offlineServerCount=$($summary.offlineServerCount), driveCount=$($summary.driveCount), totalBytes=$($summary.totalBytes), usedBytes=$($summary.usedBytes), freeBytes=$($summary.freeBytes)"
}

function Test-SanitizedQueryPlanEvidenceSummary([object] $QueryPlanEvidence) {
    if ($null -eq $QueryPlanEvidence) {
        return $true
    }
    $summaryText = $QueryPlanEvidence | ConvertTo-Json -Depth 20 -Compress
    $forbiddenPropertyPattern = '(?i)"(sql|rawSql|raw_sql|explain|explainJson|explain_json|rawExplain|raw_explain|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:'
    $credentialPattern = '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key)\s*=\s*\S+'
    $rawSqlPattern = '(?i)\bSELECT\b[\s\S]{0,200}\bFROM\b'
    return -not ($summaryText -match $forbiddenPropertyPattern -or $summaryText -match $credentialPattern -or $summaryText -match $rawSqlPattern)
}

function Test-DataFlowStoragePlanEvidenceAccepted([object] $Report) {
    if (-not ($Report.exists -and $Report.parsed)) {
        return $false
    }
    if ([string] (Get-ObjectProperty $Report.data "formatVersion") -ne "osmu.data-flow-storage-plan.v1") {
        return $false
    }
    if ([string] (Get-ObjectProperty $Report.data "result") -ne "passed") {
        return $false
    }
    $candidateStore = [string] (Get-ObjectProperty $Report.data "candidateStore")
    if ($candidateStore -notin @("MARIADB_PARTITION", "EXTERNAL_TIME_SERIES", "DUAL_WRITE")) {
        return $false
    }
    $queryPlanEvidence = Get-ObjectProperty $Report.data "queryPlanEvidence"
    if (-not (Test-SanitizedQueryPlanEvidenceSummary $queryPlanEvidence)) {
        return $false
    }
    if (@("MARIADB_PARTITION", "DUAL_WRITE") -contains $candidateStore) {
        if ($null -eq $queryPlanEvidence) {
            return $false
        }
        if ([string] (Get-ObjectProperty $queryPlanEvidence "expectedFormatVersion") -ne "osmu.mariadb-query-plan-evidence.v1") {
            return $false
        }
        if ([string] (Get-ObjectProperty $queryPlanEvidence "result") -ne "passed") {
            return $false
        }
        if ((Get-ObjectInt $queryPlanEvidence "failedCount") -ne 0) {
            return $false
        }
    }
    return $true
}

function Get-DataFlowStoragePlanDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $queryPlanEvidence = Get-ObjectProperty $Report.data "queryPlanEvidence"
    $queryPlanDetail = "queryPlanEvidence=absent"
    if ($null -ne $queryPlanEvidence) {
        $sanitized = Test-SanitizedQueryPlanEvidenceSummary $queryPlanEvidence
        $queryPlanDetail = "queryPlanEvidence.result=$([string] (Get-ObjectProperty $queryPlanEvidence "result")), queryPlanEvidence.failedCount=$(Get-ObjectInt $queryPlanEvidence "failedCount"), sanitized=$sanitized"
    }
    return "result=$($Report.data.result), candidateStore=$($Report.data.candidateStore), pendingCount=$($Report.data.pendingCount), $queryPlanDetail"
}

function Test-EnterpriseAuthEvidenceAccepted([object] $Report) {
    if (-not ($Report.exists -and $Report.parsed)) {
        return $false
    }
    $result = [string] (Get-ObjectProperty $Report.data "result")
    if ($result -eq "passed") {
        return $true
    }
    if ($result -ne "scope-out") {
        return $false
    }
    $scopeOut = Get-ObjectProperty $Report.data "scopeOut"
    $accepted = [bool] (Get-ObjectProperty $scopeOut "accepted")
    $reference = [string] (Get-ObjectProperty $scopeOut "reference")
    $reason = [string] (Get-ObjectProperty $scopeOut "reason")
    return $accepted -and -not [string]::IsNullOrWhiteSpace($reference) -and -not [string]::IsNullOrWhiteSpace($reason)
}

$releaseReport = Read-JsonReport $ReleaseReportPath "MVP release report"
$storageExpansionReport = Read-JsonReport $StorageExpansionFinalizeReportPath "Storage expansion finalizer"
$haDrReadinessReport = Read-JsonReport $KubernetesHaDrReadinessReportPath "Kubernetes HA/DR readiness"
$kubernetesDrReport = Read-JsonReport $KubernetesDrFinalizeReportPath "Kubernetes DR finalizer"
$iamRbacFinalizeReport = Read-JsonReport $IamRbacFinalizeReportPath "IAM/RBAC finalizer"
$securityFinalizeReport = Read-JsonReport $SecurityEvidenceFinalizeReportPath "Security evidence finalizer"
$imageSigningReport = Read-JsonReport $ImageSigningEvidencePath "Image signing evidence"
$containerSecurityReport = Read-JsonReport $ContainerSecurityEvidencePath "Container security evidence"
$storageBackendTelemetryReport = Read-JsonReport $StorageBackendTelemetryEvidencePath "Storage backend telemetry evidence"
$secretRotationReport = Read-JsonReport $SecretRotationEvidencePath "Secret rotation evidence"
$commercialIntegrationReport = Read-JsonReport $CommercialIntegrationEvidencePath "Commercial integration evidence"
$commercialApprovalReport = Read-JsonReport $CommercialApprovalEvidencePath "Commercial approval evidence"
$enterpriseAuthSmokeReport = Read-JsonReport $EnterpriseAuthSmokeEvidencePath "Enterprise auth smoke evidence"
$operationsHandoffPackageReport = Read-JsonReport $OperationsHandoffPackagePath "Operations handoff package"
$dataFlowStoragePlanReport = Read-JsonReport $DataFlowStoragePlanPath "Data-flow storage transition plan"

$storageExpansionRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -Namespace osmu -TenantName osmu-minio -ManifestPath .\infra\k8s\examples\minio-tenant-pool-expansion.example.yaml -ImpersonateRunner" `
    ".github/workflows/storage-expansion-finalizer-ci.yml" `
    "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f manifest_path=./infra/k8s/examples/minio-tenant-pool-expansion.example.yaml -f impersonate_runner=true" `
    "Run live against the target cluster, or dispatch the workflow with run_live=true and OSMU_KUBECONFIG_BASE64 configured."
$haDrReadinessRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-ha-dr-readiness.ps1 -Namespace osmu -RestoreManifestPath .\infra\k8s\examples\restore-from-backup.example.yaml" `
    ".github/workflows/kubernetes-ha-dr-readiness-ci.yml" `
    "gh workflow run kubernetes-ha-dr-readiness-ci.yml -f run_live=true -f namespace=osmu -f restore_manifest_path=./infra/k8s/examples/restore-from-backup.example.yaml" `
    "Run live against the target namespace, or dispatch the workflow with run_live=true and OSMU_KUBECONFIG_BASE64 configured."
$kubernetesDrRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -BackupTimestamp <YYYYMMDDTHHMMSSZ> -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -ConfirmRestore -ApiBase <restore-api-base> -AdminLoginId <admin> -AdminPassword <secret> -MetadataRowCount <count> -RunS3ClientSmoke -SubmitEvidence" `
    ".github/workflows/kubernetes-dr-finalizer-ci.yml" `
    "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f source_namespace=osmu -f restore_namespace=osmu-restore-drill -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f server_dry_run_only=false -f confirm_restore=true -f bootstrap_dr_bucket=true -f verify_dr_bucket_immutability=true -f transfer_artifacts=true -f run_s3_client_smoke=true -f submit_evidence=true -f api_base=<restore-api-base> -f admin_login_id=<admin> -f metadata_row_count=<count>" `
    "Use a real backup timestamp and confirmed restore only after operator approval; server_dry_run_only is useful preflight but does not produce ready evidence."
$securityFinalizeRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-security-evidence.ps1 -ImageSigningEvidencePath .\.osmu-run\latest-image-signing-evidence.json -ContainerSecurityEvidencePath .\.osmu-run\latest-container-security-evidence.json" `
    ".github/workflows/security-evidence-finalizer-ci.yml" `
    "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<run-id> -f image_signing_artifact_name=<artifact-name> -f container_security_run_id=<run-id> -f container_security_artifact_name=<artifact-name> -f fail_if_not_passed=true" `
    "Promote non-synthetic image signing and container security artifacts after their source workflows pass."
$imageSigningRemediation = New-Remediation `
    "Dispatch .github/workflows/image-publish-sign-ci.yml with publish=true and a release version such as v0.1.0-rc.1" `
    ".github/workflows/image-publish-sign-ci.yml" `
    "gh workflow run image-publish-sign-ci.yml -f version=v0.1.0-rc.1 -f publish=true" `
    "The workflow writes .osmu-run/latest-image-signing-evidence.json after Cosign verification and digest capture."
$containerSecurityRemediation = New-Remediation `
    "Dispatch .github/workflows/container-security-ci.yml on the target commit" `
    ".github/workflows/container-security-ci.yml" `
    "gh workflow run container-security-ci.yml" `
    "The workflow writes .osmu-run/latest-container-security-evidence.json after Trivy high/critical scans and SPDX SBOM generation."
$storageBackendTelemetryRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-storage-backend-telemetry-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -MinioAlias <alias> -EvidenceRef <run-ref> -AdminInfoJsonPath .\.osmu-run\minio-admin-info.json -FailIfNotPassed" `
    ".github/workflows/manual-storage-backend-telemetry-evidence.yml" `
    "gh workflow run manual-storage-backend-telemetry-evidence.yml -f collection_mode=live -f minio_endpoint=<minio-endpoint> -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f minio_alias=<alias> -f evidence_ref=<run-ref> -f fail_if_not_passed=true" `
    "Run after collecting target MinIO pool/node telemetry with mc admin info --json, or dispatch the manual workflow in live mode with OSMU_MINIO_ACCESS_KEY and OSMU_MINIO_SECRET_KEY secrets plus a non-secret minio_endpoint input. The workflow still supports prepared_base64 mode with OSMU_MINIO_ADMIN_INFO_JSON_BASE64 when operators need offline evidence ingestion. The evidence stores summary counts, byte totals, server states, input SHA-256, and external references only; do not pass raw credentials, bearer tokens, private keys, kubeconfig, MinIO root credentials, or object data."
$dataFlowStoragePlanRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-storage-plan.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -CandidateStore MARIADB_PARTITION -ExpectedPeakEventsPerDay <events-per-day> -ExpectedQueryWindowDays <query-window-days> -EvidenceRef <run-ref> -ConfirmNoObjectKeyInAggregates -ConfirmBackfillPlan -ConfirmRollbackPlan -ConfirmDashboardCutoverPlan -ConfirmRetentionJobBudget -ConfirmExplainEvidence -QueryPlanEvidenceJsonPath .\.osmu-run\latest-mariadb-query-plan-evidence.json -RequireQueryPlanEvidence -FailIfNotPassed" `
    ".github/workflows/manual-data-flow-storage-plan-evidence.yml" `
    "gh workflow run manual-data-flow-storage-plan-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f candidate_store=MARIADB_PARTITION -f expected_peak_events_per_day=<events-per-day> -f expected_query_window_days=<query-window-days> -f evidence_ref=<run-ref> -f query_plan_evidence_json_base64=<base64-latest-mariadb-query-plan-evidence-json> -f confirm_no_object_key_in_aggregates=true -f confirm_backfill_plan=true -f confirm_rollback_plan=true -f confirm_dashboard_cutover_plan=true -f confirm_retention_job_budget=true -f confirm_explain_evidence=true -f require_query_plan_evidence=true -f fail_if_not_passed=true" `
    "Run after target MariaDB query plan evidence passes with write-mariadb-query-plan-evidence.ps1 -Execute or operator-collected EXPLAIN input, or dispatch the manual workflow with a sanitized base64 latest-mariadb-query-plan-evidence.json summary. For EXTERNAL_TIME_SERIES, change CandidateStore and use a target-store benchmark evidence reference. The plan stores result/count/failed-check metadata only; do not include raw SQL, raw EXPLAIN, credentials, object keys, or raw event messages."
$secretRotationRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-secret-rotation-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -RotationStartedAt <iso-time> -RotationCompletedAt <iso-time> -ChangeApprovalRef <change-id> -SecretManagerEvidenceRef <audit-ref> -WorkloadRestartEvidenceRef <rollout-ref> -SmokeEvidenceRef <smoke-ref> -ArtifactLeakReviewEvidenceRef <scan-ref> -AccessKeyEncryptionDecisionRef <decision-ref> -RotateAdminPassword -RotateJwtSigningSecret -RotateDatabaseCredentials -RotateMinioRootCredentials -RotateTlsCertificate -ConfirmNoSecretValues -ConfirmWorkloadRestart -ConfirmSmokePassed -ConfirmArtifactLeakReview -FailIfNotPassed" `
    ".github/workflows/manual-secret-rotation-evidence.yml" `
    "gh workflow run manual-secret-rotation-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f rotation_started_at=<iso-time> -f rotation_completed_at=<iso-time> -f change_approval_ref=<change-id> -f secret_manager_evidence_ref=<audit-ref> -f workload_restart_evidence_ref=<rollout-ref> -f smoke_evidence_ref=<smoke-ref> -f artifact_leak_review_evidence_ref=<scan-ref> -f access_key_encryption_decision_ref=<decision-ref> -f rotate_admin_password=true -f rotate_jwt_signing_secret=true -f rotate_database_credentials=true -f rotate_minio_root_credentials=true -f rotate_tls_certificate=true -f confirm_no_secret_values=true -f confirm_workload_restart=true -f confirm_smoke_passed=true -f confirm_artifact_leak_review=true -f require_all_core_secrets=true -f fail_if_not_passed=true" `
    "Run after target-environment secret/certificate rotation. RotationCompletedAt must be the same as or later than RotationStartedAt. The evidence stores references and booleans only; do not pass secret values, tokens, private keys, kubeconfig, database credentials, MinIO credentials, OIDC/LDAP secrets, SMTP credentials, or webhook signing secrets."
$commercialIntegrationRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-integration-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -VerificationStartedAt <iso-time> -VerificationCompletedAt <iso-time> -ChangeApprovalRef <change-id> -NotificationWebhookEvidenceRef <ref> -SlackWebhookEvidenceRef <ref> -EmailSmtpEvidenceRef <ref> -PaymentGenericWebhookEvidenceRef <ref> -PaymentCardProfileEvidenceRef <ref> -PaymentBankProfileEvidenceRef <ref> -PaymentTaxProfileEvidenceRef <ref> -PaymentErpProfileEvidenceRef <ref> -PaymentProviderAdapterReadinessEvidenceRef <ref> -PaymentProviderAdapterReadinessJsonPath .\.osmu-run\payment-provider-adapter-readiness.json -AdapterRetryWorkerEvidenceRef <ref> -PayloadReviewEvidenceRef <ref> -PrivateNetworkBlockEvidenceRef <ref> -HmacSignatureEvidenceRef <ref> -VerifiedNotificationWebhook -VerifiedSlackWebhook -VerifiedEmailSmtp -VerifiedPaymentGenericWebhook -VerifiedPaymentCardProfile -VerifiedPaymentBankProfile -VerifiedPaymentTaxProfile -VerifiedPaymentErpProfile -ConfirmPaymentProviderAdapterReadinessReviewed -ConfirmAdapterRetryWorkerRun -ConfirmPayloadSizeCaps -ConfirmPrivateNetworkBlocking -ConfirmHmacSignatureHeaders -ConfirmNoSecretValues -ConfirmNoRawProviderResponses -RequireAllImplementedAdapters -FailIfNotPassed" `
    ".github/workflows/manual-commercial-integration-evidence.yml" `
    "gh workflow run manual-commercial-integration-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f verification_started_at=<iso-time> -f verification_completed_at=<iso-time> -f change_approval_ref=<change-id> -f notification_webhook_evidence_ref=<ref> -f slack_webhook_evidence_ref=<ref> -f email_smtp_evidence_ref=<ref> -f payment_generic_webhook_evidence_ref=<ref> -f payment_card_profile_evidence_ref=<ref> -f payment_bank_profile_evidence_ref=<ref> -f payment_tax_profile_evidence_ref=<ref> -f payment_erp_profile_evidence_ref=<ref> -f payment_provider_adapter_readiness_evidence_ref=<ref> -f payment_provider_adapter_readiness_json_base64=<base64-json> -f adapter_retry_worker_evidence_ref=<ref> -f payload_review_evidence_ref=<ref> -f private_network_block_evidence_ref=<ref> -f hmac_signature_evidence_ref=<ref> -f verified_notification_webhook=true -f verified_slack_webhook=true -f verified_email_smtp=true -f verified_payment_generic_webhook=true -f verified_payment_card_profile=true -f verified_payment_bank_profile=true -f verified_payment_tax_profile=true -f verified_payment_erp_profile=true -f confirm_payment_provider_adapter_readiness_reviewed=true -f confirm_adapter_retry_worker_run=true -f confirm_payload_size_caps=true -f confirm_private_network_blocking=true -f confirm_hmac_signature_headers=true -f confirm_no_secret_values=true -f confirm_no_raw_provider_responses=true -f require_all_implemented_adapters=true -f fail_if_not_passed=true" `
    "Run after target-environment notification webhook, Slack, EMAIL SMTP relay, generic payment webhook, CARD/BANK/TAX/ERP payment webhook profile handoff checks, and GET /api/admin/billing/payment-provider-adapter-readiness review. VerificationCompletedAt must be the same as or later than VerificationStartedAt. The readiness JSON can be passed as base64 to the manual workflow, is reduced to sanitized counts/profile statuses, and the decoded workflow input is deleted before artifact upload. This evidence does not claim or require native card/bank/tax/ERP processor API support and must not include credentials, raw provider responses, or customer payment data."
$commercialApprovalRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-approval-evidence.ps1 -ProductVersion <version> -ApprovalRef <approval-ref> -ApprovedBy <approver> -ApprovedAt <iso-time> -PricingApprovalRef <ref> -TermsApprovalRef <ref> -SupportSlaApprovalRef <ref> -LicenseAgreementRef <ref> -LegalApprovalRef <ref> -PilotContractRef <ref> -PricingPolicyProposalEvidenceRef <ref> -PricingPolicyProposalJsonPath .\.osmu-run\billing-pricing-policy-proposals.json -ConfirmPricingApproved -ConfirmTermsApproved -ConfirmSupportSlaApproved -ConfirmLicenseApproved -ConfirmLegalApproved -ConfirmPricingPolicyProposalCommercialApproval -RequirePricingPolicyProposalApprovalSnapshot -ConfirmNoSecretValues -FailIfNotPassed" `
    ".github/workflows/manual-commercial-approval-evidence.yml" `
    "gh workflow run manual-commercial-approval-evidence.yml -f product_version=<version> -f approval_ref=<approval-ref> -f approved_by=<approver> -f approved_at=<iso-time> -f pricing_approval_ref=<ref> -f terms_approval_ref=<ref> -f support_sla_approval_ref=<ref> -f license_agreement_ref=<ref> -f legal_approval_ref=<ref> -f pilot_contract_ref=<ref> -f pricing_policy_proposal_evidence_ref=<ref> -f pricing_policy_proposal_json_base64=<base64-json> -f confirm_pricing_approved=true -f confirm_terms_approved=true -f confirm_support_sla_approved=true -f confirm_license_approved=true -f confirm_legal_approved=true -f confirm_pricing_policy_proposal_commercial_approval=true -f confirm_no_secret_values=true -f fail_if_not_passed=true" `
    "Run after final pricing, terms, support SLA, license agreement, legal approval, pilot contract boundary, and GET /api/admin/billing/pricing-policy-proposals?status=PRICE_LIST_APPROVED review. The pricing proposal JSON can be passed as base64 to the manual workflow, is reduced to sanitized status/reference metadata, and the decoded workflow input is deleted before artifact upload. The evidence stores references and booleans only; do not pass raw prices, raw legal terms, contracts, customer payment data, passwords, tokens, private keys, license keys, or signing secrets."
$enterpriseAuthSmokeRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-smoke-plan.ps1 -Execute -AdminLoginId <admin> -AdminPassword <secret> -RequireOidc -RequireLdap" `
    ".github/workflows/enterprise-auth-smoke-ci.yml" `
    "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f api_base=<api-base> -f admin_login_id=<admin> -f require_oidc=true -f require_ldap=true -f fail_if_not_passed=true" `
    "Run against the target pilot IdP/directory only after OIDC/LDAP provider flags and local user mapping are configured, or record an explicit commercial scope-out with write-enterprise-auth-smoke-plan.ps1 -ConfirmScopeOut -ScopeOutRef <approval-ref> -ScopeOutReason <reason>. The workflow requires OSMU_ENTERPRISE_AUTH_ADMIN_PASSWORD and, when LDAP is required, OSMU_ENTERPRISE_AUTH_LDAP_LOGIN_ID/OSMU_ENTERPRISE_AUTH_LDAP_PASSWORD secrets. Evidence does not include passwords, tokens, OIDC code/state, raw claim JSON, or credential-like scope-out references."
$operationsHandoffPackageRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-handoff-package.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -HandoffStartedAt <iso-time> -HandoffCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DeploymentEvidenceRef <ref> -OperationsReadinessRef <ref> -OperationsConvergenceRef <ref> -DataFlowStoragePlanEvidenceRef <ref> -OperationsReadinessJsonPath .\.osmu-run\latest-operations-readiness.json -OperationsConvergenceJsonPath .\.osmu-run\latest-operations-readiness-convergence.json -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -SecretRotationEvidenceRef <ref> -CommercialIntegrationEvidenceRef <ref> -CommercialApprovalEvidenceRef <ref> -CommercialIntegrationJsonPath .\.osmu-run\latest-commercial-integration-evidence.json -CommercialApprovalJsonPath .\.osmu-run\latest-commercial-approval-evidence.json -EnterpriseAuthEvidenceRef <ref> -BackupRestoreEvidenceRef <ref> -HaDrEvidenceRef <ref> -MonitoringEvidenceRef <ref> -SecurityEvidenceRef <ref> -IamRbacEvidenceRef <ref> -RunbookReviewRef <ref> -TroubleshootingReviewRef <ref> -SupportEscalationRef <ref> -SupportSlaRef <ref> -KnownGapsRef <ref> -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackReviewed -ConfirmSupportEscalationReviewed -ConfirmKnownGapsAccepted -ConfirmOperationsReadinessSnapshotReviewed -ConfirmOperationsConvergenceSnapshotReviewed -ConfirmDataFlowStoragePlanReviewed -ConfirmNoSecretValues -RequireProductionEvidence -RequireOperationsSnapshotEvidence -FailIfNotPassed" `
    ".github/workflows/manual-operations-handoff-package.yml" `
    "gh workflow run manual-operations-handoff-package.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f handoff_started_at=<iso-time> -f handoff_completed_at=<iso-time> -f change_approval_ref=<change-id> -f deployment_evidence_ref=<ref> -f operations_readiness_ref=<ref> -f operations_convergence_ref=<ref> -f data_flow_storage_plan_evidence_ref=<ref> -f operations_readiness_json_base64=<base64-json> -f operations_convergence_json_base64=<base64-json> -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f secret_rotation_evidence_ref=<ref> -f commercial_integration_evidence_ref=<ref> -f commercial_approval_evidence_ref=<ref> -f commercial_integration_json_base64=<base64-latest-commercial-integration-evidence-json> -f commercial_approval_json_base64=<base64-latest-commercial-approval-evidence-json> -f enterprise_auth_evidence_ref=<ref> -f backup_restore_evidence_ref=<ref> -f ha_dr_evidence_ref=<ref> -f monitoring_evidence_ref=<ref> -f security_evidence_ref=<ref> -f iam_rbac_evidence_ref=<ref> -f runbook_review_ref=<ref> -f troubleshooting_review_ref=<ref> -f support_escalation_ref=<ref> -f support_sla_ref=<ref> -f known_gaps_ref=<ref> -f confirm_runbook_reviewed=true -f confirm_troubleshooting_reviewed=true -f confirm_rollback_reviewed=true -f confirm_support_escalation_reviewed=true -f confirm_known_gaps_accepted=true -f confirm_operations_readiness_snapshot_reviewed=true -f confirm_operations_convergence_snapshot_reviewed=true -f confirm_data_flow_storage_plan_reviewed=true -f confirm_no_secret_values=true -f require_production_evidence=true -f require_operations_snapshot_evidence=true -f fail_if_not_passed=true" `
    "Run at pilot or production handoff after the operator has reviewed runbook, troubleshooting, rollback, support escalation, known gaps, commercial approval, target evidence, .osmu-run/latest-operations-readiness.json, .osmu-run/latest-operations-readiness-convergence.json, .osmu-run/latest-data-flow-storage-plan.json, .osmu-run/latest-commercial-integration-evidence.json, and .osmu-run/latest-commercial-approval-evidence.json. HandoffCompletedAt must be the same as or later than HandoffStartedAt. The readiness/convergence/data-flow/commercial JSON can be passed as base64 to the manual workflow and is reduced to sanitized result/count/sync/query-plan/commercial summary fields. The package stores references, booleans, and reduced snapshot summaries only; do not pass passwords, bearer tokens, kubeconfig values, private keys, provider credentials, raw SQL, raw EXPLAIN JSON, raw provider responses, raw remediation commands containing credentials, raw price tables, raw contract text, or customer payment data."

Add-Check "Release report available" "release" ($releaseReport.exists -and $releaseReport.parsed) $releaseReport.detail $releaseReport.path "latest release report generated by the release gate"

Add-ScopeCheck $releaseReport "kubernetesManifests" "Kubernetes manifest draft" "static-infra"
Add-ScopeCheck $releaseReport "helmChart" "Helm chart draft" "static-infra"
Add-ScopeCheck $releaseReport "networkPolicies" "NetworkPolicy draft" "security-hardening"
Add-ScopeCheck $releaseReport "containerHardening" "Container hardening draft" "security-hardening"
Add-ScopeCheck $releaseReport "tlsIngress" "TLS ingress draft" "security-hardening"
Add-ScopeCheck $releaseReport "secretRotationPolicy" "Secret rotation policy draft" "security-hardening"
Add-ScopeCheck $releaseReport "backupRestoreDrill" "Backup restore drill draft" "backup-restore"
Add-ScopeCheck $releaseReport "prometheusObservability" "Prometheus observability draft" "monitoring"
Add-ScopeCheck $releaseReport "monitoringArtifacts" "Monitoring artifacts draft" "monitoring"
Add-ScopeCheck $releaseReport "prometheusOperatorDraft" "Prometheus Operator draft" "monitoring"
Add-ScopeCheck $releaseReport "imageSigningPolicy" "Image signing policy draft" "security-hardening"
Add-ScopeCheck $releaseReport "containerSecurityCiWorkflow" "Container security CI workflow draft" "security-hardening"

Add-FileCheck "IAM/RBAC matrix verifier" "iam-rbac" ".\scripts\verify-iam-rbac-matrix.ps1" "IAM/RBAC matrix verifier committed"
Add-FileCheck "IAM/RBAC matrix document" "iam-rbac" ".\dev-docs\iam-rbac-matrix.md" "IAM/RBAC matrix document committed"
Add-FileCheck "IAM/RBAC finalizer" "iam-rbac" ".\scripts\finalize-iam-rbac-readiness.ps1" "IAM/RBAC finalizer committed"
Add-FileCheck "IAM/RBAC finalizer self-test" "iam-rbac" ".\scripts\verify-iam-rbac-finalizer.ps1" "IAM/RBAC finalizer self-test committed"
Add-FileCheck "IAM/RBAC finalizer workflow" "iam-rbac" ".\.github\workflows\iam-rbac-finalizer-ci.yml" "manual workflow for IAM/RBAC finalizer evidence"
Add-FileCheck "Kubernetes RBAC matrix verifier" "kubernetes-rbac" ".\scripts\verify-kubernetes-rbac-matrix.ps1" "Kubernetes RBAC matrix verifier committed"
Add-FileCheck "Kubernetes RBAC matrix document" "kubernetes-rbac" ".\dev-docs\kubernetes-rbac-matrix.md" "Kubernetes RBAC matrix document committed"
Add-FileCheck "Storage expansion finalizer workflow" "automation" ".\.github\workflows\storage-expansion-finalizer-ci.yml" "manual workflow for storage expansion finalizer evidence"
Add-FileCheck "Kubernetes HA/DR readiness workflow" "ha-dr" ".\.github\workflows\kubernetes-ha-dr-readiness-ci.yml" "manual workflow for Kubernetes HA/DR readiness evidence"
Add-FileCheck "Kubernetes DR finalizer workflow" "automation" ".\.github\workflows\kubernetes-dr-finalizer-ci.yml" "manual workflow for Kubernetes DR finalizer evidence"
Add-FileCheck "Operations readiness finalizer workflow" "automation" ".\.github\workflows\operations-readiness-finalizer-ci.yml" "manual workflow for combined operations readiness evidence"
Add-FileCheck "Operations readiness finalizer" "automation" ".\scripts\finalize-operations-readiness.ps1" "combined operations readiness finalizer committed"
Add-FileCheck "Operations readiness finalizer self-test" "automation" ".\scripts\verify-operations-readiness-finalizer.ps1" "operations readiness finalizer plan self-test committed"
Add-FileCheck "Operations readiness artifact importer" "automation" ".\scripts\import-operations-readiness-artifacts.ps1" "artifact importer for previously collected evidence committed"
Add-FileCheck "Operations readiness artifact importer self-test" "automation" ".\scripts\verify-operations-readiness-artifact-import.ps1" "artifact importer self-test committed"
Add-FileCheck "Operations readiness artifact finalizer workflow" "automation" ".\.github\workflows\operations-readiness-artifact-finalizer-ci.yml" "manual workflow for importing evidence artifacts and writing readiness report"
Add-FileCheck "Container security evidence writer" "security-hardening" ".\scripts\write-container-security-evidence.ps1" "container security evidence writer committed"
Add-FileCheck "Image signing evidence writer" "security-hardening" ".\scripts\write-image-signing-evidence.ps1" "image signing evidence writer committed"
Add-FileCheck "Security evidence writer self-test" "security-hardening" ".\scripts\verify-security-evidence-writers.ps1" "security evidence writer self-test committed"
Add-FileCheck "Storage backend telemetry evidence writer" "storage-backend" ".\scripts\write-storage-backend-telemetry-evidence.ps1" "storage backend telemetry evidence writer committed"
Add-FileCheck "Storage backend telemetry evidence writer self-test" "storage-backend" ".\scripts\verify-storage-backend-telemetry-evidence.ps1" "storage backend telemetry evidence writer self-test committed"
Add-FileCheck "Storage backend telemetry evidence workflow" "storage-backend" ".\.github\workflows\manual-storage-backend-telemetry-evidence.yml" "manual workflow for storage backend telemetry evidence"
Add-FileCheck "MariaDB query plan evidence writer" "data-flow" ".\scripts\write-mariadb-query-plan-evidence.ps1" "MariaDB query plan evidence writer committed"
Add-FileCheck "MariaDB query plan evidence self-test" "data-flow" ".\scripts\verify-mariadb-query-plan-evidence.ps1" "MariaDB query plan evidence self-test committed"
Add-FileCheck "Data-flow storage plan writer" "data-flow" ".\scripts\write-data-flow-storage-plan.ps1" "data-flow storage transition plan writer committed"
Add-FileCheck "Data-flow storage plan self-test" "data-flow" ".\scripts\verify-data-flow-storage-plan.ps1" "data-flow storage transition plan self-test committed"
Add-FileCheck "Data-flow storage plan evidence workflow" "data-flow" ".\.github\workflows\manual-data-flow-storage-plan-evidence.yml" "manual workflow for target data-flow storage transition evidence"
Add-FileCheck "Secret rotation evidence writer" "security-hardening" ".\scripts\write-secret-rotation-evidence.ps1" "secret rotation evidence writer committed"
Add-FileCheck "Secret rotation evidence writer self-test" "security-hardening" ".\scripts\verify-secret-rotation-evidence.ps1" "secret rotation evidence writer self-test committed"
Add-FileCheck "Secret rotation evidence workflow" "security-hardening" ".\.github\workflows\manual-secret-rotation-evidence.yml" "manual workflow for target secret/certificate rotation evidence"
Add-FileCheck "Commercial integration evidence writer" "commercial-integration" ".\scripts\write-commercial-integration-evidence.ps1" "commercial integration evidence writer committed"
Add-FileCheck "Commercial integration evidence writer self-test" "commercial-integration" ".\scripts\verify-commercial-integration-evidence.ps1" "commercial integration evidence writer self-test committed"
Add-FileCheck "Commercial integration evidence workflow" "commercial-integration" ".\.github\workflows\manual-commercial-integration-evidence.yml" "manual workflow for target notification/payment handoff evidence"
Add-FileCheck "Commercial approval evidence writer" "commercial-approval" ".\scripts\write-commercial-approval-evidence.ps1" "commercial approval evidence writer committed"
Add-FileCheck "Commercial approval evidence writer self-test" "commercial-approval" ".\scripts\verify-commercial-approval-evidence.ps1" "commercial approval evidence writer self-test committed"
Add-FileCheck "Commercial approval evidence workflow" "commercial-approval" ".\.github\workflows\manual-commercial-approval-evidence.yml" "manual workflow for final commercial approval evidence"
Add-FileCheck "Operations handoff package writer" "operations-handoff-package" ".\scripts\write-operations-handoff-package.ps1" "operations handoff package writer committed"
Add-FileCheck "Operations handoff package writer self-test" "operations-handoff-package" ".\scripts\verify-operations-handoff-package.ps1" "operations handoff package writer self-test committed"
Add-FileCheck "Operations handoff package workflow" "operations-handoff-package" ".\.github\workflows\manual-operations-handoff-package.yml" "manual workflow for target operations handoff package evidence"
Add-FileCheck "Security evidence finalizer" "security-hardening" ".\scripts\finalize-security-evidence.ps1" "security evidence finalizer committed"
Add-FileCheck "Security evidence finalizer self-test" "security-hardening" ".\scripts\verify-security-evidence-finalizer.ps1" "security evidence finalizer self-test committed"
Add-FileCheck "Security evidence finalizer workflow" "security-hardening" ".\.github\workflows\security-evidence-finalizer-ci.yml" "manual workflow for security evidence finalizer artifact promotion"
Add-FileCheck "Enterprise auth smoke workflow" "enterprise-auth" ".\.github\workflows\enterprise-auth-smoke-ci.yml" "manual workflow for target IdP/directory enterprise auth smoke evidence"
Add-FileCheck "Enterprise auth smoke evidence helper" "enterprise-auth" ".\scripts\write-enterprise-auth-smoke-plan.ps1" "enterprise auth smoke helper committed"
Add-FileCheck "Enterprise auth smoke evidence helper self-test" "enterprise-auth" ".\scripts\verify-enterprise-auth-smoke-plan.ps1" "enterprise auth smoke helper self-test committed"

Add-Check "Storage expansion finalizer live evidence" "storage-expansion" ($storageExpansionReport.exists -and $storageExpansionReport.parsed -and $storageExpansionReport.data.result -eq "passed") (Get-StorageExpansionDetail $storageExpansionReport) $storageExpansionReport.path "finalizer result=passed from target cluster" $storageExpansionRemediation
Add-Check "Kubernetes HA/DR readiness live evidence" "ha-dr" ($haDrReadinessReport.exists -and $haDrReadinessReport.parsed -and $haDrReadinessReport.data.result -eq "passed") (Get-HaDrReadinessDetail $haDrReadinessReport) $haDrReadinessReport.path "live Kubernetes HA/DR readiness result=passed" $haDrReadinessRemediation
Add-Check "Kubernetes DR finalizer live evidence" "ha-dr" ($kubernetesDrReport.exists -and $kubernetesDrReport.parsed -and $kubernetesDrReport.data.result -eq "ready") (Get-KubernetesDrFinalizeDetail $kubernetesDrReport) $kubernetesDrReport.path "finalizer result=ready from target cluster restore drill" $kubernetesDrRemediation
Add-Check "IAM/RBAC finalizer report" "iam-rbac" ($iamRbacFinalizeReport.exists -and $iamRbacFinalizeReport.parsed -and $iamRbacFinalizeReport.data.result -eq "passed") (Get-GenericResultDetail $iamRbacFinalizeReport) $iamRbacFinalizeReport.path "IAM/RBAC finalizer result=passed"
Add-Check "Security evidence finalizer report" "security-hardening" ($securityFinalizeReport.exists -and $securityFinalizeReport.parsed -and $securityFinalizeReport.data.result -eq "passed") (Get-GenericResultDetail $securityFinalizeReport) $securityFinalizeReport.path "security evidence finalizer result=passed from promoted CI artifacts" $securityFinalizeRemediation
Add-Check "Signed image evidence" "security-hardening" ($imageSigningReport.exists -and $imageSigningReport.parsed -and $imageSigningReport.data.result -eq "passed") (Get-GenericResultDetail $imageSigningReport) $imageSigningReport.path "published image digest and Cosign verification evidence" $imageSigningRemediation
Add-Check "Container scan/SBOM evidence" "security-hardening" ($containerSecurityReport.exists -and $containerSecurityReport.parsed -and $containerSecurityReport.data.result -eq "passed") (Get-GenericResultDetail $containerSecurityReport) $containerSecurityReport.path "successful container scan and SBOM artifact evidence" $containerSecurityRemediation
Add-Check "Storage backend telemetry target evidence" "storage-backend" ($storageBackendTelemetryReport.exists -and $storageBackendTelemetryReport.parsed -and $storageBackendTelemetryReport.data.result -eq "passed") (Get-StorageBackendTelemetryDetail $storageBackendTelemetryReport) $storageBackendTelemetryReport.path "storage backend telemetry result=passed from target MinIO admin info evidence" $storageBackendTelemetryRemediation
Add-Check "Data-flow storage transition target evidence" "data-flow" (Test-DataFlowStoragePlanEvidenceAccepted $dataFlowStoragePlanReport) (Get-DataFlowStoragePlanDetail $dataFlowStoragePlanReport) $dataFlowStoragePlanReport.path "data-flow storage transition plan result=passed with target query-plan evidence for MariaDB partition or dual-write candidates" $dataFlowStoragePlanRemediation
Add-Check "Secret/certificate rotation target evidence" "security-hardening" ($secretRotationReport.exists -and $secretRotationReport.parsed -and $secretRotationReport.data.result -eq "passed") (Get-GenericResultDetail $secretRotationReport) $secretRotationReport.path "secret/certificate rotation evidence result=passed from target environment" $secretRotationRemediation
Add-Check "Commercial integration target evidence" "commercial-integration" ($commercialIntegrationReport.exists -and $commercialIntegrationReport.parsed -and $commercialIntegrationReport.data.result -eq "passed") (Get-GenericResultDetail $commercialIntegrationReport) $commercialIntegrationReport.path "commercial integration evidence result=passed from target environment" $commercialIntegrationRemediation
Add-Check "Commercial approval target evidence" "commercial-approval" ($commercialApprovalReport.exists -and $commercialApprovalReport.parsed -and $commercialApprovalReport.data.result -eq "passed") (Get-GenericResultDetail $commercialApprovalReport) $commercialApprovalReport.path "commercial approval evidence result=passed for final pricing, terms, support SLA, license agreement, legal approval, and pilot contract boundary" $commercialApprovalRemediation
Add-Check "Enterprise auth target smoke evidence" "enterprise-auth" (Test-EnterpriseAuthEvidenceAccepted $enterpriseAuthSmokeReport) (Get-GenericResultDetail $enterpriseAuthSmokeReport) $enterpriseAuthSmokeReport.path "enterprise auth smoke result=passed from target IdP/directory, or result=scope-out with explicit commercial approval reference and reason" $enterpriseAuthSmokeRemediation
Add-Check "Operations handoff package target evidence" "operations-handoff-package" ($operationsHandoffPackageReport.exists -and $operationsHandoffPackageReport.parsed -and $operationsHandoffPackageReport.data.result -eq "passed") (Get-GenericResultDetail $operationsHandoffPackageReport) $operationsHandoffPackageReport.path "operations handoff package result=passed from target environment" $operationsHandoffPackageRemediation

$passedCount = @($checks | Where-Object { $_.passed }).Count
$pendingCount = @($checks | Where-Object { -not $_.passed }).Count
$result = if ($pendingCount -eq 0) { "ready" } else { "pending" }
$generatedAt = [DateTimeOffset]::Now.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath

$report = [ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    generatedAt = $generatedAt
    result = $result
    passedCount = $passedCount
    pendingCount = $pendingCount
    summary = "passed=$passedCount pending=$pendingCount"
    inputs = [ordered]@{
        releaseReport = $releaseReport.path
        storageExpansionFinalizeReport = $storageExpansionReport.path
        kubernetesHaDrReadinessReport = $haDrReadinessReport.path
        kubernetesDrFinalizeReport = $kubernetesDrReport.path
        iamRbacFinalizeReport = $iamRbacFinalizeReport.path
        securityEvidenceFinalizeReport = $securityFinalizeReport.path
        imageSigningEvidence = $imageSigningReport.path
        containerSecurityEvidence = $containerSecurityReport.path
        storageBackendTelemetryEvidence = $storageBackendTelemetryReport.path
        dataFlowStoragePlan = $dataFlowStoragePlanReport.path
        secretRotationEvidence = $secretRotationReport.path
        commercialIntegrationEvidence = $commercialIntegrationReport.path
        commercialApprovalEvidence = $commercialApprovalReport.path
        enterpriseAuthSmokeEvidence = $enterpriseAuthSmokeReport.path
        operationsHandoffPackage = $operationsHandoffPackageReport.path
    }
    checks = $checks
    decisionRule = "Production/B2B operations readiness is ready only when every listed static, automation, live Kubernetes, storage expansion, storage backend telemetry, data-flow storage transition, HA/DR, security, secret rotation, commercial integration, commercial approval, enterprise auth, and operations handoff package evidence check is PASS."
}

$markdownLines = @(
    "# OSMU Operations Readiness",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Summary: passed=$passedCount pending=$pendingCount",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Checks",
    ""
)

foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.category) / $($check.name): $($check.detail)"
}

$markdownLines += ""
$markdownLines += "## Required Next Evidence"
$markdownLines += ""
foreach ($check in ($checks | Where-Object { -not $_.passed })) {
    $markdownLines += "- $($check.name): $($check.requiredEvidence); path=$($check.evidencePath)"
    $remediation = $check.remediation
    if ($null -ne $remediation) {
        if (-not [string]::IsNullOrWhiteSpace([string] $remediation.command)) {
            $markdownLines += "  - Remediation command: ``$($remediation.command)``"
        }
        if (-not [string]::IsNullOrWhiteSpace([string] $remediation.workflow)) {
            $markdownLines += "  - Workflow: ``$($remediation.workflow)``"
        }
        if (-not [string]::IsNullOrWhiteSpace([string] $remediation.workflowCommand)) {
            $markdownLines += "  - Workflow command: ``$($remediation.workflowCommand)``"
        }
        if (-not [string]::IsNullOrWhiteSpace([string] $remediation.note)) {
            $markdownLines += "  - Note: $($remediation.note)"
        }
    }
}

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations readiness JSON: $resolvedJsonOutputPath"
    Write-Host "Operations readiness summary: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotReady -and $result -ne "ready") {
    throw "Operations readiness is not ready: $($report.summary)"
}
