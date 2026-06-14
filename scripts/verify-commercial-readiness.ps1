param(
    [string] $CommercialReadinessPath = ".\dev-docs\commercial-readiness.md"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    if (-not $content.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

$resolvedPath = Resolve-ProjectPath $CommercialReadinessPath
if (-not (Test-Path -LiteralPath $resolvedPath)) {
    throw "Commercial readiness draft missing: $resolvedPath"
}

$content = Get-Content -Raw -LiteralPath $resolvedPath

Assert-Contains $content "private S3-compatible object storage platform" "Commercial readiness draft"
Assert-Contains $content "streaming/media teams" "Commercial readiness draft"
Assert-Contains $content "Current sellable state: local lightweight demo only." "Commercial readiness draft"
Assert-Contains $content "durable pilot and production sale remain NO-GO" "Commercial readiness draft"
Assert-Contains $content "annual B2B subscription per deployed environment" "Commercial readiness draft"
Assert-Contains $content "time-limited pilot license" "Commercial readiness draft"
Assert-Contains $content "stored capacity tier" "Commercial readiness draft"
Assert-Contains $content "Do not add hard runtime lockouts before product/legal review." "Commercial readiness draft"
Assert-Contains $content "Final prices: pending market validation and legal/commercial approval." "Commercial readiness draft"
Assert-Contains $content "Docker/MariaDB/MinIO integration gate passes." "Commercial readiness draft"
Assert-Contains $content "Real S3 client gate passes with AWS CLI or MinIO Client." "Commercial readiness draft"
Assert-Contains $content "Browser E2E gate passes." "Commercial readiness draft"
Assert-Contains $content 'Image publish/sign workflow has a successful GitHub-hosted run with `publish=true`.' "Commercial readiness draft"
Assert-Contains $content "Final legal/commercial approval: pending." "Commercial readiness draft"

Write-Host "Commercial readiness draft verified."
Write-Host "Commercial readiness: $resolvedPath"
