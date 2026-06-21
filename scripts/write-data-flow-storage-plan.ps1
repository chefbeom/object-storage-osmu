param(
    [string] $EnvironmentName = "local-plan",
    [string] $TargetCluster = "local",
    [string] $Operator = $env:USERNAME,
    [ValidateSet("MARIADB_PARTITION", "EXTERNAL_TIME_SERIES", "DUAL_WRITE")]
    [string] $CandidateStore = "MARIADB_PARTITION",
    [int] $ExpectedPeakEventsPerDay = 0,
    [int] $ExpectedQueryWindowDays = 0,
    [int] $EventRetentionDays = 90,
    [int] $DailyRollupRetentionDays = 730,
    [int] $MonthlyRollupRetentionMonths = 36,
    [string] $EvidenceRef = "",
    [switch] $ConfirmNoObjectKeyInAggregates,
    [switch] $ConfirmBackfillPlan,
    [switch] $ConfirmRollbackPlan,
    [switch] $ConfirmDashboardCutoverPlan,
    [switch] $ConfirmRetentionJobBudget,
    [switch] $ConfirmExplainEvidence,
    [string] $JsonOutputPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-data-flow-storage-plan.md",
    [switch] $FailIfNotPassed
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-NoCredentialText([string] $value, [string] $label) {
    if ($value -match '(?i)(password|secret|token|credential)\s*[:=]') {
        throw "$label must not contain credential-shaped text."
    }
}

function New-Check([string] $id, [string] $title, [bool] $passed, [string] $detail, [string] $nextAction) {
    [ordered]@{
        id = $id
        title = $title
        status = if ($passed) { "passed" } else { "pending" }
        detail = $detail
        nextAction = $nextAction
    }
}

Assert-NoCredentialText $EnvironmentName "EnvironmentName"
Assert-NoCredentialText $TargetCluster "TargetCluster"
Assert-NoCredentialText $Operator "Operator"
Assert-NoCredentialText $EvidenceRef "EvidenceRef"

$checks = @(
    (New-Check `
        "expected_peak_volume" `
        "Expected peak event volume captured" `
        ($ExpectedPeakEventsPerDay -gt 0) `
        "ExpectedPeakEventsPerDay=$ExpectedPeakEventsPerDay" `
        "Set -ExpectedPeakEventsPerDay from target telemetry or load test evidence.")
    (New-Check `
        "expected_query_window" `
        "Expected long-window query range captured" `
        ($ExpectedQueryWindowDays -gt 0) `
        "ExpectedQueryWindowDays=$ExpectedQueryWindowDays" `
        "Set -ExpectedQueryWindowDays from reporting requirements.")
    (New-Check `
        "aggregate_no_object_keys" `
        "Aggregate stores exclude object keys and raw event messages" `
        ([bool] $ConfirmNoObjectKeyInAggregates) `
        "Monthly/materialized aggregate scope must stay bucket/source/operation/status/time only." `
        "Pass -ConfirmNoObjectKeyInAggregates after schema review.")
    (New-Check `
        "backfill_plan" `
        "Backfill plan exists" `
        ([bool] $ConfirmBackfillPlan) `
        "Backfill must rebuild daily and monthly aggregates without duplicating detailed events." `
        "Pass -ConfirmBackfillPlan after documenting bounded backfill batches.")
    (New-Check `
        "rollback_plan" `
        "Rollback plan exists" `
        ([bool] $ConfirmRollbackPlan) `
        "Rollback must return reads to existing MariaDB detailed/materialized rollup paths." `
        "Pass -ConfirmRollbackPlan after documenting read-path fallback.")
    (New-Check `
        "dashboard_cutover" `
        "Dashboard cutover plan exists" `
        ([bool] $ConfirmDashboardCutoverPlan) `
        "Admin data-flow widgets must display the active storage source and not relabel estimates as billing." `
        "Pass -ConfirmDashboardCutoverPlan after UI/API cutover checklist review.")
    (New-Check `
        "retention_job_budget" `
        "Retention job budget exists" `
        ([bool] $ConfirmRetentionJobBudget) `
        "Retention must bound detailed event, daily rollup, and monthly rollup cleanup batches." `
        "Pass -ConfirmRetentionJobBudget after target batch/time budget review.")
    (New-Check `
        "explain_or_store_evidence" `
        "Query plan or target-store evidence exists" `
        ([bool] $ConfirmExplainEvidence) `
        "MariaDB partition path needs EXPLAIN evidence; external store path needs target query benchmark evidence." `
        "Pass -ConfirmExplainEvidence after evidence is attached.")
)

$passedCount = @($checks | Where-Object { $_.status -eq "passed" }).Count
$pendingCount = @($checks | Where-Object { $_.status -ne "passed" }).Count
$result = if ($pendingCount -eq 0) { "passed" } else { "plan-ready-execute-required" }
$recordedAt = (Get-Date).ToUniversalTime().ToString("o")
$scopePolicy = "OSMU operations analytics only. This plan is not AWS billing parity and aggregate stores must not include object keys or raw event messages."

$report = [ordered]@{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = $result
    recordedAt = $recordedAt
    environmentName = $EnvironmentName
    targetCluster = $TargetCluster
    operator = $Operator
    evidenceRef = $EvidenceRef
    candidateStore = $CandidateStore
    expectedPeakEventsPerDay = $ExpectedPeakEventsPerDay
    expectedQueryWindowDays = $ExpectedQueryWindowDays
    eventRetentionDays = $EventRetentionDays
    dailyRollupRetentionDays = $DailyRollupRetentionDays
    monthlyRollupRetentionMonths = $MonthlyRollupRetentionMonths
    scopePolicy = $scopePolicy
    checkCount = $checks.Count
    passedCount = $passedCount
    pendingCount = $pendingCount
    checks = $checks
}

$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null

$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8

$markdown = @(
    "# Data-flow Storage Plan Evidence"
    ""
    "- Result: $result"
    "- Recorded at: $recordedAt"
    "- Environment: $EnvironmentName"
    "- Target cluster: $TargetCluster"
    "- Candidate store: $CandidateStore"
    "- Evidence ref: $EvidenceRef"
    "- Scope policy: $scopePolicy"
    ""
    "## Sizing"
    ""
    "- Expected peak events/day: $ExpectedPeakEventsPerDay"
    "- Expected query window days: $ExpectedQueryWindowDays"
    "- Detailed event retention days: $EventRetentionDays"
    "- Daily rollup retention days: $DailyRollupRetentionDays"
    "- Monthly rollup retention months: $MonthlyRollupRetentionMonths"
    ""
    "## Checks"
    ""
)
foreach ($check in $checks) {
    $markdown += "- [$($check.status)] $($check.id): $($check.title) - $($check.detail)"
    if ($check.status -ne "passed") {
        $markdown += "  - Next: $($check.nextAction)"
    }
}
$markdown += ""
$markdown += "## Execute"
$markdown += ""
$markdown += "Rerun this command with target sizing plus all confirmation switches only after target evidence exists."
$markdown | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Data-flow storage plan is not passed: $pendingCount pending check(s)."
}

Write-Host "Data-flow storage plan evidence written: $resolvedJsonOutputPath"
