param(
    [string] $OutputDirectory = ".\.osmu-run\operations-dispatch-preflight-self-test"
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
    $Value | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $PathValue -Encoding UTF8
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

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-dispatch-preflight.ps1"
$unblockPlanPath = Join-Path $resolvedOutputDirectory "unblock-plan.json"
$missingJsonPath = Join-Path $resolvedOutputDirectory "missing-preflight.json"
$missingMarkdownPath = Join-Path $resolvedOutputDirectory "missing-preflight.md"
$readyJsonPath = Join-Path $resolvedOutputDirectory "ready-preflight.json"
$readyMarkdownPath = Join-Path $resolvedOutputDirectory "ready-preflight.md"

Write-JsonFixture $unblockPlanPath ([ordered]@{
    formatVersion = "osmu.operations-invocation-unblock-plan.v1"
    generatedAt = "2026-06-16T08:00:00+09:00"
    result = "action-required"
    sourceInvocationReport = ".osmu-run/latest-operations-evidence-plan-invocation.json"
    sourceResult = "blocked"
    sourceSummary = "passed=36 pending=6"
    selectedActionCount = 2
    plannedCount = 0
    blockedCount = 2
    failedCount = 0
    needsKubeconfigSecretConfirmation = $true
    needsOperatorApprovalConfirmation = $true
    requiredPlaceholderCount = 1
    ambiguousRepeatedPlaceholderCount = 0
    blockedActionOrders = @(1, 2)
    plannedActionOrders = @()
    confirmedPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"
    blockedOnlyPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"
    plannedOnlyCommand = ""
    decisionRule = "Resolve placeholders and confirmations before execution."
    actions = @(
        [ordered]@{
            order = 1
            name = "Storage expansion finalizer live evidence"
            category = "storage-expansion"
            actionType = "kubernetes-live"
            evidencePath = ".osmu-run/latest-storage-expansion-finalize.json"
            status = "blocked"
            commandMode = "Workflow"
            command = "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true"
            blockReasons = @("kubeconfig secret not confirmed")
            unresolvedPlaceholders = @()
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $true
            needsOperatorApprovalConfirmation = $false
            needsKubeconfigSecretConfirmation = $true
            requiredInputs = @()
            ambiguousRepeatedPlaceholders = $false
            planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed"
        },
        [ordered]@{
            order = 2
            name = "Kubernetes DR finalizer live evidence"
            category = "ha-dr"
            actionType = "kubernetes-live"
            evidencePath = ".osmu-run/latest-kubernetes-dr-finalize.json"
            status = "blocked"
            commandMode = "Workflow"
            command = "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true"
            blockReasons = @("unresolved placeholders: <YYYYMMDDTHHMMSSZ>", "operator approval not confirmed", "kubeconfig secret not confirmed")
            unresolvedPlaceholders = @("<YYYYMMDDTHHMMSSZ>")
            requiresOperatorApproval = $true
            requiresKubeconfigSecret = $true
            needsOperatorApprovalConfirmation = $true
            needsKubeconfigSecretConfirmation = $true
            requiredInputs = @(
                [ordered]@{
                    placeholder = "<YYYYMMDDTHHMMSSZ>"
                    parameter = "BackupTimestamp"
                    valueTemplate = "<YYYYMMDDTHHMMSSZ>"
                    occurrenceCount = 1
                    ambiguousRepeatedPlaceholder = $false
                    note = "Provide a concrete value before planning or executing this action."
                }
            )
            ambiguousRepeatedPlaceholders = $false
            planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 2 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"
        }
    )
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -UnblockPlanPath $unblockPlanPath `
    -JsonOutputPath $missingJsonPath `
    -MarkdownOutputPath $missingMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-dispatch-preflight.ps1 missing fixture failed with exit code $LASTEXITCODE."
}

$missingReport = Get-Content -Raw -LiteralPath $missingJsonPath | ConvertFrom-Json
$missingMarkdown = Get-Content -Raw -LiteralPath $missingMarkdownPath
Assert-Equal $missingReport.formatVersion "osmu.operations-dispatch-preflight.v1" "missing formatVersion"
Assert-Equal $missingReport.result "action-required" "missing result"
Assert-Equal $missingReport.selectedActionCount 2 "missing selected action count"
Assert-Equal $missingReport.missingInputCount 1 "missing input count"
Assert-True ($missingReport.failedCheckCount -ge 3) "expected missing preflight failures"
Assert-Contains ($missingReport.checks | ConvertTo-Json -Depth 8) "KUBECONFIG_SECRET_CONFIRMED" "missing checks"
Assert-Contains $missingMarkdown "Result: action-required" "missing markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -UnblockPlanPath $unblockPlanPath `
    -JsonOutputPath $readyJsonPath `
    -MarkdownOutputPath $readyMarkdownPath `
    -KubeconfigSecretConfirmed `
    -ConfirmOperatorApproval `
    -BackupTimestamp "20260616T010203Z" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-dispatch-preflight.ps1 ready fixture failed with exit code $LASTEXITCODE."
}

$readyReport = Get-Content -Raw -LiteralPath $readyJsonPath | ConvertFrom-Json
$readyMarkdown = Get-Content -Raw -LiteralPath $readyMarkdownPath
Assert-Equal $readyReport.result "ready" "ready result"
Assert-Equal $readyReport.failedCheckCount 0 "ready failed checks"
Assert-Equal $readyReport.missingInputCount 0 "ready missing inputs"
Assert-True $readyReport.needsKubeconfigSecretConfirmation "ready kubeconfig requirement"
Assert-True $readyReport.needsOperatorApprovalConfirmation "ready approval requirement"
Assert-Contains $readyReport.readyPlanCommand "-KubeconfigSecretConfirmed" "ready plan command"
Assert-Contains $readyReport.readyPlanCommand "-ConfirmOperatorApproval" "ready plan command"
Assert-Contains $readyReport.readyPlanCommand "-BackupTimestamp 20260616T010203Z" "ready plan command"
Assert-Contains $readyReport.executeCommand "-Execute" "ready execute command"
Assert-True (@($readyReport.workflowFiles | Where-Object { -not $_.exists }).Count -eq 0) "expected workflow files to exist"
Assert-True (@($readyReport.requiredGitHubSecrets).Count -gt 0) "expected workflow secret references"
Assert-Contains $readyMarkdown "Result: ready" "ready markdown"

Write-Host "Operations dispatch preflight verified."
Write-Host "Missing report: $missingJsonPath"
Write-Host "Ready report: $readyJsonPath"
