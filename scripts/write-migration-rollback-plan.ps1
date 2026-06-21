param(
    [string] $MigrationDir = "",
    [string] $EnvironmentName = "local",
    [string] $TargetDatabase = "osmu",
    [string] $Operator = "",
    [string] $BackupArtifactRef = "",
    [string] $PreviousReleaseRef = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-migration-rollback-plan.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-migration-rollback-plan.md",
    [switch] $NoWrite,
    [switch] $FailIfBackupMissing
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Normalize-Optional([string] $value) {
    if ($null -eq $value) {
        return ""
    }
    return $value.Trim()
}

function Assert-PlainReference([string] $value, [string] $name) {
    $normalized = Normalize-Optional $value
    if (-not $normalized) {
        return
    }
    $secretPattern = "(?i)(password|passwd|secret|token|apikey|api_key|access[_-]?key|private[_-]?key)\s*[:=]"
    if ($normalized -match $secretPattern) {
        throw "$name must be a non-secret reference, not credential material."
    }
}

function New-Stage([string] $id, [string] $title, [string] $purpose, [string[]] $commands, [string[]] $evidence, [string] $gate) {
    return [pscustomobject][ordered]@{
        id = $id
        title = $title
        purpose = $purpose
        commands = @($commands)
        evidence = @($evidence)
        gate = $gate
    }
}

if (-not $MigrationDir) {
    $MigrationDir = Join-Path $root "osmu-backend\src\main\resources\db\migration"
}

$resolvedMigrationDir = Resolve-ProjectPath $MigrationDir
if (-not (Test-Path -LiteralPath $resolvedMigrationDir)) {
    throw "Migration directory not found: $resolvedMigrationDir"
}

$migrationFiles = @(Get-ChildItem -LiteralPath $resolvedMigrationDir -Filter "V*__*.sql" | Sort-Object Name)
if ($migrationFiles.Count -eq 0) {
    throw "No Flyway migrations found in $resolvedMigrationDir."
}

$migrations = @()
foreach ($file in $migrationFiles) {
    if ($file.Name -notmatch '^V(?<version>[0-9]+)__(?<name>.+)\.sql$') {
        throw "Invalid Flyway migration name: $($file.Name)"
    }
    $migrationVersion = [int]$Matches.version
    $migrationDescription = $Matches.name
    $sql = Get-Content -Raw -LiteralPath $file.FullName
    $riskFlags = @()
    if ($sql -match '(?im)\bdrop\s+table\b') { $riskFlags += "drop-table" }
    if ($sql -match '(?im)\balter\s+table\b.+\bdrop\b') { $riskFlags += "alter-drop" }
    if ($sql -match '(?im)\btruncate\s+table\b') { $riskFlags += "truncate" }
    if ($sql -match '(?im)\bdelete\s+from\b') { $riskFlags += "delete-data" }
    if ($sql -match '(?im)\bupdate\b.+\bset\b') { $riskFlags += "data-rewrite" }
    if ($sql -match '(?im)\balter\s+table\b') { $riskFlags += "alter-table" }
    if ($sql -match '(?im)\bcreate\s+table\b') { $riskFlags += "create-table" }

    $migrations += [pscustomobject][ordered]@{
        version = $migrationVersion
        file = $file.Name
        description = $migrationDescription
        riskFlags = @($riskFlags | Select-Object -Unique)
    }
}

$duplicates = @($migrations | Group-Object version | Where-Object { $_.Count -gt 1 })
if ($duplicates.Count -gt 0) {
    $message = ($duplicates | ForEach-Object { "V$($_.Name)" }) -join ", "
    throw "Duplicate Flyway migration versions found: $message"
}

$migrations = @($migrations | Sort-Object version)
$highest = ($migrations | Measure-Object version -Maximum).Maximum
$latest = $migrations | Where-Object { $_.version -eq $highest } | Select-Object -First 1
$riskyMigrations = @($migrations | Where-Object { @($_.riskFlags).Count -gt 0 })
$backupArtifactRef = Normalize-Optional $BackupArtifactRef
$previousReleaseRef = Normalize-Optional $PreviousReleaseRef
$operatorName = Normalize-Optional $Operator
if (-not $operatorName) {
    $operatorName = Normalize-Optional ([Environment]::UserName)
}

Assert-PlainReference $backupArtifactRef "BackupArtifactRef"
Assert-PlainReference $previousReleaseRef "PreviousReleaseRef"
Assert-PlainReference $operatorName "Operator"

$backupReady = [bool]$backupArtifactRef
$result = if ($backupReady) { "ready-with-backup-reference" } else { "plan-ready-backup-required" }
if ($FailIfBackupMissing -and -not $backupReady) {
    $result = "failed"
}

$stages = @(
    New-Stage "preflight" "Pre-migration preflight" "Confirm migration order, static index coverage, and current release identity before the database is changed." @(
        "powershell -ExecutionPolicy Bypass -File .\scripts\verify-migrations.ps1",
        "powershell -ExecutionPolicy Bypass -File .\scripts\verify-metadata-index-coverage.ps1",
        "git rev-parse --short HEAD"
    ) @(
        "latest successful verify-migrations output",
        "latest metadata index coverage report",
        "current release or commit reference"
    ) "All checks pass before migration window starts."
    New-Stage "backup" "Backup before migration" "Create a restorable MariaDB metadata backup and record the non-secret artifact reference." @(
        "powershell -ExecutionPolicy Bypass -File .\scripts\backup-local-demo.ps1",
        "mysqldump --single-transaction --routines --triggers <metadata-db> > <backup-artifact>.sql"
    ) @(
        "backup artifact path or immutable object reference",
        "backup checksum",
        "restore command template"
    ) "A backup artifact reference is recorded before applying new migrations."
    New-Stage "forward-migrate" "Apply forward migrations" "Deploy the new backend version and let Flyway apply only forward migrations." @(
        "start backend with target release",
        "check Flyway startup logs",
        "GET /api/database/health or actuator health"
    ) @(
        "deployed release reference",
        "Flyway migration success log",
        "database health response"
    ) "Application starts and Flyway reports success."
    New-Stage "post-migrate-smoke" "Post-migration smoke" "Verify metadata read/write paths before opening broad traffic." @(
        "powershell -ExecutionPolicy Bypass -File .\scripts\verify-local-demo.ps1",
        "powershell -ExecutionPolicy Bypass -File .\scripts\verify-docker-integration.ps1"
    ) @(
        "local demo verification report",
        "Docker integration report when Docker is available"
    ) "Critical bucket/object/access-key/audit paths pass."
    New-Stage "rollback-restore" "Rollback by restore" "If migration or smoke fails before accepting new writes, stop writers, restore the metadata backup, and redeploy the previous release." @(
        "stop backend write traffic",
        "powershell -ExecutionPolicy Bypass -File .\scripts\restore-local-demo.ps1",
        "mysql < <backup-artifact>.sql",
        "deploy previous release reference"
    ) @(
        "restore log",
        "previous release reference",
        "post-restore health check"
    ) "Database and app release are both back at the pre-migration boundary."
    New-Stage "compensating-migration" "Rollback after new writes" "If the system accepted writes after migration, do not restore over live data. Ship a new forward compensating migration instead." @(
        "create V<next>__compensate_<issue>.sql",
        "review data-preserving SQL",
        "run focused backend tests and migration checks"
    ) @(
        "compensating migration PR",
        "review approval",
        "focused test output"
    ) "No live post-migration writes are overwritten."
)

$decisionRule = "Migration rollback is ready when a pre-migration backup reference exists, migration/static index checks pass, restore commands are known, and post-migration smoke gates define when to restore versus when to ship a compensating forward migration."
$scopePolicy = "Flyway migrations are forward-only in this repository. This plan does not create automatic down migrations. Rollback means restoring a verified backup before new writes, or applying a reviewed compensating forward migration after new writes."

$generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
$report = [pscustomobject][ordered]@{
    formatVersion = "osmu.migration-rollback-plan.v1"
    generatedAt = $generatedAt
    result = $result
    environmentName = Normalize-Optional $EnvironmentName
    targetDatabase = Normalize-Optional $TargetDatabase
    operator = $operatorName
    backupArtifactRequired = $true
    backupArtifactRef = $backupArtifactRef
    previousReleaseRef = $previousReleaseRef
    migrationDirectory = $resolvedMigrationDir
    migrationCount = $migrations.Count
    latestMigrationVersion = $latest.version
    latestMigrationFile = $latest.file
    riskyMigrationCount = $riskyMigrations.Count
    riskyMigrations = @($riskyMigrations)
    decisionRule = $decisionRule
    scopePolicy = $scopePolicy
    stages = @($stages)
}

$markdownLines = @(
    "# OSMU Migration Rollback Plan",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Environment: $($report.environmentName)",
    "Target database: $($report.targetDatabase)",
    "Migration count: $($report.migrationCount)",
    "Latest migration: V$($report.latestMigrationVersion) $($report.latestMigrationFile)",
    "Backup artifact required: $($report.backupArtifactRequired)",
    "Backup artifact reference: $(if ($backupArtifactRef) { $backupArtifactRef } else { '<required-before-live-migration>' })",
    "",
    "## Decision Rule",
    "",
    $decisionRule,
    "",
    "## Scope Policy",
    "",
    $scopePolicy,
    "",
    "## Stages",
    ""
)

foreach ($stage in $stages) {
    $markdownLines += "### $($stage.title)"
    $markdownLines += ""
    $markdownLines += $stage.purpose
    $markdownLines += ""
    $markdownLines += "Gate: $($stage.gate)"
    $markdownLines += ""
    $markdownLines += "Commands:"
    foreach ($command in $stage.commands) {
        $markdownLines += "- $command"
    }
    $markdownLines += ""
    $markdownLines += "Evidence:"
    foreach ($item in $stage.evidence) {
        $markdownLines += "- $item"
    }
    $markdownLines += ""
}

if ($riskyMigrations.Count -gt 0) {
    $markdownLines += "## Risk Flags"
    $markdownLines += ""
    foreach ($migration in $riskyMigrations) {
        $markdownLines += "- V$($migration.version) $($migration.file): $(@($migration.riskFlags) -join ', ')"
    }
    $markdownLines += ""
}

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Migration rollback plan JSON: $resolvedJsonOutputPath"
    Write-Host "Migration rollback plan markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfBackupMissing -and -not $backupReady) {
    throw "Migration rollback plan requires BackupArtifactRef before live migration."
}
