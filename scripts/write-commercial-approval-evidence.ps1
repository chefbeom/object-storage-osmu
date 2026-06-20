param(
    [string] $ProductVersion = "",
    [string] $ApprovalRef = "",
    [string] $ApprovedBy = "",
    [string] $ApprovedAt = "",
    [string] $PricingApprovalRef = "",
    [string] $TermsApprovalRef = "",
    [string] $SupportSlaApprovalRef = "",
    [string] $LicenseAgreementRef = "",
    [string] $LegalApprovalRef = "",
    [string] $PilotContractRef = "",
    [string] $NotesRef = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-commercial-approval-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-commercial-approval-evidence.md",
    [switch] $ConfirmPricingApproved,
    [switch] $ConfirmTermsApproved,
    [switch] $ConfirmSupportSlaApproved,
    [switch] $ConfirmLicenseApproved,
    [switch] $ConfirmLegalApproved,
    [switch] $ConfirmNoSecretValues,
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
        "(?i)\b(password|passwd|secret|token|client_secret|license_key|private_key|webhook_secret)\s*[=:]\s*\S+"
    )

    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain credential material. Store only a non-secret approval reference."
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

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail, [string] $EvidenceRef = "") {
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

foreach ($entry in @(
    @("ProductVersion", $ProductVersion),
    @("ApprovalRef", $ApprovalRef),
    @("ApprovedBy", $ApprovedBy),
    @("PricingApprovalRef", $PricingApprovalRef),
    @("TermsApprovalRef", $TermsApprovalRef),
    @("SupportSlaApprovalRef", $SupportSlaApprovalRef),
    @("LicenseAgreementRef", $LicenseAgreementRef),
    @("LegalApprovalRef", $LegalApprovalRef),
    @("PilotContractRef", $PilotContractRef),
    @("NotesRef", $NotesRef)
)) {
    Assert-SafeReference ([string] $entry[1]) ([string] $entry[0])
}

$hasAnyInput = -not [string]::IsNullOrWhiteSpace($ProductVersion + $ApprovalRef + $ApprovedBy + $ApprovedAt + $PricingApprovalRef + $TermsApprovalRef + $SupportSlaApprovalRef + $LicenseAgreementRef + $LegalApprovalRef + $PilotContractRef + $NotesRef) -or $ConfirmPricingApproved -or $ConfirmTermsApproved -or $ConfirmSupportSlaApproved -or $ConfirmLicenseApproved -or $ConfirmLegalApproved -or $ConfirmNoSecretValues

Add-Check "product-version" "Product version recorded" (-not [string]::IsNullOrWhiteSpace($ProductVersion)) "productVersion=$ProductVersion"
Add-Check "approval-ref" "Commercial approval reference recorded" (-not [string]::IsNullOrWhiteSpace($ApprovalRef)) "approvalRef=$ApprovalRef" $ApprovalRef
Add-Check "approved-by" "Approver recorded" (-not [string]::IsNullOrWhiteSpace($ApprovedBy)) "approvedBy=$ApprovedBy"
Add-Check "approved-at" "Approval timestamp recorded" (Test-DateText $ApprovedAt) "approvedAt=$ApprovedAt"
Add-Check "pricing-approved" "Final pricing approved" ([bool] $ConfirmPricingApproved -and -not [string]::IsNullOrWhiteSpace($PricingApprovalRef)) "pricingApprovalRef=$PricingApprovalRef" $PricingApprovalRef
Add-Check "terms-approved" "Final terms approved" ([bool] $ConfirmTermsApproved -and -not [string]::IsNullOrWhiteSpace($TermsApprovalRef)) "termsApprovalRef=$TermsApprovalRef" $TermsApprovalRef
Add-Check "support-sla-approved" "Support SLA approved" ([bool] $ConfirmSupportSlaApproved -and -not [string]::IsNullOrWhiteSpace($SupportSlaApprovalRef)) "supportSlaApprovalRef=$SupportSlaApprovalRef" $SupportSlaApprovalRef
Add-Check "license-agreement-approved" "License agreement approved" ([bool] $ConfirmLicenseApproved -and -not [string]::IsNullOrWhiteSpace($LicenseAgreementRef)) "licenseAgreementRef=$LicenseAgreementRef" $LicenseAgreementRef
Add-Check "legal-approval-confirmed" "Legal approval confirmed" ([bool] $ConfirmLegalApproved -and -not [string]::IsNullOrWhiteSpace($LegalApprovalRef)) "legalApprovalRef=$LegalApprovalRef" $LegalApprovalRef
Add-Check "pilot-contract-boundary-recorded" "Pilot contract boundary recorded" (-not [string]::IsNullOrWhiteSpace($PilotContractRef)) "pilotContractRef=$PilotContractRef" $PilotContractRef
Add-Check "no-secret-values-confirmed" "No credential values recorded confirmation" ([bool] $ConfirmNoSecretValues) "Evidence stores references and booleans only."

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
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

$report = [ordered]@{
    formatVersion = "osmu.commercial-approval-evidence.v1"
    generatedAt = $generatedAt
    result = $result
    productVersion = $ProductVersion
    approvedBy = $ApprovedBy
    approvedAt = $ApprovedAt
    evidenceRefs = [ordered]@{
        approval = $ApprovalRef
        pricing = $PricingApprovalRef
        terms = $TermsApprovalRef
        supportSla = $SupportSlaApprovalRef
        licenseAgreement = $LicenseAgreementRef
        legal = $LegalApprovalRef
        pilotContract = $PilotContractRef
        notes = $NotesRef
    }
    confirmations = [ordered]@{
        pricingApproved = [bool] $ConfirmPricingApproved
        termsApproved = [bool] $ConfirmTermsApproved
        supportSlaApproved = [bool] $ConfirmSupportSlaApproved
        licenseApproved = [bool] $ConfirmLicenseApproved
        legalApproved = [bool] $ConfirmLegalApproved
        noSecretValues = [bool] $ConfirmNoSecretValues
    }
    summary = [ordered]@{
        passedCount = $passedCount
        failureCount = $failureCount
        checkCount = $checkArray.Count
    }
    checks = $checkArray
    decisionRule = "Production/B2B sale commercial approval requires result=passed, final pricing approval, final terms approval, support SLA approval, license agreement approval, legal approval, a pilot contract boundary reference, and no-secret confirmation."
    scopePolicy = "This evidence records commercial/legal approval references only. It does not publish prices, legal terms, contracts, customer data, or native payment processor credentials."
    secretPolicy = "Evidence stores only product version, approver identity, timestamps, booleans, and external approval references; it must not contain passwords, tokens, private keys, license keys, signing secrets, customer payment data, or raw contract text."
}

$markdownLines = @(
    "# OSMU Commercial Approval Evidence",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Product version: $ProductVersion",
    "Approved by: $ApprovedBy",
    "Approved at: $ApprovedAt",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Scope Policy",
    "",
    $report.scopePolicy,
    "",
    "## Secret Policy",
    "",
    $report.secretPolicy,
    "",
    "## References",
    ""
)

foreach ($ref in $report.evidenceRefs.GetEnumerator()) {
    $markdownLines += "- $($ref.Key): $($ref.Value)"
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
$markdownLines += "- Record passed approval evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-approval-evidence.ps1 -ProductVersion <version> -ApprovalRef <approval-ref> -ApprovedBy <approver> -ApprovedAt <iso-time> -PricingApprovalRef <ref> -TermsApprovalRef <ref> -SupportSlaApprovalRef <ref> -LicenseAgreementRef <ref> -LegalApprovalRef <ref> -PilotContractRef <ref> -ConfirmPricingApproved -ConfirmTermsApproved -ConfirmSupportSlaApproved -ConfirmLicenseApproved -ConfirmLegalApproved -ConfirmNoSecretValues -FailIfNotPassed``"

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Commercial approval evidence JSON: $resolvedJsonOutputPath"
    Write-Host "Commercial approval evidence markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Commercial approval evidence did not pass: result=$result failureCount=$failureCount"
}
