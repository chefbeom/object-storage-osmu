param(
    [string] $ManifestDirectory = ".\infra\k8s"
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

function Read-Manifest([string] $fileName) {
    $path = Join-Path $resolvedManifestDirectory $fileName
    Assert-True (Test-Path -LiteralPath $path) "Kubernetes manifest missing: $fileName"
    $content = Get-Content -Raw -LiteralPath $path
    Assert-True (-not $content.Contains("`t")) "Tabs are not allowed in Kubernetes manifest: $fileName"
    Assert-True ($content.Contains("apiVersion:")) "apiVersion missing in Kubernetes manifest: $fileName"
    Assert-True ($content.Contains("kind:")) "kind missing in Kubernetes manifest: $fileName"
    return $content
}

function Assert-Contains([string] $content, [string] $expected, [string] $fileName) {
    Assert-True $content.Contains($expected) "$fileName does not contain expected text: $expected"
}

$resolvedManifestDirectory = Resolve-ProjectPath $ManifestDirectory
Assert-True (Test-Path -LiteralPath $resolvedManifestDirectory) "Kubernetes manifest directory missing: $resolvedManifestDirectory"

$requiredFiles = @(
    "README.md",
    "namespace.yaml",
    "serviceaccount.yaml",
    "storage-expansion-rbac.yaml",
    "configmap.yaml",
    "secret.example.yaml",
    "mariadb.yaml",
    "minio.yaml",
    "backup.yaml",
    "ha.yaml",
    "backend.yaml",
    "frontend.yaml",
    "ingress.yaml",
    "networkpolicy.yaml",
    "monitoring-operator.yaml",
    "kustomization.yaml"
)

foreach ($fileName in $requiredFiles) {
    $path = Join-Path $resolvedManifestDirectory $fileName
    Assert-True (Test-Path -LiteralPath $path) "Required Kubernetes draft file missing: $fileName"
}

$namespace = Read-Manifest "namespace.yaml"
Assert-Contains $namespace "kind: Namespace" "namespace.yaml"
Assert-Contains $namespace "name: osmu" "namespace.yaml"

$serviceAccount = Read-Manifest "serviceaccount.yaml"
Assert-Contains $serviceAccount "kind: ServiceAccount" "serviceaccount.yaml"
Assert-Contains $serviceAccount "name: osmu-backend" "serviceaccount.yaml"
Assert-Contains $serviceAccount "name: osmu-frontend" "serviceaccount.yaml"
Assert-Contains $serviceAccount "name: osmu-mariadb" "serviceaccount.yaml"
Assert-Contains $serviceAccount "name: osmu-minio" "serviceaccount.yaml"
Assert-Contains $serviceAccount "automountServiceAccountToken: false" "serviceaccount.yaml"

$storageExpansionRbac = Read-Manifest "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "kind: ServiceAccount" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "name: osmu-storage-expansion-runner" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "automountServiceAccountToken: false" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "kind: Role" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "kind: RoleBinding" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "apiGroups:" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- minio.min.io" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- tenants" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- osmu-minio" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- statefulsets" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- statefulsets/status" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- get" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- patch" "storage-expansion-rbac.yaml"
Assert-Contains $storageExpansionRbac "- update" "storage-expansion-rbac.yaml"
Assert-True (-not $storageExpansionRbac.Contains("- delete")) "storage-expansion-rbac.yaml must not grant delete."
Assert-True (-not $storageExpansionRbac.Contains("- create")) "storage-expansion-rbac.yaml must not grant create."
Assert-True (-not $storageExpansionRbac.Contains("- secrets")) "storage-expansion-rbac.yaml must not grant secrets access."
Assert-True (-not $storageExpansionRbac.Contains("pods/exec")) "storage-expansion-rbac.yaml must not grant pod exec."

$configMap = Read-Manifest "configmap.yaml"
Assert-Contains $configMap "kind: ConfigMap" "configmap.yaml"
Assert-Contains $configMap "OSMU_METADATA_MODE: mariadb" "configmap.yaml"
Assert-Contains $configMap "OSMU_STORAGE_MODE: minio" "configmap.yaml"
Assert-Contains $configMap "OSMU_ACCESS_KEY_PROVISIONING_MODE: minio" "configmap.yaml"
Assert-Contains $configMap "OSMU_S3_PUBLIC_ENDPOINT: https://osmu.local/api/s3" "configmap.yaml"
Assert-Contains $configMap "OSMU_S3_REGION: us-east-1" "configmap.yaml"
Assert-Contains $configMap "OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH: .osmu-run/latest-operations-readiness-convergence.json" "configmap.yaml"
Assert-Contains $configMap "OSMU_OPERATIONS_READINESS_KUBERNETES_REPORT_SYNC_REPORT_PATH: .osmu-run/latest-kubernetes-operations-report-sync.json" "configmap.yaml"

$secretExample = Read-Manifest "secret.example.yaml"
Assert-Contains $secretExample "kind: Secret" "secret.example.yaml"
Assert-Contains $secretExample "MARIADB_PASSWORD:" "secret.example.yaml"
Assert-Contains $secretExample "MINIO_ROOT_PASSWORD:" "secret.example.yaml"
Assert-Contains $secretExample "OSMU_JWT_SECRET:" "secret.example.yaml"
Assert-Contains $secretExample "change-me" "secret.example.yaml"

$mariadb = Read-Manifest "mariadb.yaml"
Assert-Contains $mariadb "kind: StatefulSet" "mariadb.yaml"
Assert-Contains $mariadb "serviceAccountName: osmu-mariadb" "mariadb.yaml"
Assert-Contains $mariadb "automountServiceAccountToken: false" "mariadb.yaml"
Assert-Contains $mariadb "image: mariadb:11.4" "mariadb.yaml"
Assert-Contains $mariadb "healthcheck.sh" "mariadb.yaml"
Assert-Contains $mariadb "resources:" "mariadb.yaml"
Assert-Contains $mariadb "requests:" "mariadb.yaml"
Assert-Contains $mariadb "limits:" "mariadb.yaml"

$minio = Read-Manifest "minio.yaml"
Assert-Contains $minio "kind: StatefulSet" "minio.yaml"
Assert-Contains $minio "serviceAccountName: osmu-minio" "minio.yaml"
Assert-Contains $minio "automountServiceAccountToken: false" "minio.yaml"
Assert-Contains $minio "image: minio/minio:RELEASE.2025-05-24T17-08-30Z" "minio.yaml"
Assert-Contains $minio "/minio/health/live" "minio.yaml"
Assert-Contains $minio "resources:" "minio.yaml"
Assert-Contains $minio "requests:" "minio.yaml"
Assert-Contains $minio "limits:" "minio.yaml"

$backup = Read-Manifest "backup.yaml"
Assert-Contains $backup "kind: ServiceAccount" "backup.yaml"
Assert-Contains $backup "name: osmu-backup" "backup.yaml"
Assert-Contains $backup "automountServiceAccountToken: false" "backup.yaml"
Assert-Contains $backup "kind: PersistentVolumeClaim" "backup.yaml"
Assert-Contains $backup "name: osmu-backup-data" "backup.yaml"
Assert-Contains $backup "kind: CronJob" "backup.yaml"
Assert-Contains $backup "name: osmu-mariadb-backup" "backup.yaml"
Assert-Contains $backup "name: osmu-minio-backup" "backup.yaml"
Assert-Contains $backup "mariadb-dump --single-transaction" "backup.yaml"
Assert-Contains $backup "mc mirror --overwrite osmu" "backup.yaml"
Assert-Contains $backup "OSMU_BACKUP_RETENTION_DAYS" "backup.yaml"
Assert-Contains $backup "serviceAccountName: osmu-backup" "backup.yaml"
Assert-Contains $backup "allowPrivilegeEscalation: false" "backup.yaml"
Assert-Contains $backup "drop:" "backup.yaml"
Assert-Contains $backup "claimName: osmu-backup-data" "backup.yaml"

$ha = Read-Manifest "ha.yaml"
Assert-Contains $ha "apiVersion: policy/v1" "ha.yaml"
Assert-Contains $ha "kind: PodDisruptionBudget" "ha.yaml"
Assert-Contains $ha "name: osmu-backend" "ha.yaml"
Assert-Contains $ha "name: osmu-frontend" "ha.yaml"
Assert-Contains $ha "name: osmu-mariadb" "ha.yaml"
Assert-Contains $ha "name: osmu-minio" "ha.yaml"
Assert-Contains $ha "minAvailable: 1" "ha.yaml"
Assert-Contains $ha "app.kubernetes.io/name: osmu-backend" "ha.yaml"
Assert-Contains $ha "app.kubernetes.io/name: osmu-frontend" "ha.yaml"
Assert-Contains $ha "app.kubernetes.io/name: osmu-mariadb" "ha.yaml"
Assert-Contains $ha "app.kubernetes.io/name: osmu-minio" "ha.yaml"

$backend = Read-Manifest "backend.yaml"
Assert-Contains $backend "kind: Deployment" "backend.yaml"
Assert-Contains $backend "replicas: 2" "backend.yaml"
Assert-Contains $backend "serviceAccountName: osmu-backend" "backend.yaml"
Assert-Contains $backend "automountServiceAccountToken: false" "backend.yaml"
Assert-Contains $backend "topologySpreadConstraints:" "backend.yaml"
Assert-Contains $backend "topologyKey: kubernetes.io/hostname" "backend.yaml"
Assert-Contains $backend "whenUnsatisfiable: ScheduleAnyway" "backend.yaml"
Assert-Contains $backend "image: osmu-backend:local" "backend.yaml"
Assert-Contains $backend "SPRING_DATASOURCE_URL" "backend.yaml"
Assert-Contains $backend "OSMU_STORAGE_ACCESS_KEY" "backend.yaml"
Assert-Contains $backend "OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY" "backend.yaml"
Assert-Contains $backend "volumeMounts:" "backend.yaml"
Assert-Contains $backend "operations-reports" "backend.yaml"
Assert-Contains $backend "mountPath: /app/.osmu-run" "backend.yaml"
Assert-Contains $backend "readOnly: true" "backend.yaml"
Assert-Contains $backend "volumes:" "backend.yaml"
Assert-Contains $backend "name: osmu-operations-reports" "backend.yaml"
Assert-Contains $backend "optional: true" "backend.yaml"
Assert-Contains $backend "path: /api/health" "backend.yaml"
Assert-Contains $backend 'prometheus.io/scrape: "true"' "backend.yaml"
Assert-Contains $backend "prometheus.io/path: /actuator/prometheus" "backend.yaml"
Assert-Contains $backend 'prometheus.io/port: "8080"' "backend.yaml"
Assert-Contains $backend "resources:" "backend.yaml"
Assert-Contains $backend "requests:" "backend.yaml"
Assert-Contains $backend "limits:" "backend.yaml"

$frontend = Read-Manifest "frontend.yaml"
Assert-Contains $frontend "kind: Deployment" "frontend.yaml"
Assert-Contains $frontend "replicas: 2" "frontend.yaml"
Assert-Contains $frontend "serviceAccountName: osmu-frontend" "frontend.yaml"
Assert-Contains $frontend "automountServiceAccountToken: false" "frontend.yaml"
Assert-Contains $frontend "topologySpreadConstraints:" "frontend.yaml"
Assert-Contains $frontend "topologyKey: kubernetes.io/hostname" "frontend.yaml"
Assert-Contains $frontend "whenUnsatisfiable: ScheduleAnyway" "frontend.yaml"
Assert-Contains $frontend "image: osmu-frontend:local" "frontend.yaml"
Assert-Contains $frontend "containerPort: 8080" "frontend.yaml"
Assert-Contains $frontend "runAsNonRoot: true" "frontend.yaml"
Assert-Contains $frontend "runAsUser: 101" "frontend.yaml"
Assert-Contains $frontend "allowPrivilegeEscalation: false" "frontend.yaml"
Assert-Contains $frontend "resources:" "frontend.yaml"
Assert-Contains $frontend "requests:" "frontend.yaml"
Assert-Contains $frontend "limits:" "frontend.yaml"

$ingress = Read-Manifest "ingress.yaml"
Assert-Contains $ingress "kind: Ingress" "ingress.yaml"
Assert-Contains $ingress "host: osmu.local" "ingress.yaml"
Assert-Contains $ingress "nginx.ingress.kubernetes.io/ssl-redirect" "ingress.yaml"
Assert-Contains $ingress "nginx.ingress.kubernetes.io/force-ssl-redirect" "ingress.yaml"
Assert-Contains $ingress "tls:" "ingress.yaml"
Assert-Contains $ingress "secretName: osmu-tls" "ingress.yaml"
Assert-Contains $ingress "name: osmu-backend" "ingress.yaml"
Assert-Contains $ingress "name: osmu-frontend" "ingress.yaml"

$networkPolicy = Read-Manifest "networkpolicy.yaml"
Assert-Contains $networkPolicy "kind: NetworkPolicy" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-backup-egress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-backend-egress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-mariadb-ingress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-minio-ingress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "app.kubernetes.io/name: osmu-backup" "networkpolicy.yaml"
Assert-Contains $networkPolicy "policyTypes:" "networkpolicy.yaml"
Assert-Contains $networkPolicy "- Egress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "- Ingress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "port: 3306" "networkpolicy.yaml"
Assert-Contains $networkPolicy "port: 9000" "networkpolicy.yaml"
Assert-Contains $networkPolicy "kube-dns" "networkpolicy.yaml"

$monitoringOperator = Read-Manifest "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "apiVersion: monitoring.coreos.com/v1" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "kind: ServiceMonitor" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "kind: PrometheusRule" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "path: /actuator/prometheus" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "OsmuBackendDown" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "OsmuBackendHighErrorRate" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "OsmuBackendHighLatencyP95" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "OsmuBackupCronJobFailed" "monitoring-operator.yaml"
Assert-Contains $monitoringOperator "OsmuBackupCronJobStale" "monitoring-operator.yaml"

$kustomization = Read-Manifest "kustomization.yaml"
Assert-Contains $kustomization "kind: Kustomization" "kustomization.yaml"
Assert-Contains $kustomization "namespace.yaml" "kustomization.yaml"
Assert-Contains $kustomization "serviceaccount.yaml" "kustomization.yaml"
Assert-Contains $kustomization "storage-expansion-rbac.yaml" "kustomization.yaml"
Assert-Contains $kustomization "backup.yaml" "kustomization.yaml"
Assert-Contains $kustomization "ha.yaml" "kustomization.yaml"
Assert-Contains $kustomization "backend.yaml" "kustomization.yaml"
Assert-Contains $kustomization "frontend.yaml" "kustomization.yaml"
Assert-Contains $kustomization "networkpolicy.yaml" "kustomization.yaml"
Assert-True (-not $kustomization.Contains("secret.example.yaml")) "kustomization.yaml must not include secret.example.yaml."
Assert-True (-not $kustomization.Contains("monitoring-operator.yaml")) "kustomization.yaml must not include monitoring-operator.yaml unless Prometheus Operator CRDs are required."

$osmuDevOverlayDirectory = Join-Path $root "infra\k8s-overlays\osmu-dev"
Assert-True (Test-Path -LiteralPath $osmuDevOverlayDirectory) "osmu-dev overlay missing."
$osmuDevKustomization = Get-Content -Raw -LiteralPath (Join-Path $osmuDevOverlayDirectory "kustomization.yaml")
Assert-Contains $osmuDevKustomization "namespace: osmu-dev" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "osmu-dev.192.168.35.60.nip.io" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "30080" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "OSMU_S3_PUBLIC_ENDPOINT" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "ingressClassName" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "nodeSelector" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "eclipse-temurin:17-jre-jammy" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "nginx:1.27-alpine" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "/var/lib/osmu-dev/backend" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "/usr/local/bin/mc" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "MC_CONFIG_DIR" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "/var/lib/osmu-dev/frontend/dist" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "osmu-backup-data" "overlays/osmu-dev/kustomization.yaml"

$osmuDevFrontendNginx = Get-Content -Raw -LiteralPath (Join-Path $osmuDevOverlayDirectory "frontend-nginx-config.yaml")
Assert-Contains $osmuDevFrontendNginx "kind: ConfigMap" "overlays/osmu-dev/frontend-nginx-config.yaml"
Assert-Contains $osmuDevFrontendNginx "name: osmu-frontend-nginx" "overlays/osmu-dev/frontend-nginx-config.yaml"
Assert-Contains $osmuDevFrontendNginx "listen 8080" "overlays/osmu-dev/frontend-nginx-config.yaml"
Assert-Contains $osmuDevKustomization "osmu-dev-local" "overlays/osmu-dev/kustomization.yaml"

$osmuDevPv = Get-Content -Raw -LiteralPath (Join-Path $osmuDevOverlayDirectory "pv.yaml")
Assert-Contains $osmuDevPv "kind: StorageClass" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "kind: PersistentVolume" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "/var/lib/osmu-dev/mariadb" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "/var/lib/osmu-dev/minio" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "/var/lib/osmu-dev/backup" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "osmu-dev-backup-pv" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "nodeAffinity:" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "slave01" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "persistentVolumeReclaimPolicy: Retain" "overlays/osmu-dev/pv.yaml"

$restoreExample = Get-Content -Raw -LiteralPath (Join-Path $resolvedManifestDirectory "examples\restore-from-backup.example.yaml")
Assert-Contains $restoreExample "kind: Job" "examples/restore-from-backup.example.yaml"
Assert-Contains $restoreExample "osmu-restore-from-backup-example" "examples/restore-from-backup.example.yaml"
Assert-Contains $restoreExample "BACKUP_TIMESTAMP" "examples/restore-from-backup.example.yaml"
Assert-Contains $restoreExample "YYYYMMDDTHHMMSSZ" "examples/restore-from-backup.example.yaml"
Assert-Contains $restoreExample "serviceAccountName: osmu-backup" "examples/restore-from-backup.example.yaml"
Assert-Contains $restoreExample "automountServiceAccountToken: false" "examples/restore-from-backup.example.yaml"
Assert-Contains $restoreExample "mc mirror --overwrite" "examples/restore-from-backup.example.yaml"
Assert-Contains $restoreExample "Restoring can overwrite" "examples/restore-from-backup.example.yaml"

$yamlFiles = Get-ChildItem -LiteralPath $resolvedManifestDirectory -Filter *.yaml
foreach ($yamlFile in $yamlFiles) {
    $content = Get-Content -Raw -LiteralPath $yamlFile.FullName
    if ($yamlFile.Name -ne "secret.example.yaml") {
        Assert-True (-not $content.Contains("change-me")) "$($yamlFile.Name) contains placeholder secret text."
    }
}

Write-Host "Kubernetes draft manifests verified."
Write-Host "Manifest directory: $resolvedManifestDirectory"
Write-Host "Files checked: $($requiredFiles.Count)"
