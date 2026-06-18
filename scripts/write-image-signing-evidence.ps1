param(
    [string] $Version = "",
    [string] $CommitSha = "",
    [string] $BackendVersionRef = "",
    [string] $BackendShaRef = "",
    [string] $FrontendVersionRef = "",
    [string] $FrontendShaRef = "",
    [string] $BackendDigest = "",
    [string] $FrontendDigest = "",
    [string] $SourceRunUrl = "",
    [string] $OutputPath = ".\.osmu-run\latest-image-signing-evidence.json",
    [switch] $BackendVersionSignatureVerified,
    [switch] $BackendShaSignatureVerified,
    [switch] $FrontendVersionSignatureVerified,
    [switch] $FrontendShaSignatureVerified,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function New-Check([string] $Name, [bool] $Passed, [string] $Detail) {
    return [ordered]@{
        name = $Name
        passed = $Passed
        detail = $Detail
    }
}

function Test-Digest([string] $Value) {
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -match "^sha256:[0-9a-fA-F]{64}$" -and $Value -notmatch "^sha256:0{64}$"
}

$checks = @(
    (New-Check "version-provided" (-not [string]::IsNullOrWhiteSpace($Version)) "version=$Version"),
    (New-Check "commit-sha-provided" (-not [string]::IsNullOrWhiteSpace($CommitSha)) "commitSha=$CommitSha"),
    (New-Check "backend-version-ref-provided" (-not [string]::IsNullOrWhiteSpace($BackendVersionRef)) "backendVersionRef=$BackendVersionRef"),
    (New-Check "backend-sha-ref-provided" (-not [string]::IsNullOrWhiteSpace($BackendShaRef)) "backendShaRef=$BackendShaRef"),
    (New-Check "frontend-version-ref-provided" (-not [string]::IsNullOrWhiteSpace($FrontendVersionRef)) "frontendVersionRef=$FrontendVersionRef"),
    (New-Check "frontend-sha-ref-provided" (-not [string]::IsNullOrWhiteSpace($FrontendShaRef)) "frontendShaRef=$FrontendShaRef"),
    (New-Check "backend-digest-provided" (Test-Digest $BackendDigest) "backendDigest=$BackendDigest"),
    (New-Check "frontend-digest-provided" (Test-Digest $FrontendDigest) "frontendDigest=$FrontendDigest"),
    (New-Check "backend-version-signature-verified" ([bool] $BackendVersionSignatureVerified) "Cosign verify passed for backend version tag"),
    (New-Check "backend-sha-signature-verified" ([bool] $BackendShaSignatureVerified) "Cosign verify passed for backend commit SHA tag"),
    (New-Check "frontend-version-signature-verified" ([bool] $FrontendVersionSignatureVerified) "Cosign verify passed for frontend version tag"),
    (New-Check "frontend-sha-signature-verified" ([bool] $FrontendShaSignatureVerified) "Cosign verify passed for frontend commit SHA tag")
)

$failureCount = @($checks | Where-Object { -not $_.passed }).Count
$result = if ($failureCount -eq 0) { "passed" } else { "failed" }
$resolvedOutputPath = Resolve-ProjectPath $OutputPath

$evidence = [ordered]@{
    formatVersion = "osmu.image-signing-evidence.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    result = $result
    failureCount = $failureCount
    version = $Version
    commitSha = $CommitSha
    sourceRunUrl = $SourceRunUrl
    issuer = "https://token.actions.githubusercontent.com"
    signingMode = "keyless-github-actions-oidc"
    backend = [ordered]@{
        versionRef = $BackendVersionRef
        shaRef = $BackendShaRef
        digest = $BackendDigest
        versionSignatureVerified = [bool] $BackendVersionSignatureVerified
        shaSignatureVerified = [bool] $BackendShaSignatureVerified
    }
    frontend = [ordered]@{
        versionRef = $FrontendVersionRef
        shaRef = $FrontendShaRef
        digest = $FrontendDigest
        versionSignatureVerified = [bool] $FrontendVersionSignatureVerified
        shaSignatureVerified = [bool] $FrontendShaSignatureVerified
    }
    checks = $checks
    secretPolicy = "Evidence contains public image references, optional digests, workflow URL, and signature verification flags only; it does not contain registry credentials or tokens."
}

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
    $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8
    Write-Host "Image signing evidence: $resolvedOutputPath"
}

Write-Host "Image signing evidence result: $result"
Write-Host "Backend refs: $BackendVersionRef, $BackendShaRef"
Write-Host "Frontend refs: $FrontendVersionRef, $FrontendShaRef"

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Image signing evidence is not passed: failureCount=$failureCount"
}
