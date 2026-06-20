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
    -SecretRotationEvidenceRef "latest-secret-rotation-evidence-passed-20260620" `
    -CommercialIntegrationEvidenceRef "latest-commercial-integration-evidence-passed-20260620" `
    -CommercialApprovalEvidenceRef "latest-commercial-approval-evidence-passed-20260620" `
    -EnterpriseAuthEvidenceRef "latest-enterprise-auth-smoke-passed-20260620" `
    -BackupRestoreEvidenceRef "latest-kubernetes-dr-finalize-ready-20260620" `
    -HaDrEvidenceRef "latest-kubernetes-ha-dr-readiness-passed-20260620" `
    -MonitoringEvidenceRef "prometheus-alertmanager-grafana-review-20260620" `
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
    -ConfirmNoSecretValues `
    -RequireProductionEvidence `
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
Assert-True ($checks.Count -ge 23) "Expected operations handoff package checks."
Assert-True (@($checks | Where-Object { $_.id -eq "handoff-window-order" -and $_.passed }).Count -eq 1) "Expected handoff window order check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "commercial-approval-evidence" -and $_.passed }).Count -eq 1) "Expected commercial approval evidence check to pass."
Assert-True ($report.confirmations.noSecretValues) "Expected no-secret-values confirmation."
Assert-True ($report.confirmations.runbookReviewed) "Expected runbook reviewed confirmation."
Assert-True ($report.confirmations.troubleshootingReviewed) "Expected troubleshooting reviewed confirmation."
Assert-True ($report.confirmations.rollbackReviewed) "Expected rollback reviewed confirmation."
Assert-True ($report.confirmations.supportEscalationReviewed) "Expected support escalation reviewed confirmation."
Assert-True ($report.confirmations.knownGapsAccepted) "Expected known gaps accepted confirmation."
Assert-True ($report.confirmations.requireProductionEvidence) "Expected production evidence requirement."

Assert-Contains $markdown "# OSMU Operations Handoff Package" "operations handoff package markdown"
Assert-Contains $markdown "Record passed target package" "operations handoff package markdown"
Assert-Contains $report.decisionRule "Production/B2B operations handoff package readiness requires result=passed" "operations handoff package JSON"
Assert-Contains $report.decisionRule "commercial approval" "operations handoff package JSON"
Assert-Contains $report.scopePolicy "does not execute kubectl, gh, provider APIs" "operations handoff package JSON"
Assert-Contains $report.secretPolicy "must not contain passwords, bearer tokens, kubeconfig values" "operations handoff package JSON"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----")) {
    Assert-NotContains $reportText $unexpected "operations handoff package JSON"
    Assert-NotContains $markdown $unexpected "operations handoff package markdown"
}

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
        -SecretRotationEvidenceRef "latest-secret-rotation-evidence-passed-20260620" `
        -CommercialIntegrationEvidenceRef "latest-commercial-integration-evidence-passed-20260620" `
        -CommercialApprovalEvidenceRef "latest-commercial-approval-evidence-passed-20260620" `
        -EnterpriseAuthEvidenceRef "latest-enterprise-auth-smoke-passed-20260620" `
        -BackupRestoreEvidenceRef "latest-kubernetes-dr-finalize-ready-20260620" `
        -HaDrEvidenceRef "latest-kubernetes-ha-dr-readiness-passed-20260620" `
        -MonitoringEvidenceRef "prometheus-alertmanager-grafana-review-20260620" `
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
