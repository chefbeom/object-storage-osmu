param(
    [string] $OutputDirectory = ".\.osmu-run\commercial-approval-evidence-self-test"
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

$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-commercial-approval-evidence.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-commercial-approval-evidence.md"
$pricingProposalJsonPath = Join-Path $resolvedOutputDirectory "billing-pricing-policy-proposals.json"
$scriptPath = Resolve-ProjectPath ".\scripts\write-commercial-approval-evidence.ps1"

$proposalFixture = [ordered]@{
    success = $true
    data = [ordered]@{
        proposalCount = 2
        generatedAt = "2026-06-20T03:05:00Z"
        proposals = @(
            [ordered]@{
                id = 11
                status = "PRICE_LIST_APPROVED"
                approvedPriceList = $true
                currency = "USD"
                storageGbMonthRate = "0.10"
                ingressGbRate = "0.01"
                egressGbRate = "0.02"
                internalGbRate = "0.005"
                operationThousandRate = "0.001"
                warningAmount = "500"
                criticalAmount = "1000"
                eventScanLimit = 5000
                requestedBy = "billing-admin"
                approvedBy = "finance-owner"
                reason = "internal policy approval"
                approvalNote = "internal rates applied"
                commercialApprovedBy = "commercial-review-board"
                commercialApprovalReference = "commercial-approval-board-20260620"
                commercialApprovalNote = "final commercial approval"
                createdAt = "2026-06-20T01:00:00Z"
                updatedAt = "2026-06-20T03:00:00Z"
                approvedAt = "2026-06-20T02:00:00Z"
                appliedAt = "2026-06-20T02:05:00Z"
                commercialApprovedAt = "2026-06-20T03:00:00Z"
                commercialEffectiveFrom = "2026-07-01T00:00:00Z"
            },
            [ordered]@{
                id = 10
                status = "APPROVED_APPLIED"
                approvedPriceList = $false
                currency = "USD"
                requestedBy = "billing-admin"
                approvedBy = "finance-owner"
                commercialApprovedBy = ""
                commercialApprovalReference = ""
                createdAt = "2026-06-19T01:00:00Z"
                updatedAt = "2026-06-19T02:00:00Z"
                approvedAt = "2026-06-19T02:00:00Z"
                appliedAt = "2026-06-19T02:05:00Z"
                commercialApprovedAt = ""
                commercialEffectiveFrom = ""
            }
        )
    }
}
$proposalFixture | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $pricingProposalJsonPath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ProductVersion "v0.1.0-rc.1" `
    -ApprovalRef "commercial-approval-board-20260620" `
    -ApprovedBy "commercial-review-board" `
    -ApprovedAt "2026-06-20T03:00:00Z" `
    -PricingApprovalRef "pricing-approval-20260620" `
    -TermsApprovalRef "terms-approval-20260620" `
    -SupportSlaApprovalRef "support-sla-approval-20260620" `
    -LicenseAgreementRef "license-agreement-approval-20260620" `
    -LegalApprovalRef "legal-approval-20260620" `
    -PilotContractRef "pilot-contract-template-20260620" `
    -PricingPolicyProposalEvidenceRef "pricing-policy-proposal-commercial-approval-20260620" `
    -PricingPolicyProposalJsonPath $pricingProposalJsonPath `
    -NotesRef "commercial-readiness-review-20260620" `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -ConfirmPricingApproved `
    -ConfirmTermsApproved `
    -ConfirmSupportSlaApproved `
    -ConfirmLicenseApproved `
    -ConfirmLegalApproved `
    -ConfirmPricingPolicyProposalCommercialApproval `
    -RequirePricingPolicyProposalApprovalSnapshot `
    -ConfirmNoSecretValues `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-commercial-approval-evidence.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Commercial approval evidence JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Commercial approval evidence markdown missing."

$reportText = Get-Content -Raw -LiteralPath $jsonOutputPath
$markdown = Get-Content -Raw -LiteralPath $markdownOutputPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)

Assert-True ($report.formatVersion -eq "osmu.commercial-approval-evidence.v1") "Unexpected commercial approval evidence formatVersion."
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($checks.Count -ge 13) "Expected commercial approval checks."
Assert-True ($report.summary.pricingPolicyProposalCommercialApproved) "Expected pricing policy proposal commercial approval summary."
Assert-True ($report.summary.pricingPolicyProposalCommercialApprovedCount -eq 1) "Expected one commercial-approved pricing proposal."
Assert-True ($report.summary.pricingPolicyProposalApprovedPriceListCount -eq 1) "Expected one approved price-list proposal."
Assert-True ($report.confirmations.pricingApproved) "Expected pricing approval confirmation."
Assert-True ($report.confirmations.termsApproved) "Expected terms approval confirmation."
Assert-True ($report.confirmations.supportSlaApproved) "Expected support SLA approval confirmation."
Assert-True ($report.confirmations.licenseApproved) "Expected license approval confirmation."
Assert-True ($report.confirmations.legalApproved) "Expected legal approval confirmation."
Assert-True ($report.confirmations.pricingPolicyProposalCommercialApproval) "Expected pricing policy proposal commercial approval confirmation."
Assert-True ($report.confirmations.noSecretValues) "Expected no-secret-values confirmation."
Assert-True (@($checks | Where-Object { $_.id -eq "legal-approval-confirmed" -and $_.passed }).Count -eq 1) "Expected legal approval check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "pricing-policy-proposal-snapshot" -and $_.passed }).Count -eq 1) "Expected pricing proposal snapshot check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "pricing-policy-proposal-commercial-approved" -and $_.passed }).Count -eq 1) "Expected pricing proposal commercial approval check to pass."
Assert-True ($report.pricingPolicyProposalApproval.reviewed) "Expected pricing proposal approval section reviewed."
Assert-True (@($report.pricingPolicyProposalApproval.snapshot.proposals).Count -eq 2) "Expected sanitized proposal rows."

Assert-Contains $markdown "# OSMU Commercial Approval Evidence" "commercial approval markdown"
Assert-Contains $markdown "Billing Pricing Policy Proposal" "commercial approval markdown"
Assert-Contains $markdown "Record passed approval evidence" "commercial approval markdown"
Assert-Contains $report.decisionRule "Production/B2B sale commercial approval requires result=passed" "commercial approval JSON"
Assert-Contains $report.decisionRule "billing pricing policy proposal commercial approval evidence" "commercial approval JSON"
Assert-Contains $report.scopePolicy "does not publish prices, legal terms, contracts" "commercial approval JSON"
Assert-Contains $report.secretPolicy "raw price tables" "commercial approval JSON"

Assert-NotContains $reportText "storageGbMonthRate" "commercial approval JSON"
Assert-NotContains $markdown "storageGbMonthRate" "commercial approval markdown"
Assert-NotContains $reportText "0.10" "commercial approval JSON"
Assert-NotContains $markdown "0.10" "commercial approval markdown"
foreach ($unexpected in @("contractText", "customer@example.com", "licenseKey")) {
    Assert-NotContains $reportText $unexpected "commercial approval JSON"
    Assert-NotContains $markdown $unexpected "commercial approval markdown"
}

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----")) {
    Assert-NotContains $reportText $unexpected "commercial approval JSON"
    Assert-NotContains $markdown $unexpected "commercial approval markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -ProductVersion "v0.1.0-rc.1" `
        -ApprovalRef "commercial-approval-board-20260620" `
        -ApprovedBy "commercial-review-board" `
        -ApprovedAt "2026-06-20T03:00:00Z" `
        -SupportSlaApprovalRef "password=super-secret" `
        -NoWrite 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Credential-like approval reference should be rejected."
Assert-Contains ($invalidOutput | Out-String) "SupportSlaApprovalRef appears to contain credential material" "invalid commercial approval output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingApprovalOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -ProductVersion "v0.1.0-rc.1" `
        -ApprovalRef "commercial-approval-board-20260620" `
        -ApprovedBy "commercial-review-board" `
        -ApprovedAt "2026-06-20T03:00:00Z" `
        -PricingApprovalRef "pricing-approval-20260620" `
        -ConfirmPricingApproved `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $missingApprovalExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingApprovalExitCode -ne 0) "Incomplete commercial approval evidence should fail with FailIfNotPassed."
Assert-Contains ($missingApprovalOutput | Out-String) "Commercial approval evidence did not pass" "incomplete commercial approval output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingSnapshotOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -ProductVersion "v0.1.0-rc.1" `
        -ApprovalRef "commercial-approval-board-20260620" `
        -ApprovedBy "commercial-review-board" `
        -ApprovedAt "2026-06-20T03:00:00Z" `
        -PricingApprovalRef "pricing-approval-20260620" `
        -TermsApprovalRef "terms-approval-20260620" `
        -SupportSlaApprovalRef "support-sla-approval-20260620" `
        -LicenseAgreementRef "license-agreement-approval-20260620" `
        -LegalApprovalRef "legal-approval-20260620" `
        -PilotContractRef "pilot-contract-template-20260620" `
        -ConfirmPricingApproved `
        -ConfirmTermsApproved `
        -ConfirmSupportSlaApproved `
        -ConfirmLicenseApproved `
        -ConfirmLegalApproved `
        -ConfirmPricingPolicyProposalCommercialApproval `
        -RequirePricingPolicyProposalApprovalSnapshot `
        -ConfirmNoSecretValues `
        -FailIfNotPassed `
        -NoWrite 2>&1
    $missingSnapshotExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingSnapshotExitCode -ne 0) "Required pricing proposal snapshot should fail when missing."
Assert-Contains ($missingSnapshotOutput | Out-String) "Billing pricing policy proposal snapshot parsed" "missing pricing proposal snapshot output"

$unsafeProposalJsonPath = Join-Path $resolvedOutputDirectory "unsafe-billing-pricing-policy-proposals.json"
[ordered]@{
    data = [ordered]@{
        proposal = [ordered]@{
            id = 12
            status = "PRICE_LIST_APPROVED"
            approvedPriceList = $true
            commercialApprovalReference = "Bearer abcdefghijklmnop"
        }
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $unsafeProposalJsonPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeSnapshotOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -ProductVersion "v0.1.0-rc.1" `
        -PricingPolicyProposalEvidenceRef "pricing-policy-proposal-commercial-approval-20260620" `
        -PricingPolicyProposalJsonPath $unsafeProposalJsonPath `
        -ConfirmPricingPolicyProposalCommercialApproval `
        -NoWrite 2>&1
    $unsafeSnapshotExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeSnapshotExitCode -ne 0) "Credential-like pricing proposal snapshot should be rejected."
Assert-Contains ($unsafeSnapshotOutput | Out-String) "PricingPolicyProposalJson appears to contain credential material" "unsafe pricing proposal snapshot output"

$unsafeRawProposalJsonPath = Join-Path $resolvedOutputDirectory "unsafe-raw-billing-pricing-policy-proposals.json"
[ordered]@{
    data = [ordered]@{
        proposal = [ordered]@{
            id = 13
            status = "PRICE_LIST_APPROVED"
            approvedPriceList = $true
            commercialApprovalReference = "commercial-approval-board-20260620"
            contractText = "Customer customer@example.com receives confidential terms."
        }
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $unsafeRawProposalJsonPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeRawSnapshotOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -ProductVersion "v0.1.0-rc.1" `
        -PricingPolicyProposalEvidenceRef "pricing-policy-proposal-commercial-approval-20260620" `
        -PricingPolicyProposalJsonPath $unsafeRawProposalJsonPath `
        -ConfirmPricingPolicyProposalCommercialApproval `
        -NoWrite 2>&1
    $unsafeRawSnapshotExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeRawSnapshotExitCode -ne 0) "Raw commercial proposal snapshot should be rejected."
Assert-Contains ($unsafeRawSnapshotOutput | Out-String) "raw contract" "unsafe raw pricing proposal snapshot output"

Write-Host "Commercial approval evidence writer verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
