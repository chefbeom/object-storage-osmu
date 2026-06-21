param(
    [string] $RoadmapPath = ".\dev-docs\development-roadmap.md"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-Contains([string] $Content, [string] $Expected, [string] $Label) {
    if (-not $Content.Contains($Expected)) {
        throw "$Label does not contain expected text: $Expected"
    }
}

function Assert-NotContains([string] $Content, [string] $Unexpected, [string] $Label) {
    if ($Content.Contains($Unexpected)) {
        throw "$Label contains unexpected text: $Unexpected"
    }
}

function Decode-Utf8Base64([string] $Value) {
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

$resolvedPath = Resolve-ProjectPath $RoadmapPath
if (-not (Test-Path -LiteralPath $resolvedPath)) {
    throw "Development roadmap missing: $resolvedPath"
}

$content = Get-Content -Raw -LiteralPath $resolvedPath

Assert-Contains $content "OSMU Development Roadmap" "Development roadmap"
Assert-Contains $content "S3-compatible replacement layer" "Development roadmap"
Assert-Contains $content 'docker-durable-demo-verified' "Development roadmap"
Assert-Contains $content "Production Operations Evidence" "Development roadmap"
Assert-Contains $content (Decode-Utf8Base64 "S3ViZXJuZXRlcyBEUiBmaW5hbGl6ZXIgYHJlc3VsdD1yZWFkeWA=") "Development roadmap"
Assert-Contains $content 'operations readiness convergence `result=ready`' "Development roadmap"
Assert-Contains $content 'Kubernetes operations report sync `result=applied`' "Development roadmap"
Assert-Contains $content "Data-flow storage transition plan" "Development roadmap"
Assert-Contains $content "target query-plan evidence" "Development roadmap"
Assert-Contains $content "Enterprise auth target smoke" "Development roadmap"
Assert-Contains $content "scope-out evidence" "Development roadmap"
Assert-Contains $content "S3 client smoke" "Development roadmap"
Assert-Contains $content "role scope" "Development roadmap"
Assert-NotContains $content "edge parity" "Development roadmap"

Write-Host "Development roadmap verified."
Write-Host "Development roadmap: $resolvedPath"
