param(
    [string] $MigrationDir = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

if (-not $MigrationDir) {
    $MigrationDir = Join-Path $root "osmu-backend\src\main\resources\db\migration"
}

$resolvedMigrationDir = Resolve-Path -LiteralPath $MigrationDir
$migrations = Get-ChildItem -LiteralPath $resolvedMigrationDir -Filter "V*__*.sql" |
    ForEach-Object {
        if ($_.Name -notmatch '^V(?<version>[0-9]+)__.+\.sql$') {
            throw "Invalid Flyway migration name: $($_.Name)"
        }
        [pscustomobject]@{
            Version = [int]$Matches.version
            Name = $_.Name
        }
    }

if (($migrations | Measure-Object).Count -eq 0) {
    throw "No Flyway migrations found in $($resolvedMigrationDir.Path)."
}

$duplicates = $migrations |
    Group-Object Version |
    Where-Object { $_.Count -gt 1 }

if ($duplicates) {
    $message = ($duplicates | ForEach-Object {
        "V$($_.Name): $($_.Group.Name -join ', ')"
    }) -join "; "
    throw "Duplicate Flyway migration versions found. $message"
}

$highest = ($migrations | Measure-Object Version -Maximum).Maximum
Write-Host "Flyway migration check passed: $($migrations.Count) migrations, highest V$highest."
