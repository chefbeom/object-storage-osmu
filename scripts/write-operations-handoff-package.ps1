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
    [string] $DataFlowStorageTransitionRunbookEvidenceRef = "",
    [string] $OperationsReadinessJsonPath = "",
    [string] $OperationsConvergenceJsonPath = "",
    [string] $DataFlowStoragePlanJsonPath = "",
    [string] $DataFlowStorageTransitionRunbookJsonPath = "",
    [string] $SecretRotationEvidenceRef = "",
    [string] $SecretRotationJsonPath = "",
    [string] $CommercialIntegrationEvidenceRef = "",
    [string] $CommercialApprovalEvidenceRef = "",
    [string] $CommercialIntegrationJsonPath = "",
    [string] $CommercialApprovalJsonPath = "",
    [string] $EnterpriseAuthEvidenceRef = "",
    [string] $EnterpriseAuthJsonPath = "",
    [string] $BackupRestoreEvidenceRef = "",
    [string] $HaDrEvidenceRef = "",
    [string] $MonitoringEvidenceRef = "",
    [string] $MonitoringThresholdJsonPath = "",
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
    [switch] $ConfirmDataFlowStorageTransitionRunbookReviewed,
    [switch] $ConfirmSecretRotationSnapshotReviewed,
    [switch] $ConfirmCommercialIntegrationSnapshotReviewed,
    [switch] $ConfirmCommercialApprovalSnapshotReviewed,
    [switch] $ConfirmEnterpriseAuthSmokeSnapshotReviewed,
    [switch] $ConfirmMonitoringThresholdReviewed,
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

    $forbiddenPropertyPattern = '(?i)"(rawProviderResponse|raw_provider_response|providerResponse|provider_response|responseBody|response_body|responseHeaders|response_headers|customerData|customer_data|customerEmail|customer_email|customerName|customer_name|customerPaymentData|customer_payment_data|cardNumber|card_number|bankAccount|bank_account|rawPriceTable|raw_price_table|priceTable|price_table|rawContractText|raw_contract_text|contractText|contract_text|licenseKey|license_key|rawRemediation|raw_remediation|rawCommand|raw_command|rawClaims|raw_claims|rawClaimJson|raw_claim_json|claimsJson|claims_json|idToken|id_token|accessToken|access_token|refreshToken|refresh_token|authorizationCode|authorization_code|oidcCallbackCode|oidc_callback_code|oidcCallbackState|oidc_callback_state|ldapPassword|ldap_password|adminPassword|admin_password|clientSecret|client_secret)"\s*:'
    if ($Value -match $forbiddenPropertyPattern) {
        throw "$Label appears to contain raw remediation, provider, customer, contract, license, payment, identity, or credential content. Store only sanitized operations snapshot summary fields."
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

function Assert-SanitizedMonitoringThresholdJson([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $forbiddenPropertyPattern = '(?i)"(rawAlertmanagerConfig|raw_alertmanager_config|rawReceiver|raw_receiver|receiverSecret|receiver_secret|webhookSecret|webhook_secret|smtpPassword|smtp_password|customerData|customer_data|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:'
    $credentialPattern = '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|webhook[_-]?secret|smtp[_-]?pass)\s*=\s*\S+'
    if ($Value -match $forbiddenPropertyPattern -or $Value -match $credentialPattern) {
        throw "$Label appears to contain raw Alertmanager receiver, customer, or credential-shaped content. Store only sanitized monitoring threshold summary fields."
    }
}

function Assert-SanitizedSecretRotationJson([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $forbiddenPropertyPattern = '(?i)"(rawSecret|raw_secret|secretValue|secret_value|oldSecret|old_secret|newSecret|new_secret|databasePassword|database_password|minioRootPassword|minio_root_password|jwtSigningSecret|jwt_signing_secret|oidcClientSecret|oidc_client_secret|ldapPassword|ldap_password|smtpPassword|smtp_password|webhookSecret|webhook_secret|password|passwd|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key|kubeconfig)"\s*:'
    $credentialPattern = '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|webhook[_-]?secret|smtp[_-]?pass)\s*=\s*\S+'
    if ($Value -match $forbiddenPropertyPattern -or $Value -match $credentialPattern) {
        throw "$Label appears to contain raw secret or credential-shaped content. Store only sanitized secret rotation summary fields."
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

function Get-SummaryOrSelf([object] $Object) {
    $summary = Get-PropertyValue $Object "summary"
    if ($null -eq $summary) {
        return $Object
    }
    return $summary
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

function New-DataFlowStorageTransitionRunbookCheckSnapshotRow([object] $Check) {
    return [ordered]@{
        id = Get-PropertyText $Check "id"
        name = Get-PropertyText $Check "name"
        status = Get-PropertyText $Check "status"
        passed = Get-PropertyBool $Check "passed"
        detail = Get-PropertyText $Check "detail"
    }
}

function New-CommercialEvidenceCheckSnapshotRow([object] $Check) {
    return [ordered]@{
        id = Get-PropertyText $Check "id"
        name = Get-PropertyText $Check "name"
        status = Get-PropertyText $Check "status"
        passed = Get-PropertyBool $Check "passed"
        detail = Get-PropertyText $Check "detail"
        evidenceRef = Get-PropertyText $Check "evidenceRef"
    }
}

function New-EnterpriseAuthSmokeCheckSnapshotRow([object] $Check) {
    return [ordered]@{
        id = Get-PropertyText $Check "id"
        name = Get-PropertyText $Check "name"
        category = Get-PropertyText $Check "category"
        endpoint = Get-PropertyText $Check "endpoint"
        status = Get-PropertyText $Check "status"
        detail = Get-PropertyText $Check "detail"
        requiredInputs = @(Get-PropertyArray $Check "requiredInputs" | ForEach-Object { [string] $_ })
    }
}

function New-MonitoringThresholdCheckSnapshotRow([object] $Check) {
    return [ordered]@{
        id = Get-PropertyText $Check "id"
        name = Get-PropertyText $Check "name"
        status = Get-PropertyText $Check "status"
        passed = Get-PropertyBool $Check "passed"
        detail = Get-PropertyText $Check "detail"
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
        targetP95QueryLatencyMs = 0
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
    $snapshot["targetP95QueryLatencyMs"] = Get-PropertyInt $payload "targetP95QueryLatencyMs"
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

function Read-DataFlowStorageTransitionRunbookSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        evidenceRef = ""
        storagePlanResult = ""
        candidateStore = ""
        targetP95QueryLatencyMs = 0
        failureCount = 0
        checkCount = 0
        confirmations = [ordered]@{
            backfillRehearsed = $false
            dualWriteOrPartitionToggleReviewed = $false
            rollbackRehearsed = $false
            reconciliationPassed = $false
            dashboardCutoverReviewed = $false
            retentionDryRunReviewed = $false
            noObjectKeysInAggregates = $false
            noSecretValues = $false
        }
        topFailedChecks = @()
        detail = "No data-flow storage transition runbook evidence JSON supplied."
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $snapshot
    }

    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "Data-flow storage transition runbook evidence JSON not found."
        return $snapshot
    }

    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    Assert-SafeText $raw "DataFlowStorageTransitionRunbookJson"
    Assert-SanitizedOperationsSnapshotJson $raw "DataFlowStorageTransitionRunbookJson"
    Assert-SanitizedDataFlowStoragePlanJson $raw "DataFlowStorageTransitionRunbookJson"
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $snapshot["detail"] = "Data-flow storage transition runbook evidence JSON parse failed: $($_.Exception.Message)"
        return $snapshot
    }

    $checks = @(Get-PropertyArray $payload "checks")
    $failedRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $failedRows.Add((New-DataFlowStorageTransitionRunbookCheckSnapshotRow $check))
        }
        if ($failedRows.Count -ge 5) {
            break
        }
    }

    $summary = Get-PropertyValue $payload "summary"
    $confirmations = Get-PropertyValue $payload "confirmations"
    $planSnapshot = Get-PropertyValue $payload "dataFlowStoragePlanSnapshot"
    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $snapshot["parsed"] = $true
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["environmentName"] = Get-PropertyText $payload "environmentName"
    $snapshot["targetCluster"] = Get-PropertyText $payload "targetCluster"
    $snapshot["operatorName"] = Get-PropertyText $payload "operatorName"
    $snapshot["evidenceRef"] = Get-PropertyText $payload "evidenceRef"
    $snapshot["storagePlanResult"] = Get-PropertyText $planSnapshot "result"
    $snapshot["candidateStore"] = Get-PropertyText $planSnapshot "candidateStore"
    $snapshot["targetP95QueryLatencyMs"] = Get-PropertyInt $planSnapshot "targetP95QueryLatencyMs"
    $snapshot["failureCount"] = Get-PropertyInt $summary "failureCount"
    $snapshot["checkCount"] = Get-PropertyInt $summary "checkCount"
    $snapshot["confirmations"] = [ordered]@{
        backfillRehearsed = Get-PropertyBool $confirmations "backfillRehearsed"
        dualWriteOrPartitionToggleReviewed = Get-PropertyBool $confirmations "dualWriteOrPartitionToggleReviewed"
        rollbackRehearsed = Get-PropertyBool $confirmations "rollbackRehearsed"
        reconciliationPassed = Get-PropertyBool $confirmations "reconciliationPassed"
        dashboardCutoverReviewed = Get-PropertyBool $confirmations "dashboardCutoverReviewed"
        retentionDryRunReviewed = Get-PropertyBool $confirmations "retentionDryRunReviewed"
        noObjectKeysInAggregates = Get-PropertyBool $confirmations "noObjectKeysInAggregates"
        noSecretValues = Get-PropertyBool $confirmations "noSecretValues"
    }
    $snapshot["topFailedChecks"] = @($failedRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; storagePlanResult=$($snapshot["storagePlanResult"]); candidateStore=$($snapshot["candidateStore"]); failures=$($snapshot["failureCount"]); checks=$($snapshot["checkCount"])"
    return $snapshot
}

function Read-CommercialIntegrationEvidenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.commercial-integration-evidence.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        integrationCount = 0
        verifiedCount = 0
        requiredCount = 0
        requiredVerifiedCount = 0
        paymentProviderAdapterReadinessReviewed = $false
        paymentProviderAdapterReadinessStatus = ""
        paymentProviderAdapterWebhookReadyProfileCount = 0
        paymentProviderAdapterNativeReadyProfileCount = 0
        failureCount = 0
        plannedCount = 0
        checkCount = 0
        topChecks = @()
        detail = "No commercial integration evidence JSON supplied."
    }

    $payloadResult = Read-JsonPayload $Path "CommercialIntegration" $snapshot["detail"]
    $snapshot["provided"] = [bool] $payloadResult["provided"]
    $snapshot["path"] = [string] $payloadResult["path"]
    $snapshot["parsed"] = [bool] $payloadResult["parsed"]
    if (-not $snapshot["parsed"]) {
        $snapshot["detail"] = [string] $payloadResult["detail"]
        return $snapshot
    }

    $payload = $payloadResult["payload"]
    $summary = Get-PropertyValue $payload "summary"
    $checks = @(Get-PropertyArray $payload "checks")
    $topRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $topRows.Add((New-CommercialEvidenceCheckSnapshotRow $check))
        }
        if ($topRows.Count -ge 5) {
            break
        }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["environmentName"] = Get-PropertyText $payload "environmentName"
    $snapshot["targetCluster"] = Get-PropertyText $payload "targetCluster"
    $snapshot["operatorName"] = Get-PropertyText $payload "operatorName"
    $snapshot["integrationCount"] = Get-PropertyInt $summary "integrationCount"
    $snapshot["verifiedCount"] = Get-PropertyInt $summary "verifiedCount"
    $snapshot["requiredCount"] = Get-PropertyInt $summary "requiredCount"
    $snapshot["requiredVerifiedCount"] = Get-PropertyInt $summary "requiredVerifiedCount"
    $snapshot["paymentProviderAdapterReadinessReviewed"] = Get-PropertyBool $summary "paymentProviderAdapterReadinessReviewed"
    $snapshot["paymentProviderAdapterReadinessStatus"] = Get-PropertyText $summary "paymentProviderAdapterReadinessStatus"
    $snapshot["paymentProviderAdapterWebhookReadyProfileCount"] = Get-PropertyInt $summary "paymentProviderAdapterWebhookReadyProfileCount"
    $snapshot["paymentProviderAdapterNativeReadyProfileCount"] = Get-PropertyInt $summary "paymentProviderAdapterNativeReadyProfileCount"
    $snapshot["failureCount"] = Get-PropertyInt $summary "failureCount"
    $snapshot["plannedCount"] = Get-PropertyInt $summary "plannedCount"
    $snapshot["checkCount"] = $checks.Count
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; requiredVerified=$($snapshot["requiredVerifiedCount"])/$($snapshot["requiredCount"]); failures=$($snapshot["failureCount"]); planned=$($snapshot["plannedCount"])"
    return $snapshot
}

function Read-SecretRotationEvidenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.secret-rotation-evidence.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        rotationWindow = [ordered]@{}
        evidenceRefs = [ordered]@{}
        confirmations = [ordered]@{
            noSecretValues = $false
            workloadRestart = $false
            smokePassed = $false
            artifactLeakReview = $false
            requireAllCoreSecrets = $false
        }
        rotatedCount = 0
        coreRotatedCount = 0
        coreRequiredCount = 0
        failureCount = 0
        plannedCount = 0
        checkCount = 0
        rotations = @()
        topChecks = @()
        detail = "No secret rotation evidence JSON supplied."
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $snapshot
    }

    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "Secret rotation evidence JSON not found."
        return $snapshot
    }

    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    Assert-SafeText $raw "SecretRotationJson"
    Assert-SanitizedOperationsSnapshotJson $raw "SecretRotationJson"
    Assert-SanitizedSecretRotationJson $raw "SecretRotationJson"
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $snapshot["detail"] = "Secret rotation evidence JSON parse failed: $($_.Exception.Message)"
        return $snapshot
    }

    $summary = Get-SummaryOrSelf $payload
    $confirmations = Get-PropertyValue $payload "confirmations"
    $rotationWindow = Get-PropertyValue $payload "rotationWindow"
    $checks = @(Get-PropertyArray $payload "checks")
    $rotations = @(Get-PropertyArray $payload "rotations")
    $topRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $topRows.Add((New-CommercialEvidenceCheckSnapshotRow $check))
        }
        if ($topRows.Count -ge 5) {
            break
        }
    }

    $rotationRows = New-Object System.Collections.Generic.List[object]
    foreach ($rotation in $rotations) {
        [void] $rotationRows.Add([ordered]@{
            id = Get-PropertyText $rotation "id"
            name = Get-PropertyText $rotation "name"
            core = Get-PropertyBool $rotation "core"
            rotated = Get-PropertyBool $rotation "rotated"
            note = Get-PropertyText $rotation "note"
        })
        if ($rotationRows.Count -ge 8) {
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
    $snapshot["operatorName"] = Get-PropertyText $payload "operatorName"
    $snapshot["rotationWindow"] = [ordered]@{
        startedAt = Get-PropertyText $rotationWindow "startedAt"
        completedAt = Get-PropertyText $rotationWindow "completedAt"
    }
    $snapshot["evidenceRefs"] = [ordered]@{
        changeApproval = Get-PropertyText (Get-PropertyValue $payload "evidenceRefs") "changeApproval"
        secretManagerAudit = Get-PropertyText (Get-PropertyValue $payload "evidenceRefs") "secretManagerAudit"
        workloadRestart = Get-PropertyText (Get-PropertyValue $payload "evidenceRefs") "workloadRestart"
        smoke = Get-PropertyText (Get-PropertyValue $payload "evidenceRefs") "smoke"
        artifactLeakReview = Get-PropertyText (Get-PropertyValue $payload "evidenceRefs") "artifactLeakReview"
        accessKeyEncryptionDecision = Get-PropertyText (Get-PropertyValue $payload "evidenceRefs") "accessKeyEncryptionDecision"
    }
    $snapshot["confirmations"] = [ordered]@{
        noSecretValues = Get-PropertyBool $confirmations "noSecretValues"
        workloadRestart = Get-PropertyBool $confirmations "workloadRestart"
        smokePassed = Get-PropertyBool $confirmations "smokePassed"
        artifactLeakReview = Get-PropertyBool $confirmations "artifactLeakReview"
        requireAllCoreSecrets = Get-PropertyBool $confirmations "requireAllCoreSecrets"
    }
    $snapshot["rotatedCount"] = Get-PropertyInt $summary "rotatedCount"
    $snapshot["coreRotatedCount"] = Get-PropertyInt $summary "coreRotatedCount"
    $snapshot["coreRequiredCount"] = Get-PropertyInt $summary "coreRequiredCount"
    $snapshot["failureCount"] = Get-PropertyInt $summary "failureCount"
    $snapshot["plannedCount"] = Get-PropertyInt $summary "plannedCount"
    $snapshot["checkCount"] = $checks.Count
    $snapshot["rotations"] = @($rotationRows.ToArray())
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; core=$($snapshot["coreRotatedCount"])/$($snapshot["coreRequiredCount"]); failures=$($snapshot["failureCount"]); planned=$($snapshot["plannedCount"])"
    return $snapshot
}

function Read-CommercialApprovalEvidenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.commercial-approval-evidence.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        productVersion = ""
        approvedBy = ""
        approvedAt = ""
        passedCount = 0
        failureCount = 0
        checkCount = 0
        pricingPolicyProposalCommercialApproved = $false
        pricingPolicyProposalCommercialApprovedCount = 0
        pricingPolicyProposalApprovedPriceListCount = 0
        topChecks = @()
        detail = "No commercial approval evidence JSON supplied."
    }

    $payloadResult = Read-JsonPayload $Path "CommercialApproval" $snapshot["detail"]
    $snapshot["provided"] = [bool] $payloadResult["provided"]
    $snapshot["path"] = [string] $payloadResult["path"]
    $snapshot["parsed"] = [bool] $payloadResult["parsed"]
    if (-not $snapshot["parsed"]) {
        $snapshot["detail"] = [string] $payloadResult["detail"]
        return $snapshot
    }

    $payload = $payloadResult["payload"]
    $summary = Get-PropertyValue $payload "summary"
    $checks = @(Get-PropertyArray $payload "checks")
    $topRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $topRows.Add((New-CommercialEvidenceCheckSnapshotRow $check))
        }
        if ($topRows.Count -ge 5) {
            break
        }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["productVersion"] = Get-PropertyText $payload "productVersion"
    $snapshot["approvedBy"] = Get-PropertyText $payload "approvedBy"
    $snapshot["approvedAt"] = Get-PropertyText $payload "approvedAt"
    $snapshot["passedCount"] = Get-PropertyInt $summary "passedCount"
    $snapshot["failureCount"] = Get-PropertyInt $summary "failureCount"
    $snapshot["checkCount"] = Get-PropertyInt $summary "checkCount"
    if ($snapshot["checkCount"] -eq 0) {
        $snapshot["checkCount"] = $checks.Count
    }
    $snapshot["pricingPolicyProposalCommercialApproved"] = Get-PropertyBool $summary "pricingPolicyProposalCommercialApproved"
    $snapshot["pricingPolicyProposalCommercialApprovedCount"] = Get-PropertyInt $summary "pricingPolicyProposalCommercialApprovedCount"
    $snapshot["pricingPolicyProposalApprovedPriceListCount"] = Get-PropertyInt $summary "pricingPolicyProposalApprovedPriceListCount"
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; failures=$($snapshot["failureCount"]); checks=$($snapshot["checkCount"]); priceListApproved=$($snapshot["pricingPolicyProposalApprovedPriceListCount"])"
    return $snapshot
}

function Read-EnterpriseAuthSmokeEvidenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.enterprise-auth-smoke.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        scopeOutAccepted = $false
        accepted = $false
        executionMode = ""
        apiBase = ""
        requireOidc = $false
        requireLdap = $false
        requireAuditEvents = $false
        inputs = [ordered]@{}
        scopeOut = [ordered]@{}
        passCount = 0
        failCount = 0
        blockedCount = 0
        plannedCount = 0
        skippedCount = 0
        checkCount = 0
        topChecks = @()
        detail = "No enterprise auth smoke JSON supplied."
    }

    $payloadResult = Read-JsonPayload $Path "EnterpriseAuthSmoke" $snapshot["detail"]
    $snapshot["provided"] = [bool] $payloadResult["provided"]
    $snapshot["path"] = [string] $payloadResult["path"]
    $snapshot["parsed"] = [bool] $payloadResult["parsed"]
    if (-not $snapshot["parsed"]) {
        $snapshot["detail"] = [string] $payloadResult["detail"]
        return $snapshot
    }

    $payload = $payloadResult["payload"]
    $summary = Get-SummaryOrSelf $payload
    $inputs = Get-PropertyValue $payload "inputs"
    $scopeOut = Get-PropertyValue $payload "scopeOut"
    $checks = @(Get-PropertyArray $payload "checks")
    $topRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        $status = Get-PropertyText $check "status"
        if (-not "PASS".Equals($status, [System.StringComparison]::OrdinalIgnoreCase) -and -not "SKIPPED".Equals($status, [System.StringComparison]::OrdinalIgnoreCase)) {
            [void] $topRows.Add((New-EnterpriseAuthSmokeCheckSnapshotRow $check))
        }
        if ($topRows.Count -ge 5) {
            break
        }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $scopeOutAccepted = Get-PropertyBool $scopeOut "accepted"
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["scopeOutAccepted"] = $scopeOutAccepted
    $snapshot["accepted"] = [bool] $snapshot["passed"] -or ("scope-out".Equals($result, [System.StringComparison]::OrdinalIgnoreCase) -and $scopeOutAccepted)
    $snapshot["executionMode"] = Get-PropertyText $payload "executionMode"
    $snapshot["apiBase"] = Get-PropertyText $payload "apiBase"
    $snapshot["requireOidc"] = Get-PropertyBool $payload "requireOidc"
    $snapshot["requireLdap"] = Get-PropertyBool $payload "requireLdap"
    $snapshot["requireAuditEvents"] = Get-PropertyBool $payload "requireAuditEvents"
    $snapshot["inputs"] = [ordered]@{
        adminPasswordProvided = Get-PropertyBool $inputs "adminPasswordProvided"
        oidcCallbackCodeProvided = Get-PropertyBool $inputs "oidcCallbackCodeProvided"
        oidcCallbackStateProvided = Get-PropertyBool $inputs "oidcCallbackStateProvided"
        oidcClaimPreviewJsonPathProvided = Get-PropertyBool $inputs "oidcClaimPreviewJsonPathProvided"
        oidcJitProvisionJsonPathProvided = Get-PropertyBool $inputs "oidcJitProvisionJsonPathProvided"
        confirmJitProvision = Get-PropertyBool $inputs "confirmJitProvision"
        ldapLoginIdProvided = Get-PropertyBool $inputs "ldapLoginIdProvided"
        ldapPasswordProvided = Get-PropertyBool $inputs "ldapPasswordProvided"
        expectedEmailProvided = Get-PropertyBool $inputs "expectedEmailProvided"
    }
    $snapshot["scopeOut"] = [ordered]@{
        confirmed = Get-PropertyBool $scopeOut "confirmed"
        reference = Get-PropertyText $scopeOut "reference"
        reason = Get-PropertyText $scopeOut "reason"
        accepted = $scopeOutAccepted
    }
    $snapshot["passCount"] = Get-PropertyInt $summary "passCount"
    $snapshot["failCount"] = Get-PropertyInt $summary "failCount"
    $snapshot["blockedCount"] = Get-PropertyInt $summary "blockedCount"
    $snapshot["plannedCount"] = Get-PropertyInt $summary "plannedCount"
    $snapshot["skippedCount"] = Get-PropertyInt $summary "skippedCount"
    $snapshot["checkCount"] = $checks.Count
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; pass=$($snapshot["passCount"]); fail=$($snapshot["failCount"]); blocked=$($snapshot["blockedCount"]); planned=$($snapshot["plannedCount"]); scopeOutAccepted=$scopeOutAccepted"
    return $snapshot
}

function Read-MonitoringThresholdEvidenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.monitoring-threshold-evidence.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        evidenceRef = ""
        requiredAlertCount = 0
        mappedAlertCount = 0
        missingAlertCount = 0
        routeCount = 0
        routes = @()
        grafanaPanelCount = 0
        tuningEvidenceCount = 0
        confirmations = [ordered]@{
            prometheusRulesLoaded = $false
            grafanaDashboardImported = $false
            alertmanagerRoutesReviewed = $false
            targetBaselinesReviewed = $false
            incidentRoutingReviewed = $false
            noSecretValues = $false
        }
        complete = $false
        failureCount = 0
        checkCount = 0
        topFailedChecks = @()
        detail = "No monitoring threshold evidence JSON supplied."
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $snapshot
    }

    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "Monitoring threshold evidence JSON not found."
        return $snapshot
    }

    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    Assert-SafeText $raw "MonitoringThresholdJson"
    Assert-SanitizedOperationsSnapshotJson $raw "MonitoringThresholdJson"
    Assert-SanitizedMonitoringThresholdJson $raw "MonitoringThresholdJson"
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $snapshot["detail"] = "Monitoring threshold evidence JSON parse failed: $($_.Exception.Message)"
        return $snapshot
    }

    $thresholdSummary = Get-PropertyValue $payload "thresholdTargetSummary"
    $summary = Get-SummaryOrSelf $payload
    $confirmations = Get-PropertyValue $payload "confirmations"
    $checks = @(Get-PropertyArray $payload "checks")
    $failedRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $failedRows.Add((New-MonitoringThresholdCheckSnapshotRow $check))
        }
        if ($failedRows.Count -ge 5) {
            break
        }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $routes = @(Get-PropertyArray $thresholdSummary "routes" | ForEach-Object { [string] $_ })
    $missingAlerts = @(Get-PropertyArray $thresholdSummary "missingAlerts")
    $requiredAlertCount = Get-PropertyInt $thresholdSummary "requiredAlertCount"
    $mappedAlertCount = Get-PropertyInt $thresholdSummary "mappedAlertCount"
    $grafanaPanelCount = Get-PropertyInt $thresholdSummary "grafanaPanelCount"
    $tuningEvidenceCount = Get-PropertyInt $thresholdSummary "tuningEvidenceCount"
    $failureCount = Get-PropertyInt $summary "failureCount"
    $allConfirmationsPassed = (Get-PropertyBool $confirmations "prometheusRulesLoaded") `
        -and (Get-PropertyBool $confirmations "grafanaDashboardImported") `
        -and (Get-PropertyBool $confirmations "alertmanagerRoutesReviewed") `
        -and (Get-PropertyBool $confirmations "targetBaselinesReviewed") `
        -and (Get-PropertyBool $confirmations "incidentRoutingReviewed") `
        -and (Get-PropertyBool $confirmations "noSecretValues")
    $complete = $requiredAlertCount -gt 0 `
        -and $mappedAlertCount -ge $requiredAlertCount `
        -and $grafanaPanelCount -ge $requiredAlertCount `
        -and $tuningEvidenceCount -ge $requiredAlertCount `
        -and $missingAlerts.Count -eq 0 `
        -and $allConfirmationsPassed `
        -and $failureCount -eq 0

    $snapshot["parsed"] = $true
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["environmentName"] = Get-PropertyText $payload "environmentName"
    $snapshot["targetCluster"] = Get-PropertyText $payload "targetCluster"
    $snapshot["operatorName"] = Get-PropertyText $payload "operatorName"
    $snapshot["evidenceRef"] = Get-PropertyText $payload "evidenceRef"
    $snapshot["requiredAlertCount"] = $requiredAlertCount
    $snapshot["mappedAlertCount"] = $mappedAlertCount
    $snapshot["missingAlertCount"] = $missingAlerts.Count
    $snapshot["routeCount"] = Get-PropertyInt $thresholdSummary "routeCount"
    $snapshot["routes"] = $routes
    $snapshot["grafanaPanelCount"] = $grafanaPanelCount
    $snapshot["tuningEvidenceCount"] = $tuningEvidenceCount
    $snapshot["confirmations"] = [ordered]@{
        prometheusRulesLoaded = Get-PropertyBool $confirmations "prometheusRulesLoaded"
        grafanaDashboardImported = Get-PropertyBool $confirmations "grafanaDashboardImported"
        alertmanagerRoutesReviewed = Get-PropertyBool $confirmations "alertmanagerRoutesReviewed"
        targetBaselinesReviewed = Get-PropertyBool $confirmations "targetBaselinesReviewed"
        incidentRoutingReviewed = Get-PropertyBool $confirmations "incidentRoutingReviewed"
        noSecretValues = Get-PropertyBool $confirmations "noSecretValues"
    }
    $snapshot["complete"] = $complete
    $snapshot["failureCount"] = $failureCount
    $snapshot["checkCount"] = Get-PropertyInt $summary "checkCount"
    if ($snapshot["checkCount"] -eq 0) {
        $snapshot["checkCount"] = $checks.Count
    }
    $snapshot["topFailedChecks"] = @($failedRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; alerts=$mappedAlertCount/$requiredAlertCount; routes=$($snapshot["routeCount"]); failures=$failureCount; complete=$complete"
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
        finalizerFailedCount = 0
        kubernetesReportSyncReady = $false
        kubernetesReportSyncResult = ""
        kubernetesReportSyncFailedCount = 0
        kubernetesReportSyncSourceReportResult = ""
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
    $snapshot["finalizerFailedCount"] = Get-PropertyInt $payload "finalizerFailedCount"
    $snapshot["kubernetesReportSyncReady"] = Get-PropertyBool $payload "kubernetesReportSyncReady"
    $snapshot["kubernetesReportSyncResult"] = Get-PropertyText $payload "kubernetesReportSyncResult"
    $snapshot["kubernetesReportSyncFailedCount"] = Get-PropertyInt $payload "kubernetesReportSyncFailedCount"
    $snapshot["kubernetesReportSyncSourceReportResult"] = Get-PropertyText $payload "kubernetesReportSyncSourceReportResult"
    $snapshot["stageCount"] = Get-PropertyInt $payload "stageCount"
    $snapshot["readyStageCount"] = Get-PropertyInt $payload "readyStageCount"
    $snapshot["finalizerGapCount"] = Get-PropertyInt $payload "finalizerGapCount"
    $snapshot["currentBottleneckCode"] = Get-PropertyText $currentBottleneck "code"
    $snapshot["currentBottleneckTitle"] = Get-PropertyText $currentBottleneck "title"
    $snapshot["recommendedCommandCount"] = $recommendedCommands.Count
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; readinessResult=$($snapshot["readinessResult"]); finalizerFailed=$($snapshot["finalizerFailedCount"]); finalizerGaps=$($snapshot["finalizerGapCount"]); kubernetesReportSyncReady=$($snapshot["kubernetesReportSyncReady"]); sourceReportResult=$($snapshot["kubernetesReportSyncSourceReportResult"])"
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
    @("DataFlowStorageTransitionRunbookEvidenceRef", $DataFlowStorageTransitionRunbookEvidenceRef),
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
$dataFlowStorageTransitionRunbookSnapshot = Read-DataFlowStorageTransitionRunbookSnapshot $DataFlowStorageTransitionRunbookJsonPath
$secretRotationSnapshot = Read-SecretRotationEvidenceSnapshot $SecretRotationJsonPath
$commercialIntegrationSnapshot = Read-CommercialIntegrationEvidenceSnapshot $CommercialIntegrationJsonPath
$commercialApprovalSnapshot = Read-CommercialApprovalEvidenceSnapshot $CommercialApprovalJsonPath
$enterpriseAuthSmokeSnapshot = Read-EnterpriseAuthSmokeEvidenceSnapshot $EnterpriseAuthJsonPath
$monitoringThresholdSnapshot = Read-MonitoringThresholdEvidenceSnapshot $MonitoringThresholdJsonPath
$operationsReadinessSnapshotValid = [bool] $operationsReadinessSnapshot["provided"] -and [bool] $operationsReadinessSnapshot["parsed"] -and [bool] $operationsReadinessSnapshot["validFormatVersion"]
$operationsConvergenceSnapshotValid = [bool] $operationsConvergenceSnapshot["provided"] -and [bool] $operationsConvergenceSnapshot["parsed"] -and [bool] $operationsConvergenceSnapshot["validFormatVersion"]
$dataFlowStoragePlanSnapshotValid = [bool] $dataFlowStoragePlanSnapshot["provided"] -and [bool] $dataFlowStoragePlanSnapshot["parsed"] -and [bool] $dataFlowStoragePlanSnapshot["validFormatVersion"]
$dataFlowStorageTransitionRunbookSnapshotValid = [bool] $dataFlowStorageTransitionRunbookSnapshot["provided"] -and [bool] $dataFlowStorageTransitionRunbookSnapshot["parsed"] -and [bool] $dataFlowStorageTransitionRunbookSnapshot["validFormatVersion"]
$secretRotationSnapshotValid = [bool] $secretRotationSnapshot["provided"] -and [bool] $secretRotationSnapshot["parsed"] -and [bool] $secretRotationSnapshot["validFormatVersion"]
$commercialIntegrationSnapshotValid = [bool] $commercialIntegrationSnapshot["provided"] -and [bool] $commercialIntegrationSnapshot["parsed"] -and [bool] $commercialIntegrationSnapshot["validFormatVersion"]
$commercialApprovalSnapshotValid = [bool] $commercialApprovalSnapshot["provided"] -and [bool] $commercialApprovalSnapshot["parsed"] -and [bool] $commercialApprovalSnapshot["validFormatVersion"]
$enterpriseAuthSmokeSnapshotValid = [bool] $enterpriseAuthSmokeSnapshot["provided"] -and [bool] $enterpriseAuthSmokeSnapshot["parsed"] -and [bool] $enterpriseAuthSmokeSnapshot["validFormatVersion"]
$monitoringThresholdSnapshotValid = [bool] $monitoringThresholdSnapshot["provided"] -and [bool] $monitoringThresholdSnapshot["parsed"] -and [bool] $monitoringThresholdSnapshot["validFormatVersion"]
$operationsReadinessSnapshotReady = $operationsReadinessSnapshotValid -and [bool] $operationsReadinessSnapshot["ready"]
$operationsConvergenceSnapshotReady = $operationsConvergenceSnapshotValid `
    -and [bool] $operationsConvergenceSnapshot["ready"] `
    -and "ready".Equals([string] $operationsConvergenceSnapshot["readinessResult"], [System.StringComparison]::OrdinalIgnoreCase) `
    -and "ready".Equals([string] $operationsConvergenceSnapshot["finalizerResult"], [System.StringComparison]::OrdinalIgnoreCase) `
    -and "ready".Equals([string] $operationsConvergenceSnapshot["finalizerReadinessResult"], [System.StringComparison]::OrdinalIgnoreCase) `
    -and ([int] $operationsConvergenceSnapshot["finalizerFailedCount"]) -eq 0 `
    -and ([int] $operationsConvergenceSnapshot["finalizerGapCount"]) -eq 0 `
    -and [bool] $operationsConvergenceSnapshot["kubernetesReportSyncReady"] `
    -and ([int] $operationsConvergenceSnapshot["kubernetesReportSyncFailedCount"]) -eq 0 `
    -and "ready".Equals([string] $operationsConvergenceSnapshot["kubernetesReportSyncSourceReportResult"], [System.StringComparison]::OrdinalIgnoreCase)
$dataFlowStoragePlanSnapshotPassed = $dataFlowStoragePlanSnapshotValid -and [bool] $dataFlowStoragePlanSnapshot["passed"]
$dataFlowStorageTransitionRunbookSnapshotPassed = $dataFlowStorageTransitionRunbookSnapshotValid -and [bool] $dataFlowStorageTransitionRunbookSnapshot["passed"]
$secretRotationSnapshotPassed = $secretRotationSnapshotValid -and [bool] $secretRotationSnapshot["passed"]
$commercialIntegrationSnapshotPassed = $commercialIntegrationSnapshotValid -and [bool] $commercialIntegrationSnapshot["passed"]
$commercialApprovalSnapshotPassed = $commercialApprovalSnapshotValid -and [bool] $commercialApprovalSnapshot["passed"]
$enterpriseAuthSmokeSnapshotAccepted = $enterpriseAuthSmokeSnapshotValid -and [bool] $enterpriseAuthSmokeSnapshot["accepted"]
$monitoringThresholdSnapshotPassed = $monitoringThresholdSnapshotValid -and [bool] $monitoringThresholdSnapshot["passed"] -and [bool] $monitoringThresholdSnapshot["complete"]

$evidenceText = $DeploymentEvidenceRef + $OperationsReadinessRef + $OperationsConvergenceRef + $DataFlowStoragePlanEvidenceRef + $DataFlowStorageTransitionRunbookEvidenceRef + $SecretRotationEvidenceRef + $CommercialIntegrationEvidenceRef + $CommercialApprovalEvidenceRef + $EnterpriseAuthEvidenceRef + $BackupRestoreEvidenceRef + $HaDrEvidenceRef + $MonitoringEvidenceRef + $SecurityEvidenceRef + $IamRbacEvidenceRef + $RunbookReviewRef + $TroubleshootingReviewRef + $SupportEscalationRef + $SupportSlaRef + $KnownGapsRef
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $HandoffStartedAt + $HandoffCompletedAt + $ChangeApprovalRef + $evidenceText + $OperationsReadinessJsonPath + $OperationsConvergenceJsonPath + $DataFlowStoragePlanJsonPath + $DataFlowStorageTransitionRunbookJsonPath + $SecretRotationJsonPath + $CommercialIntegrationJsonPath + $CommercialApprovalJsonPath + $EnterpriseAuthJsonPath + $MonitoringThresholdJsonPath) -or $ConfirmRunbookReviewed -or $ConfirmTroubleshootingReviewed -or $ConfirmRollbackReviewed -or $ConfirmSupportEscalationReviewed -or $ConfirmKnownGapsAccepted -or $ConfirmOperationsReadinessSnapshotReviewed -or $ConfirmOperationsConvergenceSnapshotReviewed -or $ConfirmDataFlowStoragePlanReviewed -or $ConfirmDataFlowStorageTransitionRunbookReviewed -or $ConfirmSecretRotationSnapshotReviewed -or $ConfirmCommercialIntegrationSnapshotReviewed -or $ConfirmCommercialApprovalSnapshotReviewed -or $ConfirmEnterpriseAuthSmokeSnapshotReviewed -or $ConfirmMonitoringThresholdReviewed -or $ConfirmNoSecretValues -or $RequireOperationsSnapshotEvidence
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
    Add-Check "operations-convergence-snapshot-ready" "Operations convergence snapshot ready" $operationsConvergenceSnapshotReady "result=$($operationsConvergenceSnapshot["result"]); readinessResult=$($operationsConvergenceSnapshot["readinessResult"]); finalizerResult=$($operationsConvergenceSnapshot["finalizerResult"]); finalizerReadinessResult=$($operationsConvergenceSnapshot["finalizerReadinessResult"]); finalizerFailed=$($operationsConvergenceSnapshot["finalizerFailedCount"]); finalizerGaps=$($operationsConvergenceSnapshot["finalizerGapCount"]); kubernetesReportSyncReady=$($operationsConvergenceSnapshot["kubernetesReportSyncReady"]); failedSyncChecks=$($operationsConvergenceSnapshot["kubernetesReportSyncFailedCount"]); sourceReportResult=$($operationsConvergenceSnapshot["kubernetesReportSyncSourceReportResult"])" $OperationsConvergenceRef
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
Add-EvidenceCheck "data-flow-storage-transition-runbook-evidence" "Data-flow storage transition runbook target evidence" ([bool] $RequireProductionEvidence) $DataFlowStorageTransitionRunbookEvidenceRef "target backfill, dual-write or partition toggle, rollback, reconciliation, dashboard cutover, and retention dry-run evidence"
if ([bool] $RequireProductionEvidence -or [bool] $dataFlowStorageTransitionRunbookSnapshot["provided"]) {
    Add-Check "data-flow-storage-transition-runbook-snapshot-parsed" "Data-flow storage transition runbook snapshot parsed" $dataFlowStorageTransitionRunbookSnapshotValid $dataFlowStorageTransitionRunbookSnapshot["detail"] $DataFlowStorageTransitionRunbookEvidenceRef
    Add-Check "data-flow-storage-transition-runbook-snapshot-passed" "Data-flow storage transition runbook snapshot passed" $dataFlowStorageTransitionRunbookSnapshotPassed "result=$($dataFlowStorageTransitionRunbookSnapshot["result"]); failures=$($dataFlowStorageTransitionRunbookSnapshot["failureCount"]); candidateStore=$($dataFlowStorageTransitionRunbookSnapshot["candidateStore"])" $DataFlowStorageTransitionRunbookEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $dataFlowStorageTransitionRunbookSnapshot["provided"] -or [bool] $ConfirmDataFlowStorageTransitionRunbookReviewed) {
    Add-Check "data-flow-storage-transition-runbook-reviewed" "Data-flow storage transition runbook reviewed" ([bool] $ConfirmDataFlowStorageTransitionRunbookReviewed -and $dataFlowStorageTransitionRunbookSnapshotValid) "confirmed=$([bool] $ConfirmDataFlowStorageTransitionRunbookReviewed); snapshotValid=$dataFlowStorageTransitionRunbookSnapshotValid" $DataFlowStorageTransitionRunbookEvidenceRef
}
Add-EvidenceCheck "secret-rotation-evidence" "Secret/certificate rotation target evidence" ([bool] $RequireProductionEvidence) $SecretRotationEvidenceRef "target secret/certificate rotation result=passed"
if ([bool] $RequireProductionEvidence -or [bool] $secretRotationSnapshot["provided"]) {
    Add-Check "secret-rotation-snapshot-parsed" "Secret/certificate rotation snapshot parsed" $secretRotationSnapshotValid $secretRotationSnapshot["detail"] $SecretRotationEvidenceRef
    Add-Check "secret-rotation-snapshot-passed" "Secret/certificate rotation snapshot passed" $secretRotationSnapshotPassed "result=$($secretRotationSnapshot["result"]); core=$($secretRotationSnapshot["coreRotatedCount"])/$($secretRotationSnapshot["coreRequiredCount"]); failures=$($secretRotationSnapshot["failureCount"]); planned=$($secretRotationSnapshot["plannedCount"])" $SecretRotationEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $secretRotationSnapshot["provided"] -or [bool] $ConfirmSecretRotationSnapshotReviewed) {
    Add-Check "secret-rotation-snapshot-reviewed" "Secret/certificate rotation snapshot reviewed" ([bool] $ConfirmSecretRotationSnapshotReviewed -and $secretRotationSnapshotValid) "confirmed=$([bool] $ConfirmSecretRotationSnapshotReviewed); snapshotValid=$secretRotationSnapshotValid" $SecretRotationEvidenceRef
}
Add-EvidenceCheck "commercial-integration-evidence" "Commercial integration target evidence" ([bool] $RequireProductionEvidence) $CommercialIntegrationEvidenceRef "target commercial integration result=passed without native processor API claims"
if ([bool] $RequireProductionEvidence -or [bool] $commercialIntegrationSnapshot["provided"]) {
    Add-Check "commercial-integration-snapshot-parsed" "Commercial integration snapshot parsed" $commercialIntegrationSnapshotValid $commercialIntegrationSnapshot["detail"] $CommercialIntegrationEvidenceRef
    Add-Check "commercial-integration-snapshot-passed" "Commercial integration snapshot passed" $commercialIntegrationSnapshotPassed "result=$($commercialIntegrationSnapshot["result"]); requiredVerified=$($commercialIntegrationSnapshot["requiredVerifiedCount"])/$($commercialIntegrationSnapshot["requiredCount"]); failures=$($commercialIntegrationSnapshot["failureCount"])" $CommercialIntegrationEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $commercialIntegrationSnapshot["provided"] -or [bool] $ConfirmCommercialIntegrationSnapshotReviewed) {
    Add-Check "commercial-integration-snapshot-reviewed" "Commercial integration snapshot reviewed" ([bool] $ConfirmCommercialIntegrationSnapshotReviewed -and $commercialIntegrationSnapshotValid) "confirmed=$([bool] $ConfirmCommercialIntegrationSnapshotReviewed); snapshotValid=$commercialIntegrationSnapshotValid" $CommercialIntegrationEvidenceRef
}
Add-EvidenceCheck "commercial-approval-evidence" "Commercial approval target evidence" ([bool] $RequireProductionEvidence) $CommercialApprovalEvidenceRef "target commercial approval result=passed for final pricing, terms, support SLA, license agreement, legal approval, and pilot contract boundary"
if ([bool] $RequireProductionEvidence -or [bool] $commercialApprovalSnapshot["provided"]) {
    Add-Check "commercial-approval-snapshot-parsed" "Commercial approval snapshot parsed" $commercialApprovalSnapshotValid $commercialApprovalSnapshot["detail"] $CommercialApprovalEvidenceRef
    Add-Check "commercial-approval-snapshot-passed" "Commercial approval snapshot passed" $commercialApprovalSnapshotPassed "result=$($commercialApprovalSnapshot["result"]); failures=$($commercialApprovalSnapshot["failureCount"]); priceListApproved=$($commercialApprovalSnapshot["pricingPolicyProposalApprovedPriceListCount"])" $CommercialApprovalEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $commercialApprovalSnapshot["provided"] -or [bool] $ConfirmCommercialApprovalSnapshotReviewed) {
    Add-Check "commercial-approval-snapshot-reviewed" "Commercial approval snapshot reviewed" ([bool] $ConfirmCommercialApprovalSnapshotReviewed -and $commercialApprovalSnapshotValid) "confirmed=$([bool] $ConfirmCommercialApprovalSnapshotReviewed); snapshotValid=$commercialApprovalSnapshotValid" $CommercialApprovalEvidenceRef
}
Add-EvidenceCheck "enterprise-auth-evidence" "Enterprise auth target evidence" ([bool] $RequireProductionEvidence) $EnterpriseAuthEvidenceRef "target IdP/directory smoke result=passed or contracted scope-out"
if ([bool] $RequireProductionEvidence -or [bool] $enterpriseAuthSmokeSnapshot["provided"]) {
    Add-Check "enterprise-auth-smoke-snapshot-parsed" "Enterprise auth smoke snapshot parsed" $enterpriseAuthSmokeSnapshotValid $enterpriseAuthSmokeSnapshot["detail"] $EnterpriseAuthEvidenceRef
    Add-Check "enterprise-auth-smoke-snapshot-accepted" "Enterprise auth smoke snapshot accepted" $enterpriseAuthSmokeSnapshotAccepted "result=$($enterpriseAuthSmokeSnapshot["result"]); scopeOutAccepted=$($enterpriseAuthSmokeSnapshot["scopeOutAccepted"]); pass=$($enterpriseAuthSmokeSnapshot["passCount"]); fail=$($enterpriseAuthSmokeSnapshot["failCount"]); blocked=$($enterpriseAuthSmokeSnapshot["blockedCount"])" $EnterpriseAuthEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $enterpriseAuthSmokeSnapshot["provided"] -or [bool] $ConfirmEnterpriseAuthSmokeSnapshotReviewed) {
    Add-Check "enterprise-auth-smoke-snapshot-reviewed" "Enterprise auth smoke snapshot reviewed" ([bool] $ConfirmEnterpriseAuthSmokeSnapshotReviewed -and $enterpriseAuthSmokeSnapshotValid) "confirmed=$([bool] $ConfirmEnterpriseAuthSmokeSnapshotReviewed); snapshotValid=$enterpriseAuthSmokeSnapshotValid" $EnterpriseAuthEvidenceRef
}
Add-EvidenceCheck "backup-restore-evidence" "Backup/restore target evidence" ([bool] $RequireProductionEvidence) $BackupRestoreEvidenceRef "target backup restore or DR drill evidence"
Add-EvidenceCheck "ha-dr-evidence" "HA/DR target evidence" ([bool] $RequireProductionEvidence) $HaDrEvidenceRef "target HA/DR readiness evidence"
Add-EvidenceCheck "monitoring-evidence" "Monitoring target evidence" ([bool] $RequireProductionEvidence) $MonitoringEvidenceRef "target Prometheus/Alertmanager/Grafana evidence"
if ([bool] $RequireProductionEvidence -or [bool] $monitoringThresholdSnapshot["provided"]) {
    Add-Check "monitoring-threshold-snapshot-parsed" "Monitoring threshold snapshot parsed" $monitoringThresholdSnapshotValid $monitoringThresholdSnapshot["detail"] $MonitoringEvidenceRef
    Add-Check "monitoring-threshold-snapshot-passed" "Monitoring threshold snapshot passed" $monitoringThresholdSnapshotPassed "result=$($monitoringThresholdSnapshot["result"]); alerts=$($monitoringThresholdSnapshot["mappedAlertCount"])/$($monitoringThresholdSnapshot["requiredAlertCount"]); failures=$($monitoringThresholdSnapshot["failureCount"]); complete=$($monitoringThresholdSnapshot["complete"])" $MonitoringEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $monitoringThresholdSnapshot["provided"] -or [bool] $ConfirmMonitoringThresholdReviewed) {
    Add-Check "monitoring-threshold-reviewed" "Monitoring threshold snapshot reviewed" ([bool] $ConfirmMonitoringThresholdReviewed -and $monitoringThresholdSnapshotValid) "confirmed=$([bool] $ConfirmMonitoringThresholdReviewed); snapshotValid=$monitoringThresholdSnapshotValid" $MonitoringEvidenceRef
}
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
    dataFlowStorageTransitionRunbook = $DataFlowStorageTransitionRunbookEvidenceRef
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
    dataFlowStorageTransitionRunbook = $dataFlowStorageTransitionRunbookSnapshot
    secretRotation = $secretRotationSnapshot
    commercialIntegration = $commercialIntegrationSnapshot
    commercialApproval = $commercialApprovalSnapshot
    enterpriseAuthSmoke = $enterpriseAuthSmokeSnapshot
    monitoringThreshold = $monitoringThresholdSnapshot
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
    dataFlowStorageTransitionRunbookReviewed = [bool] $ConfirmDataFlowStorageTransitionRunbookReviewed
    secretRotationSnapshotReviewed = [bool] $ConfirmSecretRotationSnapshotReviewed
    commercialIntegrationSnapshotReviewed = [bool] $ConfirmCommercialIntegrationSnapshotReviewed
    commercialApprovalSnapshotReviewed = [bool] $ConfirmCommercialApprovalSnapshotReviewed
    enterpriseAuthSmokeSnapshotReviewed = [bool] $ConfirmEnterpriseAuthSmokeSnapshotReviewed
    monitoringThresholdReviewed = [bool] $ConfirmMonitoringThresholdReviewed
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
    operationsConvergenceFinalizerFailedCount = $operationsConvergenceSnapshot["finalizerFailedCount"]
    operationsConvergenceFinalizerGapCount = $operationsConvergenceSnapshot["finalizerGapCount"]
    operationsConvergenceKubernetesReportSyncReady = $operationsConvergenceSnapshot["kubernetesReportSyncReady"]
    operationsConvergenceKubernetesReportSyncSourceReportResult = $operationsConvergenceSnapshot["kubernetesReportSyncSourceReportResult"]
    dataFlowStoragePlanSnapshotResult = $dataFlowStoragePlanSnapshot["result"]
    dataFlowStorageTransitionRunbookSnapshotResult = $dataFlowStorageTransitionRunbookSnapshot["result"]
    secretRotationSnapshotResult = $secretRotationSnapshot["result"]
    commercialIntegrationSnapshotResult = $commercialIntegrationSnapshot["result"]
    commercialApprovalSnapshotResult = $commercialApprovalSnapshot["result"]
    enterpriseAuthSmokeSnapshotResult = $enterpriseAuthSmokeSnapshot["result"]
    monitoringThresholdSnapshotResult = $monitoringThresholdSnapshot["result"]
})
[void] $report.Add("checks", [object] $checkArray)
[void] $report.Add("decisionRule", "Production/B2B operations handoff package readiness requires result=passed from the target environment, reviewed runbook/troubleshooting/rollback/support paths, accepted known gaps, no-secret confirmation, and references to target readiness, convergence, data-flow storage transition, data-flow storage transition runbook, secret rotation, commercial integration, commercial approval, enterprise auth, backup/restore, HA/DR, monitoring, security, and IAM/RBAC evidence when production evidence is required. When operations snapshot evidence is required, the latest operations readiness snapshot must be result=ready and the latest operations readiness convergence snapshot must be result=ready with readinessResult=ready, finalizer result=ready, finalizer failed/gap counts at zero, Kubernetes report sync ready, failedSyncChecks=0, and sourceReportResult=ready. When production evidence is required, the data-flow storage plan, data-flow storage transition runbook, secret rotation, commercial integration, commercial approval, and monitoring threshold snapshots must be result=passed, the enterprise auth smoke snapshot must be result=passed or result=scope-out with accepted=true, and the data-flow storage plan, data-flow storage transition runbook, secret rotation, commercial integration, commercial approval, enterprise auth smoke, and monitoring threshold snapshots must be reviewed.")
[void] $report.Add("scopePolicy", "This package is a handoff wrapper for already-collected operations evidence. It can reduce sanitized operations readiness, convergence, data-flow storage plan, data-flow storage transition runbook, secret rotation, commercial integration, commercial approval, enterprise auth smoke, and monitoring threshold JSON snapshots to summary fields, but it does not execute kubectl, gh, provider APIs, notification adapters, payment adapters, storage migrations, IdP/directory login flows, Prometheus/Grafana/Alertmanager API calls, or native card/bank/tax/ERP processor calls.")
[void] $report.Add("secretPolicy", "Evidence stores only environment labels, operator/change references, timestamps, booleans, external evidence references, reduced operations readiness/convergence snapshot summaries, reduced data-flow storage plan/runbook summaries, reduced secret rotation summaries, reduced commercial evidence summaries, reduced enterprise auth smoke summaries, and reduced monitoring threshold summaries; it must not contain passwords, bearer tokens, kubeconfig values, private keys, SMTP credentials, webhook signing secrets, provider credentials, raw SQL, raw EXPLAIN JSON, object keys, raw event messages, raw provider responses, raw identity claims, OIDC codes/states/tokens, LDAP/admin passwords, raw remediation commands containing credentials, raw Alertmanager receiver secrets, raw price tables, raw contract text, or customer payment data.")

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
$markdownLines += "- Convergence: provided=$($operationsConvergenceSnapshot["provided"]); parsed=$($operationsConvergenceSnapshot["parsed"]); result=$($operationsConvergenceSnapshot["result"]); readiness=$($operationsConvergenceSnapshot["readinessResult"]); finalizerFailed=$($operationsConvergenceSnapshot["finalizerFailedCount"]); finalizerGaps=$($operationsConvergenceSnapshot["finalizerGapCount"]); kubernetesReportSyncReady=$($operationsConvergenceSnapshot["kubernetesReportSyncReady"]); sourceReportResult=$($operationsConvergenceSnapshot["kubernetesReportSyncSourceReportResult"])"
foreach ($pendingCheck in @($operationsReadinessSnapshot["topPendingChecks"])) {
    $markdownLines += "- Readiness pending: [$($pendingCheck.status)] $($pendingCheck.category) / $($pendingCheck.name): $($pendingCheck.detail)"
}

$markdownLines += ""
$markdownLines += "## Target Evidence Snapshots"
$markdownLines += ""
$markdownLines += "- Data-flow storage plan: provided=$($dataFlowStoragePlanSnapshot["provided"]); parsed=$($dataFlowStoragePlanSnapshot["parsed"]); result=$($dataFlowStoragePlanSnapshot["result"]); candidateStore=$($dataFlowStoragePlanSnapshot["candidateStore"]); targetP95QueryLatencyMs=$($dataFlowStoragePlanSnapshot["targetP95QueryLatencyMs"]); passed=$($dataFlowStoragePlanSnapshot["passedCount"]); pending=$($dataFlowStoragePlanSnapshot["pendingCount"]); checks=$($dataFlowStoragePlanSnapshot["checkCount"])"
$markdownLines += "- Data-flow storage transition runbook: provided=$($dataFlowStorageTransitionRunbookSnapshot["provided"]); parsed=$($dataFlowStorageTransitionRunbookSnapshot["parsed"]); result=$($dataFlowStorageTransitionRunbookSnapshot["result"]); storagePlanResult=$($dataFlowStorageTransitionRunbookSnapshot["storagePlanResult"]); candidateStore=$($dataFlowStorageTransitionRunbookSnapshot["candidateStore"]); failures=$($dataFlowStorageTransitionRunbookSnapshot["failureCount"]); checks=$($dataFlowStorageTransitionRunbookSnapshot["checkCount"])"
$markdownLines += "- Secret rotation: provided=$($secretRotationSnapshot["provided"]); parsed=$($secretRotationSnapshot["parsed"]); result=$($secretRotationSnapshot["result"]); core=$($secretRotationSnapshot["coreRotatedCount"])/$($secretRotationSnapshot["coreRequiredCount"]); failures=$($secretRotationSnapshot["failureCount"]); planned=$($secretRotationSnapshot["plannedCount"])"
$markdownLines += "- Commercial integration: provided=$($commercialIntegrationSnapshot["provided"]); parsed=$($commercialIntegrationSnapshot["parsed"]); result=$($commercialIntegrationSnapshot["result"]); requiredVerified=$($commercialIntegrationSnapshot["requiredVerifiedCount"])/$($commercialIntegrationSnapshot["requiredCount"]); failures=$($commercialIntegrationSnapshot["failureCount"]); planned=$($commercialIntegrationSnapshot["plannedCount"])"
$markdownLines += "- Commercial approval: provided=$($commercialApprovalSnapshot["provided"]); parsed=$($commercialApprovalSnapshot["parsed"]); result=$($commercialApprovalSnapshot["result"]); failures=$($commercialApprovalSnapshot["failureCount"]); checks=$($commercialApprovalSnapshot["checkCount"]); priceListApproved=$($commercialApprovalSnapshot["pricingPolicyProposalApprovedPriceListCount"])"
$markdownLines += "- Enterprise auth smoke: provided=$($enterpriseAuthSmokeSnapshot["provided"]); parsed=$($enterpriseAuthSmokeSnapshot["parsed"]); result=$($enterpriseAuthSmokeSnapshot["result"]); pass=$($enterpriseAuthSmokeSnapshot["passCount"]); fail=$($enterpriseAuthSmokeSnapshot["failCount"]); blocked=$($enterpriseAuthSmokeSnapshot["blockedCount"]); scopeOutAccepted=$($enterpriseAuthSmokeSnapshot["scopeOutAccepted"])"
$markdownLines += "- Monitoring threshold: provided=$($monitoringThresholdSnapshot["provided"]); parsed=$($monitoringThresholdSnapshot["parsed"]); result=$($monitoringThresholdSnapshot["result"]); alerts=$($monitoringThresholdSnapshot["mappedAlertCount"])/$($monitoringThresholdSnapshot["requiredAlertCount"]); routes=$($monitoringThresholdSnapshot["routeCount"]); failures=$($monitoringThresholdSnapshot["failureCount"]); complete=$($monitoringThresholdSnapshot["complete"])"
foreach ($pendingCheck in @($dataFlowStoragePlanSnapshot["topPendingChecks"])) {
    $markdownLines += "- Data-flow pending: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.title): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($dataFlowStorageTransitionRunbookSnapshot["topFailedChecks"])) {
    $markdownLines += "- Data-flow transition runbook failed: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($secretRotationSnapshot["topChecks"])) {
    $markdownLines += "- Secret rotation pending: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($commercialIntegrationSnapshot["topChecks"])) {
    $markdownLines += "- Commercial integration pending: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($commercialApprovalSnapshot["topChecks"])) {
    $markdownLines += "- Commercial approval pending: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($enterpriseAuthSmokeSnapshot["topChecks"])) {
    $markdownLines += "- Enterprise auth pending: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($monitoringThresholdSnapshot["topFailedChecks"])) {
    $markdownLines += "- Monitoring threshold failed: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
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
$markdownLines += "- Record passed target package: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-handoff-package.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -HandoffStartedAt <iso-time> -HandoffCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DeploymentEvidenceRef <ref> -OperationsReadinessRef <ref> -OperationsConvergenceRef <ref> -DataFlowStoragePlanEvidenceRef <ref> -DataFlowStorageTransitionRunbookEvidenceRef <ref> -OperationsReadinessJsonPath .\.osmu-run\latest-operations-readiness.json -OperationsConvergenceJsonPath .\.osmu-run\latest-operations-readiness-convergence.json -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -DataFlowStorageTransitionRunbookJsonPath .\.osmu-run\latest-data-flow-storage-transition-runbook-evidence.json -SecretRotationEvidenceRef <ref> -SecretRotationJsonPath .\.osmu-run\latest-secret-rotation-evidence.json -CommercialIntegrationEvidenceRef <ref> -CommercialApprovalEvidenceRef <ref> -CommercialIntegrationJsonPath .\.osmu-run\latest-commercial-integration-evidence.json -CommercialApprovalJsonPath .\.osmu-run\latest-commercial-approval-evidence.json -EnterpriseAuthEvidenceRef <ref> -EnterpriseAuthJsonPath .\.osmu-run\latest-enterprise-auth-smoke.json -BackupRestoreEvidenceRef <ref> -HaDrEvidenceRef <ref> -MonitoringEvidenceRef <ref> -MonitoringThresholdJsonPath .\.osmu-run\latest-monitoring-threshold-evidence.json -SecurityEvidenceRef <ref> -IamRbacEvidenceRef <ref> -RunbookReviewRef <ref> -TroubleshootingReviewRef <ref> -SupportEscalationRef <ref> -SupportSlaRef <ref> -KnownGapsRef <ref> -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackReviewed -ConfirmSupportEscalationReviewed -ConfirmKnownGapsAccepted -ConfirmOperationsReadinessSnapshotReviewed -ConfirmOperationsConvergenceSnapshotReviewed -ConfirmDataFlowStoragePlanReviewed -ConfirmDataFlowStorageTransitionRunbookReviewed -ConfirmSecretRotationSnapshotReviewed -ConfirmCommercialIntegrationSnapshotReviewed -ConfirmCommercialApprovalSnapshotReviewed -ConfirmEnterpriseAuthSmokeSnapshotReviewed -ConfirmMonitoringThresholdReviewed -ConfirmNoSecretValues -RequireProductionEvidence -RequireOperationsSnapshotEvidence -FailIfNotPassed``"

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
