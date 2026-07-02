param(
    [string] $OutputDirectory = ".\.osmu-run\support-escalation-handoff-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return [System.IO.Path]::GetFullPath($PathValue) }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    $resolvedPath = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}

function Assert-True([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Assert-Contains([string] $Text, [string] $Expected, [string] $Label) { if (-not $Text.Contains($Expected)) { throw "$Label does not contain expected text: $Expected" } }
function Assert-NotContains([string] $Text, [string] $Unexpected, [string] $Label) { if ($Text.Contains($Unexpected)) { throw "$Label contains unexpected secret/raw text: $Unexpected" } }

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) { Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force }
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$scriptPath = Resolve-ProjectPath ".\scripts\write-support-escalation-handoff-evidence.ps1"
$plannedJsonPath = Join-Path $resolvedOutputDirectory "planned.json"
$plannedMarkdownPath = Join-Path $resolvedOutputDirectory "planned.md"
$passedJsonPath = Join-Path $resolvedOutputDirectory "passed.json"
$passedMarkdownPath = Join-Path $resolvedOutputDirectory "passed.md"
$invalidWindowJsonPath = Join-Path $resolvedOutputDirectory "invalid-window.json"
$invalidWindowMarkdownPath = Join-Path $resolvedOutputDirectory "invalid-window.md"
$tamperedJsonPath = Join-Path $resolvedOutputDirectory "tampered.json"
$tamperedMarkdownPath = Join-Path $resolvedOutputDirectory "tampered.md"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -JsonOutputPath $plannedJsonPath `
    -MarkdownOutputPath $plannedMarkdownPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw "planned write-support-escalation-handoff-evidence.ps1 failed with exit code $LASTEXITCODE." }

$plannedReport = Read-Utf8Text $plannedJsonPath | ConvertFrom-Json
$plannedMarkdown = Read-Utf8Text $plannedMarkdownPath
Assert-True ($plannedReport.formatVersion -eq "osmu.support-escalation-handoff-evidence.v1") "Unexpected support escalation handoff formatVersion."
Assert-True ($plannedReport.result -eq "planned") "Default support escalation handoff evidence should be planned."
Assert-True ($plannedReport.summary.failureCount -gt 0) "Planned support escalation handoff evidence should include missing checks."
Assert-True ($plannedReport.documentSnapshot.runbookCoverage -eq $true) "Expected runbook coverage to be detected."
Assert-True ($plannedReport.documentSnapshot.supportEscalationCoverage -eq $true) "Expected support escalation coverage to be detected."
Assert-Contains $plannedMarkdown "Support Escalation Handoff Evidence" "planned markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "support-self-test" `
    -ReviewStartedAt "2026-06-24T01:00:00Z" `
    -ReviewCompletedAt "2026-06-24T01:30:00Z" `
    -ChangeApprovalRef "CHG-2026-SUPPORT-HANDOFF" `
    -OperationsHandoffPackageRef "operations-handoff-package-prep-20260624" `
    -RunbookReviewRef "operator-runbook-review-20260624" `
    -TroubleshootingReviewRef "troubleshooting-review-20260624" `
    -RollbackReviewRef "rollback-review-20260624" `
    -SupportEscalationRef "support-escalation-routing-20260624" `
    -SupportSlaRef "support-sla-approval-20260624" `
    -KnownGapsRef "known-gaps-acceptance-20260624" `
    -EvidenceRef "support-escalation-handoff-20260624" `
    -ConfirmRunbookReviewed `
    -ConfirmTroubleshootingReviewed `
    -ConfirmRollbackPathReviewed `
    -ConfirmSupportEscalationReviewed `
    -ConfirmSupportSlaReviewed `
    -ConfirmKnownGapsAccepted `
    -ConfirmOperationsHandoffReferenceReady `
    -ConfirmNoCredentialValues `
    -JsonOutputPath $passedJsonPath `
    -MarkdownOutputPath $passedMarkdownPath `
    -FailIfNotPassed | Out-Null
if ($LASTEXITCODE -ne 0) { throw "passed write-support-escalation-handoff-evidence.ps1 failed with exit code $LASTEXITCODE." }

$reportText = Read-Utf8Text $passedJsonPath
$markdown = Read-Utf8Text $passedMarkdownPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.documentSnapshot.troubleshootingCoverage -eq $true) "Expected troubleshooting coverage."
Assert-True ($report.documentSnapshot.rollbackCoverage -eq $true) "Expected rollback coverage."
Assert-True ($report.documentSnapshot.supportSlaCoverage -eq $true) "Expected support SLA coverage."
Assert-True ($report.confirmations.noCredentialValues -eq $true) "Expected no credential confirmation."
Assert-True (@($checks | Where-Object { $_.id -eq "operations-handoff-reference-ready-confirmed" -and $_.passed }).Count -eq 1) "Expected operations handoff reference readiness confirmation."
Assert-Contains $markdown "Document Coverage" "passed markdown"
Assert-Contains $report.scopePolicy "does not contact ticketing systems" "support handoff JSON scope policy"
Assert-Contains $report.secretPolicy "support desk credentials" "support handoff JSON secret policy"
Assert-Contains $report.decisionRule "Production/B2B support escalation handoff readiness requires result=passed" "support handoff JSON decision rule"
foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----", "kubeconfig=raw")) {
    Assert-NotContains $reportText $unexpected "support handoff JSON"
    Assert-NotContains $markdown $unexpected "support handoff markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $secretRefOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -EvidenceRef "password=super-secret" -NoWrite 2>&1
    $secretRefExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($secretRefExitCode -ne 0) "Secret-like evidence reference should be rejected."
Assert-Contains ($secretRefOutput | Out-String) "credential material" "secret ref output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidWindowOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "support-self-test" `
        -ReviewStartedAt "2026-06-24T01:30:00Z" `
        -ReviewCompletedAt "2026-06-24T01:00:00Z" `
        -ChangeApprovalRef "CHG-2026-SUPPORT-HANDOFF" `
        -OperationsHandoffPackageRef "operations-handoff-package-prep-20260624" `
        -RunbookReviewRef "operator-runbook-review-20260624" `
        -TroubleshootingReviewRef "troubleshooting-review-20260624" `
        -RollbackReviewRef "rollback-review-20260624" `
        -SupportEscalationRef "support-escalation-routing-20260624" `
        -SupportSlaRef "support-sla-approval-20260624" `
        -KnownGapsRef "known-gaps-acceptance-20260624" `
        -EvidenceRef "support-escalation-handoff-20260624" `
        -ConfirmRunbookReviewed `
        -ConfirmTroubleshootingReviewed `
        -ConfirmRollbackPathReviewed `
        -ConfirmSupportEscalationReviewed `
        -ConfirmSupportSlaReviewed `
        -ConfirmKnownGapsAccepted `
        -ConfirmOperationsHandoffReferenceReady `
        -ConfirmNoCredentialValues `
        -JsonOutputPath $invalidWindowJsonPath `
        -MarkdownOutputPath $invalidWindowMarkdownPath `
        -FailIfNotPassed 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($invalidWindowExitCode -ne 0) "Invalid review window should be rejected."
Assert-Contains ($invalidWindowOutput | Out-String) "review-window-order" "invalid window output"
Assert-True (Test-Path -LiteralPath $invalidWindowJsonPath) "Invalid-window JSON should stay isolated under the self-test output directory."

$fixtureDir = Join-Path $resolvedOutputDirectory "tampered-docs"
New-Item -ItemType Directory -Force -Path $fixtureDir | Out-Null
$minimalDoc = "# Minimal`n`nrunbook evidence readiness dashboard rollback deployment secret rotation operations handoff package known gaps target evidence result=passed troubleshooting support escalation"
$minimalDoc | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $fixtureDir "runbook.md")
$minimalDoc | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $fixtureDir "troubleshooting.md")
$minimalDoc | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $fixtureDir "deployment.md")
$minimalDoc | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $fixtureDir "commercial.md")
$minimalDoc | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $fixtureDir "prototype.md")

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $tamperedOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -RunbookDocumentPath (Join-Path $fixtureDir "runbook.md") `
        -TroubleshootingDocumentPath (Join-Path $fixtureDir "troubleshooting.md") `
        -DeploymentStrategyPath (Join-Path $fixtureDir "deployment.md") `
        -CommercialReadinessPath (Join-Path $fixtureDir "commercial.md") `
        -PrototypeStatusPath (Join-Path $fixtureDir "prototype.md") `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "support-self-test" `
        -ReviewStartedAt "2026-06-24T01:00:00Z" `
        -ReviewCompletedAt "2026-06-24T01:30:00Z" `
        -ChangeApprovalRef "CHG-2026-SUPPORT-HANDOFF" `
        -OperationsHandoffPackageRef "operations-handoff-package-prep-20260624" `
        -RunbookReviewRef "operator-runbook-review-20260624" `
        -TroubleshootingReviewRef "troubleshooting-review-20260624" `
        -RollbackReviewRef "rollback-review-20260624" `
        -SupportEscalationRef "support-escalation-routing-20260624" `
        -SupportSlaRef "support-sla-approval-20260624" `
        -KnownGapsRef "known-gaps-acceptance-20260624" `
        -EvidenceRef "support-escalation-handoff-20260624" `
        -ConfirmRunbookReviewed `
        -ConfirmTroubleshootingReviewed `
        -ConfirmRollbackPathReviewed `
        -ConfirmSupportEscalationReviewed `
        -ConfirmSupportSlaReviewed `
        -ConfirmKnownGapsAccepted `
        -ConfirmOperationsHandoffReferenceReady `
        -ConfirmNoCredentialValues `
        -JsonOutputPath $tamperedJsonPath `
        -MarkdownOutputPath $tamperedMarkdownPath `
        -FailIfNotPassed 2>&1
    $tamperedExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($tamperedExitCode -ne 0) "Tampered docs without support SLA should fail."
Assert-Contains ($tamperedOutput | Out-String) "support-sla-doc-coverage" "tampered docs output"
Assert-True (Test-Path -LiteralPath $tamperedJsonPath) "Tampered-docs JSON should stay isolated under the self-test output directory."

Write-Host "Support escalation handoff evidence verification passed: $passedJsonPath"
exit 0
