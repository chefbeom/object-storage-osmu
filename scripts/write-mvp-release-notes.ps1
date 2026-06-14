param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
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

$resolvedReleaseReportPath = Resolve-ProjectPath $ReleaseReportPath
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

$notesLines = @(
    "# OSMU $Version Release Notes",
    "",
    "Generated at: $([DateTimeOffset]::Now.ToString("o"))",
    "Release report: $resolvedReleaseReportPath",
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
    "",
    "## External Pending Evidence",
    "",
    "- Docker/MariaDB/MinIO integration: dockerIntegration=$($scope.dockerIntegration), dockerDaemon=$($optionalGates.dockerDaemonAvailable)",
    "- Real S3 client smoke: aws=$($optionalGates.awsCliAvailable), mc=$($optionalGates.mcAvailable)",
    "- Browser visual/click E2E: browserE2E=$($scope.browserE2E)",
    '- Signed image evidence: pending GitHub Actions `Image Publish and Sign CI` run with `publish=true`.',
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
    "- Use this release as local lightweight demo evidence only.",
    "- Do not present it as durable pilot-ready until Docker, real S3 client, Browser E2E, and signed-image evidence gates pass.",
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
