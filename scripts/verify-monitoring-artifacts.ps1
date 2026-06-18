param(
    [string] $MonitoringDirectory = ".\infra\monitoring",
    [string] $OperationMonitoringPath = ".\dev-docs\operation-monitoring.md"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-RequiredFile([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "$label missing: $resolvedPath"
    }
    return [pscustomobject]@{
        Path = $resolvedPath
        Content = Get-Content -Raw -LiteralPath $resolvedPath
    }
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    if (-not $content.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

$resolvedMonitoringDirectory = Resolve-ProjectPath $MonitoringDirectory
if (-not (Test-Path -LiteralPath $resolvedMonitoringDirectory)) {
    throw "Monitoring directory missing: $resolvedMonitoringDirectory"
}

$readme = Read-RequiredFile (Join-Path $resolvedMonitoringDirectory "README.md") "Monitoring README"
$rules = Read-RequiredFile (Join-Path $resolvedMonitoringDirectory "prometheus-rules.yaml") "Prometheus rules"
$dashboard = Read-RequiredFile (Join-Path $resolvedMonitoringDirectory "grafana-dashboard-osmu.json") "Grafana dashboard"
$operationMonitoring = Read-RequiredFile $OperationMonitoringPath "Operation monitoring doc"

Assert-Contains $readme.Content "prometheus-rules.yaml" "Monitoring README"
Assert-Contains $readme.Content "grafana-dashboard-osmu.json" "Monitoring README"
Assert-Contains $readme.Content "/actuator/prometheus" "Monitoring README"

Assert-Contains $rules.Content "groups:" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackendDown" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackendHighErrorRate" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackendHighLatencyP95" "Prometheus rules"
Assert-Contains $rules.Content "OsmuRetentionPurgeFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuVersionRetentionPurgeFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuMultipartCleanupFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuShareLinkCleanupFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackupRestoreDrillPending" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackupCronJobFailed" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackupCronJobStale" "Prometheus rules"
Assert-Contains $rules.Content "kube_job_status_failed" "Prometheus rules"
Assert-Contains $rules.Content "kube_cronjob_status_last_successful_time" "Prometheus rules"
Assert-Contains $rules.Content "severity:" "Prometheus rules"
Assert-Contains $rules.Content "summary:" "Prometheus rules"

$parsedDashboard = $dashboard.Content | ConvertFrom-Json
if ($parsedDashboard.title -ne "OSMU MVP Overview") {
    throw "Grafana dashboard title mismatch."
}
if (-not $parsedDashboard.panels -or $parsedDashboard.panels.Count -lt 6) {
    throw "Grafana dashboard must contain at least 6 panels."
}
Assert-Contains $dashboard.Content "http_server_requests_seconds_count" "Grafana dashboard"
Assert-Contains $dashboard.Content "http_server_requests_seconds_bucket" "Grafana dashboard"
Assert-Contains $dashboard.Content "jvm_memory_used_bytes" "Grafana dashboard"
Assert-Contains $dashboard.Content "osmu_object_retention_purge_runs_total" "Grafana dashboard"
Assert-Contains $dashboard.Content "GET /api/admin/backup/status" "Grafana dashboard"

Assert-Contains $operationMonitoring.Content "infra/monitoring/prometheus-rules.yaml" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "infra/monitoring/grafana-dashboard-osmu.json" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "kube_cronjob_status_last_successful_time" "Operation monitoring doc"

Write-Host "Monitoring artifacts verified."
Write-Host "Monitoring directory: $resolvedMonitoringDirectory"
Write-Host "Grafana panels: $($parsedDashboard.panels.Count)"
