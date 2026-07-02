param(
    [string] $OutputDirectory = ".\.osmu-run\kubernetes-operations-report-mount-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

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

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message. Expected '$Expected' but got '$Actual'."
    }
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Message) {
    if (-not $Text.Contains($Expected)) {
        throw "$Message. Missing '$Expected'."
    }
}

function Write-JsonFixture([string] $PathValue, [object] $Value) {
    $directory = Split-Path -Parent $PathValue
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $Value | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $PathValue -Encoding UTF8
}

function Escape-SingleQuotedPowerShellString([string] $Value) {
    return $Value -replace "'", "''"
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

$scriptPath = Resolve-ProjectPath ".\scripts\verify-kubernetes-operations-report-mount.ps1"
$reportPath = Join-Path $resolvedOutputDirectory "latest-operations-readiness-convergence.json"
$syncEvidencePath = Join-Path $resolvedOutputDirectory "latest-kubernetes-operations-report-sync.json"
$dataFlowStoragePlanPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-plan.json"
$dataFlowStorageTransitionRunbookPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-transition-runbook-evidence.json"
$dataFlowQueryRetentionBudgetPath = Join-Path $resolvedOutputDirectory "latest-data-flow-query-retention-budget-evidence.json"
$fakeKubectlPath = Join-Path $resolvedOutputDirectory "fake-kubectl.ps1"
$evidencePath = Join-Path $resolvedOutputDirectory "mount-evidence.json"
$planEvidencePath = Join-Path $resolvedOutputDirectory "mount-plan.json"

Write-JsonFixture $reportPath ([ordered]@{
    formatVersion = "osmu.operations-readiness-convergence.v1"
    generatedAt = "2026-06-16T00:00:00+09:00"
    result = "ready"
    kubernetesReportSyncReady = $true
    kubernetesReportSyncResult = "applied"
    currentBottleneck = [ordered]@{
        code = "none"
        title = "Operations readiness is ready"
        reason = "fixture"
        command = ""
    }
    recommendedCommands = @()
})

Write-JsonFixture $syncEvidencePath ([ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    generatedAt = "2026-06-16T00:00:00+09:00"
    result = "applied"
    namespace = "osmu"
    configMapName = "osmu-operations-reports"
    configMapKey = "latest-operations-readiness-convergence.json"
    evidenceConfigMapKey = "latest-kubernetes-operations-report-sync.json"
    publishEvidenceToConfigMap = $true
    sourceReportPath = ".osmu-run/latest-operations-readiness-convergence.json"
    sourceReportResult = "ready"
    failedCount = 0
    checkCount = 7
})

Write-JsonFixture $dataFlowStoragePlanPath ([ordered]@{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    recordedAt = "2026-06-16T00:05:00+09:00"
    environmentName = "mount-self-test"
    targetCluster = "mount-self-test"
    operator = "mount-self-test"
    candidateStore = "MARIADB_PARTITION"
    expectedPeakEventsPerDay = 250000
    expectedQueryWindowDays = 180
    targetP95QueryLatencyMs = 500
    checkCount = 3
    passedCount = 0
    pendingCount = 3
    checks = @(
        [ordered]@{
            id = "expected_peak_volume"
            title = "Expected peak event volume captured"
            status = "pending"
            detail = "Fixture pending peak."
            nextAction = "Set target sizing evidence."
        },
        [ordered]@{
            id = "explain_or_store_evidence"
            title = "Query plan or target-store evidence exists"
            status = "pending"
            detail = "Fixture pending check."
            nextAction = "Attach target evidence."
        },
        [ordered]@{
            id = "mariadb_query_plan_evidence"
            title = "MariaDB query plan evidence passed"
            status = "pending"
            detail = "No MariaDB query plan evidence JSON supplied."
            nextAction = "Run scripts/write-mariadb-query-plan-evidence.ps1 with -Execute or -ExplainInputDir until result=passed, then rerun this storage plan."
        }
    )
    queryPlanEvidence = [ordered]@{
        provided = $false
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
    scopePolicy = "OSMU operations analytics only."
})

Write-JsonFixture $dataFlowStorageTransitionRunbookPath ([ordered]@{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    generatedAt = "2026-06-16T00:06:00+09:00"
    result = "passed"
    dataFlowStoragePlanSnapshot = [ordered]@{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
    }
    summary = [ordered]@{
        failureCount = 0
        checkCount = 8
    }
    confirmations = [ordered]@{
        backfillRehearsed = $true
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
    topFailedChecks = @()
    scopePolicy = "OSMU operations analytics transition runbook only."
})

Write-JsonFixture $dataFlowQueryRetentionBudgetPath ([ordered]@{
    formatVersion = "osmu.data-flow-query-retention-budget-evidence.v1"
    generatedAt = "2026-06-16T00:07:00+09:00"
    result = "passed"
    dataFlowStoragePlanSnapshot = [ordered]@{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        targetP95QueryLatencyMs = 500
        pendingCount = 0
    }
    queryLatencyBudget = [ordered]@{
        targetP95QueryLatencyMs = 500
        observedP95QueryLatencyMs = 420
        observedP99QueryLatencyMs = 470
        querySampleCount = 120
        observedQueryWindowDays = 180
        withinBudget = $true
    }
    retentionBudget = [ordered]@{
        budgetSeconds = 30
        detailedRetentionObservedSeconds = 20
        dailyRollupRetentionObservedSeconds = 18
        monthlyRollupRetentionObservedSeconds = 12
        withinBudget = $true
    }
    summary = [ordered]@{
        failureCount = 0
        checkCount = 8
    }
    confirmations = [ordered]@{
        queryLatencyReviewed = $true
        retentionJobsWithinBudget = $true
        noObjectKeysInEvidence = $true
        noRawSqlOrExplain = $true
        noSecretValues = $true
    }
    topFailedChecks = @()
    scopePolicy = "OSMU operations analytics query/retention budget only."
})

$fakeKubectlTemplate = @'
$reportPath = '__REPORT_PATH__'
$syncPath = '__SYNC_PATH__'
$dataFlowStoragePlanPath = '__DATA_FLOW_STORAGE_PLAN_PATH__'
$dataFlowStorageTransitionRunbookPath = '__DATA_FLOW_STORAGE_TRANSITION_RUNBOOK_PATH__'
$dataFlowQueryRetentionBudgetPath = '__DATA_FLOW_QUERY_RETENTION_BUDGET_PATH__'

function Escape-JsonString([string] $Value) {
    return ($Value | ConvertTo-Json -Compress)
}
function Read-Utf8Text([string] $PathValue) {
    return [System.IO.File]::ReadAllText((Resolve-Path $PathValue), [System.Text.UTF8Encoding]::new($false, $true))
}

if (($args -contains 'get') -and ($args -contains 'configmap')) {
    $reportText = Read-Utf8Text $reportPath
    $syncText = Read-Utf8Text $syncPath
    $dataFlowStoragePlanText = Read-Utf8Text $dataFlowStoragePlanPath
    $dataFlowStorageTransitionRunbookText = Read-Utf8Text $dataFlowStorageTransitionRunbookPath
    $dataFlowQueryRetentionBudgetText = Read-Utf8Text $dataFlowQueryRetentionBudgetPath
    Write-Output -NoEnumerate (
        '{' +
        '"apiVersion":"v1",' +
        '"kind":"ConfigMap",' +
        '"metadata":{"name":"osmu-operations-reports","namespace":"osmu"},' +
        '"data":{' +
        '"latest-operations-readiness-convergence.json":' + (Escape-JsonString $reportText) + ',' +
        '"latest-kubernetes-operations-report-sync.json":' + (Escape-JsonString $syncText) + ',' +
        '"latest-data-flow-storage-plan.json":' + (Escape-JsonString $dataFlowStoragePlanText) + ',' +
        '"latest-data-flow-storage-transition-runbook-evidence.json":' + (Escape-JsonString $dataFlowStorageTransitionRunbookText) + ',' +
        '"latest-data-flow-query-retention-budget-evidence.json":' + (Escape-JsonString $dataFlowQueryRetentionBudgetText) +
        '}' +
        '}'
    )
    exit 0
}

if (($args -contains 'get') -and ($args -contains 'pods')) {
    [ordered]@{
        apiVersion = 'v1'
        items = @(
            [ordered]@{
                metadata = [ordered]@{
                    name = 'osmu-backend-fixture-0'
                }
                status = [ordered]@{
                    phase = 'Running'
                    conditions = @(
                        [ordered]@{
                            type = 'Ready'
                            status = 'True'
                        }
                    )
                }
            }
        )
    } | ConvertTo-Json -Depth 12
    exit 0
}

if ($args -contains 'exec') {
    $path = [string] $args[-1]
    if ($path.EndsWith('latest-operations-readiness-convergence.json')) {
        Write-Output -NoEnumerate (Read-Utf8Text $reportPath)
        exit 0
    }
    if ($path.EndsWith('latest-kubernetes-operations-report-sync.json')) {
        Write-Output -NoEnumerate (Read-Utf8Text $syncPath)
        exit 0
    }
    if ($path.EndsWith('latest-data-flow-storage-plan.json')) {
        Write-Output -NoEnumerate (Read-Utf8Text $dataFlowStoragePlanPath)
        exit 0
    }
    if ($path.EndsWith('latest-data-flow-storage-transition-runbook-evidence.json')) {
        Write-Output -NoEnumerate (Read-Utf8Text $dataFlowStorageTransitionRunbookPath)
        exit 0
    }
    if ($path.EndsWith('latest-data-flow-query-retention-budget-evidence.json')) {
        Write-Output -NoEnumerate (Read-Utf8Text $dataFlowQueryRetentionBudgetPath)
        exit 0
    }
    Write-Error "Unexpected mounted path: $path"
    exit 1
}

Write-Error "Unexpected fake kubectl args: $($args -join ' ')"
exit 1
'@

$fakeKubectlScript = $fakeKubectlTemplate.
    Replace("__REPORT_PATH__", (Escape-SingleQuotedPowerShellString $reportPath)).
    Replace("__SYNC_PATH__", (Escape-SingleQuotedPowerShellString $syncEvidencePath)).
    Replace("__DATA_FLOW_STORAGE_PLAN_PATH__", (Escape-SingleQuotedPowerShellString $dataFlowStoragePlanPath)).
    Replace("__DATA_FLOW_STORAGE_TRANSITION_RUNBOOK_PATH__", (Escape-SingleQuotedPowerShellString $dataFlowStorageTransitionRunbookPath)).
    Replace("__DATA_FLOW_QUERY_RETENTION_BUDGET_PATH__", (Escape-SingleQuotedPowerShellString $dataFlowQueryRetentionBudgetPath))
$fakeKubectlScript | Set-Content -LiteralPath $fakeKubectlPath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanOnly `
    -KubectlPath $fakeKubectlPath `
    -LocalReportPath $reportPath `
    -LocalSyncEvidencePath $syncEvidencePath `
    -LocalDataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -LocalDataFlowStorageTransitionRunbookPath $dataFlowStorageTransitionRunbookPath `
    -LocalDataFlowQueryRetentionBudgetPath $dataFlowQueryRetentionBudgetPath `
    -EvidencePath $planEvidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "verify-kubernetes-operations-report-mount.ps1 plan check failed with exit code $LASTEXITCODE."
}

$plan = Read-Utf8Text $planEvidencePath | ConvertFrom-Json
Assert-Equal $plan.formatVersion "osmu.kubernetes-operations-report-mount.v1" "plan formatVersion"
Assert-Equal $plan.result "planned" "plan result"
Assert-Equal $plan.podMountChecked $false "plan pod mount checked"
Assert-Equal $plan.dataFlowStoragePlanChecked $true "plan data-flow storage plan checked"
Assert-Equal $plan.dataFlowStorageTransitionRunbookChecked $true "plan data-flow storage transition runbook checked"
Assert-Equal $plan.dataFlowQueryRetentionBudgetChecked $true "plan data-flow query retention budget checked"
Assert-Equal $plan.failedCount 0 "plan failed count"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -KubectlPath $fakeKubectlPath `
    -LocalReportPath $reportPath `
    -LocalSyncEvidencePath $syncEvidencePath `
    -LocalDataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -LocalDataFlowStorageTransitionRunbookPath $dataFlowStorageTransitionRunbookPath `
    -LocalDataFlowQueryRetentionBudgetPath $dataFlowQueryRetentionBudgetPath `
    -EvidencePath $evidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "verify-kubernetes-operations-report-mount.ps1 mounted check failed with exit code $LASTEXITCODE."
}

$evidence = Read-Utf8Text $evidencePath | ConvertFrom-Json
$checksText = $evidence.checks | ConvertTo-Json -Depth 12
Assert-Equal $evidence.result "passed" "mount evidence result"
Assert-Equal $evidence.backendPodName "osmu-backend-fixture-0" "mount evidence backend pod"
Assert-Equal $evidence.podMountChecked $true "mount evidence pod mount checked"
Assert-Equal $evidence.dataFlowStoragePlanChecked $true "mount evidence data-flow storage plan checked"
Assert-Equal $evidence.dataFlowStorageTransitionRunbookChecked $true "mount evidence data-flow storage transition runbook checked"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetChecked $true "mount evidence data-flow query retention budget checked"
Assert-Equal $evidence.failedCount 0 "mount evidence failed count"
Assert-True (-not [string]::IsNullOrWhiteSpace($evidence.configMapReportSha256)) "configmap report hash"
Assert-Equal $evidence.configMapReportSha256 $evidence.mountedReportSha256 "mounted report hash match"
Assert-Equal $evidence.configMapSyncEvidenceSha256 $evidence.mountedSyncEvidenceSha256 "mounted sync evidence hash match"
Assert-Equal $evidence.configMapDataFlowStoragePlanSha256 $evidence.mountedDataFlowStoragePlanSha256 "mounted data-flow storage plan hash match"
Assert-Equal $evidence.configMapDataFlowStorageTransitionRunbookSha256 $evidence.mountedDataFlowStorageTransitionRunbookSha256 "mounted data-flow storage transition runbook hash match"
Assert-Equal $evidence.configMapDataFlowQueryRetentionBudgetSha256 $evidence.mountedDataFlowQueryRetentionBudgetSha256 "mounted data-flow query retention budget hash match"
Assert-Contains $checksText "configmap-sync-evidence-key-present" "configmap sync evidence key check"
Assert-Contains $checksText "mounted-sync-evidence-readable" "mounted sync evidence readable check"
Assert-Contains $checksText "mounted-sync-evidence-matches-configmap" "mounted sync evidence match check"
Assert-Contains $checksText "configmap-data-flow-storage-plan-key-present" "configmap data-flow storage plan key check"
Assert-Contains $checksText "configmap-data-flow-storage-plan-query-plan-evidence-present" "configmap data-flow query plan summary present check"
Assert-Contains $checksText "configmap-data-flow-storage-plan-query-plan-expected-format-version" "configmap data-flow query plan format check"
Assert-Contains $checksText "mounted-data-flow-storage-plan-readable" "mounted data-flow storage plan readable check"
Assert-Contains $checksText "mounted-data-flow-storage-plan-query-plan-evidence-present" "mounted data-flow query plan summary present check"
Assert-Contains $checksText "mounted-data-flow-storage-plan-query-plan-failed-count" "mounted data-flow query plan failed count check"
Assert-Contains $checksText "mounted-data-flow-storage-plan-matches-configmap" "mounted data-flow storage plan match check"
Assert-Contains $checksText "configmap-data-flow-storage-transition-runbook-key-present" "configmap data-flow runbook key check"
Assert-Contains $checksText "configmap-data-flow-storage-transition-runbook-result" "configmap data-flow runbook result check"
Assert-Contains $checksText "configmap-data-flow-query-retention-budget-key-present" "configmap data-flow query retention budget key check"
Assert-Contains $checksText "configmap-data-flow-query-retention-budget-result" "configmap data-flow query retention budget result check"
Assert-Contains $checksText "mounted-data-flow-storage-transition-runbook-readable" "mounted data-flow runbook readable check"
Assert-Contains $checksText "mounted-data-flow-storage-transition-runbook-noSecretValues" "mounted data-flow runbook no-secret check"
Assert-Contains $checksText "mounted-data-flow-storage-transition-runbook-matches-configmap" "mounted data-flow runbook match check"
Assert-Contains $checksText "mounted-data-flow-query-retention-budget-readable" "mounted data-flow query retention budget readable check"
Assert-Contains $checksText "mounted-data-flow-query-retention-budget-noSecretValues" "mounted data-flow query retention budget no-secret check"
Assert-Contains $checksText "mounted-data-flow-query-retention-budget-matches-configmap" "mounted data-flow query retention budget match check"
Assert-True ($evidence.safetyPolicy.Contains("read-only")) "mount evidence safety policy"

Write-Host "Kubernetes operations report mount verifier self-test passed."
Write-Host "Mount evidence: $evidencePath"