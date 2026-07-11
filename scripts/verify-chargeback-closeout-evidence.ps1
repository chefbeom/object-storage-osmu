param(
    [string] $OutputDirectory = ".\.osmu-run\chargeback-closeout-evidence-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return [System.IO.Path]::GetFullPath($PathValue) }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
}
function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Label) {
    if (-not $Text.Contains($Expected)) { throw "$Label does not contain expected text: $Expected" }
}

function Assert-NotContains([string] $Text, [string] $Unexpected, [string] $Label) {
    if ($Text.Contains($Unexpected)) { throw "$Label contains unexpected text: $Unexpected" }
}

function New-CommonArgs([string] $StartedAt, [string] $CompletedAt, [bool] $IncludeReconciliationConfirmation) {
    $args = @(
        "-EnvironmentName", "pilot-prod-self-test",
        "-TargetCluster", "customer-cluster-a",
        "-Operator", "ops-self-test",
        "-BillingPeriod", "2026-06",
        "-CloseoutStartedAt", $StartedAt,
        "-CloseoutCompletedAt", $CompletedAt,
        "-ChangeApprovalRef", "CHG-2026-CHARGEBACK-CLOSEOUT-SELF-TEST",
        "-PricingPolicyEvidenceRef", "pricing-policy-run-20260630",
        "-PricingProposalApprovalRef", "pricing-proposal-approval-run-20260630",
        "-ChargebackPreviewEvidenceRef", "chargeback-preview-run-20260630",
        "-ChargebackTrendExportEvidenceRef", "chargeback-trend-export-run-20260630",
        "-InvoiceDraftEvidenceRef", "invoice-draft-run-20260630",
        "-InvoiceFinalizationEvidenceRef", "invoice-finalization-run-20260630",
        "-PaymentRequestEvidenceRef", "payment-request-run-20260630",
        "-PaymentProviderHandoffEvidenceRef", "payment-provider-handoff-run-20260630",
        "-PaymentProviderAdapterReadinessEvidenceRef", "payment-adapter-readiness-run-20260630",
        "-PaymentProviderAdapterReadinessJsonPath", $script:readinessJsonPath,
        "-NotificationDeliveryEvidenceRef", "notification-delivery-run-20260630",
        "-AdapterRetryWorkerEvidenceRef", "adapter-retry-worker-run-20260630",
        "-ReconciliationEvidenceRef", "chargeback-reconciliation-run-20260630",
        "-CommercialIntegrationEvidenceRef", "commercial-integration-run-20260630",
        "-CommercialApprovalEvidenceRef", "commercial-approval-run-20260630",
        "-ChargebackCloseoutSnapshotJsonPath", $script:closeoutJsonPath,
        "-ConfirmPricingPolicyReviewed",
        "-ConfirmPriceListApproved",
        "-ConfirmUsageWindowReviewed",
        "-ConfirmChargebackPreviewReviewed",
        "-ConfirmTrendExportReviewed",
        "-ConfirmInvoiceDraftReviewed",
        "-ConfirmInvoiceFinalized",
        "-ConfirmPaymentRequestReviewed",
        "-ConfirmPaymentProviderHandoffReviewed",
        "-ConfirmPaymentProviderAdapterReadinessReviewed",
        "-ConfirmNotificationDeliveryReviewed",
        "-ConfirmAdapterRetryReviewed",
        "-ConfirmCommercialIntegrationReviewed",
        "-ConfirmCommercialApprovalReviewed",
        "-ConfirmNoRawCustomerPaymentData",
        "-ConfirmNoRawProviderResponses",
        "-ConfirmNoSecretValues"
    )
    if ($IncludeReconciliationConfirmation) { $args += "-ConfirmReconciliationReviewed" }
    return $args
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) { Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force }
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$scriptPath = Resolve-ProjectPath ".\scripts\write-chargeback-closeout-evidence.ps1"
$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-chargeback-closeout-evidence.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-chargeback-closeout-evidence.md"
$script:readinessJsonPath = Join-Path $resolvedOutputDirectory "payment-provider-adapter-readiness.json"
$script:closeoutJsonPath = Join-Path $resolvedOutputDirectory "chargeback-closeout-summary.json"
$plannedJsonPath = Join-Path $resolvedOutputDirectory "planned-chargeback-closeout-evidence.json"
$plannedMarkdownPath = Join-Path $resolvedOutputDirectory "planned-chargeback-closeout-evidence.md"
$failedJsonPath = Join-Path $resolvedOutputDirectory "failed-chargeback-closeout-evidence.json"
$failedMarkdownPath = Join-Path $resolvedOutputDirectory "failed-chargeback-closeout-evidence.md"
$invalidWindowJsonPath = Join-Path $resolvedOutputDirectory "invalid-window-chargeback-closeout-evidence.json"
$invalidWindowMarkdownPath = Join-Path $resolvedOutputDirectory "invalid-window-chargeback-closeout-evidence.md"
$truncatedCloseoutJsonPath = Join-Path $resolvedOutputDirectory "truncated-chargeback-closeout-summary.json"
$truncatedJsonPath = Join-Path $resolvedOutputDirectory "truncated-chargeback-closeout-evidence.json"
$truncatedMarkdownPath = Join-Path $resolvedOutputDirectory "truncated-chargeback-closeout-evidence.md"

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
        profiles = @(
            [ordered]@{ providerProfile = "GENERIC"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
            [ordered]@{ providerProfile = "CARD"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
            [ordered]@{ providerProfile = "BANK"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
            [ordered]@{ providerProfile = "TAX"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false },
            [ordered]@{ providerProfile = "ERP"; adapterMode = "WEBHOOK"; status = "WEBHOOK_READY"; webhookProfileConfigured = $true; nativeApiSupported = $false; nativeApiReady = $false }
        )
    }
}
$readinessFixture | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $script:readinessJsonPath -Encoding UTF8

$closeoutFixture = [ordered]@{
    result = "passed"
    billingPeriod = "2026-06"
    invoiceDraftCount = 4
    finalInvoiceCount = 4
    paymentRequestedCount = 4
    paymentHandoffCount = 4
    paidInvoiceCount = 4
    scanLimit = 500
    sourceTruncated = $false
    truncationBlockerCount = 0
    reconciliationDifferenceMinorUnits = 0
    failureCount = 0
    closeoutReady = $true
    invoiceFinalizationComplete = $true
    paymentRequestsComplete = $true
    paymentsSettled = $true
    paymentHandoffsClosed = $true
    notificationDeliveriesClosed = $true
    reconciliationBalanced = $true
    blockerCount = 0
    missingFinalInvoiceBlockerCount = 0
    missingPaymentRequestBlockerCount = 0
    unpaidInvoiceBlockerCount = 0
    openHandoffBlockerCount = 0
    openNotificationBlockerCount = 0
    reconciliationBlockerCount = 0
    rawCustomerPaymentDataStored = $false
    rawProviderResponseStored = $false
    rawSecretValuesStored = $false
}
$closeoutFixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:closeoutJsonPath -Encoding UTF8

$passedArgs = New-CommonArgs "2026-06-30T01:00:00Z" "2026-06-30T01:45:00Z" $true
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @passedArgs -JsonOutputPath $jsonOutputPath -MarkdownOutputPath $markdownOutputPath -RequirePaymentProviderAdapterReadinessSnapshot -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) { throw "write-chargeback-closeout-evidence.ps1 failed with exit code $LASTEXITCODE." }

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Chargeback closeout evidence JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Chargeback closeout evidence markdown missing."

$reportText = Read-Utf8Text $jsonOutputPath
$markdown = Read-Utf8Text $markdownOutputPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)

Assert-True ($report.formatVersion -eq "osmu.chargeback-closeout-evidence.v1") "Unexpected chargeback closeout evidence formatVersion."
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.summary.requiredEvidenceRefCount -eq 14) "Expected fourteen required evidence references."
Assert-True ($report.summary.providedEvidenceRefCount -eq 14) "Expected fourteen provided evidence references."
Assert-True ($report.summary.chargebackCloseoutSnapshotValid) "Expected valid closeout snapshot."
Assert-True ($report.summary.chargebackCloseoutSnapshotReady) "Expected closeout snapshot readiness flag."
Assert-True ($report.summary.chargebackCloseoutSnapshotBlockerCount -eq 0) "Expected zero closeout blockers."
Assert-True ($report.summary.chargebackCloseoutSnapshotScanLimit -eq 500) "Expected closeout scan limit summary."
Assert-True (-not $report.summary.chargebackCloseoutSnapshotSourceTruncated) "Expected complete closeout source summary."
Assert-True ($report.summary.chargebackCloseoutSnapshotTruncationBlockerCount -eq 0) "Expected zero truncation blockers in summary."
Assert-True ($report.summary.paymentProviderAdapterReadinessSnapshotValid) "Expected valid payment adapter readiness snapshot."
Assert-True ($report.summary.commercialEvidenceReviewed) "Expected commercial evidence review."
Assert-True ($report.confirmations.noRawCustomerPaymentData) "Expected no raw customer/payment confirmation."
Assert-True ($report.confirmations.noRawProviderResponses) "Expected no raw provider response confirmation."
Assert-True ($report.confirmations.noSecretValues) "Expected no secret values confirmation."
Assert-True ($report.chargebackCloseoutSnapshot.valid) "Expected closeout snapshot valid flag."
Assert-True ($report.chargebackCloseoutSnapshot.closeoutReady) "Expected closeout snapshot ready flag."
Assert-True ($report.chargebackCloseoutSnapshot.sourceComplete) "Expected closeout snapshot source completeness flag."
Assert-True (-not $report.chargebackCloseoutSnapshot.sourceTruncated) "Expected untruncated closeout snapshot."
Assert-True ($report.chargebackCloseoutSnapshot.readinessBooleansClosed) "Expected all closeout readiness booleans closed."
Assert-True ($report.chargebackCloseoutSnapshot.counts.failureCount -eq 0) "Expected zero closeout snapshot failures."
Assert-True ($report.chargebackCloseoutSnapshot.counts.blockerCount -eq 0) "Expected zero closeout snapshot blockers."
Assert-True ($report.chargebackCloseoutSnapshot.counts.scanLimit -eq 500) "Expected closeout snapshot scan limit."
Assert-True ($report.chargebackCloseoutSnapshot.counts.truncationBlockerCount -eq 0) "Expected zero closeout snapshot truncation blockers."
Assert-True ($report.chargebackCloseoutSnapshot.counts.reconciliationDifferenceMinorUnits -eq 0) "Expected zero reconciliation difference."
Assert-True ($report.paymentProviderAdapterReadiness.valid) "Expected payment provider readiness snapshot valid flag."
Assert-True ($report.paymentProviderAdapterReadiness.profileCoverageValid) "Expected payment provider profile coverage."
Assert-True (@($checks | Where-Object { $_.id -eq "chargeback-closeout-snapshot-valid" -and $_.passed }).Count -eq 1) "Expected closeout snapshot validation check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "payment-provider-adapter-readiness-snapshot-valid" -and $_.passed }).Count -eq 1) "Expected payment adapter readiness validation check to pass."

Assert-Contains $markdown "# OSMU Chargeback Closeout Evidence" "chargeback closeout evidence markdown"
Assert-Contains $markdown "Scope Policy" "chargeback closeout evidence markdown"
Assert-Contains $markdown "Decision Rule" "chargeback closeout evidence markdown"
Assert-Contains $markdown "Record Passed Target Evidence" "chargeback closeout evidence markdown"
Assert-Contains $report.scopePolicy "does not claim vendor-specific fixed SDK/schema card, bank, tax, ERP, or external payment processor implementation" "chargeback closeout evidence JSON"
Assert-Contains $report.secretPolicy "raw customer data" "chargeback closeout evidence JSON"
Assert-Contains $report.decisionRule "Production/B2B chargeback closeout readiness requires result=passed" "chargeback closeout evidence JSON"
Assert-Contains $report.decisionRule "sourceTruncated=false" "chargeback closeout evidence JSON"
Assert-Contains $report.decisionRule "truncationBlockerCount=0" "chargeback closeout evidence JSON"
Assert-Contains $report.decisionRule "closeoutReady=true" "chargeback closeout evidence JSON"
foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----", "customer@example.com", "cardNumber")) {
    Assert-NotContains $reportText $unexpected "chargeback closeout evidence JSON"
    Assert-NotContains $markdown $unexpected "chargeback closeout evidence markdown"
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -JsonOutputPath $plannedJsonPath -MarkdownOutputPath $plannedMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) { throw "planned write-chargeback-closeout-evidence.ps1 failed with exit code $LASTEXITCODE." }
$plannedReport = Read-Utf8Text $plannedJsonPath | ConvertFrom-Json
Assert-True ($plannedReport.result -eq "planned") "Expected no-input result=planned."
Assert-True ($plannedReport.summary.plannedCount -ge 1) "Expected planned checks for no-input run."

$truncatedFixture = $closeoutFixture | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$truncatedFixture.sourceTruncated = $true
$truncatedFixture.truncationBlockerCount = 1
$truncatedFixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $truncatedCloseoutJsonPath -Encoding UTF8
$truncatedArgs = @(New-CommonArgs "2026-06-30T01:00:00Z" "2026-06-30T01:45:00Z" $true)
$closeoutPathArgIndex = [Array]::IndexOf($truncatedArgs, "-ChargebackCloseoutSnapshotJsonPath")
Assert-True ($closeoutPathArgIndex -ge 0) "Expected closeout snapshot path argument."
$truncatedArgs[$closeoutPathArgIndex + 1] = $truncatedCloseoutJsonPath
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @truncatedArgs -JsonOutputPath $truncatedJsonPath -MarkdownOutputPath $truncatedMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) { throw "truncated closeout write should generate failed evidence without exiting nonzero." }
$truncatedReport = Read-Utf8Text $truncatedJsonPath | ConvertFrom-Json
Assert-True ($truncatedReport.result -eq "failed") "Expected truncated closeout result=failed."
Assert-True (-not $truncatedReport.chargebackCloseoutSnapshot.valid) "Expected truncated closeout snapshot to be invalid."
Assert-True (-not $truncatedReport.chargebackCloseoutSnapshot.sourceComplete) "Expected truncated closeout source completeness to fail."
Assert-True ($truncatedReport.summary.chargebackCloseoutSnapshotSourceTruncated) "Expected truncated source summary flag."
Assert-True ($truncatedReport.summary.chargebackCloseoutSnapshotTruncationBlockerCount -eq 1) "Expected one truncation blocker in summary."
Assert-True (@($truncatedReport.checks | Where-Object { $_.id -eq "chargeback-closeout-snapshot-valid" -and -not $_.passed }).Count -eq 1) "Expected truncated closeout snapshot validation check to fail."

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -EnvironmentName "pilot-prod-self-test" -TargetCluster "customer-cluster-a" -Operator "ops-self-test" -BillingPeriod "2026-06" -PricingPolicyEvidenceRef "Bearer abcdefghijklmnop" -NoWrite 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($invalidExitCode -ne 0) "Credential-like evidence reference should be rejected."

$badWindowArgs = New-CommonArgs "2026-06-30T01:45:00Z" "2026-06-30T01:00:00Z" $true
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidWindowOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @badWindowArgs -JsonOutputPath $invalidWindowJsonPath -MarkdownOutputPath $invalidWindowMarkdownPath -FailIfNotPassed 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($invalidWindowExitCode -ne 0) "Invalid closeout window should fail when FailIfNotPassed is set."

$unsafeCloseoutJsonPath = Join-Path $resolvedOutputDirectory "unsafe-chargeback-closeout-summary.json"
@{ result = "passed"; billingPeriod = "2026-06"; rawProviderResponse = "customer@example.com" } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $unsafeCloseoutJsonPath -Encoding UTF8
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -EnvironmentName "pilot-prod-self-test" -TargetCluster "customer-cluster-a" -Operator "ops-self-test" -BillingPeriod "2026-06" -CloseoutStartedAt "2026-06-30T01:00:00Z" -CloseoutCompletedAt "2026-06-30T01:45:00Z" -ChargebackCloseoutSnapshotJsonPath $unsafeCloseoutJsonPath -NoWrite 2>&1
    $unsafeExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($unsafeExitCode -ne 0) "Unsafe closeout snapshot should be rejected."

$missingConfirmationArgs = New-CommonArgs "2026-06-30T01:00:00Z" "2026-06-30T01:45:00Z" $false
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @missingConfirmationArgs -JsonOutputPath $failedJsonPath -MarkdownOutputPath $failedMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) { throw "missing-confirmation write should generate failed evidence without exiting nonzero." }
$failedReport = Read-Utf8Text $failedJsonPath | ConvertFrom-Json
Assert-True ($failedReport.result -eq "failed") "Expected missing confirmation result=failed."
Assert-True ($failedReport.summary.failureCount -gt 0) "Expected missing confirmation failure count."
Assert-True (@($failedReport.checks | Where-Object { $_.id -eq "reconciliation-reviewed" -and -not $_.passed }).Count -eq 1) "Expected reconciliation-reviewed failure."

Write-Host "Chargeback closeout evidence writer self-test passed."
Write-Host "Chargeback closeout evidence self-test output: $resolvedOutputDirectory"