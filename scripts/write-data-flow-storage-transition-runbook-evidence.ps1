param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $ReviewStartedAt = "",
    [string] $ReviewCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $DataFlowStoragePlanJsonPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $DataFlowStoragePlanEvidenceRef = "",
    [string] $BackfillEvidenceRef = "",
    [string] $DualWriteOrPartitionToggleEvidenceRef = "",
    [string] $RollbackEvidenceRef = "",
    [string] $ReconciliationEvidenceRef = "",
    [string] $DashboardCutoverEvidenceRef = "",
    [string] $RetentionDryRunEvidenceRef = "",
    [string] $EvidenceRef = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-data-flow-storage-transition-runbook-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-data-flow-storage-transition-runbook-evidence.md",
    [switch] $ConfirmBackfillRehearsed,
    [switch] $ConfirmDualWriteOrPartitionToggleReviewed,
    [switch] $ConfirmRollbackRehearsed,
    [switch] $ConfirmReconciliationPassed,
    [switch] $ConfirmDashboardCutoverReviewed,
    [switch] $ConfirmRetentionDryRunReviewed,
    [switch] $ConfirmNoObjectKeysInAggregates,
    [switch] $ConfirmNoSecretValues,
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
function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
}

function Assert-SafeText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "(?i)\b(password|passwd|secret|token|credential|client_secret|x-amz-security-token|smtp_pass|webhook_secret)\s*[=:]\s*\S+"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain credential material. Store only an external evidence reference."
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
        "(?i)rawSql|raw_sql|rawExplain|raw_explain|queryText|query_text",
        "(?i)\b(password|passwd|secret|token|credential|client_secret)\s*[=:]\s*\S+",
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "DataFlowStoragePlanJson appears to contain raw SQL, raw EXPLAIN, or credential-shaped content. Store only sanitized summary evidence."
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

function Get-PropertyBool([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return $false
    }
    if ($value -is [bool]) {
        return [bool] $value
    }
    $parsed = $false
    if ([bool]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return $false
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
        targetP95QueryLatencyMs = 0
        expectedPeakEventsPerDay = 0
        expectedQueryWindowDays = 0
        pendingCount = 0
        checkCount = 0
        queryPlanEvidenceResult = ""
        queryPlanEvidence = [ordered]@{
            provided = $false
            path = ""
            parsed = $false
            formatVersion = ""
            expectedFormatVersion = ""
            validFormatVersion = $false
            result = ""
            mode = ""
            checkCount = 0
            passedCount = 0
            failedCount = 0
            detail = ""
        }
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
    $raw = Read-Utf8Text $resolvedPath
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
    $summary["targetP95QueryLatencyMs"] = Get-PropertyInt $payload "targetP95QueryLatencyMs"
    $summary["expectedPeakEventsPerDay"] = Get-PropertyInt $payload "expectedPeakEventsPerDay"
    $summary["expectedQueryWindowDays"] = Get-PropertyInt $payload "expectedQueryWindowDays"
    $summary["pendingCount"] = Get-PropertyInt $payload "pendingCount"
    $summary["checkCount"] = Get-PropertyInt $payload "checkCount"
    if ($null -ne $queryPlanEvidence) {
        $providedProperty = Get-PropertyValue $queryPlanEvidence "provided"
        $parsedProperty = Get-PropertyValue $queryPlanEvidence "parsed"
        $validFormatVersionProperty = Get-PropertyValue $queryPlanEvidence "validFormatVersion"
        $queryPlanSummary = [ordered]@{
            provided = if ($null -ne $providedProperty) { Get-PropertyBool $queryPlanEvidence "provided" } else { $true }
            path = Get-PropertyText $queryPlanEvidence "path"
            parsed = if ($null -ne $parsedProperty) { Get-PropertyBool $queryPlanEvidence "parsed" } else { $true }
            formatVersion = Get-PropertyText $queryPlanEvidence "formatVersion"
            expectedFormatVersion = Get-PropertyText $queryPlanEvidence "expectedFormatVersion"
            validFormatVersion = if ($null -ne $validFormatVersionProperty) { Get-PropertyBool $queryPlanEvidence "validFormatVersion" } else { $false }
            result = Get-PropertyText $queryPlanEvidence "result"
            mode = Get-PropertyText $queryPlanEvidence "mode"
            checkCount = Get-PropertyInt $queryPlanEvidence "checkCount"
            passedCount = Get-PropertyInt $queryPlanEvidence "passedCount"
            failedCount = Get-PropertyInt $queryPlanEvidence "failedCount"
            detail = Get-PropertyText $queryPlanEvidence "detail"
        }
        $summary["queryPlanEvidence"] = $queryPlanSummary
        $summary["queryPlanEvidenceResult"] = $queryPlanSummary["result"]
    }
    $summary["detail"] = "formatVersion=$($summary["formatVersion"]); result=$($summary["result"]); candidateStore=$($summary["candidateStore"]); pending=$($summary["pendingCount"]); targetP95QueryLatencyMs=$($summary["targetP95QueryLatencyMs"]); queryPlanEvidenceResult=$($summary["queryPlanEvidenceResult"]); queryPlanEvidenceFailed=$($summary["queryPlanEvidence"]["failedCount"])"
    return $summary
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef),
    @("DataFlowStoragePlanEvidenceRef", $DataFlowStoragePlanEvidenceRef),
    @("BackfillEvidenceRef", $BackfillEvidenceRef),
    @("DualWriteOrPartitionToggleEvidenceRef", $DualWriteOrPartitionToggleEvidenceRef),
    @("RollbackEvidenceRef", $RollbackEvidenceRef),
    @("ReconciliationEvidenceRef", $ReconciliationEvidenceRef),
    @("DashboardCutoverEvidenceRef", $DashboardCutoverEvidenceRef),
    @("RetentionDryRunEvidenceRef", $RetentionDryRunEvidenceRef),
    @("EvidenceRef", $EvidenceRef)
)) {
    Assert-SafeText ([string] $entry[1]) ([string] $entry[0])
}

$planSummary = Read-DataFlowStoragePlan $DataFlowStoragePlanJsonPath
$planPassed = [bool] $planSummary["provided"] -and
    [bool] $planSummary["parsed"] -and
    $planSummary["formatVersion"] -eq "osmu.data-flow-storage-plan.v1" -and
    "passed".Equals([string] $planSummary["result"], [System.StringComparison]::OrdinalIgnoreCase) -and
    [int] $planSummary["pendingCount"] -eq 0
$candidateNeedsQueryPlanEvidence = @("MARIADB_PARTITION", "DUAL_WRITE") -contains [string] $planSummary["candidateStore"]
$queryPlanEvidenceSummary = $planSummary["queryPlanEvidence"]
$queryPlanEvidenceTyped = -not $candidateNeedsQueryPlanEvidence -or (
    [bool] $queryPlanEvidenceSummary["provided"] -and
    [bool] $queryPlanEvidenceSummary["parsed"] -and
    "osmu.mariadb-query-plan-evidence.v1".Equals([string] $queryPlanEvidenceSummary["expectedFormatVersion"], [System.StringComparison]::OrdinalIgnoreCase) -and
    [bool] $queryPlanEvidenceSummary["validFormatVersion"] -and
    "passed".Equals([string] $queryPlanEvidenceSummary["result"], [System.StringComparison]::OrdinalIgnoreCase) -and
    [int] $queryPlanEvidenceSummary["checkCount"] -gt 0 -and
    [int] $queryPlanEvidenceSummary["passedCount"] -ge [int] $queryPlanEvidenceSummary["checkCount"] -and
    [int] $queryPlanEvidenceSummary["failedCount"] -eq 0
)
$reviewStartedAtParsed = Get-ParsedDateText $ReviewStartedAt
$reviewCompletedAtParsed = Get-ParsedDateText $ReviewCompletedAt
$reviewWindowOrdered = $null -ne $reviewStartedAtParsed -and $null -ne $reviewCompletedAtParsed -and $reviewCompletedAtParsed -ge $reviewStartedAtParsed
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ReviewStartedAt + $ReviewCompletedAt + $ChangeApprovalRef + $DataFlowStoragePlanEvidenceRef + $BackfillEvidenceRef + $DualWriteOrPartitionToggleEvidenceRef + $RollbackEvidenceRef + $ReconciliationEvidenceRef + $DashboardCutoverEvidenceRef + $RetentionDryRunEvidenceRef + $EvidenceRef) -or $ConfirmBackfillRehearsed -or $ConfirmDualWriteOrPartitionToggleReviewed -or $ConfirmRollbackRehearsed -or $ConfirmReconciliationPassed -or $ConfirmDashboardCutoverReviewed -or $ConfirmRetentionDryRunReviewed -or $ConfirmNoObjectKeysInAggregates -or $ConfirmNoSecretValues

Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($Operator)) "operator=$Operator"
Add-Check "review-started-at" "Review start timestamp recorded" (Test-DateText $ReviewStartedAt) "reviewStartedAt=$ReviewStartedAt"
Add-Check "review-completed-at" "Review completion timestamp recorded" (Test-DateText $ReviewCompletedAt) "reviewCompletedAt=$ReviewCompletedAt"
Add-Check "review-window-order" "Review window order valid" $reviewWindowOrdered "reviewStartedAt=$ReviewStartedAt; reviewCompletedAt=$ReviewCompletedAt"
Add-Check "change-approval-ref" "Change approval reference recorded" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "changeApprovalRef=$ChangeApprovalRef"
Add-Check "data-flow-storage-plan-evidence-ref" "Data-flow storage plan evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($DataFlowStoragePlanEvidenceRef)) "dataFlowStoragePlanEvidenceRef=$DataFlowStoragePlanEvidenceRef"
Add-Check "data-flow-storage-plan-passed" "Data-flow storage plan snapshot passed" $planPassed $planSummary["detail"]
Add-Check "data-flow-storage-plan-query-plan-snapshot" "Data-flow storage plan query-plan snapshot typed" $queryPlanEvidenceTyped "required=$candidateNeedsQueryPlanEvidence; result=$($queryPlanEvidenceSummary["result"]); passed=$($queryPlanEvidenceSummary["passedCount"]); failed=$($queryPlanEvidenceSummary["failedCount"]); checks=$($queryPlanEvidenceSummary["checkCount"])"
Add-Check "backfill-evidence-ref" "Backfill rehearsal evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($BackfillEvidenceRef)) "backfillEvidenceRef=$BackfillEvidenceRef"
Add-Check "dual-write-or-partition-toggle-evidence-ref" "Dual-write or partition toggle evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($DualWriteOrPartitionToggleEvidenceRef)) "dualWriteOrPartitionToggleEvidenceRef=$DualWriteOrPartitionToggleEvidenceRef"
Add-Check "rollback-evidence-ref" "Rollback rehearsal evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($RollbackEvidenceRef)) "rollbackEvidenceRef=$RollbackEvidenceRef"
Add-Check "reconciliation-evidence-ref" "Row/count reconciliation evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($ReconciliationEvidenceRef)) "reconciliationEvidenceRef=$ReconciliationEvidenceRef"
Add-Check "dashboard-cutover-evidence-ref" "Dashboard cutover evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($DashboardCutoverEvidenceRef)) "dashboardCutoverEvidenceRef=$DashboardCutoverEvidenceRef"
Add-Check "retention-dry-run-evidence-ref" "Retention dry-run evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($RetentionDryRunEvidenceRef)) "retentionDryRunEvidenceRef=$RetentionDryRunEvidenceRef"
Add-Check "backfill-rehearsed-confirmed" "Backfill rehearsal confirmation" ([bool] $ConfirmBackfillRehearsed) "Backfill batches were rehearsed against target scale without duplicating detailed events."
Add-Check "dual-write-or-partition-toggle-reviewed-confirmed" "Dual-write or partition toggle review confirmation" ([bool] $ConfirmDualWriteOrPartitionToggleReviewed) "Read/write toggle, feature flag, or partition switch path was reviewed."
Add-Check "rollback-rehearsed-confirmed" "Rollback rehearsal confirmation" ([bool] $ConfirmRollbackRehearsed) "Rollback returns reads to existing MariaDB detailed/materialized rollup paths."
Add-Check "reconciliation-passed-confirmed" "Row/count reconciliation passed confirmation" ([bool] $ConfirmReconciliationPassed) "Detailed/daily/monthly aggregate counts and byte totals were reconciled."
Add-Check "dashboard-cutover-reviewed-confirmed" "Dashboard cutover review confirmation" ([bool] $ConfirmDashboardCutoverReviewed) "Admin dashboard labels active analytics storage source and keeps billing parity out of scope."
Add-Check "retention-dry-run-reviewed-confirmed" "Retention dry-run review confirmation" ([bool] $ConfirmRetentionDryRunReviewed) "Retention jobs stay within target batch/time budgets."
Add-Check "no-object-keys-in-aggregates-confirmed" "No object keys in aggregate stores confirmation" ([bool] $ConfirmNoObjectKeysInAggregates) "Aggregate stores remain bucket/source/operation/status/time scoped."
Add-Check "no-secret-values-confirmed" "No secret values recorded confirmation" ([bool] $ConfirmNoSecretValues) "Evidence stores references and booleans only."

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

$report = New-Object System.Collections.Specialized.OrderedDictionary
[void] $report.Add("formatVersion", "osmu.data-flow-storage-transition-runbook-evidence.v1")
[void] $report.Add("generatedAt", $generatedAt)
[void] $report.Add("result", $result)
[void] $report.Add("environmentName", $EnvironmentName)
[void] $report.Add("targetCluster", $TargetCluster)
[void] $report.Add("operatorName", $Operator)
[void] $report.Add("evidenceRef", $EvidenceRef)
[void] $report.Add("reviewWindow", [ordered]@{
    startedAt = $ReviewStartedAt
    completedAt = $ReviewCompletedAt
})
[void] $report.Add("dataFlowStoragePlanSnapshot", $planSummary)
[void] $report.Add("evidenceRefs", [ordered]@{
    changeApproval = $ChangeApprovalRef
    dataFlowStoragePlan = $DataFlowStoragePlanEvidenceRef
    backfill = $BackfillEvidenceRef
    dualWriteOrPartitionToggle = $DualWriteOrPartitionToggleEvidenceRef
    rollback = $RollbackEvidenceRef
    reconciliation = $ReconciliationEvidenceRef
    dashboardCutover = $DashboardCutoverEvidenceRef
    retentionDryRun = $RetentionDryRunEvidenceRef
})
[void] $report.Add("confirmations", [ordered]@{
    backfillRehearsed = [bool] $ConfirmBackfillRehearsed
    dualWriteOrPartitionToggleReviewed = [bool] $ConfirmDualWriteOrPartitionToggleReviewed
    rollbackRehearsed = [bool] $ConfirmRollbackRehearsed
    reconciliationPassed = [bool] $ConfirmReconciliationPassed
    dashboardCutoverReviewed = [bool] $ConfirmDashboardCutoverReviewed
    retentionDryRunReviewed = [bool] $ConfirmRetentionDryRunReviewed
    noObjectKeysInAggregates = [bool] $ConfirmNoObjectKeysInAggregates
    noSecretValues = [bool] $ConfirmNoSecretValues
})
[void] $report.Add("summary", [ordered]@{
    failureCount = $failureCount
    checkCount = $checkArray.Count
})
[void] $report.Add("checks", [object] $checkArray)
[void] $report.Add("decisionRule", "Production/B2B analytics storage transition requires result=passed after a passed data-flow storage plan snapshot, backfill rehearsal, dual-write or partition toggle review, rollback rehearsal, row/count reconciliation, dashboard cutover review, retention dry-run review, no-object-key aggregate confirmation, and no-secret confirmation.")
[void] $report.Add("scopePolicy", "OSMU operations analytics storage transition only. This is not AWS billing parity, and aggregate stores must not include object keys, raw messages, raw SQL, raw EXPLAIN JSON, or credentials.")
[void] $report.Add("secretPolicy", "Evidence stores only environment labels, operator/change references, timestamps, booleans, sanitized data-flow storage plan summary, and external evidence references; it does not contain passwords, bearer tokens, kubeconfig, private keys, provider credentials, raw SQL, raw EXPLAIN JSON, object keys, or raw event messages.")

$markdownLines = @(
    "# OSMU Data-flow Storage Transition Runbook Evidence",
    "",
    "- Result: $result",
    "- Generated at: $generatedAt",
    "- Environment: $EnvironmentName",
    "- Target cluster: $TargetCluster",
    "- Operator: $Operator",
    "- Evidence ref: $EvidenceRef",
    "- Data-flow storage plan: $DataFlowStoragePlanEvidenceRef",
    "- Candidate store: $($planSummary["candidateStore"])",
    "- Target p95 query latency ms: $($planSummary["targetP95QueryLatencyMs"])",
    "- Query-plan evidence: result=$($queryPlanEvidenceSummary["result"]); mode=$($queryPlanEvidenceSummary["mode"]); passed=$($queryPlanEvidenceSummary["passedCount"])/$($queryPlanEvidenceSummary["checkCount"]); failed=$($queryPlanEvidenceSummary["failedCount"])",
    "",
    "## Checks"
)
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}
$markdownLines += @(
    "",
    "## Runbook Coverage",
    "",
    "- Backfill rehearsal",
    "- Dual-write or partition toggle review",
    "- Rollback rehearsal",
    "- Row/count reconciliation",
    "- Dashboard cutover review",
    "- Retention dry-run budget review",
    "- No object keys in aggregate stores",
    "",
    "## Secret Policy",
    "",
    $report.secretPolicy,
    "",
    "## Next Command",
    "",
    "- Feed this evidence reference into the data-flow storage plan or handoff package notes as the storage transition runbook rehearsal reference.",
    "- Record passed target evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-storage-transition-runbook-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -DataFlowStoragePlanEvidenceRef <ref> -BackfillEvidenceRef <ref> -DualWriteOrPartitionToggleEvidenceRef <ref> -RollbackEvidenceRef <ref> -ReconciliationEvidenceRef <ref> -DashboardCutoverEvidenceRef <ref> -RetentionDryRunEvidenceRef <ref> -EvidenceRef <run-ref> -ConfirmBackfillRehearsed -ConfirmDualWriteOrPartitionToggleReviewed -ConfirmRollbackRehearsed -ConfirmReconciliationPassed -ConfirmDashboardCutoverReviewed -ConfirmRetentionDryRunReviewed -ConfirmNoObjectKeysInAggregates -ConfirmNoSecretValues -FailIfNotPassed``"
)

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($resolvedJsonOutputPath)) | Out-Null
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($resolvedMarkdownOutputPath)) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 -LiteralPath $resolvedJsonOutputPath
    $markdownLines -join [Environment]::NewLine | Set-Content -Encoding UTF8 -LiteralPath $resolvedMarkdownOutputPath
}

if ($FailIfNotPassed -and $result -ne "passed") {
    $failedDetails = ($checks | Where-Object { $_.status -eq "FAIL" } | ForEach-Object { "$($_.id): $($_.detail)" }) -join "; "
    throw "Data-flow storage transition runbook evidence result is $result. $failedDetails"
}

Write-Host "Data-flow storage transition runbook evidence result: $result"
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"
