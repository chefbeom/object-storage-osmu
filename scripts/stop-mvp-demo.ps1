param(
    [ValidateSet("auto", "docker", "prototype", "mock")]
    [string] $Mode = "auto",
    [int] $BackendPort = 8080,
    [int] $FrontendPort = 5173,
    [int] $ApiPort = 8080,
    [string] $LogDir = ".\.osmu-run\mvp-demo",
    [switch] $ResetData,
    [switch] $ForcePorts
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Invoke-ProjectScript([string] $ScriptName, [string[]] $Arguments = @()) {
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    Write-Host "    $ScriptName $($Arguments -join ' ')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptName failed with exit code $LASTEXITCODE."
    }
}

function Join-RunPath([string] $Name) {
    return Join-Path $LogDir $Name
}

$resolvedLogDir = Resolve-ProjectPath $LogDir
$metadataPath = Join-Path $resolvedLogDir "latest-mvp-demo.json"
$selectedMode = $Mode
if ($Mode -eq "auto" -and (Test-Path -LiteralPath $metadataPath)) {
    try {
        $metadata = Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json
        if ($metadata.selectedMode) {
            $selectedMode = [string]$metadata.selectedMode
        }
    }
    catch {
        $selectedMode = "auto"
    }
}

if ($selectedMode -eq "auto") {
    Invoke-ProjectScript "stop-local-demo.ps1"
    Invoke-ProjectScript "stop-local-prototype.ps1" @(
        "-LogDir", (Join-RunPath "prototype"),
        "-BackendPort", "$BackendPort",
        "-FrontendPort", "$FrontendPort",
        "-ForcePorts"
    )
    Invoke-ProjectScript "stop-frontend-mock-demo.ps1" @(
        "-LogDir", (Join-RunPath "mock"),
        "-ForcePorts",
        "-Ports", "$ApiPort", "$FrontendPort"
    )
}
elseif ($selectedMode -eq "docker") {
    $stopArgs = @()
    if ($ResetData) {
        $stopArgs += "-ResetData"
    }
    Invoke-ProjectScript "stop-local-demo.ps1" $stopArgs
}
elseif ($selectedMode -eq "prototype") {
    $stopArgs = @(
        "-LogDir", (Join-RunPath "prototype"),
        "-BackendPort", "$BackendPort",
        "-FrontendPort", "$FrontendPort"
    )
    if ($ForcePorts) {
        $stopArgs += "-ForcePorts"
    }
    Invoke-ProjectScript "stop-local-prototype.ps1" $stopArgs
}
else {
    $stopArgs = @(
        "-LogDir", (Join-RunPath "mock"),
        "-Ports", "$ApiPort", "$FrontendPort"
    )
    if ($ForcePorts) {
        $stopArgs += "-ForcePorts"
    }
    Invoke-ProjectScript "stop-frontend-mock-demo.ps1" $stopArgs
}

if (Test-Path -LiteralPath $metadataPath) {
    Remove-Item -LiteralPath $metadataPath -Force
}

Write-Host "OSMU MVP demo stopped."
