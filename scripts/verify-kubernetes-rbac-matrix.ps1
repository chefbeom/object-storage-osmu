param(
    [string] $MatrixPath = ".\dev-docs\kubernetes-rbac-matrix.md",
    [string] $K8sDirectory = ".\infra\k8s",
    [string] $HelmChartDirectory = ".\infra\helm\osmu"
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

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    Assert-True $content.Contains($expected) "$label does not contain expected text: $expected"
}

function Read-RequiredFile([string] $path, [string] $label) {
    $resolved = Resolve-ProjectPath $path
    Assert-True (Test-Path -LiteralPath $resolved) "$label not found: $resolved"
    $content = Get-Content -Raw -LiteralPath $resolved
    Assert-True (-not $content.Contains("`t")) "Tabs are not allowed in $label."
    return $content
}

$matrix = Read-RequiredFile $MatrixPath "Kubernetes RBAC matrix"
Assert-Contains $matrix "# OSMU Kubernetes RBAC Matrix" "Kubernetes RBAC matrix"
Assert-Contains $matrix "osmu-backend" "Kubernetes RBAC matrix"
Assert-Contains $matrix "osmu-frontend" "Kubernetes RBAC matrix"
Assert-Contains $matrix "osmu-mariadb" "Kubernetes RBAC matrix"
Assert-Contains $matrix "osmu-minio" "Kubernetes RBAC matrix"
Assert-Contains $matrix "osmu-backup" "Kubernetes RBAC matrix"
Assert-Contains $matrix "Automount Token" "Kubernetes RBAC matrix"
Assert-Contains $matrix "Role/RoleBinding" "Kubernetes RBAC matrix"
Assert-Contains $matrix "GitOps PR" "Kubernetes RBAC matrix"
Assert-Contains $matrix "osmu-storage-expansion-runner" "Kubernetes RBAC matrix"
Assert-Contains $matrix "Tenant/osmu-minio" "Kubernetes RBAC matrix"
Assert-Contains $matrix "no Secret read" "Kubernetes RBAC matrix"
Assert-Contains $matrix "verify-storage-expansion-rbac-auth.ps1" "Kubernetes RBAC matrix"
Assert-Contains $matrix "kubectl auth can-i" "Kubernetes RBAC matrix"

$authEvidenceScript = Read-RequiredFile ".\scripts\verify-storage-expansion-rbac-auth.ps1" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "kubectl auth can-i" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "tenants.minio.min.io/osmu-minio" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "statefulsets.apps/osmu-minio" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "secrets/osmu-secret" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "pods" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "jobs.batch" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "clusterroles.rbac.authorization.k8s.io" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "clusterrolebindings.rbac.authorization.k8s.io" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "latest-storage-expansion-rbac-auth.json" "Storage expansion RBAC auth evidence script"
Assert-Contains $authEvidenceScript "PlanOnly" "Storage expansion RBAC auth evidence script"

$serverDryRunScript = Read-RequiredFile ".\scripts\verify-storage-expansion-server-dry-run.ps1" "Storage expansion server-side dry-run evidence script"
Assert-Contains $serverDryRunScript "kubectl apply --server-side --dry-run=server" "Storage expansion server-side dry-run evidence script"
Assert-Contains $serverDryRunScript "tenants.minio.min.io" "Storage expansion server-side dry-run evidence script"
Assert-Contains $serverDryRunScript "minio-tenant-pool-expansion.example.yaml" "Storage expansion server-side dry-run evidence script"
Assert-Contains $serverDryRunScript "latest-storage-expansion-server-dry-run.json" "Storage expansion server-side dry-run evidence script"
Assert-Contains $serverDryRunScript "ImpersonateRunner" "Storage expansion server-side dry-run evidence script"
Assert-Contains $serverDryRunScript "PlanOnly" "Storage expansion server-side dry-run evidence script"

$verifyLocal = Read-RequiredFile ".\scripts\verify-local.ps1" "verify-local script"
Assert-Contains $verifyLocal "Storage Expansion RBAC auth plan check" "verify-local script"
Assert-Contains $verifyLocal "verify-storage-expansion-rbac-auth.ps1 -PlanOnly" "verify-local script"
Assert-Contains $verifyLocal "Storage Expansion server dry-run plan check" "verify-local script"
Assert-Contains $verifyLocal "verify-storage-expansion-server-dry-run.ps1 -PlanOnly" "verify-local script"

$k8sDir = Resolve-ProjectPath $K8sDirectory
$serviceAccount = Read-RequiredFile (Join-Path $k8sDir "serviceaccount.yaml") "Kubernetes serviceaccount manifest"
foreach ($name in @("osmu-backend", "osmu-frontend", "osmu-mariadb", "osmu-minio")) {
    Assert-Contains $serviceAccount "name: $name" "Kubernetes serviceaccount manifest"
}
Assert-Contains $serviceAccount "automountServiceAccountToken: false" "Kubernetes serviceaccount manifest"

$storageExpansionRbac = Read-RequiredFile (Join-Path $k8sDir "storage-expansion-rbac.yaml") "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "kind: ServiceAccount" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "name: osmu-storage-expansion-runner" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "automountServiceAccountToken: false" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "kind: Role" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "kind: RoleBinding" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "- minio.min.io" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "- tenants" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "- osmu-minio" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "- statefulsets" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "- statefulsets/status" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "- get" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "- patch" "Kubernetes storage expansion RBAC manifest"
Assert-Contains $storageExpansionRbac "- update" "Kubernetes storage expansion RBAC manifest"
Assert-True (-not $storageExpansionRbac.Contains("- delete")) "Storage expansion runner must not grant delete."
Assert-True (-not $storageExpansionRbac.Contains("- create")) "Storage expansion runner must not grant create."
Assert-True (-not $storageExpansionRbac.Contains("- secrets")) "Storage expansion runner must not grant secret read."
Assert-True (-not $storageExpansionRbac.Contains("pods/exec")) "Storage expansion runner must not grant pod exec."

$kustomization = Read-RequiredFile (Join-Path $k8sDir "kustomization.yaml") "Kubernetes kustomization"
Assert-Contains $kustomization "serviceaccount.yaml" "Kubernetes kustomization"
Assert-Contains $kustomization "storage-expansion-rbac.yaml" "Kubernetes kustomization"

foreach ($entry in @(
    @{ File = "backend.yaml"; ServiceAccount = "osmu-backend" },
    @{ File = "frontend.yaml"; ServiceAccount = "osmu-frontend" },
    @{ File = "mariadb.yaml"; ServiceAccount = "osmu-mariadb" },
    @{ File = "minio.yaml"; ServiceAccount = "osmu-minio" }
)) {
    $content = Read-RequiredFile (Join-Path $k8sDir $entry.File) "Kubernetes $($entry.File)"
    Assert-Contains $content "serviceAccountName: $($entry.ServiceAccount)" "Kubernetes $($entry.File)"
    Assert-Contains $content "automountServiceAccountToken: false" "Kubernetes $($entry.File)"
}

$backup = Read-RequiredFile (Join-Path $k8sDir "backup.yaml") "Kubernetes backup manifest"
Assert-Contains $backup "name: osmu-backup" "Kubernetes backup manifest"
Assert-Contains $backup "serviceAccountName: osmu-backup" "Kubernetes backup manifest"
Assert-Contains $backup "automountServiceAccountToken: false" "Kubernetes backup manifest"

$restore = Read-RequiredFile (Join-Path $k8sDir "examples\restore-from-backup.example.yaml") "Kubernetes restore example"
Assert-Contains $restore "serviceAccountName: osmu-backup" "Kubernetes restore example"
Assert-Contains $restore "automountServiceAccountToken: false" "Kubernetes restore example"

$allK8s = Get-ChildItem -LiteralPath $k8sDir -Filter *.yaml -Recurse |
    Where-Object { $_.Name -ne "monitoring-operator.yaml" } |
    ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            Content = Get-Content -Raw -LiteralPath $_.FullName
        }
    }
$joinedK8s = ($allK8s | ForEach-Object { $_.Content }) -join "`n"
Assert-True (-not [regex]::IsMatch($joinedK8s, "(?m)^kind:\s+(ClusterRole|ClusterRoleBinding)\s*$")) "Application Kubernetes manifests must not grant cluster-scoped RBAC."
$unauthorizedRbac = $allK8s |
    Where-Object { $_.Name -ne "storage-expansion-rbac.yaml" -and [regex]::IsMatch($_.Content, "(?m)^kind:\s+(Role|RoleBinding)\s*$") }
Assert-True (-not $unauthorizedRbac) "Only storage-expansion-rbac.yaml may define namespace Role/RoleBinding."

$helmDir = Resolve-ProjectPath $HelmChartDirectory
$helmServiceAccount = Read-RequiredFile (Join-Path $helmDir "templates\serviceaccount.yaml") "Helm serviceaccount template"
foreach ($name in @("osmu-backend", "osmu-frontend", "osmu-mariadb", "osmu-minio")) {
    Assert-Contains $helmServiceAccount "name: $name" "Helm serviceaccount template"
}
Assert-Contains $helmServiceAccount "automountServiceAccountToken: false" "Helm serviceaccount template"

$helmStorageExpansionRbac = Read-RequiredFile (Join-Path $helmDir "templates\storage-expansion-rbac.yaml") "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "{{- if .Values.storageExpansion.runner.rbac.enabled }}" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "kind: ServiceAccount" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "kind: Role" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "kind: RoleBinding" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac ".Values.storageExpansion.runner.rbac.serviceAccountName" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac ".Values.storageExpansion.runner.rbac.tenantName" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac ".Values.storageExpansion.runner.rbac.legacyStatefulSetName" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "- minio.min.io" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "- tenants" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "- statefulsets" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "- statefulsets/status" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "- get" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "- patch" "Helm storage expansion RBAC template"
Assert-Contains $helmStorageExpansionRbac "- update" "Helm storage expansion RBAC template"
Assert-True (-not $helmStorageExpansionRbac.Contains("- delete")) "Helm storage expansion runner must not grant delete."
Assert-True (-not $helmStorageExpansionRbac.Contains("- create")) "Helm storage expansion runner must not grant create."
Assert-True (-not $helmStorageExpansionRbac.Contains("- secrets")) "Helm storage expansion runner must not grant secret read."
Assert-True (-not $helmStorageExpansionRbac.Contains("pods/exec")) "Helm storage expansion runner must not grant pod exec."

$allHelmTemplates = Get-ChildItem -LiteralPath (Join-Path $helmDir "templates") -Filter *.yaml |
    ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            Content = Get-Content -Raw -LiteralPath $_.FullName
        }
    }
$joinedHelm = ($allHelmTemplates | ForEach-Object { $_.Content }) -join "`n"
Assert-True (-not [regex]::IsMatch($joinedHelm, "(?m)^kind:\s+(ClusterRole|ClusterRoleBinding)\s*$")) "Helm templates must not grant cluster-scoped RBAC."
$unauthorizedHelmRbac = $allHelmTemplates |
    Where-Object { $_.Name -ne "storage-expansion-rbac.yaml" -and [regex]::IsMatch($_.Content, "(?m)^kind:\s+(Role|RoleBinding)\s*$") }
Assert-True (-not $unauthorizedHelmRbac) "Only storage-expansion-rbac.yaml may define namespace Role/RoleBinding in Helm templates."

foreach ($entry in @(
    @{ File = "templates\backend.yaml"; ServiceAccount = "osmu-backend" },
    @{ File = "templates\frontend.yaml"; ServiceAccount = "osmu-frontend" },
    @{ File = "templates\mariadb.yaml"; ServiceAccount = "osmu-mariadb" },
    @{ File = "templates\minio.yaml"; ServiceAccount = "osmu-minio" }
)) {
    $content = Read-RequiredFile (Join-Path $helmDir $entry.File) "Helm $($entry.File)"
    Assert-Contains $content "serviceAccountName: $($entry.ServiceAccount)" "Helm $($entry.File)"
    Assert-Contains $content "automountServiceAccountToken: false" "Helm $($entry.File)"
}

$helmBackup = Read-RequiredFile (Join-Path $helmDir "templates\backup.yaml") "Helm backup template"
Assert-Contains $helmBackup "kind: ServiceAccount" "Helm backup template"
Assert-Contains $helmBackup "serviceAccountName: {{ include `"osmu.fullname`" . }}-backup" "Helm backup template"
Assert-Contains $helmBackup "automountServiceAccountToken: false" "Helm backup template"

Write-Host "Kubernetes RBAC matrix verified."
Write-Host "Matrix: $(Resolve-ProjectPath $MatrixPath)"
