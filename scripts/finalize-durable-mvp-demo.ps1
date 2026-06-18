param(
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [ValidateSet("auto", "aws", "boto3", "aws-js", "mc", "docker-mc", "all")]
    [string] $S3Client = "docker-mc",
    [string] $JavaHome = "",
    [string] $DurableGateReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [string] $DurablePreflightReportPath = ".\.osmu-run\latest-durable-demo-preflight.json",
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $AuditPath = ".\.osmu-run\latest-mvp-audit.md",
    [string] $DecisionPath = ".\.osmu-run\latest-release-decision.md",
    [string] $ReleaseNotesPath = ".\.osmu-run\latest-release-notes.md",
    [string] $ReadinessReportPath = ".\.osmu-run\latest-demo-readiness.json",
    [string] $ReportPath = ".\.osmu-run\latest-durable-mvp-finalize.json",
    [string] $SummaryPath = ".\.osmu-run\latest-durable-mvp-finalize.md",
    [switch] $NoBuild,
    [switch] $PlanOnly,
    [switch] $NoReport
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "java-toolchain.ps1")
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

function Invoke-ProjectScript([string] $ScriptName, [string[]] $Arguments = @()) {
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    Write-Host "    $ScriptName $($Arguments -join ' ')"
    $exitCode = Invoke-OsmuPowerShellScript $scriptPath $Arguments
    if ($exitCode -ne 0) {
        throw "$ScriptName failed with exit code $exitCode."
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

function New-CommandEntry([string] $Name, [string] $ScriptName, [string[]] $Arguments) {
    $powerShell = if (Test-OsmuWindows) { "powershell.exe" } else { "pwsh" }
    $scriptDisplayPath = if (Test-OsmuWindows) { ".\scripts\$ScriptName" } else { "./scripts/$ScriptName" }
    return [ordered]@{
        name = $Name
        script = $ScriptName
        arguments = $Arguments
        command = "$powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptDisplayPath $($Arguments -join ' ')".Trim()
    }
}

function New-BackendCommandEntry() {
    $command = if (Test-OsmuWindows) {
        "cd .\osmu-backend; .\gradlew.bat test"
    }
    else {
        "cd ./osmu-backend; ./gradlew test"
    }
    return [ordered]@{
        name = "Backend Gradle tests"
        script = "osmu-backend/gradlew test"
        arguments = @()
        command = $command
    }
}

$resolvedDurablePreflightReportPath = Resolve-ProjectPath $DurablePreflightReportPath
$resolvedDurableGateReportPath = Resolve-ProjectPath $DurableGateReportPath
$resolvedReleaseReportPath = Resolve-ProjectPath $ReleaseReportPath
$resolvedAuditPath = Resolve-ProjectPath $AuditPath
$resolvedDecisionPath = Resolve-ProjectPath $DecisionPath
$resolvedReleaseNotesPath = Resolve-ProjectPath $ReleaseNotesPath
$resolvedReadinessReportPath = Resolve-ProjectPath $ReadinessReportPath

$preflightArgs = @(
    "-EnvFile", $EnvFile,
    "-EnvExample", $EnvExample,
    "-ComposeFile", $ComposeFile,
    "-S3Client", $S3Client,
    "-ReportPath", $DurablePreflightReportPath
)

$gateArgs = @(
    "-EnvFile", $EnvFile,
    "-EnvExample", $EnvExample,
    "-ComposeFile", $ComposeFile,
    "-S3Client", $S3Client,
    "-ReportPath", $DurableGateReportPath
)
if ($NoBuild) {
    $gateArgs += "-NoBuild"
}

$releaseArgs = @(
    "-DurableGateReportPath", $DurableGateReportPath,
    "-ReleaseReportPath", $ReleaseReportPath,
    "-AuditPath", $AuditPath,
    "-DecisionPath", $DecisionPath,
    "-ReleaseNotesPath", $ReleaseNotesPath,
    "-BackendTestsIncluded"
)

$readinessArgs = @(
    "-S3Client", $S3Client,
    "-ReportPath", $ReadinessReportPath,
    "-FailIfDurablePending"
)
if ($JavaHome) {
    $readinessArgs += @("-JavaHome", $JavaHome)
}

$commands = @(
    (New-CommandEntry "Durable demo preflight" "verify-durable-demo-preflight.ps1" $preflightArgs),
    (New-BackendCommandEntry),
    (New-CommandEntry "Durable MVP demo gate" "verify-durable-demo-gate.ps1" $gateArgs),
    (New-CommandEntry "Durable release artifacts" "write-durable-release-artifacts.ps1" $releaseArgs),
    (New-CommandEntry "MVP demo readiness hard gate" "verify-mvp-demo-readiness.ps1" $readinessArgs)
)

$report = [ordered]@{
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = if ($PlanOnly) { "planned" } else { "pending" }
    currentDemoStatus = if ($PlanOnly) { "durable-mvp-finalize-plan" } else { "durable-mvp-finalize-running" }
    selectedS3Client = $S3Client
    noBuild = [bool] $NoBuild
    durablePreflightReportPath = $resolvedDurablePreflightReportPath
    durableGateReportPath = $resolvedDurableGateReportPath
    releaseReportPath = $resolvedReleaseReportPath
    auditPath = $resolvedAuditPath
    decisionPath = $resolvedDecisionPath
    releaseNotesPath = $resolvedReleaseNotesPath
    readinessReportPath = $resolvedReadinessReportPath
    commands = $commands
}

if ($PlanOnly) {
    Step "Durable MVP finalize plan"
    foreach ($command in $commands) {
        Write-Host "- $($command.name): $($command.command)"
    }
}
else {
    Step "Java toolchain"
    Use-OsmuJavaHome $JavaHome | Out-Null
    Assert-OsmuJavaAvailable -RequiredVersion 17 | Out-Host

    Step "Durable demo preflight"
    Invoke-ProjectScript "verify-durable-demo-preflight.ps1" $preflightArgs

    Step "Backend Gradle tests"
    Invoke-BackendTests

    Step "Durable MVP demo gate"
    Invoke-ProjectScript "verify-durable-demo-gate.ps1" $gateArgs

    Step "Durable release artifacts"
    Invoke-ProjectScript "write-durable-release-artifacts.ps1" $releaseArgs

    Step "MVP demo readiness hard gate"
    Invoke-ProjectScript "verify-mvp-demo-readiness.ps1" $readinessArgs

    $report["result"] = "ready"
    $report["currentDemoStatus"] = "docker-durable-demo-verified"
    $report["completionEstimate"] = [ordered]@{
        mvpDemo = "90-95%"
        product = "20-25%"
    }
}

$summaryLines = @(
    "# OSMU Durable MVP Finalize",
    "",
    "Generated at: $($report.generatedAt)",
    "Result: $($report.result)",
    "Current demo status: $($report.currentDemoStatus)",
    "Selected S3 client: $($report.selectedS3Client)",
    "",
    "## Artifact Paths",
    "",
    "- Durable preflight: $($report.durablePreflightReportPath)",
    "- Durable gate: $($report.durableGateReportPath)",
    "- Release report: $($report.releaseReportPath)",
    "- MVP audit: $($report.auditPath)",
    "- Release decision: $($report.decisionPath)",
    "- Release notes: $($report.releaseNotesPath)",
    "- Readiness report: $($report.readinessReportPath)",
    "",
    "## Commands",
    ""
)

foreach ($command in $commands) {
    $summaryLines += "- $($command.name): ``$($command.command)``"
}

$summary = $summaryLines -join [Environment]::NewLine

if (-not $NoReport) {
    $resolvedReportPath = Resolve-ProjectPath $ReportPath
    $resolvedSummaryPath = Resolve-ProjectPath $SummaryPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedSummaryPath) | Out-Null
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Set-Content -LiteralPath $resolvedSummaryPath -Value $summary -Encoding UTF8
    Write-Host "Durable MVP finalize report: $resolvedReportPath"
    Write-Host "Durable MVP finalize summary: $resolvedSummaryPath"
}

Step "Durable MVP finalize summary"
Write-Host $summary
