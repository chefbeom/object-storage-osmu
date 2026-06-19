param(
    [string] $OutputDirectory = ".\.osmu-run\operations-readiness-artifact-import-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
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

function Write-JsonEvidence([string] $Path, [hashtable] $Data) {
    $resolvedPath = Resolve-ProjectPath $Path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedPath) | Out-Null
    $Data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
}

function Write-TextEvidence([string] $Path, [string] $Content) {
    $resolvedPath = Resolve-ProjectPath $Path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedPath) | Out-Null
    $Content | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$sourceRoot = Join-Path $resolvedOutputDirectory "source"
$promotedRoot = Join-Path $resolvedOutputDirectory "promoted"
$invalidRoot = Join-Path $resolvedOutputDirectory "invalid-source"

$storageSource = Join-Path $sourceRoot "storage-expansion"
$haDrSource = Join-Path $sourceRoot "ha-dr-readiness"
$kubernetesDrSource = Join-Path $sourceRoot "kubernetes-dr"
$iamSource = Join-Path $sourceRoot "iam-rbac"
$securitySource = Join-Path $sourceRoot "security-evidence"
$enterpriseAuthSource = Join-Path $sourceRoot "enterprise-auth"
$kubernetesOperationsReportSyncSource = Join-Path $sourceRoot "kubernetes-operations-report-sync"

Write-JsonEvidence (Join-Path $storageSource "latest-storage-expansion-finalize.json") @{
    formatVersion = "osmu.storage-expansion-finalize.v1"
    result = "passed"
}
Write-TextEvidence (Join-Path $storageSource "latest-storage-expansion-finalize.md") "# Storage expansion"
Write-JsonEvidence (Join-Path $haDrSource "latest-kubernetes-ha-dr-readiness.json") @{
    formatVersion = "osmu.kubernetes-ha-dr-readiness.v1"
    result = "passed"
}
Write-JsonEvidence (Join-Path $kubernetesDrSource "nested\latest-kubernetes-dr-finalize.json") @{
    formatVersion = "osmu.kubernetes-dr-finalize.v1"
    result = "ready"
}
Write-TextEvidence (Join-Path $kubernetesDrSource "latest-kubernetes-dr-finalize.md") "# Kubernetes DR"
Write-JsonEvidence (Join-Path $iamSource "latest-iam-rbac-finalize.json") @{
    formatVersion = "osmu.iam-rbac-finalize.v1"
    result = "passed"
}
Write-TextEvidence (Join-Path $iamSource "latest-iam-rbac-finalize.md") "# IAM/RBAC"
Write-JsonEvidence (Join-Path $securitySource "latest-security-evidence-finalize.json") @{
    formatVersion = "osmu.security-evidence-finalize.v1"
    result = "passed"
}
Write-JsonEvidence (Join-Path $securitySource "latest-image-signing-evidence.json") @{
    formatVersion = "osmu.image-signing-evidence.v1"
    result = "passed"
}
Write-JsonEvidence (Join-Path $securitySource "latest-container-security-evidence.json") @{
    formatVersion = "osmu.container-security-evidence.v1"
    result = "passed"
}
Write-JsonEvidence (Join-Path $enterpriseAuthSource "latest-enterprise-auth-smoke.json") @{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "passed"
}
Write-TextEvidence (Join-Path $enterpriseAuthSource "latest-enterprise-auth-smoke.md") "# Enterprise auth smoke"
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-kubernetes-operations-report-sync.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "applied"
    failedCount = 0
}
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-kubernetes-operations-report-sync-plan.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "planned"
}
Write-JsonEvidence (Join-Path $kubernetesOperationsReportSyncSource "latest-kubernetes-operations-report-sync-server-dry-run.json") @{
    formatVersion = "osmu.kubernetes-operations-report-sync.v1"
    result = "server-dry-run-passed"
}

$importScript = Resolve-ProjectPath ".\scripts\import-operations-readiness-artifacts.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
    -StorageExpansionArtifactPath $storageSource `
    -HaDrReadinessArtifactPath $haDrSource `
    -KubernetesDrArtifactPath $kubernetesDrSource `
    -IamRbacArtifactPath $iamSource `
    -SecurityEvidenceArtifactPath $securitySource `
    -EnterpriseAuthArtifactPath $enterpriseAuthSource `
    -KubernetesOperationsReportSyncArtifactPath $kubernetesOperationsReportSyncSource `
    -OutputDirectory $promotedRoot `
    -JsonOutputPath (Join-Path $resolvedOutputDirectory "latest-operations-readiness-artifact-import.json") `
    -MarkdownOutputPath (Join-Path $resolvedOutputDirectory "latest-operations-readiness-artifact-import.md") | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "import-operations-readiness-artifacts.ps1 failed with exit code $LASTEXITCODE."
}

$reportPath = Join-Path $resolvedOutputDirectory "latest-operations-readiness-artifact-import.json"
$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
Assert-True ($report.formatVersion -eq "osmu.operations-readiness-artifact-import.v1") "Unexpected import report formatVersion."
Assert-True ($report.result -eq "passed") "Expected import report result=passed."
Assert-True ($report.status -eq "artifact-imported") "Expected import report status=artifact-imported."
Assert-True ($report.importedCount -ge 8) "Expected imported evidence files."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-storage-expansion-finalize.json")) "Promoted storage expansion evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-ha-dr-readiness.json")) "Promoted HA/DR readiness evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-dr-finalize.json")) "Promoted Kubernetes DR evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-iam-rbac-finalize.json")) "Promoted IAM/RBAC evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-security-evidence-finalize.json")) "Promoted security finalizer evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-image-signing-evidence.json")) "Promoted image signing evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-container-security-evidence.json")) "Promoted container security evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-enterprise-auth-smoke.json")) "Promoted enterprise auth smoke evidence missing."
Assert-True (Test-Path -LiteralPath (Join-Path $promotedRoot "latest-kubernetes-operations-report-sync.json")) "Promoted Kubernetes operations report sync evidence missing."

Write-JsonEvidence (Join-Path $invalidRoot "latest-kubernetes-ha-dr-readiness.json") @{
    formatVersion = "osmu.kubernetes-ha-dr-readiness.v1"
    result = "failed"
}
$invalidOutput = Join-Path $resolvedOutputDirectory "invalid-promoted"
$invalidJson = Join-Path $resolvedOutputDirectory "invalid-import.json"
$invalidMarkdown = Join-Path $resolvedOutputDirectory "invalid-import.md"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $importScript `
        -HaDrReadinessArtifactPath $invalidRoot `
        -OutputDirectory $invalidOutput `
        -JsonOutputPath $invalidJson `
        -MarkdownOutputPath $invalidMarkdown 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Invalid HA/DR evidence import should fail."
Assert-True (Test-Path -LiteralPath $invalidJson) "Invalid import report should still be written."
$invalidReport = Get-Content -Raw -LiteralPath $invalidJson | ConvertFrom-Json
Assert-True ($invalidReport.result -eq "failed") "Invalid import report should be failed."
Assert-True (-not (Test-Path -LiteralPath (Join-Path $invalidOutput "latest-kubernetes-ha-dr-readiness.json"))) "Invalid evidence must not be promoted."

Write-Host "Operations readiness artifact import verified."
Write-Host "Report: $reportPath"
