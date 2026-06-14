param(
    [string] $DrillPath = ".\dev-docs\backup-restore-drill.md",
    [string] $BackupRecoveryPath = ".\dev-docs\backup-recovery.md",
    [string] $DeploymentStrategyPath = ".\dev-docs\deployment-strategy.md"
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

function Read-RequiredFile([string] $path, [string] $label) {
    $resolved = Resolve-ProjectPath $path
    Assert-True (Test-Path -LiteralPath $resolved) "$label not found: $resolved"
    $content = Get-Content -Raw -LiteralPath $resolved
    Assert-True (-not $content.Contains("`t")) "Tabs are not allowed in $label."
    return $content
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    Assert-True $content.Contains($expected) "$label does not contain expected text: $expected"
}

$drill = Read-RequiredFile $DrillPath "Backup restore drill"
Assert-Contains $drill "MariaDB metadata backup and restore." "Backup restore drill"
Assert-Contains $drill "MinIO bucket/object backup and restore." "Backup restore drill"
Assert-Contains $drill "MVP pilot RPO: 24 hours." "Backup restore drill"
Assert-Contains $drill "MVP pilot RTO: 4 hours" "Backup restore drill"
Assert-Contains $drill "Do not copy secret values" "Backup restore drill"
Assert-Contains $drill "Drill Runbook" "Backup restore drill"
Assert-Contains $drill "Restore MariaDB metadata." "Backup restore drill"
Assert-Contains $drill "Restore MinIO bucket/object data." "Backup restore drill"
Assert-Contains $drill "verify-s3-client-smoke.ps1" "Backup restore drill"
Assert-Contains $drill "Acceptance Criteria" "Backup restore drill"
Assert-Contains $drill "Actual durable restore execution requires Docker/MariaDB/MinIO" "Backup restore drill"

$backupRecovery = Read-RequiredFile $BackupRecoveryPath "Backup recovery"
Assert-Contains $backupRecovery "backup-restore-drill.md" "Backup recovery"

$deploymentStrategy = Read-RequiredFile $DeploymentStrategyPath "Deployment strategy"
Assert-Contains $deploymentStrategy "backup-restore-drill.md" "Deployment strategy"

Write-Host "Backup restore drill draft verified."
Write-Host "Drill: $(Resolve-ProjectPath $DrillPath)"
