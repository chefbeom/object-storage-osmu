param(
    [string] $OutputRoot = ".\.osmu-run\durable-mvp-finalize-plan-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")

function Resolve-ProjectPath([string] $PathValue) {
    $path = Convert-OsmuPathSeparators $PathValue
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
}

function Read-Json([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    Assert-True (Test-Path -LiteralPath $resolved) "Expected JSON report missing: $resolved"
    return (Read-Utf8Text $resolved | ConvertFrom-Json)
}

function Get-FileHashOrEmpty([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        return ""
    }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $resolved).Hash
}

function Invoke-FinalizePlan([string[]] $Arguments) {
    $scriptPath = Join-Path $PSScriptRoot "finalize-durable-mvp-demo.ps1"
    $exitCode = Invoke-OsmuPowerShellScript $scriptPath $Arguments
    if ($exitCode -ne 0) {
        throw "finalize-durable-mvp-demo.ps1 failed with exit code $exitCode."
    }
}

$resolvedOutputRoot = Resolve-ProjectPath $OutputRoot
New-Item -ItemType Directory -Force -Path $resolvedOutputRoot | Out-Null

$latestReadyJson = ".\.osmu-run\latest-durable-mvp-finalize.json"
$latestReadyMd = ".\.osmu-run\latest-durable-mvp-finalize.md"
$beforeLatestReadyJsonHash = Get-FileHashOrEmpty $latestReadyJson
$beforeLatestReadyMdHash = Get-FileHashOrEmpty $latestReadyMd

Invoke-FinalizePlan @("-PlanOnly", "-S3Client", "docker-mc")

$afterLatestReadyJsonHash = Get-FileHashOrEmpty $latestReadyJson
$afterLatestReadyMdHash = Get-FileHashOrEmpty $latestReadyMd
Assert-True ($beforeLatestReadyJsonHash -eq $afterLatestReadyJsonHash) "Default PlanOnly changed latest durable finalizer JSON evidence."
Assert-True ($beforeLatestReadyMdHash -eq $afterLatestReadyMdHash) "Default PlanOnly changed latest durable finalizer markdown evidence."

$defaultPlan = Read-Json ".\.osmu-run\latest-durable-mvp-finalize-plan.json"
Assert-True ($defaultPlan.result -eq "planned") "Default PlanOnly report result should be planned."
Assert-True ($defaultPlan.currentDemoStatus -eq "durable-mvp-finalize-plan") "Default PlanOnly report should use durable-mvp-finalize-plan status."
Assert-True ($defaultPlan.planOnlyUsesDefaultReportPath -eq $true) "Default PlanOnly report should record default report path usage."
Assert-True ($defaultPlan.planOnlyUsesDefaultSummaryPath -eq $true) "Default PlanOnly report should record default summary path usage."
Assert-True ($defaultPlan.latestReadyFinalizerEvidencePreservedByDefault -eq $true) "Default PlanOnly report should record ready evidence preservation."

$explicitJson = Join-Path $resolvedOutputRoot "explicit-plan.json"
$explicitMd = Join-Path $resolvedOutputRoot "explicit-plan.md"
Invoke-FinalizePlan @(
    "-PlanOnly",
    "-S3Client", "docker-mc",
    "-ReportPath", $explicitJson,
    "-SummaryPath", $explicitMd
)

$explicitPlan = Read-Utf8Text $explicitJson | ConvertFrom-Json
Assert-True ($explicitPlan.result -eq "planned") "Explicit PlanOnly report result should be planned."
Assert-True ($explicitPlan.currentDemoStatus -eq "durable-mvp-finalize-plan") "Explicit PlanOnly report should use durable-mvp-finalize-plan status."
Assert-True ($explicitPlan.planOnlyUsesDefaultReportPath -eq $false) "Explicit PlanOnly report should not record default report path usage."
Assert-True ($explicitPlan.planOnlyUsesDefaultSummaryPath -eq $false) "Explicit PlanOnly report should not record default summary path usage."
Assert-True ($explicitPlan.latestReadyFinalizerEvidencePreservedByDefault -eq $false) "Explicit PlanOnly report should not claim default ready evidence preservation."
Assert-True (Test-Path -LiteralPath $explicitMd) "Explicit PlanOnly markdown report missing: $explicitMd"

Write-Host "Durable MVP finalize PlanOnly verifier passed."
