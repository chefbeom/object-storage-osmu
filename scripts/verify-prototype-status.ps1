param(
    [string] $StatusPath = ".\dev-docs\prototype-status.md",
    [string] $MvpCompletionReportPath = ".\.osmu-run\latest-mvp-completion.json",
    [string] $OperationsReadinessReportPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $OperationsEvidencePlanReportPath = ".\.osmu-run\latest-operations-evidence-plan.json",
    [string] $OperationsWorkflowRunIdPlanReportPath = ".\.osmu-run\latest-operations-workflow-run-ids.json",
    [string] $OperationsArtifactCollectionPlanReportPath = ".\.osmu-run\latest-operations-artifact-collection-plan.json",
    [string] $OperationsEvidenceHandoffReportPath = ".\.osmu-run\latest-operations-evidence-handoff.json",
    [string] $OperationsReadinessConvergenceReportPath = ".\.osmu-run\latest-operations-readiness-convergence.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-prototype-status.json",
    [string] $ApiSpecPath = ".\dev-docs\api-spec.md",
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

function Assert-OccurrenceCount([string] $Content, [string] $Expected, [int] $Count, [string] $Label) {
    $actual = ([regex]::Matches($Content, [regex]::Escape($Expected))).Count
    if ($actual -ne $Count) {
        throw "$Label contains '$Expected' $actual time(s), expected $Count."
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

function New-ReportSnapshot([object] $Report, [string] $FormatVersion) {
    if ($null -eq $Report) {
        return [ordered]@{
            provided = $false
            path = $null
            formatVersion = $null
        }
    }

    $data = $Report.data
    $snapshot = [ordered]@{
        provided = $true
        path = $Report.path
        formatVersion = $data.formatVersion
        expectedFormatVersion = $FormatVersion
        result = $data.result
    }

    if ($FormatVersion -eq "osmu.mvp-completion.v1") {
        $snapshot["classification"] = $data.classification
        $snapshot["localDurableMvpReady"] = $data.localDurableMvpReady
        $snapshot["durablePreflightResult"] = $data.durablePreflightResult
        $snapshot["durablePreflightNextAction"] = $data.durablePreflightNextAction
        $snapshot["durablePreflightNextActionCommand"] = $data.durablePreflightNextActionCommand
        $snapshot["durablePreflightBlockingActions"] = @($data.durablePreflightBlockingActions | ForEach-Object {
            [ordered]@{
                check = [string] $_.check
                action = [string] $_.action
                command = [string] $_.command
            }
        })
    }
    elseif ($FormatVersion -eq "osmu.operations-readiness.v1") {
        $checks = @($data.checks)
        $snapshot["summary"] = $data.summary
        $snapshot["passedCount"] = $data.passedCount
        $snapshot["pendingCount"] = $data.pendingCount
        $snapshot["totalCount"] = $data.totalCount
        $snapshot["checkCount"] = $data.checkCount
        $computedPendingCategoryCounts = @(Get-PendingCategoryCounts $checks)
        $computedPendingCategorySummary = Format-PendingCategorySummary $checks
        if ($null -ne $data.PSObject.Properties["pendingCategorySummary"]) {
            Assert-True ([string] $data.pendingCategorySummary -eq $computedPendingCategorySummary) "Operations readiness pendingCategorySummary does not match checks."
            $snapshot["pendingCategorySummary"] = [string] $data.pendingCategorySummary
        }
        else {
            $snapshot["pendingCategorySummary"] = $computedPendingCategorySummary
        }
        if ($null -ne $data.PSObject.Properties["pendingCategoryCounts"]) {
            $sourcePendingCategoryCounts = @($data.pendingCategoryCounts)
            Assert-True ($sourcePendingCategoryCounts.Count -eq $computedPendingCategoryCounts.Count) "Operations readiness pendingCategoryCounts length does not match checks."
            for ($i = 0; $i -lt $computedPendingCategoryCounts.Count; $i++) {
                $expected = $computedPendingCategoryCounts[$i]
                $actual = $sourcePendingCategoryCounts[$i]
                Assert-True ([string] $actual.category -eq [string] $expected.category -and [int] $actual.count -eq [int] $expected.count) "Operations readiness pendingCategoryCounts[$i] does not match checks."
            }
            $snapshot["pendingCategoryCounts"] = $sourcePendingCategoryCounts
        }
        else {
            $snapshot["pendingCategoryCounts"] = $computedPendingCategoryCounts
        }
        $pendingChecks = @($checks | Where-Object { ($_.status -eq "PENDING") -or ($_.passed -eq $false) })
        $pendingRemediations = @($data.pendingRemediations)
        Assert-True ([int] $data.pendingRemediationCount -eq $pendingChecks.Count) "Operations readiness pendingRemediationCount does not match pending checks."
        Assert-True ($pendingRemediations.Count -eq $pendingChecks.Count) "Operations readiness pendingRemediations length does not match pending checks."
        $snapshot["pendingRemediationCount"] = [int] $data.pendingRemediationCount
    }
    elseif ($FormatVersion -eq "osmu.operations-evidence-plan.v1") {
        $snapshot["sourcePendingRemediationCount"] = [int] $data.sourcePendingRemediationCount
        $snapshot["sourcePendingRemediationEntryCount"] = [int] $data.sourcePendingRemediationEntryCount
        $snapshot["sourcePendingRemediationActionCount"] = [int] $data.sourcePendingRemediationActionCount
        $snapshot["sourcePendingRemediationMissingActionCount"] = [int] $data.sourcePendingRemediationMissingActionCount
        $snapshot["sourcePendingRemediationCoverageReady"] = [bool] $data.sourcePendingRemediationCoverageReady
    }
    elseif ($FormatVersion -eq "osmu.operations-workflow-run-id-plan.v1") {
        $hints = @($data.securityEvidenceFinalizerRunIdInputHints)
        $snapshot["securityEvidenceFinalizerRunIdInputHintCount"] = $hints.Count
        $snapshot["securityEvidenceFinalizerRunIdInputHintInputs"] = @($hints | ForEach-Object { [string] $_.runIdParameter })
        $snapshot["securityEvidenceFinalizerSupplementalRunIdInputs"] = @($hints | Where-Object { $_.supplementalForSecurityFinalizer -eq $true } | ForEach-Object { [string] $_.runIdParameter })
    }
    elseif ($FormatVersion -eq "osmu.operations-artifact-collection-plan.v1") {
        $snapshot["selectedActionOrders"] = @($data.selectedActionOrders)
        $snapshot["securityEvidenceFinalizerReady"] = $data.securityEvidenceFinalizerReady
        $snapshot["securityEvidenceFinalizerMissingRunIdInputs"] = @($data.securityEvidenceFinalizerMissingRunIdInputs)
        $snapshot["missingSecuritySourceArtifactCount"] = $data.missingSecuritySourceArtifactCount
    }
    elseif ($FormatVersion -eq "osmu.operations-evidence-handoff.v1") {
        $snapshot["currentBottleneck"] = [string] $data.currentBottleneck.code
        $snapshot["missingWorkflowRunCount"] = $data.missingWorkflowRunCount
        $snapshot["staleReportCount"] = $data.staleReportCount
        $browserDispatchChecklist = @($data.browserDispatchChecklist)
        $snapshot["browserDispatchChecklistCount"] = [int] $data.browserDispatchChecklistCount
        $snapshot["browserDispatchChecklistActionOrders"] = @($browserDispatchChecklist | ForEach-Object { $_.actionOrder })
        $snapshot["browserDispatchChecklistWorkflows"] = @($browserDispatchChecklist | ForEach-Object { [string] $_.workflow })
        $snapshot["browserDispatchChecklistRunIdParameters"] = @($browserDispatchChecklist | ForEach-Object { [string] $_.runIdParameter })
    }
    elseif ($FormatVersion -eq "osmu.operations-readiness-convergence.v1") {
        $snapshot["readinessResult"] = $data.readinessResult
        $snapshot["currentBottleneck"] = [string] $data.currentBottleneck.code
        $snapshot["missingWorkflowRunCount"] = $data.missingWorkflowRunCount
        $snapshot["kubernetesReportSyncStale"] = $data.kubernetesReportSyncStale
    }

    return $snapshot
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

$resolvedPath = Resolve-ProjectPath $StatusPath
if (-not (Test-Path -LiteralPath $resolvedPath)) {
    throw "Prototype status missing: $resolvedPath"
}

$content = [System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8)
$resolvedApiSpecPath = Resolve-ProjectPath $ApiSpecPath
if (-not (Test-Path -LiteralPath $resolvedApiSpecPath)) {
    throw "API spec missing: $resolvedApiSpecPath"
}
$apiSpecContent = [System.IO.File]::ReadAllText($resolvedApiSpecPath, [System.Text.Encoding]::UTF8)

Assert-Contains $content "OSMU Prototype Status" "Prototype status"
Assert-Contains $content "Last updated: 2026-06-30 KST" "Prototype status"
Assert-Contains $content "Local durable MVP: ready" "Prototype status"
Assert-Contains $content 'docker-durable-demo-verified' "Prototype status"
Assert-Contains $content "MVP demo estimate: 90-95%" "Prototype status"
Assert-Contains $content "Production/B2B readiness: pending target evidence" "Prototype status"
Assert-Contains $content "S3 compatibility role: replacement layer, not AWS edge parity" "Prototype status"
Assert-Contains $content "S3-compatible replacement layer" "Prototype status"
Assert-Contains $content "Latest Verification Snapshot" "Prototype status"
Assert-Contains $content "Snapshot date: 2026-06-30 KST" "Prototype status"
Assert-Contains $content "MVP completion latest verification:" "Prototype status"
Assert-Contains $content "Durable preflight latest handoff:" "Prototype status"
Assert-Contains $content "Operations readiness latest verification: result=pending, passed=82, pending=20, total=102." "Prototype status"
Assert-Contains $content "Operations readiness pending categories:" "Prototype status"
Assert-Contains $content "Operations readiness pending remediation entries:" "Prototype status"
Assert-Contains $content "Operations evidence plan remediation coverage:" "Prototype status"
Assert-Contains $content "Operations workflow run-id security finalizer hints:" "Prototype status"
Assert-Contains $content "Operations artifact collection latest verification:" "Prototype status"
Assert-Contains $content "Operations evidence handoff latest verification:" "Prototype status"
Assert-Contains $content "Operations evidence handoff browser dispatch checklist:" "Prototype status"
Assert-Contains $content "Operations readiness convergence latest verification:" "Prototype status"
Assert-Contains $content "S3 boundary latest verification: verify-s3-compatibility-boundary.ps1 passed." "Prototype status"
Assert-Contains $content 'Prototype status verifier output: `.osmu-run/latest-prototype-status.json` records the reduced snapshot, durable preflight handoff, total/check counts, source readiness pending category summary/counts, pending remediation count, workflow run-id security finalizer hint summary, artifact collection security finalizer input checklist, handoff browser dispatch checklist, convergence, and evidence cross-check.' "Prototype status"
Assert-Contains $apiSpecContent 'The response JSON below is a synthetic field-shape fixture; its `passed=36 pending=6` operations readiness summary is not the current evidence snapshot.' "API spec"
Assert-Contains $apiSpecContent 'Use `dev-docs/prototype-status.md`, `dev-docs/development-roadmap.md`, and `.osmu-run/latest-operations-readiness.json` for current readiness counts.' "API spec"
Assert-Contains $content "B2B product estimate remains about 45%" "Prototype status"
Assert-Contains $content "Vendor-specific fixed SDK/schema card/bank/tax/ERP provider adapters and raw provider response storage remain out of scope" "Prototype status"
Assert-Contains $content "configurable native API bridge readiness is implemented" "Prototype status"
Assert-NotContains $content "Native card/bank/tax/ERP provider API adapters and raw provider response storage remain out of scope" "Prototype status"
Assert-Contains $content "do not expand AWS S3 parity unless a supported replacement-client smoke or migration blocker proves product impact" "Prototype status"
Assert-Contains $content "Enterprise auth implemented locally" "Prototype status"
Assert-Contains $content "OIDC callback" "Prototype status"
Assert-Contains $content "LDAP bind/search" "Prototype status"
Assert-Contains $content "admin-approved JIT" "Prototype status"
Assert-Contains $content "Data-flow analytics implemented locally" "Prototype status"
Assert-Contains $content "daily/materialized/monthly/stored monthly" "Prototype status"
Assert-Contains $content "target query-plan evidence" "Prototype status"
Assert-Contains $content "Operations evidence chain implemented locally" "Prototype status"
Assert-Contains $content "storage backend telemetry" "Prototype status"
Assert-Contains $content "monitoring threshold" "Prototype status"
Assert-Contains $content "secret rotation" "Prototype status"
Assert-Contains $content "commercial integration" "Prototype status"
Assert-Contains $content "commercial approval" "Prototype status"
Assert-Contains $content "operations handoff package" "Prototype status"
Assert-Contains $content "support escalation handoff workflow/import" "Prototype status"
Assert-Contains $content "readiness convergence" "Prototype status"
Assert-Contains $content "Kubernetes operations report sync" "Prototype status"
Assert-Contains $content "Next Best Work" "Prototype status"
Assert-Contains $content "Production operations evidence chain" "Prototype status"
Assert-Contains $content "monitoring threshold" "Prototype status"
Assert-Contains $content "Data-flow storage transition plan" "Prototype status"
Assert-Contains $content "Commercial integration/approval target evidence" "Prototype status"
Assert-Contains $content "S3 replacement layer" "Prototype status"
Assert-NotContains $content "`n0. " "Prototype status"
Assert-NotContains $content "Last updated: 2026-06-18" "Prototype status"
Assert-NotContains $content "Last updated: 2026-06-21" "Prototype status"
Assert-NotContains $content "full Docker runtime verification is still pending" "Prototype status"
Assert-NotContains $content "Current sellable state: local lightweight demo only" "Prototype status"
Assert-NotContains $content "SSO/LDAP, final billing/licensing approval" "Prototype status"
Assert-NotContains $content "Backup/replication, production monitoring/alert validation, SSO/LDAP" "Prototype status"
Assert-OccurrenceCount $content "- Commercial readiness: B2B positioning, pilot packaging, licensing, and pricing draft with final approval still pending." 0 "Prototype status"

$expectedMvpLine = $null
$expectedDurablePreflightLine = $null
$expectedOperationsLine = $null
$expectedOperationsPendingCategoriesLine = $null
$expectedOperationsWorkflowRunIdHintLine = $null
$expectedArtifactCollectionLine = $null
$expectedEvidenceHandoffLine = $null
$expectedConvergenceLine = $null

$mvpCompletion = Read-OptionalJsonReport $MvpCompletionReportPath "MVP completion report"
if ($null -ne $mvpCompletion) {
    $mvp = $mvpCompletion.data
    Assert-True ($mvp.formatVersion -eq "osmu.mvp-completion.v1") "Unexpected MVP completion formatVersion in $($mvpCompletion.path)."

    $expectedMvpLine = "MVP completion latest verification: result=$($mvp.result), classification=$($mvp.classification), localDurableMvpReady=$(Format-BoolLower $mvp.localDurableMvpReady)."
    Assert-Contains $content $expectedMvpLine "Prototype status"
    $durablePreflightBlockingChecks = @($mvp.durablePreflightBlockingActions | ForEach-Object { [string] $_.check })
    $expectedDurablePreflightLine = "Durable preflight latest handoff: result=$($mvp.durablePreflightResult), blockingActions=$(Format-ListSlash $durablePreflightBlockingChecks), nextAction=$($mvp.durablePreflightNextAction)"
    Assert-Contains $content $expectedDurablePreflightLine "Prototype status"
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
    $expectedOperationsEvidencePlanLine = "Operations evidence plan remediation coverage: source=$($plan.sourcePendingRemediationCount), entries=$($plan.sourcePendingRemediationEntryCount), actions=$($plan.sourcePendingRemediationActionCount), missing=$($plan.sourcePendingRemediationMissingActionCount), ready=$(Format-BoolLower $plan.sourcePendingRemediationCoverageReady)."
    Assert-Contains $content $expectedOperationsEvidencePlanLine "Prototype status"
}
$operationsWorkflowRunIdPlan = Read-OptionalJsonReport $OperationsWorkflowRunIdPlanReportPath "Operations workflow run-id plan report"
if ($null -ne $operationsWorkflowRunIdPlan) {
    $runIds = $operationsWorkflowRunIdPlan.data
    Assert-True ($runIds.formatVersion -eq "osmu.operations-workflow-run-id-plan.v1") "Unexpected operations workflow run-id formatVersion in $($operationsWorkflowRunIdPlan.path)."
    $runIdHints = @($runIds.securityEvidenceFinalizerRunIdInputHints)
    $runIdHintInputs = @($runIdHints | ForEach-Object { [string] $_.runIdParameter })
    $runIdHintSupplementalInputs = @($runIdHints | Where-Object { $_.supplementalForSecurityFinalizer -eq $true } | ForEach-Object { [string] $_.runIdParameter })
    $expectedOperationsWorkflowRunIdHintLine = "Operations workflow run-id security finalizer hints: count=$($runIdHints.Count), inputs=$(Format-ListSlash $runIdHintInputs), supplemental=$(Format-ListSlash $runIdHintSupplementalInputs)."
    Assert-Contains $content $expectedOperationsWorkflowRunIdHintLine "Prototype status"
}
$operationsArtifactCollection = Read-OptionalJsonReport $OperationsArtifactCollectionPlanReportPath "Operations artifact collection plan report"
if ($null -ne $operationsArtifactCollection) {
    $artifactCollection = $operationsArtifactCollection.data
    Assert-True ($artifactCollection.formatVersion -eq "osmu.operations-artifact-collection-plan.v1") "Unexpected operations artifact collection formatVersion in $($operationsArtifactCollection.path)."
    $expectedArtifactCollectionLine = "Operations artifact collection latest verification: result=$($artifactCollection.result), selectedActions=$(Format-IntListCsv @($artifactCollection.selectedActionOrders)), securityEvidenceFinalizerReady=$(Format-BoolLower $artifactCollection.securityEvidenceFinalizerReady), securityFinalizerInputRows=$(@($artifactCollection.securityEvidenceFinalizerInputs).Count), missingSecurityFinalizerInputs=$(Format-ListSlash @($artifactCollection.securityEvidenceFinalizerMissingRunIdInputs))."
    Assert-Contains $content $expectedArtifactCollectionLine "Prototype status"
}

$operationsEvidenceHandoff = Read-OptionalJsonReport $OperationsEvidenceHandoffReportPath "Operations evidence handoff report"
if ($null -ne $operationsEvidenceHandoff) {
    $handoff = $operationsEvidenceHandoff.data
    Assert-True ($handoff.formatVersion -eq "osmu.operations-evidence-handoff.v1") "Unexpected operations evidence handoff formatVersion in $($operationsEvidenceHandoff.path)."
    $expectedEvidenceHandoffLine = "Operations evidence handoff latest verification: result=$($handoff.result), bottleneck=$($handoff.currentBottleneck.code), missingWorkflowRunCount=$($handoff.missingWorkflowRunCount)."
    Assert-Contains $content $expectedEvidenceHandoffLine "Prototype status"
    $browserDispatchChecklist = @($handoff.browserDispatchChecklist)
    Assert-True ([int] $handoff.browserDispatchChecklistCount -eq $browserDispatchChecklist.Count) "Operations evidence handoff browserDispatchChecklistCount does not match checklist length."
    $browserDispatchChecklistActionOrders = @($browserDispatchChecklist | ForEach-Object { $_.actionOrder })
    $browserDispatchChecklistWorkflows = @($browserDispatchChecklist | ForEach-Object { [string] $_.workflow })
    $browserDispatchChecklistRunIdParameters = @($browserDispatchChecklist | ForEach-Object { [string] $_.runIdParameter })
    $expectedEvidenceHandoffBrowserChecklistLine = "Operations evidence handoff browser dispatch checklist: count=$($handoff.browserDispatchChecklistCount), actionOrders=$(Format-IntListCsv $browserDispatchChecklistActionOrders), workflows=$(Format-ListSlash $browserDispatchChecklistWorkflows), runIdParameters=$(Format-ListSlash $browserDispatchChecklistRunIdParameters)."
    Assert-Contains $content $expectedEvidenceHandoffBrowserChecklistLine "Prototype status"
}

$operationsReadinessConvergence = Read-OptionalJsonReport $OperationsReadinessConvergenceReportPath "Operations readiness convergence report"
if ($null -ne $operationsReadinessConvergence) {
    $convergence = $operationsReadinessConvergence.data
    Assert-True ($convergence.formatVersion -eq "osmu.operations-readiness-convergence.v1") "Unexpected operations readiness convergence formatVersion in $($operationsReadinessConvergence.path)."
    $expectedConvergenceLine = "Operations readiness convergence latest verification: result=$($convergence.result), readinessResult=$($convergence.readinessResult), bottleneck=$($convergence.currentBottleneck.code), missingWorkflowRunCount=$($convergence.missingWorkflowRunCount), kubernetesReportSyncStale=$(Format-BoolLower $convergence.kubernetesReportSyncStale)."
    Assert-Contains $content $expectedConvergenceLine "Prototype status"
}

$operationsReadiness = Read-OptionalJsonReport $OperationsReadinessReportPath "Operations readiness report"
if ($null -ne $operationsReadiness) {
    $operations = $operationsReadiness.data
    $checks = @($operations.checks)
    Assert-True ($operations.formatVersion -eq "osmu.operations-readiness.v1") "Unexpected operations readiness formatVersion in $($operationsReadiness.path)."
    Assert-True ($operations.result -eq "pending") "Prototype status expects operations readiness result=pending, but report has result=$($operations.result)."
    Assert-True ($operations.summary -eq "passed=$($operations.passedCount) pending=$($operations.pendingCount)") "Operations readiness summary does not match passed/pending counts."
    Assert-True (($operations.passedCount + $operations.pendingCount) -eq $checks.Count) "Operations readiness passed+pending count does not match check count."
    Assert-True ($operations.totalCount -eq $checks.Count) "Operations readiness totalCount does not match check count."
    Assert-True ($operations.checkCount -eq $checks.Count) "Operations readiness checkCount does not match check count."

    $expectedOperationsLine = "Operations readiness latest verification: result=$($operations.result), passed=$($operations.passedCount), pending=$($operations.pendingCount), total=$($operations.totalCount)."
    Assert-Contains $content $expectedOperationsLine "Prototype status"
    $pendingChecks = @($checks | Where-Object { ($_.status -eq "PENDING") -or ($_.passed -eq $false) })
    Assert-True ($pendingChecks.Count -eq $operations.pendingCount) "Operations readiness pending check count does not match pendingCount."
    $pendingRemediations = @($operations.pendingRemediations)
    Assert-True ([int] $operations.pendingRemediationCount -eq $pendingChecks.Count) "Operations readiness pendingRemediationCount does not match pending checks."
    Assert-True ($pendingRemediations.Count -eq $pendingChecks.Count) "Operations readiness pendingRemediations length does not match pending checks."

    $expectedOperationsPendingCategoriesLine = "Operations readiness pending categories: $(Format-PendingCategorySummary $checks)."
    Assert-Contains $content $expectedOperationsPendingCategoriesLine "Prototype status"
    $expectedOperationsPendingRemediationLine = "Operations readiness pending remediation entries: $($operations.pendingRemediationCount)."
    Assert-Contains $content $expectedOperationsPendingRemediationLine "Prototype status"
    if ($null -ne $operationsEvidencePlan) {
        Assert-True ([int] $operationsEvidencePlan.data.sourcePendingRemediationCount -eq [int] $operations.pendingRemediationCount) "Operations evidence plan sourcePendingRemediationCount does not match readiness pendingRemediationCount."
    }
}

if (-not [string]::IsNullOrWhiteSpace($JsonOutputPath)) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $jsonOutputDirectory = Split-Path -Parent $resolvedJsonOutputPath
    if (-not (Test-Path -LiteralPath $jsonOutputDirectory)) {
        New-Item -ItemType Directory -Force -Path $jsonOutputDirectory | Out-Null
    }

    $report = [ordered]@{
        formatVersion = "osmu.prototype-status-verification.v1"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        result = "passed"
        statusPath = $resolvedPath
        requireEvidenceReports = [bool] $RequireEvidenceReports
        statusSummary = [ordered]@{
            localDurableMvp = "ready"
            currentDemoStatus = "docker-durable-demo-verified"
            mvpDemoEstimate = "90-95%"
            productionB2bReadiness = "pending target evidence"
            s3CompatibilityRole = "replacement layer, not AWS edge parity"
            snapshotDate = "2026-06-30 KST"
            b2bProductEstimate = "about 45%"
        }
        evidence = [ordered]@{
            mvpCompletion = New-ReportSnapshot $mvpCompletion "osmu.mvp-completion.v1"
            operationsReadiness = New-ReportSnapshot $operationsReadiness "osmu.operations-readiness.v1"
            operationsEvidencePlan = New-ReportSnapshot $operationsEvidencePlan "osmu.operations-evidence-plan.v1"
            operationsWorkflowRunIdPlan = New-ReportSnapshot $operationsWorkflowRunIdPlan "osmu.operations-workflow-run-id-plan.v1"
            operationsArtifactCollection = New-ReportSnapshot $operationsArtifactCollection "osmu.operations-artifact-collection-plan.v1"
            operationsEvidenceHandoff = New-ReportSnapshot $operationsEvidenceHandoff "osmu.operations-evidence-handoff.v1"
            operationsReadinessConvergence = New-ReportSnapshot $operationsReadinessConvergence "osmu.operations-readiness-convergence.v1"
        }
        expectedLines = [ordered]@{
            mvpCompletion = $expectedMvpLine
            durablePreflight = $expectedDurablePreflightLine
            operationsReadiness = $expectedOperationsLine
            operationsReadinessPendingCategories = $expectedOperationsPendingCategoriesLine
            operationsEvidencePlan = $expectedOperationsEvidencePlanLine
            operationsWorkflowRunIdHints = $expectedOperationsWorkflowRunIdHintLine
            operationsArtifactCollection = $expectedArtifactCollectionLine
            operationsEvidenceHandoff = $expectedEvidenceHandoffLine
            operationsEvidenceHandoffBrowserChecklist = $expectedEvidenceHandoffBrowserChecklistLine
            operationsReadinessConvergence = $expectedConvergenceLine
        }
        nextBestWork = @(
            "Production operations evidence chain",
            "Data-flow storage transition plan",
            "Commercial integration/approval target evidence",
            "Enterprise auth target smoke",
            "Operations handoff package",
            "S3 replacement layer"
        )
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($resolvedJsonOutputPath, ($report | ConvertTo-Json -Depth 10), $utf8NoBom)
    Write-Host "Prototype status JSON: $resolvedJsonOutputPath"
}

Write-Host "Prototype status verified."
Write-Host "Prototype status: $resolvedPath"
