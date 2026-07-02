param(
    [string] $RoadmapPath = ".\dev-docs\development-roadmap.md",
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

$docEncodingVerifier = Join-Path $PSScriptRoot "verify-doc-encoding-hygiene.ps1"
if (-not (Test-Path -LiteralPath $docEncodingVerifier)) {
    throw "Doc encoding hygiene verifier missing: $docEncodingVerifier"
}
& $docEncodingVerifier

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

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-NotContains([string] $Content, [string] $Unexpected, [string] $Label) {
    if ($Content.Contains($Unexpected)) {
        throw "$Label contains unexpected text: $Unexpected"
    }
}

function Decode-Utf8Base64([string] $Value) {
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
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
$resolvedPath = Resolve-ProjectPath $RoadmapPath
if (-not (Test-Path -LiteralPath $resolvedPath)) {
    throw "Development roadmap missing: $resolvedPath"
}

$content = [System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8)
$testCasesPath = Resolve-ProjectPath ".\dev-docs\test-cases.md"
if (-not (Test-Path -LiteralPath $testCasesPath)) {
    throw "Test cases missing: $testCasesPath"
}
$testCasesContent = [System.IO.File]::ReadAllText($testCasesPath, [System.Text.Encoding]::UTF8)

Assert-Contains $content "OSMU Development Roadmap" "Development roadmap"
Assert-Contains $content (Decode-Utf8Base64 "7J6R7ISx7J28OiAyMDI2LTA2LTMwIEtTVA==") "Development roadmap"
Assert-Contains $content (Decode-Utf8Base64 "6riw7KSAIHNuYXBzaG90OiAyMDI2LTA2LTMwIEtTVC4=") "Development roadmap"
Assert-Contains $content "S3-compatible replacement layer" "Development roadmap"
Assert-Contains $content 'docker-durable-demo-verified' "Development roadmap"
Assert-Contains $content "MVP completion latest verification:" "Development roadmap"
Assert-Contains $content "Durable preflight latest handoff:" "Development roadmap"
Assert-Contains $content "Operations readiness latest verification:" "Development roadmap"
Assert-Contains $content "Operations readiness pending categories:" "Development roadmap"
Assert-Contains $content "Operations readiness pending remediation entries:" "Development roadmap"
Assert-Contains $content "Operations evidence plan remediation coverage:" "Development roadmap"
Assert-Contains $content "Operations workflow run-id security finalizer hints:" "Development roadmap"
Assert-Contains $content "Operations artifact collection latest verification:" "Development roadmap"
Assert-Contains $content "Operations evidence handoff latest verification:" "Development roadmap"
Assert-Contains $content "Operations evidence handoff input-free review:" "Development roadmap"
Assert-Contains $content "Operations evidence handoff browser dispatch checklist:" "Development roadmap"
Assert-Contains $content "Operations readiness convergence latest verification:" "Development roadmap"
Assert-Contains $content "Operations readiness convergence input-free review:" "Development roadmap"
Assert-Contains $content "S3 boundary latest verification: verify-s3-compatibility-boundary.ps1 passed." "Development roadmap"
Assert-Contains $testCasesContent "2026-06-30 snapshot" "Test cases"
Assert-NotContains $testCasesContent "2026-06-23 snapshot" "Test cases"
Assert-Contains $content "Production Operations Evidence" "Development roadmap"
Assert-Contains $content (Decode-Utf8Base64 "S3ViZXJuZXRlcyBEUiBmaW5hbGl6ZXIgYHJlc3VsdD1yZWFkeWA=") "Development roadmap"
Assert-Contains $content 'security evidence finalizer `result=passed`' "Development roadmap"
Assert-Contains $content 'IAM/RBAC finalizer `result=passed`' "Development roadmap"
Assert-NotContains $content 'security evidence finalizer `result=ready`' "Development roadmap"
Assert-NotContains $content 'IAM/RBAC finalizer `result=ready`' "Development roadmap"
Assert-Contains $content 'operations readiness convergence `result=ready`' "Development roadmap"
Assert-Contains $content 'Kubernetes operations report sync `result=applied`' "Development roadmap"
Assert-Contains $content "Data-flow storage transition plan" "Development roadmap"
Assert-Contains $content "target query latency" "Development roadmap"
Assert-Contains $content "data-flow query/retention budget evidence writer" "Development roadmap"
Assert-Contains $content "write-data-flow-query-retention-budget-evidence.ps1" "Development roadmap"
Assert-Contains $content "target query-plan evidence" "Development roadmap"
Assert-Contains $content "Alertmanager/Grafana threshold target contract" "Development roadmap"
Assert-Contains $content "monitoring threshold evidence writer" "Development roadmap"
Assert-Contains $content "data-flow storage transition runbook evidence writer" "Development roadmap"
Assert-Contains $content "threshold value/receiver" "Development roadmap"
Assert-Contains $content "chargeback closeout evidence writer" "Development roadmap"
Assert-Contains $content "write-chargeback-closeout-evidence.ps1" "Development roadmap"
Assert-Contains $content "Enterprise auth target smoke" "Development roadmap"
Assert-Contains $content "JIT rollback/runbook evidence writer" "Development roadmap"
Assert-Contains $content "write-enterprise-auth-jit-rollback-evidence.ps1" "Development roadmap"
Assert-Contains $content "scope-out evidence" "Development roadmap"
Assert-Contains $content "cluster network access review evidence writer" "Development roadmap"
Assert-Contains $content "write-cluster-network-access-review-evidence.ps1" "Development roadmap"
Assert-Contains $content "Helm values hardening evidence writer" "Development roadmap"
Assert-Contains $content "write-helm-values-hardening-evidence.ps1" "Development roadmap"
Assert-Contains $content "support escalation handoff evidence writer" "Development roadmap"
Assert-Contains $content "write-support-escalation-handoff-evidence.ps1" "Development roadmap"
Assert-Contains $content "manual-support-escalation-handoff-evidence.yml" "Development roadmap"
Assert-Contains $content "S3 client smoke" "Development roadmap"
Assert-Contains $content "role scope" "Development roadmap"
Assert-NotContains $content "edge parity" "Development roadmap"
Assert-NotContains $content "`n0. " "Development roadmap"
Assert-NotContains $content "`n## 0. " "Development roadmap"
$sectionMatches = @([regex]::Matches($content, "(?m)^##\s+(\d+)\."))
$expectedSections = @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
Assert-True ($sectionMatches.Count -eq $expectedSections.Count) "Development roadmap numbered section count does not match expected 1..10."
for ($sectionIndex = 0; $sectionIndex -lt $expectedSections.Count; $sectionIndex++) {
    $actualSection = [int] $sectionMatches[$sectionIndex].Groups[1].Value
    $expectedSection = [int] $expectedSections[$sectionIndex]
    Assert-True ($actualSection -eq $expectedSection) "Development roadmap numbered section order mismatch at index ${sectionIndex}: expected $expectedSection but found $actualSection."
}
Assert-NotContains $content (Decode-Utf8Base64 "7J6R7ISx7J28OiAyMDI2LTA2LTIx") "Development roadmap"

$mvpCompletion = Read-OptionalJsonReport $MvpCompletionReportPath "MVP completion report"
if ($null -ne $mvpCompletion) {
    $mvp = $mvpCompletion.data
    Assert-True ($mvp.formatVersion -eq "osmu.mvp-completion.v1") "Unexpected MVP completion formatVersion in $($mvpCompletion.path)."
    $expectedMvpLine = "MVP completion latest verification: result=$($mvp.result), classification=$($mvp.classification), localDurableMvpReady=$(Format-BoolLower $mvp.localDurableMvpReady)."
    Assert-Contains $content $expectedMvpLine "Development roadmap"
    if ($RequireEvidenceReports) {
        $durablePreflightBlockingChecks = @($mvp.durablePreflightBlockingActions | ForEach-Object { [string] $_.check })
        $expectedDurablePreflightLine = "Durable preflight latest handoff: result=$($mvp.durablePreflightResult), blockingActions=$(Format-ListSlash $durablePreflightBlockingChecks), nextAction=$($mvp.durablePreflightNextAction)"
        Assert-Contains $content $expectedDurablePreflightLine "Development roadmap"
    }
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
    Assert-Contains $content $expectedEvidencePlanCoverageLine "Development roadmap"
}
$operationsWorkflowRunIdPlan = Read-OptionalJsonReport $OperationsWorkflowRunIdPlanReportPath "Operations workflow run-id plan report"
if ($null -ne $operationsWorkflowRunIdPlan) {
    $runIds = $operationsWorkflowRunIdPlan.data
    Assert-True ($runIds.formatVersion -eq "osmu.operations-workflow-run-id-plan.v1") "Unexpected operations workflow run-id formatVersion in $($operationsWorkflowRunIdPlan.path)."
    $runIdHints = @($runIds.securityEvidenceFinalizerRunIdInputHints)
    $runIdHintInputs = @($runIdHints | ForEach-Object { [string] $_.runIdParameter })
    $runIdHintSupplementalInputs = @($runIdHints | Where-Object { $_.supplementalForSecurityFinalizer -eq $true } | ForEach-Object { [string] $_.runIdParameter })
    $expectedWorkflowRunIdHintLine = "Operations workflow run-id security finalizer hints: count=$($runIdHints.Count), inputs=$(Format-ListSlash $runIdHintInputs), supplemental=$(Format-ListSlash $runIdHintSupplementalInputs)."
    Assert-Contains $content $expectedWorkflowRunIdHintLine "Development roadmap"
}
$operationsArtifactCollection = Read-OptionalJsonReport $OperationsArtifactCollectionPlanReportPath "Operations artifact collection plan report"
if ($null -ne $operationsArtifactCollection) {
    $artifactCollection = $operationsArtifactCollection.data
    Assert-True ($artifactCollection.formatVersion -eq "osmu.operations-artifact-collection-plan.v1") "Unexpected operations artifact collection formatVersion in $($operationsArtifactCollection.path)."
    $expectedArtifactCollectionLine = "Operations artifact collection latest verification: result=$($artifactCollection.result), selectedActions=$(Format-IntListCsv @($artifactCollection.selectedActionOrders)), securityEvidenceFinalizerReady=$(Format-BoolLower $artifactCollection.securityEvidenceFinalizerReady), securityFinalizerInputRows=$(@($artifactCollection.securityEvidenceFinalizerInputs).Count), missingSecurityFinalizerInputs=$(Format-ListSlash @($artifactCollection.securityEvidenceFinalizerMissingRunIdInputs))."
    Assert-Contains $content $expectedArtifactCollectionLine "Development roadmap"
}

$operationsEvidenceHandoff = Read-OptionalJsonReport $OperationsEvidenceHandoffReportPath "Operations evidence handoff report"
if ($null -ne $operationsEvidenceHandoff) {
    $handoff = $operationsEvidenceHandoff.data
    Assert-True ($handoff.formatVersion -eq "osmu.operations-evidence-handoff.v1") "Unexpected operations evidence handoff formatVersion in $($operationsEvidenceHandoff.path)."
    $expectedEvidenceHandoffLine = "Operations evidence handoff latest verification: result=$($handoff.result), bottleneck=$($handoff.currentBottleneck.code), missingWorkflowRunCount=$($handoff.missingWorkflowRunCount)."
    Assert-Contains $content $expectedEvidenceHandoffLine "Development roadmap"
    $expectedEvidenceHandoffInputFreeReviewLine = "Operations evidence handoff input-free review: exists=$(Format-BoolLower $handoff.inputFreeBlockedReviewReportExists), result=$($handoff.inputFreeBlockedReviewReportResult), actionOrders=$(Format-IntListCsv @($handoff.inputFreeBlockedReviewReportActionOrders)), selected=$($handoff.inputFreeBlockedReviewReportSelectedActionCount), blocked=$($handoff.inputFreeBlockedReviewReportBlockedCount), stale=$(Format-BoolLower $handoff.inputFreeBlockedReviewReportStale), scopeMismatch=$(Format-BoolLower $handoff.inputFreeBlockedReviewReportScopeMismatch)."
    Assert-Contains $content $expectedEvidenceHandoffInputFreeReviewLine "Development roadmap"
    $browserDispatchChecklist = @($handoff.browserDispatchChecklist)
    Assert-True ([int] $handoff.browserDispatchChecklistCount -eq $browserDispatchChecklist.Count) "Operations evidence handoff browserDispatchChecklistCount does not match checklist length."
    $browserDispatchChecklistActionOrders = @($browserDispatchChecklist | ForEach-Object { $_.actionOrder })
    $browserDispatchChecklistWorkflows = @($browserDispatchChecklist | ForEach-Object { [string] $_.workflow })
    $browserDispatchChecklistRunIdParameters = @($browserDispatchChecklist | ForEach-Object { [string] $_.runIdParameter })
    $expectedEvidenceHandoffBrowserChecklistLine = "Operations evidence handoff browser dispatch checklist: count=$($handoff.browserDispatchChecklistCount), actionOrders=$(Format-IntListCsv $browserDispatchChecklistActionOrders), workflows=$(Format-ListSlash $browserDispatchChecklistWorkflows), runIdParameters=$(Format-ListSlash $browserDispatchChecklistRunIdParameters)."
    Assert-Contains $content $expectedEvidenceHandoffBrowserChecklistLine "Development roadmap"
}

$operationsReadinessConvergence = Read-OptionalJsonReport $OperationsReadinessConvergenceReportPath "Operations readiness convergence report"
if ($null -ne $operationsReadinessConvergence) {
    $convergence = $operationsReadinessConvergence.data
    Assert-True ($convergence.formatVersion -eq "osmu.operations-readiness-convergence.v1") "Unexpected operations readiness convergence formatVersion in $($operationsReadinessConvergence.path)."
    $expectedConvergenceLine = "Operations readiness convergence latest verification: result=$($convergence.result), readinessResult=$($convergence.readinessResult), bottleneck=$($convergence.currentBottleneck.code), missingWorkflowRunCount=$($convergence.missingWorkflowRunCount), kubernetesReportSyncStale=$(Format-BoolLower $convergence.kubernetesReportSyncStale)."
    Assert-Contains $content $expectedConvergenceLine "Development roadmap"
    $expectedConvergenceInputFreeReviewLine = "Operations readiness convergence input-free review: exists=$(Format-BoolLower $convergence.handoffInputFreeBlockedReviewReportExists), result=$($convergence.handoffInputFreeBlockedReviewReportResult), actionOrders=$(Format-IntListCsv @($convergence.handoffInputFreeBlockedReviewReportActionOrders)), selected=$($convergence.handoffInputFreeBlockedReviewReportSelectedActionCount), blocked=$($convergence.handoffInputFreeBlockedReviewReportBlockedCount), stale=$(Format-BoolLower $convergence.handoffInputFreeBlockedReviewReportStale), scopeMismatch=$(Format-BoolLower $convergence.handoffInputFreeBlockedReviewReportScopeMismatch)."
    Assert-Contains $content $expectedConvergenceInputFreeReviewLine "Development roadmap"
}
$operationsReadiness = Read-OptionalJsonReport $OperationsReadinessReportPath "Operations readiness report"
if ($null -ne $operationsReadiness) {
    $operations = $operationsReadiness.data
    $checks = @($operations.checks)
    Assert-True ($operations.formatVersion -eq "osmu.operations-readiness.v1") "Unexpected operations readiness formatVersion in $($operationsReadiness.path)."
    Assert-True ($operations.result -eq "pending") "Development roadmap expects operations readiness result=pending, but report has result=$($operations.result)."
    Assert-True ($operations.summary -eq "passed=$($operations.passedCount) pending=$($operations.pendingCount)") "Operations readiness summary does not match passed/pending counts."
    Assert-True (($operations.passedCount + $operations.pendingCount) -eq $checks.Count) "Operations readiness passed+pending count does not match check count."
    Assert-True ($operations.totalCount -eq $checks.Count) "Operations readiness totalCount does not match check count."
    Assert-True ($operations.checkCount -eq $checks.Count) "Operations readiness checkCount does not match check count."
    $expectedPendingCategoryCounts = @(Get-PendingCategoryCounts $checks)
    $expectedPendingCategorySummary = Format-PendingCategorySummary $checks
    Assert-True ($operations.pendingCategorySummary -eq $expectedPendingCategorySummary) "Operations readiness pendingCategorySummary does not match checks."
    Assert-True (@($operations.pendingCategoryCounts).Count -eq $expectedPendingCategoryCounts.Count) "Operations readiness pendingCategoryCounts length does not match checks."
    for ($i = 0; $i -lt $expectedPendingCategoryCounts.Count; $i++) {
        $expected = $expectedPendingCategoryCounts[$i]
        $actual = @($operations.pendingCategoryCounts)[$i]
        Assert-True ([string] $actual.category -eq [string] $expected.category -and [int] $actual.count -eq [int] $expected.count) "Operations readiness pendingCategoryCounts[$i] does not match checks."
    }

    $expectedOperationsLine = "Operations readiness latest verification: result=$($operations.result), passed=$($operations.passedCount), pending=$($operations.pendingCount), total=$($operations.totalCount)."
    Assert-Contains $content $expectedOperationsLine "Development roadmap"
    $pendingChecks = @($checks | Where-Object { ($_.status -eq "PENDING") -or ($_.passed -eq $false) })
    Assert-True ($pendingChecks.Count -eq $operations.pendingCount) "Operations readiness pending check count does not match pendingCount."
    $pendingRemediations = @($operations.pendingRemediations)
    Assert-True ([int] $operations.pendingRemediationCount -eq $pendingChecks.Count) "Operations readiness pendingRemediationCount does not match pending checks."
    Assert-True ($pendingRemediations.Count -eq $pendingChecks.Count) "Operations readiness pendingRemediations length does not match pending checks."

    $expectedPendingCategoriesLine = "Operations readiness pending categories: $expectedPendingCategorySummary."
    Assert-Contains $content $expectedPendingCategoriesLine "Development roadmap"
    $expectedPendingRemediationLine = "Operations readiness pending remediation entries: $($operations.pendingRemediationCount)."
    Assert-Contains $content $expectedPendingRemediationLine "Development roadmap"
    if ($null -ne $operationsEvidencePlan) {
        Assert-True ([int] $operationsEvidencePlan.data.sourcePendingRemediationCount -eq [int] $operations.pendingRemediationCount) "Operations evidence plan sourcePendingRemediationCount does not match readiness pendingRemediationCount."
    }
}

Write-Host "Development roadmap verified."
Write-Host "Development roadmap: $resolvedPath"
