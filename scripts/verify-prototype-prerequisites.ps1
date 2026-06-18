param(
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $FrontendBase = "http://localhost:5173",
    [string] $JavaHome = "",
    [switch] $RequireJava,
    [switch] $RequireNode,
    [switch] $RequireDocker,
    [switch] $RequireS3Client,
    [switch] $RequireRuntime
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$script:Results = New-Object System.Collections.Generic.List[object]
. (Join-Path $PSScriptRoot "java-toolchain.ps1")
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Add-Check($name, $status, $detail, [bool] $required = $false) {
    $script:Results.Add([pscustomobject]@{
        Name = $name
        Status = $status
        Required = $required
        Detail = $detail
    }) | Out-Null

    $label = if ($required) { "required" } else { "optional" }
    Write-Host ("[{0}] {1} ({2}) - {3}" -f $status, $name, $label, $detail)
}

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

function Use-JavaHome($path) {
    return Use-OsmuJavaHome $path
}

function Invoke-Capture([string] $Executable, [string[]] $Arguments = @()) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Executable @Arguments 2>&1
        $filteredOutput = @($output | Where-Object {
            $line = [string]$_
            $line.Trim() -and $line.Trim() -ne '""'
        })
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = ($filteredOutput -join " ")
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Get-HttpStatus($url) {
    try {
        $response = Invoke-WebRequest -Method GET -Uri $url -UseBasicParsing -TimeoutSec 5
        return [int]$response.StatusCode
    }
    catch {
        return $null
    }
}

function Test-TcpPort([string] $HostName, [int] $Port) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(1000)) {
            return $false
        }
        $client.EndConnect($async)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

Normalize-ProcessPath
Use-OsmuDockerConfig $root | Out-Null

if ($JavaHome) {
    try {
        $resolvedJavaHome = Use-JavaHome $JavaHome
        Add-Check "JAVA_HOME override" "PASS" $resolvedJavaHome $RequireJava
    }
    catch {
        Add-Check "JAVA_HOME override" "FAIL" $_.Exception.Message $RequireJava
    }
}
else {
    Use-JavaHome "" | Out-Null
}

Step "Core toolchain"
$java = Get-Command java -ErrorAction SilentlyContinue
if ($java) {
    $javaVersion = Invoke-Capture $java.Source @("-version")
    $versionText = $javaVersion.Output
    $isJdk17OrNewer = $versionText -match 'version "((1\.)?([0-9]+))'
    $major = if ($isJdk17OrNewer) {
        if ($Matches[2]) { [int]$Matches[3] } else { [int]$Matches[1] }
    } else {
        0
    }
    if ($major -ge 17) {
        Add-Check "Java 17+" "PASS" $versionText $RequireJava
    } else {
        Add-Check "Java 17+" "FAIL" "java found, but version is below 17 or unreadable: $versionText" $RequireJava
    }
} else {
    Add-Check "Java 17+" "FAIL" "java not found on PATH. Use -JavaHome or install JDK 17+." $RequireJava
}

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $nodeVersion = Invoke-Capture $node.Source @("--version")
    Add-Check "Node.js" "PASS" $nodeVersion.Output $RequireNode
} else {
    Add-Check "Node.js" "FAIL" "node not found on PATH." $RequireNode
}

$npmSource = ""
try {
    $npmSource = Get-OsmuNpmExecutable
}
catch {
}
if ($npmSource) {
    $npmVersion = Invoke-Capture $npmSource @("--version")
    Add-Check "npm" "PASS" $npmVersion.Output $RequireNode
} else {
    Add-Check "npm" "FAIL" "npm not found on PATH." $RequireNode
}

Step "Docker"
$dockerDaemonAvailable = $false
$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($docker) {
    Add-Check "Docker CLI" "PASS" $docker.Source $RequireDocker
    $dockerInfo = Invoke-Capture $docker.Source @("info", "--format", "{{json .ServerVersion}}")
    if ($dockerInfo.ExitCode -eq 0) {
        $dockerDaemonAvailable = $true
        Add-Check "Docker daemon" "PASS" $dockerInfo.Output $RequireDocker
    } else {
        Add-Check "Docker daemon" "FAIL" $dockerInfo.Output $RequireDocker
    }

    $localInfra = Join-Path (Join-Path $root "infra") "local"
    $composeFile = Join-Path $localInfra "docker-compose.yml"
    $envFile = Join-Path $localInfra ".env.example"
    if (Test-Path -LiteralPath $composeFile) {
        $compose = Invoke-Capture $docker.Source @("compose", "--env-file", $envFile, "-f", $composeFile, "config", "--quiet")
        if ($compose.ExitCode -eq 0) {
            Add-Check "Docker Compose config" "PASS" $composeFile $RequireDocker
        } else {
            Add-Check "Docker Compose config" "FAIL" $compose.Output $RequireDocker
        }
    } else {
        Add-Check "Docker Compose config" "FAIL" "compose file missing: $composeFile" $RequireDocker
    }
} else {
    Add-Check "Docker CLI" "FAIL" "docker not found on PATH." $RequireDocker
    Add-Check "Docker daemon" "FAIL" "docker not found on PATH." $RequireDocker
    Add-Check "Docker Compose config" "FAIL" "docker not found on PATH." $RequireDocker
}

Step "S3 clients"
$aws = Get-Command aws -ErrorAction SilentlyContinue
if ($aws) {
    $awsVersion = Invoke-Capture $aws.Source @("--version")
    Add-Check "AWS CLI" "PASS" "$($aws.Source) $($awsVersion.Output)" $false
} else {
    Add-Check "AWS CLI" "FAIL" "aws not found on PATH." $false
}

$boto3Available = $false
foreach ($candidate in @("python", "python3", "py")) {
    $python = Get-Command $candidate -ErrorAction SilentlyContinue
    if (-not $python) {
        continue
    }
    $arguments = if ($candidate -eq "py") {
        @("-3", "-c", "import boto3, botocore")
    } else {
        @("-c", "import boto3, botocore")
    }
    $boto3Check = Invoke-Capture $python.Source $arguments
    if ($boto3Check.ExitCode -eq 0) {
        $boto3Available = $true
        Add-Check "Python boto3" "PASS" "$($python.Source) with boto3" $false
        break
    }
}
if (-not $boto3Available) {
    Add-Check "Python boto3" "FAIL" "Python with boto3 not found on PATH." $false
}

$mc = Get-Command mc -ErrorAction SilentlyContinue
if ($mc) {
    $mcVersion = Invoke-Capture $mc.Source @("--version")
    Add-Check "MinIO Client mc" "PASS" "$($mc.Source) $($mcVersion.Output)" $false
} else {
    Add-Check "MinIO Client mc" "FAIL" "mc not found on PATH." $false
}

if ($dockerDaemonAvailable) {
    Add-Check "Dockerized MinIO Client mc" "PASS" "Docker daemon is available; verify-s3-client-smoke.ps1 can run minio/mc in a container." $false
} else {
    Add-Check "Dockerized MinIO Client mc" "FAIL" "Docker daemon is not available for containerized mc." $false
}

if ($aws -or $boto3Available -or $mc -or $dockerDaemonAvailable) {
    Add-Check "Real S3 client" "PASS" "at least one of aws, Python+boto3, host mc, or Dockerized mc is available." $RequireS3Client
} else {
    Add-Check "Real S3 client" "FAIL" "install AWS CLI, install Python+boto3, install MinIO Client mc, or start Docker Desktop for Dockerized MinIO Client smoke." $RequireS3Client
}

Step "Runtime endpoints"
$apiUri = [Uri]$ApiBase
$frontendUri = [Uri]$FrontendBase
$backendPortOpen = Test-TcpPort $apiUri.Host $apiUri.Port
$frontendPortOpen = Test-TcpPort $frontendUri.Host $frontendUri.Port
Add-Check "Backend port" $(if ($backendPortOpen) { "PASS" } else { "FAIL" }) "$($apiUri.Host):$($apiUri.Port)" $RequireRuntime
Add-Check "Frontend port" $(if ($frontendPortOpen) { "PASS" } else { "FAIL" }) "$($frontendUri.Host):$($frontendUri.Port)" $RequireRuntime

$healthStatus = Get-HttpStatus "$ApiBase/health"
if ($healthStatus -eq 200) {
    Add-Check "Backend health" "PASS" "$ApiBase/health HTTP 200" $RequireRuntime
} else {
    Add-Check "Backend health" "FAIL" "$ApiBase/health not reachable." $RequireRuntime
}

$databaseHealthStatus = Get-HttpStatus "$ApiBase/database/health"
if ($databaseHealthStatus -eq 200) {
    Add-Check "Database health" "PASS" "$ApiBase/database/health HTTP 200" $RequireRuntime
} else {
    Add-Check "Database health" "FAIL" "$ApiBase/database/health not reachable." $RequireRuntime
}

$storageHealthStatus = Get-HttpStatus "$ApiBase/storage/health"
if ($storageHealthStatus -eq 200) {
    Add-Check "Storage health" "PASS" "$ApiBase/storage/health HTTP 200" $RequireRuntime
} else {
    Add-Check "Storage health" "FAIL" "$ApiBase/storage/health not reachable." $RequireRuntime
}

$frontendStatus = Get-HttpStatus $FrontendBase
if ($frontendStatus -eq 200) {
    Add-Check "Frontend HTTP" "PASS" "$FrontendBase HTTP 200" $RequireRuntime
} else {
    Add-Check "Frontend HTTP" "FAIL" "$FrontendBase not reachable." $RequireRuntime
}

Step "Summary"
$requiredFailures = $script:Results | Where-Object { $_.Required -and $_.Status -eq "FAIL" }
$optionalFailures = $script:Results | Where-Object { -not $_.Required -and $_.Status -eq "FAIL" }
Write-Host "Required failures: $(($requiredFailures | Measure-Object).Count)"
Write-Host "Optional warnings: $(($optionalFailures | Measure-Object).Count)"

if ($requiredFailures) {
    throw "Prototype prerequisite check failed for required items: $(($requiredFailures | ForEach-Object { $_.Name }) -join ', ')"
}

Write-Host "Prototype prerequisite check finished."

