param(
    [string] $OutputDirectory = ".\.osmu-run\operations-invocation-unblock-plan-self-test"
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

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-invocation-unblock-plan.ps1"
$blockedInvocationPath = Join-Path $resolvedOutputDirectory "blocked-invocation.json"
$blockedJsonPath = Join-Path $resolvedOutputDirectory "blocked-unblock-plan.json"
$blockedMarkdownPath = Join-Path $resolvedOutputDirectory "blocked-unblock-plan.md"
$readyInvocationPath = Join-Path $resolvedOutputDirectory "ready-invocation.json"
$readyJsonPath = Join-Path $resolvedOutputDirectory "ready-unblock-plan.json"
$readyMarkdownPath = Join-Path $resolvedOutputDirectory "ready-unblock-plan.md"
$invalidInvocationPath = Join-Path $resolvedOutputDirectory "invalid-invocation.json"
$invalidJsonPath = Join-Path $resolvedOutputDirectory "invalid-unblock-plan.json"
$invalidMarkdownPath = Join-Path $resolvedOutputDirectory "invalid-unblock-plan.md"

Write-JsonFixture $blockedInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = "2026-06-16T07:30:00+09:00"
    result = "blocked"
    sourcePlan = ".osmu-run/latest-operations-evidence-plan.json"
    sourceSummary = "passed=36 pending=6"
    commandMode = "Workflow"
    executionMode = "plan-only"
    selectedActionCount = 4
    plannedCount = 1
    blockedCount = 3
    executedCount = 0
    failedCount = 0
    actions = @(
        [ordered]@{
            order = 1
            name = "Storage expansion finalizer live evidence"
            category = "storage-expansion"
            actionType = "kubernetes-live"
            evidencePath = ".osmu-run/latest-storage-expansion-finalize.json"
            commandMode = "Workflow"
            command = "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true"
            status = "blocked"
            blockReasons = @("kubeconfig secret not confirmed")
            unresolvedPlaceholders = @()
            invalidPlaceholders = @()
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $true
        },
        [ordered]@{
            order = 2
            name = "Kubernetes DR finalizer live evidence"
            category = "ha-dr"
            actionType = "kubernetes-live"
            evidencePath = ".osmu-run/latest-kubernetes-dr-finalize.json"
            commandMode = "Workflow"
            command = "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f api_base=<restore-api-base> -f admin_login_id=<admin> -f metadata_row_count=<count>"
            status = "blocked"
            blockReasons = @("unresolved placeholders: <YYYYMMDDTHHMMSSZ>, <restore-api-base>, <admin>, <count>", "operator approval not confirmed", "kubeconfig secret not confirmed")
            unresolvedPlaceholders = @("<YYYYMMDDTHHMMSSZ>", "<restore-api-base>", "<admin>", "<count>")
            invalidPlaceholders = @()
            requiresOperatorApproval = $true
            requiresKubeconfigSecret = $true
        },
        [ordered]@{
            order = 3
            name = "Security evidence finalizer report"
            category = "security-hardening"
            actionType = "security-ci"
            evidencePath = ".osmu-run/latest-security-evidence-finalize.json"
            commandMode = "Workflow"
            command = "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<run-id> -f image_signing_artifact_name=<artifact-name> -f container_security_run_id=<run-id> -f container_security_artifact_name=<artifact-name>"
            status = "blocked"
            blockReasons = @("unresolved placeholders: <run-id>, <artifact-name>")
            unresolvedPlaceholders = @("<run-id>", "<artifact-name>")
            invalidPlaceholders = @()
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $false
        },
        [ordered]@{
            order = 4
            name = "Container scan/SBOM evidence"
            category = "security-hardening"
            actionType = "security-ci"
            evidencePath = ".osmu-run/latest-container-security-evidence.json"
            commandMode = "Workflow"
            command = "gh workflow run container-security-ci.yml"
            status = "planned"
            blockReasons = @()
            unresolvedPlaceholders = @()
            invalidPlaceholders = @()
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $false
        }
    )
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $blockedInvocationPath `
    -JsonOutputPath $blockedJsonPath `
    -MarkdownOutputPath $blockedMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-invocation-unblock-plan.ps1 blocked fixture failed with exit code $LASTEXITCODE."
}

$blockedReport = Get-Content -Raw -LiteralPath $blockedJsonPath | ConvertFrom-Json
$blockedMarkdown = Get-Content -Raw -LiteralPath $blockedMarkdownPath
Assert-Equal $blockedReport.formatVersion "osmu.operations-invocation-unblock-plan.v1" "blocked formatVersion"
Assert-Equal $blockedReport.result "action-required" "blocked result"
Assert-Equal $blockedReport.blockedCount 3 "blocked count"
Assert-Equal $blockedReport.plannedCount 1 "planned count"
Assert-Equal $blockedReport.requiredPlaceholderCount 6 "placeholder count"
Assert-Equal $blockedReport.ambiguousRepeatedPlaceholderCount 2 "ambiguous placeholder count"
Assert-True $blockedReport.needsKubeconfigSecretConfirmation "expected kubeconfig confirmation"
Assert-True $blockedReport.needsOperatorApprovalConfirmation "expected operator approval"
Assert-Contains $blockedReport.confirmedPlanCommand "-KubeconfigSecretConfirmed" "confirmed command"
Assert-Contains $blockedReport.confirmedPlanCommand "-ConfirmOperatorApproval" "confirmed command"
Assert-Contains $blockedReport.confirmedPlanCommand "-BackupTimestamp <YYYYMMDDTHHMMSSZ>" "confirmed command"
Assert-Contains $blockedReport.confirmedPlanCommand "-RestoreApiBase <restore-api-base>" "confirmed command"
Assert-Contains $blockedReport.confirmedPlanCommand "-Placeholder '<run-id>=<run-id>'" "confirmed command"
Assert-Contains $blockedReport.plannedOnlyCommand "-ActionOrder 4" "planned-only command"
Assert-True $blockedReport.actions[2].ambiguousRepeatedPlaceholders "expected repeated placeholders on security finalizer"
Assert-Contains $blockedMarkdown "repeated generic placeholders" "blocked markdown"

Write-JsonFixture $readyInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = "2026-06-16T07:30:00+09:00"
    result = "planned"
    sourcePlan = ".osmu-run/latest-operations-evidence-plan.json"
    sourceSummary = "passed=36 pending=6"
    commandMode = "Workflow"
    executionMode = "plan-only"
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 0
    failedCount = 0
    actions = @(
        [ordered]@{
            order = 1
            name = "Container scan/SBOM evidence"
            category = "security-hardening"
            actionType = "security-ci"
            evidencePath = ".osmu-run/latest-container-security-evidence.json"
            commandMode = "Workflow"
            command = "gh workflow run container-security-ci.yml"
            status = "planned"
            blockReasons = @()
            unresolvedPlaceholders = @()
            invalidPlaceholders = @()
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $false
        }
    )
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $readyInvocationPath `
    -JsonOutputPath $readyJsonPath `
    -MarkdownOutputPath $readyMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-invocation-unblock-plan.ps1 ready fixture failed with exit code $LASTEXITCODE."
}

$readyReport = Get-Content -Raw -LiteralPath $readyJsonPath | ConvertFrom-Json
$readyMarkdown = Get-Content -Raw -LiteralPath $readyMarkdownPath
Assert-Equal $readyReport.result "ready" "ready result"
Assert-Equal $readyReport.blockedCount 0 "ready blocked count"
Assert-Equal $readyReport.requiredPlaceholderCount 0 "ready placeholder count"
Assert-Contains $readyReport.plannedOnlyCommand "-ActionOrder 1" "ready planned-only command"
Assert-Contains $readyMarkdown "Result: ready" "ready markdown"

Write-JsonFixture $invalidInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = "2026-06-16T07:30:00+09:00"
    result = "blocked"
    sourcePlan = ".osmu-run/latest-operations-evidence-plan.json"
    sourceSummary = "passed=36 pending=6"
    commandMode = "Workflow"
    executionMode = "plan-only"
    selectedActionCount = 1
    plannedCount = 0
    blockedCount = 1
    executedCount = 0
    failedCount = 0
    actions = @(
        [ordered]@{
            order = 1
            name = "Kubernetes DR finalizer live evidence"
            category = "ha-dr"
            actionType = "kubernetes-live"
            evidencePath = ".osmu-run/latest-kubernetes-dr-finalize.json"
            commandMode = "Workflow"
            command = "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=not-a-timestamp -f confirm_restore=true"
            status = "blocked"
            blockReasons = @("invalid placeholder value for <YYYYMMDDTHHMMSSZ>")
            unresolvedPlaceholders = @()
            invalidPlaceholders = @("<YYYYMMDDTHHMMSSZ>")
            requiresOperatorApproval = $true
            requiresKubeconfigSecret = $true
        }
    )
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $invalidInvocationPath `
    -JsonOutputPath $invalidJsonPath `
    -MarkdownOutputPath $invalidMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-invocation-unblock-plan.ps1 invalid fixture failed with exit code $LASTEXITCODE."
}

$invalidReport = Get-Content -Raw -LiteralPath $invalidJsonPath | ConvertFrom-Json
$invalidMarkdown = Get-Content -Raw -LiteralPath $invalidMarkdownPath
Assert-Equal $invalidReport.result "action-required" "invalid result"
Assert-Equal $invalidReport.requiredPlaceholderCount 1 "invalid required placeholder count"
Assert-Contains $invalidReport.confirmedPlanCommand "-BackupTimestamp <YYYYMMDDTHHMMSSZ>" "invalid confirmed command"
Assert-True (@($invalidReport.actions)[0].invalidPlaceholders -contains "<YYYYMMDDTHHMMSSZ>") "invalid action should carry invalid placeholder"
Assert-Contains $invalidMarkdown "<YYYYMMDDTHHMMSSZ> via BackupTimestamp" "invalid markdown"

Write-Host "Operations invocation unblock plan verified."
Write-Host "Blocked report: $blockedJsonPath"
Write-Host "Ready report: $readyJsonPath"
Write-Host "Invalid report: $invalidJsonPath"
