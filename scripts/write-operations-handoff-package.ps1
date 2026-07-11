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
    [string] $DataFlowQueryRetentionBudgetEvidenceRef = "",
    [string] $DataFlowStorageTransitionRunbookEvidenceRef = "",
    [string] $OperationsReadinessJsonPath = "",
    [string] $OperationsConvergenceJsonPath = "",
    [string] $DataFlowStoragePlanJsonPath = "",
    [string] $DataFlowQueryRetentionBudgetJsonPath = "",
    [string] $DataFlowStorageTransitionRunbookJsonPath = "",
    [string] $SecretRotationEvidenceRef = "",
    [string] $SecretRotationJsonPath = "",
    [string] $CommercialIntegrationEvidenceRef = "",
    [string] $CommercialApprovalEvidenceRef = "",
    [string] $ChargebackCloseoutEvidenceRef = "",
    [string] $CommercialIntegrationJsonPath = "",
    [string] $CommercialApprovalJsonPath = "",
    [string] $ChargebackCloseoutJsonPath = "",
    [string] $EnterpriseAuthEvidenceRef = "",
    [string] $EnterpriseAuthJsonPath = "",
    [string] $EnterpriseAuthJitRollbackEvidenceRef = "",
    [string] $EnterpriseAuthJitRollbackJsonPath = "",
    [string] $BackupRestoreEvidenceRef = "",
    [string] $HaDrEvidenceRef = "",
    [string] $MonitoringEvidenceRef = "",
    [string] $MonitoringThresholdJsonPath = "",
    [string] $ClusterNetworkAccessReviewEvidenceRef = "",
    [string] $ClusterNetworkAccessReviewJsonPath = "",
    [string] $HelmValuesHardeningEvidenceRef = "",
    [string] $HelmValuesHardeningJsonPath = "",
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
    [switch] $ConfirmDataFlowQueryRetentionBudgetReviewed,
    [switch] $ConfirmDataFlowStorageTransitionRunbookReviewed,
    [switch] $ConfirmSecretRotationSnapshotReviewed,
    [switch] $ConfirmCommercialIntegrationSnapshotReviewed,
    [switch] $ConfirmCommercialApprovalSnapshotReviewed,
    [switch] $ConfirmChargebackCloseoutSnapshotReviewed,
    [switch] $ConfirmEnterpriseAuthSmokeSnapshotReviewed,
    [switch] $ConfirmEnterpriseAuthJitRollbackSnapshotReviewed,
    [switch] $ConfirmMonitoringThresholdReviewed,
    [switch] $ConfirmClusterNetworkAccessReviewReviewed,
    [switch] $ConfirmHelmValuesHardeningReviewed,
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

function Read-Utf8Text([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
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

function Assert-SanitizedChargebackCloseoutJson([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $forbiddenPropertyPattern = '(?i)"(rawCustomer|rawCustomerData|raw_customer_data|rawPayment|raw_payment|customerPaymentData|customer_payment_data|paymentReference|payment_reference|paymentTarget|payment_target|paymentPayload|payment_payload|providerPayload|provider_payload|providerResponse|provider_response|rawProviderResponse|raw_provider_response|rawInvoice|raw_invoice|invoiceDocument|invoice_document|rawPriceTable|raw_price_table|priceTable|price_table|endpointUrl|endpoint_url|webhookUrl|webhook_url|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:'
    $credentialPattern = '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|webhook[_-]?secret|provider[_-]?secret)\s*[=:]\s*\S+'
    if ($Value -match $forbiddenPropertyPattern -or $Value -match $credentialPattern) {
        throw "$Label appears to contain raw chargeback, invoice, provider, endpoint, payment, or credential-shaped content. Store only sanitized chargeback closeout summary fields."
    }
}

function Assert-SanitizedEnterpriseAuthJitRollbackJson([string] $Value, [string] $Label) {    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $forbiddenPropertyPattern = '(?i)"(rawClaim|rawClaims|raw_claim|raw_claims|claimPayload|claim_payload|claimJson|claim_json|claimsJson|claims_json|rawIdentityProviderResponse|raw_identity_provider_response|rawDirectoryResponse|raw_directory_response|idToken|id_token|accessToken|access_token|refreshToken|refresh_token|authorizationCode|authorization_code|oidcCode|oidc_code|oidcState|oidc_state|ldapPassword|ldap_password|adminPassword|admin_password|clientSecret|client_secret|password|passwd|secret|token|credential)"\s*:'
    $jwtPattern = '\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b'
    $credentialPattern = '(?i)\b(password|passwd|secret|token|credential|client[_-]?secret|ldap[_-]?password|admin[_-]?password|oidc[_-]?code|oidc[_-]?state|refresh[_-]?token|access[_-]?token|id[_-]?token)\s*[=:]\s*\S+'
    if ($Value -match $forbiddenPropertyPattern -or $Value -match $jwtPattern -or $Value -match $credentialPattern) {
        throw "$Label appears to contain raw identity, claim, token, or credential-shaped content. Store only sanitized enterprise auth JIT rollback summary fields."
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
    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
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

function Get-FirstPropertyText([object] $Object, [string[]] $Names) {
    foreach ($name in $Names) {
        $value = Get-PropertyText $Object $name
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }
    return ""
}

function Get-TargetIdentityText([object] $Object, [string] $FieldName) {
    if ($null -eq $Object) {
        return ""
    }

    switch ($FieldName) {
        "environmentName" { return Get-FirstPropertyText $Object @("environmentName") }
        "targetCluster" { return Get-FirstPropertyText $Object @("targetCluster", "cluster") }
        "operatorName" { return Get-FirstPropertyText $Object @("operatorName", "operator") }
        default { return Get-PropertyText $Object $FieldName }
    }
}

function Test-TargetIdentityField([object] $Snapshot, [string] $Label, [string] $FieldName, [string] $ExpectedValue) {
    $actualValue = Get-TargetIdentityText $Snapshot $FieldName
    if ([string]::IsNullOrWhiteSpace($ExpectedValue)) {
        return "$Label.$FieldName cannot be checked because handoff $FieldName is missing"
    }
    if ([string]::IsNullOrWhiteSpace($actualValue)) {
        return "$Label.$FieldName missing; expected=$ExpectedValue"
    }
    if (-not $ExpectedValue.Equals($actualValue, [System.StringComparison]::Ordinal)) {
        return "$Label.$FieldName=$actualValue expected=$ExpectedValue"
    }
    return ""
}

function Test-TargetIdentityConsistency([object] $Snapshot, [string] $Label, [string] $ExpectedEnvironmentName, [string] $ExpectedTargetCluster, [string] $ExpectedOperatorName) {
    $failures = New-Object System.Collections.Generic.List[string]
    foreach ($field in @(
        @("environmentName", $ExpectedEnvironmentName),
        @("targetCluster", $ExpectedTargetCluster),
        @("operatorName", $ExpectedOperatorName)
    )) {
        $failure = Test-TargetIdentityField $Snapshot $Label ([string] $field[0]) ([string] $field[1])
        if (-not [string]::IsNullOrWhiteSpace($failure)) {
            [void] $failures.Add($failure)
        }
    }

    if ($failures.Count -gt 0) {
        return [pscustomobject]@{
            passed = $false
            detail = $failures -join "; "
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "$Label target identity matches environmentName=$ExpectedEnvironmentName targetCluster=$ExpectedTargetCluster operatorName=$ExpectedOperatorName"
    }
}

function Test-TargetEvidenceIdentityConsistency([object[]] $Entries, [string] $ExpectedEnvironmentName, [string] $ExpectedTargetCluster, [string] $ExpectedOperatorName) {
    $checked = 0
    foreach ($entry in $Entries) {
        $required = [bool] $entry.required
        $snapshot = $entry.snapshot
        if (-not $required -and ($null -eq $snapshot -or -not [bool] $snapshot["provided"])) {
            continue
        }

        $checked += 1
        $validation = Test-TargetIdentityConsistency $snapshot ([string] $entry.label) $ExpectedEnvironmentName $ExpectedTargetCluster $ExpectedOperatorName
        if (-not $validation.passed) {
            return [pscustomobject]@{
                passed = $false
                detail = [string] $validation.detail
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "target evidence identity matches handoff target for $checked snapshots"
    }
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

function Get-RequiredPropertyInt([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
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

function Get-RequiredPropertyBool([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
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

function Get-RequiredBoolSetSnapshot([object] $Object, [string[]] $Names) {
    $values = [ordered]@{}
    $validation = [ordered]@{}
    $allValidAndTrue = $true
    foreach ($name in $Names) {
        $required = Get-RequiredPropertyBool $Object $name
        $values[$name] = [bool] $required.value
        $validation[$name] = [ordered]@{
            valid = [bool] $required.valid
            raw = [string] $required.raw
        }
        if (-not ([bool] $required.valid) -or -not ([bool] $required.value)) {
            $allValidAndTrue = $false
        }
    }
    return [pscustomobject]@{
        values = $values
        validation = $validation
        allValidAndTrue = $allValidAndTrue
    }
}

function Get-RequiredIntSetSnapshot([object] $Object, [string[]] $Names) {
    $values = [ordered]@{}
    $validation = [ordered]@{}
    $allValid = $true
    foreach ($name in $Names) {
        $required = Get-RequiredPropertyInt $Object $name
        $values[$name] = if ($null -eq $required.value) { 0 } else { [int64] $required.value }
        $validation[$name] = [ordered]@{
            valid = [bool] $required.valid
            raw = [string] $required.raw
        }
        if (-not ([bool] $required.valid)) {
            $allValid = $false
        }
    }
    return [pscustomobject]@{
        values = $values
        validation = $validation
        allValid = $allValid
    }
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

    $raw = Read-Utf8Text $resolvedPath
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
function New-HandoffPostDispatchCommandSnapshotRow([object] $Command) {
    return [ordered]@{
        name = Get-PropertyText $Command "name"
        command = Get-PropertyText $Command "command"
        note = Get-PropertyText $Command "note"
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

function New-DataFlowQueryRetentionBudgetCheckSnapshotRow([object] $Check) {
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

function New-ChargebackCloseoutCheckSnapshotRow([object] $Check) {
    return [ordered]@{
        id = Get-PropertyText $Check "id"
        name = Get-PropertyText $Check "name"
        status = Get-PropertyText $Check "status"
        passed = Get-PropertyBool $Check "passed"
        detail = Get-PropertyText $Check "detail"
        evidenceRef = Get-PropertyText $Check "evidenceRef"
    }
}

function New-EnterpriseAuthSmokeCheckSnapshotRow([object] $Check) {    return [ordered]@{
        id = Get-PropertyText $Check "id"
        name = Get-PropertyText $Check "name"
        category = Get-PropertyText $Check "category"
        endpoint = Get-PropertyText $Check "endpoint"
        status = Get-PropertyText $Check "status"
        detail = Get-PropertyText $Check "detail"
        requiredInputs = @(Get-PropertyArray $Check "requiredInputs" | ForEach-Object { [string] $_ })
    }
}

function New-EnterpriseAuthJitRollbackCheckSnapshotRow([object] $Check) {
    return [ordered]@{
        id = Get-PropertyText $Check "id"
        name = Get-PropertyText $Check "name"
        status = Get-PropertyText $Check "status"
        passed = Get-PropertyBool $Check "passed"
        detail = Get-PropertyText $Check "detail"
        evidenceRef = Get-PropertyText $Check "evidenceRef"
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

    $provided = Get-RequiredPropertyBool $QueryPlanEvidence "provided"
    $validFormatVersion = Get-RequiredPropertyBool $QueryPlanEvidence "validFormatVersion"
    $counts = Get-RequiredIntSetSnapshot $QueryPlanEvidence @("checkCount", "passedCount", "failedCount")

    return [ordered]@{
        provided = [bool] $provided.value
        providedValid = [bool] $provided.valid
        providedRaw = [string] $provided.raw
        formatVersion = Get-PropertyText $QueryPlanEvidence "formatVersion"
        expectedFormatVersion = Get-PropertyText $QueryPlanEvidence "expectedFormatVersion"
        validFormatVersion = [bool] $validFormatVersion.value
        validFormatVersionValid = [bool] $validFormatVersion.valid
        validFormatVersionRaw = [string] $validFormatVersion.raw
        result = Get-PropertyText $QueryPlanEvidence "result"
        mode = Get-PropertyText $QueryPlanEvidence "mode"
        checkCount = $counts.values["checkCount"]
        passedCount = $counts.values["passedCount"]
        failedCount = $counts.values["failedCount"]
        countsValid = [bool] $counts.allValid
        countValidation = $counts.validation
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
        operatorName = ""
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
        candidateDecision = [ordered]@{
            candidateStore = ""
            decision = ""
            evidenceModel = ""
            requiresMariaDbQueryEvidence = $false
            requiresTargetStoreEvidence = $false
            queryPlanEvidenceRequired = $false
            queryPlanEvidencePassed = $false
            targetStoreEvidenceConfirmed = $false
            safeDataPolicy = ""
            nextAction = ""
        }
        queryPlanEvidence = $null
        queryPlanEvidenceRequired = $false
        queryPlanEvidencePassed = $false
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

    $raw = Read-Utf8Text $resolvedPath
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
    $snapshot["operatorName"] = Get-TargetIdentityText $payload "operatorName"
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
    $queryPlanEvidence = New-QueryPlanEvidenceSummarySnapshot (Get-PropertyValue $payload "queryPlanEvidence")
    $queryPlanEvidenceRequired = @("MARIADB_PARTITION", "DUAL_WRITE") -contains $snapshot["candidateStore"]
    $targetStoreEvidenceRequired = @("EXTERNAL_TIME_SERIES", "DUAL_WRITE") -contains $snapshot["candidateStore"]
    $queryPlanEvidenceProvided = $null -ne $queryPlanEvidence
    $queryPlanEvidencePassed = -not $queryPlanEvidenceRequired -and -not $queryPlanEvidenceProvided
    if ($queryPlanEvidenceProvided) {
        $queryPlanEvidencePassed = [bool] $queryPlanEvidence["provided"] `
            -and [bool] $queryPlanEvidence["providedValid"] `
            -and "osmu.mariadb-query-plan-evidence.v1".Equals([string] $queryPlanEvidence["expectedFormatVersion"], [System.StringComparison]::OrdinalIgnoreCase) `
            -and [bool] $queryPlanEvidence["validFormatVersion"] `
            -and [bool] $queryPlanEvidence["validFormatVersionValid"] `
            -and "passed".Equals([string] $queryPlanEvidence["result"], [System.StringComparison]::OrdinalIgnoreCase) `
            -and [bool] $queryPlanEvidence["countsValid"] `
            -and ([int64] $queryPlanEvidence["checkCount"]) -gt 0 `
            -and ([int64] $queryPlanEvidence["passedCount"]) -ge ([int64] $queryPlanEvidence["checkCount"]) `
            -and ([int64] $queryPlanEvidence["failedCount"]) -eq 0
    }
    $candidateDecisionPayload = Get-PropertyValue $payload "candidateDecision"
    $candidateDecision = [ordered]@{
        candidateStore = $snapshot["candidateStore"]
        decision = ""
        evidenceModel = ""
        requiresMariaDbQueryEvidence = [bool] $queryPlanEvidenceRequired
        requiresTargetStoreEvidence = [bool] $targetStoreEvidenceRequired
        queryPlanEvidenceRequired = [bool] $queryPlanEvidenceRequired
        queryPlanEvidencePassed = [bool] $queryPlanEvidencePassed
        targetStoreEvidenceConfirmed = $false
        safeDataPolicy = ""
        nextAction = ""
    }
    if ($null -ne $candidateDecisionPayload) {
        $candidateStoreFromDecision = Get-PropertyText $candidateDecisionPayload "candidateStore"
        if (-not [string]::IsNullOrWhiteSpace($candidateStoreFromDecision)) { $candidateDecision["candidateStore"] = $candidateStoreFromDecision }
        $candidateDecision["decision"] = Get-PropertyText $candidateDecisionPayload "decision"
        $candidateDecision["evidenceModel"] = Get-PropertyText $candidateDecisionPayload "evidenceModel"
        $candidateDecision["requiresMariaDbQueryEvidence"] = Get-PropertyBool $candidateDecisionPayload "requiresMariaDbQueryEvidence"
        $candidateDecision["requiresTargetStoreEvidence"] = Get-PropertyBool $candidateDecisionPayload "requiresTargetStoreEvidence"
        $candidateDecision["queryPlanEvidenceRequired"] = Get-PropertyBool $candidateDecisionPayload "queryPlanEvidenceRequired"
        $candidateDecision["queryPlanEvidencePassed"] = Get-PropertyBool $candidateDecisionPayload "queryPlanEvidencePassed"
        $candidateDecision["targetStoreEvidenceConfirmed"] = Get-PropertyBool $candidateDecisionPayload "targetStoreEvidenceConfirmed"
        $candidateDecision["safeDataPolicy"] = Get-PropertyText $candidateDecisionPayload "safeDataPolicy"
        $candidateDecision["nextAction"] = Get-PropertyText $candidateDecisionPayload "nextAction"
    }
    $snapshot["candidateDecision"] = $candidateDecision
    $snapshot["queryPlanEvidence"] = $queryPlanEvidence
    $snapshot["queryPlanEvidenceRequired"] = $queryPlanEvidenceRequired
    $snapshot["queryPlanEvidencePassed"] = $queryPlanEvidencePassed
    $snapshot["topPendingChecks"] = @($pendingRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; candidateStore=$($snapshot["candidateStore"]); pending=$($snapshot["pendingCount"]); checks=$($snapshot["checkCount"]); queryPlanEvidenceRequired=$queryPlanEvidenceRequired; queryPlanEvidencePassed=$queryPlanEvidencePassed"
    return $snapshot
}

function Read-DataFlowQueryRetentionBudgetSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false; path = ""; parsed = $false
        formatVersion = ""; expectedFormatVersion = "osmu.data-flow-query-retention-budget-evidence.v1"; validFormatVersion = $false
        result = ""; passed = $false; environmentName = ""; targetCluster = ""; operatorName = ""; evidenceRef = ""
        reviewWindow = [ordered]@{ startedAt = ""; completedAt = "" }
        storagePlanResult = ""; candidateStore = ""; storagePlanPendingCount = 0; storagePlanCheckCount = 0
        targetP95QueryLatencyMs = 0; observedP95QueryLatencyMs = 0; observedP99QueryLatencyMs = 0; querySampleCount = 0; observedQueryWindowDays = 0; queryLatencyWithinBudget = $false
        retentionBudgetSeconds = 0; detailedRetentionObservedSeconds = 0; dailyRollupRetentionObservedSeconds = 0; monthlyRollupRetentionObservedSeconds = 0
        detailedRetentionDeletedRows = 0; dailyRollupRetentionDeletedRows = 0; monthlyRollupRetentionDeletedRows = 0; retentionJobsWithinBudget = $false
        confirmations = [ordered]@{}; confirmationsValid = $false; confirmationValidation = [ordered]@{}
        metricCountsValid = $false; metricCountValidation = [ordered]@{}; failureCount = 0; checkCount = 0; topFailedChecks = @()
        detail = "No data-flow query/retention budget evidence JSON supplied."
    }
    if ([string]::IsNullOrWhiteSpace($Path)) { return $snapshot }
    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "Data-flow query/retention budget evidence JSON not found."
        return $snapshot
    }
    $raw = Read-Utf8Text $resolvedPath
    Assert-SafeText $raw "DataFlowQueryRetentionBudgetJson"
    Assert-SanitizedOperationsSnapshotJson $raw "DataFlowQueryRetentionBudgetJson"
    Assert-SanitizedDataFlowStoragePlanJson $raw "DataFlowQueryRetentionBudgetJson"
    try { $payload = $raw | ConvertFrom-Json }
    catch {
        $snapshot["detail"] = "Data-flow query/retention budget evidence JSON parse failed: $($_.Exception.Message)"
        return $snapshot
    }
    $failedRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in @(Get-PropertyArray $payload "checks")) {
        if (-not (Get-PropertyBool $check "passed")) { [void] $failedRows.Add((New-DataFlowQueryRetentionBudgetCheckSnapshotRow $check)) }
        if ($failedRows.Count -ge 5) { break }
    }
    $summary = Get-PropertyValue $payload "summary"
    $planSnapshot = Get-PropertyValue $payload "dataFlowStoragePlanSnapshot"
    $queryLatencyBudget = Get-PropertyValue $payload "queryLatencyBudget"
    $retentionBudget = Get-PropertyValue $payload "retentionBudget"
    $confirmations = Get-PropertyValue $payload "confirmations"
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
    $snapshot["reviewWindow"] = [ordered]@{ startedAt = Get-PropertyText (Get-PropertyValue $payload "reviewWindow") "startedAt"; completedAt = Get-PropertyText (Get-PropertyValue $payload "reviewWindow") "completedAt" }
    $snapshot["storagePlanResult"] = Get-PropertyText $planSnapshot "result"
    $snapshot["candidateStore"] = Get-PropertyText $planSnapshot "candidateStore"
    $snapshot["storagePlanPendingCount"] = Get-PropertyInt $planSnapshot "pendingCount"
    $snapshot["storagePlanCheckCount"] = Get-PropertyInt $planSnapshot "checkCount"
    $queryCounts = Get-RequiredIntSetSnapshot $queryLatencyBudget @("targetP95QueryLatencyMs", "observedP95QueryLatencyMs", "observedP99QueryLatencyMs", "querySampleCount", "observedQueryWindowDays")
    $retentionCounts = Get-RequiredIntSetSnapshot $retentionBudget @("budgetSeconds", "detailedRetentionObservedSeconds", "dailyRollupRetentionObservedSeconds", "monthlyRollupRetentionObservedSeconds", "detailedRetentionDeletedRows", "dailyRollupRetentionDeletedRows", "monthlyRollupRetentionDeletedRows")
    $queryWithin = Get-RequiredPropertyBool $queryLatencyBudget "withinBudget"
    $retentionWithin = Get-RequiredPropertyBool $retentionBudget "withinBudget"
    $snapshot["metricCountsValid"] = [bool] $queryCounts.allValid -and [bool] $retentionCounts.allValid -and [bool] $queryWithin.valid -and [bool] $retentionWithin.valid
    $snapshot["metricCountValidation"] = [ordered]@{ queryLatency = $queryCounts.validation; retention = $retentionCounts.validation; queryLatencyWithinBudget = [ordered]@{ valid = [bool] $queryWithin.valid; raw = [string] $queryWithin.raw }; retentionJobsWithinBudget = [ordered]@{ valid = [bool] $retentionWithin.valid; raw = [string] $retentionWithin.raw } }
    $snapshot["targetP95QueryLatencyMs"] = $queryCounts.values["targetP95QueryLatencyMs"]
    $snapshot["observedP95QueryLatencyMs"] = $queryCounts.values["observedP95QueryLatencyMs"]
    $snapshot["observedP99QueryLatencyMs"] = $queryCounts.values["observedP99QueryLatencyMs"]
    $snapshot["querySampleCount"] = $queryCounts.values["querySampleCount"]
    $snapshot["observedQueryWindowDays"] = $queryCounts.values["observedQueryWindowDays"]
    $snapshot["queryLatencyWithinBudget"] = [bool] $queryWithin.value
    $snapshot["retentionBudgetSeconds"] = $retentionCounts.values["budgetSeconds"]
    $snapshot["detailedRetentionObservedSeconds"] = $retentionCounts.values["detailedRetentionObservedSeconds"]
    $snapshot["dailyRollupRetentionObservedSeconds"] = $retentionCounts.values["dailyRollupRetentionObservedSeconds"]
    $snapshot["monthlyRollupRetentionObservedSeconds"] = $retentionCounts.values["monthlyRollupRetentionObservedSeconds"]
    $snapshot["detailedRetentionDeletedRows"] = $retentionCounts.values["detailedRetentionDeletedRows"]
    $snapshot["dailyRollupRetentionDeletedRows"] = $retentionCounts.values["dailyRollupRetentionDeletedRows"]
    $snapshot["monthlyRollupRetentionDeletedRows"] = $retentionCounts.values["monthlyRollupRetentionDeletedRows"]
    $snapshot["retentionJobsWithinBudget"] = [bool] $retentionWithin.value
    $confirmationResult = Get-RequiredBoolSetSnapshot $confirmations @("queryLatencyReviewed", "retentionJobsWithinBudget", "noObjectKeysInEvidence", "noRawSqlOrExplain", "noSecretValues")
    $snapshot["confirmations"] = $confirmationResult.values
    $snapshot["confirmationsValid"] = [bool] $confirmationResult.allValidAndTrue
    $snapshot["confirmationValidation"] = $confirmationResult.validation
    $snapshot["failureCount"] = Get-PropertyInt $summary "failureCount"
    $snapshot["checkCount"] = Get-PropertyInt $summary "checkCount"
    $snapshot["topFailedChecks"] = @($failedRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; storagePlanResult=$($snapshot["storagePlanResult"]); p95=$($snapshot["observedP95QueryLatencyMs"])/$($snapshot["targetP95QueryLatencyMs"]); retentionBudget=$($snapshot["retentionBudgetSeconds"]); failures=$($snapshot["failureCount"]); checks=$($snapshot["checkCount"]); confirmationsValid=$($snapshot["confirmationsValid"]); metricsValid=$($snapshot["metricCountsValid"])"
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
        confirmationsValid = $false
        confirmationValidation = [ordered]@{}
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

    $raw = Read-Utf8Text $resolvedPath
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
    $confirmationResult = Get-RequiredBoolSetSnapshot $confirmations @(
        "backfillRehearsed",
        "dualWriteOrPartitionToggleReviewed",
        "rollbackRehearsed",
        "reconciliationPassed",
        "dashboardCutoverReviewed",
        "retentionDryRunReviewed",
        "noObjectKeysInAggregates",
        "noSecretValues"
    )
    $snapshot["confirmations"] = $confirmationResult.values
    $snapshot["confirmationsValid"] = [bool] $confirmationResult.allValidAndTrue
    $snapshot["confirmationValidation"] = $confirmationResult.validation
    $snapshot["topFailedChecks"] = @($failedRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; storagePlanResult=$($snapshot["storagePlanResult"]); candidateStore=$($snapshot["candidateStore"]); failures=$($snapshot["failureCount"]); checks=$($snapshot["checkCount"]); confirmationsValid=$($snapshot["confirmationsValid"])"
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
        countsValid = $false
        countValidation = [ordered]@{}
        paymentProviderAdapterReadinessReviewedValid = $false
        paymentProviderAdapterReadinessReviewedRaw = "<missing>"
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
    $countResult = Get-RequiredIntSetSnapshot $summary @(
        "integrationCount",
        "verifiedCount",
        "requiredCount",
        "requiredVerifiedCount",
        "paymentProviderAdapterWebhookReadyProfileCount",
        "paymentProviderAdapterNativeReadyProfileCount",
        "failureCount",
        "plannedCount"
    )
    $snapshot["integrationCount"] = $countResult.values["integrationCount"]
    $snapshot["verifiedCount"] = $countResult.values["verifiedCount"]
    $snapshot["requiredCount"] = $countResult.values["requiredCount"]
    $snapshot["requiredVerifiedCount"] = $countResult.values["requiredVerifiedCount"]
    $snapshot["paymentProviderAdapterWebhookReadyProfileCount"] = $countResult.values["paymentProviderAdapterWebhookReadyProfileCount"]
    $snapshot["paymentProviderAdapterNativeReadyProfileCount"] = $countResult.values["paymentProviderAdapterNativeReadyProfileCount"]
    $snapshot["failureCount"] = $countResult.values["failureCount"]
    $snapshot["plannedCount"] = $countResult.values["plannedCount"]
    $snapshot["countsValid"] = [bool] $countResult.allValid
    $snapshot["countValidation"] = $countResult.validation
    $reviewedResult = Get-RequiredPropertyBool $summary "paymentProviderAdapterReadinessReviewed"
    $snapshot["paymentProviderAdapterReadinessReviewed"] = [bool] $reviewedResult.value
    $snapshot["paymentProviderAdapterReadinessReviewedValid"] = [bool] $reviewedResult.valid
    $snapshot["paymentProviderAdapterReadinessReviewedRaw"] = [string] $reviewedResult.raw
    $snapshot["paymentProviderAdapterReadinessStatus"] = Get-PropertyText $summary "paymentProviderAdapterReadinessStatus"
    $snapshot["checkCount"] = $checks.Count
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; requiredVerified=$($snapshot["requiredVerifiedCount"])/$($snapshot["requiredCount"]); failures=$($snapshot["failureCount"]); planned=$($snapshot["plannedCount"]); countsValid=$($snapshot["countsValid"]); paymentProviderAdapterReadinessReviewed=$($snapshot["paymentProviderAdapterReadinessReviewedRaw"])(valid=$($snapshot["paymentProviderAdapterReadinessReviewedValid"]))"
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
        confirmationsValid = $false
        confirmationValidation = [ordered]@{}
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

    $raw = Read-Utf8Text $resolvedPath
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
    $confirmationResult = Get-RequiredBoolSetSnapshot $confirmations @(
        "noSecretValues",
        "workloadRestart",
        "smokePassed",
        "artifactLeakReview",
        "requireAllCoreSecrets"
    )
    $snapshot["confirmations"] = $confirmationResult.values
    $snapshot["confirmationsValid"] = [bool] $confirmationResult.allValidAndTrue
    $snapshot["confirmationValidation"] = $confirmationResult.validation
    $snapshot["rotatedCount"] = Get-PropertyInt $summary "rotatedCount"
    $snapshot["coreRotatedCount"] = Get-PropertyInt $summary "coreRotatedCount"
    $snapshot["coreRequiredCount"] = Get-PropertyInt $summary "coreRequiredCount"
    $snapshot["failureCount"] = Get-PropertyInt $summary "failureCount"
    $snapshot["plannedCount"] = Get-PropertyInt $summary "plannedCount"
    $snapshot["checkCount"] = $checks.Count
    $snapshot["rotations"] = @($rotationRows.ToArray())
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; core=$($snapshot["coreRotatedCount"])/$($snapshot["coreRequiredCount"]); failures=$($snapshot["failureCount"]); planned=$($snapshot["plannedCount"]); confirmationsValid=$($snapshot["confirmationsValid"])"
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
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        productVersion = ""
        approvedBy = ""
        approvedAt = ""
        passedCount = 0
        failureCount = 0
        checkCount = 0
        pricingPolicyProposalCommercialApproved = $false
        pricingPolicyProposalCommercialApprovedCount = 0
        pricingPolicyProposalApprovedPriceListCount = 0
        countsValid = $false
        countValidation = [ordered]@{}
        pricingPolicyProposalCommercialApprovedValid = $false
        pricingPolicyProposalCommercialApprovedRaw = "<missing>"
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
    $snapshot["environmentName"] = Get-PropertyText $payload "environmentName"
    $snapshot["targetCluster"] = Get-PropertyText $payload "targetCluster"
    $snapshot["operatorName"] = Get-TargetIdentityText $payload "operatorName"
    $snapshot["productVersion"] = Get-PropertyText $payload "productVersion"
    $snapshot["approvedBy"] = Get-PropertyText $payload "approvedBy"
    $snapshot["approvedAt"] = Get-PropertyText $payload "approvedAt"
    $countResult = Get-RequiredIntSetSnapshot $summary @(
        "passedCount",
        "failureCount",
        "checkCount",
        "pricingPolicyProposalCommercialApprovedCount",
        "pricingPolicyProposalApprovedPriceListCount"
    )
    $snapshot["passedCount"] = $countResult.values["passedCount"]
    $snapshot["failureCount"] = $countResult.values["failureCount"]
    $snapshot["checkCount"] = $countResult.values["checkCount"]
    $snapshot["pricingPolicyProposalCommercialApprovedCount"] = $countResult.values["pricingPolicyProposalCommercialApprovedCount"]
    $snapshot["pricingPolicyProposalApprovedPriceListCount"] = $countResult.values["pricingPolicyProposalApprovedPriceListCount"]
    $snapshot["countsValid"] = [bool] $countResult.allValid
    $snapshot["countValidation"] = $countResult.validation
    if ($snapshot["checkCount"] -eq 0) {
        $snapshot["checkCount"] = $checks.Count
    }
    $approvedResult = Get-RequiredPropertyBool $summary "pricingPolicyProposalCommercialApproved"
    $snapshot["pricingPolicyProposalCommercialApproved"] = [bool] $approvedResult.value
    $snapshot["pricingPolicyProposalCommercialApprovedValid"] = [bool] $approvedResult.valid
    $snapshot["pricingPolicyProposalCommercialApprovedRaw"] = [string] $approvedResult.raw
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; failures=$($snapshot["failureCount"]); checks=$($snapshot["checkCount"]); priceListApproved=$($snapshot["pricingPolicyProposalApprovedPriceListCount"]); countsValid=$($snapshot["countsValid"]); pricingPolicyProposalCommercialApproved=$($snapshot["pricingPolicyProposalCommercialApprovedRaw"])(valid=$($snapshot["pricingPolicyProposalCommercialApprovedValid"]))"
    return $snapshot
}

function Read-ChargebackCloseoutEvidenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.chargeback-closeout-evidence.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        billingPeriod = ""
        closeoutWindow = [ordered]@{
            startedAt = ""
            completedAt = ""
        }
        evidenceRefs = [ordered]@{}
        confirmations = [ordered]@{}
        confirmationsValid = $false
        confirmationValidation = [ordered]@{}
        chargebackCloseoutSnapshot = [ordered]@{
            provided = $false
            parsed = $false
            valid = $false
            billingPeriod = ""
            result = ""
            statusClosed = $false
            billingPeriodMatches = $false
            integersValid = $false
            booleansValid = $false
            failureCountZero = $false
            blockerCountZero = $false
            scanLimitPositive = $false
            sourceTruncated = $false
            sourceComplete = $false
            truncationBlockerCountZero = $false
            closeoutReady = $false
            readinessBooleansClosed = $false
            noRawDataStored = $false
            counts = [ordered]@{}
            rawDataFlags = [ordered]@{}
            detail = ""
        }
        paymentProviderAdapterReadiness = [ordered]@{
            provided = $false
            parsed = $false
            valid = $false
            mode = ""
            status = ""
            profileCount = 0
            webhookReadyProfileCount = 0
            nativeApiReadyProfileCount = 0
            nativeApiSupported = $false
            nativeApiReady = $false
            detail = ""
        }
        checkCount = 0
        passCount = 0
        failureCount = 0
        plannedCount = 0
        summaryValid = $false
        closeoutCountsValid = $false
        rawDataFlagsValid = $false
        noRawDataStored = $false
        reconciliationDifferenceMinorUnits = 0
        topChecks = @()
        decisionRule = ""
        scopePolicy = ""
        secretPolicy = ""
        detail = "No chargeback closeout evidence JSON supplied."
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $snapshot
    }

    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "Chargeback closeout evidence JSON not found."
        return $snapshot
    }

    $raw = Read-Utf8Text $resolvedPath
    Assert-SafeText $raw "ChargebackCloseoutJson"
    Assert-SanitizedOperationsSnapshotJson $raw "ChargebackCloseoutJson"
    Assert-SanitizedChargebackCloseoutJson $raw "ChargebackCloseoutJson"
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $snapshot["detail"] = "Chargeback closeout evidence JSON parse failed: $($_.Exception.Message)"
        return $snapshot
    }

    $target = Get-PropertyValue $payload "target"
    $summary = Get-PropertyValue $payload "summary"
    $evidenceRefs = Get-PropertyValue $payload "evidenceRefs"
    $confirmations = Get-PropertyValue $payload "confirmations"
    $closeoutSnapshot = Get-PropertyValue $payload "chargebackCloseoutSnapshot"
    $closeoutCounts = Get-PropertyValue $closeoutSnapshot "counts"
    $rawDataFlags = Get-PropertyValue $closeoutSnapshot "rawDataFlags"
    $paymentSnapshot = Get-PropertyValue $payload "paymentProviderAdapterReadiness"
    $checks = @(Get-PropertyArray $payload "checks")
    $topRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $topRows.Add((New-ChargebackCloseoutCheckSnapshotRow $check))
        }
        if ($topRows.Count -ge 5) {
            break
        }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $summaryCountResult = Get-RequiredIntSetSnapshot $summary @(
        "checkCount",
        "passCount",
        "failureCount",
        "plannedCount"
    )
    $closeoutCountResult = Get-RequiredIntSetSnapshot $closeoutCounts @(
        "invoiceDraftCount",
        "finalInvoiceCount",
        "paymentRequestedCount",
        "paymentHandoffCount",
        "paidInvoiceCount",
        "scanLimit",
        "truncationBlockerCount",
        "blockerCount",
        "reconciliationDifferenceMinorUnits",
        "failureCount"
    )
    $rawCustomerPaymentData = Get-RequiredPropertyBool $rawDataFlags "rawCustomerPaymentDataStored"
    $rawProviderResponse = Get-RequiredPropertyBool $rawDataFlags "rawProviderResponseStored"
    $rawSecretValues = Get-RequiredPropertyBool $rawDataFlags "rawSecretValuesStored"
    $rawFlagsValid = [bool] $rawCustomerPaymentData.valid -and [bool] $rawProviderResponse.valid -and [bool] $rawSecretValues.valid
    $noRawDataStored = $rawFlagsValid `
        -and (-not [bool] $rawCustomerPaymentData.value) `
        -and (-not [bool] $rawProviderResponse.value) `
        -and (-not [bool] $rawSecretValues.value)
    $confirmationResult = Get-RequiredBoolSetSnapshot $confirmations @(
        "pricingPolicyReviewed",
        "priceListApproved",
        "usageWindowReviewed",
        "chargebackPreviewReviewed",
        "trendExportReviewed",
        "invoiceDraftReviewed",
        "invoiceFinalized",
        "paymentRequestReviewed",
        "paymentProviderHandoffReviewed",
        "paymentProviderAdapterReadinessReviewed",
        "notificationDeliveryReviewed",
        "adapterRetryReviewed",
        "reconciliationReviewed",
        "commercialIntegrationReviewed",
        "commercialApprovalReviewed",
        "noRawCustomerPaymentData",
        "noRawProviderResponses",
        "noSecretValues"
    )

    $snapshot["parsed"] = $true
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["environmentName"] = Get-PropertyText $target "environmentName"
    $snapshot["targetCluster"] = Get-PropertyText $target "targetCluster"
    $snapshot["operatorName"] = Get-PropertyText $target "operator"
    $snapshot["billingPeriod"] = Get-PropertyText $target "billingPeriod"
    $snapshot["closeoutWindow"] = [ordered]@{
        startedAt = Get-PropertyText $target "closeoutStartedAt"
        completedAt = Get-PropertyText $target "closeoutCompletedAt"
    }
    $snapshot["evidenceRefs"] = [ordered]@{
        pricingPolicy = Get-PropertyText $evidenceRefs "pricingPolicy"
        pricingProposalApproval = Get-PropertyText $evidenceRefs "pricingProposalApproval"
        chargebackPreview = Get-PropertyText $evidenceRefs "chargebackPreview"
        chargebackTrendExport = Get-PropertyText $evidenceRefs "chargebackTrendExport"
        invoiceDraft = Get-PropertyText $evidenceRefs "invoiceDraft"
        invoiceFinalization = Get-PropertyText $evidenceRefs "invoiceFinalization"
        paymentRequest = Get-PropertyText $evidenceRefs "paymentRequest"
        paymentProviderHandoff = Get-PropertyText $evidenceRefs "paymentProviderHandoff"
        paymentProviderAdapterReadiness = Get-PropertyText $evidenceRefs "paymentProviderAdapterReadiness"
        notificationDelivery = Get-PropertyText $evidenceRefs "notificationDelivery"
        adapterRetryWorker = Get-PropertyText $evidenceRefs "adapterRetryWorker"
        reconciliation = Get-PropertyText $evidenceRefs "reconciliation"
        commercialIntegration = Get-PropertyText $evidenceRefs "commercialIntegration"
        commercialApproval = Get-PropertyText $evidenceRefs "commercialApproval"
    }
    $snapshot["confirmations"] = $confirmationResult.values
    $snapshot["confirmationsValid"] = [bool] $confirmationResult.allValidAndTrue
    $snapshot["confirmationValidation"] = $confirmationResult.validation
    $snapshot["chargebackCloseoutSnapshot"] = [ordered]@{
        provided = Get-PropertyBool $closeoutSnapshot "provided"
        parsed = Get-PropertyBool $closeoutSnapshot "parsed"
        valid = Get-PropertyBool $closeoutSnapshot "valid"
        billingPeriod = Get-PropertyText $closeoutSnapshot "billingPeriod"
        result = Get-PropertyText $closeoutSnapshot "result"
        statusClosed = Get-PropertyBool $closeoutSnapshot "statusClosed"
        billingPeriodMatches = Get-PropertyBool $closeoutSnapshot "billingPeriodMatches"
        integersValid = Get-PropertyBool $closeoutSnapshot "integersValid"
        booleansValid = Get-PropertyBool $closeoutSnapshot "booleansValid"
        failureCountZero = Get-PropertyBool $closeoutSnapshot "failureCountZero"
        blockerCountZero = Get-PropertyBool $closeoutSnapshot "blockerCountZero"
        scanLimitPositive = Get-PropertyBool $closeoutSnapshot "scanLimitPositive"
        sourceTruncated = Get-PropertyBool $closeoutSnapshot "sourceTruncated"
        sourceComplete = Get-PropertyBool $closeoutSnapshot "sourceComplete"
        truncationBlockerCountZero = Get-PropertyBool $closeoutSnapshot "truncationBlockerCountZero"
        closeoutReady = Get-PropertyBool $closeoutSnapshot "closeoutReady"
        readinessBooleansClosed = Get-PropertyBool $closeoutSnapshot "readinessBooleansClosed"
        noRawDataStored = Get-PropertyBool $closeoutSnapshot "noRawDataStored"
        counts = $closeoutCountResult.values
        rawDataFlags = [ordered]@{
            rawCustomerPaymentDataStored = [bool] $rawCustomerPaymentData.value
            rawProviderResponseStored = [bool] $rawProviderResponse.value
            rawSecretValuesStored = [bool] $rawSecretValues.value
        }
        detail = Get-PropertyText $closeoutSnapshot "detail"
    }
    $snapshot["paymentProviderAdapterReadiness"] = [ordered]@{
        provided = Get-PropertyBool $paymentSnapshot "provided"
        parsed = Get-PropertyBool $paymentSnapshot "parsed"
        valid = Get-PropertyBool $paymentSnapshot "valid"
        mode = Get-PropertyText $paymentSnapshot "mode"
        status = Get-PropertyText $paymentSnapshot "status"
        profileCount = Get-PropertyInt $paymentSnapshot "profileCount"
        webhookReadyProfileCount = Get-PropertyInt $paymentSnapshot "webhookReadyProfileCount"
        nativeApiReadyProfileCount = Get-PropertyInt $paymentSnapshot "nativeApiReadyProfileCount"
        nativeApiSupported = Get-PropertyBool $paymentSnapshot "nativeApiSupported"
        nativeApiReady = Get-PropertyBool $paymentSnapshot "nativeApiReady"
        detail = Get-PropertyText $paymentSnapshot "detail"
    }
    $snapshot["checkCount"] = $summaryCountResult.values["checkCount"]
    if ($snapshot["checkCount"] -eq 0) {
        $snapshot["checkCount"] = $checks.Count
    }
    $snapshot["passCount"] = $summaryCountResult.values["passCount"]
    $snapshot["failureCount"] = $summaryCountResult.values["failureCount"]
    $snapshot["plannedCount"] = $summaryCountResult.values["plannedCount"]
    $snapshot["summaryValid"] = [bool] $summaryCountResult.allValid
    $snapshot["closeoutCountsValid"] = [bool] $closeoutCountResult.allValid
    $snapshot["rawDataFlagsValid"] = $rawFlagsValid
    $snapshot["noRawDataStored"] = $noRawDataStored
    $snapshot["reconciliationDifferenceMinorUnits"] = $closeoutCountResult.values["reconciliationDifferenceMinorUnits"]
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["decisionRule"] = Get-PropertyText $payload "decisionRule"
    $snapshot["scopePolicy"] = Get-PropertyText $payload "scopePolicy"
    $snapshot["secretPolicy"] = Get-PropertyText $payload "secretPolicy"
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; billingPeriod=$($snapshot["billingPeriod"]); failures=$($snapshot["failureCount"]); planned=$($snapshot["plannedCount"]); scanLimit=$($snapshot["chargebackCloseoutSnapshot"]["counts"]["scanLimit"]); sourceTruncated=$($snapshot["chargebackCloseoutSnapshot"]["sourceTruncated"]); truncationBlockers=$($snapshot["chargebackCloseoutSnapshot"]["counts"]["truncationBlockerCount"]); reconciliationDifferenceMinorUnits=$($snapshot["reconciliationDifferenceMinorUnits"]); snapshotValid=$($snapshot["chargebackCloseoutSnapshot"]["valid"]); confirmationsValid=$($snapshot["confirmationsValid"]); noRawDataStored=$noRawDataStored"
    return $snapshot
}

function Read-EnterpriseAuthSmokeEvidenceSnapshot([string] $Path) {    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.enterprise-auth-smoke.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        scopeOutAccepted = $false
        scopeOutAcceptedValid = $false
        scopeOutAcceptedRaw = "<missing>"
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
        countsValid = $false
        countValidation = [ordered]@{}
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
    $scopeOutAccepted = Get-RequiredPropertyBool $scopeOut "accepted"
    $scopeOutReference = Get-PropertyText $scopeOut "reference"
    $scopeOutReason = Get-PropertyText $scopeOut "reason"
    $scopeOutApproved = [bool] $scopeOutAccepted.valid `
        -and [bool] $scopeOutAccepted.value `
        -and -not [string]::IsNullOrWhiteSpace($scopeOutReference) `
        -and -not [string]::IsNullOrWhiteSpace($scopeOutReason)
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $target = Get-PropertyValue $payload "target"
    $snapshot["environmentName"] = Get-TargetIdentityText $payload "environmentName"
    if ([string]::IsNullOrWhiteSpace($snapshot["environmentName"])) { $snapshot["environmentName"] = Get-TargetIdentityText $target "environmentName" }
    $snapshot["targetCluster"] = Get-TargetIdentityText $payload "targetCluster"
    if ([string]::IsNullOrWhiteSpace($snapshot["targetCluster"])) { $snapshot["targetCluster"] = Get-TargetIdentityText $target "targetCluster" }
    $snapshot["operatorName"] = Get-TargetIdentityText $payload "operatorName"
    if ([string]::IsNullOrWhiteSpace($snapshot["operatorName"])) { $snapshot["operatorName"] = Get-TargetIdentityText $target "operatorName" }
    $snapshot["scopeOutAccepted"] = [bool] $scopeOutAccepted.value
    $snapshot["scopeOutAcceptedValid"] = [bool] $scopeOutAccepted.valid
    $snapshot["scopeOutAcceptedRaw"] = [string] $scopeOutAccepted.raw
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
        reference = $scopeOutReference
        reason = $scopeOutReason
        accepted = [bool] $scopeOutAccepted.value
        acceptedValid = [bool] $scopeOutAccepted.valid
        acceptedRaw = [string] $scopeOutAccepted.raw
    }
    $countResult = Get-RequiredIntSetSnapshot $summary @(
        "passCount",
        "failCount",
        "blockedCount",
        "plannedCount",
        "skippedCount"
    )
    $snapshot["passCount"] = $countResult.values["passCount"]
    $snapshot["failCount"] = $countResult.values["failCount"]
    $snapshot["blockedCount"] = $countResult.values["blockedCount"]
    $snapshot["plannedCount"] = $countResult.values["plannedCount"]
    $snapshot["skippedCount"] = $countResult.values["skippedCount"]
    $snapshot["countsValid"] = [bool] $countResult.allValid
    $snapshot["countValidation"] = $countResult.validation
    $snapshot["accepted"] = ([bool] $snapshot["passed"] `
            -and [bool] $snapshot["countsValid"] `
            -and ([int64] $snapshot["passCount"]) -gt 0 `
            -and ([int64] $snapshot["failCount"]) -eq 0 `
            -and ([int64] $snapshot["blockedCount"]) -eq 0 `
            -and ([int64] $snapshot["plannedCount"]) -eq 0) `
        -or ("scope-out".Equals($result, [System.StringComparison]::OrdinalIgnoreCase) -and $scopeOutApproved)
    $snapshot["checkCount"] = $checks.Count
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; pass=$($snapshot["passCount"]); fail=$($snapshot["failCount"]); blocked=$($snapshot["blockedCount"]); planned=$($snapshot["plannedCount"]); countsValid=$($snapshot["countsValid"]); scopeOutAccepted=$($snapshot["scopeOutAcceptedRaw"])(valid=$($snapshot["scopeOutAcceptedValid"])); scopeOutReference=$scopeOutReference"
    return $snapshot
}

function Read-EnterpriseAuthJitRollbackEvidenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.enterprise-auth-jit-rollback-evidence.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        evidenceRef = ""
        reviewWindow = [ordered]@{
            startedAt = ""
            completedAt = ""
        }
        enterpriseAuthSmokeSnapshot = [ordered]@{
            provided = $false
            parsed = $false
            formatVersion = ""
            result = ""
            executionMode = ""
            passCount = 0
            failCount = 0
            blockedCount = 0
            plannedCount = 0
            skippedCount = 0
            scopeOutAccepted = $false
            detail = ""
        }
        evidenceRefs = [ordered]@{}
        confirmations = [ordered]@{
            adminApprovalRequired = $false
            callbackAutoJitDisabled = $false
            jitUserDisableOrLockRollbackReviewed = $false
            roleOrgTeamRollbackReviewed = $false
            localPasswordFallbackValidated = $false
            auditEventsReviewed = $false
            noRawClaims = $false
            noSecretValues = $false
        }
        confirmationsValid = $false
        confirmationValidation = [ordered]@{}
        failureCount = 0
        checkCount = 0
        topChecks = @()
        decisionRule = ""
        scopePolicy = ""
        secretPolicy = ""
        detail = "No enterprise auth JIT rollback evidence JSON supplied."
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $snapshot
    }

    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "Enterprise auth JIT rollback evidence JSON not found."
        return $snapshot
    }

    $raw = Read-Utf8Text $resolvedPath
    Assert-SafeText $raw "EnterpriseAuthJitRollbackJson"
    Assert-SanitizedOperationsSnapshotJson $raw "EnterpriseAuthJitRollbackJson"
    Assert-SanitizedEnterpriseAuthJitRollbackJson $raw "EnterpriseAuthJitRollbackJson"
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $snapshot["detail"] = "Enterprise auth JIT rollback evidence JSON parse failed: $($_.Exception.Message)"
        return $snapshot
    }

    $summary = Get-SummaryOrSelf $payload
    $reviewWindow = Get-PropertyValue $payload "reviewWindow"
    $smokeSnapshot = Get-PropertyValue $payload "enterpriseAuthSmokeSnapshot"
    $evidenceRefs = Get-PropertyValue $payload "evidenceRefs"
    $confirmations = Get-PropertyValue $payload "confirmations"
    $checks = @(Get-PropertyArray $payload "checks")
    $topRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $topRows.Add((New-EnterpriseAuthJitRollbackCheckSnapshotRow $check))
        }
        if ($topRows.Count -ge 5) {
            break
        }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $countResult = Get-RequiredIntSetSnapshot $summary @(
        "failureCount",
        "checkCount"
    )
    $confirmationResult = Get-RequiredBoolSetSnapshot $confirmations @(
        "adminApprovalRequired",
        "callbackAutoJitDisabled",
        "jitUserDisableOrLockRollbackReviewed",
        "roleOrgTeamRollbackReviewed",
        "localPasswordFallbackValidated",
        "auditEventsReviewed",
        "noRawClaims",
        "noSecretValues"
    )

    $snapshot["parsed"] = $true
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["environmentName"] = Get-PropertyText $payload "environmentName"
    $snapshot["targetCluster"] = Get-PropertyText $payload "targetCluster"
    $snapshot["operatorName"] = Get-PropertyText $payload "operatorName"
    $snapshot["evidenceRef"] = Get-PropertyText $payload "evidenceRef"
    $snapshot["reviewWindow"] = [ordered]@{
        startedAt = Get-PropertyText $reviewWindow "startedAt"
        completedAt = Get-PropertyText $reviewWindow "completedAt"
    }
    $snapshot["enterpriseAuthSmokeSnapshot"] = [ordered]@{
        provided = Get-PropertyBool $smokeSnapshot "provided"
        parsed = Get-PropertyBool $smokeSnapshot "parsed"
        formatVersion = Get-PropertyText $smokeSnapshot "formatVersion"
        result = Get-PropertyText $smokeSnapshot "result"
        executionMode = Get-PropertyText $smokeSnapshot "executionMode"
        passCount = Get-PropertyInt $smokeSnapshot "passCount"
        failCount = Get-PropertyInt $smokeSnapshot "failCount"
        blockedCount = Get-PropertyInt $smokeSnapshot "blockedCount"
        plannedCount = Get-PropertyInt $smokeSnapshot "plannedCount"
        skippedCount = Get-PropertyInt $smokeSnapshot "skippedCount"
        scopeOutAccepted = Get-PropertyBool $smokeSnapshot "scopeOutAccepted"
        detail = Get-PropertyText $smokeSnapshot "detail"
    }
    $snapshot["evidenceRefs"] = [ordered]@{
        changeApproval = Get-PropertyText $evidenceRefs "changeApproval"
        jitProvision = Get-PropertyText $evidenceRefs "jitProvision"
        jitRollbackRunbook = Get-PropertyText $evidenceRefs "jitRollbackRunbook"
        userDisableRollback = Get-PropertyText $evidenceRefs "userDisableRollback"
        roleMappingRollback = Get-PropertyText $evidenceRefs "roleMappingRollback"
        localLoginFallback = Get-PropertyText $evidenceRefs "localLoginFallback"
        auditReview = Get-PropertyText $evidenceRefs "auditReview"
    }
    $snapshot["confirmations"] = $confirmationResult.values
    $snapshot["confirmationsValid"] = [bool] $confirmationResult.allValidAndTrue
    $snapshot["confirmationValidation"] = $confirmationResult.validation
    $snapshot["failureCount"] = $countResult.values["failureCount"]
    $snapshot["checkCount"] = $countResult.values["checkCount"]
    if ($snapshot["checkCount"] -eq 0) {
        $snapshot["checkCount"] = $checks.Count
    }
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["decisionRule"] = Get-PropertyText $payload "decisionRule"
    $snapshot["scopePolicy"] = Get-PropertyText $payload "scopePolicy"
    $snapshot["secretPolicy"] = Get-PropertyText $payload "secretPolicy"
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; failures=$($snapshot["failureCount"]); checks=$($snapshot["checkCount"]); confirmationsValid=$($snapshot["confirmationsValid"]); smokeResult=$($snapshot["enterpriseAuthSmokeSnapshot"]["result"])"
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
        alertTargetCoverageComplete = $false
        routeCoverageComplete = $false
        grafanaPanelCoverageComplete = $false
        tuningEvidenceCoverageComplete = $false
        thresholdMappingComplete = $false
        confirmations = [ordered]@{
            prometheusRulesLoaded = $false
            grafanaDashboardImported = $false
            alertmanagerRoutesReviewed = $false
            targetBaselinesReviewed = $false
            incidentRoutingReviewed = $false
            noSecretValues = $false
        }
        confirmationsValid = $false
        confirmationValidation = [ordered]@{}
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

    $raw = Read-Utf8Text $resolvedPath
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
    $alertTargetCoverageComplete = Get-PropertyBool $thresholdSummary "alertTargetCoverageComplete"
    $routeCoverageComplete = Get-PropertyBool $thresholdSummary "routeCoverageComplete"
    $grafanaPanelCoverageComplete = Get-PropertyBool $thresholdSummary "grafanaPanelCoverageComplete"
    $tuningEvidenceCoverageComplete = Get-PropertyBool $thresholdSummary "tuningEvidenceCoverageComplete"
    $thresholdMappingComplete = Get-PropertyBool $thresholdSummary "thresholdMappingComplete"
    $failureCount = Get-PropertyInt $summary "failureCount"
    $confirmationResult = Get-RequiredBoolSetSnapshot $confirmations @(
        "prometheusRulesLoaded",
        "grafanaDashboardImported",
        "alertmanagerRoutesReviewed",
        "targetBaselinesReviewed",
        "incidentRoutingReviewed",
        "noSecretValues"
    )
    $allConfirmationsPassed = [bool] $confirmationResult.allValidAndTrue
    $complete = $requiredAlertCount -gt 0 `
        -and $mappedAlertCount -ge $requiredAlertCount `
        -and $grafanaPanelCount -ge $requiredAlertCount `
        -and $tuningEvidenceCount -ge $requiredAlertCount `
        -and $missingAlerts.Count -eq 0 `
        -and $alertTargetCoverageComplete `
        -and $routeCoverageComplete `
        -and $grafanaPanelCoverageComplete `
        -and $tuningEvidenceCoverageComplete `
        -and $thresholdMappingComplete `
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
    $snapshot["alertTargetCoverageComplete"] = $alertTargetCoverageComplete
    $snapshot["routeCoverageComplete"] = $routeCoverageComplete
    $snapshot["grafanaPanelCoverageComplete"] = $grafanaPanelCoverageComplete
    $snapshot["tuningEvidenceCoverageComplete"] = $tuningEvidenceCoverageComplete
    $snapshot["thresholdMappingComplete"] = $thresholdMappingComplete
    $snapshot["confirmations"] = $confirmationResult.values
    $snapshot["confirmationsValid"] = [bool] $confirmationResult.allValidAndTrue
    $snapshot["confirmationValidation"] = $confirmationResult.validation
    $snapshot["complete"] = $complete
    $snapshot["failureCount"] = $failureCount
    $snapshot["checkCount"] = Get-PropertyInt $summary "checkCount"
    if ($snapshot["checkCount"] -eq 0) {
        $snapshot["checkCount"] = $checks.Count
    }
    $snapshot["topFailedChecks"] = @($failedRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; alerts=$mappedAlertCount/$requiredAlertCount; routes=$($snapshot["routeCount"]); failures=$failureCount; mappingComplete=$thresholdMappingComplete; complete=$complete; confirmationsValid=$($snapshot["confirmationsValid"])"
    return $snapshot
}

function Read-ClusterNetworkAccessReviewEvidenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.cluster-network-access-review-evidence.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        evidenceRef = ""
        passCount = 0
        failureCount = 0
        totalCount = 0
        countsValid = $false
        countValidation = [ordered]@{}
        staticControls = [ordered]@{}
        staticControlsValid = $false
        staticControlValidation = [ordered]@{}
        confirmations = [ordered]@{}
        confirmationsValid = $false
        confirmationValidation = [ordered]@{}
        topChecks = @()
        detail = "No cluster network access review evidence JSON supplied."
    }

    $payloadResult = Read-JsonPayload $Path "ClusterNetworkAccessReview" $snapshot["detail"]
    $snapshot["provided"] = [bool] $payloadResult["provided"]
    $snapshot["path"] = [string] $payloadResult["path"]
    $snapshot["parsed"] = [bool] $payloadResult["parsed"]
    if (-not $snapshot["parsed"]) {
        $snapshot["detail"] = [string] $payloadResult["detail"]
        return $snapshot
    }

    $payload = $payloadResult["payload"]
    $summary = Get-SummaryOrSelf $payload
    $staticControls = Get-PropertyValue $payload "staticControlSnapshot"
    $confirmations = Get-PropertyValue $payload "confirmations"
    $checks = @(Get-PropertyArray $payload "checks")
    $topRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $topRows.Add((New-CommercialEvidenceCheckSnapshotRow $check))
        }
        if ($topRows.Count -ge 5) { break }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["environmentName"] = Get-PropertyText $payload "environmentName"
    $snapshot["targetCluster"] = Get-PropertyText $payload "targetCluster"
    $snapshot["operatorName"] = Get-TargetIdentityText $payload "operatorName"
    $snapshot["evidenceRef"] = Get-PropertyText (Get-PropertyValue $payload "evidence") "evidenceRef"

    $countResult = Get-RequiredIntSetSnapshot $summary @("passCount", "failureCount", "totalCount")
    $snapshot["passCount"] = $countResult.values["passCount"]
    $snapshot["failureCount"] = $countResult.values["failureCount"]
    $snapshot["totalCount"] = $countResult.values["totalCount"]
    $snapshot["countsValid"] = [bool] $countResult.allValid
    $snapshot["countValidation"] = $countResult.validation

    $staticResult = Get-RequiredBoolSetSnapshot $staticControls @(
        "requiredPolicyNamesPresent",
        "backendEgressScoped",
        "backupEgressScoped",
        "dnsEgressScoped",
        "mariaDbIngressScoped",
        "minioIngressScoped",
        "noBroadCidr",
        "helmNetworkPolicyEnabled"
    )
    $snapshot["staticControls"] = $staticResult.values
    $snapshot["staticControlsValid"] = [bool] $staticResult.allValidAndTrue
    $snapshot["staticControlValidation"] = $staticResult.validation

    $confirmationResult = Get-RequiredBoolSetSnapshot $confirmations @(
        "backendOnlyMariaDb",
        "backendOnlyMinio",
        "backupOnlyMariaDbMinio",
        "dnsEgressScoped",
        "mariaDbIngressBackendBackupOnly",
        "minioIngressBackendBackupOnly",
        "publicIngressLimited",
        "namespaceDefaultDenyReviewed",
        "observabilityScrapeReviewed",
        "helmNetworkPolicyEnabled",
        "noCredentialValues"
    )
    $snapshot["confirmations"] = $confirmationResult.values
    $snapshot["confirmationsValid"] = [bool] $confirmationResult.allValidAndTrue
    $snapshot["confirmationValidation"] = $confirmationResult.validation
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; failures=$($snapshot["failureCount"]); checks=$($snapshot["totalCount"]); staticControlsValid=$($snapshot["staticControlsValid"]); confirmationsValid=$($snapshot["confirmationsValid"])"
    return $snapshot
}

function Read-HelmValuesHardeningEvidenceSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        expectedFormatVersion = "osmu.helm-values-hardening-evidence.v1"
        validFormatVersion = $false
        result = ""
        passed = $false
        environmentName = ""
        targetCluster = ""
        operatorName = ""
        evidenceRef = ""
        passCount = 0
        failureCount = 0
        totalCount = 0
        countsValid = $false
        countValidation = [ordered]@{}
        chartFileCount = 0
        staticHardening = [ordered]@{}
        staticHardeningValid = $false
        staticHardeningValidation = [ordered]@{}
        confirmations = [ordered]@{}
        confirmationsValid = $false
        confirmationValidation = [ordered]@{}
        topChecks = @()
        detail = "No Helm values hardening evidence JSON supplied."
    }

    $payloadResult = Read-JsonPayload $Path "HelmValuesHardening" $snapshot["detail"]
    $snapshot["provided"] = [bool] $payloadResult["provided"]
    $snapshot["path"] = [string] $payloadResult["path"]
    $snapshot["parsed"] = [bool] $payloadResult["parsed"]
    if (-not $snapshot["parsed"]) {
        $snapshot["detail"] = [string] $payloadResult["detail"]
        return $snapshot
    }

    $payload = $payloadResult["payload"]
    $summary = Get-SummaryOrSelf $payload
    $staticHardening = Get-PropertyValue $payload "staticHardeningSnapshot"
    $confirmations = Get-PropertyValue $payload "confirmations"
    $chartSnapshot = Get-PropertyValue $payload "chartSnapshot"
    $checks = @(Get-PropertyArray $payload "checks")
    $topRows = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) {
        if (-not (Get-PropertyBool $check "passed")) {
            [void] $topRows.Add((New-CommercialEvidenceCheckSnapshotRow $check))
        }
        if ($topRows.Count -ge 5) { break }
    }

    $formatVersion = Get-PropertyText $payload "formatVersion"
    $result = Get-PropertyText $payload "result"
    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["passed"] = "passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["environmentName"] = Get-PropertyText $payload "environmentName"
    $snapshot["targetCluster"] = Get-PropertyText $payload "targetCluster"
    $snapshot["operatorName"] = Get-TargetIdentityText $payload "operatorName"
    $snapshot["evidenceRef"] = Get-PropertyText (Get-PropertyValue $payload "evidence") "evidenceRef"
    $snapshot["chartFileCount"] = @(Get-PropertyArray $chartSnapshot "files").Count

    $countResult = Get-RequiredIntSetSnapshot $summary @("passCount", "failureCount", "totalCount")
    $snapshot["passCount"] = $countResult.values["passCount"]
    $snapshot["failureCount"] = $countResult.values["failureCount"]
    $snapshot["totalCount"] = $countResult.values["totalCount"]
    $snapshot["countsValid"] = [bool] $countResult.allValid
    $snapshot["countValidation"] = $countResult.validation

    $staticResult = Get-RequiredBoolSetSnapshot $staticHardening @(
        "secretsExternalized",
        "defaultSecretPlaceholdersPresent",
        "haReplicas",
        "resourceBounds",
        "securityContexts",
        "serviceAccountTokensDisabled",
        "networkPolicyEnabled",
        "tlsIngress",
        "operationsReportsReadOnly",
        "storageExpansionRbacDisabled"
    )
    $snapshot["staticHardening"] = $staticResult.values
    $snapshot["staticHardeningValid"] = [bool] $staticResult.allValidAndTrue
    $snapshot["staticHardeningValidation"] = $staticResult.validation

    $confirmationResult = Get-RequiredBoolSetSnapshot $confirmations @(
        "secretsExternalized",
        "defaultSecretPlaceholdersNotUsed",
        "haReplicasReviewed",
        "resourcesBounded",
        "securityContextsReviewed",
        "networkPolicyEnabled",
        "tlsIngressReviewed",
        "operationsReportsReadOnly",
        "storageExpansionRbacDisabledByDefault",
        "noCredentialValues"
    )
    $snapshot["confirmations"] = $confirmationResult.values
    $snapshot["confirmationsValid"] = [bool] $confirmationResult.allValidAndTrue
    $snapshot["confirmationValidation"] = $confirmationResult.validation
    $snapshot["topChecks"] = @($topRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; failures=$($snapshot["failureCount"]); checks=$($snapshot["totalCount"]); staticHardeningValid=$($snapshot["staticHardeningValid"]); confirmationsValid=$($snapshot["confirmationsValid"]); chartFiles=$($snapshot["chartFileCount"])"
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
        finalizerFailedCountValid = $false
        finalizerFailedCountRaw = "<missing>"
        kubernetesReportSyncReady = $false
        kubernetesReportSyncReadyValid = $false
        kubernetesReportSyncReadyRaw = "<missing>"
        kubernetesReportSyncResult = ""
        kubernetesReportSyncFailedCount = 0
        kubernetesReportSyncFailedCountValid = $false
        kubernetesReportSyncFailedCountRaw = "<missing>"
        kubernetesReportSyncSourceReportResult = ""
        stageCount = 0
        readyStageCount = 0
        finalizerGapCount = 0
        finalizerGapCountValid = $false
        finalizerGapCountRaw = "<missing>"
        currentBottleneckCode = ""
        currentBottleneckTitle = ""
        recommendedCommandCount = 0
        handoffPostDispatchCommandCount = 0
        handoffPostDispatchCommands = @()
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
    $handoffPostDispatchCommands = @(Get-PropertyArray $payload "handoffPostDispatchCommands")
    $handoffPostDispatchCommandRows = New-Object System.Collections.Generic.List[object]
    foreach ($command in $handoffPostDispatchCommands) {
        [void] $handoffPostDispatchCommandRows.Add((New-HandoffPostDispatchCommandSnapshotRow $command))
    }

    $snapshot["formatVersion"] = $formatVersion
    $snapshot["validFormatVersion"] = $formatVersion -eq $snapshot["expectedFormatVersion"]
    $snapshot["result"] = $result
    $snapshot["ready"] = "ready".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)
    $snapshot["readinessResult"] = Get-PropertyText $payload "readinessResult"
    $snapshot["readinessSummary"] = Get-PropertyText $payload "readinessSummary"
    $snapshot["finalizerResult"] = Get-PropertyText $payload "finalizerResult"
    $snapshot["finalizerReadinessResult"] = Get-PropertyText $payload "finalizerReadinessResult"
    $finalizerFailedCount = Get-RequiredPropertyInt $payload "finalizerFailedCount"
    $finalizerGapCount = Get-RequiredPropertyInt $payload "finalizerGapCount"
    $kubernetesReportSyncReady = Get-RequiredPropertyBool $payload "kubernetesReportSyncReady"
    $kubernetesReportSyncFailedCount = Get-RequiredPropertyInt $payload "kubernetesReportSyncFailedCount"
    $snapshot["finalizerFailedCount"] = $finalizerFailedCount.value
    $snapshot["finalizerFailedCountValid"] = $finalizerFailedCount.valid
    $snapshot["finalizerFailedCountRaw"] = $finalizerFailedCount.raw
    $snapshot["finalizerGapCount"] = $finalizerGapCount.value
    $snapshot["finalizerGapCountValid"] = $finalizerGapCount.valid
    $snapshot["finalizerGapCountRaw"] = $finalizerGapCount.raw
    $snapshot["kubernetesReportSyncReady"] = $kubernetesReportSyncReady.value
    $snapshot["kubernetesReportSyncReadyValid"] = $kubernetesReportSyncReady.valid
    $snapshot["kubernetesReportSyncReadyRaw"] = $kubernetesReportSyncReady.raw
    $snapshot["kubernetesReportSyncResult"] = Get-PropertyText $payload "kubernetesReportSyncResult"
    $snapshot["kubernetesReportSyncFailedCount"] = $kubernetesReportSyncFailedCount.value
    $snapshot["kubernetesReportSyncFailedCountValid"] = $kubernetesReportSyncFailedCount.valid
    $snapshot["kubernetesReportSyncFailedCountRaw"] = $kubernetesReportSyncFailedCount.raw
    $snapshot["kubernetesReportSyncSourceReportResult"] = Get-PropertyText $payload "kubernetesReportSyncSourceReportResult"
    $snapshot["stageCount"] = Get-PropertyInt $payload "stageCount"
    $snapshot["readyStageCount"] = Get-PropertyInt $payload "readyStageCount"
    $snapshot["currentBottleneckCode"] = Get-PropertyText $currentBottleneck "code"
    $snapshot["currentBottleneckTitle"] = Get-PropertyText $currentBottleneck "title"
    $snapshot["recommendedCommandCount"] = $recommendedCommands.Count
    $snapshot["handoffPostDispatchCommandCount"] = $handoffPostDispatchCommands.Count
    $snapshot["handoffPostDispatchCommands"] = @($handoffPostDispatchCommandRows.ToArray())
    $snapshot["detail"] = "formatVersion=$formatVersion; result=$result; readinessResult=$($snapshot["readinessResult"]); finalizerFailed=$($snapshot["finalizerFailedCountRaw"])(valid=$($snapshot["finalizerFailedCountValid"])); finalizerGaps=$($snapshot["finalizerGapCountRaw"])(valid=$($snapshot["finalizerGapCountValid"])); kubernetesReportSyncReady=$($snapshot["kubernetesReportSyncReadyRaw"])(valid=$($snapshot["kubernetesReportSyncReadyValid"])); failedSyncChecks=$($snapshot["kubernetesReportSyncFailedCountRaw"])(valid=$($snapshot["kubernetesReportSyncFailedCountValid"])); sourceReportResult=$($snapshot["kubernetesReportSyncSourceReportResult"]); handoffPostDispatchCommands=$($snapshot["handoffPostDispatchCommandCount"])"
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
    @("DataFlowQueryRetentionBudgetEvidenceRef", $DataFlowQueryRetentionBudgetEvidenceRef),
    @("DataFlowStorageTransitionRunbookEvidenceRef", $DataFlowStorageTransitionRunbookEvidenceRef),
    @("SecretRotationEvidenceRef", $SecretRotationEvidenceRef),
    @("CommercialIntegrationEvidenceRef", $CommercialIntegrationEvidenceRef),
    @("CommercialApprovalEvidenceRef", $CommercialApprovalEvidenceRef),
    @("ChargebackCloseoutEvidenceRef", $ChargebackCloseoutEvidenceRef),
    @("EnterpriseAuthEvidenceRef", $EnterpriseAuthEvidenceRef),
    @("EnterpriseAuthJitRollbackEvidenceRef", $EnterpriseAuthJitRollbackEvidenceRef),
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
$dataFlowQueryRetentionBudgetSnapshot = Read-DataFlowQueryRetentionBudgetSnapshot $DataFlowQueryRetentionBudgetJsonPath
$dataFlowStorageTransitionRunbookSnapshot = Read-DataFlowStorageTransitionRunbookSnapshot $DataFlowStorageTransitionRunbookJsonPath
$secretRotationSnapshot = Read-SecretRotationEvidenceSnapshot $SecretRotationJsonPath
$commercialIntegrationSnapshot = Read-CommercialIntegrationEvidenceSnapshot $CommercialIntegrationJsonPath
$commercialApprovalSnapshot = Read-CommercialApprovalEvidenceSnapshot $CommercialApprovalJsonPath
$chargebackCloseoutSnapshot = Read-ChargebackCloseoutEvidenceSnapshot $ChargebackCloseoutJsonPath
$enterpriseAuthSmokeSnapshot = Read-EnterpriseAuthSmokeEvidenceSnapshot $EnterpriseAuthJsonPath
$enterpriseAuthJitRollbackSnapshot = Read-EnterpriseAuthJitRollbackEvidenceSnapshot $EnterpriseAuthJitRollbackJsonPath
$monitoringThresholdSnapshot = Read-MonitoringThresholdEvidenceSnapshot $MonitoringThresholdJsonPath
$clusterNetworkAccessReviewSnapshot = Read-ClusterNetworkAccessReviewEvidenceSnapshot $ClusterNetworkAccessReviewJsonPath
$helmValuesHardeningSnapshot = Read-HelmValuesHardeningEvidenceSnapshot $HelmValuesHardeningJsonPath
$operationsReadinessSnapshotValid = [bool] $operationsReadinessSnapshot["provided"] -and [bool] $operationsReadinessSnapshot["parsed"] -and [bool] $operationsReadinessSnapshot["validFormatVersion"]
$operationsConvergenceSnapshotValid = [bool] $operationsConvergenceSnapshot["provided"] -and [bool] $operationsConvergenceSnapshot["parsed"] -and [bool] $operationsConvergenceSnapshot["validFormatVersion"]
$dataFlowStoragePlanSnapshotValid = [bool] $dataFlowStoragePlanSnapshot["provided"] -and [bool] $dataFlowStoragePlanSnapshot["parsed"] -and [bool] $dataFlowStoragePlanSnapshot["validFormatVersion"]
$dataFlowQueryRetentionBudgetSnapshotValid = [bool] $dataFlowQueryRetentionBudgetSnapshot["provided"] -and [bool] $dataFlowQueryRetentionBudgetSnapshot["parsed"] -and [bool] $dataFlowQueryRetentionBudgetSnapshot["validFormatVersion"]
$dataFlowStorageTransitionRunbookSnapshotValid = [bool] $dataFlowStorageTransitionRunbookSnapshot["provided"] -and [bool] $dataFlowStorageTransitionRunbookSnapshot["parsed"] -and [bool] $dataFlowStorageTransitionRunbookSnapshot["validFormatVersion"]
$secretRotationSnapshotValid = [bool] $secretRotationSnapshot["provided"] -and [bool] $secretRotationSnapshot["parsed"] -and [bool] $secretRotationSnapshot["validFormatVersion"]
$commercialIntegrationSnapshotValid = [bool] $commercialIntegrationSnapshot["provided"] -and [bool] $commercialIntegrationSnapshot["parsed"] -and [bool] $commercialIntegrationSnapshot["validFormatVersion"]
$commercialApprovalSnapshotValid = [bool] $commercialApprovalSnapshot["provided"] -and [bool] $commercialApprovalSnapshot["parsed"] -and [bool] $commercialApprovalSnapshot["validFormatVersion"]
$chargebackCloseoutSnapshotValid = [bool] $chargebackCloseoutSnapshot["provided"] -and [bool] $chargebackCloseoutSnapshot["parsed"] -and [bool] $chargebackCloseoutSnapshot["validFormatVersion"]
$enterpriseAuthSmokeSnapshotValid = [bool] $enterpriseAuthSmokeSnapshot["provided"] -and [bool] $enterpriseAuthSmokeSnapshot["parsed"] -and [bool] $enterpriseAuthSmokeSnapshot["validFormatVersion"]
$enterpriseAuthJitRollbackSnapshotValid = [bool] $enterpriseAuthJitRollbackSnapshot["provided"] -and [bool] $enterpriseAuthJitRollbackSnapshot["parsed"] -and [bool] $enterpriseAuthJitRollbackSnapshot["validFormatVersion"]
$monitoringThresholdSnapshotValid = [bool] $monitoringThresholdSnapshot["provided"] -and [bool] $monitoringThresholdSnapshot["parsed"] -and [bool] $monitoringThresholdSnapshot["validFormatVersion"]
$clusterNetworkAccessReviewSnapshotValid = [bool] $clusterNetworkAccessReviewSnapshot["provided"] -and [bool] $clusterNetworkAccessReviewSnapshot["parsed"] -and [bool] $clusterNetworkAccessReviewSnapshot["validFormatVersion"]
$helmValuesHardeningSnapshotValid = [bool] $helmValuesHardeningSnapshot["provided"] -and [bool] $helmValuesHardeningSnapshot["parsed"] -and [bool] $helmValuesHardeningSnapshot["validFormatVersion"]
$operationsReadinessSnapshotReady = $operationsReadinessSnapshotValid -and [bool] $operationsReadinessSnapshot["ready"]
$operationsConvergenceSnapshotReady = $operationsConvergenceSnapshotValid `
    -and [bool] $operationsConvergenceSnapshot["ready"] `
    -and "ready".Equals([string] $operationsConvergenceSnapshot["readinessResult"], [System.StringComparison]::OrdinalIgnoreCase) `
    -and "ready".Equals([string] $operationsConvergenceSnapshot["finalizerResult"], [System.StringComparison]::OrdinalIgnoreCase) `
    -and "ready".Equals([string] $operationsConvergenceSnapshot["finalizerReadinessResult"], [System.StringComparison]::OrdinalIgnoreCase) `
    -and [bool] $operationsConvergenceSnapshot["finalizerFailedCountValid"] `
    -and [bool] $operationsConvergenceSnapshot["finalizerGapCountValid"] `
    -and [bool] $operationsConvergenceSnapshot["kubernetesReportSyncReadyValid"] `
    -and [bool] $operationsConvergenceSnapshot["kubernetesReportSyncFailedCountValid"] `
    -and ([int] $operationsConvergenceSnapshot["finalizerFailedCount"]) -eq 0 `
    -and ([int] $operationsConvergenceSnapshot["finalizerGapCount"]) -eq 0 `
    -and [bool] $operationsConvergenceSnapshot["kubernetesReportSyncReady"] `
    -and ([int] $operationsConvergenceSnapshot["kubernetesReportSyncFailedCount"]) -eq 0 `
    -and "ready".Equals([string] $operationsConvergenceSnapshot["kubernetesReportSyncSourceReportResult"], [System.StringComparison]::OrdinalIgnoreCase)
$dataFlowStoragePlanSnapshotPassed = $dataFlowStoragePlanSnapshotValid -and [bool] $dataFlowStoragePlanSnapshot["passed"] -and [bool] $dataFlowStoragePlanSnapshot["queryPlanEvidencePassed"]
$dataFlowQueryRetentionBudgetSnapshotPassed = $dataFlowQueryRetentionBudgetSnapshotValid `
    -and [bool] $dataFlowQueryRetentionBudgetSnapshot["passed"] `
    -and [bool] $dataFlowQueryRetentionBudgetSnapshot["metricCountsValid"] `
    -and [bool] $dataFlowQueryRetentionBudgetSnapshot["queryLatencyWithinBudget"] `
    -and [bool] $dataFlowQueryRetentionBudgetSnapshot["retentionJobsWithinBudget"] `
    -and [bool] $dataFlowQueryRetentionBudgetSnapshot["confirmationsValid"] `
    -and "passed".Equals([string] $dataFlowQueryRetentionBudgetSnapshot["storagePlanResult"], [System.StringComparison]::OrdinalIgnoreCase) `
    -and ([int64] $dataFlowQueryRetentionBudgetSnapshot["storagePlanPendingCount"]) -eq 0 `
    -and ([int64] $dataFlowQueryRetentionBudgetSnapshot["failureCount"]) -eq 0 `
    -and ([int64] $dataFlowQueryRetentionBudgetSnapshot["checkCount"]) -gt 0 `
    -and ([int64] $dataFlowQueryRetentionBudgetSnapshot["observedP95QueryLatencyMs"]) -le ([int64] $dataFlowQueryRetentionBudgetSnapshot["targetP95QueryLatencyMs"])
$dataFlowStorageTransitionRunbookSnapshotPassed = $dataFlowStorageTransitionRunbookSnapshotValid -and [bool] $dataFlowStorageTransitionRunbookSnapshot["passed"] -and [bool] $dataFlowStorageTransitionRunbookSnapshot["confirmationsValid"]
$secretRotationSnapshotPassed = $secretRotationSnapshotValid -and [bool] $secretRotationSnapshot["passed"] -and [bool] $secretRotationSnapshot["confirmationsValid"]
$commercialIntegrationSnapshotPassed = $commercialIntegrationSnapshotValid `
    -and [bool] $commercialIntegrationSnapshot["passed"] `
    -and [bool] $commercialIntegrationSnapshot["countsValid"] `
    -and ([int64] $commercialIntegrationSnapshot["requiredCount"]) -gt 0 `
    -and ([int64] $commercialIntegrationSnapshot["requiredVerifiedCount"]) -ge ([int64] $commercialIntegrationSnapshot["requiredCount"]) `
    -and ([int64] $commercialIntegrationSnapshot["verifiedCount"]) -ge ([int64] $commercialIntegrationSnapshot["requiredVerifiedCount"]) `
    -and ([int64] $commercialIntegrationSnapshot["integrationCount"]) -ge ([int64] $commercialIntegrationSnapshot["requiredCount"]) `
    -and ([int64] $commercialIntegrationSnapshot["failureCount"]) -eq 0 `
    -and ([int64] $commercialIntegrationSnapshot["plannedCount"]) -eq 0 `
    -and [bool] $commercialIntegrationSnapshot["paymentProviderAdapterReadinessReviewedValid"] `
    -and [bool] $commercialIntegrationSnapshot["paymentProviderAdapterReadinessReviewed"]
$commercialApprovalSnapshotPassed = $commercialApprovalSnapshotValid `
    -and [bool] $commercialApprovalSnapshot["passed"] `
    -and [bool] $commercialApprovalSnapshot["countsValid"] `
    -and ([int64] $commercialApprovalSnapshot["passedCount"]) -gt 0 `
    -and ([int64] $commercialApprovalSnapshot["checkCount"]) -gt 0 `
    -and ([int64] $commercialApprovalSnapshot["failureCount"]) -eq 0 `
    -and [bool] $commercialApprovalSnapshot["pricingPolicyProposalCommercialApprovedValid"] `
    -and [bool] $commercialApprovalSnapshot["pricingPolicyProposalCommercialApproved"] `
    -and ([int64] $commercialApprovalSnapshot["pricingPolicyProposalCommercialApprovedCount"]) -gt 0 `
    -and ([int64] $commercialApprovalSnapshot["pricingPolicyProposalApprovedPriceListCount"]) -gt 0
$chargebackCloseoutSnapshotPassed = $chargebackCloseoutSnapshotValid `
    -and [bool] $chargebackCloseoutSnapshot["passed"] `
    -and [bool] $chargebackCloseoutSnapshot["summaryValid"] `
    -and [bool] $chargebackCloseoutSnapshot["confirmationsValid"] `
    -and [bool] $chargebackCloseoutSnapshot["closeoutCountsValid"] `
    -and [bool] $chargebackCloseoutSnapshot["rawDataFlagsValid"] `
    -and [bool] $chargebackCloseoutSnapshot["noRawDataStored"] `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["valid"] `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["statusClosed"] `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["billingPeriodMatches"] `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["failureCountZero"] `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["blockerCountZero"] `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["scanLimitPositive"] `
    -and (-not [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["sourceTruncated"]) `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["sourceComplete"] `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["truncationBlockerCountZero"] `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["closeoutReady"] `
    -and [bool] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["readinessBooleansClosed"] `
    -and ([int64] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["counts"]["scanLimit"]) -gt 0 `
    -and ([int64] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["counts"]["blockerCount"]) -eq 0 `
    -and ([int64] $chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["counts"]["truncationBlockerCount"]) -eq 0 `
    -and ([int64] $chargebackCloseoutSnapshot["failureCount"]) -eq 0 `
    -and ([int64] $chargebackCloseoutSnapshot["plannedCount"]) -eq 0 `
    -and ([int64] $chargebackCloseoutSnapshot["checkCount"]) -gt 0 `
    -and ([int64] $chargebackCloseoutSnapshot["reconciliationDifferenceMinorUnits"]) -eq 0

$enterpriseAuthSmokeSnapshotPassed = $enterpriseAuthSmokeSnapshotValid `
    -and [bool] $enterpriseAuthSmokeSnapshot["passed"] `
    -and [bool] $enterpriseAuthSmokeSnapshot["countsValid"] `
    -and ([int64] $enterpriseAuthSmokeSnapshot["passCount"]) -gt 0 `
    -and ([int64] $enterpriseAuthSmokeSnapshot["failCount"]) -eq 0 `
    -and ([int64] $enterpriseAuthSmokeSnapshot["blockedCount"]) -eq 0 `
    -and ([int64] $enterpriseAuthSmokeSnapshot["plannedCount"]) -eq 0
$enterpriseAuthSmokeSnapshotScopeOutAccepted = $enterpriseAuthSmokeSnapshotValid `
    -and "scope-out".Equals([string] $enterpriseAuthSmokeSnapshot["result"], [System.StringComparison]::OrdinalIgnoreCase) `
    -and [bool] $enterpriseAuthSmokeSnapshot["scopeOutAcceptedValid"] `
    -and [bool] $enterpriseAuthSmokeSnapshot["scopeOutAccepted"]
$enterpriseAuthSmokeSnapshotAccepted = $enterpriseAuthSmokeSnapshotPassed -or $enterpriseAuthSmokeSnapshotScopeOutAccepted
$enterpriseAuthJitRollbackSnapshotPassed = $enterpriseAuthJitRollbackSnapshotValid `
    -and [bool] $enterpriseAuthJitRollbackSnapshot["passed"] `
    -and [bool] $enterpriseAuthJitRollbackSnapshot["confirmationsValid"] `
    -and ([int64] $enterpriseAuthJitRollbackSnapshot["failureCount"]) -eq 0 `
    -and ([int64] $enterpriseAuthJitRollbackSnapshot["checkCount"]) -gt 0
$enterpriseAuthJitRollbackSnapshotRequired = ([bool] $RequireProductionEvidence -and $enterpriseAuthSmokeSnapshotPassed) `
    -or [bool] $enterpriseAuthJitRollbackSnapshot["provided"] `
    -or [bool] $ConfirmEnterpriseAuthJitRollbackSnapshotReviewed
$monitoringThresholdSnapshotPassed = $monitoringThresholdSnapshotValid -and [bool] $monitoringThresholdSnapshot["passed"] -and [bool] $monitoringThresholdSnapshot["complete"]
$clusterNetworkAccessReviewSnapshotPassed = $clusterNetworkAccessReviewSnapshotValid -and [bool] $clusterNetworkAccessReviewSnapshot["passed"] -and [bool] $clusterNetworkAccessReviewSnapshot["countsValid"] -and [bool] $clusterNetworkAccessReviewSnapshot["staticControlsValid"] -and [bool] $clusterNetworkAccessReviewSnapshot["confirmationsValid"] -and ([int64] $clusterNetworkAccessReviewSnapshot["failureCount"]) -eq 0 -and ([int64] $clusterNetworkAccessReviewSnapshot["totalCount"]) -gt 0
$helmValuesHardeningSnapshotPassed = $helmValuesHardeningSnapshotValid -and [bool] $helmValuesHardeningSnapshot["passed"] -and [bool] $helmValuesHardeningSnapshot["countsValid"] -and [bool] $helmValuesHardeningSnapshot["staticHardeningValid"] -and [bool] $helmValuesHardeningSnapshot["confirmationsValid"] -and ([int64] $helmValuesHardeningSnapshot["failureCount"]) -eq 0 -and ([int64] $helmValuesHardeningSnapshot["totalCount"]) -gt 0 -and ([int64] $helmValuesHardeningSnapshot["chartFileCount"]) -gt 0
$targetEvidenceIdentityEntries = @(
    [pscustomobject]@{ label = "targetEvidenceSnapshots.dataFlowStoragePlan"; snapshot = $dataFlowStoragePlanSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $dataFlowStoragePlanSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.dataFlowQueryRetentionBudget"; snapshot = $dataFlowQueryRetentionBudgetSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $dataFlowQueryRetentionBudgetSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.dataFlowStorageTransitionRunbook"; snapshot = $dataFlowStorageTransitionRunbookSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $dataFlowStorageTransitionRunbookSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.secretRotation"; snapshot = $secretRotationSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $secretRotationSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.commercialIntegration"; snapshot = $commercialIntegrationSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $commercialIntegrationSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.commercialApproval"; snapshot = $commercialApprovalSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $commercialApprovalSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.chargebackCloseout"; snapshot = $chargebackCloseoutSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $chargebackCloseoutSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.enterpriseAuthSmoke"; snapshot = $enterpriseAuthSmokeSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $enterpriseAuthSmokeSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.enterpriseAuthJitRollback"; snapshot = $enterpriseAuthJitRollbackSnapshot; required = $enterpriseAuthJitRollbackSnapshotRequired },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.monitoringThreshold"; snapshot = $monitoringThresholdSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $monitoringThresholdSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.clusterNetworkAccessReview"; snapshot = $clusterNetworkAccessReviewSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $clusterNetworkAccessReviewSnapshot["provided"]) },
    [pscustomobject]@{ label = "targetEvidenceSnapshots.helmValuesHardening"; snapshot = $helmValuesHardeningSnapshot; required = ([bool] $RequireProductionEvidence -or [bool] $helmValuesHardeningSnapshot["provided"]) }
)
$targetEvidenceIdentityCheckRequired = [bool] $RequireProductionEvidence
foreach ($entry in $targetEvidenceIdentityEntries) {
    if ([bool] $entry.required) {
        $targetEvidenceIdentityCheckRequired = $true
        break
    }
}
$targetEvidenceIdentityValidation = [pscustomobject]@{ passed = $true; detail = "No target evidence identity snapshots supplied." }
if ($targetEvidenceIdentityCheckRequired) {
    $targetEvidenceIdentityValidation = Test-TargetEvidenceIdentityConsistency $targetEvidenceIdentityEntries $EnvironmentName $TargetCluster $Operator
}

$evidenceText = $DeploymentEvidenceRef + $OperationsReadinessRef + $OperationsConvergenceRef + $DataFlowStoragePlanEvidenceRef + $DataFlowQueryRetentionBudgetEvidenceRef + $DataFlowStorageTransitionRunbookEvidenceRef + $SecretRotationEvidenceRef + $CommercialIntegrationEvidenceRef + $CommercialApprovalEvidenceRef + $ChargebackCloseoutEvidenceRef + $EnterpriseAuthEvidenceRef + $EnterpriseAuthJitRollbackEvidenceRef + $BackupRestoreEvidenceRef + $HaDrEvidenceRef + $MonitoringEvidenceRef + $ClusterNetworkAccessReviewEvidenceRef + $HelmValuesHardeningEvidenceRef + $SecurityEvidenceRef + $IamRbacEvidenceRef + $RunbookReviewRef + $TroubleshootingReviewRef + $SupportEscalationRef + $SupportSlaRef + $KnownGapsRef
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $HandoffStartedAt + $HandoffCompletedAt + $ChangeApprovalRef + $evidenceText + $OperationsReadinessJsonPath + $OperationsConvergenceJsonPath + $DataFlowStoragePlanJsonPath + $DataFlowQueryRetentionBudgetJsonPath + $DataFlowStorageTransitionRunbookJsonPath + $SecretRotationJsonPath + $CommercialIntegrationJsonPath + $CommercialApprovalJsonPath + $ChargebackCloseoutJsonPath + $EnterpriseAuthJsonPath + $EnterpriseAuthJitRollbackJsonPath + $MonitoringThresholdJsonPath + $ClusterNetworkAccessReviewJsonPath + $HelmValuesHardeningJsonPath) -or $ConfirmRunbookReviewed -or $ConfirmTroubleshootingReviewed -or $ConfirmRollbackReviewed -or $ConfirmSupportEscalationReviewed -or $ConfirmKnownGapsAccepted -or $ConfirmOperationsReadinessSnapshotReviewed -or $ConfirmOperationsConvergenceSnapshotReviewed -or $ConfirmDataFlowStoragePlanReviewed -or $ConfirmDataFlowQueryRetentionBudgetReviewed -or $ConfirmDataFlowStorageTransitionRunbookReviewed -or $ConfirmSecretRotationSnapshotReviewed -or $ConfirmCommercialIntegrationSnapshotReviewed -or $ConfirmCommercialApprovalSnapshotReviewed -or $ConfirmChargebackCloseoutSnapshotReviewed -or $ConfirmEnterpriseAuthSmokeSnapshotReviewed -or $ConfirmEnterpriseAuthJitRollbackSnapshotReviewed -or $ConfirmMonitoringThresholdReviewed -or $ConfirmClusterNetworkAccessReviewReviewed -or $ConfirmHelmValuesHardeningReviewed -or $ConfirmNoSecretValues -or $RequireOperationsSnapshotEvidence
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
if ($targetEvidenceIdentityCheckRequired) {
    Add-Check "target-evidence-identity-consistent" "Target evidence identity consistent" ([bool] $targetEvidenceIdentityValidation.passed) ([string] $targetEvidenceIdentityValidation.detail)
}

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
    Add-Check "operations-convergence-snapshot-ready" "Operations convergence snapshot ready" $operationsConvergenceSnapshotReady "result=$($operationsConvergenceSnapshot["result"]); readinessResult=$($operationsConvergenceSnapshot["readinessResult"]); finalizerResult=$($operationsConvergenceSnapshot["finalizerResult"]); finalizerReadinessResult=$($operationsConvergenceSnapshot["finalizerReadinessResult"]); finalizerFailed=$($operationsConvergenceSnapshot["finalizerFailedCountRaw"])(valid=$($operationsConvergenceSnapshot["finalizerFailedCountValid"])); finalizerGaps=$($operationsConvergenceSnapshot["finalizerGapCountRaw"])(valid=$($operationsConvergenceSnapshot["finalizerGapCountValid"])); kubernetesReportSyncReady=$($operationsConvergenceSnapshot["kubernetesReportSyncReadyRaw"])(valid=$($operationsConvergenceSnapshot["kubernetesReportSyncReadyValid"])); failedSyncChecks=$($operationsConvergenceSnapshot["kubernetesReportSyncFailedCountRaw"])(valid=$($operationsConvergenceSnapshot["kubernetesReportSyncFailedCountValid"])); sourceReportResult=$($operationsConvergenceSnapshot["kubernetesReportSyncSourceReportResult"])" $OperationsConvergenceRef
}
if ([bool] $RequireOperationsSnapshotEvidence -or [bool] $operationsConvergenceSnapshot["provided"] -or [bool] $ConfirmOperationsConvergenceSnapshotReviewed) {
    Add-Check "operations-convergence-snapshot-reviewed" "Operations convergence snapshot reviewed" ([bool] $ConfirmOperationsConvergenceSnapshotReviewed -and $operationsConvergenceSnapshotValid) "confirmed=$([bool] $ConfirmOperationsConvergenceSnapshotReviewed); snapshotValid=$operationsConvergenceSnapshotValid" $OperationsConvergenceRef
}
Add-EvidenceCheck "data-flow-storage-plan-evidence" "Data-flow storage transition target evidence" ([bool] $RequireProductionEvidence) $DataFlowStoragePlanEvidenceRef "target data-flow storage plan result=passed with sanitized query-plan summary"
if ([bool] $RequireProductionEvidence -or [bool] $dataFlowStoragePlanSnapshot["provided"]) {
    Add-Check "data-flow-storage-plan-snapshot-parsed" "Data-flow storage plan snapshot parsed" $dataFlowStoragePlanSnapshotValid $dataFlowStoragePlanSnapshot["detail"] $DataFlowStoragePlanEvidenceRef
    Add-Check "data-flow-storage-plan-snapshot-passed" "Data-flow storage plan snapshot passed" $dataFlowStoragePlanSnapshotPassed "result=$($dataFlowStoragePlanSnapshot["result"]); pending=$($dataFlowStoragePlanSnapshot["pendingCount"]); candidateStore=$($dataFlowStoragePlanSnapshot["candidateStore"]); queryPlanEvidenceRequired=$($dataFlowStoragePlanSnapshot["queryPlanEvidenceRequired"]); queryPlanEvidencePassed=$($dataFlowStoragePlanSnapshot["queryPlanEvidencePassed"])" $DataFlowStoragePlanEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $dataFlowStoragePlanSnapshot["provided"] -or [bool] $ConfirmDataFlowStoragePlanReviewed) {
    Add-Check "data-flow-storage-plan-reviewed" "Data-flow storage plan reviewed" ([bool] $ConfirmDataFlowStoragePlanReviewed -and $dataFlowStoragePlanSnapshotValid) "confirmed=$([bool] $ConfirmDataFlowStoragePlanReviewed); snapshotValid=$dataFlowStoragePlanSnapshotValid" $DataFlowStoragePlanEvidenceRef
}
Add-EvidenceCheck "data-flow-query-retention-budget-evidence" "Data-flow query/retention budget target evidence" ([bool] $RequireProductionEvidence) $DataFlowQueryRetentionBudgetEvidenceRef "target p95 query latency and detailed/daily/monthly retention job durations are within budget"
if ([bool] $RequireProductionEvidence -or [bool] $dataFlowQueryRetentionBudgetSnapshot["provided"]) {
    Add-Check "data-flow-query-retention-budget-snapshot-parsed" "Data-flow query/retention budget snapshot parsed" $dataFlowQueryRetentionBudgetSnapshotValid $dataFlowQueryRetentionBudgetSnapshot["detail"] $DataFlowQueryRetentionBudgetEvidenceRef
    Add-Check "data-flow-query-retention-budget-snapshot-passed" "Data-flow query/retention budget snapshot passed" $dataFlowQueryRetentionBudgetSnapshotPassed "result=$($dataFlowQueryRetentionBudgetSnapshot["result"]); storagePlanResult=$($dataFlowQueryRetentionBudgetSnapshot["storagePlanResult"]); p95=$($dataFlowQueryRetentionBudgetSnapshot["observedP95QueryLatencyMs"])/$($dataFlowQueryRetentionBudgetSnapshot["targetP95QueryLatencyMs"]); retentionSeconds=$($dataFlowQueryRetentionBudgetSnapshot["detailedRetentionObservedSeconds"])/$($dataFlowQueryRetentionBudgetSnapshot["dailyRollupRetentionObservedSeconds"])/$($dataFlowQueryRetentionBudgetSnapshot["monthlyRollupRetentionObservedSeconds"]); budgetSeconds=$($dataFlowQueryRetentionBudgetSnapshot["retentionBudgetSeconds"]); failures=$($dataFlowQueryRetentionBudgetSnapshot["failureCount"]); metricsValid=$($dataFlowQueryRetentionBudgetSnapshot["metricCountsValid"]); confirmationsValid=$($dataFlowQueryRetentionBudgetSnapshot["confirmationsValid"])" $DataFlowQueryRetentionBudgetEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $dataFlowQueryRetentionBudgetSnapshot["provided"] -or [bool] $ConfirmDataFlowQueryRetentionBudgetReviewed) {
    Add-Check "data-flow-query-retention-budget-reviewed" "Data-flow query/retention budget reviewed" ([bool] $ConfirmDataFlowQueryRetentionBudgetReviewed -and $dataFlowQueryRetentionBudgetSnapshotValid) "confirmed=$([bool] $ConfirmDataFlowQueryRetentionBudgetReviewed); snapshotValid=$dataFlowQueryRetentionBudgetSnapshotValid" $DataFlowQueryRetentionBudgetEvidenceRef
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
Add-EvidenceCheck "commercial-integration-evidence" "Commercial integration target evidence" ([bool] $RequireProductionEvidence) $CommercialIntegrationEvidenceRef "target commercial integration result=passed with native bridge readiness snapshot and without vendor-specific processor claims"
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
Add-EvidenceCheck "chargeback-closeout-evidence" "Chargeback closeout target evidence" ([bool] $RequireProductionEvidence) $ChargebackCloseoutEvidenceRef "target billing period chargeback closeout result=passed with sanitized invoice/payment/reconciliation summary"
if ([bool] $RequireProductionEvidence -or [bool] $chargebackCloseoutSnapshot["provided"]) {
    Add-Check "chargeback-closeout-snapshot-parsed" "Chargeback closeout snapshot parsed" $chargebackCloseoutSnapshotValid $chargebackCloseoutSnapshot["detail"] $ChargebackCloseoutEvidenceRef
    Add-Check "chargeback-closeout-snapshot-passed" "Chargeback closeout snapshot passed" $chargebackCloseoutSnapshotPassed "result=$($chargebackCloseoutSnapshot["result"]); billingPeriod=$($chargebackCloseoutSnapshot["billingPeriod"]); failures=$($chargebackCloseoutSnapshot["failureCount"]); planned=$($chargebackCloseoutSnapshot["plannedCount"]); reconciliationDifferenceMinorUnits=$($chargebackCloseoutSnapshot["reconciliationDifferenceMinorUnits"]); snapshotValid=$($chargebackCloseoutSnapshot["chargebackCloseoutSnapshot"]["valid"]); confirmationsValid=$($chargebackCloseoutSnapshot["confirmationsValid"]); noRawDataStored=$($chargebackCloseoutSnapshot["noRawDataStored"])" $ChargebackCloseoutEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $chargebackCloseoutSnapshot["provided"] -or [bool] $ConfirmChargebackCloseoutSnapshotReviewed) {
    Add-Check "chargeback-closeout-snapshot-reviewed" "Chargeback closeout snapshot reviewed" ([bool] $ConfirmChargebackCloseoutSnapshotReviewed -and $chargebackCloseoutSnapshotValid) "confirmed=$([bool] $ConfirmChargebackCloseoutSnapshotReviewed); snapshotValid=$chargebackCloseoutSnapshotValid" $ChargebackCloseoutEvidenceRef
}
Add-EvidenceCheck "enterprise-auth-evidence" "Enterprise auth target evidence" ([bool] $RequireProductionEvidence) $EnterpriseAuthEvidenceRef "target IdP/directory smoke result=passed or contracted scope-out"
if ([bool] $RequireProductionEvidence -or [bool] $enterpriseAuthSmokeSnapshot["provided"]) {
    Add-Check "enterprise-auth-smoke-snapshot-parsed" "Enterprise auth smoke snapshot parsed" $enterpriseAuthSmokeSnapshotValid $enterpriseAuthSmokeSnapshot["detail"] $EnterpriseAuthEvidenceRef
    Add-Check "enterprise-auth-smoke-snapshot-accepted" "Enterprise auth smoke snapshot accepted" $enterpriseAuthSmokeSnapshotAccepted "result=$($enterpriseAuthSmokeSnapshot["result"]); scopeOutAccepted=$($enterpriseAuthSmokeSnapshot["scopeOutAccepted"]); pass=$($enterpriseAuthSmokeSnapshot["passCount"]); fail=$($enterpriseAuthSmokeSnapshot["failCount"]); blocked=$($enterpriseAuthSmokeSnapshot["blockedCount"]); planned=$($enterpriseAuthSmokeSnapshot["plannedCount"]); countsValid=$($enterpriseAuthSmokeSnapshot["countsValid"])" $EnterpriseAuthEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $enterpriseAuthSmokeSnapshot["provided"] -or [bool] $ConfirmEnterpriseAuthSmokeSnapshotReviewed) {
    Add-Check "enterprise-auth-smoke-snapshot-reviewed" "Enterprise auth smoke snapshot reviewed" ([bool] $ConfirmEnterpriseAuthSmokeSnapshotReviewed -and $enterpriseAuthSmokeSnapshotValid) "confirmed=$([bool] $ConfirmEnterpriseAuthSmokeSnapshotReviewed); snapshotValid=$enterpriseAuthSmokeSnapshotValid" $EnterpriseAuthEvidenceRef
}
if ($enterpriseAuthJitRollbackSnapshotRequired) {
    Add-EvidenceCheck "enterprise-auth-jit-rollback-evidence" "Enterprise auth JIT rollback target evidence" $enterpriseAuthJitRollbackSnapshotRequired $EnterpriseAuthJitRollbackEvidenceRef "target admin-approved JIT rollback evidence without raw identity claims or credentials"
    Add-Check "enterprise-auth-jit-rollback-snapshot-parsed" "Enterprise auth JIT rollback snapshot parsed" $enterpriseAuthJitRollbackSnapshotValid $enterpriseAuthJitRollbackSnapshot["detail"] $EnterpriseAuthJitRollbackEvidenceRef
    Add-Check "enterprise-auth-jit-rollback-snapshot-passed" "Enterprise auth JIT rollback snapshot passed" $enterpriseAuthJitRollbackSnapshotPassed "result=$($enterpriseAuthJitRollbackSnapshot["result"]); failures=$($enterpriseAuthJitRollbackSnapshot["failureCount"]); checks=$($enterpriseAuthJitRollbackSnapshot["checkCount"]); confirmationsValid=$($enterpriseAuthJitRollbackSnapshot["confirmationsValid"]); smokeResult=$($enterpriseAuthJitRollbackSnapshot["enterpriseAuthSmokeSnapshot"]["result"])" $EnterpriseAuthJitRollbackEvidenceRef
    Add-Check "enterprise-auth-jit-rollback-snapshot-reviewed" "Enterprise auth JIT rollback snapshot reviewed" ([bool] $ConfirmEnterpriseAuthJitRollbackSnapshotReviewed -and $enterpriseAuthJitRollbackSnapshotValid) "confirmed=$([bool] $ConfirmEnterpriseAuthJitRollbackSnapshotReviewed); snapshotValid=$enterpriseAuthJitRollbackSnapshotValid" $EnterpriseAuthJitRollbackEvidenceRef
}
Add-EvidenceCheck "backup-restore-evidence" "Backup/restore target evidence" ([bool] $RequireProductionEvidence) $BackupRestoreEvidenceRef "target backup restore or DR drill evidence"
Add-EvidenceCheck "ha-dr-evidence" "HA/DR target evidence" ([bool] $RequireProductionEvidence) $HaDrEvidenceRef "target HA/DR readiness evidence"
Add-EvidenceCheck "monitoring-evidence" "Monitoring target evidence" ([bool] $RequireProductionEvidence) $MonitoringEvidenceRef "target Prometheus/Alertmanager/Grafana evidence"
if ([bool] $RequireProductionEvidence -or [bool] $monitoringThresholdSnapshot["provided"]) {
    Add-Check "monitoring-threshold-snapshot-parsed" "Monitoring threshold snapshot parsed" $monitoringThresholdSnapshotValid $monitoringThresholdSnapshot["detail"] $MonitoringEvidenceRef
    Add-Check "monitoring-threshold-snapshot-passed" "Monitoring threshold snapshot passed" $monitoringThresholdSnapshotPassed "result=$($monitoringThresholdSnapshot["result"]); alerts=$($monitoringThresholdSnapshot["mappedAlertCount"])/$($monitoringThresholdSnapshot["requiredAlertCount"]); failures=$($monitoringThresholdSnapshot["failureCount"]); mappingComplete=$($monitoringThresholdSnapshot["thresholdMappingComplete"]); complete=$($monitoringThresholdSnapshot["complete"])" $MonitoringEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $monitoringThresholdSnapshot["provided"] -or [bool] $ConfirmMonitoringThresholdReviewed) {
    Add-Check "monitoring-threshold-reviewed" "Monitoring threshold snapshot reviewed" ([bool] $ConfirmMonitoringThresholdReviewed -and $monitoringThresholdSnapshotValid) "confirmed=$([bool] $ConfirmMonitoringThresholdReviewed); snapshotValid=$monitoringThresholdSnapshotValid" $MonitoringEvidenceRef
}
Add-EvidenceCheck "cluster-network-access-review-evidence" "Cluster network access review target evidence" ([bool] $RequireProductionEvidence) $ClusterNetworkAccessReviewEvidenceRef "target cluster NetworkPolicy access review result=passed with static hashes and no-credential confirmations"
if ([bool] $RequireProductionEvidence -or [bool] $clusterNetworkAccessReviewSnapshot["provided"]) {
    Add-Check "cluster-network-access-review-snapshot-parsed" "Cluster network access review snapshot parsed" $clusterNetworkAccessReviewSnapshotValid $clusterNetworkAccessReviewSnapshot["detail"] $ClusterNetworkAccessReviewEvidenceRef
    Add-Check "cluster-network-access-review-snapshot-passed" "Cluster network access review snapshot passed" $clusterNetworkAccessReviewSnapshotPassed "result=$($clusterNetworkAccessReviewSnapshot["result"]); failures=$($clusterNetworkAccessReviewSnapshot["failureCount"]); checks=$($clusterNetworkAccessReviewSnapshot["totalCount"]); staticControlsValid=$($clusterNetworkAccessReviewSnapshot["staticControlsValid"]); confirmationsValid=$($clusterNetworkAccessReviewSnapshot["confirmationsValid"])" $ClusterNetworkAccessReviewEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $clusterNetworkAccessReviewSnapshot["provided"] -or [bool] $ConfirmClusterNetworkAccessReviewReviewed) {
    Add-Check "cluster-network-access-review-reviewed" "Cluster network access review snapshot reviewed" ([bool] $ConfirmClusterNetworkAccessReviewReviewed -and $clusterNetworkAccessReviewSnapshotValid) "confirmed=$([bool] $ConfirmClusterNetworkAccessReviewReviewed); snapshotValid=$clusterNetworkAccessReviewSnapshotValid" $ClusterNetworkAccessReviewEvidenceRef
}
Add-EvidenceCheck "helm-values-hardening-evidence" "Helm values hardening target evidence" ([bool] $RequireProductionEvidence) $HelmValuesHardeningEvidenceRef "target Helm values hardening result=passed with externalized secrets, HA/resource/security/network/TLS, read-only reports, and storage expansion RBAC defaults"
if ([bool] $RequireProductionEvidence -or [bool] $helmValuesHardeningSnapshot["provided"]) {
    Add-Check "helm-values-hardening-snapshot-parsed" "Helm values hardening snapshot parsed" $helmValuesHardeningSnapshotValid $helmValuesHardeningSnapshot["detail"] $HelmValuesHardeningEvidenceRef
    Add-Check "helm-values-hardening-snapshot-passed" "Helm values hardening snapshot passed" $helmValuesHardeningSnapshotPassed "result=$($helmValuesHardeningSnapshot["result"]); failures=$($helmValuesHardeningSnapshot["failureCount"]); checks=$($helmValuesHardeningSnapshot["totalCount"]); chartFiles=$($helmValuesHardeningSnapshot["chartFileCount"]); staticHardeningValid=$($helmValuesHardeningSnapshot["staticHardeningValid"]); confirmationsValid=$($helmValuesHardeningSnapshot["confirmationsValid"])" $HelmValuesHardeningEvidenceRef
}
if ([bool] $RequireProductionEvidence -or [bool] $helmValuesHardeningSnapshot["provided"] -or [bool] $ConfirmHelmValuesHardeningReviewed) {
    Add-Check "helm-values-hardening-reviewed" "Helm values hardening snapshot reviewed" ([bool] $ConfirmHelmValuesHardeningReviewed -and $helmValuesHardeningSnapshotValid) "confirmed=$([bool] $ConfirmHelmValuesHardeningReviewed); snapshotValid=$helmValuesHardeningSnapshotValid" $HelmValuesHardeningEvidenceRef
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
    dataFlowQueryRetentionBudget = $DataFlowQueryRetentionBudgetEvidenceRef
    dataFlowStorageTransitionRunbook = $DataFlowStorageTransitionRunbookEvidenceRef
    secretRotation = $SecretRotationEvidenceRef
    commercialIntegration = $CommercialIntegrationEvidenceRef
    commercialApproval = $CommercialApprovalEvidenceRef
    chargebackCloseout = $ChargebackCloseoutEvidenceRef
    enterpriseAuth = $EnterpriseAuthEvidenceRef
    enterpriseAuthJitRollback = $EnterpriseAuthJitRollbackEvidenceRef
    backupRestore = $BackupRestoreEvidenceRef
    haDr = $HaDrEvidenceRef
    monitoring = $MonitoringEvidenceRef
    clusterNetworkAccessReview = $ClusterNetworkAccessReviewEvidenceRef
    helmValuesHardening = $HelmValuesHardeningEvidenceRef
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
    dataFlowQueryRetentionBudget = $dataFlowQueryRetentionBudgetSnapshot
    dataFlowStorageTransitionRunbook = $dataFlowStorageTransitionRunbookSnapshot
    secretRotation = $secretRotationSnapshot
    commercialIntegration = $commercialIntegrationSnapshot
    commercialApproval = $commercialApprovalSnapshot
    chargebackCloseout = $chargebackCloseoutSnapshot
    enterpriseAuthSmoke = $enterpriseAuthSmokeSnapshot
    enterpriseAuthJitRollback = $enterpriseAuthJitRollbackSnapshot
    monitoringThreshold = $monitoringThresholdSnapshot
    clusterNetworkAccessReview = $clusterNetworkAccessReviewSnapshot
    helmValuesHardening = $helmValuesHardeningSnapshot
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
    dataFlowQueryRetentionBudgetReviewed = [bool] $ConfirmDataFlowQueryRetentionBudgetReviewed
    dataFlowStorageTransitionRunbookReviewed = [bool] $ConfirmDataFlowStorageTransitionRunbookReviewed
    secretRotationSnapshotReviewed = [bool] $ConfirmSecretRotationSnapshotReviewed
    commercialIntegrationSnapshotReviewed = [bool] $ConfirmCommercialIntegrationSnapshotReviewed
    commercialApprovalSnapshotReviewed = [bool] $ConfirmCommercialApprovalSnapshotReviewed
    chargebackCloseoutSnapshotReviewed = [bool] $ConfirmChargebackCloseoutSnapshotReviewed
    enterpriseAuthSmokeSnapshotReviewed = [bool] $ConfirmEnterpriseAuthSmokeSnapshotReviewed
    enterpriseAuthJitRollbackSnapshotReviewed = [bool] $ConfirmEnterpriseAuthJitRollbackSnapshotReviewed
    monitoringThresholdReviewed = [bool] $ConfirmMonitoringThresholdReviewed
    clusterNetworkAccessReviewReviewed = [bool] $ConfirmClusterNetworkAccessReviewReviewed
    helmValuesHardeningReviewed = [bool] $ConfirmHelmValuesHardeningReviewed
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
    operationsConvergenceHandoffPostDispatchCommandCount = $operationsConvergenceSnapshot["handoffPostDispatchCommandCount"]
    dataFlowStoragePlanSnapshotResult = $dataFlowStoragePlanSnapshot["result"]
    dataFlowQueryRetentionBudgetSnapshotResult = $dataFlowQueryRetentionBudgetSnapshot["result"]
    dataFlowStorageTransitionRunbookSnapshotResult = $dataFlowStorageTransitionRunbookSnapshot["result"]
    secretRotationSnapshotResult = $secretRotationSnapshot["result"]
    commercialIntegrationSnapshotResult = $commercialIntegrationSnapshot["result"]
    commercialApprovalSnapshotResult = $commercialApprovalSnapshot["result"]
    chargebackCloseoutSnapshotResult = $chargebackCloseoutSnapshot["result"]
    enterpriseAuthSmokeSnapshotResult = $enterpriseAuthSmokeSnapshot["result"]
    enterpriseAuthJitRollbackSnapshotResult = $enterpriseAuthJitRollbackSnapshot["result"]
    monitoringThresholdSnapshotResult = $monitoringThresholdSnapshot["result"]
    clusterNetworkAccessReviewSnapshotResult = $clusterNetworkAccessReviewSnapshot["result"]
    helmValuesHardeningSnapshotResult = $helmValuesHardeningSnapshot["result"]
})
[void] $report.Add("checks", [object] $checkArray)
[void] $report.Add("decisionRule", "Production/B2B operations handoff package readiness requires result=passed from the target environment, reviewed runbook/troubleshooting/rollback/support paths, accepted known gaps, no-secret confirmation, and references to target readiness, convergence, data-flow storage transition, data-flow query/retention budget, data-flow storage transition runbook, secret rotation, commercial integration, commercial approval, enterprise auth, backup/restore, HA/DR, monitoring, cluster network access review, Helm values hardening, security, and IAM/RBAC evidence when production evidence is required. When operations snapshot evidence is required, the latest operations readiness snapshot must be result=ready and the latest operations readiness convergence snapshot must be result=ready with readinessResult=ready, finalizer result=ready, typed integer finalizer failed/gap counts at zero, typed boolean Kubernetes report sync ready=true, typed integer failedSyncChecks=0, and sourceReportResult=ready. When production evidence is required, the data-flow storage plan, data-flow query/retention budget, data-flow storage transition runbook, secret rotation, commercial integration, chargeback closeout, commercial approval, monitoring threshold, cluster network access review, and Helm values hardening snapshots must be result=passed; the query/retention budget snapshot must prove observed p95 query latency and detailed/daily/monthly retention jobs are within budget with typed metric counts and confirmations; the enterprise auth smoke snapshot must be result=passed with typed integer summary counts, passCount>0, failCount=0, blockedCount=0, plannedCount=0, or result=scope-out with accepted=true; active enterprise auth production handoffs with smoke result=passed must include a passed enterprise auth JIT rollback snapshot with reviewed admin approval, rollback, fallback, audit, no-raw-claims, and no-secret confirmations; and the data-flow storage plan, data-flow query/retention budget, data-flow storage transition runbook, secret rotation, commercial integration, commercial approval, chargeback closeout, enterprise auth smoke, required enterprise auth JIT rollback, monitoring threshold, cluster network access review, and Helm values hardening snapshots must be reviewed.")
[void] $report.Add("scopePolicy", "This package is a handoff wrapper for already-collected operations evidence. It can reduce sanitized operations readiness, convergence, data-flow storage plan, data-flow query/retention budget, data-flow storage transition runbook, secret rotation, commercial integration, chargeback closeout, commercial approval, enterprise auth smoke, enterprise auth JIT rollback, monitoring threshold, cluster network access review, and Helm values hardening JSON snapshots to summary fields, but it does not execute kubectl, gh, provider APIs, notification adapters, payment adapters, configurable native payment-provider bridge calls, storage migrations, IdP/directory login flows, user/role/org/team rollback operations, Prometheus/Grafana/Alertmanager API calls, or vendor-specific fixed SDK/schema card/bank/tax/ERP processor calls.")
[void] $report.Add("secretPolicy", "Evidence stores only environment labels, operator/change references, timestamps, booleans, external evidence references, reduced operations readiness/convergence snapshot summaries, reduced data-flow storage plan/query-retention/runbook summaries, reduced secret rotation summaries, reduced commercial and chargeback closeout evidence summaries, reduced enterprise auth smoke and JIT rollback summaries, reduced monitoring threshold summaries, and reduced cluster network/Helm hardening summaries; it must not contain passwords, bearer tokens, kubeconfig values, private keys, SMTP credentials, webhook signing secrets, provider credentials, raw SQL, raw EXPLAIN JSON, object keys, raw event messages, raw provider responses, raw identity claims, raw identity provider or directory responses, OIDC codes/states/tokens, LDAP/admin passwords, raw remediation commands containing credentials, raw Alertmanager receiver secrets, raw price tables, raw contract text, or customer payment data.")

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
$markdownLines += "- Convergence: provided=$($operationsConvergenceSnapshot["provided"]); parsed=$($operationsConvergenceSnapshot["parsed"]); result=$($operationsConvergenceSnapshot["result"]); readiness=$($operationsConvergenceSnapshot["readinessResult"]); finalizerFailed=$($operationsConvergenceSnapshot["finalizerFailedCount"]); finalizerGaps=$($operationsConvergenceSnapshot["finalizerGapCount"]); kubernetesReportSyncReady=$($operationsConvergenceSnapshot["kubernetesReportSyncReady"]); sourceReportResult=$($operationsConvergenceSnapshot["kubernetesReportSyncSourceReportResult"]); handoffPostDispatchCommands=$($operationsConvergenceSnapshot["handoffPostDispatchCommandCount"])"
foreach ($pendingCheck in @($operationsReadinessSnapshot["topPendingChecks"])) {
    $markdownLines += "- Readiness pending: [$($pendingCheck.status)] $($pendingCheck.category) / $($pendingCheck.name): $($pendingCheck.detail)"
}

$markdownLines += ""
$markdownLines += "## Target Evidence Snapshots"
$markdownLines += ""
$markdownLines += "- Data-flow storage plan: provided=$($dataFlowStoragePlanSnapshot["provided"]); parsed=$($dataFlowStoragePlanSnapshot["parsed"]); result=$($dataFlowStoragePlanSnapshot["result"]); candidateStore=$($dataFlowStoragePlanSnapshot["candidateStore"]); targetP95QueryLatencyMs=$($dataFlowStoragePlanSnapshot["targetP95QueryLatencyMs"]); passed=$($dataFlowStoragePlanSnapshot["passedCount"]); pending=$($dataFlowStoragePlanSnapshot["pendingCount"]); checks=$($dataFlowStoragePlanSnapshot["checkCount"])"
$dataFlowStoragePlanCandidateDecision = $dataFlowStoragePlanSnapshot["candidateDecision"]
$markdownLines += "- Data-flow candidate decision: candidateStore=$($dataFlowStoragePlanCandidateDecision["candidateStore"]); decision=$($dataFlowStoragePlanCandidateDecision["decision"]); evidenceModel=$($dataFlowStoragePlanCandidateDecision["evidenceModel"]); mariaDbQueryEvidenceRequired=$($dataFlowStoragePlanCandidateDecision["requiresMariaDbQueryEvidence"]); targetStoreEvidenceRequired=$($dataFlowStoragePlanCandidateDecision["requiresTargetStoreEvidence"]); queryPlanEvidencePassed=$($dataFlowStoragePlanCandidateDecision["queryPlanEvidencePassed"]); targetStoreEvidenceConfirmed=$($dataFlowStoragePlanCandidateDecision["targetStoreEvidenceConfirmed"]); nextAction=$($dataFlowStoragePlanCandidateDecision["nextAction"])"
$markdownLines += "- Data-flow query/retention budget: provided=$($dataFlowQueryRetentionBudgetSnapshot["provided"]); parsed=$($dataFlowQueryRetentionBudgetSnapshot["parsed"]); result=$($dataFlowQueryRetentionBudgetSnapshot["result"]); storagePlanResult=$($dataFlowQueryRetentionBudgetSnapshot["storagePlanResult"]); p95=$($dataFlowQueryRetentionBudgetSnapshot["observedP95QueryLatencyMs"])/$($dataFlowQueryRetentionBudgetSnapshot["targetP95QueryLatencyMs"]); p99=$($dataFlowQueryRetentionBudgetSnapshot["observedP99QueryLatencyMs"]); samples=$($dataFlowQueryRetentionBudgetSnapshot["querySampleCount"]); retentionSeconds=$($dataFlowQueryRetentionBudgetSnapshot["detailedRetentionObservedSeconds"])/$($dataFlowQueryRetentionBudgetSnapshot["dailyRollupRetentionObservedSeconds"])/$($dataFlowQueryRetentionBudgetSnapshot["monthlyRollupRetentionObservedSeconds"]); budgetSeconds=$($dataFlowQueryRetentionBudgetSnapshot["retentionBudgetSeconds"]); failures=$($dataFlowQueryRetentionBudgetSnapshot["failureCount"]); checks=$($dataFlowQueryRetentionBudgetSnapshot["checkCount"]); confirmationsValid=$($dataFlowQueryRetentionBudgetSnapshot["confirmationsValid"])"
$markdownLines += "- Data-flow storage transition runbook: provided=$($dataFlowStorageTransitionRunbookSnapshot["provided"]); parsed=$($dataFlowStorageTransitionRunbookSnapshot["parsed"]); result=$($dataFlowStorageTransitionRunbookSnapshot["result"]); storagePlanResult=$($dataFlowStorageTransitionRunbookSnapshot["storagePlanResult"]); candidateStore=$($dataFlowStorageTransitionRunbookSnapshot["candidateStore"]); failures=$($dataFlowStorageTransitionRunbookSnapshot["failureCount"]); checks=$($dataFlowStorageTransitionRunbookSnapshot["checkCount"])"
$markdownLines += "- Secret rotation: provided=$($secretRotationSnapshot["provided"]); parsed=$($secretRotationSnapshot["parsed"]); result=$($secretRotationSnapshot["result"]); core=$($secretRotationSnapshot["coreRotatedCount"])/$($secretRotationSnapshot["coreRequiredCount"]); failures=$($secretRotationSnapshot["failureCount"]); planned=$($secretRotationSnapshot["plannedCount"])"
$markdownLines += "- Commercial integration: provided=$($commercialIntegrationSnapshot["provided"]); parsed=$($commercialIntegrationSnapshot["parsed"]); result=$($commercialIntegrationSnapshot["result"]); requiredVerified=$($commercialIntegrationSnapshot["requiredVerifiedCount"])/$($commercialIntegrationSnapshot["requiredCount"]); failures=$($commercialIntegrationSnapshot["failureCount"]); planned=$($commercialIntegrationSnapshot["plannedCount"])"
$markdownLines += "- Commercial approval: provided=$($commercialApprovalSnapshot["provided"]); parsed=$($commercialApprovalSnapshot["parsed"]); result=$($commercialApprovalSnapshot["result"]); failures=$($commercialApprovalSnapshot["failureCount"]); checks=$($commercialApprovalSnapshot["checkCount"]); priceListApproved=$($commercialApprovalSnapshot["pricingPolicyProposalApprovedPriceListCount"])"
$markdownLines += "- Chargeback closeout: provided=$($chargebackCloseoutSnapshot["provided"]); parsed=$($chargebackCloseoutSnapshot["parsed"]); result=$($chargebackCloseoutSnapshot["result"]); billingPeriod=$($chargebackCloseoutSnapshot["billingPeriod"]); failures=$($chargebackCloseoutSnapshot["failureCount"]); planned=$($chargebackCloseoutSnapshot["plannedCount"]); reconciliationDifferenceMinorUnits=$($chargebackCloseoutSnapshot["reconciliationDifferenceMinorUnits"]); confirmationsValid=$($chargebackCloseoutSnapshot["confirmationsValid"]); noRawDataStored=$($chargebackCloseoutSnapshot["noRawDataStored"])"
$markdownLines += "- Enterprise auth smoke: provided=$($enterpriseAuthSmokeSnapshot["provided"]); parsed=$($enterpriseAuthSmokeSnapshot["parsed"]); result=$($enterpriseAuthSmokeSnapshot["result"]); pass=$($enterpriseAuthSmokeSnapshot["passCount"]); fail=$($enterpriseAuthSmokeSnapshot["failCount"]); blocked=$($enterpriseAuthSmokeSnapshot["blockedCount"]); scopeOutAccepted=$($enterpriseAuthSmokeSnapshot["scopeOutAccepted"])"
$markdownLines += "- Enterprise auth JIT rollback: required=$enterpriseAuthJitRollbackSnapshotRequired; provided=$($enterpriseAuthJitRollbackSnapshot["provided"]); parsed=$($enterpriseAuthJitRollbackSnapshot["parsed"]); result=$($enterpriseAuthJitRollbackSnapshot["result"]); failures=$($enterpriseAuthJitRollbackSnapshot["failureCount"]); checks=$($enterpriseAuthJitRollbackSnapshot["checkCount"]); smokeResult=$($enterpriseAuthJitRollbackSnapshot["enterpriseAuthSmokeSnapshot"]["result"]); confirmationsValid=$($enterpriseAuthJitRollbackSnapshot["confirmationsValid"])"
$markdownLines += "- Monitoring threshold: provided=$($monitoringThresholdSnapshot["provided"]); parsed=$($monitoringThresholdSnapshot["parsed"]); result=$($monitoringThresholdSnapshot["result"]); alerts=$($monitoringThresholdSnapshot["mappedAlertCount"])/$($monitoringThresholdSnapshot["requiredAlertCount"]); routes=$($monitoringThresholdSnapshot["routeCount"]); failures=$($monitoringThresholdSnapshot["failureCount"]); mappingComplete=$($monitoringThresholdSnapshot["thresholdMappingComplete"]); complete=$($monitoringThresholdSnapshot["complete"])"
$markdownLines += "- Cluster network access review: provided=$($clusterNetworkAccessReviewSnapshot["provided"]); parsed=$($clusterNetworkAccessReviewSnapshot["parsed"]); result=$($clusterNetworkAccessReviewSnapshot["result"]); failures=$($clusterNetworkAccessReviewSnapshot["failureCount"]); checks=$($clusterNetworkAccessReviewSnapshot["totalCount"]); staticControlsValid=$($clusterNetworkAccessReviewSnapshot["staticControlsValid"]); confirmationsValid=$($clusterNetworkAccessReviewSnapshot["confirmationsValid"])"
$markdownLines += "- Helm values hardening: provided=$($helmValuesHardeningSnapshot["provided"]); parsed=$($helmValuesHardeningSnapshot["parsed"]); result=$($helmValuesHardeningSnapshot["result"]); failures=$($helmValuesHardeningSnapshot["failureCount"]); checks=$($helmValuesHardeningSnapshot["totalCount"]); chartFiles=$($helmValuesHardeningSnapshot["chartFileCount"]); staticHardeningValid=$($helmValuesHardeningSnapshot["staticHardeningValid"]); confirmationsValid=$($helmValuesHardeningSnapshot["confirmationsValid"])"
foreach ($pendingCheck in @($dataFlowStoragePlanSnapshot["topPendingChecks"])) {
    $markdownLines += "- Data-flow pending: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.title): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($dataFlowQueryRetentionBudgetSnapshot["topFailedChecks"])) {
    $markdownLines += "- Data-flow query/retention budget failed: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
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
foreach ($pendingCheck in @($chargebackCloseoutSnapshot["topChecks"])) {
    $markdownLines += "- Chargeback closeout pending: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($enterpriseAuthSmokeSnapshot["topChecks"])) {
    $markdownLines += "- Enterprise auth pending: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($enterpriseAuthJitRollbackSnapshot["topChecks"])) {
    $markdownLines += "- Enterprise auth JIT rollback failed: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($monitoringThresholdSnapshot["topFailedChecks"])) {
    $markdownLines += "- Monitoring threshold failed: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($clusterNetworkAccessReviewSnapshot["topChecks"])) {
    $markdownLines += "- Cluster network access review failed: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
}
foreach ($pendingCheck in @($helmValuesHardeningSnapshot["topChecks"])) {
    $markdownLines += "- Helm values hardening failed: [$($pendingCheck.status)] $($pendingCheck.id) / $($pendingCheck.name): $($pendingCheck.detail)"
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
$markdownLines += "- Record passed target package: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-handoff-package.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -HandoffStartedAt <iso-time> -HandoffCompletedAt <iso-time> -ChangeApprovalRef <change-id> -DeploymentEvidenceRef <ref> -OperationsReadinessRef <ref> -OperationsConvergenceRef <ref> -DataFlowStoragePlanEvidenceRef <ref> -DataFlowQueryRetentionBudgetEvidenceRef <ref> -DataFlowStorageTransitionRunbookEvidenceRef <ref> -OperationsReadinessJsonPath .\.osmu-run\latest-operations-readiness.json -OperationsConvergenceJsonPath .\.osmu-run\latest-operations-readiness-convergence.json -DataFlowStoragePlanJsonPath .\.osmu-run\latest-data-flow-storage-plan.json -DataFlowQueryRetentionBudgetJsonPath .\.osmu-run\latest-data-flow-query-retention-budget-evidence.json -DataFlowStorageTransitionRunbookJsonPath .\.osmu-run\latest-data-flow-storage-transition-runbook-evidence.json -SecretRotationEvidenceRef <ref> -SecretRotationJsonPath .\.osmu-run\latest-secret-rotation-evidence.json -CommercialIntegrationEvidenceRef <ref> -CommercialApprovalEvidenceRef <ref> -ChargebackCloseoutEvidenceRef <ref> -CommercialIntegrationJsonPath .\.osmu-run\latest-commercial-integration-evidence.json -CommercialApprovalJsonPath .\.osmu-run\latest-commercial-approval-evidence.json -ChargebackCloseoutJsonPath .\.osmu-run\latest-chargeback-closeout-evidence.json -EnterpriseAuthEvidenceRef <ref> -EnterpriseAuthJsonPath .\.osmu-run\latest-enterprise-auth-smoke.json -EnterpriseAuthJitRollbackEvidenceRef <ref> -EnterpriseAuthJitRollbackJsonPath .\.osmu-run\latest-enterprise-auth-jit-rollback-evidence.json -BackupRestoreEvidenceRef <ref> -HaDrEvidenceRef <ref> -MonitoringEvidenceRef <ref> -MonitoringThresholdJsonPath .\.osmu-run\latest-monitoring-threshold-evidence.json -ClusterNetworkAccessReviewEvidenceRef <ref> -ClusterNetworkAccessReviewJsonPath .\.osmu-run\latest-cluster-network-access-review-evidence.json -HelmValuesHardeningEvidenceRef <ref> -HelmValuesHardeningJsonPath .\.osmu-run\latest-helm-values-hardening-evidence.json -SecurityEvidenceRef <ref> -IamRbacEvidenceRef <ref> -RunbookReviewRef <ref> -TroubleshootingReviewRef <ref> -SupportEscalationRef <ref> -SupportSlaRef <ref> -KnownGapsRef <ref> -ConfirmRunbookReviewed -ConfirmTroubleshootingReviewed -ConfirmRollbackReviewed -ConfirmSupportEscalationReviewed -ConfirmKnownGapsAccepted -ConfirmOperationsReadinessSnapshotReviewed -ConfirmOperationsConvergenceSnapshotReviewed -ConfirmDataFlowStoragePlanReviewed -ConfirmDataFlowQueryRetentionBudgetReviewed -ConfirmDataFlowStorageTransitionRunbookReviewed -ConfirmSecretRotationSnapshotReviewed -ConfirmCommercialIntegrationSnapshotReviewed -ConfirmCommercialApprovalSnapshotReviewed -ConfirmChargebackCloseoutSnapshotReviewed -ConfirmEnterpriseAuthSmokeSnapshotReviewed -ConfirmEnterpriseAuthJitRollbackSnapshotReviewed -ConfirmMonitoringThresholdReviewed -ConfirmClusterNetworkAccessReviewReviewed -ConfirmHelmValuesHardeningReviewed -ConfirmNoSecretValues -RequireProductionEvidence -RequireOperationsSnapshotEvidence -FailIfNotPassed``"

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
