param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $StorageExpansionFinalizeReportPath = ".\.osmu-run\latest-storage-expansion-finalize.json",
    [string] $KubernetesHaDrReadinessReportPath = ".\.osmu-run\latest-kubernetes-ha-dr-readiness.json",
    [string] $KubernetesDrFinalizeReportPath = ".\.osmu-run\latest-kubernetes-dr-finalize.json",
    [string] $IamRbacFinalizeReportPath = ".\.osmu-run\latest-iam-rbac-finalize.json",
    [string] $SecurityEvidenceFinalizeReportPath = ".\.osmu-run\latest-security-evidence-finalize.json",
    [string] $ImageSigningEvidencePath = ".\.osmu-run\latest-image-signing-evidence.json",
    [string] $ContainerSecurityEvidencePath = ".\.osmu-run\latest-container-security-evidence.json",
    [string] $SecretRotationEvidencePath = ".\.osmu-run\latest-secret-rotation-evidence.json",
    [string] $CommercialIntegrationEvidencePath = ".\.osmu-run\latest-commercial-integration-evidence.json",
    [string] $EnterpriseAuthSmokeEvidencePath = ".\.osmu-run\latest-enterprise-auth-smoke.json",
    [string] $OperationsHandoffPackagePath = ".\.osmu-run\latest-operations-handoff-package.json",
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

$releaseReport = Read-JsonReport $ReleaseReportPath "MVP release report"
$storageExpansionReport = Read-JsonReport $StorageExpansionFinalizeReportPath "Storage expansion finalizer"
$haDrReadinessReport = Read-JsonReport $KubernetesHaDrReadinessReportPath "Kubernetes HA/DR readiness"
$kubernetesDrReport = Read-JsonReport $KubernetesDrFinalizeReportPath "Kubernetes DR finalizer"
$iamRbacFinalizeReport = Read-JsonReport $IamRbacFinalizeReportPath "IAM/RBAC finalizer"
$securityFinalizeReport = Read-JsonReport $SecurityEvidenceFinalizeReportPath "Security evidence finalizer"
$imageSigningReport = Read-JsonReport $ImageSigningEvidencePath "Image signing evidence"
$containerSecurityReport = Read-JsonReport $ContainerSecurityEvidencePath "Container security evidence"
$secretRotationReport = Read-JsonReport $SecretRotationEvidencePath "Secret rotation evidence"
$commercialIntegrationReport = Read-JsonReport $CommercialIntegrationEvidencePath "Commercial integration evidence"
$enterpriseAuthSmokeReport = Read-JsonReport $EnterpriseAuthSmokeEvidencePath "Enterprise auth smoke evidence"
$operationsHandoffPackageReport = Read-JsonReport $OperationsHandoffPackagePath "Operations handoff package"

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
$secretRotationRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-secret-rotation-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -RotationStartedAt <iso-time> -RotationCompletedAt <iso-time> -ChangeApprovalRef <change-id> -SecretManagerEvidenceRef <audit-ref> -WorkloadRestartEvidenceRef <rollout-ref> -SmokeEvidenceRef <smoke-ref> -ArtifactLeakReviewEvidenceRef <scan-ref> -AccessKeyEncryptionDecisionRef <decision-ref> -RotateAdminPassword -RotateJwtSigningSecret -RotateDatabaseCredentials -RotateMinioRootCredentials -RotateTlsCertificate -ConfirmNoSecretValues -ConfirmWorkloadRestart -ConfirmSmokePassed -ConfirmArtifactLeakReview -FailIfNotPassed" `
    "" `
    "" `
    "Run after target-environment secret/certificate rotation. RotationCompletedAt must be the same as or later than RotationStartedAt. The evidence stores references and booleans only; do not pass secret values, tokens, private keys, kubeconfig, database credentials, MinIO credentials, OIDC/LDAP secrets, SMTP credentials, or webhook signing secrets."
$commercialIntegrationRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-integration-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -VerificationStartedAt <iso-time> -VerificationCompletedAt <iso-time> -ChangeApprovalRef <change-id> -NotificationWebhookEvidenceRef <ref> -SlackWebhookEvidenceRef <ref> -EmailSmtpEvidenceRef <ref> -PaymentGenericWebhookEvidenceRef <ref> -PaymentCardProfileEvidenceRef <ref> -PaymentBankProfileEvidenceRef <ref> -PaymentTaxProfileEvidenceRef <ref> -PaymentErpProfileEvidenceRef <ref> -AdapterRetryWorkerEvidenceRef <ref> -PayloadReviewEvidenceRef <ref> -PrivateNetworkBlockEvidenceRef <ref> -HmacSignatureEvidenceRef <ref> -VerifiedNotificationWebhook -VerifiedSlackWebhook -VerifiedEmailSmtp -VerifiedPaymentGenericWebhook -VerifiedPaymentCardProfile -VerifiedPaymentBankProfile -VerifiedPaymentTaxProfile -VerifiedPaymentErpProfile -ConfirmAdapterRetryWorkerRun -ConfirmPayloadSizeCaps -ConfirmPrivateNetworkBlocking -ConfirmHmacSignatureHeaders -ConfirmNoSecretValues -ConfirmNoRawProviderResponses -RequireAllImplementedAdapters -FailIfNotPassed" `
    "" `
    "" `
    "Run after target-environment notification webhook, Slack, EMAIL SMTP relay, generic payment webhook, and CARD/BANK/TAX/ERP payment webhook profile handoff checks. VerificationCompletedAt must be the same as or later than VerificationStartedAt. This evidence does not claim native card/bank/tax/ERP processor API support and must not include credentials, raw provider responses, or customer payment data."
$enterpriseAuthSmokeRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-smoke-plan.ps1 -Execute -AdminLoginId <admin> -AdminPassword <secret> -RequireOidc -RequireLdap" `
    ".github/workflows/enterprise-auth-smoke-ci.yml" `
    "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f api_base=<api-base> -f admin_login_id=<admin> -f require_oidc=true -f require_ldap=true -f fail_if_not_passed=true" `
    "Run against the target pilot IdP/directory only after OIDC/LDAP provider flags and local user mapping are configured. The workflow requires OSMU_ENTERPRISE_AUTH_ADMIN_PASSWORD and, when LDAP is required, OSMU_ENTERPRISE_AUTH_LDAP_LOGIN_ID/OSMU_ENTERPRISE_AUTH_LDAP_PASSWORD secrets. Evidence does not include passwords, tokens, OIDC code/state, or raw claim JSON."
$operationsHandoffPackageRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-handoff-package.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -HandoffStartedAt <iso-time> -HandoffCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DeploymentEvidenceRef <ref> -OperationsReadinessRef <ref> -OperationsConvergenceRef <ref> -SecretRotationEvidenceRef <ref> -CommercialIntegrationEvidenceRef <ref> -EnterpriseAuthEvidenceRef <ref> -BackupRestoreEvidenceRef <ref> -HaDrEvidenceRef <ref> -MonitoringEvidenceRef <ref> -SecurityEvidenceRef <ref> -IamRbacEvidenceRef <ref> -RunbookReviewRef <ref> -TroubleshootingReviewRef <ref> -SupportEscalationRef <ref> -SupportSlaRef <ref> -KnownGapsRef <ref> -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackReviewed -ConfirmSupportEscalationReviewed -ConfirmKnownGapsAccepted -ConfirmNoSecretValues -RequireProductionEvidence -FailIfNotPassed" `
    "" `
    "" `
    "Run at pilot or production handoff after the operator has reviewed runbook, troubleshooting, rollback, support escalation, known gaps, and target evidence. HandoffCompletedAt must be the same as or later than HandoffStartedAt. The package stores references and booleans only; do not pass passwords, bearer tokens, kubeconfig values, private keys, provider credentials, raw provider responses, or customer payment data."

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
Add-FileCheck "Secret rotation evidence writer" "security-hardening" ".\scripts\write-secret-rotation-evidence.ps1" "secret rotation evidence writer committed"
Add-FileCheck "Secret rotation evidence writer self-test" "security-hardening" ".\scripts\verify-secret-rotation-evidence.ps1" "secret rotation evidence writer self-test committed"
Add-FileCheck "Commercial integration evidence writer" "commercial-integration" ".\scripts\write-commercial-integration-evidence.ps1" "commercial integration evidence writer committed"
Add-FileCheck "Commercial integration evidence writer self-test" "commercial-integration" ".\scripts\verify-commercial-integration-evidence.ps1" "commercial integration evidence writer self-test committed"
Add-FileCheck "Operations handoff package writer" "operations-handoff-package" ".\scripts\write-operations-handoff-package.ps1" "operations handoff package writer committed"
Add-FileCheck "Operations handoff package writer self-test" "operations-handoff-package" ".\scripts\verify-operations-handoff-package.ps1" "operations handoff package writer self-test committed"
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
Add-Check "Secret/certificate rotation target evidence" "security-hardening" ($secretRotationReport.exists -and $secretRotationReport.parsed -and $secretRotationReport.data.result -eq "passed") (Get-GenericResultDetail $secretRotationReport) $secretRotationReport.path "secret/certificate rotation evidence result=passed from target environment" $secretRotationRemediation
Add-Check "Commercial integration target evidence" "commercial-integration" ($commercialIntegrationReport.exists -and $commercialIntegrationReport.parsed -and $commercialIntegrationReport.data.result -eq "passed") (Get-GenericResultDetail $commercialIntegrationReport) $commercialIntegrationReport.path "commercial integration evidence result=passed from target environment" $commercialIntegrationRemediation
Add-Check "Enterprise auth target smoke evidence" "enterprise-auth" ($enterpriseAuthSmokeReport.exists -and $enterpriseAuthSmokeReport.parsed -and $enterpriseAuthSmokeReport.data.result -eq "passed") (Get-GenericResultDetail $enterpriseAuthSmokeReport) $enterpriseAuthSmokeReport.path "enterprise auth smoke result=passed from target IdP/directory, or explicit commercial scope-out" $enterpriseAuthSmokeRemediation
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
        secretRotationEvidence = $secretRotationReport.path
        commercialIntegrationEvidence = $commercialIntegrationReport.path
        enterpriseAuthSmokeEvidence = $enterpriseAuthSmokeReport.path
        operationsHandoffPackage = $operationsHandoffPackageReport.path
    }
    checks = $checks
    decisionRule = "Production/B2B operations readiness is ready only when every listed static, automation, live Kubernetes, storage expansion, HA/DR, security, secret rotation, commercial integration, enterprise auth, and operations handoff package evidence check is PASS."
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
