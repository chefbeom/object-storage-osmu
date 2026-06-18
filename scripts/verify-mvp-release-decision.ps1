$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$decisionScript = Join-Path $PSScriptRoot "write-mvp-release-decision.ps1"
$selfTestDir = Join-Path $root ".osmu-run\decision-self-test"

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Assert-Contains([string] $text, [string] $expected) {
    if (-not $text.Contains($expected)) {
        throw "Expected decision output to contain '$expected'."
    }
}

function New-Scope([string] $DockerIntegration, [bool] $RealS3ClientRequired, [string] $BrowserE2E) {
    return [ordered]@{
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
        backendTests = "included"
        dockerIntegration = $DockerIntegration
        dockerRequired = $DockerIntegration -eq "included"
        realS3ClientRequired = $RealS3ClientRequired
        virtualHostedS3Smoke = "skipped"
        browserE2E = $BrowserE2E
        browserE2ENote = ""
    }
}

function New-OptionalGates([bool] $Docker, [bool] $Aws, [bool] $Mc) {
    return [ordered]@{
        dockerDaemonAvailable = $Docker
        dockerDetail = if ($Docker) { '"24.0.0"' } else { "docker daemon unavailable" }
        awsCliAvailable = $Aws
        mcAvailable = $Mc
        dockerizedMcAvailable = $Docker
        realS3ClientAvailable = $Aws -or $Mc -or $Docker
    }
}

function Write-SampleReport([string] $Path, [object] $Scope, [object] $OptionalGates, [string] $Result = "passed") {
    $report = [ordered]@{
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        result = $Result
        errorMessage = ""
        apiBase = "http://localhost:8080/api"
        frontendBase = "http://localhost:5173"
        javaHome = ""
        scope = $Scope
        optionalGates = $OptionalGates
        reportPath = $Path
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-SampleDurableGateReport([string] $Path, [string] $Result = "ready") {
    $report = [ordered]@{
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        result = $Result
        currentDemoStatus = if ($Result -eq "ready") { "docker-durable-demo-verified" } else { "docker-durable-demo-partial" }
        failureMessage = ""
        completionEstimate = [ordered]@{
            mvpDemo = if ($Result -eq "ready") { "90-95%" } else { "70-85%" }
            product = if ($Result -eq "ready") { "20-25%" } else { "15-20%" }
        }
        checks = @()
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-DecisionScript([string[]] $Arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $decisionScript @Arguments 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = ($output -join [Environment]::NewLine)
        }
    }
    catch {
        $exitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output = ($_.Exception.Message)
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

New-Item -ItemType Directory -Force -Path $selfTestDir | Out-Null
$missingDurableGateReport = Join-Path $selfTestDir "missing-durable-gate-report.json"
Remove-Item -LiteralPath $missingDurableGateReport -Force -ErrorAction SilentlyContinue

Step "Lightweight demo decision"
$lightweightReport = Join-Path $selfTestDir "lightweight-report.json"
Write-SampleReport `
    -Path $lightweightReport `
    -Scope (New-Scope -DockerIntegration "skipped" -RealS3ClientRequired $false -BrowserE2E "pending") `
    -OptionalGates (New-OptionalGates -Docker $false -Aws $false -Mc $false)
$lightweightResult = Invoke-DecisionScript @("-ReleaseReportPath", $lightweightReport, "-DurableGateReportPath", $missingDurableGateReport, "-NoWrite")
if ($lightweightResult.ExitCode -ne 0) {
    throw "Lightweight decision script failed: $($lightweightResult.Output)"
}
Assert-Contains $lightweightResult.Output "- Lightweight demo candidate: GO"
Assert-Contains $lightweightResult.Output "- Durable MVP pilot: NO-GO"

Step "Durable pilot decision"
$durableReport = Join-Path $selfTestDir "durable-report.json"
Write-SampleReport `
    -Path $durableReport `
    -Scope (New-Scope -DockerIntegration "included" -RealS3ClientRequired $true -BrowserE2E "verified") `
    -OptionalGates (New-OptionalGates -Docker $true -Aws $true -Mc $false)
$durableResult = Invoke-DecisionScript @("-ReleaseReportPath", $durableReport, "-DurableGateReportPath", $missingDurableGateReport, "-NoWrite")
if ($durableResult.ExitCode -ne 0) {
    throw "Durable decision script failed: $($durableResult.Output)"
}
Assert-Contains $durableResult.Output "- Lightweight demo candidate: GO"
Assert-Contains $durableResult.Output "- Durable MVP pilot: GO"

Step "Durable gate report decision"
$durableGateOnlyReport = Join-Path $selfTestDir "durable-gate-only-release-report.json"
$durableGateReport = Join-Path $selfTestDir "durable-gate-report.json"
Write-SampleReport `
    -Path $durableGateOnlyReport `
    -Scope (New-Scope -DockerIntegration "skipped" -RealS3ClientRequired $false -BrowserE2E "pending") `
    -OptionalGates (New-OptionalGates -Docker $false -Aws $false -Mc $false)
Write-SampleDurableGateReport -Path $durableGateReport -Result "ready"
$durableGateResult = Invoke-DecisionScript @("-ReleaseReportPath", $durableGateOnlyReport, "-DurableGateReportPath", $durableGateReport, "-NoWrite")
if ($durableGateResult.ExitCode -ne 0) {
    throw "Durable gate report decision script failed: $($durableGateResult.Output)"
}
Assert-Contains $durableGateResult.Output "- Lightweight demo candidate: GO"
Assert-Contains $durableGateResult.Output "- Durable MVP pilot: GO"
Assert-Contains $durableGateResult.Output "- [PASS] Durable MVP demo gate report"

Step "Durable no-go failure switch"
$failureResult = Invoke-DecisionScript @("-ReleaseReportPath", $lightweightReport, "-DurableGateReportPath", $missingDurableGateReport, "-NoWrite", "-FailIfDurablePilotNoGo")
if ($failureResult.ExitCode -eq 0 -or -not $failureResult.Output.Contains("Durable MVP pilot decision is NO-GO")) {
    throw "-FailIfDurablePilotNoGo did not fail for lightweight-only report."
}

Write-Host ""
Write-Host "MVP release decision self-test passed."
