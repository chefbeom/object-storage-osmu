param(
    [string] $OutputDirectory = ".\.osmu-run\kubernetes-operations-report-sync-live-self-test"
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

$scriptPath = Resolve-ProjectPath ".\scripts\verify-kubernetes-operations-report-sync-live.ps1"
$syncEvidencePath = Join-Path $resolvedOutputDirectory "latest-kubernetes-operations-report-sync.json"
$dashboardFixturePath = Join-Path $resolvedOutputDirectory "dashboard-readiness.json"
$evidencePath = Join-Path $resolvedOutputDirectory "live-evidence.json"
$planEvidencePath = Join-Path $resolvedOutputDirectory "plan-evidence.json"
$failedDashboardFixturePath = Join-Path $resolvedOutputDirectory "dashboard-readiness-failed.json"
$failedEvidencePath = Join-Path $resolvedOutputDirectory "live-evidence-failed.json"

Write-JsonFixture $syncEvidencePath ([ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    generatedAt = "2026-06-16T00:00:00+09:00"
    result = "applied"
    namespace = "osmu"
    configMapName = "osmu-operations-reports"
    configMapKey = "latest-operations-readiness-convergence.json"
    sourceReportPath = ".osmu-run/latest-operations-readiness-convergence.json"
    sourceReportResult = "ready"
    failedCount = 0
    checkCount = 3
    checks = @(
        [ordered]@{
            name = "apply-configmap"
            passed = $true
            summary = "fixture"
            command = "kubectl apply -f manifest.yaml"
            exitCode = 0
        }
    )
})

Write-JsonFixture $dashboardFixturePath ([ordered]@{
    data = [ordered]@{
        operationsReadinessConvergence = [ordered]@{
            result = "ready"
            kubernetesReportSyncReady = $true
            kubernetesReportSyncResult = "applied"
            kubernetesReportSyncFailedCount = 0
            kubernetesReportSyncConfigMapName = "osmu-operations-reports"
            kubernetesReportSyncConfigMapKey = "latest-operations-readiness-convergence.json"
        }
        kubernetesOperationsReportSync = [ordered]@{
            result = "applied"
            namespace = "osmu"
            configMapName = "osmu-operations-reports"
            configMapKey = "latest-operations-readiness-convergence.json"
            sourceReportResult = "ready"
            failedCount = 0
            checkCount = 3
            checks = @()
        }
    }
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -SkipSync `
    -SyncEvidencePath $syncEvidencePath `
    -DashboardReadinessFixturePath $dashboardFixturePath `
    -DashboardRetryCount 3 `
    -DashboardRetryDelaySeconds 0 `
    -EvidencePath $evidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "verify-kubernetes-operations-report-sync-live.ps1 fixture pass check failed with exit code $LASTEXITCODE."
}

$evidence = Get-Content -Raw -LiteralPath $evidencePath | ConvertFrom-Json
Assert-Equal $evidence.formatVersion "osmu.kubernetes-operations-report-sync-live.v1" "live evidence formatVersion"
Assert-Equal $evidence.result "passed" "live evidence result"
Assert-Equal $evidence.syncResult "applied" "live evidence sync result"
Assert-Equal $evidence.dashboardChecked $true "live evidence dashboard checked"
Assert-Equal $evidence.dashboardRetryCount 3 "live evidence dashboard retry count"
Assert-Equal $evidence.dashboardRetryDelaySeconds 0 "live evidence dashboard retry delay"
Assert-Equal $evidence.dashboardAttemptCount 1 "live evidence dashboard attempt count"
Assert-Equal $evidence.dashboardMatchedExpected $true "live evidence dashboard matched expected"
Assert-Equal $evidence.dashboardSyncReady $true "live evidence dashboard sync ready"
Assert-Equal $evidence.dashboardSyncResult "applied" "live evidence dashboard sync result"
Assert-Equal $evidence.failedCount 0 "live evidence failed count"
Assert-True ($evidence.safetyPolicy.Contains("does not store admin passwords")) "live evidence safety policy"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanOnly `
    -DashboardReadinessFixturePath $dashboardFixturePath `
    -DashboardRetryCount 2 `
    -DashboardRetryDelaySeconds 0 `
    -EvidencePath $planEvidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "verify-kubernetes-operations-report-sync-live.ps1 plan check failed with exit code $LASTEXITCODE."
}
$planEvidence = Get-Content -Raw -LiteralPath $planEvidencePath | ConvertFrom-Json
Assert-Equal $planEvidence.result "planned" "plan evidence result"
Assert-Equal $planEvidence.failedCount 0 "plan evidence failed count"
Assert-Equal $planEvidence.dashboardRetryCount 2 "plan evidence dashboard retry count"

Write-JsonFixture $failedDashboardFixturePath ([ordered]@{
    data = [ordered]@{
        operationsReadinessConvergence = [ordered]@{
            result = "action-required"
            kubernetesReportSyncReady = $false
            kubernetesReportSyncResult = "planned"
        }
        kubernetesOperationsReportSync = [ordered]@{
            result = "planned"
            namespace = "osmu"
            configMapName = "osmu-operations-reports"
            configMapKey = "latest-operations-readiness-convergence.json"
            failedCount = 0
        }
    }
})

$failedOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -SkipSync `
    -SyncEvidencePath $syncEvidencePath `
    -DashboardReadinessFixturePath $failedDashboardFixturePath `
    -DashboardRetryCount 2 `
    -DashboardRetryDelaySeconds 0 `
    -EvidencePath $failedEvidencePath 2>&1
$failedExitCode = $LASTEXITCODE
$failedOutput = ($failedOutputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
if ($failedExitCode -eq 0) {
    throw "verify-kubernetes-operations-report-sync-live.ps1 must fail when dashboard sync evidence is not applied."
}
Assert-Contains $failedOutput "Result: failed" "failed dashboard output"
$failedEvidence = Get-Content -Raw -LiteralPath $failedEvidencePath | ConvertFrom-Json
Assert-Equal $failedEvidence.result "failed" "failed evidence result"
Assert-True ($failedEvidence.failedCount -gt 0) "failed evidence failed count"
Assert-Equal $failedEvidence.dashboardMatchedExpected $false "failed evidence dashboard matched expected"

Write-Host "Kubernetes operations report sync live verifier self-test passed."
Write-Host "Live evidence: $evidencePath"
