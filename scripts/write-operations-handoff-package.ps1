param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $HandoffStartedAt = "",
    [string] $HandoffCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $DeploymentEvidenceRef = "",
    [string] $OperationsReadinessRef = "",
    [string] $OperationsConvergenceRef = "",
    [string] $DataFlowStoragePlanEvidenceRef = "",
    [string] $OperationsReadinessJsonPath = "",
    [string] $OperationsConvergenceJsonPath = "",
    [string] $DataFlowStoragePlanJsonPath = "",
    [string] $SecretRotationEvidenceRef = "",
    [string] $CommercialIntegrationEvidenceRef = "",
    [string] $CommercialApprovalEvidenceRef = "",
    [string] $EnterpriseAuthEvidenceRef = "",
    [string] $BackupRestoreEvidenceRef = "",
    [string] $HaDrEvidenceRef = "",
    [string] $MonitoringEvidenceRef = "",
    [string] $SecurityEvidenceRef = "",
    [string] $IamRbacEvidenceRef = "",
    [string] $RunbookReviewRef = "",
    [string] $TroubleshootingReviewRef = "",
    [string] $SupportEscalationRef = "",
    [string] $SupportSlaRef = "",
    [string] $KnownGapsRef = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-handoff-package.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-handoff-package.md",
    [switch] $ConfirmRunbookReviewed,
    [switch] $ConfirmTroubleshootingReviewed,
    [switch] $ConfirmRollbackReviewed,
    [switch] $ConfirmSupportEscalationReviewed,
    [switch] $ConfirmKnownGapsAccepted,
    [switch] $ConfirmOperationsReadinessSnapshotReviewed,
    [switch] $ConfirmOperationsConvergenceSnapshotReviewed,
    [switch] $ConfirmDataFlowStoragePlanReviewed,
    [switch] $ConfirmNoSecretValues,
    [switch] $RequireProductionEvidence,
    [switch] $RequireOperationsSnapshotEvidence,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-SafeText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "(?i)\b(password|passwd|secret|token|client_secret|x-amz-security-token|smtp_pass|webhook_secret|kubeconfig)\s*[=:]\s*\S+",
        "(?i)""?(password|passwd|secret|token|client_secret|x-amz-security-token|smtp_pass|webhook_secret|kubeconfig)""?\s*[:=]\s*""?[^""\s,}]+"
    )

    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain credential material. Store only a sanitized evidence reference or summary snapshot."
        }
    }
}

function Assert-SafeReference([string] $Value, [string] $Label) {
    Assert-SafeText $Value $Label
}

function Assert-SanitizedOperationsSnapshotJson([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $forbiddenPropertyPattern = '(?i)"(rawProviderResponse|raw_provider_response|providerResponse|provider_response|responseBody|response_body|responseHeaders|response_headers|customerData|customer_data|customerEmail|customer_email|customerName|customer_name|customerPaymentData|customer_payment_data|cardNumber|card_number|bankAccount|bank_account|rawContractText|raw_contract_text|contractText|contract_text|licenseKey|license_key|rawRemediation|raw_remediation|rawCommand|raw_command)"\s*:'
    if ($Value -match $forbiddenPropertyPattern) {
        throw "$Label appears to contain raw remediation, provider, customer, contract, license, or payment content. Store only sanitized operations snapshot summary fields."
    }
}

function Assert-SanitizedDataFlowStoragePlanJson([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $forbiddenPropertyPattern = '(?i)"(sql|rawSql|raw_sql|explain|explainJson|explain_json|rawExplain|raw_explain|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:'
    $credentialPattern = '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key)\s*=\s*\S+'
    $rawSqlPattern = '(?i)\bSELECT\b[\s\S]{0,200}\bFROM\b'
    if ($Value -match $forbiddenPropertyPattern -or $Value -match $credentialPattern -or $Value -match $rawSqlPattern) {
        throw "$Label appears to contain raw SQL, raw EXPLAIN, or credential-shaped content. Store only sanitized data-flow storage plan summary fields."
    }
}

function Test-DateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse($Value, [ref] $parsed)
}

function Get-ParsedDateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($Value, [ref] $parsed)) {
        return $parsed
    }
    return $null
}

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail, [string] $EvidenceRef) {
    return [ordered]@{
        id = $Id
        name = $Name
        status = $Status
        passed = $Status -eq "PASS"
        detail = $Detail
        evidenceRef = $EvidenceRef
    }
}

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail, [string] $EvidenceRef = "") {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    [void] $script:checks.Add((New-Check $Id $Name $status $Detail $EvidenceRef))
}

function Add-PlannedCheck([string] $Id, [string] $Name, [string] $Detail, [string] $EvidenceRef = "") {
    [void] $script:checks.Add((New-Check $Id $Name "PLANNED" $Detail $EvidenceRef))
}

function Add-EvidenceCheck([string] $Id, [string] $Name, [bool] $Required, [string] $EvidenceRef, [string] $Detail) {
    if ($Required) {
        Add-Check $Id $Name (-not [string]::IsNullOrWhiteSpace($EvidenceRef)) "$Detail; required=true; evidenceRef=$EvidenceRef" $EvidenceRef
    }
    elseif (-not [string]::IsNullOrWhiteSpace($EvidenceRef)) {
        Add-Check $Id $Name $true "$Detail; required=false; evidenceRef=$EvidenceRef" $EvidenceRef
    }
    else {
        Add-PlannedCheck $Id "$Name planned" "$Detail; required=false; no target evidence recorded." $EvidenceRef
    }
}

function Get-PropertyValue([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-PropertyText([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Get-PropertyBool([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return $false
    }
    if ($value -is [bool]) {
        return [bool] $value
    }
    return ([string] $value).Equals("true", [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-PropertyInt([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return 0
    }
    $parsed = 0
    if ([int]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return 0
}

function Get-PropertyArray([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return @()
    }
    if ($value -is [System.Array]) {
        return @($value)
    }
    return @($value)
}

function Read-JsonPayload([string] $Path, [string] $Label, [string] $MissingDetail) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        payload = $null
        detail = $MissingDetail
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $snapshot
    }

    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "$Label JSON not found."
        return $snapshot
    }

    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    Assert-SafeText $raw "${Label}Json"
    Assert-SanitizedOperationsSnapshotJson $raw "${Label}Json"
    try {
        $snapshot["payload"] = $raw | ConvertFrom-Json
        $snapshot["parsed"] = $true
        $snapshot["detail"] = "JSON parsed."
    }
    catch {
        $snapshot["detail"] = "$Label JSON parse failed: $($_.Exception.Message)"
    }
    return $snapshot
}

function New-CheckSnapshotRow([object] $Check) {
    return [ordered]@{
        name = Get-PropertyText $Check "name"
        category = Get-PropertyText $Check "category"
        status = Get-PropertyText $Check "status"
        passed = Get-PropertyBool $Check "passed"
        detail = Get-PropertyText $Check "detail"
        evidencePath = Get-PropertyText $Check "evidencePath"
        requiredEvidence = Get-PropertyText $Check "requiredEvidence"
    }
}

function New-DataFlowStoragePlanCheckSnapshotRow([object] $Check) {
    return [ordered]@{
        id = Get-PropertyText $Check "id"
        title = Get-PropertyText $Check "title"
        status = Get-PropertyText $Check "status"
        detail = Get-PropertyText $Check "detail"
        nextAction = Get-PropertyText $Check "nextAction"
    }
}

function New-QueryPlanFailedCheckSnapshotRow([object] $Check) {
    return [ordered]@{
        id = Get-PropertyText $Check "id"
        table = Get-PropertyText $Check "table"
        queryPath = Get-PropertyText $Check "queryPath"
        expectedIndex = Get-PropertyText $Check "expectedIndex"
        status = Get-PropertyText $Check "status"
        usesExpectedIndex = Get-PropertyBool $Check "usesExpectedIndex"
    }
}

function New-QueryPlanEvidenceSummarySnapshot([object] $QueryPlanEvidence) {
    if ($null -eq $QueryPlanEvidence) {
        return $null
    }

    $failedRows = New-Object System.Collections.Generic.List[object]
    foreach ($failedCheck in @(Get-PropertyArray $QueryPlanEvidence "failedChecks")) {
        [void] $failedRows.Add((New-QueryPlanFailedCheckSnapshotRow $failedCheck))
        if ($failedRows.Count -ge 5) {
            break
        }
    }

    return [ordered]@{
        provided = Get-PropertyBool $QueryPlanEvidence "provided"
        formatVersion = Get-PropertyText $QueryPlanEvidence "formatVersion"
        expectedFormatVersion = Get-PropertyText $QueryPlanEvidence "expectedFormatVersion"
        validFormatVersion = Get-PropertyBool $QueryPlanEvidence "validFormatVersion"
        result = Get-PropertyText $QueryPlanEvidence "result"
        mode = Get-PropertyText $QueryPlanEvidence "mode"
        checkCount = Get-PropertyInt $QueryPlanEvidence "checkCount"
        passedCount = Get-PropertyInt $QueryPlanEvidence "passedCount"
        failedCount = Get-PropertyInt $QueryPlanEvidence "failedCount"
        failedChecks = @($failedRows.ToArray())
        detail = Get-PropertyText $QueryPlanEvidence "detail"
    }
}

function Read-DataFlowStoragePlanSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.data-flow-storage-plan.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        candidateStore = ""
        expectedPeakEventsPerDay = 0
        expectedQueryWindowDays = 0
        eventRetentionDays = 0
        dailyRollupRetentionDays = 0
        monthlyRollupRetentionMonths = 0
        checkCount = 0
        passedCount = 0
        pendingCount = 0
        queryPlanEvidence = $null
        topPendingChecks = @()
        detail = "No data-flow storage plan JSON supplied."
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $snapshot
    }

    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "Data-flow storage plan JSON not found."
        return $snapshot
    }

    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    Assert-SafeText $raw "DataFlowStoragePlanJson"
    Assert-SanitizedOperationsSnapshotJson $raw "DataFlowStoragePlanJson"
    Assert-SanitizedDataFlowStoragePlanJson $raw "DataFlowStoragePlanJson"
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $snapshot["detail"] = "Data-flow storage plan JSON parse failed: $($_.Exception.Message)"
        return $snapshot
    }

    $checks = @(Get-PropertyArray $payload "checks")
    $pendingRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        $status = Get-PropertyText $check "status"
        if (-not "passed".Equals($status, [System.StringComparison]::OrdinalIgnoreCase)) {
            [void] $pendingRows.Add((New-DataFlowStoragePlanCheckSnapshotRow $check))
        }
        if ($pendingRows.Count -ge 5) {
            break
        }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $snapshot["parsed"] = $true
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["environmentName"] = Get-PropertyText $payload "environmentName"
    $snapshot["targetCluster"] = Get-PropertyText $payload "targetCluster"
    $snapshot["candidateStore"] = Get-PropertyText $payload "candidateStore"
    $snapshot["expectedPeakEventsPerDay"] = Get-PropertyInt $payload "expectedPeakEventsPerDay"
    $snapshot["expectedQueryWindowDays"] = Get-PropertyInt $payload "expectedQueryWindowDays"
    $snapshot["eventRetentionDays"] = Get-PropertyInt $payload "eventRetentionDays"
    $snapshot["dailyRollupRetentionDays"] = Get-PropertyInt $payload "dailyRollupRetentionDays"
    $snapshot["monthlyRollupRetentionMonths"] = Get-PropertyInt $payload "monthlyRollupRetentionMonths"
    $snapshot["checkCount"] = Get-PropertyInt $payload "checkCount"
    $snapshot["passedCount"] = Get-PropertyInt $payload "passedCount"
    $snapshot["pendingCount"] = Get-PropertyInt $payload "pendingCount"
    $snapshot["queryPlanEvidence"] = New-QueryPlanEvidenceSummarySnapshot (Get-PropertyValue $payload "queryPlanEvidence")
    $snapshot["topPendingChecks"] = @($pendingRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; candidateStore=$($snapshot["candidateStore"]); pending=$($snapshot["pendingCount"]); checks=$($snapshot["checkCount"])"
    return $snapshot
}

function Read-OperationsReadinessSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.operations-readiness.v1"
        validFormatVersion = $false
        result = ""
        ready = $false
        summary = ""
        passedCount = 0
        pendingCount = 0
        checkCount = 0
        topPendingChecks = @()
        detail = "No operations readiness JSON supplied."
    }

    $payloadResult = Read-JsonPayload $Path "OperationsReadiness" $snapshot["detail"]
    $snapshot["provided"] = [bool] $payloadResult["provided"]
    $snapshot["path"] = [string] $payloadResult["path"]
    $snapshot["parsed"] = [bool] $payloadResult["parsed"]
    if (-not $snapshot["parsed"]) {
        $snapshot["detail"] = [string] $payloadResult["detail"]
        return $snapshot
    }

    $payload = $payloadResult["payload"]
    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $checks = @(Get-PropertyArray $payload "checks")
    $pendingRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $pendingRows.Add((New-CheckSnapshotRow $check))
        }
        if ($pendingRows.Count -ge 5) {
            break
        }
    }

    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["ready"] = "ready".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["summary"] = Get-PropertyText $payload "summary"
    $snapshot["passedCount"] = Get-PropertyInt $payload "passedCount"
    $snapshot["pendingCount"] = Get-PropertyInt $payload "pendingCount"
    $snapshot["checkCount"] = $checks.Count
    $snapshot["topPendingChecks"] = @($pendingRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; passed=$($snapshot["passedCount"]); pending=$($snapshot["pendingCount"]); checks=$($snapshot["checkCount"])"
    return $snapshot
}

function Read-OperationsConvergenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.operations-readiness-convergence.v1"
        validFormatVersion = $false
        result = ""
        ready = $false
        readinessResult = ""
        readinessSummary = ""
        finalizerResult = ""
        finalizerReadinessResult = ""
        kubernetesReportSyncReady = $false
        kubernetesReportSyncResult = ""
        kubernetesReportSyncFailedCount = 0
        stageCount = 0
        readyStageCount = 0
        finalizerGapCount = 0
        currentBottleneckCode = ""
        currentBottleneckTitle = ""
        recommendedCommandCount = 0
        detail = "No operations readiness convergence JSON supplied."
    }

    $payloadResult = Read-JsonPayload $Path "OperationsReadinessConvergence" $snapshot["detail"]
    $snapshot["provided"] = [bool] $payloadResult["provided"]
    $snapshot["path"] = [string] $payloadResult["path"]
    $snapshot["parsed"] = [bool] $payloadResult["parsed"]
    if (-not $snapshot["parsed"]) {
        $snapshot["detail"] = [string] $payloadResult["detail"]
        return $snapshot
    }

    $payload = $payloadResult["payload"]
    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $currentBottleneck = Get-PropertyValue $payload "currentBottleneck"
    $recommendedCommands = @(Get-PropertyArray $payload "recommendedCommands")

    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["ready"] = "ready".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["readinessResult"] = Get-PropertyText $payload "readinessResult"
    $snapshot["readinessSummary"] = Get-PropertyText $payload "readinessSummary"
    $snapshot["finalizerResult"] = Get-PropertyText $payload "finalizerResult"
    $snapshot["finalizerReadinessResult"] = Get-PropertyText $payload "finalizerReadinessResult"
    $snapshot["kubernetesReportSyncReady"] = Get-PropertyBool $payload "kubernetesReportSyncReady"
    $snapshot["kubernetesReportSyncResult"] = Get-PropertyText $payload "kubernetesReportSyncResult"
    $snapshot["kubernetesReportSyncFailedCount"] = Get-PropertyInt $payload "kubernetesReportSyncFailedCount"
    $snapshot["stageCount"] = Get-PropertyInt $payload "stageCount"
    $snapshot["readyStageCount"] = Get-PropertyInt $payload "readyStageCount"
    $snapshot["finalizerGapCount"] = Get-PropertyInt $payload "finalizerGapCount"
    $snapshot["currentBottleneckCode"] = Get-PropertyText $currentBottleneck "code"
    $snapshot["currentBottleneckTitle"] = Get-PropertyText $currentBottleneck "title"
    $snapshot["recommendedCommandCount"] = $recommendedCommands.Count
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; readinessResult=$($snapshot["readinessResult"]); kubernetesReportSyncReady=$($snapshot["kubernetesReportSyncReady"]); finalizerGaps=$($snapshot["finalizerGapCount"])"
    return $snapshot
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef),
    @("DeploymentEvidenceRef", $DeploymentEvidenceRef),
    @("OperationsReadinessRef", $OperationsReadinessRef),
    @("OperationsConvergenceRef", $OperationsConvergenceRef),
    @("DataFlowStoragePlanEvidenceRef", $DataFlowStoragePlanEvidenceRef),
    @("SecretRotationEvidenceRef", $SecretRotationEvidenceRef),
    @("CommercialIntegrationEvidenceRef", $CommercialIntegrationEvidenceRef),
    @("CommercialApprovalEvidenceRef", $CommercialApprovalEvidenceRef),
    @("EnterpriseAuthEvidenceRef", $EnterpriseAuthEvidenceRef),
    @("BackupRestoreEvidenceRef", $BackupRestoreEvidenceRef),
    @("HaDrEvidenceRef", $HaDrEvidenceRef),
    @("MonitoringEvidenceRef", $MonitoringEvidenceRef),
    @("SecurityEvidenceRef", $SecurityEvidenceRef),
    @("IamRbacEvidenceRef", $IamRbacEvidenceRef),
    @("RunbookReviewRef", $RunbookReviewRef),
    @("TroubleshootingReviewRef", $TroubleshootingReviewRef),
    @("SupportEscalationRef", $SupportEscalationRef),
    @("SupportSlaRef", $SupportSlaRef),
    @("KnownGapsRef", $KnownGapsRef)
)) {
    Assert-SafeReference ([string] $entry[1]) ([string] $entry[0])
}

$operationsReadinessSnapshot = Read-OperationsReadinessSnapshot $OperationsReadinessJsonPath
$operationsConvergenceSnapshot = Read-OperationsConvergenceSnapshot $OperationsConvergenceJsonPath
$dataFlowStoragePlanSnapshot = Read-DataFlowStoragePlanSnapshot $DataFlowStoragePlanJsonPath
$operationsReadinessSnapshotValid = [bool] $operationsReadinessSnapshot["provided"] -and [bool] $operationsReadinessSnapshot["parsed"] -and [bool] $operationsReadinessSnapshot["validFormatVersion"]
$operationsConvergenceSnapshotValid = [bool] $operationsConvergenceSnapshot["provided"] -and [bool] $operationsConvergenceSnapshot["parsed"] -and [bool] $operationsConvergenceSnapshot["validFormatVersion"]
$dataFlowStoragePlanSnapshotValid = [bool] $dataFlowStoragePlanSnapshot["provided"] -and [bool] $dataFlowStoragePlanSnapshot["parsed"] -and [bool] $dataFlowStoragePlanSnapshot["validFormatVersion"]
$operationsReadinessSnapshotReady = $operationsReadinessSnapshotValid -and [bool] $operationsReadinessSnapshot["ready"]
$operationsConvergenceSnapshotReady = $operationsConvergenceSnapshotValid -and [bool] $operationsConvergenceSnapshot["ready"] -and [bool] $operationsConvergenceSnapshot["kubernetesReportSyncReady"]
$dataFlowStoragePlanSnapshotPassed = $dataFlowStoragePlanSnapshotValid -and [bool] $dataFlowStoragePlanSnapshot["passed"]

$evidenceText = $DeploymentEvidenceRef + $OperationsReadinessRef + $OperationsConvergenceRef + $DataFlowStoragePlanEvidenceRef + $SecretRotationEvidenceRef + $CommercialIntegrationEvidenceRef + $CommercialApprovalEvidenceRef + $EnterpriseAuthEvidenceRef + $BackupRestoreEvidenceRef + $HaDrEvidenceRef + $MonitoringEvidenceRef + $SecurityEvidenceRef + $IamRbacEvidenceRef + $RunbookReviewRef + $TroubleshootingReviewRef + $SupportEscalationRef + $SupportSlaRef + $KnownGapsRef
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $HandoffStartedAt + $HandoffCompletedAt + $ChangeApprovalRef + $evidenceText + $OperationsReadinessJsonPath + $OperationsConvergenceJsonPath + $DataFlowStoragePlanJsonPath) -or $ConfirmRunbookReviewed -or $ConfirmTroubleshootingReviewed -or $ConfirmRollbackReviewed -or $ConfirmSupportEscalationReviewed -or $ConfirmKnownGapsAccepted -or $ConfirmOperationsReadinessSnapshotReviewed -or $ConfirmOperationsConvergenceSnapshotReviewed -or $ConfirmDataFlowStoragePlanReviewed -or $ConfirmNoSecretValues -or $RequireOperationsSnapshotEvidence
$handoffStartedAtParsed = Get-ParsedDateText $HandoffStartedAt
$handoffCompletedAtParsed = Get-ParsedDateText $HandoffCompletedAt
$handoffWindowOrdered = $null -ne $handoffStartedAtParsed -and $null -ne $handoffCompletedAtParsed -and $handoffCompletedAtParsed -ge $handoffStartedAtParsed

Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($Operator)) "operator=$Operator"
Add-Check "handoff-started-at" "Handoff start timestamp recorded" (Test-DateText $HandoffStartedAt) "handoffStartedAt=$HandoffStartedAt"
Add-Check "handoff-completed-at" "Handoff completion timestamp recorded" (Test-DateText $HandoffCompletedAt) "handoffCompletedAt=$HandoffCompletedAt"
Add-Check "handoff-window-order" "Handoff window order valid" $handoffWindowOrdered "handoffStartedAt=$HandoffStartedAt; handoffCompletedAt=$HandoffCompletedAt"
Add-Check "change-approval-ref" "Change approval reference recorded" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "changeApprovalRef=$ChangeApprovalRef" $ChangeApprovalRef
Add-Check "no-secret-values-confirmed" "No credential values recorded confirmation" ([bool] $ConfirmNoSecretValues) "Evidence stores references and booleans only."
Add-Check "runbook-reviewed" "Operator runbook reviewed" ([bool] $ConfirmRunbookReviewed -and -not [string]::IsNullOrWhiteSpace($RunbookReviewRef)) "runbookReviewRef=$RunbookReviewRef" $RunbookReviewRef
Add-Check "troubleshooting-reviewed" "Troubleshooting guide reviewed" ([bool] $ConfirmTroubleshootingReviewed -and -not [string]::IsNullOrWhiteSpace($TroubleshootingReviewRef)) "troubleshootingReviewRef=$TroubleshootingReviewRef" $TroubleshootingReviewRef
Add-Check "rollback-reviewed" "Rollback path reviewed" ([bool] $ConfirmRollbackReviewed -and -not [string]::IsNullOrWhiteSpace($DeploymentEvidenceRef)) "deploymentEvidenceRef=$DeploymentEvidenceRef" $DeploymentEvidenceRef
Add-Check "support-escalation-reviewed" "Support escalation path reviewed" ([bool] $ConfirmSupportEscalationReviewed -and -not [string]::IsNullOrWhiteSpace($SupportEscalationRef) -and -not [string]::IsNullOrWhiteSpace($SupportSlaRef)) "supportEscalationRef=$SupportEscalationRef; supportSlaRef=$SupportSlaRef" $SupportEscalationRef
Add-Check "known-gaps-accepted" "Known gaps accepted" ([bool] $ConfirmKnownGapsAccepted -and -not [string]::IsNullOrWhiteSpace($KnownGapsRef)) "knownGapsRef=$KnownGapsRef" $KnownGapsRef

Add-EvidenceCheck "operations-readiness-evidence" "Operations readiness target evidence" ([bool] $RequireProductionEvidence) $OperationsReadinessRef "latest operations readiness result=ready or accepted target report"
Add-EvidenceCheck "operations-convergence-evidence" "Operations convergence target evidence" ([bool] $RequireProductionEvidence) $OperationsConvergenceRef "latest operations convergence and dashboard sync evidence"
if ([bool] $RequireOperationsSnapshotEvidence -or [bool] $operationsReadinessSnapshot["provided"]) {
    Add-Check "operations-readiness-snapshot-parsed" "Operations readiness snapshot parsed" $operationsReadinessSnapshotValid $operationsReadinessSnapshot["detail"] $OperationsReadinessRef
    Add-Check "operations-readiness-snapshot-ready" "Operations readiness snapshot ready" $operationsReadinessSnapshotReady "result=$($operationsReadinessSnapshot["result"]); pending=$($operationsReadinessSnapshot["pendingCount"])" $OperationsReadinessRef
}
if ([bool] $RequireOperationsSnapshotEvidence -or [bool] $operationsReadinessSnapshot["provided"] -or [bool] $ConfirmOperationsReadinessSnapshotReviewed) {
    Add-Check "operations-readiness-snapshot-reviewed" "Operations readiness snapshot reviewed" ([bool] $ConfirmOperationsReadinessSnapshotReviewed -and $operationsReadinessSnapshotValid) "confirmed=$([bool] $ConfirmOperationsReadinessSnapshotReviewed); snapshotValid=$operationsReadinessSnapshotValid" $OperationsReadinessRef
}
if ([bool] $RequireOperationsSnapshotEvidence -or [bool] $operationsConvergenceSnapshot["provided"]) {
    Add-Check "operations-convergence-snapshot-parsed" "Operations convergence snapshot parsed" $operationsConvergenceSnapshotValid $operationsConvergenceSnapshot["detail"] $OperationsConvergenceRef
    Add-Check "operations-convergence-snapshot-ready" "Operations convergence snapshot ready" $operationsConvergenceSnapshotReady "result=$($operationsConvergenceSnapshot["result"]); kubernetesReportSyncReady=$($operationsConvergenceSnapshot["kubernetesReportSyncReady"]); failedSyncChecks=$($operationsConvergenceSnapshot["kubernetesReportSyncFailedCount"])" $OperationsConvergenceRef
}
if ([bool] $RequireOperationsSnapshotEvidence -or [bool] $operationsConvergenceSnapshot["provided"] -or [bool] $ConfirmOperationsConvergenceSnapshotReviewed) {
    Add-Check "operations-convergence-snapshot-reviewed" "Operations convergence snapshot reviewed" ([bool] $ConfirmOperationsConvergenceSnapshotReviewed -and $operationsConvergenceSnapshotValid) "confirmed=$([bool] $ConfirmOperationsConvergenceSnapshotReviewed); snapshotValid=$operationsConvergenceSnapshotValid" $OperationsConvergenceRef
}
Add-EvidenceCheck "data-flow-storage-plan-evidence" "Data-flow storage transition target evidence" ([bool] $RequireProductionEvidence) $DataFlowStoragePlanEvidenceRef "target data-flow storage plan result=passed with sanitized query-plan summary"
if ([bool] $RequireProductionEvidence -or [bool] $dataFlowStoragePlanSnapshot["provided"]) {
    Add-Check "data-flow-storage-plan-snapshot-parsed" "Data-flow storage plan snapshot parsed" $dataFlowStoragePlanSnapshotValid $dataFlowStoragePlanSnapshot["detail"] $DataFlowStoragePlanEvidenceRef
    Add-Check "data-flow-storage-plan-snapshot-passed" "Data-flow storage plan snapshot passed" $dataFlowStoragePlanSnapshotPassed "result=$($dataFlowStoragePlanSnapshot["result"]); pending=$($dataFlowStoragePlanSnapshot["pendingCount"]); candidateStore=$($dataFlowStoragePlanSnapshot["candidateStore"])" $DataFlowStoragePlanEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $dataFlowStoragePlanSnapshot["provided"] -or [bool] $ConfirmDataFlowStoragePlanReviewed) {
    Add-Check "data-flow-storage-plan-reviewed" "Data-flow storage plan reviewed" ([bool] $ConfirmDataFlowStoragePlanReviewed -and $dataFlowStoragePlanSnapshotValid) "confirmed=$([bool] $ConfirmDataFlowStoragePlanReviewed); snapshotValid=$dataFlowStoragePlanSnapshotValid" $DataFlowStoragePlanEvidenceRef
}
Add-EvidenceCheck "secret-rotation-evidence" "Secret/certificate rotation target evidence" ([bool] $RequireProductionEvidence) $SecretRotationEvidenceRef "target secret/certificate rotation result=passed"
Add-EvidenceCheck "commercial-integration-evidence" "Commercial integration target evidence" ([bool] $RequireProductionEvidence) $CommercialIntegrationEvidenceRef "target commercial integration result=passed without native processor API claims"
Add-EvidenceCheck "commercial-approval-evidence" "Commercial approval target evidence" ([bool] $RequireProductionEvidence) $CommercialApprovalEvidenceRef "target commercial approval result=passed for final pricing, terms, support SLA, license agreement, legal approval, and pilot contract boundary"
Add-EvidenceCheck "enterprise-auth-evidence" "Enterprise auth target evidence" ([bool] $RequireProductionEvidence) $EnterpriseAuthEvidenceRef "target IdP/directory smoke result=passed or contracted scope-out"
Add-EvidenceCheck "backup-restore-evidence" "Backup/restore target evidence" ([bool] $RequireProductionEvidence) $BackupRestoreEvidenceRef "target backup restore or DR drill evidence"
Add-EvidenceCheck "ha-dr-evidence" "HA/DR target evidence" ([bool] $RequireProductionEvidence) $HaDrEvidenceRef "target HA/DR readiness evidence"
Add-EvidenceCheck "monitoring-evidence" "Monitoring target evidence" ([bool] $RequireProductionEvidence) $MonitoringEvidenceRef "target Prometheus/Alertmanager/Grafana evidence"
Add-EvidenceCheck "security-evidence" "Security target evidence" ([bool] $RequireProductionEvidence) $SecurityEvidenceRef "target image signing/container security evidence"
Add-EvidenceCheck "iam-rbac-evidence" "IAM/RBAC target evidence" ([bool] $RequireProductionEvidence) $IamRbacEvidenceRef "target IAM/RBAC finalizer evidence"

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$plannedCount = @($checks | Where-Object { $_.status -eq "PLANNED" }).Count
$passedCount = @($checks | Where-Object { $_.status -eq "PASS" }).Count
$result = if (-not $hasAnyInput) {
    "planned"
}
elseif ($failureCount -eq 0) {
    "passed"
}
else {
    "failed"
}

$generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$checkArray = @($checks | ForEach-Object { $_ })

$evidenceRefs = [ordered]@{
    changeApproval = $ChangeApprovalRef
    deployment = $DeploymentEvidenceRef
    operationsReadiness = $OperationsReadinessRef
    operationsConvergence = $OperationsConvergenceRef
    dataFlowStoragePlan = $DataFlowStoragePlanEvidenceRef
    secretRotation = $SecretRotationEvidenceRef
    commercialIntegration = $CommercialIntegrationEvidenceRef
    commercialApproval = $CommercialApprovalEvidenceRef
    enterpriseAuth = $EnterpriseAuthEvidenceRef
    backupRestore = $BackupRestoreEvidenceRef
    haDr = $HaDrEvidenceRef
    monitoring = $MonitoringEvidenceRef
    security = $SecurityEvidenceRef
    iamRbac = $IamRbacEvidenceRef
    runbookReview = $RunbookReviewRef
    troubleshootingReview = $TroubleshootingReviewRef
    supportEscalation = $SupportEscalationRef
    supportSla = $SupportSlaRef
    knownGaps = $KnownGapsRef
}

$report = New-Object System.Collections.Specialized.OrderedDictionary
[void] $report.Add("formatVersion", "osmu.operations-handoff-package.v1")
[void] $report.Add("generatedAt", $generatedAt)
[void] $report.Add("result", $result)
[void] $report.Add("environmentName", $EnvironmentName)
[void] $report.Add("targetCluster", $TargetCluster)
[void] $report.Add("operatorName", $Operator)
[void] $report.Add("handoffWindow", [ordered]@{
    startedAt = $HandoffStartedAt
    completedAt = $HandoffCompletedAt
})
[void] $report.Add("evidenceRefs", $evidenceRefs)
[void] $report.Add("operationsSnapshots", [ordered]@{
    readiness = $operationsReadinessSnapshot
    convergence = $operationsConvergenceSnapshot
})
[void] $report.Add("targetEvidenceSnapshots", [ordered]@{
    dataFlowStoragePlan = $dataFlowStoragePlanSnapshot
})
[void] $report.Add("confirmations", [ordered]@{
    noSecretValues = [bool] $ConfirmNoSecretValues
    runbookReviewed = [bool] $ConfirmRunbookReviewed
    troubleshootingReviewed = [bool] $ConfirmTroubleshootingReviewed
    rollbackReviewed = [bool] $ConfirmRollbackReviewed
    supportEscalationReviewed = [bool] $ConfirmSupportEscalationReviewed
    knownGapsAccepted = [bool] $ConfirmKnownGapsAccepted
    operationsReadinessSnapshotReviewed = [bool] $ConfirmOperationsReadinessSnapshotReviewed
    operationsConvergenceSnapshotReviewed = [bool] $ConfirmOperationsConvergenceSnapshotReviewed
    dataFlowStoragePlanReviewed = [bool] $ConfirmDataFlowStoragePlanReviewed
    requireProductionEvidence = [bool] $RequireProductionEvidence
    requireOperationsSnapshotEvidence = [bool] $RequireOperationsSnapshotEvidence
})
[void] $report.Add("summary", [ordered]@{
    passedCount = $passedCount
    failureCount = $failureCount
    plannedCount = $plannedCount
    checkCount = $checkArray.Count
    operationsReadinessSnapshotResult = $operationsReadinessSnapshot["result"]
    operationsConvergenceSnapshotResult = $operationsConvergenceSnapshot["result"]
    operationsConvergenceKubernetesReportSyncReady = $operationsConvergenceSnapshot["kubernetesReportSyncReady"]
    dataFlowStoragePlanSnapshotResult = $dataFlowStoragePlanSnapshot["result"]
})
[void] $report.Add("checks", [object] $checkArray)
[void] $report.Add("decisionRule", "Production/B2B operations handoff package readiness requires result=passed from the target environment, reviewed runbook/troubleshooting/rollback/support paths, accepted known gaps, no-secret confirmation, and references to target readiness, convergence, data-flow storage transition, secret rotation, commercial integration, commercial approval, enterprise auth, backup/restore, HA/DR, monitoring, security, and IAM/RBAC evidence when production evidence is required. When operations snapshot evidence is required, the latest operations readiness snapshot must be result=ready and the latest operations readiness convergence snapshot must be result=ready with Kubernetes report sync ready. When production evidence is required, the data-flow storage plan snapshot must be result=passed and reviewed.")
[void] $report.Add("scopePolicy", "This package is a handoff wrapper for already-collected operations evidence. It can reduce sanitized operations readiness, convergence, and data-flow storage plan JSON snapshots to summary fields, but it does not execute kubectl, gh, provider APIs, notification adapters, payment adapters, storage migrations, or native card/bank/tax/ERP processor calls.")
[void] $report.Add("secretPolicy", "Evidence stores only environment labels, operator/change references, timestamps, booleans, external evidence references, reduced operations readiness/convergence snapshot summaries, and reduced data-flow storage plan summaries; it must not contain passwords, bearer tokens, kubeconfig values, private keys, SMTP credentials, webhook signing secrets, provider credentials, raw SQL, raw EXPLAIN JSON, raw provider responses, raw remediation commands containing credentials, or customer payment data.")

$markdownLines = @(
    "# OSMU Operations Handoff Package",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Environment: $EnvironmentName",
    "Target cluster: $TargetCluster",
    "Operator: $Operator",
    "",
    "## Decision Rule",
    "",
    $report["decisionRule"],
    "",
    "## Scope Policy",
    "",
    $report["scopePolicy"],
    "",
    "## Secret Policy",
    "",
    $report["secretPolicy"],
    "",
    "## Evidence References",
    ""
)

foreach ($key in $evidenceRefs.Keys) {
    $markdownLines += "- ${key}: $($evidenceRefs[$key])"
}

$markdownLines += ""
$markdownLines += "## Operations Snapshots"
$markdownLines += ""
$markdownLines += "- Readiness: provided=$($operationsReadinessSnapshot["provided"]); parsed=$($operationsReadinessSnapshot["parsed"]); result=$($operationsReadinessSnapshot["result"]); passed=$($operationsReadinessSnapshot["passedCount"]); pending=$($operationsReadinessSnapshot["pendingCount"]); checks=$($operationsReadinessSnapshot["checkCount"])"
$markdownLines += "- Convergence: provided=$($operationsConvergenceSnapshot["provided"]); parsed=$($operationsConvergenceSnapshot["parsed"]); result=$($operationsConvergenceSnapshot["result"]); readiness=$($operationsConvergenceSnapshot["readinessResult"]); kubernetesReportSyncReady=$($operationsConvergenceSnapshot["kubernetesReportSyncReady"]); finalizerGaps=$($operationsConvergenceSnapshot["finalizerGapCount"])"
foreach ($pendingCheck in @($operationsReadinessSnapshot["topPendingChecks"])) {
    $markdownLines += "- Readiness pending: [$($pendingCheck.status)] $($pendingCheck.category) / $($pendingCheck.name): $($pendingCheck.detail)"
}

$markdownLines += ""
$markdownLines += "## Target Evidence Snapshots"
$markdownLines += ""
$markdownLines += "- Data-flow storage plan: provided=$($dataFlowStoragePlanSnapshot["provided"]); parsed=$($dataFlowStoragePlanSnapshot["parsed"]); result=$($dataFlowStoragePlanSnapshot["result"]); candidateStore=$($dataFlowStoragePlanSnapshot["candidateStore"]); passed=$($dataFlowStoragePlanSnapshot["passedCount"]); pending=$($dataFlowStoragePlanSnapshot["pendingCount"]); checks=$($dataFlowStoragePlanSnapshot["checkCount"])"
foreach ($pendingCheck in @($dataFlowStoragePlanSnapshot["topPendingChecks"])) {
    $markdownLines += "- Data-flow pending: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.title): $($pendingCheck.detail)"
}

$markdownLines += ""
$markdownLines += "## Checks"
$markdownLines += ""
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}

$markdownLines += ""
$markdownLines += "## Operator Command"
$markdownLines += ""
$markdownLines += "- Record passed target package: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-handoff-package.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -HandoffStartedAt <iso-time> -HandoffCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DeploymentEvidenceRef <ref> -OperationsReadinessRef <ref> -OperationsConvergenceRef <ref> -DataFlowStoragePlanEvidenceRef <ref> -OperationsReadinessJsonPath .\.osmu-run\latest-operations-readiness.json -OperationsConvergenceJsonPath .\.osmu-run\latest-operations-readiness-convergence.json -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -SecretRotationEvidenceRef <ref> -CommercialIntegrationEvidenceRef <ref> -CommercialApprovalEvidenceRef <ref> -EnterpriseAuthEvidenceRef <ref> -BackupRestoreEvidenceRef <ref> -HaDrEvidenceRef <ref> -MonitoringEvidenceRef <ref> -SecurityEvidenceRef <ref> -IamRbacEvidenceRef <ref> -RunbookReviewRef <ref> -TroubleshootingReviewRef <ref> -SupportEscalationRef <ref> -SupportSlaRef <ref> -KnownGapsRef <ref> -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackReviewed -ConfirmSupportEscalationReviewed -ConfirmKnownGapsAccepted -ConfirmOperationsReadinessSnapshotReviewed -ConfirmOperationsConvergenceSnapshotReviewed -ConfirmDataFlowStoragePlanReviewed -ConfirmNoSecretValues -RequireProductionEvidence -RequireOperationsSnapshotEvidence -FailIfNotPassed``"

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations handoff package JSON: $resolvedJsonOutputPath"
    Write-Host "Operations handoff package markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Operations handoff package did not pass: result=$result failureCount=$failureCount"
}
