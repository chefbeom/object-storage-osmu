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
    [string] $QueryPlanEvidenceJsonPath = "",
    [switch] $RequireQueryPlanEvidence,
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

function Assert-NoCredentialJson([string] $value, [string] $label) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        return
    }
    $patterns = @(
        '(?i)"(password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:\s*"[^"]+"',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key)\s*=\s*\S+',
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b"
    )
    foreach ($pattern in $patterns) {
        if ($value -match $pattern) {
            throw "$label must not contain credential-shaped text."
        }
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

function Get-PropertyValue([object] $object, [string] $name) {
    if ($null -eq $object) {
        return $null
    }
    $property = $object.PSObject.Properties[$name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-PropertyText([object] $object, [string] $name) {
    $value = Get-PropertyValue $object $name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Get-PropertyInt([object] $object, [string] $name) {
    $value = Get-PropertyValue $object $name
    if ($null -eq $value) {
        return 0
    }
    $parsed = 0
    if ([int]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return 0
}

function Get-PropertyBool([object] $object, [string] $name) {
    $value = Get-PropertyValue $object $name
    if ($null -eq $value) {
        return $false
    }
    if ($value -is [bool]) {
        return [bool] $value
    }
    return ([string] $value).Equals("true", [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-PropertyArray([object] $object, [string] $name) {
    $value = Get-PropertyValue $object $name
    if ($null -eq $value) {
        return @()
    }
    if ($value -is [System.Array]) {
        return @($value)
    }
    return @($value)
}

function Read-QueryPlanEvidenceSummary([string] $path) {
    $summary = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
        validFormatVersion = $false
        result = ""
        mode = ""
        checkCount = 0
        passedCount = 0
        failedCount = 0
        failedChecks = @()
        detail = "No MariaDB query plan evidence JSON supplied."
    }

    if ([string]::IsNullOrWhiteSpace($path)) {
        return $summary
    }

    $resolvedPath = Resolve-ProjectPath $path
    $summary["provided"] = $true
    $summary["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $summary["detail"] = "MariaDB query plan evidence JSON not found."
        return $summary
    }

    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    Assert-NoCredentialJson $raw "QueryPlanEvidenceJson"
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $summary["detail"] = "MariaDB query plan evidence JSON parse failed: $($_.Exception.Message)"
        return $summary
    }

    $failedRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in @(Get-PropertyArray $payload "checks")) {
        $status = Get-PropertyText $check "status"
        $passed = Get-PropertyBool $check "passed"
        if ($status -eq "FAIL" -or -not $passed) {
            [void] $failedRows.Add([ordered]@{
                id = Get-PropertyText $check "id"
                table = Get-PropertyText $check "table"
                queryPath = Get-PropertyText $check "queryPath"
                expectedIndex = Get-PropertyText $check "expectedIndex"
                status = $status
                usesExpectedIndex = Get-PropertyBool $check "usesExpectedIndex"
                errorMessage = Get-PropertyText $check "errorMessage"
            })
        }
        if ($failedRows.Count -ge 5) {
            break
        }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $summary["parsed"] = $true
    $summary["formatVersion"] = $formatVersion
    $summary["validFormatVersion"] = $formatVersion -eq $summary["expectedFormatVersion"]
    $summary["result"] = $result
    $summary["mode"] = Get-PropertyText $payload "mode"
    $summary["checkCount"] = Get-PropertyInt $payload "checkCount"
    $summary["passedCount"] = Get-PropertyInt $payload "passedCount"
    $summary["failedCount"] = Get-PropertyInt $payload "failedCount"
    $summary["failedChecks"] = @($failedRows.ToArray())
    $summary["detail"] = "formatVersion=$formatVersion; result=$result; mode=$($summary["mode"]); passed=$($summary["passedCount"]); failed=$($summary["failedCount"]); checks=$($summary["checkCount"])"
    return $summary
}

Assert-NoCredentialText $EnvironmentName "EnvironmentName"
Assert-NoCredentialText $TargetCluster "TargetCluster"
Assert-NoCredentialText $Operator "Operator"
Assert-NoCredentialText $EvidenceRef "EvidenceRef"

$queryPlanEvidence = Read-QueryPlanEvidenceSummary $QueryPlanEvidenceJsonPath
$queryPlanEvidencePassed = [bool] $queryPlanEvidence["provided"] -and
    [bool] $queryPlanEvidence["parsed"] -and
    [bool] $queryPlanEvidence["validFormatVersion"] -and
    "passed".Equals([string] $queryPlanEvidence["result"], [System.StringComparison]::OrdinalIgnoreCase) -and
    [int] $queryPlanEvidence["failedCount"] -eq 0
$candidateNeedsMariaDbQueryEvidence = @("MARIADB_PARTITION", "DUAL_WRITE") -contains $CandidateStore
$queryPlanEvidenceRequired = [bool] $RequireQueryPlanEvidence -or $candidateNeedsMariaDbQueryEvidence
$explainEvidencePassed = [bool] $ConfirmExplainEvidence
if ($queryPlanEvidenceRequired -or [bool] $queryPlanEvidence["provided"]) {
    $explainEvidencePassed = $explainEvidencePassed -and $queryPlanEvidencePassed
}

$checks = New-Object System.Collections.Generic.List[object]
foreach ($check in @(
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
        $explainEvidencePassed `
        "candidateStore=$CandidateStore; confirmExplainEvidence=$([bool] $ConfirmExplainEvidence); queryPlanEvidenceRequired=$queryPlanEvidenceRequired; queryPlanEvidenceResult=$($queryPlanEvidence["result"])" `
        "Pass -ConfirmExplainEvidence and, for MariaDB partition or dual-write, attach -QueryPlanEvidenceJsonPath .\.osmu-run\latest-mariadb-query-plan-evidence.json from a passed query-plan evidence run.")
)) {
    [void] $checks.Add($check)
}

if ($queryPlanEvidenceRequired -or [bool] $queryPlanEvidence["provided"]) {
    [void] $checks.Add((New-Check `
        "mariadb_query_plan_evidence" `
        "MariaDB query plan evidence passed" `
        $queryPlanEvidencePassed `
        $queryPlanEvidence["detail"] `
        "Run scripts/write-mariadb-query-plan-evidence.ps1 with -Execute or -ExplainInputDir until result=passed, then rerun this storage plan."))
}

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
    queryPlanEvidence = $queryPlanEvidence
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
    "## Query Plan Evidence"
    ""
    "- Required: $queryPlanEvidenceRequired"
    "- Provided: $($queryPlanEvidence["provided"])"
    "- Result: $($queryPlanEvidence["result"])"
    "- Mode: $($queryPlanEvidence["mode"])"
    "- Checks: $($queryPlanEvidence["passedCount"])/$($queryPlanEvidence["checkCount"]) passed; failed=$($queryPlanEvidence["failedCount"])"
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
$markdown += "For MariaDB partition or dual-write, include -QueryPlanEvidenceJsonPath .\.osmu-run\latest-mariadb-query-plan-evidence.json -RequireQueryPlanEvidence after the query-plan evidence result is passed."
$markdown | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Data-flow storage plan is not passed: $pendingCount pending check(s)."
}

Write-Host "Data-flow storage plan evidence written: $resolvedJsonOutputPath"
