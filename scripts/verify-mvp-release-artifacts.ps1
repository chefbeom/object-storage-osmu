param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $AuditPath = ".\.osmu-run\latest-mvp-audit.md",
    [string] $DecisionPath = ".\.osmu-run\latest-release-decision.md"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-FileExists([string] $path) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required release artifact not found: $path"
    }
}

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

$resolvedReleaseReportPath = Resolve-ProjectPath $ReleaseReportPath
$resolvedAuditPath = Resolve-ProjectPath $AuditPath
$resolvedDecisionPath = Resolve-ProjectPath $DecisionPath

Assert-FileExists $resolvedReleaseReportPath
Assert-FileExists $resolvedAuditPath
Assert-FileExists $resolvedDecisionPath

$report = Get-Content -Raw -LiteralPath $resolvedReleaseReportPath | ConvertFrom-Json
$audit = Get-Content -Raw -LiteralPath $resolvedAuditPath
$decision = Get-Content -Raw -LiteralPath $resolvedDecisionPath

$releasePathLine = "Release report: $resolvedReleaseReportPath"
Assert-Contains $audit $releasePathLine "MVP audit"
Assert-Contains $decision $releasePathLine "MVP release decision"

$lightweightGo = $report.result -eq "passed" `
    -and $report.scope.preflight -eq "included" `
    -and $report.scope.runtime -eq "included" `
    -and $report.scope.lightweightApiSmoke -eq "included" `
    -and $report.scope.seededDemoSmoke -eq "included" `
    -and $report.scope.s3Smoke -eq "included" `
    -and $report.scope.buildVerify -eq "included" `
    -and $report.scope.ciWorkflow -eq "included" `
    -and $report.scope.openApiContract -eq "included" `
    -and $report.scope.kubernetesManifests -eq "included" `
    -and $report.scope.helmChart -eq "included" `
    -and $report.scope.networkPolicies -eq "included" `
    -and $report.scope.containerHardening -eq "included" `
    -and $report.scope.tlsIngress -eq "included" `
    -and $report.scope.secretRotationPolicy -eq "included" `
    -and $report.scope.backupRestoreDrill -eq "included" `
    -and $report.scope.prometheusObservability -eq "included" `
    -and $report.scope.monitoringArtifacts -eq "included" `
    -and $report.scope.prometheusOperatorDraft -eq "included" `
    -and $report.scope.backendTests -eq "included"

$durableGo = $lightweightGo `
    -and [bool]$report.optionalGates.dockerDaemonAvailable `
    -and $report.scope.dockerIntegration -eq "included" `
    -and [bool]$report.optionalGates.realS3ClientAvailable `
    -and [bool]$report.scope.realS3ClientRequired `
    -and $report.scope.browserE2E -eq "verified"

$expectedLightweightDecision = if ($lightweightGo) { "GO" } else { "NO-GO" }
$expectedDurableDecision = if ($durableGo) { "GO" } else { "NO-GO" }

Assert-Contains $decision "- Lightweight demo candidate: $expectedLightweightDecision" "MVP release decision"
Assert-Contains $decision "- Durable MVP pilot: $expectedDurableDecision" "MVP release decision"

if ($lightweightGo) {
    Assert-Contains $audit "- PASS: Lightweight MVP prototype" "MVP audit"
    Assert-Contains $audit "- PASS: Prototype CI workflow" "MVP audit"
    Assert-Contains $audit "- PASS: MVP API contract" "MVP audit"
    Assert-Contains $audit "- PASS: Kubernetes manifest draft" "MVP audit"
    Assert-Contains $audit "- PASS: Helm chart draft" "MVP audit"
    Assert-Contains $audit "- PASS: NetworkPolicy draft" "MVP audit"
    Assert-Contains $audit "- PASS: Container hardening draft" "MVP audit"
    Assert-Contains $audit "- PASS: TLS ingress draft" "MVP audit"
    Assert-Contains $audit "- PASS: Secret rotation policy draft" "MVP audit"
    Assert-Contains $audit "- PASS: Backup restore drill draft" "MVP audit"
    Assert-Contains $audit "- PASS: Prometheus observability draft" "MVP audit"
    Assert-Contains $audit "- PASS: Monitoring artifacts draft" "MVP audit"
    Assert-Contains $audit "- PASS: Prometheus Operator draft" "MVP audit"
    Assert-Contains $audit "- PASS: Secret rotation policy draft" "MVP audit"
    Assert-Contains $decision "- [PASS] OpenAPI contract included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Kubernetes manifest draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Helm chart draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] NetworkPolicy draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Container hardening draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] TLS ingress draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Secret rotation policy draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Backup restore drill draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Prometheus observability draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Monitoring artifacts draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Prometheus Operator draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Secret rotation policy draft included" "MVP release decision"
} else {
    Assert-Contains $audit "- PENDING: Lightweight MVP prototype" "MVP audit"
}

if ($durableGo) {
    Assert-Contains $audit "- PASS: Docker/MariaDB/MinIO integration" "MVP audit"
    Assert-Contains $audit "- PASS: Real S3 client smoke" "MVP audit"
    Assert-Contains $audit "- PASS: Browser visual/click E2E" "MVP audit"
} else {
    Assert-Contains $decision "Durable MVP pilot: NO-GO" "MVP release decision"
}

Write-Host "MVP release artifacts verified."
Write-Host "Release report: $resolvedReleaseReportPath"
Write-Host "Audit: $resolvedAuditPath"
Write-Host "Decision: $resolvedDecisionPath"
