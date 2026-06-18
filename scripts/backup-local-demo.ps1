param(
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [string] $OutputDir = "",
    [switch] $SkipMetadataDump,
    [switch] $SkipObjectMirror
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")
Use-OsmuDockerConfig $root | Out-Null

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Resolve-ProjectPath($path) {
    $path = Convert-OsmuPathSeparators $path
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-EnvValue($path, $name, $defaultValue) {
    $resolved = Resolve-Path -LiteralPath $path -ErrorAction Stop
    foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $resolved.Path) {
        if ($line -match "^\s*#" -or $line -match "^\s*$") {
            continue
        }
        if ($line -match "^\s*$([regex]::Escape($name))=(.*)$") {
            return $Matches[1].Trim()
        }
    }
    return $defaultValue
}

function Invoke-Docker([string[]] $Arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & docker @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($output) {
        $output | ForEach-Object { Write-Host $_ }
    }
    if ($exitCode -ne 0) {
        throw "docker failed: $($Arguments -join ' ')"
    }
}

function Invoke-DockerCapture([string[]] $Arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & docker @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        throw "docker failed: $($Arguments -join ' ')"
    }
    return (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
}

function Invoke-Compose([string[]] $ComposeArgs) {
    Push-Location $root
    try {
        $arguments = @("compose", "--env-file", $script:ResolvedEnvFile, "-f", $script:ResolvedComposeFile) + $ComposeArgs
        Invoke-Docker $arguments
    }
    finally {
        Pop-Location
    }
}

function Assert-DockerDaemon() {
    Invoke-Docker @("info", "--format", "{{json .ServerVersion}}")
}

function Get-FileSha256($path) {
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
}

function Convert-ToDockerBindPath($path) {
    return ([System.IO.Path]::GetFullPath($path) -replace "\\", "/")
}

function Get-ObjectMirrorStats($path) {
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{ Count = 0; Bytes = 0 }
    }
    $files = Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        Count = ($files | Measure-Object).Count
        Bytes = [long](($files | Measure-Object -Property Length -Sum).Sum)
    }
}

$script:ResolvedEnvFile = Resolve-ProjectPath $EnvFile
$resolvedEnvExample = Resolve-ProjectPath $EnvExample
if (-not (Test-Path -LiteralPath $script:ResolvedEnvFile)) {
    $script:ResolvedEnvFile = $resolvedEnvExample
}
$script:ResolvedComposeFile = Resolve-ProjectPath $ComposeFile

$timestamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ")
if (-not $OutputDir) {
    $OutputDir = ".osmu-run\backups\local-demo-$timestamp"
}
$resolvedOutputDir = Resolve-ProjectPath $OutputDir
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null

Step "Validate Docker and compose"
Assert-DockerDaemon
Invoke-Compose @("config", "--quiet")

$databaseName = Read-EnvValue $script:ResolvedEnvFile "MARIADB_DATABASE" "osmu"
$metadataDumpPath = Join-Path $resolvedOutputDir "metadata.sql"
$objectMirrorPath = Join-Path (Join-Path $resolvedOutputDir "objects") "minio"
$manifestPath = Join-Path $resolvedOutputDir "backup-manifest.json"
$backupStartedAt = [DateTimeOffset]::UtcNow
$metadataRowCount = 0L

if (-not $SkipMetadataDump) {
    Step "Backup MariaDB metadata"
    $containerDumpPath = "/tmp/osmu-metadata-$timestamp.sql"
    $dumpCommand = 'mariadb-dump --single-transaction --routines --triggers -u"$MARIADB_USER" --password="$MARIADB_PASSWORD" "$MARIADB_DATABASE" > ' + $containerDumpPath
    Invoke-Docker @("exec", "osmu-mariadb", "sh", "-c", $dumpCommand)
    Invoke-Docker @("cp", "osmu-mariadb:$containerDumpPath", $metadataDumpPath)
    Invoke-Docker @("exec", "osmu-mariadb", "sh", "-c", "rm -f $containerDumpPath")

    $rowCountCommand = 'mariadb -N -B -u"$MARIADB_USER" --password="$MARIADB_PASSWORD" "$MARIADB_DATABASE" -e "SELECT COALESCE(SUM(TABLE_ROWS), 0) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE();"'
    $rowCountText = Invoke-DockerCapture @("exec", "osmu-mariadb", "sh", "-c", $rowCountCommand)
    if ($rowCountText -match "^\d+$") {
        $metadataRowCount = [long]$rowCountText
    }
}

if (-not $SkipObjectMirror) {
    Step "Backup MinIO objects"
    New-Item -ItemType Directory -Force -Path $objectMirrorPath | Out-Null
    $objectsRoot = Split-Path -Parent $objectMirrorPath
    $bindMount = "$(Convert-ToDockerBindPath $objectsRoot):/backup"
    $mirrorCommand = 'mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null && mc mirror --overwrite local /backup/minio'
    Invoke-Compose @("run", "--rm", "--entrypoint", "/bin/sh", "-v", $bindMount, "create-minio-buckets", "-c", $mirrorCommand)
}

$backupCompletedAt = [DateTimeOffset]::UtcNow
$objectStats = Get-ObjectMirrorStats $objectMirrorPath
$metadataBytes = if (Test-Path -LiteralPath $metadataDumpPath) { (Get-Item -LiteralPath $metadataDumpPath).Length } else { 0L }

$manifest = [ordered]@{
    formatVersion = "osmu.local-backup.v1"
    environment = "local-demo"
    createdAt = $backupCompletedAt.ToString("o")
    startedAt = $backupStartedAt.ToString("o")
    completedAt = $backupCompletedAt.ToString("o")
    source = [ordered]@{
        composeFile = $script:ResolvedComposeFile
        envFile = $script:ResolvedEnvFile
        metadataStore = "mariadb"
        objectStore = "minio"
        database = $databaseName
    }
    metadata = [ordered]@{
        file = "metadata.sql"
        bytes = $metadataBytes
        rowCount = $metadataRowCount
        sha256 = Get-FileSha256 $metadataDumpPath
        skipped = [bool]$SkipMetadataDump
    }
    objects = [ordered]@{
        path = "objects/minio"
        fileCount = $objectStats.Count
        bytes = $objectStats.Bytes
        skipped = [bool]$SkipObjectMirror
    }
    secretPolicy = "Secret values are not copied into this backup manifest."
}

$manifestJson = $manifest | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))
$manifestSha256 = Get-FileSha256 $manifestPath

Step "Backup manifest"
Write-Host "Output:   $resolvedOutputDir"
Write-Host "Manifest: $manifestPath"
Write-Host "SHA-256:  $manifestSha256"
Write-Host "Rows:     $metadataRowCount"
Write-Host "Objects:  $($objectStats.Count)"
Write-Host "Bytes:    $($objectStats.Bytes)"
