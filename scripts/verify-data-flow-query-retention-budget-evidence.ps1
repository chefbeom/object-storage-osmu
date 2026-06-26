param(
    [string] $OutputDirectory = ".\.osmu-run\data-flow-query-retention-budget-evidence-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Label) {
    if (-not $Text.Contains($Expected)) {
        throw "$Label does not contain expected text: $Expected"
    }
}

function Assert-NotContains([string] $Text, [string] $Unexpected, [string] $Label) {
    if ($Text.Contains($Unexpected)) {
        throw "$Label contains unexpected secret/raw text: $Unexpected"
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
$unsafePlanPath = Join-Path $resolvedOutputDirectory "unsafe-data-flow-storage-plan.json"
$plannedJsonPath = Join-Path $resolvedOutputDirectory "planned.json"
$plannedMarkdownPath = Join-Path $resolvedOutputDirectory "planned.md"
$passedJsonPath = Join-Path $resolvedOutputDirectory "passed.json"
$passedMarkdownPath = Join-Path $resolvedOutputDirectory "passed.md"
$scriptPath = Resolve-ProjectPath ".\scripts\write-data-flow-query-retention-budget-evidence.ps1"

[ordered]@{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "passed"
    candidateStore = "DUAL_WRITE"
    expectedPeakEventsPerDay = 1000000
    expectedQueryWindowDays = 180
    targetP95QueryLatencyMs = 500
    eventRetentionDays = 90
    dailyRollupRetentionDays = 730
    monthlyRollupRetentionMonths = 36
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
} | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $planPath

[ordered]@{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "passed"
    candidateStore = "MARIADB_PARTITION"
    expectedQueryWindowDays = 180
    targetP95QueryLatencyMs = 500
    pendingCount = 0
    rawSql = "SELECT * FROM data_flow_events"
} | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $unsafePlanPath

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -DataFlowStoragePlanJsonPath $planPath `
    -JsonOutputPath $plannedJsonPath `
    -MarkdownOutputPath $plannedMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "planned write-data-flow-query-retention-budget-evidence.ps1 failed with exit code $LASTEXITCODE."
}

$plannedReport = Get-Content -Raw -LiteralPath $plannedJsonPath | ConvertFrom-Json
$plannedMarkdown = Get-Content -Raw -LiteralPath $plannedMarkdownPath
Assert-True ($plannedReport.formatVersion -eq "osmu.data-flow-query-retention-budget-evidence.v1") "Unexpected query/retention evidence formatVersion."
Assert-True ($plannedReport.result -eq "planned") "Default query/retention evidence should be planned."
Assert-True ($plannedReport.summary.failureCount -gt 0) "Planned query/retention evidence should include missing checks."
Assert-Contains $plannedMarkdown "Query Latency" "planned markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "ops-self-test" `
    -ReviewStartedAt "2026-06-20T05:00:00Z" `
    -ReviewCompletedAt "2026-06-20T05:20:00Z" `
    -DataFlowStoragePlanJsonPath $planPath `
    -QueryLatencyEvidenceRef "query-latency-benchmark-20260620" `
    -RetentionBudgetEvidenceRef "retention-dry-run-budget-20260620" `
    -EvidenceRef "query-retention-budget-20260620" `
    -ObservedP95QueryLatencyMs 420 `
    -ObservedP99QueryLatencyMs 470 `
    -QuerySampleCount 120 `
    -ObservedQueryWindowDays 180 `
    -RetentionJobBudgetSeconds 30 `
    -DetailedRetentionObservedSeconds 20 `
    -DailyRollupRetentionObservedSeconds 18 `
    -MonthlyRollupRetentionObservedSeconds 12 `
    -DetailedRetentionDeletedRows 1000 `
    -DailyRollupRetentionDeletedRows 300 `
    -MonthlyRollupRetentionDeletedRows 20 `
    -ConfirmQueryLatencyReviewed `
    -ConfirmRetentionJobsWithinBudget `
    -ConfirmNoObjectKeysInEvidence `
    -ConfirmNoRawSqlOrExplain `
    -ConfirmNoSecretValues `
    -JsonOutputPath $passedJsonPath `
    -MarkdownOutputPath $passedMarkdownPath `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "passed write-data-flow-query-retention-budget-evidence.ps1 failed with exit code $LASTEXITCODE."
}

$reportText = Get-Content -Raw -LiteralPath $passedJsonPath
$markdown = Get-Content -Raw -LiteralPath $passedMarkdownPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)

Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.dataFlowStoragePlanSnapshot.result -eq "passed") "Expected passed storage plan snapshot."
Assert-True ($report.queryLatencyBudget.targetP95QueryLatencyMs -eq 500) "Expected target p95 from storage plan."
Assert-True ($report.queryLatencyBudget.observedP95QueryLatencyMs -eq 420) "Expected observed p95 query latency."
Assert-True ($report.queryLatencyBudget.withinBudget) "Expected query latency within budget."
Assert-True ($report.retentionBudget.budgetSeconds -eq 30) "Expected retention budget seconds."
Assert-True ($report.retentionBudget.monthlyRollupRetentionObservedSeconds -eq 12) "Expected monthly retention duration."
Assert-True ($report.retentionBudget.withinBudget) "Expected retention jobs within budget."
Assert-True ($report.confirmations.noRawSqlOrExplain) "Expected no-raw-SQL confirmation."
Assert-True (@($checks | Where-Object { $_.id -eq "query-latency-budget" -and $_.passed }).Count -eq 1) "Expected query latency budget pass check."
Assert-True (@($checks | Where-Object { $_.id -eq "retention-jobs-within-budget" -and $_.passed }).Count -eq 1) "Expected retention budget pass check."
Assert-Contains $markdown "# OSMU Data-flow Query And Retention Budget Evidence" "passed markdown"
Assert-Contains $markdown "Within budget: True" "passed markdown"
Assert-Contains $report.scopePolicy "not AWS billing parity" "query/retention evidence JSON"
Assert-Contains $report.secretPolicy "does not contain passwords" "query/retention evidence JSON"
Assert-Contains $report.decisionRule "Production/B2B analytics and chargeback scale requires result=passed" "query/retention evidence JSON"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----", "SELECT * FROM data_flow_events", "EXPLAIN FORMAT=JSON")) {
    Assert-NotContains $reportText $unexpected "query/retention evidence JSON"
    Assert-NotContains $markdown $unexpected "query/retention evidence markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $slowQueryOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -ReviewStartedAt "2026-06-20T05:00:00Z" `
        -ReviewCompletedAt "2026-06-20T05:20:00Z" `
        -DataFlowStoragePlanJsonPath $planPath `
        -QueryLatencyEvidenceRef "query-latency-benchmark-20260620" `
        -RetentionBudgetEvidenceRef "retention-dry-run-budget-20260620" `
        -EvidenceRef "query-retention-budget-20260620" `
        -ObservedP95QueryLatencyMs 650 `
        -ObservedP99QueryLatencyMs 700 `
        -QuerySampleCount 120 `
        -ObservedQueryWindowDays 180 `
        -RetentionJobBudgetSeconds 30 `
        -DetailedRetentionObservedSeconds 20 `
        -DailyRollupRetentionObservedSeconds 18 `
        -MonthlyRollupRetentionObservedSeconds 12 `
        -ConfirmQueryLatencyReviewed `
        -ConfirmRetentionJobsWithinBudget `
        -ConfirmNoObjectKeysInEvidence `
        -ConfirmNoRawSqlOrExplain `
        -ConfirmNoSecretValues `
        -FailIfNotPassed 2>&1
    $slowQueryExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($slowQueryExitCode -ne 0) "Over-budget query latency should be rejected."
Assert-Contains ($slowQueryOutput | Out-String) "query-latency-budget" "slow query output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $slowRetentionOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -ReviewStartedAt "2026-06-20T05:00:00Z" `
        -ReviewCompletedAt "2026-06-20T05:20:00Z" `
        -DataFlowStoragePlanJsonPath $planPath `
        -QueryLatencyEvidenceRef "query-latency-benchmark-20260620" `
        -RetentionBudgetEvidenceRef "retention-dry-run-budget-20260620" `
        -EvidenceRef "query-retention-budget-20260620" `
        -ObservedP95QueryLatencyMs 420 `
        -ObservedP99QueryLatencyMs 470 `
        -QuerySampleCount 120 `
        -ObservedQueryWindowDays 180 `
        -RetentionJobBudgetSeconds 30 `
        -DetailedRetentionObservedSeconds 31 `
        -DailyRollupRetentionObservedSeconds 18 `
        -MonthlyRollupRetentionObservedSeconds 12 `
        -ConfirmQueryLatencyReviewed `
        -ConfirmRetentionJobsWithinBudget `
        -ConfirmNoObjectKeysInEvidence `
        -ConfirmNoRawSqlOrExplain `
        -ConfirmNoSecretValues `
        -FailIfNotPassed 2>&1
    $slowRetentionExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($slowRetentionExitCode -ne 0) "Over-budget retention duration should be rejected."
Assert-Contains ($slowRetentionOutput | Out-String) "retention-jobs-within-budget" "slow retention output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafePlanOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -DataFlowStoragePlanJsonPath $unsafePlanPath `
        -NoWrite 2>&1
    $unsafePlanExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafePlanExitCode -ne 0) "Raw SQL storage plan snapshot should be rejected."
Assert-Contains ($unsafePlanOutput | Out-String) "raw SQL" "unsafe plan output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $secretRefOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EvidenceRef "password=super-secret" `
        -NoWrite 2>&1
    $secretRefExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($secretRefExitCode -ne 0) "Secret-like evidence reference should be rejected."
Assert-Contains ($secretRefOutput | Out-String) "secret" "secret ref output"

Write-Host "Data-flow query and retention budget evidence verification passed: $passedJsonPath"