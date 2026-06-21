param(
    [string] $KubernetesManifestPath = ".\infra\k8s\monitoring-operator.yaml",
    [string] $KustomizationPath = ".\infra\k8s\kustomization.yaml",
    [string] $HelmValuesPath = ".\infra\helm\osmu\values.yaml",
    [string] $HelmTemplatePath = ".\infra\helm\osmu\templates\monitoring-operator.yaml",
    [string] $MonitoringReadmePath = ".\infra\monitoring\README.md"
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

function Assert-NotContains([string] $content, [string] $expected, [string] $label) {
    if ($content.Contains($expected)) {
        throw "$label must not contain text: $expected"
    }
}

$kubernetesManifest = Read-RequiredFile $KubernetesManifestPath "Kubernetes Prometheus Operator draft"
$kustomization = Read-RequiredFile $KustomizationPath "Kubernetes kustomization"
$helmValues = Read-RequiredFile $HelmValuesPath "Helm values"
$helmTemplate = Read-RequiredFile $HelmTemplatePath "Helm Prometheus Operator template"
$monitoringReadme = Read-RequiredFile $MonitoringReadmePath "Monitoring README"

Assert-Contains $kubernetesManifest.Content "apiVersion: monitoring.coreos.com/v1" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "kind: ServiceMonitor" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "kind: PrometheusRule" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "path: /actuator/prometheus" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuBackendDown" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuBackendHighErrorRate" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuBackendHighLatencyP95" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuDataFlowFailureSpike" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuDataFlowCancelSpike" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuDataFlowAbnormalEgress" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuDataFlowBucketTrafficAnomaly" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuDataFlowRetentionFailures" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuDataFlowDailyRollupRetentionFailures" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuDataFlowMonthlyRollupRetentionFailures" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuBackupCronJobFailed" "Kubernetes Prometheus Operator draft"
Assert-Contains $kubernetesManifest.Content "OsmuBackupCronJobStale" "Kubernetes Prometheus Operator draft"
Assert-NotContains $kustomization.Content "monitoring-operator.yaml" "kustomization.yaml"

Assert-Contains $helmValues.Content "monitoring:" "Helm values"
Assert-Contains $helmValues.Content "operator:" "Helm values"
Assert-Contains $helmValues.Content "enabled: false" "Helm values"
Assert-Contains $helmValues.Content "interval: 30s" "Helm values"
Assert-Contains $helmValues.Content "scrapeTimeout: 10s" "Helm values"
Assert-Contains $helmValues.Content "releaseLabel: prometheus" "Helm values"

Assert-Contains $helmTemplate.Content "{{- if .Values.monitoring.operator.enabled }}" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "kind: ServiceMonitor" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "kind: PrometheusRule" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content ".Values.backend.metrics.path" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content ".Values.monitoring.operator.interval" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content ".Values.monitoring.operator.releaseLabel" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuBackendDown" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuBackendHighErrorRate" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuBackendHighLatencyP95" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuDataFlowFailureSpike" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuDataFlowCancelSpike" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuDataFlowAbnormalEgress" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuDataFlowBucketTrafficAnomaly" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuDataFlowRetentionFailures" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuDataFlowDailyRollupRetentionFailures" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuDataFlowMonthlyRollupRetentionFailures" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuBackupCronJobFailed" "Helm Prometheus Operator template"
Assert-Contains $helmTemplate.Content "OsmuBackupCronJobStale" "Helm Prometheus Operator template"

Assert-Contains $monitoringReadme.Content "ServiceMonitor" "Monitoring README"
Assert-Contains $monitoringReadme.Content "PrometheusRule" "Monitoring README"

Write-Host "Prometheus Operator draft verified."
Write-Host "Kubernetes manifest: $($kubernetesManifest.Path)"
Write-Host "Helm template: $($helmTemplate.Path)"
