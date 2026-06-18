param(
    [string] $LogDir = ".\.osmu-run",
    [int] $BackendPort = 8080,
    [int] $FrontendPort = 5173,
    [switch] $ForcePorts
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$runDir = Join-Path $root $LogDir

function Wait-ProcessExit($processId, $timeoutSeconds = 5) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
            return
        }
        Start-Sleep -Milliseconds 200
    }
}

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
        Wait-ProcessExit $processId
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
        Stop-ProcessTree $processId
        Write-Host "Stopped $label listener pid $processId"
    }
}

function Wait-PortsReleased($ports, $timeoutSeconds = 10) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    do {
        $remaining = @()
        foreach ($port in $ports) {
            $listeners = @(Get-ListeningPortProcessIds $port)
            if ($listeners.Count -gt 0) {
                $remaining += [pscustomobject]@{
                    Port = $port
                    Pids = ($listeners -join ",")
                }
            }
        }

        if ($remaining.Count -eq 0) {
            Start-Sleep -Milliseconds 750
            $reappeared = @()
            foreach ($port in $ports) {
                $listeners = @(Get-ListeningPortProcessIds $port)
                if ($listeners.Count -gt 0) {
                    $reappeared += $port
                }
            }
            if ($reappeared.Count -eq 0) {
                return
            }
        }

        Stop-ListeningPort $FrontendPort "frontend"
        Stop-ListeningPort $BackendPort "backend"
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    $busy = @()
    foreach ($port in $ports) {
        $listeners = @(Get-ListeningPortProcessIds $port)
        if ($listeners.Count -gt 0) {
            $busy += "$port pid(s): $($listeners -join ', ')"
        }
    }
    if ($busy.Count -gt 0) {
        throw "Ports still in use after stop: $($busy -join '; ')"
    }
}

if (-not (Test-Path -LiteralPath $runDir)) {
    if ($ForcePorts) {
        Stop-ListeningPort $FrontendPort "frontend"
        Stop-ListeningPort $BackendPort "backend"
        Wait-PortsReleased @($FrontendPort, $BackendPort)
    }
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
    Wait-PortsReleased @($FrontendPort, $BackendPort)
}

Write-Host "OSMU local prototype stopped."
