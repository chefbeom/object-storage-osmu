param(
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [string] $ReportPath = ".\.osmu-run\latest-durable-demo-preflight.json",
    [string] $SummaryPath = ".\.osmu-run\latest-durable-demo-preflight.md",
    [ValidateSet("auto", "aws", "boto3", "mc", "docker-mc", "all")]
    [string] $S3Client = "docker-mc",
    [switch] $AllowNotReady,
    [switch] $NoReport
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$script:Checks = New-Object System.Collections.Generic.List[object]
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")

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

function Add-Check([string] $Name, [string] $Status, [bool] $Required, [string] $Detail, [string] $Evidence = "") {
    $script:Checks.Add([pscustomobject]@{
        name = $Name
        status = $Status
        required = $Required
        detail = $Detail
        evidence = $Evidence
    }) | Out-Null

    $requiredLabel = if ($Required) { "required" } else { "optional" }
    $line = "[$Status] $Name ($requiredLabel) - $Detail"
    if ($Evidence) {
        $line = "$line ($Evidence)"
    }
    Write-Host $line
}

function Invoke-Capture([string] $Executable, [string[]] $Arguments = @()) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Executable @Arguments 2>&1
        $filteredOutput = @($output | Where-Object {
            $line = [string] $_
            $line.Trim() -and $line.Trim() -ne '""'
        })
        return [pscustomobject]@{
            exitCode = [int] $LASTEXITCODE
            output = ($filteredOutput -join " ")
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Test-Command([string] $Name) {
    return Get-Command $Name -ErrorAction SilentlyContinue
}

function Test-PythonBoto3Available() {
    foreach ($candidate in @("python", "python3", "py")) {
        $python = Test-Command $candidate
        if (-not $python) {
            continue
        }
        $arguments = if ($candidate -eq "py") {
            @("-3", "-c", "import boto3, botocore")
        } else {
            @("-c", "import boto3, botocore")
        }
        $result = Invoke-Capture $python.Source $arguments
        if ($result.exitCode -eq 0) {
            return [pscustomobject]@{
                available = $true
                detail = "$($python.Source) with boto3"
            }
        }
    }
    return [pscustomobject]@{
        available = $false
        detail = "Python with boto3 not found on PATH"
    }
}

function Get-S3SelectionReady([string] $Selection, [bool] $AwsAvailable, [bool] $Boto3Available, [bool] $McAvailable, [bool] $DockerClientAvailable) {
    switch ($Selection) {
        "aws" { return $AwsAvailable }
        "boto3" { return $Boto3Available }
        "mc" { return $McAvailable }
        "docker-mc" { return $DockerClientAvailable }
        default { return ($AwsAvailable -or $Boto3Available -or $McAvailable -or $DockerClientAvailable) }
    }
}

$resolvedEnvFile = Resolve-ProjectPath $EnvFile
$resolvedEnvExample = Resolve-ProjectPath $EnvExample
$resolvedComposeFile = Resolve-ProjectPath $ComposeFile
$dockerConfig = Use-OsmuDockerConfig $root

Step "Durable demo preflight"
Add-Check "Docker config isolation" "PASS" $false "using repo-local Docker config" "DOCKER_CONFIG=$dockerConfig"

if (Test-Path -LiteralPath $resolvedEnvFile) {
    Add-Check "Local env file" "PASS" $true "env file exists" $resolvedEnvFile
    $composeEnvFile = $resolvedEnvFile
}
elseif (Test-Path -LiteralPath $resolvedEnvExample) {
    Add-Check "Local env file" "PASS" $true "env file can be created from example by the durable gate" "$resolvedEnvExample -> $resolvedEnvFile"
    $composeEnvFile = $resolvedEnvExample
}
else {
    Add-Check "Local env file" "FAIL" $true "neither env file nor env example exists" "$resolvedEnvFile / $resolvedEnvExample"
    $composeEnvFile = $resolvedEnvFile
}

if (Test-Path -LiteralPath $resolvedComposeFile) {
    Add-Check "Docker Compose file" "PASS" $true "compose file exists" $resolvedComposeFile
}
else {
    Add-Check "Docker Compose file" "FAIL" $true "compose file is missing" $resolvedComposeFile
}

Step "Core tools"
$node = Test-Command "node"
if ($node) {
    $nodeVersion = Invoke-Capture $node.Source @("--version")
    Add-Check "Node.js" "PASS" $true $nodeVersion.output $node.Source
}
else {
    Add-Check "Node.js" "FAIL" $true "node not found on PATH"
}

$npmSource = ""
try {
    $npmSource = Get-OsmuNpmExecutable
}
catch {
}
if ($npmSource) {
    $npmVersion = Invoke-Capture $npmSource @("--version")
    Add-Check "npm" "PASS" $true $npmVersion.output $npmSource
}
else {
    Add-Check "npm" "FAIL" $true "npm not found on PATH"
}

Step "Docker"
$dockerDaemonAvailable = $false
$docker = Test-Command "docker"
if ($docker) {
    Add-Check "Docker CLI" "PASS" $true "docker CLI found" $docker.Source

    $dockerInfo = Invoke-Capture $docker.Source @("info", "--format", "{{json .ServerVersion}}")
    if ($dockerInfo.exitCode -eq 0) {
        $dockerDaemonAvailable = $true
        Add-Check "Docker daemon" "PASS" $true $dockerInfo.output "docker info --format '{{json .ServerVersion}}'"
    }
    else {
        Add-Check "Docker daemon" "FAIL" $true $dockerInfo.output "Start Docker Desktop, then rerun this command."
    }

    if ((Test-Path -LiteralPath $resolvedComposeFile) -and (Test-Path -LiteralPath $composeEnvFile)) {
        $compose = Invoke-Capture $docker.Source @(
            "compose",
            "--env-file", $composeEnvFile,
            "-f", $resolvedComposeFile,
            "config",
            "--quiet"
        )
        if ($compose.exitCode -eq 0) {
            Add-Check "Docker Compose config" "PASS" $true "compose config parsed" "$resolvedComposeFile with $composeEnvFile"
        }
        else {
            Add-Check "Docker Compose config" "FAIL" $true $compose.output "$resolvedComposeFile with $composeEnvFile"
        }
    }
    else {
        Add-Check "Docker Compose config" "FAIL" $true "compose file or env source missing" "$resolvedComposeFile with $composeEnvFile"
    }
}
else {
    Add-Check "Docker CLI" "FAIL" $true "docker not found on PATH"
    Add-Check "Docker daemon" "FAIL" $true "docker not found on PATH"
    Add-Check "Docker Compose config" "FAIL" $true "docker not found on PATH"
}

Step "S3 clients"
$aws = Test-Command "aws"
$awsAvailable = $false
if ($aws) {
    $awsVersion = Invoke-Capture $aws.Source @("--version")
    $awsAvailable = $awsVersion.exitCode -eq 0
    Add-Check "AWS CLI" $(if ($awsAvailable) { "PASS" } else { "FAIL" }) $false $awsVersion.output $aws.Source
}
else {
    Add-Check "AWS CLI" "FAIL" $false "aws not found on PATH"
}

$boto3Status = Test-PythonBoto3Available
$boto3Available = [bool]$boto3Status.available
Add-Check "Python boto3" $(if ($boto3Available) { "PASS" } else { "FAIL" }) $false $boto3Status.detail

$mc = Test-Command "mc"
$mcAvailable = $false
if ($mc) {
    $mcVersion = Invoke-Capture $mc.Source @("--version")
    $mcAvailable = $mcVersion.exitCode -eq 0
    Add-Check "MinIO Client mc" $(if ($mcAvailable) { "PASS" } else { "FAIL" }) $false $mcVersion.output $mc.Source
}
else {
    Add-Check "MinIO Client mc" "FAIL" $false "mc not found on PATH"
}

if ($dockerDaemonAvailable) {
    Add-Check "Dockerized MinIO Client mc" "PASS" $false "Docker daemon is available for minio/mc container smoke"
}
else {
    Add-Check "Dockerized MinIO Client mc" "FAIL" $false "Docker daemon is unavailable for containerized mc"
}

$s3SelectionReady = Get-S3SelectionReady $S3Client $awsAvailable $boto3Available $mcAvailable $dockerDaemonAvailable
if ($s3SelectionReady) {
    Add-Check "Selected real S3 client path" "PASS" $true "selected S3 client path is available" "S3Client=$S3Client"
}
else {
    Add-Check "Selected real S3 client path" "FAIL" $true "selected S3 client path is unavailable" "S3Client=$S3Client; choose auto/aws/boto3/mc or start Docker Desktop for docker-mc"
}

$requiredFailures = @($script:Checks | Where-Object { $_.required -and $_.status -eq "FAIL" })
$result = if ($requiredFailures.Count -eq 0) { "ready" } else { "pending" }
$report = [pscustomobject]@{
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = $result
    currentDemoStatus = if ($result -eq "ready") { "durable-demo-prerequisites-ready" } else { "durable-demo-prerequisites-pending" }
    selectedS3Client = $S3Client
    dockerConfig = $dockerConfig
    composeFile = $resolvedComposeFile
    composeEnvFile = $composeEnvFile
    requiredFailures = @($requiredFailures | ForEach-Object { $_.name })
    checks = @($script:Checks | ForEach-Object { $_ })
    nextCommands = @(
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-preflight.ps1 -S3Client $S3Client",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-gate.ps1 -S3Client $S3Client",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -S3Client $S3Client",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-mvp-demo-readiness.ps1 -S3Client $S3Client -FailIfDurablePending"
    )
}

$summaryLines = @(
    "# OSMU Durable Demo Preflight",
    "",
    "Generated at: $($report.generatedAt)",
    "Result: $($report.result)",
    "Current demo status: $($report.currentDemoStatus)",
    "Selected S3 client: $($report.selectedS3Client)",
    "Docker config: $($report.dockerConfig)",
    "",
    "## Checks",
    ""
)

foreach ($check in $script:Checks) {
    $requiredLabel = if ($check.required) { "required" } else { "optional" }
    $line = "- $($check.status): $($check.name) ($requiredLabel) - $($check.detail)"
    if ($check.evidence) {
        $line = "$line Evidence: $($check.evidence)"
    }
    $summaryLines += $line
}

$summaryLines += @(
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
    Write-Host "Durable demo preflight report: $resolvedReportPath"
    Write-Host "Durable demo preflight summary: $resolvedSummaryPath"
}

Step "Durable demo preflight summary"
Write-Host $summary

if ($result -ne "ready" -and -not $AllowNotReady) {
    throw "Durable demo preflight is not ready. Required failures: $($requiredFailures.name -join ', ')"
}
