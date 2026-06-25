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
$unsafeJsonPath = Join-Path $resolvedOutputDirectory "unsafe-preflight.json"
$unsafeMarkdownPath = Join-Path $resolvedOutputDirectory "unsafe-preflight.md"
$invalidJsonPath = Join-Path $resolvedOutputDirectory "invalid-preflight.json"
$invalidMarkdownPath = Join-Path $resolvedOutputDirectory "invalid-preflight.md"

Write-JsonFixture $unblockPlanPath ([ordered]@{
    formatVersion = "osmu.operations-invocation-unblock-plan.v1"
    generatedAt = "2026-06-16T08:00:00+09:00"
    result = "action-required"
    sourceInvocationReport = ".osmu-run/latest-operations-evidence-plan-invocation.json"
    sourceResult = "blocked"
    sourceSummary = "passed=36 pending=6"
    selectedActionCount = 3
    plannedCount = 0
    blockedCount = 3
    failedCount = 0
    needsKubeconfigSecretConfirmation = $true
    needsOperatorApprovalConfirmation = $true
    requiredPlaceholderCount = 1
    ambiguousRepeatedPlaceholderCount = 0
    blockedActionOrders = @(1, 2, 3)
    plannedActionOrders = @()
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
Assert-Equal $missingReport.selectedActionCount 3 "missing selected action count"
Assert-Equal $missingReport.missingInputCount 1 "missing input count"
Assert-Equal $missingReport.unsafeInputCount 0 "missing unsafe input count"
Assert-Equal $missingReport.invalidInputCount 0 "missing invalid input count"
Assert-True ($missingReport.failedCheckCount -ge 3) "expected missing preflight failures"
Assert-Contains ($missingReport.checks | ConvertTo-Json -Depth 8) "KUBECONFIG_SECRET_CONFIRMED" "missing checks"
Assert-Equal @($missingReport.inputTemplates).Count 3 "missing input template count"
$missingDrTemplate = @($missingReport.inputTemplates | Where-Object { $_.actionOrder -eq 2 })[0]
Assert-Equal $missingDrTemplate.workflow "kubernetes-dr-finalizer-ci.yml" "missing DR template workflow"
Assert-Equal $missingDrTemplate.missingInputCount 1 "missing DR template missing input count"
Assert-Equal $missingDrTemplate.unsafeInputCount 0 "missing DR template unsafe input count"
Assert-Equal $missingDrTemplate.invalidInputCount 0 "missing DR template invalid input count"
Assert-True (-not $missingDrTemplate.readyToDispatch) "missing DR template should not be ready to dispatch"
Assert-True (@($missingDrTemplate.requiredSecrets) -contains "OSMU_ADMIN_PASSWORD") "missing DR template admin password secret"
Assert-True (@($missingDrTemplate.workflowInputNames) -contains "backup_timestamp") "missing DR template workflow input summary"
Assert-True (@($missingDrTemplate.missingInputParameters) -contains "BackupTimestamp") "missing DR template missing parameter summary"
Assert-Equal @($missingDrTemplate.unsafeInputParameters).Count 0 "missing DR template unsafe parameter summary"
Assert-Equal @($missingDrTemplate.invalidInputParameters).Count 0 "missing DR template invalid parameter summary"
Assert-Equal $missingDrTemplate.inputs[0].valueTemplate "<YYYYMMDDTHHMMSSZ>" "missing DR template input value template"
Assert-True (@($missingDrTemplate.inputs[0].workflowInputs) -contains "backup_timestamp") "missing DR template workflow input mapping"
Assert-True (-not $missingDrTemplate.inputs[0].supplied) "missing DR template input should be missing"
Assert-Contains $missingMarkdown "Result: action-required" "missing markdown"
Assert-Contains $missingMarkdown "## Input Templates" "missing markdown input templates section"
Assert-Contains $missingMarkdown "action 2 - Kubernetes DR finalizer live evidence" "missing markdown DR template"

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

$unsafeReport = Get-Content -Raw -LiteralPath $unsafeJsonPath | ConvertFrom-Json
$unsafeMarkdown = Get-Content -Raw -LiteralPath $unsafeMarkdownPath
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

$invalidReport = Get-Content -Raw -LiteralPath $invalidJsonPath | ConvertFrom-Json
$invalidMarkdown = Get-Content -Raw -LiteralPath $invalidMarkdownPath
Assert-Equal $invalidReport.result "action-required" "invalid result"
Assert-Equal $invalidReport.invalidInputCount 1 "invalid input count"
Assert-True ($invalidReport.failedCheckCount -ge 1) "invalid preflight should fail"
Assert-True ([string]::IsNullOrWhiteSpace($invalidReport.readyPlanCommand)) "invalid ready plan command should be blank"
Assert-Contains ($invalidReport.checks | ConvertTo-Json -Depth 8) "KNOWN_INPUT_VALUE_SHAPES" "invalid checks"
Assert-Contains $invalidMarkdown "Invalid inputs: 1" "invalid markdown"

Write-Host "Operations dispatch preflight verified."
Write-Host "Missing report: $missingJsonPath"
Write-Host "Ready report: $readyJsonPath"
Write-Host "Unsafe report: $unsafeJsonPath"
Write-Host "Invalid report: $invalidJsonPath"
