param(
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [switch] $NoBuild,
    [switch] $SkipWait,
    [switch] $SeedDemo,
    [switch] $VerifyDemo,
    [switch] $SkipS3AccessKeySmoke,
    [string] $DemoPassword = "DemoPassword!23",
    [string] $DemoOutputPath = "",
    [int] $WaitTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

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

function Assert-DockerDaemon() {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & docker info --format "{{json .ServerVersion}}" 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($exitCode -ne 0) {
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        throw "Docker daemon is not available. Start Docker Desktop and rerun this script."
    }
}

function Wait-HttpOk($Name, $Url, $TimeoutSeconds) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = ""
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
                Write-Host "PASS $Name $Url"
                return
            }
            $lastError = "HTTP $($response.StatusCode)"
        }
        catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Seconds 3
    }
    throw "$Name did not become ready: $Url ($lastError)"
}

$script:ResolvedEnvFile = Resolve-ProjectPath $EnvFile
$resolvedEnvExample = Resolve-ProjectPath $EnvExample
$script:ResolvedComposeFile = Resolve-ProjectPath $ComposeFile
Use-OsmuDockerConfig $root | Out-Null
New-Item -ItemType Directory -Force -Path (Resolve-ProjectPath ".osmu-run") | Out-Null

if (-not (Test-Path -LiteralPath $script:ResolvedEnvFile)) {
    Step "Create local env"
    Copy-Item -LiteralPath $resolvedEnvExample -Destination $script:ResolvedEnvFile
    Write-Host "Created $script:ResolvedEnvFile from $resolvedEnvExample"
}

Step "Validate compose config"
Invoke-Compose @("config", "--quiet")

Step "Check Docker daemon"
Assert-DockerDaemon

Step "Start OSMU local demo"
$upArgs = @("up", "-d")
if (-not $NoBuild) {
    $upArgs += "--build"
}
Invoke-Compose $upArgs

Step "Containers"
Invoke-Compose @("ps")

$backendPort = Read-EnvValue $script:ResolvedEnvFile "BACKEND_PORT" "8080"
$frontendPort = Read-EnvValue $script:ResolvedEnvFile "FRONTEND_PORT" "5173"
$minioApiPort = Read-EnvValue $script:ResolvedEnvFile "MINIO_API_PORT" "9000"
$minioConsolePort = Read-EnvValue $script:ResolvedEnvFile "MINIO_CONSOLE_PORT" "9001"
$adminLoginId = Read-EnvValue $script:ResolvedEnvFile "OSMU_ADMIN_LOGIN_ID" "admin"
$adminPassword = Read-EnvValue $script:ResolvedEnvFile "OSMU_ADMIN_PASSWORD" "password"
$minioUser = Read-EnvValue $script:ResolvedEnvFile "MINIO_ROOT_USER" "minioadmin"
$minioPassword = Read-EnvValue $script:ResolvedEnvFile "MINIO_ROOT_PASSWORD" "minioadmin"

$backendApi = "http://localhost:$backendPort/api"
$frontendUrl = "http://localhost:$frontendPort"
$minioApiUrl = "http://localhost:$minioApiPort"
$minioConsoleUrl = "http://localhost:$minioConsolePort"

if (-not $SkipWait) {
    Step "Wait for service readiness"
    Wait-HttpOk "backend" "$backendApi/health" $WaitTimeoutSeconds
    Wait-HttpOk "database" "$backendApi/database/health" $WaitTimeoutSeconds
    Wait-HttpOk "storage" "$backendApi/storage/health" $WaitTimeoutSeconds
    Wait-HttpOk "frontend" $frontendUrl $WaitTimeoutSeconds
}

if ($SeedDemo) {
    Step "Seed demo data"
    $seedScript = Join-Path $PSScriptRoot "seed-local-demo.ps1"
    $seedOutputPath = Resolve-ProjectPath $(if ($DemoOutputPath) { $DemoOutputPath } else { ".osmu-run\latest-demo.json" })
    $seedArgs = @(
        "-ApiBase", $backendApi,
        "-AdminLoginId", $adminLoginId,
        "-AdminPassword", $adminPassword,
        "-DemoPassword", $DemoPassword,
        "-DemoOutputPath", $seedOutputPath
    )
    $seedExitCode = Invoke-OsmuPowerShellScript $seedScript $seedArgs
    if ($seedExitCode -ne 0) {
        throw "Demo data seed failed."
    }
}

if ($VerifyDemo) {
    Step "Verify demo data"
    $verifyScript = Join-Path $PSScriptRoot "verify-local-demo.ps1"
    $verifyOutputPath = Resolve-ProjectPath $(if ($DemoOutputPath) { $DemoOutputPath } else { ".osmu-run\latest-demo.json" })
    $verifyArgs = @(
        "-FrontendBase", $frontendUrl,
        "-ApiBase", $backendApi,
        "-AdminLoginId", $adminLoginId,
        "-AdminPassword", $adminPassword,
        "-DemoPassword", $DemoPassword,
        "-DemoCredentialPath", $verifyOutputPath
    )
    if ($SeedDemo) {
        $verifyArgs += "-SeedIfMissing"
    }
    if ($SkipS3AccessKeySmoke) {
        $verifyArgs += "-SkipS3AccessKeySmoke"
    }
    $verifyExitCode = Invoke-OsmuPowerShellScript $verifyScript $verifyArgs
    if ($verifyExitCode -ne 0) {
        throw "Demo data verification failed."
    }
}

Step "Demo URLs"
Write-Host "Frontend:     $frontendUrl"
Write-Host "Backend API:  $backendApi"
Write-Host "MinIO API:    $minioApiUrl"
Write-Host "MinIO Console:$minioConsoleUrl"
Write-Host ""
Write-Host "OSMU login:   $adminLoginId / $adminPassword"
Write-Host "MinIO login:  $minioUser / $minioPassword"
if ($SeedDemo) {
    Write-Host "Demo data:    $seedOutputPath"
}
Write-Host ""
Write-Host "Stop:         powershell -ExecutionPolicy Bypass -File .\scripts\stop-local-demo.ps1"
Write-Host "Reset data:   powershell -ExecutionPolicy Bypass -File .\scripts\stop-local-demo.ps1 -ResetData"
