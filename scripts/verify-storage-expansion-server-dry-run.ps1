param(
    [string] $Namespace = "osmu",
    [string] $TenantName = "osmu-minio",
    [string] $ManifestPath = ".\infra\k8s\examples\minio-tenant-pool-expansion.example.yaml",
    [string] $KubectlPath = "kubectl",
    [string] $EvidencePath = ".\.osmu-run\latest-storage-expansion-server-dry-run.json",
    [string] $ServiceAccount = "osmu-storage-expansion-runner",
    [switch] $ImpersonateRunner,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

# Live evidence command pattern: kubectl apply --server-side --dry-run=server -f <tenant-pool-expansion-manifest>

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Invoke-KubectlEvidence([string] $Id, [string[]] $Arguments) {
    $outputLines = & $KubectlPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output = ($outputLines | ForEach-Object { $_.ToString() }) -join "`n"
    return [pscustomobject]@{
        id = $Id
        command = "$KubectlPath $($Arguments -join ' ')"
        exitCode = $exitCode
        output = $output
        passed = $exitCode -eq 0
    }
}

function Add-Impersonation([string[]] $Arguments) {
    if (-not $ImpersonateRunner) {
        return $Arguments
    }
    $subject = "system:serviceaccount:$Namespace`:$ServiceAccount"
    return @("--as=$subject") + $Arguments
}

function New-EffectiveManifest([string] $sourcePath) {
    $content = Read-Utf8Text $sourcePath
    Assert-True $content.Contains("apiVersion: minio.min.io/v2") "Storage expansion manifest must target MinIO Tenant apiVersion minio.min.io/v2."
    Assert-True $content.Contains("kind: Tenant") "Storage expansion manifest must define a MinIO Tenant."
    Assert-True $content.Contains("name: $TenantName") "Storage expansion manifest must target Tenant name: $TenantName."
    Assert-True $content.Contains("pool-1") "Storage expansion manifest must include the expansion pool example pool-1."
    Assert-True $content.Contains("volumesPerServer") "Storage expansion manifest must include volumesPerServer."

    $effectiveContent = [regex]::Replace($content, "(?m)^  namespace:\s+\S+\s*$", "  namespace: $Namespace", 1)
    $temporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) ("osmu-storage-expansion-dry-run-" + [Guid]::NewGuid().ToString("N") + ".yaml")
    Set-Content -Encoding UTF8 -LiteralPath $temporaryPath -Value $effectiveContent
    return $temporaryPath
}

$resolvedManifestPath = Resolve-ProjectPath $ManifestPath
Assert-True (Test-Path -LiteralPath $resolvedManifestPath) "Storage expansion manifest not found: $resolvedManifestPath"

$subject = "system:serviceaccount:$Namespace`:$ServiceAccount"
$effectiveManifestForPlan = if ($Namespace -eq "osmu") { $resolvedManifestPath } else { "<temporary manifest with namespace $Namespace>" }
$crdArgs = @("get", "crd", "tenants.minio.min.io", "-o", "name")
$tenantArgs = Add-Impersonation @("-n", $Namespace, "get", "tenants.minio.min.io", $TenantName, "-o", "name")
$dryRunArgs = Add-Impersonation @("-n", $Namespace, "apply", "--server-side", "--dry-run=server", "-f", $effectiveManifestForPlan)

if ($PlanOnly) {
    Write-Host "Storage Expansion server-side dry-run plan only."
    Write-Host "Namespace: $Namespace"
    Write-Host "Tenant: $TenantName"
    Write-Host "Manifest: $resolvedManifestPath"
    Write-Host "Impersonate runner: $ImpersonateRunner"
    if ($ImpersonateRunner) {
        Write-Host "Subject: $subject"
    }
    Write-Host "[CHECK] MinIO Tenant CRD: $KubectlPath $($crdArgs -join ' ')"
    Write-Host "[CHECK] Existing Tenant: $KubectlPath $($tenantArgs -join ' ')"
    Write-Host "[CHECK] Server dry-run: $KubectlPath $($dryRunArgs -join ' ')"
    Write-Host "Plan only; no evidence file written."
    exit 0
}

$command = Get-Command $KubectlPath -ErrorAction SilentlyContinue
if (-not $command) {
    throw "kubectl executable not found: $KubectlPath"
}

$effectiveManifestPath = New-EffectiveManifest $resolvedManifestPath
try {
    $sourceManifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedManifestPath).Hash.ToLowerInvariant()
    $effectiveManifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $effectiveManifestPath).Hash.ToLowerInvariant()
    $actualDryRunArgs = Add-Impersonation @("-n", $Namespace, "apply", "--server-side", "--dry-run=server", "-f", $effectiveManifestPath)

    $results = @(
        (Invoke-KubectlEvidence "tenant-crd-present" $crdArgs)
        (Invoke-KubectlEvidence "existing-tenant-present" $tenantArgs)
        (Invoke-KubectlEvidence "server-side-dry-run" $actualDryRunArgs)
    )
}
finally {
    if (Test-Path -LiteralPath $effectiveManifestPath) {
        Remove-Item -LiteralPath $effectiveManifestPath -Force
    }
}

$failed = @($results | Where-Object { -not $_.passed })
$evidence = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    namespace = $Namespace
    tenantName = $TenantName
    manifestPath = $resolvedManifestPath
    manifestSha256 = $sourceManifestHash
    effectiveManifestSha256 = $effectiveManifestHash
    kubectlPath = $KubectlPath
    impersonateRunner = [bool] $ImpersonateRunner
    serviceAccount = $ServiceAccount
    subject = if ($ImpersonateRunner) { $subject } else { "" }
    passed = $failed.Count -eq 0
    failedCount = $failed.Count
    results = $results
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory | Out-Null
}
$evidence | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -LiteralPath $resolvedEvidencePath

if ($failed.Count -gt 0) {
    $failedIds = ($failed | ForEach-Object { $_.id }) -join ", "
    throw "Storage Expansion server-side dry-run failed: $failedIds. Evidence: $resolvedEvidencePath"
}

Write-Host "Storage Expansion server-side dry-run passed."
Write-Host "Evidence: $resolvedEvidencePath"
