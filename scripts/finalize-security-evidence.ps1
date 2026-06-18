param(
    [string] $ImageSigningEvidencePath = ".\.osmu-run\latest-image-signing-evidence.json",
    [string] $ContainerSecurityEvidencePath = ".\.osmu-run\latest-container-security-evidence.json",
    [string] $PromotedImageSigningEvidencePath = ".\.osmu-run\latest-image-signing-evidence.json",
    [string] $PromotedContainerSecurityEvidencePath = ".\.osmu-run\latest-container-security-evidence.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-security-evidence-finalize.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-security-evidence-finalize.md",
    [switch] $AllowSyntheticEvidence,
    [switch] $NoPromote,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Get-ObjectProperty($object, [string] $name) {
    if ($null -eq $object) {
        return $null
    }
    $property = $object.PSObject.Properties[$name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Add-Check([string] $Name, [bool] $Passed, [string] $Detail, [string] $EvidencePath = "") {
    $script:checks += [ordered]@{
        name = $Name
        passed = $Passed
        status = if ($Passed) { "PASS" } else { "FAIL" }
        detail = $Detail
        evidencePath = $EvidencePath
    }
}

function Read-Evidence([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            label = $label
            path = $resolvedPath
            exists = $false
            parsed = $false
            data = $null
            detail = "evidence file not found"
        }
    }

    try {
        return [pscustomobject]@{
            label = $label
            path = $resolvedPath
            exists = $true
            parsed = $true
            data = (Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json)
            detail = "evidence parsed"
        }
    }
    catch {
        return [pscustomobject]@{
            label = $label
            path = $resolvedPath
            exists = $true
            parsed = $false
            data = $null
            detail = $_.Exception.Message
        }
    }
}

function Test-HttpUrl([string] $value) {
    return -not [string]::IsNullOrWhiteSpace($value) -and $value -match "^https?://"
}

function Test-CommitSha([string] $value) {
    return -not [string]::IsNullOrWhiteSpace($value) -and $value -match "^[0-9a-fA-F]{40}$" -and $value -notmatch "^0{40}$"
}

function Test-Digest([string] $value) {
    return -not [string]::IsNullOrWhiteSpace($value) -and $value -match "^sha256:[0-9a-fA-F]{64}$" -and $value -notmatch "^sha256:0{64}$"
}

function Test-Sha256([string] $value) {
    return -not [string]::IsNullOrWhiteSpace($value) -and $value -match "^[0-9a-fA-F]{64}$" -and $value -notmatch "^0{64}$"
}

function Test-ContainsSyntheticMarker([object] $value) {
    if ($null -eq $value) {
        return $false
    }
    $text = ($value | ConvertTo-Json -Depth 12 -Compress)
    return $text -match "example\.invalid" -or $text -match "self-test" -or $text -match "0{40}"
}

function Add-CommonEvidenceChecks([object] $report, [string] $expectedFormatVersion, [string] $prefix) {
    Add-Check "$prefix exists" ($report.exists) $report.detail $report.path
    Add-Check "$prefix parsed" ($report.exists -and $report.parsed) $report.detail $report.path
    if (-not ($report.exists -and $report.parsed)) {
        return
    }

    Add-Check "$prefix format" ($report.data.formatVersion -eq $expectedFormatVersion) "formatVersion=$($report.data.formatVersion)" $report.path
    Add-Check "$prefix result" ($report.data.result -eq "passed") "result=$($report.data.result)" $report.path
    Add-Check "$prefix failure count" ([int] $report.data.failureCount -eq 0) "failureCount=$($report.data.failureCount)" $report.path
    Add-Check "$prefix source run url" (Test-HttpUrl ([string] $report.data.sourceRunUrl)) "sourceRunUrl=$($report.data.sourceRunUrl)" $report.path
    Add-Check "$prefix secret policy" (-not [string]::IsNullOrWhiteSpace([string] $report.data.secretPolicy)) "secretPolicy present" $report.path
    Add-Check "$prefix non-synthetic" ($AllowSyntheticEvidence -or -not (Test-ContainsSyntheticMarker $report.data)) "allowSyntheticEvidence=$([bool] $AllowSyntheticEvidence)" $report.path
}

function Test-SamePath([string] $left, [string] $right) {
    return ([System.IO.Path]::GetFullPath($left)).TrimEnd("\") -ieq ([System.IO.Path]::GetFullPath($right)).TrimEnd("\")
}

function Promote-Evidence([string] $sourcePath, [string] $targetPath, [string] $label) {
    if (Test-SamePath $sourcePath $targetPath) {
        return "already at $targetPath"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    return "promoted $label evidence to $targetPath"
}

$imageEvidence = Read-Evidence $ImageSigningEvidencePath "Image signing evidence"
$containerEvidence = Read-Evidence $ContainerSecurityEvidencePath "Container security evidence"

Add-CommonEvidenceChecks $imageEvidence "osmu.image-signing-evidence.v1" "image signing evidence"
Add-CommonEvidenceChecks $containerEvidence "osmu.container-security-evidence.v1" "container security evidence"

if ($imageEvidence.exists -and $imageEvidence.parsed) {
    Add-Check "image signing version" (-not [string]::IsNullOrWhiteSpace([string] $imageEvidence.data.version)) "version=$($imageEvidence.data.version)" $imageEvidence.path
    Add-Check "image signing commit sha" ($AllowSyntheticEvidence -or (Test-CommitSha ([string] $imageEvidence.data.commitSha))) "commitSha=$($imageEvidence.data.commitSha)" $imageEvidence.path
    Add-Check "image signing backend refs" (-not [string]::IsNullOrWhiteSpace([string] $imageEvidence.data.backend.versionRef) -and -not [string]::IsNullOrWhiteSpace([string] $imageEvidence.data.backend.shaRef)) "backend refs present" $imageEvidence.path
    Add-Check "image signing frontend refs" (-not [string]::IsNullOrWhiteSpace([string] $imageEvidence.data.frontend.versionRef) -and -not [string]::IsNullOrWhiteSpace([string] $imageEvidence.data.frontend.shaRef)) "frontend refs present" $imageEvidence.path
    Add-Check "image signing backend digest" (Test-Digest ([string] $imageEvidence.data.backend.digest)) "backendDigest=$($imageEvidence.data.backend.digest)" $imageEvidence.path
    Add-Check "image signing frontend digest" (Test-Digest ([string] $imageEvidence.data.frontend.digest)) "frontendDigest=$($imageEvidence.data.frontend.digest)" $imageEvidence.path
}

if ($containerEvidence.exists -and $containerEvidence.parsed) {
    $backendSbom = Get-ObjectProperty (Get-ObjectProperty $containerEvidence.data "sbom") "backend"
    $frontendSbom = Get-ObjectProperty (Get-ObjectProperty $containerEvidence.data "sbom") "frontend"
    Add-Check "container security commit sha" ($AllowSyntheticEvidence -or (Test-CommitSha ([string] $containerEvidence.data.commitSha))) "commitSha=$($containerEvidence.data.commitSha)" $containerEvidence.path
    Add-Check "container security artifact name" (-not [string]::IsNullOrWhiteSpace([string] $containerEvidence.data.artifactName)) "artifactName=$($containerEvidence.data.artifactName)" $containerEvidence.path
    Add-Check "container security backend image" (-not [string]::IsNullOrWhiteSpace([string] $containerEvidence.data.backendImage)) "backendImage=$($containerEvidence.data.backendImage)" $containerEvidence.path
    Add-Check "container security frontend image" (-not [string]::IsNullOrWhiteSpace([string] $containerEvidence.data.frontendImage)) "frontendImage=$($containerEvidence.data.frontendImage)" $containerEvidence.path
    Add-Check "container security backend sbom" ([bool] $backendSbom.valid -and [int] $backendSbom.packageCount -gt 0) "backend packageCount=$($backendSbom.packageCount)" $containerEvidence.path
    Add-Check "container security frontend sbom" ([bool] $frontendSbom.valid -and [int] $frontendSbom.packageCount -gt 0) "frontend packageCount=$($frontendSbom.packageCount)" $containerEvidence.path
    Add-Check "container security backend sbom hash" ((Test-Sha256 ([string] $backendSbom.sha256)) -and [int64] $backendSbom.byteSize -gt 0) "backend sha256=$($backendSbom.sha256), byteSize=$($backendSbom.byteSize)" $containerEvidence.path
    Add-Check "container security frontend sbom hash" ((Test-Sha256 ([string] $frontendSbom.sha256)) -and [int64] $frontendSbom.byteSize -gt 0) "frontend sha256=$($frontendSbom.sha256), byteSize=$($frontendSbom.byteSize)" $containerEvidence.path
}

$failureCount = @($checks | Where-Object { -not $_.passed }).Count
$result = if ($failureCount -eq 0) { "passed" } else { "failed" }
$resolvedPromotedImagePath = Resolve-ProjectPath $PromotedImageSigningEvidencePath
$resolvedPromotedContainerPath = Resolve-ProjectPath $PromotedContainerSecurityEvidencePath
$promotionActions = @()

if (-not $NoWrite -and -not $NoPromote -and $result -eq "passed") {
    $promotionActions += Promote-Evidence $imageEvidence.path $resolvedPromotedImagePath "image signing"
    $promotionActions += Promote-Evidence $containerEvidence.path $resolvedPromotedContainerPath "container security"
}
elseif ($NoPromote) {
    $promotionActions += "promotion disabled"
}
elseif ($result -ne "passed") {
    $promotionActions += "promotion skipped because finalizer result is failed"
}

$generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath

$report = [ordered]@{
    formatVersion = "osmu.security-evidence-finalize.v1"
    generatedAt = $generatedAt
    result = $result
    failureCount = $failureCount
    allowSyntheticEvidence = [bool] $AllowSyntheticEvidence
    inputs = [ordered]@{
        imageSigningEvidence = $imageEvidence.path
        containerSecurityEvidence = $containerEvidence.path
    }
    promoted = [ordered]@{
        imageSigningEvidence = $resolvedPromotedImagePath
        containerSecurityEvidence = $resolvedPromotedContainerPath
        actions = $promotionActions
    }
    source = [ordered]@{
        imageSigningRunUrl = if ($imageEvidence.parsed) { [string] $imageEvidence.data.sourceRunUrl } else { "" }
        containerSecurityRunUrl = if ($containerEvidence.parsed) { [string] $containerEvidence.data.sourceRunUrl } else { "" }
        containerSecurityArtifactName = if ($containerEvidence.parsed) { [string] $containerEvidence.data.artifactName } else { "" }
    }
    images = [ordered]@{
        backendVersionRef = if ($imageEvidence.parsed) { [string] $imageEvidence.data.backend.versionRef } else { "" }
        backendShaRef = if ($imageEvidence.parsed) { [string] $imageEvidence.data.backend.shaRef } else { "" }
        frontendVersionRef = if ($imageEvidence.parsed) { [string] $imageEvidence.data.frontend.versionRef } else { "" }
        frontendShaRef = if ($imageEvidence.parsed) { [string] $imageEvidence.data.frontend.shaRef } else { "" }
        backendDigest = if ($imageEvidence.parsed) { [string] $imageEvidence.data.backend.digest } else { "" }
        frontendDigest = if ($imageEvidence.parsed) { [string] $imageEvidence.data.frontend.digest } else { "" }
        backendImage = if ($containerEvidence.parsed) { [string] $containerEvidence.data.backendImage } else { "" }
        frontendImage = if ($containerEvidence.parsed) { [string] $containerEvidence.data.frontendImage } else { "" }
    }
    checks = $checks
    decisionRule = "Security evidence finalization passes only when image signing evidence and container scan/SBOM evidence are present, parsed, passed, non-synthetic by default, and promotable to the standard latest evidence paths."
    secretPolicy = "Finalizer copies and summarizes existing evidence JSON only; it does not read or write registry credentials, signing keys, tokens, kubeconfig, or application secrets."
}

$markdownLines = @(
    "# OSMU Security Evidence Finalize",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Failure count: $failureCount",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Inputs",
    "",
    "- Image signing evidence: $($imageEvidence.path)",
    "- Container security evidence: $($containerEvidence.path)",
    "",
    "## Promotion",
    ""
)

foreach ($action in $promotionActions) {
    $markdownLines += "- $action"
}

$markdownLines += ""
$markdownLines += "## Checks"
$markdownLines += ""
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}

if ($failureCount -gt 0) {
    $markdownLines += ""
    $markdownLines += "## Required Next Evidence"
    $markdownLines += ""
    foreach ($check in ($checks | Where-Object { -not $_.passed })) {
        $markdownLines += "- $($check.name): $($check.detail); path=$($check.evidencePath)"
    }
}

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Security evidence finalizer JSON: $resolvedJsonOutputPath"
    Write-Host "Security evidence finalizer markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Security evidence finalization failed: failureCount=$failureCount"
}
