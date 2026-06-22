param(
    [string] $OutputDirectory = ".\.osmu-run\commercial-integration-evidence-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-NotContains([string] $text, [string] $unexpected, [string] $label) {
    if ($text.Contains($unexpected)) {
        throw "$label contains unexpected credential text: $unexpected"
    }
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

$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-commercial-integration-evidence.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-commercial-integration-evidence.md"
$readinessJsonPath = Join-Path $resolvedOutputDirectory "payment-provider-adapter-readiness.json"
$scriptPath = Resolve-ProjectPath ".\scripts\write-commercial-integration-evidence.ps1"

$readinessFixture = [ordered]@{
    success = $true
    data = [ordered]@{
        mode = "PAYMENT_PROVIDER_ADAPTER_READINESS"
        status = "WEBHOOK_PROFILE_READY"
        nativeApiSupported = $false
        nativeApiReady = $false
        profileCount = 5
        webhookReadyProfileCount = 5
        nativeApiReadyProfileCount = 0
        generatedAt = "2026-06-20T01:30:00Z"
        scopePolicy = "Readiness view checks OSMU payment-provider handoff adapter configuration only."
        secretPolicy = "Only sanitized profile metadata is exposed."
        note = "Webhook handoff profiles are ready; native card/bank/tax/ERP API adapters remain out of scope for this evidence."
        profiles = @(
            [ordered]@{ providerProfile = "GENERIC"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
            [ordered]@{ providerProfile = "CARD"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
            [ordered]@{ providerProfile = "BANK"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
            [ordered]@{ providerProfile = "TAX"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
            [ordered]@{ providerProfile = "ERP"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false }
        )
    }
}
$readinessFixture | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $readinessJsonPath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "ops-self-test" `
    -VerificationStartedAt "2026-06-20T01:00:00Z" `
    -VerificationCompletedAt "2026-06-20T01:45:00Z" `
    -ChangeApprovalRef "CHG-2026-COMMERCIAL-INTEGRATION-SELF-TEST" `
    -NotificationWebhookEvidenceRef "notification-webhook-run-20260620" `
    -SlackWebhookEvidenceRef "slack-webhook-run-20260620" `
    -EmailSmtpEvidenceRef "email-smtp-run-20260620" `
    -PaymentGenericWebhookEvidenceRef "payment-generic-webhook-run-20260620" `
    -PaymentCardProfileEvidenceRef "payment-card-profile-run-20260620" `
    -PaymentBankProfileEvidenceRef "payment-bank-profile-run-20260620" `
    -PaymentTaxProfileEvidenceRef "payment-tax-profile-run-20260620" `
    -PaymentErpProfileEvidenceRef "payment-erp-profile-run-20260620" `
    -PaymentProviderAdapterReadinessEvidenceRef "payment-adapter-readiness-run-20260620" `
    -PaymentProviderAdapterReadinessJsonPath $readinessJsonPath `
    -AdapterRetryWorkerEvidenceRef "adapter-retry-worker-run-20260620" `
    -PayloadReviewEvidenceRef "payload-cap-review-20260620" `
    -PrivateNetworkBlockEvidenceRef "private-network-block-review-20260620" `
    -HmacSignatureEvidenceRef "hmac-signature-review-20260620" `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -VerifiedNotificationWebhook `
    -VerifiedSlackWebhook `
    -VerifiedEmailSmtp `
    -VerifiedPaymentGenericWebhook `
    -VerifiedPaymentCardProfile `
    -VerifiedPaymentBankProfile `
    -VerifiedPaymentTaxProfile `
    -VerifiedPaymentErpProfile `
    -ConfirmAdapterRetryWorkerRun `
    -ConfirmPayloadSizeCaps `
    -ConfirmPrivateNetworkBlocking `
    -ConfirmHmacSignatureHeaders `
    -ConfirmPaymentProviderAdapterReadinessReviewed `
    -ConfirmNoSecretValues `
    -ConfirmNoRawProviderResponses `
    -RequireAllImplementedAdapters `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-commercial-integration-evidence.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Commercial integration evidence JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Commercial integration evidence markdown missing."

$reportText = Get-Content -Raw -LiteralPath $jsonOutputPath
$markdown = Get-Content -Raw -LiteralPath $markdownOutputPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)
$integrations = @($report.integrations)

Assert-True ($report.formatVersion -eq "osmu.commercial-integration-evidence.v1") "Unexpected commercial integration evidence formatVersion."
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.summary.requiredCount -eq 8) "Expected all eight implemented integration profiles required."
Assert-True ($report.summary.requiredVerifiedCount -eq 8) "Expected all required integration profiles verified."
Assert-True ($report.summary.paymentProviderAdapterReadinessReviewed) "Expected payment-provider adapter readiness review."
Assert-True ($report.summary.paymentProviderAdapterReadinessStatus -eq "WEBHOOK_PROFILE_READY") "Expected readiness status from snapshot."
Assert-True ($report.summary.paymentProviderAdapterWebhookReadyProfileCount -eq 5) "Expected five webhook-ready payment profiles."
Assert-True ($report.summary.paymentProviderAdapterNativeReadyProfileCount -eq 0) "Expected no native payment API adapters ready."
Assert-True ($integrations.Count -eq 8) "Expected eight integration entries."
Assert-True ($checks.Count -ge 23) "Expected commercial integration checks."
Assert-True (@($checks | Where-Object { $_.id -eq "verification-window-order" -and $_.passed }).Count -eq 1) "Expected verification window order check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "payment-provider-adapter-readiness-snapshot" -and $_.passed }).Count -eq 1) "Expected payment adapter readiness snapshot check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "payment-provider-adapter-readiness-counts-typed" -and $_.passed }).Count -eq 1) "Expected payment adapter readiness typed counts check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "payment-provider-adapter-readiness-booleans-typed" -and $_.passed }).Count -eq 1) "Expected payment adapter readiness typed booleans check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "payment-provider-adapter-readiness-profile-coverage" -and $_.passed }).Count -eq 1) "Expected payment adapter readiness profile coverage check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "payment-provider-adapter-readiness-reviewed" -and $_.passed }).Count -eq 1) "Expected payment adapter readiness review check to pass."
Assert-True ($report.confirmations.noSecretValues) "Expected no-secret-values confirmation."
Assert-True ($report.confirmations.noRawProviderResponses) "Expected no-raw-provider-responses confirmation."
Assert-True ($report.confirmations.payloadSizeCaps) "Expected payload size caps confirmation."
Assert-True ($report.confirmations.privateNetworkBlocking) "Expected private network blocking confirmation."
Assert-True ($report.confirmations.hmacSignatureHeaders) "Expected HMAC signature confirmation."
Assert-True ($report.confirmations.paymentProviderAdapterReadinessReviewed) "Expected payment adapter readiness confirmation."
Assert-True ($report.confirmations.adapterRetryWorkerRun) "Expected adapter retry worker confirmation."
Assert-True ($report.paymentProviderAdapterReadiness.reviewed) "Expected payment adapter readiness section reviewed."
Assert-True ($report.paymentProviderAdapterReadiness.snapshot.validMode) "Expected valid payment adapter readiness mode."
Assert-True (@($report.paymentProviderAdapterReadiness.snapshot.profiles).Count -eq 5) "Expected sanitized payment adapter readiness profiles."

Assert-Contains $markdown "# OSMU Commercial Integration Evidence" "commercial integration evidence markdown"
Assert-Contains $markdown "Scope Policy" "commercial integration evidence markdown"
Assert-Contains $markdown "Payment Provider Adapter Readiness" "commercial integration evidence markdown"
Assert-Contains $markdown "Record passed target evidence" "commercial integration evidence markdown"
Assert-Contains $report.scopePolicy "does not claim or require native card, bank, tax invoice, or ERP processor API support" "commercial integration evidence JSON"
Assert-Contains $report.secretPolicy "does not contain webhook URLs with credentials" "commercial integration evidence JSON"
Assert-Contains $report.decisionRule "Production/B2B commercial integration readiness requires result=passed" "commercial integration evidence JSON"
Assert-Contains $report.decisionRule "payment-provider adapter readiness review" "commercial integration evidence JSON"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----")) {
    Assert-NotContains $reportText $unexpected "commercial integration evidence JSON"
    Assert-NotContains $markdown $unexpected "commercial integration evidence markdown"
}
foreach ($unexpected in @("rawProviderResponse", "customer@example.com", "https://pay.example")) {
    Assert-NotContains $reportText $unexpected "commercial integration evidence JSON"
    Assert-NotContains $markdown $unexpected "commercial integration evidence markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -NotificationWebhookEvidenceRef "Bearer abcdefghijklmnop" `
        -NoWrite 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Credential-like evidence reference should be rejected."

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidWindowOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -VerificationStartedAt "2026-06-20T01:45:00Z" `
        -VerificationCompletedAt "2026-06-20T01:00:00Z" `
        -ChangeApprovalRef "CHG-2026-COMMERCIAL-INTEGRATION-SELF-TEST" `
        -NotificationWebhookEvidenceRef "notification-webhook-run-20260620" `
        -SlackWebhookEvidenceRef "slack-webhook-run-20260620" `
        -EmailSmtpEvidenceRef "email-smtp-run-20260620" `
        -PaymentGenericWebhookEvidenceRef "payment-generic-webhook-run-20260620" `
        -PaymentCardProfileEvidenceRef "payment-card-profile-run-20260620" `
        -PaymentBankProfileEvidenceRef "payment-bank-profile-run-20260620" `
        -PaymentTaxProfileEvidenceRef "payment-tax-profile-run-20260620" `
        -PaymentErpProfileEvidenceRef "payment-erp-profile-run-20260620" `
        -PaymentProviderAdapterReadinessEvidenceRef "payment-adapter-readiness-run-20260620" `
        -PaymentProviderAdapterReadinessJsonPath $readinessJsonPath `
        -AdapterRetryWorkerEvidenceRef "adapter-retry-worker-run-20260620" `
        -PayloadReviewEvidenceRef "payload-cap-review-20260620" `
        -PrivateNetworkBlockEvidenceRef "private-network-block-review-20260620" `
        -HmacSignatureEvidenceRef "hmac-signature-review-20260620" `
        -VerifiedNotificationWebhook `
        -VerifiedSlackWebhook `
        -VerifiedEmailSmtp `
        -VerifiedPaymentGenericWebhook `
        -VerifiedPaymentCardProfile `
        -VerifiedPaymentBankProfile `
        -VerifiedPaymentTaxProfile `
        -VerifiedPaymentErpProfile `
        -ConfirmAdapterRetryWorkerRun `
        -ConfirmPayloadSizeCaps `
        -ConfirmPrivateNetworkBlocking `
        -ConfirmHmacSignatureHeaders `
        -ConfirmPaymentProviderAdapterReadinessReviewed `
        -ConfirmNoSecretValues `
        -ConfirmNoRawProviderResponses `
        -RequireAllImplementedAdapters `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidWindowExitCode -ne 0) "Reversed verification window should be rejected."
Assert-Contains ($invalidWindowOutput | Out-String) "Verification window order valid" "invalid verification window output"

$unsafeReadinessJsonPath = Join-Path $resolvedOutputDirectory "unsafe-payment-provider-adapter-readiness.json"
[ordered]@{
    mode = "PAYMENT_PROVIDER_ADAPTER_READINESS"
    webhook_secret = "secret=super-secret"
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $unsafeReadinessJsonPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidReadinessOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -PaymentProviderAdapterReadinessEvidenceRef "payment-adapter-readiness-run-20260620" `
        -PaymentProviderAdapterReadinessJsonPath $unsafeReadinessJsonPath `
        -ConfirmPaymentProviderAdapterReadinessReviewed `
        -NoWrite 2>&1
    $invalidReadinessExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidReadinessExitCode -ne 0) "Credential-like readiness snapshot should be rejected."
Assert-Contains ($invalidReadinessOutput | Out-String) "PaymentProviderAdapterReadinessJson appears to contain credential material" "invalid readiness snapshot output"

$unsafeRawReadinessJsonPath = Join-Path $resolvedOutputDirectory "unsafe-raw-payment-provider-adapter-readiness.json"
[ordered]@{
    mode = "PAYMENT_PROVIDER_ADAPTER_READINESS"
    status = "WEBHOOK_PROFILE_READY"
    rawProviderResponse = @{
        statusCode = 200
        body = "customer@example.com approved through https://pay.example/provider"
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $unsafeRawReadinessJsonPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeRawReadinessOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -PaymentProviderAdapterReadinessEvidenceRef "payment-adapter-readiness-run-20260620" `
        -PaymentProviderAdapterReadinessJsonPath $unsafeRawReadinessJsonPath `
        -ConfirmPaymentProviderAdapterReadinessReviewed `
        -NoWrite 2>&1
    $unsafeRawReadinessExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeRawReadinessExitCode -ne 0) "Raw provider readiness snapshot should be rejected."
Assert-Contains ($unsafeRawReadinessOutput | Out-String) "raw provider response" "unsafe raw readiness snapshot output"

$stringTypedReadinessJsonPath = Join-Path $resolvedOutputDirectory "string-typed-payment-provider-adapter-readiness.json"
[ordered]@{
    mode = "PAYMENT_PROVIDER_ADAPTER_READINESS"
    status = "WEBHOOK_PROFILE_READY"
    nativeApiSupported = "false"
    nativeApiReady = $false
    profileCount = "5"
    webhookReadyProfileCount = 5
    nativeApiReadyProfileCount = 0
    profiles = @(
        [ordered]@{ providerProfile = "GENERIC"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = "true"; nativeApiSupported = $false; nativeApiReady = $false },
        [ordered]@{ providerProfile = "CARD"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
        [ordered]@{ providerProfile = "BANK"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
        [ordered]@{ providerProfile = "TAX"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
        [ordered]@{ providerProfile = "ERP"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false }
    )
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $stringTypedReadinessJsonPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $stringTypedReadinessOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -VerificationStartedAt "2026-06-20T01:00:00Z" `
        -VerificationCompletedAt "2026-06-20T01:45:00Z" `
        -ChangeApprovalRef "CHG-2026-COMMERCIAL-INTEGRATION-SELF-TEST" `
        -PaymentProviderAdapterReadinessEvidenceRef "payment-adapter-readiness-run-20260620" `
        -PaymentProviderAdapterReadinessJsonPath $stringTypedReadinessJsonPath `
        -ConfirmPaymentProviderAdapterReadinessReviewed `
        -RequirePaymentProviderAdapterReadinessReview `
        -ConfirmNoSecretValues `
        -ConfirmNoRawProviderResponses `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $stringTypedReadinessExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($stringTypedReadinessExitCode -ne 0) "String-typed readiness counts/booleans should be rejected."
Assert-Contains ($stringTypedReadinessOutput | Out-String) "Payment-provider adapter readiness counts are typed integers" "string-typed readiness snapshot output"
Assert-Contains ($stringTypedReadinessOutput | Out-String) "Payment-provider adapter readiness booleans are typed" "string-typed readiness snapshot output"

Write-Host "Commercial integration evidence writer verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
