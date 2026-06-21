param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $VerificationStartedAt = "",
    [string] $VerificationCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $NotificationWebhookEvidenceRef = "",
    [string] $SlackWebhookEvidenceRef = "",
    [string] $EmailSmtpEvidenceRef = "",
    [string] $PaymentGenericWebhookEvidenceRef = "",
    [string] $PaymentCardProfileEvidenceRef = "",
    [string] $PaymentBankProfileEvidenceRef = "",
    [string] $PaymentTaxProfileEvidenceRef = "",
    [string] $PaymentErpProfileEvidenceRef = "",
    [string] $PaymentProviderAdapterReadinessEvidenceRef = "",
    [string] $PaymentProviderAdapterReadinessJsonPath = "",
    [string] $AdapterRetryWorkerEvidenceRef = "",
    [string] $PayloadReviewEvidenceRef = "",
    [string] $PrivateNetworkBlockEvidenceRef = "",
    [string] $HmacSignatureEvidenceRef = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-commercial-integration-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-commercial-integration-evidence.md",
    [switch] $VerifiedNotificationWebhook,
    [switch] $VerifiedSlackWebhook,
    [switch] $VerifiedEmailSmtp,
    [switch] $VerifiedPaymentGenericWebhook,
    [switch] $VerifiedPaymentCardProfile,
    [switch] $VerifiedPaymentBankProfile,
    [switch] $VerifiedPaymentTaxProfile,
    [switch] $VerifiedPaymentErpProfile,
    [switch] $ConfirmAdapterRetryWorkerRun,
    [switch] $ConfirmPayloadSizeCaps,
    [switch] $ConfirmPrivateNetworkBlocking,
    [switch] $ConfirmHmacSignatureHeaders,
    [switch] $ConfirmPaymentProviderAdapterReadinessReviewed,
    [switch] $ConfirmNoSecretValues,
    [switch] $ConfirmNoRawProviderResponses,
    [switch] $RequireNotificationWebhook,
    [switch] $RequireSlackWebhook,
    [switch] $RequireEmailSmtp,
    [switch] $RequirePaymentGenericWebhook,
    [switch] $RequirePaymentCardProfile,
    [switch] $RequirePaymentBankProfile,
    [switch] $RequirePaymentTaxProfile,
    [switch] $RequirePaymentErpProfile,
    [switch] $RequirePaymentProviderAdapterReadinessReview,
    [switch] $RequireAllImplementedAdapters,
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
        "(?i)\b(password|passwd|secret|token|client_secret|x-amz-security-token|smtp_pass|webhook_secret)\s*[=:]\s*\S+"
    )

    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain credential material. Store only an external evidence reference."
        }
    }
}

function Assert-SafeReference([string] $Value, [string] $Label) {
    Assert-SafeText $Value $Label
}

function Assert-SanitizedPaymentProviderAdapterReadinessJson([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $forbiddenPropertyPattern = '(?i)"(rawProviderResponse|raw_provider_response|providerResponse|provider_response|responseBody|response_body|responseHeaders|response_headers|webhookUrl|webhook_url|endpointUrl|endpoint_url|callbackUrl|callback_url|customerPaymentData|customer_payment_data|customerEmail|customer_email|customerName|customer_name|cardNumber|card_number|pan|bankAccount|bank_account|routingNumber|routing_number|taxId|tax_id|paymentTargetAccount|payment_target_account)"\s*:'
    if ($Value -match $forbiddenPropertyPattern) {
        throw "PaymentProviderAdapterReadinessJson appears to contain raw provider response, endpoint URL, or customer payment data. Store only sanitized profile metadata."
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

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail) {
    return [ordered]@{
        id = $Id
        name = $Name
        status = $Status
        passed = $Status -eq "PASS"
        detail = $Detail
    }
}

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail) {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    [void] $script:checks.Add((New-Check $Id $Name $status $Detail))
}

function Add-PlannedCheck([string] $Id, [string] $Name, [string] $Detail) {
    [void] $script:checks.Add((New-Check $Id $Name "PLANNED" $Detail))
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

function Read-PaymentProviderAdapterReadinessSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        validMode = $false
        status = ""
        nativeApiSupported = $false
        nativeApiReady = $false
        profileCount = 0
        webhookReadyProfileCount = 0
        nativeApiReadyProfileCount = 0
        generatedAt = ""
        profiles = @()
        scopePolicy = ""
        secretPolicy = ""
        note = ""
        detail = "No payment-provider adapter readiness JSON supplied."
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $snapshot
    }

    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "Payment-provider adapter readiness JSON not found."
        return $snapshot
    }

    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    Assert-SafeText $raw "PaymentProviderAdapterReadinessJson"
    Assert-SanitizedPaymentProviderAdapterReadinessJson $raw
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $snapshot["detail"] = "Payment-provider adapter readiness JSON parse failed: $($_.Exception.Message)"
        return $snapshot
    }

    if ([string]::IsNullOrWhiteSpace((Get-PropertyText $payload "mode")) -and $null -ne (Get-PropertyValue $payload "data")) {
        $payload = Get-PropertyValue $payload "data"
    }

    $profiles = New-Object System.Collections.Generic.List[object]
    foreach ($profile in @(Get-PropertyArray $payload "profiles")) {
        [void] $profiles.Add([ordered]@{
            providerProfile = Get-PropertyText $profile "providerProfile"
            adapterMode = Get-PropertyText $profile "adapterMode"
            status = Get-PropertyText $profile "status"
            webhookProfileConfigured = Get-PropertyBool $profile "webhookProfileConfigured"
            nativeApiSupported = Get-PropertyBool $profile "nativeApiSupported"
            nativeApiReady = Get-PropertyBool $profile "nativeApiReady"
        })
    }

    $mode = Get-PropertyText $payload "mode"
    $snapshot["parsed"] = $true
    $snapshot["validMode"] = $mode -eq "PAYMENT_PROVIDER_ADAPTER_READINESS"
    $snapshot["status"] = Get-PropertyText $payload "status"
    $snapshot["nativeApiSupported"] = Get-PropertyBool $payload "nativeApiSupported"
    $snapshot["nativeApiReady"] = Get-PropertyBool $payload "nativeApiReady"
    $snapshot["profileCount"] = Get-PropertyInt $payload "profileCount"
    $snapshot["webhookReadyProfileCount"] = Get-PropertyInt $payload "webhookReadyProfileCount"
    $snapshot["nativeApiReadyProfileCount"] = Get-PropertyInt $payload "nativeApiReadyProfileCount"
    $snapshot["generatedAt"] = Get-PropertyText $payload "generatedAt"
    $snapshot["profiles"] = @($profiles.ToArray())
    $snapshot["scopePolicy"] = Get-PropertyText $payload "scopePolicy"
    $snapshot["secretPolicy"] = Get-PropertyText $payload "secretPolicy"
    $snapshot["note"] = Get-PropertyText $payload "note"
    $snapshot["detail"] = if ($snapshot["validMode"]) {
        "status=$($snapshot["status"]); webhookReadyProfileCount=$($snapshot["webhookReadyProfileCount"]); nativeApiReadyProfileCount=$($snapshot["nativeApiReadyProfileCount"])"
    }
    else {
        "Unexpected readiness mode: $mode"
    }
    return $snapshot
}

function New-Integration(
    [string] $Id,
    [string] $Name,
    [bool] $Required,
    [bool] $Verified,
    [string] $EvidenceRef,
    [string] $Note
) {
    return [ordered]@{
        id = $Id
        name = $Name
        required = $Required
        verified = $Verified
        evidenceRef = $EvidenceRef
        note = $Note
    }
}

function Add-IntegrationCheck([object] $Integration) {
    if ($Integration.required) {
        Add-Check "integration-$($Integration.id)" "$($Integration.name) verified" ($Integration.verified -and -not [string]::IsNullOrWhiteSpace([string] $Integration.evidenceRef)) "required=true verified=$($Integration.verified) evidenceRef=$($Integration.evidenceRef)"
    }
    elseif ($Integration.verified -or -not [string]::IsNullOrWhiteSpace([string] $Integration.evidenceRef)) {
        Add-Check "integration-$($Integration.id)" "$($Integration.name) verified" ($Integration.verified -and -not [string]::IsNullOrWhiteSpace([string] $Integration.evidenceRef)) "required=false verified=$($Integration.verified) evidenceRef=$($Integration.evidenceRef)"
    }
    else {
        Add-PlannedCheck "integration-$($Integration.id)" "$($Integration.name) verification planned" "required=false; no target evidence recorded."
    }
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef),
    @("NotificationWebhookEvidenceRef", $NotificationWebhookEvidenceRef),
    @("SlackWebhookEvidenceRef", $SlackWebhookEvidenceRef),
    @("EmailSmtpEvidenceRef", $EmailSmtpEvidenceRef),
    @("PaymentGenericWebhookEvidenceRef", $PaymentGenericWebhookEvidenceRef),
    @("PaymentCardProfileEvidenceRef", $PaymentCardProfileEvidenceRef),
    @("PaymentBankProfileEvidenceRef", $PaymentBankProfileEvidenceRef),
    @("PaymentTaxProfileEvidenceRef", $PaymentTaxProfileEvidenceRef),
    @("PaymentErpProfileEvidenceRef", $PaymentErpProfileEvidenceRef),
    @("PaymentProviderAdapterReadinessEvidenceRef", $PaymentProviderAdapterReadinessEvidenceRef),
    @("AdapterRetryWorkerEvidenceRef", $AdapterRetryWorkerEvidenceRef),
    @("PayloadReviewEvidenceRef", $PayloadReviewEvidenceRef),
    @("PrivateNetworkBlockEvidenceRef", $PrivateNetworkBlockEvidenceRef),
    @("HmacSignatureEvidenceRef", $HmacSignatureEvidenceRef)
)) {
    Assert-SafeReference ([string] $entry[1]) ([string] $entry[0])
}

$requireNotificationWebhook = [bool] ($RequireAllImplementedAdapters -or $RequireNotificationWebhook)
$requireSlackWebhook = [bool] ($RequireAllImplementedAdapters -or $RequireSlackWebhook)
$requireEmailSmtp = [bool] ($RequireAllImplementedAdapters -or $RequireEmailSmtp)
$requirePaymentGenericWebhook = [bool] ($RequireAllImplementedAdapters -or $RequirePaymentGenericWebhook)
$requirePaymentCardProfile = [bool] ($RequireAllImplementedAdapters -or $RequirePaymentCardProfile)
$requirePaymentBankProfile = [bool] ($RequireAllImplementedAdapters -or $RequirePaymentBankProfile)
$requirePaymentTaxProfile = [bool] ($RequireAllImplementedAdapters -or $RequirePaymentTaxProfile)
$requirePaymentErpProfile = [bool] ($RequireAllImplementedAdapters -or $RequirePaymentErpProfile)
$requirePaymentProviderAdapterReadinessReview = [bool] ($RequireAllImplementedAdapters -or $RequirePaymentProviderAdapterReadinessReview)

$integrations = @(
    (New-Integration "notification-webhook" "Generic notification webhook delivery" $requireNotificationWebhook ([bool] $VerifiedNotificationWebhook) $NotificationWebhookEvidenceRef "Chargeback notification outbox adapter-send or retry worker path."),
    (New-Integration "notification-slack" "Slack notification webhook delivery" $requireSlackWebhook ([bool] $VerifiedSlackWebhook) $SlackWebhookEvidenceRef "SLACK channel adapter-send or retry worker path."),
    (New-Integration "notification-email-smtp" "EMAIL SMTP relay delivery" $requireEmailSmtp ([bool] $VerifiedEmailSmtp) $EmailSmtpEvidenceRef "EMAIL channel SMTP relay adapter-send or retry worker path."),
    (New-Integration "payment-generic-webhook" "Generic payment-provider webhook handoff" $requirePaymentGenericWebhook ([bool] $VerifiedPaymentGenericWebhook) $PaymentGenericWebhookEvidenceRef "Payment handoff adapter-send generic profile."),
    (New-Integration "payment-card-profile" "CARD payment webhook profile handoff" $requirePaymentCardProfile ([bool] $VerifiedPaymentCardProfile) $PaymentCardProfileEvidenceRef "Payment handoff providerProfile=CARD."),
    (New-Integration "payment-bank-profile" "BANK payment webhook profile handoff" $requirePaymentBankProfile ([bool] $VerifiedPaymentBankProfile) $PaymentBankProfileEvidenceRef "Payment handoff providerProfile=BANK."),
    (New-Integration "payment-tax-profile" "TAX payment webhook profile handoff" $requirePaymentTaxProfile ([bool] $VerifiedPaymentTaxProfile) $PaymentTaxProfileEvidenceRef "Payment handoff providerProfile=TAX."),
    (New-Integration "payment-erp-profile" "ERP payment webhook profile handoff" $requirePaymentErpProfile ([bool] $VerifiedPaymentErpProfile) $PaymentErpProfileEvidenceRef "Payment handoff providerProfile=ERP.")
)

$verifiedCount = @($integrations | Where-Object { $_.verified -and -not [string]::IsNullOrWhiteSpace([string] $_.evidenceRef) }).Count
$requiredIntegrations = @($integrations | Where-Object { $_.required })
$requiredVerifiedCount = @($requiredIntegrations | Where-Object { $_.verified -and -not [string]::IsNullOrWhiteSpace([string] $_.evidenceRef) }).Count
$paymentProviderAdapterReadinessSnapshot = Read-PaymentProviderAdapterReadinessSnapshot $PaymentProviderAdapterReadinessJsonPath
$paymentProviderAdapterReadinessSnapshotValid = $paymentProviderAdapterReadinessSnapshot.provided -and $paymentProviderAdapterReadinessSnapshot.parsed -and $paymentProviderAdapterReadinessSnapshot.validMode
$paymentProviderAdapterReadinessEvidenceRecorded = -not [string]::IsNullOrWhiteSpace($PaymentProviderAdapterReadinessEvidenceRef)
$paymentProviderAdapterReadinessReviewed = [bool] $ConfirmPaymentProviderAdapterReadinessReviewed -and $paymentProviderAdapterReadinessEvidenceRecorded -and $paymentProviderAdapterReadinessSnapshotValid
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ChangeApprovalRef + $NotificationWebhookEvidenceRef + $SlackWebhookEvidenceRef + $EmailSmtpEvidenceRef + $PaymentGenericWebhookEvidenceRef + $PaymentCardProfileEvidenceRef + $PaymentBankProfileEvidenceRef + $PaymentTaxProfileEvidenceRef + $PaymentErpProfileEvidenceRef + $PaymentProviderAdapterReadinessEvidenceRef + $PaymentProviderAdapterReadinessJsonPath + $AdapterRetryWorkerEvidenceRef + $PayloadReviewEvidenceRef + $PrivateNetworkBlockEvidenceRef + $HmacSignatureEvidenceRef + $VerificationStartedAt + $VerificationCompletedAt) -or $verifiedCount -gt 0 -or [bool] $ConfirmPaymentProviderAdapterReadinessReviewed
$verificationStartedAtParsed = Get-ParsedDateText $VerificationStartedAt
$verificationCompletedAtParsed = Get-ParsedDateText $VerificationCompletedAt
$verificationWindowOrdered = $null -ne $verificationStartedAtParsed -and $null -ne $verificationCompletedAtParsed -and $verificationCompletedAtParsed -ge $verificationStartedAtParsed

Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($Operator)) "operator=$Operator"
Add-Check "verification-started-at" "Verification start timestamp recorded" (Test-DateText $VerificationStartedAt) "verificationStartedAt=$VerificationStartedAt"
Add-Check "verification-completed-at" "Verification completion timestamp recorded" (Test-DateText $VerificationCompletedAt) "verificationCompletedAt=$VerificationCompletedAt"
Add-Check "verification-window-order" "Verification window order valid" $verificationWindowOrdered "verificationStartedAt=$VerificationStartedAt; verificationCompletedAt=$VerificationCompletedAt"
Add-Check "change-approval-ref" "Change approval reference recorded" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "changeApprovalRef=$ChangeApprovalRef"
Add-Check "no-secret-values-confirmed" "No credential values recorded confirmation" ([bool] $ConfirmNoSecretValues) "Evidence stores references and booleans only."
Add-Check "no-raw-provider-responses-confirmed" "No raw provider responses recorded confirmation" ([bool] $ConfirmNoRawProviderResponses) "Provider responses are summarized outside this evidence."
Add-Check "payload-size-caps-confirmed" "Outbound payload size caps verified" ([bool] $ConfirmPayloadSizeCaps -and -not [string]::IsNullOrWhiteSpace($PayloadReviewEvidenceRef)) "payloadReviewEvidenceRef=$PayloadReviewEvidenceRef"
Add-Check "private-network-blocking-confirmed" "Private/local endpoint blocking verified" ([bool] $ConfirmPrivateNetworkBlocking -and -not [string]::IsNullOrWhiteSpace($PrivateNetworkBlockEvidenceRef)) "privateNetworkBlockEvidenceRef=$PrivateNetworkBlockEvidenceRef"
Add-Check "hmac-signature-confirmed" "Webhook HMAC signature headers verified or reviewed" ([bool] $ConfirmHmacSignatureHeaders -and -not [string]::IsNullOrWhiteSpace($HmacSignatureEvidenceRef)) "hmacSignatureEvidenceRef=$HmacSignatureEvidenceRef"
Add-Check "adapter-retry-worker-confirmed" "Adapter retry worker target run verified" ([bool] $ConfirmAdapterRetryWorkerRun -and -not [string]::IsNullOrWhiteSpace($AdapterRetryWorkerEvidenceRef)) "adapterRetryWorkerEvidenceRef=$AdapterRetryWorkerEvidenceRef"

if ($paymentProviderAdapterReadinessSnapshot.provided) {
    Add-Check "payment-provider-adapter-readiness-snapshot" "Payment-provider adapter readiness snapshot parsed" $paymentProviderAdapterReadinessSnapshotValid $paymentProviderAdapterReadinessSnapshot.detail
}
elseif ($requirePaymentProviderAdapterReadinessReview) {
    Add-Check "payment-provider-adapter-readiness-snapshot" "Payment-provider adapter readiness snapshot parsed" $false $paymentProviderAdapterReadinessSnapshot.detail
}
else {
    Add-PlannedCheck "payment-provider-adapter-readiness-snapshot" "Payment-provider adapter readiness snapshot planned" $paymentProviderAdapterReadinessSnapshot.detail
}

if ($paymentProviderAdapterReadinessSnapshotValid) {
    $expectedProfiles = @("GENERIC", "CARD", "BANK", "TAX", "ERP")
    $observedProfiles = @($paymentProviderAdapterReadinessSnapshot.profiles | ForEach-Object { [string] $_.providerProfile })
    $expectedProfileCount = @($expectedProfiles | Where-Object { $observedProfiles -contains $_ }).Count
    Add-Check "payment-provider-adapter-readiness-profile-coverage" "Payment-provider adapter readiness profile coverage" ($expectedProfileCount -eq $expectedProfiles.Count) "profiles=$($observedProfiles -join ','); expected=GENERIC,CARD,BANK,TAX,ERP"
}
elseif ($requirePaymentProviderAdapterReadinessReview) {
    Add-Check "payment-provider-adapter-readiness-profile-coverage" "Payment-provider adapter readiness profile coverage" $false "No valid readiness snapshot available."
}
else {
    Add-PlannedCheck "payment-provider-adapter-readiness-profile-coverage" "Payment-provider adapter readiness profile coverage planned" "No readiness snapshot required for this run."
}

if ($requirePaymentProviderAdapterReadinessReview -or $paymentProviderAdapterReadinessEvidenceRecorded -or [bool] $ConfirmPaymentProviderAdapterReadinessReviewed) {
    Add-Check "payment-provider-adapter-readiness-reviewed" "Payment-provider adapter readiness reviewed" $paymentProviderAdapterReadinessReviewed "required=$requirePaymentProviderAdapterReadinessReview confirmed=$([bool] $ConfirmPaymentProviderAdapterReadinessReviewed) evidenceRef=$PaymentProviderAdapterReadinessEvidenceRef snapshotValid=$paymentProviderAdapterReadinessSnapshotValid"
}
else {
    Add-PlannedCheck "payment-provider-adapter-readiness-reviewed" "Payment-provider adapter readiness review planned" "No readiness evidence reference or confirmation recorded."
}

foreach ($integration in $integrations) {
    Add-IntegrationCheck $integration
}

if ($requiredIntegrations.Count -gt 0) {
    Add-Check "required-integration-coverage" "Required commercial integration coverage" ($requiredVerifiedCount -eq $requiredIntegrations.Count) "requiredVerified=$requiredVerifiedCount/$($requiredIntegrations.Count)"
}
else {
    Add-PlannedCheck "required-integration-coverage" "Required commercial integration coverage planned" "No required integration switches were selected."
}

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$plannedCount = @($checks | Where-Object { $_.status -eq "PLANNED" }).Count
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
$integrationArray = @($integrations)
$checkArray = @($checks | ForEach-Object { $_ })

$report = New-Object System.Collections.Specialized.OrderedDictionary
[void] $report.Add("formatVersion", "osmu.commercial-integration-evidence.v1")
[void] $report.Add("generatedAt", $generatedAt)
[void] $report.Add("result", $result)
[void] $report.Add("environmentName", $EnvironmentName)
[void] $report.Add("targetCluster", $TargetCluster)
[void] $report.Add("operatorName", $Operator)
[void] $report.Add("verificationWindow", [ordered]@{
    startedAt = $VerificationStartedAt
    completedAt = $VerificationCompletedAt
})
[void] $report.Add("evidenceRefs", [ordered]@{
    changeApproval = $ChangeApprovalRef
    paymentProviderAdapterReadiness = $PaymentProviderAdapterReadinessEvidenceRef
    adapterRetryWorker = $AdapterRetryWorkerEvidenceRef
    payloadReview = $PayloadReviewEvidenceRef
    privateNetworkBlocking = $PrivateNetworkBlockEvidenceRef
    hmacSignature = $HmacSignatureEvidenceRef
})
[void] $report.Add("confirmations", [ordered]@{
    noSecretValues = [bool] $ConfirmNoSecretValues
    noRawProviderResponses = [bool] $ConfirmNoRawProviderResponses
    payloadSizeCaps = [bool] $ConfirmPayloadSizeCaps
    privateNetworkBlocking = [bool] $ConfirmPrivateNetworkBlocking
    hmacSignatureHeaders = [bool] $ConfirmHmacSignatureHeaders
    paymentProviderAdapterReadinessReviewed = [bool] $ConfirmPaymentProviderAdapterReadinessReviewed
    adapterRetryWorkerRun = [bool] $ConfirmAdapterRetryWorkerRun
    requireAllImplementedAdapters = [bool] $RequireAllImplementedAdapters
    requirePaymentProviderAdapterReadinessReview = $requirePaymentProviderAdapterReadinessReview
})
[void] $report.Add("integrations", [object] $integrationArray)
[void] $report.Add("paymentProviderAdapterReadiness", [ordered]@{
    required = $requirePaymentProviderAdapterReadinessReview
    reviewed = $paymentProviderAdapterReadinessReviewed
    evidenceRef = $PaymentProviderAdapterReadinessEvidenceRef
    snapshot = $paymentProviderAdapterReadinessSnapshot
})
[void] $report.Add("summary", [ordered]@{
    integrationCount = $integrationArray.Count
    verifiedCount = $verifiedCount
    requiredCount = $requiredIntegrations.Count
    requiredVerifiedCount = $requiredVerifiedCount
    paymentProviderAdapterReadinessReviewed = $paymentProviderAdapterReadinessReviewed
    paymentProviderAdapterReadinessStatus = $paymentProviderAdapterReadinessSnapshot.status
    paymentProviderAdapterWebhookReadyProfileCount = $paymentProviderAdapterReadinessSnapshot.webhookReadyProfileCount
    paymentProviderAdapterNativeReadyProfileCount = $paymentProviderAdapterReadinessSnapshot.nativeApiReadyProfileCount
    failureCount = $failureCount
    plannedCount = $plannedCount
})
[void] $report.Add("checks", [object] $checkArray)
[void] $report.Add("decisionRule", "Production/B2B commercial integration readiness requires result=passed from the target environment for every required notification/payment handoff adapter profile, payment-provider adapter readiness review, adapter retry worker evidence, payload cap check, private/local endpoint blocking check, HMAC signature review, no-secret confirmation, and no-raw-provider-response confirmation.")
[void] $report.Add("scopePolicy", "This evidence covers configured webhook/Slack/EMAIL SMTP relay, generic/CARD/BANK/TAX/ERP payment webhook profile handoff verification, and the sanitized payment-provider adapter readiness snapshot. It does not claim or require native card, bank, tax invoice, or ERP processor API support.")
[void] $report.Add("secretPolicy", "Evidence stores only environment labels, operator/change references, timestamps, booleans, and external evidence references; it does not contain webhook URLs with credentials, SMTP passwords, payment provider credentials, signing secrets, bearer tokens, private keys, raw provider responses, or customer payment data.")

$markdownLines = @(
    "# OSMU Commercial Integration Evidence",
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
    "## Integrations",
    ""
)

foreach ($integration in $integrations) {
    $markdownLines += "- [$($integration.verified)] $($integration.name): required=$($integration.required); evidence=$($integration.evidenceRef)"
    $markdownLines += "  - Note: $($integration.note)"
}

$markdownLines += ""
$markdownLines += "## Payment Provider Adapter Readiness"
$markdownLines += ""
$markdownLines += "- Required: $requirePaymentProviderAdapterReadinessReview"
$markdownLines += "- Reviewed: $paymentProviderAdapterReadinessReviewed"
$markdownLines += "- Evidence: $PaymentProviderAdapterReadinessEvidenceRef"
$markdownLines += "- Snapshot: provided=$($paymentProviderAdapterReadinessSnapshot.provided); parsed=$($paymentProviderAdapterReadinessSnapshot.parsed); validMode=$($paymentProviderAdapterReadinessSnapshot.validMode); status=$($paymentProviderAdapterReadinessSnapshot.status); webhookReady=$($paymentProviderAdapterReadinessSnapshot.webhookReadyProfileCount); nativeReady=$($paymentProviderAdapterReadinessSnapshot.nativeApiReadyProfileCount)"
foreach ($profile in @($paymentProviderAdapterReadinessSnapshot.profiles)) {
    $markdownLines += "  - $($profile.providerProfile): status=$($profile.status); webhook=$($profile.webhookProfileConfigured); nativeSupported=$($profile.nativeApiSupported); nativeReady=$($profile.nativeApiReady)"
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
$markdownLines += "- Record passed target evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-integration-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -VerificationStartedAt <iso-time> -VerificationCompletedAt <iso-time> -ChangeApprovalRef <change-id> -NotificationWebhookEvidenceRef <ref> -SlackWebhookEvidenceRef <ref> -EmailSmtpEvidenceRef <ref> -PaymentGenericWebhookEvidenceRef <ref> -PaymentCardProfileEvidenceRef <ref> -PaymentBankProfileEvidenceRef <ref> -PaymentTaxProfileEvidenceRef <ref> -PaymentErpProfileEvidenceRef <ref> -PaymentProviderAdapterReadinessEvidenceRef <ref> -PaymentProviderAdapterReadinessJsonPath .\.osmu-run\payment-provider-adapter-readiness.json -AdapterRetryWorkerEvidenceRef <ref> -PayloadReviewEvidenceRef <ref> -PrivateNetworkBlockEvidenceRef <ref> -HmacSignatureEvidenceRef <ref> -VerifiedNotificationWebhook -VerifiedSlackWebhook -VerifiedEmailSmtp -VerifiedPaymentGenericWebhook -VerifiedPaymentCardProfile -VerifiedPaymentBankProfile -VerifiedPaymentTaxProfile -VerifiedPaymentErpProfile -ConfirmPaymentProviderAdapterReadinessReviewed -ConfirmAdapterRetryWorkerRun -ConfirmPayloadSizeCaps -ConfirmPrivateNetworkBlocking -ConfirmHmacSignatureHeaders -ConfirmNoSecretValues -ConfirmNoRawProviderResponses -RequireAllImplementedAdapters -FailIfNotPassed``"

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Commercial integration evidence JSON: $resolvedJsonOutputPath"
    Write-Host "Commercial integration evidence markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Commercial integration evidence did not pass: result=$result failureCount=$failureCount"
}
