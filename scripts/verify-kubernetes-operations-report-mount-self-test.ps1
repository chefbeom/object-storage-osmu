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
    checkCount = 1
    passedCount = 0
    pendingCount = 1
    checks = @(
        [ordered]@{
            id = "explain_or_store_evidence"
            title = "Query plan or target-store evidence exists"
            status = "pending"
            detail = "Fixture pending check."
            nextAction = "Attach target evidence."
        }
    )
    scopePolicy = "OSMU operations analytics only."
})

$fakeKubectlTemplate = @'
$reportPath = '__REPORT_PATH__'
$syncPath = '__SYNC_PATH__'
$dataFlowStoragePlanPath = '__DATA_FLOW_STORAGE_PLAN_PATH__'

function Escape-JsonString([string] $Value) {
    return ($Value | ConvertTo-Json -Compress)
}

if (($args -contains 'get') -and ($args -contains 'configmap')) {
    $reportText = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath
    $syncText = Get-Content -Raw -Encoding UTF8 -LiteralPath $syncPath
    $dataFlowStoragePlanText = Get-Content -Raw -Encoding UTF8 -LiteralPath $dataFlowStoragePlanPath
    Write-Output -NoEnumerate (
        '{' +
        '"apiVersion":"v1",' +
        '"kind":"ConfigMap",' +
        '"metadata":{"name":"osmu-operations-reports","namespace":"osmu"},' +
        '"data":{' +
        '"latest-operations-readiness-convergence.json":' + (Escape-JsonString $reportText) + ',' +
        '"latest-kubernetes-operations-report-sync.json":' + (Escape-JsonString $syncText) + ',' +
        '"latest-data-flow-storage-plan.json":' + (Escape-JsonString $dataFlowStoragePlanText) +
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
        Write-Output -NoEnumerate (Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath)
        exit 0
    }
    if ($path.EndsWith('latest-kubernetes-operations-report-sync.json')) {
        Write-Output -NoEnumerate (Get-Content -Raw -Encoding UTF8 -LiteralPath $syncPath)
        exit 0
    }
    if ($path.EndsWith('latest-data-flow-storage-plan.json')) {
        Write-Output -NoEnumerate (Get-Content -Raw -Encoding UTF8 -LiteralPath $dataFlowStoragePlanPath)
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
    Replace("__DATA_FLOW_STORAGE_PLAN_PATH__", (Escape-SingleQuotedPowerShellString $dataFlowStoragePlanPath))
$fakeKubectlScript | Set-Content -LiteralPath $fakeKubectlPath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanOnly `
    -KubectlPath $fakeKubectlPath `
    -LocalReportPath $reportPath `
    -LocalSyncEvidencePath $syncEvidencePath `
    -LocalDataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -EvidencePath $planEvidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "verify-kubernetes-operations-report-mount.ps1 plan check failed with exit code $LASTEXITCODE."
}

$plan = Get-Content -Raw -LiteralPath $planEvidencePath | ConvertFrom-Json
Assert-Equal $plan.formatVersion "osmu.kubernetes-operations-report-mount.v1" "plan formatVersion"
Assert-Equal $plan.result "planned" "plan result"
Assert-Equal $plan.podMountChecked $false "plan pod mount checked"
Assert-Equal $plan.dataFlowStoragePlanChecked $true "plan data-flow storage plan checked"
Assert-Equal $plan.failedCount 0 "plan failed count"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -KubectlPath $fakeKubectlPath `
    -LocalReportPath $reportPath `
    -LocalSyncEvidencePath $syncEvidencePath `
    -LocalDataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -EvidencePath $evidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "verify-kubernetes-operations-report-mount.ps1 mounted check failed with exit code $LASTEXITCODE."
}

$evidence = Get-Content -Raw -LiteralPath $evidencePath | ConvertFrom-Json
$checksText = $evidence.checks | ConvertTo-Json -Depth 12
Assert-Equal $evidence.result "passed" "mount evidence result"
Assert-Equal $evidence.backendPodName "osmu-backend-fixture-0" "mount evidence backend pod"
Assert-Equal $evidence.podMountChecked $true "mount evidence pod mount checked"
Assert-Equal $evidence.dataFlowStoragePlanChecked $true "mount evidence data-flow storage plan checked"
Assert-Equal $evidence.failedCount 0 "mount evidence failed count"
Assert-True (-not [string]::IsNullOrWhiteSpace($evidence.configMapReportSha256)) "configmap report hash"
Assert-Equal $evidence.configMapReportSha256 $evidence.mountedReportSha256 "mounted report hash match"
Assert-Equal $evidence.configMapSyncEvidenceSha256 $evidence.mountedSyncEvidenceSha256 "mounted sync evidence hash match"
Assert-Equal $evidence.configMapDataFlowStoragePlanSha256 $evidence.mountedDataFlowStoragePlanSha256 "mounted data-flow storage plan hash match"
Assert-Contains $checksText "configmap-sync-evidence-key-present" "configmap sync evidence key check"
Assert-Contains $checksText "mounted-sync-evidence-readable" "mounted sync evidence readable check"
Assert-Contains $checksText "mounted-sync-evidence-matches-configmap" "mounted sync evidence match check"
Assert-Contains $checksText "configmap-data-flow-storage-plan-key-present" "configmap data-flow storage plan key check"
Assert-Contains $checksText "mounted-data-flow-storage-plan-readable" "mounted data-flow storage plan readable check"
Assert-Contains $checksText "mounted-data-flow-storage-plan-matches-configmap" "mounted data-flow storage plan match check"
Assert-True ($evidence.safetyPolicy.Contains("read-only")) "mount evidence safety policy"

Write-Host "Kubernetes operations report mount verifier self-test passed."
Write-Host "Mount evidence: $evidencePath"
