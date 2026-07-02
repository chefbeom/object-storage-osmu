param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $StorageExpansionFinalizeReportPath = ".\.osmu-run\latest-storage-expansion-finalize.json",
    [string] $KubernetesHaDrReadinessReportPath = ".\.osmu-run\latest-kubernetes-ha-dr-readiness.json",
    [string] $KubernetesDrFinalizeReportPath = ".\.osmu-run\latest-kubernetes-dr-finalize.json",
    [string] $IamRbacFinalizeReportPath = ".\.osmu-run\latest-iam-rbac-finalize.json",
    [string] $SecurityEvidenceFinalizeReportPath = ".\.osmu-run\latest-security-evidence-finalize.json",
    [string] $ImageSigningEvidencePath = ".\.osmu-run\latest-image-signing-evidence.json",
    [string] $ContainerSecurityEvidencePath = ".\.osmu-run\latest-container-security-evidence.json",
    [string] $StorageBackendTelemetryEvidencePath = ".\.osmu-run\latest-storage-backend-telemetry.json",
    [string] $MonitoringThresholdEvidencePath = ".\.osmu-run\latest-monitoring-threshold-evidence.json",
    [string] $SecretRotationEvidencePath = ".\.osmu-run\latest-secret-rotation-evidence.json",
    [string] $CommercialIntegrationEvidencePath = ".\.osmu-run\latest-commercial-integration-evidence.json",
    [string] $CommercialApprovalEvidencePath = ".\.osmu-run\latest-commercial-approval-evidence.json",
    [string] $ChargebackCloseoutEvidencePath = ".\.osmu-run\latest-chargeback-closeout-evidence.json",
    [string] $EnterpriseAuthSmokeEvidencePath = ".\.osmu-run\latest-enterprise-auth-smoke.json",
    [string] $EnterpriseAuthJitRollbackEvidencePath = ".\.osmu-run\latest-enterprise-auth-jit-rollback-evidence.json",
    [string] $OperationsHandoffPackagePath = ".\.osmu-run\latest-operations-handoff-package.json",
    [string] $ClusterNetworkAccessReviewEvidencePath = ".\.osmu-run\latest-cluster-network-access-review-evidence.json",
    [string] $HelmValuesHardeningEvidencePath = ".\.osmu-run\latest-helm-values-hardening-evidence.json",
    [string] $DataFlowStoragePlanPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $DataFlowQueryRetentionBudgetEvidencePath = ".\.osmu-run\latest-data-flow-query-retention-budget-evidence.json",
    [string] $DataFlowStorageTransitionRunbookEvidencePath = ".\.osmu-run\latest-data-flow-storage-transition-runbook-evidence.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-readiness.md",
    [switch] $FailIfNotReady,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}
function Get-ObjectProperty($object, [string] $name) {
    if ($null -eq $object) {
        return $null
    }
    $property = $object.PSObject.Properties[$name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-ObjectInt($object, [string] $name) {
    $value = Get-ObjectProperty $object $name
    if ($null -eq $value) {
        return 0
    }
    $parsed = 0
    if ([int]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return 0
}

function Get-CheckField([object] $Check, [string] $Name) {
    if ($Check -is [System.Collections.IDictionary] -and $Check.Contains($Name)) {
        return $Check[$Name]
    }
    $property = $Check.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }
    return $null
}

function Get-PendingCategoryCounts([object[]] $Checks) {
    $counts = @{}
    foreach ($check in @($Checks)) {
        if ([bool] (Get-CheckField $check "passed")) {
            continue
        }
        $category = [string] (Get-CheckField $check "category")
        if ([string]::IsNullOrWhiteSpace($category)) {
            $category = "uncategorized"
        }
        if (-not $counts.ContainsKey($category)) {
            $counts[$category] = 0
        }
        $counts[$category]++
    }
    return @($counts.Keys |
        Sort-Object |
        ForEach-Object {
            [ordered]@{
                category = $_
                count = $counts[$_]
            }
        })
}

function Format-PendingCategorySummary([object[]] $CategoryCounts) {
    $summary = @($CategoryCounts | ForEach-Object { "$($_.category)=$($_.count)" }) -join ", "
    if ([string]::IsNullOrWhiteSpace($summary)) {
        return "none"
    }
    return $summary
}
function Get-TargetEvidenceFieldValues([object] $Report) {
    if (-not ($Report.exists -and $Report.parsed)) {
        return @()
    }
    $values = New-Object System.Collections.ArrayList
    foreach ($source in @((Get-ObjectProperty $Report.data "target"), $Report.data)) {
        if ($null -eq $source) { continue }
        foreach ($name in @("environmentName", "targetCluster", "cluster", "namespace", "sourceNamespace", "restoreNamespace", "operator", "reviewedBy", "approvedBy")) {
            $value = [string] (Get-ObjectProperty $source $name)
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                [void] $values.Add($value)
            }
        }
    }
    return @($values)
}

function Test-SelfTestTargetEvidence([object] $Report) {
    $selfTestPattern = "(?i)(^|[-_ .])(self[-_ .]?test|fixture|sample)([-_ .]|$)"
    foreach ($value in (Get-TargetEvidenceFieldValues $Report)) {
        if ($value -match $selfTestPattern) {
            return $true
        }
    }
    return $false
}

function Test-PassedTargetEvidence([object] $Report) {
    return $Report.exists -and $Report.parsed -and ([string] (Get-ObjectProperty $Report.data "result") -eq "passed") -and -not (Test-SelfTestTargetEvidence $Report)
}

function Add-TargetEvidenceGuardDetail([object] $Report, [string] $Detail) {
    if (Test-SelfTestTargetEvidence $Report) {
        $markers = (Get-TargetEvidenceFieldValues $Report) -join ","
        return "$Detail; rejected=self-test-target-evidence markers=$markers"
    }
    return $Detail
}
function Get-RequiredObjectInt($object, [string] $name) {
    $value = Get-ObjectProperty $object $name
    if ($null -eq $value) {
        return [pscustomobject]@{
            valid = $false
            value = $null
            raw = "<missing>"
        }
    }
    $integerTypeNames = @("Byte", "SByte", "Int16", "UInt16", "Int32", "UInt32", "Int64", "UInt64")
    if ($integerTypeNames -notcontains $value.GetType().Name) {
        return [pscustomobject]@{
            valid = $false
            value = $null
            raw = [string] $value
        }
    }
    try {
        return [pscustomobject]@{
            valid = $true
            value = [int64] $value
            raw = [string] $value
        }
    }
    catch {
        return [pscustomobject]@{
            valid = $false
            value = $null
            raw = [string] $value
        }
    }
}

function Get-RequiredObjectBool($object, [string] $name) {
    $value = Get-ObjectProperty $object $name
    if ($value -is [bool]) {
        return [pscustomobject]@{
            valid = $true
            value = [bool] $value
            raw = [string] $value
        }
    }
    return [pscustomobject]@{
        valid = $false
        value = $false
        raw = if ($null -eq $value) { "<missing>" } else { [string] $value }
    }
}

function Read-JsonReport([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            label = $label
            path = $resolvedPath
            exists = $false
            parsed = $false
            data = $null
            detail = "report not found"
        }
    }

    try {
        return [pscustomobject]@{
            label = $label
            path = $resolvedPath
            exists = $true
            parsed = $true
            data = (Read-Utf8Text $resolvedPath | ConvertFrom-Json)
            detail = "report parsed"
        }
    }
    catch {
        return [pscustomobject]@{
            label = $label
            path = $resolvedPath
            exists = $true
            parsed = $false
            data = $null
            detail = $_.Exception.Message
        }
    }
}

function Add-Check(
    [string] $Name,
    [string] $Category,
    [bool] $Passed,
    [string] $Detail,
    [string] $EvidencePath = "",
    [string] $RequiredEvidence = "",
    [object] $Remediation = $null
) {
    $check = [ordered]@{
        name = $Name
        category = $Category
        status = if ($Passed) { "PASS" } else { "PENDING" }
        passed = $Passed
        detail = $Detail
        evidencePath = $EvidencePath
        requiredEvidence = $RequiredEvidence
    }
    if ($null -ne $Remediation) {
        $check.remediation = $Remediation
    }
    $script:checks += $check
}

function New-Remediation([string] $Command, [string] $Workflow, [string] $WorkflowCommand, [string] $Note) {
    return [ordered]@{
        command = $Command
        workflow = $Workflow
        workflowCommand = $WorkflowCommand
        note = $Note
    }
}

function Get-ScopeValue([object] $ReleaseReport, [string] $Name) {
    $scope = Get-ObjectProperty $ReleaseReport.data "scope"
    $value = Get-ObjectProperty $scope $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Add-ScopeCheck([object] $ReleaseReport, [string] $ScopeName, [string] $Label, [string] $Category, [object] $Remediation = $null) {
    $value = Get-ScopeValue $ReleaseReport $ScopeName
    Add-Check $Label $Category ($value -eq "included") "scope.$ScopeName=$value" $ReleaseReport.path "latest release report with scope.$ScopeName=included" $Remediation
}

function Test-FileExists([string] $path) {
    return Test-Path -LiteralPath (Resolve-ProjectPath $path)
}

function Add-FileCheck([string] $Name, [string] $Category, [string] $Path, [string] $RequiredEvidence) {
    $resolvedPath = Resolve-ProjectPath $Path
    Add-Check $Name $Category (Test-Path -LiteralPath $resolvedPath) "path=$resolvedPath" $resolvedPath $RequiredEvidence
}

function Get-StorageExpansionDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $backend = Get-ObjectProperty $Report.data "backend"
    return "result=$($Report.data.result), namespace=$($Report.data.namespace), tenant=$($Report.data.tenantName), runDryRunRunner=$($backend.runDryRunRunner), runApply=$($backend.runApply)"
}

function Get-HaDrReadinessDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    return "result=$($Report.data.result), namespace=$($Report.data.namespace), failureCount=$($Report.data.failureCount)"
}

function Get-KubernetesDrFinalizeDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    return "result=$($Report.data.result), status=$($Report.data.status), sourceNamespace=$($Report.data.sourceNamespace), restoreNamespace=$($Report.data.restoreNamespace), backupTimestamp=$($Report.data.backupTimestamp), serverDryRunOnly=$($Report.data.serverDryRunOnly), confirmRestore=$($Report.data.confirmRestore), submitEvidence=$($Report.data.submitEvidence)"
}

function Get-GenericResultDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $result = Get-ObjectProperty $Report.data "result"
    if (-not $result) {
        $result = Get-ObjectProperty $Report.data "status"
    }
    return "result=$result"
}


function Get-FirstNonPassCheckSummary([object] $Data) {
    $checks = @(Get-ObjectProperty $Data "checks")
    foreach ($check in $checks) {
        $status = [string] (Get-ObjectProperty $check "status")
        $passed = Get-ObjectProperty $check "passed"
        if ($status -ne "PASS" -or ($passed -is [bool] -and -not $passed)) {
            $id = [string] (Get-ObjectProperty $check "id")
            if ([string]::IsNullOrWhiteSpace($id)) { $id = [string] (Get-ObjectProperty $check "name") }
            $detail = [string] (Get-ObjectProperty $check "detail")
            if ([string]::IsNullOrWhiteSpace($detail)) { $detail = "no detail" }
            return "$id/$status $detail"
        }
    }
    return "none"
}

function Get-ChargebackCloseoutDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $data = $Report.data
    $summary = Get-ObjectProperty $data "summary"
    $target = Get-ObjectProperty $data "target"
    $closeoutSnapshot = Get-ObjectProperty $data "chargebackCloseoutSnapshot"
    $closeoutCounts = Get-ObjectProperty $closeoutSnapshot "counts"
    $paymentSnapshotValid = Get-ObjectProperty $summary "paymentProviderAdapterReadinessSnapshotValid"
    $paymentReviewed = Get-ObjectProperty $summary "paymentProviderAdapterReadinessReviewed"
    $closeoutSnapshotValid = Get-ObjectProperty $summary "chargebackCloseoutSnapshotValid"
    $commercialReviewed = Get-ObjectProperty $summary "commercialEvidenceReviewed"
    $failureCount = Get-ObjectInt $summary "failureCount"
    $plannedCount = Get-ObjectInt $summary "plannedCount"
    $providedRefs = Get-ObjectInt $summary "providedEvidenceRefCount"
    $requiredRefs = Get-ObjectInt $summary "requiredEvidenceRefCount"
    $reconciliationDiff = Get-ObjectInt $closeoutCounts "reconciliationDifferenceMinorUnits"
    $firstIssue = Get-FirstNonPassCheckSummary $data
    return "result=$($data.result), billingPeriod=$($target.billingPeriod), window=$($target.closeoutStartedAt)->$($target.closeoutCompletedAt), failures=$failureCount, planned=$plannedCount, refs=$providedRefs/$requiredRefs, reconciliationDifferenceMinorUnits=$reconciliationDiff, closeoutSnapshotValid=$closeoutSnapshotValid, paymentProviderAdapterReadinessSnapshotValid=$paymentSnapshotValid, paymentProviderAdapterReadinessReviewed=$paymentReviewed, commercialEvidenceReviewed=$commercialReviewed, firstIssue=$firstIssue"
}
function Get-StorageBackendTelemetryDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $summary = Get-ObjectProperty $Report.data "summary"
    return "result=$($Report.data.result), poolCount=$($summary.poolCount), serverCount=$($summary.serverCount), offlineServerCount=$($summary.offlineServerCount), driveCount=$($summary.driveCount), totalBytes=$($summary.totalBytes), usedBytes=$($summary.usedBytes), freeBytes=$($summary.freeBytes)"
}

function Test-SanitizedQueryPlanEvidenceSummary([object] $QueryPlanEvidence) {
    if ($null -eq $QueryPlanEvidence) {
        return $true
    }
    $summaryText = $QueryPlanEvidence | ConvertTo-Json -Depth 20 -Compress
    $forbiddenPropertyPattern = '(?i)"(sql|rawSql|raw_sql|explain|explainJson|explain_json|rawExplain|raw_explain|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:'
    $credentialPattern = '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key)\s*=\s*\S+'
    $rawSqlPattern = '(?i)\bSELECT\b[\s\S]{0,200}\bFROM\b'
    return -not ($summaryText -match $forbiddenPropertyPattern -or $summaryText -match $credentialPattern -or $summaryText -match $rawSqlPattern)
}

function Test-DataFlowStoragePlanEvidenceAccepted([object] $Report) {
    if (-not ($Report.exists -and $Report.parsed)) {
        return $false
    }
    if (Test-SelfTestTargetEvidence $Report) {
        return $false
    }
    if ([string] (Get-ObjectProperty $Report.data "formatVersion") -ne "osmu.data-flow-storage-plan.v1") {
        return $false
    }
    if ([string] (Get-ObjectProperty $Report.data "result") -ne "passed") {
        return $false
    }
    $candidateStore = [string] (Get-ObjectProperty $Report.data "candidateStore")
    if ($candidateStore -notin @("MARIADB_PARTITION", "EXTERNAL_TIME_SERIES", "DUAL_WRITE")) {
        return $false
    }
    $queryPlanEvidence = Get-ObjectProperty $Report.data "queryPlanEvidence"
    if (-not (Test-SanitizedQueryPlanEvidenceSummary $queryPlanEvidence)) {
        return $false
    }
    if (@("MARIADB_PARTITION", "DUAL_WRITE") -contains $candidateStore) {
        if ($null -eq $queryPlanEvidence) {
            return $false
        }
        if ([string] (Get-ObjectProperty $queryPlanEvidence "expectedFormatVersion") -ne "osmu.mariadb-query-plan-evidence.v1") {
            return $false
        }
        if ([string] (Get-ObjectProperty $queryPlanEvidence "result") -ne "passed") {
            return $false
        }
        if ((Get-ObjectInt $queryPlanEvidence "failedCount") -ne 0) {
            return $false
        }
    }
    return $true
}

function Get-DataFlowStoragePlanDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $queryPlanEvidence = Get-ObjectProperty $Report.data "queryPlanEvidence"
    $queryPlanDetail = "queryPlanEvidence=absent"
    if ($null -ne $queryPlanEvidence) {
        $sanitized = Test-SanitizedQueryPlanEvidenceSummary $queryPlanEvidence
        $queryPlanDetail = "queryPlanEvidence.result=$([string] (Get-ObjectProperty $queryPlanEvidence "result")), queryPlanEvidence.failedCount=$(Get-ObjectInt $queryPlanEvidence "failedCount"), sanitized=$sanitized"
    }
    return "result=$($Report.data.result), candidateStore=$($Report.data.candidateStore), pendingCount=$($Report.data.pendingCount), $queryPlanDetail"
}

function Test-DataFlowQueryRetentionBudgetEvidenceAccepted([object] $Report) {
    if (-not ($Report.exists -and $Report.parsed)) { return $false }
    if (Test-SelfTestTargetEvidence $Report) { return $false }
    if ([string] (Get-ObjectProperty $Report.data "formatVersion") -ne "osmu.data-flow-query-retention-budget-evidence.v1") { return $false }
    if ([string] (Get-ObjectProperty $Report.data "result") -ne "passed") { return $false }
    $planSnapshot = Get-ObjectProperty $Report.data "dataFlowStoragePlanSnapshot"
    if ([string] (Get-ObjectProperty $planSnapshot "result") -ne "passed") { return $false }
    if ((Get-ObjectInt $planSnapshot "pendingCount") -ne 0) { return $false }
    $queryLatencyBudget = Get-ObjectProperty $Report.data "queryLatencyBudget"
    $retentionBudget = Get-ObjectProperty $Report.data "retentionBudget"
    $summary = Get-ObjectProperty $Report.data "summary"
    $targetP95 = Get-RequiredObjectInt $queryLatencyBudget "targetP95QueryLatencyMs"
    $observedP95 = Get-RequiredObjectInt $queryLatencyBudget "observedP95QueryLatencyMs"
    $observedP99 = Get-RequiredObjectInt $queryLatencyBudget "observedP99QueryLatencyMs"
    $sampleCount = Get-RequiredObjectInt $queryLatencyBudget "querySampleCount"
    $windowDays = Get-RequiredObjectInt $queryLatencyBudget "observedQueryWindowDays"
    $queryWithin = Get-RequiredObjectBool $queryLatencyBudget "withinBudget"
    $budgetSeconds = Get-RequiredObjectInt $retentionBudget "budgetSeconds"
    $detailedSeconds = Get-RequiredObjectInt $retentionBudget "detailedRetentionObservedSeconds"
    $dailySeconds = Get-RequiredObjectInt $retentionBudget "dailyRollupRetentionObservedSeconds"
    $monthlySeconds = Get-RequiredObjectInt $retentionBudget "monthlyRollupRetentionObservedSeconds"
    $retentionWithin = Get-RequiredObjectBool $retentionBudget "withinBudget"
    $failureCount = Get-RequiredObjectInt $summary "failureCount"
    $checkCount = Get-RequiredObjectInt $summary "checkCount"
    $countsValid = $targetP95.valid -and $observedP95.valid -and $observedP99.valid -and $sampleCount.valid -and $windowDays.valid -and $budgetSeconds.valid -and $detailedSeconds.valid -and $dailySeconds.valid -and $monthlySeconds.valid -and $failureCount.valid -and $checkCount.valid
    if (-not $countsValid) { return $false }
    if (-not ($queryWithin.valid -and $queryWithin.value -and $retentionWithin.valid -and $retentionWithin.value)) { return $false }
    if ($targetP95.value -le 0 -or $observedP95.value -gt $targetP95.value -or $observedP99.value -lt $observedP95.value -or $sampleCount.value -le 0 -or $windowDays.value -le 0) { return $false }
    if ($budgetSeconds.value -le 0 -or $detailedSeconds.value -gt $budgetSeconds.value -or $dailySeconds.value -gt $budgetSeconds.value -or $monthlySeconds.value -gt $budgetSeconds.value) { return $false }
    if ($failureCount.value -ne 0 -or $checkCount.value -le 0) { return $false }
    $confirmations = Get-ObjectProperty $Report.data "confirmations"
    foreach ($confirmation in @("queryLatencyReviewed", "retentionJobsWithinBudget", "noObjectKeysInEvidence", "noRawSqlOrExplain", "noSecretValues")) {
        $value = Get-RequiredObjectBool $confirmations $confirmation
        if (-not ($value.valid -and $value.value)) { return $false }
    }
    return $true
}

function Get-DataFlowQueryRetentionBudgetDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) { return $Report.detail }
    $planSnapshot = Get-ObjectProperty $Report.data "dataFlowStoragePlanSnapshot"
    $queryLatencyBudget = Get-ObjectProperty $Report.data "queryLatencyBudget"
    $retentionBudget = Get-ObjectProperty $Report.data "retentionBudget"
    $summary = Get-ObjectProperty $Report.data "summary"
    return "result=$($Report.data.result), storagePlanResult=$($planSnapshot.result), p95=$(Get-ObjectInt $queryLatencyBudget "observedP95QueryLatencyMs")/$(Get-ObjectInt $queryLatencyBudget "targetP95QueryLatencyMs"), p99=$(Get-ObjectInt $queryLatencyBudget "observedP99QueryLatencyMs"), samples=$(Get-ObjectInt $queryLatencyBudget "querySampleCount"), retentionSeconds=$(Get-ObjectInt $retentionBudget "detailedRetentionObservedSeconds")/$(Get-ObjectInt $retentionBudget "dailyRollupRetentionObservedSeconds")/$(Get-ObjectInt $retentionBudget "monthlyRollupRetentionObservedSeconds"), retentionBudget=$(Get-ObjectInt $retentionBudget "budgetSeconds"), failureCount=$(Get-ObjectInt $summary "failureCount")"
}
function Test-DataFlowStorageTransitionRunbookEvidenceAccepted([object] $Report) {
    if (-not ($Report.exists -and $Report.parsed)) {
        return $false
    }
    if (Test-SelfTestTargetEvidence $Report) {
        return $false
    }
    if ([string] (Get-ObjectProperty $Report.data "formatVersion") -ne "osmu.data-flow-storage-transition-runbook-evidence.v1") {
        return $false
    }
    if ([string] (Get-ObjectProperty $Report.data "result") -ne "passed") {
        return $false
    }
    $planSnapshot = Get-ObjectProperty $Report.data "dataFlowStoragePlanSnapshot"
    if ([string] (Get-ObjectProperty $planSnapshot "result") -ne "passed") {
        return $false
    }
    if (-not (Test-SanitizedQueryPlanEvidenceSummary (Get-ObjectProperty $planSnapshot "queryPlanEvidence"))) {
        return $false
    }
    $summary = Get-ObjectProperty $Report.data "summary"
    if ((Get-ObjectInt $summary "failureCount") -ne 0) {
        return $false
    }
    $confirmations = Get-ObjectProperty $Report.data "confirmations"
    $requiredConfirmations = @(
        "backfillRehearsed",
        "dualWriteOrPartitionToggleReviewed",
        "rollbackRehearsed",
        "reconciliationPassed",
        "dashboardCutoverReviewed",
        "retentionDryRunReviewed",
        "noObjectKeysInAggregates",
        "noSecretValues"
    )
    foreach ($confirmation in $requiredConfirmations) {
        $value = Get-RequiredObjectBool $confirmations $confirmation
        if (-not ($value.valid -and $value.value)) {
            return $false
        }
    }
    return $true
}

function Get-DataFlowStorageTransitionRunbookDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $planSnapshot = Get-ObjectProperty $Report.data "dataFlowStoragePlanSnapshot"
    $summary = Get-ObjectProperty $Report.data "summary"
    $confirmations = Get-ObjectProperty $Report.data "confirmations"
    $confirmationNames = @(
        "backfillRehearsed",
        "dualWriteOrPartitionToggleReviewed",
        "rollbackRehearsed",
        "reconciliationPassed",
        "dashboardCutoverReviewed",
        "retentionDryRunReviewed",
        "noObjectKeysInAggregates",
        "noSecretValues"
    )
    $confirmedCount = 0
    foreach ($confirmationName in $confirmationNames) {
        $value = Get-RequiredObjectBool $confirmations $confirmationName
        if ($value.valid -and $value.value) {
            $confirmedCount += 1
        }
    }
    $failureCount = Get-ObjectInt $summary "failureCount"
    return "result=$($Report.data.result), storagePlanResult=$($planSnapshot.result), candidateStore=$($planSnapshot.candidateStore), failureCount=$failureCount, confirmed=$confirmedCount/$($confirmationNames.Count)"
}

function Test-EnterpriseAuthEvidenceAccepted([object] $Report) {
    if (-not ($Report.exists -and $Report.parsed)) {
        return $false
    }
    if (Test-SelfTestTargetEvidence $Report) {
        return $false
    }
    $result = [string] (Get-ObjectProperty $Report.data "result")
    if ($result -eq "passed") {
        $summary = Get-ObjectProperty $Report.data "summary"
        $passCount = Get-RequiredObjectInt $summary "passCount"
        $failCount = Get-RequiredObjectInt $summary "failCount"
        $blockedCount = Get-RequiredObjectInt $summary "blockedCount"
        $plannedCount = Get-RequiredObjectInt $summary "plannedCount"
        $skippedCount = Get-RequiredObjectInt $summary "skippedCount"
        return $passCount.valid -and $failCount.valid -and $blockedCount.valid -and $plannedCount.valid -and $skippedCount.valid `
            -and $passCount.value -gt 0 `
            -and $failCount.value -eq 0 `
            -and $blockedCount.value -eq 0 `
            -and $plannedCount.value -eq 0
    }
    if ($result -ne "scope-out") {
        return $false
    }
    $scopeOut = Get-ObjectProperty $Report.data "scopeOut"
    $accepted = Get-RequiredObjectBool $scopeOut "accepted"
    $reference = [string] (Get-ObjectProperty $scopeOut "reference")
    $reason = [string] (Get-ObjectProperty $scopeOut "reason")
    return $accepted.valid -and $accepted.value -and -not [string]::IsNullOrWhiteSpace($reference) -and -not [string]::IsNullOrWhiteSpace($reason)
}

function Get-EnterpriseAuthEvidenceDetail([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }
    $result = [string] (Get-ObjectProperty $Report.data "result")
    if ($result -eq "passed") {
        $summary = Get-ObjectProperty $Report.data "summary"
        $passCount = Get-RequiredObjectInt $summary "passCount"
        $failCount = Get-RequiredObjectInt $summary "failCount"
        $blockedCount = Get-RequiredObjectInt $summary "blockedCount"
        $plannedCount = Get-RequiredObjectInt $summary "plannedCount"
        $skippedCount = Get-RequiredObjectInt $summary "skippedCount"
        $countsValid = $passCount.valid -and $failCount.valid -and $blockedCount.valid -and $plannedCount.valid -and $skippedCount.valid
        return "result=passed, passCount=$($passCount.raw)(valid=$($passCount.valid)), failCount=$($failCount.raw)(valid=$($failCount.valid)), blockedCount=$($blockedCount.raw)(valid=$($blockedCount.valid)), plannedCount=$($plannedCount.raw)(valid=$($plannedCount.valid)), skippedCount=$($skippedCount.raw)(valid=$($skippedCount.valid)), countsValid=$countsValid"
    }
    if ($result -ne "scope-out") {
        return "result=$result"
    }
    $scopeOut = Get-ObjectProperty $Report.data "scopeOut"
    $accepted = Get-RequiredObjectBool $scopeOut "accepted"
    $reference = [string] (Get-ObjectProperty $scopeOut "reference")
    $reason = [string] (Get-ObjectProperty $scopeOut "reason")
    return "result=$result, scopeOut.accepted=$($accepted.raw)(valid=$($accepted.valid)), referencePresent=$(-not [string]::IsNullOrWhiteSpace($reference)), reasonPresent=$(-not [string]::IsNullOrWhiteSpace($reason))"
}

function Test-EnterpriseAuthJitRollbackEvidenceAccepted([object] $Report) {
    if (-not ($Report.exists -and $Report.parsed)) {
        return $false
    }
    if (Test-SelfTestTargetEvidence $Report) {
        return $false
    }

    $formatVersion = [string] (Get-ObjectProperty $Report.data "formatVersion")
    $result = [string] (Get-ObjectProperty $Report.data "result")
    $summary = Get-ObjectProperty $Report.data "summary"
    $failureCount = Get-RequiredObjectInt $summary "failureCount"
    $checkCount = Get-RequiredObjectInt $summary "checkCount"
    $confirmations = Get-ObjectProperty $Report.data "confirmations"
    foreach ($confirmationName in @("adminApprovalRequired", "callbackAutoJitDisabled", "jitUserDisableOrLockRollbackReviewed", "roleOrgTeamRollbackReviewed", "localPasswordFallbackValidated", "auditEventsReviewed", "noRawClaims", "noSecretValues")) {
        $confirmation = Get-RequiredObjectBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) {
            return $false
        }
    }

    $smoke = Get-ObjectProperty $Report.data "enterpriseAuthSmokeSnapshot"
    $smokeFormatVersion = [string] (Get-ObjectProperty $smoke "formatVersion")
    $smokeResult = [string] (Get-ObjectProperty $smoke "result")
    $smokeAccepted = $false
    if ($smokeFormatVersion -eq "osmu.enterprise-auth-smoke.v1" -and $smokeResult -eq "passed") {
        $passCount = Get-RequiredObjectInt $smoke "passCount"
        $failCount = Get-RequiredObjectInt $smoke "failCount"
        $blockedCount = Get-RequiredObjectInt $smoke "blockedCount"
        $plannedCount = Get-RequiredObjectInt $smoke "plannedCount"
        $smokeAccepted = $passCount.valid -and $failCount.valid -and $blockedCount.valid -and $plannedCount.valid `
            -and $passCount.value -gt 0 `
            -and $failCount.value -eq 0 `
            -and $blockedCount.value -eq 0 `
            -and $plannedCount.value -eq 0
    }
    elseif ($smokeFormatVersion -eq "osmu.enterprise-auth-smoke.v1" -and $smokeResult -eq "scope-out") {
        $scopeOutAccepted = Get-RequiredObjectBool $smoke "scopeOutAccepted"
        $smokeAccepted = $scopeOutAccepted.valid -and $scopeOutAccepted.value
    }

    return $formatVersion -eq "osmu.enterprise-auth-jit-rollback-evidence.v1" `
        -and $result -eq "passed" `
        -and $failureCount.valid `
        -and $checkCount.valid `
        -and $failureCount.value -eq 0 `
        -and $checkCount.value -gt 0 `
        -and $smokeAccepted
}

function Test-EnterpriseAuthJitRollbackRequirementSatisfied([object] $Report, [object] $EnterpriseAuthSmokeReport) {
    if ((Test-EnterpriseAuthEvidenceAccepted $EnterpriseAuthSmokeReport) -and ([string] (Get-ObjectProperty $EnterpriseAuthSmokeReport.data "result")) -eq "scope-out") {
        return $true
    }
    if ($Report.exists -or $Report.parsed) {
        return Test-EnterpriseAuthJitRollbackEvidenceAccepted $Report
    }
    return $false
}

function Get-EnterpriseAuthJitRollbackEvidenceDetail([object] $Report, [object] $EnterpriseAuthSmokeReport) {
    if ((Test-EnterpriseAuthEvidenceAccepted $EnterpriseAuthSmokeReport) -and ([string] (Get-ObjectProperty $EnterpriseAuthSmokeReport.data "result")) -eq "scope-out") {
        return "not required because enterprise auth target smoke result=scope-out with accepted commercial reference"
    }
    if (-not $Report.exists -or -not $Report.parsed) {
        return $Report.detail
    }

    $formatVersion = [string] (Get-ObjectProperty $Report.data "formatVersion")
    $result = [string] (Get-ObjectProperty $Report.data "result")
    $summary = Get-ObjectProperty $Report.data "summary"
    $failureCount = Get-RequiredObjectInt $summary "failureCount"
    $checkCount = Get-RequiredObjectInt $summary "checkCount"
    $confirmations = Get-ObjectProperty $Report.data "confirmations"
    $confirmedCount = 0
    $confirmationNames = @("adminApprovalRequired", "callbackAutoJitDisabled", "jitUserDisableOrLockRollbackReviewed", "roleOrgTeamRollbackReviewed", "localPasswordFallbackValidated", "auditEventsReviewed", "noRawClaims", "noSecretValues")
    foreach ($confirmationName in $confirmationNames) {
        $confirmation = Get-RequiredObjectBool $confirmations $confirmationName
        if ($confirmation.valid -and $confirmation.value) {
            $confirmedCount += 1
        }
    }
    $smoke = Get-ObjectProperty $Report.data "enterpriseAuthSmokeSnapshot"
    $smokeResult = [string] (Get-ObjectProperty $smoke "result")
    return "formatVersion=$formatVersion, result=$result, failures=$($failureCount.raw)(valid=$($failureCount.valid)), checks=$($checkCount.raw)(valid=$($checkCount.valid)), confirmations=$confirmedCount/$($confirmationNames.Count), smokeResult=$smokeResult"
}
function Get-OperationsHandoffPackageRequiredConfirmations() {
    return @(
        "noSecretValues",
        "runbookReviewed",
        "troubleshootingReviewed",
        "rollbackReviewed",
        "supportEscalationReviewed",
        "knownGapsAccepted",
        "operationsReadinessSnapshotReviewed",
        "operationsConvergenceSnapshotReviewed",
        "dataFlowStoragePlanReviewed",
        "dataFlowQueryRetentionBudgetReviewed",
        "dataFlowStorageTransitionRunbookReviewed",
        "secretRotationSnapshotReviewed",
        "commercialIntegrationSnapshotReviewed",
        "commercialApprovalSnapshotReviewed",
        "chargebackCloseoutSnapshotReviewed",
        "enterpriseAuthSmokeSnapshotReviewed",
        "monitoringThresholdReviewed",
        "clusterNetworkAccessReviewReviewed",
        "helmValuesHardeningReviewed",
        "requireProductionEvidence",
        "requireOperationsSnapshotEvidence"
    )
}

function Test-OperationsHandoffPackageContentSafe([object] $Data) {
    if ($null -eq $Data) {
        return $true
    }
    $reportText = $Data | ConvertTo-Json -Depth 40 -Compress
    $patterns = @(
        '(?i)"(rawClaimJson|raw_claim_json|idToken|id_token|accessToken|access_token|refreshToken|refresh_token|authorizationCode|authorization_code|oidcCode|oidc_code|oidcState|oidc_state|ldapPassword|ldap_password|adminPassword|admin_password|clientSecret|client_secret)"\s*:',
        '(?i)\b(password|passwd|credential|api[_-]?key|private[_-]?key|client[_-]?secret|ldap[_-]?password|admin[_-]?password)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($reportText -match $pattern) {
            return $false
        }
    }
    return $true
}

function Test-ReadyText($Value) {
    return "ready".Equals([string] $Value, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-OperationsHandoffPackageSnapshotValidation([object] $Data) {
    $operationsSnapshots = Get-ObjectProperty $Data "operationsSnapshots"
    if ($null -eq $operationsSnapshots) {
        return [pscustomobject]@{
            passed = $false
            detail = "operationsSnapshots expected"
        }
    }

    $readiness = Get-ObjectProperty $operationsSnapshots "readiness"
    $readinessResult = [string] (Get-ObjectProperty $readiness "result")
    if (-not (Test-ReadyText $readinessResult)) {
        return [pscustomobject]@{
            passed = $false
            detail = "operations readiness snapshot result=$readinessResult expected=ready"
        }
    }

    $convergence = Get-ObjectProperty $operationsSnapshots "convergence"
    $convergenceResult = [string] (Get-ObjectProperty $convergence "result")
    $convergenceReadinessResult = [string] (Get-ObjectProperty $convergence "readinessResult")
    $finalizerResult = [string] (Get-ObjectProperty $convergence "finalizerResult")
    $finalizerReadinessResult = [string] (Get-ObjectProperty $convergence "finalizerReadinessResult")
    $finalizerFailedCount = Get-RequiredObjectInt $convergence "finalizerFailedCount"
    $finalizerGapCount = Get-RequiredObjectInt $convergence "finalizerGapCount"
    $syncReady = Get-RequiredObjectBool $convergence "kubernetesReportSyncReady"
    $syncFailedCount = Get-RequiredObjectInt $convergence "kubernetesReportSyncFailedCount"
    $sourceReportResult = [string] (Get-ObjectProperty $convergence "kubernetesReportSyncSourceReportResult")

    if (-not (Test-ReadyText $convergenceResult)) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence snapshot result=$convergenceResult expected=ready" }
    }
    if (-not (Test-ReadyText $convergenceReadinessResult)) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence readinessResult=$convergenceReadinessResult expected=ready" }
    }
    if (-not (Test-ReadyText $finalizerResult) -or -not (Test-ReadyText $finalizerReadinessResult)) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence finalizerResult=$finalizerResult finalizerReadinessResult=$finalizerReadinessResult expected=ready" }
    }
    if (-not $finalizerFailedCount.valid -or -not $finalizerGapCount.valid) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence finalizerFailedCount=$($finalizerFailedCount.raw) finalizerGapCount=$($finalizerGapCount.raw) expected integer 0" }
    }
    if ($finalizerFailedCount.value -ne 0 -or $finalizerGapCount.value -ne 0) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence finalizerFailedCount=$($finalizerFailedCount.value) finalizerGapCount=$($finalizerGapCount.value) expected=0" }
    }
    if (-not $syncReady.valid -or -not $syncFailedCount.valid) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence kubernetesReportSyncReady=$($syncReady.raw) failedSyncChecks=$($syncFailedCount.raw) expected boolean true and integer 0" }
    }
    if (-not $syncReady.value -or $syncFailedCount.value -ne 0) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence kubernetesReportSyncReady=$($syncReady.value) failedSyncChecks=$($syncFailedCount.value) expected ready/0" }
    }
    if (-not (Test-ReadyText $sourceReportResult)) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence sourceReportResult=$sourceReportResult expected=ready" }
    }

    $targetSnapshots = Get-ObjectProperty $Data "targetEvidenceSnapshots"
    if ($null -eq $targetSnapshots) {
        return [pscustomobject]@{ passed = $false; detail = "targetEvidenceSnapshots expected" }
    }

    $clusterNetworkAccessReview = Get-ObjectProperty $targetSnapshots "clusterNetworkAccessReview"
    $clusterNetworkAccessReviewResult = [string] (Get-ObjectProperty $clusterNetworkAccessReview "result")
    $clusterNetworkAccessReviewFailureCount = Get-RequiredObjectInt $clusterNetworkAccessReview "failureCount"
    $clusterNetworkAccessReviewTotalCount = Get-RequiredObjectInt $clusterNetworkAccessReview "totalCount"
    $clusterNetworkAccessReviewStaticControlsValid = Get-RequiredObjectBool $clusterNetworkAccessReview "staticControlsValid"
    $clusterNetworkAccessReviewConfirmationsValid = Get-RequiredObjectBool $clusterNetworkAccessReview "confirmationsValid"
    if ($clusterNetworkAccessReviewResult -ne "passed" -or -not $clusterNetworkAccessReviewFailureCount.valid -or $clusterNetworkAccessReviewFailureCount.value -ne 0 -or -not $clusterNetworkAccessReviewTotalCount.valid -or $clusterNetworkAccessReviewTotalCount.value -le 0 -or -not $clusterNetworkAccessReviewStaticControlsValid.valid -or -not $clusterNetworkAccessReviewStaticControlsValid.value -or -not $clusterNetworkAccessReviewConfirmationsValid.valid -or -not $clusterNetworkAccessReviewConfirmationsValid.value) {
        return [pscustomobject]@{ passed = $false; detail = "clusterNetworkAccessReview snapshot result=$clusterNetworkAccessReviewResult failures=$($clusterNetworkAccessReviewFailureCount.raw) checks=$($clusterNetworkAccessReviewTotalCount.raw) staticControlsValid=$($clusterNetworkAccessReviewStaticControlsValid.raw) confirmationsValid=$($clusterNetworkAccessReviewConfirmationsValid.raw) expected passed/0/typed true" }
    }

    $helmValuesHardening = Get-ObjectProperty $targetSnapshots "helmValuesHardening"
    $helmValuesHardeningResult = [string] (Get-ObjectProperty $helmValuesHardening "result")
    $helmValuesHardeningFailureCount = Get-RequiredObjectInt $helmValuesHardening "failureCount"
    $helmValuesHardeningTotalCount = Get-RequiredObjectInt $helmValuesHardening "totalCount"
    $helmValuesHardeningChartFileCount = Get-RequiredObjectInt $helmValuesHardening "chartFileCount"
    $helmValuesHardeningStaticHardeningValid = Get-RequiredObjectBool $helmValuesHardening "staticHardeningValid"
    $helmValuesHardeningConfirmationsValid = Get-RequiredObjectBool $helmValuesHardening "confirmationsValid"
    if ($helmValuesHardeningResult -ne "passed" -or -not $helmValuesHardeningFailureCount.valid -or $helmValuesHardeningFailureCount.value -ne 0 -or -not $helmValuesHardeningTotalCount.valid -or $helmValuesHardeningTotalCount.value -le 0 -or -not $helmValuesHardeningChartFileCount.valid -or $helmValuesHardeningChartFileCount.value -le 0 -or -not $helmValuesHardeningStaticHardeningValid.valid -or -not $helmValuesHardeningStaticHardeningValid.value -or -not $helmValuesHardeningConfirmationsValid.valid -or -not $helmValuesHardeningConfirmationsValid.value) {
        return [pscustomobject]@{ passed = $false; detail = "helmValuesHardening snapshot result=$helmValuesHardeningResult failures=$($helmValuesHardeningFailureCount.raw) checks=$($helmValuesHardeningTotalCount.raw) chartFiles=$($helmValuesHardeningChartFileCount.raw) staticHardeningValid=$($helmValuesHardeningStaticHardeningValid.raw) confirmationsValid=$($helmValuesHardeningConfirmationsValid.raw) expected passed/0/typed true" }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "snapshotReadiness=ready, convergence=ready, finalizerFailed=0, finalizerGaps=0, sourceReportResult=ready, clusterNetworkAccessReview=passed, helmValuesHardening=passed"
    }
}

function Get-OperationsHandoffPackageValidation([object] $Report) {
    if (-not $Report.exists -or -not $Report.parsed) {
        return [pscustomobject]@{
            passed = $false
            detail = $Report.detail
        }
    }

    if (Test-SelfTestTargetEvidence $Report) {
        return [pscustomobject]@{
            passed = $false
            detail = Add-TargetEvidenceGuardDetail $Report "operations handoff package target evidence rejected"
        }
    }

    $formatVersion = [string] (Get-ObjectProperty $Report.data "formatVersion")
    if ($formatVersion -ne "osmu.operations-handoff-package.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.operations-handoff-package.v1"
        }
    }

    $result = [string] (Get-ObjectProperty $Report.data "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $confirmations = Get-ObjectProperty $Report.data "confirmations"
    $requiredConfirmations = Get-OperationsHandoffPackageRequiredConfirmations
    foreach ($confirmationName in $requiredConfirmations) {
        $confirmation = Get-RequiredObjectBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true"
            }
        }
    }

    $snapshotValidation = Get-OperationsHandoffPackageSnapshotValidation $Report.data
    if (-not $snapshotValidation.passed) {
        return $snapshotValidation
    }

    if (-not (Test-OperationsHandoffPackageContentSafe $Report.data)) {
        return [pscustomobject]@{
            passed = $false
            detail = "operations handoff package contains raw identity or credential-shaped content"
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion, result=$result, requiredConfirmations=$($requiredConfirmations.Count), $($snapshotValidation.detail)"
    }
}

$releaseReport = Read-JsonReport $ReleaseReportPath "MVP release report"
$storageExpansionReport = Read-JsonReport $StorageExpansionFinalizeReportPath "Storage expansion finalizer"
$haDrReadinessReport = Read-JsonReport $KubernetesHaDrReadinessReportPath "Kubernetes HA/DR readiness"
$kubernetesDrReport = Read-JsonReport $KubernetesDrFinalizeReportPath "Kubernetes DR finalizer"
$iamRbacFinalizeReport = Read-JsonReport $IamRbacFinalizeReportPath "IAM/RBAC finalizer"
$securityFinalizeReport = Read-JsonReport $SecurityEvidenceFinalizeReportPath "Security evidence finalizer"
$imageSigningReport = Read-JsonReport $ImageSigningEvidencePath "Image signing evidence"
$containerSecurityReport = Read-JsonReport $ContainerSecurityEvidencePath "Container security evidence"
$storageBackendTelemetryReport = Read-JsonReport $StorageBackendTelemetryEvidencePath "Storage backend telemetry evidence"
$monitoringThresholdReport = Read-JsonReport $MonitoringThresholdEvidencePath "Monitoring threshold evidence"
$secretRotationReport = Read-JsonReport $SecretRotationEvidencePath "Secret rotation evidence"
$commercialIntegrationReport = Read-JsonReport $CommercialIntegrationEvidencePath "Commercial integration evidence"
$commercialApprovalReport = Read-JsonReport $CommercialApprovalEvidencePath "Commercial approval evidence"
$chargebackCloseoutReport = Read-JsonReport $ChargebackCloseoutEvidencePath "Chargeback closeout evidence"
$enterpriseAuthSmokeReport = Read-JsonReport $EnterpriseAuthSmokeEvidencePath "Enterprise auth smoke evidence"
$enterpriseAuthJitRollbackReport = Read-JsonReport $EnterpriseAuthJitRollbackEvidencePath "Enterprise auth JIT rollback evidence"
$operationsHandoffPackageReport = Read-JsonReport $OperationsHandoffPackagePath "Operations handoff package"
$clusterNetworkAccessReviewReport = Read-JsonReport $ClusterNetworkAccessReviewEvidencePath "Cluster network access review evidence"
$helmValuesHardeningReport = Read-JsonReport $HelmValuesHardeningEvidencePath "Helm values hardening evidence"
$dataFlowStoragePlanReport = Read-JsonReport $DataFlowStoragePlanPath "Data-flow storage transition plan"
$dataFlowQueryRetentionBudgetReport = Read-JsonReport $DataFlowQueryRetentionBudgetEvidencePath "Data-flow query/retention budget evidence"
$dataFlowStorageTransitionRunbookReport = Read-JsonReport $DataFlowStorageTransitionRunbookEvidencePath "Data-flow storage transition runbook evidence"
$operationsHandoffPackageValidation = Get-OperationsHandoffPackageValidation $operationsHandoffPackageReport

$storageExpansionRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -Namespace osmu -TenantName osmu-minio -ManifestPath .\infra\k8s\examples\minio-tenant-pool-expansion.example.yaml -ImpersonateRunner" `
    ".github/workflows/storage-expansion-finalizer-ci.yml" `
    "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f manifest_path=./infra/k8s/examples/minio-tenant-pool-expansion.example.yaml -f impersonate_runner=true" `
    "Run live against the target cluster, or dispatch the workflow with run_live=true and OSMU_KUBECONFIG_BASE64 configured."
$haDrReadinessRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-ha-dr-readiness.ps1 -Namespace osmu -RestoreManifestPath .\infra\k8s\examples\restore-from-backup.example.yaml" `
    ".github/workflows/kubernetes-ha-dr-readiness-ci.yml" `
    "gh workflow run kubernetes-ha-dr-readiness-ci.yml -f run_live=true -f namespace=osmu -f restore_manifest_path=./infra/k8s/examples/restore-from-backup.example.yaml" `
    "Run live against the target namespace, or dispatch the workflow with run_live=true and OSMU_KUBECONFIG_BASE64 configured."
$kubernetesDrRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -BackupTimestamp <YYYYMMDDTHHMMSSZ> -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -ConfirmRestore -ApiBase <restore-api-base> -AdminLoginId <admin> -AdminPassword <secret> -MetadataRowCount <count> -RunS3ClientSmoke -SubmitEvidence" `
    ".github/workflows/kubernetes-dr-finalizer-ci.yml" `
    "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f source_namespace=osmu -f restore_namespace=osmu-restore-drill -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f server_dry_run_only=false -f confirm_restore=true -f bootstrap_dr_bucket=true -f verify_dr_bucket_immutability=true -f transfer_artifacts=true -f run_s3_client_smoke=true -f submit_evidence=true -f api_base=<restore-api-base> -f admin_login_id=<admin> -f metadata_row_count=<count>" `
    "Use a real backup timestamp and confirmed restore only after operator approval; server_dry_run_only is useful preflight but does not produce ready evidence."
$securityFinalizeRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-security-evidence.ps1 -ImageSigningEvidencePath .\.osmu-run\latest-image-signing-evidence.json -ContainerSecurityEvidencePath .\.osmu-run\latest-container-security-evidence.json" `
    ".github/workflows/security-evidence-finalizer-ci.yml" `
    "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<run-id> -f image_signing_artifact_name=<artifact-name> -f container_security_run_id=<run-id> -f container_security_artifact_name=<artifact-name> -f fail_if_not_passed=true" `
    "Promote non-synthetic image signing and container security artifacts only after the source workflow artifacts pass the strict GitHub OIDC keyless signing and SPDX SBOM import contracts."
$imageSigningRemediation = New-Remediation `
    "Dispatch .github/workflows/image-publish-sign-ci.yml with publish=true and a release version such as v0.1.0-rc.1" `
    ".github/workflows/image-publish-sign-ci.yml" `
    "gh workflow run image-publish-sign-ci.yml -f version=v0.1.0-rc.1 -f publish=true" `
    "The workflow writes .osmu-run/latest-image-signing-evidence.json after GitHub Actions OIDC keyless Cosign verification, release-version tag verification, commit-SHA tag verification, and digest capture."
$containerSecurityRemediation = New-Remediation `
    "Dispatch .github/workflows/container-security-ci.yml on the target commit" `
    ".github/workflows/container-security-ci.yml" `
    "gh workflow run container-security-ci.yml" `
    "The workflow writes .osmu-run/latest-container-security-evidence.json after Trivy CRITICAL,HIGH scans, commit-SHA image tag capture, ignore-unfixed policy recording, and backend/frontend SPDX SBOM metadata generation."
$storageBackendTelemetryRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-storage-backend-telemetry-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -MinioAlias <alias> -EvidenceRef <run-ref> -AdminInfoJsonPath .\.osmu-run\minio-admin-info.json -FailIfNotPassed" `
    ".github/workflows/manual-storage-backend-telemetry-evidence.yml" `
    "gh workflow run manual-storage-backend-telemetry-evidence.yml -f collection_mode=live -f minio_endpoint=<minio-endpoint> -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f minio_alias=<alias> -f evidence_ref=<run-ref> -f fail_if_not_passed=true" `
    "Run after collecting target MinIO pool/node telemetry with mc admin info --json, or dispatch the manual workflow in live mode with OSMU_MINIO_ACCESS_KEY and OSMU_MINIO_SECRET_KEY secrets plus a non-secret minio_endpoint input. The workflow still supports prepared_base64 mode with OSMU_MINIO_ADMIN_INFO_JSON_BASE64 when operators need offline evidence ingestion. The evidence stores summary counts, byte totals, server states, input SHA-256, and external references only; do not pass raw credentials, bearer tokens, private keys, kubeconfig, MinIO root credentials, or object data."
$dataFlowStoragePlanRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-storage-plan.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -CandidateStore MARIADB_PARTITION -ExpectedPeakEventsPerDay <events-per-day> -ExpectedQueryWindowDays <query-window-days> -TargetP95QueryLatencyMs <p95-ms> -EvidenceRef <run-ref> -ConfirmNoObjectKeyInAggregates -ConfirmBackfillPlan -ConfirmRollbackPlan -ConfirmDashboardCutoverPlan -ConfirmRetentionJobBudget -ConfirmExplainEvidence -QueryPlanEvidenceJsonPath .\.osmu-run\latest-mariadb-query-plan-evidence.json -RequireQueryPlanEvidence -FailIfNotPassed" `
    ".github/workflows/manual-data-flow-storage-plan-evidence.yml" `
    "gh workflow run manual-data-flow-storage-plan-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f candidate_store=MARIADB_PARTITION -f expected_peak_events_per_day=<events-per-day> -f expected_query_window_days=<query-window-days> -f target_p95_query_latency_ms=<p95-ms> -f evidence_ref=<run-ref> -f query_plan_evidence_json_base64=<base64-latest-mariadb-query-plan-evidence-json> -f confirm_no_object_key_in_aggregates=true -f confirm_backfill_plan=true -f confirm_rollback_plan=true -f confirm_dashboard_cutover_plan=true -f confirm_retention_job_budget=true -f confirm_explain_evidence=true -f require_query_plan_evidence=true -f fail_if_not_passed=true" `
    "Run after target MariaDB query plan evidence passes with write-mariadb-query-plan-evidence.ps1 -Execute or operator-collected EXPLAIN input, or dispatch the manual workflow with a sanitized base64 latest-mariadb-query-plan-evidence.json summary. For EXTERNAL_TIME_SERIES, change CandidateStore and use a target-store benchmark evidence reference. The plan stores result/count/failed-check metadata only; do not include raw SQL, raw EXPLAIN, credentials, object keys, or raw event messages."
$dataFlowQueryRetentionBudgetRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-query-retention-budget-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -QueryLatencyEvidenceRef <ref> -RetentionBudgetEvidenceRef <ref> -EvidenceRef <run-ref> -ObservedP95QueryLatencyMs <ms> -ObservedP99QueryLatencyMs <ms> -QuerySampleCount <n> -ObservedQueryWindowDays <days> -RetentionJobBudgetSeconds <seconds> -DetailedRetentionObservedSeconds <seconds> -DailyRollupRetentionObservedSeconds <seconds> -MonthlyRollupRetentionObservedSeconds <seconds> -DetailedRetentionDeletedRows <n> -DailyRollupRetentionDeletedRows <n> -MonthlyRollupRetentionDeletedRows <n> -ConfirmQueryLatencyReviewed -ConfirmRetentionJobsWithinBudget -ConfirmNoObjectKeysInEvidence -ConfirmNoRawSqlOrExplain -ConfirmNoSecretValues -FailIfNotPassed" `
    ".github/workflows/manual-data-flow-query-retention-budget-evidence.yml" `
    "gh workflow run manual-data-flow-query-retention-budget-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f review_started_at=<iso-time> -f review_completed_at=<iso-time> -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f query_latency_evidence_ref=<ref> -f retention_budget_evidence_ref=<ref> -f evidence_ref=<run-ref> -f observed_p95_query_latency_ms=<ms> -f observed_p99_query_latency_ms=<ms> -f query_sample_count=<n> -f observed_query_window_days=<days> -f retention_job_budget_seconds=<seconds> -f detailed_retention_observed_seconds=<seconds> -f daily_rollup_retention_observed_seconds=<seconds> -f monthly_rollup_retention_observed_seconds=<seconds> -f detailed_retention_deleted_rows=<n> -f daily_rollup_retention_deleted_rows=<n> -f monthly_rollup_retention_deleted_rows=<n> -f confirm_query_latency_reviewed=true -f confirm_retention_jobs_within_budget=true -f confirm_no_object_keys_in_evidence=true -f confirm_no_raw_sql_or_explain=true -f confirm_no_secret_values=true" `
    "Run after the target data-flow storage plan has passed and target query-latency benchmark plus detailed/daily/monthly retention dry-run metrics are collected. Evidence must stay aggregate-only: store p95/p99/sample/window counts, retention durations/deleted-row counts, references, and confirmations, not raw SQL, raw EXPLAIN, object keys, raw event messages, or credentials."
$dataFlowStorageTransitionRunbookRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-data-flow-storage-transition-runbook-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -DataFlowStoragePlanEvidenceRef <ref> -BackfillEvidenceRef <ref> -DualWriteOrPartitionToggleEvidenceRef <ref> -RollbackEvidenceRef <ref> -ReconciliationEvidenceRef <ref> -DashboardCutoverEvidenceRef <ref> -RetentionDryRunEvidenceRef <ref> -EvidenceRef <run-ref> -ConfirmBackfillRehearsed -ConfirmDualWriteOrPartitionToggleReviewed -ConfirmRollbackRehearsed -ConfirmReconciliationPassed -ConfirmDashboardCutoverReviewed -ConfirmRetentionDryRunReviewed -ConfirmNoObjectKeysInAggregates -ConfirmNoSecretValues -FailIfNotPassed" `
    ".github/workflows/manual-data-flow-storage-transition-runbook-evidence.yml" `
    "gh workflow run manual-data-flow-storage-transition-runbook-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f review_started_at=<iso-time> -f review_completed_at=<iso-time> -f change_approval_ref=<change-id> -f data_flow_storage_plan_evidence_ref=<ref> -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f backfill_evidence_ref=<ref> -f dual_write_or_partition_toggle_evidence_ref=<ref> -f rollback_evidence_ref=<ref> -f reconciliation_evidence_ref=<ref> -f dashboard_cutover_evidence_ref=<ref> -f retention_dry_run_evidence_ref=<ref> -f evidence_ref=<run-ref> -f confirm_backfill_rehearsed=true -f confirm_dual_write_or_partition_toggle_reviewed=true -f confirm_rollback_rehearsed=true -f confirm_reconciliation_passed=true -f confirm_dashboard_cutover_reviewed=true -f confirm_retention_dry_run_reviewed=true -f confirm_no_object_keys_in_aggregates=true -f confirm_no_secret_values=true -f fail_if_not_passed=true" `
    "Run after a passed target data-flow storage plan and target backfill, dual-write or partition toggle, rollback, reconciliation, dashboard cutover, and retention dry-run rehearsal evidence. The runbook evidence stores only reduced plan summary, references, booleans, and counts; do not include raw SQL, raw EXPLAIN, credentials, object keys, or raw event messages."
$monitoringThresholdRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-monitoring-threshold-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -ChangeApprovalRef <change-id> -EvidenceRef <run-ref> -PrometheusRulesEvidenceRef <ref> -GrafanaDashboardEvidenceRef <ref> -AlertmanagerRouteEvidenceRef <ref> -TargetBaselineEvidenceRef <ref> -IncidentRoutingEvidenceRef <ref> -ConfirmPrometheusRulesLoaded -ConfirmGrafanaDashboardImported -ConfirmAlertmanagerRoutesReviewed -ConfirmTargetBaselinesReviewed -ConfirmIncidentRoutingReviewed -ConfirmNoSecretValues -FailIfNotPassed" `
    ".github/workflows/manual-monitoring-threshold-evidence.yml" `
    "gh workflow run manual-monitoring-threshold-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f review_started_at=<iso-time> -f review_completed_at=<iso-time> -f change_approval_ref=<change-id> -f evidence_ref=<run-ref> -f prometheus_rules_evidence_ref=<ref> -f grafana_dashboard_evidence_ref=<ref> -f alertmanager_route_evidence_ref=<ref> -f target_baseline_evidence_ref=<ref> -f incident_routing_evidence_ref=<ref> -f confirm_prometheus_rules_loaded=true -f confirm_grafana_dashboard_imported=true -f confirm_alertmanager_routes_reviewed=true -f confirm_target_baselines_reviewed=true -f confirm_incident_routing_reviewed=true -f confirm_no_secret_values=true -f fail_if_not_passed=true" `
    "Run after target Prometheus rules, Grafana dashboards, Alertmanager routes, incident routing, and tenant baseline thresholds are reviewed. ReviewCompletedAt must be the same as or later than ReviewStartedAt. The evidence stores external references, typed counts, check rows, and confirmations only; do not pass Alertmanager receiver secrets, webhook credentials, bearer tokens, private keys, kubeconfig, raw customer incident data, or raw tenant object keys."
$secretRotationRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-secret-rotation-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -RotationStartedAt <iso-time> -RotationCompletedAt <iso-time> -ChangeApprovalRef <change-id> -SecretManagerEvidenceRef <audit-ref> -WorkloadRestartEvidenceRef <rollout-ref> -SmokeEvidenceRef <smoke-ref> -ArtifactLeakReviewEvidenceRef <scan-ref> -AccessKeyEncryptionDecisionRef <decision-ref> -RotateAdminPassword -RotateJwtSigningSecret -RotateDatabaseCredentials -RotateMinioRootCredentials -RotateTlsCertificate -ConfirmNoSecretValues -ConfirmWorkloadRestart -ConfirmSmokePassed -ConfirmArtifactLeakReview -FailIfNotPassed" `
    ".github/workflows/manual-secret-rotation-evidence.yml" `
    "gh workflow run manual-secret-rotation-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f rotation_started_at=<iso-time> -f rotation_completed_at=<iso-time> -f change_approval_ref=<change-id> -f secret_manager_evidence_ref=<audit-ref> -f workload_restart_evidence_ref=<rollout-ref> -f smoke_evidence_ref=<smoke-ref> -f artifact_leak_review_evidence_ref=<scan-ref> -f access_key_encryption_decision_ref=<decision-ref> -f rotate_admin_password=true -f rotate_jwt_signing_secret=true -f rotate_database_credentials=true -f rotate_minio_root_credentials=true -f rotate_tls_certificate=true -f confirm_no_secret_values=true -f confirm_workload_restart=true -f confirm_smoke_passed=true -f confirm_artifact_leak_review=true -f require_all_core_secrets=true -f fail_if_not_passed=true" `
    "Run after target-environment secret/certificate rotation. RotationCompletedAt must be the same as or later than RotationStartedAt. The evidence stores references and booleans only; do not pass secret values, tokens, private keys, kubeconfig, database credentials, MinIO credentials, OIDC/LDAP secrets, SMTP credentials, or webhook signing secrets."
$commercialIntegrationRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-integration-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -VerificationStartedAt <iso-time> -VerificationCompletedAt <iso-time> -ChangeApprovalRef <change-id> -NotificationWebhookEvidenceRef <ref> -SlackWebhookEvidenceRef <ref> -EmailSmtpEvidenceRef <ref> -PaymentGenericWebhookEvidenceRef <ref> -PaymentCardProfileEvidenceRef <ref> -PaymentBankProfileEvidenceRef <ref> -PaymentTaxProfileEvidenceRef <ref> -PaymentErpProfileEvidenceRef <ref> -PaymentProviderAdapterReadinessEvidenceRef <ref> -PaymentProviderAdapterReadinessJsonPath .\.osmu-run\payment-provider-adapter-readiness.json -AdapterRetryWorkerEvidenceRef <ref> -PayloadReviewEvidenceRef <ref> -PrivateNetworkBlockEvidenceRef <ref> -HmacSignatureEvidenceRef <ref> -VerifiedNotificationWebhook -VerifiedSlackWebhook -VerifiedEmailSmtp -VerifiedPaymentGenericWebhook -VerifiedPaymentCardProfile -VerifiedPaymentBankProfile -VerifiedPaymentTaxProfile -VerifiedPaymentErpProfile -ConfirmPaymentProviderAdapterReadinessReviewed -ConfirmAdapterRetryWorkerRun -ConfirmPayloadSizeCaps -ConfirmPrivateNetworkBlocking -ConfirmHmacSignatureHeaders -ConfirmNoSecretValues -ConfirmNoRawProviderResponses -RequireAllImplementedAdapters -FailIfNotPassed" `
    ".github/workflows/manual-commercial-integration-evidence.yml" `
    "gh workflow run manual-commercial-integration-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f verification_started_at=<iso-time> -f verification_completed_at=<iso-time> -f change_approval_ref=<change-id> -f notification_webhook_evidence_ref=<ref> -f slack_webhook_evidence_ref=<ref> -f email_smtp_evidence_ref=<ref> -f payment_generic_webhook_evidence_ref=<ref> -f payment_card_profile_evidence_ref=<ref> -f payment_bank_profile_evidence_ref=<ref> -f payment_tax_profile_evidence_ref=<ref> -f payment_erp_profile_evidence_ref=<ref> -f payment_provider_adapter_readiness_evidence_ref=<ref> -f payment_provider_adapter_readiness_json_base64=<base64-json> -f adapter_retry_worker_evidence_ref=<ref> -f payload_review_evidence_ref=<ref> -f private_network_block_evidence_ref=<ref> -f hmac_signature_evidence_ref=<ref> -f verified_notification_webhook=true -f verified_slack_webhook=true -f verified_email_smtp=true -f verified_payment_generic_webhook=true -f verified_payment_card_profile=true -f verified_payment_bank_profile=true -f verified_payment_tax_profile=true -f verified_payment_erp_profile=true -f confirm_payment_provider_adapter_readiness_reviewed=true -f confirm_adapter_retry_worker_run=true -f confirm_payload_size_caps=true -f confirm_private_network_blocking=true -f confirm_hmac_signature_headers=true -f confirm_no_secret_values=true -f confirm_no_raw_provider_responses=true -f require_all_implemented_adapters=true -f fail_if_not_passed=true" `
    "Run after target-environment notification webhook, Slack, EMAIL SMTP relay, generic payment webhook, CARD/BANK/TAX/ERP payment webhook profile handoff checks, and GET /api/admin/billing/payment-provider-adapter-readiness review. VerificationCompletedAt must be the same as or later than VerificationStartedAt. The readiness JSON can be passed as base64 to the manual workflow, is reduced to sanitized counts/profile statuses, and the decoded workflow input is deleted before artifact upload. This evidence can include sanitized native bridge readiness when configured but does not claim vendor-specific fixed SDK/schema card/bank/tax/ERP processor implementation, and must not include credentials, raw provider responses, or customer payment data."
$commercialApprovalRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-approval-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -OperatorName <operator> -ProductVersion <version> -ApprovalRef <approval-ref> -ApprovedBy <approver> -ApprovedAt <iso-time> -PricingApprovalRef <ref> -TermsApprovalRef <ref> -SupportSlaApprovalRef <ref> -LicenseAgreementRef <ref> -LegalApprovalRef <ref> -PilotContractRef <ref> -PricingPolicyProposalEvidenceRef <ref> -PricingPolicyProposalJsonPath .\.osmu-run\billing-pricing-policy-proposals.json -ConfirmPricingApproved -ConfirmTermsApproved -ConfirmSupportSlaApproved -ConfirmLicenseApproved -ConfirmLegalApproved -ConfirmPricingPolicyProposalCommercialApproval -RequirePricingPolicyProposalApprovalSnapshot -ConfirmNoSecretValues -FailIfNotPassed" `
    ".github/workflows/manual-commercial-approval-evidence.yml" `
    "gh workflow run manual-commercial-approval-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f product_version=<version> -f approval_ref=<approval-ref> -f approved_by=<approver> -f approved_at=<iso-time> -f pricing_approval_ref=<ref> -f terms_approval_ref=<ref> -f support_sla_approval_ref=<ref> -f license_agreement_ref=<ref> -f legal_approval_ref=<ref> -f pilot_contract_ref=<ref> -f pricing_policy_proposal_evidence_ref=<ref> -f pricing_policy_proposal_json_base64=<base64-json> -f confirm_pricing_approved=true -f confirm_terms_approved=true -f confirm_support_sla_approved=true -f confirm_license_approved=true -f confirm_legal_approved=true -f confirm_pricing_policy_proposal_commercial_approval=true -f confirm_no_secret_values=true -f fail_if_not_passed=true" `
    "Run after final pricing, terms, support SLA, license agreement, legal approval, pilot contract boundary, and GET /api/admin/billing/pricing-policy-proposals?status=PRICE_LIST_APPROVED review. The pricing proposal JSON can be passed as base64 to the manual workflow, is reduced to sanitized status/reference metadata, and the decoded workflow input is deleted before artifact upload. The evidence stores references and booleans only; do not pass raw prices, raw legal terms, contracts, customer payment data, passwords, tokens, private keys, license keys, or signing secrets."
$chargebackCloseoutRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-chargeback-closeout-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -BillingPeriod <yyyy-mm> -CloseoutStartedAt <iso-time> -CloseoutCompletedAt <iso-time> -ChangeApprovalRef <change-id> -PricingPolicyEvidenceRef <ref> -PricingProposalApprovalRef <ref> -ChargebackPreviewEvidenceRef <ref> -ChargebackTrendExportEvidenceRef <ref> -InvoiceDraftEvidenceRef <ref> -InvoiceFinalizationEvidenceRef <ref> -PaymentRequestEvidenceRef <ref> -PaymentProviderHandoffEvidenceRef <ref> -PaymentProviderAdapterReadinessEvidenceRef <ref> -PaymentProviderAdapterReadinessJsonPath .\.osmu-run\payment-provider-adapter-readiness.json -NotificationDeliveryEvidenceRef <ref> -AdapterRetryWorkerEvidenceRef <ref> -ReconciliationEvidenceRef <ref> -CommercialIntegrationEvidenceRef <ref> -CommercialApprovalEvidenceRef <ref> -ChargebackCloseoutSnapshotJsonPath .\.osmu-run\chargeback-closeout-summary.json -ConfirmPricingPolicyReviewed -ConfirmPriceListApproved -ConfirmUsageWindowReviewed -ConfirmChargebackPreviewReviewed -ConfirmTrendExportReviewed -ConfirmInvoiceDraftReviewed -ConfirmInvoiceFinalized -ConfirmPaymentRequestReviewed -ConfirmPaymentProviderHandoffReviewed -ConfirmPaymentProviderAdapterReadinessReviewed -ConfirmNotificationDeliveryReviewed -ConfirmAdapterRetryReviewed -ConfirmReconciliationReviewed -ConfirmCommercialIntegrationReviewed -ConfirmCommercialApprovalReviewed -ConfirmNoRawCustomerPaymentData -ConfirmNoRawProviderResponses -ConfirmNoSecretValues -RequirePaymentProviderAdapterReadinessSnapshot -FailIfNotPassed" `
    ".github/workflows/manual-chargeback-closeout-evidence.yml" `
    "gh workflow run manual-chargeback-closeout-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f billing_period=<yyyy-mm> -f closeout_started_at=<iso-time> -f closeout_completed_at=<iso-time> -f change_approval_ref=<change-id> -f payment_provider_adapter_readiness_json_base64=<base64-payment-provider-adapter-readiness-json> -f chargeback_closeout_snapshot_json_base64=<base64-chargeback-closeout-summary-json> -f chargeback_closeout_payload_json_base64=<base64-chargeback-closeout-refs-and-confirmations-json> -f fail_if_not_passed=true" `
    "Run after the target billing period has been closed and pricing, usage, invoice, payment handoff, notification, retry, reconciliation, commercial integration, and commercial approval references have been reviewed. The sanitized payment-provider adapter readiness and closeout snapshots can be passed as base64 to the manual workflow, are decoded only into temporary files, and are deleted before artifact upload. The sanitized closeout snapshot must be typed and must not include raw customer/payment/provider data, raw invoices, raw price tables, endpoint secrets, or credentials. This evidence can include sanitized native bridge readiness but does not claim vendor-specific fixed SDK/schema card/bank/tax/ERP provider implementation."
$enterpriseAuthSmokeRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-smoke-plan.ps1 -EnvironmentName <env> -TargetCluster <cluster> -OperatorName <operator> -Execute -AdminLoginId <admin> -AdminPassword <secret> -RequireOidc -RequireLdap" `
    ".github/workflows/enterprise-auth-smoke-ci.yml" `
    "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f api_base=<api-base> -f admin_login_id=<admin> -f require_oidc=true -f require_ldap=true -f fail_if_not_passed=true" `
    "Run against the target pilot IdP/directory only after OIDC/LDAP provider flags and local user mapping are configured. Passed promotion requires typed integer summary counts with passCount>0 and fail/block/planned counts at zero, or record an explicit commercial scope-out with write-enterprise-auth-smoke-plan.ps1 -ConfirmScopeOut -ScopeOutRef <approval-ref> -ScopeOutReason <reason>. The workflow requires OSMU_ENTERPRISE_AUTH_ADMIN_PASSWORD and, when LDAP is required, OSMU_ENTERPRISE_AUTH_LDAP_LOGIN_ID/OSMU_ENTERPRISE_AUTH_LDAP_PASSWORD secrets. Evidence does not include passwords, tokens, OIDC code/state, raw claim JSON, or credential-like scope-out references."
$enterpriseAuthJitRollbackRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-jit-rollback-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -ChangeApprovalRef <change-id> -EnterpriseAuthSmokeJsonPath .\.osmu-run\latest-enterprise-auth-smoke.json -RequireEnterpriseAuthSmokeEvidence -JitProvisionEvidenceRef <ref> -JitRollbackRunbookRef <ref> -UserDisableRollbackEvidenceRef <ref> -RoleMappingRollbackEvidenceRef <ref> -LocalLoginFallbackEvidenceRef <ref> -AuditReviewEvidenceRef <ref> -EvidenceRef <run-ref> -ConfirmAdminApprovalRequired -ConfirmCallbackAutoJitDisabled -ConfirmJitUserDisableOrLockRollbackReviewed -ConfirmRoleOrgTeamRollbackReviewed -ConfirmLocalPasswordFallbackValidated -ConfirmAuditEventsReviewed -ConfirmNoRawClaims -ConfirmNoSecretValues -FailIfNotPassed" `
    ".github/workflows/manual-enterprise-auth-jit-rollback-evidence.yml" `
    "gh workflow run manual-enterprise-auth-jit-rollback-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f review_started_at=<iso-time> -f review_completed_at=<iso-time> -f change_approval_ref=<change-id> -f enterprise_auth_smoke_json_base64=<base64-latest-enterprise-auth-smoke-json> -f jit_rollback_payload_json_base64=<base64-jit-rollback-refs-and-confirmations-json> -f require_enterprise_auth_smoke_evidence=true -f fail_if_not_passed=true" `
    "Run when target enterprise auth smoke is result=passed and JIT provisioning is in production scope. The evidence must prove admin approval, callback auto-JIT disablement, user disable/lock rollback, role/org/team mapping rollback, local password fallback, audit review, no raw claims, and no secret values. If enterprise auth is contractually deferred, record accepted enterprise auth smoke scope-out instead; this readiness check then treats JIT rollback as not required. The workflow accepts sanitized base64 smoke and rollback payload inputs only and must not include OIDC codes/states/tokens, LDAP/admin passwords, raw claims, identity provider responses, or directory data."
$clusterNetworkAccessReviewRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-cluster-network-access-review-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DnsEgressReviewRef <ref> -MariaDbAccessReviewRef <ref> -MinioAccessReviewRef <ref> -BackupAccessReviewRef <ref> -PublicIngressReviewRef <ref> -DefaultDenyReviewRef <ref> -ObservabilityScrapeReviewRef <ref> -K8sVerifierEvidenceRef <ref> -HelmVerifierEvidenceRef <ref> -EvidenceRef <run-ref> -ConfirmBackendOnlyMariaDb -ConfirmBackendOnlyMinio -ConfirmBackupOnlyMariaDbMinio -ConfirmDnsEgressScoped -ConfirmMariaDbIngressBackendBackupOnly -ConfirmMinioIngressBackendBackupOnly -ConfirmPublicIngressLimited -ConfirmNamespaceDefaultDenyReviewed -ConfirmObservabilityScrapeReviewed -ConfirmHelmNetworkPolicyEnabled -ConfirmNoCredentialValues -FailIfNotPassed" `
    ".github/workflows/manual-cluster-network-access-review-evidence.yml" `
    "gh workflow run manual-cluster-network-access-review-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f review_started_at=<iso-time> -f review_completed_at=<iso-time> -f change_approval_ref=<change-id> -f evidence_ref=<run-ref> -f access_review_refs_json_base64=<base64-json-with-network-review-refs> -f confirm_backend_only_mariadb=true -f confirm_backend_only_minio=true -f confirm_backup_only_mariadb_minio=true -f confirm_dns_egress_scoped=true -f confirm_mariadb_ingress_backend_backup_only=true -f confirm_minio_ingress_backend_backup_only=true -f confirm_public_ingress_limited=true -f confirm_namespace_default_deny_reviewed=true -f confirm_observability_scrape_reviewed=true -f confirm_helm_network_policy_enabled=true -f confirm_no_credential_values=true -f fail_if_not_passed=true" `
    "Run after Kubernetes and Helm NetworkPolicy sources plus target access review references are checked. The manual workflow accepts a base64 JSON payload containing non-secret DnsEgressReviewRef, MariaDbAccessReviewRef, MinioAccessReviewRef, BackupAccessReviewRef, PublicIngressReviewRef, DefaultDenyReviewRef, ObservabilityScrapeReviewRef, K8sVerifierEvidenceRef, and HelmVerifierEvidenceRef values, deletes the decoded payload before upload, and stores file hashes, references, and typed confirmations only; do not include kubeconfig, bearer tokens, passwords, private keys, access keys, raw secret values, or live CNI enforcement output."
$helmValuesHardeningRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-helm-values-hardening-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -ChangeApprovalRef <change-id> -HelmVerifierEvidenceRef <ref> -KubernetesVerifierEvidenceRef <ref> -ContainerHardeningEvidenceRef <ref> -ClusterNetworkAccessReviewEvidenceRef <ref> -EvidenceRef <run-ref> -ConfirmSecretsExternalized -ConfirmDefaultSecretPlaceholdersNotUsed -ConfirmHaReplicasReviewed -ConfirmResourcesBounded -ConfirmSecurityContextsReviewed -ConfirmNetworkPolicyEnabled -ConfirmTlsIngressReviewed -ConfirmOperationsReportsReadOnly -ConfirmStorageExpansionRbacDisabledByDefault -ConfirmNoCredentialValues -FailIfNotPassed" `
    ".github/workflows/manual-helm-values-hardening-evidence.yml" `
    "gh workflow run manual-helm-values-hardening-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f review_started_at=<iso-time> -f review_completed_at=<iso-time> -f change_approval_ref=<change-id> -f evidence_ref=<run-ref> -f hardening_refs_json_base64=<base64-json-with-helm-hardening-refs> -f confirm_secrets_externalized=true -f confirm_default_secret_placeholders_not_used=true -f confirm_ha_replicas_reviewed=true -f confirm_resources_bounded=true -f confirm_security_contexts_reviewed=true -f confirm_network_policy_enabled=true -f confirm_tls_ingress_reviewed=true -f confirm_operations_reports_read_only=true -f confirm_storage_expansion_rbac_disabled_by_default=true -f confirm_no_credential_values=true -f fail_if_not_passed=true" `
    "Run after Helm chart values/templates and target hardening review references are checked. The manual workflow accepts a base64 JSON payload containing non-secret HelmVerifierEvidenceRef, KubernetesVerifierEvidenceRef, ContainerHardeningEvidenceRef, and ClusterNetworkAccessReviewEvidenceRef values, deletes the decoded payload before upload, and stores chart hashes, static hardening booleans, references, and typed confirmations only; do not include production secret values, kubeconfig, bearer tokens, private keys, raw credentials, or rendered secret manifests."
$operationsHandoffPackageRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-handoff-package.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -HandoffStartedAt <iso-time> -HandoffCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DeploymentEvidenceRef <ref> -OperationsReadinessRef <ref> -OperationsConvergenceRef <ref> -DataFlowStoragePlanEvidenceRef <ref> -DataFlowQueryRetentionBudgetEvidenceRef <ref> -DataFlowStorageTransitionRunbookEvidenceRef <ref> -OperationsReadinessJsonPath .\.osmu-run\latest-operations-readiness.json -OperationsConvergenceJsonPath .\.osmu-run\latest-operations-readiness-convergence.json -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -DataFlowQueryRetentionBudgetJsonPath .\.osmu-run\latest-data-flow-query-retention-budget-evidence.json -DataFlowStorageTransitionRunbookJsonPath .\.osmu-run\latest-data-flow-storage-transition-runbook-evidence.json -SecretRotationEvidenceRef <ref> -SecretRotationJsonPath .\.osmu-run\latest-secret-rotation-evidence.json -CommercialIntegrationEvidenceRef <ref> -CommercialApprovalEvidenceRef <ref> -ChargebackCloseoutEvidenceRef <ref> -CommercialIntegrationJsonPath .\.osmu-run\latest-commercial-integration-evidence.json -CommercialApprovalJsonPath .\.osmu-run\latest-commercial-approval-evidence.json -ChargebackCloseoutJsonPath .\.osmu-run\latest-chargeback-closeout-evidence.json -EnterpriseAuthEvidenceRef <ref> -EnterpriseAuthJsonPath .\.osmu-run\latest-enterprise-auth-smoke.json -EnterpriseAuthJitRollbackEvidenceRef <ref> -EnterpriseAuthJitRollbackJsonPath .\.osmu-run\latest-enterprise-auth-jit-rollback-evidence.json -BackupRestoreEvidenceRef <ref> -HaDrEvidenceRef <ref> -MonitoringEvidenceRef <ref> -MonitoringThresholdJsonPath .\.osmu-run\latest-monitoring-threshold-evidence.json -ClusterNetworkAccessReviewEvidenceRef <ref> -ClusterNetworkAccessReviewJsonPath .\.osmu-run\latest-cluster-network-access-review-evidence.json -HelmValuesHardeningEvidenceRef <ref> -HelmValuesHardeningJsonPath .\.osmu-run\latest-helm-values-hardening-evidence.json -SecurityEvidenceRef <ref> -IamRbacEvidenceRef <ref> -RunbookReviewRef <ref> -TroubleshootingReviewRef <ref> -SupportEscalationRef <ref> -SupportSlaRef <ref> -KnownGapsRef <ref> -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackReviewed -ConfirmSupportEscalationReviewed -ConfirmKnownGapsAccepted -ConfirmOperationsReadinessSnapshotReviewed -ConfirmOperationsConvergenceSnapshotReviewed -ConfirmDataFlowStoragePlanReviewed -ConfirmDataFlowQueryRetentionBudgetReviewed -ConfirmDataFlowStorageTransitionRunbookReviewed -ConfirmSecretRotationSnapshotReviewed -ConfirmCommercialIntegrationSnapshotReviewed -ConfirmCommercialApprovalSnapshotReviewed -ConfirmChargebackCloseoutSnapshotReviewed -ConfirmEnterpriseAuthSmokeSnapshotReviewed -ConfirmEnterpriseAuthJitRollbackSnapshotReviewed -ConfirmMonitoringThresholdReviewed -ConfirmClusterNetworkAccessReviewReviewed -ConfirmHelmValuesHardeningReviewed -ConfirmNoSecretValues -RequireProductionEvidence -RequireOperationsSnapshotEvidence -FailIfNotPassed" `
    ".github/workflows/manual-operations-handoff-package.yml" `
    "gh workflow run manual-operations-handoff-package.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f handoff_started_at=<iso-time> -f handoff_completed_at=<iso-time> -f change_approval_ref=<change-id> -f deployment_evidence_ref=<ref> -f operations_readiness_ref=<ref> -f operations_convergence_ref=<ref> -f data_flow_storage_plan_evidence_ref=<ref> -f data_flow_query_retention_budget_evidence_ref=<ref> -f data_flow_storage_transition_runbook_evidence_ref=<ref> -f operations_readiness_json_base64=<base64-json> -f operations_convergence_json_base64=<base64-json> -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f data_flow_query_retention_budget_json_base64=<base64-latest-data-flow-query-retention-budget-json> -f data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json> -f secret_rotation_evidence_ref=<ref> -f secret_rotation_json_base64=<base64-latest-secret-rotation-evidence-json> -f commercial_integration_evidence_ref=<ref> -f commercial_approval_evidence_ref=<ref> -f chargeback_closeout_evidence_ref=<ref> -f commercial_integration_json_base64=<base64-latest-commercial-integration-evidence-json> -f commercial_approval_json_base64=<base64-latest-commercial-approval-evidence-json> -f chargeback_closeout_json_base64=<base64-latest-chargeback-closeout-evidence-json> -f enterprise_auth_evidence_ref=<ref> -f enterprise_auth_json_base64=<base64-latest-enterprise-auth-smoke-json> -f enterprise_auth_jit_rollback_evidence_ref=<ref> -f enterprise_auth_jit_rollback_json_base64=<base64-latest-enterprise-auth-jit-rollback-evidence-json> -f backup_restore_evidence_ref=<ref> -f ha_dr_evidence_ref=<ref> -f monitoring_evidence_ref=<ref> -f monitoring_threshold_json_base64=<base64-latest-monitoring-threshold-evidence-json> -f cluster_network_access_review_evidence_ref=<ref> -f helm_values_hardening_evidence_ref=<ref> -f hardening_evidence_json_payload_base64=<base64-json-with-cluster-network-access-review-and-helm-values-hardening-snapshot-base64> -f security_evidence_ref=<ref> -f iam_rbac_evidence_ref=<ref> -f runbook_review_ref=<ref> -f troubleshooting_review_ref=<ref> -f support_escalation_ref=<ref> -f support_sla_ref=<ref> -f known_gaps_ref=<ref> -f confirm_runbook_reviewed=true -f confirm_troubleshooting_reviewed=true -f confirm_rollback_reviewed=true -f confirm_support_escalation_reviewed=true -f confirm_known_gaps_accepted=true -f confirm_operations_readiness_snapshot_reviewed=true -f confirm_operations_convergence_snapshot_reviewed=true -f confirm_data_flow_storage_plan_reviewed=true -f confirm_data_flow_query_retention_budget_reviewed=true -f confirm_data_flow_storage_transition_runbook_reviewed=true -f confirm_secret_rotation_snapshot_reviewed=true -f confirm_commercial_integration_snapshot_reviewed=true -f confirm_commercial_approval_snapshot_reviewed=true -f confirm_chargeback_closeout_snapshot_reviewed=true -f confirm_enterprise_auth_smoke_snapshot_reviewed=true -f confirm_enterprise_auth_jit_rollback_snapshot_reviewed=true -f confirm_monitoring_threshold_reviewed=true -f confirm_cluster_network_access_review_reviewed=true -f confirm_helm_values_hardening_reviewed=true -f confirm_no_secret_values=true -f require_production_evidence=true -f require_operations_snapshot_evidence=true -f fail_if_not_passed=true" `
    "Run at pilot or production handoff after the operator has reviewed runbook, troubleshooting, rollback, support escalation, known gaps, commercial approval, target evidence, .osmu-run/latest-operations-readiness.json, .osmu-run/latest-operations-readiness-convergence.json, .osmu-run/latest-data-flow-storage-plan.json, .osmu-run/latest-data-flow-query-retention-budget-evidence.json, .osmu-run/latest-data-flow-storage-transition-runbook-evidence.json, .osmu-run/latest-secret-rotation-evidence.json, .osmu-run/latest-commercial-integration-evidence.json, .osmu-run/latest-commercial-approval-evidence.json, .osmu-run/latest-chargeback-closeout-evidence.json, .osmu-run/latest-enterprise-auth-smoke.json, optional .osmu-run/latest-enterprise-auth-jit-rollback-evidence.json, .osmu-run/latest-monitoring-threshold-evidence.json, .osmu-run/latest-cluster-network-access-review-evidence.json, and .osmu-run/latest-helm-values-hardening-evidence.json, including explicit secret rotation, commercial integration, commercial approval, chargeback closeout, enterprise auth smoke, optional enterprise auth JIT rollback, monitoring threshold, cluster network access review, and Helm values hardening snapshot review confirmations. HandoffCompletedAt must be the same as or later than HandoffStartedAt. The readiness/convergence/data-flow plan/data-flow query-retention/data-flow runbook/secret-rotation/commercial/chargeback closeout/enterprise auth/monitoring threshold JSON can be passed as base64 to the manual workflow, and cluster network access review plus Helm values hardening JSON are passed together through hardening_evidence_json_payload_base64 and are reduced to sanitized result/count/sync/query-plan/query-retention/runbook/secret-rotation/commercial/chargeback closeout/enterprise auth smoke/JIT rollback/monitoring threshold/cluster network/Helm hardening summary fields. The package stores references, booleans, and reduced snapshot summaries only; do not pass passwords, bearer tokens, kubeconfig values, private keys, provider credentials, raw SQL, raw EXPLAIN JSON, object keys, raw event messages, raw provider responses, raw identity claims, OIDC codes/states/tokens, LDAP/admin passwords, raw remediation commands containing credentials, raw Alertmanager receiver secrets, raw price tables, raw contract text, or customer payment data."

$releaseReportRemediation = New-Remediation `
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -EnvFile .\infra\local\.env -EnvExample .\infra\local\.env.example -ComposeFile .\infra\local\docker-compose.yml -S3Client docker-mc -EnableRealMultipartEvidence" `
    ".github/workflows/durable-docker-ci.yml" `
    "gh workflow run durable-docker-ci.yml" `
    "Run the durable MVP finalizer on a Docker-ready machine, or dispatch Durable Docker CI, then import/retain .osmu-run/latest-release.json before regenerating operations readiness. The release report must be generated by the release gate and include the required scope flags."

Add-Check "Release report available" "release" ($releaseReport.exists -and $releaseReport.parsed) $releaseReport.detail $releaseReport.path "latest release report generated by the release gate" $releaseReportRemediation

Add-ScopeCheck $releaseReport "kubernetesManifests" "Kubernetes manifest draft" "static-infra" $releaseReportRemediation
Add-ScopeCheck $releaseReport "helmChart" "Helm chart draft" "static-infra" $releaseReportRemediation
Add-ScopeCheck $releaseReport "networkPolicies" "NetworkPolicy draft" "security-hardening" $releaseReportRemediation
Add-ScopeCheck $releaseReport "containerHardening" "Container hardening draft" "security-hardening" $releaseReportRemediation
Add-ScopeCheck $releaseReport "tlsIngress" "TLS ingress draft" "security-hardening" $releaseReportRemediation
Add-ScopeCheck $releaseReport "secretRotationPolicy" "Secret rotation policy draft" "security-hardening" $releaseReportRemediation
Add-ScopeCheck $releaseReport "backupRestoreDrill" "Backup restore drill draft" "backup-restore" $releaseReportRemediation
Add-ScopeCheck $releaseReport "prometheusObservability" "Prometheus observability draft" "monitoring" $releaseReportRemediation
Add-ScopeCheck $releaseReport "monitoringArtifacts" "Monitoring artifacts draft" "monitoring" $releaseReportRemediation
Add-ScopeCheck $releaseReport "prometheusOperatorDraft" "Prometheus Operator draft" "monitoring" $releaseReportRemediation
Add-ScopeCheck $releaseReport "imageSigningPolicy" "Image signing policy draft" "security-hardening" $releaseReportRemediation
Add-ScopeCheck $releaseReport "containerSecurityCiWorkflow" "Container security CI workflow draft" "security-hardening" $releaseReportRemediation

Add-FileCheck "IAM/RBAC matrix verifier" "iam-rbac" ".\scripts\verify-iam-rbac-matrix.ps1" "IAM/RBAC matrix verifier committed"
Add-FileCheck "IAM/RBAC matrix document" "iam-rbac" ".\dev-docs\iam-rbac-matrix.md" "IAM/RBAC matrix document committed"
Add-FileCheck "IAM/RBAC finalizer" "iam-rbac" ".\scripts\finalize-iam-rbac-readiness.ps1" "IAM/RBAC finalizer committed"
Add-FileCheck "IAM/RBAC finalizer self-test" "iam-rbac" ".\scripts\verify-iam-rbac-finalizer.ps1" "IAM/RBAC finalizer self-test committed"
Add-FileCheck "IAM/RBAC finalizer workflow" "iam-rbac" ".\.github\workflows\iam-rbac-finalizer-ci.yml" "manual workflow for IAM/RBAC finalizer evidence"
Add-FileCheck "Kubernetes RBAC matrix verifier" "kubernetes-rbac" ".\scripts\verify-kubernetes-rbac-matrix.ps1" "Kubernetes RBAC matrix verifier committed"
Add-FileCheck "Kubernetes RBAC matrix document" "kubernetes-rbac" ".\dev-docs\kubernetes-rbac-matrix.md" "Kubernetes RBAC matrix document committed"
Add-FileCheck "Storage expansion finalizer workflow" "automation" ".\.github\workflows\storage-expansion-finalizer-ci.yml" "manual workflow for storage expansion finalizer evidence"
Add-FileCheck "Kubernetes HA/DR readiness workflow" "ha-dr" ".\.github\workflows\kubernetes-ha-dr-readiness-ci.yml" "manual workflow for Kubernetes HA/DR readiness evidence"
Add-FileCheck "Kubernetes DR finalizer workflow" "automation" ".\.github\workflows\kubernetes-dr-finalizer-ci.yml" "manual workflow for Kubernetes DR finalizer evidence"
Add-FileCheck "Operations readiness finalizer workflow" "automation" ".\.github\workflows\operations-readiness-finalizer-ci.yml" "manual workflow for combined operations readiness evidence"
Add-FileCheck "Operations readiness finalizer" "automation" ".\scripts\finalize-operations-readiness.ps1" "combined operations readiness finalizer committed"
Add-FileCheck "Operations readiness finalizer self-test" "automation" ".\scripts\verify-operations-readiness-finalizer.ps1" "operations readiness finalizer plan self-test committed"
Add-FileCheck "Operations readiness artifact importer" "automation" ".\scripts\import-operations-readiness-artifacts.ps1" "artifact importer for previously collected evidence committed"
Add-FileCheck "Operations readiness artifact importer self-test" "automation" ".\scripts\verify-operations-readiness-artifact-import.ps1" "artifact importer self-test committed"
Add-FileCheck "Operations readiness artifact finalizer workflow" "automation" ".\.github\workflows\operations-readiness-artifact-finalizer-ci.yml" "manual workflow for importing evidence artifacts and writing readiness report"
Add-FileCheck "Container security evidence writer" "security-hardening" ".\scripts\write-container-security-evidence.ps1" "container security evidence writer committed"
Add-FileCheck "Image signing evidence writer" "security-hardening" ".\scripts\write-image-signing-evidence.ps1" "image signing evidence writer committed"
Add-FileCheck "Security evidence writer self-test" "security-hardening" ".\scripts\verify-security-evidence-writers.ps1" "security evidence writer self-test committed"
Add-FileCheck "Storage backend telemetry evidence writer" "storage-backend" ".\scripts\write-storage-backend-telemetry-evidence.ps1" "storage backend telemetry evidence writer committed"
Add-FileCheck "Storage backend telemetry evidence writer self-test" "storage-backend" ".\scripts\verify-storage-backend-telemetry-evidence.ps1" "storage backend telemetry evidence writer self-test committed"
Add-FileCheck "Storage backend telemetry evidence workflow" "storage-backend" ".\.github\workflows\manual-storage-backend-telemetry-evidence.yml" "manual workflow for storage backend telemetry evidence"
Add-FileCheck "MariaDB query plan evidence writer" "data-flow" ".\scripts\write-mariadb-query-plan-evidence.ps1" "MariaDB query plan evidence writer committed"
Add-FileCheck "MariaDB query plan evidence self-test" "data-flow" ".\scripts\verify-mariadb-query-plan-evidence.ps1" "MariaDB query plan evidence self-test committed"
Add-FileCheck "Data-flow storage plan writer" "data-flow" ".\scripts\write-data-flow-storage-plan.ps1" "data-flow storage transition plan writer committed"
Add-FileCheck "Data-flow storage plan self-test" "data-flow" ".\scripts\verify-data-flow-storage-plan.ps1" "data-flow storage transition plan self-test committed"
Add-FileCheck "Data-flow storage plan evidence workflow" "data-flow" ".\.github\workflows\manual-data-flow-storage-plan-evidence.yml" "manual workflow for target data-flow storage transition evidence"
Add-FileCheck "Data-flow query/retention budget writer" "data-flow" ".\scripts\write-data-flow-query-retention-budget-evidence.ps1" "data-flow query/retention budget evidence writer committed"
Add-FileCheck "Data-flow query/retention budget self-test" "data-flow" ".\scripts\verify-data-flow-query-retention-budget-evidence.ps1" "data-flow query/retention budget evidence self-test committed"
Add-FileCheck "Data-flow query/retention budget workflow" "data-flow" ".\.github\workflows\manual-data-flow-query-retention-budget-evidence.yml" "manual workflow for target data-flow query/retention budget evidence"
Add-FileCheck "Data-flow storage transition runbook writer" "data-flow" ".\scripts\write-data-flow-storage-transition-runbook-evidence.ps1" "data-flow storage transition runbook evidence writer committed"
Add-FileCheck "Data-flow storage transition runbook self-test" "data-flow" ".\scripts\verify-data-flow-storage-transition-runbook-evidence.ps1" "data-flow storage transition runbook evidence self-test committed"
Add-FileCheck "Data-flow storage transition runbook workflow" "data-flow" ".\.github\workflows\manual-data-flow-storage-transition-runbook-evidence.yml" "manual workflow for target data-flow storage transition runbook evidence"
Add-FileCheck "Monitoring threshold evidence writer" "monitoring" ".\scripts\write-monitoring-threshold-evidence.ps1" "monitoring threshold evidence writer committed"
Add-FileCheck "Monitoring threshold evidence writer self-test" "monitoring" ".\scripts\verify-monitoring-threshold-evidence.ps1" "monitoring threshold evidence writer self-test committed"
Add-FileCheck "Monitoring threshold evidence workflow" "monitoring" ".\.github\workflows\manual-monitoring-threshold-evidence.yml" "manual workflow for target monitoring threshold evidence"
Add-FileCheck "Secret rotation evidence writer" "security-hardening" ".\scripts\write-secret-rotation-evidence.ps1" "secret rotation evidence writer committed"
Add-FileCheck "Secret rotation evidence writer self-test" "security-hardening" ".\scripts\verify-secret-rotation-evidence.ps1" "secret rotation evidence writer self-test committed"
Add-FileCheck "Secret rotation evidence workflow" "security-hardening" ".\.github\workflows\manual-secret-rotation-evidence.yml" "manual workflow for target secret/certificate rotation evidence"
Add-FileCheck "Cluster network access review evidence writer" "security-hardening" ".\scripts\write-cluster-network-access-review-evidence.ps1" "cluster network access review evidence writer committed"
Add-FileCheck "Cluster network access review evidence writer self-test" "security-hardening" ".\scripts\verify-cluster-network-access-review-evidence.ps1" "cluster network access review evidence writer self-test committed"
Add-FileCheck "Cluster network access review evidence workflow" "security-hardening" ".\.github\workflows\manual-cluster-network-access-review-evidence.yml" "manual workflow for target cluster network access review evidence"
Add-FileCheck "Helm values hardening evidence writer" "security-hardening" ".\scripts\write-helm-values-hardening-evidence.ps1" "Helm values hardening evidence writer committed"
Add-FileCheck "Helm values hardening evidence writer self-test" "security-hardening" ".\scripts\verify-helm-values-hardening-evidence.ps1" "Helm values hardening evidence writer self-test committed"
Add-FileCheck "Helm values hardening evidence workflow" "security-hardening" ".\.github\workflows\manual-helm-values-hardening-evidence.yml" "manual workflow for target Helm values hardening evidence"
Add-FileCheck "Commercial integration evidence writer" "commercial-integration" ".\scripts\write-commercial-integration-evidence.ps1" "commercial integration evidence writer committed"
Add-FileCheck "Commercial integration evidence writer self-test" "commercial-integration" ".\scripts\verify-commercial-integration-evidence.ps1" "commercial integration evidence writer self-test committed"
Add-FileCheck "Commercial integration evidence workflow" "commercial-integration" ".\.github\workflows\manual-commercial-integration-evidence.yml" "manual workflow for target notification/payment handoff evidence"
Add-FileCheck "Commercial approval evidence writer" "commercial-approval" ".\scripts\write-commercial-approval-evidence.ps1" "commercial approval evidence writer committed"
Add-FileCheck "Commercial approval evidence writer self-test" "commercial-approval" ".\scripts\verify-commercial-approval-evidence.ps1" "commercial approval evidence writer self-test committed"
Add-FileCheck "Commercial approval evidence workflow" "commercial-approval" ".\.github\workflows\manual-commercial-approval-evidence.yml" "manual workflow for final commercial approval evidence"
Add-FileCheck "Chargeback closeout evidence writer" "chargeback-closeout" ".\scripts\write-chargeback-closeout-evidence.ps1" "chargeback closeout evidence writer committed"
Add-FileCheck "Chargeback closeout evidence writer self-test" "chargeback-closeout" ".\scripts\verify-chargeback-closeout-evidence.ps1" "chargeback closeout evidence writer self-test committed"
Add-FileCheck "Operations handoff package writer" "operations-handoff-package" ".\scripts\write-operations-handoff-package.ps1" "operations handoff package writer committed"
Add-FileCheck "Operations handoff package writer self-test" "operations-handoff-package" ".\scripts\verify-operations-handoff-package.ps1" "operations handoff package writer self-test committed"
Add-FileCheck "Operations handoff package workflow" "operations-handoff-package" ".\.github\workflows\manual-operations-handoff-package.yml" "manual workflow for target operations handoff package evidence"
Add-FileCheck "Support escalation handoff evidence writer" "operations-handoff-package" ".\scripts\write-support-escalation-handoff-evidence.ps1" "support escalation handoff evidence writer committed"
Add-FileCheck "Support escalation handoff evidence writer self-test" "operations-handoff-package" ".\scripts\verify-support-escalation-handoff-evidence.ps1" "support escalation handoff evidence writer self-test committed"
Add-FileCheck "Support escalation handoff evidence workflow" "operations-handoff-package" ".\.github\workflows\manual-support-escalation-handoff-evidence.yml" "manual workflow for support escalation handoff evidence"
Add-FileCheck "Security evidence finalizer" "security-hardening" ".\scripts\finalize-security-evidence.ps1" "security evidence finalizer committed"
Add-FileCheck "Security evidence finalizer self-test" "security-hardening" ".\scripts\verify-security-evidence-finalizer.ps1" "security evidence finalizer self-test committed"
Add-FileCheck "Security evidence finalizer workflow" "security-hardening" ".\.github\workflows\security-evidence-finalizer-ci.yml" "manual workflow for security evidence finalizer artifact promotion"
Add-FileCheck "Enterprise auth smoke workflow" "enterprise-auth" ".\.github\workflows\enterprise-auth-smoke-ci.yml" "manual workflow for target IdP/directory enterprise auth smoke evidence"
Add-FileCheck "Enterprise auth smoke evidence helper" "enterprise-auth" ".\scripts\write-enterprise-auth-smoke-plan.ps1" "enterprise auth smoke helper committed"
Add-FileCheck "Enterprise auth smoke evidence helper self-test" "enterprise-auth" ".\scripts\verify-enterprise-auth-smoke-plan.ps1" "enterprise auth smoke helper self-test committed"
Add-FileCheck "Enterprise auth JIT rollback workflow" "enterprise-auth" ".\.github\workflows\manual-enterprise-auth-jit-rollback-evidence.yml" "manual workflow for admin-approved enterprise auth JIT rollback evidence"
Add-FileCheck "Enterprise auth JIT rollback evidence helper" "enterprise-auth" ".\scripts\write-enterprise-auth-jit-rollback-evidence.ps1" "enterprise auth JIT rollback helper committed"
Add-FileCheck "Enterprise auth JIT rollback evidence helper self-test" "enterprise-auth" ".\scripts\verify-enterprise-auth-jit-rollback-evidence.ps1" "enterprise auth JIT rollback helper self-test committed"

Add-Check "Storage expansion finalizer live evidence" "storage-expansion" ($storageExpansionReport.exists -and $storageExpansionReport.parsed -and $storageExpansionReport.data.result -eq "passed") (Get-StorageExpansionDetail $storageExpansionReport) $storageExpansionReport.path "finalizer result=passed from target cluster" $storageExpansionRemediation
Add-Check "Kubernetes HA/DR readiness live evidence" "ha-dr" ($haDrReadinessReport.exists -and $haDrReadinessReport.parsed -and $haDrReadinessReport.data.result -eq "passed") (Get-HaDrReadinessDetail $haDrReadinessReport) $haDrReadinessReport.path "live Kubernetes HA/DR readiness result=passed" $haDrReadinessRemediation
Add-Check "Kubernetes DR finalizer live evidence" "ha-dr" ($kubernetesDrReport.exists -and $kubernetesDrReport.parsed -and $kubernetesDrReport.data.result -eq "ready") (Get-KubernetesDrFinalizeDetail $kubernetesDrReport) $kubernetesDrReport.path "finalizer result=ready from target cluster restore drill" $kubernetesDrRemediation
Add-Check "IAM/RBAC finalizer report" "iam-rbac" ($iamRbacFinalizeReport.exists -and $iamRbacFinalizeReport.parsed -and $iamRbacFinalizeReport.data.result -eq "passed") (Get-GenericResultDetail $iamRbacFinalizeReport) $iamRbacFinalizeReport.path "IAM/RBAC finalizer result=passed"
Add-Check "Security evidence finalizer report" "security-hardening" ($securityFinalizeReport.exists -and $securityFinalizeReport.parsed -and $securityFinalizeReport.data.result -eq "passed") (Get-GenericResultDetail $securityFinalizeReport) $securityFinalizeReport.path "security evidence finalizer result=passed from promoted CI artifacts after strict image signing and container SBOM import validation" $securityFinalizeRemediation
Add-Check "Signed image evidence" "security-hardening" ($imageSigningReport.exists -and $imageSigningReport.parsed -and $imageSigningReport.data.result -eq "passed") (Get-GenericResultDetail $imageSigningReport) $imageSigningReport.path "published image digest and GitHub OIDC keyless Cosign verification evidence for release-version and commit-SHA tags" $imageSigningRemediation
Add-Check "Container scan/SBOM evidence" "security-hardening" ($containerSecurityReport.exists -and $containerSecurityReport.parsed -and $containerSecurityReport.data.result -eq "passed") (Get-GenericResultDetail $containerSecurityReport) $containerSecurityReport.path "successful Trivy CRITICAL,HIGH scan, commit-SHA image tag, and backend/frontend SPDX SBOM artifact evidence" $containerSecurityRemediation
Add-Check "Storage backend telemetry target evidence" "storage-backend" (Test-PassedTargetEvidence $storageBackendTelemetryReport) (Add-TargetEvidenceGuardDetail $storageBackendTelemetryReport (Get-StorageBackendTelemetryDetail $storageBackendTelemetryReport)) $storageBackendTelemetryReport.path "storage backend telemetry result=passed from target MinIO admin info evidence" $storageBackendTelemetryRemediation
Add-Check "Data-flow storage transition target evidence" "data-flow" (Test-DataFlowStoragePlanEvidenceAccepted $dataFlowStoragePlanReport) (Add-TargetEvidenceGuardDetail $dataFlowStoragePlanReport (Get-DataFlowStoragePlanDetail $dataFlowStoragePlanReport)) $dataFlowStoragePlanReport.path "data-flow storage transition plan result=passed with target p95 query latency budget and target query-plan evidence for MariaDB partition or dual-write candidates" $dataFlowStoragePlanRemediation
Add-Check "Data-flow query/retention budget target evidence" "data-flow" (Test-DataFlowQueryRetentionBudgetEvidenceAccepted $dataFlowQueryRetentionBudgetReport) (Add-TargetEvidenceGuardDetail $dataFlowQueryRetentionBudgetReport (Get-DataFlowQueryRetentionBudgetDetail $dataFlowQueryRetentionBudgetReport)) $dataFlowQueryRetentionBudgetReport.path "data-flow query/retention budget evidence result=passed with observed p95 query latency and detailed/daily/monthly retention jobs within target budget" $dataFlowQueryRetentionBudgetRemediation
Add-Check "Data-flow storage transition runbook target evidence" "data-flow" (Test-DataFlowStorageTransitionRunbookEvidenceAccepted $dataFlowStorageTransitionRunbookReport) (Add-TargetEvidenceGuardDetail $dataFlowStorageTransitionRunbookReport (Get-DataFlowStorageTransitionRunbookDetail $dataFlowStorageTransitionRunbookReport)) $dataFlowStorageTransitionRunbookReport.path "data-flow storage transition runbook result=passed with target backfill, toggle, rollback, reconciliation, dashboard cutover, retention dry-run, no-object-key, and no-secret confirmations" $dataFlowStorageTransitionRunbookRemediation
Add-Check "Monitoring threshold target evidence" "monitoring" (Test-PassedTargetEvidence $monitoringThresholdReport) (Add-TargetEvidenceGuardDetail $monitoringThresholdReport (Get-GenericResultDetail $monitoringThresholdReport)) $monitoringThresholdReport.path "monitoring threshold evidence result=passed from target Prometheus/Grafana/Alertmanager/tenant baseline review" $monitoringThresholdRemediation
Add-Check "Secret/certificate rotation target evidence" "security-hardening" (Test-PassedTargetEvidence $secretRotationReport) (Add-TargetEvidenceGuardDetail $secretRotationReport (Get-GenericResultDetail $secretRotationReport)) $secretRotationReport.path "secret/certificate rotation evidence result=passed from target environment" $secretRotationRemediation
Add-Check "Commercial integration target evidence" "commercial-integration" (Test-PassedTargetEvidence $commercialIntegrationReport) (Add-TargetEvidenceGuardDetail $commercialIntegrationReport (Get-GenericResultDetail $commercialIntegrationReport)) $commercialIntegrationReport.path "commercial integration evidence result=passed from target environment" $commercialIntegrationRemediation
Add-Check "Commercial approval target evidence" "commercial-approval" (Test-PassedTargetEvidence $commercialApprovalReport) (Add-TargetEvidenceGuardDetail $commercialApprovalReport (Get-GenericResultDetail $commercialApprovalReport)) $commercialApprovalReport.path "commercial approval evidence result=passed for final pricing, terms, support SLA, license agreement, legal approval, and pilot contract boundary" $commercialApprovalRemediation
Add-Check "Chargeback closeout target evidence" "chargeback-closeout" (Test-PassedTargetEvidence $chargebackCloseoutReport) (Add-TargetEvidenceGuardDetail $chargebackCloseoutReport (Get-ChargebackCloseoutDetail $chargebackCloseoutReport)) $chargebackCloseoutReport.path "chargeback closeout evidence result=passed for target billing period pricing, usage, invoice, payment handoff, notification, retry, reconciliation, commercial integration, and commercial approval review" $chargebackCloseoutRemediation
Add-Check "Enterprise auth target smoke evidence" "enterprise-auth" (Test-EnterpriseAuthEvidenceAccepted $enterpriseAuthSmokeReport) (Add-TargetEvidenceGuardDetail $enterpriseAuthSmokeReport (Get-EnterpriseAuthEvidenceDetail $enterpriseAuthSmokeReport)) $enterpriseAuthSmokeReport.path "enterprise auth smoke result=passed from target IdP/directory, or result=scope-out with explicit commercial approval reference and reason" $enterpriseAuthSmokeRemediation
Add-Check "Enterprise auth JIT rollback target evidence" "enterprise-auth" (Test-EnterpriseAuthJitRollbackRequirementSatisfied $enterpriseAuthJitRollbackReport $enterpriseAuthSmokeReport) (Add-TargetEvidenceGuardDetail $enterpriseAuthJitRollbackReport (Get-EnterpriseAuthJitRollbackEvidenceDetail $enterpriseAuthJitRollbackReport $enterpriseAuthSmokeReport)) $enterpriseAuthJitRollbackReport.path "enterprise auth smoke result=passed requires target admin-approved JIT rollback result=passed; accepted scope-out makes JIT rollback not required" $enterpriseAuthJitRollbackRemediation
Add-Check "Operations handoff package target evidence" "operations-handoff-package" $operationsHandoffPackageValidation.passed $operationsHandoffPackageValidation.detail $operationsHandoffPackageReport.path "operations handoff package result=passed from target environment with required handoff review/production/snapshot confirmations" $operationsHandoffPackageRemediation
Add-Check "Cluster network access review target evidence" "security-hardening" (Test-PassedTargetEvidence $clusterNetworkAccessReviewReport) (Add-TargetEvidenceGuardDetail $clusterNetworkAccessReviewReport (Get-GenericResultDetail $clusterNetworkAccessReviewReport)) $clusterNetworkAccessReviewReport.path "cluster network access review result=passed with Kubernetes/Helm NetworkPolicy hashes, target access review references, and no-credential confirmations" $clusterNetworkAccessReviewRemediation
Add-Check "Helm values hardening target evidence" "security-hardening" (Test-PassedTargetEvidence $helmValuesHardeningReport) (Add-TargetEvidenceGuardDetail $helmValuesHardeningReport (Get-GenericResultDetail $helmValuesHardeningReport)) $helmValuesHardeningReport.path "Helm values hardening result=passed with externalized secrets, HA/resource/security/network/TLS/read-only mount, and storage expansion RBAC defaults reviewed" $helmValuesHardeningRemediation

$passedCount = @($checks | Where-Object { $_.passed }).Count
$pendingCount = @($checks | Where-Object { -not $_.passed }).Count
$totalCount = @($checks).Count
$pendingCategoryCounts = @(Get-PendingCategoryCounts $checks)
$pendingCategorySummary = Format-PendingCategorySummary $pendingCategoryCounts
$pendingRemediations = @(
    $checks |
        Where-Object { -not $_.passed } |
        ForEach-Object {
            $remediation = $_.remediation
            [ordered]@{
                name = $_.name
                category = $_.category
                evidencePath = $_.evidencePath
                requiredEvidence = $_.requiredEvidence
                detail = $_.detail
                command = if ($null -ne $remediation) { [string] $remediation.command } else { "" }
                workflow = if ($null -ne $remediation) { [string] $remediation.workflow } else { "" }
                workflowCommand = if ($null -ne $remediation) { [string] $remediation.workflowCommand } else { "" }
                note = if ($null -ne $remediation) { [string] $remediation.note } else { "" }
            }
        }
)
$pendingRemediationCount = @($pendingRemediations).Count
$result = if ($pendingCount -eq 0) { "ready" } else { "pending" }
$generatedAt = [DateTimeOffset]::Now.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath

$report = [ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    generatedAt = $generatedAt
    result = $result
    passedCount = $passedCount
    pendingCount = $pendingCount
    totalCount = $totalCount
    checkCount = $totalCount
    summary = "passed=$passedCount pending=$pendingCount"
    pendingCategorySummary = $pendingCategorySummary
    pendingCategoryCounts = $pendingCategoryCounts
    pendingRemediationCount = $pendingRemediationCount
    pendingRemediations = $pendingRemediations
    inputs = [ordered]@{
        releaseReport = $releaseReport.path
        storageExpansionFinalizeReport = $storageExpansionReport.path
        kubernetesHaDrReadinessReport = $haDrReadinessReport.path
        kubernetesDrFinalizeReport = $kubernetesDrReport.path
        iamRbacFinalizeReport = $iamRbacFinalizeReport.path
        securityEvidenceFinalizeReport = $securityFinalizeReport.path
        imageSigningEvidence = $imageSigningReport.path
        containerSecurityEvidence = $containerSecurityReport.path
        storageBackendTelemetryEvidence = $storageBackendTelemetryReport.path
        dataFlowStoragePlan = $dataFlowStoragePlanReport.path
        dataFlowQueryRetentionBudgetEvidence = $dataFlowQueryRetentionBudgetReport.path
        dataFlowStorageTransitionRunbookEvidence = $dataFlowStorageTransitionRunbookReport.path
        monitoringThresholdEvidence = $monitoringThresholdReport.path
        secretRotationEvidence = $secretRotationReport.path
        commercialIntegrationEvidence = $commercialIntegrationReport.path
        commercialApprovalEvidence = $commercialApprovalReport.path
        chargebackCloseoutEvidence = $chargebackCloseoutReport.path
        enterpriseAuthSmokeEvidence = $enterpriseAuthSmokeReport.path
        enterpriseAuthJitRollbackEvidence = $enterpriseAuthJitRollbackReport.path
        clusterNetworkAccessReviewEvidence = $clusterNetworkAccessReviewReport.path
        helmValuesHardeningEvidence = $helmValuesHardeningReport.path
        operationsHandoffPackage = $operationsHandoffPackageReport.path
    }
    checks = $checks
    decisionRule = "Production/B2B operations readiness is ready only when every listed static, automation, live Kubernetes, storage expansion, storage backend telemetry, data-flow storage transition plan, data-flow query/retention budget, data-flow storage transition runbook, monitoring threshold, HA/DR, security, secret rotation, commercial integration, chargeback closeout, commercial approval, enterprise auth smoke/JIT rollback, operations handoff package, cluster network access review, and Helm values hardening evidence checks are PASS."
}

$markdownLines = @(
    "# OSMU Operations Readiness",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Summary: passed=$passedCount pending=$pendingCount",
    "Total checks: $totalCount",
    "Pending categories: $pendingCategorySummary",
    "Pending remediation entries: $pendingRemediationCount",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Checks",
    ""
)

foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.category) / $($check.name): $($check.detail)"
}

$markdownLines += ""
$markdownLines += "## Required Next Evidence"
$markdownLines += ""
foreach ($check in ($checks | Where-Object { -not $_.passed })) {
    $markdownLines += "- $($check.name): $($check.requiredEvidence); path=$($check.evidencePath)"
    $remediation = $check.remediation
    if ($null -ne $remediation) {
        if (-not [string]::IsNullOrWhiteSpace([string] $remediation.command)) {
            $markdownLines += "  - Remediation command: ``$($remediation.command)``"
        }
        if (-not [string]::IsNullOrWhiteSpace([string] $remediation.workflow)) {
            $markdownLines += "  - Workflow: ``$($remediation.workflow)``"
        }
        if (-not [string]::IsNullOrWhiteSpace([string] $remediation.workflowCommand)) {
            $markdownLines += "  - Workflow command: ``$($remediation.workflowCommand)``"
        }
        if (-not [string]::IsNullOrWhiteSpace([string] $remediation.note)) {
            $markdownLines += "  - Note: $($remediation.note)"
        }
    }
}

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations readiness JSON: $resolvedJsonOutputPath"
    Write-Host "Operations readiness summary: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotReady -and $result -ne "ready") {
    throw "Operations readiness is not ready: $($report.summary)"
}
