param(
    [ValidateSet("Start", "Stop", "Reset", "Status", "Help")]
    [string] $Action = "Start",
    [switch] $NoBuild,
    [switch] $NoSeed,
    [switch] $Verify
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$startScript = Join-Path $PSScriptRoot "start-local-demo.ps1"
$stopScript = Join-Path $PSScriptRoot "stop-local-demo.ps1"
$envFile = Join-Path $root "infra\local\.env.portfolio"
$envExample = Join-Path $root "infra\local\.env.example"
$composeFile = Join-Path $root "infra\local\docker-compose.yml"

function Show-Usage {
    Write-Host "OSMU portfolio demo"
    Write-Host ""
    Write-Host "Start:  .\run-demo.cmd"
    Write-Host "Stop:   .\run-demo.cmd Stop"
    Write-Host "Reset:  .\run-demo.cmd Reset"
    Write-Host "Status: .\run-demo.cmd Status"
    Write-Host ""
    Write-Host "Ports auto-select when default ports are busy."
}

function Ensure-PortfolioEnv {
    if (-not (Test-Path -LiteralPath $envFile)) {
        Copy-Item -LiteralPath $envExample -Destination $envFile
    }
}

function Read-EnvValue([string] $Name, [string] $DefaultValue) {
    foreach ($line in Get-Content -LiteralPath $envFile) {
        if ($line -match "^$([regex]::Escape($Name))=(.*)$") {
            return $Matches[1].Trim()
        }
    }
    return $DefaultValue
}

function Set-EnvValue([string] $Name, [string] $Value) {
    $lines = Get-Content -LiteralPath $envFile
    $found = $false
    $updated = foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($Name))=") {
            $found = $true
            "$Name=$Value"
        }
        else {
            $line
        }
    }
    if (-not $found) {
        $updated += "$Name=$Value"
    }
    [System.IO.File]::WriteAllLines($envFile, [string[]] $updated, [System.Text.UTF8Encoding]::new($false))
}

function Test-PortInUse([int] $Port) {
    return @(
        Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Where-Object { $_.LocalPort -eq $Port }
    ).Count -gt 0
}

function Test-ComposeServiceRunning([string] $Service) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $id = & docker compose --env-file $envFile -f $composeFile ps -q $Service 2>$null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    return $exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($id | Out-String))
}

function Resolve-DemoPort([string] $Name, [int] $FallbackPort, [string] $Service) {
    $port = [int] (Read-EnvValue $Name $FallbackPort)
    if ((Test-ComposeServiceRunning $Service) -or -not (Test-PortInUse $port)) {
        return $port
    }

    $candidate = $port + 1
    while (Test-PortInUse $candidate) {
        $candidate++
    }
    Set-EnvValue $Name $candidate
    Write-Host "Port $port busy. $Name -> $candidate"
    return $candidate
}

function Prepare-PortfolioPorts {
    $mariadbPort = Resolve-DemoPort "MARIADB_PORT" 3306 "mariadb"
    $minioApiPort = Resolve-DemoPort "MINIO_API_PORT" 9000 "minio"
    $minioConsolePort = Resolve-DemoPort "MINIO_CONSOLE_PORT" 9001 "minio"
    if ($minioConsolePort -eq $minioApiPort) {
        $candidate = $minioConsolePort + 1
        while (Test-PortInUse $candidate -or $candidate -eq $minioApiPort) {
            $candidate++
        }
        Set-EnvValue "MINIO_CONSOLE_PORT" $candidate
        Write-Host "MINIO_CONSOLE_PORT -> $candidate"
        $minioConsolePort = $candidate
    }
    $backendPort = Resolve-DemoPort "BACKEND_PORT" 8080 "backend"
    $frontendPort = Resolve-DemoPort "FRONTEND_PORT" 5173 "frontend"

    Set-EnvValue "VITE_API_BASE_URL" "http://localhost:$backendPort/api"
    Set-EnvValue "OSMU_STORAGE_PRESIGNED_ENDPOINT" "http://localhost:$minioApiPort"
    Set-EnvValue "OSMU_STORAGE_CORS_ALLOWED_ORIGINS" "http://localhost:$frontendPort,http://127.0.0.1:$frontendPort"
    Set-EnvValue "MINIO_API_CORS_ALLOW_ORIGIN" "http://localhost:$frontendPort,http://127.0.0.1:$frontendPort"
    Set-EnvValue "OSMU_STORAGE_CORS_ENABLED" "false"
    Set-EnvValue "OSMU_ACCESS_KEY_MC_PATH" "/opt/osmu-tools/mc"
}

Ensure-PortfolioEnv

switch ($Action) {
    "Help" {
        Show-Usage
        exit 0
    }
    "Start" {
        Prepare-PortfolioPorts
        $startArgs = @{
            EnvFile = $envFile
            EnvExample = $envExample
            NoBuild = $NoBuild
            SeedDemo = -not $NoSeed
            VerifyDemo = $Verify
        }
        & $startScript @startArgs
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Portfolio stop: .\run-demo.cmd Stop"
            Write-Host "Portfolio reset: .\run-demo.cmd Reset"
        }
        exit $LASTEXITCODE
    }
    "Stop" {
        & $stopScript -EnvFile $envFile -EnvExample $envExample
        exit $LASTEXITCODE
    }
    "Reset" {
        & $stopScript -EnvFile $envFile -EnvExample $envExample -ResetData
        exit $LASTEXITCODE
    }
    "Status" {
        & docker compose --env-file $envFile -f $composeFile ps
        exit $LASTEXITCODE
    }
}