param(
    [string] $OutputDirectory = ".\.osmu-run\operations-evidence-handoff-self-test"
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

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-evidence-handoff.ps1"

$missingJsonPath = Join-Path $resolvedOutputDirectory "missing-handoff.json"
$missingMarkdownPath = Join-Path $resolvedOutputDirectory "missing-handoff.md"
$missingReadinessPath = Join-Path $resolvedOutputDirectory "missing-readiness.json"
$missingPlanPath = Join-Path $resolvedOutputDirectory "missing-plan.json"
$missingInvocationPath = Join-Path $resolvedOutputDirectory "missing-invocation.json"
$missingDispatchPreflightPath = Join-Path $resolvedOutputDirectory "missing-dispatch-preflight.json"
$missingRunIdPath = Join-Path $resolvedOutputDirectory "missing-run-ids.json"
$missingCollectionPath = Join-Path $resolvedOutputDirectory "missing-collection.json"
$missingImportPath = Join-Path $resolvedOutputDirectory "missing-import.json"
$missingFinalizePath = Join-Path $resolvedOutputDirectory "missing-finalize.json"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $missingReadinessPath `
    -EvidencePlanPath $missingPlanPath `
    -InvocationReportPath $missingInvocationPath `
    -DispatchPreflightReportPath $missingDispatchPreflightPath `
    -WorkflowRunIdPlanPath $missingRunIdPath `
    -ArtifactCollectionPlanPath $missingCollectionPath `
    -ArtifactImportReportPath $missingImportPath `
    -OperationsReadinessFinalizeReportPath $missingFinalizePath `
    -JsonOutputPath $missingJsonPath `
    -MarkdownOutputPath $missingMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 missing-report check failed with exit code $LASTEXITCODE."
}

$missingReport = Read-Utf8Text $missingJsonPath | ConvertFrom-Json
$missingMarkdown = Read-Utf8Text $missingMarkdownPath
Assert-Equal $missingReport.formatVersion "osmu.operations-evidence-handoff.v1" "missing formatVersion"
Assert-Equal $missingReport.result "action-required" "missing result"
Assert-Equal $missingReport.nextStep.code "write-readiness" "missing next step"
Assert-Equal $missingReport.currentBottleneck.code "write-readiness" "missing current bottleneck"
Assert-Equal $missingReport.stageCount 10 "missing stage count"
Assert-Contains $missingMarkdown "## Current Bottleneck" "missing markdown current bottleneck"
Assert-Contains $missingMarkdown "Generate operations readiness report" "missing markdown next step"

$staleInvocationReadinessPath = Join-Path $resolvedOutputDirectory "stale-invocation-readiness.json"
$staleInvocationPlanPath = Join-Path $resolvedOutputDirectory "stale-invocation-plan.json"
$staleInvocationInvocationPath = Join-Path $resolvedOutputDirectory "stale-invocation-invocation.json"
$staleInvocationDispatchPreflightPath = Join-Path $resolvedOutputDirectory "stale-invocation-dispatch-preflight.json"
$staleInvocationRunIdPath = Join-Path $resolvedOutputDirectory "stale-invocation-run-ids.json"
$staleInvocationCollectionPath = Join-Path $resolvedOutputDirectory "stale-invocation-collection.json"
$staleInvocationImportPath = Join-Path $resolvedOutputDirectory "stale-invocation-import.json"
$staleInvocationFinalizePath = Join-Path $resolvedOutputDirectory "stale-invocation-finalize.json"
$staleInvocationJsonPath = Join-Path $resolvedOutputDirectory "stale-invocation-handoff.json"
$staleInvocationMarkdownPath = Join-Path $resolvedOutputDirectory "stale-invocation-handoff.md"

Write-JsonFixture $staleInvocationReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    generatedAt = "2026-06-27T10:00:00+09:00"
    result = "pending"
    summary = "passed=82 pending=20"
    passedCount = 82
    pendingCount = 20
    totalCount = 102
    checkCount = 102
})
Write-JsonFixture $staleInvocationPlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    generatedAt = "2026-06-27T10:05:00+09:00"
    result = "action-required"
    pendingCount = 20
    actionCount = 20
    unplannedCount = 0
})
Write-JsonFixture $staleInvocationInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = "2026-06-27T09:30:00+09:00"
    result = "planned"
    selectedActionCount = 6
    plannedCount = 6
    blockedCount = 0
    executedCount = 0
    failedCount = 0
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $staleInvocationReadinessPath `
    -EvidencePlanPath $staleInvocationPlanPath `
    -InvocationReportPath $staleInvocationInvocationPath `
    -DispatchPreflightReportPath $staleInvocationDispatchPreflightPath `
    -WorkflowRunIdPlanPath $staleInvocationRunIdPath `
    -ArtifactCollectionPlanPath $staleInvocationCollectionPath `
    -ArtifactImportReportPath $staleInvocationImportPath `
    -OperationsReadinessFinalizeReportPath $staleInvocationFinalizePath `
    -JsonOutputPath $staleInvocationJsonPath `
    -MarkdownOutputPath $staleInvocationMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 stale-invocation check failed with exit code $LASTEXITCODE."
}

$staleInvocationReport = Read-Utf8Text $staleInvocationJsonPath | ConvertFrom-Json
$staleInvocationMarkdown = Read-Utf8Text $staleInvocationMarkdownPath
Assert-Equal $staleInvocationReport.result "action-required" "stale invocation result"
Assert-Equal $staleInvocationReport.nextStep.code "refresh-invocation" "stale invocation next step"
Assert-Equal $staleInvocationReport.currentBottleneck.code "refresh-invocation" "stale invocation current bottleneck"
Assert-Equal $staleInvocationReport.invocationStale $true "stale invocation flag"
Assert-Equal $staleInvocationReport.dispatchPreflightStale $false "stale dispatch flag"
Assert-Equal $staleInvocationReport.staleReportCount 1 "stale report count"
Assert-Equal $staleInvocationReport.readinessSummary "passed=82 pending=20" "stale invocation readiness summary"
Assert-Equal $staleInvocationReport.readinessPassedCount 82 "stale invocation readiness passed count"
Assert-Equal $staleInvocationReport.readinessPendingCount 20 "stale invocation readiness pending count"
Assert-Equal $staleInvocationReport.readinessTotalCount 102 "stale invocation readiness total count"
Assert-Equal $staleInvocationReport.readinessCheckCount 102 "stale invocation readiness check count"
Assert-Contains $staleInvocationMarkdown "Counts: passed=82 pending=20 total=102 checks=102" "stale invocation markdown readiness counts"
Assert-Contains $staleInvocationReport.nextStep.reason "older than the latest operations evidence plan" "stale invocation reason"
Assert-Contains @($staleInvocationReport.stages)[2].summary "stale=true" "stale invocation stage summary"
Assert-Contains $staleInvocationMarkdown "Stale reports: 1" "stale invocation markdown count"

$blockedReadinessPath = Join-Path $resolvedOutputDirectory "blocked-readiness.json"
$blockedPlanPath = Join-Path $resolvedOutputDirectory "blocked-plan.json"
$blockedInvocationPath = Join-Path $resolvedOutputDirectory "blocked-invocation.json"
$blockedUnblockPath = Join-Path $resolvedOutputDirectory "blocked-unblock-plan.json"
$blockedDispatchPreflightPath = Join-Path $resolvedOutputDirectory "blocked-dispatch-preflight.json"
$blockedWorksheetPath = Join-Path $resolvedOutputDirectory "blocked-operator-worksheet.json"
$blockedWorksheetCsvPath = Join-Path $resolvedOutputDirectory "blocked-operator-worksheet.csv"
$blockedTemplatePath = Join-Path $resolvedOutputDirectory "blocked-operator-values-template.json"
$blockedTemplateMarkdownPath = Join-Path $resolvedOutputDirectory "blocked-operator-values-template.md"
$blockedCheckPath = Join-Path $resolvedOutputDirectory "blocked-operator-values-check.json"
$blockedRunIdPath = Join-Path $resolvedOutputDirectory "blocked-run-ids.json"
$blockedCollectionPath = Join-Path $resolvedOutputDirectory "blocked-collection.json"
$blockedImportPath = Join-Path $resolvedOutputDirectory "blocked-import.json"
$blockedFinalizePath = Join-Path $resolvedOutputDirectory "blocked-finalize.json"
$blockedJsonPath = Join-Path $resolvedOutputDirectory "blocked-handoff.json"
$blockedMarkdownPath = Join-Path $resolvedOutputDirectory "blocked-handoff.md"

Write-JsonFixture $blockedReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=6"
})
Write-JsonFixture $blockedPlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    result = "action-required"
    pendingCount = 6
    actionCount = 6
    unplannedCount = 0
})
Write-JsonFixture $blockedInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    result = "blocked"
    selectedActionCount = 6
    plannedCount = 1
    blockedCount = 5
    executedCount = 0
    failedCount = 0
})
Write-JsonFixture $blockedUnblockPath ([ordered]@{
    formatVersion = "osmu.operations-invocation-unblock-plan.v1"
    result = "action-required"
    sourceInvocationReport = $blockedInvocationPath
    selectedActionCount = 3
    blockedCount = 2
    actions = @(
        [ordered]@{
            order = 1
            name = "Storage expansion finalizer live evidence"
            status = "blocked"
            blockReasonCount = 2
            blockReasons = @("operator approval not confirmed", "kubeconfig secret not confirmed")
            requiredInputCount = 0
            requiredSecretCount = 1
            requiredSecrets = @("OSMU_KUBECONFIG_BASE64")
            needsOperatorApprovalConfirmation = $true
            needsKubeconfigSecretConfirmation = $true
            defaultBranchWorkflowMissing = $false
            planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval"
        },
        [ordered]@{
            order = 2
            name = "Container scan/SBOM evidence"
            status = "planned"
            blockReasonCount = 0
            requiredInputCount = 0
            requiredSecretCount = 0
            needsOperatorApprovalConfirmation = $false
            needsKubeconfigSecretConfirmation = $false
            defaultBranchWorkflowMissing = $false
        },
        [ordered]@{
            order = 3
            name = "Kubernetes DR finalizer live evidence"
            status = "blocked"
            blockReasonCount = 2
            blockReasons = @("unresolved placeholders: <YYYYMMDDTHHMMSSZ>, <restore-api-base>", "operator approval not confirmed")
            requiredInputCount = 2
            requiredSecretCount = 1
            requiredSecrets = @("OSMU_KUBECONFIG_BASE64")
            needsOperatorApprovalConfirmation = $true
            needsKubeconfigSecretConfirmation = $true
            defaultBranchWorkflowMissing = $true
        }
    )
})
Write-JsonFixture $blockedRunIdPath ([ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    result = "query-required"
    workflowCount = 6
    readyWorkflowCount = 0
    missingWorkflowCount = 6
    staleWorkflowCount = 0
    artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1"
})
Write-JsonFixture $blockedDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    result = "action-required"
    githubRepository = "chefbeom/object-storage-osmu"
    selectedActionCount = 3
    missingInputCount = 2
    requiredInputCount = 2
    requiredGitHubSecrets = @("OSMU_KUBECONFIG_BASE64", "GITHUB_TOKEN")
    defaultBranchRef = "origin/main"
    workflowFiles = @(
        [ordered]@{
            workflow = "storage-expansion-finalizer-ci.yml"
            requiredSecrets = @("OSMU_KUBECONFIG_BASE64")
            defaultBranchRef = "origin/main"
            existsOnDefaultBranch = $true
            actionOrder = 1
            actionOrders = @(1)
        },
        [ordered]@{
            workflow = "container-security-ci.yml"
            requiredSecrets = @("GITHUB_TOKEN")
            defaultBranchRef = "origin/main"
            existsOnDefaultBranch = $true
            actionOrder = 2
            actionOrders = @(2)
        },
        [ordered]@{
            workflow = "manual-data-flow-query-retention-budget-evidence.yml"
            defaultBranchRef = "origin/main"
            existsOnDefaultBranch = $false
            actionOrder = 3
            actionOrders = @(3)
        }
    )
    readySubsetPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 2"
    readySubsetExecuteCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 2 -Execute"
    readySubsetApiExecuteCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 2 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute"
    inputTemplates = @(
        [ordered]@{
            actionOrder = 1
            name = "Storage expansion finalizer live evidence"
            workflow = "storage-expansion-finalizer-ci.yml"
            requiredSecrets = @("OSMU_KUBECONFIG_BASE64")
            readyToDispatch = $false
            missingInputCount = 0
            unsafeInputCount = 0
            invalidInputCount = 0
            workflowInputNames = @()
            missingInputParameters = @()
        },
        [ordered]@{
            actionOrder = 2
            name = "Container scan/SBOM evidence"
            workflow = "container-security-ci.yml"
            requiredSecrets = @("GITHUB_TOKEN")
            dispatchUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
            readyToDispatch = $true
            missingInputCount = 0
            unsafeInputCount = 0
            invalidInputCount = 0
            workflowInputNames = @()
            missingInputParameters = @()
        },
        [ordered]@{
            actionOrder = 3
            name = "Kubernetes DR finalizer live evidence"
            workflow = "kubernetes-dr-finalizer-ci.yml"
            requiredSecrets = @("OSMU_KUBECONFIG_BASE64")
            dispatchUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/kubernetes-dr-finalizer-ci.yml"
            readyToDispatch = $false
            missingInputCount = 2
            unsafeInputCount = 0
            invalidInputCount = 0
            workflowInputNames = @("backup_timestamp", "api_base")
            missingInputParameters = @("BackupTimestamp", "RestoreApiBase")
        }
    )
})
Write-JsonFixture $blockedWorksheetPath ([ordered]@{
    formatVersion = "osmu.operations-operator-input-worksheet.v1"
    generatedAt = "2026-06-27T10:12:00+09:00"
    result = "action-required"
    sourceDispatchPreflightReport = $blockedDispatchPreflightPath
    csvPath = $blockedWorksheetCsvPath
    inputValuesTemplatePath = $blockedTemplatePath
    inputValuesTemplateMarkdownPath = $blockedTemplateMarkdownPath
    inputRowCount = 4
    ambiguousInputRowCount = 1
    inputFreeActionCount = 1
    requiredSecretCount = 2
})
Write-JsonFixture $blockedCheckPath ([ordered]@{
    formatVersion = "osmu.operations-operator-input-values-check.v1"
    generatedAt = "2026-06-27T10:15:00+09:00"
    result = "action-required"
    sourceValuesTemplate = $blockedTemplatePath
    valueCount = 4
    readyValueCount = 0
    missingValueCount = 4
    unsafeValueCount = 0
    invalidValueCount = 0
    actionSummaryCount = 3
    valueReadyActionCount = 1
    nonReadyActionCount = 2
})
Write-JsonFixture $blockedCollectionPath ([ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    result = "action-required"
    artifactCount = 6
    readyArtifactCount = 2
    missingRequiredArtifactCount = 4
    operationsArtifactFinalizerCommand = "gh workflow run operations-readiness-artifact-finalizer-ci.yml"
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $blockedReadinessPath `
    -EvidencePlanPath $blockedPlanPath `
    -InvocationReportPath $blockedInvocationPath `
    -InvocationUnblockPlanPath $blockedUnblockPath `
    -DispatchPreflightReportPath $blockedDispatchPreflightPath `
    -OperatorInputWorksheetReportPath $blockedWorksheetPath `
    -OperatorInputValuesCheckReportPath $blockedCheckPath `
    -WorkflowRunIdPlanPath $blockedRunIdPath `
    -ArtifactCollectionPlanPath $blockedCollectionPath `
    -ArtifactImportReportPath $blockedImportPath `
    -OperationsReadinessFinalizeReportPath $blockedFinalizePath `
    -JsonOutputPath $blockedJsonPath `
    -MarkdownOutputPath $blockedMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 blocked-report check failed with exit code $LASTEXITCODE."
}

$blockedReport = Read-Utf8Text $blockedJsonPath | ConvertFrom-Json
$blockedMarkdown = Read-Utf8Text $blockedMarkdownPath

$inputFreeOnlyDispatchPreflightPath = Join-Path $resolvedOutputDirectory "input-free-only-dispatch-preflight.json"
$inputFreeOnlyJsonPath = Join-Path $resolvedOutputDirectory "input-free-only-handoff.json"
$inputFreeOnlyMarkdownPath = Join-Path $resolvedOutputDirectory "input-free-only-handoff.md"
Write-JsonFixture $inputFreeOnlyDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    result = "action-required"
    githubRepository = "chefbeom/object-storage-osmu"
    selectedActionCount = 3
    missingInputCount = 2
    requiredInputCount = 2
    requiredGitHubSecrets = @("OSMU_KUBECONFIG_BASE64", "GITHUB_TOKEN")
    defaultBranchRef = "origin/main"
    workflowFiles = @(
        [ordered]@{ workflow = "storage-expansion-finalizer-ci.yml"; requiredSecrets = @("OSMU_KUBECONFIG_BASE64"); defaultBranchRef = "origin/main"; existsOnDefaultBranch = $true; actionOrder = 1; actionOrders = @(1) },
        [ordered]@{ workflow = "container-security-ci.yml"; requiredSecrets = @("GITHUB_TOKEN"); defaultBranchRef = "origin/main"; existsOnDefaultBranch = $true; actionOrder = 2; actionOrders = @(2) },
        [ordered]@{ workflow = "kubernetes-dr-finalizer-ci.yml"; requiredSecrets = @("OSMU_KUBECONFIG_BASE64"); defaultBranchRef = "origin/main"; existsOnDefaultBranch = $true; actionOrder = 3; actionOrders = @(3) }
    )
    inputTemplates = @(
        [ordered]@{ actionOrder = 1; name = "Storage expansion finalizer live evidence"; workflow = "storage-expansion-finalizer-ci.yml"; requiredSecrets = @("OSMU_KUBECONFIG_BASE64"); readyToDispatch = $false; missingInputCount = 0; unsafeInputCount = 0; invalidInputCount = 0; workflowInputNames = @(); missingInputParameters = @() },
        [ordered]@{ actionOrder = 2; name = "Container scan/SBOM evidence"; workflow = "container-security-ci.yml"; requiredSecrets = @("GITHUB_TOKEN"); readyToDispatch = $false; missingInputCount = 0; unsafeInputCount = 0; invalidInputCount = 0; workflowInputNames = @(); missingInputParameters = @() },
        [ordered]@{ actionOrder = 3; name = "Kubernetes DR finalizer live evidence"; workflow = "kubernetes-dr-finalizer-ci.yml"; requiredSecrets = @("OSMU_KUBECONFIG_BASE64"); readyToDispatch = $false; missingInputCount = 2; unsafeInputCount = 0; invalidInputCount = 0; workflowInputNames = @("backup_timestamp", "api_base"); missingInputParameters = @("BackupTimestamp", "RestoreApiBase") }
    )
})
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $blockedReadinessPath `
    -EvidencePlanPath $blockedPlanPath `
    -InvocationReportPath $blockedInvocationPath `
    -InvocationUnblockPlanPath $blockedUnblockPath `
    -DispatchPreflightReportPath $inputFreeOnlyDispatchPreflightPath `
    -OperatorInputWorksheetReportPath $blockedWorksheetPath `
    -OperatorInputValuesCheckReportPath $blockedCheckPath `
    -WorkflowRunIdPlanPath $blockedRunIdPath `
    -ArtifactCollectionPlanPath $blockedCollectionPath `
    -ArtifactImportReportPath $blockedImportPath `
    -OperationsReadinessFinalizeReportPath $blockedFinalizePath `
    -JsonOutputPath $inputFreeOnlyJsonPath `
    -MarkdownOutputPath $inputFreeOnlyMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 input-free-only check failed with exit code $LASTEXITCODE."
}
$inputFreeOnlyReport = Read-Utf8Text $inputFreeOnlyJsonPath | ConvertFrom-Json
$inputFreeOnlyMarkdown = Read-Utf8Text $inputFreeOnlyMarkdownPath
Assert-Equal $inputFreeOnlyReport.nextStep.code "confirm-input-free-blockers" "input-free-only next step"
Assert-Contains $inputFreeOnlyReport.nextStep.command "-ActionOrder 1" "input-free-only next step command"
Assert-Contains $inputFreeOnlyReport.nextStep.reason "require no operator input values" "input-free-only next step reason"
Assert-Contains $inputFreeOnlyReport.nextStep.note "Execute after confirming operator approval" "input-free-only execute note"
Assert-Contains $inputFreeOnlyMarkdown "Confirm input-free blocked actions" "input-free-only markdown next step"
Assert-Equal $blockedReport.result "blocked" "blocked result"
Assert-Equal $blockedReport.nextStep.code "dispatch-ready-subset" "blocked next step"
Assert-Contains $blockedReport.nextStep.command "-ActionOrder 2" "blocked ready subset command"
Assert-Contains $blockedReport.nextStep.reason "1 action(s) are ready" "blocked ready subset reason"
Assert-Contains $blockedReport.nextStep.note "remaining blocked actions" "blocked ready subset note"
Assert-Contains $blockedReport.nextStep.note "Default-branch workflow blocker" "blocked ready subset default branch hint"
Assert-Contains $blockedReport.nextStep.note "manual-data-flow-query-retention-budget-evidence.yml" "blocked ready subset default branch workflow"
Assert-Contains $blockedReport.nextStep.note "Web dispatch URL(s) for ready templates" "blocked ready subset dispatch URL hint"
Assert-Contains $blockedReport.nextStep.note "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "blocked ready subset dispatch URL hint value"
Assert-Equal @($blockedReport.nextStep.dispatchUrls).Count 1 "blocked ready subset structured dispatch URL count"
Assert-Equal @($blockedReport.nextStep.dispatchUrls)[0] "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "blocked ready subset structured dispatch URL"
Assert-Equal $blockedReport.dispatchGithubRepository "chefbeom/object-storage-osmu" "blocked dispatch github repository"
Assert-Equal $blockedReport.defaultBranchRef "origin/main" "blocked default branch ref"
Assert-Equal $blockedReport.defaultBranchMissingWorkflowCount 1 "blocked default branch missing workflow count"
Assert-Equal $blockedReport.requiredGitHubSecretCount 2 "blocked required GitHub secret count"
Assert-True (@($blockedReport.requiredGitHubSecrets) -contains "OSMU_KUBECONFIG_BASE64") "blocked required kubeconfig secret"
Assert-True (@($blockedReport.requiredGitHubSecrets) -contains "GITHUB_TOKEN") "blocked required github token secret"
$blockedKubeSecret = @($blockedReport.requiredGitHubSecretSummaries | Where-Object { $_.secretName -eq "OSMU_KUBECONFIG_BASE64" } | Select-Object -First 1)
$blockedGithubSecret = @($blockedReport.requiredGitHubSecretSummaries | Where-Object { $_.secretName -eq "GITHUB_TOKEN" } | Select-Object -First 1)
Assert-Equal $blockedKubeSecret.actionCount 2 "blocked kubeconfig secret action count"
Assert-Equal $blockedKubeSecret.inputFreeBlockedActionCount 1 "blocked kubeconfig input-free action count"
Assert-True (@($blockedKubeSecret.actionOrders) -contains 3) "blocked kubeconfig action orders"
Assert-Equal $blockedGithubSecret.actionCount 1 "blocked github token action count"
Assert-Equal @($blockedReport.defaultBranchMissingActionOrders)[0] 3 "blocked default branch missing action order"
Assert-Equal $blockedReport.invocationUnblockPlanExists $true "blocked unblock plan exists"
Assert-Equal $blockedReport.invocationUnblockPlanActionCount 3 "blocked unblock action count"
Assert-Equal $blockedReport.invocationUnblockPlanBlockReasonCount 4 "blocked unblock reason count"
Assert-Equal $blockedReport.invocationUnblockPlanRequiredInputCount 2 "blocked unblock required input count"
Assert-Equal $blockedReport.invocationUnblockPlanRequiredSecretCount 2 "blocked unblock required secret count"
Assert-Equal $blockedReport.invocationUnblockPlanOperatorApprovalActionCount 2 "blocked unblock operator approval count"
Assert-Equal $blockedReport.invocationUnblockPlanKubeconfigSecretActionCount 2 "blocked unblock kubeconfig count"
Assert-Equal $blockedReport.invocationUnblockPlanDefaultBranchMissingActionCount 1 "blocked unblock default branch action count"
Assert-Equal @($blockedReport.invocationUnblockActions).Count 3 "blocked unblock action summary count"
Assert-Equal @($blockedReport.invocationUnblockActions)[2].requiredInputCount 2 "blocked unblock action required inputs"
Assert-Equal $blockedReport.inputFreeBlockedActionCount 1 "blocked input-free blocked action count"
Assert-Equal $blockedReport.inputFreeBlockedRequiredSecretCount 1 "blocked input-free required secret count"
Assert-Equal $blockedReport.inputFreeBlockedOperatorApprovalActionCount 1 "blocked input-free operator approval count"
Assert-Equal $blockedReport.inputFreeBlockedKubeconfigSecretActionCount 1 "blocked input-free kubeconfig count"
Assert-Equal $blockedReport.inputFreeBlockedPlanCommand "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval" "blocked input-free aggregate plan command"
Assert-Equal $blockedReport.inputFreeBlockedExecuteCommand "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -Execute" "blocked input-free aggregate execute command"
Assert-Equal @($blockedReport.inputFreeBlockedActions)[0].actionOrder 1 "blocked input-free action order"
Assert-True (@(@($blockedReport.inputFreeBlockedActions)[0].requiredSecrets) -contains "OSMU_KUBECONFIG_BASE64") "blocked input-free required secret name"
Assert-Contains @($blockedReport.inputFreeBlockedActions)[0].planCommand "-KubeconfigSecretConfirmed" "blocked input-free plan command"
Assert-Equal @($blockedReport.defaultBranchMissingWorkflows)[0].workflow "manual-data-flow-query-retention-budget-evidence.yml" "blocked default branch missing workflow name"
Assert-Equal $blockedReport.blockedActionCount 5 "blocked count"
Assert-Equal $blockedReport.missingWorkflowRunCount 6 "blocked missing workflow run count"
Assert-Equal $blockedReport.dispatchPreflightRequiredInputCount 2 "blocked dispatch required input count"
Assert-Equal $blockedReport.dispatchPreflightMissingInputCount 2 "blocked dispatch missing input count"
Assert-Equal $blockedReport.operatorInputWorksheetReportPath $blockedWorksheetPath "blocked worksheet report path"
Assert-Equal $blockedReport.operatorInputWorksheetCsvPath $blockedWorksheetCsvPath "blocked worksheet csv path"
Assert-Equal $blockedReport.operatorInputValuesTemplatePath $blockedTemplatePath "blocked values template path"
Assert-Equal $blockedReport.operatorInputValuesTemplateMarkdownPath $blockedTemplateMarkdownPath "blocked values template markdown path"
Assert-Equal $blockedReport.operatorInputWorksheetInputRowCount 4 "blocked worksheet input row count"
Assert-Equal $blockedReport.operatorInputWorksheetExpandedInputRowDelta 2 "blocked worksheet expanded row delta"
Assert-Equal $blockedReport.operatorInputValuesCheckValueCount 4 "blocked values check value count"
Assert-Equal $blockedReport.operatorInputValuesCheckMissingValueCount 4 "blocked values check missing count"
Assert-Equal @($blockedReport.readyDispatchWorkflows).Count 1 "blocked ready dispatch workflow count"
Assert-Equal @($blockedReport.blockedDispatchWorkflows).Count 2 "blocked blocked dispatch workflow count"
Assert-Equal @($blockedReport.readyDispatchWorkflows)[0].actionOrder 2 "blocked ready dispatch workflow action order"
Assert-Equal @($blockedReport.readyDispatchWorkflows)[0].workflow "container-security-ci.yml" "blocked ready dispatch workflow name"
Assert-Equal @($blockedReport.readyDispatchWorkflows)[0].name "Container scan/SBOM evidence" "blocked ready dispatch action name"
Assert-Equal @($blockedReport.readyDispatchWorkflows)[0].dispatchUrl "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "blocked ready dispatch workflow url"
Assert-Equal @($blockedReport.blockedDispatchWorkflows)[1].missingInputCount 2 "blocked workflow missing input count"
Assert-Equal @($blockedReport.blockedDispatchWorkflows)[1].dispatchUrl "https://github.com/chefbeom/object-storage-osmu/actions/workflows/kubernetes-dr-finalizer-ci.yml" "blocked workflow dispatch url"
$blockedDispatchStage = @($blockedReport.stages | Where-Object { $_.name -eq "dispatch-preflight" } | Select-Object -First 1)
$blockedWorksheetStage = @($blockedReport.stages | Where-Object { $_.name -eq "operator-input-worksheet" } | Select-Object -First 1)
Assert-Contains $blockedDispatchStage.summary "requiredInputs=2 missingInputs=2" "blocked dispatch stage input summary"
Assert-Contains $blockedWorksheetStage.summary "inputs=4 expandedDelta=2" "blocked worksheet stage expansion summary"
Assert-Contains $blockedMarkdown "Plan ready dispatch subset" "blocked markdown next step"
Assert-Contains $blockedMarkdown "GitHub repository: chefbeom/object-storage-osmu" "blocked markdown repository"
Assert-Contains $blockedMarkdown "## Invocation Unblock Summary" "blocked markdown unblock summary"
Assert-Contains $blockedMarkdown "## Operator Input Expansion" "blocked markdown input expansion section"
Assert-Contains $blockedMarkdown "## Input-Free Blocked Actions" "blocked markdown input-free section"
Assert-Contains $blockedMarkdown "Actions: 1" "blocked markdown input-free action count"
Assert-Contains $blockedMarkdown "Plan command: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval``" "blocked markdown input-free aggregate plan command"
Assert-Contains $blockedMarkdown "Execute command after confirmations: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -Execute``" "blocked markdown input-free aggregate execute command"
Assert-Contains $blockedMarkdown "action 1: blockers=2 secrets=OSMU_KUBECONFIG_BASE64" "blocked markdown input-free action summary"
Assert-Contains $blockedMarkdown "-KubeconfigSecretConfirmed" "blocked markdown input-free plan command"
Assert-Contains $blockedMarkdown "## Required GitHub Secrets" "blocked markdown required secrets section"
Assert-Contains $blockedMarkdown "OSMU_KUBECONFIG_BASE64: actions=1,3 inputFreeBlocked=1" "blocked markdown kubeconfig secret summary"
Assert-Contains $blockedMarkdown "GITHUB_TOKEN: actions=2 inputFreeBlocked=none" "blocked markdown github token secret summary"
Assert-Contains $blockedMarkdown "Dispatch required inputs: 2" "blocked markdown dispatch required inputs"
Assert-Contains $blockedMarkdown "Worksheet report: $blockedWorksheetPath" "blocked markdown worksheet report path"
Assert-Contains $blockedMarkdown "Worksheet CSV: $blockedWorksheetCsvPath" "blocked markdown worksheet csv path"
Assert-Contains $blockedMarkdown "Values template JSON: $blockedTemplatePath" "blocked markdown values template path"
Assert-Contains $blockedMarkdown "Values template Markdown: $blockedTemplateMarkdownPath" "blocked markdown values template markdown path"
Assert-Contains $blockedMarkdown "Expanded worksheet row delta: 2" "blocked markdown worksheet expansion delta"
Assert-Contains $blockedMarkdown "Values check rows: 4" "blocked markdown values check rows"
Assert-Contains $blockedMarkdown "Block reasons: 4" "blocked markdown unblock reason count"
Assert-Contains $blockedMarkdown "action 3: status=blocked blockers=2 inputs=2 secrets=1" "blocked markdown unblock action summary"
Assert-Contains $blockedMarkdown "ready action 2: container-security-ci.yml" "blocked markdown ready workflow"
Assert-Contains $blockedMarkdown "dispatchUrl=https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "blocked markdown ready dispatch url"
Assert-Contains $blockedMarkdown "blocked action 3: kubernetes-dr-finalizer-ci.yml" "blocked markdown blocked workflow"
Assert-Contains $blockedMarkdown "Default Branch Workflow Readiness" "blocked markdown default branch section"
Assert-Contains $blockedMarkdown "missing workflow: manual-data-flow-query-retention-budget-evidence.yml" "blocked markdown default branch workflow"

$preflightBlockReadinessPath = Join-Path $resolvedOutputDirectory "preflight-block-readiness.json"
$preflightBlockPlanPath = Join-Path $resolvedOutputDirectory "preflight-block-plan.json"
$preflightBlockInvocationPath = Join-Path $resolvedOutputDirectory "preflight-block-invocation.json"
$preflightBlockDispatchPreflightPath = Join-Path $resolvedOutputDirectory "preflight-block-dispatch-preflight.json"
$preflightBlockRunIdPath = Join-Path $resolvedOutputDirectory "preflight-block-run-ids.json"
$preflightBlockCollectionPath = Join-Path $resolvedOutputDirectory "preflight-block-collection.json"
$preflightBlockImportPath = Join-Path $resolvedOutputDirectory "preflight-block-import.json"
$preflightBlockFinalizePath = Join-Path $resolvedOutputDirectory "preflight-block-finalize.json"
$preflightBlockJsonPath = Join-Path $resolvedOutputDirectory "preflight-block-handoff.json"
$preflightBlockMarkdownPath = Join-Path $resolvedOutputDirectory "preflight-block-handoff.md"

Write-JsonFixture $preflightBlockReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=1"
})
Write-JsonFixture $preflightBlockPlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    result = "action-required"
    pendingCount = 1
    actionCount = 1
    unplannedCount = 0
})
Write-JsonFixture $preflightBlockInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    result = "planned"
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 0
    failedCount = 0
})
Write-JsonFixture $preflightBlockDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    result = "action-required"
    githubRepository = "chefbeom/object-storage-osmu"
    selectedActionCount = 1
    selectedActionOrders = @(2)
    readyActionCount = 1
    readyActionOrders = @(2)
    blockedActionCount = 0
    blockedActionOrders = @()
    missingInputCount = 0
    failedCheckCount = 1
    warningCheckCount = 0
    githubCliPath = "C:\tools\gh.exe"
    readySubsetPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -GitHubCliPath C:\tools\gh.exe -ActionOrder 2"
    readySubsetApiExecuteCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -GitHubCliPath C:\tools\gh.exe -ActionOrder 2 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute"
    checks = @(
        [ordered]@{
            code = "GITHUB_CLI_AVAILABLE"
            status = "fail"
            message = "GitHub CLI was not found on PATH."
        }
    )
    inputTemplates = @(
        [ordered]@{
            actionOrder = 2
            name = "Container scan/SBOM evidence"
            workflow = "container-security-ci.yml"
            dispatchUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
            readyToDispatch = $true
            missingInputCount = 0
            unsafeInputCount = 0
            invalidInputCount = 0
            workflowInputNames = @()
            missingInputParameters = @()
        }
    )
})
Write-JsonFixture $preflightBlockRunIdPath ([ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    result = "query-required"
    workflowCount = 1
    readyWorkflowCount = 0
    missingWorkflowCount = 1
    staleWorkflowCount = 0
    sourceActionOrders = @(2)

    branch = "main"
    runListJsonDirectoryCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory .\.osmu-run\workflow-run-lists"
    githubApiRunListCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1"
    artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1"
    manualArtifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId>"
    workflowRunIdInputs = @(
        [ordered]@{
            workflow = "container-security-ci.yml"
            actionOrders = @(2)
            runIdParameter = "ContainerSecurityRunId"
            artifactName = "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68"
            runsUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
            runListJsonPath = ".\.osmu-run\workflow-run-lists\container-security-ci.yml.json"
        }
    )
    securityEvidenceFinalizerRunIdInputHints = @(
        [ordered]@{
            workflow = "image-publish-sign-ci.yml"
            group = "image-signing-source"
            actionOrders = @()
            runIdParameter = "ImageSigningRunId"
            artifactName = "osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68"
            runsUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"
            runListJsonPath = ".\.osmu-run\workflow-run-lists\image-publish-sign-ci.yml.json"
            queryCommand = "gh run list --workflow image-publish-sign-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle"
            sourceSelected = $false
            supplementalForSecurityFinalizer = $true
        },
        [ordered]@{
            workflow = "container-security-ci.yml"
            group = "container-security-source"
            actionOrders = @(2)
            runIdParameter = "ContainerSecurityRunId"
            artifactName = "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68"
            runsUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
            runListJsonPath = ".\.osmu-run\workflow-run-lists\container-security-ci.yml.json"
            queryCommand = "gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle"
            sourceSelected = $true
            supplementalForSecurityFinalizer = $false
        }
    )
    workflows = @(
        [ordered]@{
            workflow = "container-security-ci.yml"
            runsUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
        }
    )
})
Write-JsonFixture $preflightBlockCollectionPath ([ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    result = "action-required"
    artifactCount = 1
    readyArtifactCount = 0
    missingRequiredArtifactCount = 1
    sourceActionOrders = @(2)
    securityEvidenceFinalizerInputs = @(
        [ordered]@{
            name = "ImageSigningRunId"
        },
        [ordered]@{
            name = "ContainerSecurityRunId"
        }
    )
    securityEvidenceFinalizerMissingRunIdInputs = @("ImageSigningRunId", "ContainerSecurityRunId")
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $preflightBlockReadinessPath `
    -EvidencePlanPath $preflightBlockPlanPath `
    -InvocationReportPath $preflightBlockInvocationPath `
    -DispatchPreflightReportPath $preflightBlockDispatchPreflightPath `
    -WorkflowRunIdPlanPath $preflightBlockRunIdPath `
    -ArtifactCollectionPlanPath $preflightBlockCollectionPath `
    -ArtifactImportReportPath $preflightBlockImportPath `
    -OperationsReadinessFinalizeReportPath $preflightBlockFinalizePath `
    -JsonOutputPath $preflightBlockJsonPath `
    -MarkdownOutputPath $preflightBlockMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 preflight-block check failed with exit code $LASTEXITCODE."
}

$preflightBlockReport = Read-Utf8Text $preflightBlockJsonPath | ConvertFrom-Json
$preflightBlockMarkdown = Read-Utf8Text $preflightBlockMarkdownPath
Assert-Equal $preflightBlockReport.result "action-required" "preflight-block result"
Assert-Equal $preflightBlockReport.nextStep.code "dispatch-ready-subset-browser" "preflight-block next step"
Assert-Contains $preflightBlockReport.nextStep.command "-ActionOrder 2" "preflight-block command action order"
Assert-Contains $preflightBlockReport.nextStep.command "-GitHubCliPath C:\tools\gh.exe" "preflight-block command github cli path"
Assert-Contains $preflightBlockReport.nextStep.reason "only failed because GitHub CLI is unavailable" "preflight-block reason"
Assert-Contains $preflightBlockReport.nextStep.note "GITHUB_CLI_AVAILABLE" "preflight-block note"
Assert-Contains $preflightBlockReport.nextStep.note "Web dispatch URL(s) for ready templates" "preflight-block dispatch URL hint"
Assert-Contains $preflightBlockReport.nextStep.note "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "preflight-block dispatch URL hint value"
Assert-Equal @($preflightBlockReport.nextStep.dispatchUrls).Count 1 "preflight-block structured dispatch URL count"
Assert-Equal @($preflightBlockReport.nextStep.dispatchUrls)[0] "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "preflight-block structured dispatch URL"
Assert-Equal $preflightBlockReport.dispatchGithubRepository "chefbeom/object-storage-osmu" "preflight-block dispatch github repository"
Assert-Equal @($preflightBlockReport.workflowRunIdPlanActionOrders)[0] 2 "preflight-block workflow run id source action order"
Assert-Equal @($preflightBlockReport.artifactCollectionActionOrders)[0] 2 "preflight-block artifact collection source action order"
Assert-Equal $preflightBlockReport.workflowRunIdPlanScopeMismatch $false "preflight-block workflow run id scope mismatch"
Assert-Equal $preflightBlockReport.artifactCollectionScopeMismatch $false "preflight-block artifact collection scope mismatch"
Assert-Equal @($preflightBlockReport.readyDispatchWorkflows)[0].dispatchUrl "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "preflight-block ready dispatch workflow url"
Assert-Equal $preflightBlockReport.browserDispatchChecklistCount 1 "preflight-block browser dispatch checklist count"
Assert-Equal @($preflightBlockReport.browserDispatchChecklist).Count 1 "preflight-block browser dispatch checklist array count"
Assert-Equal @($preflightBlockReport.browserDispatchChecklist)[0].workflow "container-security-ci.yml" "preflight-block browser checklist workflow"
Assert-Equal @($preflightBlockReport.browserDispatchChecklist)[0].runIdParameter "ContainerSecurityRunId" "preflight-block browser checklist run id parameter"
Assert-Equal @($preflightBlockReport.browserDispatchChecklist)[0].artifactName "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68" "preflight-block browser checklist artifact name"
Assert-Equal @($preflightBlockReport.browserDispatchChecklist)[0].runListJsonPath ".\.osmu-run\workflow-run-lists\container-security-ci.yml.json" "preflight-block browser checklist run-list path"
Assert-Contains @($preflightBlockReport.browserDispatchChecklist)[0].manualArtifactCollectionCommand "-ContainerSecurityRunId <ContainerSecurityRunId>" "preflight-block browser checklist manual command"
Assert-Contains @($preflightBlockReport.browserDispatchChecklist)[0].steps[0] "select branch main" "preflight-block browser checklist branch step"
Assert-Contains @($preflightBlockReport.browserDispatchChecklist)[0].steps[3] "ContainerSecurityRunId" "preflight-block browser checklist run id step"
Assert-Contains (@(@($preflightBlockReport.browserDispatchChecklist)[0].securityFinalizerRunIdInputs) -join ",") "ContainerSecurityRunId" "preflight-block browser checklist security finalizer input"
Assert-Contains (@(@($preflightBlockReport.browserDispatchChecklist)[0].securityFinalizerMissingRunIdInputs) -join ",") "ImageSigningRunId" "preflight-block browser checklist security finalizer missing input"
Assert-Contains @($preflightBlockReport.browserDispatchChecklist)[0].securityFinalizerDependencyNote "also collect ImageSigningRunId" "preflight-block browser checklist security finalizer note"
Assert-Contains (@(@($preflightBlockReport.browserDispatchChecklist)[0].steps) -join " ") "security-evidence-finalizer-ci.yml" "preflight-block browser checklist finalizer step"
Assert-Equal $preflightBlockReport.securityEvidenceFinalizerRunIdInputHintCount 2 "preflight-block security finalizer hint count"
Assert-Equal @($preflightBlockReport.securityEvidenceFinalizerRunIdInputHints).Count 2 "preflight-block security finalizer hint array count"
$preflightBlockImageHint = @($preflightBlockReport.securityEvidenceFinalizerRunIdInputHints | Where-Object { $_.runIdParameter -eq "ImageSigningRunId" } | Select-Object -First 1)
$preflightBlockContainerHint = @($preflightBlockReport.securityEvidenceFinalizerRunIdInputHints | Where-Object { $_.runIdParameter -eq "ContainerSecurityRunId" } | Select-Object -First 1)
Assert-Equal $preflightBlockImageHint.workflow "image-publish-sign-ci.yml" "preflight-block image signing hint workflow"
Assert-Equal ([bool] $preflightBlockImageHint.supplementalForSecurityFinalizer) $true "preflight-block image signing hint supplemental flag"
Assert-Equal $preflightBlockContainerHint.workflow "container-security-ci.yml" "preflight-block container hint workflow"
Assert-Equal ([bool] $preflightBlockContainerHint.sourceSelected) $true "preflight-block container hint selected flag"
Assert-Equal @($preflightBlockReport.postDispatchCommands).Count 5 "preflight-block post-dispatch command count"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[0].command "-RunListJsonDirectory <run-list-json-dir>" "preflight-block post-dispatch fixture command"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[0].note "GitHub CLI is unavailable" "preflight-block post-dispatch fixture note"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[1].name "GitHub REST API" "preflight-block post-dispatch github api command name"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[1].command "-UseGitHubApi" "preflight-block post-dispatch github api command"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[1].note "repository Actions API" "preflight-block post-dispatch github api note"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[2].command "write-operations-workflow-run-id-plan.ps1 -Execute" "preflight-block post-dispatch gh command"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[3].command "-ContainerSecurityRunId <ContainerSecurityRunId>" "preflight-block post-dispatch browser run id artifact collection command"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[3].note "workflow run page URL" "preflight-block post-dispatch browser run id note"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[3].note "full workflow run URLs" "preflight-block post-dispatch browser run id URL note"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[4].command "write-operations-artifact-collection-plan.ps1" "preflight-block post-dispatch artifact collection command"
Assert-Contains @($preflightBlockReport.postDispatchCommands)[4].note "selected-action scope" "preflight-block post-dispatch artifact collection note"
$preflightBlockWorkflowRunStage = @($preflightBlockReport.stages | Where-Object { $_.name -eq "workflow-run-ids" } | Select-Object -First 1)
Assert-Contains $preflightBlockWorkflowRunStage.command "-UseGitHubApi" "preflight-block workflow run stage github api command"
Assert-Contains $preflightBlockWorkflowRunStage.note "GitHub REST API" "preflight-block workflow run stage github api note"
Assert-Contains $preflightBlockWorkflowRunStage.note "Browser workflow runs URL(s)" "preflight-block workflow run stage runs URL hint"
Assert-Contains $preflightBlockWorkflowRunStage.note "container-security-ci.yml" "preflight-block workflow run stage workflow label"
Assert-Contains $preflightBlockMarkdown "Open browser or API dispatch for ready subset" "preflight-block markdown next step"
Assert-Contains $preflightBlockReport.nextStep.note "API dispatch" "preflight-block API dispatch note"
Assert-Contains $preflightBlockReport.nextStep.note "GH_TOKEN" "preflight-block API token note"
Assert-Contains $preflightBlockMarkdown "Browser workflow runs URL(s): container-security-ci.yml: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "preflight-block markdown workflow runs URL hint"
Assert-Contains $preflightBlockMarkdown "dispatchUrl=https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml" "preflight-block markdown dispatch url"
Assert-Contains $preflightBlockMarkdown "## Browser Dispatch Checklist" "preflight-block markdown browser checklist section"
Assert-Contains $preflightBlockMarkdown "runIdParameter=ContainerSecurityRunId" "preflight-block markdown browser checklist run id parameter"
Assert-Contains $preflightBlockMarkdown "Run-list JSON path: .\.osmu-run\workflow-run-lists\container-security-ci.yml.json" "preflight-block markdown browser checklist run-list path"
Assert-Contains $preflightBlockMarkdown "Step: Copy the numeric run id or full workflow run URL into ContainerSecurityRunId." "preflight-block markdown browser checklist run id step"
Assert-Contains $preflightBlockMarkdown "Security finalizer missing run-id inputs: ImageSigningRunId, ContainerSecurityRunId" "preflight-block markdown browser checklist security missing inputs"
Assert-Contains $preflightBlockMarkdown "Security finalizer note: Security finalizer dependency: this dispatch can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml." "preflight-block markdown browser checklist security finalizer note"
Assert-Contains $preflightBlockMarkdown "## Security Finalizer Run-id Hints" "preflight-block markdown security finalizer hints section"
Assert-Contains $preflightBlockMarkdown "ImageSigningRunId: workflow=image-publish-sign-ci.yml / source=supplemental" "preflight-block markdown image signing hint"
Assert-Contains $preflightBlockMarkdown "ContainerSecurityRunId: workflow=container-security-ci.yml / source=selected" "preflight-block markdown container hint"
Assert-Contains $preflightBlockMarkdown "## Post Dispatch Handoff" "preflight-block markdown post-dispatch section"
Assert-Contains $preflightBlockMarkdown "-RunListJsonDirectory <run-list-json-dir>" "preflight-block markdown post-dispatch fixture command"
Assert-Contains $preflightBlockMarkdown "-UseGitHubApi" "preflight-block markdown post-dispatch github api command"
Assert-Contains $preflightBlockMarkdown "write-operations-workflow-run-id-plan.ps1 -Execute" "preflight-block markdown post-dispatch gh command"
Assert-Contains $preflightBlockMarkdown "Regenerate artifact collection plan with browser run ids" "preflight-block markdown browser run id artifact command"
Assert-Contains $preflightBlockMarkdown "-ContainerSecurityRunId <ContainerSecurityRunId>" "preflight-block markdown browser run id artifact parameter"
Assert-Contains $preflightBlockMarkdown "Regenerate artifact collection plan after run id collection" "preflight-block markdown post-dispatch artifact command"

$scopeMismatchReadinessPath = Join-Path $resolvedOutputDirectory "scope-mismatch-readiness.json"
$scopeMismatchPlanPath = Join-Path $resolvedOutputDirectory "scope-mismatch-plan.json"
$scopeMismatchInvocationPath = Join-Path $resolvedOutputDirectory "scope-mismatch-invocation.json"
$scopeMismatchDispatchPreflightPath = Join-Path $resolvedOutputDirectory "scope-mismatch-dispatch-preflight.json"
$scopeMismatchRunIdPath = Join-Path $resolvedOutputDirectory "scope-mismatch-run-ids.json"
$scopeMismatchCollectionPath = Join-Path $resolvedOutputDirectory "scope-mismatch-collection.json"
$scopeMismatchImportPath = Join-Path $resolvedOutputDirectory "scope-mismatch-import.json"
$scopeMismatchFinalizePath = Join-Path $resolvedOutputDirectory "scope-mismatch-finalize.json"
$scopeMismatchJsonPath = Join-Path $resolvedOutputDirectory "scope-mismatch-handoff.json"
$scopeMismatchMarkdownPath = Join-Path $resolvedOutputDirectory "scope-mismatch-handoff.md"

Write-JsonFixture $scopeMismatchReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=1"
})
Write-JsonFixture $scopeMismatchPlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    result = "action-required"
    pendingCount = 1
    actionCount = 1
    unplannedCount = 0
})
Write-JsonFixture $scopeMismatchInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    result = "planned"
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 0
    failedCount = 0
    actions = @(
        [ordered]@{
            order = 2
            name = "Container scan/SBOM evidence"
            status = "planned"
        }
    )
})
Write-JsonFixture $scopeMismatchDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    result = "action-required"
    githubRepository = "chefbeom/object-storage-osmu"
    selectedActionCount = 3
    selectedActionOrders = @(1, 2, 3)
    readyActionCount = 1
    readyActionOrders = @(2)
    blockedActionCount = 2
    blockedActionOrders = @(1, 3)
    missingInputCount = 0
    failedCheckCount = 1
    warningCheckCount = 0
    githubCliPath = "C:\tools\gh.exe"
    readySubsetPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -GitHubCliPath C:\tools\gh.exe -ActionOrder 2"
    readySubsetApiExecuteCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -GitHubCliPath C:\tools\gh.exe -ActionOrder 2 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute"
    checks = @(
        [ordered]@{
            code = "GITHUB_CLI_AVAILABLE"
            status = "fail"
            message = "GitHub CLI was not found on PATH."
        }
    )
    inputTemplates = @(
        [ordered]@{
            actionOrder = 2
            name = "Container scan/SBOM evidence"
            workflow = "container-security-ci.yml"
            dispatchUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
            readyToDispatch = $true
            missingInputCount = 0
            unsafeInputCount = 0
            invalidInputCount = 0
            workflowInputNames = @()
            missingInputParameters = @()
        }
    )
})
Write-JsonFixture $scopeMismatchRunIdPath ([ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    result = "query-required"
    workflowCount = 1
    readyWorkflowCount = 0
    missingWorkflowCount = 1
    staleWorkflowCount = 0
})
Write-JsonFixture $scopeMismatchCollectionPath ([ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    result = "action-required"
    artifactCount = 1
    readyArtifactCount = 0
    missingRequiredArtifactCount = 1
    sourceActionOrders = @(2)
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $scopeMismatchReadinessPath `
    -EvidencePlanPath $scopeMismatchPlanPath `
    -InvocationReportPath $scopeMismatchInvocationPath `
    -DispatchPreflightReportPath $scopeMismatchDispatchPreflightPath `
    -WorkflowRunIdPlanPath $scopeMismatchRunIdPath `
    -ArtifactCollectionPlanPath $scopeMismatchCollectionPath `
    -ArtifactImportReportPath $scopeMismatchImportPath `
    -OperationsReadinessFinalizeReportPath $scopeMismatchFinalizePath `
    -JsonOutputPath $scopeMismatchJsonPath `
    -MarkdownOutputPath $scopeMismatchMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 scope-mismatch check failed with exit code $LASTEXITCODE."
}

$scopeMismatchReport = Read-Utf8Text $scopeMismatchJsonPath | ConvertFrom-Json
$scopeMismatchMarkdown = Read-Utf8Text $scopeMismatchMarkdownPath
Assert-Equal $scopeMismatchReport.result "action-required" "scope mismatch result"
Assert-Equal $scopeMismatchReport.nextStep.code "refresh-dispatch-preflight" "scope mismatch next step"
Assert-Contains $scopeMismatchReport.nextStep.command "-ActionOrder 2" "scope mismatch refresh command action order"
Assert-Contains $scopeMismatchReport.nextStep.reason "do not match the latest invocation selected action orders" "scope mismatch reason"
Assert-Equal $scopeMismatchReport.dispatchPreflightScopeMismatch $true "scope mismatch flag"
Assert-Equal $scopeMismatchReport.staleReportCount 1 "scope mismatch stale count"
Assert-Contains (@($scopeMismatchReport.stages)[3].summary) "scopeMismatch=true" "scope mismatch stage summary"
Assert-Contains $scopeMismatchMarkdown "Refresh dispatch preflight" "scope mismatch markdown next step"
Assert-Contains $scopeMismatchMarkdown "Stale reports: 1" "scope mismatch markdown stale count"
$runIdScopeMismatchReadinessPath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-readiness.json"
$runIdScopeMismatchPlanPath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-plan.json"
$runIdScopeMismatchInvocationPath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-invocation.json"
$runIdScopeMismatchDispatchPreflightPath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-dispatch-preflight.json"
$runIdScopeMismatchRunIdPath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-run-ids.json"
$runIdScopeMismatchCollectionPath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-collection.json"
$runIdScopeMismatchImportPath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-import.json"
$runIdScopeMismatchFinalizePath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-finalize.json"
$runIdScopeMismatchJsonPath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-handoff.json"
$runIdScopeMismatchMarkdownPath = Join-Path $resolvedOutputDirectory "run-id-scope-mismatch-handoff.md"

Write-JsonFixture $runIdScopeMismatchReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=1"
})
Write-JsonFixture $runIdScopeMismatchPlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    result = "action-required"
    pendingCount = 1
    actionCount = 1
    unplannedCount = 0
})
Write-JsonFixture $runIdScopeMismatchInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    result = "planned"
    selectedActionOrders = @(2)
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 1
    failedCount = 0
    actions = @(
        [ordered]@{
            order = 2
            name = "Container scan/SBOM evidence"
            status = "planned"
        }
    )
})
Write-JsonFixture $runIdScopeMismatchDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    result = "ready"
    githubRepository = "chefbeom/object-storage-osmu"
    selectedActionCount = 1
    selectedActionOrders = @(2)
    readyActionCount = 1
    readyActionOrders = @(2)
    blockedActionCount = 0
    blockedActionOrders = @()
    missingInputCount = 0
    failedCheckCount = 0
    warningCheckCount = 0
    inputTemplates = @(
        [ordered]@{
            actionOrder = 2
            name = "Container scan/SBOM evidence"
            workflow = "container-security-ci.yml"
            readyToDispatch = $true
            missingInputCount = 0
            unsafeInputCount = 0
            invalidInputCount = 0
            workflowInputNames = @()
            missingInputParameters = @()
        }
    )
})
Write-JsonFixture $runIdScopeMismatchRunIdPath ([ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    result = "ready"
    workflowCount = 2
    readyWorkflowCount = 2
    missingWorkflowCount = 0
    staleWorkflowCount = 0
    sourceActionOrders = @(1, 2)
    artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1"
})
Write-JsonFixture $runIdScopeMismatchCollectionPath ([ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    result = "ready"
    artifactCount = 1
    readyArtifactCount = 1
    missingRequiredArtifactCount = 0
    sourceActionOrders = @(2)
    operationsArtifactFinalizerCommand = "gh workflow run operations-readiness-artifact-finalizer-ci.yml"
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $runIdScopeMismatchReadinessPath `
    -EvidencePlanPath $runIdScopeMismatchPlanPath `
    -InvocationReportPath $runIdScopeMismatchInvocationPath `
    -DispatchPreflightReportPath $runIdScopeMismatchDispatchPreflightPath `
    -WorkflowRunIdPlanPath $runIdScopeMismatchRunIdPath `
    -ArtifactCollectionPlanPath $runIdScopeMismatchCollectionPath `
    -ArtifactImportReportPath $runIdScopeMismatchImportPath `
    -OperationsReadinessFinalizeReportPath $runIdScopeMismatchFinalizePath `
    -JsonOutputPath $runIdScopeMismatchJsonPath `
    -MarkdownOutputPath $runIdScopeMismatchMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 run-id scope mismatch check failed with exit code $LASTEXITCODE."
}

$runIdScopeMismatchReport = Read-Utf8Text $runIdScopeMismatchJsonPath | ConvertFrom-Json
$runIdScopeMismatchMarkdown = Read-Utf8Text $runIdScopeMismatchMarkdownPath
$runIdScopeMismatchStage = @($runIdScopeMismatchReport.stages | Where-Object { $_.name -eq "workflow-run-ids" })[0]
Assert-Equal $runIdScopeMismatchReport.result "action-required" "run-id scope mismatch result"
Assert-Equal $runIdScopeMismatchReport.nextStep.code "refresh-run-id-plan" "run-id scope mismatch next step"
Assert-Contains $runIdScopeMismatchReport.nextStep.reason "do not match the latest invocation selected action orders" "run-id scope mismatch reason"
Assert-Equal $runIdScopeMismatchReport.workflowRunIdPlanScopeMismatch $true "run-id scope mismatch flag"
Assert-Equal $runIdScopeMismatchReport.artifactCollectionScopeMismatch $false "run-id scope mismatch artifact flag"
Assert-Equal $runIdScopeMismatchReport.staleReportCount 1 "run-id scope mismatch stale count"
Assert-Equal @($runIdScopeMismatchReport.workflowRunIdPlanActionOrders).Count 2 "run-id scope mismatch action order count"
Assert-Equal @($runIdScopeMismatchReport.workflowRunIdPlanActionOrders)[0] 1 "run-id scope mismatch first action order"
Assert-Equal @($runIdScopeMismatchReport.workflowRunIdPlanActionOrders)[1] 2 "run-id scope mismatch second action order"
Assert-Contains $runIdScopeMismatchStage.summary "scopeMismatch=true" "run-id scope mismatch stage summary"
Assert-Contains $runIdScopeMismatchMarkdown "Refresh workflow run id plan" "run-id scope mismatch markdown next step"
Assert-Contains $runIdScopeMismatchMarkdown "Stale reports: 1" "run-id scope mismatch markdown stale count"

$artifactScopeMismatchReadinessPath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-readiness.json"
$artifactScopeMismatchPlanPath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-plan.json"
$artifactScopeMismatchInvocationPath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-invocation.json"
$artifactScopeMismatchDispatchPreflightPath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-dispatch-preflight.json"
$artifactScopeMismatchRunIdPath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-run-ids.json"
$artifactScopeMismatchCollectionPath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-collection.json"
$artifactScopeMismatchImportPath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-import.json"
$artifactScopeMismatchFinalizePath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-finalize.json"
$artifactScopeMismatchJsonPath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-handoff.json"
$artifactScopeMismatchMarkdownPath = Join-Path $resolvedOutputDirectory "artifact-scope-mismatch-handoff.md"

Write-JsonFixture $artifactScopeMismatchReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=1"
})
Write-JsonFixture $artifactScopeMismatchPlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    result = "action-required"
    pendingCount = 1
    actionCount = 1
    unplannedCount = 0
})
Write-JsonFixture $artifactScopeMismatchInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    result = "planned"
    selectedActionOrders = @(2)
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 1
    failedCount = 0
    actions = @(
        [ordered]@{
            order = 2
            name = "Container scan/SBOM evidence"
            status = "planned"
        }
    )
})
Write-JsonFixture $artifactScopeMismatchDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    result = "ready"
    githubRepository = "chefbeom/object-storage-osmu"
    selectedActionCount = 1
    selectedActionOrders = @(2)
    readyActionCount = 1
    readyActionOrders = @(2)
    blockedActionCount = 0
    blockedActionOrders = @()
    missingInputCount = 0
    failedCheckCount = 0
    warningCheckCount = 0
    inputTemplates = @(
        [ordered]@{
            actionOrder = 2
            name = "Container scan/SBOM evidence"
            workflow = "container-security-ci.yml"
            readyToDispatch = $true
            missingInputCount = 0
            unsafeInputCount = 0
            invalidInputCount = 0
            workflowInputNames = @()
            missingInputParameters = @()
        }
    )
})
Write-JsonFixture $artifactScopeMismatchRunIdPath ([ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    result = "ready"
    workflowCount = 1
    readyWorkflowCount = 1
    missingWorkflowCount = 0
    staleWorkflowCount = 0
    sourceActionOrders = @(2)
    artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1"
})
Write-JsonFixture $artifactScopeMismatchCollectionPath ([ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    result = "ready"
    artifactCount = 2
    readyArtifactCount = 2
    missingRequiredArtifactCount = 0
    sourceActionOrders = @(1, 2)
    operationsArtifactFinalizerCommand = "gh workflow run operations-readiness-artifact-finalizer-ci.yml"
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $artifactScopeMismatchReadinessPath `
    -EvidencePlanPath $artifactScopeMismatchPlanPath `
    -InvocationReportPath $artifactScopeMismatchInvocationPath `
    -DispatchPreflightReportPath $artifactScopeMismatchDispatchPreflightPath `
    -WorkflowRunIdPlanPath $artifactScopeMismatchRunIdPath `
    -ArtifactCollectionPlanPath $artifactScopeMismatchCollectionPath `
    -ArtifactImportReportPath $artifactScopeMismatchImportPath `
    -OperationsReadinessFinalizeReportPath $artifactScopeMismatchFinalizePath `
    -JsonOutputPath $artifactScopeMismatchJsonPath `
    -MarkdownOutputPath $artifactScopeMismatchMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 artifact scope mismatch check failed with exit code $LASTEXITCODE."
}

$artifactScopeMismatchReport = Read-Utf8Text $artifactScopeMismatchJsonPath | ConvertFrom-Json
$artifactScopeMismatchMarkdown = Read-Utf8Text $artifactScopeMismatchMarkdownPath
$artifactScopeMismatchStage = @($artifactScopeMismatchReport.stages | Where-Object { $_.name -eq "artifact-collection" })[0]
Assert-Equal $artifactScopeMismatchReport.result "action-required" "artifact scope mismatch result"
Assert-Equal $artifactScopeMismatchReport.nextStep.code "refresh-artifact-collection-plan" "artifact scope mismatch next step"
Assert-Contains $artifactScopeMismatchReport.nextStep.command "write-operations-artifact-collection-plan.ps1" "artifact scope mismatch refresh command"
Assert-Contains $artifactScopeMismatchReport.nextStep.reason "do not match the latest invocation selected action orders" "artifact scope mismatch reason"
Assert-Equal $artifactScopeMismatchReport.workflowRunIdPlanScopeMismatch $false "artifact scope mismatch run-id flag"
Assert-Equal $artifactScopeMismatchReport.artifactCollectionScopeMismatch $true "artifact scope mismatch flag"
Assert-Equal $artifactScopeMismatchReport.staleReportCount 1 "artifact scope mismatch stale count"
Assert-Equal @($artifactScopeMismatchReport.artifactCollectionActionOrders).Count 2 "artifact scope mismatch action order count"
Assert-Equal @($artifactScopeMismatchReport.artifactCollectionActionOrders)[0] 1 "artifact scope mismatch first action order"
Assert-Equal @($artifactScopeMismatchReport.artifactCollectionActionOrders)[1] 2 "artifact scope mismatch second action order"
Assert-Contains $artifactScopeMismatchStage.summary "scopeMismatch=true" "artifact scope mismatch stage summary"
Assert-Contains $artifactScopeMismatchMarkdown "Refresh artifact collection plan" "artifact scope mismatch markdown next step"
Assert-Contains $artifactScopeMismatchMarkdown "Stale reports: 1" "artifact scope mismatch markdown stale count"

$securityOnlyReadinessPath = Join-Path $resolvedOutputDirectory "security-only-readiness.json"
$securityOnlyPlanPath = Join-Path $resolvedOutputDirectory "security-only-plan.json"
$securityOnlyInvocationPath = Join-Path $resolvedOutputDirectory "security-only-invocation.json"
$securityOnlyDispatchPreflightPath = Join-Path $resolvedOutputDirectory "security-only-dispatch-preflight.json"
$securityOnlyRunIdPath = Join-Path $resolvedOutputDirectory "security-only-run-ids.json"
$securityOnlyCollectionPath = Join-Path $resolvedOutputDirectory "security-only-collection.json"
$securityOnlyImportPath = Join-Path $resolvedOutputDirectory "security-only-import.json"
$securityOnlyFinalizePath = Join-Path $resolvedOutputDirectory "security-only-finalize.json"
$securityOnlyJsonPath = Join-Path $resolvedOutputDirectory "security-only-handoff.json"
$securityOnlyMarkdownPath = Join-Path $resolvedOutputDirectory "security-only-handoff.md"
$securityOnlyCommand = "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=104 -f container_security_run_id=105"

Write-JsonFixture $securityOnlyReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=1"
})
Write-JsonFixture $securityOnlyPlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    result = "action-required"
    pendingCount = 1
    actionCount = 1
    unplannedCount = 0
})
Write-JsonFixture $securityOnlyInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    result = "planned"
    selectedActionOrders = @(2)
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 1
    failedCount = 0
    actions = @(
        [ordered]@{
            order = 2
            name = "Container scan/SBOM evidence"
            status = "planned"
        }
    )
})
Write-JsonFixture $securityOnlyDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    result = "ready"
    githubRepository = "chefbeom/object-storage-osmu"
    selectedActionCount = 1
    selectedActionOrders = @(2)
    readyActionCount = 1
    readyActionOrders = @(2)
    blockedActionCount = 0
    blockedActionOrders = @()
    missingInputCount = 0
    failedCheckCount = 0
    warningCheckCount = 0
    inputTemplates = @(
        [ordered]@{
            actionOrder = 2
            name = "Container scan/SBOM evidence"
            workflow = "container-security-ci.yml"
            dispatchUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
            readyToDispatch = $true
            missingInputCount = 0
            unsafeInputCount = 0
            invalidInputCount = 0
            workflowInputNames = @()
            missingInputParameters = @()
        }
    )
})
Write-JsonFixture $securityOnlyRunIdPath ([ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    result = "ready"
    workflowCount = 1
    readyWorkflowCount = 1
    missingWorkflowCount = 0
    staleWorkflowCount = 0
    sourceActionOrders = @(2)
    artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 -ImageSigningRunId 104 -ContainerSecurityRunId 105"
})
Write-JsonFixture $securityOnlyCollectionPath ([ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    result = "no-readiness-artifacts"
    artifactCount = 0
    readyArtifactCount = 0
    missingRequiredArtifactCount = 0
    sourceActionOrders = @(2)
    securityEvidenceFinalizerCommand = $securityOnlyCommand
    operationsArtifactFinalizerCommand = ""
    localImportCommand = ""
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $securityOnlyReadinessPath `
    -EvidencePlanPath $securityOnlyPlanPath `
    -InvocationReportPath $securityOnlyInvocationPath `
    -DispatchPreflightReportPath $securityOnlyDispatchPreflightPath `
    -WorkflowRunIdPlanPath $securityOnlyRunIdPath `
    -ArtifactCollectionPlanPath $securityOnlyCollectionPath `
    -ArtifactImportReportPath $securityOnlyImportPath `
    -OperationsReadinessFinalizeReportPath $securityOnlyFinalizePath `
    -JsonOutputPath $securityOnlyJsonPath `
    -MarkdownOutputPath $securityOnlyMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 security-only collection check failed with exit code $LASTEXITCODE."
}

$securityOnlyReport = Read-Utf8Text $securityOnlyJsonPath | ConvertFrom-Json
$securityOnlyMarkdown = Read-Utf8Text $securityOnlyMarkdownPath
$securityOnlyStage = @($securityOnlyReport.stages | Where-Object { $_.name -eq "artifact-collection" })[0]
Assert-Equal $securityOnlyReport.result "action-required" "security-only result"
Assert-Equal $securityOnlyReport.nextStep.code "complete-artifact-collection-plan" "security-only next step"
Assert-Equal $securityOnlyStage.ready $false "security-only artifact stage ready"
Assert-Equal $securityOnlyStage.command $securityOnlyCommand "security-only artifact stage command"
Assert-Contains $securityOnlyMarkdown "security-evidence-finalizer-ci.yml" "security-only markdown stage command"

$finalizerReadinessPath = Join-Path $resolvedOutputDirectory "finalizer-readiness.json"
$finalizerPlanPath = Join-Path $resolvedOutputDirectory "finalizer-plan.json"
$finalizerInvocationPath = Join-Path $resolvedOutputDirectory "finalizer-invocation.json"
$finalizerRunIdPath = Join-Path $resolvedOutputDirectory "finalizer-run-ids.json"
$finalizerCollectionPath = Join-Path $resolvedOutputDirectory "finalizer-collection.json"
$finalizerImportPath = Join-Path $resolvedOutputDirectory "finalizer-import.json"
$finalizerFinalizePath = Join-Path $resolvedOutputDirectory "finalizer-finalize.json"
$finalizerJsonPath = Join-Path $resolvedOutputDirectory "finalizer-handoff.json"
$finalizerMarkdownPath = Join-Path $resolvedOutputDirectory "finalizer-handoff.md"

Write-JsonFixture $finalizerReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=6"
})
Write-JsonFixture $finalizerPlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    result = "action-required"
    pendingCount = 6
    actionCount = 6
    unplannedCount = 0
})
Write-JsonFixture $finalizerInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    result = "planned"
    selectedActionCount = 6
    plannedCount = 6
    blockedCount = 0
    executedCount = 6
    failedCount = 0
})
Write-JsonFixture $finalizerRunIdPath ([ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    result = "ready"
    workflowCount = 6
    readyWorkflowCount = 6
    missingWorkflowCount = 0
    staleWorkflowCount = 0
    artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 -StorageExpansionRunId 101"
})
Write-JsonFixture $finalizerCollectionPath ([ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    result = "ready"
    artifactCount = 6
    readyArtifactCount = 6
    missingRequiredArtifactCount = 0
    operationsArtifactFinalizerCommand = "gh workflow run operations-readiness-artifact-finalizer-ci.yml -f storage_expansion_run_id=101"
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $finalizerReadinessPath `
    -EvidencePlanPath $finalizerPlanPath `
    -InvocationReportPath $finalizerInvocationPath `
    -DispatchPreflightReportPath $missingDispatchPreflightPath `
    -WorkflowRunIdPlanPath $finalizerRunIdPath `
    -ArtifactCollectionPlanPath $finalizerCollectionPath `
    -ArtifactImportReportPath $finalizerImportPath `
    -OperationsReadinessFinalizeReportPath $finalizerFinalizePath `
    -JsonOutputPath $finalizerJsonPath `
    -MarkdownOutputPath $finalizerMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 finalizer-report check failed with exit code $LASTEXITCODE."
}

$finalizerReport = Read-Utf8Text $finalizerJsonPath | ConvertFrom-Json
$finalizerMarkdown = Read-Utf8Text $finalizerMarkdownPath
Assert-Equal $finalizerReport.result "action-required" "finalizer result"
Assert-Equal $finalizerReport.nextStep.code "run-artifact-finalizer" "finalizer next step"
Assert-Equal $finalizerReport.missingRequiredArtifactCount 0 "finalizer missing artifact count"
Assert-Contains $finalizerReport.nextStep.command "operations-readiness-artifact-finalizer-ci.yml" "finalizer command"
Assert-Contains $finalizerMarkdown "Run operations artifact finalizer" "finalizer markdown next step"

$operationsFinalizeReadinessPath = Join-Path $resolvedOutputDirectory "operations-finalize-readiness.json"
$operationsFinalizePlanPath = Join-Path $resolvedOutputDirectory "operations-finalize-plan.json"
$operationsFinalizeInvocationPath = Join-Path $resolvedOutputDirectory "operations-finalize-invocation.json"
$operationsFinalizeRunIdPath = Join-Path $resolvedOutputDirectory "operations-finalize-run-ids.json"
$operationsFinalizeCollectionPath = Join-Path $resolvedOutputDirectory "operations-finalize-collection.json"
$operationsFinalizeImportPath = Join-Path $resolvedOutputDirectory "operations-finalize-import.json"
$operationsFinalizeFinalizePath = Join-Path $resolvedOutputDirectory "operations-finalize-finalize.json"
$operationsFinalizeJsonPath = Join-Path $resolvedOutputDirectory "operations-finalize-handoff.json"
$operationsFinalizeMarkdownPath = Join-Path $resolvedOutputDirectory "operations-finalize-handoff.md"

Write-JsonFixture $operationsFinalizeReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=6"
})
Write-JsonFixture $operationsFinalizePlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    result = "action-required"
    pendingCount = 6
    actionCount = 6
    unplannedCount = 0
})
Write-JsonFixture $operationsFinalizeInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    result = "planned"
    selectedActionCount = 6
    plannedCount = 6
    blockedCount = 0
    executedCount = 6
    failedCount = 0
})
Write-JsonFixture $operationsFinalizeRunIdPath ([ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    result = "ready"
    workflowCount = 6
    readyWorkflowCount = 6
    missingWorkflowCount = 0
    staleWorkflowCount = 0
    artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 -StorageExpansionRunId 101"
})
Write-JsonFixture $operationsFinalizeCollectionPath ([ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    result = "ready"
    artifactCount = 6
    readyArtifactCount = 6
    missingRequiredArtifactCount = 0
    operationsArtifactFinalizerCommand = "gh workflow run operations-readiness-artifact-finalizer-ci.yml -f storage_expansion_run_id=101"
})
Write-JsonFixture $operationsFinalizeImportPath ([ordered]@{
    formatVersion = "osmu.operations-readiness-artifact-import.v1"
    result = "passed"
    status = "artifact-import-passed"
    selectedGroupCount = 6
    importedCount = 6
    failedCount = 0
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $operationsFinalizeReadinessPath `
    -EvidencePlanPath $operationsFinalizePlanPath `
    -InvocationReportPath $operationsFinalizeInvocationPath `
    -DispatchPreflightReportPath $missingDispatchPreflightPath `
    -WorkflowRunIdPlanPath $operationsFinalizeRunIdPath `
    -ArtifactCollectionPlanPath $operationsFinalizeCollectionPath `
    -ArtifactImportReportPath $operationsFinalizeImportPath `
    -OperationsReadinessFinalizeReportPath $operationsFinalizeFinalizePath `
    -JsonOutputPath $operationsFinalizeJsonPath `
    -MarkdownOutputPath $operationsFinalizeMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 operations-finalizer missing check failed with exit code $LASTEXITCODE."
}

$operationsFinalizeReport = Read-Utf8Text $operationsFinalizeJsonPath | ConvertFrom-Json
$operationsFinalizeMarkdown = Read-Utf8Text $operationsFinalizeMarkdownPath
Assert-Equal $operationsFinalizeReport.result "action-required" "operations finalizer result"
Assert-Equal $operationsFinalizeReport.nextStep.code "run-operations-finalizer" "operations finalizer next step"
Assert-Equal $operationsFinalizeReport.stageCount 10 "operations finalizer stage count"
Assert-Contains $operationsFinalizeReport.nextStep.command "finalize-operations-readiness.ps1" "operations finalizer command"
Assert-Contains $operationsFinalizeMarkdown "Run operations readiness finalizer" "operations finalizer markdown next step"

$pendingFinalizePath = Join-Path $resolvedOutputDirectory "pending-finalize.json"
$pendingHandoffPath = Join-Path $resolvedOutputDirectory "pending-finalize-handoff.json"
$pendingMarkdownPath = Join-Path $resolvedOutputDirectory "pending-finalize-handoff.md"
Write-JsonFixture $pendingFinalizePath ([ordered]@{
    formatVersion = "osmu.operations-readiness-finalize.v1"
    result = "pending"
    status = "operations-readiness-finalize-pending"
    readinessResult = "pending"
    failedCount = 0
    gaps = @("Operations readiness result is pending: passed=36 pending=6.")
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $operationsFinalizeReadinessPath `
    -EvidencePlanPath $operationsFinalizePlanPath `
    -InvocationReportPath $operationsFinalizeInvocationPath `
    -DispatchPreflightReportPath $missingDispatchPreflightPath `
    -WorkflowRunIdPlanPath $operationsFinalizeRunIdPath `
    -ArtifactCollectionPlanPath $operationsFinalizeCollectionPath `
    -ArtifactImportReportPath $operationsFinalizeImportPath `
    -OperationsReadinessFinalizeReportPath $pendingFinalizePath `
    -JsonOutputPath $pendingHandoffPath `
    -MarkdownOutputPath $pendingMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 operations-finalizer pending check failed with exit code $LASTEXITCODE."
}

$pendingReport = Read-Utf8Text $pendingHandoffPath | ConvertFrom-Json
Assert-Equal $pendingReport.nextStep.code "fix-operations-finalizer" "pending finalizer next step"
Assert-Equal $pendingReport.finalizerGapCount 1 "pending finalizer gap count"
Assert-Contains $pendingReport.nextStep.reason "readiness=pending" "pending finalizer reason"

$gapReadyFinalizePath = Join-Path $resolvedOutputDirectory "gap-ready-finalize.json"
$gapReadyHandoffPath = Join-Path $resolvedOutputDirectory "gap-ready-finalize-handoff.json"
$gapReadyMarkdownPath = Join-Path $resolvedOutputDirectory "gap-ready-finalize-handoff.md"
Write-JsonFixture $gapReadyFinalizePath ([ordered]@{
    formatVersion = "osmu.operations-readiness-finalize.v1"
    result = "ready"
    status = "operations-readiness-finalize-ready"
    readinessResult = "ready"
    failedCount = 1
    gaps = @("Security evidence finalizer report is missing.")
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $operationsFinalizeReadinessPath `
    -EvidencePlanPath $operationsFinalizePlanPath `
    -InvocationReportPath $operationsFinalizeInvocationPath `
    -DispatchPreflightReportPath $missingDispatchPreflightPath `
    -WorkflowRunIdPlanPath $operationsFinalizeRunIdPath `
    -ArtifactCollectionPlanPath $operationsFinalizeCollectionPath `
    -ArtifactImportReportPath $operationsFinalizeImportPath `
    -OperationsReadinessFinalizeReportPath $gapReadyFinalizePath `
    -JsonOutputPath $gapReadyHandoffPath `
    -MarkdownOutputPath $gapReadyMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 operations-finalizer gap-ready check failed with exit code $LASTEXITCODE."
}

$gapReadyReport = Read-Utf8Text $gapReadyHandoffPath | ConvertFrom-Json
$gapReadyStage = @($gapReadyReport.stages | Where-Object { $_.name -eq "operations-finalizer" })[0]
Assert-Equal $gapReadyReport.result "action-required" "gap-ready finalizer result"
Assert-Equal $gapReadyReport.nextStep.code "fix-operations-finalizer" "gap-ready finalizer next step"
Assert-Equal $gapReadyReport.finalizerFailedCount 1 "gap-ready finalizer failed count"
Assert-Equal $gapReadyReport.finalizerGapCount 1 "gap-ready finalizer gap count"
Assert-Equal $gapReadyStage.ready $false "gap-ready finalizer stage ready"
Assert-Contains $gapReadyReport.nextStep.reason "failed=1, gaps=1" "gap-ready finalizer reason"

$readyReadinessPath = Join-Path $resolvedOutputDirectory "ready-readiness.json"
$readyMissingFinalizePath = Join-Path $resolvedOutputDirectory "ready-missing-finalize.json"
$readyMissingFinalizeHandoffPath = Join-Path $resolvedOutputDirectory "ready-missing-finalize-handoff.json"
$readyMissingFinalizeMarkdownPath = Join-Path $resolvedOutputDirectory "ready-missing-finalize-handoff.md"
$readyGapFinalizePath = Join-Path $resolvedOutputDirectory "ready-gap-finalize.json"
$readyGapHandoffPath = Join-Path $resolvedOutputDirectory "ready-gap-finalize-handoff.json"
$readyGapMarkdownPath = Join-Path $resolvedOutputDirectory "ready-gap-finalize-handoff.md"
$readyFinalizePath = Join-Path $resolvedOutputDirectory "ready-finalize.json"
$readyHandoffPath = Join-Path $resolvedOutputDirectory "ready-handoff.json"
$readyMarkdownPath = Join-Path $resolvedOutputDirectory "ready-handoff.md"

Write-JsonFixture $readyReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "ready"
    summary = "passed=54 pending=0"
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $readyReadinessPath `
    -EvidencePlanPath $missingPlanPath `
    -InvocationReportPath $missingInvocationPath `
    -DispatchPreflightReportPath $missingDispatchPreflightPath `
    -WorkflowRunIdPlanPath $missingRunIdPath `
    -ArtifactCollectionPlanPath $missingCollectionPath `
    -ArtifactImportReportPath $missingImportPath `
    -OperationsReadinessFinalizeReportPath $readyMissingFinalizePath `
    -JsonOutputPath $readyMissingFinalizeHandoffPath `
    -MarkdownOutputPath $readyMissingFinalizeMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 ready-without-finalizer check failed with exit code $LASTEXITCODE."
}

$readyMissingFinalizeReport = Read-Utf8Text $readyMissingFinalizeHandoffPath | ConvertFrom-Json
$readyMissingFinalizeMarkdown = Read-Utf8Text $readyMissingFinalizeMarkdownPath
Assert-Equal $readyMissingFinalizeReport.result "action-required" "ready missing finalizer result"
Assert-Equal $readyMissingFinalizeReport.nextStep.code "run-operations-finalizer" "ready missing finalizer next step"
Assert-Contains $readyMissingFinalizeReport.nextStep.reason "finalizer report is missing" "ready missing finalizer reason"
Assert-Contains $readyMissingFinalizeMarkdown "Run operations readiness finalizer" "ready missing finalizer markdown next step"

Write-JsonFixture $readyGapFinalizePath ([ordered]@{
    formatVersion = "osmu.operations-readiness-finalize.v1"
    result = "ready"
    status = "operations-readiness-finalize-ready"
    readinessResult = "ready"
    failedCount = 1
    gaps = @("Operations readiness finalizer retained a gap.")
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $readyReadinessPath `
    -EvidencePlanPath $missingPlanPath `
    -InvocationReportPath $missingInvocationPath `
    -DispatchPreflightReportPath $missingDispatchPreflightPath `
    -WorkflowRunIdPlanPath $missingRunIdPath `
    -ArtifactCollectionPlanPath $missingCollectionPath `
    -ArtifactImportReportPath $missingImportPath `
    -OperationsReadinessFinalizeReportPath $readyGapFinalizePath `
    -JsonOutputPath $readyGapHandoffPath `
    -MarkdownOutputPath $readyGapMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 ready-with-gap-finalizer check failed with exit code $LASTEXITCODE."
}

$readyGapReport = Read-Utf8Text $readyGapHandoffPath | ConvertFrom-Json
$readyGapStage = @($readyGapReport.stages | Where-Object { $_.name -eq "operations-finalizer" })[0]
Assert-Equal $readyGapReport.result "action-required" "ready gap finalizer result"
Assert-Equal $readyGapReport.nextStep.code "fix-operations-finalizer" "ready gap finalizer next step"
Assert-Equal $readyGapReport.finalizerFailedCount 1 "ready gap finalizer failed count"
Assert-Equal $readyGapReport.finalizerGapCount 1 "ready gap finalizer gap count"
Assert-Equal $readyGapStage.ready $false "ready gap finalizer stage ready"
Assert-Contains $readyGapReport.nextStep.reason "failed=1, gaps=1" "ready gap finalizer reason"

Write-JsonFixture $readyFinalizePath ([ordered]@{
    formatVersion = "osmu.operations-readiness-finalize.v1"
    result = "ready"
    status = "operations-readiness-finalize-ready"
    readinessResult = "ready"
    failedCount = 0
    gaps = @()
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $readyReadinessPath `
    -EvidencePlanPath $missingPlanPath `
    -InvocationReportPath $missingInvocationPath `
    -DispatchPreflightReportPath $missingDispatchPreflightPath `
    -WorkflowRunIdPlanPath $missingRunIdPath `
    -ArtifactCollectionPlanPath $missingCollectionPath `
    -ArtifactImportReportPath $missingImportPath `
    -OperationsReadinessFinalizeReportPath $readyFinalizePath `
    -JsonOutputPath $readyHandoffPath `
    -MarkdownOutputPath $readyMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 ready-with-finalizer check failed with exit code $LASTEXITCODE."
}

$readyReport = Read-Utf8Text $readyHandoffPath | ConvertFrom-Json
Assert-Equal $readyReport.result "ready" "ready handoff result"
Assert-Equal $readyReport.nextStep.code "none" "ready handoff next step"
Assert-Equal $readyReport.readyStageCount 2 "ready handoff stage count"
Assert-Contains $readyReport.nextStep.reason "operations finalizer reports are ready" "ready handoff reason"

$valuesStageReadinessPath = Join-Path $resolvedOutputDirectory "values-stage-readiness.json"
$valuesStagePlanPath = Join-Path $resolvedOutputDirectory "values-stage-plan.json"
$valuesStageInvocationPath = Join-Path $resolvedOutputDirectory "values-stage-invocation.json"
$valuesStageDispatchPreflightPath = Join-Path $resolvedOutputDirectory "values-stage-dispatch-preflight.json"
$valuesStageWorksheetPath = Join-Path $resolvedOutputDirectory "values-stage-operator-worksheet.json"
$valuesStageTemplatePath = Join-Path $resolvedOutputDirectory "values-stage-operator-values-template.json"
$valuesStageCheckPath = Join-Path $resolvedOutputDirectory "values-stage-operator-values-check.json"
$valuesStageRunIdPath = Join-Path $resolvedOutputDirectory "values-stage-run-ids.json"
$valuesStageCollectionPath = Join-Path $resolvedOutputDirectory "values-stage-collection.json"
$valuesStageImportPath = Join-Path $resolvedOutputDirectory "values-stage-import.json"
$valuesStageFinalizePath = Join-Path $resolvedOutputDirectory "values-stage-finalize.json"
$valuesStageHandoffPath = Join-Path $resolvedOutputDirectory "values-stage-handoff.json"
$valuesStageMarkdownPath = Join-Path $resolvedOutputDirectory "values-stage-handoff.md"

Write-JsonFixture $valuesStageReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=36 pending=1"
})
Write-JsonFixture $valuesStagePlanPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    result = "action-required"
    pendingCount = 1
    actionCount = 1
    unplannedCount = 0
})
Write-JsonFixture $valuesStageInvocationPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    result = "planned"
    selectedActionOrders = @(2)
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 1
    failedCount = 0
})
Write-JsonFixture $valuesStageDispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    generatedAt = "2026-06-27T10:10:00+09:00"
    result = "ready"
    selectedActionOrders = @(2)
    selectedActionCount = 1
    missingInputCount = 0
    inputTemplates = @()
})
Write-JsonFixture $valuesStageWorksheetPath ([ordered]@{
    formatVersion = "osmu.operations-operator-input-worksheet.v1"
    generatedAt = "2026-06-27T10:15:00+09:00"
    result = "action-required"
    sourceDispatchPreflightReport = $valuesStageDispatchPreflightPath
    inputValuesTemplatePath = $valuesStageTemplatePath
    inputRowCount = 2
    ambiguousInputRowCount = 0
    inputFreeActionCount = 0
    requiredSecretCount = 0
})
Write-JsonFixture $valuesStageCheckPath ([ordered]@{
    formatVersion = "osmu.operations-operator-input-values-check.v1"
    generatedAt = "2026-06-27T10:20:00+09:00"
    result = "ready"
    sourceValuesTemplate = $valuesStageTemplatePath
    valueCount = 2
    readyValueCount = 2
    missingValueCount = 0
    unsafeValueCount = 0
    invalidValueCount = 0
    actionSummaryCount = 1
    valueReadyActionCount = 1
    nonReadyActionCount = 0
})
Write-JsonFixture $valuesStageRunIdPath ([ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    result = "ready"
    workflowCount = 1
    readyWorkflowCount = 1
    missingWorkflowCount = 0
    staleWorkflowCount = 0
    sourceActionOrders = @(2)
})
Write-JsonFixture $valuesStageCollectionPath ([ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    result = "ready"
    artifactCount = 1
    readyArtifactCount = 1
    missingRequiredArtifactCount = 0
    sourceActionOrders = @(2)
})
Write-JsonFixture $valuesStageImportPath ([ordered]@{
    formatVersion = "osmu.operations-readiness-artifact-import.v1"
    result = "passed"
    failedCount = 0
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $valuesStageReadinessPath `
    -EvidencePlanPath $valuesStagePlanPath `
    -InvocationReportPath $valuesStageInvocationPath `
    -DispatchPreflightReportPath $valuesStageDispatchPreflightPath `
    -OperatorInputWorksheetReportPath $valuesStageWorksheetPath `
    -OperatorInputValuesCheckReportPath $valuesStageCheckPath `
    -WorkflowRunIdPlanPath $valuesStageRunIdPath `
    -ArtifactCollectionPlanPath $valuesStageCollectionPath `
    -ArtifactImportReportPath $valuesStageImportPath `
    -OperationsReadinessFinalizeReportPath $valuesStageFinalizePath `
    -JsonOutputPath $valuesStageHandoffPath `
    -MarkdownOutputPath $valuesStageMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 values-stage check failed with exit code $LASTEXITCODE."
}

$valuesStageReport = Read-Utf8Text $valuesStageHandoffPath | ConvertFrom-Json
$valuesStage = @($valuesStageReport.stages | Where-Object { $_.name -eq "operator-input-values-check" } | Select-Object -First 1)
Assert-Equal $valuesStageReport.stageCount 10 "values stage count"
Assert-Equal $valuesStageReport.operatorInputValuesCheckResult "ready" "values stage result"
Assert-Equal $valuesStageReport.operatorInputValuesCheckValueCount 2 "values stage value count"
Assert-Equal $valuesStageReport.operatorInputValuesCheckValueReadyActionCount 1 "values stage ready action count"
Assert-Equal $valuesStageReport.operatorInputValuesCheckNonReadyActionCount 0 "values stage non-ready action count"
Assert-Equal $valuesStage.ready $true "values stage ready flag"
Assert-Contains $valuesStage.summary "values=2 ready=2 missing=0 unsafe=0 invalid=0" "values stage summary"
Assert-Contains $valuesStage.summary "readyActions=1 nonReadyActions=0" "values stage action summary"
Write-Host "Operations evidence handoff verified."
Write-Host "Missing report: $missingJsonPath"
Write-Host "Blocked report: $blockedJsonPath"
Write-Host "Dispatch preflight scope mismatch report: $scopeMismatchJsonPath"
Write-Host "Workflow run id scope mismatch report: $runIdScopeMismatchJsonPath"
Write-Host "Artifact collection scope mismatch report: $artifactScopeMismatchJsonPath"
Write-Host "Security-only artifact collection report: $securityOnlyJsonPath"
Write-Host "Finalizer report: $finalizerJsonPath"
Write-Host "Operations finalizer report: $operationsFinalizeJsonPath"
Write-Host "Pending finalizer report: $pendingHandoffPath"
Write-Host "Ready missing finalizer report: $readyMissingFinalizeHandoffPath"
Write-Host "Ready report: $readyHandoffPath"
