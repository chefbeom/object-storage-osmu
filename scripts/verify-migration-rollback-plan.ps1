param(
    [string] $OutputDir = ".\.osmu-run\migration-rollback-plan-verification"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
}
function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Assert-Contains([string] $value, [string] $expected, [string] $label) {
    if (-not $value -or -not $value.Contains($expected)) {
        throw "$label must contain '$expected'."
    }
}

$resolvedOutputDir = Resolve-ProjectPath $OutputDir
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null
$jsonPath = Join-Path $resolvedOutputDir "latest-migration-rollback-plan.json"
$markdownPath = Join-Path $resolvedOutputDir "latest-migration-rollback-plan.md"
$withBackupJsonPath = Join-Path $resolvedOutputDir "migration-rollback-plan-with-backup.json"
$withBackupMarkdownPath = Join-Path $resolvedOutputDir "migration-rollback-plan-with-backup.md"

& (Join-Path $PSScriptRoot "write-migration-rollback-plan.ps1") `
    -EnvironmentName "verification" `
    -TargetDatabase "osmu_test" `
    -Operator "verification-runner" `
    -JsonOutputPath $jsonPath `
    -MarkdownOutputPath $markdownPath

$report = Read-Utf8Text $jsonPath | ConvertFrom-Json
$markdown = Read-Utf8Text $markdownPath

Assert-True ($report.formatVersion -eq "osmu.migration-rollback-plan.v1") "Unexpected migration rollback plan formatVersion."
Assert-True ($report.result -eq "plan-ready-backup-required") "Default plan result should require a backup reference."
Assert-True ($report.backupArtifactRequired -eq $true) "Migration rollback plan must require a backup artifact."
Assert-True ($report.migrationCount -gt 0) "Migration rollback plan must include migration count."
Assert-True ($report.latestMigrationVersion -gt 0) "Migration rollback plan must include latest migration version."
Assert-Contains $report.decisionRule "pre-migration backup reference" "decisionRule"
Assert-Contains $report.scopePolicy "forward-only" "scopePolicy"
Assert-Contains $report.scopePolicy "compensating forward migration" "scopePolicy"

$stageIds = @($report.stages | ForEach-Object { $_.id })
foreach ($requiredStage in @("preflight", "backup", "forward-migrate", "post-migrate-smoke", "rollback-restore", "compensating-migration")) {
    Assert-True ($stageIds -contains $requiredStage) "Migration rollback plan missing stage '$requiredStage'."
}

$allCommands = (($report.stages | ForEach-Object { $_.commands }) -join "`n")
Assert-Contains $allCommands "verify-migrations.ps1" "stage commands"
Assert-Contains $allCommands "backup-local-demo.ps1" "stage commands"
Assert-Contains $allCommands "restore-local-demo.ps1" "stage commands"

$secretPattern = "(?i)(password|passwd|secret|token|apikey|api_key|access[_-]?key|private[_-]?key)\s*[:=]"
Assert-True (-not (($report | ConvertTo-Json -Depth 12) -match $secretPattern)) "Migration rollback plan must not contain credential-shaped values."
Assert-Contains $markdown "Backup artifact reference: <required-before-live-migration>" "markdown"
Assert-Contains $markdown "Rollback by restore" "markdown"
Assert-Contains $markdown "Rollback after new writes" "markdown"

& (Join-Path $PSScriptRoot "write-migration-rollback-plan.ps1") `
    -EnvironmentName "verification" `
    -TargetDatabase "osmu_test" `
    -Operator "verification-runner" `
    -BackupArtifactRef "artifact://metadata-backup-self-test" `
    -PreviousReleaseRef "release/self-test-previous" `
    -JsonOutputPath $withBackupJsonPath `
    -MarkdownOutputPath $withBackupMarkdownPath `
    -FailIfBackupMissing

$withBackupReport = Read-Utf8Text $withBackupJsonPath | ConvertFrom-Json
Assert-True ($withBackupReport.result -eq "ready-with-backup-reference") "Plan with BackupArtifactRef should be ready."
Assert-True ($withBackupReport.backupArtifactRef -eq "artifact://metadata-backup-self-test") "Plan with BackupArtifactRef should preserve reference."

Write-Host "Migration rollback plan verification passed: $jsonPath"
