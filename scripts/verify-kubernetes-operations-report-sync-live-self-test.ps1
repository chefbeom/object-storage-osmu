param(
    [string] $OutputDirectory = ".\.osmu-run\kubernetes-operations-report-sync-live-self-test"
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
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
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

$scriptPath = Resolve-ProjectPath ".\scripts\verify-kubernetes-operations-report-sync-live.ps1"
$syncEvidencePath = Join-Path $resolvedOutputDirectory "latest-kubernetes-operations-report-sync.json"
$dataFlowStoragePlanPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-plan.json"
$dataFlowQueryRetentionBudgetPath = Join-Path $resolvedOutputDirectory "latest-data-flow-query-retention-budget-evidence.json"
$dataFlowStorageTransitionRunbookPath = Join-Path $resolvedOutputDirectory "latest-data-flow-storage-transition-runbook-evidence.json"
$dashboardFixturePath = Join-Path $resolvedOutputDirectory "dashboard-readiness.json"
$evidencePath = Join-Path $resolvedOutputDirectory "live-evidence.json"
$planEvidencePath = Join-Path $resolvedOutputDirectory "plan-evidence.json"
$failedDashboardFixturePath = Join-Path $resolvedOutputDirectory "dashboard-readiness-failed.json"
$failedEvidencePath = Join-Path $resolvedOutputDirectory "live-evidence-failed.json"

Write-JsonFixture $syncEvidencePath ([ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    generatedAt = "2026-06-16T00:00:00+09:00"
    result = "applied"
    namespace = "osmu"
    configMapName = "osmu-operations-reports"
    configMapKey = "latest-operations-readiness-convergence.json"
    sourceReportPath = ".osmu-run/latest-operations-readiness-convergence.json"
    sourceReportResult = "ready"
    failedCount = 0
    checkCount = 3
    checks = @(
        [ordered]@{
            name = "apply-configmap"
            passed = $true
            summary = "fixture"
            command = "kubectl apply -f manifest.yaml"
            exitCode = 0
        }
    )
})

Write-JsonFixture $dataFlowStoragePlanPath ([ordered]@{
    formatVersion = "osmu.data-flow-storage-plan.v1"
    result = "plan-ready-execute-required"
    recordedAt = "2026-06-16T00:05:00+09:00"
    environmentName = "sync-live-self-test"
    targetCluster = "customer-cluster-a"
    operator = "ops-admin"
    evidenceRef = "data-flow-sizing-run-20260621"
    candidateStore = "MARIADB_PARTITION"
    expectedPeakEventsPerDay = 250000
    expectedQueryWindowDays = 180
    targetP95QueryLatencyMs = 500
    eventRetentionDays = 90
    dailyRollupRetentionDays = 730
    monthlyRollupRetentionMonths = 36
    checkCount = 3
    passedCount = 1
    pendingCount = 2
    checks = @(
        [ordered]@{
            id = "aggregate_no_object_keys"
            title = "Aggregate stores omit object keys"
            status = "passed"
            detail = "Fixture passed check."
            nextAction = ""
        },
        [ordered]@{
            id = "explain_or_store_evidence"
            title = "Query plan or target-store evidence exists"
            status = "pending"
            detail = "Fixture pending check."
            nextAction = "Attach target evidence."
        },
        [ordered]@{
            id = "mariadb_query_plan_evidence"
            title = "MariaDB query plan evidence passed"
            status = "pending"
            detail = "No MariaDB query plan evidence JSON supplied."
            nextAction = "Run scripts/write-mariadb-query-plan-evidence.ps1 with -Execute or -ExplainInputDir until result=passed, then rerun this storage plan."
        }
    )
    queryPlanEvidence = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
        validFormatVersion = $false
        result = ""
        mode = ""
        checkCount = 0
        passedCount = 0
        failedCount = 0
        failedChecks = @()
        detail = "No MariaDB query plan evidence JSON supplied."
    }
    scopePolicy = "OSMU operations analytics only. This plan is not AWS billing parity."
})

Write-JsonFixture $dataFlowQueryRetentionBudgetPath ([ordered]@{
    formatVersion = "osmu.data-flow-query-retention-budget-evidence.v1"
    generatedAt = "2026-06-16T00:07:00+09:00"
    result = "passed"
    environmentName = "sync-live-self-test"
    targetCluster = "customer-cluster-a"
    operator = "ops-admin"
    evidenceRef = "data-flow-query-retention-budget-20260621"
    dataFlowStoragePlanSnapshot = [ordered]@{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        targetP95QueryLatencyMs = 500
        expectedQueryWindowDays = 180
    }
    queryLatencyBudget = [ordered]@{
        evidenceRef = "query-latency-run-20260621"
        targetP95QueryLatencyMs = 500
        observedP95QueryLatencyMs = 320
        observedP99QueryLatencyMs = 440
        querySampleCount = 120
        observedQueryWindowDays = 180
        withinBudget = $true
    }
    retentionBudget = [ordered]@{
        evidenceRef = "retention-budget-run-20260621"
        budgetSeconds = 30
        detailedRetentionObservedSeconds = 12
        dailyRollupRetentionObservedSeconds = 7
        monthlyRollupRetentionObservedSeconds = 5
        detailedRetentionDeletedRows = 1500
        dailyRollupRetentionDeletedRows = 700
        monthlyRollupRetentionDeletedRows = 90
        withinBudget = $true
    }
    confirmations = [ordered]@{
        queryLatencyReviewed = $true
        retentionJobsWithinBudget = $true
        noObjectKeysInEvidence = $true
        noRawSqlOrExplain = $true
        noSecretValues = $true
    }
    summary = [ordered]@{
        failureCount = 0
        checkCount = 14
    }
    checks = @()
    scopePolicy = "OSMU operations analytics query/retention budget only."
})
Write-JsonFixture $dataFlowStorageTransitionRunbookPath ([ordered]@{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    generatedAt = "2026-06-16T00:06:00+09:00"
    result = "passed"
    environmentName = "sync-live-self-test"
    targetCluster = "customer-cluster-a"
    operator = "ops-admin"
    evidenceRef = "data-flow-runbook-20260621"
    dataFlowStoragePlanSnapshot = [ordered]@{
        result = "passed"
        candidateStore = "MARIADB_PARTITION"
        targetP95QueryLatencyMs = 500
    }
    summary = [ordered]@{
        failureCount = 0
        checkCount = 8
    }
    confirmations = [ordered]@{
        backfillRehearsed = $true
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
    topFailedChecks = @()
    scopePolicy = "OSMU operations analytics transition runbook only."
})

Write-JsonFixture $dashboardFixturePath ([ordered]@{
    data = [ordered]@{
        items = @(
            [ordered]@{
                code = "DATA_FLOW_STORAGE_PLAN"
                category = "OPERATIONS"
                severity = "WARN"
                message = "Data-flow storage plan still needs target evidence."
                evidencePath = ".osmu-run/latest-data-flow-storage-plan.json"
            }
        )
        operationsReadinessConvergence = [ordered]@{
            result = "ready"
            kubernetesReportSyncReady = $true
            kubernetesReportSyncResult = "applied"
            kubernetesReportSyncFailedCount = 0
            kubernetesReportSyncConfigMapName = "osmu-operations-reports"
            kubernetesReportSyncConfigMapKey = "latest-operations-readiness-convergence.json"
        }
        kubernetesOperationsReportSync = [ordered]@{
            result = "applied"
            namespace = "osmu"
            configMapName = "osmu-operations-reports"
            configMapKey = "latest-operations-readiness-convergence.json"
            sourceReportResult = "ready"
            failedCount = 0
            checkCount = 3
            checks = @()
        }
        dataFlowStoragePlan = [ordered]@{
            result = "plan-ready-execute-required"
            recordedAt = "2026-06-16T00:05:00+09:00"
            environmentName = "sync-live-self-test"
            targetCluster = "customer-cluster-a"
            operatorName = "ops-admin"
            evidenceRef = "data-flow-sizing-run-20260621"
            candidateStore = "MARIADB_PARTITION"
            expectedPeakEventsPerDay = 250000
            expectedQueryWindowDays = 180
            targetP95QueryLatencyMs = 500
            eventRetentionDays = 90
            dailyRollupRetentionDays = 730
            monthlyRollupRetentionMonths = 36
            checkCount = 3
            passedCount = 1
            pendingCount = 2
            checks = @(
                [ordered]@{
                    id = "aggregate_no_object_keys"
                    title = "Aggregate stores omit object keys"
                    status = "passed"
                    detail = "Fixture passed check."
                    nextAction = ""
                },
                [ordered]@{
                    id = "explain_or_store_evidence"
                    title = "Query plan or target-store evidence exists"
                    status = "pending"
                    detail = "Fixture pending check."
                    nextAction = "Attach target evidence."
                },
                [ordered]@{
                    id = "mariadb_query_plan_evidence"
                    title = "MariaDB query plan evidence passed"
                    status = "pending"
                    detail = "No MariaDB query plan evidence JSON supplied."
                    nextAction = "Run scripts/write-mariadb-query-plan-evidence.ps1 with -Execute or -ExplainInputDir until result=passed, then rerun this storage plan."
                }
            )
            queryPlanEvidence = [ordered]@{
                provided = $false
                path = ""
                parsed = $false
                formatVersion = ""
                expectedFormatVersion = "osmu.mariadb-query-plan-evidence.v1"
                validFormatVersion = $false
                result = ""
                mode = ""
                checkCount = 0
                passedCount = 0
                failedCount = 0
                failedChecks = @()
                detail = "No MariaDB query plan evidence JSON supplied."
            }
            scopePolicy = "OSMU operations analytics only. This plan is not AWS billing parity."
        }
        dataFlowQueryRetentionBudget = [ordered]@{
            result = "passed"
            environmentName = "sync-live-self-test"
            targetCluster = "customer-cluster-a"
            operatorName = "ops-admin"
            evidenceRef = "data-flow-query-retention-budget-20260621"
            storagePlanResult = "passed"
            candidateStore = "MARIADB_PARTITION"
            targetP95QueryLatencyMs = 500
            observedP95QueryLatencyMs = 320
            observedP99QueryLatencyMs = 440
            querySampleCount = 120
            observedQueryWindowDays = 180
            retentionBudgetSeconds = 30
            detailedRetentionObservedSeconds = 12
            dailyRollupRetentionObservedSeconds = 7
            monthlyRollupRetentionObservedSeconds = 5
            detailedRetentionDeletedRows = 1500
            dailyRollupRetentionDeletedRows = 700
            monthlyRollupRetentionDeletedRows = 90
            queryLatencyWithinBudget = $true
            retentionJobsWithinBudget = $true
            failureCount = 0
            checkCount = 14
            confirmations = [ordered]@{
                queryLatencyReviewed = $true
                retentionJobsWithinBudget = $true
                noObjectKeysInEvidence = $true
                noRawSqlOrExplain = $true
                noSecretValues = $true
            }
            topFailedChecks = @()
            scopePolicy = "OSMU operations analytics query/retention budget only."
        }
        dataFlowStorageTransitionRunbook = [ordered]@{
            result = "passed"
            environmentName = "sync-live-self-test"
            targetCluster = "customer-cluster-a"
            operatorName = "ops-admin"
            evidenceRef = "data-flow-runbook-20260621"
            storagePlanResult = "passed"
            candidateStore = "MARIADB_PARTITION"
            targetP95QueryLatencyMs = 500
            failureCount = 0
            checkCount = 8
            confirmations = [ordered]@{
                backfillRehearsed = $true
                dualWriteOrPartitionToggleReviewed = $true
                rollbackRehearsed = $true
                reconciliationPassed = $true
                dashboardCutoverReviewed = $true
                retentionDryRunReviewed = $true
                noObjectKeysInAggregates = $true
                noSecretValues = $true
            }
            topFailedChecks = @()
            scopePolicy = "OSMU operations analytics transition runbook only."
        }
    }
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -SkipSync `
    -SyncEvidencePath $syncEvidencePath `
    -DataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -DataFlowQueryRetentionBudgetPath $dataFlowQueryRetentionBudgetPath `
    -DataFlowStorageTransitionRunbookPath $dataFlowStorageTransitionRunbookPath `
    -DashboardReadinessFixturePath $dashboardFixturePath `
    -DashboardRetryCount 3 `
    -DashboardRetryDelaySeconds 0 `
    -EvidencePath $evidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "verify-kubernetes-operations-report-sync-live.ps1 fixture pass check failed with exit code $LASTEXITCODE."
}

$evidence = Read-Utf8Text $evidencePath | ConvertFrom-Json
Assert-Equal $evidence.formatVersion "osmu.kubernetes-operations-report-sync-live.v1" "live evidence formatVersion"
Assert-Equal $evidence.result "passed" "live evidence result"
Assert-Equal $evidence.syncResult "applied" "live evidence sync result"
Assert-Equal $evidence.dashboardChecked $true "live evidence dashboard checked"
Assert-Equal $evidence.dashboardRetryCount 3 "live evidence dashboard retry count"
Assert-Equal $evidence.dashboardRetryDelaySeconds 0 "live evidence dashboard retry delay"
Assert-Equal $evidence.dashboardAttemptCount 1 "live evidence dashboard attempt count"
Assert-Equal $evidence.dashboardMatchedExpected $true "live evidence dashboard matched expected"
Assert-Equal $evidence.dashboardSyncReady $true "live evidence dashboard sync ready"
Assert-Equal $evidence.dashboardSyncResult "applied" "live evidence dashboard sync result"
Assert-Equal $evidence.dataFlowStoragePlanExpected $true "live evidence data-flow storage plan expected"
Assert-Equal $evidence.dataFlowStoragePlanExpectedResult "plan-ready-execute-required" "live evidence expected data-flow storage plan result"
Assert-Equal $evidence.dataFlowStoragePlanExpectedCandidateStore "MARIADB_PARTITION" "live evidence expected data-flow storage plan candidate store"
Assert-Equal $evidence.dataFlowStoragePlanExpectedPendingCount 2 "live evidence expected data-flow storage plan pending count"
Assert-Equal $evidence.dataFlowQueryPlanEvidenceExpected $true "live evidence query plan expected"
Assert-Equal $evidence.dataFlowQueryPlanEvidenceExpectedProvided $false "live evidence query plan expected provided"
Assert-Equal $evidence.dataFlowQueryPlanEvidenceExpectedResult "" "live evidence query plan expected result"
Assert-Equal $evidence.dataFlowQueryPlanEvidenceExpectedFailedCount 0 "live evidence query plan expected failed count"
Assert-Equal $evidence.dashboardDataFlowStoragePlanChecked $true "live evidence dashboard data-flow storage plan checked"
Assert-Equal $evidence.dashboardDataFlowStoragePlanResult "plan-ready-execute-required" "live evidence dashboard data-flow storage plan result"
Assert-Equal $evidence.dashboardDataFlowStoragePlanCandidateStore "MARIADB_PARTITION" "live evidence dashboard data-flow storage plan candidate store"
Assert-Equal $evidence.dashboardDataFlowStoragePlanPendingCount 2 "live evidence dashboard data-flow storage plan pending count"
Assert-Equal $evidence.dashboardDataFlowQueryPlanEvidenceProvided $false "live evidence dashboard query plan provided"
Assert-Equal $evidence.dashboardDataFlowQueryPlanEvidenceResult "" "live evidence dashboard query plan result"
Assert-Equal $evidence.dashboardDataFlowQueryPlanEvidenceFailedCount 0 "live evidence dashboard query plan failed count"
Assert-Equal $evidence.dashboardDataFlowStoragePlanItemPresent $true "live evidence dashboard data-flow storage plan item"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetExpected $true "live evidence data-flow query/retention budget expected"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetExpectedResult "passed" "live evidence expected data-flow query/retention budget result"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetExpectedStoragePlanResult "passed" "live evidence expected data-flow query/retention budget storage plan result"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetExpectedCandidateStore "MARIADB_PARTITION" "live evidence expected data-flow query/retention budget candidate store"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetExpectedTargetP95QueryLatencyMs 500 "live evidence expected data-flow query/retention budget target p95"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetExpectedObservedP95QueryLatencyMs 320 "live evidence expected data-flow query/retention budget observed p95"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetExpectedRetentionBudgetSeconds 30 "live evidence expected data-flow query/retention budget retention seconds"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetExpectedFailureCount 0 "live evidence expected data-flow query/retention budget failure count"
Assert-Equal $evidence.dataFlowQueryRetentionBudgetExpectedCheckCount 14 "live evidence expected data-flow query/retention budget check count"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetChecked $true "live evidence dashboard data-flow query/retention budget checked"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetResult "passed" "live evidence dashboard data-flow query/retention budget result"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetStoragePlanResult "passed" "live evidence dashboard data-flow query/retention budget storage plan result"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetCandidateStore "MARIADB_PARTITION" "live evidence dashboard data-flow query/retention budget candidate store"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetTargetP95QueryLatencyMs 500 "live evidence dashboard data-flow query/retention budget target p95"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetObservedP95QueryLatencyMs 320 "live evidence dashboard data-flow query/retention budget observed p95"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetRetentionBudgetSeconds 30 "live evidence dashboard data-flow query/retention budget retention seconds"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetFailureCount 0 "live evidence dashboard data-flow query/retention budget failure count"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetCheckCount 14 "live evidence dashboard data-flow query/retention budget check count"
Assert-Equal $evidence.dashboardDataFlowQueryRetentionBudgetItemPresent $false "live evidence dashboard data-flow query/retention budget item"
Assert-Equal $evidence.dataFlowStorageTransitionRunbookExpected $true "live evidence data-flow storage transition runbook expected"
Assert-Equal $evidence.dataFlowStorageTransitionRunbookExpectedResult "passed" "live evidence expected data-flow storage transition runbook result"
Assert-Equal $evidence.dataFlowStorageTransitionRunbookExpectedStoragePlanResult "passed" "live evidence expected data-flow storage transition runbook storage plan result"
Assert-Equal $evidence.dataFlowStorageTransitionRunbookExpectedCandidateStore "MARIADB_PARTITION" "live evidence expected data-flow storage transition runbook candidate store"
Assert-Equal $evidence.dataFlowStorageTransitionRunbookExpectedFailureCount 0 "live evidence expected data-flow storage transition runbook failure count"
Assert-Equal $evidence.dataFlowStorageTransitionRunbookExpectedCheckCount 8 "live evidence expected data-flow storage transition runbook check count"
Assert-Equal $evidence.dashboardDataFlowStorageTransitionRunbookChecked $true "live evidence dashboard data-flow storage transition runbook checked"
Assert-Equal $evidence.dashboardDataFlowStorageTransitionRunbookResult "passed" "live evidence dashboard data-flow storage transition runbook result"
Assert-Equal $evidence.dashboardDataFlowStorageTransitionRunbookStoragePlanResult "passed" "live evidence dashboard data-flow storage transition runbook storage plan result"
Assert-Equal $evidence.dashboardDataFlowStorageTransitionRunbookCandidateStore "MARIADB_PARTITION" "live evidence dashboard data-flow storage transition runbook candidate store"
Assert-Equal $evidence.dashboardDataFlowStorageTransitionRunbookFailureCount 0 "live evidence dashboard data-flow storage transition runbook failure count"
Assert-Equal $evidence.dashboardDataFlowStorageTransitionRunbookCheckCount 8 "live evidence dashboard data-flow storage transition runbook check count"
Assert-Equal $evidence.dashboardDataFlowStorageTransitionRunbookItemPresent $false "live evidence dashboard data-flow storage transition runbook item"
Assert-Equal $evidence.failedCount 0 "live evidence failed count"
Assert-True ($evidence.safetyPolicy.Contains("does not store admin passwords")) "live evidence safety policy"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanOnly `
    -DataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -DataFlowQueryRetentionBudgetPath $dataFlowQueryRetentionBudgetPath `
    -DataFlowStorageTransitionRunbookPath $dataFlowStorageTransitionRunbookPath `
    -DashboardReadinessFixturePath $dashboardFixturePath `
    -DashboardRetryCount 2 `
    -DashboardRetryDelaySeconds 0 `
    -EvidencePath $planEvidencePath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "verify-kubernetes-operations-report-sync-live.ps1 plan check failed with exit code $LASTEXITCODE."
}
$planEvidence = Read-Utf8Text $planEvidencePath | ConvertFrom-Json
Assert-Equal $planEvidence.result "planned" "plan evidence result"
Assert-Equal $planEvidence.failedCount 0 "plan evidence failed count"
Assert-Equal $planEvidence.dashboardRetryCount 2 "plan evidence dashboard retry count"
Assert-Equal $planEvidence.dataFlowStoragePlanExpected $true "plan evidence data-flow storage plan expected"
Assert-Equal $planEvidence.dataFlowStoragePlanExpectedResult "plan-ready-execute-required" "plan evidence expected data-flow storage plan result"
Assert-Equal $planEvidence.dataFlowQueryPlanEvidenceExpected $true "plan evidence query plan expected"
Assert-Equal $planEvidence.dataFlowQueryRetentionBudgetExpected $true "plan evidence data-flow query/retention budget expected"
Assert-Equal $planEvidence.dataFlowQueryRetentionBudgetExpectedResult "passed" "plan evidence expected data-flow query/retention budget result"
Assert-Equal $planEvidence.dashboardDataFlowQueryRetentionBudgetChecked $false "plan evidence dashboard data-flow query/retention budget checked"
Assert-Equal $planEvidence.dashboardDataFlowStoragePlanChecked $false "plan evidence dashboard data-flow storage plan checked"
Assert-Equal $planEvidence.dataFlowStorageTransitionRunbookExpected $true "plan evidence data-flow storage transition runbook expected"
Assert-Equal $planEvidence.dataFlowStorageTransitionRunbookExpectedResult "passed" "plan evidence expected data-flow storage transition runbook result"
Assert-Equal $planEvidence.dashboardDataFlowStorageTransitionRunbookChecked $false "plan evidence dashboard data-flow storage transition runbook checked"

Write-JsonFixture $failedDashboardFixturePath ([ordered]@{
    data = [ordered]@{
        operationsReadinessConvergence = [ordered]@{
            result = "action-required"
            kubernetesReportSyncReady = $false
            kubernetesReportSyncResult = "planned"
        }
        kubernetesOperationsReportSync = [ordered]@{
            result = "planned"
            namespace = "osmu"
            configMapName = "osmu-operations-reports"
            configMapKey = "latest-operations-readiness-convergence.json"
            failedCount = 0
        }
    }
})

$failedOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -SkipSync `
    -SyncEvidencePath $syncEvidencePath `
    -DataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -DataFlowQueryRetentionBudgetPath $dataFlowQueryRetentionBudgetPath `
    -DataFlowStorageTransitionRunbookPath $dataFlowStorageTransitionRunbookPath `
    -DashboardReadinessFixturePath $failedDashboardFixturePath `
    -DashboardRetryCount 2 `
    -DashboardRetryDelaySeconds 0 `
    -EvidencePath $failedEvidencePath 2>&1
$failedExitCode = $LASTEXITCODE
$failedOutput = ($failedOutputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
if ($failedExitCode -eq 0) {
    throw "verify-kubernetes-operations-report-sync-live.ps1 must fail when dashboard sync evidence is not applied."
}
Assert-Contains $failedOutput "Result: failed" "failed dashboard output"
$failedEvidence = Read-Utf8Text $failedEvidencePath | ConvertFrom-Json
Assert-Equal $failedEvidence.result "failed" "failed evidence result"
Assert-True ($failedEvidence.failedCount -gt 0) "failed evidence failed count"
Assert-Equal $failedEvidence.dashboardMatchedExpected $false "failed evidence dashboard matched expected"

Write-Host "Kubernetes operations report sync live verifier self-test passed."
Write-Host "Live evidence: $evidencePath"
exit 0
