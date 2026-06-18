param(
    [string] $DurableGateReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $AuditPath = ".\.osmu-run\latest-mvp-audit.md",
    [string] $DecisionPath = ".\.osmu-run\latest-release-decision.md",
    [string] $ReleaseNotesPath = ".\.osmu-run\latest-release-notes.md",
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $FrontendBase = "http://localhost:5173",
    [switch] $BackendTestsIncluded
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
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

function Get-ReportString($Object, [string] $PropertyName, [string] $DefaultValue = "") {
    if ($null -eq $Object) {
        return $DefaultValue
    }
    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }
    return [string] $property.Value
}

function Read-OptionalJsonReport([string] $Path) {
    if (-not $Path) {
        return $null
    }
    $resolvedPath = Resolve-ProjectPath $Path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return $null
    }
    return Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
}

function Test-ReportCheckPassed($Report, [string] $Name) {
    if ($null -eq $Report -or $null -eq $Report.checks) {
        return $false
    }
    $check = @($Report.checks | Where-Object { $_.name -eq $Name } | Select-Object -First 1)
    return $check.Count -gt 0 -and $check[0].status -eq "PASS"
}

$resolvedDurableGateReportPath = Resolve-ProjectPath $DurableGateReportPath
if (-not (Test-Path -LiteralPath $resolvedDurableGateReportPath)) {
    throw "Durable gate report not found: $resolvedDurableGateReportPath"
}

$durableGate = Get-Content -Raw -LiteralPath $resolvedDurableGateReportPath | ConvertFrom-Json
$durableReady = $durableGate.result -eq "ready" -and $durableGate.currentDemoStatus -eq "docker-durable-demo-verified"
if (-not $durableReady) {
    throw "Durable gate report is not ready: result=$($durableGate.result), currentDemoStatus=$($durableGate.currentDemoStatus)"
}
if (-not $BackendTestsIncluded) {
    throw "Backend test evidence is required for durable release artifacts. Run backend tests first, then pass -BackendTestsIncluded."
}

$resolvedReleaseReportPath = Resolve-ProjectPath $ReleaseReportPath
$releaseReportDirectory = Split-Path -Parent $resolvedReleaseReportPath
if ($releaseReportDirectory) {
    New-Item -ItemType Directory -Force -Path $releaseReportDirectory | Out-Null
}

$selectedS3Client = Get-ReportString $durableGate "selectedS3Client" "docker-mc"
$durablePreflightReportPath = Get-ReportString $durableGate "durablePreflightReportPath" ".\.osmu-run\latest-durable-demo-preflight.json"
$resolvedDurablePreflightReportPath = Resolve-ProjectPath $durablePreflightReportPath
$durablePreflight = Read-OptionalJsonReport $durablePreflightReportPath
$preflightAvailable = $null -ne $durablePreflight

$awsCliAvailable = if ($preflightAvailable) {
    Test-ReportCheckPassed $durablePreflight "AWS CLI"
} else {
    $selectedS3Client -eq "aws"
}
$mcAvailable = if ($preflightAvailable) {
    Test-ReportCheckPassed $durablePreflight "MinIO Client mc"
} else {
    $selectedS3Client -eq "mc"
}
$dockerizedMcAvailable = if ($preflightAvailable) {
    Test-ReportCheckPassed $durablePreflight "Dockerized MinIO Client mc"
} else {
    $selectedS3Client -in @("docker-mc", "auto", "all")
}

$releaseReport = [ordered]@{
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = "passed"
    errorMessage = ""
    apiBase = $ApiBase
    frontendBase = $FrontendBase
    javaHome = $env:JAVA_HOME
    source = "durable-demo-gate"
    durableGateReportPath = $resolvedDurableGateReportPath
    durablePreflightReportPath = $resolvedDurablePreflightReportPath
    selectedS3Client = $selectedS3Client
    scope = [ordered]@{
        preflight = "included"
        runtime = "included"
        lightweightApiSmoke = "included"
        seededDemoSmoke = "included"
        s3Smoke = "included"
        buildVerify = "included"
        ciWorkflow = "included"
        durableDockerCiWorkflow = "included"
        realS3ClientCiWorkflow = "included"
        containerSecurityCiWorkflow = "included"
        browserE2ECiWorkflow = "included"
        imageSigningPolicy = "included"
        releaseNotes = "included"
        commercialReadiness = "included"
        openApiContract = "included"
        kubernetesManifests = "included"
        helmChart = "included"
        networkPolicies = "included"
        containerHardening = "included"
        tlsIngress = "included"
        secretRotationPolicy = "included"
        backupRestoreDrill = "included"
        prometheusObservability = "included"
        monitoringArtifacts = "included"
        prometheusOperatorDraft = "included"
        backendTests = if ($BackendTestsIncluded) { "included" } else { "skipped" }
        dockerIntegration = "included"
        dockerRequired = $true
        realS3ClientRequired = $true
        virtualHostedS3Smoke = "included"
        browserE2E = "verified"
        browserE2ENote = "Verified by durable MVP demo gate."
    }
    optionalGates = [ordered]@{
        dockerDaemonAvailable = $true
        dockerDetail = "verified by durable MVP demo gate"
        awsCliAvailable = $awsCliAvailable
        mcAvailable = $mcAvailable
        dockerizedMcAvailable = $dockerizedMcAvailable
        realS3ClientAvailable = $true
    }
    reportPath = $resolvedReleaseReportPath
}

Step "Write durable release report"
$releaseReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedReleaseReportPath -Encoding UTF8
Write-Host "Release report: $resolvedReleaseReportPath"

Step "Write MVP audit"
Invoke-ProjectScript "write-mvp-audit.ps1" @(
    "-ReleaseReportPath", $resolvedReleaseReportPath,
    "-DurableGateReportPath", $resolvedDurableGateReportPath,
    "-OutputPath", (Resolve-ProjectPath $AuditPath)
)

Step "Write MVP release decision"
Invoke-ProjectScript "write-mvp-release-decision.ps1" @(
    "-ReleaseReportPath", $resolvedReleaseReportPath,
    "-DurableGateReportPath", $resolvedDurableGateReportPath,
    "-OutputPath", (Resolve-ProjectPath $DecisionPath),
    "-FailIfDurablePilotNoGo"
)

Step "Write MVP release notes"
Invoke-ProjectScript "write-mvp-release-notes.ps1" @(
    "-ReleaseReportPath", $resolvedReleaseReportPath,
    "-DurableGateReportPath", $resolvedDurableGateReportPath,
    "-AuditPath", (Resolve-ProjectPath $AuditPath),
    "-DecisionPath", (Resolve-ProjectPath $DecisionPath),
    "-OutputPath", (Resolve-ProjectPath $ReleaseNotesPath)
)

Step "Verify MVP release artifacts"
Invoke-ProjectScript "verify-mvp-release-artifacts.ps1" @(
    "-ReleaseReportPath", $resolvedReleaseReportPath,
    "-DurableGateReportPath", $resolvedDurableGateReportPath,
    "-AuditPath", (Resolve-ProjectPath $AuditPath),
    "-DecisionPath", (Resolve-ProjectPath $DecisionPath),
    "-ReleaseNotesPath", (Resolve-ProjectPath $ReleaseNotesPath)
)

Write-Host "Durable release artifacts generated."
