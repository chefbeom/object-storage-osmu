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
$scriptPath = Resolve-ProjectPath ".\scripts\write-commercial-approval-evidence.ps1"

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
    -NotesRef "commercial-readiness-review-20260620" `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -ConfirmPricingApproved `
    -ConfirmTermsApproved `
    -ConfirmSupportSlaApproved `
    -ConfirmLicenseApproved `
    -ConfirmLegalApproved `
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
Assert-True ($checks.Count -ge 10) "Expected commercial approval checks."
Assert-True ($report.confirmations.pricingApproved) "Expected pricing approval confirmation."
Assert-True ($report.confirmations.termsApproved) "Expected terms approval confirmation."
Assert-True ($report.confirmations.supportSlaApproved) "Expected support SLA approval confirmation."
Assert-True ($report.confirmations.licenseApproved) "Expected license approval confirmation."
Assert-True ($report.confirmations.legalApproved) "Expected legal approval confirmation."
Assert-True ($report.confirmations.noSecretValues) "Expected no-secret-values confirmation."
Assert-True (@($checks | Where-Object { $_.id -eq "legal-approval-confirmed" -and $_.passed }).Count -eq 1) "Expected legal approval check to pass."

Assert-Contains $markdown "# OSMU Commercial Approval Evidence" "commercial approval markdown"
Assert-Contains $markdown "Record passed approval evidence" "commercial approval markdown"
Assert-Contains $report.decisionRule "Production/B2B sale commercial approval requires result=passed" "commercial approval JSON"
Assert-Contains $report.scopePolicy "does not publish prices, legal terms, contracts" "commercial approval JSON"
Assert-Contains $report.secretPolicy "must not contain passwords, tokens, private keys, license keys" "commercial approval JSON"

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

Write-Host "Commercial approval evidence writer verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
