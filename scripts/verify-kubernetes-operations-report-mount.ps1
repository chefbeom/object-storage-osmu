param(
    [string] $Namespace = "osmu",
    [string] $KubectlPath = "kubectl",
    [string] $ConfigMapName = "osmu-operations-reports",
    [string] $ReportKey = "latest-operations-readiness-convergence.json",
    [string] $SyncEvidenceKey = "latest-kubernetes-operations-report-sync.json",
    [string] $DataFlowStoragePlanKey = "latest-data-flow-storage-plan.json",
    [string] $DataFlowStorageTransitionRunbookKey = "latest-data-flow-storage-transition-runbook-evidence.json",
    [string] $DataFlowQueryRetentionBudgetKey = "latest-data-flow-query-retention-budget-evidence.json",
    [string] $LocalReportPath = ".\.osmu-run\latest-operations-readiness-convergence.json",
    [string] $LocalSyncEvidencePath = ".\.osmu-run\latest-kubernetes-operations-report-sync.json",
    [string] $LocalDataFlowStoragePlanPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $LocalDataFlowStorageTransitionRunbookPath = ".\.osmu-run\latest-data-flow-storage-transition-runbook-evidence.json",
    [string] $LocalDataFlowQueryRetentionBudgetPath = ".\.osmu-run\latest-data-flow-query-retention-budget-evidence.json",
    [string] $BackendSelector = "app.kubernetes.io/name=osmu-backend",
    [string] $BackendContainer = "backend",
    [string] $MountPath = "/app/.osmu-run",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-operations-report-mount.json",
    [switch] $SkipPodMountCheck,
    [switch] $SkipDataFlowStoragePlanCheck,
    [switch] $SkipDataFlowStorageTransitionRunbookCheck,
    [switch] $SkipDataFlowQueryRetentionBudgetCheck,
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
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
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
    if ($Text.Length -le 4000) {
        return $Text
    }
    return $Text.Substring(0, 4000) + "`n...truncated..."
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

function Read-KubectlJson([string] $Name, [string[]] $Arguments) {
    $result = Invoke-KubectlRaw $Name $Arguments
    if ($result.exitCode -ne 0) {
        Add-Check $Name $false "kubectl command failed." $result.command $result.exitCode $result.output
        return $null
    }
    try {
        return [pscustomobject]@{
            json = ($result.output | ConvertFrom-Json)
            command = $result.command
            output = $result.output
        }
    }
    catch {
        Add-Check $Name $false "kubectl returned invalid JSON: $($_.Exception.Message)" $result.command $result.exitCode $result.output
        return $null
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
        throw "ConfigMap key must not be empty."
    }
    if ($Value -notmatch "^[A-Za-z0-9._-]+$") {
        throw "ConfigMap key must contain only letters, numbers, dot, underscore, or dash: $Value"
    }
}

function Get-DataValue([object] $Data, [string] $Key) {
    if ($null -eq $Data) {
        return $null
    }
    $property = $Data.PSObject.Properties[$Key]
    if ($null -eq $property) {
        return $null
    }
    return [string] $property.Value
}

function Read-JsonText([string] $Text, [string] $Label) {
    try {
        return $Text | ConvertFrom-Json
    }
    catch {
        Add-Check "$Label-json-valid" $false "$Label is not valid JSON: $($_.Exception.Message)"
        return $null
    }
}

function Get-ObjectText([object] $Value) {
    if ($null -eq $Value) {
        return ""
    }
    return [string] $Value
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

function Get-ObjectBool([object] $Value) {
    if ($null -eq $Value -or "$Value" -eq "") {
        return $false
    }
    try {
        return [bool] $Value
    }
    catch {
        return $false
    }
}

function Get-TextSha256([string] $Text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
        $sha.Dispose()
    }
}

function Get-FirstReadyPod([object] $Pods) {
    foreach ($pod in @($Pods.items)) {
        $phase = Get-ObjectText $pod.status.phase
        if ($phase -ne "Running") {
            continue
        }
        $ready = $false
        foreach ($condition in @($pod.status.conditions)) {
            if ((Get-ObjectText $condition.type) -eq "Ready" -and (Get-ObjectText $condition.status) -eq "True") {
                $ready = $true
            }
        }
        if ($ready) {
            return $pod
        }
    }
    if (@($Pods.items).Count -gt 0) {
        return @($Pods.items)[0]
    }
    return $null
}

function Compare-ReportJson([object] $Actual, [object] $Expected, [string] $Label) {
    if ($null -eq $Actual) {
        return
    }
    Add-Check "$Label-format-version" ((Get-ObjectText $Actual.formatVersion) -eq "osmu.operations-readiness-convergence.v1") "$Label formatVersion=$(Get-ObjectText $Actual.formatVersion)."
    if ($null -ne $Expected) {
        Add-Check "$Label-result" ((Get-ObjectText $Actual.result) -eq (Get-ObjectText $Expected.result)) "$Label result=$(Get-ObjectText $Actual.result), expected=$(Get-ObjectText $Expected.result)."
    }
}

function Compare-SyncEvidenceJson([object] $Actual, [object] $Expected, [string] $Label) {
    if ($null -eq $Actual) {
        return
    }
    Add-Check "$Label-format-version" ((Get-ObjectText $Actual.formatVersion) -eq "osmu.kubernetes-operations-report-sync.v1") "$Label formatVersion=$(Get-ObjectText $Actual.formatVersion)."
    Add-Check "$Label-result" ((Get-ObjectText $Actual.result) -eq "applied") "$Label result=$(Get-ObjectText $Actual.result), expected=applied."
    Add-Check "$Label-failed-count" ((Get-ObjectInt $Actual.failedCount) -eq 0) "$Label failedCount=$(Get-ObjectInt $Actual.failedCount)."
    Add-Check "$Label-configmap-name" ((Get-ObjectText $Actual.configMapName) -eq $ConfigMapName) "$Label configMapName=$(Get-ObjectText $Actual.configMapName)."
    Add-Check "$Label-configmap-key" ((Get-ObjectText $Actual.configMapKey) -eq $ReportKey) "$Label configMapKey=$(Get-ObjectText $Actual.configMapKey)."
    if ($Actual.PSObject.Properties.Name -contains "evidenceConfigMapKey") {
        Add-Check "$Label-evidence-key" ((Get-ObjectText $Actual.evidenceConfigMapKey) -eq $SyncEvidenceKey) "$Label evidenceConfigMapKey=$(Get-ObjectText $Actual.evidenceConfigMapKey)."
    }
    if ($null -ne $Expected) {
        Add-Check "$Label-source-result" ((Get-ObjectText $Actual.sourceReportResult) -eq (Get-ObjectText $Expected.sourceReportResult)) "$Label sourceReportResult=$(Get-ObjectText $Actual.sourceReportResult), expected=$(Get-ObjectText $Expected.sourceReportResult)."
    }
}

function Compare-DataFlowStoragePlanJson([object] $Actual, [object] $Expected, [string] $Label) {
    if ($null -eq $Actual) {
        return
    }
    $actualCandidateStore = Get-ObjectText $Actual.candidateStore
    $actualQueryPlanEvidence = if ($Actual.PSObject.Properties.Name -contains "queryPlanEvidence") { $Actual.queryPlanEvidence } else { $null }
    Add-Check "$Label-format-version" ((Get-ObjectText $Actual.formatVersion) -eq "osmu.data-flow-storage-plan.v1") "$Label formatVersion=$(Get-ObjectText $Actual.formatVersion)."
    if (@("MARIADB_PARTITION", "DUAL_WRITE") -contains $actualCandidateStore) {
        Add-Check "$Label-query-plan-evidence-present" ($null -ne $actualQueryPlanEvidence) "$Label candidateStore=$actualCandidateStore requires queryPlanEvidence summary."
    }
    if ($null -ne $actualQueryPlanEvidence) {
        Add-Check "$Label-query-plan-expected-format-version" ((Get-ObjectText $actualQueryPlanEvidence.expectedFormatVersion) -eq "osmu.mariadb-query-plan-evidence.v1") "$Label queryPlanEvidence expectedFormatVersion=$(Get-ObjectText $actualQueryPlanEvidence.expectedFormatVersion)."
    }
    if ($null -ne $Expected) {
        $expectedQueryPlanEvidence = if ($Expected.PSObject.Properties.Name -contains "queryPlanEvidence") { $Expected.queryPlanEvidence } else { $null }
        Add-Check "$Label-result" ((Get-ObjectText $Actual.result) -eq (Get-ObjectText $Expected.result)) "$Label result=$(Get-ObjectText $Actual.result), expected=$(Get-ObjectText $Expected.result)."
        Add-Check "$Label-candidate-store" ($actualCandidateStore -eq (Get-ObjectText $Expected.candidateStore)) "$Label candidateStore=$actualCandidateStore, expected=$(Get-ObjectText $Expected.candidateStore)."
        if ($null -ne $expectedQueryPlanEvidence -and $null -ne $actualQueryPlanEvidence) {
            Add-Check "$Label-query-plan-provided" ((Get-ObjectBool $actualQueryPlanEvidence.provided) -eq (Get-ObjectBool $expectedQueryPlanEvidence.provided)) "$Label queryPlanEvidence provided=$(Get-ObjectBool $actualQueryPlanEvidence.provided), expected=$(Get-ObjectBool $expectedQueryPlanEvidence.provided)."
            Add-Check "$Label-query-plan-result" ((Get-ObjectText $actualQueryPlanEvidence.result) -eq (Get-ObjectText $expectedQueryPlanEvidence.result)) "$Label queryPlanEvidence result=$(Get-ObjectText $actualQueryPlanEvidence.result), expected=$(Get-ObjectText $expectedQueryPlanEvidence.result)."
            Add-Check "$Label-query-plan-failed-count" ((Get-ObjectInt $actualQueryPlanEvidence.failedCount) -eq (Get-ObjectInt $expectedQueryPlanEvidence.failedCount)) "$Label queryPlanEvidence failedCount=$(Get-ObjectInt $actualQueryPlanEvidence.failedCount), expected=$(Get-ObjectInt $expectedQueryPlanEvidence.failedCount)."
        }
    }
}

function Compare-DataFlowStorageTransitionRunbookJson([object] $Actual, [object] $Expected, [string] $Label) {
    if ($null -eq $Actual) {
        return
    }
    Add-Check "$Label-format-version" ((Get-ObjectText $Actual.formatVersion) -eq "osmu.data-flow-storage-transition-runbook-evidence.v1") "$Label formatVersion=$(Get-ObjectText $Actual.formatVersion)."
    Add-Check "$Label-result" ((Get-ObjectText $Actual.result) -eq "passed") "$Label result=$(Get-ObjectText $Actual.result), expected=passed."
    Add-Check "$Label-storage-plan-result" ((Get-ObjectText $Actual.dataFlowStoragePlanSnapshot.result) -eq "passed") "$Label dataFlowStoragePlanSnapshot.result=$(Get-ObjectText $Actual.dataFlowStoragePlanSnapshot.result), expected=passed."
    Add-Check "$Label-failure-count" ((Get-ObjectInt $Actual.summary.failureCount) -eq 0) "$Label failureCount=$(Get-ObjectInt $Actual.summary.failureCount)."
    foreach ($confirmationName in @("backfillRehearsed", "dualWriteOrPartitionToggleReviewed", "rollbackRehearsed", "reconciliationPassed", "dashboardCutoverReviewed", "retentionDryRunReviewed", "noObjectKeysInAggregates", "noSecretValues")) {
        $confirmationValue = if ($null -ne $Actual.confirmations -and $Actual.confirmations.PSObject.Properties.Name -contains $confirmationName) { $Actual.confirmations.PSObject.Properties[$confirmationName].Value } else { $null }
        Add-Check "$Label-$confirmationName" (($confirmationValue -is [bool]) -and [bool] $confirmationValue) "$Label confirmation $confirmationName=$confirmationValue expected boolean true."
    }
    if ($null -ne $Expected) {
        Add-Check "$Label-candidate-store" ((Get-ObjectText $Actual.dataFlowStoragePlanSnapshot.candidateStore) -eq (Get-ObjectText $Expected.dataFlowStoragePlanSnapshot.candidateStore)) "$Label candidateStore=$(Get-ObjectText $Actual.dataFlowStoragePlanSnapshot.candidateStore), expected=$(Get-ObjectText $Expected.dataFlowStoragePlanSnapshot.candidateStore)."
        Add-Check "$Label-check-count" ((Get-ObjectInt $Actual.summary.checkCount) -eq (Get-ObjectInt $Expected.summary.checkCount)) "$Label checkCount=$(Get-ObjectInt $Actual.summary.checkCount), expected=$(Get-ObjectInt $Expected.summary.checkCount)."
    }
}


function Compare-DataFlowQueryRetentionBudgetJson([object] $Actual, [object] $Expected, [string] $Label) {
    if ($null -eq $Actual) {
        return
    }
    $queryLatencyBudget = $Actual.queryLatencyBudget
    $retentionBudget = $Actual.retentionBudget
    Add-Check "$Label-format-version" ((Get-ObjectText $Actual.formatVersion) -eq "osmu.data-flow-query-retention-budget-evidence.v1") "$Label formatVersion=$(Get-ObjectText $Actual.formatVersion)."
    Add-Check "$Label-result" ((Get-ObjectText $Actual.result) -eq "passed") "$Label result=$(Get-ObjectText $Actual.result), expected=passed."
    Add-Check "$Label-storage-plan-result" ((Get-ObjectText $Actual.dataFlowStoragePlanSnapshot.result) -eq "passed") "$Label dataFlowStoragePlanSnapshot.result=$(Get-ObjectText $Actual.dataFlowStoragePlanSnapshot.result), expected=passed."
    Add-Check "$Label-query-latency-within-budget" ((Get-ObjectBool $queryLatencyBudget.withinBudget) -eq $true) "$Label queryLatencyBudget.withinBudget=$(Get-ObjectBool $queryLatencyBudget.withinBudget)."
    Add-Check "$Label-retention-within-budget" ((Get-ObjectBool $retentionBudget.withinBudget) -eq $true) "$Label retentionBudget.withinBudget=$(Get-ObjectBool $retentionBudget.withinBudget)."
    Add-Check "$Label-failure-count" ((Get-ObjectInt $Actual.summary.failureCount) -eq 0) "$Label failureCount=$(Get-ObjectInt $Actual.summary.failureCount)."
    foreach ($confirmationName in @("queryLatencyReviewed", "retentionJobsWithinBudget", "noObjectKeysInEvidence", "noRawSqlOrExplain", "noSecretValues")) {
        $confirmationValue = if ($null -ne $Actual.confirmations -and $Actual.confirmations.PSObject.Properties.Name -contains $confirmationName) { $Actual.confirmations.PSObject.Properties[$confirmationName].Value } else { $null }
        Add-Check "$Label-$confirmationName" (($confirmationValue -is [bool]) -and [bool] $confirmationValue) "$Label confirmation $confirmationName=$confirmationValue expected boolean true."
    }
    if ($null -ne $Expected) {
        Add-Check "$Label-candidate-store" ((Get-ObjectText $Actual.dataFlowStoragePlanSnapshot.candidateStore) -eq (Get-ObjectText $Expected.dataFlowStoragePlanSnapshot.candidateStore)) "$Label candidateStore=$(Get-ObjectText $Actual.dataFlowStoragePlanSnapshot.candidateStore), expected=$(Get-ObjectText $Expected.dataFlowStoragePlanSnapshot.candidateStore)."
        Add-Check "$Label-target-p95" ((Get-ObjectInt $queryLatencyBudget.targetP95QueryLatencyMs) -eq (Get-ObjectInt $Expected.queryLatencyBudget.targetP95QueryLatencyMs)) "$Label targetP95=$(Get-ObjectInt $queryLatencyBudget.targetP95QueryLatencyMs), expected=$(Get-ObjectInt $Expected.queryLatencyBudget.targetP95QueryLatencyMs)."
        Add-Check "$Label-observed-p95" ((Get-ObjectInt $queryLatencyBudget.observedP95QueryLatencyMs) -eq (Get-ObjectInt $Expected.queryLatencyBudget.observedP95QueryLatencyMs)) "$Label observedP95=$(Get-ObjectInt $queryLatencyBudget.observedP95QueryLatencyMs), expected=$(Get-ObjectInt $Expected.queryLatencyBudget.observedP95QueryLatencyMs)."
        Add-Check "$Label-retention-budget-seconds" ((Get-ObjectInt $retentionBudget.budgetSeconds) -eq (Get-ObjectInt $Expected.retentionBudget.budgetSeconds)) "$Label retention budget seconds=$(Get-ObjectInt $retentionBudget.budgetSeconds), expected=$(Get-ObjectInt $Expected.retentionBudget.budgetSeconds)."
        Add-Check "$Label-check-count" ((Get-ObjectInt $Actual.summary.checkCount) -eq (Get-ObjectInt $Expected.summary.checkCount)) "$Label checkCount=$(Get-ObjectInt $Actual.summary.checkCount), expected=$(Get-ObjectInt $Expected.summary.checkCount)."
    }
}
Assert-KubernetesName "Namespace" $Namespace
Assert-KubernetesName "ConfigMapName" $ConfigMapName
Assert-ConfigMapKey $ReportKey
Assert-ConfigMapKey $SyncEvidenceKey
Assert-ConfigMapKey $DataFlowStoragePlanKey
Assert-ConfigMapKey $DataFlowStorageTransitionRunbookKey
Assert-ConfigMapKey $DataFlowQueryRetentionBudgetKey
if ([string]::IsNullOrWhiteSpace($BackendSelector) -or $BackendSelector -notmatch "^[A-Za-z0-9_.\-/]+=[A-Za-z0-9_.\-/]+$") {
    throw "BackendSelector must be a simple label selector key=value: $BackendSelector"
}
if ([string]::IsNullOrWhiteSpace($BackendContainer)) {
    throw "BackendContainer must not be empty."
}
if ([string]::IsNullOrWhiteSpace($MountPath) -or -not $MountPath.StartsWith("/")) {
    throw "MountPath must be an absolute container path: $MountPath"
}

$resolvedLocalReportPath = Resolve-ProjectPath $LocalReportPath
$resolvedLocalSyncEvidencePath = Resolve-ProjectPath $LocalSyncEvidencePath
$resolvedLocalDataFlowStoragePlanPath = Resolve-ProjectPath $LocalDataFlowStoragePlanPath
$resolvedLocalDataFlowStorageTransitionRunbookPath = Resolve-ProjectPath $LocalDataFlowStorageTransitionRunbookPath
$resolvedLocalDataFlowQueryRetentionBudgetPath = Resolve-ProjectPath $LocalDataFlowQueryRetentionBudgetPath
$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$reportMountPath = ($MountPath.TrimEnd("/") + "/" + $ReportKey)
$syncEvidenceMountPath = ($MountPath.TrimEnd("/") + "/" + $SyncEvidenceKey)
$dataFlowStoragePlanMountPath = ($MountPath.TrimEnd("/") + "/" + $DataFlowStoragePlanKey)
$dataFlowStorageTransitionRunbookMountPath = ($MountPath.TrimEnd("/") + "/" + $DataFlowStorageTransitionRunbookKey)
$dataFlowQueryRetentionBudgetMountPath = ($MountPath.TrimEnd("/") + "/" + $DataFlowQueryRetentionBudgetKey)
$shouldCheckDataFlowStoragePlan = [bool](-not $SkipDataFlowStoragePlanCheck -and (Test-Path -LiteralPath $resolvedLocalDataFlowStoragePlanPath))
$shouldCheckDataFlowStorageTransitionRunbook = [bool](-not $SkipDataFlowStorageTransitionRunbookCheck -and (Test-Path -LiteralPath $resolvedLocalDataFlowStorageTransitionRunbookPath))
$shouldCheckDataFlowQueryRetentionBudget = [bool](-not $SkipDataFlowQueryRetentionBudgetCheck -and (Test-Path -LiteralPath $resolvedLocalDataFlowQueryRetentionBudgetPath))

$localReportJson = $null
$localSyncEvidenceJson = $null
$localDataFlowStoragePlanJson = $null
$localDataFlowStorageTransitionRunbookJson = $null
$localDataFlowQueryRetentionBudgetJson = $null
if (Test-Path -LiteralPath $resolvedLocalReportPath) {
    $localReportJson = Read-Utf8Text $resolvedLocalReportPath | ConvertFrom-Json
}
if (Test-Path -LiteralPath $resolvedLocalSyncEvidencePath) {
    $localSyncEvidenceJson = Read-Utf8Text $resolvedLocalSyncEvidencePath | ConvertFrom-Json
}
if ($shouldCheckDataFlowStoragePlan) {
    $localDataFlowStoragePlanJson = Read-Utf8Text $resolvedLocalDataFlowStoragePlanPath | ConvertFrom-Json
}
if ($shouldCheckDataFlowStorageTransitionRunbook) {
    $localDataFlowStorageTransitionRunbookJson = Read-Utf8Text $resolvedLocalDataFlowStorageTransitionRunbookPath | ConvertFrom-Json
}
if ($shouldCheckDataFlowQueryRetentionBudget) {
    $localDataFlowQueryRetentionBudgetJson = Read-Utf8Text $resolvedLocalDataFlowQueryRetentionBudgetPath | ConvertFrom-Json
}

$configMapReportText = ""
$configMapSyncText = ""
$configMapDataFlowStoragePlanText = ""
$configMapDataFlowStorageTransitionRunbookText = ""
$configMapDataFlowQueryRetentionBudgetText = ""
$backendPodName = ""
$mountedReportText = ""
$mountedSyncText = ""
$mountedDataFlowStoragePlanText = ""
$mountedDataFlowStorageTransitionRunbookText = ""
$mountedDataFlowQueryRetentionBudgetText = ""

if ($PlanOnly) {
    Add-Check "plan-only" $true "Plan-only mode does not call kubectl."
}
else {
    $configMapSource = Read-KubectlJson "get-operations-report-configmap" @("-n", $Namespace, "get", "configmap", $ConfigMapName, "-o", "json")
    if ($null -ne $configMapSource) {
        $configMapReportText = Get-DataValue $configMapSource.json.data $ReportKey
        $configMapSyncText = Get-DataValue $configMapSource.json.data $SyncEvidenceKey
        $configMapDataFlowStoragePlanText = Get-DataValue $configMapSource.json.data $DataFlowStoragePlanKey
        $configMapDataFlowStorageTransitionRunbookText = Get-DataValue $configMapSource.json.data $DataFlowStorageTransitionRunbookKey
        $configMapDataFlowQueryRetentionBudgetText = Get-DataValue $configMapSource.json.data $DataFlowQueryRetentionBudgetKey
        Add-Check "configmap-report-key-present" ($null -ne $configMapReportText) "ConfigMap report key present=$($null -ne $configMapReportText)." $configMapSource.command
        Add-Check "configmap-sync-evidence-key-present" ($null -ne $configMapSyncText) "ConfigMap sync evidence key present=$($null -ne $configMapSyncText)." $configMapSource.command
        if ($shouldCheckDataFlowStoragePlan) {
            Add-Check "configmap-data-flow-storage-plan-key-present" ($null -ne $configMapDataFlowStoragePlanText) "ConfigMap data-flow storage plan key present=$($null -ne $configMapDataFlowStoragePlanText)." $configMapSource.command
        }
        else {
            Add-Check "data-flow-storage-plan-check-optional" $true "Local data-flow storage plan evidence is absent or skipped; ConfigMap key is optional."
        }
        if ($shouldCheckDataFlowStorageTransitionRunbook) {
            Add-Check "configmap-data-flow-storage-transition-runbook-key-present" ($null -ne $configMapDataFlowStorageTransitionRunbookText) "ConfigMap data-flow storage transition runbook key present=$($null -ne $configMapDataFlowStorageTransitionRunbookText)." $configMapSource.command
        }
        else {
            Add-Check "data-flow-storage-transition-runbook-check-optional" $true "Local data-flow storage transition runbook evidence is absent or skipped; ConfigMap key is optional."
        }
        if ($shouldCheckDataFlowQueryRetentionBudget) {
            Add-Check "configmap-data-flow-query-retention-budget-key-present" ($null -ne $configMapDataFlowQueryRetentionBudgetText) "ConfigMap data-flow query/retention budget key present=$($null -ne $configMapDataFlowQueryRetentionBudgetText)." $configMapSource.command
        }
        else {
            Add-Check "data-flow-query-retention-budget-check-optional" $true "Local data-flow query/retention budget evidence is absent or skipped; ConfigMap key is optional."
        }

        if ($null -ne $configMapReportText) {
            $configMapReportJson = Read-JsonText $configMapReportText "configmap-report"
            Compare-ReportJson $configMapReportJson $localReportJson "configmap-report"
        }
        if ($null -ne $configMapSyncText) {
            $configMapSyncJson = Read-JsonText $configMapSyncText "configmap-sync-evidence"
            Compare-SyncEvidenceJson $configMapSyncJson $localSyncEvidenceJson "configmap-sync-evidence"
        }
        if ($null -ne $configMapDataFlowStoragePlanText) {
            $configMapDataFlowStoragePlanJson = Read-JsonText $configMapDataFlowStoragePlanText "configmap-data-flow-storage-plan"
            Compare-DataFlowStoragePlanJson $configMapDataFlowStoragePlanJson $localDataFlowStoragePlanJson "configmap-data-flow-storage-plan"
        }
        if ($null -ne $configMapDataFlowStorageTransitionRunbookText) {
            $configMapDataFlowStorageTransitionRunbookJson = Read-JsonText $configMapDataFlowStorageTransitionRunbookText "configmap-data-flow-storage-transition-runbook"
            Compare-DataFlowStorageTransitionRunbookJson $configMapDataFlowStorageTransitionRunbookJson $localDataFlowStorageTransitionRunbookJson "configmap-data-flow-storage-transition-runbook"
        }
        if ($null -ne $configMapDataFlowQueryRetentionBudgetText) {
            $configMapDataFlowQueryRetentionBudgetJson = Read-JsonText $configMapDataFlowQueryRetentionBudgetText "configmap-data-flow-query-retention-budget"
            Compare-DataFlowQueryRetentionBudgetJson $configMapDataFlowQueryRetentionBudgetJson $localDataFlowQueryRetentionBudgetJson "configmap-data-flow-query-retention-budget"
        }
    }

    if (-not $SkipPodMountCheck) {
        $podsSource = Read-KubectlJson "get-backend-pods" @("-n", $Namespace, "get", "pods", "-l", $BackendSelector, "-o", "json")
        $pod = if ($null -ne $podsSource) { Get-FirstReadyPod $podsSource.json } else { $null }
        if ($null -eq $pod) {
            Add-Check "backend-pod-found" $false "No backend pod found for selector $BackendSelector." $(if ($null -ne $podsSource) { $podsSource.command } else { "" })
        }
        else {
            $backendPodName = Get-ObjectText $pod.metadata.name
            Add-Check "backend-pod-found" $true "Using backend pod $backendPodName for mounted file verification." $podsSource.command

            $mountedReport = Invoke-KubectlRaw "read-mounted-report" @("-n", $Namespace, "exec", $backendPodName, "-c", $BackendContainer, "--", "cat", $reportMountPath)
            $mountedReportText = $mountedReport.output
            Add-Check "mounted-report-readable" ($mountedReport.exitCode -eq 0) "Mounted convergence report is readable from backend pod." $mountedReport.command $mountedReport.exitCode $mountedReport.output
            if ($mountedReport.exitCode -eq 0) {
                $mountedReportJson = Read-JsonText $mountedReportText "mounted-report"
                Compare-ReportJson $mountedReportJson $localReportJson "mounted-report"
                if ($configMapReportText) {
                    Add-Check "mounted-report-matches-configmap" ((Get-TextSha256 $mountedReportText) -eq (Get-TextSha256 $configMapReportText)) "Mounted convergence report content matches ConfigMap data."
                }
            }

            $mountedSync = Invoke-KubectlRaw "read-mounted-sync-evidence" @("-n", $Namespace, "exec", $backendPodName, "-c", $BackendContainer, "--", "cat", $syncEvidenceMountPath)
            $mountedSyncText = $mountedSync.output
            Add-Check "mounted-sync-evidence-readable" ($mountedSync.exitCode -eq 0) "Mounted sync evidence is readable from backend pod." $mountedSync.command $mountedSync.exitCode $mountedSync.output
            if ($mountedSync.exitCode -eq 0) {
                $mountedSyncJson = Read-JsonText $mountedSyncText "mounted-sync-evidence"
                Compare-SyncEvidenceJson $mountedSyncJson $localSyncEvidenceJson "mounted-sync-evidence"
                if ($configMapSyncText) {
                    Add-Check "mounted-sync-evidence-matches-configmap" ((Get-TextSha256 $mountedSyncText) -eq (Get-TextSha256 $configMapSyncText)) "Mounted sync evidence content matches ConfigMap data."
                }
            }

            if ($shouldCheckDataFlowStoragePlan) {
                $mountedDataFlowStoragePlan = Invoke-KubectlRaw "read-mounted-data-flow-storage-plan" @("-n", $Namespace, "exec", $backendPodName, "-c", $BackendContainer, "--", "cat", $dataFlowStoragePlanMountPath)
                $mountedDataFlowStoragePlanText = $mountedDataFlowStoragePlan.output
                Add-Check "mounted-data-flow-storage-plan-readable" ($mountedDataFlowStoragePlan.exitCode -eq 0) "Mounted data-flow storage plan is readable from backend pod." $mountedDataFlowStoragePlan.command $mountedDataFlowStoragePlan.exitCode $mountedDataFlowStoragePlan.output
                if ($mountedDataFlowStoragePlan.exitCode -eq 0) {
                    $mountedDataFlowStoragePlanJson = Read-JsonText $mountedDataFlowStoragePlanText "mounted-data-flow-storage-plan"
                    Compare-DataFlowStoragePlanJson $mountedDataFlowStoragePlanJson $localDataFlowStoragePlanJson "mounted-data-flow-storage-plan"
                    if ($configMapDataFlowStoragePlanText) {
                        Add-Check "mounted-data-flow-storage-plan-matches-configmap" ((Get-TextSha256 $mountedDataFlowStoragePlanText) -eq (Get-TextSha256 $configMapDataFlowStoragePlanText)) "Mounted data-flow storage plan content matches ConfigMap data."
                    }
                }
            }

            if ($shouldCheckDataFlowStorageTransitionRunbook) {
                $mountedDataFlowStorageTransitionRunbook = Invoke-KubectlRaw "read-mounted-data-flow-storage-transition-runbook" @("-n", $Namespace, "exec", $backendPodName, "-c", $BackendContainer, "--", "cat", $dataFlowStorageTransitionRunbookMountPath)
                $mountedDataFlowStorageTransitionRunbookText = $mountedDataFlowStorageTransitionRunbook.output
                Add-Check "mounted-data-flow-storage-transition-runbook-readable" ($mountedDataFlowStorageTransitionRunbook.exitCode -eq 0) "Mounted data-flow storage transition runbook evidence is readable from backend pod." $mountedDataFlowStorageTransitionRunbook.command $mountedDataFlowStorageTransitionRunbook.exitCode $mountedDataFlowStorageTransitionRunbook.output
                if ($mountedDataFlowStorageTransitionRunbook.exitCode -eq 0) {
                    $mountedDataFlowStorageTransitionRunbookJson = Read-JsonText $mountedDataFlowStorageTransitionRunbookText "mounted-data-flow-storage-transition-runbook"
                    Compare-DataFlowStorageTransitionRunbookJson $mountedDataFlowStorageTransitionRunbookJson $localDataFlowStorageTransitionRunbookJson "mounted-data-flow-storage-transition-runbook"
                    if ($configMapDataFlowStorageTransitionRunbookText) {
                        Add-Check "mounted-data-flow-storage-transition-runbook-matches-configmap" ((Get-TextSha256 $mountedDataFlowStorageTransitionRunbookText) -eq (Get-TextSha256 $configMapDataFlowStorageTransitionRunbookText)) "Mounted data-flow storage transition runbook content matches ConfigMap data."
                    }
                }
            }

            if ($shouldCheckDataFlowQueryRetentionBudget) {
                $mountedDataFlowQueryRetentionBudget = Invoke-KubectlRaw "read-mounted-data-flow-query-retention-budget" @("-n", $Namespace, "exec", $backendPodName, "-c", $BackendContainer, "--", "cat", $dataFlowQueryRetentionBudgetMountPath)
                $mountedDataFlowQueryRetentionBudgetText = $mountedDataFlowQueryRetentionBudget.output
                Add-Check "mounted-data-flow-query-retention-budget-readable" ($mountedDataFlowQueryRetentionBudget.exitCode -eq 0) "Mounted data-flow query/retention budget evidence is readable from backend pod." $mountedDataFlowQueryRetentionBudget.command $mountedDataFlowQueryRetentionBudget.exitCode $mountedDataFlowQueryRetentionBudget.output
                if ($mountedDataFlowQueryRetentionBudget.exitCode -eq 0) {
                    $mountedDataFlowQueryRetentionBudgetJson = Read-JsonText $mountedDataFlowQueryRetentionBudgetText "mounted-data-flow-query-retention-budget"
                    Compare-DataFlowQueryRetentionBudgetJson $mountedDataFlowQueryRetentionBudgetJson $localDataFlowQueryRetentionBudgetJson "mounted-data-flow-query-retention-budget"
                    if ($configMapDataFlowQueryRetentionBudgetText) {
                        Add-Check "mounted-data-flow-query-retention-budget-matches-configmap" ((Get-TextSha256 $mountedDataFlowQueryRetentionBudgetText) -eq (Get-TextSha256 $configMapDataFlowQueryRetentionBudgetText)) "Mounted data-flow query/retention budget content matches ConfigMap data."
                    }
                }
            }
        }
    }
    else {
        Add-Check "pod-mount-check-skipped" $true "Backend pod mounted file check skipped."
    }
}

$result = if ($failureCount -eq 0) {
    if ($PlanOnly) { "planned" } else { "passed" }
}
else {
    "failed"
}

$report = [ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-mount.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = $result
    namespace = $Namespace
    configMapName = $ConfigMapName
    reportKey = $ReportKey
    syncEvidenceKey = $SyncEvidenceKey
    dataFlowStoragePlanKey = $DataFlowStoragePlanKey
    dataFlowStorageTransitionRunbookKey = $DataFlowStorageTransitionRunbookKey
    dataFlowQueryRetentionBudgetKey = $DataFlowQueryRetentionBudgetKey
    backendSelector = $BackendSelector
    backendContainer = $BackendContainer
    backendPodName = $backendPodName
    mountPath = $MountPath
    reportMountPath = $reportMountPath
    syncEvidenceMountPath = $syncEvidenceMountPath
    dataFlowStoragePlanMountPath = $dataFlowStoragePlanMountPath
    dataFlowStorageTransitionRunbookMountPath = $dataFlowStorageTransitionRunbookMountPath
    dataFlowQueryRetentionBudgetMountPath = $dataFlowQueryRetentionBudgetMountPath
    localReportPath = $resolvedLocalReportPath
    localSyncEvidencePath = $resolvedLocalSyncEvidencePath
    localDataFlowStoragePlanPath = $resolvedLocalDataFlowStoragePlanPath
    localDataFlowStorageTransitionRunbookPath = $resolvedLocalDataFlowStorageTransitionRunbookPath
    localDataFlowQueryRetentionBudgetPath = $resolvedLocalDataFlowQueryRetentionBudgetPath
    configMapReportSha256 = if ($configMapReportText) { Get-TextSha256 $configMapReportText } else { "" }
    configMapSyncEvidenceSha256 = if ($configMapSyncText) { Get-TextSha256 $configMapSyncText } else { "" }
    configMapDataFlowStoragePlanSha256 = if ($configMapDataFlowStoragePlanText) { Get-TextSha256 $configMapDataFlowStoragePlanText } else { "" }
    configMapDataFlowStorageTransitionRunbookSha256 = if ($configMapDataFlowStorageTransitionRunbookText) { Get-TextSha256 $configMapDataFlowStorageTransitionRunbookText } else { "" }
    configMapDataFlowQueryRetentionBudgetSha256 = if ($configMapDataFlowQueryRetentionBudgetText) { Get-TextSha256 $configMapDataFlowQueryRetentionBudgetText } else { "" }
    mountedReportSha256 = if ($mountedReportText) { Get-TextSha256 $mountedReportText } else { "" }
    mountedSyncEvidenceSha256 = if ($mountedSyncText) { Get-TextSha256 $mountedSyncText } else { "" }
    mountedDataFlowStoragePlanSha256 = if ($mountedDataFlowStoragePlanText) { Get-TextSha256 $mountedDataFlowStoragePlanText } else { "" }
    mountedDataFlowStorageTransitionRunbookSha256 = if ($mountedDataFlowStorageTransitionRunbookText) { Get-TextSha256 $mountedDataFlowStorageTransitionRunbookText } else { "" }
    mountedDataFlowQueryRetentionBudgetSha256 = if ($mountedDataFlowQueryRetentionBudgetText) { Get-TextSha256 $mountedDataFlowQueryRetentionBudgetText } else { "" }
    dataFlowStoragePlanChecked = [bool]$shouldCheckDataFlowStoragePlan
    dataFlowStorageTransitionRunbookChecked = [bool]$shouldCheckDataFlowStorageTransitionRunbook
    dataFlowQueryRetentionBudgetChecked = [bool]$shouldCheckDataFlowQueryRetentionBudget
    podMountChecked = [bool](-not $SkipPodMountCheck -and -not $PlanOnly)
    checkCount = @($checks).Count
    failedCount = $failureCount
    checks = $checks
    safetyPolicy = "This verifier is read-only. It does not create, update, or delete Kubernetes resources and it does not read Kubernetes Secret values. Optional data-flow storage plan, query/retention budget, and transition runbook evidence are read only as reduced JSON summaries from ConfigMap and backend mounts."
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedEvidencePath) | Out-Null
$report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

Write-Host "Kubernetes operations report mount evidence: $resolvedEvidencePath"
Write-Host "Result: $result"
$report | ConvertTo-Json -Depth 14

if ($failureCount -gt 0) {
    exit 1
}