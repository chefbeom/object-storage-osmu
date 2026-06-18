param(
    [string] $OutputDirectory = ".\.osmu-run\operations-readiness-convergence-self-test"
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

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-readiness-convergence.ps1"

$missingHandoffPath = Join-Path $resolvedOutputDirectory "missing-handoff.json"
$missingReadinessPath = Join-Path $resolvedOutputDirectory "missing-readiness.json"
$missingFinalizePath = Join-Path $resolvedOutputDirectory "missing-finalize.json"
$missingSyncPath = Join-Path $resolvedOutputDirectory "missing-sync.json"
$missingJsonPath = Join-Path $resolvedOutputDirectory "missing-convergence.json"
$missingMarkdownPath = Join-Path $resolvedOutputDirectory "missing-convergence.md"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $missingHandoffPath `
    -ReadinessReportPath $missingReadinessPath `
    -OperationsReadinessFinalizeReportPath $missingFinalizePath `
    -KubernetesOperationsReportSyncReportPath $missingSyncPath `
    -JsonOutputPath $missingJsonPath `
    -MarkdownOutputPath $missingMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 missing-handoff check failed with exit code $LASTEXITCODE."
}

$missingReport = Get-Content -Raw -LiteralPath $missingJsonPath | ConvertFrom-Json
$missingMarkdown = Get-Content -Raw -LiteralPath $missingMarkdownPath
Assert-Equal $missingReport.formatVersion "osmu.operations-readiness-convergence.v1" "missing formatVersion"
Assert-Equal $missingReport.result "action-required" "missing result"
Assert-Equal $missingReport.currentBottleneck.code "write-handoff" "missing bottleneck"
Assert-Equal $missingReport.recommendedCommands[0].name "Generate operations evidence handoff" "missing recommended command"
Assert-Contains $missingMarkdown "Generate operations evidence handoff" "missing markdown command"

$actionHandoffPath = Join-Path $resolvedOutputDirectory "action-handoff.json"
$actionReadinessPath = Join-Path $resolvedOutputDirectory "action-readiness.json"
$actionFinalizePath = Join-Path $resolvedOutputDirectory "action-finalize.json"
$actionSyncPath = Join-Path $resolvedOutputDirectory "action-sync.json"
$actionJsonPath = Join-Path $resolvedOutputDirectory "action-convergence.json"
$actionMarkdownPath = Join-Path $resolvedOutputDirectory "action-convergence.md"

Write-JsonFixture $actionReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=6"
})
Write-JsonFixture $actionHandoffPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-handoff.v1"
    result = "action-required"
    nextStep = [ordered]@{
        code = "run-operations-finalizer"
        title = "Run operations readiness finalizer"
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1"
        reason = "Evidence import has passed but the operations readiness finalizer report is missing."
        note = "Run the combined finalizer."
    }
    stageCount = 7
    readyStageCount = 5
    blockedActionCount = 0
    missingWorkflowRunCount = 0
    missingRequiredArtifactCount = 0
    failedImportCount = 0
    finalizerFailedCount = 0
    finalizerGapCount = 0
    stages = @(
        [ordered]@{
            name = "operations-finalizer"
            exists = $false
            ready = $false
            result = ""
            summary = "readiness= failed=0 gaps=0"
            command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1"
            note = "Combined finalizer and final readiness regeneration."
        }
    )
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $actionHandoffPath `
    -ReadinessReportPath $actionReadinessPath `
    -OperationsReadinessFinalizeReportPath $actionFinalizePath `
    -KubernetesOperationsReportSyncReportPath $actionSyncPath `
    -JsonOutputPath $actionJsonPath `
    -MarkdownOutputPath $actionMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 action-required check failed with exit code $LASTEXITCODE."
}

$actionReport = Get-Content -Raw -LiteralPath $actionJsonPath | ConvertFrom-Json
$actionMarkdown = Get-Content -Raw -LiteralPath $actionMarkdownPath
Assert-Equal $actionReport.result "action-required" "action result"
Assert-Equal $actionReport.currentBottleneck.code "run-operations-finalizer" "action bottleneck"
Assert-Equal $actionReport.stageCount 7 "action stage count"
Assert-Equal $actionReport.readyStageCount 5 "action ready stage count"
Assert-Contains $actionReport.recommendedCommands[0].command "finalize-operations-readiness.ps1" "action recommended command"
Assert-Contains $actionMarkdown "Run operations readiness finalizer" "action markdown command"

$readyHandoffPath = Join-Path $resolvedOutputDirectory "ready-handoff.json"
$readyReadinessPath = Join-Path $resolvedOutputDirectory "ready-readiness.json"
$readyFinalizePath = Join-Path $resolvedOutputDirectory "ready-finalize.json"
$readySyncPath = Join-Path $resolvedOutputDirectory "ready-sync.json"
$syncRequiredPath = Join-Path $resolvedOutputDirectory "sync-required-convergence.json"
$syncRequiredMarkdownPath = Join-Path $resolvedOutputDirectory "sync-required-convergence.md"
$readyJsonPath = Join-Path $resolvedOutputDirectory "ready-convergence.json"
$readyMarkdownPath = Join-Path $resolvedOutputDirectory "ready-convergence.md"

Write-JsonFixture $readyReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "ready"
    summary = "passed=42 pending=0"
})
Write-JsonFixture $readyFinalizePath ([ordered]@{
    formatVersion = "osmu.operations-readiness-finalize.v1"
    result = "ready"
    status = "operations-readiness-finalize-ready"
    readinessResult = "ready"
    failedCount = 0
    gaps = @()
})
Write-JsonFixture $readyHandoffPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-handoff.v1"
    result = "ready"
    nextStep = [ordered]@{
        code = "none"
        title = "Operations readiness is ready"
        command = ""
        reason = "The latest operations readiness report is ready."
        note = "No handoff action is required."
    }
    stageCount = 7
    readyStageCount = 7
    blockedActionCount = 0
    missingWorkflowRunCount = 0
    missingRequiredArtifactCount = 0
    failedImportCount = 0
    finalizerFailedCount = 0
    finalizerGapCount = 0
    stages = @()
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $readyHandoffPath `
    -ReadinessReportPath $readyReadinessPath `
    -OperationsReadinessFinalizeReportPath $readyFinalizePath `
    -KubernetesOperationsReportSyncReportPath $readySyncPath `
    -JsonOutputPath $syncRequiredPath `
    -MarkdownOutputPath $syncRequiredMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 sync-required check failed with exit code $LASTEXITCODE."
}

$syncRequiredReport = Get-Content -Raw -LiteralPath $syncRequiredPath | ConvertFrom-Json
$syncRequiredMarkdown = Get-Content -Raw -LiteralPath $syncRequiredMarkdownPath
Assert-Equal $syncRequiredReport.result "action-required" "sync required result"
Assert-Equal $syncRequiredReport.currentBottleneck.code "sync-kubernetes-operations-report" "sync required bottleneck"
Assert-Equal $syncRequiredReport.kubernetesReportSyncExists $false "sync required exists"
Assert-Equal $syncRequiredReport.kubernetesReportSyncReady $false "sync required ready"
Assert-Contains $syncRequiredReport.recommendedCommands[0].command "sync-kubernetes-operations-reports.ps1" "sync required command"
Assert-Contains $syncRequiredMarkdown "Kubernetes report sync: " "sync required markdown status"

Write-JsonFixture $readySyncPath ([ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    namespace = "osmu"
    configMapName = "osmu-operations-reports"
    configMapKey = "latest-operations-readiness-convergence.json"
    sourceReportResult = "ready"
    failedCount = 0
    checkCount = 5
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $readyHandoffPath `
    -ReadinessReportPath $readyReadinessPath `
    -OperationsReadinessFinalizeReportPath $readyFinalizePath `
    -KubernetesOperationsReportSyncReportPath $readySyncPath `
    -JsonOutputPath $readyJsonPath `
    -MarkdownOutputPath $readyMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 ready check failed with exit code $LASTEXITCODE."
}

$readyReport = Get-Content -Raw -LiteralPath $readyJsonPath | ConvertFrom-Json
$readyMarkdown = Get-Content -Raw -LiteralPath $readyMarkdownPath
Assert-Equal $readyReport.result "ready" "ready result"
Assert-Equal $readyReport.currentBottleneck.code "none" "ready bottleneck"
Assert-Equal @($readyReport.recommendedCommands).Count 0 "ready command count"
Assert-Equal $readyReport.finalizerResult "ready" "ready finalizer"
Assert-Equal $readyReport.kubernetesReportSyncResult "applied" "ready sync result"
Assert-Equal $readyReport.kubernetesReportSyncReady $true "ready sync ready"
Assert-Contains $readyMarkdown "Result: ready" "ready markdown result"

Assert-True ($readyReport.safetyPolicy.Contains("does not execute")) "safety policy"

Write-Host "Operations readiness convergence verified."
Write-Host "Missing report: $missingJsonPath"
Write-Host "Action report: $actionJsonPath"
Write-Host "Sync required report: $syncRequiredPath"
Write-Host "Ready report: $readyJsonPath"
