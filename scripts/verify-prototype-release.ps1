param(
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $FrontendBase = "http://localhost:5173",
    [string] $JavaHome = "",
    [switch] $ReseedDemo,
    [switch] $SkipBackendTests,
    [switch] $SkipS3ClientSmoke,
    [switch] $IncludeVirtualHostedS3Smoke,
    [switch] $RequireDocker,
    [switch] $RequireS3Client,
    [switch] $RunDockerIntegration,
    [switch] $BrowserE2EVerified,
    [string] $BrowserE2ENote = "Browser E2E pending; in-app browser automation failed in this environment.",
    [string] $ReportPath = ".\.osmu-run\latest-release.json",
    [string] $DurableGateReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [switch] $NoReport
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Invoke-ProjectScript($scriptName, [string[]] $arguments = @()) {
    $scriptPath = Join-Path $PSScriptRoot $scriptName
    Write-Host "    $scriptName $($arguments -join ' ')"
    & powershell -ExecutionPolicy Bypass -File $scriptPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$scriptName failed with exit code $LASTEXITCODE."
    }
}

function Invoke-Capture([string] $Executable, [string[]] $Arguments = @()) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Executable @Arguments 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = ($output -join " ")
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Get-OptionalGateStatus() {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    $dockerDaemon = $false
    $dockerDetail = "docker not found on PATH."
    if ($docker) {
        $dockerInfo = Invoke-Capture $docker.Source @("info", "--format", "{{json .ServerVersion}}")
        $dockerDaemon = $dockerInfo.ExitCode -eq 0
        $dockerDetail = if ($dockerDaemon) { $dockerInfo.Output } else { $dockerInfo.Output }
    }

    $aws = Get-Command aws -ErrorAction SilentlyContinue
    $mc = Get-Command mc -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        dockerDaemonAvailable = $dockerDaemon
        dockerDetail = $dockerDetail
        awsCliAvailable = [bool]$aws
        mcAvailable = [bool]$mc
        dockerizedMcAvailable = $dockerDaemon
        realS3ClientAvailable = [bool]($aws -or $mc -or $dockerDaemon)
    }
}

function Write-ReleaseReport([string] $Result = "passed", [string] $ErrorMessage = "") {
    if ($NoReport) {
        return
    }

    $resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) {
        [System.IO.Path]::GetFullPath($ReportPath)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $root $ReportPath))
    }
    $reportDirectory = Split-Path -Parent $resolvedReportPath
    if ($reportDirectory) {
        New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
    }

    $optionalGates = Get-OptionalGateStatus
    $report = [ordered]@{
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        result = $Result
        errorMessage = $ErrorMessage
        apiBase = $ApiBase
        frontendBase = $FrontendBase
        javaHome = $JavaHome
        scope = [ordered]@{
            preflight = "included"
            runtime = "included"
            lightweightApiSmoke = "included"
            seededDemoSmoke = "included"
            s3Smoke = if ($SkipS3ClientSmoke) { "skipped" } else { "included" }
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
            backendTests = if ($SkipBackendTests) { "skipped" } else { "included" }
            dockerIntegration = if ($RunDockerIntegration) { "included" } else { "skipped" }
            dockerRequired = [bool]($RequireDocker -or $RunDockerIntegration)
            realS3ClientRequired = [bool]$RequireS3Client
            virtualHostedS3Smoke = if ($IncludeVirtualHostedS3Smoke) { "included" } else { "skipped" }
            browserE2E = if ($BrowserE2EVerified) { "verified" } else { "pending" }
            browserE2ENote = $BrowserE2ENote
        }
        optionalGates = $optionalGates
        reportPath = $resolvedReportPath
    }

    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Release report: $resolvedReportPath"
}

trap {
    $releaseError = $_
    try {
        Write-ReleaseReport -Result "failed" -ErrorMessage $releaseError.Exception.Message
    }
    catch {
        Write-Warning "Release report write failed: $($_.Exception.Message)"
    }
    throw $releaseError
}

Step "Prototype release preflight"
$preflightArguments = @(
    "-ApiBase", $ApiBase,
    "-FrontendBase", $FrontendBase,
    "-RequireJava",
    "-RequireNode",
    "-RequireRuntime"
)
if ($JavaHome) {
    $preflightArguments += @("-JavaHome", $JavaHome)
}
if ($RequireDocker -or $RunDockerIntegration) {
    $preflightArguments += "-RequireDocker"
}
if ($RequireS3Client) {
    $preflightArguments += "-RequireS3Client"
}
Invoke-ProjectScript "verify-prototype-prerequisites.ps1" $preflightArguments

Step "Prototype functional gate"
$gateArguments = @(
    "-ApiBase", $ApiBase,
    "-FrontendBase", $FrontendBase,
    "-IncludeBuildVerify"
)
if ($JavaHome) {
    $gateArguments += @("-JavaHome", $JavaHome)
}
if ($ReseedDemo) {
    $gateArguments += "-ReseedDemo"
}
if (-not $SkipBackendTests) {
    $gateArguments += "-IncludeBackendTests"
}
if ($SkipS3ClientSmoke) {
    $gateArguments += "-SkipS3ClientSmoke"
}
if ($IncludeVirtualHostedS3Smoke) {
    $gateArguments += "-IncludeVirtualHostedS3Smoke"
}
Invoke-ProjectScript "verify-prototype-gate.ps1" $gateArguments

if ($RunDockerIntegration) {
    Step "Docker integration gate"
    Invoke-ProjectScript "verify-docker-integration.ps1"
}

Step "Prototype release gate passed"
Write-Host "MVP release checks passed for the configured scope."
Write-Host "Docker integration: $(if ($RunDockerIntegration) { 'included' } else { 'skipped' })"
Write-Host "Real S3 client required: $(if ($RequireS3Client) { 'yes' } else { 'no' })"
Write-Host "Backend tests: $(if ($SkipBackendTests) { 'skipped' } else { 'included' })"
Write-Host "CI workflow: included"
Write-Host "Durable Docker CI workflow: included"
Write-Host "Real S3 client CI workflow: included"
Write-Host "Container security CI workflow: included"
Write-Host "Browser E2E CI workflow: included"
Write-Host "Image signing policy: included"
Write-Host "Release notes: included"
Write-Host "Commercial readiness: included"
Write-Host "OpenAPI contract: included"
Write-Host "Kubernetes manifests: included"
Write-Host "Helm chart: included"
Write-Host "Network policies: included"
Write-Host "Container hardening: included"
Write-Host "TLS ingress: included"
Write-Host "Secret rotation policy: included"
Write-Host "Backup restore drill: included"
Write-Host "Prometheus observability: included"
Write-Host "Monitoring artifacts: included"
Write-Host "Prometheus Operator draft: included"
Write-ReleaseReport

if (-not $NoReport) {
    Step "Prototype release artifacts"
    Invoke-ProjectScript "write-mvp-audit.ps1" @("-ReleaseReportPath", $ReportPath, "-DurableGateReportPath", $DurableGateReportPath)
    Invoke-ProjectScript "write-mvp-release-decision.ps1" @("-ReleaseReportPath", $ReportPath, "-DurableGateReportPath", $DurableGateReportPath)
    Invoke-ProjectScript "write-mvp-release-notes.ps1" @("-ReleaseReportPath", $ReportPath, "-DurableGateReportPath", $DurableGateReportPath)
    Invoke-ProjectScript "verify-mvp-release-artifacts.ps1" @("-ReleaseReportPath", $ReportPath, "-DurableGateReportPath", $DurableGateReportPath)
}

