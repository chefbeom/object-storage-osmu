param(
    [string] $JavaHome = "",
    [int] $BackendPort = 8080,
    [int] $FrontendPort = 5173,
    [string] $LogDir = ".\.osmu-run",
    [string] $GradleUserHome = ".\.osmu-run\gradle-home",
    [switch] $SkipBackend,
    [switch] $SkipFrontend
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$runDir = Join-Path $root $LogDir
. (Join-Path $PSScriptRoot "java-toolchain.ps1")
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

function Normalize-ProcessPath() {
    Normalize-OsmuProcessPath
}

function Use-JavaHome($path) {
    Use-OsmuJavaHome $path | Out-Null
}

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Wait-Http($url, $name, $timeoutSeconds = 90) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    do {
        try {
            $response = Invoke-WebRequest -Method GET -Uri $url -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                Write-Host "$name ready: $url"
                return
            }
        }
        catch {
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    throw "$name did not become ready: $url"
}

function Get-ListeningPortProcessIds($port) {
    $pattern = "^\s*TCP\s+\S+:$port\s+\S+\s+LISTENING\s+(\d+)\s*$"
    return netstat -ano |
        Select-String -Pattern $pattern |
        ForEach-Object { [int]$_.Matches[0].Groups[1].Value } |
        Sort-Object -Unique
}

function Assert-PortAvailable($port, $name) {
    $listeners = @(Get-ListeningPortProcessIds $port)
    if ($listeners.Count -gt 0) {
        throw "$name port $port is already in use by pid(s): $($listeners -join ', '). Run .\scripts\stop-local-prototype.ps1 -ForcePorts or choose another port."
    }
}

function Start-LoggedProcess($name, $workingDirectory, [string[]] $arguments, $pidPath) {
    $stdoutPath = Join-Path $runDir "$name.out.log"
    $stderrPath = Join-Path $runDir "$name.err.log"
    $process = Start-Process `
        -FilePath "powershell" `
        -ArgumentList $arguments `
        -WorkingDirectory $workingDirectory `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -PassThru

    Set-Content -LiteralPath $pidPath -Value $process.Id -Encoding ASCII
    Write-Host "$name pid: $($process.Id)"
    Write-Host "$name logs: $stdoutPath / $stderrPath"
}

Use-JavaHome $JavaHome
Normalize-ProcessPath
$resolvedGradleUserHome = Resolve-ProjectPath $GradleUserHome
New-Item -ItemType Directory -Force -Path $resolvedGradleUserHome | Out-Null
$env:GRADLE_USER_HOME = $resolvedGradleUserHome

if (-not $SkipBackend) {
    Assert-OsmuJavaAvailable -RequiredVersion 17 | Out-Null

    $backendPid = Join-Path $runDir "backend.pid"
    if (Test-Path -LiteralPath $backendPid) {
        throw "Backend pid file already exists: $backendPid. Run .\scripts\stop-local-prototype.ps1 first."
    }
    Assert-PortAvailable $BackendPort "Backend"

    $backendCommand = "`$env:SERVER_PORT='$BackendPort'; `$env:OSMU_METADATA_MODE='in-memory'; `$env:OSMU_STORAGE_MODE='in-memory'; `$env:OSMU_FLYWAY_ENABLED='false'; .\gradlew.bat bootRun --args='--server.port=$BackendPort'"
    Start-LoggedProcess `
        "backend" `
        (Join-Path $root "osmu-backend") `
        @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $backendCommand) `
        $backendPid

    Wait-Http "http://localhost:$BackendPort/api/health" "backend"
}

if (-not $SkipFrontend) {
    $frontendPid = Join-Path $runDir "frontend.pid"
    if (Test-Path -LiteralPath $frontendPid) {
        throw "Frontend pid file already exists: $frontendPid. Run .\scripts\stop-local-prototype.ps1 first."
    }
    Assert-PortAvailable $FrontendPort "Frontend"

    $frontendCommand = "`$env:VITE_API_BASE_URL='http://localhost:$BackendPort/api'; npm.cmd run dev -- --host 127.0.0.1 --port $FrontendPort"
    Start-LoggedProcess `
        "frontend" `
        (Join-Path $root "osmu-frontend") `
        @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $frontendCommand) `
        $frontendPid

    Wait-Http "http://localhost:$FrontendPort" "frontend"
}

Write-Host ""
if ($SkipBackend -and $SkipFrontend) {
    Write-Host "No OSMU local prototype services were started because -SkipBackend and -SkipFrontend were both set."
    return
}

Write-Host "OSMU local prototype ready."
if (-not $SkipFrontend) {
    Write-Host "Frontend: http://localhost:$FrontendPort"
}
if (-not $SkipBackend) {
    Write-Host "Backend:  http://localhost:$BackendPort/api/health"
    Write-Host "Login:    admin / password"
    Write-Host ""
    Write-Host "Note: this mode uses in-memory metadata/storage. Presigned URL and multipart upload require Docker/MinIO mode."
}
Write-Host "Stop: .\scripts\stop-local-prototype.ps1"
