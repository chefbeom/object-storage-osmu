param(
    [string] $ChartDirectory = ".\infra\helm\osmu"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
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

function Assert-Contains([string] $content, [string] $expected, [string] $fileName) {
    Assert-True $content.Contains($expected) "$fileName does not contain expected text: $expected"
}

function Read-ChartFile([string] $relativePath) {
    $path = Join-Path $resolvedChartDirectory $relativePath
    Assert-True (Test-Path -LiteralPath $path) "Helm chart file missing: $relativePath"
    $content = Get-Content -Raw -LiteralPath $path
    Assert-True (-not $content.Contains("`t")) "Tabs are not allowed in Helm chart file: $relativePath"
    return $content
}

$resolvedChartDirectory = Resolve-ProjectPath $ChartDirectory
Assert-True (Test-Path -LiteralPath $resolvedChartDirectory) "Helm chart directory missing: $resolvedChartDirectory"

$requiredFiles = @(
    "Chart.yaml",
    "values.yaml",
    "README.md",
    "templates\_helpers.tpl",
    "templates\configmap.yaml",
    "templates\secret.yaml",
    "templates\mariadb.yaml",
    "templates\minio.yaml",
    "templates\backend.yaml",
    "templates\frontend.yaml",
    "templates\ingress.yaml",
    "templates\networkpolicy.yaml",
    "templates\monitoring-operator.yaml"
)

foreach ($fileName in $requiredFiles) {
    $path = Join-Path $resolvedChartDirectory $fileName
    Assert-True (Test-Path -LiteralPath $path) "Required Helm chart draft file missing: $fileName"
}

$chart = Read-ChartFile "Chart.yaml"
Assert-Contains $chart "apiVersion: v2" "Chart.yaml"
Assert-Contains $chart "name: osmu" "Chart.yaml"
Assert-Contains $chart "type: application" "Chart.yaml"

$values = Read-ChartFile "values.yaml"
Assert-Contains $values "secrets:" "values.yaml"
Assert-Contains $values "create: false" "values.yaml"
Assert-Contains $values "backend:" "values.yaml"
Assert-Contains $values "frontend:" "values.yaml"
Assert-Contains $values "mariadb:" "values.yaml"
Assert-Contains $values "minio:" "values.yaml"
Assert-Contains $values "ingress:" "values.yaml"
Assert-Contains $values "resources:" "values.yaml"
Assert-Contains $values "requests:" "values.yaml"
Assert-Contains $values "limits:" "values.yaml"
Assert-Contains $values "networkPolicy:" "values.yaml"
Assert-Contains $values "enabled: true" "values.yaml"
Assert-Contains $values "nginx.ingress.kubernetes.io/ssl-redirect" "values.yaml"
Assert-Contains $values "nginx.ingress.kubernetes.io/force-ssl-redirect" "values.yaml"
Assert-Contains $values "secretName: osmu-tls" "values.yaml"
Assert-Contains $values "metadataMode: mariadb" "values.yaml"
Assert-Contains $values "storageMode: minio" "values.yaml"
Assert-Contains $values "metrics:" "values.yaml"
Assert-Contains $values "path: /actuator/prometheus" "values.yaml"
Assert-Contains $values "monitoring:" "values.yaml"
Assert-Contains $values "operator:" "values.yaml"
Assert-Contains $values "releaseLabel: prometheus" "values.yaml"

$helpers = Read-ChartFile "templates\_helpers.tpl"
Assert-Contains $helpers 'define "osmu.fullname"' "_helpers.tpl"
Assert-Contains $helpers 'define "osmu.secretName"' "_helpers.tpl"

$configMap = Read-ChartFile "templates\configmap.yaml"
Assert-Contains $configMap "kind: ConfigMap" "configmap.yaml"
Assert-Contains $configMap ".Values.config.metadataMode" "configmap.yaml"
Assert-Contains $configMap "OSMU_ACCESS_KEY_PROVISIONING_MODE" "configmap.yaml"

$secret = Read-ChartFile "templates\secret.yaml"
Assert-Contains $secret "{{- if .Values.secrets.create }}" "secret.yaml"
Assert-Contains $secret "kind: Secret" "secret.yaml"
Assert-Contains $secret "MARIADB_PASSWORD:" "secret.yaml"
Assert-Contains $secret "OSMU_JWT_SECRET:" "secret.yaml"

$mariadb = Read-ChartFile "templates\mariadb.yaml"
Assert-Contains $mariadb "kind: StatefulSet" "mariadb.yaml"
Assert-Contains $mariadb ".Values.mariadb.image.repository" "mariadb.yaml"
Assert-Contains $mariadb ".Values.mariadb.resources" "mariadb.yaml"
Assert-Contains $mariadb "healthcheck.sh" "mariadb.yaml"
Assert-Contains $mariadb "MARIADB_ROOT_PASSWORD" "mariadb.yaml"

$minio = Read-ChartFile "templates\minio.yaml"
Assert-Contains $minio "kind: StatefulSet" "minio.yaml"
Assert-Contains $minio ".Values.minio.image.repository" "minio.yaml"
Assert-Contains $minio ".Values.minio.resources" "minio.yaml"
Assert-Contains $minio "/minio/health/live" "minio.yaml"
Assert-Contains $minio "MINIO_ROOT_PASSWORD" "minio.yaml"

$backend = Read-ChartFile "templates\backend.yaml"
Assert-Contains $backend "kind: Deployment" "backend.yaml"
Assert-Contains $backend ".Values.backend.image.repository" "backend.yaml"
Assert-Contains $backend ".Values.backend.resources" "backend.yaml"
Assert-Contains $backend "SPRING_DATASOURCE_URL" "backend.yaml"
Assert-Contains $backend "OSMU_STORAGE_ACCESS_KEY" "backend.yaml"
Assert-Contains $backend "OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY" "backend.yaml"
Assert-Contains $backend "path: /api/health" "backend.yaml"
Assert-Contains $backend ".Values.backend.metrics.enabled" "backend.yaml"
Assert-Contains $backend "prometheus.io/scrape" "backend.yaml"
Assert-Contains $backend ".Values.backend.metrics.path" "backend.yaml"

$frontend = Read-ChartFile "templates\frontend.yaml"
Assert-Contains $frontend "kind: Deployment" "frontend.yaml"
Assert-Contains $frontend ".Values.frontend.image.repository" "frontend.yaml"
Assert-Contains $frontend ".Values.frontend.resources" "frontend.yaml"
Assert-Contains $frontend ".Values.frontend.podSecurityContext" "frontend.yaml"
Assert-Contains $frontend ".Values.frontend.containerSecurityContext" "frontend.yaml"
Assert-Contains $frontend "containerPort: 8080" "frontend.yaml"

$ingress = Read-ChartFile "templates\ingress.yaml"
Assert-Contains $ingress "{{- if .Values.ingress.enabled }}" "ingress.yaml"
Assert-Contains $ingress "kind: Ingress" "ingress.yaml"
Assert-Contains $ingress ".Values.ingress.host" "ingress.yaml"
Assert-Contains $ingress ".Values.ingress.tls" "ingress.yaml"
Assert-Contains $ingress "name: osmu-backend" "ingress.yaml"
Assert-Contains $ingress "name: osmu-frontend" "ingress.yaml"

$networkPolicy = Read-ChartFile "templates\networkpolicy.yaml"
Assert-Contains $networkPolicy "{{- if .Values.networkPolicy.enabled }}" "networkpolicy.yaml"
Assert-Contains $networkPolicy "kind: NetworkPolicy" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-backend-egress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-mariadb-ingress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-minio-ingress" "networkpolicy.yaml"
Assert-Contains $networkPolicy ".Values.networkPolicy.dns.namespaceName" "networkpolicy.yaml"
Assert-Contains $networkPolicy "port: 3306" "networkpolicy.yaml"
Assert-Contains $networkPolicy "port: 9000" "networkpolicy.yaml"
Assert-Contains $networkPolicy "port: 53" "networkpolicy.yaml"

$monitoringOperator = Read-ChartFile "templates\monitoring-operator.yaml"
Assert-Contains $monitoringOperator "{{- if .Values.monitoring.operator.enabled }}" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "kind: ServiceMonitor" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "kind: PrometheusRule" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator ".Values.backend.metrics.path" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator ".Values.monitoring.operator.interval" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator ".Values.monitoring.operator.releaseLabel" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "OsmuBackendDown" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "OsmuBackendHighErrorRate" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "OsmuBackendHighLatencyP95" "monitoring-operator.yaml"

$templateFiles = Get-ChildItem -LiteralPath (Join-Path $resolvedChartDirectory "templates") -Filter *.yaml
foreach ($templateFile in $templateFiles) {
    $content = Get-Content -Raw -LiteralPath $templateFile.FullName
    Assert-True ($content.Contains("apiVersion:")) "$($templateFile.Name) is missing apiVersion."
    Assert-True ($content.Contains("kind:")) "$($templateFile.Name) is missing kind."
}

Write-Host "Helm chart draft verified."
Write-Host "Chart directory: $resolvedChartDirectory"
Write-Host "Files checked: $($requiredFiles.Count)"

