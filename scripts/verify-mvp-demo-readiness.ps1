param(
    [string] $ReportPath = ".\.osmu-run\latest-demo-readiness.json",
    [string] $SummaryPath = ".\.osmu-run\latest-demo-readiness.md",
    [string] $JavaHome = "",
    [ValidateSet("auto", "aws", "boto3", "aws-js", "aws-java", "mc", "docker-mc", "all")]
    [string] $S3Client = "docker-mc",
    [switch] $SkipBackendTests,
    [switch] $SkipDockerFullStackE2E,
    [switch] $FailIfDurablePending,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$script:Checks = New-Object System.Collections.Generic.List[object]
$script:JavaToolchainError = ""
$script:ResolvedJavaHome = ""
$javaToolchain = Join-Path $PSScriptRoot "java-toolchain.ps1"
if (Test-Path -LiteralPath $javaToolchain) {
    . $javaToolchain
    try {
        $script:ResolvedJavaHome = Use-OsmuJavaHome $JavaHome
    }
    catch {
        $script:JavaToolchainError = $_.Exception.Message
    }
}
$dockerToolchain = Join-Path $PSScriptRoot "docker-toolchain.ps1"
if (Test-Path -LiteralPath $dockerToolchain) {
    . $dockerToolchain
    Use-OsmuDockerConfig $root | Out-Null
}

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
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
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptName failed with exit code $LASTEXITCODE."
    }
}

function Invoke-Capture([string] $Executable, [string[]] $Arguments = @()) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Executable @Arguments 2>&1
        return [pscustomobject]@{
            exitCode = $LASTEXITCODE
            output = ($output -join " ")
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Invoke-BackendTests() {
    $backendDirectory = Join-Path $root "osmu-backend"
    $windowsWrapper = Join-Path $backendDirectory "gradlew.bat"
    $unixWrapper = Join-Path $backendDirectory "gradlew"
    $isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Windows
    )
    $wrapperPath = if ($isWindows) { $windowsWrapper } else { $unixWrapper }
    $wrapper = if ($isWindows) { ".\gradlew.bat" } else { "./gradlew" }
    if (-not (Test-Path -LiteralPath $wrapperPath)) {
        throw "Gradle wrapper not found: $wrapperPath"
    }
    if (-not $isWindows) {
        $chmod = Get-Command chmod -ErrorAction SilentlyContinue
        if ($chmod) {
            & $chmod.Source +x $unixWrapper | Out-Null
        }
    }

    Push-Location $backendDirectory
    try {
        & $wrapper test
        if ($LASTEXITCODE -ne 0) {
            throw "Backend Gradle tests failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

function Test-Java17Available() {
    if ($script:JavaToolchainError) {
        return [pscustomobject]@{
            passed = $false
            detail = $script:JavaToolchainError
        }
    }

    $assertJava = Get-Command Assert-OsmuJavaAvailable -ErrorAction SilentlyContinue
    if ($assertJava) {
        try {
            $versionText = Assert-OsmuJavaAvailable -RequiredVersion 17
            $detail = $versionText
            if ($script:ResolvedJavaHome) {
                $detail = "$detail; JAVA_HOME=$script:ResolvedJavaHome"
            }
            return [pscustomobject]@{
                passed = $true
                detail = $detail
            }
        }
        catch {
            return [pscustomobject]@{
                passed = $false
                detail = $_.Exception.Message
            }
        }
    }

    $java = Get-Command java -ErrorAction SilentlyContinue
    if (-not $java) {
        return [pscustomobject]@{
            passed = $false
            detail = "java not found on PATH."
        }
    }

    $javaVersion = Invoke-Capture $java.Source @("-version")
    $versionText = $javaVersion.output
    $matched = $versionText -match 'version "((1\.)?([0-9]+))'
    $major = if ($matched) {
        if ($Matches[2]) { [int]$Matches[3] } else { [int]$Matches[1] }
    } else {
        0
    }

    return [pscustomobject]@{
        passed = $major -ge 17
        detail = if ($major -ge 17) { $versionText } else { "Java found, but version is below 17 or unreadable: $versionText" }
    }
}

function Test-DockerDaemonAvailable() {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        return [pscustomobject]@{
            passed = $false
            detail = "docker not found on PATH."
        }
    }

    $dockerInfo = Invoke-Capture $docker.Source @("info", "--format", "{{json .ServerVersion}}")
    return [pscustomobject]@{
        passed = $dockerInfo.exitCode -eq 0
        detail = if ($dockerInfo.exitCode -eq 0) { $dockerInfo.output } else { $dockerInfo.output }
    }
}

function Test-PythonBoto3Available() {
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
        $result = Invoke-Capture $python.Source $arguments
        if ($result.exitCode -eq 0) {
            return [pscustomobject]@{
                passed = $true
                detail = "$($python.Source) with boto3"
            }
        }
    }
    return [pscustomobject]@{
        passed = $false
        detail = "Python with boto3 not found on PATH."
    }
}

function Test-NodeAwsSdkS3Available() {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        return [pscustomobject]@{
            passed = $false
            detail = "node not found on PATH."
        }
    }

    foreach ($moduleRoot in @($root, (Join-Path $root "osmu-frontend"))) {
        if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot "node_modules\@aws-sdk\client-s3\package.json"))) {
            continue
        }

        Push-Location $moduleRoot
        try {
            $result = Invoke-Capture $node.Source @("--input-type=module", "-e", "import('@aws-sdk/client-s3').then(() => process.exit(0)).catch(() => process.exit(1));")
            if ($result.exitCode -eq 0) {
                return [pscustomobject]@{
                    passed = $true
                    detail = "$($node.Source) with @aws-sdk/client-s3 at $moduleRoot"
                }
            }
        }
        finally {
            Pop-Location
        }
    }

    return [pscustomobject]@{
        passed = $false
        detail = "Node.js with @aws-sdk/client-s3 not found in repo node_modules."
    }
}

function Test-JavaAwsSdkS3Available() {
    if ([string]::IsNullOrWhiteSpace($env:OSMU_AWS_SDK_JAVA_CLASSPATH)) {
        return [pscustomobject]@{
            passed = $false
            detail = "OSMU_AWS_SDK_JAVA_CLASSPATH is not set."
        }
    }

    $java = Get-Command java -ErrorAction SilentlyContinue
    $javac = Get-Command javac -ErrorAction SilentlyContinue
    if (-not $java -or -not $javac) {
        return [pscustomobject]@{
            passed = $false
            detail = "java and javac are required for AWS SDK Java smoke."
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "$($java.Source) and $($javac.Source) with OSMU_AWS_SDK_JAVA_CLASSPATH"
    }
}

function Test-RealS3ClientAvailable() {
    $aws = Get-Command aws -ErrorAction SilentlyContinue
    $boto3Status = Test-PythonBoto3Available
    $awsJsStatus = Test-NodeAwsSdkS3Available
    $awsJavaStatus = Test-JavaAwsSdkS3Available
    $mc = Get-Command mc -ErrorAction SilentlyContinue
    $dockerStatus = Test-DockerDaemonAvailable

    $details = @()
    if ($aws) {
        $details += "aws=$($aws.Source)"
    }
    if ($boto3Status.passed) {
        $details += "boto3=$($boto3Status.detail)"
    }
    if ($awsJsStatus.passed) {
        $details += "aws-js=$($awsJsStatus.detail)"
    }
    if ($awsJavaStatus.passed) {
        $details += "aws-java=$($awsJavaStatus.detail)"
    }
    if ($mc) {
        $details += "mc=$($mc.Source)"
    }
    if ($dockerStatus.passed) {
        $details += "docker-mc=$($dockerStatus.detail)"
    }
    if (-not $details) {
        $details += "aws/Python+boto3/Node @aws-sdk/client-s3/AWS SDK Java classpath/mc not found and Docker daemon is not available for dockerized mc."
    }

    return [pscustomobject]@{
        passed = [bool]($aws -or $boto3Status.passed -or $awsJsStatus.passed -or $awsJavaStatus.passed -or $mc -or $dockerStatus.passed)
        detail = $details -join "; "
    }
}

function Invoke-DurableDemoPreflight([string] $SelectedS3Client) {
    $preflightReportPath = if ($NoWrite) {
        Join-Path ([System.IO.Path]::GetTempPath()) "osmu-durable-demo-preflight-$PID.json"
    } else {
        ".\.osmu-run\latest-durable-demo-preflight.json"
    }
    $preflightSummaryPath = if ($NoWrite) {
        Join-Path ([System.IO.Path]::GetTempPath()) "osmu-durable-demo-preflight-$PID.md"
    } else {
        ".\.osmu-run\latest-durable-demo-preflight.md"
    }

    $preflightArgs = @(
        "-S3Client", $SelectedS3Client,
        "-AllowNotReady",
        "-ReportPath", $preflightReportPath,
        "-SummaryPath", $preflightSummaryPath
    )
    Invoke-ProjectScript "verify-durable-demo-preflight.ps1" $preflightArgs

    $resolvedPreflightReportPath = Resolve-ProjectPath $preflightReportPath
    if (-not (Test-Path -LiteralPath $resolvedPreflightReportPath)) {
        throw "Durable preflight report was not written: $resolvedPreflightReportPath"
    }

    $preflightReport = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedPreflightReportPath | ConvertFrom-Json
    $requiredFailures = @($preflightReport.requiredFailures | ForEach-Object { [string] $_ })
    return [pscustomobject]@{
        result = [string] $preflightReport.result
        requiredFailures = $requiredFailures
        reportPath = $resolvedPreflightReportPath
    }
}

Step "MVP demo readiness preflight"
Invoke-ProjectScript "verify-prototype-prerequisites.ps1" @("-RequireNode")
Add-Check "Node/npm prerequisite" "PASS" "Node and npm are available." "verify-prototype-prerequisites.ps1 -RequireNode"

Step "Static and frontend gate"
Invoke-ProjectScript "verify-local.ps1" @("-SkipDocker", "-SkipBackend")
Add-Check "Static/frontend/mock API gate" "PASS" "Static checks, docs gates, frontend unit tests, build, and mock API self-test passed." "verify-local.ps1 -SkipDocker -SkipBackend"

Step "Java/Docker-free frontend mock demo"
Invoke-ProjectScript "verify-frontend-mock-demo.ps1"
Add-Check "Mock web demo smoke" "PASS" "Admin login, developer login, S3 config, developer access key, bucket create, object upload/list, and dashboard summary passed against mock API." "verify-frontend-mock-demo.ps1"

$browserMockE2EPassed = $false
$browserPrototypeE2EPassed = $false
$dockerFullStackE2EPassed = $false
$durableDemoGatePassed = $false
$backendTestsPassed = $false
Step "Browser E2E mock demo"
try {
    Invoke-ProjectScript "verify-browser-e2e-mock-demo.ps1"
    $browserMockE2EPassed = $true
    Add-Check "Browser mock E2E smoke" "PASS" "Playwright Browser E2E passed against the Java/Docker-free frontend mock demo." "verify-browser-e2e-mock-demo.ps1"
}
catch {
    Add-Check "Browser mock E2E smoke" "PENDING" "Playwright Browser E2E against the frontend mock demo is not available on this machine." $_.Exception.Message
}

Step "Durable demo preflight"
try {
    $durablePreflight = Invoke-DurableDemoPreflight $S3Client
    if ($durablePreflight.result -eq "ready") {
        Add-Check "Durable demo preflight" "READY" "Docker, Compose, Node/npm, and selected real S3 client prerequisites are ready." "verify-durable-demo-preflight.ps1 -S3Client $S3Client; $($durablePreflight.reportPath)"
    } else {
        $failureText = if ($durablePreflight.requiredFailures.Count -gt 0) {
            $durablePreflight.requiredFailures -join ", "
        } else {
            "unknown required prerequisite"
        }
        Add-Check "Durable demo preflight" "PENDING" "Durable prerequisites are pending: $failureText." "verify-durable-demo-preflight.ps1 -S3Client $S3Client; $($durablePreflight.reportPath)"
    }
}
catch {
    Add-Check "Durable demo preflight" "PENDING" "Durable preflight could not be completed on this machine." $_.Exception.Message
}

Step "Durable gate availability"
$javaStatus = Test-Java17Available
if ($javaStatus.passed) {
    Add-Check "Backend Gradle test readiness" "READY" "JDK 17+ is available." $javaStatus.detail
    if ($SkipBackendTests) {
        Add-Check "Backend Gradle tests" "PENDING" "Backend tests were skipped by parameter." "Rerun without -SkipBackendTests."
    } else {
        Step "Backend Gradle tests"
        try {
            Invoke-BackendTests
            $backendTestsPassed = $true
            Add-Check "Backend Gradle tests" "PASS" "Backend automated test suite passed." "osmu-backend/gradlew test"
        }
        catch {
            Add-Check "Backend Gradle tests" "PENDING" "Backend automated test suite did not pass on this machine." $_.Exception.Message
        }
    }
} else {
    Add-Check "Backend Gradle test readiness" "PENDING" "JDK 17+ is required for backend tests." $javaStatus.detail
    Add-Check "Backend Gradle tests" "PENDING" "Backend automated tests require JDK 17+." $javaStatus.detail
}

$dockerStatus = Test-DockerDaemonAvailable
if ($dockerStatus.passed) {
    Add-Check "MariaDB/MinIO full-stack readiness" "READY" "Docker daemon is available." $dockerStatus.detail
    if ($SkipDockerFullStackE2E) {
        Add-Check "Docker-backed Browser E2E readiness" "PENDING" "Docker daemon is available, but full-stack Browser E2E was skipped by parameter." "Rerun without -SkipDockerFullStackE2E."
        Add-Check "Durable MVP demo gate" "PENDING" "Docker daemon is available, but durable demo gate was skipped by parameter." "Rerun without -SkipDockerFullStackE2E."
    } else {
        Step "Durable Docker MVP demo gate"
        try {
            $durableArgs = @("-S3Client", $S3Client)
            if ($NoWrite) {
                $durableArgs += "-NoReport"
            }
            Invoke-ProjectScript "verify-durable-demo-gate.ps1" $durableArgs
            $dockerFullStackE2EPassed = $true
            $durableDemoGatePassed = $true
            Add-Check "Docker-backed Browser E2E readiness" "PASS" "Docker Compose MariaDB/MinIO/backend/frontend demo, seed smoke, S3 access-key smoke, and Browser E2E passed inside the durable gate." "verify-durable-demo-gate.ps1"
            Add-Check "Durable MVP demo gate" "PASS" "Docker local demo Browser E2E, Docker integration smoke, and real S3 client smoke passed." "verify-durable-demo-gate.ps1"
        }
        catch {
            Add-Check "Docker-backed Browser E2E readiness" "PENDING" "Docker daemon is available, but durable demo gate did not pass on this machine." $_.Exception.Message
            Add-Check "Durable MVP demo gate" "PENDING" "Docker daemon is available, but Docker integration and real S3 client evidence are not complete." $_.Exception.Message
        }
    }
} else {
    Add-Check "MariaDB/MinIO full-stack readiness" "PENDING" "Docker daemon is required for full local demo smoke." $dockerStatus.detail
    Add-Check "Docker-backed Browser E2E readiness" "PENDING" "Docker daemon is required for the MariaDB/MinIO/backend/frontend Browser E2E gate." "Start Docker Desktop, then run verify-browser-e2e-local-demo.ps1."
    Add-Check "Durable MVP demo gate" "PENDING" "Docker daemon is required for the one-command Docker/MariaDB/MinIO/Browser/S3 client gate." "Start Docker Desktop, then run verify-durable-demo-gate.ps1."
}

$s3ClientStatus = Test-RealS3ClientAvailable
if ($s3ClientStatus.passed) {
    Add-Check "Real S3 client readiness" "READY" "At least one real S3 client is available." $s3ClientStatus.detail
} else {
    Add-Check "Real S3 client readiness" "PENDING" "AWS CLI, Python+boto3, AWS SDK JavaScript, AWS SDK Java via OSMU_AWS_SDK_JAVA_CLASSPATH, host MinIO Client mc, or Dockerized MinIO Client is required for real client smoke." $s3ClientStatus.detail
}

if ($javaStatus.passed) {
    $prototypeArgs = @()
    if ($JavaHome) {
        $prototypeArgs += @("-JavaHome", $JavaHome)
    }

    Step "Backend-backed Browser E2E prototype"
    try {
        Invoke-ProjectScript "verify-browser-e2e-prototype.ps1" $prototypeArgs
        $browserPrototypeE2EPassed = $true
        Add-Check "Backend-backed Browser E2E readiness" "PASS" "Java backend prototype, API smoke, Vite frontend, and Browser E2E passed." "verify-browser-e2e-prototype.ps1"
    }
    catch {
        Add-Check "Backend-backed Browser E2E readiness" "PENDING" "Java is available, but backend-backed Browser E2E did not pass on this machine." $_.Exception.Message
    }
} elseif ($browserMockE2EPassed) {
    Add-Check "Backend-backed Browser E2E readiness" "PENDING" "Browser E2E passed against mock API, but backend-backed Browser E2E still requires a running Java backend prototype." "Java 17+ is required for start-local-prototype.ps1 or pass -JavaHome <jdk17>."
} else {
    Add-Check "Backend-backed Browser E2E readiness" "PENDING" "Browser/Playwright visual click-path evidence against a running backend is still required." "Mock Browser E2E did not pass on this machine."
}

$pendingDurableChecks = @($script:Checks | Where-Object {
    $_.name -in @(
        "Backend Gradle test readiness",
        "Backend Gradle tests",
        "Durable demo preflight",
        "MariaDB/MinIO full-stack readiness",
        "Real S3 client readiness",
        "Backend-backed Browser E2E readiness",
        "Docker-backed Browser E2E readiness",
        "Durable MVP demo gate"
    ) -and $_.status -eq "PENDING"
})

$result = if ($pendingDurableChecks.Count -eq 0) { "ready" } else { "partial" }
$completionEstimate = [ordered]@{
    mvpDemo = if ($durableDemoGatePassed) { "90-95%" } elseif ($dockerFullStackE2EPassed) { "85-90%" } elseif ($browserPrototypeE2EPassed -and $backendTestsPassed) { "80-85%" } elseif ($browserPrototypeE2EPassed) { "75-80%" } elseif ($browserMockE2EPassed) { "60-65%" } else { "50-60%" }
    product = if ($durableDemoGatePassed) { "20-25%" } elseif ($dockerFullStackE2EPassed) { "20-25%" } else { "15-20%" }
}
$javaHomeArgument = if ($JavaHome) { " -JavaHome `"$JavaHome`"" } else { " -JavaHome <jdk17>" }
$nextCommands = @(
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1 -SkipDocker$javaHomeArgument",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-mock-demo.ps1",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-prototype.ps1$javaHomeArgument",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-preflight.ps1 -S3Client $S3Client",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-gate.ps1 -S3Client $S3Client",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -S3Client $S3Client$javaHomeArgument",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-local-demo.ps1",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-docker-integration.ps1",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client auto -RequireClient",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client aws-js -RequireClient",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client aws-java -RequireClient",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client docker-mc -RequireClient",
    "cd .\osmu-frontend; npm run test:e2e"
)
$checkArray = @($script:Checks | ForEach-Object { $_ })
$pendingDurableNames = @($pendingDurableChecks | ForEach-Object { [string]$_.name })
$report = [pscustomobject]@{
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = $result
    currentDemoStatus = if ($durableDemoGatePassed) { "docker-durable-demo-verified" } elseif ($dockerFullStackE2EPassed) { "docker-full-stack-browser-demo-verified" } elseif ($browserPrototypeE2EPassed) { "backend-prototype-browser-demo-verified" } elseif ($browserMockE2EPassed) { "mock-browser-demo-verified" } else { "mock-demo-verified" }
    completionEstimate = [pscustomobject]@{
        mvpDemo = $completionEstimate["mvpDemo"]
        product = $completionEstimate["product"]
    }
    checks = $checkArray
    pendingDurableChecks = $pendingDurableNames
    nextCommands = $nextCommands
}

$summaryLines = @(
    "# OSMU MVP Demo Readiness",
    "",
    "Generated at: $($report.generatedAt)",
    "Result: $($report.result)",
    "Current demo status: $($report.currentDemoStatus)",
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
    "- MVP demo: $($completionEstimate['mvpDemo'])",
    "- Product: $($completionEstimate['product'])",
    "",
    "## Next Commands",
    ""
)

foreach ($command in $nextCommands) {
    $summaryLines += "- ``$command``"
}

$summary = $summaryLines -join [Environment]::NewLine

if (-not $NoWrite) {
    $resolvedReportPath = Resolve-ProjectPath $ReportPath
    $resolvedSummaryPath = Resolve-ProjectPath $SummaryPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedSummaryPath) | Out-Null
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Set-Content -LiteralPath $resolvedSummaryPath -Value $summary -Encoding UTF8
    Write-Host "Readiness report: $resolvedReportPath"
    Write-Host "Readiness summary: $resolvedSummaryPath"
}

Step "MVP demo readiness summary"
Write-Host $summary

if ($FailIfDurablePending -and $pendingDurableChecks.Count -gt 0) {
    throw "Durable MVP gates are pending: $(($pendingDurableChecks | ForEach-Object { $_.name }) -join ', ')"
}
