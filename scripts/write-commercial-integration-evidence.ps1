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

function Assert-SafeReference([string] $Value, [string] $Label) {
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
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ChangeApprovalRef + $NotificationWebhookEvidenceRef + $SlackWebhookEvidenceRef + $EmailSmtpEvidenceRef + $PaymentGenericWebhookEvidenceRef + $PaymentCardProfileEvidenceRef + $PaymentBankProfileEvidenceRef + $PaymentTaxProfileEvidenceRef + $PaymentErpProfileEvidenceRef + $AdapterRetryWorkerEvidenceRef + $PayloadReviewEvidenceRef + $PrivateNetworkBlockEvidenceRef + $HmacSignatureEvidenceRef + $VerificationStartedAt + $VerificationCompletedAt) -or $verifiedCount -gt 0
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
    adapterRetryWorkerRun = [bool] $ConfirmAdapterRetryWorkerRun
    requireAllImplementedAdapters = [bool] $RequireAllImplementedAdapters
})
[void] $report.Add("integrations", [object] $integrationArray)
[void] $report.Add("summary", [ordered]@{
    integrationCount = $integrationArray.Count
    verifiedCount = $verifiedCount
    requiredCount = $requiredIntegrations.Count
    requiredVerifiedCount = $requiredVerifiedCount
    failureCount = $failureCount
    plannedCount = $plannedCount
})
[void] $report.Add("checks", [object] $checkArray)
[void] $report.Add("decisionRule", "Production/B2B commercial integration readiness requires result=passed from the target environment for every required notification/payment handoff adapter profile, adapter retry worker evidence, payload cap check, private/local endpoint blocking check, HMAC signature review, no-secret confirmation, and no-raw-provider-response confirmation.")
[void] $report.Add("scopePolicy", "This evidence covers configured webhook/Slack/EMAIL SMTP relay and generic/CARD/BANK/TAX/ERP payment webhook profile handoff verification. It does not claim native card, bank, tax invoice, or ERP processor API support.")
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
$markdownLines += "## Checks"
$markdownLines += ""
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}

$markdownLines += ""
$markdownLines += "## Operator Command"
$markdownLines += ""
$markdownLines += "- Record passed target evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-integration-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -VerificationStartedAt <iso-time> -VerificationCompletedAt <iso-time> -ChangeApprovalRef <change-id> -NotificationWebhookEvidenceRef <ref> -SlackWebhookEvidenceRef <ref> -EmailSmtpEvidenceRef <ref> -PaymentGenericWebhookEvidenceRef <ref> -PaymentCardProfileEvidenceRef <ref> -PaymentBankProfileEvidenceRef <ref> -PaymentTaxProfileEvidenceRef <ref> -PaymentErpProfileEvidenceRef <ref> -AdapterRetryWorkerEvidenceRef <ref> -PayloadReviewEvidenceRef <ref> -PrivateNetworkBlockEvidenceRef <ref> -HmacSignatureEvidenceRef <ref> -VerifiedNotificationWebhook -VerifiedSlackWebhook -VerifiedEmailSmtp -VerifiedPaymentGenericWebhook -VerifiedPaymentCardProfile -VerifiedPaymentBankProfile -VerifiedPaymentTaxProfile -VerifiedPaymentErpProfile -ConfirmAdapterRetryWorkerRun -ConfirmPayloadSizeCaps -ConfirmPrivateNetworkBlocking -ConfirmHmacSignatureHeaders -ConfirmNoSecretValues -ConfirmNoRawProviderResponses -RequireAllImplementedAdapters -FailIfNotPassed``"

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
