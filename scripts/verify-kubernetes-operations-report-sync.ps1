param(
    [string] $OutputDirectory = ".\.osmu-run\kubernetes-operations-report-sync-self-test"
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

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$scriptPath = Resolve-ProjectPath ".\scripts\sync-kubernetes-operations-reports.ps1"
$fixturePath = Join-Path $resolvedOutputDirectory "latest-operations-readiness-convergence.json"
$dataFlowStoragePlanPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-plan.json"
$planEvidencePath = Join-Path $resolvedOutputDirectory "plan.json"
$serverDryRunEvidencePath = Join-Path $resolvedOutputDirectory "server-dry-run.json"
$applyEvidencePath = Join-Path $resolvedOutputDirectory "apply.json"
$fakeKubectlPath = Join-Path $resolvedOutputDirectory "fake-kubectl.ps1"

Write-JsonFixture $fixturePath ([ordered]@{
    formatVersion = "osmu.operations-readiness-convergence.v1"
    generatedAt = "2026-06-16T00:00:00+09:00"
    result = "action-required"
    currentBottleneck = [ordered]@{
        code = "collect-run-ids"
        title = "Collect workflow run ids"
        reason = "Fixture bottleneck."
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1"
    }
    recommendedCommands = @(
        [ordered]@{
            order = 1
            name = "Collect run ids"
            command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1"
            reason = "Fixture command."
        }
    )
    safetyPolicy = "fixture"
})

Write-JsonFixture $dataFlowStoragePlanPath ([ordered]@{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    recordedAt = "2026-06-16T00:05:00+09:00"
    environmentName = "sync-self-test"
    targetCluster = "sync-self-test"
    operator = "sync-self-test"
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

$conflictExitCode = 0
$conflictOutput = ""
try {
    $conflictOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -PlanOnly `
        -Apply `
        -KubectlPath $fakeKubectlPath `
        -ReportPath $fixturePath `
        -EvidencePath (Join-Path $resolvedOutputDirectory "conflict.json") 2>&1
    $conflictExitCode = $LASTEXITCODE
}
catch {
    $conflictExitCode = 1
    $conflictOutput = $_.Exception.Message
}
if ($conflictExitCode -eq 0) {
    throw "sync-kubernetes-operations-reports.ps1 must reject conflicting modes."
}
Assert-Contains (($conflictOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine) "Use only one mode" "conflicting mode guard"

@'
if ($args -contains "apply") {
    Write-Output "configmap/osmu-operations-reports configured"
    exit 0
}

if (($args -contains "create") -and ($args -contains "configmap")) {
    Write-Output "apiVersion: v1"
    Write-Output "kind: ConfigMap"
    Write-Output "metadata:"
    Write-Output "  name: osmu-operations-reports"
    Write-Output "data:"
    Write-Output "  latest-operations-readiness-convergence.json: '{}'"
    exit 0
}

Write-Error "Unexpected fake kubectl args: $($args -join ' ')"
exit 1
'@ | Set-Content -LiteralPath $fakeKubectlPath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanOnly `
    -ReportPath $fixturePath `
    -DataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -EvidencePath $planEvidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "sync-kubernetes-operations-reports.ps1 plan check failed with exit code $LASTEXITCODE."
}

$plan = Get-Content -Raw -LiteralPath $planEvidencePath | ConvertFrom-Json
Assert-Equal $plan.formatVersion "osmu.kubernetes-operations-report-sync.v1" "plan formatVersion"
Assert-Equal $plan.result "planned" "plan result"
Assert-Equal $plan.sourceReportFormatVersion "osmu.operations-readiness-convergence.v1" "plan source format"
Assert-Equal $plan.evidenceConfigMapKey "latest-kubernetes-operations-report-sync.json" "plan evidence ConfigMap key"
Assert-Equal $plan.dataFlowStoragePlanConfigMapKey "latest-data-flow-storage-plan.json" "plan data-flow storage plan ConfigMap key"
Assert-Equal $plan.publishEvidenceToConfigMap $true "plan publish evidence flag"
Assert-Equal $plan.publishDataFlowStoragePlanToConfigMap $true "plan data-flow storage plan publish flag"
Assert-Equal $plan.dataFlowStoragePlanFormatVersion "osmu.data-flow-storage-plan.v1" "plan data-flow storage plan format"
Assert-Equal $plan.dataFlowStoragePlanResult "plan-ready-execute-required" "plan data-flow storage plan result"
Assert-Equal $plan.failedCount 0 "plan failed count"
Assert-Contains $plan.serverDryRunCommand "--dry-run=server" "plan server dry-run command"
Assert-Contains $plan.serverDryRunCommand "latest-data-flow-storage-plan.json" "plan server dry-run data-flow plan command"
Assert-Contains $plan.applyCommand "kubectl apply -f -" "plan apply command"
Assert-Contains $plan.publishEvidenceApplyCommand "latest-kubernetes-operations-report-sync.json" "plan publish evidence command"
Assert-Contains $plan.publishEvidenceApplyCommand "latest-data-flow-storage-plan.json" "plan publish evidence data-flow plan command"
Assert-True ($plan.sourceReportBytes -gt 0) "plan source report byte count"
Assert-True (-not [string]::IsNullOrWhiteSpace($plan.sourceReportSha256)) "plan source report hash"
Assert-True ($plan.dataFlowStoragePlanBytes -gt 0) "plan data-flow storage plan byte count"
Assert-True (-not [string]::IsNullOrWhiteSpace($plan.dataFlowStoragePlanSha256)) "plan data-flow storage plan hash"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ServerDryRunOnly `
    -KubectlPath $fakeKubectlPath `
    -ReportPath $fixturePath `
    -DataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -EvidencePath $serverDryRunEvidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "sync-kubernetes-operations-reports.ps1 server dry-run check failed with exit code $LASTEXITCODE."
}

$serverDryRun = Get-Content -Raw -LiteralPath $serverDryRunEvidencePath | ConvertFrom-Json
Assert-Equal $serverDryRun.result "server-dry-run-passed" "server dry-run result"
Assert-Equal $serverDryRun.failedCount 0 "server dry-run failed count"
Assert-Contains $serverDryRun.serverDryRunOutput "kind: ConfigMap" "server dry-run output"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -Apply `
    -KubectlPath $fakeKubectlPath `
    -ReportPath $fixturePath `
    -DataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -EvidencePath $applyEvidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "sync-kubernetes-operations-reports.ps1 apply check failed with exit code $LASTEXITCODE."
}

$apply = Get-Content -Raw -LiteralPath $applyEvidencePath | ConvertFrom-Json
Assert-Equal $apply.result "applied" "apply result"
Assert-Equal $apply.failedCount 0 "apply failed count"
Assert-Contains $apply.applyOutput "configured" "apply output"
Assert-Contains $apply.publishEvidenceApplyOutput "configured" "publish evidence apply output"
Assert-Contains ($apply.checks | ConvertTo-Json -Depth 10) "render-configmap-with-sync-evidence" "apply evidence render check"
Assert-Contains ($apply.checks | ConvertTo-Json -Depth 10) "apply-configmap-with-sync-evidence" "apply evidence publish check"

Write-Host "Kubernetes operations report sync verified."
Write-Host "Plan evidence: $planEvidencePath"
Write-Host "Server dry-run evidence: $serverDryRunEvidencePath"
Write-Host "Apply evidence: $applyEvidencePath"
