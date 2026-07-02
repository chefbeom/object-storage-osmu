param(
    [string] $ChecklistPath = ".\dev-docs\mvp-release-checklist.md",
    [string] $MvpCompletionReportPath = ".\.osmu-run\latest-mvp-completion.json",
    [string] $OperationsReadinessReportPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $OperationsEvidencePlanReportPath = ".\.osmu-run\latest-operations-evidence-plan.json",
    [string] $OperationsWorkflowRunIdPlanReportPath = ".\.osmu-run\latest-operations-workflow-run-ids.json",
    [string] $OperationsArtifactCollectionPlanReportPath = ".\.osmu-run\latest-operations-artifact-collection-plan.json",
    [string] $OperationsEvidenceHandoffReportPath = ".\.osmu-run\latest-operations-evidence-handoff.json",
    [string] $OperationsReadinessConvergenceReportPath = ".\.osmu-run\latest-operations-readiness-convergence.json",
    [switch] $RequireEvidenceReports
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-Contains([string] $Content, [string] $Expected, [string] $Label) {
    if (-not $Content.Contains($Expected)) {
        throw "$Label does not contain expected text: $Expected"
    }
}

function Assert-NotContains([string] $Content, [string] $Unexpected, [string] $Label) {
    if ($Content.Contains($Unexpected)) {
        throw "$Label contains unexpected text: $Unexpected"
    }
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Read-OptionalJsonReport([string] $PathValue, [string] $Label) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        if ($RequireEvidenceReports) {
            throw "$Label missing: $resolved"
        }
        return $null
    }

    try {
        return [pscustomobject]@{
            path = $resolved
            data = [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        }
    }
    catch {
        throw "$Label could not be parsed as JSON: $resolved. $($_.Exception.Message)"
    }
}

function Format-BoolLower([object] $Value) {
    if ($Value -eq $true) {
        return "true"
    }
    if ($Value -eq $false) {
        return "false"
    }
    return [string] $Value
}

function Format-ListSlash([object[]] $Values) {
    $items = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) } | ForEach-Object { [string] $_ })
    if ($items.Count -eq 0) {
        return "none"
    }
    return $items -join "/"
}

function Format-IntListCsv([object[]] $Values) {
    $items = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [string] ([int] $_) })
    if ($items.Count -eq 0) {
        return "none"
    }
    return $items -join ","
}

function Get-PendingCategoryCounts([object[]] $Checks) {
    return @($Checks |
        Where-Object { ($_.status -eq "PENDING") -or ($_.passed -eq $false) } |
        Group-Object category |
        Sort-Object Name |
        ForEach-Object {
            [ordered]@{
                category = $_.Name
                count = $_.Count
            }
        })
}

function Format-PendingCategorySummary([object[]] $Checks) {
    $categoryCounts = @(Get-PendingCategoryCounts $Checks)
    $summary = @($categoryCounts | ForEach-Object { "$($_.category)=$($_.count)" }) -join ", "
    if ([string]::IsNullOrWhiteSpace($summary)) {
        return "none"
    }
    return $summary
}

$resolvedPath = Resolve-ProjectPath $ChecklistPath
if (-not (Test-Path -LiteralPath $resolvedPath)) {
    throw "MVP release checklist missing: $resolvedPath"
}

$content = [System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8)

Assert-Contains $content "OSMU MVP v0.1 Release Checklist" "MVP release checklist"
Assert-Contains $content "Current Evidence Snapshot" "MVP release checklist"
Assert-Contains $content 'Latest operations evidence plan invocation: `.osmu-run/latest-operations-evidence-plan-invocation.json`' "MVP release checklist"
Assert-Contains $content 'Latest operations workflow run-id plan: `.osmu-run/latest-operations-workflow-run-ids.json`' "MVP release checklist"
Assert-Contains $content 'Latest operations artifact collection plan: `.osmu-run/latest-operations-artifact-collection-plan.json`' "MVP release checklist"
Assert-Contains $content 'Current operations bottleneck: `fix-dispatch-preflight`; action 6 dispatch now first requires GitHub CLI/token availability, committed local changes, and a GitHub ref containing the committed readiness code.' "MVP release checklist"
Assert-Contains $content "MVP completion latest verification:" "MVP release checklist"
Assert-Contains $content "Durable preflight latest handoff:" "MVP release checklist"
Assert-Contains $content "Operations readiness latest verification:" "MVP release checklist"
Assert-Contains $content "Operations readiness pending categories:" "MVP release checklist"
Assert-Contains $content "Operations readiness pending remediation entries:" "MVP release checklist"
Assert-Contains $content "Operations evidence plan remediation coverage:" "MVP release checklist"
Assert-Contains $content "Operations workflow run-id latest verification:" "MVP release checklist"
Assert-Contains $content "Operations workflow run-id security finalizer hints:" "MVP release checklist"
Assert-Contains $content "Operations artifact collection latest verification:" "MVP release checklist"
Assert-Contains $content "Operations evidence handoff latest verification:" "MVP release checklist"
Assert-Contains $content "Operations evidence handoff browser dispatch checklist:" "MVP release checklist"
Assert-Contains $content "Operations readiness convergence latest verification:" "MVP release checklist"
Assert-Contains $content "[x] MVP release checklist verifier passes." "MVP release checklist"
Assert-NotContains $content "NO-GO until every durable gate above passes" "MVP release checklist"

$mvpCompletion = Read-OptionalJsonReport $MvpCompletionReportPath "MVP completion report"
if ($null -ne $mvpCompletion) {
    $mvp = $mvpCompletion.data
    Assert-True ($mvp.formatVersion -eq "osmu.mvp-completion.v1") "Unexpected MVP completion formatVersion in $($mvpCompletion.path)."
    $expectedMvpLine = "MVP completion latest verification: result=$($mvp.result), classification=$($mvp.classification), localDurableMvpReady=$(Format-BoolLower $mvp.localDurableMvpReady)."
    Assert-Contains $content $expectedMvpLine "MVP release checklist"
    $durablePreflightBlockingChecks = @($mvp.durablePreflightBlockingActions | ForEach-Object { [string] $_.check })
    $expectedDurablePreflightLine = "Durable preflight latest handoff: result=$($mvp.durablePreflightResult), blockingActions=$(Format-ListSlash $durablePreflightBlockingChecks), nextAction=$($mvp.durablePreflightNextAction)"
    Assert-Contains $content $expectedDurablePreflightLine "MVP release checklist"
}

$operationsReadiness = Read-OptionalJsonReport $OperationsReadinessReportPath "Operations readiness report"
if ($null -ne $operationsReadiness) {
    $operations = $operationsReadiness.data
    $checks = @($operations.checks)
    Assert-True ($operations.formatVersion -eq "osmu.operations-readiness.v1") "Unexpected operations readiness formatVersion in $($operationsReadiness.path)."
    Assert-True ($operations.summary -eq "passed=$($operations.passedCount) pending=$($operations.pendingCount)") "Operations readiness summary does not match passed/pending counts."
    Assert-True (($operations.passedCount + $operations.pendingCount) -eq $checks.Count) "Operations readiness passed+pending count does not match check count."
    Assert-True ($operations.totalCount -eq $checks.Count) "Operations readiness totalCount does not match check count."
    Assert-True ($operations.checkCount -eq $checks.Count) "Operations readiness checkCount does not match check count."

    $expectedOperationsLine = "Operations readiness latest verification: result=$($operations.result), passed=$($operations.passedCount), pending=$($operations.pendingCount), total=$($operations.totalCount)."
    Assert-Contains $content $expectedOperationsLine "MVP release checklist"
    $pendingChecks = @($checks | Where-Object { ($_.status -eq "PENDING") -or ($_.passed -eq $false) })
    Assert-True ($pendingChecks.Count -eq $operations.pendingCount) "Operations readiness pending check count does not match pendingCount."
    $pendingRemediations = @($operations.pendingRemediations)
    Assert-True ([int] $operations.pendingRemediationCount -eq $pendingChecks.Count) "Operations readiness pendingRemediationCount does not match pending checks."
    Assert-True ($pendingRemediations.Count -eq $pendingChecks.Count) "Operations readiness pendingRemediations length does not match pending checks."
    $expectedPendingCategoriesLine = "Operations readiness pending categories: $(Format-PendingCategorySummary $checks)."
    Assert-Contains $content $expectedPendingCategoriesLine "MVP release checklist"
    $expectedPendingRemediationLine = "Operations readiness pending remediation entries: $($operations.pendingRemediationCount)."
    Assert-Contains $content $expectedPendingRemediationLine "MVP release checklist"

}

$operationsEvidencePlan = Read-OptionalJsonReport $OperationsEvidencePlanReportPath "Operations evidence plan report"
if ($null -ne $operationsEvidencePlan) {
    $plan = $operationsEvidencePlan.data
    Assert-True ($plan.formatVersion -eq "osmu.operations-evidence-plan.v1") "Unexpected operations evidence plan formatVersion in $($operationsEvidencePlan.path)."
    $sourceRemediationActions = @($plan.actions | Where-Object { $_.sourcePassed -eq $false })
    Assert-True ([int] $plan.sourcePendingRemediationEntryCount -eq [int] $plan.sourcePendingRemediationCount) "Operations evidence plan remediation entry count does not match source count."
    Assert-True ([int] $plan.sourcePendingRemediationActionCount -eq $sourceRemediationActions.Count) "Operations evidence plan remediation action count does not match source-pending actions."
    Assert-True ([int] $plan.sourcePendingRemediationMissingActionCount -eq ([Math]::Max(0, [int] $plan.sourcePendingRemediationCount - [int] $plan.sourcePendingRemediationActionCount))) "Operations evidence plan missing remediation action count is inconsistent."
    $expectedCoverageReady = ([int] $plan.sourcePendingRemediationCount -eq [int] $plan.sourcePendingRemediationEntryCount) -and ([int] $plan.sourcePendingRemediationCount -eq [int] $plan.sourcePendingRemediationActionCount) -and ([int] $plan.sourcePendingRemediationMissingActionCount -eq 0)
    Assert-True ([bool] $plan.sourcePendingRemediationCoverageReady -eq $expectedCoverageReady) "Operations evidence plan remediation coverageReady flag is inconsistent."
    $expectedEvidencePlanCoverageLine = "Operations evidence plan remediation coverage: source=$($plan.sourcePendingRemediationCount), entries=$($plan.sourcePendingRemediationEntryCount), actions=$($plan.sourcePendingRemediationActionCount), missing=$($plan.sourcePendingRemediationMissingActionCount), ready=$(Format-BoolLower $plan.sourcePendingRemediationCoverageReady)."
    Assert-Contains $content $expectedEvidencePlanCoverageLine "MVP release checklist"
    if ($null -ne $operationsReadiness) {
        Assert-True ([int] $plan.sourcePendingRemediationCount -eq [int] $operationsReadiness.data.pendingRemediationCount) "Operations evidence plan sourcePendingRemediationCount does not match readiness pendingRemediationCount after plan load."
    }
}
$workflowRunIdPlan = Read-OptionalJsonReport $OperationsWorkflowRunIdPlanReportPath "Operations workflow run-id plan report"
if ($null -ne $workflowRunIdPlan) {
    $runIds = $workflowRunIdPlan.data
    Assert-True ($runIds.formatVersion -eq "osmu.operations-workflow-run-id-plan.v1") "Unexpected operations workflow run-id formatVersion in $($workflowRunIdPlan.path)."
    $expectedRunIdLine = "Operations workflow run-id latest verification: result=$($runIds.result), selectedActions=$(Format-IntListCsv @($runIds.selectedActionOrders)), missingWorkflowCount=$($runIds.missingWorkflowCount)."
    Assert-Contains $content $expectedRunIdLine "MVP release checklist"
    $runIdHints = @($runIds.securityEvidenceFinalizerRunIdInputHints)
    $runIdHintInputs = @($runIdHints | ForEach-Object { [string] $_.runIdParameter })
    $runIdHintSupplementalInputs = @($runIdHints | Where-Object { $_.supplementalForSecurityFinalizer -eq $true } | ForEach-Object { [string] $_.runIdParameter })
    $expectedRunIdHintLine = "Operations workflow run-id security finalizer hints: count=$($runIdHints.Count), inputs=$(Format-ListSlash $runIdHintInputs), supplemental=$(Format-ListSlash $runIdHintSupplementalInputs)."
    Assert-Contains $content $expectedRunIdHintLine "MVP release checklist"
}

$operationsArtifactCollection = Read-OptionalJsonReport $OperationsArtifactCollectionPlanReportPath "Operations artifact collection plan report"
if ($null -ne $operationsArtifactCollection) {
    $artifactCollection = $operationsArtifactCollection.data
    Assert-True ($artifactCollection.formatVersion -eq "osmu.operations-artifact-collection-plan.v1") "Unexpected operations artifact collection formatVersion in $($operationsArtifactCollection.path)."
    $expectedArtifactCollectionLine = "Operations artifact collection latest verification: result=$($artifactCollection.result), selectedActions=$(Format-IntListCsv @($artifactCollection.selectedActionOrders)), securityEvidenceFinalizerReady=$(Format-BoolLower $artifactCollection.securityEvidenceFinalizerReady), securityFinalizerInputRows=$(@($artifactCollection.securityEvidenceFinalizerInputs).Count), missingSecurityFinalizerInputs=$(Format-ListSlash @($artifactCollection.securityEvidenceFinalizerMissingRunIdInputs))."
    Assert-Contains $content $expectedArtifactCollectionLine "MVP release checklist"
}

$operationsEvidenceHandoff = Read-OptionalJsonReport $OperationsEvidenceHandoffReportPath "Operations evidence handoff report"
if ($null -ne $operationsEvidenceHandoff) {
    $handoff = $operationsEvidenceHandoff.data
    Assert-True ($handoff.formatVersion -eq "osmu.operations-evidence-handoff.v1") "Unexpected operations evidence handoff formatVersion in $($operationsEvidenceHandoff.path)."
    $expectedEvidenceHandoffLine = "Operations evidence handoff latest verification: result=$($handoff.result), bottleneck=$($handoff.currentBottleneck.code), missingWorkflowRunCount=$($handoff.missingWorkflowRunCount)."
    Assert-Contains $content $expectedEvidenceHandoffLine "MVP release checklist"
    $browserDispatchChecklist = @($handoff.browserDispatchChecklist)
    Assert-True ([int] $handoff.browserDispatchChecklistCount -eq $browserDispatchChecklist.Count) "Operations evidence handoff browserDispatchChecklistCount does not match checklist length."
    $browserDispatchChecklistActionOrders = @($browserDispatchChecklist | ForEach-Object { $_.actionOrder })
    $browserDispatchChecklistWorkflows = @($browserDispatchChecklist | ForEach-Object { [string] $_.workflow })
    $browserDispatchChecklistRunIdParameters = @($browserDispatchChecklist | ForEach-Object { [string] $_.runIdParameter })
    $expectedEvidenceHandoffBrowserChecklistLine = "Operations evidence handoff browser dispatch checklist: count=$($handoff.browserDispatchChecklistCount), actionOrders=$(Format-IntListCsv $browserDispatchChecklistActionOrders), workflows=$(Format-ListSlash $browserDispatchChecklistWorkflows), runIdParameters=$(Format-ListSlash $browserDispatchChecklistRunIdParameters)."
    Assert-Contains $content $expectedEvidenceHandoffBrowserChecklistLine "MVP release checklist"
}

$operationsReadinessConvergence = Read-OptionalJsonReport $OperationsReadinessConvergenceReportPath "Operations readiness convergence report"
if ($null -ne $operationsReadinessConvergence) {
    $convergence = $operationsReadinessConvergence.data
    Assert-True ($convergence.formatVersion -eq "osmu.operations-readiness-convergence.v1") "Unexpected operations readiness convergence formatVersion in $($operationsReadinessConvergence.path)."
    $expectedConvergenceLine = "Operations readiness convergence latest verification: result=$($convergence.result), readinessResult=$($convergence.readinessResult), bottleneck=$($convergence.currentBottleneck.code), missingWorkflowRunCount=$($convergence.missingWorkflowRunCount), kubernetesReportSyncStale=$(Format-BoolLower $convergence.kubernetesReportSyncStale)."
    Assert-Contains $content $expectedConvergenceLine "MVP release checklist"
}

Write-Host "MVP release checklist verified."
Write-Host "MVP release checklist: $resolvedPath"
