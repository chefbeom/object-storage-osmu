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
    "templates\serviceaccount.yaml",
    "templates\storage-expansion-rbac.yaml",
    "templates\configmap.yaml",
    "templates\secret.yaml",
    "templates\mariadb.yaml",
    "templates\minio.yaml",
    "templates\backup.yaml",
    "templates\ha.yaml",
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
Assert-Contains $values "backup:" "values.yaml"
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
Assert-Contains $values "s3PublicEndpoint: https://osmu.local/api/s3" "values.yaml"
Assert-Contains $values "s3Region: us-east-1" "values.yaml"
Assert-Contains $values "operationsReadinessConvergenceReportPath: .osmu-run/latest-operations-readiness-convergence.json" "values.yaml"
Assert-Contains $values "kubernetesOperationsReportSyncReportPath: .osmu-run/latest-kubernetes-operations-report-sync.json" "values.yaml"
Assert-Contains $values "metrics:" "values.yaml"
Assert-Contains $values "path: /actuator/prometheus" "values.yaml"
Assert-Contains $values "operationsReports:" "values.yaml"
Assert-Contains $values "type: configMap" "values.yaml"
Assert-Contains $values "configMapName: osmu-operations-reports" "values.yaml"
Assert-Contains $values "claimName:" "values.yaml"
Assert-Contains $values "mountPath: /app/.osmu-run" "values.yaml"
Assert-Contains $values "monitoring:" "values.yaml"
Assert-Contains $values "operator:" "values.yaml"
Assert-Contains $values "releaseLabel: prometheus" "values.yaml"
Assert-Contains $values "tenant:" "values.yaml"
Assert-Contains $values "pools:" "values.yaml"
Assert-Contains $values "volumesPerServer:" "values.yaml"
Assert-Contains $values "size: 1Ti" "values.yaml"
Assert-Contains $values "storageClassName:" "values.yaml"
Assert-Contains $values "storageExpansion:" "values.yaml"
Assert-Contains $values "serviceAccountName: osmu-storage-expansion-runner" "values.yaml"
Assert-Contains $values "tenantName: osmu-minio" "values.yaml"
Assert-Contains $values "legacyStatefulSetName: osmu-minio" "values.yaml"
Assert-Contains $values "retentionDays:" "values.yaml"
Assert-Contains $values "mcImage:" "values.yaml"
Assert-Contains $values "backup:" "values.yaml"
Assert-Contains $values "ha:" "values.yaml"
Assert-Contains $values "podDisruptionBudgets:" "values.yaml"
Assert-Contains $values "topologySpread:" "values.yaml"
Assert-Contains $values "topologyKey: kubernetes.io/hostname" "values.yaml"
Assert-Contains $values "whenUnsatisfiable: ScheduleAnyway" "values.yaml"

$helpers = Read-ChartFile "templates\_helpers.tpl"
Assert-Contains $helpers 'define "osmu.fullname"' "_helpers.tpl"
Assert-Contains $helpers 'define "osmu.secretName"' "_helpers.tpl"

$serviceAccount = Read-ChartFile "templates\serviceaccount.yaml"
Assert-Contains $serviceAccount "kind: ServiceAccount" "serviceaccount.yaml"
Assert-Contains $serviceAccount "name: osmu-backend" "serviceaccount.yaml"
Assert-Contains $serviceAccount "name: osmu-frontend" "serviceaccount.yaml"
Assert-Contains $serviceAccount "name: osmu-mariadb" "serviceaccount.yaml"
Assert-Contains $serviceAccount "name: osmu-minio" "serviceaccount.yaml"
Assert-Contains $serviceAccount "automountServiceAccountToken: false" "serviceaccount.yaml"

$storageExpansionRbac = Read-ChartFile "templates\storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "{{- if .Values.storageExpansion.runner.rbac.enabled }}" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "kind: ServiceAccount" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "kind: Role" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "kind: RoleBinding" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac ".Values.storageExpansion.runner.rbac.serviceAccountName" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- minio.min.io" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- tenants" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac ".Values.storageExpansion.runner.rbac.tenantName" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- statefulsets" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- statefulsets/status" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- get" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- patch" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- update" "storage-expansion-rbac.yaml"
Assert-True (-not $storageExpansionRbac.Contains("- delete")) "storage-expansion-rbac.yaml must not grant delete."
Assert-True (-not $storageExpansionRbac.Contains("- create")) "storage-expansion-rbac.yaml must not grant create."
Assert-True (-not $storageExpansionRbac.Contains("- secrets")) "storage-expansion-rbac.yaml must not grant secrets access."
Assert-True (-not $storageExpansionRbac.Contains("pods/exec")) "storage-expansion-rbac.yaml must not grant pod exec."

$configMap = Read-ChartFile "templates\configmap.yaml"
Assert-Contains $configMap "kind: ConfigMap" "configmap.yaml"
Assert-Contains $configMap ".Values.config.metadataMode" "configmap.yaml"
Assert-Contains $configMap "OSMU_ACCESS_KEY_PROVISIONING_MODE" "configmap.yaml"
Assert-Contains $configMap "OSMU_S3_PUBLIC_ENDPOINT" "configmap.yaml"
Assert-Contains $configMap "OSMU_S3_REGION" "configmap.yaml"
Assert-Contains $configMap "OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH" "configmap.yaml"
Assert-Contains $configMap "OSMU_OPERATIONS_READINESS_KUBERNETES_REPORT_SYNC_REPORT_PATH" "configmap.yaml"

$secret = Read-ChartFile "templates\secret.yaml"
Assert-Contains $secret "{{- if .Values.secrets.create }}" "secret.yaml"
Assert-Contains $secret "kind: Secret" "secret.yaml"
Assert-Contains $secret "MARIADB_PASSWORD:" "secret.yaml"
Assert-Contains $secret "OSMU_JWT_SECRET:" "secret.yaml"

$mariadb = Read-ChartFile "templates\mariadb.yaml"
Assert-Contains $mariadb "kind: StatefulSet" "mariadb.yaml"
Assert-Contains $mariadb "serviceAccountName: osmu-mariadb" "mariadb.yaml"
Assert-Contains $mariadb "automountServiceAccountToken: false" "mariadb.yaml"
Assert-Contains $mariadb ".Values.mariadb.image.repository" "mariadb.yaml"
Assert-Contains $mariadb ".Values.mariadb.resources" "mariadb.yaml"
Assert-Contains $mariadb "healthcheck.sh" "mariadb.yaml"
Assert-Contains $mariadb "MARIADB_ROOT_PASSWORD" "mariadb.yaml"

$minio = Read-ChartFile "templates\minio.yaml"
Assert-Contains $minio "kind: StatefulSet" "minio.yaml"
Assert-Contains $minio "serviceAccountName: osmu-minio" "minio.yaml"
Assert-Contains $minio "automountServiceAccountToken: false" "minio.yaml"
Assert-Contains $minio ".Values.minio.tenant.enabled" "minio.yaml"
Assert-Contains $minio "kind: Tenant" "minio.yaml"
Assert-Contains $minio ".Values.minio.pools" "minio.yaml"
Assert-Contains $minio "volumesPerServer" "minio.yaml"
Assert-Contains $minio "volumeClaimTemplate" "minio.yaml"
Assert-Contains $minio "default .volumeSize .size" "minio.yaml"
Assert-Contains $minio "requestAutoCert" "minio.yaml"
Assert-Contains $minio ".Values.minio.image.repository" "minio.yaml"
Assert-Contains $minio ".Values.minio.resources" "minio.yaml"
Assert-Contains $minio "/minio/health/live" "minio.yaml"
Assert-Contains $minio "MINIO_ROOT_PASSWORD" "minio.yaml"

$backup = Read-ChartFile "templates\backup.yaml"
Assert-Contains $backup "{{- if .Values.backup.enabled }}" "backup.yaml"
Assert-Contains $backup "kind: ServiceAccount" "backup.yaml"
Assert-Contains $backup "automountServiceAccountToken: false" "backup.yaml"
Assert-Contains $backup "kind: PersistentVolumeClaim" "backup.yaml"
Assert-Contains $backup "kind: CronJob" "backup.yaml"
Assert-Contains $backup ".Values.backup.mariadb.schedule" "backup.yaml"
Assert-Contains $backup ".Values.backup.minio.schedule" "backup.yaml"
Assert-Contains $backup "mariadb-dump --single-transaction" "backup.yaml"
Assert-Contains $backup "mc mirror --overwrite osmu" "backup.yaml"
Assert-Contains $backup ".Values.backup.retentionDays" "backup.yaml"
Assert-Contains $backup "serviceAccountName: {{ include `"osmu.fullname`" . }}-backup" "backup.yaml"
Assert-Contains $backup ".Values.backup.resources" "backup.yaml"
Assert-Contains $backup ".Values.backup.containerSecurityContext" "backup.yaml"

$ha = Read-ChartFile "templates\ha.yaml"
Assert-Contains $ha "{{- if .Values.ha.podDisruptionBudgets.enabled }}" "ha.yaml"
Assert-Contains $ha "kind: PodDisruptionBudget" "ha.yaml"
Assert-Contains $ha ".Values.ha.podDisruptionBudgets.backend.minAvailable" "ha.yaml"
Assert-Contains $ha ".Values.ha.podDisruptionBudgets.frontend.minAvailable" "ha.yaml"
Assert-Contains $ha ".Values.ha.podDisruptionBudgets.mariadb.minAvailable" "ha.yaml"
Assert-Contains $ha ".Values.ha.podDisruptionBudgets.minio.minAvailable" "ha.yaml"
Assert-Contains $ha "{{- if not .Values.minio.tenant.enabled }}" "ha.yaml"
Assert-Contains $ha "app.kubernetes.io/name: osmu-backend" "ha.yaml"
Assert-Contains $ha "app.kubernetes.io/name: osmu-frontend" "ha.yaml"
Assert-Contains $ha "app.kubernetes.io/name: osmu-mariadb" "ha.yaml"
Assert-Contains $ha "app.kubernetes.io/name: osmu-minio" "ha.yaml"

$backend = Read-ChartFile "templates\backend.yaml"
Assert-Contains $backend "kind: Deployment" "backend.yaml"
Assert-Contains $backend "replicas: {{ .Values.backend.replicas }}" "backend.yaml"
Assert-Contains $backend "serviceAccountName: osmu-backend" "backend.yaml"
Assert-Contains $backend "automountServiceAccountToken: false" "backend.yaml"
Assert-Contains $backend ".Values.ha.topologySpread.enabled" "backend.yaml"
Assert-Contains $backend "topologySpreadConstraints:" "backend.yaml"
Assert-Contains $backend ".Values.ha.topologySpread.topologyKey" "backend.yaml"
Assert-Contains $backend ".Values.backend.image.repository" "backend.yaml"
Assert-Contains $backend ".Values.backend.resources" "backend.yaml"
Assert-Contains $backend "SPRING_DATASOURCE_URL" "backend.yaml"
Assert-Contains $backend "OSMU_STORAGE_ACCESS_KEY" "backend.yaml"
Assert-Contains $backend "OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY" "backend.yaml"
Assert-Contains $backend ".Values.backend.operationsReports.enabled" "backend.yaml"
Assert-Contains $backend "operations-reports" "backend.yaml"
Assert-Contains $backend ".Values.backend.operationsReports.mountPath" "backend.yaml"
Assert-Contains $backend "readOnly: true" "backend.yaml"
Assert-Contains $backend ".Values.backend.operationsReports.type" "backend.yaml"
Assert-Contains $backend "persistentVolumeClaim:" "backend.yaml"
Assert-Contains $backend ".Values.backend.operationsReports.claimName" "backend.yaml"
Assert-Contains $backend "configMap:" "backend.yaml"
Assert-Contains $backend ".Values.backend.operationsReports.configMapName" "backend.yaml"
Assert-Contains $backend ".Values.backend.operationsReports.optional" "backend.yaml"
Assert-Contains $backend "path: /api/health" "backend.yaml"
Assert-Contains $backend ".Values.backend.metrics.enabled" "backend.yaml"
Assert-Contains $backend "prometheus.io/scrape" "backend.yaml"
Assert-Contains $backend ".Values.backend.metrics.path" "backend.yaml"

$frontend = Read-ChartFile "templates\frontend.yaml"
Assert-Contains $frontend "kind: Deployment" "frontend.yaml"
Assert-Contains $frontend "replicas: {{ .Values.frontend.replicas }}" "frontend.yaml"
Assert-Contains $frontend "serviceAccountName: osmu-frontend" "frontend.yaml"
Assert-Contains $frontend "automountServiceAccountToken: false" "frontend.yaml"
Assert-Contains $frontend ".Values.ha.topologySpread.enabled" "frontend.yaml"
Assert-Contains $frontend "topologySpreadConstraints:" "frontend.yaml"
Assert-Contains $frontend ".Values.ha.topologySpread.topologyKey" "frontend.yaml"
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
Assert-Contains $networkPolicy "name: osmu-backup-egress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-backend-egress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-mariadb-ingress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-minio-ingress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "app.kubernetes.io/name: osmu-backup" "networkpolicy.yaml"
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
Assert-Contains $monitoringOperator "OsmuBackupCronJobFailed" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "OsmuBackupCronJobStale" "monitoring-operator.yaml"

$templateFiles = Get-ChildItem -LiteralPath (Join-Path $resolvedChartDirectory "templates") -Filter *.yaml
foreach ($templateFile in $templateFiles) {
    $content = Get-Content -Raw -LiteralPath $templateFile.FullName
    Assert-True ($content.Contains("apiVersion:")) "$($templateFile.Name) is missing apiVersion."
    Assert-True ($content.Contains("kind:")) "$($templateFile.Name) is missing kind."
}

Write-Host "Helm chart draft verified."
Write-Host "Chart directory: $resolvedChartDirectory"
Write-Host "Files checked: $($requiredFiles.Count)"

