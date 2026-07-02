param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $ReviewStartedAt = "",
    [string] $ReviewCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $RunbookDocumentPath = ".\dev-docs\operation-monitoring.md",
    [string] $TroubleshootingDocumentPath = ".\README.md",
    [string] $DeploymentStrategyPath = ".\dev-docs\deployment-strategy.md",
    [string] $CommercialReadinessPath = ".\dev-docs\commercial-readiness.md",
    [string] $PrototypeStatusPath = ".\dev-docs\prototype-status.md",
    [string] $OperationsHandoffPackageRef = "",
    [string] $RunbookReviewRef = "",
    [string] $TroubleshootingReviewRef = "",
    [string] $RollbackReviewRef = "",
    [string] $SupportEscalationRef = "",
    [string] $SupportSlaRef = "",
    [string] $KnownGapsRef = "",
    [string] $EvidenceRef = "",
    [switch] $ConfirmRunbookReviewed,
    [switch] $ConfirmTroubleshootingReviewed,
    [switch] $ConfirmRollbackPathReviewed,
    [switch] $ConfirmSupportEscalationReviewed,
    [switch] $ConfirmSupportSlaReviewed,
    [switch] $ConfirmKnownGapsAccepted,
    [switch] $ConfirmOperationsHandoffReferenceReady,
    [switch] $ConfirmNoCredentialValues,
    [string] $JsonOutputPath = ".\.osmu-run\latest-support-escalation-handoff-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-support-escalation-handoff-evidence.md",
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return [System.IO.Path]::GetFullPath($PathValue) }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-SafeText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b",
        "(?i)\b(password|passwd|secret|token|credential|client_secret|smtp_pass|webhook_secret|access_key|secret_key|kubeconfig)\s*[=:]\s*\S+"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) { throw "$Label appears to contain credential material. Store only a non-secret evidence reference." }
    }
}

function Get-ParsedDateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($Value, [ref] $parsed)) { return $parsed }
    return $null
}

function Test-DateText([string] $Value) { return $null -ne (Get-ParsedDateText $Value) }

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail, [string] $EvidenceRef = "") {
    [void] $script:checks.Add([ordered]@{
        id = $Id
        name = $Name
        status = if ($Passed) { "PASS" } else { "FAIL" }
        passed = $Passed
        detail = $Detail
        evidenceRef = $EvidenceRef
    })
}

function Read-DocumentSnapshot([string] $PathValue, [string] $Id) {
    $resolved = Resolve-ProjectPath $PathValue
    $exists = Test-Path -LiteralPath $resolved
    $text = ""
    $sha256 = ""
    $byteCount = 0
    if ($exists) {
        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $byteCount = $bytes.Length
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $sha256 = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLowerInvariant() }
        finally { $sha.Dispose() }
        $text = [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
    }
    Add-Check "$Id-present" "$Id document exists" $exists "Document path: $resolved" $resolved
    if ($exists) { Add-Check "$Id-no-tabs" "$Id document has no tabs" (-not $text.Contains("`t")) "Document should not contain tabs." $resolved }
    return [ordered]@{ id = $Id; path = $resolved; exists = $exists; byteCount = $byteCount; sha256 = $sha256; text = $text }
}

function Has([string] $Text, [string] $Needle) {
    return (-not [string]::IsNullOrEmpty($Text)) -and $Text.Contains($Needle)
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName), @("TargetCluster", $TargetCluster), @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef), @("OperationsHandoffPackageRef", $OperationsHandoffPackageRef),
    @("RunbookReviewRef", $RunbookReviewRef), @("TroubleshootingReviewRef", $TroubleshootingReviewRef),
    @("RollbackReviewRef", $RollbackReviewRef), @("SupportEscalationRef", $SupportEscalationRef),
    @("SupportSlaRef", $SupportSlaRef), @("KnownGapsRef", $KnownGapsRef), @("EvidenceRef", $EvidenceRef)
)) { Assert-SafeText ([string] $entry[1]) ([string] $entry[0]) }

$runbookDoc = Read-DocumentSnapshot $RunbookDocumentPath "runbook"
$troubleshootingDoc = Read-DocumentSnapshot $TroubleshootingDocumentPath "troubleshooting"
$deploymentDoc = Read-DocumentSnapshot $DeploymentStrategyPath "deployment-strategy"
$commercialDoc = Read-DocumentSnapshot $CommercialReadinessPath "commercial-readiness"
$prototypeDoc = Read-DocumentSnapshot $PrototypeStatusPath "prototype-status"
$combinedText = @($runbookDoc.text, $troubleshootingDoc.text, $deploymentDoc.text, $commercialDoc.text, $prototypeDoc.text) -join "`n"

$runbookCoverage = (Has $combinedText "write-operations-handoff-package.ps1") -and (Has $combinedText "Backup Restore Operations") -and (Has $combinedText "Storage Expansion Operations") -and (Has $combinedText "Prometheus")
$troubleshootingCoverage = (Has $combinedText "troubleshooting") -and (Has $combinedText "readiness") -and (Has $combinedText "dashboard") -and (Has $combinedText "evidence")
$rollbackCoverage = (Has $combinedText "rollback") -and (Has $combinedText "deployment") -and (Has $combinedText "secret rotation")
$supportEscalationCoverage = (Has $combinedText "support escalation") -and (Has $combinedText "operations handoff package")
$supportSlaCoverage = (Has $combinedText "support SLA") -and (Has $combinedText "support tier") -and (Has $combinedText "Commercial approval evidence")
$knownGapsCoverage = (Has $combinedText "known gaps") -and (Has $combinedText "target evidence") -and (Has $combinedText "result=passed")
$handoffPackageCoverage = (Has $combinedText "latest-operations-handoff-package.json") -and (Has $combinedText "RunbookReviewRef") -or ((Has $combinedText "runbook") -and (Has $combinedText "support escalation") -and (Has $combinedText "known gaps"))

Add-Check "runbook-doc-coverage" "Runbook coverage is documented" $runbookCoverage "Operation monitoring/deployment docs should cover runbook, backup/restore, storage expansion, monitoring, and handoff package."
Add-Check "troubleshooting-doc-coverage" "Troubleshooting coverage is documented" $troubleshootingCoverage "Docs should mention troubleshooting, readiness, dashboard, and evidence visibility."
Add-Check "rollback-doc-coverage" "Rollback path coverage is documented" $rollbackCoverage "Docs should mention rollback/deployment/secret rotation handoff paths."
Add-Check "support-escalation-doc-coverage" "Support escalation coverage is documented" $supportEscalationCoverage "Docs should mention support escalation and operations handoff package."
Add-Check "support-sla-doc-coverage" "Support SLA coverage is documented" $supportSlaCoverage "Commercial readiness docs should cover support SLA/tier and commercial approval evidence."
Add-Check "known-gaps-doc-coverage" "Known gaps coverage is documented" $knownGapsCoverage "Docs should mention known gaps, target evidence, and result=passed handoff requirements."
Add-Check "operations-handoff-package-doc-coverage" "Operations handoff package integration is documented" $handoffPackageCoverage "Docs should connect runbook/troubleshooting/support/known-gap review to operations handoff package."

$started = Get-ParsedDateText $ReviewStartedAt
$completed = Get-ParsedDateText $ReviewCompletedAt
$windowOrdered = $null -ne $started -and $null -ne $completed -and $completed -ge $started
$hasInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ReviewStartedAt + $ReviewCompletedAt + $ChangeApprovalRef + $OperationsHandoffPackageRef + $RunbookReviewRef + $TroubleshootingReviewRef + $RollbackReviewRef + $SupportEscalationRef + $SupportSlaRef + $KnownGapsRef + $EvidenceRef) -or $ConfirmRunbookReviewed -or $ConfirmTroubleshootingReviewed -or $ConfirmRollbackPathReviewed -or $ConfirmSupportEscalationReviewed -or $ConfirmSupportSlaReviewed -or $ConfirmKnownGapsAccepted -or $ConfirmOperationsHandoffReferenceReady -or $ConfirmNoCredentialValues

Add-Check "environment-name-present" "Environment name supplied" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "Target environment is required."
Add-Check "target-cluster-present" "Target cluster supplied" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "Target cluster label is required."
Add-Check "operator-present" "Operator supplied" (-not [string]::IsNullOrWhiteSpace($Operator)) "Operator/reviewer identity is required."
Add-Check "review-started-at-valid" "Review start timestamp is valid" (Test-DateText $ReviewStartedAt) "ReviewStartedAt must be parseable."
Add-Check "review-completed-at-valid" "Review completion timestamp is valid" (Test-DateText $ReviewCompletedAt) "ReviewCompletedAt must be parseable."
Add-Check "review-window-order" "Review window is ordered" $windowOrdered "ReviewCompletedAt must be equal to or after ReviewStartedAt."
Add-Check "change-approval-present" "Change approval reference supplied" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "Change approval or review ticket reference is required." $ChangeApprovalRef
Add-Check "operations-handoff-package-ref-present" "Operations handoff package reference supplied" (-not [string]::IsNullOrWhiteSpace($OperationsHandoffPackageRef)) "Operations handoff package target or preparation reference is required." $OperationsHandoffPackageRef
Add-Check "runbook-review-ref-present" "Runbook review reference supplied" (-not [string]::IsNullOrWhiteSpace($RunbookReviewRef)) "Runbook review reference is required." $RunbookReviewRef
Add-Check "troubleshooting-review-ref-present" "Troubleshooting review reference supplied" (-not [string]::IsNullOrWhiteSpace($TroubleshootingReviewRef)) "Troubleshooting review reference is required." $TroubleshootingReviewRef
Add-Check "rollback-review-ref-present" "Rollback review reference supplied" (-not [string]::IsNullOrWhiteSpace($RollbackReviewRef)) "Rollback review reference is required." $RollbackReviewRef
Add-Check "support-escalation-ref-present" "Support escalation reference supplied" (-not [string]::IsNullOrWhiteSpace($SupportEscalationRef)) "Support escalation reference is required." $SupportEscalationRef
Add-Check "support-sla-ref-present" "Support SLA reference supplied" (-not [string]::IsNullOrWhiteSpace($SupportSlaRef)) "Support SLA reference is required." $SupportSlaRef
Add-Check "known-gaps-ref-present" "Known gaps reference supplied" (-not [string]::IsNullOrWhiteSpace($KnownGapsRef)) "Known gaps acceptance reference is required." $KnownGapsRef
Add-Check "evidence-ref-present" "Evidence reference supplied" (-not [string]::IsNullOrWhiteSpace($EvidenceRef)) "External or internal evidence reference is required." $EvidenceRef

Add-Check "runbook-reviewed-confirmed" "Runbook review confirmed" (([bool] $ConfirmRunbookReviewed)) "Operator must confirm runbook review."
Add-Check "troubleshooting-reviewed-confirmed" "Troubleshooting review confirmed" (([bool] $ConfirmTroubleshootingReviewed)) "Operator must confirm troubleshooting review."
Add-Check "rollback-path-reviewed-confirmed" "Rollback path review confirmed" (([bool] $ConfirmRollbackPathReviewed)) "Operator must confirm rollback path review."
Add-Check "support-escalation-reviewed-confirmed" "Support escalation review confirmed" (([bool] $ConfirmSupportEscalationReviewed)) "Operator must confirm support escalation review."
Add-Check "support-sla-reviewed-confirmed" "Support SLA review confirmed" (([bool] $ConfirmSupportSlaReviewed)) "Operator must confirm support SLA review."
Add-Check "known-gaps-accepted-confirmed" "Known gaps accepted confirmed" (([bool] $ConfirmKnownGapsAccepted)) "Operator must confirm known gaps acceptance."
Add-Check "operations-handoff-reference-ready-confirmed" "Operations handoff reference readiness confirmed" (([bool] $ConfirmOperationsHandoffReferenceReady)) "Operator must confirm these refs can be fed into operations handoff package."
Add-Check "no-credential-values-confirmed" "No credential values included" (([bool] $ConfirmNoCredentialValues)) "Operator must confirm evidence references contain no credentials or secret values."

$passCount = @($checks | Where-Object { $_.passed }).Count
$failureCount = @($checks | Where-Object { -not $_.passed }).Count
$result = if ($failureCount -eq 0) { "passed" } elseif ($hasInput) { "failed" } else { "planned" }
$checkSnapshot = New-Object System.Collections.ArrayList
foreach ($check in $checks) { [void] $checkSnapshot.Add($check) }
$documentSnapshots = New-Object System.Collections.ArrayList
foreach ($doc in @($runbookDoc, $troubleshootingDoc, $deploymentDoc, $commercialDoc, $prototypeDoc)) {
    [void] $documentSnapshots.Add([ordered]@{ id = $doc.id; path = $doc.path; exists = $doc.exists; byteCount = $doc.byteCount; sha256 = $doc.sha256 })
}

$report = [ordered]@{
    formatVersion = "osmu.support-escalation-handoff-evidence.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    result = $result
    environmentName = $EnvironmentName
    targetCluster = $TargetCluster
    operator = $Operator
    reviewWindow = [ordered]@{ startedAt = $ReviewStartedAt; completedAt = $ReviewCompletedAt; ordered = $windowOrdered }
    evidence = [ordered]@{ changeApprovalRef = $ChangeApprovalRef; operationsHandoffPackageRef = $OperationsHandoffPackageRef; runbookReviewRef = $RunbookReviewRef; troubleshootingReviewRef = $TroubleshootingReviewRef; rollbackReviewRef = $RollbackReviewRef; supportEscalationRef = $SupportEscalationRef; supportSlaRef = $SupportSlaRef; knownGapsRef = $KnownGapsRef; evidenceRef = $EvidenceRef }
    documentSnapshot = [ordered]@{ files = $documentSnapshots; runbookCoverage = $runbookCoverage; troubleshootingCoverage = $troubleshootingCoverage; rollbackCoverage = $rollbackCoverage; supportEscalationCoverage = $supportEscalationCoverage; supportSlaCoverage = $supportSlaCoverage; knownGapsCoverage = $knownGapsCoverage; handoffPackageCoverage = $handoffPackageCoverage }
    confirmations = [ordered]@{ runbookReviewed = ([bool] $ConfirmRunbookReviewed); troubleshootingReviewed = ([bool] $ConfirmTroubleshootingReviewed); rollbackPathReviewed = ([bool] $ConfirmRollbackPathReviewed); supportEscalationReviewed = ([bool] $ConfirmSupportEscalationReviewed); supportSlaReviewed = ([bool] $ConfirmSupportSlaReviewed); knownGapsAccepted = ([bool] $ConfirmKnownGapsAccepted); operationsHandoffReferenceReady = ([bool] $ConfirmOperationsHandoffReferenceReady); noCredentialValues = ([bool] $ConfirmNoCredentialValues) }
    summary = [ordered]@{ passCount = $passCount; failureCount = $failureCount; totalCount = $checks.Count }
    checks = $checkSnapshot
    scopePolicy = "Reviews local handoff documentation and operator-approved references for runbook, troubleshooting, rollback, support escalation, support SLA, and known-gap handoff; it does not contact ticketing systems, support desks, customers, or production clusters."
    secretPolicy = "Evidence stores document hashes, labels, booleans, and non-secret references only. Do not embed passwords, tokens, kubeconfig, private keys, support desk credentials, customer data, or raw incident transcripts."
    decisionRule = "Production/B2B support escalation handoff readiness requires result=passed, zero failed checks, current document hashes, non-secret handoff references, and typed operator confirmations."
}

$lines = @(
    "# Support Escalation Handoff Evidence",
    "",
    "- Result: $result",
    "- Environment: $EnvironmentName",
    "- Target cluster: $TargetCluster",
    "- Operator: $Operator",
    "- Review window: $ReviewStartedAt to $ReviewCompletedAt",
    "- Change approval: $ChangeApprovalRef",
    "- Evidence ref: $EvidenceRef",
    "",
    "## Document Coverage",
    "",
    "- runbookCoverage: $runbookCoverage",
    "- troubleshootingCoverage: $troubleshootingCoverage",
    "- rollbackCoverage: $rollbackCoverage",
    "- supportEscalationCoverage: $supportEscalationCoverage",
    "- supportSlaCoverage: $supportSlaCoverage",
    "- knownGapsCoverage: $knownGapsCoverage",
    "- handoffPackageCoverage: $handoffPackageCoverage",
    "",
    "## Checks",
    ""
)
foreach ($check in $checks) { $lines += "- [$($check.status)] $($check.id): $($check.detail)" }
$lines += @("", "## Policy", "", "- Scope: $($report.scopePolicy)", "- Secret handling: $($report.secretPolicy)", "- Decision: $($report.decisionRule)")
$markdown = ($lines -join [Environment]::NewLine) + [Environment]::NewLine

if (-not $NoWrite) {
    $jsonPath = Resolve-ProjectPath $JsonOutputPath
    $mdPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $mdPath) | Out-Null
    $report | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -LiteralPath $jsonPath
    $markdown | Set-Content -Encoding UTF8 -LiteralPath $mdPath
    Write-Host "Support escalation handoff evidence written: $jsonPath"
    Write-Host "Support escalation handoff markdown written: $mdPath"
}
else { Write-Host "Support escalation handoff evidence result: $result" }

if ($FailIfNotPassed -and $result -ne "passed") {
    $failed = @($checks | Where-Object { -not $_.passed } | ForEach-Object { $_.id }) -join ", "
    throw "Support escalation handoff evidence did not pass: result=$result; failed=$failed"
}