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

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
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
$githubCliJsonOutputPath = Join-Path $resolvedOutputDirectory "github-cli-path-operations-evidence-plan-invocation.json"
$githubCliMarkdownOutputPath = Join-Path $resolvedOutputDirectory "github-cli-path-operations-evidence-plan-invocation.md"
$githubApiBlockedJsonOutputPath = Join-Path $resolvedOutputDirectory "github-api-blocked-operations-evidence-plan-invocation.json"
$githubApiBlockedMarkdownOutputPath = Join-Path $resolvedOutputDirectory "github-api-blocked-operations-evidence-plan-invocation.md"
$fakeGitHubCliDirectory = Join-Path $resolvedOutputDirectory "fake-github-cli"
$fakeGitHubCliPath = Join-Path $fakeGitHubCliDirectory "gh.cmd"
New-Item -ItemType Directory -Force -Path $fakeGitHubCliDirectory | Out-Null
Set-Content -LiteralPath $fakeGitHubCliPath -Value "@echo off`r`necho fake gh %*`r`nexit /b 0`r`n" -Encoding ASCII

$fixture = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = "action-required"
    sourceReport = ".osmu-run/latest-operations-readiness.json"
    sourceResult = "pending"
    sourceSummary = "passed=36 pending=6"
    sourcePassedCount = 36
    sourcePendingCount = 6
    sourceTotalCount = 42
    sourceCheckCount = 42
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
            requiresOperatorApproval = $true
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

$blockedReport = Read-Utf8Text $blockedJsonOutputPath | ConvertFrom-Json
$blockedMarkdown = Read-Utf8Text $blockedMarkdownOutputPath

Assert-True ($blockedReport.formatVersion -eq "osmu.operations-evidence-plan-invocation.v1") "Unexpected invocation formatVersion."
Assert-True ($blockedReport.sourcePassedCount -eq 36) "Expected source passed count."
Assert-True ($blockedReport.sourcePendingCount -eq 6) "Expected source pending count."
Assert-True ($blockedReport.sourceTotalCount -eq 42) "Expected source total count."
Assert-True ($blockedReport.sourceCheckCount -eq 42) "Expected source check count."
Assert-True ($blockedReport.result -eq "blocked") "Expected blocked result without confirmations."
Assert-True ($blockedReport.selectedActionCount -eq 3) "Expected three selected actions."
Assert-True ((@($blockedReport.selectedActionOrders) -join ",") -eq "1,2,3") "Expected blocked report selected action orders."
Assert-True ($blockedReport.blockedCount -eq 2) "Expected two blocked actions without confirmations."
Assert-True ($blockedReport.plannedCount -eq 1) "Expected one planned action without confirmations."
Assert-True (@(@($blockedReport.actions)[0].blockReasons) -contains "operator approval not confirmed") "Storage expansion run_live action should be blocked on operator approval."
Assert-Contains $blockedMarkdown "Source counts: passed=36 pending=6 total=42 checks=42" "blocked invocation markdown"
Assert-Contains $blockedMarkdown "- Selected action orders: 1, 2, 3" "blocked invocation markdown"
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

$plannedReport = Read-Utf8Text $plannedJsonOutputPath | ConvertFrom-Json
$plannedMarkdown = Read-Utf8Text $plannedMarkdownOutputPath
$plannedActions = @($plannedReport.actions)

Assert-True ($plannedReport.result -eq "planned") "Expected planned result with confirmations."
Assert-True ($plannedReport.blockedCount -eq 0) "Expected no blocked actions with confirmations."
Assert-True ($plannedReport.plannedCount -eq 3) "Expected three planned actions with confirmations."
Assert-True ((@($plannedReport.selectedActionOrders) -join ",") -eq "1,2,3") "Expected planned report selected action orders."
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

$unsafeReport = Read-Utf8Text $unsafeJsonOutputPath | ConvertFrom-Json
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

$invalidReport = Read-Utf8Text $invalidJsonOutputPath | ConvertFrom-Json
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

$selectedReport = Read-Utf8Text $selectedJsonOutputPath | ConvertFrom-Json
Assert-True ($selectedReport.result -eq "planned") "Expected selected action result to be planned."
Assert-True ($selectedReport.selectedActionCount -eq 1) "Expected one selected action."
Assert-True ((@($selectedReport.selectedActionOrders) -join ",") -eq "2") "Expected selected report action order scope."
Assert-True (@($selectedReport.actions)[0].order -eq 2) "Expected action order 2 to be selected."

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanPath $fixturePath `
    -JsonOutputPath $githubCliJsonOutputPath `
    -MarkdownOutputPath $githubCliMarkdownOutputPath `
    -ActionOrder 2 `
    -KubeconfigSecretConfirmed `
    -ConfirmOperatorApproval `
    -BackupTimestamp "20260615T010203Z" `
    -GitHubCliPath $fakeGitHubCliPath `
    -Execute | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "invoke-operations-evidence-plan.ps1 GitHubCliPath execute check failed with exit code $LASTEXITCODE."
}

$githubCliReport = Read-Utf8Text $githubCliJsonOutputPath | ConvertFrom-Json
$githubCliAction = @($githubCliReport.actions)[0]
Assert-True ($githubCliReport.result -eq "executed") "Expected GitHubCliPath execution result."
Assert-True ($githubCliReport.githubCliPath -eq $fakeGitHubCliPath) "Expected GitHubCliPath report path."
Assert-True ($githubCliReport.githubCliExecutionSource -eq $fakeGitHubCliPath) "Expected GitHubCliPath execution source."
Assert-True ($githubCliAction.status -eq "executed") "Expected GitHubCliPath action execution status."
Assert-True ($githubCliAction.exitCode -eq 0) "Expected fake GitHub CLI exit code."
Assert-Contains (($githubCliAction.output | ConvertTo-Json -Depth 4)) "fake gh workflow run kubernetes-dr-finalizer-ci.yml" "GitHubCliPath fake output"
$githubCliMarkdown = Read-Utf8Text $githubCliMarkdownOutputPath
Assert-Contains $githubCliMarkdown "GitHub CLI path:" "GitHubCliPath markdown"

$previousGhToken = $env:GH_TOKEN
$previousGitHubToken = $env:GITHUB_TOKEN
try {
    $env:GH_TOKEN = ""
    $env:GITHUB_TOKEN = ""
    & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -PlanPath $fixturePath `
        -JsonOutputPath $githubApiBlockedJsonOutputPath `
        -MarkdownOutputPath $githubApiBlockedMarkdownOutputPath `
        -ActionOrder 3 `
        -UseGitHubApi `
        -GitHubRepository "example/osmu" `
        -GitHubRef "main" `
        -Execute | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "invoke-operations-evidence-plan.ps1 GitHub API blocked check failed with exit code $LASTEXITCODE."
    }
}
finally {
    $env:GH_TOKEN = $previousGhToken
    $env:GITHUB_TOKEN = $previousGitHubToken
}

$githubApiBlockedReport = Read-Utf8Text $githubApiBlockedJsonOutputPath | ConvertFrom-Json
$githubApiBlockedAction = @($githubApiBlockedReport.actions)[0]
Assert-True ($githubApiBlockedReport.result -eq "blocked") "Expected GitHub API execution to block without token."
Assert-True ($githubApiBlockedReport.useGitHubApi -eq $true) "Expected GitHub API execution mode in report."
Assert-True ($githubApiBlockedReport.githubRepository -eq "example/osmu") "Expected explicit GitHub repository in report."
Assert-True ($githubApiBlockedReport.githubRef -eq "main") "Expected GitHub ref in report."
Assert-True (@($githubApiBlockedAction.blockReasons) -contains "GH_TOKEN or GITHUB_TOKEN not set for API dispatch") "Expected missing token block reason."
Assert-True ($githubApiBlockedAction.status -eq "blocked") "Expected GitHub API action to be blocked without token."

Write-Host "Operations evidence plan invocation verified."
Write-Host "Blocked report: $blockedJsonOutputPath"
Write-Host "Planned report: $plannedJsonOutputPath"
Write-Host "Unsafe report: $unsafeJsonOutputPath"
Write-Host "Invalid report: $invalidJsonOutputPath"
Write-Host "Selected report: $selectedJsonOutputPath"
