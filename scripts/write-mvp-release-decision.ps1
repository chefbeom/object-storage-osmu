param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $DurableGateReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [string] $StorageExpansionFinalizeReportPath = ".\.osmu-run\latest-storage-expansion-finalize.json",
    [string] $KubernetesDrFinalizeReportPath = ".\.osmu-run\latest-kubernetes-dr-finalize.json",
    [string] $SecurityEvidenceFinalizeReportPath = ".\.osmu-run\latest-security-evidence-finalize.json",
    [string] $OutputPath = ".\.osmu-run\latest-release-decision.md",
    [switch] $FailIfDurablePilotNoGo,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Gate-Line([bool] $passed, [string] $label, [string] $detail = "") {
    $status = if ($passed) { "PASS" } else { "PENDING" }
    if ($detail) {
        return "- [$status] $label - $detail"
    }
    return "- [$status] $label"
}

function Read-DurableGateReport([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $false
            passed = $false
            result = "missing"
            currentDemoStatus = "missing"
            detail = "report not found"
        }
    }

    try {
        $gateReport = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
        $passed = $gateReport.result -eq "ready" -and $gateReport.currentDemoStatus -eq "docker-durable-demo-verified"
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$gateReport.result
            currentDemoStatus = [string]$gateReport.currentDemoStatus
            detail = "result=$($gateReport.result), currentDemoStatus=$($gateReport.currentDemoStatus)"
        }
    }
    catch {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $false
            result = "unreadable"
            currentDemoStatus = "unreadable"
            detail = $_.Exception.Message
        }
    }
}

function Read-StorageExpansionFinalizeReport([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $false
            passed = $false
            result = "missing"
            detail = "report not found"
        }
    }

    try {
        $finalizeReport = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
        $passed = $finalizeReport.result -eq "passed"
        $backend = $finalizeReport.backend
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$finalizeReport.result
            detail = "result=$($finalizeReport.result), namespace=$($finalizeReport.namespace), tenant=$($finalizeReport.tenantName), runDryRunRunner=$($backend.runDryRunRunner), runApply=$($backend.runApply)"
        }
    }
    catch {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $false
            result = "unreadable"
            detail = $_.Exception.Message
        }
    }
}

function Read-KubernetesDrFinalizeReport([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $false
            passed = $false
            result = "missing"
            detail = "report not found"
        }
    }

    try {
        $finalizeReport = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
        $passed = $finalizeReport.result -eq "ready"
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$finalizeReport.result
            detail = "result=$($finalizeReport.result), status=$($finalizeReport.status), sourceNamespace=$($finalizeReport.sourceNamespace), restoreNamespace=$($finalizeReport.restoreNamespace), backupTimestamp=$($finalizeReport.backupTimestamp), serverDryRunOnly=$($finalizeReport.serverDryRunOnly), confirmRestore=$($finalizeReport.confirmRestore), submitEvidence=$($finalizeReport.submitEvidence)"
        }
    }
    catch {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $false
            result = "unreadable"
            detail = $_.Exception.Message
        }
    }
}

function Read-SecurityEvidenceFinalizeReport([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $false
            passed = $false
            result = "missing"
            detail = "report not found"
        }
    }

    try {
        $finalizeReport = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
        $passed = $finalizeReport.result -eq "passed"
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$finalizeReport.result
            detail = "result=$($finalizeReport.result), failureCount=$($finalizeReport.failureCount)"
        }
    }
    catch {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $false
            result = "unreadable"
            detail = $_.Exception.Message
        }
    }
}

$resolvedReleaseReportPath = Resolve-ProjectPath $ReleaseReportPath
if (-not (Test-Path -LiteralPath $resolvedReleaseReportPath)) {
    throw "Release report not found: $resolvedReleaseReportPath. Run scripts\verify-prototype-release.ps1 first."
}

$report = Get-Content -Raw -LiteralPath $resolvedReleaseReportPath | ConvertFrom-Json
$scope = $report.scope
$optionalGates = $report.optionalGates

$lightweightDemoGo = $report.result -eq "passed" `
    -and $scope.preflight -eq "included" `
    -and $scope.runtime -eq "included" `
    -and $scope.lightweightApiSmoke -eq "included" `
    -and $scope.seededDemoSmoke -eq "included" `
    -and $scope.s3Smoke -eq "included" `
    -and $scope.buildVerify -eq "included" `
    -and $scope.ciWorkflow -eq "included" `
    -and $scope.durableDockerCiWorkflow -eq "included" `
    -and $scope.realS3ClientCiWorkflow -eq "included" `
    -and $scope.containerSecurityCiWorkflow -eq "included" `
    -and $scope.browserE2ECiWorkflow -eq "included" `
    -and $scope.imageSigningPolicy -eq "included" `
    -and $scope.releaseNotes -eq "included" `
    -and $scope.commercialReadiness -eq "included" `
    -and $scope.openApiContract -eq "included" `
    -and $scope.kubernetesManifests -eq "included" `
    -and $scope.helmChart -eq "included" `
    -and $scope.networkPolicies -eq "included" `
    -and $scope.containerHardening -eq "included" `
    -and $scope.tlsIngress -eq "included" `
    -and $scope.secretRotationPolicy -eq "included" `
    -and $scope.backupRestoreDrill -eq "included" `
    -and $scope.prometheusObservability -eq "included" `
    -and $scope.monitoringArtifacts -eq "included" `
    -and $scope.prometheusOperatorDraft -eq "included" `
    -and $scope.backendTests -eq "included"

$dockerPilotGate = [bool]$optionalGates.dockerDaemonAvailable -and $scope.dockerIntegration -eq "included"
$realS3PilotGate = [bool]$optionalGates.realS3ClientAvailable -and [bool]$scope.realS3ClientRequired
$browserPilotGate = $scope.browserE2E -eq "verified"
$durableGate = Read-DurableGateReport $DurableGateReportPath
$durableGatePassed = [bool]$durableGate.passed
$storageExpansionFinalize = Read-StorageExpansionFinalizeReport $StorageExpansionFinalizeReportPath
$storageExpansionFinalizePassed = [bool]$storageExpansionFinalize.passed
$kubernetesDrFinalize = Read-KubernetesDrFinalizeReport $KubernetesDrFinalizeReportPath
$kubernetesDrFinalizePassed = [bool]$kubernetesDrFinalize.passed
$securityEvidenceFinalize = Read-SecurityEvidenceFinalizeReport $SecurityEvidenceFinalizeReportPath
$securityEvidenceFinalizePassed = [bool]$securityEvidenceFinalize.passed
$durablePilotGo = $lightweightDemoGo -and (($dockerPilotGate -and $realS3PilotGate -and $browserPilotGate) -or $durableGatePassed)

$lightweightDecision = if ($lightweightDemoGo) { "GO" } else { "NO-GO" }
$durableDecision = if ($durablePilotGo) { "GO" } else { "NO-GO" }

$decisionLines = @(
    "# OSMU MVP Release Decision",
    "",
    "Generated at: $([DateTimeOffset]::Now.ToString("o"))",
    "Release report: $resolvedReleaseReportPath",
    "",
    "## Decision",
    "",
    "- Lightweight demo candidate: $lightweightDecision",
    "- Durable MVP pilot: $durableDecision",
    "",
    "## Lightweight Demo Gate",
    "",
    (Gate-Line ($report.result -eq "passed") "Release report result" "result=$($report.result)"),
    (Gate-Line ($scope.preflight -eq "included") "Preflight included" "scope.preflight=$($scope.preflight)"),
    (Gate-Line ($scope.runtime -eq "included") "Runtime health included" "scope.runtime=$($scope.runtime)"),
    (Gate-Line ($scope.lightweightApiSmoke -eq "included") "Lightweight API smoke included" "scope.lightweightApiSmoke=$($scope.lightweightApiSmoke)"),
    (Gate-Line ($scope.seededDemoSmoke -eq "included") "Seeded demo smoke included" "scope.seededDemoSmoke=$($scope.seededDemoSmoke)"),
    (Gate-Line ($scope.s3Smoke -eq "included") "Built-in S3 smoke included" "scope.s3Smoke=$($scope.s3Smoke)"),
    (Gate-Line ($scope.buildVerify -eq "included") "Build verify included" "scope.buildVerify=$($scope.buildVerify)"),
    (Gate-Line ($scope.ciWorkflow -eq "included") "CI workflow draft included" "scope.ciWorkflow=$($scope.ciWorkflow)"),
    (Gate-Line ($scope.durableDockerCiWorkflow -eq "included") "Durable Docker CI workflow draft included" "scope.durableDockerCiWorkflow=$($scope.durableDockerCiWorkflow)"),
    (Gate-Line ($scope.realS3ClientCiWorkflow -eq "included") "Real S3 client CI workflow draft included" "scope.realS3ClientCiWorkflow=$($scope.realS3ClientCiWorkflow)"),
    (Gate-Line ($scope.containerSecurityCiWorkflow -eq "included") "Container security CI workflow draft included" "scope.containerSecurityCiWorkflow=$($scope.containerSecurityCiWorkflow)"),
    (Gate-Line ($scope.browserE2ECiWorkflow -eq "included") "Browser E2E CI workflow draft included" "scope.browserE2ECiWorkflow=$($scope.browserE2ECiWorkflow)"),
    (Gate-Line ($scope.imageSigningPolicy -eq "included") "Image signing policy/workflow draft included" "scope.imageSigningPolicy=$($scope.imageSigningPolicy)"),
    (Gate-Line ($scope.releaseNotes -eq "included") "Release notes generation included" "scope.releaseNotes=$($scope.releaseNotes)"),
    (Gate-Line ($scope.commercialReadiness -eq "included") "Commercial readiness draft included" "scope.commercialReadiness=$($scope.commercialReadiness)"),
    (Gate-Line ($scope.openApiContract -eq "included") "OpenAPI contract included" "scope.openApiContract=$($scope.openApiContract)"),
    (Gate-Line ($scope.kubernetesManifests -eq "included") "Kubernetes manifest draft included" "scope.kubernetesManifests=$($scope.kubernetesManifests)"),
    (Gate-Line ($scope.helmChart -eq "included") "Helm chart draft included" "scope.helmChart=$($scope.helmChart)"),
    (Gate-Line ($scope.networkPolicies -eq "included") "NetworkPolicy draft included" "scope.networkPolicies=$($scope.networkPolicies)"),
    (Gate-Line ($scope.containerHardening -eq "included") "Container hardening draft included" "scope.containerHardening=$($scope.containerHardening)"),
    (Gate-Line ($scope.tlsIngress -eq "included") "TLS ingress draft included" "scope.tlsIngress=$($scope.tlsIngress)"),
    (Gate-Line ($scope.secretRotationPolicy -eq "included") "Secret rotation policy draft included" "scope.secretRotationPolicy=$($scope.secretRotationPolicy)"),
    (Gate-Line ($scope.backupRestoreDrill -eq "included") "Backup restore drill draft included" "scope.backupRestoreDrill=$($scope.backupRestoreDrill)"),
    (Gate-Line ($scope.prometheusObservability -eq "included") "Prometheus observability draft included" "scope.prometheusObservability=$($scope.prometheusObservability)"),
    (Gate-Line ($scope.monitoringArtifacts -eq "included") "Monitoring artifacts draft included" "scope.monitoringArtifacts=$($scope.monitoringArtifacts)"),
    (Gate-Line ($scope.prometheusOperatorDraft -eq "included") "Prometheus Operator draft included" "scope.prometheusOperatorDraft=$($scope.prometheusOperatorDraft)"),
    (Gate-Line ($scope.backendTests -eq "included") "Backend tests included" "scope.backendTests=$($scope.backendTests)"),
    "",
    "## Operations Evidence Gate",
    "",
    (Gate-Line $storageExpansionFinalizePassed "Storage expansion finalizer evidence" "$($storageExpansionFinalize.detail), report=$($storageExpansionFinalize.path)"),
    (Gate-Line $kubernetesDrFinalizePassed "Kubernetes DR finalizer evidence" "$($kubernetesDrFinalize.detail), report=$($kubernetesDrFinalize.path)"),
    (Gate-Line $securityEvidenceFinalizePassed "Security evidence finalizer" "$($securityEvidenceFinalize.detail), report=$($securityEvidenceFinalize.path)"),
    "",
    "## Durable Pilot Gate",
    "",
    (Gate-Line $dockerPilotGate "Docker/MariaDB/MinIO integration" "dockerIntegration=$($scope.dockerIntegration), dockerDaemon=$($optionalGates.dockerDaemonAvailable)"),
    (Gate-Line $realS3PilotGate "Real S3 client required and available" "realS3ClientRequired=$($scope.realS3ClientRequired), aws=$($optionalGates.awsCliAvailable), boto3=$($optionalGates.boto3Available), mc=$($optionalGates.mcAvailable), dockerizedMc=$($optionalGates.dockerizedMcAvailable)"),
    (Gate-Line $browserPilotGate "Browser E2E verified" "browserE2E=$($scope.browserE2E)"),
    (Gate-Line $durableGatePassed "Durable MVP demo gate report" "$($durableGate.detail), report=$($durableGate.path)"),
    "",
    "## Next Action",
    ""
)

if ($durablePilotGo) {
    $decisionLines += "- Durable MVP pilot gates passed. Prepare pilot release notes and deployment hardening review."
} elseif ($lightweightDemoGo) {
    $decisionLines += "- Lightweight demo can be shown locally. Durable MVP pilot remains blocked by pending external gates."
} else {
    $decisionLines += "- Lightweight demo is not release-ready. Re-run the prototype release gate and inspect failures."
}

$decision = $decisionLines -join [Environment]::NewLine

if (-not $NoWrite) {
    $resolvedOutputPath = Resolve-ProjectPath $OutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
    Set-Content -LiteralPath $resolvedOutputPath -Value $decision -Encoding UTF8
    Write-Host "MVP release decision: $resolvedOutputPath"
}

Write-Host $decision

if ($FailIfDurablePilotNoGo -and -not $durablePilotGo) {
    throw "Durable MVP pilot decision is NO-GO."
}
