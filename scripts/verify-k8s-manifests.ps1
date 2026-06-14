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
    "configmap.yaml",
    "secret.example.yaml",
    "mariadb.yaml",
    "minio.yaml",
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

$configMap = Read-Manifest "configmap.yaml"
Assert-Contains $configMap "kind: ConfigMap" "configmap.yaml"
Assert-Contains $configMap "OSMU_METADATA_MODE: mariadb" "configmap.yaml"
Assert-Contains $configMap "OSMU_STORAGE_MODE: minio" "configmap.yaml"
Assert-Contains $configMap "OSMU_ACCESS_KEY_PROVISIONING_MODE: minio" "configmap.yaml"

$secretExample = Read-Manifest "secret.example.yaml"
Assert-Contains $secretExample "kind: Secret" "secret.example.yaml"
Assert-Contains $secretExample "MARIADB_PASSWORD:" "secret.example.yaml"
Assert-Contains $secretExample "MINIO_ROOT_PASSWORD:" "secret.example.yaml"
Assert-Contains $secretExample "OSMU_JWT_SECRET:" "secret.example.yaml"
Assert-Contains $secretExample "change-me" "secret.example.yaml"

$mariadb = Read-Manifest "mariadb.yaml"
Assert-Contains $mariadb "kind: StatefulSet" "mariadb.yaml"
Assert-Contains $mariadb "image: mariadb:11.4" "mariadb.yaml"
Assert-Contains $mariadb "healthcheck.sh" "mariadb.yaml"
Assert-Contains $mariadb "resources:" "mariadb.yaml"
Assert-Contains $mariadb "requests:" "mariadb.yaml"
Assert-Contains $mariadb "limits:" "mariadb.yaml"

$minio = Read-Manifest "minio.yaml"
Assert-Contains $minio "kind: StatefulSet" "minio.yaml"
Assert-Contains $minio "image: minio/minio:RELEASE.2025-05-24T17-08-30Z" "minio.yaml"
Assert-Contains $minio "/minio/health/live" "minio.yaml"
Assert-Contains $minio "resources:" "minio.yaml"
Assert-Contains $minio "requests:" "minio.yaml"
Assert-Contains $minio "limits:" "minio.yaml"

$backend = Read-Manifest "backend.yaml"
Assert-Contains $backend "kind: Deployment" "backend.yaml"
Assert-Contains $backend "image: osmu-backend:local" "backend.yaml"
Assert-Contains $backend "SPRING_DATASOURCE_URL" "backend.yaml"
Assert-Contains $backend "OSMU_STORAGE_ACCESS_KEY" "backend.yaml"
Assert-Contains $backend "OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY" "backend.yaml"
Assert-Contains $backend "path: /api/health" "backend.yaml"
Assert-Contains $backend 'prometheus.io/scrape: "true"' "backend.yaml"
Assert-Contains $backend "prometheus.io/path: /actuator/prometheus" "backend.yaml"
Assert-Contains $backend 'prometheus.io/port: "8080"' "backend.yaml"
Assert-Contains $backend "resources:" "backend.yaml"
Assert-Contains $backend "requests:" "backend.yaml"
Assert-Contains $backend "limits:" "backend.yaml"

$frontend = Read-Manifest "frontend.yaml"
Assert-Contains $frontend "kind: Deployment" "frontend.yaml"
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
Assert-Contains $networkPolicy "name: osmu-backend-egress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-mariadb-ingress" "networkpolicy.yaml"
Assert-Contains $networkPolicy "name: osmu-minio-ingress" "networkpolicy.yaml"
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

$kustomization = Read-Manifest "kustomization.yaml"
Assert-Contains $kustomization "kind: Kustomization" "kustomization.yaml"
Assert-Contains $kustomization "namespace.yaml" "kustomization.yaml"
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
Assert-Contains $osmuDevKustomization "ingressClassName" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "nodeSelector" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "eclipse-temurin:17-jre-jammy" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "nginx:1.27-alpine" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "/var/lib/osmu-dev/backend" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "/usr/local/bin/mc" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "MC_CONFIG_DIR" "overlays/osmu-dev/kustomization.yaml"
Assert-Contains $osmuDevKustomization "/var/lib/osmu-dev/frontend/dist" "overlays/osmu-dev/kustomization.yaml"

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
Assert-Contains $osmuDevPv "nodeAffinity:" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "slave01" "overlays/osmu-dev/pv.yaml"
Assert-Contains $osmuDevPv "persistentVolumeReclaimPolicy: Retain" "overlays/osmu-dev/pv.yaml"

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
