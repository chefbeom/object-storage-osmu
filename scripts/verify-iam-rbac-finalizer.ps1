param(
    [string] $JsonOutputPath = ".\.osmu-run\iam-rbac-finalizer-self-test\latest-iam-rbac-finalize.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\iam-rbac-finalizer-self-test\latest-iam-rbac-finalize.md",
    [string] $PlanJsonOutputPath = ".\.osmu-run\iam-rbac-finalizer-self-test\latest-iam-rbac-finalize-plan.json",
    [string] $PlanMarkdownOutputPath = ".\.osmu-run\iam-rbac-finalizer-self-test\latest-iam-rbac-finalize-plan.md"
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

$scriptPath = Resolve-ProjectPath ".\scripts\finalize-iam-rbac-readiness.ps1"
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$resolvedPlanJsonOutputPath = Resolve-ProjectPath $PlanJsonOutputPath
$resolvedPlanMarkdownOutputPath = Resolve-ProjectPath $PlanMarkdownOutputPath

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -JsonOutputPath $resolvedJsonOutputPath `
    -MarkdownOutputPath $resolvedMarkdownOutputPath `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "finalize-iam-rbac-readiness.ps1 static check failed with exit code $LASTEXITCODE."
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanOnly `
    -RunBackendPolicyTests `
    -RunKubernetesLiveAuth `
    -JsonOutputPath $resolvedPlanJsonOutputPath `
    -MarkdownOutputPath $resolvedPlanMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "finalize-iam-rbac-readiness.ps1 plan check failed with exit code $LASTEXITCODE."
}

foreach ($path in @($resolvedJsonOutputPath, $resolvedMarkdownOutputPath, $resolvedPlanJsonOutputPath, $resolvedPlanMarkdownOutputPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "IAM/RBAC finalizer self-test output missing: $path"
    }
}

$reportText = Get-Content -Raw -LiteralPath $resolvedJsonOutputPath
$report = $reportText | ConvertFrom-Json
$markdown = Get-Content -Raw -LiteralPath $resolvedMarkdownOutputPath
$planText = Get-Content -Raw -LiteralPath $resolvedPlanJsonOutputPath
$planReport = $planText | ConvertFrom-Json
$planMarkdown = Get-Content -Raw -LiteralPath $resolvedPlanMarkdownOutputPath

if ($report.formatVersion -ne "osmu.iam-rbac-finalize.v1") {
    throw "Unexpected IAM/RBAC finalizer formatVersion: $($report.formatVersion)"
}
if ($report.result -ne "passed") {
    throw "IAM/RBAC finalizer static report must pass: $($report.result)"
}
if ($report.commands.Count -ne 2) {
    throw "IAM/RBAC finalizer static report must include two verifier commands."
}
if ($report.failedCount -ne 0) {
    throw "IAM/RBAC finalizer static report must have failedCount=0."
}

Assert-Contains $reportText "IAM/RBAC matrix verifier" "IAM/RBAC finalizer JSON"
Assert-Contains $reportText "Kubernetes RBAC matrix verifier" "IAM/RBAC finalizer JSON"
Assert-Contains $reportText "secretPolicy" "IAM/RBAC finalizer JSON"
Assert-Contains $markdown "# OSMU IAM/RBAC Finalize" "IAM/RBAC finalizer markdown"
Assert-Contains $markdown "iam-rbac-static-passed" "IAM/RBAC finalizer markdown"
Assert-NotContains $reportText "OSMU_ADMIN_PASSWORD" "IAM/RBAC finalizer JSON"
Assert-NotContains $markdown "OSMU_ADMIN_PASSWORD" "IAM/RBAC finalizer markdown"

if ($planReport.result -ne "planned") {
    throw "IAM/RBAC finalizer plan report must be planned: $($planReport.result)"
}
if ($planReport.commands.Count -lt 4) {
    throw "IAM/RBAC finalizer plan must include optional backend and live evidence commands."
}

Assert-Contains $planText "Backend focused RBAC tests" "IAM/RBAC finalizer plan JSON"
Assert-Contains $planText "Storage expansion live RBAC auth" "IAM/RBAC finalizer plan JSON"
Assert-Contains $planMarkdown "Plan only" "IAM/RBAC finalizer plan markdown"

Write-Host "IAM/RBAC finalizer verified."
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"
