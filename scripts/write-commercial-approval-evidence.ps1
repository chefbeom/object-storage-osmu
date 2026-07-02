param(
    [string] $ProductVersion = "",
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $OperatorName = "",
    [string] $ApprovalRef = "",
    [string] $ApprovedBy = "",
    [string] $ApprovedAt = "",
    [string] $PricingApprovalRef = "",
    [string] $TermsApprovalRef = "",
    [string] $SupportSlaApprovalRef = "",
    [string] $LicenseAgreementRef = "",
    [string] $LegalApprovalRef = "",
    [string] $PilotContractRef = "",
    [string] $PricingPolicyProposalEvidenceRef = "",
    [string] $PricingPolicyProposalJsonPath = "",
    [string] $NotesRef = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-commercial-approval-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-commercial-approval-evidence.md",
    [switch] $ConfirmPricingApproved,
    [switch] $ConfirmTermsApproved,
    [switch] $ConfirmSupportSlaApproved,
    [switch] $ConfirmLicenseApproved,
    [switch] $ConfirmLegalApproved,
    [switch] $ConfirmPricingPolicyProposalCommercialApproval,
    [switch] $RequirePricingPolicyProposalApprovalSnapshot,
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
function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
}

function Assert-SafeText([string] $Value, [string] $Label) {
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

function Assert-SafeReference([string] $Value, [string] $Label) {
    Assert-SafeText $Value $Label
}

function Assert-SanitizedPricingPolicyProposalJson([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $forbiddenPropertyPattern = '(?i)"(rawContractText|raw_contract_text|contractText|contract_text|legalTerms|legal_terms|termsText|terms_text|customerData|customer_data|customerEmail|customer_email|customerName|customer_name|licenseKey|license_key|licenseText|license_text|rawPriceTable|raw_price_table|paymentCard|payment_card|cardNumber|card_number|bankAccount|bank_account)"\s*:'
    if ($Value -match $forbiddenPropertyPattern) {
        throw "PricingPolicyProposalJson appears to contain raw contract, customer, license, payment, or raw price table content. Store only sanitized proposal approval metadata."
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

function Add-PlannedCheck([string] $Id, [string] $Name, [string] $Detail, [string] $EvidenceRef = "") {
    [void] $script:checks.Add((New-Check $Id $Name "PLANNED" $Detail $EvidenceRef))
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

function Get-RequiredPropertyBool([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return [pscustomobject]@{ value = $false; valid = $false; raw = "<missing>" }
    }
    if ($value -is [bool]) {
        return [pscustomobject]@{ value = [bool] $value; valid = $true; raw = [string] $value }
    }
    return [pscustomobject]@{ value = $false; valid = $false; raw = [string] $value }
}

function Get-PropertyLong([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return 0
    }
    $parsed = 0L
    if ([long]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return 0L
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

function Get-ProposalArray([object] $Payload) {
    if ($null -eq $Payload) {
        return @()
    }
    if ($Payload -is [System.Array]) {
        return @($Payload)
    }
    if ($null -ne (Get-PropertyValue $Payload "data")) {
        $data = Get-PropertyValue $Payload "data"
        $nested = Get-ProposalArray $data
        if ($nested.Count -gt 0) {
            return @($nested)
        }
    }
    $proposals = Get-PropertyArray $Payload "proposals"
    if ($proposals.Count -gt 0) {
        return @($proposals)
    }
    $proposal = Get-PropertyValue $Payload "proposal"
    if ($null -ne $proposal) {
        return @($proposal)
    }
    return @()
}

function Read-PricingPolicyProposalSnapshot([string] $Path) {
    $snapshot = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        proposalCount = 0
        approvedPriceListCount = 0
        commercialApprovedCount = 0
        latestCommercialApprovedAt = ""
        proposals = @()
        approvalFlagsValid = $false
        approvalFlagValidation = [ordered]@{}
        detail = "No billing pricing policy proposal JSON supplied."
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $snapshot
    }

    $resolvedPath = Resolve-ProjectPath $Path
    $snapshot["provided"] = $true
    $snapshot["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $snapshot["detail"] = "Billing pricing policy proposal JSON not found."
        return $snapshot
    }

    $raw = Read-Utf8Text $resolvedPath
    Assert-SafeText $raw "PricingPolicyProposalJson"
    Assert-SanitizedPricingPolicyProposalJson $raw
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $snapshot["detail"] = "Billing pricing policy proposal JSON parse failed: $($_.Exception.Message)"
        return $snapshot
    }

    $proposalRows = New-Object System.Collections.Generic.List[object]
    $approvalFlagValidation = [ordered]@{}
    $proposalIndex = 0
    foreach ($proposal in @(Get-ProposalArray $payload)) {
        $approvedPriceList = Get-RequiredPropertyBool $proposal "approvedPriceList"
        $approvalFlagValidation["proposals[$proposalIndex].approvedPriceList"] = $approvedPriceList
        [void] $proposalRows.Add([ordered]@{
            id = Get-PropertyLong $proposal "id"
            status = Get-PropertyText $proposal "status"
            approvedPriceList = [bool] $approvedPriceList.value
            approvedPriceListValid = [bool] $approvedPriceList.valid
            currency = Get-PropertyText $proposal "currency"
            requestedBy = Get-PropertyText $proposal "requestedBy"
            approvedBy = Get-PropertyText $proposal "approvedBy"
            commercialApprovedBy = Get-PropertyText $proposal "commercialApprovedBy"
            commercialApprovalReference = Get-PropertyText $proposal "commercialApprovalReference"
            createdAt = Get-PropertyText $proposal "createdAt"
            updatedAt = Get-PropertyText $proposal "updatedAt"
            approvedAt = Get-PropertyText $proposal "approvedAt"
            appliedAt = Get-PropertyText $proposal "appliedAt"
            commercialApprovedAt = Get-PropertyText $proposal "commercialApprovedAt"
            commercialEffectiveFrom = Get-PropertyText $proposal "commercialEffectiveFrom"
        })
        $proposalIndex += 1
    }

    $approvalFlagsValid = @($approvalFlagValidation.GetEnumerator() | Where-Object { -not [bool] $_.Value.valid }).Count -eq 0
    $approvedPriceListCount = @($proposalRows | Where-Object { $_.approvedPriceList }).Count
    $commercialApprovedRows = @($proposalRows | Where-Object {
        $_.approvedPriceList `
            -and $_.status -eq "PRICE_LIST_APPROVED" `
            -and -not [string]::IsNullOrWhiteSpace([string] $_.commercialApprovalReference)
    })
    $latestCommercialApprovedAt = @($commercialApprovedRows |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_.commercialApprovedAt) } |
        Sort-Object -Property commercialApprovedAt -Descending |
        Select-Object -First 1 |
        ForEach-Object { [string] $_.commercialApprovedAt })

    $snapshot["parsed"] = $true
    $snapshot["proposalCount"] = $proposalRows.Count
    $snapshot["approvedPriceListCount"] = $approvedPriceListCount
    $snapshot["commercialApprovedCount"] = $commercialApprovedRows.Count
    $snapshot["latestCommercialApprovedAt"] = if ($latestCommercialApprovedAt.Count -gt 0) { $latestCommercialApprovedAt[0] } else { "" }
    $snapshot["proposals"] = @($proposalRows.ToArray())
    $snapshot["approvalFlagsValid"] = [bool] $approvalFlagsValid
    $snapshot["approvalFlagValidation"] = $approvalFlagValidation
    $snapshot["detail"] = "proposalCount=$($proposalRows.Count); approvedPriceListCount=$approvedPriceListCount; commercialApprovedCount=$($commercialApprovedRows.Count); approvalFlagsValid=$approvalFlagsValid"
    return $snapshot
}

foreach ($entry in @(
    @("ProductVersion", $ProductVersion),
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("OperatorName", $OperatorName),
    @("ApprovalRef", $ApprovalRef),
    @("ApprovedBy", $ApprovedBy),
    @("PricingApprovalRef", $PricingApprovalRef),
    @("TermsApprovalRef", $TermsApprovalRef),
    @("SupportSlaApprovalRef", $SupportSlaApprovalRef),
    @("LicenseAgreementRef", $LicenseAgreementRef),
    @("LegalApprovalRef", $LegalApprovalRef),
    @("PilotContractRef", $PilotContractRef),
    @("PricingPolicyProposalEvidenceRef", $PricingPolicyProposalEvidenceRef),
    @("NotesRef", $NotesRef)
)) {
    Assert-SafeReference ([string] $entry[1]) ([string] $entry[0])
}

$pricingPolicyProposalSnapshot = Read-PricingPolicyProposalSnapshot $PricingPolicyProposalJsonPath
$pricingPolicyProposalSnapshotValid = $pricingPolicyProposalSnapshot.provided -and $pricingPolicyProposalSnapshot.parsed -and $pricingPolicyProposalSnapshot.approvalFlagsValid
$pricingPolicyProposalCommercialApproved = $pricingPolicyProposalSnapshotValid -and $pricingPolicyProposalSnapshot.commercialApprovedCount -gt 0
$pricingPolicyProposalEvidenceRecorded = -not [string]::IsNullOrWhiteSpace($PricingPolicyProposalEvidenceRef)
$pricingPolicyProposalCommercialApprovalReviewed = [bool] $ConfirmPricingPolicyProposalCommercialApproval -and $pricingPolicyProposalEvidenceRecorded -and $pricingPolicyProposalCommercialApproved
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($ProductVersion + $EnvironmentName + $TargetCluster + $OperatorName + $ApprovalRef + $ApprovedBy + $ApprovedAt + $PricingApprovalRef + $TermsApprovalRef + $SupportSlaApprovalRef + $LicenseAgreementRef + $LegalApprovalRef + $PilotContractRef + $PricingPolicyProposalEvidenceRef + $PricingPolicyProposalJsonPath + $NotesRef) -or $ConfirmPricingApproved -or $ConfirmTermsApproved -or $ConfirmSupportSlaApproved -or $ConfirmLicenseApproved -or $ConfirmLegalApproved -or $ConfirmPricingPolicyProposalCommercialApproval -or $ConfirmNoSecretValues

Add-Check "product-version" "Product version recorded" (-not [string]::IsNullOrWhiteSpace($ProductVersion)) "productVersion=$ProductVersion"
Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($OperatorName)) "operatorName=$OperatorName"
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

if ($pricingPolicyProposalSnapshot.provided) {
    Add-Check "pricing-policy-proposal-snapshot" "Billing pricing policy proposal snapshot parsed" $pricingPolicyProposalSnapshotValid $pricingPolicyProposalSnapshot.detail $PricingPolicyProposalEvidenceRef
}
elseif ($RequirePricingPolicyProposalApprovalSnapshot) {
    Add-Check "pricing-policy-proposal-snapshot" "Billing pricing policy proposal snapshot parsed" $false $pricingPolicyProposalSnapshot.detail $PricingPolicyProposalEvidenceRef
}
else {
    Add-PlannedCheck "pricing-policy-proposal-snapshot" "Billing pricing policy proposal snapshot planned" $pricingPolicyProposalSnapshot.detail $PricingPolicyProposalEvidenceRef
}

if ($pricingPolicyProposalSnapshot.provided) {
    Add-Check "pricing-policy-proposal-approval-fields-typed" "Billing pricing policy proposal approval fields are typed" $pricingPolicyProposalSnapshot.approvalFlagsValid "approvedPriceList fields must be JSON booleans; approvalFlagsValid=$($pricingPolicyProposalSnapshot.approvalFlagsValid)" $PricingPolicyProposalEvidenceRef
}
elseif ($RequirePricingPolicyProposalApprovalSnapshot) {
    Add-Check "pricing-policy-proposal-approval-fields-typed" "Billing pricing policy proposal approval fields are typed" $false "No pricing proposal snapshot available." $PricingPolicyProposalEvidenceRef
}
else {
    Add-PlannedCheck "pricing-policy-proposal-approval-fields-typed" "Billing pricing policy proposal typed approval fields planned" "No pricing proposal snapshot required for this run." $PricingPolicyProposalEvidenceRef
}

if ($RequirePricingPolicyProposalApprovalSnapshot -or $pricingPolicyProposalEvidenceRecorded -or [bool] $ConfirmPricingPolicyProposalCommercialApproval) {
    Add-Check "pricing-policy-proposal-commercial-approved" "Billing pricing policy proposal commercial approval recorded" $pricingPolicyProposalCommercialApprovalReviewed "required=$([bool] $RequirePricingPolicyProposalApprovalSnapshot) confirmed=$([bool] $ConfirmPricingPolicyProposalCommercialApproval) evidenceRef=$PricingPolicyProposalEvidenceRef commercialApprovedCount=$($pricingPolicyProposalSnapshot.commercialApprovedCount)" $PricingPolicyProposalEvidenceRef
}
else {
    Add-PlannedCheck "pricing-policy-proposal-commercial-approved" "Billing pricing policy proposal commercial approval planned" "No pricing proposal evidence reference or confirmation recorded." $PricingPolicyProposalEvidenceRef
}

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
    environmentName = $EnvironmentName
    targetCluster = $TargetCluster
    operatorName = $OperatorName
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
        pricingPolicyProposal = $PricingPolicyProposalEvidenceRef
        notes = $NotesRef
    }
    confirmations = [ordered]@{
        pricingApproved = [bool] $ConfirmPricingApproved
        termsApproved = [bool] $ConfirmTermsApproved
        supportSlaApproved = [bool] $ConfirmSupportSlaApproved
        licenseApproved = [bool] $ConfirmLicenseApproved
        legalApproved = [bool] $ConfirmLegalApproved
        pricingPolicyProposalCommercialApproval = [bool] $ConfirmPricingPolicyProposalCommercialApproval
        requirePricingPolicyProposalApprovalSnapshot = [bool] $RequirePricingPolicyProposalApprovalSnapshot
        noSecretValues = [bool] $ConfirmNoSecretValues
    }
    pricingPolicyProposalApproval = [ordered]@{
        required = [bool] $RequirePricingPolicyProposalApprovalSnapshot
        reviewed = $pricingPolicyProposalCommercialApprovalReviewed
        evidenceRef = $PricingPolicyProposalEvidenceRef
        snapshot = $pricingPolicyProposalSnapshot
    }
    summary = [ordered]@{
        passedCount = $passedCount
        failureCount = $failureCount
        checkCount = $checkArray.Count
        pricingPolicyProposalCommercialApproved = $pricingPolicyProposalCommercialApproved
        pricingPolicyProposalCommercialApprovedCount = $pricingPolicyProposalSnapshot.commercialApprovedCount
        pricingPolicyProposalApprovedPriceListCount = $pricingPolicyProposalSnapshot.approvedPriceListCount
        pricingPolicyProposalApprovalFlagsValid = $pricingPolicyProposalSnapshot.approvalFlagsValid
    }
    checks = $checkArray
    decisionRule = "Production/B2B sale commercial approval requires result=passed, final pricing approval, final terms approval, support SLA approval, license agreement approval, legal approval, a pilot contract boundary reference, required billing pricing policy proposal commercial approval evidence, and no-secret confirmation."
    scopePolicy = "This evidence records commercial/legal approval references and sanitized billing pricing policy proposal approval status only. It does not publish prices, legal terms, contracts, customer data, or native payment processor credentials."
    secretPolicy = "Evidence stores only product version, approver identity, timestamps, booleans, sanitized pricing proposal status/reference metadata, and external approval references; it must not contain passwords, tokens, private keys, license keys, signing secrets, customer payment data, raw price tables, or raw contract text."
}

$markdownLines = @(
    "# OSMU Commercial Approval Evidence",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Product version: $ProductVersion",
    "Environment: $EnvironmentName",
    "Target cluster: $TargetCluster",
    "Operator: $OperatorName",
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
$markdownLines += "## Billing Pricing Policy Proposal"
$markdownLines += ""
$markdownLines += "- Required: $([bool] $RequirePricingPolicyProposalApprovalSnapshot)"
$markdownLines += "- Reviewed: $pricingPolicyProposalCommercialApprovalReviewed"
$markdownLines += "- Evidence: $PricingPolicyProposalEvidenceRef"
$markdownLines += "- Snapshot: provided=$($pricingPolicyProposalSnapshot.provided); parsed=$($pricingPolicyProposalSnapshot.parsed); proposalCount=$($pricingPolicyProposalSnapshot.proposalCount); approvedPriceList=$($pricingPolicyProposalSnapshot.approvedPriceListCount); commercialApproved=$($pricingPolicyProposalSnapshot.commercialApprovedCount)"
foreach ($proposal in @($pricingPolicyProposalSnapshot.proposals)) {
    $markdownLines += "  - proposal=$($proposal.id); status=$($proposal.status); approvedPriceList=$($proposal.approvedPriceList); commercialApprovalReference=$($proposal.commercialApprovalReference); commercialApprovedAt=$($proposal.commercialApprovedAt); commercialEffectiveFrom=$($proposal.commercialEffectiveFrom)"
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
$markdownLines += "- Record passed approval evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-commercial-approval-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -OperatorName <operator> -ProductVersion <version> -ApprovalRef <approval-ref> -ApprovedBy <approver> -ApprovedAt <iso-time> -PricingApprovalRef <ref> -TermsApprovalRef <ref> -SupportSlaApprovalRef <ref> -LicenseAgreementRef <ref> -LegalApprovalRef <ref> -PilotContractRef <ref> -PricingPolicyProposalEvidenceRef <ref> -PricingPolicyProposalJsonPath .\.osmu-run\billing-pricing-policy-proposals.json -ConfirmPricingApproved -ConfirmTermsApproved -ConfirmSupportSlaApproved -ConfirmLicenseApproved -ConfirmLegalApproved -ConfirmPricingPolicyProposalCommercialApproval -RequirePricingPolicyProposalApprovalSnapshot -ConfirmNoSecretValues -FailIfNotPassed``"

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
