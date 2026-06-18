param(
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [string] $ReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [string] $SummaryPath = ".\.osmu-run\latest-durable-demo-gate.md",
    [ValidateSet("auto", "aws", "boto3", "aws-js", "aws-java", "mc", "docker-mc", "all")]
    [string] $S3Client = "docker-mc",
    [switch] $NoBuild,
    [switch] $KeepRunning,
    [switch] $SkipPreflight,
    [switch] $SkipBrowserE2E,
    [switch] $SkipDockerIntegration,
    [switch] $SkipS3ClientSmoke,
    [switch] $NoReport
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$script:Checks = New-Object System.Collections.Generic.List[object]
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")
Use-OsmuDockerConfig $root | Out-Null

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Resolve-ProjectPath($path) {
    $path = Convert-OsmuPathSeparators $path
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
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

function Add-Check([string] $Name, [string] $Status, [string] $Detail, [string] $Evidence = "") {
    $script:Checks.Add([pscustomobject]@{
        name = $Name
        status = $Status
        detail = $Detail
        evidence = $Evidence
    }) | Out-Null

    $line = "[$Status] $Name - $Detail"
    if ($Evidence) {
        $line = "$line ($Evidence)"
    }
    Write-Host $line
}

function Invoke-ProjectScript([string] $ScriptName, [string[]] $Arguments = @()) {
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    Write-Host "    $ScriptName $($Arguments -join ' ')"
    $exitCode = Invoke-OsmuPowerShellScript $scriptPath $Arguments
    if ($exitCode -ne 0) {
        throw "$ScriptName failed with exit code $exitCode."
    }
}

function Invoke-RequiredStep([string] $Name, [scriptblock] $Body, [string] $Evidence) {
    try {
        & $Body
        Add-Check $Name "PASS" "completed" $Evidence
    }
    catch {
        Add-Check $Name "FAIL" $_.Exception.Message $Evidence
        throw
    }
}

function Stop-LocalDemo() {
    try {
        Invoke-ProjectScript "stop-local-demo.ps1" @(
            "-EnvFile", $EnvFile,
            "-EnvExample", $EnvExample,
            "-ComposeFile", $ComposeFile
        )
    }
    catch {
        Write-Warning "Stop Docker local demo failed: $($_.Exception.Message)"
    }
}

function Ensure-LocalEnvFile() {
    if (Test-Path -LiteralPath $resolvedEnvFile) {
        Add-Check "Local env file" "PASS" "env file already exists" $resolvedEnvFile
        return
    }

    if (-not (Test-Path -LiteralPath $resolvedEnvExample)) {
        Add-Check "Local env file" "FAIL" "env example file is missing" $resolvedEnvExample
        throw "Local env example file is missing: $resolvedEnvExample"
    }

    Copy-Item -LiteralPath $resolvedEnvExample -Destination $resolvedEnvFile
    Add-Check "Local env file" "PASS" "created env file from example" "$resolvedEnvExample -> $resolvedEnvFile"
}

$resolvedEnvFile = Resolve-ProjectPath $EnvFile
$resolvedEnvExample = Resolve-ProjectPath $EnvExample
$apiBase = "http://localhost:8080/api"
$adminLoginId = "admin"
$adminPassword = "password"
$preflightReportPath = ".\.osmu-run\latest-durable-demo-preflight.json"

$gateSucceeded = $false
$gateFailureMessage = ""
try {
    Step "Prepare local env"
    Ensure-LocalEnvFile

    if ($SkipPreflight) {
        Add-Check "Durable demo preflight" "SKIPPED" "skipped by parameter" "verify-durable-demo-preflight.ps1"
    }
    else {
        Step "Durable demo preflight"
        Invoke-RequiredStep "Durable demo preflight" {
            Invoke-ProjectScript "verify-durable-demo-preflight.ps1" @(
                "-EnvFile", $EnvFile,
                "-EnvExample", $EnvExample,
                "-ComposeFile", $ComposeFile,
                "-S3Client", $S3Client,
                "-ReportPath", $preflightReportPath
            )
        } "verify-durable-demo-preflight.ps1 -S3Client $S3Client"
    }

    Step "Durable MVP demo prerequisites"
    Invoke-RequiredStep "Prerequisites" {
        Invoke-ProjectScript "verify-prototype-prerequisites.ps1" @(
            "-RequireNode",
            "-RequireDocker",
            "-RequireS3Client"
        )
    } "verify-prototype-prerequisites.ps1 -RequireNode -RequireDocker -RequireS3Client"

    if ($SkipBrowserE2E) {
        Add-Check "Docker local demo Browser E2E" "SKIPPED" "skipped by parameter" "verify-browser-e2e-local-demo.ps1"
    }
    else {
        Step "Docker local demo Browser E2E"
        $browserArgs = @(
            "-EnvFile", $EnvFile,
            "-EnvExample", $EnvExample,
            "-ComposeFile", $ComposeFile,
            "-KeepRunning"
        )
        if ($NoBuild) {
            $browserArgs += "-NoBuild"
        }
        Invoke-RequiredStep "Docker local demo Browser E2E" {
            Invoke-ProjectScript "verify-browser-e2e-local-demo.ps1" $browserArgs
        } "verify-browser-e2e-local-demo.ps1"
    }

    if (Test-Path -LiteralPath $resolvedEnvFile) {
        $backendPort = Read-EnvValue $resolvedEnvFile "BACKEND_PORT" "8080"
        $adminLoginId = Read-EnvValue $resolvedEnvFile "OSMU_ADMIN_LOGIN_ID" "admin"
        $adminPassword = Read-EnvValue $resolvedEnvFile "OSMU_ADMIN_PASSWORD" "password"
    }
    elseif (Test-Path -LiteralPath $resolvedEnvExample) {
        $backendPort = Read-EnvValue $resolvedEnvExample "BACKEND_PORT" "8080"
        $adminLoginId = Read-EnvValue $resolvedEnvExample "OSMU_ADMIN_LOGIN_ID" "admin"
        $adminPassword = Read-EnvValue $resolvedEnvExample "OSMU_ADMIN_PASSWORD" "password"
    }
    else {
        $backendPort = "8080"
    }
    $apiBase = "http://localhost:$backendPort/api"

    if ($SkipDockerIntegration) {
        Add-Check "Docker integration smoke" "SKIPPED" "skipped by parameter" "verify-docker-integration.ps1"
    }
    else {
        Step "Docker integration smoke"
        $dockerArgs = @(
            "-EnvFile", $EnvFile,
            "-ComposeFile", $ComposeFile,
            "-KeepRunning"
        )
        if ($NoBuild) {
            $dockerArgs += "-NoBuild"
        }
        Invoke-RequiredStep "Docker integration smoke" {
            Invoke-ProjectScript "verify-docker-integration.ps1" $dockerArgs
        } "verify-docker-integration.ps1"
    }

    if ($SkipS3ClientSmoke) {
        Add-Check "Real S3 client smoke" "SKIPPED" "skipped by parameter" "verify-s3-client-smoke.ps1"
    }
    else {
        Step "Real S3 client smoke"
        Invoke-RequiredStep "Real S3 client smoke" {
            Invoke-ProjectScript "verify-s3-client-smoke.ps1" @(
                "-ApiBase", $apiBase,
                "-AdminLoginId", $adminLoginId,
                "-AdminPassword", $adminPassword,
                "-Client", $S3Client,
                "-RequireClient"
            )
        } "verify-s3-client-smoke.ps1 -Client $S3Client -RequireClient"
    }

    $gateSucceeded = $true
}
catch {
    $gateFailureMessage = $_.Exception.Message
}
finally {
    if (-not $KeepRunning) {
        Step "Stop Docker local demo"
        Stop-LocalDemo
    }
}

$skipped = @($script:Checks | Where-Object { $_.status -eq "SKIPPED" })
$failed = @($script:Checks | Where-Object { $_.status -eq "FAIL" })
$result = if ($failed.Count -gt 0) {
    "failed"
}
elseif ($skipped.Count -gt 0) {
    "partial"
}
elseif ($gateSucceeded) {
    "ready"
}
else {
    "failed"
}

$report = [pscustomobject]@{
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = $result
    currentDemoStatus = if ($result -eq "ready") { "docker-durable-demo-verified" } else { "docker-durable-demo-partial" }
    failureMessage = $gateFailureMessage
    selectedS3Client = $S3Client
    durablePreflightReportPath = Resolve-ProjectPath $preflightReportPath
    completionEstimate = [pscustomobject]@{
        mvpDemo = if ($result -eq "ready") { "90-95%" } else { "70-85%" }
        product = if ($result -eq "ready") { "20-25%" } else { "15-20%" }
    }
    checks = @($script:Checks | ForEach-Object { $_ })
    nextCommands = @(
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-preflight.ps1 -S3Client $S3Client",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-gate.ps1 -S3Client $S3Client",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -S3Client $S3Client",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-mvp-demo-readiness.ps1 -S3Client $S3Client -FailIfDurablePending",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-durable-release-artifacts.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json -BackendTestsIncluded"
    )
}

$summaryLines = @(
    "# OSMU Durable MVP Demo Gate",
    "",
    "Generated at: $($report.generatedAt)",
    "Result: $($report.result)",
    "Current demo status: $($report.currentDemoStatus)",
    "Selected S3 client: $($report.selectedS3Client)",
    "Durable preflight report: $($report.durablePreflightReportPath)",
    "",
    "## Checks",
    ""
)

foreach ($check in $script:Checks) {
    $line = "- $($check.status): $($check.name) - $($check.detail)"
    if ($check.evidence) {
        $line = "$line Evidence: $($check.evidence)"
    }
    $summaryLines += $line
}

$summaryLines += @(
    "",
    "## Completion Estimate",
    "",
    "- MVP demo: $($report.completionEstimate.mvpDemo)",
    "- Product: $($report.completionEstimate.product)",
    "",
    "## Next Commands",
    ""
)
foreach ($command in $report.nextCommands) {
    $summaryLines += "- ``$command``"
}

$summary = $summaryLines -join [Environment]::NewLine

if (-not $NoReport) {
    $resolvedReportPath = Resolve-ProjectPath $ReportPath
    $resolvedSummaryPath = Resolve-ProjectPath $SummaryPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedSummaryPath) | Out-Null
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Set-Content -LiteralPath $resolvedSummaryPath -Value $summary -Encoding UTF8
    Write-Host "Durable demo gate report: $resolvedReportPath"
    Write-Host "Durable demo gate summary: $resolvedSummaryPath"
}

Step "Durable MVP demo gate summary"
Write-Host $summary

if ($result -ne "ready") {
    throw "Durable MVP demo gate is not fully ready. Result: $result"
}
