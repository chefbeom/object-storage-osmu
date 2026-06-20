param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $HandoffStartedAt = "",
    [string] $HandoffCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $DeploymentEvidenceRef = "",
    [string] $OperationsReadinessRef = "",
    [string] $OperationsConvergenceRef = "",
    [string] $SecretRotationEvidenceRef = "",
    [string] $CommercialIntegrationEvidenceRef = "",
    [string] $EnterpriseAuthEvidenceRef = "",
    [string] $BackupRestoreEvidenceRef = "",
    [string] $HaDrEvidenceRef = "",
    [string] $MonitoringEvidenceRef = "",
    [string] $SecurityEvidenceRef = "",
    [string] $IamRbacEvidenceRef = "",
    [string] $RunbookReviewRef = "",
    [string] $TroubleshootingReviewRef = "",
    [string] $SupportEscalationRef = "",
    [string] $SupportSlaRef = "",
    [string] $KnownGapsRef = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-handoff-package.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-handoff-package.md",
    [switch] $ConfirmRunbookReviewed,
    [switch] $ConfirmTroubleshootingReviewed,
    [switch] $ConfirmRollbackReviewed,
    [switch] $ConfirmSupportEscalationReviewed,
    [switch] $ConfirmKnownGapsAccepted,
    [switch] $ConfirmNoSecretValues,
    [switch] $RequireProductionEvidence,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-SafeReference([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "(?i)\b(password|passwd|secret|token|client_secret|x-amz-security-token|smtp_pass|webhook_secret|kubeconfig)\s*[=:]\s*\S+"
    )

    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain credential material. Store only an external evidence reference."
        }
    }
}

function Test-DateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse($Value, [ref] $parsed)
}

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail, [string] $EvidenceRef) {
    return [ordered]@{
        id = $Id
        name = $Name
        status = $Status
        passed = $Status -eq "PASS"
        detail = $Detail
        evidenceRef = $EvidenceRef
    }
}

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail, [string] $EvidenceRef = "") {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    [void] $script:checks.Add((New-Check $Id $Name $status $Detail $EvidenceRef))
}

function Add-PlannedCheck([string] $Id, [string] $Name, [string] $Detail, [string] $EvidenceRef = "") {
    [void] $script:checks.Add((New-Check $Id $Name "PLANNED" $Detail $EvidenceRef))
}

function Add-EvidenceCheck([string] $Id, [string] $Name, [bool] $Required, [string] $EvidenceRef, [string] $Detail) {
    if ($Required) {
        Add-Check $Id $Name (-not [string]::IsNullOrWhiteSpace($EvidenceRef)) "$Detail; required=true; evidenceRef=$EvidenceRef" $EvidenceRef
    }
    elseif (-not [string]::IsNullOrWhiteSpace($EvidenceRef)) {
        Add-Check $Id $Name $true "$Detail; required=false; evidenceRef=$EvidenceRef" $EvidenceRef
    }
    else {
        Add-PlannedCheck $Id "$Name planned" "$Detail; required=false; no target evidence recorded." $EvidenceRef
    }
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef),
    @("DeploymentEvidenceRef", $DeploymentEvidenceRef),
    @("OperationsReadinessRef", $OperationsReadinessRef),
    @("OperationsConvergenceRef", $OperationsConvergenceRef),
    @("SecretRotationEvidenceRef", $SecretRotationEvidenceRef),
    @("CommercialIntegrationEvidenceRef", $CommercialIntegrationEvidenceRef),
    @("EnterpriseAuthEvidenceRef", $EnterpriseAuthEvidenceRef),
    @("BackupRestoreEvidenceRef", $BackupRestoreEvidenceRef),
    @("HaDrEvidenceRef", $HaDrEvidenceRef),
    @("MonitoringEvidenceRef", $MonitoringEvidenceRef),
    @("SecurityEvidenceRef", $SecurityEvidenceRef),
    @("IamRbacEvidenceRef", $IamRbacEvidenceRef),
    @("RunbookReviewRef", $RunbookReviewRef),
    @("TroubleshootingReviewRef", $TroubleshootingReviewRef),
    @("SupportEscalationRef", $SupportEscalationRef),
    @("SupportSlaRef", $SupportSlaRef),
    @("KnownGapsRef", $KnownGapsRef)
)) {
    Assert-SafeReference ([string] $entry[1]) ([string] $entry[0])
}

$evidenceText = $DeploymentEvidenceRef + $OperationsReadinessRef + $OperationsConvergenceRef + $SecretRotationEvidenceRef + $CommercialIntegrationEvidenceRef + $EnterpriseAuthEvidenceRef + $BackupRestoreEvidenceRef + $HaDrEvidenceRef + $MonitoringEvidenceRef + $SecurityEvidenceRef + $IamRbacEvidenceRef + $RunbookReviewRef + $TroubleshootingReviewRef + $SupportEscalationRef + $SupportSlaRef + $KnownGapsRef
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $HandoffStartedAt + $HandoffCompletedAt + $ChangeApprovalRef + $evidenceText) -or $ConfirmRunbookReviewed -or $ConfirmTroubleshootingReviewed -or $ConfirmRollbackReviewed -or $ConfirmSupportEscalationReviewed -or $ConfirmKnownGapsAccepted -or $ConfirmNoSecretValues

Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($Operator)) "operator=$Operator"
Add-Check "handoff-started-at" "Handoff start timestamp recorded" (Test-DateText $HandoffStartedAt) "handoffStartedAt=$HandoffStartedAt"
Add-Check "handoff-completed-at" "Handoff completion timestamp recorded" (Test-DateText $HandoffCompletedAt) "handoffCompletedAt=$HandoffCompletedAt"
Add-Check "change-approval-ref" "Change approval reference recorded" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "changeApprovalRef=$ChangeApprovalRef" $ChangeApprovalRef
Add-Check "no-secret-values-confirmed" "No credential values recorded confirmation" ([bool] $ConfirmNoSecretValues) "Evidence stores references and booleans only."
Add-Check "runbook-reviewed" "Operator runbook reviewed" ([bool] $ConfirmRunbookReviewed -and -not [string]::IsNullOrWhiteSpace($RunbookReviewRef)) "runbookReviewRef=$RunbookReviewRef" $RunbookReviewRef
Add-Check "troubleshooting-reviewed" "Troubleshooting guide reviewed" ([bool] $ConfirmTroubleshootingReviewed -and -not [string]::IsNullOrWhiteSpace($TroubleshootingReviewRef)) "troubleshootingReviewRef=$TroubleshootingReviewRef" $TroubleshootingReviewRef
Add-Check "rollback-reviewed" "Rollback path reviewed" ([bool] $ConfirmRollbackReviewed -and -not [string]::IsNullOrWhiteSpace($DeploymentEvidenceRef)) "deploymentEvidenceRef=$DeploymentEvidenceRef" $DeploymentEvidenceRef
Add-Check "support-escalation-reviewed" "Support escalation path reviewed" ([bool] $ConfirmSupportEscalationReviewed -and -not [string]::IsNullOrWhiteSpace($SupportEscalationRef) -and -not [string]::IsNullOrWhiteSpace($SupportSlaRef)) "supportEscalationRef=$SupportEscalationRef; supportSlaRef=$SupportSlaRef" $SupportEscalationRef
Add-Check "known-gaps-accepted" "Known gaps accepted" ([bool] $ConfirmKnownGapsAccepted -and -not [string]::IsNullOrWhiteSpace($KnownGapsRef)) "knownGapsRef=$KnownGapsRef" $KnownGapsRef

Add-EvidenceCheck "operations-readiness-evidence" "Operations readiness target evidence" ([bool] $RequireProductionEvidence) $OperationsReadinessRef "latest operations readiness result=ready or accepted target report"
Add-EvidenceCheck "operations-convergence-evidence" "Operations convergence target evidence" ([bool] $RequireProductionEvidence) $OperationsConvergenceRef "latest operations convergence and dashboard sync evidence"
Add-EvidenceCheck "secret-rotation-evidence" "Secret/certificate rotation target evidence" ([bool] $RequireProductionEvidence) $SecretRotationEvidenceRef "target secret/certificate rotation result=passed"
Add-EvidenceCheck "commercial-integration-evidence" "Commercial integration target evidence" ([bool] $RequireProductionEvidence) $CommercialIntegrationEvidenceRef "target commercial integration result=passed without native processor API claims"
Add-EvidenceCheck "enterprise-auth-evidence" "Enterprise auth target evidence" ([bool] $RequireProductionEvidence) $EnterpriseAuthEvidenceRef "target IdP/directory smoke result=passed or contracted scope-out"
Add-EvidenceCheck "backup-restore-evidence" "Backup/restore target evidence" ([bool] $RequireProductionEvidence) $BackupRestoreEvidenceRef "target backup restore or DR drill evidence"
Add-EvidenceCheck "ha-dr-evidence" "HA/DR target evidence" ([bool] $RequireProductionEvidence) $HaDrEvidenceRef "target HA/DR readiness evidence"
Add-EvidenceCheck "monitoring-evidence" "Monitoring target evidence" ([bool] $RequireProductionEvidence) $MonitoringEvidenceRef "target Prometheus/Alertmanager/Grafana evidence"
Add-EvidenceCheck "security-evidence" "Security target evidence" ([bool] $RequireProductionEvidence) $SecurityEvidenceRef "target image signing/container security evidence"
Add-EvidenceCheck "iam-rbac-evidence" "IAM/RBAC target evidence" ([bool] $RequireProductionEvidence) $IamRbacEvidenceRef "target IAM/RBAC finalizer evidence"

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$plannedCount = @($checks | Where-Object { $_.status -eq "PLANNED" }).Count
$passedCount = @($checks | Where-Object { $_.status -eq "PASS" }).Count
$result = if (-not $hasAnyInput) {
    "planned"
}
elseif ($failureCount -eq 0) {
    "passed"
}
else {
    "failed"
}

$generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$checkArray = @($checks | ForEach-Object { $_ })

$evidenceRefs = [ordered]@{
    changeApproval = $ChangeApprovalRef
    deployment = $DeploymentEvidenceRef
    operationsReadiness = $OperationsReadinessRef
    operationsConvergence = $OperationsConvergenceRef
    secretRotation = $SecretRotationEvidenceRef
    commercialIntegration = $CommercialIntegrationEvidenceRef
    enterpriseAuth = $EnterpriseAuthEvidenceRef
    backupRestore = $BackupRestoreEvidenceRef
    haDr = $HaDrEvidenceRef
    monitoring = $MonitoringEvidenceRef
    security = $SecurityEvidenceRef
    iamRbac = $IamRbacEvidenceRef
    runbookReview = $RunbookReviewRef
    troubleshootingReview = $TroubleshootingReviewRef
    supportEscalation = $SupportEscalationRef
    supportSla = $SupportSlaRef
    knownGaps = $KnownGapsRef
}

$report = New-Object System.Collections.Specialized.OrderedDictionary
[void] $report.Add("formatVersion", "osmu.operations-handoff-package.v1")
[void] $report.Add("generatedAt", $generatedAt)
[void] $report.Add("result", $result)
[void] $report.Add("environmentName", $EnvironmentName)
[void] $report.Add("targetCluster", $TargetCluster)
[void] $report.Add("operatorName", $Operator)
[void] $report.Add("handoffWindow", [ordered]@{
    startedAt = $HandoffStartedAt
    completedAt = $HandoffCompletedAt
})
[void] $report.Add("evidenceRefs", $evidenceRefs)
[void] $report.Add("confirmations", [ordered]@{
    noSecretValues = [bool] $ConfirmNoSecretValues
    runbookReviewed = [bool] $ConfirmRunbookReviewed
    troubleshootingReviewed = [bool] $ConfirmTroubleshootingReviewed
    rollbackReviewed = [bool] $ConfirmRollbackReviewed
    supportEscalationReviewed = [bool] $ConfirmSupportEscalationReviewed
    knownGapsAccepted = [bool] $ConfirmKnownGapsAccepted
    requireProductionEvidence = [bool] $RequireProductionEvidence
})
[void] $report.Add("summary", [ordered]@{
    passedCount = $passedCount
    failureCount = $failureCount
    plannedCount = $plannedCount
    checkCount = $checkArray.Count
})
[void] $report.Add("checks", [object] $checkArray)
[void] $report.Add("decisionRule", "Production/B2B operations handoff package readiness requires result=passed from the target environment, reviewed runbook/troubleshooting/rollback/support paths, accepted known gaps, no-secret confirmation, and references to target readiness, convergence, secret rotation, commercial integration, enterprise auth, backup/restore, HA/DR, monitoring, security, and IAM/RBAC evidence when production evidence is required.")
[void] $report.Add("scopePolicy", "This package is a handoff wrapper for already-collected operations evidence. It does not execute kubectl, gh, provider APIs, notification adapters, payment adapters, or native card/bank/tax/ERP processor calls.")
[void] $report.Add("secretPolicy", "Evidence stores only environment labels, operator/change references, timestamps, booleans, and external evidence references; it must not contain passwords, bearer tokens, kubeconfig values, private keys, SMTP credentials, webhook signing secrets, provider credentials, raw provider responses, or customer payment data.")

$markdownLines = @(
    "# OSMU Operations Handoff Package",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Environment: $EnvironmentName",
    "Target cluster: $TargetCluster",
    "Operator: $Operator",
    "",
    "## Decision Rule",
    "",
    $report["decisionRule"],
    "",
    "## Scope Policy",
    "",
    $report["scopePolicy"],
    "",
    "## Secret Policy",
    "",
    $report["secretPolicy"],
    "",
    "## Evidence References",
    ""
)

foreach ($key in $evidenceRefs.Keys) {
    $markdownLines += "- ${key}: $($evidenceRefs[$key])"
}

$markdownLines += ""
$markdownLines += "## Checks"
$markdownLines += ""
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}

$markdownLines += ""
$markdownLines += "## Operator Command"
$markdownLines += ""
$markdownLines += "- Record passed target package: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-handoff-package.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -HandoffStartedAt <iso-time> -HandoffCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DeploymentEvidenceRef <ref> -OperationsReadinessRef <ref> -OperationsConvergenceRef <ref> -SecretRotationEvidenceRef <ref> -CommercialIntegrationEvidenceRef <ref> -EnterpriseAuthEvidenceRef <ref> -BackupRestoreEvidenceRef <ref> -HaDrEvidenceRef <ref> -MonitoringEvidenceRef <ref> -SecurityEvidenceRef <ref> -IamRbacEvidenceRef <ref> -RunbookReviewRef <ref> -TroubleshootingReviewRef <ref> -SupportEscalationRef <ref> -SupportSlaRef <ref> -KnownGapsRef <ref> -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackReviewed -ConfirmSupportEscalationReviewed -ConfirmKnownGapsAccepted -ConfirmNoSecretValues -RequireProductionEvidence -FailIfNotPassed``"

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations handoff package JSON: $resolvedJsonOutputPath"
    Write-Host "Operations handoff package markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Operations handoff package did not pass: result=$result failureCount=$failureCount"
}
