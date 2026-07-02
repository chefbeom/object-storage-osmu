param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $BillingPeriod = "",
    [string] $CloseoutStartedAt = "",
    [string] $CloseoutCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $PricingPolicyEvidenceRef = "",
    [string] $PricingProposalApprovalRef = "",
    [string] $ChargebackPreviewEvidenceRef = "",
    [string] $ChargebackTrendExportEvidenceRef = "",
    [string] $InvoiceDraftEvidenceRef = "",
    [string] $InvoiceFinalizationEvidenceRef = "",
    [string] $PaymentRequestEvidenceRef = "",
    [string] $PaymentProviderHandoffEvidenceRef = "",
    [string] $PaymentProviderAdapterReadinessEvidenceRef = "",
    [string] $PaymentProviderAdapterReadinessJsonPath = "",
    [string] $NotificationDeliveryEvidenceRef = "",
    [string] $AdapterRetryWorkerEvidenceRef = "",
    [string] $ReconciliationEvidenceRef = "",
    [string] $CommercialIntegrationEvidenceRef = "",
    [string] $CommercialApprovalEvidenceRef = "",
    [string] $ChargebackCloseoutSnapshotJsonPath = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-chargeback-closeout-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-chargeback-closeout-evidence.md",
    [switch] $ConfirmPricingPolicyReviewed,
    [switch] $ConfirmPriceListApproved,
    [switch] $ConfirmUsageWindowReviewed,
    [switch] $ConfirmChargebackPreviewReviewed,
    [switch] $ConfirmTrendExportReviewed,
    [switch] $ConfirmInvoiceDraftReviewed,
    [switch] $ConfirmInvoiceFinalized,
    [switch] $ConfirmPaymentRequestReviewed,
    [switch] $ConfirmPaymentProviderHandoffReviewed,
    [switch] $ConfirmPaymentProviderAdapterReadinessReviewed,
    [switch] $ConfirmNotificationDeliveryReviewed,
    [switch] $ConfirmAdapterRetryReviewed,
    [switch] $ConfirmReconciliationReviewed,
    [switch] $ConfirmCommercialIntegrationReviewed,
    [switch] $ConfirmCommercialApprovalReviewed,
    [switch] $ConfirmNoRawCustomerPaymentData,
    [switch] $ConfirmNoRawProviderResponses,
    [switch] $ConfirmNoSecretValues,
    [switch] $RequirePaymentProviderAdapterReadinessSnapshot,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return [System.IO.Path]::GetFullPath($PathValue) }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}
function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
}

function Assert-SafeText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "(?i)\b(password|passwd|secret|token|client_secret|x-amz-security-token|smtp_pass|webhook_secret|api_key|apikey)\s*[=:]\s*\S+"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) { throw "$Label appears to contain credential material. Store only an external evidence reference." }
    }
}

function Assert-SanitizedJsonText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $forbiddenPropertyPattern = '(?i)"(rawProviderResponse|raw_provider_response|providerResponse|provider_response|responseBody|response_body|responseHeaders|response_headers|webhookUrl|webhook_url|endpointUrl|endpoint_url|callbackUrl|callback_url|customerData|customer_data|customerEmail|customer_email|customerName|customer_name|customerPaymentData|customer_payment_data|paymentCard|payment_card|cardNumber|card_number|pan|bankAccount|bank_account|routingNumber|routing_number|taxId|tax_id|paymentTargetAccount|payment_target_account|rawPriceTable|raw_price_table|priceTable|price_table|rawInvoice|raw_invoice|invoicePdf|invoice_pdf|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:'
    if ($Value -match $forbiddenPropertyPattern) { throw "$Label appears to contain raw customer/payment/provider data or credential-shaped fields. Store only sanitized status/count metadata." }
    Assert-SafeText $Value $Label
}

function Read-SanitizedJson([string] $PathValue, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return [pscustomobject]@{ provided = $false; parsed = $false; data = $null; detail = "No $Label JSON path supplied." }
    }
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) { throw "$Label JSON missing: $resolved" }
    $raw = Read-Utf8Text $resolved
    Assert-SanitizedJsonText $raw $Label
    try {
        return [pscustomobject]@{ provided = $true; parsed = $true; path = $resolved; data = ($raw | ConvertFrom-Json); detail = "Parsed $Label JSON." }
    }
    catch { throw "$Label JSON could not be parsed: $resolved. $($_.Exception.Message)" }
}

function Get-PropertyValue([object] $Object, [string] $Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-PropertyText([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) { return "" }
    return [string] $value
}

function Get-RequiredPropertyInt([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) { return [pscustomobject]@{ value = 0; valid = $false; raw = "<missing>" } }
    if ($value -is [byte] -or $value -is [int16] -or $value -is [int32] -or $value -is [int64]) {
        return [pscustomobject]@{ value = [int64] $value; valid = $true; raw = [string] $value }
    }
    return [pscustomobject]@{ value = 0; valid = $false; raw = [string] $value }
}

function Get-RequiredPropertyBool([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) { return [pscustomobject]@{ value = $false; valid = $false; raw = "<missing>" } }
    if ($value -is [bool]) { return [pscustomobject]@{ value = [bool] $value; valid = $true; raw = [string] $value } }
    return [pscustomobject]@{ value = $false; valid = $false; raw = [string] $value }
}

function Get-SnapshotData([object] $Snapshot) {
    $data = Get-PropertyValue $Snapshot "data"
    if ($null -ne $data) { return $data }
    return $Snapshot
}

function Get-ArrayProperty([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) { return @() }
    return @($value)
}

function Test-DateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse($Value, [ref] $parsed)
}

function Get-ParsedDateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($Value, [ref] $parsed)) { return $parsed }
    return $null
}

function Test-StatusClosed([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return @("PASSED", "CLOSED", "COMPLETE", "COMPLETED", "RECONCILED") -contains $Value.Trim().ToUpperInvariant()
}

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail) {
    return [pscustomobject][ordered]@{ id = $Id; name = $Name; status = $Status; passed = ($Status -eq "PASS"); detail = $Detail }
}

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail) {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    [void] $script:checks.Add((New-Check $Id $Name $status $Detail))
}

function Add-PlannedCheck([string] $Id, [string] $Name, [string] $Detail) {
    [void] $script:checks.Add((New-Check $Id $Name "PLANNED" $Detail))
}

function Convert-SafeProfile([object] $Profile) {
    $webhookReady = Get-RequiredPropertyBool $Profile "webhookProfileConfigured"
    $nativeSupported = Get-RequiredPropertyBool $Profile "nativeApiSupported"
    $nativeReady = Get-RequiredPropertyBool $Profile "nativeApiReady"
    return [pscustomobject][ordered]@{
        providerProfile = (Get-PropertyText $Profile "providerProfile")
        adapterMode = (Get-PropertyText $Profile "adapterMode")
        status = (Get-PropertyText $Profile "status")
        webhookProfileConfigured = $webhookReady.value
        webhookProfileConfiguredTyped = $webhookReady.valid
        nativeApiSupported = $nativeSupported.value
        nativeApiSupportedTyped = $nativeSupported.valid
        nativeApiReady = $nativeReady.value
        nativeApiReadyTyped = $nativeReady.valid
    }
}

function Parse-PaymentProviderAdapterReadinessSnapshot([string] $PathValue) {
    $readResult = Read-SanitizedJson $PathValue "Payment provider adapter readiness"
    if (-not $readResult.provided) { return [pscustomobject][ordered]@{ provided = $false; parsed = $false; valid = $false; detail = $readResult.detail; profiles = @() } }
    $data = Get-SnapshotData $readResult.data
    $profiles = @()
    foreach ($profile in (Get-ArrayProperty $data "profiles")) { $profiles += (Convert-SafeProfile $profile) }
    $expectedProfiles = @("GENERIC", "CARD", "BANK", "TAX", "ERP")
    $observedProfiles = @($profiles | ForEach-Object { ([string] $_.providerProfile).ToUpperInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $missingProfiles = @($expectedProfiles | Where-Object { $observedProfiles -notcontains $_ })
    $profileBooleansValid = (@($profiles | Where-Object { -not $_.webhookProfileConfiguredTyped -or -not $_.nativeApiSupportedTyped -or -not $_.nativeApiReadyTyped }).Count -eq 0)
    $profileCount = Get-RequiredPropertyInt $data "profileCount"
    $webhookReadyProfileCount = Get-RequiredPropertyInt $data "webhookReadyProfileCount"
    $nativeApiReadyProfileCount = Get-RequiredPropertyInt $data "nativeApiReadyProfileCount"
    $nativeApiSupported = Get-RequiredPropertyBool $data "nativeApiSupported"
    $nativeApiReady = Get-RequiredPropertyBool $data "nativeApiReady"
    $mode = Get-PropertyText $data "mode"
    $status = Get-PropertyText $data "status"
    $validMode = $mode -eq "PAYMENT_PROVIDER_ADAPTER_READINESS"
    $countsValid = $profileCount.valid -and $webhookReadyProfileCount.valid -and $nativeApiReadyProfileCount.valid
    $booleansValid = $nativeApiSupported.valid -and $nativeApiReady.valid -and $profileBooleansValid
    $coverageValid = $missingProfiles.Count -eq 0
    return [pscustomobject][ordered]@{
        provided = $true; parsed = $readResult.parsed; valid = ($readResult.parsed -and $validMode -and $countsValid -and $booleansValid -and $coverageValid); path = $readResult.path
        mode = $mode; status = $status; profileCount = $profileCount.value; webhookReadyProfileCount = $webhookReadyProfileCount.value; nativeApiReadyProfileCount = $nativeApiReadyProfileCount.value
        nativeApiSupported = $nativeApiSupported.value; nativeApiReady = $nativeApiReady.value; validMode = $validMode; countsValid = $countsValid; booleansValid = $booleansValid
        profileCoverageValid = $coverageValid; missingProfiles = $missingProfiles; profiles = @($profiles); detail = "mode=$mode; status=$status; profiles=$($observedProfiles -join ','); missing=$($missingProfiles -join ',')"
    }
}

function Parse-ChargebackCloseoutSnapshot([string] $PathValue) {
    $readResult = Read-SanitizedJson $PathValue "Chargeback closeout"
    if (-not $readResult.provided) { return [pscustomobject][ordered]@{ provided = $false; parsed = $false; valid = $false; detail = $readResult.detail } }
    $data = Get-SnapshotData $readResult.data
    $snapshotBillingPeriod = Get-PropertyText $data "billingPeriod"
    $resultText = Get-PropertyText $data "result"
    if ([string]::IsNullOrWhiteSpace($resultText)) { $resultText = Get-PropertyText $data "closeoutStatus" }
    $intNames = @("invoiceDraftCount", "finalInvoiceCount", "paymentRequestedCount", "paymentHandoffCount", "paidInvoiceCount", "reconciliationDifferenceMinorUnits", "failureCount", "blockerCount", "missingFinalInvoiceBlockerCount", "missingPaymentRequestBlockerCount", "unpaidInvoiceBlockerCount", "openHandoffBlockerCount", "openNotificationBlockerCount", "reconciliationBlockerCount")
    $counts = [ordered]@{}
    $intInvalid = 0
    foreach ($name in $intNames) {
        $parsed = Get-RequiredPropertyInt $data $name
        $counts[$name] = $parsed.value
        if (-not $parsed.valid) { $intInvalid++ }
    }
    $boolNames = @("closeoutReady", "invoiceFinalizationComplete", "paymentRequestsComplete", "paymentsSettled", "paymentHandoffsClosed", "notificationDeliveriesClosed", "reconciliationBalanced", "rawCustomerPaymentDataStored", "rawProviderResponseStored", "rawSecretValuesStored")
    $bools = [ordered]@{}
    $boolInvalid = 0
    foreach ($name in $boolNames) {
        $parsed = Get-RequiredPropertyBool $data $name
        $bools[$name] = $parsed.value
        if (-not $parsed.valid) { $boolInvalid++ }
    }
    $billingPeriodMatches = ([string]::IsNullOrWhiteSpace($BillingPeriod) -or $snapshotBillingPeriod -eq $BillingPeriod)
    $statusClosed = Test-StatusClosed $resultText
    $noRawDataStored = (-not $bools["rawCustomerPaymentDataStored"]) -and (-not $bools["rawProviderResponseStored"]) -and (-not $bools["rawSecretValuesStored"])
    $failureCountZero = $counts["failureCount"] -eq 0
    $blockerCountZero = $counts["blockerCount"] -eq 0
    $closeoutReady = [bool] $bools["closeoutReady"]
    $readinessBooleansClosed = ([bool] $bools["invoiceFinalizationComplete"]) -and ([bool] $bools["paymentRequestsComplete"]) -and ([bool] $bools["paymentsSettled"]) -and ([bool] $bools["paymentHandoffsClosed"]) -and ([bool] $bools["notificationDeliveriesClosed"]) -and ([bool] $bools["reconciliationBalanced"])
    $valid = $readResult.parsed -and (-not [string]::IsNullOrWhiteSpace($snapshotBillingPeriod)) -and $billingPeriodMatches -and $statusClosed -and ($intInvalid -eq 0) -and ($boolInvalid -eq 0) -and $noRawDataStored -and $failureCountZero -and $blockerCountZero -and $closeoutReady -and $readinessBooleansClosed
    return [pscustomobject][ordered]@{
        provided = $true; parsed = $readResult.parsed; valid = $valid; path = $readResult.path; billingPeriod = $snapshotBillingPeriod; result = $resultText
        statusClosed = $statusClosed; billingPeriodMatches = $billingPeriodMatches; integersValid = ($intInvalid -eq 0); booleansValid = ($boolInvalid -eq 0); failureCountZero = $failureCountZero; blockerCountZero = $blockerCountZero; closeoutReady = $closeoutReady; readinessBooleansClosed = $readinessBooleansClosed; noRawDataStored = $noRawDataStored
        counts = $counts; readinessFlags = $bools; rawDataFlags = $bools; detail = "result=$resultText; billingPeriod=$snapshotBillingPeriod; failures=$($counts['failureCount']); blockers=$($counts['blockerCount']); ready=$closeoutReady; reconciliationDifferenceMinorUnits=$($counts['reconciliationDifferenceMinorUnits'])"
    }
}

$safeFields = [ordered]@{
    EnvironmentName = $EnvironmentName; TargetCluster = $TargetCluster; Operator = $Operator; BillingPeriod = $BillingPeriod; ChangeApprovalRef = $ChangeApprovalRef
    PricingPolicyEvidenceRef = $PricingPolicyEvidenceRef; PricingProposalApprovalRef = $PricingProposalApprovalRef; ChargebackPreviewEvidenceRef = $ChargebackPreviewEvidenceRef; ChargebackTrendExportEvidenceRef = $ChargebackTrendExportEvidenceRef
    InvoiceDraftEvidenceRef = $InvoiceDraftEvidenceRef; InvoiceFinalizationEvidenceRef = $InvoiceFinalizationEvidenceRef; PaymentRequestEvidenceRef = $PaymentRequestEvidenceRef; PaymentProviderHandoffEvidenceRef = $PaymentProviderHandoffEvidenceRef
    PaymentProviderAdapterReadinessEvidenceRef = $PaymentProviderAdapterReadinessEvidenceRef; NotificationDeliveryEvidenceRef = $NotificationDeliveryEvidenceRef; AdapterRetryWorkerEvidenceRef = $AdapterRetryWorkerEvidenceRef; ReconciliationEvidenceRef = $ReconciliationEvidenceRef
    CommercialIntegrationEvidenceRef = $CommercialIntegrationEvidenceRef; CommercialApprovalEvidenceRef = $CommercialApprovalEvidenceRef
}
foreach ($entry in $safeFields.GetEnumerator()) { Assert-SafeText ([string] $entry.Value) $entry.Key }
Assert-SafeText $CloseoutStartedAt "CloseoutStartedAt"
Assert-SafeText $CloseoutCompletedAt "CloseoutCompletedAt"

$switches = @($ConfirmPricingPolicyReviewed, $ConfirmPriceListApproved, $ConfirmUsageWindowReviewed, $ConfirmChargebackPreviewReviewed, $ConfirmTrendExportReviewed, $ConfirmInvoiceDraftReviewed, $ConfirmInvoiceFinalized, $ConfirmPaymentRequestReviewed, $ConfirmPaymentProviderHandoffReviewed, $ConfirmPaymentProviderAdapterReadinessReviewed, $ConfirmNotificationDeliveryReviewed, $ConfirmAdapterRetryReviewed, $ConfirmReconciliationReviewed, $ConfirmCommercialIntegrationReviewed, $ConfirmCommercialApprovalReviewed, $ConfirmNoRawCustomerPaymentData, $ConfirmNoRawProviderResponses, $ConfirmNoSecretValues)
$hasSwitchInput = (@($switches | Where-Object { [bool] $_ }).Count -gt 0)
$hasReferenceInput = (@($safeFields.GetEnumerator() | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_.Value) }).Count -gt 0)
$hasSnapshotInput = (-not [string]::IsNullOrWhiteSpace($ChargebackCloseoutSnapshotJsonPath)) -or (-not [string]::IsNullOrWhiteSpace($PaymentProviderAdapterReadinessJsonPath))
$hasTargetInput = $hasReferenceInput -or $hasSwitchInput -or $hasSnapshotInput -or (-not [string]::IsNullOrWhiteSpace($CloseoutStartedAt)) -or (-not [string]::IsNullOrWhiteSpace($CloseoutCompletedAt))

$paymentSnapshot = Parse-PaymentProviderAdapterReadinessSnapshot $PaymentProviderAdapterReadinessJsonPath
$closeoutSnapshot = Parse-ChargebackCloseoutSnapshot $ChargebackCloseoutSnapshotJsonPath
$closeoutSnapshotBlockerCount = $null
if ($null -ne $closeoutSnapshot.counts) { $closeoutSnapshotBlockerCount = $closeoutSnapshot.counts["blockerCount"] }

if (-not $hasTargetInput) {
    Add-PlannedCheck "target-closeout-planned" "Target chargeback closeout evidence planned" "Run this writer after a target billing period has been closed."
    Add-PlannedCheck "closeout-snapshot-planned" "Sanitized closeout snapshot planned" "Provide ChargebackCloseoutSnapshotJsonPath from a reduced target closeout summary."
    Add-PlannedCheck "commercial-evidence-planned" "Commercial evidence review planned" "Provide commercial integration and approval evidence refs during target closeout."
}
else {
    Add-Check "target-metadata" "Target metadata is complete" ((-not [string]::IsNullOrWhiteSpace($EnvironmentName)) -and (-not [string]::IsNullOrWhiteSpace($TargetCluster)) -and (-not [string]::IsNullOrWhiteSpace($Operator)) -and (-not [string]::IsNullOrWhiteSpace($BillingPeriod))) "environment=$EnvironmentName; cluster=$TargetCluster; operator=$Operator; billingPeriod=$BillingPeriod"
    Add-Check "change-approval-ref" "Change approval reference is recorded" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "changeApprovalRef=$ChangeApprovalRef"
    $started = Get-ParsedDateText $CloseoutStartedAt
    $completed = Get-ParsedDateText $CloseoutCompletedAt
    Add-Check "closeout-started-at-valid" "CloseoutStartedAt is parseable" ($null -ne $started) "CloseoutStartedAt=$CloseoutStartedAt"
    Add-Check "closeout-completed-at-valid" "CloseoutCompletedAt is parseable" ($null -ne $completed) "CloseoutCompletedAt=$CloseoutCompletedAt"
    Add-Check "closeout-window-order" "Closeout window is chronological" (($null -ne $started) -and ($null -ne $completed) -and ($completed -ge $started)) "started=$CloseoutStartedAt completed=$CloseoutCompletedAt"
    $requiredReferences = [ordered]@{
        "pricing-policy" = $PricingPolicyEvidenceRef; "pricing-proposal-approval" = $PricingProposalApprovalRef; "chargeback-preview" = $ChargebackPreviewEvidenceRef; "chargeback-trend-export" = $ChargebackTrendExportEvidenceRef
        "invoice-draft" = $InvoiceDraftEvidenceRef; "invoice-finalization" = $InvoiceFinalizationEvidenceRef; "payment-request" = $PaymentRequestEvidenceRef; "payment-provider-handoff" = $PaymentProviderHandoffEvidenceRef
        "payment-provider-adapter-readiness" = $PaymentProviderAdapterReadinessEvidenceRef; "notification-delivery" = $NotificationDeliveryEvidenceRef; "adapter-retry-worker" = $AdapterRetryWorkerEvidenceRef; "reconciliation" = $ReconciliationEvidenceRef
        "commercial-integration" = $CommercialIntegrationEvidenceRef; "commercial-approval" = $CommercialApprovalEvidenceRef
    }
    foreach ($entry in $requiredReferences.GetEnumerator()) { Add-Check "evidence-ref-$($entry.Key)" "Evidence reference recorded: $($entry.Key)" (-not [string]::IsNullOrWhiteSpace([string] $entry.Value)) "ref=$($entry.Value)" }
    $confirmationChecks = @(
        @{ id = "pricing-policy-reviewed"; name = "Pricing policy reviewed"; value = [bool] $ConfirmPricingPolicyReviewed }, @{ id = "price-list-approved"; name = "Commercial price list approval reviewed"; value = [bool] $ConfirmPriceListApproved },
        @{ id = "usage-window-reviewed"; name = "Usage window reviewed"; value = [bool] $ConfirmUsageWindowReviewed }, @{ id = "chargeback-preview-reviewed"; name = "Chargeback preview reviewed"; value = [bool] $ConfirmChargebackPreviewReviewed },
        @{ id = "trend-export-reviewed"; name = "Chargeback trend export reviewed"; value = [bool] $ConfirmTrendExportReviewed }, @{ id = "invoice-draft-reviewed"; name = "Invoice draft reviewed"; value = [bool] $ConfirmInvoiceDraftReviewed },
        @{ id = "invoice-finalized"; name = "Final invoice state reviewed"; value = [bool] $ConfirmInvoiceFinalized }, @{ id = "payment-request-reviewed"; name = "Payment request reviewed"; value = [bool] $ConfirmPaymentRequestReviewed },
        @{ id = "payment-provider-handoff-reviewed"; name = "Payment provider handoff reviewed"; value = [bool] $ConfirmPaymentProviderHandoffReviewed }, @{ id = "payment-provider-adapter-readiness-reviewed"; name = "Payment provider adapter readiness reviewed"; value = [bool] $ConfirmPaymentProviderAdapterReadinessReviewed },
        @{ id = "notification-delivery-reviewed"; name = "Notification delivery reviewed"; value = [bool] $ConfirmNotificationDeliveryReviewed }, @{ id = "adapter-retry-reviewed"; name = "Adapter retry worker reviewed"; value = [bool] $ConfirmAdapterRetryReviewed },
        @{ id = "reconciliation-reviewed"; name = "Reconciliation reviewed"; value = [bool] $ConfirmReconciliationReviewed }, @{ id = "commercial-integration-reviewed"; name = "Commercial integration evidence reviewed"; value = [bool] $ConfirmCommercialIntegrationReviewed },
        @{ id = "commercial-approval-reviewed"; name = "Commercial approval evidence reviewed"; value = [bool] $ConfirmCommercialApprovalReviewed }, @{ id = "no-raw-customer-payment-data"; name = "No raw customer/payment data stored"; value = [bool] $ConfirmNoRawCustomerPaymentData },
        @{ id = "no-raw-provider-responses"; name = "No raw provider responses stored"; value = [bool] $ConfirmNoRawProviderResponses }, @{ id = "no-secret-values"; name = "No secret values stored"; value = [bool] $ConfirmNoSecretValues }
    )
    foreach ($confirmation in $confirmationChecks) { Add-Check $confirmation.id $confirmation.name $confirmation.value "confirmed=$($confirmation.value)" }
    Add-Check "chargeback-closeout-snapshot-present" "Sanitized chargeback closeout snapshot is supplied" $closeoutSnapshot.provided $closeoutSnapshot.detail
    Add-Check "chargeback-closeout-snapshot-valid" "Sanitized chargeback closeout snapshot is valid" $closeoutSnapshot.valid $closeoutSnapshot.detail
    if ($RequirePaymentProviderAdapterReadinessSnapshot -or $paymentSnapshot.provided) { Add-Check "payment-provider-adapter-readiness-snapshot-valid" "Payment-provider adapter readiness snapshot is valid" $paymentSnapshot.valid $paymentSnapshot.detail }
}

$failedCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$plannedCount = @($checks | Where-Object { $_.status -eq "PLANNED" }).Count
$passCount = @($checks | Where-Object { $_.status -eq "PASS" }).Count
$result = "planned"
if ($hasTargetInput) { if ($failedCount -eq 0 -and $plannedCount -eq 0) { $result = "passed" } else { $result = "failed" } }

$evidenceRefs = [ordered]@{
    pricingPolicy = $PricingPolicyEvidenceRef; pricingProposalApproval = $PricingProposalApprovalRef; chargebackPreview = $ChargebackPreviewEvidenceRef; chargebackTrendExport = $ChargebackTrendExportEvidenceRef
    invoiceDraft = $InvoiceDraftEvidenceRef; invoiceFinalization = $InvoiceFinalizationEvidenceRef; paymentRequest = $PaymentRequestEvidenceRef; paymentProviderHandoff = $PaymentProviderHandoffEvidenceRef
    paymentProviderAdapterReadiness = $PaymentProviderAdapterReadinessEvidenceRef; notificationDelivery = $NotificationDeliveryEvidenceRef; adapterRetryWorker = $AdapterRetryWorkerEvidenceRef; reconciliation = $ReconciliationEvidenceRef
    commercialIntegration = $CommercialIntegrationEvidenceRef; commercialApproval = $CommercialApprovalEvidenceRef
}
$providedEvidenceRefs = @($evidenceRefs.GetEnumerator() | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_.Value) }).Count
$confirmations = [ordered]@{
    pricingPolicyReviewed = [bool] $ConfirmPricingPolicyReviewed; priceListApproved = [bool] $ConfirmPriceListApproved; usageWindowReviewed = [bool] $ConfirmUsageWindowReviewed; chargebackPreviewReviewed = [bool] $ConfirmChargebackPreviewReviewed
    trendExportReviewed = [bool] $ConfirmTrendExportReviewed; invoiceDraftReviewed = [bool] $ConfirmInvoiceDraftReviewed; invoiceFinalized = [bool] $ConfirmInvoiceFinalized; paymentRequestReviewed = [bool] $ConfirmPaymentRequestReviewed
    paymentProviderHandoffReviewed = [bool] $ConfirmPaymentProviderHandoffReviewed; paymentProviderAdapterReadinessReviewed = [bool] $ConfirmPaymentProviderAdapterReadinessReviewed; notificationDeliveryReviewed = [bool] $ConfirmNotificationDeliveryReviewed
    adapterRetryReviewed = [bool] $ConfirmAdapterRetryReviewed; reconciliationReviewed = [bool] $ConfirmReconciliationReviewed; commercialIntegrationReviewed = [bool] $ConfirmCommercialIntegrationReviewed; commercialApprovalReviewed = [bool] $ConfirmCommercialApprovalReviewed
    noRawCustomerPaymentData = [bool] $ConfirmNoRawCustomerPaymentData; noRawProviderResponses = [bool] $ConfirmNoRawProviderResponses; noSecretValues = [bool] $ConfirmNoSecretValues; requirePaymentProviderAdapterReadinessSnapshot = [bool] $RequirePaymentProviderAdapterReadinessSnapshot
}
$targetInfo = [pscustomobject][ordered]@{
    environmentName = $EnvironmentName
    targetCluster = $TargetCluster
    operator = $Operator
    billingPeriod = $BillingPeriod
    closeoutStartedAt = $CloseoutStartedAt
    closeoutCompletedAt = $CloseoutCompletedAt
    changeApprovalRef = $ChangeApprovalRef
}
$summaryInfo = [pscustomobject][ordered]@{
    checkCount = $checks.Count
    passCount = $passCount
    failureCount = $failedCount
    plannedCount = $plannedCount
    requiredEvidenceRefCount = $evidenceRefs.Count
    providedEvidenceRefCount = $providedEvidenceRefs
    chargebackCloseoutSnapshotValid = $closeoutSnapshot.valid
    chargebackCloseoutSnapshotReady = $closeoutSnapshot.closeoutReady
    chargebackCloseoutSnapshotBlockerCount = $closeoutSnapshotBlockerCount
    paymentProviderAdapterReadinessSnapshotValid = $paymentSnapshot.valid
    paymentProviderAdapterReadinessReviewed = [bool] $ConfirmPaymentProviderAdapterReadinessReviewed
    commercialEvidenceReviewed = (([bool] $ConfirmCommercialIntegrationReviewed) -and ([bool] $ConfirmCommercialApprovalReviewed))
}
$decisionRule = "Production/B2B chargeback closeout readiness requires result=passed from the target environment after pricing policy/proposal, usage window, preview/trend exports, draft/final invoice, payment request, payment-provider handoff, notification delivery, adapter retry, reconciliation, commercial integration, and commercial approval evidence are all reviewed; the sanitized closeout snapshot must be typed, closeoutReady=true, blockerCount=0, reconciled, and free of raw customer/payment/provider data."
$scopePolicy = "OSMU tenant billing/chargeback closeout evidence only. This proves internal chargeback and handoff readiness for the target billing period, including sanitized payment-provider adapter/native-bridge readiness; it does not claim vendor-specific fixed SDK/schema card, bank, tax, ERP, or external payment processor implementation."
$secretPolicy = "Evidence stores target labels, timestamps, external references, booleans, typed counts, and reduced readiness metadata only; it must not contain passwords, bearer tokens, private keys, endpoint URLs with credentials, raw customer data, raw payment data, raw price tables, invoices, contracts, provider responses, or provider credentials."
$report = New-Object psobject
$report | Add-Member -NotePropertyName formatVersion -NotePropertyValue "osmu.chargeback-closeout-evidence.v1"
$report | Add-Member -NotePropertyName generatedAt -NotePropertyValue ([DateTimeOffset]::UtcNow.ToString("o"))
$report | Add-Member -NotePropertyName result -NotePropertyValue $result
$report | Add-Member -NotePropertyName target -NotePropertyValue $targetInfo
$report | Add-Member -NotePropertyName summary -NotePropertyValue $summaryInfo
$report | Add-Member -NotePropertyName evidenceRefs -NotePropertyValue $evidenceRefs
$report | Add-Member -NotePropertyName confirmations -NotePropertyValue $confirmations
$report | Add-Member -NotePropertyName chargebackCloseoutSnapshot -NotePropertyValue $closeoutSnapshot
$report | Add-Member -NotePropertyName paymentProviderAdapterReadiness -NotePropertyValue $paymentSnapshot
$checkList = New-Object System.Collections.ArrayList
foreach ($check in $checks) { [void] $checkList.Add($check) }
$report | Add-Member -NotePropertyName checks -NotePropertyValue $checkList
$report | Add-Member -NotePropertyName decisionRule -NotePropertyValue $decisionRule
$report | Add-Member -NotePropertyName scopePolicy -NotePropertyValue $scopePolicy
$report | Add-Member -NotePropertyName secretPolicy -NotePropertyValue $secretPolicy
$markdownLines = @(
    "# OSMU Chargeback Closeout Evidence", "", "- Result: ``$result``", "- Environment: ``$EnvironmentName``", "- Cluster: ``$TargetCluster``", "- Operator: ``$Operator``", "- Billing period: ``$BillingPeriod``", "- Closeout window: ``$CloseoutStartedAt`` to ``$CloseoutCompletedAt``", "- Checks: pass=$passCount fail=$failedCount planned=$plannedCount total=$($checks.Count)", "- Evidence refs: provided=$providedEvidenceRefs required=$($evidenceRefs.Count)", "- Chargeback closeout snapshot: provided=$($closeoutSnapshot.provided) valid=$($closeoutSnapshot.valid) detail=$($closeoutSnapshot.detail)", "- Payment-provider adapter readiness snapshot: provided=$($paymentSnapshot.provided) valid=$($paymentSnapshot.valid) detail=$($paymentSnapshot.detail)", "", "## Scope Policy", "", $report.scopePolicy, "", "## Secret Policy", "", $report.secretPolicy, "", "## Decision Rule", "", $report.decisionRule, "", "## Checks", ""
)
foreach ($check in $checks) { $markdownLines += "- [$($check.status)] $($check.id): $($check.detail)" }
$markdownLines += @("", "## Record Passed Target Evidence", "", "- Record passed target evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-chargeback-closeout-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -BillingPeriod <yyyy-mm> -CloseoutStartedAt <iso-time> -CloseoutCompletedAt <iso-time> -ChangeApprovalRef <change-id> -PricingPolicyEvidenceRef <ref> -PricingProposalApprovalRef <ref> -ChargebackPreviewEvidenceRef <ref> -ChargebackTrendExportEvidenceRef <ref> -InvoiceDraftEvidenceRef <ref> -InvoiceFinalizationEvidenceRef <ref> -PaymentRequestEvidenceRef <ref> -PaymentProviderHandoffEvidenceRef <ref> -PaymentProviderAdapterReadinessEvidenceRef <ref> -NotificationDeliveryEvidenceRef <ref> -AdapterRetryWorkerEvidenceRef <ref> -ReconciliationEvidenceRef <ref> -CommercialIntegrationEvidenceRef <ref> -CommercialApprovalEvidenceRef <ref> -ChargebackCloseoutSnapshotJsonPath .\.osmu-run\chargeback-closeout-summary.json -ConfirmPricingPolicyReviewed -ConfirmPriceListApproved -ConfirmUsageWindowReviewed -ConfirmChargebackPreviewReviewed -ConfirmTrendExportReviewed -ConfirmInvoiceDraftReviewed -ConfirmInvoiceFinalized -ConfirmPaymentRequestReviewed -ConfirmPaymentProviderHandoffReviewed -ConfirmPaymentProviderAdapterReadinessReviewed -ConfirmNotificationDeliveryReviewed -ConfirmAdapterRetryReviewed -ConfirmReconciliationReviewed -ConfirmCommercialIntegrationReviewed -ConfirmCommercialApprovalReviewed -ConfirmNoRawCustomerPaymentData -ConfirmNoRawProviderResponses -ConfirmNoSecretValues -FailIfNotPassed``")

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    $markdownLines | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Chargeback closeout evidence JSON: $resolvedJsonOutputPath"
    Write-Host "Chargeback closeout evidence Markdown: $resolvedMarkdownOutputPath"
}
Write-Host "Chargeback closeout evidence result: $result"
Write-Host "Checks: pass=$passCount fail=$failedCount planned=$plannedCount total=$($checks.Count)"
if ($FailIfNotPassed -and $result -ne "passed") { throw "Chargeback closeout evidence result is $result, expected passed." }