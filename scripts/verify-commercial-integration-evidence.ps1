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
$scriptPath = Resolve-ProjectPath ".\scripts\write-commercial-integration-evidence.ps1"

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
Assert-True ($integrations.Count -eq 8) "Expected eight integration entries."
Assert-True ($checks.Count -ge 20) "Expected commercial integration checks."
Assert-True (@($checks | Where-Object { $_.id -eq "verification-window-order" -and $_.passed }).Count -eq 1) "Expected verification window order check to pass."
Assert-True ($report.confirmations.noSecretValues) "Expected no-secret-values confirmation."
Assert-True ($report.confirmations.noRawProviderResponses) "Expected no-raw-provider-responses confirmation."
Assert-True ($report.confirmations.payloadSizeCaps) "Expected payload size caps confirmation."
Assert-True ($report.confirmations.privateNetworkBlocking) "Expected private network blocking confirmation."
Assert-True ($report.confirmations.hmacSignatureHeaders) "Expected HMAC signature confirmation."
Assert-True ($report.confirmations.adapterRetryWorkerRun) "Expected adapter retry worker confirmation."

Assert-Contains $markdown "# OSMU Commercial Integration Evidence" "commercial integration evidence markdown"
Assert-Contains $markdown "Scope Policy" "commercial integration evidence markdown"
Assert-Contains $markdown "Record passed target evidence" "commercial integration evidence markdown"
Assert-Contains $report.scopePolicy "does not claim native card, bank, tax invoice, or ERP processor API support" "commercial integration evidence JSON"
Assert-Contains $report.secretPolicy "does not contain webhook URLs with credentials" "commercial integration evidence JSON"
Assert-Contains $report.decisionRule "Production/B2B commercial integration readiness requires result=passed" "commercial integration evidence JSON"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----")) {
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

Write-Host "Commercial integration evidence writer verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
