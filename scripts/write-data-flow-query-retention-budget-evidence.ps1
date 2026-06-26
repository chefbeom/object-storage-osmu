param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $ReviewStartedAt = "",
    [string] $ReviewCompletedAt = "",
    [string] $DataFlowStoragePlanJsonPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $QueryLatencyEvidenceRef = "",
    [string] $RetentionBudgetEvidenceRef = "",
    [string] $EvidenceRef = "",
    [int] $TargetP95QueryLatencyMs = 0,
    [int] $ObservedP95QueryLatencyMs = 0,
    [int] $ObservedP99QueryLatencyMs = 0,
    [int] $QuerySampleCount = 0,
    [int] $ObservedQueryWindowDays = 0,
    [int] $RetentionJobBudgetSeconds = 0,
    [int] $DetailedRetentionObservedSeconds = 0,
    [int] $DailyRollupRetentionObservedSeconds = 0,
    [int] $MonthlyRollupRetentionObservedSeconds = 0,
    [int] $DetailedRetentionDeletedRows = 0,
    [int] $DailyRollupRetentionDeletedRows = 0,
    [int] $MonthlyRollupRetentionDeletedRows = 0,
    [switch] $ConfirmQueryLatencyReviewed,
    [switch] $ConfirmRetentionJobsWithinBudget,
    [switch] $ConfirmNoObjectKeysInEvidence,
    [switch] $ConfirmNoRawSqlOrExplain,
    [switch] $ConfirmNoSecretValues,
    [string] $JsonOutputPath = ".\.osmu-run\latest-data-flow-query-retention-budget-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-data-flow-query-retention-budget-evidence.md",
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-SafeText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "(?i)\b(password|passwd|secret|token|credential|client_secret|x-amz-security-token|smtp_pass|webhook_secret)\s*[=:]\s*\S+",
        "(?i)\bselect\s+.+\s+from\s+",
        "(?i)\bexplain\s+format\s*=\s*json\b"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain secret, raw SQL, or raw EXPLAIN material. Store only an external evidence reference."
        }
    }
}

function Assert-SanitizedPlanJson([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    $patterns = @(
        "(?i)\bselect\s+.+\s+from\s+",
        "(?i)\bexplain\s+format\s*=\s*json\b",
        "(?i)rawSql|raw_sql|rawExplain|raw_explain|queryText|query_text|objectKey|object_key|rawMessage|raw_message",
        "(?i)\b(password|passwd|secret|token|credential|client_secret)\s*[=:]\s*\S+",
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "DataFlowStoragePlanJson appears to contain raw SQL, raw EXPLAIN, object-key, raw-message, or credential-shaped content. Store only sanitized summary evidence."
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

function Get-ParsedDateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($Value, [ref] $parsed)) {
        return $parsed
    }
    return $null
}

function Get-PropertyValue([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-PropertyText([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Get-PropertyInt([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return 0
    }
    $parsed = 0
    if ([int]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return 0
}

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail) {
    return [ordered]@{
        id = $Id
        name = $Name
        status = $Status
        passed = $Status -eq "PASS"
        detail = $Detail
    }
}

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail) {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    [void] $script:checks.Add((New-Check $Id $Name $status $Detail))
}

function Read-DataFlowStoragePlan([string] $Path) {
    $summary = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        result = ""
        candidateStore = ""
        expectedPeakEventsPerDay = 0
        expectedQueryWindowDays = 0
        targetP95QueryLatencyMs = 0
        eventRetentionDays = 0
        dailyRollupRetentionDays = 0
        monthlyRollupRetentionMonths = 0
        pendingCount = 0
        checkCount = 0
        queryPlanEvidenceResult = ""
        queryPlanEvidenceFailedCount = 0
        detail = "No data-flow storage plan JSON supplied."
    }
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $summary
    }
    $resolvedPath = Resolve-ProjectPath $Path
    $summary["provided"] = $true
    $summary["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $summary["detail"] = "Data-flow storage plan JSON not found."
        return $summary
    }
    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    Assert-SanitizedPlanJson $raw
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $summary["detail"] = "Data-flow storage plan JSON parse failed: $($_.Exception.Message)"
        return $summary
    }
    $queryPlanEvidence = Get-PropertyValue $payload "queryPlanEvidence"
    $summary["parsed"] = $true
    $summary["formatVersion"] = Get-PropertyText $payload "formatVersion"
    $summary["result"] = Get-PropertyText $payload "result"
    $summary["candidateStore"] = Get-PropertyText $payload "candidateStore"
    $summary["expectedPeakEventsPerDay"] = Get-PropertyInt $payload "expectedPeakEventsPerDay"
    $summary["expectedQueryWindowDays"] = Get-PropertyInt $payload "expectedQueryWindowDays"
    $summary["targetP95QueryLatencyMs"] = Get-PropertyInt $payload "targetP95QueryLatencyMs"
    $summary["eventRetentionDays"] = Get-PropertyInt $payload "eventRetentionDays"
    $summary["dailyRollupRetentionDays"] = Get-PropertyInt $payload "dailyRollupRetentionDays"
    $summary["monthlyRollupRetentionMonths"] = Get-PropertyInt $payload "monthlyRollupRetentionMonths"
    $summary["pendingCount"] = Get-PropertyInt $payload "pendingCount"
    $summary["checkCount"] = Get-PropertyInt $payload "checkCount"
    if ($null -ne $queryPlanEvidence) {
        $summary["queryPlanEvidenceResult"] = Get-PropertyText $queryPlanEvidence "result"
        $summary["queryPlanEvidenceFailedCount"] = Get-PropertyInt $queryPlanEvidence "failedCount"
    }
    $summary["detail"] = "formatVersion=$($summary["formatVersion"]); result=$($summary["result"]); candidateStore=$($summary["candidateStore"]); pending=$($summary["pendingCount"]); targetP95QueryLatencyMs=$($summary["targetP95QueryLatencyMs"]); expectedQueryWindowDays=$($summary["expectedQueryWindowDays"]); queryPlanEvidenceResult=$($summary["queryPlanEvidenceResult"]); queryPlanEvidenceFailed=$($summary["queryPlanEvidenceFailedCount"])"
    return $summary
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("Operator", $Operator),
    @("QueryLatencyEvidenceRef", $QueryLatencyEvidenceRef),
    @("RetentionBudgetEvidenceRef", $RetentionBudgetEvidenceRef),
    @("EvidenceRef", $EvidenceRef)
)) {
    Assert-SafeText ([string] $entry[1]) ([string] $entry[0])
}

$planSummary = Read-DataFlowStoragePlan $DataFlowStoragePlanJsonPath
$effectiveTargetP95 = if ($TargetP95QueryLatencyMs -gt 0) { $TargetP95QueryLatencyMs } else { [int] $planSummary["targetP95QueryLatencyMs"] }
$planPassed = [bool] $planSummary["provided"] -and
    [bool] $planSummary["parsed"] -and
    $planSummary["formatVersion"] -eq "osmu.data-flow-storage-plan.v1" -and
    "passed".Equals([string] $planSummary["result"], [System.StringComparison]::OrdinalIgnoreCase) -and
    [int] $planSummary["pendingCount"] -eq 0
$reviewStartedAtParsed = Get-ParsedDateText $ReviewStartedAt
$reviewCompletedAtParsed = Get-ParsedDateText $ReviewCompletedAt
$reviewWindowOrdered = $null -ne $reviewStartedAtParsed -and $null -ne $reviewCompletedAtParsed -and $reviewCompletedAtParsed -ge $reviewStartedAtParsed
$queryLatencyWithinBudget = $ObservedP95QueryLatencyMs -gt 0 -and $effectiveTargetP95 -gt 0 -and $ObservedP95QueryLatencyMs -le $effectiveTargetP95
$queryP99Valid = $ObservedP99QueryLatencyMs -eq 0 -or $ObservedP99QueryLatencyMs -ge $ObservedP95QueryLatencyMs
$queryWindowCovered = [int] $planSummary["expectedQueryWindowDays"] -gt 0 -and $ObservedQueryWindowDays -ge [int] $planSummary["expectedQueryWindowDays"]
$retentionDurationsRecorded = $DetailedRetentionObservedSeconds -gt 0 -and
    $DailyRollupRetentionObservedSeconds -gt 0 -and
    $MonthlyRollupRetentionObservedSeconds -gt 0
$retentionJobsWithinBudget = $RetentionJobBudgetSeconds -gt 0 -and
    $DetailedRetentionObservedSeconds -le $RetentionJobBudgetSeconds -and
    $DailyRollupRetentionObservedSeconds -le $RetentionJobBudgetSeconds -and
    $MonthlyRollupRetentionObservedSeconds -le $RetentionJobBudgetSeconds
$retentionDeletedRowsValid = $DetailedRetentionDeletedRows -ge 0 -and
    $DailyRollupRetentionDeletedRows -ge 0 -and
    $MonthlyRollupRetentionDeletedRows -ge 0
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ReviewStartedAt + $ReviewCompletedAt + $QueryLatencyEvidenceRef + $RetentionBudgetEvidenceRef + $EvidenceRef) -or
    $TargetP95QueryLatencyMs -gt 0 -or
    $ObservedP95QueryLatencyMs -gt 0 -or
    $ObservedP99QueryLatencyMs -gt 0 -or
    $QuerySampleCount -gt 0 -or
    $ObservedQueryWindowDays -gt 0 -or
    $RetentionJobBudgetSeconds -gt 0 -or
    $DetailedRetentionObservedSeconds -gt 0 -or
    $DailyRollupRetentionObservedSeconds -gt 0 -or
    $MonthlyRollupRetentionObservedSeconds -gt 0 -or
    $ConfirmQueryLatencyReviewed -or
    $ConfirmRetentionJobsWithinBudget -or
    $ConfirmNoObjectKeysInEvidence -or
    $ConfirmNoRawSqlOrExplain -or
    $ConfirmNoSecretValues

Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($Operator)) "operator=$Operator"
Add-Check "review-started-at" "Review start timestamp recorded" (Test-DateText $ReviewStartedAt) "reviewStartedAt=$ReviewStartedAt"
Add-Check "review-completed-at" "Review completion timestamp recorded" (Test-DateText $ReviewCompletedAt) "reviewCompletedAt=$ReviewCompletedAt"
Add-Check "review-window-order" "Review window order valid" $reviewWindowOrdered "reviewStartedAt=$ReviewStartedAt; reviewCompletedAt=$ReviewCompletedAt"
Add-Check "data-flow-storage-plan-passed" "Data-flow storage plan snapshot passed" $planPassed $planSummary["detail"]
Add-Check "query-latency-evidence-ref" "Query latency evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($QueryLatencyEvidenceRef)) "queryLatencyEvidenceRef=$QueryLatencyEvidenceRef"
Add-Check "query-latency-budget" "Observed p95 query latency is within target budget" $queryLatencyWithinBudget "observedP95QueryLatencyMs=$ObservedP95QueryLatencyMs; targetP95QueryLatencyMs=$effectiveTargetP95"
Add-Check "query-p99-shape" "Observed p99 query latency shape is valid when supplied" $queryP99Valid "observedP95QueryLatencyMs=$ObservedP95QueryLatencyMs; observedP99QueryLatencyMs=$ObservedP99QueryLatencyMs"
Add-Check "query-sample-count" "Query benchmark sample count recorded" ($QuerySampleCount -gt 0) "querySampleCount=$QuerySampleCount"
Add-Check "query-window-covered" "Observed query benchmark covers target window" $queryWindowCovered "observedQueryWindowDays=$ObservedQueryWindowDays; expectedQueryWindowDays=$($planSummary["expectedQueryWindowDays"])"
Add-Check "query-latency-reviewed-confirmed" "Query latency review confirmation" ([bool] $ConfirmQueryLatencyReviewed) "Target benchmark source was reviewed without raw SQL or object keys."
Add-Check "retention-budget-evidence-ref" "Retention budget evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($RetentionBudgetEvidenceRef)) "retentionBudgetEvidenceRef=$RetentionBudgetEvidenceRef"
Add-Check "retention-budget-recorded" "Retention job budget recorded" ($RetentionJobBudgetSeconds -gt 0) "retentionJobBudgetSeconds=$RetentionJobBudgetSeconds"
Add-Check "retention-durations-recorded" "Retention job observed durations recorded" $retentionDurationsRecorded "detailed=$DetailedRetentionObservedSeconds; daily=$DailyRollupRetentionObservedSeconds; monthly=$MonthlyRollupRetentionObservedSeconds"
Add-Check "retention-jobs-within-budget" "Retention jobs are within budget" $retentionJobsWithinBudget "budgetSeconds=$RetentionJobBudgetSeconds; detailed=$DetailedRetentionObservedSeconds; daily=$DailyRollupRetentionObservedSeconds; monthly=$MonthlyRollupRetentionObservedSeconds"
Add-Check "retention-deleted-rows-valid" "Retention deleted-row counts are typed and non-negative" $retentionDeletedRowsValid "detailed=$DetailedRetentionDeletedRows; daily=$DailyRollupRetentionDeletedRows; monthly=$MonthlyRollupRetentionDeletedRows"
Add-Check "retention-budget-reviewed-confirmed" "Retention budget review confirmation" ([bool] $ConfirmRetentionJobsWithinBudget) "Detailed, daily, and monthly retention runs stayed within target batch/time budgets."
Add-Check "no-object-keys-confirmed" "No object keys in evidence confirmation" ([bool] $ConfirmNoObjectKeysInEvidence) "Evidence stores aggregate counts, durations, and references only."
Add-Check "no-raw-sql-or-explain-confirmed" "No raw SQL or EXPLAIN in evidence confirmation" ([bool] $ConfirmNoRawSqlOrExplain) "Evidence stores sanitized query-plan result references only."
Add-Check "no-secret-values-confirmed" "No secret values recorded confirmation" ([bool] $ConfirmNoSecretValues) "Evidence stores references and typed metrics only."

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
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

$report = [ordered]@{
    formatVersion = "osmu.data-flow-query-retention-budget-evidence.v1"
    generatedAt = $generatedAt
    result = $result
    environmentName = $EnvironmentName
    targetCluster = $TargetCluster
    operatorName = $Operator
    evidenceRef = $EvidenceRef
    reviewWindow = [ordered]@{
        startedAt = $ReviewStartedAt
        completedAt = $ReviewCompletedAt
    }
    dataFlowStoragePlanSnapshot = $planSummary
    queryLatencyBudget = [ordered]@{
        evidenceRef = $QueryLatencyEvidenceRef
        targetP95QueryLatencyMs = $effectiveTargetP95
        observedP95QueryLatencyMs = $ObservedP95QueryLatencyMs
        observedP99QueryLatencyMs = $ObservedP99QueryLatencyMs
        querySampleCount = $QuerySampleCount
        observedQueryWindowDays = $ObservedQueryWindowDays
        withinBudget = $queryLatencyWithinBudget
    }
    retentionBudget = [ordered]@{
        evidenceRef = $RetentionBudgetEvidenceRef
        budgetSeconds = $RetentionJobBudgetSeconds
        detailedRetentionObservedSeconds = $DetailedRetentionObservedSeconds
        dailyRollupRetentionObservedSeconds = $DailyRollupRetentionObservedSeconds
        monthlyRollupRetentionObservedSeconds = $MonthlyRollupRetentionObservedSeconds
        detailedRetentionDeletedRows = $DetailedRetentionDeletedRows
        dailyRollupRetentionDeletedRows = $DailyRollupRetentionDeletedRows
        monthlyRollupRetentionDeletedRows = $MonthlyRollupRetentionDeletedRows
        withinBudget = $retentionJobsWithinBudget
    }
    confirmations = [ordered]@{
        queryLatencyReviewed = [bool] $ConfirmQueryLatencyReviewed
        retentionJobsWithinBudget = [bool] $ConfirmRetentionJobsWithinBudget
        noObjectKeysInEvidence = [bool] $ConfirmNoObjectKeysInEvidence
        noRawSqlOrExplain = [bool] $ConfirmNoRawSqlOrExplain
        noSecretValues = [bool] $ConfirmNoSecretValues
    }
    summary = [ordered]@{
        failureCount = $failureCount
        checkCount = $checkArray.Count
    }
    checks = [object] $checkArray
    decisionRule = "Production/B2B analytics and chargeback scale requires result=passed after a passed data-flow storage plan, observed p95 query latency at or below the target budget, target-window benchmark coverage, retention job duration evidence within budget, and explicit no-object-key/no-raw-SQL/no-secret confirmations."
    scopePolicy = "OSMU operations analytics and internal chargeback scale evidence only. This is not AWS billing parity, and evidence must not include object keys, raw event messages, raw SQL, raw EXPLAIN JSON, or credentials."
    secretPolicy = "Evidence stores only environment labels, operator references, timestamps, aggregate latency/duration/count metrics, sanitized storage-plan summary, and external evidence references; it does not contain passwords, bearer tokens, kubeconfig, private keys, provider credentials, raw SQL, raw EXPLAIN JSON, object keys, or raw event messages."
}

$markdownLines = @(
    "# OSMU Data-flow Query And Retention Budget Evidence",
    "",
    "- Result: $result",
    "- Generated at: $generatedAt",
    "- Environment: $EnvironmentName",
    "- Target cluster: $TargetCluster",
    "- Operator: $Operator",
    "- Evidence ref: $EvidenceRef",
    "- Storage plan: result=$($planSummary["result"]); candidateStore=$($planSummary["candidateStore"]); pending=$($planSummary["pendingCount"])",
    "",
    "## Query Latency",
    "",
    "- Evidence ref: $QueryLatencyEvidenceRef",
    "- Target p95 query latency ms: $effectiveTargetP95",
    "- Observed p95 query latency ms: $ObservedP95QueryLatencyMs",
    "- Observed p99 query latency ms: $ObservedP99QueryLatencyMs",
    "- Query sample count: $QuerySampleCount",
    "- Observed query window days: $ObservedQueryWindowDays",
    "- Within budget: $queryLatencyWithinBudget",
    "",
    "## Retention Budget",
    "",
    "- Evidence ref: $RetentionBudgetEvidenceRef",
    "- Budget seconds: $RetentionJobBudgetSeconds",
    "- Detailed retention observed seconds: $DetailedRetentionObservedSeconds",
    "- Daily rollup retention observed seconds: $DailyRollupRetentionObservedSeconds",
    "- Monthly rollup retention observed seconds: $MonthlyRollupRetentionObservedSeconds",
    "- Within budget: $retentionJobsWithinBudget",
    "",
    "## Checks"
)
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}
$markdownLines += @(
    "",
    "## Secret Policy",
    "",
    $report.secretPolicy,
    "",
    "## Next Command",
    "",
    "- Feed this evidence reference into data-flow storage transition runbook notes and the operations handoff package as the query-latency/retention-budget evidence reference.",
    "- Record passed target evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-query-retention-budget-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -QueryLatencyEvidenceRef <ref> -RetentionBudgetEvidenceRef <ref> -EvidenceRef <run-ref> -ObservedP95QueryLatencyMs <ms> -ObservedP99QueryLatencyMs <ms> -QuerySampleCount <n> -ObservedQueryWindowDays <days> -RetentionJobBudgetSeconds <seconds> -DetailedRetentionObservedSeconds <seconds> -DailyRollupRetentionObservedSeconds <seconds> -MonthlyRollupRetentionObservedSeconds <seconds> -DetailedRetentionDeletedRows <n> -DailyRollupRetentionDeletedRows <n> -MonthlyRollupRetentionDeletedRows <n> -ConfirmQueryLatencyReviewed -ConfirmRetentionJobsWithinBudget -ConfirmNoObjectKeysInEvidence -ConfirmNoRawSqlOrExplain -ConfirmNoSecretValues -FailIfNotPassed``"
)

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($resolvedJsonOutputPath)) | Out-Null
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($resolvedMarkdownOutputPath)) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 -LiteralPath $resolvedJsonOutputPath
    $markdownLines -join [Environment]::NewLine | Set-Content -Encoding UTF8 -LiteralPath $resolvedMarkdownOutputPath
}

if ($FailIfNotPassed -and $result -ne "passed") {
    $failedDetails = ($checks | Where-Object { $_.status -eq "FAIL" } | ForEach-Object { "$($_.id): $($_.detail)" }) -join "; "
    throw "Data-flow query and retention budget evidence result is $result. $failedDetails"
}

Write-Host "Data-flow query and retention budget evidence result: $result"
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"