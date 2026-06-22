param(
    [string] $OutputDirectory = ".\.osmu-run\operations-evidence-plan-invocation-self-test"
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

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
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

$fixturePath = Join-Path $resolvedOutputDirectory "fixture-operations-evidence-plan.json"
$blockedJsonOutputPath = Join-Path $resolvedOutputDirectory "blocked-operations-evidence-plan-invocation.json"
$blockedMarkdownOutputPath = Join-Path $resolvedOutputDirectory "blocked-operations-evidence-plan-invocation.md"
$plannedJsonOutputPath = Join-Path $resolvedOutputDirectory "planned-operations-evidence-plan-invocation.json"
$plannedMarkdownOutputPath = Join-Path $resolvedOutputDirectory "planned-operations-evidence-plan-invocation.md"
$unsafeJsonOutputPath = Join-Path $resolvedOutputDirectory "unsafe-operations-evidence-plan-invocation.json"
$unsafeMarkdownOutputPath = Join-Path $resolvedOutputDirectory "unsafe-operations-evidence-plan-invocation.md"
$invalidJsonOutputPath = Join-Path $resolvedOutputDirectory "invalid-operations-evidence-plan-invocation.json"
$invalidMarkdownOutputPath = Join-Path $resolvedOutputDirectory "invalid-operations-evidence-plan-invocation.md"
$selectedJsonOutputPath = Join-Path $resolvedOutputDirectory "selected-operations-evidence-plan-invocation.json"
$selectedMarkdownOutputPath = Join-Path $resolvedOutputDirectory "selected-operations-evidence-plan-invocation.md"

$fixture = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = "action-required"
    sourceReport = ".osmu-run/latest-operations-readiness.json"
    sourceResult = "pending"
    sourceSummary = "passed=36 pending=6"
    pendingCount = 3
    actionCount = 3
    unplannedCount = 0
    decisionRule = "fixture"
    actions = @(
        [ordered]@{
            order = 1
            name = "Storage expansion finalizer live evidence"
            category = "storage-expansion"
            actionType = "kubernetes-live"
            evidencePath = ".osmu-run/latest-storage-expansion-finalize.json"
            requiredEvidence = "finalizer result=passed from target cluster"
            localCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -Namespace osmu -TenantName osmu-minio -ImpersonateRunner"
            workflow = ".github/workflows/storage-expansion-finalizer-ci.yml"
            workflowCommand = "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f impersonate_runner=true"
            recommendedCommand = "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f impersonate_runner=true"
            operatorInputs = @()
            hasPlaceholders = $false
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $true
            note = "Run live against target cluster."
        },
        [ordered]@{
            order = 2
            name = "Kubernetes DR finalizer live evidence"
            category = "ha-dr"
            actionType = "kubernetes-live"
            evidencePath = ".osmu-run/latest-kubernetes-dr-finalize.json"
            requiredEvidence = "finalizer result=ready from target cluster restore drill"
            localCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -BackupTimestamp <YYYYMMDDTHHMMSSZ> -ConfirmRestore -SubmitEvidence"
            workflow = ".github/workflows/kubernetes-dr-finalizer-ci.yml"
            workflowCommand = "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true -f submit_evidence=true"
            recommendedCommand = "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true -f submit_evidence=true"
            operatorInputs = @("<YYYYMMDDTHHMMSSZ>")
            hasPlaceholders = $true
            requiresOperatorApproval = $true
            requiresKubeconfigSecret = $true
            note = "Use a real backup timestamp and confirmed restore."
        },
        [ordered]@{
            order = 3
            name = "Security evidence finalizer report"
            category = "security-hardening"
            actionType = "security-ci"
            evidencePath = ".osmu-run/latest-security-evidence-finalize.json"
            requiredEvidence = "security evidence finalizer result=passed"
            localCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-security-evidence.ps1 -FailIfNotPassed"
            workflow = ".github/workflows/security-evidence-finalizer-ci.yml"
            workflowCommand = "gh workflow run security-evidence-finalizer-ci.yml -f fail_if_not_passed=true"
            recommendedCommand = "gh workflow run security-evidence-finalizer-ci.yml -f fail_if_not_passed=true"
            operatorInputs = @()
            hasPlaceholders = $false
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $false
            note = "Promote non-synthetic image signing and SBOM evidence."
        }
    )
    unplannedChecks = @()
}
$fixture | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $fixturePath -Encoding UTF8

$scriptPath = Resolve-ProjectPath ".\scripts\invoke-operations-evidence-plan.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanPath $fixturePath `
    -JsonOutputPath $blockedJsonOutputPath `
    -MarkdownOutputPath $blockedMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "invoke-operations-evidence-plan.ps1 blocked plan-only check failed with exit code $LASTEXITCODE."
}

$blockedReport = Get-Content -Raw -LiteralPath $blockedJsonOutputPath | ConvertFrom-Json
$blockedMarkdown = Get-Content -Raw -LiteralPath $blockedMarkdownOutputPath

Assert-True ($blockedReport.formatVersion -eq "osmu.operations-evidence-plan-invocation.v1") "Unexpected invocation formatVersion."
Assert-True ($blockedReport.result -eq "blocked") "Expected blocked result without confirmations."
Assert-True ($blockedReport.selectedActionCount -eq 3) "Expected three selected actions."
Assert-True ($blockedReport.blockedCount -eq 2) "Expected two blocked actions without confirmations."
Assert-True ($blockedReport.plannedCount -eq 1) "Expected one planned action without confirmations."
Assert-Contains $blockedMarkdown "kubeconfig secret not confirmed" "blocked invocation markdown"
Assert-Contains $blockedMarkdown "unresolved placeholders: <YYYYMMDDTHHMMSSZ>" "blocked invocation markdown"
Assert-Contains $blockedMarkdown "operator approval not confirmed" "blocked invocation markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanPath $fixturePath `
    -JsonOutputPath $plannedJsonOutputPath `
    -MarkdownOutputPath $plannedMarkdownOutputPath `
    -KubeconfigSecretConfirmed `
    -ConfirmOperatorApproval `
    -BackupTimestamp "20260615T010203Z" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "invoke-operations-evidence-plan.ps1 confirmed plan-only check failed with exit code $LASTEXITCODE."
}

$plannedReport = Get-Content -Raw -LiteralPath $plannedJsonOutputPath | ConvertFrom-Json
$plannedMarkdown = Get-Content -Raw -LiteralPath $plannedMarkdownOutputPath
$plannedActions = @($plannedReport.actions)

Assert-True ($plannedReport.result -eq "planned") "Expected planned result with confirmations."
Assert-True ($plannedReport.blockedCount -eq 0) "Expected no blocked actions with confirmations."
Assert-True ($plannedReport.plannedCount -eq 3) "Expected three planned actions with confirmations."
Assert-True ($plannedActions[1].command -like "*20260615T010203Z*") "Expected backup timestamp replacement."
Assert-True ($plannedActions[1].unresolvedPlaceholders.Count -eq 0) "Expected no unresolved placeholders after replacement."
Assert-Contains $plannedMarkdown "Result: planned" "planned invocation markdown"
Assert-Contains $plannedMarkdown "gh workflow run kubernetes-dr-finalizer-ci.yml" "planned invocation markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanPath $fixturePath `
    -JsonOutputPath $unsafeJsonOutputPath `
    -MarkdownOutputPath $unsafeMarkdownOutputPath `
    -ActionOrder 2 `
    -KubeconfigSecretConfirmed `
    -ConfirmOperatorApproval `
    -BackupTimestamp "20260615T010203Z | Write-Host unsafe" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "invoke-operations-evidence-plan.ps1 unsafe placeholder check failed with exit code $LASTEXITCODE."
}

$unsafeReport = Get-Content -Raw -LiteralPath $unsafeJsonOutputPath | ConvertFrom-Json
$unsafeAction = @($unsafeReport.actions)[0]
Assert-True ($unsafeReport.result -eq "blocked") "Expected unsafe placeholder command to be blocked."
Assert-True (@($unsafeAction.blockReasons) -contains "command failed allowlist/shell metacharacter check") "Expected unsafe placeholder command to fail shell metacharacter check."
Assert-True ($unsafeAction.command -like "*| Write-Host unsafe*") "Expected unsafe command to preserve rejected pipe for audit."

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanPath $fixturePath `
    -JsonOutputPath $invalidJsonOutputPath `
    -MarkdownOutputPath $invalidMarkdownOutputPath `
    -ActionOrder 2 `
    -KubeconfigSecretConfirmed `
    -ConfirmOperatorApproval `
    -BackupTimestamp "not-a-timestamp" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "invoke-operations-evidence-plan.ps1 invalid placeholder check failed with exit code $LASTEXITCODE."
}

$invalidReport = Get-Content -Raw -LiteralPath $invalidJsonOutputPath | ConvertFrom-Json
$invalidAction = @($invalidReport.actions)[0]
Assert-True ($invalidReport.result -eq "blocked") "Expected invalid known placeholder command to be blocked."
Assert-True (@($invalidAction.blockReasons) -contains "invalid placeholder value for <YYYYMMDDTHHMMSSZ>") "Expected invalid backup timestamp to fail known placeholder validation."
Assert-True (@($invalidAction.invalidPlaceholders) -contains "<YYYYMMDDTHHMMSSZ>") "Expected invalid backup timestamp to be exposed for unblock planning."
Assert-True ($invalidAction.command -like "*not-a-timestamp*") "Expected invalid command to preserve rejected timestamp for audit."

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanPath $fixturePath `
    -JsonOutputPath $selectedJsonOutputPath `
    -MarkdownOutputPath $selectedMarkdownOutputPath `
    -ActionOrder 2 `
    -KubeconfigSecretConfirmed `
    -ConfirmOperatorApproval `
    -BackupTimestamp "20260615T010203Z" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "invoke-operations-evidence-plan.ps1 action selection check failed with exit code $LASTEXITCODE."
}

$selectedReport = Get-Content -Raw -LiteralPath $selectedJsonOutputPath | ConvertFrom-Json
Assert-True ($selectedReport.result -eq "planned") "Expected selected action result to be planned."
Assert-True ($selectedReport.selectedActionCount -eq 1) "Expected one selected action."
Assert-True (@($selectedReport.actions)[0].order -eq 2) "Expected action order 2 to be selected."

Write-Host "Operations evidence plan invocation verified."
Write-Host "Blocked report: $blockedJsonOutputPath"
Write-Host "Planned report: $plannedJsonOutputPath"
Write-Host "Unsafe report: $unsafeJsonOutputPath"
Write-Host "Invalid report: $invalidJsonOutputPath"
Write-Host "Selected report: $selectedJsonOutputPath"
