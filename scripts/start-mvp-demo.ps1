param(
    [ValidateSet("auto", "docker", "prototype", "mock")]
    [string] $Mode = "auto",
    [string] $JavaHome = "",
    [int] $BackendPort = 8080,
    [int] $FrontendPort = 5173,
    [int] $ApiPort = 8080,
    [string] $LogDir = ".\.osmu-run\mvp-demo",
    [switch] $ForcePorts,
    [switch] $Verify,
    [switch] $NoBuild,
    [switch] $SkipS3AccessKeySmoke
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "java-toolchain.ps1")
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Invoke-ProjectScript([string] $ScriptName, [string[]] $Arguments = @()) {
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    Write-Host "    $ScriptName $($Arguments -join ' ')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptName failed with exit code $LASTEXITCODE."
    }
}

function Test-DockerDaemonAvailable() {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        return $false
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $docker.Source info --format "{{json .ServerVersion}}" *> $null
        return $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Test-Java17Available() {
    try {
        Use-OsmuJavaHome $JavaHome | Out-Null
        Assert-OsmuJavaAvailable -RequiredVersion 17 | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Join-RunPath([string] $Name) {
    return Join-Path $LogDir $Name
}

$resolvedLogDir = Resolve-ProjectPath $LogDir
New-Item -ItemType Directory -Force -Path $resolvedLogDir | Out-Null
Use-OsmuDockerConfig $root | Out-Null

$selectedMode = $Mode
if ($Mode -eq "auto") {
    if (Test-DockerDaemonAvailable) {
        $selectedMode = "docker"
    }
    elseif (Test-Java17Available) {
        $selectedMode = "prototype"
    }
    else {
        $selectedMode = "mock"
    }
}

Step "Start OSMU MVP demo"
Write-Host "Selected mode: $selectedMode"

if ($ForcePorts) {
    Step "Pre-clean selected demo mode"
    if ($selectedMode -eq "docker") {
        Invoke-ProjectScript "stop-local-demo.ps1"
    }
    elseif ($selectedMode -eq "prototype") {
        Invoke-ProjectScript "stop-local-prototype.ps1" @(
            "-LogDir", (Join-RunPath "prototype"),
            "-BackendPort", "$BackendPort",
            "-FrontendPort", "$FrontendPort",
            "-ForcePorts"
        )
    }
    else {
        Invoke-ProjectScript "stop-frontend-mock-demo.ps1" @(
            "-LogDir", (Join-RunPath "mock"),
            "-ForcePorts",
            "-Ports", "$ApiPort", "$FrontendPort"
        )
    }
}

if ($selectedMode -eq "docker") {
    $startArgs = @("-SeedDemo")
    if ($Verify) {
        $startArgs += "-VerifyDemo"
    }
    if ($NoBuild) {
        $startArgs += "-NoBuild"
    }
    if ($SkipS3AccessKeySmoke) {
        $startArgs += "-SkipS3AccessKeySmoke"
    }

    Invoke-ProjectScript "start-local-demo.ps1" $startArgs
}
elseif ($selectedMode -eq "prototype") {
    $startArgs = @(
        "-BackendPort", "$BackendPort",
        "-FrontendPort", "$FrontendPort",
        "-LogDir", (Join-RunPath "prototype")
    )
    if ($JavaHome) {
        $startArgs += @("-JavaHome", $JavaHome)
    }

    Invoke-ProjectScript "start-local-prototype.ps1" $startArgs
    if ($Verify) {
        Invoke-ProjectScript "verify-lightweight-prototype.ps1" @(
            "-ApiBase", "http://localhost:$BackendPort/api"
        )
    }
}
else {
    Invoke-ProjectScript "start-frontend-mock-demo.ps1" @(
        "-ApiPort", "$ApiPort",
        "-FrontendPort", "$FrontendPort",
        "-LogDir", (Join-RunPath "mock")
    )
    if ($Verify) {
        Invoke-ProjectScript "verify-frontend-mock-demo.ps1" @(
            "-ApiPort", "$ApiPort",
            "-FrontendPort", "$FrontendPort",
            "-LogDir", (Join-RunPath "mock"),
            "-NoStart"
        )
    }
}

$metadata = [ordered]@{
    startedAt = [DateTimeOffset]::Now.ToString("o")
    requestedMode = $Mode
    selectedMode = $selectedMode
    frontend = "http://localhost:$FrontendPort"
    backendApi = if ($selectedMode -eq "mock") { "http://localhost:$ApiPort/api" } else { "http://localhost:$BackendPort/api" }
    logDir = $resolvedLogDir
    stopCommand = "powershell -ExecutionPolicy Bypass -File .\scripts\stop-mvp-demo.ps1"
}
$metadataPath = Join-Path $resolvedLogDir "latest-mvp-demo.json"
$metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

Write-Host ""
Write-Host "OSMU MVP demo ready."
Write-Host "Mode:     $selectedMode"
Write-Host "Frontend: http://localhost:$FrontendPort"
if ($selectedMode -eq "mock") {
    Write-Host "API:      http://localhost:$ApiPort/api"
    Write-Host "Login:    admin/password or developer/password"
}
else {
    Write-Host "API:      http://localhost:$BackendPort/api"
    Write-Host "Login:    admin/password"
}
Write-Host "Metadata: $metadataPath"
Write-Host "Stop:     .\scripts\stop-mvp-demo.ps1"
