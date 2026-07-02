param(
    [string] $Namespace = "osmu",
    [string] $KubectlPath = "kubectl",
    [string] $ConfigMapName = "osmu-operations-reports",
    [string] $ReportPath = ".\.osmu-run\latest-operations-readiness-convergence.json",
    [string] $ConfigMapKey = "latest-operations-readiness-convergence.json",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-operations-report-sync.json",
    [string] $EvidenceConfigMapKey = "latest-kubernetes-operations-report-sync.json",
    [string] $DataFlowStoragePlanPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $DataFlowStoragePlanConfigMapKey = "latest-data-flow-storage-plan.json",
    [string] $DataFlowStorageTransitionRunbookPath = ".\.osmu-run\latest-data-flow-storage-transition-runbook-evidence.json",
    [string] $DataFlowStorageTransitionRunbookConfigMapKey = "latest-data-flow-storage-transition-runbook-evidence.json",
    [string] $DataFlowQueryRetentionBudgetPath = ".\.osmu-run\latest-data-flow-query-retention-budget-evidence.json",
    [string] $DataFlowQueryRetentionBudgetConfigMapKey = "latest-data-flow-query-retention-budget-evidence.json",
    [switch] $SkipEvidenceConfigMapPublish,
    [switch] $SkipDataFlowStoragePlanConfigMapPublish,
    [switch] $SkipDataFlowStorageTransitionRunbookConfigMapPublish,
    [switch] $SkipDataFlowQueryRetentionBudgetConfigMapPublish,
    [switch] $ServerDryRunOnly,
    [switch] $Apply,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()
$failureCount = 0

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    $resolvedPath = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}
function Format-Command([string[]] $Arguments) {
    $renderedArgs = $Arguments | ForEach-Object {
        if ($_ -match "\s") {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }
    return "$KubectlPath " + ($renderedArgs -join " ")
}

function Limit-Text([string] $Text) {
    if ($null -eq $Text) {
        return ""
    }
    if ($Text.Length -le 6000) {
        return $Text
    }
    return $Text.Substring(0, 6000) + "`n...truncated..."
}

function Add-Check(
    [string] $Name,
    [bool] $Passed,
    [string] $Summary,
    [string] $Command = "",
    [int] $ExitCode = 0,
    [string] $Output = ""
) {
    $script:checks += [pscustomobject]@{
        name = $Name
        passed = $Passed
        summary = $Summary
        command = $Command
        exitCode = $ExitCode
        output = (Limit-Text $Output)
    }
    if (-not $Passed) {
        $script:failureCount += 1
    }
}

function Invoke-KubectlRaw([string] $Name, [string[]] $Arguments) {
    $command = Format-Command $Arguments
    $outputLines = & $KubectlPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output = ($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    return [pscustomobject]@{
        name = $Name
        command = $command
        exitCode = $exitCode
        output = $output
    }
}

function Assert-KubernetesName([string] $Name, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name must not be empty."
    }
    if ($Value -notmatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" -or $Value.Length -gt 253) {
        throw "$Name must be a valid Kubernetes DNS label/name: $Value"
    }
}

function Assert-ConfigMapKey([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "ConfigMapKey must not be empty."
    }
    if ($Value -notmatch "^[A-Za-z0-9._-]+$") {
        throw "ConfigMapKey must contain only letters, numbers, dot, underscore, or dash: $Value"
    }
}

function Get-FileSha256([string] $PathValue) {
    return (Get-FileHash -LiteralPath $PathValue -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ObjectInt([object] $Value) {
    if ($null -eq $Value -or "$Value" -eq "") {
        return 0
    }
    try {
        return [int] $Value
    }
    catch {
        return 0
    }
}

function Get-FirstJsonValue([object[]] $Values) {
    foreach ($value in $Values) {
        if ($null -ne $value -and "$value" -ne "") {
            return $value
        }
    }
    return $null
}

function Get-ObjectBoolOrNull([object] $Value) {
    if ($Value -is [bool]) {
        return [bool] $Value
    }
    return $null
}

function Test-SanitizedQueryPlanEvidenceSummary([object] $QueryPlanEvidence) {
    if ($null -eq $QueryPlanEvidence) {
        return [pscustomobject]@{
            passed = $true
            detail = "queryPlanEvidence summary absent"
        }
    }

    $summaryText = $QueryPlanEvidence | ConvertTo-Json -Depth 20 -Compress
    $patterns = @(
        '(?i)"(sql|rawSql|raw_sql|explain|explainJson|explain_json|rawExplain|raw_explain|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key)\s*=\s*\S+',
        '(?i)\bSELECT\b[\s\S]{0,200}\bFROM\b'
    )
    foreach ($pattern in $patterns) {
        if ($summaryText -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "queryPlanEvidence summary contains raw SQL, raw EXPLAIN, or credential-shaped content"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "queryPlanEvidence summary is sanitized"
    }
}

Assert-KubernetesName "Namespace" $Namespace
Assert-KubernetesName "ConfigMapName" $ConfigMapName
Assert-ConfigMapKey $ConfigMapKey
Assert-ConfigMapKey $EvidenceConfigMapKey
Assert-ConfigMapKey $DataFlowStoragePlanConfigMapKey
Assert-ConfigMapKey $DataFlowStorageTransitionRunbookConfigMapKey
Assert-ConfigMapKey $DataFlowQueryRetentionBudgetConfigMapKey

$selectedModeCount = 0
foreach ($selectedMode in @($PlanOnly.IsPresent, $ServerDryRunOnly.IsPresent, $Apply.IsPresent)) {
    if ($selectedMode) {
        $selectedModeCount += 1
    }
}
if ($selectedModeCount -gt 1) {
    throw "Use only one mode: -PlanOnly, -ServerDryRunOnly, or -Apply."
}

$resolvedReportPath = Resolve-ProjectPath $ReportPath
$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$resolvedDataFlowStoragePlanPath = Resolve-ProjectPath $DataFlowStoragePlanPath
$resolvedDataFlowStorageTransitionRunbookPath = Resolve-ProjectPath $DataFlowStorageTransitionRunbookPath
$resolvedDataFlowQueryRetentionBudgetPath = Resolve-ProjectPath $DataFlowQueryRetentionBudgetPath
$publishEvidenceToConfigMap = [bool](-not $SkipEvidenceConfigMapPublish)
$publishDataFlowStoragePlanToConfigMap = [bool](-not $SkipDataFlowStoragePlanConfigMapPublish -and (Test-Path -LiteralPath $resolvedDataFlowStoragePlanPath))
$publishDataFlowStorageTransitionRunbookToConfigMap = [bool](-not $SkipDataFlowStorageTransitionRunbookConfigMapPublish -and (Test-Path -LiteralPath $resolvedDataFlowStorageTransitionRunbookPath))
$publishDataFlowQueryRetentionBudgetToConfigMap = [bool](-not $SkipDataFlowQueryRetentionBudgetConfigMapPublish -and (Test-Path -LiteralPath $resolvedDataFlowQueryRetentionBudgetPath))

if (-not (Test-Path -LiteralPath $resolvedReportPath)) {
    Add-Check "report-file-exists" $false "Report file is missing: $resolvedReportPath"
}
else {
    Add-Check "report-file-exists" $true "Report file exists."
}

$reportJson = $null
if (Test-Path -LiteralPath $resolvedReportPath) {
    try {
        $reportJson = Read-Utf8Text $resolvedReportPath | ConvertFrom-Json
        Add-Check "report-json-valid" $true "Report file is valid JSON."
    }
    catch {
        Add-Check "report-json-valid" $false "Report file is not valid JSON: $($_.Exception.Message)"
    }
}

$formatVersion = ""
$reportResult = ""
if ($null -ne $reportJson) {
    $formatVersion = [string] $reportJson.formatVersion
    $reportResult = [string] $reportJson.result
    Add-Check `
        "report-format-version" `
        ($formatVersion -eq "osmu.operations-readiness-convergence.v1") `
        "formatVersion=$formatVersion"
}

$reportBytes = if (Test-Path -LiteralPath $resolvedReportPath) {
    (Get-Item -LiteralPath $resolvedReportPath).Length
}
else {
    0
}
$reportSha256 = if (Test-Path -LiteralPath $resolvedReportPath) {
    Get-FileSha256 $resolvedReportPath
}
else {
    ""
}

$dataFlowStoragePlanFormatVersion = ""
$dataFlowStoragePlanResult = ""
$dataFlowStoragePlanCandidateStore = ""
$dataFlowQueryPlanEvidencePresent = $false
$dataFlowQueryPlanEvidenceProvided = $false
$dataFlowQueryPlanEvidenceResult = ""
$dataFlowQueryPlanEvidenceFailedCount = 0
$dataFlowQueryPlanEvidenceExpectedFormatVersion = ""
$dataFlowQueryPlanEvidenceFormatVersion = ""
if ($SkipDataFlowStoragePlanConfigMapPublish) {
    Add-Check "data-flow-storage-plan-publish-skipped" $true "Data-flow storage plan ConfigMap publish skipped by parameter."
}
elseif (-not (Test-Path -LiteralPath $resolvedDataFlowStoragePlanPath)) {
    Add-Check "data-flow-storage-plan-optional" $true "Optional data-flow storage plan file is missing; ConfigMap will not include it."
}
else {
    Add-Check "data-flow-storage-plan-file-exists" $true "Data-flow storage plan file exists."
    try {
        $dataFlowStoragePlanJson = Read-Utf8Text $resolvedDataFlowStoragePlanPath | ConvertFrom-Json
        $dataFlowStoragePlanFormatVersion = [string] $dataFlowStoragePlanJson.formatVersion
        $dataFlowStoragePlanResult = [string] $dataFlowStoragePlanJson.result
        $dataFlowStoragePlanCandidateStore = [string] $dataFlowStoragePlanJson.candidateStore
        $queryPlanEvidence = $dataFlowStoragePlanJson.queryPlanEvidence
        $dataFlowQueryPlanEvidencePresent = $null -ne $queryPlanEvidence
        if ($dataFlowQueryPlanEvidencePresent) {
            $dataFlowQueryPlanEvidenceProvided = [bool] $queryPlanEvidence.provided
            $dataFlowQueryPlanEvidenceResult = [string] $queryPlanEvidence.result
            $dataFlowQueryPlanEvidenceFailedCount = Get-ObjectInt $queryPlanEvidence.failedCount
            $dataFlowQueryPlanEvidenceExpectedFormatVersion = [string] $queryPlanEvidence.expectedFormatVersion
            $dataFlowQueryPlanEvidenceFormatVersion = [string] $queryPlanEvidence.formatVersion
            $dataFlowQueryPlanEvidenceSanitized = Test-SanitizedQueryPlanEvidenceSummary $queryPlanEvidence
        }
        $dataFlowQueryPlanEvidenceRequired = @("MARIADB_PARTITION", "DUAL_WRITE") -contains $dataFlowStoragePlanCandidateStore
        Add-Check "data-flow-storage-plan-json-valid" $true "Data-flow storage plan file is valid JSON."
        Add-Check `
            "data-flow-storage-plan-format-version" `
            ($dataFlowStoragePlanFormatVersion -eq "osmu.data-flow-storage-plan.v1") `
            "formatVersion=$dataFlowStoragePlanFormatVersion"
        if ($dataFlowQueryPlanEvidenceRequired) {
            Add-Check `
                "data-flow-query-plan-evidence-summary-present" `
                $dataFlowQueryPlanEvidencePresent `
                "candidateStore=$dataFlowStoragePlanCandidateStore requires queryPlanEvidence summary before ConfigMap publish."
        }
        if ($dataFlowQueryPlanEvidencePresent) {
            Add-Check `
                "data-flow-query-plan-evidence-format-contract" `
                ($dataFlowQueryPlanEvidenceExpectedFormatVersion -eq "osmu.mariadb-query-plan-evidence.v1") `
                "queryPlanEvidence expectedFormatVersion=$dataFlowQueryPlanEvidenceExpectedFormatVersion."
            Add-Check `
                "data-flow-query-plan-evidence-sanitized" `
                $dataFlowQueryPlanEvidenceSanitized.passed `
                $dataFlowQueryPlanEvidenceSanitized.detail
        }
    }
    catch {
        Add-Check "data-flow-storage-plan-json-valid" $false "Data-flow storage plan file is not valid JSON: $($_.Exception.Message)"
    }
}

$dataFlowStorageTransitionRunbookFormatVersion = ""
$dataFlowStorageTransitionRunbookResult = ""
$dataFlowStorageTransitionRunbookStoragePlanResult = ""
$dataFlowStorageTransitionRunbookCandidateStore = ""
$dataFlowStorageTransitionRunbookFailureCount = 0
$dataFlowStorageTransitionRunbookCheckCount = 0
if ($SkipDataFlowStorageTransitionRunbookConfigMapPublish) {
    Add-Check "data-flow-storage-transition-runbook-publish-skipped" $true "Data-flow storage transition runbook ConfigMap publish skipped by parameter."
}
elseif (-not (Test-Path -LiteralPath $resolvedDataFlowStorageTransitionRunbookPath)) {
    Add-Check "data-flow-storage-transition-runbook-optional" $true "Optional data-flow storage transition runbook file is missing; ConfigMap will not include it."
}
else {
    Add-Check "data-flow-storage-transition-runbook-file-exists" $true "Data-flow storage transition runbook file exists."
    try {
        $runbookRaw = Read-Utf8Text $resolvedDataFlowStorageTransitionRunbookPath
        $runbookJson = $runbookRaw | ConvertFrom-Json
        $dataFlowStorageTransitionRunbookFormatVersion = [string] $runbookJson.formatVersion
        $dataFlowStorageTransitionRunbookResult = [string] $runbookJson.result
        $dataFlowStorageTransitionRunbookStoragePlanResult = [string] $runbookJson.dataFlowStoragePlanSnapshot.result
        $dataFlowStorageTransitionRunbookCandidateStore = [string] $runbookJson.dataFlowStoragePlanSnapshot.candidateStore
        $dataFlowStorageTransitionRunbookFailureCount = Get-ObjectInt $runbookJson.summary.failureCount
        $dataFlowStorageTransitionRunbookCheckCount = Get-ObjectInt $runbookJson.summary.checkCount
        Add-Check "data-flow-storage-transition-runbook-json-valid" $true "Data-flow storage transition runbook file is valid JSON."
        Add-Check `
            "data-flow-storage-transition-runbook-format-version" `
            ($dataFlowStorageTransitionRunbookFormatVersion -eq "osmu.data-flow-storage-transition-runbook-evidence.v1") `
            "formatVersion=$dataFlowStorageTransitionRunbookFormatVersion"
        Add-Check `
            "data-flow-storage-transition-runbook-result" `
            ($dataFlowStorageTransitionRunbookResult -eq "passed") `
            "result=$dataFlowStorageTransitionRunbookResult expected=passed before ConfigMap publish."
        Add-Check `
            "data-flow-storage-transition-runbook-plan-result" `
            ($dataFlowStorageTransitionRunbookStoragePlanResult -eq "passed") `
            "dataFlowStoragePlanSnapshot.result=$dataFlowStorageTransitionRunbookStoragePlanResult expected=passed."
        Add-Check `
            "data-flow-storage-transition-runbook-failure-count" `
            ($dataFlowStorageTransitionRunbookFailureCount -eq 0) `
            "failureCount=$dataFlowStorageTransitionRunbookFailureCount expected=0."
        foreach ($confirmationName in @("backfillRehearsed", "dualWriteOrPartitionToggleReviewed", "rollbackRehearsed", "reconciliationPassed", "dashboardCutoverReviewed", "retentionDryRunReviewed", "noObjectKeysInAggregates", "noSecretValues")) {
            $confirmationValue = $runbookJson.confirmations.PSObject.Properties[$confirmationName].Value
            Add-Check `
                "data-flow-storage-transition-runbook-$confirmationName" `
                (($confirmationValue -is [bool]) -and [bool] $confirmationValue) `
                "confirmation $confirmationName=$confirmationValue expected boolean true."
        }
        $patterns = @(
            '(?i)"(sql|rawSql|raw_sql|queryText|query_text|explain|explainJson|explain_json|rawExplain|raw_explain|rawEventMessage|raw_event_message|objectKey|object_key|password|passwd|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:',
            '(?i)\b(password|passwd|credential|api[_-]?key|access[_-]?key|private[_-]?key)\s*=\s*\S+',
            '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
            '(?i)\bSELECT\b[\s\S]{0,200}\bFROM\b',
            '(?i)\bEXPLAIN\b[\s\S]{0,200}\bFORMAT\b'
        )
        $sanitized = $true
        foreach ($pattern in $patterns) {
            if ($runbookRaw -match $pattern) {
                $sanitized = $false
            }
        }
        Add-Check `
            "data-flow-storage-transition-runbook-sanitized" `
            $sanitized `
            "Runbook evidence contains no raw SQL, raw EXPLAIN, object keys, raw event messages, or credential-shaped content."
    }
    catch {
        Add-Check "data-flow-storage-transition-runbook-json-valid" $false "Data-flow storage transition runbook file is not valid JSON: $($_.Exception.Message)"
    }
}

$dataFlowQueryRetentionBudgetFormatVersion = ""
$dataFlowQueryRetentionBudgetResult = ""
$dataFlowQueryRetentionBudgetStoragePlanResult = ""
$dataFlowQueryRetentionBudgetCandidateStore = ""
$dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs = 0
$dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs = 0
$dataFlowQueryRetentionBudgetObservedP99QueryLatencyMs = 0
$dataFlowQueryRetentionBudgetRetentionBudgetSeconds = 0
$dataFlowQueryRetentionBudgetFailureCount = 0
$dataFlowQueryRetentionBudgetCheckCount = 0
if ($SkipDataFlowQueryRetentionBudgetConfigMapPublish) {
    Add-Check "data-flow-query-retention-budget-publish-skipped" $true "Data-flow query/retention budget ConfigMap publish skipped by parameter."
}
elseif (-not (Test-Path -LiteralPath $resolvedDataFlowQueryRetentionBudgetPath)) {
    Add-Check "data-flow-query-retention-budget-optional" $true "Optional data-flow query/retention budget file is missing; ConfigMap will not include it."
}
else {
    Add-Check "data-flow-query-retention-budget-file-exists" $true "Data-flow query/retention budget file exists."
    try {
        $budgetRaw = Read-Utf8Text $resolvedDataFlowQueryRetentionBudgetPath
        $budgetJson = $budgetRaw | ConvertFrom-Json
        $storagePlanSnapshot = $budgetJson.dataFlowStoragePlanSnapshot
        $queryLatencyBudget = $budgetJson.queryLatencyBudget
        $retentionBudget = $budgetJson.retentionBudget
        $dataFlowQueryRetentionBudgetFormatVersion = [string] $budgetJson.formatVersion
        $dataFlowQueryRetentionBudgetResult = [string] $budgetJson.result
        $dataFlowQueryRetentionBudgetStoragePlanResult = [string] (Get-FirstJsonValue @($storagePlanSnapshot.result, $budgetJson.storagePlanResult))
        $dataFlowQueryRetentionBudgetCandidateStore = [string] (Get-FirstJsonValue @($storagePlanSnapshot.candidateStore, $budgetJson.candidateStore))
        $dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs = Get-ObjectInt (Get-FirstJsonValue @($queryLatencyBudget.targetP95QueryLatencyMs, $budgetJson.targetP95QueryLatencyMs, $storagePlanSnapshot.targetP95QueryLatencyMs))
        $dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs = Get-ObjectInt (Get-FirstJsonValue @($queryLatencyBudget.observedP95QueryLatencyMs, $budgetJson.observedP95QueryLatencyMs))
        $dataFlowQueryRetentionBudgetObservedP99QueryLatencyMs = Get-ObjectInt (Get-FirstJsonValue @($queryLatencyBudget.observedP99QueryLatencyMs, $budgetJson.observedP99QueryLatencyMs))
        $querySampleCount = Get-ObjectInt (Get-FirstJsonValue @($queryLatencyBudget.querySampleCount, $budgetJson.querySampleCount))
        $observedQueryWindowDays = Get-ObjectInt (Get-FirstJsonValue @($queryLatencyBudget.observedQueryWindowDays, $budgetJson.observedQueryWindowDays))
        $dataFlowQueryRetentionBudgetRetentionBudgetSeconds = Get-ObjectInt (Get-FirstJsonValue @($retentionBudget.budgetSeconds, $retentionBudget.retentionBudgetSeconds, $budgetJson.retentionBudgetSeconds, $budgetJson.retentionJobBudgetSeconds))
        $detailedRetentionObservedSeconds = Get-ObjectInt (Get-FirstJsonValue @($retentionBudget.detailedRetentionObservedSeconds, $budgetJson.detailedRetentionObservedSeconds))
        $dailyRollupRetentionObservedSeconds = Get-ObjectInt (Get-FirstJsonValue @($retentionBudget.dailyRollupRetentionObservedSeconds, $budgetJson.dailyRollupRetentionObservedSeconds))
        $monthlyRollupRetentionObservedSeconds = Get-ObjectInt (Get-FirstJsonValue @($retentionBudget.monthlyRollupRetentionObservedSeconds, $budgetJson.monthlyRollupRetentionObservedSeconds))
        $dataFlowQueryRetentionBudgetFailureCount = Get-ObjectInt (Get-FirstJsonValue @($budgetJson.summary.failureCount, $budgetJson.failureCount))
        $dataFlowQueryRetentionBudgetCheckCount = Get-ObjectInt (Get-FirstJsonValue @($budgetJson.summary.checkCount, $budgetJson.checkCount))
        $storagePlanPendingCount = Get-ObjectInt (Get-FirstJsonValue @($storagePlanSnapshot.pendingCount, $budgetJson.storagePlanPendingCount))
        $queryLatencyWithinBudget = Get-ObjectBoolOrNull (Get-FirstJsonValue @($queryLatencyBudget.withinBudget, $budgetJson.queryLatencyWithinBudget))
        $retentionJobsWithinBudget = Get-ObjectBoolOrNull (Get-FirstJsonValue @($retentionBudget.withinBudget, $budgetJson.retentionJobsWithinBudget))
        Add-Check "data-flow-query-retention-budget-json-valid" $true "Data-flow query/retention budget file is valid JSON."
        Add-Check `
            "data-flow-query-retention-budget-format-version" `
            ($dataFlowQueryRetentionBudgetFormatVersion -eq "osmu.data-flow-query-retention-budget-evidence.v1") `
            "formatVersion=$dataFlowQueryRetentionBudgetFormatVersion"
        Add-Check `
            "data-flow-query-retention-budget-result" `
            ($dataFlowQueryRetentionBudgetResult -eq "passed") `
            "result=$dataFlowQueryRetentionBudgetResult expected=passed before ConfigMap publish."
        Add-Check `
            "data-flow-query-retention-budget-storage-plan-result" `
            ($dataFlowQueryRetentionBudgetStoragePlanResult -eq "passed") `
            "storagePlanResult=$dataFlowQueryRetentionBudgetStoragePlanResult expected=passed."
        Add-Check `
            "data-flow-query-retention-budget-storage-plan-pending-count" `
            ($storagePlanPendingCount -eq 0) `
            "storagePlanPendingCount=$storagePlanPendingCount expected=0."
        Add-Check `
            "data-flow-query-retention-budget-query-latency-within-budget" `
            (($null -ne $queryLatencyWithinBudget) -and [bool] $queryLatencyWithinBudget) `
            "query latency within budget=$queryLatencyWithinBudget expected boolean true."
        $queryMetricsValid = $dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs -gt 0 `
            -and $dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs -gt 0 `
            -and $dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs -le $dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs `
            -and $dataFlowQueryRetentionBudgetObservedP99QueryLatencyMs -ge $dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs `
            -and $querySampleCount -gt 0 `
            -and $observedQueryWindowDays -gt 0
        Add-Check `
            "data-flow-query-retention-budget-query-metrics" `
            $queryMetricsValid `
            "targetP95=$dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs observedP95=$dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs observedP99=$dataFlowQueryRetentionBudgetObservedP99QueryLatencyMs sampleCount=$querySampleCount windowDays=$observedQueryWindowDays."
        Add-Check `
            "data-flow-query-retention-budget-retention-within-budget" `
            (($null -ne $retentionJobsWithinBudget) -and [bool] $retentionJobsWithinBudget) `
            "retention jobs within budget=$retentionJobsWithinBudget expected boolean true."
        $retentionMetricsValid = $dataFlowQueryRetentionBudgetRetentionBudgetSeconds -gt 0 `
            -and $detailedRetentionObservedSeconds -ge 0 `
            -and $dailyRollupRetentionObservedSeconds -ge 0 `
            -and $monthlyRollupRetentionObservedSeconds -ge 0 `
            -and $detailedRetentionObservedSeconds -le $dataFlowQueryRetentionBudgetRetentionBudgetSeconds `
            -and $dailyRollupRetentionObservedSeconds -le $dataFlowQueryRetentionBudgetRetentionBudgetSeconds `
            -and $monthlyRollupRetentionObservedSeconds -le $dataFlowQueryRetentionBudgetRetentionBudgetSeconds
        Add-Check `
            "data-flow-query-retention-budget-retention-metrics" `
            $retentionMetricsValid `
            "budgetSeconds=$dataFlowQueryRetentionBudgetRetentionBudgetSeconds detailed=$detailedRetentionObservedSeconds daily=$dailyRollupRetentionObservedSeconds monthly=$monthlyRollupRetentionObservedSeconds."
        Add-Check `
            "data-flow-query-retention-budget-failure-count" `
            ($dataFlowQueryRetentionBudgetFailureCount -eq 0) `
            "failureCount=$dataFlowQueryRetentionBudgetFailureCount expected=0."
        foreach ($confirmationName in @("queryLatencyReviewed", "retentionJobsWithinBudget", "noObjectKeysInEvidence", "noRawSqlOrExplain", "noSecretValues")) {
            $confirmationValue = if ($null -ne $budgetJson.confirmations -and $budgetJson.confirmations.PSObject.Properties.Name -contains $confirmationName) { $budgetJson.confirmations.PSObject.Properties[$confirmationName].Value } else { $null }
            Add-Check `
                "data-flow-query-retention-budget-$confirmationName" `
                (($confirmationValue -is [bool]) -and [bool] $confirmationValue) `
                "confirmation $confirmationName=$confirmationValue expected boolean true."
        }
        $patterns = @(
            '(?i)"(sql|rawSql|raw_sql|queryText|query_text|explain|explainJson|explain_json|rawExplain|raw_explain|rawEventMessage|raw_event_message|objectKey|object_key|password|passwd|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:',
            '(?i)\b(password|passwd|credential|api[_-]?key|access[_-]?key|private[_-]?key|object[_-]?key)\s*=\s*\S+',
            '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
            '(?i)\bSELECT\b[\s\S]{0,200}\bFROM\b',
            '(?i)\bEXPLAIN\b[\s\S]{0,200}\bFORMAT\b'
        )
        $sanitized = $true
        foreach ($pattern in $patterns) {
            if ($budgetRaw -match $pattern) {
                $sanitized = $false
            }
        }
        Add-Check `
            "data-flow-query-retention-budget-sanitized" `
            $sanitized `
            "Query/retention budget evidence contains no raw SQL, raw EXPLAIN, object keys, raw event messages, or credential-shaped content."
    }
    catch {
        Add-Check "data-flow-query-retention-budget-json-valid" $false "Data-flow query/retention budget file is not valid JSON: $($_.Exception.Message)"
    }
}

$dataFlowStoragePlanBytes = if ($publishDataFlowStoragePlanToConfigMap) {
    (Get-Item -LiteralPath $resolvedDataFlowStoragePlanPath).Length
}
else {
    0
}
$dataFlowStoragePlanSha256 = if ($publishDataFlowStoragePlanToConfigMap) {
    Get-FileSha256 $resolvedDataFlowStoragePlanPath
}
else {
    ""
}
$dataFlowStorageTransitionRunbookBytes = if ($publishDataFlowStorageTransitionRunbookToConfigMap) {
    (Get-Item -LiteralPath $resolvedDataFlowStorageTransitionRunbookPath).Length
}
else {
    0
}
$dataFlowQueryRetentionBudgetBytes = if ($publishDataFlowQueryRetentionBudgetToConfigMap) {
    (Get-Item -LiteralPath $resolvedDataFlowQueryRetentionBudgetPath).Length
}
else {
    0
}
$dataFlowQueryRetentionBudgetSha256 = if ($publishDataFlowQueryRetentionBudgetToConfigMap) {
    Get-FileSha256 $resolvedDataFlowQueryRetentionBudgetPath
}
else {
    ""
}

$dataFlowStorageTransitionRunbookSha256 = if ($publishDataFlowStorageTransitionRunbookToConfigMap) {
    Get-FileSha256 $resolvedDataFlowStorageTransitionRunbookPath
}
else {
    ""
}

function New-CreateConfigMapArguments([bool] $IncludeEvidence, [string] $DryRunMode) {
    $arguments = @(
        "-n", $Namespace,
        "create", "configmap", $ConfigMapName,
        "--from-file=$ConfigMapKey=$resolvedReportPath"
    )
    if ($publishDataFlowStoragePlanToConfigMap) {
        $arguments += "--from-file=$DataFlowStoragePlanConfigMapKey=$resolvedDataFlowStoragePlanPath"
    }
    if ($publishDataFlowStorageTransitionRunbookToConfigMap) {
        $arguments += "--from-file=$DataFlowStorageTransitionRunbookConfigMapKey=$resolvedDataFlowStorageTransitionRunbookPath"
    }
    if ($publishDataFlowQueryRetentionBudgetToConfigMap) {
        $arguments += "--from-file=$DataFlowQueryRetentionBudgetConfigMapKey=$resolvedDataFlowQueryRetentionBudgetPath"
    }
    if ($IncludeEvidence) {
        $arguments += "--from-file=$EvidenceConfigMapKey=$resolvedEvidencePath"
    }
    $arguments += @(
        "--dry-run=$DryRunMode",
        "-o", "yaml"
    )
    return $arguments
}

$createClientArguments = New-CreateConfigMapArguments $false "client"
$serverDryRunArguments = New-CreateConfigMapArguments $false "server"
$publishEvidenceClientArguments = New-CreateConfigMapArguments $true "client"

$clientDryRunCommand = Format-Command $createClientArguments
$serverDryRunCommand = Format-Command $serverDryRunArguments
$applyCommand = "$clientDryRunCommand | $KubectlPath apply -f -"
$publishEvidenceClientDryRunCommand = Format-Command $publishEvidenceClientArguments
$publishEvidenceApplyCommand = "$publishEvidenceClientDryRunCommand | $KubectlPath apply -f -"

$result = "planned"
$serverDryRunOutput = ""
$applyOutput = ""
$publishEvidenceApplyOutput = ""

function New-ReportObject([string] $ResultValue) {
    return [ordered]@{
        formatVersion = "osmu.kubernetes-operations-report-sync.v1"
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        result = $ResultValue
        namespace = $Namespace
        configMapName = $ConfigMapName
        configMapKey = $ConfigMapKey
        evidenceConfigMapKey = $EvidenceConfigMapKey
        dataFlowStoragePlanConfigMapKey = $DataFlowStoragePlanConfigMapKey
        dataFlowStorageTransitionRunbookConfigMapKey = $DataFlowStorageTransitionRunbookConfigMapKey
        dataFlowQueryRetentionBudgetConfigMapKey = $DataFlowQueryRetentionBudgetConfigMapKey
        publishEvidenceToConfigMap = [bool] $publishEvidenceToConfigMap
        publishDataFlowStoragePlanToConfigMap = [bool] $publishDataFlowStoragePlanToConfigMap
        publishDataFlowStorageTransitionRunbookToConfigMap = [bool] $publishDataFlowStorageTransitionRunbookToConfigMap
        publishDataFlowQueryRetentionBudgetToConfigMap = [bool] $publishDataFlowQueryRetentionBudgetToConfigMap
        sourceReportPath = $resolvedReportPath
        sourceReportFormatVersion = $formatVersion
        sourceReportResult = $reportResult
        sourceReportBytes = $reportBytes
        sourceReportSha256 = $reportSha256
        dataFlowStoragePlanPath = $resolvedDataFlowStoragePlanPath
        dataFlowStoragePlanFormatVersion = $dataFlowStoragePlanFormatVersion
        dataFlowStoragePlanResult = $dataFlowStoragePlanResult
        dataFlowStoragePlanCandidateStore = $dataFlowStoragePlanCandidateStore
        dataFlowStoragePlanBytes = $dataFlowStoragePlanBytes
        dataFlowStoragePlanSha256 = $dataFlowStoragePlanSha256
        dataFlowQueryPlanEvidencePresent = [bool] $dataFlowQueryPlanEvidencePresent
        dataFlowQueryPlanEvidenceProvided = [bool] $dataFlowQueryPlanEvidenceProvided
        dataFlowQueryPlanEvidenceResult = $dataFlowQueryPlanEvidenceResult
        dataFlowQueryPlanEvidenceFailedCount = $dataFlowQueryPlanEvidenceFailedCount
        dataFlowQueryPlanEvidenceExpectedFormatVersion = $dataFlowQueryPlanEvidenceExpectedFormatVersion
        dataFlowQueryPlanEvidenceFormatVersion = $dataFlowQueryPlanEvidenceFormatVersion
        dataFlowQueryRetentionBudgetPath = $resolvedDataFlowQueryRetentionBudgetPath
        dataFlowQueryRetentionBudgetFormatVersion = $dataFlowQueryRetentionBudgetFormatVersion
        dataFlowQueryRetentionBudgetResult = $dataFlowQueryRetentionBudgetResult
        dataFlowQueryRetentionBudgetStoragePlanResult = $dataFlowQueryRetentionBudgetStoragePlanResult
        dataFlowQueryRetentionBudgetCandidateStore = $dataFlowQueryRetentionBudgetCandidateStore
        dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs = $dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs
        dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs = $dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs
        dataFlowQueryRetentionBudgetObservedP99QueryLatencyMs = $dataFlowQueryRetentionBudgetObservedP99QueryLatencyMs
        dataFlowQueryRetentionBudgetRetentionBudgetSeconds = $dataFlowQueryRetentionBudgetRetentionBudgetSeconds
        dataFlowQueryRetentionBudgetFailureCount = $dataFlowQueryRetentionBudgetFailureCount
        dataFlowQueryRetentionBudgetCheckCount = $dataFlowQueryRetentionBudgetCheckCount
        dataFlowQueryRetentionBudgetBytes = $dataFlowQueryRetentionBudgetBytes
        dataFlowQueryRetentionBudgetSha256 = $dataFlowQueryRetentionBudgetSha256
        dataFlowStorageTransitionRunbookPath = $resolvedDataFlowStorageTransitionRunbookPath
        dataFlowStorageTransitionRunbookFormatVersion = $dataFlowStorageTransitionRunbookFormatVersion
        dataFlowStorageTransitionRunbookResult = $dataFlowStorageTransitionRunbookResult
        dataFlowStorageTransitionRunbookStoragePlanResult = $dataFlowStorageTransitionRunbookStoragePlanResult
        dataFlowStorageTransitionRunbookCandidateStore = $dataFlowStorageTransitionRunbookCandidateStore
        dataFlowStorageTransitionRunbookFailureCount = $dataFlowStorageTransitionRunbookFailureCount
        dataFlowStorageTransitionRunbookCheckCount = $dataFlowStorageTransitionRunbookCheckCount
        dataFlowStorageTransitionRunbookBytes = $dataFlowStorageTransitionRunbookBytes
        dataFlowStorageTransitionRunbookSha256 = $dataFlowStorageTransitionRunbookSha256
        clientDryRunCommand = $clientDryRunCommand
        serverDryRunCommand = $serverDryRunCommand
        applyCommand = $applyCommand
        publishEvidenceClientDryRunCommand = $publishEvidenceClientDryRunCommand
        publishEvidenceApplyCommand = $publishEvidenceApplyCommand
        serverDryRunOutput = (Limit-Text $serverDryRunOutput)
        applyOutput = (Limit-Text $applyOutput)
        publishEvidenceApplyOutput = (Limit-Text $publishEvidenceApplyOutput)
        checkCount = @($checks).Count
        failedCount = $failureCount
        checks = $checks
        safetyPolicy = "This script writes to Kubernetes only when -Apply is supplied. -ServerDryRunOnly talks to the API server without persisting changes. The default and -PlanOnly modes do not execute kubectl. When present, the data-flow storage plan, query/retention budget evidence, and transition runbook evidence are included in the same ConfigMap so dashboard readiness can expose target analytics-storage planning, latency/retention budget, and rehearsal evidence. After a successful apply, the sync evidence file is also published into the same ConfigMap unless -SkipEvidenceConfigMapPublish is supplied."
    }
}

if ($failureCount -eq 0 -and $ServerDryRunOnly) {
    $serverDryRun = Invoke-KubectlRaw "server-dry-run-configmap" $serverDryRunArguments
    $serverDryRunOutput = $serverDryRun.output
    Add-Check `
        "server-dry-run-configmap" `
        ($serverDryRun.exitCode -eq 0) `
        "Server-side dry-run validates ConfigMap create/update shape without writing." `
        $serverDryRun.command `
        $serverDryRun.exitCode `
        $serverDryRun.output
    $result = if ($failureCount -eq 0) { "server-dry-run-passed" } else { "failed" }
}
elseif ($failureCount -eq 0 -and $Apply) {
    $clientDryRun = Invoke-KubectlRaw "render-configmap" $createClientArguments
    Add-Check `
        "render-configmap" `
        ($clientDryRun.exitCode -eq 0) `
        "Rendered ConfigMap manifest from the local report file." `
        $clientDryRun.command `
        $clientDryRun.exitCode `
        $clientDryRun.output

    if ($clientDryRun.exitCode -eq 0) {
        $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "osmu"
        New-Item -ItemType Directory -Force -Path $tempDirectory | Out-Null
        $tempManifest = Join-Path $tempDirectory ("operations-reports-configmap-{0}.yaml" -f ([Guid]::NewGuid().ToString("N")))
        try {
            $clientDryRun.output | Set-Content -LiteralPath $tempManifest -Encoding UTF8
            $applyResult = Invoke-KubectlRaw "apply-configmap" @("apply", "-f", $tempManifest)
            $applyOutput = $applyResult.output
            Add-Check `
                "apply-configmap" `
                ($applyResult.exitCode -eq 0) `
                "Applied operations report ConfigMap." `
                $applyResult.command `
                $applyResult.exitCode `
                $applyResult.output
        }
        finally {
            if (Test-Path -LiteralPath $tempManifest) {
                Remove-Item -LiteralPath $tempManifest -Force
            }
        }
    }

    if ($failureCount -eq 0 -and $publishEvidenceToConfigMap) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedEvidencePath) | Out-Null
        $preliminaryReport = New-ReportObject "applied"
        $preliminaryReport | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

        $publishRender = Invoke-KubectlRaw "render-configmap-with-sync-evidence" $publishEvidenceClientArguments
        Add-Check `
            "render-configmap-with-sync-evidence" `
            ($publishRender.exitCode -eq 0) `
            "Rendered ConfigMap manifest with convergence report and sync evidence." `
            $publishRender.command `
            $publishRender.exitCode `
            $publishRender.output

        if ($publishRender.exitCode -eq 0) {
            $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "osmu"
            New-Item -ItemType Directory -Force -Path $tempDirectory | Out-Null
            $tempManifest = Join-Path $tempDirectory ("operations-reports-configmap-with-evidence-{0}.yaml" -f ([Guid]::NewGuid().ToString("N")))
            try {
                $publishRender.output | Set-Content -LiteralPath $tempManifest -Encoding UTF8
                $publishApply = Invoke-KubectlRaw "apply-configmap-with-sync-evidence" @("apply", "-f", $tempManifest)
                $publishEvidenceApplyOutput = $publishApply.output
                Add-Check `
                    "apply-configmap-with-sync-evidence" `
                    ($publishApply.exitCode -eq 0) `
                    "Applied operations report ConfigMap with sync evidence for dashboard visibility." `
                    $publishApply.command `
                    $publishApply.exitCode `
                    $publishApply.output
            }
            finally {
                if (Test-Path -LiteralPath $tempManifest) {
                    Remove-Item -LiteralPath $tempManifest -Force
                }
            }
        }
    }
    $result = if ($failureCount -eq 0) { "applied" } else { "failed" }
}
elseif ($failureCount -gt 0) {
    $result = "failed"
}
else {
    $result = "planned"
}

if ($PlanOnly) {
    $result = if ($failureCount -eq 0) { "planned" } else { "failed" }
}

$report = New-ReportObject $result

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedEvidencePath) | Out-Null
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

Write-Host "Kubernetes operations report sync evidence: $resolvedEvidencePath"
Write-Host "Result: $result"
if ($result -eq "planned") {
    Write-Host "Server dry-run command: $serverDryRunCommand"
    Write-Host "Apply command: $applyCommand"
    Write-Host "Publish evidence command: $publishEvidenceApplyCommand"
}

$report | ConvertTo-Json -Depth 12

if ($failureCount -gt 0) {
    exit 1
}