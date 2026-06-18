param(
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [string] $OutputDir = "",
    [switch] $ConfirmRestore,
    [switch] $RemoveExtraObjects,
    [switch] $RestartBackend,
    [switch] $VerifyDemo,
    [switch] $RecordEvidence
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")

function Resolve-ProjectPath($path) {
    $path = Convert-OsmuPathSeparators $path
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

if (-not $ConfirmRestore) {
    throw "This drill backs up and restores local demo data. Rerun with -ConfirmRestore after confirming the target is safe."
}

$timestamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ")
if (-not $OutputDir) {
    $OutputDir = ".osmu-run\backup-restore-drills\local-demo-$timestamp"
}
$resolvedOutputDir = Resolve-ProjectPath $OutputDir
$backupDir = Join-Path $resolvedOutputDir "backup"
$evidencePath = Join-Path $resolvedOutputDir "restore-evidence.json"

$backupScript = Join-Path $PSScriptRoot "backup-local-demo.ps1"
$restoreScript = Join-Path $PSScriptRoot "restore-local-demo.ps1"

$backupArgs = @(
    "-EnvFile", $EnvFile,
    "-EnvExample", $EnvExample,
    "-ComposeFile", $ComposeFile,
    "-OutputDir", $backupDir
)
$backupExitCode = Invoke-OsmuPowerShellScript $backupScript $backupArgs
if ($backupExitCode -ne 0) {
    throw "Local demo backup failed."
}

$restoreArgs = @(
    "-BackupDir", $backupDir,
    "-EnvFile", $EnvFile,
    "-EnvExample", $EnvExample,
    "-ComposeFile", $ComposeFile,
    "-EvidenceOutputPath", $evidencePath,
    "-ConfirmRestore"
)
if ($RemoveExtraObjects) {
    $restoreArgs += "-RemoveExtraObjects"
}
if ($RestartBackend) {
    $restoreArgs += "-RestartBackend"
}
if ($VerifyDemo) {
    $restoreArgs += "-VerifyDemo"
}
if ($RecordEvidence) {
    $restoreArgs += "-RecordEvidence"
}

$restoreExitCode = Invoke-OsmuPowerShellScript $restoreScript $restoreArgs
if ($restoreExitCode -ne 0) {
    throw "Local demo restore drill failed."
}

Write-Host ""
Write-Host "Local backup/restore drill complete."
Write-Host "Output:   $resolvedOutputDir"
Write-Host "Backup:   $backupDir"
Write-Host "Evidence: $evidencePath"
