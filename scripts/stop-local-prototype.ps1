param(
    [string] $LogDir = ".\.osmu-run",
    [int] $BackendPort = 8080,
    [int] $FrontendPort = 5173,
    [switch] $ForcePorts
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$runDir = Join-Path $root $LogDir

function Stop-ProcessTree($processId) {
    try {
        $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$processId" -ErrorAction Stop
    }
    catch {
        $children = @()
    }
    foreach ($child in $children) {
        Stop-ProcessTree $child.ProcessId
    }

    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($process) {
        Stop-Process -Id $processId -Force
        Write-Host "Stopped pid $processId"
    }
}

function Get-ListeningPortProcessIds($port) {
    $pattern = "^\s*TCP\s+\S+:$port\s+\S+\s+LISTENING\s+(\d+)\s*$"
    return netstat -ano |
        Select-String -Pattern $pattern |
        ForEach-Object { [int]$_.Matches[0].Groups[1].Value } |
        Sort-Object -Unique
}

function Stop-ListeningPort($port, $label) {
    foreach ($processId in Get-ListeningPortProcessIds $port) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if (-not $process) {
            continue
        }
        Stop-Process -Id $processId -Force
        Write-Host "Stopped $label listener pid $processId"
    }
}

if (-not (Test-Path -LiteralPath $runDir)) {
    Write-Host "No local prototype run directory found."
    return
}

$hadPidFiles = $false
foreach ($name in @("frontend", "backend")) {
    $pidPath = Join-Path $runDir "$name.pid"
    if (-not (Test-Path -LiteralPath $pidPath)) {
        continue
    }

    $hadPidFiles = $true
    $processId = [int](Get-Content -Raw -LiteralPath $pidPath)
    Stop-ProcessTree $processId
    Remove-Item -LiteralPath $pidPath -Force
}

if ($hadPidFiles -or $ForcePorts) {
    Stop-ListeningPort $FrontendPort "frontend"
    Stop-ListeningPort $BackendPort "backend"
}

Write-Host "OSMU local prototype stopped."
