param(
    [string] $OutputDirectory = ".\.osmu-run\security-evidence-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-FileResultPassed([string] $path, [string] $label, [string] $formatVersion) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "$label evidence missing: $resolvedPath"
    }
    $evidence = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
    if ($evidence.formatVersion -ne $formatVersion) {
        throw "$label formatVersion mismatch: $($evidence.formatVersion)"
    }
    if ($evidence.result -ne "passed") {
        throw "$label result must be passed: $($evidence.result)"
    }
    if ([int] $evidence.failureCount -ne 0) {
        throw "$label failureCount must be zero: $($evidence.failureCount)"
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$backendSbomPath = Join-Path $resolvedOutputDirectory "backend.spdx.json"
$frontendSbomPath = Join-Path $resolvedOutputDirectory "frontend.spdx.json"
$containerEvidencePath = Join-Path $resolvedOutputDirectory "container-security-evidence.json"
$signingEvidencePath = Join-Path $resolvedOutputDirectory "image-signing-evidence.json"

$sbomTemplate = [ordered]@{
    spdxVersion = "SPDX-2.3"
    dataLicense = "CC0-1.0"
    SPDXID = "SPDXRef-DOCUMENT"
    name = "osmu-self-test"
    documentNamespace = "https://example.invalid/osmu/self-test"
    creationInfo = [ordered]@{
        created = "2026-06-16T00:00:00Z"
        creators = @("Tool: osmu-self-test")
    }
    packages = @(
        [ordered]@{
            name = "osmu-placeholder"
            SPDXID = "SPDXRef-Package-osmu-placeholder"
            downloadLocation = "NOASSERTION"
            filesAnalyzed = $false
        }
    )
}

$sbomTemplate | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $backendSbomPath -Encoding UTF8
$sbomTemplate | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $frontendSbomPath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-ProjectPath ".\scripts\write-container-security-evidence.ps1") `
    -BackendImage "osmu-backend:self-test" `
    -FrontendImage "osmu-frontend:self-test" `
    -BackendSbomPath $backendSbomPath `
    -FrontendSbomPath $frontendSbomPath `
    -OutputPath $containerEvidencePath `
    -SourceRunUrl "https://example.invalid/actions/runs/1" `
    -CommitSha "0000000000000000000000000000000000000000" `
    -ArtifactName "osmu-sbom-self-test" `
    -BackendScanPassed `
    -FrontendScanPassed `
    -FailIfNotPassed
if ($LASTEXITCODE -ne 0) {
    throw "write-container-security-evidence.ps1 failed with exit code $LASTEXITCODE."
}

& powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-ProjectPath ".\scripts\write-image-signing-evidence.ps1") `
    -Version "v0.0.0-self-test" `
    -CommitSha "0000000000000000000000000000000000000000" `
    -BackendVersionRef "ghcr.io/example/osmu-backend:v0.0.0-self-test" `
    -BackendShaRef "ghcr.io/example/osmu-backend:0000000000000000000000000000000000000000" `
    -FrontendVersionRef "ghcr.io/example/osmu-frontend:v0.0.0-self-test" `
    -FrontendShaRef "ghcr.io/example/osmu-frontend:0000000000000000000000000000000000000000" `
    -BackendDigest "sha256:1111111111111111111111111111111111111111111111111111111111111111" `
    -FrontendDigest "sha256:2222222222222222222222222222222222222222222222222222222222222222" `
    -SourceRunUrl "https://example.invalid/actions/runs/2" `
    -OutputPath $signingEvidencePath `
    -BackendVersionSignatureVerified `
    -BackendShaSignatureVerified `
    -FrontendVersionSignatureVerified `
    -FrontendShaSignatureVerified `
    -FailIfNotPassed
if ($LASTEXITCODE -ne 0) {
    throw "write-image-signing-evidence.ps1 failed with exit code $LASTEXITCODE."
}

Assert-FileResultPassed $containerEvidencePath "Container security" "osmu.container-security-evidence.v1"
Assert-FileResultPassed $signingEvidencePath "Image signing" "osmu.image-signing-evidence.v1"

Write-Host "Security evidence writers verified."
Write-Host "Container security evidence: $containerEvidencePath"
Write-Host "Image signing evidence: $signingEvidencePath"
