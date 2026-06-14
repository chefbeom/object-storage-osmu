param(
    [string] $Namespace = "osmu-dev",
    [string] $ManifestDirectory = ".\infra\k8s-overlays\osmu-dev",
    [string] $BackendImage = "osmu-backend:local",
    [string] $FrontendImage = "osmu-frontend:local",
    [switch] $SkipRolloutWait
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function New-SecretValue([int] $bytes = 32) {
    $buffer = New-Object byte[] $bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($buffer)
    }
    finally {
        $rng.Dispose()
    }
    return [Convert]::ToBase64String($buffer)
}

function Invoke-Kubectl {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Arguments
    )

    & kubectl @Arguments
}

$manifestPath = Resolve-ProjectPath $ManifestDirectory
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest directory missing: $manifestPath"
}

& kubectl create namespace $Namespace --dry-run=client -o yaml |
    & kubectl apply -f -

$secretExists = $true
Invoke-Kubectl "-n" $Namespace "get" "secret" "osmu-secret" *> $null
if ($LASTEXITCODE -ne 0) {
    $secretExists = $false
}

if (-not $secretExists) {
    $secretArgs = @(
        "-n", $Namespace,
        "create", "secret", "generic", "osmu-secret",
        "--from-literal=MARIADB_USER=osmu",
        "--from-literal=MARIADB_PASSWORD=$(New-SecretValue)",
        "--from-literal=MARIADB_ROOT_PASSWORD=$(New-SecretValue)",
        "--from-literal=MINIO_ROOT_USER=osmuadmin",
        "--from-literal=MINIO_ROOT_PASSWORD=$(New-SecretValue)",
        "--from-literal=OSMU_ADMIN_PASSWORD=$(New-SecretValue 18)",
        "--from-literal=OSMU_JWT_SECRET=$(New-SecretValue 48)",
        "--from-literal=OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY=$(New-SecretValue 48)",
        "--dry-run=client",
        "-o",
        "yaml"
    )
    & kubectl @secretArgs |
        & kubectl apply -f -
}

Invoke-Kubectl "apply" "-k" $manifestPath

if ($BackendImage -ne "osmu-backend:local") {
    Invoke-Kubectl "-n" $Namespace "set" "image" "deployment/osmu-backend" "backend=$BackendImage"
}

if ($FrontendImage -ne "osmu-frontend:local") {
    Invoke-Kubectl "-n" $Namespace "set" "image" "deployment/osmu-frontend" "frontend=$FrontendImage"
}

if (-not $SkipRolloutWait) {
    Invoke-Kubectl "-n" $Namespace "rollout" "status" "deployment/osmu-backend" "--timeout=180s"
    Invoke-Kubectl "-n" $Namespace "rollout" "status" "deployment/osmu-frontend" "--timeout=180s"
    Invoke-Kubectl "-n" $Namespace "rollout" "status" "statefulset/osmu-mariadb" "--timeout=180s"
    Invoke-Kubectl "-n" $Namespace "rollout" "status" "statefulset/osmu-minio" "--timeout=180s"
}

Invoke-Kubectl "-n" $Namespace "get" "pods,svc,ingress,pvc"
Invoke-Kubectl "get" "pv" "osmu-dev-mariadb-pv" "osmu-dev-minio-pv"
