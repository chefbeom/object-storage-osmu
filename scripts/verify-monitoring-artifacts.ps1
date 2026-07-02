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

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
}
function Read-RequiredFile([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "$label missing: $resolvedPath"
    }
    return [pscustomobject]@{
        Path = $resolvedPath
        Content = Read-Utf8Text $resolvedPath
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
$thresholdTargets = Read-RequiredFile (Join-Path $resolvedMonitoringDirectory "alert-threshold-targets.yaml") "Monitoring threshold targets"
$operationMonitoring = Read-RequiredFile $OperationMonitoringPath "Operation monitoring doc"

Assert-Contains $readme.Content "prometheus-rules.yaml" "Monitoring README"
Assert-Contains $readme.Content "grafana-dashboard-osmu.json" "Monitoring README"
Assert-Contains $readme.Content "alert-threshold-targets.yaml" "Monitoring README"
Assert-Contains $readme.Content "/actuator/prometheus" "Monitoring README"
Assert-Contains $readme.Content "Alertmanager/Grafana threshold target contract" "Monitoring README"

Assert-Contains $rules.Content "groups:" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackendDown" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackendHighErrorRate" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackendHighLatencyP95" "Prometheus rules"
Assert-Contains $rules.Content "OsmuRetentionPurgeFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuVersionRetentionPurgeFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuMultipartCleanupFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuShareLinkCleanupFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuDataFlowFailureSpike" "Prometheus rules"
Assert-Contains $rules.Content "OsmuDataFlowCancelSpike" "Prometheus rules"
Assert-Contains $rules.Content "OsmuDataFlowAbnormalEgress" "Prometheus rules"
Assert-Contains $rules.Content "OsmuDataFlowBucketTrafficAnomaly" "Prometheus rules"
Assert-Contains $rules.Content "OsmuDataFlowRetentionFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuDataFlowDailyRollupRetentionFailures" "Prometheus rules"
Assert-Contains $rules.Content "OsmuDataFlowMonthlyRollupRetentionFailures" "Prometheus rules"
Assert-Contains $rules.Content "osmu_data_flow_operations_total" "Prometheus rules"
Assert-Contains $rules.Content "osmu_data_flow_bytes_total" "Prometheus rules"
Assert-Contains $rules.Content "osmu_data_flow_retention_runs_total" "Prometheus rules"
Assert-Contains $rules.Content "osmu_data_flow_daily_rollup_retention_runs_total" "Prometheus rules"
Assert-Contains $rules.Content "osmu_data_flow_monthly_rollup_retention_runs_total" "Prometheus rules"
Assert-Contains $rules.Content "max by (bucket)" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackupRestoreDrillPending" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackupCronJobFailed" "Prometheus rules"
Assert-Contains $rules.Content "OsmuBackupCronJobStale" "Prometheus rules"
Assert-Contains $rules.Content "kube_job_status_failed" "Prometheus rules"
Assert-Contains $rules.Content "kube_cronjob_status_last_successful_time" "Prometheus rules"
Assert-Contains $rules.Content "severity:" "Prometheus rules"
Assert-Contains $rules.Content "summary:" "Prometheus rules"
Assert-Contains $rules.Content "target_profile: pilot-default" "Prometheus rules"
Assert-Contains $rules.Content "alertmanager_route: osmu-backend" "Prometheus rules"
Assert-Contains $rules.Content "alertmanager_route: osmu-data-flow" "Prometheus rules"
Assert-Contains $rules.Content "alertmanager_route: osmu-backup" "Prometheus rules"

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
Assert-Contains $dashboard.Content "osmu_data_flow_operations_total" "Grafana dashboard"
Assert-Contains $dashboard.Content "osmu_data_flow_bytes_total" "Grafana dashboard"
Assert-Contains $dashboard.Content "osmu_data_flow_retention_runs_total" "Grafana dashboard"
Assert-Contains $dashboard.Content "osmu_data_flow_daily_rollup_retention_runs_total" "Grafana dashboard"
Assert-Contains $dashboard.Content "osmu_data_flow_monthly_rollup_retention_runs_total" "Grafana dashboard"
Assert-Contains $dashboard.Content "Data Flow Bytes By Bucket" "Grafana dashboard"
Assert-Contains $dashboard.Content "GET /api/admin/backup/status" "Grafana dashboard"
Assert-Contains $dashboard.Content "Threshold Target Contract" "Grafana dashboard"
Assert-Contains $dashboard.Content "alert-threshold-targets.yaml" "Grafana dashboard"

Assert-Contains $thresholdTargets.Content "formatVersion: osmu.monitoring.threshold-targets.v1" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "profile: pilot-default" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "alertmanagerRoutes:" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "thresholdTargets:" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuBackendHighErrorRate" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuBackendHighLatencyP95" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuDataFlowFailureSpike" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuDataFlowCancelSpike" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuDataFlowAbnormalEgress" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuDataFlowBucketTrafficAnomaly" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuDataFlowRetentionFailures" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuDataFlowDailyRollupRetentionFailures" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuDataFlowMonthlyRollupRetentionFailures" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuBackupCronJobFailed" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "OsmuBackupCronJobStale" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "alertmanagerRoute: osmu-data-flow" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "grafanaPanel: Data Flow Bytes By Bucket" "Monitoring threshold targets"
Assert-Contains $thresholdTargets.Content "target tenant baselines" "Monitoring threshold targets"

Assert-Contains $operationMonitoring.Content "infra/monitoring/prometheus-rules.yaml" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "infra/monitoring/grafana-dashboard-osmu.json" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "infra/monitoring/alert-threshold-targets.yaml" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "kube_cronjob_status_last_successful_time" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "OsmuDataFlowFailureSpike" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "OsmuDataFlowCancelSpike" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "OsmuDataFlowAbnormalEgress" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "OsmuDataFlowBucketTrafficAnomaly" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "OsmuDataFlowRetentionFailures" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "OsmuDataFlowDailyRollupRetentionFailures" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "OsmuDataFlowMonthlyRollupRetentionFailures" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "Alertmanager routes" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "manual-data-flow-query-retention-budget-evidence.yml" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "manual-chargeback-closeout-evidence.yml" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "manual-enterprise-auth-jit-rollback-evidence.yml" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "data_flow_query_retention_budget_json_base64" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "DataFlowQueryRetentionBudgetEvidencePath" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "data-flow query/retention budget workflow" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "chargeback closeout workflow" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "Enterprise auth smoke and JIT rollback workflows" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "dataFlowQueryRetentionBudget" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "DATA_FLOW_QUERY_RETENTION_BUDGET" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "nested data-flow query/retention budget latency/retention summary" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "nested chargeback closeout period/invoice/payment/reconciliation summary" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "data-flow storage plan/query-retention budget/runbook evidence" "Operation monitoring doc"
Assert-Contains $operationMonitoring.Content "query-retention budget result/candidate/latency/retention/failure/check counts" "Operation monitoring doc"

Write-Host "Monitoring artifacts verified."
Write-Host "Monitoring directory: $resolvedMonitoringDirectory"
Write-Host "Grafana panels: $($parsedDashboard.panels.Count)"
