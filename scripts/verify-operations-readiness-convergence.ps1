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

$missingReport = Read-Utf8Text $missingJsonPath | ConvertFrom-Json
$missingMarkdown = Read-Utf8Text $missingMarkdownPath
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
    passedCount = 36
    pendingCount = 6
    totalCount = 42
    checkCount = 42
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
    inputFreeBlockedActionCount = 2
    inputFreeBlockedActionOrders = @(1, 5)
    inputFreeBlockedReviewCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,5 -NoWrite"
    inputFreeBlockedConfirmedPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,5 -KubeconfigSecretConfirmed -ConfirmOperatorApproval"
    inputFreeBlockedActions = @(
        [ordered]@{ actionOrder = 1; name = "Storage expansion finalizer live evidence"; blockReasonCount = 2; blockReasons = @("operator approval not confirmed", "kubeconfig secret not confirmed"); requiredSecretCount = 1; requiredSecrets = @("OSMU_KUBECONFIG_BASE64"); needsOperatorApprovalConfirmation = $true; needsKubeconfigSecretConfirmation = $true; defaultBranchWorkflowMissing = $false; reviewCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -NoWrite"; confirmedPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval"; planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval" },
        [ordered]@{ actionOrder = 5; name = "Signed image evidence"; blockReasonCount = 1; blockReasons = @("operator approval not confirmed"); requiredSecretCount = 1; requiredSecrets = @("GITHUB_TOKEN"); needsOperatorApprovalConfirmation = $true; needsKubeconfigSecretConfirmation = $false; defaultBranchWorkflowMissing = $false; reviewCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 5 -NoWrite"; confirmedPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 5 -ConfirmOperatorApproval"; planCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 5 -ConfirmOperatorApproval" }
    )
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

$actionReport = Read-Utf8Text $actionJsonPath | ConvertFrom-Json
$actionMarkdown = Read-Utf8Text $actionMarkdownPath
Assert-Equal $actionReport.result "action-required" "action result"
Assert-Equal $actionReport.currentBottleneck.code "run-operations-finalizer" "action bottleneck"
Assert-Equal $actionReport.stageCount 7 "action stage count"
Assert-Equal $actionReport.readyStageCount 5 "action ready stage count"
Assert-Equal $actionReport.handoffInputFreeBlockedActionCount 2 "action input-free blocked action count"
Assert-Equal (@($actionReport.handoffInputFreeBlockedActionOrders) -join ",") "1,5" "action input-free blocked action orders"
Assert-Equal $actionReport.handoffInputFreeBlockedReviewCommand "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,5 -NoWrite" "action input-free aggregate review command"
Assert-Equal $actionReport.handoffInputFreeBlockedConfirmedPlanCommand "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,5 -KubeconfigSecretConfirmed -ConfirmOperatorApproval" "action input-free aggregate confirmed plan command"
Assert-Equal @($actionReport.handoffInputFreeBlockedActions).Count 2 "action input-free blocked action detail count"
Assert-Equal @($actionReport.handoffInputFreeBlockedActions)[0].actionOrder 1 "action input-free blocked detail action order"
Assert-True (@(@($actionReport.handoffInputFreeBlockedActions)[0].requiredSecrets) -contains "OSMU_KUBECONFIG_BASE64") "action input-free blocked detail required secret"
Assert-Contains @($actionReport.handoffInputFreeBlockedActions)[1].reviewCommand "-ActionOrder 5" "action input-free blocked detail review command"
Assert-Contains @($actionReport.handoffInputFreeBlockedActions)[1].confirmedPlanCommand "-ConfirmOperatorApproval" "action input-free blocked detail confirmed plan command"
Assert-Equal $actionReport.readinessSummary "passed=36 pending=6" "action readiness summary"
Assert-Equal $actionReport.readinessPassedCount 36 "action readiness passed count"
Assert-Equal $actionReport.readinessPendingCount 6 "action readiness pending count"
Assert-Equal $actionReport.readinessTotalCount 42 "action readiness total count"
Assert-Equal $actionReport.readinessCheckCount 42 "action readiness check count"
Assert-Contains $actionMarkdown "Readiness counts: passed=36 pending=6 total=42 checks=42" "action markdown readiness counts"
Assert-Contains $actionMarkdown "Input-free blocked action orders: 1,5" "action markdown input-free action orders"
Assert-Contains $actionMarkdown "Input-free review command: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,5 -NoWrite``" "action markdown input-free aggregate review command"
Assert-Contains $actionMarkdown "Input-free confirmed plan command: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,5 -KubeconfigSecretConfirmed -ConfirmOperatorApproval``" "action markdown input-free aggregate confirmed plan command"
Assert-Contains $actionMarkdown "## Handoff Input-Free Blocked Actions" "action markdown input-free detail section"
Assert-Contains $actionMarkdown "Action 1: Storage expansion finalizer live evidence" "action markdown input-free action detail"
Assert-Contains $actionMarkdown "secrets=OSMU_KUBECONFIG_BASE64" "action markdown input-free required secret"
Assert-Contains $actionMarkdown "review=``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -NoWrite``" "action markdown input-free review command"
Assert-Contains $actionMarkdown "confirmedPlan=``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval``" "action markdown input-free confirmed plan command"
Assert-Contains $actionReport.recommendedCommands[0].command "finalize-operations-readiness.ps1" "action recommended command"
Assert-Contains $actionMarkdown "Run operations readiness finalizer" "action markdown command"

$staleHandoffPath = Join-Path $resolvedOutputDirectory "stale-handoff.json"
$staleReadinessPath = Join-Path $resolvedOutputDirectory "stale-readiness.json"
$staleJsonPath = Join-Path $resolvedOutputDirectory "stale-handoff-convergence.json"
$staleMarkdownPath = Join-Path $resolvedOutputDirectory "stale-handoff-convergence.md"
Write-JsonFixture $staleReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    generatedAt = "2026-06-29T00:10:00+00:00"
    result = "pending"
    summary = "passed=40 pending=2"
})
Write-JsonFixture $staleHandoffPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-handoff.v1"
    generatedAt = "2026-06-29T00:05:00+00:00"
    result = "action-required"
    nextStep = [ordered]@{
        code = "dispatch-ready-subset"
        title = "Plan stale ready dispatch subset"
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 2"
        reason = "This stale handoff should not be trusted."
        note = "Old browser dispatch note."
    }
    stageCount = 8
    readyStageCount = 1
    blockedActionCount = 5
    missingWorkflowRunCount = 6
    missingRequiredArtifactCount = 4
    failedImportCount = 0
    finalizerFailedCount = 0
    finalizerGapCount = 1
    stages = @()
})
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $staleHandoffPath `
    -ReadinessReportPath $staleReadinessPath `
    -OperationsReadinessFinalizeReportPath $actionFinalizePath `
    -KubernetesOperationsReportSyncReportPath $actionSyncPath `
    -JsonOutputPath $staleJsonPath `
    -MarkdownOutputPath $staleMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 stale-handoff check failed with exit code $LASTEXITCODE."
}
$staleReport = Read-Utf8Text $staleJsonPath | ConvertFrom-Json
$staleMarkdown = Read-Utf8Text $staleMarkdownPath
Assert-Equal $staleReport.result "action-required" "stale handoff result"
Assert-Equal $staleReport.currentBottleneck.code "refresh-handoff" "stale handoff bottleneck"
Assert-Equal $staleReport.handoffStale $true "stale handoff flag"
Assert-Equal $staleReport.handoffTimestampSource "generatedAt" "stale handoff timestamp source"
Assert-Equal $staleReport.readinessTimestampSource "generatedAt" "stale readiness timestamp source"
Assert-Contains $staleReport.recommendedCommands[0].command "write-operations-evidence-handoff.ps1" "stale handoff refresh command"
Assert-Contains $staleReport.currentBottleneck.note "Readiness timestamp" "stale handoff bottleneck note"
Assert-Contains $staleMarkdown "Handoff stale: True" "stale handoff markdown flag"
Assert-Contains $staleMarkdown "Refresh operations evidence handoff" "stale handoff markdown command"
$readySubsetHandoffPath = Join-Path $resolvedOutputDirectory "ready-subset-handoff.json"
$readySubsetJsonPath = Join-Path $resolvedOutputDirectory "ready-subset-convergence.json"
$readySubsetMarkdownPath = Join-Path $resolvedOutputDirectory "ready-subset-convergence.md"
Write-JsonFixture $readySubsetHandoffPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-handoff.v1"
    result = "blocked"
    nextStep = [ordered]@{
        code = "dispatch-ready-subset"
        title = "Plan ready dispatch subset"
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 2"
        reason = "The invocation report still has blocked actions, but 1 action(s) are ready to dispatch: 2."
        note = "Run the ready subset plan command first without -Execute. Web dispatch URL(s) for ready templates: action 2: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml. Review failed preflight checks and operator approvals before using browser dispatch."
    }
    stageCount = 8
    readyStageCount = 1
    blockedActionCount = 5
    missingWorkflowRunCount = 6
    missingRequiredArtifactCount = 4
    failedImportCount = 0
    finalizerFailedCount = 0
    finalizerGapCount = 1
    readyDispatchWorkflows = @(
        [ordered]@{
            actionOrder = 2
            name = "Container scan/SBOM evidence"
            workflow = "container-security-ci.yml"
            dispatchUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
            readyToDispatch = $true
        }
    )
    browserDispatchChecklist = @(
        [ordered]@{
            actionOrder = 2
            workflow = "container-security-ci.yml"
            runIdParameter = "ContainerSecurityRunId"
            securityFinalizerMissingRunIdInputs = @("ImageSigningRunId", "ContainerSecurityRunId")
            securityFinalizerDependencyNote = "Security finalizer dependency: this dispatch can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml."
        }
    )
    securityEvidenceFinalizerRunIdInputHintCount = 2
    securityEvidenceFinalizerRunIdInputHints = @(
        [ordered]@{
            workflow = "image-publish-sign-ci.yml"
            group = "image-signing-source"
            actionOrders = @()
            runIdParameter = "ImageSigningRunId"
            artifactName = "osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68"
            runsUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"
            runListJsonPath = ".\.osmu-run\workflow-run-lists\image-publish-sign-ci.yml.json"
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
            sourceSelected = $true
            supplementalForSecurityFinalizer = $false
        }
    )
    postDispatchCommands = @(
        [ordered]@{
            name = "Collect workflow run ids from saved run-list JSON"
            command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>"
            note = "Use after browser dispatch when GitHub CLI is unavailable locally."
        },
        [ordered]@{
            name = "Regenerate artifact collection plan after run id collection"
            command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha abc123"
            note = "Keep artifact collection in the same selected-action scope."
        }
    )
    stages = @(
        [ordered]@{
            name = "dispatch-preflight"
            exists = $true
            ready = $false
            result = "action-required"
            summary = "selected=6 readyTemplates=1 blockedTemplates=5"
            command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-dispatch-preflight.ps1 -CheckGitHubCli"
            note = "No-execute workflow dispatch preflight and input template readiness."
        }
    )
})
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $readySubsetHandoffPath `
    -ReadinessReportPath $actionReadinessPath `
    -OperationsReadinessFinalizeReportPath $actionFinalizePath `
    -KubernetesOperationsReportSyncReportPath $actionSyncPath `
    -JsonOutputPath $readySubsetJsonPath `
    -MarkdownOutputPath $readySubsetMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 ready-subset check failed with exit code $LASTEXITCODE."
}
$readySubsetReport = Read-Utf8Text $readySubsetJsonPath | ConvertFrom-Json
$readySubsetMarkdown = Read-Utf8Text $readySubsetMarkdownPath
Assert-Equal $readySubsetReport.result "action-required" "ready subset result"
Assert-Equal $readySubsetReport.currentBottleneck.code "dispatch-ready-subset" "ready subset bottleneck"
Assert-Contains $readySubsetReport.recommendedCommands[0].command "-ActionOrder 2" "ready subset recommended command"
Assert-Contains $readySubsetReport.currentBottleneck.note "Web dispatch URL(s) for ready templates" "ready subset bottleneck note"
Assert-Contains $readySubsetReport.currentBottleneck.note "also collect ImageSigningRunId" "ready subset bottleneck security finalizer note"
Assert-Contains $readySubsetReport.recommendedCommands[0].note "container-security-ci.yml" "ready subset recommended command note"
Assert-Contains $readySubsetReport.recommendedCommands[0].note "security-evidence-finalizer-ci.yml" "ready subset recommended command security finalizer note"
Assert-Contains (@($readySubsetReport.handoffBrowserDispatchDependencyNotes) -join " ") "ContainerSecurityRunId" "ready subset dependency note array"
Assert-Equal $readySubsetReport.handoffSecurityEvidenceFinalizerRunIdInputHintCount 2 "ready subset security finalizer hint count"
Assert-Equal @($readySubsetReport.handoffSecurityEvidenceFinalizerRunIdInputHints).Count 2 "ready subset security finalizer hint array count"
$readySubsetImageHint = @($readySubsetReport.handoffSecurityEvidenceFinalizerRunIdInputHints | Where-Object { $_.runIdParameter -eq "ImageSigningRunId" } | Select-Object -First 1)
$readySubsetContainerHint = @($readySubsetReport.handoffSecurityEvidenceFinalizerRunIdInputHints | Where-Object { $_.runIdParameter -eq "ContainerSecurityRunId" } | Select-Object -First 1)
Assert-Equal $readySubsetImageHint.workflow "image-publish-sign-ci.yml" "ready subset image signing hint workflow"
Assert-Equal ([bool] $readySubsetImageHint.supplementalForSecurityFinalizer) $true "ready subset image signing hint supplemental flag"
Assert-Equal $readySubsetContainerHint.workflow "container-security-ci.yml" "ready subset container hint workflow"
Assert-Equal ([bool] $readySubsetContainerHint.sourceSelected) $true "ready subset container hint selected flag"
$readySubsetDispatchUrl = "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
Assert-Equal ((@($readySubsetReport.currentBottleneck.dispatchUrls))[0]) $readySubsetDispatchUrl "ready subset bottleneck dispatch URL"
Assert-Equal ((@($readySubsetReport.recommendedCommands[0].dispatchUrls))[0]) $readySubsetDispatchUrl "ready subset recommended command dispatch URL"
Assert-Equal @($readySubsetReport.handoffPostDispatchCommands).Count 2 "ready subset post-dispatch command count"
Assert-Contains @($readySubsetReport.handoffPostDispatchCommands)[0].command "-RunListJsonDirectory <run-list-json-dir>" "ready subset post-dispatch run-list command"
Assert-Contains @($readySubsetReport.handoffPostDispatchCommands)[1].command "write-operations-artifact-collection-plan.ps1" "ready subset post-dispatch artifact collection command"
Assert-Contains $readySubsetMarkdown "Web dispatch URL(s) for ready templates" "ready subset markdown note"
Assert-Contains $readySubsetMarkdown "also collect ImageSigningRunId" "ready subset markdown security finalizer note"
Assert-Contains $readySubsetMarkdown "Handoff security finalizer run-id hints: 2" "ready subset markdown security finalizer hint status"
Assert-Contains $readySubsetMarkdown "## Handoff Security Finalizer Run-id Hints" "ready subset markdown security finalizer hints section"
Assert-Contains $readySubsetMarkdown "ImageSigningRunId: workflow=image-publish-sign-ci.yml / source=supplemental" "ready subset markdown image signing hint"
Assert-Contains $readySubsetMarkdown "ContainerSecurityRunId: workflow=container-security-ci.yml / source=selected" "ready subset markdown container hint"
Assert-Contains $readySubsetMarkdown "Dispatch URLs:" "ready subset markdown dispatch label"
Assert-Contains $readySubsetMarkdown $readySubsetDispatchUrl "ready subset markdown dispatch URL"
Assert-Contains $readySubsetMarkdown "Plan ready dispatch subset" "ready subset markdown command"
Assert-Contains $readySubsetMarkdown "## Handoff Post Dispatch Commands" "ready subset markdown post-dispatch section"
Assert-Contains $readySubsetMarkdown "Regenerate artifact collection plan after run id collection" "ready subset markdown post-dispatch command"

$readyHandoffPath = Join-Path $resolvedOutputDirectory "ready-handoff.json"
$readyReadinessPath = Join-Path $resolvedOutputDirectory "ready-readiness.json"
$readyFinalizePath = Join-Path $resolvedOutputDirectory "ready-finalize.json"
$readySyncPath = Join-Path $resolvedOutputDirectory "ready-sync.json"
$readyMissingFinalizePath = Join-Path $resolvedOutputDirectory "ready-missing-finalize.json"
$finalizerRequiredPath = Join-Path $resolvedOutputDirectory "finalizer-required-convergence.json"
$finalizerRequiredMarkdownPath = Join-Path $resolvedOutputDirectory "finalizer-required-convergence.md"
$syncRequiredPath = Join-Path $resolvedOutputDirectory "sync-required-convergence.json"
$syncRequiredMarkdownPath = Join-Path $resolvedOutputDirectory "sync-required-convergence.md"
$stringFinalizerCountPath = Join-Path $resolvedOutputDirectory "string-finalizer-count.json"
$stringFinalizerCountJsonPath = Join-Path $resolvedOutputDirectory "string-finalizer-count-convergence.json"
$stringFinalizerCountMarkdownPath = Join-Path $resolvedOutputDirectory "string-finalizer-count-convergence.md"
$missingFinalizerCountPath = Join-Path $resolvedOutputDirectory "missing-finalizer-count.json"
$missingFinalizerCountJsonPath = Join-Path $resolvedOutputDirectory "missing-finalizer-count-convergence.json"
$missingFinalizerCountMarkdownPath = Join-Path $resolvedOutputDirectory "missing-finalizer-count-convergence.md"
$stringSyncCountPath = Join-Path $resolvedOutputDirectory "string-sync-count.json"
$stringSyncCountJsonPath = Join-Path $resolvedOutputDirectory "string-sync-count-convergence.json"
$stringSyncCountMarkdownPath = Join-Path $resolvedOutputDirectory "string-sync-count-convergence.md"
$missingSyncCountPath = Join-Path $resolvedOutputDirectory "missing-sync-count.json"
$missingSyncCountJsonPath = Join-Path $resolvedOutputDirectory "missing-sync-count-convergence.json"
$missingSyncCountMarkdownPath = Join-Path $resolvedOutputDirectory "missing-sync-count-convergence.md"
$staleSyncPath = Join-Path $resolvedOutputDirectory "stale-sync.json"
$staleSyncJsonPath = Join-Path $resolvedOutputDirectory "stale-sync-convergence.json"
$staleSyncMarkdownPath = Join-Path $resolvedOutputDirectory "stale-sync-convergence.md"
$readyJsonPath = Join-Path $resolvedOutputDirectory "ready-convergence.json"
$readyMarkdownPath = Join-Path $resolvedOutputDirectory "ready-convergence.md"

Write-JsonFixture $readyReadinessPath ([ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    generatedAt = "2026-06-29T00:10:00+00:00"
    result = "ready"
    summary = "passed=42 pending=0"
})
Write-JsonFixture $readyFinalizePath ([ordered]@{
    formatVersion = "osmu.operations-readiness-finalize.v1"
    generatedAt = "2026-06-29T00:12:00+00:00"
    result = "ready"
    status = "operations-readiness-finalize-ready"
    readinessResult = "ready"
    failedCount = 0
    gaps = @()
})
Write-JsonFixture $readyHandoffPath ([ordered]@{
    formatVersion = "osmu.operations-evidence-handoff.v1"
    generatedAt = "2026-06-29T00:11:00+00:00"
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
    -OperationsReadinessFinalizeReportPath $readyMissingFinalizePath `
    -KubernetesOperationsReportSyncReportPath $readySyncPath `
    -JsonOutputPath $finalizerRequiredPath `
    -MarkdownOutputPath $finalizerRequiredMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 finalizer-required check failed with exit code $LASTEXITCODE."
}

$finalizerRequiredReport = Read-Utf8Text $finalizerRequiredPath | ConvertFrom-Json
$finalizerRequiredMarkdown = Read-Utf8Text $finalizerRequiredMarkdownPath
Assert-Equal $finalizerRequiredReport.result "action-required" "finalizer required result"
Assert-Equal $finalizerRequiredReport.currentBottleneck.code "finalize-operations-readiness" "finalizer required bottleneck"
Assert-Equal $finalizerRequiredReport.finalizerExists $false "finalizer required exists"
Assert-Contains $finalizerRequiredReport.decisionRule "finalizer report exists" "finalizer required decision rule"
Assert-Contains $finalizerRequiredReport.decisionRule "typed integer failedCount=0" "finalizer required decision rule"
Assert-Contains $finalizerRequiredReport.decisionRule "sourceReportResult=ready" "finalizer required decision rule"
Assert-Contains $finalizerRequiredReport.decisionRule "fresh against" "finalizer required decision rule"
Assert-Contains $finalizerRequiredReport.recommendedCommands[0].command "finalize-operations-readiness.ps1" "finalizer required command"
Assert-Contains $finalizerRequiredMarkdown "Finalize operations readiness" "finalizer required markdown command"

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

$syncRequiredReport = Read-Utf8Text $syncRequiredPath | ConvertFrom-Json
$syncRequiredMarkdown = Read-Utf8Text $syncRequiredMarkdownPath
Assert-Equal $syncRequiredReport.result "action-required" "sync required result"
Assert-Equal $syncRequiredReport.currentBottleneck.code "sync-kubernetes-operations-report" "sync required bottleneck"
Assert-Equal $syncRequiredReport.kubernetesReportSyncExists $false "sync required exists"
Assert-Equal $syncRequiredReport.kubernetesReportSyncReady $false "sync required ready"
Assert-Contains $syncRequiredReport.recommendedCommands[0].command "sync-kubernetes-operations-reports.ps1" "sync required command"
Assert-Contains $syncRequiredReport.kubernetesReportSyncWorkflowCommand "kubernetes-operations-report-sync-ci.yml" "sync required workflow command"
Assert-Contains $syncRequiredReport.kubernetesReportSyncWorkflowCommand "data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>" "sync required data-flow workflow input"
Assert-Contains $syncRequiredReport.kubernetesReportSyncWorkflowCommand "data_flow_query_retention_budget_json_base64=<base64-latest-data-flow-query-retention-budget-json>" "sync required data-flow query/retention workflow input"
Assert-Contains $syncRequiredReport.kubernetesReportSyncWorkflowCommand "data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>" "sync required data-flow runbook workflow input"
Assert-Contains $syncRequiredReport.kubernetesReportSyncWorkflowNote "sanitized query-plan evidence summary" "sync required workflow note"
Assert-Contains $syncRequiredReport.kubernetesReportSyncWorkflowNote "query/retention budget and transition runbook evidence must be result=passed" "sync required workflow note"
Assert-Contains $syncRequiredReport.kubernetesReportSyncWorkflowNote "raw event messages" "sync required workflow note"
Assert-Contains $syncRequiredReport.kubernetesReportSyncWorkflowNote "Omit inputs" "sync required workflow note"
Assert-Contains $syncRequiredMarkdown "Kubernetes report sync: " "sync required markdown status"
Assert-Contains $syncRequiredMarkdown "Kubernetes report sync workflow:" "sync required markdown workflow command"
Assert-Contains $syncRequiredReport.decisionRule "fresh against" "sync required decision rule"

Write-JsonFixture $readySyncPath ([ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    generatedAt = "2026-06-29T00:20:00+00:00"
    result = "applied"
    namespace = "osmu"
    configMapName = "osmu-operations-reports"
    configMapKey = "latest-operations-readiness-convergence.json"
    sourceReportResult = "ready"
    failedCount = 0
    checkCount = 5
})

Write-JsonFixture $staleSyncPath ([ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    generatedAt = "2026-06-29T00:01:00+00:00"
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
    -KubernetesOperationsReportSyncReportPath $staleSyncPath `
    -JsonOutputPath $staleSyncJsonPath `
    -MarkdownOutputPath $staleSyncMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 stale-sync check failed with exit code $LASTEXITCODE."
}

$staleSyncReport = Read-Utf8Text $staleSyncJsonPath | ConvertFrom-Json
$staleSyncMarkdown = Read-Utf8Text $staleSyncMarkdownPath
Assert-Equal $staleSyncReport.result "action-required" "stale sync result"
Assert-Equal $staleSyncReport.currentBottleneck.code "sync-kubernetes-operations-report" "stale sync bottleneck"
Assert-Equal $staleSyncReport.kubernetesReportSyncStale $true "stale sync flag"
Assert-Equal $staleSyncReport.kubernetesReportSyncReady $false "stale sync ready"
Assert-Equal $staleSyncReport.kubernetesReportSyncTimestamp "2026-06-29T00:01:00+00:00" "stale sync timestamp"
Assert-Equal $staleSyncReport.kubernetesReportSyncTimestampSource "generatedAt" "stale sync timestamp source"
Assert-Contains $staleSyncReport.kubernetesReportSyncFreshnessReason "older than the latest" "stale sync freshness reason"
Assert-Contains $staleSyncReport.currentBottleneck.reason "older than the latest" "stale sync bottleneck reason"
Assert-Contains $staleSyncReport.recommendedCommands[0].reason "older than the latest" "stale sync recommended reason"
Assert-Contains $staleSyncReport.decisionRule "fresh against" "stale sync decision rule"
Assert-Contains $staleSyncMarkdown "Kubernetes report sync stale: True" "stale sync markdown flag"
Assert-Contains $staleSyncMarkdown "Kubernetes report sync freshness reason:" "stale sync markdown freshness reason"
Write-JsonFixture $stringFinalizerCountPath ([ordered]@{
    formatVersion = "osmu.operations-readiness-finalize.v1"
    result = "ready"
    status = "operations-readiness-finalize-ready"
    readinessResult = "ready"
    failedCount = "0"
    gaps = @()
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $readyHandoffPath `
    -ReadinessReportPath $readyReadinessPath `
    -OperationsReadinessFinalizeReportPath $stringFinalizerCountPath `
    -KubernetesOperationsReportSyncReportPath $readySyncPath `
    -JsonOutputPath $stringFinalizerCountJsonPath `
    -MarkdownOutputPath $stringFinalizerCountMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 string-finalizer-count check failed with exit code $LASTEXITCODE."
}

$stringFinalizerCountReport = Read-Utf8Text $stringFinalizerCountJsonPath | ConvertFrom-Json
Assert-Equal $stringFinalizerCountReport.result "action-required" "string finalizer count result"
Assert-Equal $stringFinalizerCountReport.currentBottleneck.code "finalize-operations-readiness" "string finalizer count bottleneck"
Assert-Equal $stringFinalizerCountReport.finalizerFailedCount 0 "string finalizer count value"
Assert-Equal $stringFinalizerCountReport.finalizerFailedCountValid $false "string finalizer count valid"
Assert-Equal $stringFinalizerCountReport.finalizerFailedCountRaw "0" "string finalizer count raw"
Assert-Contains $stringFinalizerCountReport.decisionRule "typed integer failedCount=0" "string finalizer count decision rule"

Write-JsonFixture $missingFinalizerCountPath ([ordered]@{
    formatVersion = "osmu.operations-readiness-finalize.v1"
    result = "ready"
    status = "operations-readiness-finalize-ready"
    readinessResult = "ready"
    gaps = @()
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $readyHandoffPath `
    -ReadinessReportPath $readyReadinessPath `
    -OperationsReadinessFinalizeReportPath $missingFinalizerCountPath `
    -KubernetesOperationsReportSyncReportPath $readySyncPath `
    -JsonOutputPath $missingFinalizerCountJsonPath `
    -MarkdownOutputPath $missingFinalizerCountMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 missing-finalizer-count check failed with exit code $LASTEXITCODE."
}

$missingFinalizerCountReport = Read-Utf8Text $missingFinalizerCountJsonPath | ConvertFrom-Json
Assert-Equal $missingFinalizerCountReport.result "action-required" "missing finalizer count result"
Assert-Equal $missingFinalizerCountReport.currentBottleneck.code "finalize-operations-readiness" "missing finalizer count bottleneck"
Assert-Equal $missingFinalizerCountReport.finalizerFailedCount 0 "missing finalizer count value"
Assert-Equal $missingFinalizerCountReport.finalizerFailedCountValid $false "missing finalizer count valid"
Assert-Equal $missingFinalizerCountReport.finalizerFailedCountRaw "<missing>" "missing finalizer count raw"
Assert-Contains $missingFinalizerCountReport.decisionRule "typed integer failedCount=0" "missing finalizer count decision rule"

Write-JsonFixture $stringSyncCountPath ([ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    namespace = "osmu"
    configMapName = "osmu-operations-reports"
    configMapKey = "latest-operations-readiness-convergence.json"
    sourceReportResult = "ready"
    failedCount = "0"
    checkCount = 5
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $readyHandoffPath `
    -ReadinessReportPath $readyReadinessPath `
    -OperationsReadinessFinalizeReportPath $readyFinalizePath `
    -KubernetesOperationsReportSyncReportPath $stringSyncCountPath `
    -JsonOutputPath $stringSyncCountJsonPath `
    -MarkdownOutputPath $stringSyncCountMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 string-sync-count check failed with exit code $LASTEXITCODE."
}

$stringSyncCountReport = Read-Utf8Text $stringSyncCountJsonPath | ConvertFrom-Json
Assert-Equal $stringSyncCountReport.result "action-required" "string sync count result"
Assert-Equal $stringSyncCountReport.currentBottleneck.code "sync-kubernetes-operations-report" "string sync count bottleneck"
Assert-Equal $stringSyncCountReport.kubernetesReportSyncFailedCount 0 "string sync count value"
Assert-Equal $stringSyncCountReport.kubernetesReportSyncFailedCountValid $false "string sync count valid"
Assert-Equal $stringSyncCountReport.kubernetesReportSyncFailedCountRaw "0" "string sync count raw"
Assert-Equal $stringSyncCountReport.kubernetesReportSyncReady $false "string sync count ready"

Write-JsonFixture $missingSyncCountPath ([ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    namespace = "osmu"
    configMapName = "osmu-operations-reports"
    configMapKey = "latest-operations-readiness-convergence.json"
    sourceReportResult = "ready"
    checkCount = 5
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $readyHandoffPath `
    -ReadinessReportPath $readyReadinessPath `
    -OperationsReadinessFinalizeReportPath $readyFinalizePath `
    -KubernetesOperationsReportSyncReportPath $missingSyncCountPath `
    -JsonOutputPath $missingSyncCountJsonPath `
    -MarkdownOutputPath $missingSyncCountMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 missing-sync-count check failed with exit code $LASTEXITCODE."
}

$missingSyncCountReport = Read-Utf8Text $missingSyncCountJsonPath | ConvertFrom-Json
Assert-Equal $missingSyncCountReport.result "action-required" "missing sync count result"
Assert-Equal $missingSyncCountReport.currentBottleneck.code "sync-kubernetes-operations-report" "missing sync count bottleneck"
Assert-Equal $missingSyncCountReport.kubernetesReportSyncFailedCount 0 "missing sync count value"
Assert-Equal $missingSyncCountReport.kubernetesReportSyncFailedCountValid $false "missing sync count valid"
Assert-Equal $missingSyncCountReport.kubernetesReportSyncFailedCountRaw "<missing>" "missing sync count raw"
Assert-Equal $missingSyncCountReport.kubernetesReportSyncReady $false "missing sync count ready"

$gapFinalizePath = Join-Path $resolvedOutputDirectory "gap-finalize.json"
$gapFinalizeJsonPath = Join-Path $resolvedOutputDirectory "gap-finalize-convergence.json"
$gapFinalizeMarkdownPath = Join-Path $resolvedOutputDirectory "gap-finalize-convergence.md"
Write-JsonFixture $gapFinalizePath ([ordered]@{
    formatVersion = "osmu.operations-readiness-finalize.v1"
    result = "ready"
    status = "operations-readiness-finalize-ready"
    readinessResult = "ready"
    failedCount = 1
    gaps = @("Finalizer gap should block convergence.")
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $readyHandoffPath `
    -ReadinessReportPath $readyReadinessPath `
    -OperationsReadinessFinalizeReportPath $gapFinalizePath `
    -KubernetesOperationsReportSyncReportPath $readySyncPath `
    -JsonOutputPath $gapFinalizeJsonPath `
    -MarkdownOutputPath $gapFinalizeMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 gap-finalize check failed with exit code $LASTEXITCODE."
}

$gapFinalizeReport = Read-Utf8Text $gapFinalizeJsonPath | ConvertFrom-Json
Assert-Equal $gapFinalizeReport.result "action-required" "gap finalizer result"
Assert-Equal $gapFinalizeReport.currentBottleneck.code "finalize-operations-readiness" "gap finalizer bottleneck"
Assert-Equal $gapFinalizeReport.finalizerFailedCount 1 "gap finalizer failed count"
Assert-Equal $gapFinalizeReport.finalizerGapCount 1 "gap finalizer gap count"
Assert-Contains $gapFinalizeReport.recommendedCommands[0].command "finalize-operations-readiness.ps1" "gap finalizer command"

$notReadySyncPath = Join-Path $resolvedOutputDirectory "not-ready-sync.json"
$notReadySyncJsonPath = Join-Path $resolvedOutputDirectory "not-ready-sync-convergence.json"
$notReadySyncMarkdownPath = Join-Path $resolvedOutputDirectory "not-ready-sync-convergence.md"
Write-JsonFixture $notReadySyncPath ([ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    namespace = "osmu"
    configMapName = "osmu-operations-reports"
    configMapKey = "latest-operations-readiness-convergence.json"
    sourceReportResult = "action-required"
    failedCount = 0
    checkCount = 5
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -HandoffReportPath $readyHandoffPath `
    -ReadinessReportPath $readyReadinessPath `
    -OperationsReadinessFinalizeReportPath $readyFinalizePath `
    -KubernetesOperationsReportSyncReportPath $notReadySyncPath `
    -JsonOutputPath $notReadySyncJsonPath `
    -MarkdownOutputPath $notReadySyncMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness-convergence.ps1 not-ready-sync check failed with exit code $LASTEXITCODE."
}

$notReadySyncReport = Read-Utf8Text $notReadySyncJsonPath | ConvertFrom-Json
$notReadySyncMarkdown = Read-Utf8Text $notReadySyncMarkdownPath
Assert-Equal $notReadySyncReport.result "action-required" "not-ready sync result"
Assert-Equal $notReadySyncReport.currentBottleneck.code "sync-kubernetes-operations-report" "not-ready sync bottleneck"
Assert-Equal $notReadySyncReport.kubernetesReportSyncReady $false "not-ready sync ready"
Assert-Equal $notReadySyncReport.kubernetesReportSyncStale $false "not-ready sync stale"
Assert-Equal $notReadySyncReport.kubernetesReportSyncSourceReportResult "action-required" "not-ready sync source result"
Assert-Contains $notReadySyncReport.decisionRule "sourceReportResult=ready" "not-ready sync decision rule"
Assert-Contains $notReadySyncMarkdown "Kubernetes report sync: applied" "not-ready sync markdown status"

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

$readyReport = Read-Utf8Text $readyJsonPath | ConvertFrom-Json
$readyMarkdown = Read-Utf8Text $readyMarkdownPath
Assert-Equal $readyReport.result "ready" "ready result"
Assert-Equal $readyReport.currentBottleneck.code "none" "ready bottleneck"
Assert-Equal @($readyReport.recommendedCommands).Count 0 "ready command count"
Assert-Equal $readyReport.finalizerResult "ready" "ready finalizer"
Assert-Equal $readyReport.kubernetesReportSyncResult "applied" "ready sync result"
Assert-Equal $readyReport.kubernetesReportSyncReady $true "ready sync ready"
Assert-Equal $readyReport.kubernetesReportSyncStale $false "ready sync stale"
Assert-Contains $readyReport.kubernetesReportSyncWorkflowCommand "data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>" "ready data-flow workflow input"
Assert-Contains $readyReport.kubernetesReportSyncWorkflowCommand "data_flow_query_retention_budget_json_base64=<base64-latest-data-flow-query-retention-budget-json>" "ready data-flow query/retention workflow input"
Assert-Contains $readyReport.kubernetesReportSyncWorkflowCommand "data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>" "ready data-flow runbook workflow input"
Assert-Contains $readyMarkdown "Result: ready" "ready markdown result"

Assert-True ($readyReport.safetyPolicy.Contains("does not execute")) "safety policy"

Write-Host "Operations readiness convergence verified."
Write-Host "Missing report: $missingJsonPath"
Write-Host "Action report: $actionJsonPath"
Write-Host "Finalizer required report: $finalizerRequiredPath"
Write-Host "Sync required report: $syncRequiredPath"
Write-Host "Stale sync report: $staleSyncJsonPath"
Write-Host "Ready report: $readyJsonPath"
