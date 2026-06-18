param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $DurableGateReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [string] $StorageExpansionFinalizeReportPath = ".\.osmu-run\latest-storage-expansion-finalize.json",
    [string] $KubernetesDrFinalizeReportPath = ".\.osmu-run\latest-kubernetes-dr-finalize.json",
    [string] $SecurityEvidenceFinalizeReportPath = ".\.osmu-run\latest-security-evidence-finalize.json",
    [string] $AuditPath = ".\.osmu-run\latest-mvp-audit.md",
    [string] $DecisionPath = ".\.osmu-run\latest-release-decision.md",
    [string] $OutputPath = ".\.osmu-run\latest-release-notes.md",
    [string] $Version = "MVP v0.1",
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

function Assert-FileExists([string] $path, [string] $label) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "$label not found: $path"
    }
}

function Scope-Line([object] $scope, [string] $name, [string] $label) {
    $value = $scope.$name
    if ($value -eq "included") {
        return "- ${label}: included"
    }
    return "- ${label}: $value"
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
$durableGate = Read-DurableGateReport $DurableGateReportPath
$storageExpansionFinalize = Read-StorageExpansionFinalizeReport $StorageExpansionFinalizeReportPath
$kubernetesDrFinalize = Read-KubernetesDrFinalizeReport $KubernetesDrFinalizeReportPath
$securityEvidenceFinalize = Read-SecurityEvidenceFinalizeReport $SecurityEvidenceFinalizeReportPath
$resolvedAuditPath = Resolve-ProjectPath $AuditPath
$resolvedDecisionPath = Resolve-ProjectPath $DecisionPath

Assert-FileExists $resolvedReleaseReportPath "Release report"
Assert-FileExists $resolvedAuditPath "MVP audit"
Assert-FileExists $resolvedDecisionPath "MVP release decision"

$report = Get-Content -Raw -LiteralPath $resolvedReleaseReportPath | ConvertFrom-Json
$decision = Get-Content -Raw -LiteralPath $resolvedDecisionPath
$scope = $report.scope
$optionalGates = $report.optionalGates

$lightweightDecision = if ($decision.Contains("- Lightweight demo candidate: GO")) { "GO" } else { "NO-GO" }
$durableDecision = if ($decision.Contains("- Durable MVP pilot: GO")) { "GO" } else { "NO-GO" }
$durableGatePassed = [bool]$durableGate.passed

$notesLines = @(
    "# OSMU $Version Release Notes",
    "",
    "Generated at: $([DateTimeOffset]::Now.ToString("o"))",
    "Release report: $resolvedReleaseReportPath",
    "Durable gate report: $($durableGate.path)",
    "Storage expansion finalizer report: $($storageExpansionFinalize.path)",
    "Kubernetes DR finalizer report: $($kubernetesDrFinalize.path)",
    "Security evidence finalizer report: $($securityEvidenceFinalize.path)",
    "MVP audit: $resolvedAuditPath",
    "MVP release decision: $resolvedDecisionPath",
    "",
    "## Decision",
    "",
    "- Lightweight demo candidate: $lightweightDecision",
    "- Durable MVP pilot: $durableDecision",
    "",
    "## Demo Runtime",
    "",
    "- Backend API: $($report.apiBase)",
    "- Frontend: $($report.frontendBase)",
    "- Latest release gate result: $($report.result)",
    '- Demo credentials: stored in `.osmu-run/latest-demo.json`; do not commit runtime secrets.',
    "",
    "## Included Evidence",
    "",
    (Scope-Line $scope "runtime" "Runtime health"),
    (Scope-Line $scope "lightweightApiSmoke" "Lightweight API smoke"),
    (Scope-Line $scope "seededDemoSmoke" "Seeded demo smoke"),
    (Scope-Line $scope "s3Smoke" "Built-in S3 SigV4 smoke"),
    (Scope-Line $scope "buildVerify" "Build verification"),
    (Scope-Line $scope "backendTests" "Backend tests"),
    (Scope-Line $scope "ciWorkflow" "Prototype CI workflow draft"),
    (Scope-Line $scope "durableDockerCiWorkflow" "Durable Docker CI workflow draft"),
    (Scope-Line $scope "realS3ClientCiWorkflow" "Real S3 client CI workflow draft"),
    (Scope-Line $scope "containerSecurityCiWorkflow" "Container security/SBOM workflow draft"),
    (Scope-Line $scope "browserE2ECiWorkflow" "Browser E2E CI workflow draft"),
    (Scope-Line $scope "imageSigningPolicy" "Image signing policy/workflow draft"),
    (Scope-Line $scope "releaseNotes" "Release notes generation"),
    (Scope-Line $scope "commercialReadiness" "Commercial readiness draft"),
    (Scope-Line $scope "openApiContract" "OpenAPI MVP contract"),
    (Scope-Line $scope "kubernetesManifests" "Kubernetes manifest draft"),
    (Scope-Line $scope "helmChart" "Helm chart draft"),
    (Scope-Line $scope "networkPolicies" "NetworkPolicy draft"),
    (Scope-Line $scope "containerHardening" "Container hardening draft"),
    (Scope-Line $scope "tlsIngress" "TLS ingress draft"),
    (Scope-Line $scope "secretRotationPolicy" "Secret rotation policy draft"),
    (Scope-Line $scope "backupRestoreDrill" "Backup restore drill draft"),
    (Scope-Line $scope "prometheusObservability" "Prometheus observability draft"),
    (Scope-Line $scope "monitoringArtifacts" "Monitoring artifacts draft"),
    (Scope-Line $scope "prometheusOperatorDraft" "Prometheus Operator draft"),
    "- Durable MVP demo gate report: $($durableGate.detail)",
    "- Storage expansion finalizer report: $($storageExpansionFinalize.detail)",
    "- Kubernetes DR finalizer report: $($kubernetesDrFinalize.detail)",
    "- Security evidence finalizer report: $($securityEvidenceFinalize.detail)",
    "",
    "## External and Durable Evidence",
    "",
    "- Durable MVP demo gate report: $($durableGate.detail)",
    "- Storage expansion finalizer report: $($storageExpansionFinalize.detail)",
    "- Kubernetes DR finalizer report: $($kubernetesDrFinalize.detail)",
    "- Security evidence finalizer report: $($securityEvidenceFinalize.detail)",
    "- Docker/MariaDB/MinIO integration: dockerIntegration=$($scope.dockerIntegration), dockerDaemon=$($optionalGates.dockerDaemonAvailable)",
    "- Real S3 client smoke: aws=$($optionalGates.awsCliAvailable), mc=$($optionalGates.mcAvailable), dockerizedMc=$($optionalGates.dockerizedMcAvailable)",
    "- Browser visual/click E2E: browserE2E=$($scope.browserE2E)",
    $(if ($securityEvidenceFinalize.passed) { "- Signed image and container scan/SBOM evidence: finalized and promoted." } else { '- Signed image and container scan/SBOM evidence: pending `scripts\finalize-security-evidence.ps1` from successful GitHub Actions artifacts.' }),
    "",
    "## Image References",
    "",
    '- Backend image target: `ghcr.io/<owner>/osmu-backend:<version>`',
    '- Frontend image target: `ghcr.io/<owner>/osmu-frontend:<version>`',
    "- Image digests: pending publish/sign workflow run.",
    '- SBOM artifacts: pending successful `Container Security CI` workflow run.',
    "- Signature evidence: pending successful Cosign verification output.",
    "",
    "## Operator Notes",
    "",
    $(if ($durableGatePassed) { "- Durable gate proof is present; this release can be used as local durable MVP demo evidence." } else { "- Use this release as local lightweight demo evidence only." }),
    $(if ($storageExpansionFinalize.passed) { "- Storage expansion finalizer proof is present; attach its JSON/Markdown report to Kubernetes expansion change review." } else { "- Storage expansion finalizer proof is pending; run scripts\finalize-storage-expansion.ps1 against the target cluster before treating expansion automation as operationally proven." }),
    $(if ($kubernetesDrFinalize.passed) { "- Kubernetes DR finalizer proof is present; attach its JSON/Markdown report to backup/restore change review." } else { "- Kubernetes DR finalizer proof is pending; run scripts\finalize-kubernetes-dr-drill.ps1 or the Kubernetes DR Finalizer CI workflow against the target cluster before treating HA/DR as operationally proven." }),
    $(if ($securityEvidenceFinalize.passed) { "- Security evidence finalizer proof is present; attach its JSON/Markdown report plus promoted evidence JSON to image release review." } else { "- Security evidence finalizer proof is pending; run scripts\finalize-security-evidence.ps1 after downloading successful image signing and container security workflow artifacts." }),
    $(if ($durableGatePassed) { "- For external pilot distribution, still attach signed-image and SBOM evidence when publishing images." } else { "- Do not present it as durable pilot-ready until Docker, real S3 client, Browser E2E, and signed-image evidence gates pass." }),
    '- Keep `.osmu-run` out of git; regenerate reports from scripts when evidence changes.'
)

$notes = $notesLines -join [Environment]::NewLine

if (-not $NoWrite) {
    $resolvedOutputPath = Resolve-ProjectPath $OutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
    Set-Content -LiteralPath $resolvedOutputPath -Value $notes -Encoding UTF8
    Write-Host "MVP release notes: $resolvedOutputPath"
}

Write-Host $notes
