param(
    [int] $ApiPort = 8080,
    [int] $FrontendPort = 5173,
    [string] $LogDir = ".\.osmu-run\frontend-mock-demo"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$runDir = Join-Path $root $LogDir
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

function Normalize-ProcessPath() {
    $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")
    if (-not $processPath) {
        $processPath = (([Environment]::GetEnvironmentVariable("Path", "Machine")),
            ([Environment]::GetEnvironmentVariable("Path", "User")) |
            Where-Object { $_ }) -join ";"
    }
    [Environment]::SetEnvironmentVariable("PATH", $null, "Process")
    [Environment]::SetEnvironmentVariable("Path", $processPath, "Process")
}

function Wait-Http($url, $name, $timeoutSeconds = 60) {
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
        Start-Sleep -Seconds 1
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

function Write-ListenerPidFile($port, $pidPath, $name) {
    $listeners = @(Get-ListeningPortProcessIds $port)
    if ($listeners.Count -eq 0) {
        throw "$name did not expose a listener pid on port $port."
    }
    Set-Content -LiteralPath $pidPath -Value ($listeners -join "`n") -Encoding ASCII
    Write-Host "$name listener pid(s): $($listeners -join ', ')"
}

function Assert-PortAvailable($port, $name) {
    $listeners = @(Get-ListeningPortProcessIds $port)
    if ($listeners.Count -gt 0) {
        throw "$name port $port is already in use by pid(s): $($listeners -join ', '). Run .\scripts\stop-frontend-mock-demo.ps1 -ForcePorts or choose another port."
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

Normalize-ProcessPath

$apiPid = Join-Path $runDir "mock-api.pid"
$frontendPid = Join-Path $runDir "frontend.pid"
$apiListenerPid = Join-Path $runDir "mock-api.listener.pid"
$frontendListenerPid = Join-Path $runDir "frontend.listener.pid"
if (Test-Path -LiteralPath $apiPid) {
    throw "Mock API pid file already exists: $apiPid. Run .\scripts\stop-frontend-mock-demo.ps1 first."
}
if (Test-Path -LiteralPath $frontendPid) {
    throw "Frontend pid file already exists: $frontendPid. Run .\scripts\stop-frontend-mock-demo.ps1 first."
}
if (Test-Path -LiteralPath $apiListenerPid) {
    throw "Mock API listener pid file already exists: $apiListenerPid. Run .\scripts\stop-frontend-mock-demo.ps1 first."
}
if (Test-Path -LiteralPath $frontendListenerPid) {
    throw "Frontend listener pid file already exists: $frontendListenerPid. Run .\scripts\stop-frontend-mock-demo.ps1 first."
}

Assert-PortAvailable $ApiPort "Mock API"
Assert-PortAvailable $FrontendPort "Frontend"

$frontendRoot = Join-Path $root "osmu-frontend"

Start-LoggedProcess `
    "mock-api" `
    $frontendRoot `
    @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "node .\mock-api\server.mjs --host 127.0.0.1 --port $ApiPort") `
    $apiPid

Wait-Http "http://localhost:$ApiPort/api/health" "mock api"
Write-ListenerPidFile $ApiPort $apiListenerPid "mock api"

Start-LoggedProcess `
    "frontend" `
    $frontendRoot `
    @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "`$env:VITE_API_BASE_URL='http://localhost:$ApiPort/api'; npm.cmd run dev -- --host 127.0.0.1 --port $FrontendPort") `
    $frontendPid

Wait-Http "http://localhost:$FrontendPort" "frontend"
Write-ListenerPidFile $FrontendPort $frontendListenerPid "frontend"

Write-Host ""
Write-Host "OSMU frontend mock demo ready."
Write-Host "Frontend: http://localhost:$FrontendPort"
Write-Host "Mock API: http://localhost:$ApiPort/api/health"
Write-Host "Admin login:     admin / password"
Write-Host "Developer login: developer / password"
Write-Host ""
Write-Host "This mode is for UI/demo smoke only. It does not replace Spring Boot, MariaDB, MinIO, Docker, or real S3 client gates."
Write-Host "Stop: .\scripts\stop-frontend-mock-demo.ps1"
