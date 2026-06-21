param(
    [string] $JsonOutputPath = ".\.osmu-run\operations-readiness-finalizer-self-test\latest-operations-readiness-finalize.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\operations-readiness-finalizer-self-test\latest-operations-readiness-finalize.md",
    [string] $SecretProbe = "do-not-write-this-secret"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-NotContains([string] $text, [string] $unexpected, [string] $label) {
    if ($text.Contains($unexpected)) {
        throw "$label must not contain text: $unexpected"
    }
}

$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$dataFlowStoragePlanPath = Resolve-ProjectPath ".\.osmu-run\operations-readiness-finalizer-self-test\custom-data-flow-storage-plan.json"
$scriptPath = Resolve-ProjectPath ".\scripts\finalize-operations-readiness.ps1"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanOnly `
    -RunStorageExpansionFinalizer `
    -RunHaDrReadiness `
    -RunKubernetesDrFinalizer `
    -RunIamRbacFinalizer `
    -RunIamKubernetesLiveAuth `
    -RunSecurityEvidenceFinalizer `
    -PowerShellCommand "pwsh" `
    -RunStorageBackendDryRunRunner `
    -StorageExpansionRequestId 1 `
    -AdminPassword $SecretProbe `
    -ServerDryRunOnly `
    -DataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -ReportPath $resolvedJsonOutputPath `
    -SummaryPath $resolvedMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "finalize-operations-readiness.ps1 plan check failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $resolvedJsonOutputPath)) {
    throw "Operations readiness finalizer JSON missing: $resolvedJsonOutputPath"
}
if (-not (Test-Path -LiteralPath $resolvedMarkdownOutputPath)) {
    throw "Operations readiness finalizer markdown missing: $resolvedMarkdownOutputPath"
}

$reportText = Get-Content -Raw -LiteralPath $resolvedJsonOutputPath
$markdown = Get-Content -Raw -LiteralPath $resolvedMarkdownOutputPath
$report = $reportText | ConvertFrom-Json

if ($report.formatVersion -ne "osmu.operations-readiness-finalize.v1") {
    throw "Unexpected operations readiness finalizer formatVersion: $($report.formatVersion)"
}
if ($report.result -ne "planned") {
    throw "Operations readiness finalizer plan report must be planned: $($report.result)"
}
if ($report.commands.Count -lt 6) {
    throw "Operations readiness finalizer plan must include selected evidence steps and readiness report."
}

Assert-Contains $reportText "Storage expansion finalizer" "Operations readiness finalizer JSON"
Assert-Contains $reportText "Kubernetes HA/DR readiness" "Operations readiness finalizer JSON"
Assert-Contains $reportText "Kubernetes DR finalizer" "Operations readiness finalizer JSON"
Assert-Contains $reportText "IAM/RBAC finalizer" "Operations readiness finalizer JSON"
Assert-Contains $reportText "Security evidence finalizer" "Operations readiness finalizer JSON"
Assert-Contains $reportText "Operations readiness report" "Operations readiness finalizer JSON"
Assert-Contains $reportText "DataFlowStoragePlanPath" "Operations readiness finalizer JSON"
Assert-Contains $reportText "custom-data-flow-storage-plan.json" "Operations readiness finalizer JSON"
if ($report.paths.dataFlowStoragePlan -ne $dataFlowStoragePlanPath) {
    throw "Operations readiness finalizer must preserve DataFlowStoragePlanPath: $($report.paths.dataFlowStoragePlan)"
}
if ($report.powerShellCommand -ne "pwsh") {
    throw "Operations readiness finalizer must preserve PowerShellCommand override: $($report.powerShellCommand)"
}
Assert-Contains $markdown "pwsh -NoProfile -ExecutionPolicy Bypass" "Operations readiness finalizer markdown"
Assert-Contains $markdown "custom-data-flow-storage-plan.json" "Operations readiness finalizer markdown"
Assert-NotContains $reportText $SecretProbe "Operations readiness finalizer JSON"
Assert-NotContains $markdown $SecretProbe "Operations readiness finalizer markdown"
Assert-Contains $markdown "# OSMU Operations Readiness Finalize" "Operations readiness finalizer markdown"
Assert-Contains $markdown "<secret>" "Operations readiness finalizer markdown"
Assert-Contains $markdown "Plan only" "Operations readiness finalizer markdown"

Write-Host "Operations readiness finalizer verified."
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"
