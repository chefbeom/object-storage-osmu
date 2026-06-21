param(
    [string] $OutputDir = ".\.osmu-run\data-flow-storage-plan-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Assert-Contains([string] $value, [string] $expected, [string] $label) {
    if (-not $value -or -not $value.Contains($expected)) {
        throw "$label must contain '$expected'."
    }
}

$resolvedOutputDir = Resolve-ProjectPath $OutputDir
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null

$planJsonPath = Join-Path $resolvedOutputDir "plan.json"
$planMarkdownPath = Join-Path $resolvedOutputDir "plan.md"
$passedJsonPath = Join-Path $resolvedOutputDir "passed.json"
$passedMarkdownPath = Join-Path $resolvedOutputDir "passed.md"

& (Join-Path $PSScriptRoot "write-data-flow-storage-plan.ps1") `
    -EnvironmentName "self-test" `
    -TargetCluster "local" `
    -Operator "data-flow-storage-plan-self-test" `
    -JsonOutputPath $planJsonPath `
    -MarkdownOutputPath $planMarkdownPath

$planReport = Get-Content -Raw -LiteralPath $planJsonPath | ConvertFrom-Json
$planMarkdown = Get-Content -Raw -LiteralPath $planMarkdownPath
Assert-True ($planReport.formatVersion -eq "osmu.data-flow-storage-plan.v1") "Unexpected data-flow storage plan formatVersion."
Assert-True ($planReport.result -eq "plan-ready-execute-required") "Default data-flow storage plan should require target evidence."
Assert-True ($planReport.pendingCount -gt 0) "Default data-flow storage plan should include pending checks."
Assert-Contains $planReport.scopePolicy "not AWS billing parity" "scopePolicy"
Assert-Contains $planReport.scopePolicy "must not include object keys" "scopePolicy"
Assert-Contains $planMarkdown "Expected peak events/day" "plan markdown"

& (Join-Path $PSScriptRoot "write-data-flow-storage-plan.ps1") `
    -EnvironmentName "target-fixture" `
    -TargetCluster "fixture-cluster" `
    -Operator "data-flow-storage-plan-self-test" `
    -CandidateStore "DUAL_WRITE" `
    -ExpectedPeakEventsPerDay 1000000 `
    -ExpectedQueryWindowDays 365 `
    -EvidenceRef "fixture-run-123" `
    -ConfirmNoObjectKeyInAggregates `
    -ConfirmBackfillPlan `
    -ConfirmRollbackPlan `
    -ConfirmDashboardCutoverPlan `
    -ConfirmRetentionJobBudget `
    -ConfirmExplainEvidence `
    -JsonOutputPath $passedJsonPath `
    -MarkdownOutputPath $passedMarkdownPath `
    -FailIfNotPassed

$passedReport = Get-Content -Raw -LiteralPath $passedJsonPath | ConvertFrom-Json
Assert-True ($passedReport.result -eq "passed") "Confirmed data-flow storage plan should pass."
Assert-True ($passedReport.pendingCount -eq 0) "Confirmed data-flow storage plan should have no pending checks."
Assert-True ($passedReport.candidateStore -eq "DUAL_WRITE") "Confirmed data-flow storage plan should preserve candidate store."

$rejectedSecret = $false
try {
    & (Join-Path $PSScriptRoot "write-data-flow-storage-plan.ps1") `
        -EnvironmentName "self-test" `
        -EvidenceRef "password=leaked" `
        -JsonOutputPath (Join-Path $resolvedOutputDir "secret.json") `
        -MarkdownOutputPath (Join-Path $resolvedOutputDir "secret.md")
} catch {
    $rejectedSecret = $true
}
Assert-True $rejectedSecret "Credential-shaped evidence refs must be rejected."

Write-Host "Data-flow storage plan verification passed: $passedJsonPath"
