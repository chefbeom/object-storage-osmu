param(
    [string] $LogDir = ".\.osmu-run\frontend-mock-demo",
    [switch] $ForcePorts,
    [int[]] $Ports = @(8080, 5173)
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

function Stop-PidFile($path, $name) {
    if (-not (Test-Path -LiteralPath $path)) {
        return
    }

    $pidValues = @(Get-Content -LiteralPath $path | Where-Object { $_.Trim() })
    foreach ($pidValue in $pidValues) {
        $process = Get-Process -Id ([int]$pidValue.Trim()) -ErrorAction SilentlyContinue
        if ($process) {
            Stop-ProcessTree $process.Id
            Write-Host "$name stopped: $($process.Id)"
        }
    }
    Remove-Item -LiteralPath $path -Force
}

function Get-ListeningPortProcessIds($port) {
    $pattern = "^\s*TCP\s+\S+:$port\s+\S+\s+LISTENING\s+(\d+)\s*$"
    return netstat -ano |
        Select-String -Pattern $pattern |
        ForEach-Object { [int]$_.Matches[0].Groups[1].Value } |
        Sort-Object -Unique
}

function Stop-ListeningPorts($targetPorts) {
    foreach ($port in $targetPorts) {
        foreach ($listenerProcessId in @(Get-ListeningPortProcessIds $port)) {
            $process = Get-Process -Id $listenerProcessId -ErrorAction SilentlyContinue
            if ($process) {
                Stop-ProcessTree $process.Id
                Write-Host "port $port listener stopped: $listenerProcessId"
            }
        }
    }
}

function Wait-PortsReleased($targetPorts, $timeoutSeconds = 10) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    do {
        $busyPorts = @()
        foreach ($port in $targetPorts) {
            $listeners = @(Get-ListeningPortProcessIds $port)
            if ($listeners.Count -gt 0) {
                $busyPorts += [pscustomobject]@{
                    Port = $port
                    Pids = ($listeners -join ",")
                }
            }
        }

        if ($busyPorts.Count -eq 0) {
            Start-Sleep -Milliseconds 750
            $reappearedPorts = @()
            foreach ($port in $targetPorts) {
                $listeners = @(Get-ListeningPortProcessIds $port)
                if ($listeners.Count -gt 0) {
                    $reappearedPorts += $port
                }
            }
            if ($reappearedPorts.Count -eq 0) {
                return
            }
        }

        Stop-ListeningPorts $targetPorts
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    $remaining = @()
    foreach ($port in $targetPorts) {
        $listeners = @(Get-ListeningPortProcessIds $port)
        if ($listeners.Count -gt 0) {
            $remaining += "$port pid(s): $($listeners -join ', ')"
        }
    }
    if ($remaining.Count -gt 0) {
        throw "Ports still in use after stop: $($remaining -join '; ')"
    }
}

Stop-PidFile (Join-Path $runDir "frontend.listener.pid") "frontend listener"
Stop-PidFile (Join-Path $runDir "mock-api.listener.pid") "mock-api listener"
Stop-PidFile (Join-Path $runDir "frontend.pid") "frontend"
Stop-PidFile (Join-Path $runDir "mock-api.pid") "mock-api"

if ($ForcePorts) {
    Stop-ListeningPorts $Ports
    Wait-PortsReleased $Ports
}

Write-Host "OSMU frontend mock demo stopped."
