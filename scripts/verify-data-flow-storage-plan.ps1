param(
    [string] $OutputDir = ".\.osmu-run\data-flow-storage-plan-self-test"
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

function Assert-Contains([string] $value, [string] $expected, [string] $label) {
    if (-not $value -or -not $value.Contains($expected)) {
        throw "$label must contain '$expected'."
    }
}

$resolvedOutputDir = Resolve-ProjectPath $OutputDir
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null

$planJsonPath = Join-Path $resolvedOutputDir "plan.json"
$planMarkdownPath = Join-Path $resolvedOutputDir "plan.md"
$passedJsonPath = Join-Path $resolvedOutputDir "passed.json"
$passedMarkdownPath = Join-Path $resolvedOutputDir "passed.md"
$queryPlanEvidencePath = Join-Path $resolvedOutputDir "query-plan-passed.json"
$failedQueryPlanEvidencePath = Join-Path $resolvedOutputDir "query-plan-failed.json"
$unsafeQueryPlanEvidencePath = Join-Path $resolvedOutputDir "query-plan-unsafe.json"

[ordered]@{
    formatVersion = "osmu.mariadb-query-plan-evidence.v1"
    result = "passed"
    mode = "explain-input"
    checkCount = 3
    passedCount = 3
    failedCount = 0
    checks = @(
        [ordered]@{
            id = "data-flow-time-window"
            table = "data_flow_events"
            queryPath = "data-flow recent event window/export"
            expectedIndex = "idx_data_flow_events_created_at"
            status = "PASS"
            passed = $true
            usesExpectedIndex = $true
            errorMessage = ""
        }
        [ordered]@{
            id = "daily-rollup-bucket-window"
            table = "data_flow_daily_rollups"
            queryPath = "materialized daily rollup read/export"
            expectedIndex = "idx_data_flow_daily_rollups_bucket"
            status = "PASS"
            passed = $true
            usesExpectedIndex = $true
            errorMessage = ""
        }
        [ordered]@{
            id = "monthly-rollup-bucket-window"
            table = "data_flow_monthly_rollups"
            queryPath = "materialized monthly rollup read/export"
            expectedIndex = "idx_data_flow_monthly_rollups_bucket"
            status = "PASS"
            passed = $true
            usesExpectedIndex = $true
            errorMessage = ""
        }
    )
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $queryPlanEvidencePath -Encoding UTF8

[ordered]@{
    formatVersion = "osmu.mariadb-query-plan-evidence.v1"
    result = "failed"
    mode = "explain-input"
    checkCount = 1
    passedCount = 0
    failedCount = 1
    checks = @(
        [ordered]@{
            id = "data-flow-time-window"
            table = "data_flow_events"
            queryPath = "data-flow recent event window/export"
            expectedIndex = "idx_data_flow_events_created_at"
            status = "FAIL"
            passed = $false
            usesExpectedIndex = $false
            errorMessage = "expected index not used"
        }
    )
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $failedQueryPlanEvidencePath -Encoding UTF8

'{"formatVersion":"osmu.mariadb-query-plan-evidence.v1","result":"passed","password":"leaked"}' |
    Set-Content -LiteralPath $unsafeQueryPlanEvidencePath -Encoding UTF8

& (Join-Path $PSScriptRoot "write-data-flow-storage-plan.ps1") `
    -EnvironmentName "self-test" `
    -TargetCluster "local" `
    -Operator "data-flow-storage-plan-self-test" `
    -JsonOutputPath $planJsonPath `
    -MarkdownOutputPath $planMarkdownPath

$planReport = Get-Content -Raw -LiteralPath $planJsonPath | ConvertFrom-Json
$planMarkdown = Get-Content -Raw -LiteralPath $planMarkdownPath
Assert-True ($planReport.formatVersion -eq "osmu.data-flow-storage-plan.v1") "Unexpected data-flow storage plan formatVersion."
Assert-True ($planReport.result -eq "plan-ready-execute-required") "Default data-flow storage plan should require target evidence."
Assert-True ($planReport.pendingCount -gt 0) "Default data-flow storage plan should include pending checks."
Assert-Contains $planReport.scopePolicy "not AWS billing parity" "scopePolicy"
Assert-Contains $planReport.scopePolicy "must not include object keys" "scopePolicy"
Assert-Contains $planMarkdown "Expected peak events/day" "plan markdown"

& (Join-Path $PSScriptRoot "write-data-flow-storage-plan.ps1") `
    -EnvironmentName "target-fixture" `
    -TargetCluster "fixture-cluster" `
    -Operator "data-flow-storage-plan-self-test" `
    -CandidateStore "DUAL_WRITE" `
    -ExpectedPeakEventsPerDay 1000000 `
    -ExpectedQueryWindowDays 365 `
    -EvidenceRef "fixture-run-123" `
    -ConfirmNoObjectKeyInAggregates `
    -ConfirmBackfillPlan `
    -ConfirmRollbackPlan `
    -ConfirmDashboardCutoverPlan `
    -ConfirmRetentionJobBudget `
    -ConfirmExplainEvidence `
    -QueryPlanEvidenceJsonPath $queryPlanEvidencePath `
    -RequireQueryPlanEvidence `
    -JsonOutputPath $passedJsonPath `
    -MarkdownOutputPath $passedMarkdownPath `
    -FailIfNotPassed

$passedReport = Get-Content -Raw -LiteralPath $passedJsonPath | ConvertFrom-Json
$passedMarkdown = Get-Content -Raw -LiteralPath $passedMarkdownPath
Assert-True ($passedReport.result -eq "passed") "Confirmed data-flow storage plan should pass."
Assert-True ($passedReport.pendingCount -eq 0) "Confirmed data-flow storage plan should have no pending checks."
Assert-True ($passedReport.candidateStore -eq "DUAL_WRITE") "Confirmed data-flow storage plan should preserve candidate store."
Assert-True ($passedReport.queryPlanEvidence.result -eq "passed") "Confirmed data-flow storage plan should embed passed query plan evidence summary."
Assert-True (@($passedReport.checks | Where-Object { $_.id -eq "mariadb_query_plan_evidence" -and $_.status -eq "passed" }).Count -eq 1) "Confirmed data-flow storage plan should include passed MariaDB query plan check."
Assert-Contains $passedMarkdown "Query Plan Evidence" "passed markdown"

$rejectedFailedQueryPlan = $false
try {
    & (Join-Path $PSScriptRoot "write-data-flow-storage-plan.ps1") `
        -EnvironmentName "failed-query-plan-fixture" `
        -TargetCluster "fixture-cluster" `
        -Operator "data-flow-storage-plan-self-test" `
        -CandidateStore "DUAL_WRITE" `
        -ExpectedPeakEventsPerDay 1000000 `
        -ExpectedQueryWindowDays 365 `
        -ConfirmNoObjectKeyInAggregates `
        -ConfirmBackfillPlan `
        -ConfirmRollbackPlan `
        -ConfirmDashboardCutoverPlan `
        -ConfirmRetentionJobBudget `
        -ConfirmExplainEvidence `
        -QueryPlanEvidenceJsonPath $failedQueryPlanEvidencePath `
        -RequireQueryPlanEvidence `
        -JsonOutputPath (Join-Path $resolvedOutputDir "failed-query-plan.json") `
        -MarkdownOutputPath (Join-Path $resolvedOutputDir "failed-query-plan.md") `
        -FailIfNotPassed
} catch {
    $rejectedFailedQueryPlan = $true
}
Assert-True $rejectedFailedQueryPlan "Failed MariaDB query plan evidence must keep storage plan from passing."

$rejectedUnsafeQueryPlan = $false
try {
    & (Join-Path $PSScriptRoot "write-data-flow-storage-plan.ps1") `
        -EnvironmentName "unsafe-query-plan-fixture" `
        -TargetCluster "fixture-cluster" `
        -Operator "data-flow-storage-plan-self-test" `
        -CandidateStore "DUAL_WRITE" `
        -ExpectedPeakEventsPerDay 1000000 `
        -ExpectedQueryWindowDays 365 `
        -ConfirmNoObjectKeyInAggregates `
        -ConfirmBackfillPlan `
        -ConfirmRollbackPlan `
        -ConfirmDashboardCutoverPlan `
        -ConfirmRetentionJobBudget `
        -ConfirmExplainEvidence `
        -QueryPlanEvidenceJsonPath $unsafeQueryPlanEvidencePath `
        -RequireQueryPlanEvidence `
        -JsonOutputPath (Join-Path $resolvedOutputDir "unsafe-query-plan.json") `
        -MarkdownOutputPath (Join-Path $resolvedOutputDir "unsafe-query-plan.md")
} catch {
    $rejectedUnsafeQueryPlan = $true
}
Assert-True $rejectedUnsafeQueryPlan "Credential-shaped query plan evidence must be rejected."

$rejectedSecret = $false
try {
    & (Join-Path $PSScriptRoot "write-data-flow-storage-plan.ps1") `
        -EnvironmentName "self-test" `
        -EvidenceRef "password=leaked" `
        -JsonOutputPath (Join-Path $resolvedOutputDir "secret.json") `
        -MarkdownOutputPath (Join-Path $resolvedOutputDir "secret.md")
} catch {
    $rejectedSecret = $true
}
Assert-True $rejectedSecret "Credential-shaped evidence refs must be rejected."

Write-Host "Data-flow storage plan verification passed: $passedJsonPath"
