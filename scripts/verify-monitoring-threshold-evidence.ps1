param(
    [string] $OutputDirectory = ".\.osmu-run\monitoring-threshold-evidence-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-NotContains([string] $text, [string] $unexpected, [string] $label) {
    if ($text.Contains($unexpected)) {
        throw "$label contains unexpected secret text: $unexpected"
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-monitoring-threshold-evidence.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-monitoring-threshold-evidence.md"
$scriptPath = Resolve-ProjectPath ".\scripts\write-monitoring-threshold-evidence.ps1"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "ops-self-test" `
    -ReviewStartedAt "2026-06-20T03:00:00Z" `
    -ReviewCompletedAt "2026-06-20T03:20:00Z" `
    -ChangeApprovalRef "CHG-2026-MONITORING-THRESHOLDS" `
    -EvidenceRef "monitoring-threshold-evidence-20260620" `
    -PrometheusRulesEvidenceRef "prometheus-rule-load-20260620" `
    -GrafanaDashboardEvidenceRef "grafana-dashboard-import-20260620" `
    -AlertmanagerRouteEvidenceRef "alertmanager-route-review-20260620" `
    -TargetBaselineEvidenceRef "tenant-baseline-review-20260620" `
    -IncidentRoutingEvidenceRef "incident-routing-review-20260620" `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -ConfirmPrometheusRulesLoaded `
    -ConfirmGrafanaDashboardImported `
    -ConfirmAlertmanagerRoutesReviewed `
    -ConfirmTargetBaselinesReviewed `
    -ConfirmIncidentRoutingReviewed `
    -ConfirmNoSecretValues `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-monitoring-threshold-evidence.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Monitoring threshold evidence JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Monitoring threshold evidence markdown missing."

$reportText = Get-Content -Raw -LiteralPath $jsonOutputPath
$markdown = Get-Content -Raw -LiteralPath $markdownOutputPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)

Assert-True ($report.formatVersion -eq "osmu.monitoring-threshold-evidence.v1") "Unexpected monitoring threshold evidence formatVersion."
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.thresholdTargetSummary.requiredAlertCount -ge 10) "Expected required alert count."
Assert-True ($report.thresholdTargetSummary.mappedAlertCount -ge $report.thresholdTargetSummary.requiredAlertCount) "Expected mapped alert targets."
Assert-True ($report.thresholdTargetSummary.grafanaPanelCount -ge $report.thresholdTargetSummary.requiredAlertCount) "Expected Grafana panel mappings."
Assert-True ($report.thresholdTargetSummary.tuningEvidenceCount -ge $report.thresholdTargetSummary.requiredAlertCount) "Expected tuning evidence mappings."
Assert-True ($report.thresholdTargetSummary.alertTargetCoverageComplete) "Expected alert target coverage complete."
Assert-True ($report.thresholdTargetSummary.routeCoverageComplete) "Expected route coverage complete."
Assert-True ($report.thresholdTargetSummary.grafanaPanelCoverageComplete) "Expected Grafana panel coverage complete."
Assert-True ($report.thresholdTargetSummary.tuningEvidenceCoverageComplete) "Expected tuning evidence coverage complete."
Assert-True ($report.thresholdTargetSummary.thresholdMappingComplete) "Expected threshold mapping complete."
Assert-True (@($report.thresholdTargetSummary.routes | Where-Object { $_ -eq "osmu-data-flow" }).Count -eq 1) "Expected osmu-data-flow route."
Assert-True ($report.confirmations.prometheusRulesLoaded) "Expected Prometheus rules confirmation."
Assert-True ($report.confirmations.grafanaDashboardImported) "Expected Grafana dashboard confirmation."
Assert-True ($report.confirmations.alertmanagerRoutesReviewed) "Expected Alertmanager route confirmation."
Assert-True ($report.confirmations.targetBaselinesReviewed) "Expected target baseline confirmation."
Assert-True ($report.confirmations.incidentRoutingReviewed) "Expected incident routing confirmation."
Assert-True ($report.confirmations.noSecretValues) "Expected no-secret confirmation."
Assert-True (@($checks | Where-Object { $_.id -eq "threshold-alert-targets-complete" -and $_.passed }).Count -eq 1) "Expected alert target completeness check."

Assert-Contains $markdown "# OSMU Monitoring Threshold Evidence" "monitoring threshold evidence markdown"
Assert-Contains $markdown "Alertmanager Routes" "monitoring threshold evidence markdown"
Assert-Contains $markdown "Threshold mapping complete: True" "monitoring threshold evidence markdown"
Assert-Contains $markdown "Record passed target evidence" "monitoring threshold evidence markdown"
Assert-Contains $report.secretPolicy "does not contain passwords" "monitoring threshold evidence JSON"
Assert-Contains $report.decisionRule "Production/B2B monitoring readiness requires result=passed" "monitoring threshold evidence JSON"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----")) {
    Assert-NotContains $reportText $unexpected "monitoring threshold evidence JSON"
    Assert-NotContains $markdown $unexpected "monitoring threshold evidence markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -EvidenceRef "password=super-secret" `
        -NoWrite 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Secret-like evidence reference should be rejected."

$invalidWindowJsonOutputPath = Join-Path $resolvedOutputDirectory "invalid-window-monitoring-threshold-evidence.json"
$invalidWindowMarkdownOutputPath = Join-Path $resolvedOutputDirectory "invalid-window-monitoring-threshold-evidence.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidWindowOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -ReviewStartedAt "2026-06-20T03:20:00Z" `
        -ReviewCompletedAt "2026-06-20T03:00:00Z" `
        -ChangeApprovalRef "CHG-2026-MONITORING-THRESHOLDS" `
        -EvidenceRef "monitoring-threshold-evidence-20260620" `
        -PrometheusRulesEvidenceRef "prometheus-rule-load-20260620" `
        -GrafanaDashboardEvidenceRef "grafana-dashboard-import-20260620" `
        -AlertmanagerRouteEvidenceRef "alertmanager-route-review-20260620" `
        -TargetBaselineEvidenceRef "tenant-baseline-review-20260620" `
        -IncidentRoutingEvidenceRef "incident-routing-review-20260620" `
        -JsonOutputPath $invalidWindowJsonOutputPath `
        -MarkdownOutputPath $invalidWindowMarkdownOutputPath `
        -ConfirmPrometheusRulesLoaded `
        -ConfirmGrafanaDashboardImported `
        -ConfirmAlertmanagerRoutesReviewed `
        -ConfirmTargetBaselinesReviewed `
        -ConfirmIncidentRoutingReviewed `
        -ConfirmNoSecretValues `
        -FailIfNotPassed 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidWindowExitCode -ne 0) "Reversed review window should be rejected."
Assert-Contains ($invalidWindowOutput | Out-String) "review-window-order" "invalid review window output"
Assert-True (Test-Path -LiteralPath $invalidWindowJsonOutputPath) "Invalid review window JSON should stay isolated under the self-test output directory."

$missingTargetPath = Join-Path $resolvedOutputDirectory "missing-targets.yaml"
$missingTargetJsonOutputPath = Join-Path $resolvedOutputDirectory "missing-target-monitoring-threshold-evidence.json"
$missingTargetMarkdownOutputPath = Join-Path $resolvedOutputDirectory "missing-target-monitoring-threshold-evidence.md"
@"
formatVersion: osmu.monitoring.threshold-targets.v1
profile: missing-targets
alertmanagerRoutes:
  - route: osmu-backend
thresholdTargets:
  - alert: OsmuBackendHighLatencyP95
    metric: http_server_requests_seconds_bucket
    target: p95 <= 2s
    grafanaPanel: HTTP p95 Latency
    alertmanagerRoute: osmu-backend
    tuningEvidence: target API latency SLO
"@ | Set-Content -Encoding UTF8 -LiteralPath $missingTargetPath

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingTargetOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -ReviewStartedAt "2026-06-20T03:00:00Z" `
        -ReviewCompletedAt "2026-06-20T03:20:00Z" `
        -ChangeApprovalRef "CHG-2026-MONITORING-THRESHOLDS" `
        -ThresholdTargetsPath $missingTargetPath `
        -JsonOutputPath $missingTargetJsonOutputPath `
        -MarkdownOutputPath $missingTargetMarkdownOutputPath `
        -EvidenceRef "monitoring-threshold-evidence-20260620" `
        -PrometheusRulesEvidenceRef "prometheus-rule-load-20260620" `
        -GrafanaDashboardEvidenceRef "grafana-dashboard-import-20260620" `
        -AlertmanagerRouteEvidenceRef "alertmanager-route-review-20260620" `
        -TargetBaselineEvidenceRef "tenant-baseline-review-20260620" `
        -IncidentRoutingEvidenceRef "incident-routing-review-20260620" `
        -ConfirmPrometheusRulesLoaded `
        -ConfirmGrafanaDashboardImported `
        -ConfirmAlertmanagerRoutesReviewed `
        -ConfirmTargetBaselinesReviewed `
        -ConfirmIncidentRoutingReviewed `
        -ConfirmNoSecretValues `
        -FailIfNotPassed 2>&1
    $missingTargetExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingTargetExitCode -ne 0) "Missing required alert targets should be rejected."
Assert-Contains ($missingTargetOutput | Out-String) "threshold-alert-targets-complete" "missing target output"
Assert-True (Test-Path -LiteralPath $missingTargetJsonOutputPath) "Missing target JSON should stay isolated under the self-test output directory."

Write-Host "Monitoring threshold evidence writer verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
