param(
    [string] $BackendImage = "",
    [string] $FrontendImage = "",
    [string] $BackendSbomPath = ".\.osmu-run\sbom\backend.spdx.json",
    [string] $FrontendSbomPath = ".\.osmu-run\sbom\frontend.spdx.json",
    [string] $OutputPath = ".\.osmu-run\latest-container-security-evidence.json",
    [string] $SourceRunUrl = "",
    [string] $CommitSha = "",
    [string] $ArtifactName = "",
    [switch] $BackendScanPassed,
    [switch] $FrontendScanPassed,
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

function Read-SbomSummary([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [ordered]@{
            label = $label
            path = $resolvedPath
            exists = $false
            parsed = $false
            valid = $false
            spdxVersion = ""
            packageCount = 0
            byteSize = 0
            sha256 = ""
            detail = "SBOM file not found"
        }
    }

    try {
        $sbom = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
        $spdxVersion = [string] $sbom.spdxVersion
        $packages = @($sbom.packages)
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPath
        $fileInfo = Get-Item -LiteralPath $resolvedPath
        $valid = $spdxVersion.StartsWith("SPDX-") -and $packages.Count -gt 0
        return [ordered]@{
            label = $label
            path = $resolvedPath
            exists = $true
            parsed = $true
            valid = $valid
            spdxVersion = $spdxVersion
            packageCount = $packages.Count
            byteSize = [int64] $fileInfo.Length
            sha256 = $hash.Hash.ToLowerInvariant()
            detail = if ($valid) { "valid SPDX SBOM" } else { "SBOM must include spdxVersion and at least one package" }
        }
    }
    catch {
        return [ordered]@{
            label = $label
            path = $resolvedPath
            exists = $true
            parsed = $false
            valid = $false
            spdxVersion = ""
            packageCount = 0
            byteSize = 0
            sha256 = ""
            detail = $_.Exception.Message
        }
    }
}

$backendSbom = Read-SbomSummary $BackendSbomPath "backend"
$frontendSbom = Read-SbomSummary $FrontendSbomPath "frontend"
$checks = @(
    [ordered]@{
        name = "backend-trivy-high-critical-scan"
        passed = [bool] $BackendScanPassed
        detail = "Trivy high/critical scan passed flag"
    },
    [ordered]@{
        name = "frontend-trivy-high-critical-scan"
        passed = [bool] $FrontendScanPassed
        detail = "Trivy high/critical scan passed flag"
    },
    [ordered]@{
        name = "backend-spdx-sbom"
        passed = [bool] $backendSbom.valid
        detail = $backendSbom.detail
        path = $backendSbom.path
    },
    [ordered]@{
        name = "backend-spdx-sbom-sha256"
        passed = -not [string]::IsNullOrWhiteSpace([string] $backendSbom.sha256)
        detail = "sha256=$($backendSbom.sha256), byteSize=$($backendSbom.byteSize)"
        path = $backendSbom.path
    },
    [ordered]@{
        name = "frontend-spdx-sbom"
        passed = [bool] $frontendSbom.valid
        detail = $frontendSbom.detail
        path = $frontendSbom.path
    },
    [ordered]@{
        name = "frontend-spdx-sbom-sha256"
        passed = -not [string]::IsNullOrWhiteSpace([string] $frontendSbom.sha256)
        detail = "sha256=$($frontendSbom.sha256), byteSize=$($frontendSbom.byteSize)"
        path = $frontendSbom.path
    }
)

$failureCount = @($checks | Where-Object { -not $_.passed }).Count
$result = if ($failureCount -eq 0) { "passed" } else { "failed" }
$resolvedOutputPath = Resolve-ProjectPath $OutputPath

$evidence = [ordered]@{
    formatVersion = "osmu.container-security-evidence.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    result = $result
    failureCount = $failureCount
    backendImage = $BackendImage
    frontendImage = $FrontendImage
    commitSha = $CommitSha
    sourceRunUrl = $SourceRunUrl
    artifactName = $ArtifactName
    scans = [ordered]@{
        severity = "CRITICAL,HIGH"
        ignoreUnfixed = $true
        backendScanPassed = [bool] $BackendScanPassed
        frontendScanPassed = [bool] $FrontendScanPassed
    }
    sbom = [ordered]@{
        format = "SPDX JSON"
        backend = $backendSbom
        frontend = $frontendSbom
    }
    checks = $checks
    secretPolicy = "Evidence contains image names, SBOM metadata, workflow URL, and scan pass flags only; it does not contain registry credentials or tokens."
}

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
    $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8
    Write-Host "Container security evidence: $resolvedOutputPath"
}

Write-Host "Container security evidence result: $result"
Write-Host "Backend SBOM: $($backendSbom.detail)"
Write-Host "Frontend SBOM: $($frontendSbom.detail)"

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Container security evidence is not passed: failureCount=$failureCount"
}
