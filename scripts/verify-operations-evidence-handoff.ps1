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

$missingReport = Get-Content -Raw -LiteralPath $missingJsonPath | ConvertFrom-Json
$missingMarkdown = Get-Content -Raw -LiteralPath $missingMarkdownPath
Assert-Equal $missingReport.formatVersion "osmu.operations-evidence-handoff.v1" "missing formatVersion"
Assert-Equal $missingReport.result "action-required" "missing result"
Assert-Equal $missingReport.nextStep.code "write-readiness" "missing next step"
Assert-Equal $missingReport.stageCount 8 "missing stage count"
Assert-Contains $missingMarkdown "Generate operations readiness report" "missing markdown next step"

$blockedReadinessPath = Join-Path $resolvedOutputDirectory "blocked-readiness.json"
$blockedPlanPath = Join-Path $resolvedOutputDirectory "blocked-plan.json"
$blockedInvocationPath = Join-Path $resolvedOutputDirectory "blocked-invocation.json"
$blockedDispatchPreflightPath = Join-Path $resolvedOutputDirectory "blocked-dispatch-preflight.json"
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
    selectedActionCount = 3
    missingInputCount = 2
    readySubsetPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 2"
    readySubsetExecuteCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 2 -Execute"
    inputTemplates = @(
        [ordered]@{
            actionOrder = 1
            name = "Storage expansion finalizer live evidence"
            workflow = "storage-expansion-finalizer-ci.yml"
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
            readyToDispatch = $false
            missingInputCount = 2
            unsafeInputCount = 0
            invalidInputCount = 0
            workflowInputNames = @("backup_timestamp", "api_base")
            missingInputParameters = @("BackupTimestamp", "RestoreApiBase")
        }
    )
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
    -DispatchPreflightReportPath $blockedDispatchPreflightPath `
    -WorkflowRunIdPlanPath $blockedRunIdPath `
    -ArtifactCollectionPlanPath $blockedCollectionPath `
    -ArtifactImportReportPath $blockedImportPath `
    -OperationsReadinessFinalizeReportPath $blockedFinalizePath `
    -JsonOutputPath $blockedJsonPath `
    -MarkdownOutputPath $blockedMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-handoff.ps1 blocked-report check failed with exit code $LASTEXITCODE."
}

$blockedReport = Get-Content -Raw -LiteralPath $blockedJsonPath | ConvertFrom-Json
$blockedMarkdown = Get-Content -Raw -LiteralPath $blockedMarkdownPath
Assert-Equal $blockedReport.result "blocked" "blocked result"
Assert-Equal $blockedReport.nextStep.code "dispatch-ready-subset" "blocked next step"
Assert-Contains $blockedReport.nextStep.command "-ActionOrder 2" "blocked ready subset command"
Assert-Contains $blockedReport.nextStep.reason "1 action(s) are ready" "blocked ready subset reason"
Assert-Contains $blockedReport.nextStep.note "remaining blocked actions" "blocked ready subset note"
Assert-Equal $blockedReport.blockedActionCount 5 "blocked count"
Assert-Equal $blockedReport.missingWorkflowRunCount 6 "blocked missing workflow run count"
Assert-Equal @($blockedReport.readyDispatchWorkflows).Count 1 "blocked ready dispatch workflow count"
Assert-Equal @($blockedReport.blockedDispatchWorkflows).Count 2 "blocked blocked dispatch workflow count"
Assert-Equal @($blockedReport.readyDispatchWorkflows)[0].actionOrder 2 "blocked ready dispatch workflow action order"
Assert-Equal @($blockedReport.readyDispatchWorkflows)[0].workflow "container-security-ci.yml" "blocked ready dispatch workflow name"
Assert-Equal @($blockedReport.readyDispatchWorkflows)[0].name "Container scan/SBOM evidence" "blocked ready dispatch action name"
Assert-Equal @($blockedReport.blockedDispatchWorkflows)[1].missingInputCount 2 "blocked workflow missing input count"
Assert-Contains $blockedMarkdown "Plan ready dispatch subset" "blocked markdown next step"
Assert-Contains $blockedMarkdown "ready action 2: container-security-ci.yml" "blocked markdown ready workflow"
Assert-Contains $blockedMarkdown "blocked action 3: kubernetes-dr-finalizer-ci.yml" "blocked markdown blocked workflow"

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

$finalizerReport = Get-Content -Raw -LiteralPath $finalizerJsonPath | ConvertFrom-Json
$finalizerMarkdown = Get-Content -Raw -LiteralPath $finalizerMarkdownPath
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

$operationsFinalizeReport = Get-Content -Raw -LiteralPath $operationsFinalizeJsonPath | ConvertFrom-Json
$operationsFinalizeMarkdown = Get-Content -Raw -LiteralPath $operationsFinalizeMarkdownPath
Assert-Equal $operationsFinalizeReport.result "action-required" "operations finalizer result"
Assert-Equal $operationsFinalizeReport.nextStep.code "run-operations-finalizer" "operations finalizer next step"
Assert-Equal $operationsFinalizeReport.stageCount 8 "operations finalizer stage count"
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

$pendingReport = Get-Content -Raw -LiteralPath $pendingHandoffPath | ConvertFrom-Json
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

$gapReadyReport = Get-Content -Raw -LiteralPath $gapReadyHandoffPath | ConvertFrom-Json
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

$readyMissingFinalizeReport = Get-Content -Raw -LiteralPath $readyMissingFinalizeHandoffPath | ConvertFrom-Json
$readyMissingFinalizeMarkdown = Get-Content -Raw -LiteralPath $readyMissingFinalizeMarkdownPath
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

$readyGapReport = Get-Content -Raw -LiteralPath $readyGapHandoffPath | ConvertFrom-Json
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

$readyReport = Get-Content -Raw -LiteralPath $readyHandoffPath | ConvertFrom-Json
Assert-Equal $readyReport.result "ready" "ready handoff result"
Assert-Equal $readyReport.nextStep.code "none" "ready handoff next step"
Assert-Equal $readyReport.readyStageCount 2 "ready handoff stage count"
Assert-Contains $readyReport.nextStep.reason "operations finalizer reports are ready" "ready handoff reason"

Write-Host "Operations evidence handoff verified."
Write-Host "Missing report: $missingJsonPath"
Write-Host "Blocked report: $blockedJsonPath"
Write-Host "Finalizer report: $finalizerJsonPath"
Write-Host "Operations finalizer report: $operationsFinalizeJsonPath"
Write-Host "Pending finalizer report: $pendingHandoffPath"
Write-Host "Ready missing finalizer report: $readyMissingFinalizeHandoffPath"
Write-Host "Ready report: $readyHandoffPath"
