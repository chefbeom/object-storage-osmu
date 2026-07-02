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

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
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
$unsafeJsonPath = Join-Path $resolvedOutputDirectory "unsafe-preflight.json"
$unsafeMarkdownPath = Join-Path $resolvedOutputDirectory "unsafe-preflight.md"
$invalidJsonPath = Join-Path $resolvedOutputDirectory "invalid-preflight.json"
$invalidMarkdownPath = Join-Path $resolvedOutputDirectory "invalid-preflight.md"
$githubCliJsonPath = Join-Path $resolvedOutputDirectory "github-cli-path-preflight.json"
$githubCliMarkdownPath = Join-Path $resolvedOutputDirectory "github-cli-path-preflight.md"
$apiFallbackJsonPath = Join-Path $resolvedOutputDirectory "api-fallback-preflight.json"
$apiFallbackMarkdownPath = Join-Path $resolvedOutputDirectory "api-fallback-preflight.md"
$defaultBranchMissingUnblockPlanPath = Join-Path $resolvedOutputDirectory "default-branch-missing-unblock-plan.json"
$defaultBranchMissingJsonPath = Join-Path $resolvedOutputDirectory "default-branch-missing-preflight.json"
$defaultBranchMissingMarkdownPath = Join-Path $resolvedOutputDirectory "default-branch-missing-preflight.md"
$defaultBranchUnavailableJsonPath = Join-Path $resolvedOutputDirectory "default-branch-unavailable-preflight.json"
$defaultBranchUnavailableMarkdownPath = Join-Path $resolvedOutputDirectory "default-branch-unavailable-preflight.md"
$gitRefJsonPath = Join-Path $resolvedOutputDirectory "git-ref-safety-preflight.json"
$gitRefMarkdownPath = Join-Path $resolvedOutputDirectory "git-ref-safety-preflight.md"
$fakeGitHubCliDirectory = Join-Path $resolvedOutputDirectory "fake-github-cli"
$fakeGitHubCliPath = Join-Path $fakeGitHubCliDirectory "gh.cmd"
New-Item -ItemType Directory -Force -Path $fakeGitHubCliDirectory | Out-Null
Set-Content -LiteralPath $fakeGitHubCliPath -Value "@echo off`r`necho fake gh %*`r`nexit /b 0`r`n" -Encoding ASCII
$env:GITHUB_REPOSITORY = "chefbeom/object-storage-osmu"

Write-JsonFixture $unblockPlanPath ([ordered]@{
    formatVersion = "osmu.operations-invocation-unblock-plan.v1"
    generatedAt = "2026-06-16T08:00:00+09:00"
    result = "action-required"
    sourceInvocationReport = ".osmu-run/latest-operations-evidence-plan-invocation.json"
    sourceResult = "blocked"
    sourceSummary = "passed=36 pending=6"
    sourcePassedCount = 36
    sourcePendingCount = 6
    sourceTotalCount = 42
    sourceCheckCount = 42
    selectedActionCount = 4
    plannedCount = 1
    blockedCount = 3
    failedCount = 0
    needsKubeconfigSecretConfirmation = $true
    needsOperatorApprovalConfirmation = $true
    requiredPlaceholderCount = 1
    ambiguousRepeatedPlaceholderCount = 0
    blockedActionOrders = @(1, 2, 3)
    plannedActionOrders = @(4)
    confirmedPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,3 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"
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
            blockReasons = @("operator approval not confirmed", "kubeconfig secret not confirmed")
            unresolvedPlaceholders = @()
            requiresOperatorApproval = $true
            requiresKubeconfigSecret = $true
            needsOperatorApprovalConfirmation = $true
            needsKubeconfigSecretConfirmation = $true
            requiredInputs = @()
            ambiguousRepeatedPlaceholders = $false
            planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval"
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
                    workflowInputs = @("backup_timestamp")
                    occurrenceCount = 1
                    ambiguousRepeatedPlaceholder = $false
                    note = "Provide a concrete value before planning or executing this action."
                }
            )
            ambiguousRepeatedPlaceholders = $false
            planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 2 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"
        },
        [ordered]@{
            order = 3
            name = "Enterprise auth target smoke evidence"
            category = "enterprise-auth"
            actionType = "operator-remediation"
            evidencePath = ".osmu-run/latest-enterprise-auth-smoke.json"
            status = "blocked"
            commandMode = "Workflow"
            command = "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f require_oidc=true -f require_ldap=true -f fail_if_not_passed=true"
            blockReasons = @("operator approval not confirmed")
            unresolvedPlaceholders = @()
            requiresOperatorApproval = $true
            requiresKubeconfigSecret = $false
            needsOperatorApprovalConfirmation = $true
            needsKubeconfigSecretConfirmation = $false
            requiredInputs = @()
            ambiguousRepeatedPlaceholders = $false
            planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 3 -ConfirmOperatorApproval"
        },
        [ordered]@{
            order = 4
            name = "Container scan/SBOM evidence"
            category = "security-hardening"
            actionType = "operator-remediation"
            evidencePath = ".osmu-run/latest-container-security-evidence.json"
            status = "planned"
            commandMode = "Workflow"
            command = "gh workflow run container-security-ci.yml"
            blockReasons = @()
            unresolvedPlaceholders = @()
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $false
            needsOperatorApprovalConfirmation = $false
            needsKubeconfigSecretConfirmation = $false
            requiredInputs = @()
            ambiguousRepeatedPlaceholders = $false
            planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 4"
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

$missingReport = Read-Utf8Text $missingJsonPath | ConvertFrom-Json
$missingMarkdown = Read-Utf8Text $missingMarkdownPath
Assert-Equal $missingReport.formatVersion "osmu.operations-dispatch-preflight.v1" "missing formatVersion"
Assert-Equal $missingReport.result "action-required" "missing result"
Assert-Equal $missingReport.selectedActionCount 4 "missing selected action count"
Assert-Equal $missingReport.githubRepository "chefbeom/object-storage-osmu" "missing GitHub repository"
Assert-Equal $missingReport.readyActionCount 1 "missing ready action count"
Assert-Equal $missingReport.blockedActionCount 3 "missing blocked action count"
Assert-Equal $missingReport.readyActionOrders[0] 4 "missing ready action order"
Assert-Equal $missingReport.blockedActionOrders[0] 1 "missing blocked action order"
Assert-Contains $missingReport.readySubsetPlanCommand "-ActionOrder 4" "missing ready subset plan command"
Assert-Contains $missingReport.readySubsetExecuteCommand "-Execute" "missing ready subset execute command"
Assert-Equal $missingReport.missingInputCount 1 "missing input count"
Assert-Equal $missingReport.unsafeInputCount 0 "missing unsafe input count"
Assert-Equal $missingReport.invalidInputCount 0 "missing invalid input count"
Assert-True ($missingReport.failedCheckCount -ge 3) "expected missing preflight failures"
Assert-Contains ($missingReport.checks | ConvertTo-Json -Depth 8) "KUBECONFIG_SECRET_CONFIRMED" "missing checks"
Assert-Equal @($missingReport.inputTemplates).Count 4 "missing input template count"
$missingDrTemplate = @($missingReport.inputTemplates | Where-Object { $_.actionOrder -eq 2 })[0]
Assert-Equal $missingDrTemplate.workflow "kubernetes-dr-finalizer-ci.yml" "missing DR template workflow"
Assert-Equal $missingDrTemplate.missingInputCount 1 "missing DR template missing input count"
Assert-Equal $missingDrTemplate.unsafeInputCount 0 "missing DR template unsafe input count"
Assert-Equal $missingDrTemplate.invalidInputCount 0 "missing DR template invalid input count"
Assert-True (-not $missingDrTemplate.readyToDispatch) "missing DR template should not be ready to dispatch"
Assert-True (@($missingDrTemplate.requiredSecrets) -contains "OSMU_ADMIN_PASSWORD") "missing DR template admin password secret"
Assert-True (@($missingDrTemplate.workflowInputNames) -contains "backup_timestamp") "missing DR template workflow input summary"
Assert-Equal $missingDrTemplate.dispatchUrl "https://github.com/chefbeom/object-storage-osmu/actions/workflows/kubernetes-dr-finalizer-ci.yml" "missing DR template dispatch URL"
$missingDrWorkflow = @($missingReport.workflowFiles | Where-Object { $_.actionOrder -eq 2 })[0]
Assert-Equal $missingDrWorkflow.defaultBranchRef "origin/main" "missing DR workflow default branch ref"
Assert-True $missingDrWorkflow.existsOnDefaultBranch "missing DR workflow should exist on default branch"
Assert-True (@($missingDrTemplate.missingInputParameters) -contains "BackupTimestamp") "missing DR template missing parameter summary"
Assert-Equal @($missingDrTemplate.unsafeInputParameters).Count 0 "missing DR template unsafe parameter summary"
Assert-Equal @($missingDrTemplate.invalidInputParameters).Count 0 "missing DR template invalid parameter summary"
Assert-Equal $missingDrTemplate.inputs[0].valueTemplate "<YYYYMMDDTHHMMSSZ>" "missing DR template input value template"
Assert-True (@($missingDrTemplate.inputs[0].workflowInputs) -contains "backup_timestamp") "missing DR template workflow input mapping"
Assert-True (-not $missingDrTemplate.inputs[0].supplied) "missing DR template input should be missing"
$missingContainerTemplate = @($missingReport.inputTemplates | Where-Object { $_.actionOrder -eq 4 })[0]
Assert-True $missingContainerTemplate.readyToDispatch "missing container template should be ready to dispatch"
Assert-Equal @($missingContainerTemplate.requiredSecrets).Count 0 "missing container template should not carry blank required secrets"
Assert-Equal @($missingContainerTemplate.operatorChecklist).Count 0 "missing container template should not carry blank checklist items"
Assert-Equal $missingContainerTemplate.dispatchUrl "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "missing container template dispatch URL"
$missingContainerWorkflow = @($missingReport.workflowFiles | Where-Object { $_.actionOrder -eq 4 })[0]
Assert-Equal $missingContainerWorkflow.dispatchUrl "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "missing container workflow dispatch URL"
Assert-Contains $missingMarkdown "Result: action-required" "missing markdown"
Assert-Contains $missingMarkdown "## Input Templates" "missing markdown input templates section"
Assert-Contains $missingMarkdown "## Workflow Dispatch URLs" "missing markdown workflow dispatch URL section"
Assert-Contains $missingMarkdown "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "missing markdown container dispatch URL"
Assert-Contains $missingMarkdown "Ready actions: 1 (4)" "missing markdown ready action count"
Assert-Contains $missingMarkdown "Ready subset plan command" "missing markdown ready subset command"
Assert-Contains $missingMarkdown "action 2 - Kubernetes DR finalizer live evidence" "missing markdown DR template"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -UnblockPlanPath $unblockPlanPath `
    -JsonOutputPath $githubCliJsonPath `
    -MarkdownOutputPath $githubCliMarkdownPath `
    -ActionOrder 4 `
    -GitHubCliPath $fakeGitHubCliPath `
    -CheckGitHubCli | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-dispatch-preflight.ps1 GitHubCliPath fixture failed with exit code $LASTEXITCODE."
}

$githubCliReport = Read-Utf8Text $githubCliJsonPath | ConvertFrom-Json
$githubCliMarkdown = Read-Utf8Text $githubCliMarkdownPath
Assert-Equal $githubCliReport.result "ready" "GitHubCliPath result"
Assert-Equal $githubCliReport.githubCliPath $fakeGitHubCliPath "GitHubCliPath report path"
Assert-Contains $githubCliReport.readyPlanCommand "-GitHubCliPath" "GitHubCliPath ready plan command"
Assert-Contains $githubCliReport.readySubsetPlanCommand "-GitHubCliPath" "GitHubCliPath ready subset plan command"
Assert-Equal $githubCliReport.githubRepository "chefbeom/object-storage-osmu" "GitHubCliPath repository"
Assert-Contains $githubCliReport.executeCommand "-GitHubCliPath" "GitHubCliPath execute command"
Assert-Contains (($githubCliReport.checks | ConvertTo-Json -Depth 8)) "explicit path" "GitHubCliPath check message"
Assert-Contains $githubCliMarkdown "GitHub CLI path:" "GitHubCliPath markdown"

$previousPath = $env:Path
$previousGhToken = $env:GH_TOKEN
try {
    $gitCommand = Get-Command git -ErrorAction Stop
    $gitDirectory = Split-Path -Parent ([string] $gitCommand.Source)
    $env:Path = "$gitDirectory;$env:SystemRoot\System32;$env:SystemRoot"
    $env:GH_TOKEN = "fixture-token"
    & (Join-Path $PSHOME "powershell.exe") -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -UnblockPlanPath $unblockPlanPath `
        -JsonOutputPath $apiFallbackJsonPath `
        -MarkdownOutputPath $apiFallbackMarkdownPath `
        -ActionOrder 4 `
        -CheckGitHubCli | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "write-operations-dispatch-preflight.ps1 API fallback fixture failed with exit code $LASTEXITCODE."
    }
}
finally {
    $env:Path = $previousPath
    if ($null -eq $previousGhToken) {
        Remove-Item Env:\GH_TOKEN -ErrorAction SilentlyContinue
    }
    else {
        $env:GH_TOKEN = $previousGhToken
    }
}

$apiFallbackReport = Read-Utf8Text $apiFallbackJsonPath | ConvertFrom-Json
$apiFallbackMarkdown = Read-Utf8Text $apiFallbackMarkdownPath
Assert-Equal $apiFallbackReport.result "ready" "API fallback result"
Assert-True $apiFallbackReport.githubApiTokenPresent "API fallback should detect token"
Assert-True $apiFallbackReport.githubApiDispatchAvailable "API fallback should be available"
Assert-True (-not $apiFallbackReport.githubCliAvailableForDispatch) "API fallback should not mark GitHub CLI available"
Assert-True ([string]::IsNullOrWhiteSpace($apiFallbackReport.executeCommand)) "API fallback should suppress gh execute command"
Assert-Contains $apiFallbackReport.apiExecuteCommand "-UseGitHubApi" "API fallback execute command"
Assert-Contains $apiFallbackReport.readySubsetApiExecuteCommand "-UseGitHubApi" "API fallback ready subset API command"
Assert-Contains (($apiFallbackReport.checks | ConvertTo-Json -Depth 8)) "GITHUB_API_DISPATCH_AVAILABLE" "API fallback check code"
Assert-Contains (($apiFallbackReport.checks | ConvertTo-Json -Depth 8)) "REST API dispatch is available" "API fallback CLI warning"
Assert-Contains $apiFallbackMarkdown "GitHub API dispatch available: True" "API fallback markdown"

Write-JsonFixture $defaultBranchMissingUnblockPlanPath ([ordered]@{
    formatVersion = "osmu.operations-invocation-unblock-plan.v1"
    generatedAt = "2026-06-16T08:00:00+09:00"
    result = "ready"
    sourceInvocationReport = ".osmu-run/latest-operations-evidence-plan-invocation.json"
    sourceResult = "planned"
    sourceSummary = "passed=36 pending=6"
    sourcePassedCount = 36
    sourcePendingCount = 6
    sourceTotalCount = 42
    sourceCheckCount = 42
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    failedCount = 0
    needsKubeconfigSecretConfirmation = $false
    needsOperatorApprovalConfirmation = $false
    requiredPlaceholderCount = 0
    ambiguousRepeatedPlaceholderCount = 0
    blockedActionOrders = @()
    plannedActionOrders = @(20)
    confirmedPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 20"
    blockedOnlyPlanCommand = ""
    plannedOnlyCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 20"
    decisionRule = "Resolve placeholders and confirmations before execution."
    actions = @(
        [ordered]@{
            order = 20
            name = "Branch-only workflow evidence"
            category = "operations"
            actionType = "operator-remediation"
            evidencePath = ".osmu-run/latest-branch-only-evidence.json"
            status = "planned"
            commandMode = "Workflow"
            command = "gh workflow run manual-chargeback-closeout-evidence.yml"
            blockReasons = @()
            unresolvedPlaceholders = @()
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $false
            needsOperatorApprovalConfirmation = $false
            needsKubeconfigSecretConfirmation = $false
            requiredInputs = @()
            ambiguousRepeatedPlaceholders = $false
            planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 20"
        }
    )
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -UnblockPlanPath $defaultBranchMissingUnblockPlanPath `
    -JsonOutputPath $defaultBranchMissingJsonPath `
    -MarkdownOutputPath $defaultBranchMissingMarkdownPath `
    -GitHubRepository "chefbeom/object-storage-osmu" `
    -DefaultBranchRef "origin/main" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-dispatch-preflight.ps1 default branch missing fixture failed with exit code $LASTEXITCODE."
}

$defaultBranchMissingReport = Read-Utf8Text $defaultBranchMissingJsonPath | ConvertFrom-Json
$defaultBranchMissingMarkdown = Read-Utf8Text $defaultBranchMissingMarkdownPath
Assert-Equal $defaultBranchMissingReport.defaultBranchRef "origin/main" "default branch ref"
Assert-Equal $defaultBranchMissingReport.workflowFiles[0].workflow "manual-chargeback-closeout-evidence.yml" "default branch missing workflow"
Assert-True $defaultBranchMissingReport.workflowFiles[0].exists "branch-only workflow should exist locally"
Assert-Contains (($defaultBranchMissingReport.checks | ConvertTo-Json -Depth 8)) "DEFAULT_BRANCH_WORKFLOW_FILES_PRESENT" "default branch check code"
if ($defaultBranchMissingReport.defaultBranchRefAvailable) {
    Assert-Equal $defaultBranchMissingReport.result "action-required" "default branch missing result"
    Assert-True (-not $defaultBranchMissingReport.workflowFiles[0].existsOnDefaultBranch) "branch-only workflow should be missing on default branch"
    Assert-Contains (($defaultBranchMissingReport.checks | ConvertTo-Json -Depth 8)) "workflow_dispatch requires" "default branch check message"
    Assert-Contains $defaultBranchMissingMarkdown "defaultBranchFile=missing" "default branch markdown"
}
else {
    Assert-Equal $defaultBranchMissingReport.result "ready" "default branch unavailable result"
    Assert-True $defaultBranchMissingReport.workflowFiles[0].existsOnDefaultBranch "branch-only workflow should use local presence when default branch ref is unavailable"
    Assert-Contains (($defaultBranchMissingReport.checks | ConvertTo-Json -Depth 8)) "is not available in this checkout" "default branch unavailable check message"
    Assert-Contains $defaultBranchMissingMarkdown "defaultBranchFile=present" "default branch unavailable markdown"
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -UnblockPlanPath $unblockPlanPath `
    -JsonOutputPath $defaultBranchUnavailableJsonPath `
    -MarkdownOutputPath $defaultBranchUnavailableMarkdownPath `
    -ActionOrder 4 `
    -GitHubRepository "chefbeom/object-storage-osmu" `
    -DefaultBranchRef "refs/remotes/origin/__missing-default-branch-ref-for-ci-test" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-dispatch-preflight.ps1 default branch unavailable fixture failed with exit code $LASTEXITCODE."
}

$defaultBranchUnavailableReport = Read-Utf8Text $defaultBranchUnavailableJsonPath | ConvertFrom-Json
$defaultBranchUnavailableMarkdown = Read-Utf8Text $defaultBranchUnavailableMarkdownPath
Assert-Equal $defaultBranchUnavailableReport.result "ready" "default branch unavailable result"
Assert-True (-not $defaultBranchUnavailableReport.defaultBranchRefAvailable) "default branch unavailable ref flag"
Assert-Equal $defaultBranchUnavailableReport.workflowFiles[0].workflow "container-security-ci.yml" "default branch unavailable workflow"
Assert-True $defaultBranchUnavailableReport.workflowFiles[0].exists "default branch unavailable workflow should exist locally"
Assert-True (-not $defaultBranchUnavailableReport.workflowFiles[0].defaultBranchRefAvailable) "default branch unavailable workflow ref flag"
Assert-True $defaultBranchUnavailableReport.workflowFiles[0].existsOnDefaultBranch "default branch unavailable should use local workflow presence"
Assert-Contains (($defaultBranchUnavailableReport.checks | ConvertTo-Json -Depth 8)) "is not available in this checkout" "default branch unavailable check message"
Assert-Contains $defaultBranchUnavailableMarkdown "defaultBranchFile=present" "default branch unavailable markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -UnblockPlanPath $unblockPlanPath `
    -JsonOutputPath $gitRefJsonPath `
    -MarkdownOutputPath $gitRefMarkdownPath `
    -ActionOrder 4 `
    -GitHubRepository "chefbeom/object-storage-osmu" `
    -GitHubRef "main" `
    -CheckGitRefSafety | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-dispatch-preflight.ps1 git ref safety fixture failed with exit code $LASTEXITCODE."
}

$gitRefReport = Read-Utf8Text $gitRefJsonPath | ConvertFrom-Json
$gitRefMarkdown = Read-Utf8Text $gitRefMarkdownPath
Assert-True $gitRefReport.gitRefSafety.checked "git ref safety should be checked"
Assert-True (-not [string]::IsNullOrWhiteSpace($gitRefReport.gitRefSafety.status)) "git ref safety status should be populated"
Assert-True (-not [string]::IsNullOrWhiteSpace($gitRefReport.gitRefSafety.githubRef)) "git ref safety githubRef should be populated"
Assert-Contains (($gitRefReport.checks | ConvertTo-Json -Depth 8)) "GITHUB_REF_SYNC" "git ref safety check code"
Assert-Contains $gitRefMarkdown "## Git Ref Safety" "git ref safety markdown section"
Assert-Contains $gitRefMarkdown "Suggested push command" "git ref safety markdown push command"
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

$readyReport = Read-Utf8Text $readyJsonPath | ConvertFrom-Json
$readyMarkdown = Read-Utf8Text $readyMarkdownPath
Assert-Equal $readyReport.result "ready" "ready result"
Assert-Equal $readyReport.failedCheckCount 0 "ready failed checks"
Assert-Equal $readyReport.readyActionCount 4 "ready action count"
Assert-Equal $readyReport.blockedActionCount 0 "ready blocked action count"
Assert-Equal $readyReport.readyActionOrders[0] 1 "ready first action order"
Assert-Equal $readyReport.readyActionOrders[3] 4 "ready last action order"
Assert-Contains $readyReport.readySubsetPlanCommand "-ActionOrder 1,2,3,4" "ready subset plan command"
Assert-Equal $readyReport.githubRepository "chefbeom/object-storage-osmu" "ready GitHub repository"
Assert-Equal $readyReport.sourcePassedCount 36 "ready source passed count"
Assert-Equal $readyReport.sourcePendingCount 6 "ready source pending count"
Assert-Equal $readyReport.sourceTotalCount 42 "ready source total count"
Assert-Equal $readyReport.sourceCheckCount 42 "ready source check count"
Assert-Contains $readyReport.readySubsetExecuteCommand "-Execute" "ready subset execute command"
Assert-Equal $readyReport.missingInputCount 0 "ready missing inputs"
Assert-Equal $readyReport.unsafeInputCount 0 "ready unsafe inputs"
Assert-Equal $readyReport.invalidInputCount 0 "ready invalid inputs"
Assert-True $readyReport.needsKubeconfigSecretConfirmation "ready kubeconfig requirement"
Assert-True $readyReport.needsOperatorApprovalConfirmation "ready approval requirement"
Assert-Contains $readyReport.readyPlanCommand "-KubeconfigSecretConfirmed" "ready plan command"
Assert-Contains $readyReport.readyPlanCommand "-ConfirmOperatorApproval" "ready plan command"
Assert-Contains $readyReport.readyPlanCommand "-BackupTimestamp 20260616T010203Z" "ready plan command"
Assert-Contains $readyReport.executeCommand "-Execute" "ready execute command"
Assert-True (@($readyReport.workflowFiles | Where-Object { -not $_.exists }).Count -eq 0) "expected workflow files to exist"
Assert-True (@($readyReport.requiredGitHubSecrets).Count -gt 0) "expected workflow secret references"
Assert-True (@($readyReport.requiredGitHubSecrets) -contains "OSMU_KUBECONFIG_BASE64") "expected kubeconfig secret"
Assert-True (@($readyReport.requiredGitHubSecrets) -contains "OSMU_ADMIN_PASSWORD") "expected admin password secret for confirmed DR restore"
Assert-True (@($readyReport.requiredGitHubSecrets) -contains "OSMU_ENTERPRISE_AUTH_ADMIN_PASSWORD") "expected enterprise auth admin password secret"
Assert-True (@($readyReport.requiredGitHubSecrets) -contains "OSMU_ENTERPRISE_AUTH_LDAP_LOGIN_ID") "expected enterprise auth LDAP login secret"
Assert-True (@($readyReport.requiredGitHubSecrets) -contains "OSMU_ENTERPRISE_AUTH_LDAP_PASSWORD") "expected enterprise auth LDAP password secret"
Assert-True (@($readyReport.requiredGitHubSecrets) -contains "OSMU_ENTERPRISE_AUTH_OIDC_CALLBACK_CODE") "expected enterprise auth OIDC code secret"
Assert-True (@($readyReport.requiredGitHubSecrets) -contains "OSMU_ENTERPRISE_AUTH_OIDC_CALLBACK_STATE") "expected enterprise auth OIDC state secret"
Assert-True (@($readyReport.workflowFiles | Where-Object { $_.dispatchUrl -like "https://github.com/chefbeom/object-storage-osmu/actions/workflows/*" }).Count -eq 4) "expected dispatch URLs for every workflow file"
$readyDrTemplate = @($readyReport.inputTemplates | Where-Object { $_.actionOrder -eq 2 })[0]
Assert-Equal $readyDrTemplate.missingInputCount 0 "ready DR template missing input count"
Assert-Equal $readyDrTemplate.unsafeInputCount 0 "ready DR template unsafe input count"
Assert-Equal $readyDrTemplate.invalidInputCount 0 "ready DR template invalid input count"
Assert-True $readyDrTemplate.readyToDispatch "ready DR template should be ready to dispatch"
Assert-Equal @($readyDrTemplate.missingInputParameters).Count 0 "ready DR template missing parameter summary"
Assert-True (@($readyDrTemplate.workflowInputNames) -contains "backup_timestamp") "ready DR template workflow input summary"
Assert-True $readyDrTemplate.inputs[0].supplied "ready DR template input should be supplied"
Assert-Equal $readyDrTemplate.inputs[0].valuePreview "20260616T010203Z" "ready DR template input preview"
Assert-True (@($readyDrTemplate.inputs[0].workflowInputs) -contains "backup_timestamp") "ready DR template workflow input mapping"
Assert-True (@($readyDrTemplate.operatorChecklist) -contains "Ensure GitHub secret OSMU_ADMIN_PASSWORD is configured") "ready DR template checklist should mention admin password secret"
$storageWorkflow = @($readyReport.workflowFiles | Where-Object { $_.actionOrder -eq 1 })[0]
$drWorkflow = @($readyReport.workflowFiles | Where-Object { $_.actionOrder -eq 2 })[0]
$enterpriseAuthWorkflow = @($readyReport.workflowFiles | Where-Object { $_.actionOrder -eq 3 })[0]
Assert-True (@($storageWorkflow.requiredSecrets) -contains "OSMU_KUBECONFIG_BASE64") "storage expansion workflow should require kubeconfig"
Assert-True (-not (@($storageWorkflow.requiredSecrets) -contains "OSMU_ADMIN_PASSWORD")) "storage expansion workflow should not require admin password unless backend runner actions are selected"
Assert-True (@($drWorkflow.requiredSecrets) -contains "OSMU_ADMIN_PASSWORD") "confirmed DR restore should require admin password"
Assert-True (-not (@($enterpriseAuthWorkflow.requiredSecrets) -contains "OSMU_KUBECONFIG_BASE64")) "enterprise auth workflow should not require kubeconfig"
Assert-True (@($enterpriseAuthWorkflow.requiredSecrets) -contains "OSMU_ENTERPRISE_AUTH_ADMIN_PASSWORD") "enterprise auth workflow should require admin password when run_live=true"
Assert-Contains $readyMarkdown "Result: ready" "ready markdown"
Assert-Contains $readyMarkdown "Source counts: passed=36 pending=6 total=42 checks=42" "ready markdown source counts"
Assert-Contains $readyMarkdown "Ready actions: 4 (1,2,3,4)" "ready markdown action count"
Assert-Contains $readyMarkdown "Ready subset execute command" "ready markdown ready subset execute command"
Assert-Contains $readyMarkdown "readyToDispatch=True" "ready markdown template readiness"
Assert-Contains $readyMarkdown "workflowInputs=backup_timestamp" "ready markdown workflow input summary"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -UnblockPlanPath $unblockPlanPath `
    -JsonOutputPath $unsafeJsonPath `
    -MarkdownOutputPath $unsafeMarkdownPath `
    -KubeconfigSecretConfirmed `
    -ConfirmOperatorApproval `
    -BackupTimestamp "20260616T010203Z | Write-Host unsafe" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-dispatch-preflight.ps1 unsafe fixture failed with exit code $LASTEXITCODE."
}

$unsafeReport = Read-Utf8Text $unsafeJsonPath | ConvertFrom-Json
$unsafeMarkdown = Read-Utf8Text $unsafeMarkdownPath
Assert-Equal $unsafeReport.result "action-required" "unsafe result"
Assert-Equal $unsafeReport.unsafeInputCount 1 "unsafe input count"
Assert-True ($unsafeReport.failedCheckCount -ge 1) "unsafe preflight should fail"
Assert-True ([string]::IsNullOrWhiteSpace($unsafeReport.readyPlanCommand)) "unsafe ready plan command should be blank"
Assert-Contains ($unsafeReport.checks | ConvertTo-Json -Depth 8) "SAFE_INPUT_VALUES" "unsafe checks"
Assert-Contains $unsafeMarkdown "Unsafe inputs: 1" "unsafe markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -UnblockPlanPath $unblockPlanPath `
    -JsonOutputPath $invalidJsonPath `
    -MarkdownOutputPath $invalidMarkdownPath `
    -KubeconfigSecretConfirmed `
    -ConfirmOperatorApproval `
    -BackupTimestamp "not-a-timestamp" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-dispatch-preflight.ps1 invalid fixture failed with exit code $LASTEXITCODE."
}

$invalidReport = Read-Utf8Text $invalidJsonPath | ConvertFrom-Json
$invalidMarkdown = Read-Utf8Text $invalidMarkdownPath
Assert-Equal $invalidReport.result "action-required" "invalid result"
Assert-Equal $invalidReport.invalidInputCount 1 "invalid input count"
Assert-True ($invalidReport.failedCheckCount -ge 1) "invalid preflight should fail"
Assert-True ([string]::IsNullOrWhiteSpace($invalidReport.readyPlanCommand)) "invalid ready plan command should be blank"
Assert-Contains ($invalidReport.checks | ConvertTo-Json -Depth 8) "KNOWN_INPUT_VALUE_SHAPES" "invalid checks"
Assert-Contains $invalidMarkdown "Invalid inputs: 1" "invalid markdown"

Write-Host "Operations dispatch preflight verified."
Write-Host "Missing report: $missingJsonPath"
Write-Host "Ready report: $readyJsonPath"
Write-Host "Git ref safety report: $gitRefJsonPath"
Write-Host "Unsafe report: $unsafeJsonPath"
Write-Host "Invalid report: $invalidJsonPath"
