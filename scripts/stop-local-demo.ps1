param(
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [switch] $ResetData
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return $path
    }
    return Join-Path $root $path
}

function Test-DockerDaemon() {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & docker info --format "{{json .ServerVersion}}" *> $null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    return $exitCode -eq 0
}

function Invoke-Compose([string[]] $ComposeArgs) {
    Push-Location $root
    try {
        & docker compose --env-file $script:ResolvedEnvFile -f $script:ResolvedComposeFile @ComposeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose failed: $($ComposeArgs -join ' ')"
        }
    }
    finally {
        Pop-Location
    }
}

$script:ResolvedEnvFile = Resolve-ProjectPath $EnvFile
$resolvedEnvExample = Resolve-ProjectPath $EnvExample
$script:ResolvedComposeFile = Resolve-ProjectPath $ComposeFile
Use-OsmuDockerConfig $root | Out-Null

if (-not (Test-Path -LiteralPath $script:ResolvedEnvFile)) {
    $script:ResolvedEnvFile = $resolvedEnvExample
}

if (-not (Test-DockerDaemon)) {
    if ($ResetData) {
        throw "Docker daemon is not available. Start Docker Desktop before removing local demo volumes."
    }
    Write-Host "Docker daemon is not available. No running containers were stopped."
    exit 0
}

$downArgs = @("down")
if ($ResetData) {
    $downArgs += "-v"
}

Invoke-Compose $downArgs

if ($ResetData) {
    Write-Host "OSMU local demo stopped and volumes removed."
}
else {
    Write-Host "OSMU local demo stopped. Volumes kept."
}
