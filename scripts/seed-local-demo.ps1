param(
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ApiBase = "",
    [string] $AdminLoginId = "",
    [string] $AdminPassword = "",
    [string] $DemoPassword = "DemoPassword!23",
    [string] $Suffix = "",
    [string] $DemoOutputPath = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")

function Resolve-ProjectPath($path) {
    $path = Convert-OsmuPathSeparators $path
    if ([System.IO.Path]::IsPathRooted($path)) {
        return $path
    }
    return Join-Path $root $path
}

function Read-EnvValue($path, $name, $defaultValue) {
    $resolved = Resolve-Path -LiteralPath $path -ErrorAction Stop
    foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $resolved.Path) {
        if ($line -match "^\s*#" -or $line -match "^\s*$") {
            continue
        }
        if ($line -match "^\s*$([regex]::Escape($name))=(.*)$") {
            return $Matches[1].Trim()
        }
    }
    return $defaultValue
}

$resolvedEnvFile = Resolve-ProjectPath $EnvFile
$resolvedEnvExample = Resolve-ProjectPath $EnvExample
if (-not (Test-Path -LiteralPath $resolvedEnvFile)) {
    $resolvedEnvFile = $resolvedEnvExample
}

if (-not $ApiBase) {
    $backendPort = Read-EnvValue $resolvedEnvFile "BACKEND_PORT" "8080"
    $ApiBase = "http://localhost:$backendPort/api"
}

if (-not $AdminLoginId) {
    $AdminLoginId = Read-EnvValue $resolvedEnvFile "OSMU_ADMIN_LOGIN_ID" "admin"
}

if (-not $AdminPassword) {
    $AdminPassword = Read-EnvValue $resolvedEnvFile "OSMU_ADMIN_PASSWORD" "password"
}

if (-not $DemoOutputPath) {
    $DemoOutputPath = Join-Path $root ".osmu-run\latest-demo.json"
}
$DemoOutputPath = Resolve-ProjectPath $DemoOutputPath

$seedScript = Join-Path $PSScriptRoot "seed-lightweight-demo.ps1"
$seedArgs = @(
    "-ApiBase", $ApiBase,
    "-AdminLoginId", $AdminLoginId,
    "-AdminPassword", $AdminPassword,
    "-DemoPassword", $DemoPassword,
    "-DemoOutputPath", $DemoOutputPath
)
if ($Suffix) {
    $seedArgs += @("-Suffix", $Suffix)
}

$seedExitCode = Invoke-OsmuPowerShellScript $seedScript $seedArgs
if ($seedExitCode -ne 0) {
    throw "Local demo seed failed."
}
