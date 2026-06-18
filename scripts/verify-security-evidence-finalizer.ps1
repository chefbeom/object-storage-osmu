param(
    [string] $OutputDirectory = ".\.osmu-run\security-evidence-finalizer-self-test"
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

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$sourceDirectory = Join-Path $resolvedOutputDirectory "source"
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

& powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-ProjectPath ".\scripts\verify-security-evidence-writers.ps1") `
    -OutputDirectory $sourceDirectory
if ($LASTEXITCODE -ne 0) {
    throw "verify-security-evidence-writers.ps1 failed with exit code $LASTEXITCODE."
}

$imageEvidencePath = Join-Path $sourceDirectory "image-signing-evidence.json"
$containerEvidencePath = Join-Path $sourceDirectory "container-security-evidence.json"
$promotedImagePath = Join-Path $resolvedOutputDirectory "promoted-image-signing-evidence.json"
$promotedContainerPath = Join-Path $resolvedOutputDirectory "promoted-container-security-evidence.json"
$finalizeJsonPath = Join-Path $resolvedOutputDirectory "security-evidence-finalize.json"
$finalizeMarkdownPath = Join-Path $resolvedOutputDirectory "security-evidence-finalize.md"

& powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-ProjectPath ".\scripts\finalize-security-evidence.ps1") `
    -ImageSigningEvidencePath $imageEvidencePath `
    -ContainerSecurityEvidencePath $containerEvidencePath `
    -PromotedImageSigningEvidencePath $promotedImagePath `
    -PromotedContainerSecurityEvidencePath $promotedContainerPath `
    -JsonOutputPath $finalizeJsonPath `
    -MarkdownOutputPath $finalizeMarkdownPath `
    -AllowSyntheticEvidence `
    -FailIfNotPassed
if ($LASTEXITCODE -ne 0) {
    throw "finalize-security-evidence.ps1 failed with exit code $LASTEXITCODE."
}

Assert-FileResultPassed $finalizeJsonPath "Security evidence finalizer" "osmu.security-evidence-finalize.v1"
Assert-FileResultPassed $promotedImagePath "Promoted image signing" "osmu.image-signing-evidence.v1"
Assert-FileResultPassed $promotedContainerPath "Promoted container security" "osmu.container-security-evidence.v1"

$markdown = Get-Content -Raw -LiteralPath $finalizeMarkdownPath
Assert-Contains $markdown "# OSMU Security Evidence Finalize" "Security evidence finalizer markdown"
Assert-Contains $markdown "Result: passed" "Security evidence finalizer markdown"
Assert-Contains $markdown "promoted image signing evidence" "Security evidence finalizer markdown"

$rejectedJsonPath = Join-Path $resolvedOutputDirectory "rejected-security-evidence-finalize.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-ProjectPath ".\scripts\finalize-security-evidence.ps1") `
    -ImageSigningEvidencePath $imageEvidencePath `
    -ContainerSecurityEvidencePath $containerEvidencePath `
    -JsonOutputPath $rejectedJsonPath `
    -MarkdownOutputPath (Join-Path $resolvedOutputDirectory "rejected-security-evidence-finalize.md") `
    -NoPromote
if ($LASTEXITCODE -ne 0) {
    throw "finalize-security-evidence.ps1 synthetic rejection check failed with exit code $LASTEXITCODE."
}

$rejectedEvidence = Get-Content -Raw -LiteralPath $rejectedJsonPath | ConvertFrom-Json
if ($rejectedEvidence.result -ne "failed") {
    throw "Synthetic security evidence must be rejected unless -AllowSyntheticEvidence is provided."
}

Write-Host "Security evidence finalizer verified."
Write-Host "Finalizer report: $finalizeJsonPath"
Write-Host "Promoted image evidence: $promotedImagePath"
Write-Host "Promoted container evidence: $promotedContainerPath"
