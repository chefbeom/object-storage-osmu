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

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-invocation-unblock-plan.ps1"
$blockedInvocationPath = Join-Path $resolvedOutputDirectory "blocked-invocation.json"
$blockedDispatchPreflightPath = Join-Path $resolvedOutputDirectory "blocked-dispatch-preflight.json"
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
    sourcePassedCount = 36
    sourcePendingCount = 6
    sourceTotalCount = 42
    sourceCheckCount = 42
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
            blockReasons = @("operator approval not confirmed", "kubeconfig secret not confirmed")
            unresolvedPlaceholders = @()
            invalidPlaceholders = @()
            requiresOperatorApproval = $true
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
Write-JsonFixture $blockedDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    generatedAt = "2026-06-16T07:31:00+09:00"
    result = "action-required"
    inputTemplates = @(
        [ordered]@{ actionOrder = 1; requiredSecrets = @("OSMU_KUBECONFIG_BASE64") },
        [ordered]@{ actionOrder = 2; requiredSecrets = @("OSMU_KUBECONFIG_BASE64") },
        [ordered]@{ actionOrder = 3; requiredSecrets = @() },
        [ordered]@{ actionOrder = 4; requiredSecrets = @() }
    )
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $blockedInvocationPath `
    -DispatchPreflightReportPath $blockedDispatchPreflightPath `
    -JsonOutputPath $blockedJsonPath `
    -MarkdownOutputPath $blockedMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-invocation-unblock-plan.ps1 blocked fixture failed with exit code $LASTEXITCODE."
}

$blockedReport = Read-Utf8Text $blockedJsonPath | ConvertFrom-Json
$blockedMarkdown = Read-Utf8Text $blockedMarkdownPath
Assert-Equal $blockedReport.formatVersion "osmu.operations-invocation-unblock-plan.v1" "blocked formatVersion"
Assert-Equal $blockedReport.sourcePassedCount 36 "blocked source passed count"
Assert-Equal $blockedReport.sourcePendingCount 6 "blocked source pending count"
Assert-Equal $blockedReport.sourceTotalCount 42 "blocked source total count"
Assert-Equal $blockedReport.sourceCheckCount 42 "blocked source check count"
Assert-Equal $blockedReport.result "action-required" "blocked result"
Assert-Equal $blockedReport.blockedCount 3 "blocked count"
Assert-Equal $blockedReport.plannedCount 1 "planned count"
Assert-Equal $blockedReport.requiredPlaceholderCount 6 "placeholder count"
Assert-Equal $blockedReport.ambiguousRepeatedPlaceholderCount 2 "ambiguous placeholder count"
Assert-Equal $blockedReport.confirmationGroupCount 2 "confirmation group count"
Assert-Equal $blockedReport.requiredInputGroupCount 6 "required input group count"
Assert-True $blockedReport.needsKubeconfigSecretConfirmation "expected kubeconfig confirmation"
Assert-True $blockedReport.needsOperatorApprovalConfirmation "expected operator approval"
Assert-Contains $blockedReport.confirmedPlanCommand "-KubeconfigSecretConfirmed" "confirmed command"
Assert-Contains $blockedReport.confirmedPlanCommand "-ConfirmOperatorApproval" "confirmed command"
Assert-Contains $blockedReport.confirmedPlanCommand "-BackupTimestamp <YYYYMMDDTHHMMSSZ>" "confirmed command"
Assert-Contains $blockedReport.confirmedPlanCommand "-RestoreApiBase <restore-api-base>" "confirmed command"
Assert-Contains $blockedReport.confirmedPlanCommand "-Placeholder '<run-id>=<run-id>'" "confirmed command"
Assert-Contains $blockedReport.plannedOnlyCommand "-ActionOrder 4" "planned-only command"
Assert-True $blockedReport.actions[0].requiresOperatorApproval "storage expansion live action should require operator approval"
Assert-Equal $blockedReport.actions[0].blockReasonCount 2 "storage expansion block reason count"
Assert-Equal $blockedReport.actions[0].requiredInputCount 0 "storage expansion required input count"
Assert-Equal $blockedReport.actions[0].requiredSecretCount 1 "storage expansion required secret count"
Assert-True (@($blockedReport.actions[0].requiredSecrets) -contains "OSMU_KUBECONFIG_BASE64") "storage expansion required secret name"
Assert-Equal $blockedReport.actions[1].blockReasonCount 3 "DR finalizer block reason count"
Assert-Equal $blockedReport.actions[1].unresolvedPlaceholderCount 4 "DR finalizer unresolved placeholder count"
Assert-Equal $blockedReport.actions[1].requiredInputCount 4 "DR finalizer required input count"
Assert-Equal $blockedReport.actions[1].requiredSecretCount 1 "DR finalizer required secret count"
Assert-Equal $blockedReport.actions[2].blockReasonCount 1 "security finalizer block reason count"
Assert-Equal $blockedReport.actions[2].requiredInputCount 2 "security finalizer required input count"
Assert-Equal $blockedReport.actions[2].requiredSecretCount 0 "security finalizer required secret count"
$operatorApprovalGroup = @($blockedReport.confirmationGroups | Where-Object { $_.kind -eq "operator-approval" })[0]
$kubeconfigGroup = @($blockedReport.confirmationGroups | Where-Object { $_.kind -eq "kubeconfig-secret" })[0]
Assert-Equal $operatorApprovalGroup.actionCount 2 "operator approval group action count"
Assert-True (@($operatorApprovalGroup.actionOrders) -contains 1) "operator approval group should include action 1"
Assert-True (@($operatorApprovalGroup.actionOrders) -contains 2) "operator approval group should include action 2"
Assert-Equal $operatorApprovalGroup.flag "-ConfirmOperatorApproval" "operator approval group flag"
Assert-Equal $kubeconfigGroup.actionCount 2 "kubeconfig group action count"
Assert-True (@($kubeconfigGroup.actionOrders) -contains 1) "kubeconfig group should include action 1"
$blockedDrInputs = @($blockedReport.actions[1].requiredInputs)
$backupTimestampInput = @($blockedDrInputs | Where-Object { $_.placeholder -eq "<YYYYMMDDTHHMMSSZ>" })[0]
$restoreApiInput = @($blockedDrInputs | Where-Object { $_.placeholder -eq "<restore-api-base>" })[0]
Assert-True (@($backupTimestampInput.workflowInputs) -contains "backup_timestamp") "expected backup timestamp workflow input mapping"
Assert-True (@($restoreApiInput.workflowInputs) -contains "api_base") "expected restore API workflow input mapping"
Assert-Contains $backupTimestampInput.note "Workflow inputs: backup_timestamp" "backup timestamp note"
$backupTimestampGroup = @($blockedReport.requiredInputGroups | Where-Object { $_.placeholder -eq "<YYYYMMDDTHHMMSSZ>" })[0]
Assert-Equal $backupTimestampGroup.parameter "BackupTimestamp" "backup timestamp group parameter"
Assert-True (@($backupTimestampGroup.actionOrders) -contains 2) "backup timestamp group should include action 2"
Assert-True (@($backupTimestampGroup.workflowInputs) -contains "backup_timestamp") "backup timestamp group workflow input"
Assert-True $blockedReport.actions[2].ambiguousRepeatedPlaceholders "expected repeated placeholders on security finalizer"
$securityRunIdInput = @(@($blockedReport.actions[2].requiredInputs) | Where-Object { $_.placeholder -eq "<run-id>" })[0]
Assert-True (@($securityRunIdInput.workflowInputs) -contains "image_signing_run_id") "expected image signing run id workflow input mapping"
Assert-True (@($securityRunIdInput.workflowInputs) -contains "container_security_run_id") "expected container security run id workflow input mapping"
Assert-Contains $blockedMarkdown "workflow inputs: image_signing_run_id, container_security_run_id" "blocked markdown workflow inputs"
Assert-Contains $blockedMarkdown "[blocked] 1. Storage expansion finalizer live evidence (blockers=2, inputs=0, secrets=1)" "blocked markdown action counts"
Assert-Contains $blockedMarkdown "Required GitHub secrets: OSMU_KUBECONFIG_BASE64" "blocked markdown required secrets"
Assert-Contains $blockedMarkdown "Source counts: passed=36 pending=6 total=42 checks=42" "blocked markdown source counts"
Assert-Contains $blockedMarkdown "## Unblock Groups" "blocked markdown groups"
Assert-Contains $blockedMarkdown "Confirmation: Operator approval" "blocked markdown confirmation group"
Assert-Contains $blockedMarkdown "Input: BackupTimestamp <YYYYMMDDTHHMMSSZ>" "blocked markdown input group"
Assert-Contains $blockedMarkdown "repeated generic placeholders" "blocked markdown"

Write-JsonFixture $readyInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = "2026-06-16T07:30:00+09:00"
    result = "planned"
    sourcePlan = ".osmu-run/latest-operations-evidence-plan.json"
    sourceSummary = "passed=36 pending=6"
    sourcePassedCount = 36
    sourcePendingCount = 6
    sourceTotalCount = 42
    sourceCheckCount = 42
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
    -DispatchPreflightReportPath (Join-Path $resolvedOutputDirectory "missing-dispatch-preflight.json") `
    -JsonOutputPath $readyJsonPath `
    -MarkdownOutputPath $readyMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-invocation-unblock-plan.ps1 ready fixture failed with exit code $LASTEXITCODE."
}

$readyReport = Read-Utf8Text $readyJsonPath | ConvertFrom-Json
$readyMarkdown = Read-Utf8Text $readyMarkdownPath
Assert-Equal $readyReport.result "ready" "ready result"
Assert-Equal $readyReport.blockedCount 0 "ready blocked count"
Assert-Equal $readyReport.requiredPlaceholderCount 0 "ready placeholder count"
Assert-Equal $readyReport.confirmationGroupCount 0 "ready confirmation group count"
Assert-Equal $readyReport.requiredInputGroupCount 0 "ready required input group count"
Assert-Equal $readyReport.actions[0].blockReasonCount 0 "ready action block reason count"
Assert-Equal $readyReport.actions[0].requiredInputCount 0 "ready action required input count"
Assert-Equal $readyReport.actions[0].requiredSecretCount 0 "ready action required secret count"
Assert-Contains $readyReport.plannedOnlyCommand "-ActionOrder 1" "ready planned-only command"
Assert-Contains $readyMarkdown "Result: ready" "ready markdown"

$defaultBranchInvocationPath = Join-Path $resolvedOutputDirectory "default-branch-missing-invocation.json"
$defaultBranchDispatchPreflightPath = Join-Path $resolvedOutputDirectory "default-branch-missing-dispatch-preflight.json"
$defaultBranchJsonPath = Join-Path $resolvedOutputDirectory "default-branch-missing-unblock-plan.json"
$defaultBranchMarkdownPath = Join-Path $resolvedOutputDirectory "default-branch-missing-unblock-plan.md"

Write-JsonFixture $defaultBranchInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = "2026-06-16T07:30:00+09:00"
    result = "planned"
    sourcePlan = ".osmu-run/latest-operations-evidence-plan.json"
    sourceSummary = "passed=83 pending=19"
    sourcePassedCount = 83
    sourcePendingCount = 19
    sourceTotalCount = 102
    sourceCheckCount = 102
    commandMode = "Workflow"
    executionMode = "plan-only"
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 0
    failedCount = 0
    actions = @(
        [ordered]@{
            order = 8
            name = "Data-flow query retention budget evidence"
            category = "data-flow"
            actionType = "manual-evidence"
            evidencePath = ".osmu-run/latest-data-flow-query-retention-budget-evidence.json"
            commandMode = "Workflow"
            command = "gh workflow run manual-data-flow-query-retention-budget-evidence.yml"
            status = "planned"
            blockReasons = @()
            unresolvedPlaceholders = @()
            invalidPlaceholders = @()
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $false
        }
    )
})
Write-JsonFixture $defaultBranchDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    generatedAt = "2026-06-16T07:31:00+09:00"
    result = "action-required"
    defaultBranchRef = "origin/main"
    workflowFiles = @(
        [ordered]@{
            workflow = "manual-data-flow-query-retention-budget-evidence.yml"
            defaultBranchRef = "origin/main"
            existsOnDefaultBranch = $false
            actionOrder = 8
            actionOrders = @(8)
        }
    )
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $defaultBranchInvocationPath `
    -DispatchPreflightReportPath $defaultBranchDispatchPreflightPath `
    -JsonOutputPath $defaultBranchJsonPath `
    -MarkdownOutputPath $defaultBranchMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-invocation-unblock-plan.ps1 default-branch fixture failed with exit code $LASTEXITCODE."
}

$defaultBranchReport = Read-Utf8Text $defaultBranchJsonPath | ConvertFrom-Json
$defaultBranchMarkdown = Read-Utf8Text $defaultBranchMarkdownPath
Assert-Equal $defaultBranchReport.result "action-required" "default branch result"
Assert-Equal $defaultBranchReport.blockedCount 0 "default branch invocation blocked count"
Assert-Equal $defaultBranchReport.defaultBranchWorkflowMissingCount 1 "default branch missing workflow count"
Assert-Equal $defaultBranchReport.defaultBranchWorkflowGroupCount 1 "default branch workflow group count"
Assert-Equal @($defaultBranchReport.defaultBranchWorkflowMissingActionOrders)[0] 8 "default branch missing action order"
Assert-True @($defaultBranchReport.actions)[0].defaultBranchWorkflowMissing "default branch action should carry missing workflow flag"
Assert-Contains $defaultBranchMarkdown "Default branch workflow: manual-data-flow-query-retention-budget-evidence.yml" "default branch markdown workflow group"
Assert-Contains $defaultBranchMarkdown "workflow_dispatch requires the workflow file to exist on the default branch" "default branch markdown note"

Write-JsonFixture $invalidInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = "2026-06-16T07:30:00+09:00"
    result = "blocked"
    sourcePlan = ".osmu-run/latest-operations-evidence-plan.json"
    sourceSummary = "passed=36 pending=6"
    sourcePassedCount = 36
    sourcePendingCount = 6
    sourceTotalCount = 42
    sourceCheckCount = 42
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
    -DispatchPreflightReportPath (Join-Path $resolvedOutputDirectory "missing-dispatch-preflight.json") `
    -JsonOutputPath $invalidJsonPath `
    -MarkdownOutputPath $invalidMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-invocation-unblock-plan.ps1 invalid fixture failed with exit code $LASTEXITCODE."
}

$invalidReport = Read-Utf8Text $invalidJsonPath | ConvertFrom-Json
$invalidMarkdown = Read-Utf8Text $invalidMarkdownPath
Assert-Equal $invalidReport.result "action-required" "invalid result"
Assert-Equal $invalidReport.requiredPlaceholderCount 1 "invalid required placeholder count"
Assert-Equal $invalidReport.confirmationGroupCount 0 "invalid confirmation group count"
Assert-Equal $invalidReport.requiredInputGroupCount 1 "invalid required input group count"
Assert-Equal $invalidReport.actions[0].blockReasonCount 1 "invalid action block reason count"
Assert-Equal $invalidReport.actions[0].invalidPlaceholderCount 1 "invalid action invalid placeholder count"
Assert-Equal $invalidReport.actions[0].requiredInputCount 1 "invalid action required input count"
Assert-Contains $invalidReport.confirmedPlanCommand "-BackupTimestamp <YYYYMMDDTHHMMSSZ>" "invalid confirmed command"
Assert-True (@($invalidReport.actions)[0].invalidPlaceholders -contains "<YYYYMMDDTHHMMSSZ>") "invalid action should carry invalid placeholder"
Assert-Contains $invalidMarkdown "<YYYYMMDDTHHMMSSZ> via BackupTimestamp" "invalid markdown"

Write-Host "Operations invocation unblock plan verified."
Write-Host "Blocked report: $blockedJsonPath"
Write-Host "Ready report: $readyJsonPath"
Write-Host "Default branch report: $defaultBranchJsonPath"
Write-Host "Invalid report: $invalidJsonPath"
