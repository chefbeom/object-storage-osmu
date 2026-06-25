param(
    [string] $ReadinessReportPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $EvidencePlanPath = ".\.osmu-run\latest-operations-evidence-plan.json",
    [string] $InvocationReportPath = ".\.osmu-run\latest-operations-evidence-plan-invocation.json",
    [string] $DispatchPreflightReportPath = ".\.osmu-run\latest-operations-dispatch-preflight.json",
    [string] $WorkflowRunIdPlanPath = ".\.osmu-run\latest-operations-workflow-run-ids.json",
    [string] $ArtifactCollectionPlanPath = ".\.osmu-run\latest-operations-artifact-collection-plan.json",
    [string] $ArtifactImportReportPath = ".\.osmu-run\latest-operations-readiness-artifact-import.json",
    [string] $OperationsReadinessFinalizeReportPath = ".\.osmu-run\latest-operations-readiness-finalize.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-evidence-handoff.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-evidence-handoff.md",
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-OptionalJson([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        return [ordered]@{
            path = $resolved
            exists = $false
            json = $null
        }
    }
    return [ordered]@{
        path = $resolved
        exists = $true
        json = (Get-Content -Raw -LiteralPath $resolved | ConvertFrom-Json)
    }
}

function Get-JsonProperty([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-Text([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Get-Int([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return 0
    }
    try {
        return [int] $value
    }
    catch {
        return 0
    }
}

function Get-ArrayCount([object] $Value) {
    if ($null -eq $Value) {
        return 0
    }
    return @($Value).Count
}

function Get-Array([object] $Value) {
    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [System.Array]) {
        return @($Value)
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value)
    }
    return @($Value)
}

function Get-Bool([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return $false
    }
    try {
        return [System.Convert]::ToBoolean($value)
    }
    catch {
        return $false
    }
}

function Join-IntList([int[]] $Values) {
    if ($null -eq $Values -or $Values.Count -eq 0) {
        return "none"
    }
    return (@($Values) | ForEach-Object { [string] $_ }) -join ","
}

function New-Stage(
    [string] $Name,
    [string] $ReportPath,
    [bool] $Exists,
    [string] $Result,
    [string] $Summary,
    [bool] $Ready,
    [string] $Command,
    [string] $Note
) {
    return [ordered]@{
        name = $Name
        reportPath = $ReportPath
        exists = $Exists
        result = $Result
        summary = $Summary
        ready = $Ready
        command = $Command
        note = $Note
    }
}

function New-NextStep([string] $Code, [string] $Title, [string] $Command, [string] $Reason, [string] $Note) {
    return [ordered]@{
        code = $Code
        title = $Title
        command = $Command
        reason = $Reason
        note = $Note
    }
}

function Is-ReadyResult([string] $Result) {
    return @("ready", "passed", "go") -contains $Result.ToLowerInvariant()
}

$readiness = Read-OptionalJson $ReadinessReportPath
$evidencePlan = Read-OptionalJson $EvidencePlanPath
$invocation = Read-OptionalJson $InvocationReportPath
$dispatchPreflight = Read-OptionalJson $DispatchPreflightReportPath
$runIds = Read-OptionalJson $WorkflowRunIdPlanPath
$collection = Read-OptionalJson $ArtifactCollectionPlanPath
$import = Read-OptionalJson $ArtifactImportReportPath
$finalize = Read-OptionalJson $OperationsReadinessFinalizeReportPath

$readinessResult = Get-Text $readiness.json "result"
$evidencePlanResult = Get-Text $evidencePlan.json "result"
$invocationResult = Get-Text $invocation.json "result"
$dispatchPreflightResult = Get-Text $dispatchPreflight.json "result"
$runIdResult = Get-Text $runIds.json "result"
$collectionResult = Get-Text $collection.json "result"
$importResult = Get-Text $import.json "result"
$finalizeResult = Get-Text $finalize.json "result"
$finalizeReadinessResult = Get-Text $finalize.json "readinessResult"
$finalizeFailedCount = Get-Int $finalize.json "failedCount"
$finalizeGapCount = Get-ArrayCount (Get-JsonProperty $finalize.json "gaps")
$readinessReady = $readiness.exists -and (Is-ReadyResult $readinessResult)
$finalizerReady = $finalize.exists -and (Is-ReadyResult $finalizeResult) -and (Is-ReadyResult $finalizeReadinessResult) -and $finalizeFailedCount -eq 0 -and $finalizeGapCount -eq 0
$dispatchTemplates = @(Get-Array (Get-JsonProperty $dispatchPreflight.json "inputTemplates"))
$readyDispatchTemplates = @($dispatchTemplates | Where-Object { Get-Bool $_ "readyToDispatch" })
$blockedDispatchTemplates = @($dispatchTemplates | Where-Object { -not (Get-Bool $_ "readyToDispatch") })
$readyDispatchActionOrders = @($readyDispatchTemplates | ForEach-Object { Get-Int $_ "actionOrder" } | Where-Object { $_ -gt 0 })
$blockedDispatchActionOrders = @($blockedDispatchTemplates | ForEach-Object { Get-Int $_ "actionOrder" } | Where-Object { $_ -gt 0 })
$readyDispatchTemplateCount = $readyDispatchTemplates.Count
$blockedDispatchTemplateCount = $blockedDispatchTemplates.Count
$readySubsetPlanCommand = Get-Text $dispatchPreflight.json "readySubsetPlanCommand"
$readySubsetExecuteCommand = Get-Text $dispatchPreflight.json "readySubsetExecuteCommand"

$stages = @(
    (New-Stage "operations-readiness" $readiness.path $readiness.exists $readinessResult (Get-Text $readiness.json "summary") (Is-ReadyResult $readinessResult) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1" "Production/B2B readiness gate summary."),
    (New-Stage "evidence-plan" $evidencePlan.path $evidencePlan.exists $evidencePlanResult "pending=$((Get-Int $evidencePlan.json "pendingCount")) actions=$((Get-Int $evidencePlan.json "actionCount")) unplanned=$((Get-Int $evidencePlan.json "unplannedCount"))" ($evidencePlan.exists -and (Get-Int $evidencePlan.json "actionCount") -gt 0) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-plan.ps1" "Ordered remediation plan."),
    (New-Stage "evidence-invocation" $invocation.path $invocation.exists $invocationResult "selected=$((Get-Int $invocation.json "selectedActionCount")) planned=$((Get-Int $invocation.json "plannedCount")) blocked=$((Get-Int $invocation.json "blockedCount")) failed=$((Get-Int $invocation.json "failedCount"))" ($invocation.exists -and (Get-Int $invocation.json "blockedCount") -eq 0 -and (Get-Int $invocation.json "failedCount") -eq 0 -and (Get-Int $invocation.json "selectedActionCount") -gt 0) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1" "Guarded workflow/local command invocation report."),
    (New-Stage "dispatch-preflight" $dispatchPreflight.path $dispatchPreflight.exists $dispatchPreflightResult "selected=$((Get-Int $dispatchPreflight.json "selectedActionCount")) readyTemplates=$readyDispatchTemplateCount blockedTemplates=$blockedDispatchTemplateCount missingInputs=$((Get-Int $dispatchPreflight.json "missingInputCount")) readyOrders=$(Join-IntList $readyDispatchActionOrders)" ($dispatchPreflight.exists -and (Is-ReadyResult $dispatchPreflightResult)) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-dispatch-preflight.ps1 -CheckGitHubCli" "No-execute workflow dispatch preflight and input template readiness."),
    (New-Stage "workflow-run-ids" $runIds.path $runIds.exists $runIdResult "workflows=$((Get-Int $runIds.json "workflowCount")) ready=$((Get-Int $runIds.json "readyWorkflowCount")) missing=$((Get-Int $runIds.json "missingWorkflowCount")) stale=$((Get-Int $runIds.json "staleWorkflowCount"))" ($runIds.exists -and (Is-ReadyResult $runIdResult)) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -Execute" "GitHub workflow run id handoff."),
    (New-Stage "artifact-collection" $collection.path $collection.exists $collectionResult "artifacts=$((Get-Int $collection.json "artifactCount")) ready=$((Get-Int $collection.json "readyArtifactCount")) missingRequired=$((Get-Int $collection.json "missingRequiredArtifactCount"))" ($collection.exists -and (Is-ReadyResult $collectionResult)) (Get-Text $collection.json "operationsArtifactFinalizerCommand") "Artifact download/import or finalizer plan."),
    (New-Stage "artifact-import" $import.path $import.exists $importResult "failed=$((Get-Int $import.json "failedCount"))" ($import.exists -and (Is-ReadyResult $importResult)) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\import-operations-readiness-artifacts.ps1" "Promotion of downloaded evidence artifacts into latest readiness paths."),
    (New-Stage "operations-finalizer" $finalize.path $finalize.exists $finalizeResult "readiness=$finalizeReadinessResult failed=$finalizeFailedCount gaps=$finalizeGapCount" $finalizerReady "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "Combined finalizer and final readiness regeneration.")
)

$nextStep = $null
$handoffResult = "action-required"

if ($readinessReady -and $finalizerReady) {
    $handoffResult = "ready"
    $nextStep = New-NextStep "none" "Operations readiness is ready" "" "The latest operations readiness and operations finalizer reports are ready." "No handoff action is required."
}
elseif ($readinessReady -and -not $finalize.exists) {
    $nextStep = New-NextStep "run-operations-finalizer" "Run operations readiness finalizer" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "The latest operations readiness report is ready, but the operations readiness finalizer report is missing." "Run the combined finalizer so final readiness evidence is recorded before convergence."
}
elseif ($readinessReady -and -not $finalizerReady) {
    $nextStep = New-NextStep "fix-operations-finalizer" "Fix operations readiness finalizer" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "Operations readiness is ready, but the finalizer is not ready: result=$finalizeResult, readiness=$finalizeReadinessResult, failed=$finalizeFailedCount, gaps=$finalizeGapCount." "Inspect finalizer gaps, rerun missing evidence finalizers, then rerun the combined finalizer."
}
elseif (-not $readiness.exists) {
    $nextStep = New-NextStep "write-readiness" "Generate operations readiness report" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1" "The operations readiness report is missing." "Generate the gate report before planning evidence collection."
}
elseif (-not $evidencePlan.exists) {
    $nextStep = New-NextStep "write-evidence-plan" "Generate operations evidence plan" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-plan.ps1" "The evidence plan is missing." "Convert pending readiness checks into ordered commands."
}
elseif (-not $invocation.exists) {
    $nextStep = New-NextStep "write-invocation" "Generate guarded invocation report" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1" "The invocation report is missing." "Review blockers before executing live workflow or local evidence commands."
}
elseif ((Get-Int $invocation.json "blockedCount") -gt 0 -or "blocked".Equals($invocationResult, [System.StringComparison]::OrdinalIgnoreCase)) {
    $handoffResult = "blocked"
    if ($readyDispatchTemplateCount -gt 0 -and -not [string]::IsNullOrWhiteSpace($readySubsetPlanCommand)) {
        $readyOrdersText = Join-IntList $readyDispatchActionOrders
        $executeHint = if (-not [string]::IsNullOrWhiteSpace($readySubsetExecuteCommand)) {
            "Execute command is available after plan review: $readySubsetExecuteCommand"
        }
        else {
            "Ready subset execute command is unavailable until GitHub CLI/auth checks pass; rerun dispatch preflight with -CheckGitHubCli before live execution."
        }
        $nextStep = New-NextStep "dispatch-ready-subset" "Plan ready dispatch subset" $readySubsetPlanCommand "The invocation report still has blocked actions, but $readyDispatchTemplateCount action(s) are ready to dispatch: $readyOrdersText." "Run the ready subset plan command first without -Execute, then dispatch only after review and continue resolving the remaining blocked actions. $executeHint"
    }
    else {
        $nextStep = New-NextStep "resolve-invocation-blockers" "Resolve invocation blockers" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-invocation-unblock-plan.ps1" "The invocation report still has blocked actions." "Generate the unblock plan, fill placeholders, confirm operator approvals, and confirm kubeconfig-secret readiness before dispatch."
    }
}
elseif ((Get-Int $invocation.json "plannedCount") -gt 0 -and (Get-Int $invocation.json "executedCount") -eq 0 -and "planned".Equals($invocationResult, [System.StringComparison]::OrdinalIgnoreCase)) {
    $nextStep = New-NextStep "execute-invocation" "Execute guarded evidence invocation" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -Execute" "The invocation is planned but has not executed workflows yet." "Use only after reviewing generated commands and approval requirements."
}
elseif (-not $runIds.exists) {
    $nextStep = New-NextStep "write-run-id-plan" "Generate workflow run id plan" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1" "The workflow run id plan is missing." "Collect the GitHub run id handoff after workflow dispatch."
}
elseif (-not (Is-ReadyResult $runIdResult)) {
    $nextStep = New-NextStep "collect-run-ids" "Collect successful workflow run ids" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -Execute" "Workflow run ids are not ready: $runIdResult." "Run after workflow dispatch or provide fixture JSON from gh run list outputs."
}
elseif (-not $collection.exists) {
    $nextStep = New-NextStep "write-artifact-collection-plan" "Generate artifact collection plan" (Get-Text $runIds.json "artifactCollectionPlanCommand") "The artifact collection plan is missing." "Use the run id plan's generated command to carry recommended run ids forward."
}
elseif (-not (Is-ReadyResult $collectionResult)) {
    $nextStep = New-NextStep "complete-artifact-collection-plan" "Complete artifact collection plan" (Get-Text $runIds.json "artifactCollectionPlanCommand") "Artifact collection is not ready: $collectionResult." "Fill missing run ids and concrete artifact names."
}
elseif (-not $import.exists) {
    $nextStep = New-NextStep "run-artifact-finalizer" "Run operations artifact finalizer or local import" (Get-Text $collection.json "operationsArtifactFinalizerCommand") "Artifacts are ready but the import report is missing." "Use the finalizer workflow command or the local import command from the artifact collection plan."
}
elseif (-not (Is-ReadyResult $importResult)) {
    $nextStep = New-NextStep "fix-artifact-import" "Fix failed artifact import" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\import-operations-readiness-artifacts.ps1" "Artifact import is not passing: $importResult." "Inspect failed evidence artifacts before regenerating readiness."
}
elseif (-not $finalize.exists) {
    $nextStep = New-NextStep "run-operations-finalizer" "Run operations readiness finalizer" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "Evidence import has passed but the operations readiness finalizer report is missing." "Run the combined finalizer so selected evidence finalizers and the final readiness regeneration are recorded together."
}
elseif (-not $finalizerReady) {
    $nextStep = New-NextStep "fix-operations-finalizer" "Fix operations readiness finalizer" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "Operations readiness finalizer is not ready: result=$finalizeResult, readiness=$finalizeReadinessResult, failed=$finalizeFailedCount, gaps=$finalizeGapCount." "Inspect finalizer gaps, rerun missing evidence finalizers, then rerun the combined finalizer."
}
else {
    $nextStep = New-NextStep "regenerate-readiness" "Regenerate operations readiness" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1" "Evidence import has passed but readiness is still not ready." "Refresh the operations readiness report from imported evidence."
}

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$report = [ordered]@{
    formatVersion = "osmu.operations-evidence-handoff.v1"
    generatedAt = $generatedAt
    result = $handoffResult
    nextStep = $nextStep
    stageCount = $stages.Count
    readyStageCount = @($stages | Where-Object { $_.ready }).Count
    dispatchPreflightResult = $dispatchPreflightResult
    readyDispatchTemplateCount = $readyDispatchTemplateCount
    blockedDispatchTemplateCount = $blockedDispatchTemplateCount
    readyDispatchActionOrders = @($readyDispatchActionOrders)
    blockedDispatchActionOrders = @($blockedDispatchActionOrders)
    blockedActionCount = Get-Int $invocation.json "blockedCount"
    missingWorkflowRunCount = Get-Int $runIds.json "missingWorkflowCount"
    missingRequiredArtifactCount = Get-Int $collection.json "missingRequiredArtifactCount"
    failedImportCount = Get-Int $import.json "failedCount"
    finalizerFailedCount = $finalizeFailedCount
    finalizerGapCount = $finalizeGapCount
    stages = $stages
}

$markdownLines = @(
    "# OSMU Operations Evidence Handoff",
    "",
    "Generated at: $generatedAt",
    "Result: $handoffResult",
    "",
    "## Next Step",
    "",
    "- Code: $($nextStep.code)",
    "- Title: $($nextStep.title)",
    "- Reason: $($nextStep.reason)",
    "- Command: ``$($nextStep.command)``",
    "- Note: $($nextStep.note)",
    "",
    "## Dispatch Preflight",
    "",
    "- Result: $dispatchPreflightResult",
    "- Ready templates: $readyDispatchTemplateCount",
    "- Blocked templates: $blockedDispatchTemplateCount",
    "- Ready action orders: $(Join-IntList $readyDispatchActionOrders)",
    "- Blocked action orders: $(Join-IntList $blockedDispatchActionOrders)",
    "",
    "## Stage Summary",
    ""
)
foreach ($stage in $stages) {
    $state = if ($stage.ready) { "ready" } elseif ($stage.exists) { "needs-action" } else { "missing" }
    $markdownLines += "- [$state] $($stage.name): $($stage.result)"
    if (-not [string]::IsNullOrWhiteSpace($stage.summary)) {
        $markdownLines += "  - Summary: $($stage.summary)"
    }
    $markdownLines += "  - Report: $($stage.reportPath)"
    if (-not [string]::IsNullOrWhiteSpace($stage.command)) {
        $markdownLines += "  - Command: ``$($stage.command)``"
    }
}

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    $markdownLines | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations evidence handoff JSON: $resolvedJsonOutputPath"
    Write-Host "Operations evidence handoff markdown: $resolvedMarkdownOutputPath"
}

$report | ConvertTo-Json -Depth 12
