param(
    [string] $OutputDirectory = ".\.osmu-run\data-flow-storage-transition-runbook-evidence-self-test"
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
        throw "$label contains unexpected secret/raw text: $unexpected"
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

$planPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-plan.json"
$plan = [ordered]@{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "passed"
    candidateStore = "DUAL_WRITE"
    expectedPeakEventsPerDay = 1000000
    expectedQueryWindowDays = 365
    targetP95QueryLatencyMs = 500
    pendingCount = 0
    checkCount = 10
    queryPlanEvidence = [ordered]@{
        provided = $true
        parsed = $true
        formatVersion = "osmu.mariadb-query-plan-evidence.v1"
        expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
        validFormatVersion = $true
        result = "passed"
        mode = "explain-input"
        checkCount = 15
        passedCount = 15
        failedCount = 0
        detail = "formatVersion=osmu.mariadb-query-plan-evidence.v1; result=passed; mode=explain-input; passed=15; failed=0; checks=15"
    }
}
$plan | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $planPath

$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-transition-runbook-evidence.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-transition-runbook-evidence.md"
$scriptPath = Resolve-ProjectPath ".\scripts\write-data-flow-storage-transition-runbook-evidence.ps1"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "ops-self-test" `
    -ReviewStartedAt "2026-06-20T04:00:00Z" `
    -ReviewCompletedAt "2026-06-20T04:45:00Z" `
    -ChangeApprovalRef "CHG-2026-DATA-FLOW-STORAGE-RUNBOOK" `
    -DataFlowStoragePlanJsonPath $planPath `
    -DataFlowStoragePlanEvidenceRef "data-flow-storage-plan-passed-20260620" `
    -BackfillEvidenceRef "data-flow-backfill-rehearsal-20260620" `
    -DualWriteOrPartitionToggleEvidenceRef "data-flow-dual-write-toggle-review-20260620" `
    -RollbackEvidenceRef "data-flow-rollback-rehearsal-20260620" `
    -ReconciliationEvidenceRef "data-flow-reconciliation-20260620" `
    -DashboardCutoverEvidenceRef "dashboard-cutover-review-20260620" `
    -RetentionDryRunEvidenceRef "retention-dry-run-20260620" `
    -EvidenceRef "data-flow-storage-transition-runbook-20260620" `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -ConfirmBackfillRehearsed `
    -ConfirmDualWriteOrPartitionToggleReviewed `
    -ConfirmRollbackRehearsed `
    -ConfirmReconciliationPassed `
    -ConfirmDashboardCutoverReviewed `
    -ConfirmRetentionDryRunReviewed `
    -ConfirmNoObjectKeysInAggregates `
    -ConfirmNoSecretValues `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-data-flow-storage-transition-runbook-evidence.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Data-flow storage transition runbook evidence JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Data-flow storage transition runbook evidence markdown missing."

$reportText = Get-Content -Raw -LiteralPath $jsonOutputPath
$markdown = Get-Content -Raw -LiteralPath $markdownOutputPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)

Assert-True ($report.formatVersion -eq "osmu.data-flow-storage-transition-runbook-evidence.v1") "Unexpected runbook evidence formatVersion."
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.dataFlowStoragePlanSnapshot.result -eq "passed") "Expected passed storage plan snapshot."
Assert-True ($report.dataFlowStoragePlanSnapshot.candidateStore -eq "DUAL_WRITE") "Expected candidate store."
Assert-True ($report.dataFlowStoragePlanSnapshot.targetP95QueryLatencyMs -eq 500) "Expected target p95 query latency."
Assert-True ($report.dataFlowStoragePlanSnapshot.queryPlanEvidence.result -eq "passed") "Expected query-plan evidence result."
Assert-True ($report.dataFlowStoragePlanSnapshot.queryPlanEvidence.checkCount -eq 15) "Expected query-plan evidence check count."
Assert-True ($report.dataFlowStoragePlanSnapshot.queryPlanEvidence.passedCount -eq 15) "Expected query-plan evidence passed count."
Assert-True ($report.dataFlowStoragePlanSnapshot.queryPlanEvidence.failedCount -eq 0) "Expected query-plan evidence failed count."
Assert-True ($report.confirmations.backfillRehearsed) "Expected backfill confirmation."
Assert-True ($report.confirmations.rollbackRehearsed) "Expected rollback confirmation."
Assert-True ($report.confirmations.reconciliationPassed) "Expected reconciliation confirmation."
Assert-True ($report.confirmations.noObjectKeysInAggregates) "Expected no-object-key confirmation."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-plan-passed" -and $_.passed }).Count -eq 1) "Expected storage plan pass check."
Assert-True (@($checks | Where-Object { $_.id -eq "data-flow-storage-plan-query-plan-snapshot" -and $_.passed }).Count -eq 1) "Expected query-plan snapshot pass check."

Assert-Contains $markdown "# OSMU Data-flow Storage Transition Runbook Evidence" "runbook evidence markdown"
Assert-Contains $markdown "Query-plan evidence: result=passed" "runbook evidence markdown"
Assert-Contains $markdown "Runbook Coverage" "runbook evidence markdown"
Assert-Contains $markdown "Record passed target evidence" "runbook evidence markdown"
Assert-Contains $report.scopePolicy "not AWS billing parity" "runbook evidence JSON"
Assert-Contains $report.secretPolicy "does not contain passwords" "runbook evidence JSON"
Assert-Contains $report.decisionRule "Production/B2B analytics storage transition requires result=passed" "runbook evidence JSON"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----", "SELECT * FROM data_flow_events", "EXPLAIN FORMAT=JSON")) {
    Assert-NotContains $reportText $unexpected "runbook evidence JSON"
    Assert-NotContains $markdown $unexpected "runbook evidence markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -EvidenceRef "password=super-secret" `
        -NoWrite 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Secret-like evidence reference should be rejected."

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidWindowOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -ReviewStartedAt "2026-06-20T04:45:00Z" `
        -ReviewCompletedAt "2026-06-20T04:00:00Z" `
        -ChangeApprovalRef "CHG-2026-DATA-FLOW-STORAGE-RUNBOOK" `
        -DataFlowStoragePlanJsonPath $planPath `
        -DataFlowStoragePlanEvidenceRef "data-flow-storage-plan-passed-20260620" `
        -BackfillEvidenceRef "data-flow-backfill-rehearsal-20260620" `
        -DualWriteOrPartitionToggleEvidenceRef "data-flow-dual-write-toggle-review-20260620" `
        -RollbackEvidenceRef "data-flow-rollback-rehearsal-20260620" `
        -ReconciliationEvidenceRef "data-flow-reconciliation-20260620" `
        -DashboardCutoverEvidenceRef "dashboard-cutover-review-20260620" `
        -RetentionDryRunEvidenceRef "retention-dry-run-20260620" `
        -EvidenceRef "data-flow-storage-transition-runbook-20260620" `
        -ConfirmBackfillRehearsed `
        -ConfirmDualWriteOrPartitionToggleReviewed `
        -ConfirmRollbackRehearsed `
        -ConfirmReconciliationPassed `
        -ConfirmDashboardCutoverReviewed `
        -ConfirmRetentionDryRunReviewed `
        -ConfirmNoObjectKeysInAggregates `
        -ConfirmNoSecretValues `
        -NoWrite `
        -FailIfNotPassed 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidWindowExitCode -ne 0) "Reversed review window should be rejected."
Assert-Contains ($invalidWindowOutput | Out-String) "review-window-order" "invalid review window output"

$rawSqlPlanPath = Join-Path $resolvedOutputDirectory "raw-sql-plan.json"
@"
{
  "formatVersion": "osmu.data-flow-storage-plan.v1",
  "result": "passed",
  "candidateStore": "DUAL_WRITE",
  "pendingCount": 0,
  "rawSql": "SELECT * FROM data_flow_events"
}
"@ | Set-Content -Encoding UTF8 -LiteralPath $rawSqlPlanPath

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $rawSqlOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -ReviewStartedAt "2026-06-20T04:00:00Z" `
        -ReviewCompletedAt "2026-06-20T04:45:00Z" `
        -DataFlowStoragePlanJsonPath $rawSqlPlanPath `
        -NoWrite 2>&1
    $rawSqlExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($rawSqlExitCode -ne 0) "Raw SQL storage plan snapshot should be rejected."
Assert-Contains ($rawSqlOutput | Out-String) "raw SQL" "raw SQL plan output"

Write-Host "Data-flow storage transition runbook evidence writer verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
