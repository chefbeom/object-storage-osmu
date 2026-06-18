function Test-OsmuWindows() {
    return [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Windows
    )
}

function Get-OsmuCommandSource([string[]] $Names, [string] $Label) {
    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }
    throw "$Label not found on PATH. Tried: $($Names -join ', ')"
}

function Convert-OsmuPathSeparators([string] $Path) {
    if (-not $Path) {
        return $Path
    }
    if (Test-OsmuWindows) {
        return $Path
    }
    return $Path -replace "\\", "/"
}

function Get-OsmuPowerShellExecutable() {
    if (Test-OsmuWindows) {
        return Get-OsmuCommandSource @("powershell.exe", "pwsh", "powershell") "PowerShell"
    }
    return Get-OsmuCommandSource @("pwsh", "powershell") "PowerShell"
}

function Get-OsmuNpmExecutable() {
    if (Test-OsmuWindows) {
        return Get-OsmuCommandSource @("npm.cmd", "npm") "npm"
    }
    return Get-OsmuCommandSource @("npm", "npm.cmd") "npm"
}

function Get-OsmuNpxExecutable() {
    if (Test-OsmuWindows) {
        return Get-OsmuCommandSource @("npx.cmd", "npx") "npx"
    }
    return Get-OsmuCommandSource @("npx", "npx.cmd") "npx"
}

function Invoke-OsmuPowerShellScript([string] $ScriptPath, [string[]] $Arguments = @()) {
    $powerShell = Get-OsmuPowerShellExecutable
    & $powerShell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments | Out-Host
    return [int]$LASTEXITCODE
}
