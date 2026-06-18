param(
    [Parameter(Mandatory = $true)]
    [string] $BackupDir,
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [string] $ApiBase = "",
    [string] $AdminLoginId = "",
    [string] $AdminPassword = "",
    [string] $EvidenceOutputPath = "",
    [switch] $ConfirmRestore,
    [switch] $RemoveExtraObjects,
    [switch] $SkipMetadataRestore,
    [switch] $SkipObjectRestore,
    [switch] $RestartBackend,
    [switch] $VerifyDemo,
    [switch] $RecordEvidence
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

function Convert-ToDockerBindPath($path) {
    return ([System.IO.Path]::GetFullPath($path) -replace "\\", "/")
}

function Get-FileSha256($path) {
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
}

function Invoke-Json($method, $url, $body = $null, $token = $null) {
    $headers = @{}
    if ($token) {
        $headers.Authorization = "Bearer $token"
    }
    if ($null -eq $body) {
        return Invoke-RestMethod -Method $method -Uri $url -Headers $headers
    }
    return Invoke-RestMethod `
        -Method $method `
        -Uri $url `
        -Headers $headers `
        -ContentType "application/json" `
        -Body ($body | ConvertTo-Json -Depth 10)
}

if (-not $ConfirmRestore) {
    throw "Restore can overwrite local demo data. Rerun with -ConfirmRestore after checking the backup path."
}

$script:ResolvedEnvFile = Resolve-ProjectPath $EnvFile
$resolvedEnvExample = Resolve-ProjectPath $EnvExample
if (-not (Test-Path -LiteralPath $script:ResolvedEnvFile)) {
    $script:ResolvedEnvFile = $resolvedEnvExample
}
$script:ResolvedComposeFile = Resolve-ProjectPath $ComposeFile
$resolvedBackupDir = Resolve-ProjectPath $BackupDir
$manifestPath = Join-Path $resolvedBackupDir "backup-manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Backup manifest not found: $manifestPath"
}
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.formatVersion -ne "osmu.local-backup.v1") {
    throw "Unsupported backup manifest format: $($manifest.formatVersion)"
}

$restoreStartedAt = [DateTimeOffset]::UtcNow
Step "Validate Docker and compose"
Invoke-Docker @("info", "--format", "{{json .ServerVersion}}")
Invoke-Compose @("config", "--quiet")

if (-not $SkipMetadataRestore) {
    Step "Restore MariaDB metadata"
    $metadataDumpPath = Join-Path $resolvedBackupDir "metadata.sql"
    if (-not (Test-Path -LiteralPath $metadataDumpPath)) {
        throw "Metadata dump not found: $metadataDumpPath"
    }
    $containerRestorePath = "/tmp/osmu-restore-$([DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ")).sql"
    Invoke-Docker @("cp", $metadataDumpPath, "osmu-mariadb:$containerRestorePath")
    $restoreCommand = 'mariadb -u"$MARIADB_USER" --password="$MARIADB_PASSWORD" "$MARIADB_DATABASE" < ' + $containerRestorePath
    Invoke-Docker @("exec", "osmu-mariadb", "sh", "-c", $restoreCommand)
    Invoke-Docker @("exec", "osmu-mariadb", "sh", "-c", "rm -f $containerRestorePath")
}

if (-not $SkipObjectRestore) {
    Step "Restore MinIO objects"
    $objectBackupPath = Join-Path (Join-Path $resolvedBackupDir "objects") "minio"
    if (-not (Test-Path -LiteralPath $objectBackupPath)) {
        throw "Object backup path not found: $objectBackupPath"
    }
    $objectsRoot = Split-Path -Parent $objectBackupPath
    $bindMount = "$(Convert-ToDockerBindPath $objectsRoot):/backup"
    $removeFlag = if ($RemoveExtraObjects) { "--remove " } else { "" }
    $mirrorCommand = 'mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null && mc mirror ' + $removeFlag + '--overwrite /backup/minio local'
    Invoke-Compose @("run", "--rm", "--entrypoint", "/bin/sh", "-v", $bindMount, "create-minio-buckets", "-c", $mirrorCommand)
}

if ($RestartBackend) {
    Step "Restart backend"
    Invoke-Compose @("restart", "backend")
}

if (-not $ApiBase) {
    $backendPort = Read-EnvValue $script:ResolvedEnvFile "BACKEND_PORT" "8080"
    $ApiBase = "http://localhost:$backendPort/api"
}
if (-not $AdminLoginId) {
    $AdminLoginId = Read-EnvValue $script:ResolvedEnvFile "OSMU_ADMIN_LOGIN_ID" "admin"
}
if (-not $AdminPassword) {
    $AdminPassword = Read-EnvValue $script:ResolvedEnvFile "OSMU_ADMIN_PASSWORD" "password"
}

if ($VerifyDemo) {
    Step "Verify local demo after restore"
    $verifyScript = Join-Path $PSScriptRoot "verify-local-demo.ps1"
    $verifyExitCode = Invoke-OsmuPowerShellScript $verifyScript @(
        "-ApiBase", $ApiBase,
        "-AdminLoginId", $AdminLoginId,
        "-AdminPassword", $AdminPassword
    )
    if ($verifyExitCode -ne 0) {
        throw "Post-restore local demo verification failed."
    }
}

$restoreCompletedAt = [DateTimeOffset]::UtcNow
if (-not $EvidenceOutputPath) {
    $EvidenceOutputPath = ".osmu-run\restore-drills\local-demo-$($restoreCompletedAt.ToString("yyyyMMddTHHmmssZ")).json"
}
$resolvedEvidenceOutputPath = Resolve-ProjectPath $EvidenceOutputPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedEvidenceOutputPath) | Out-Null

$manifestSha256 = Get-FileSha256 $manifestPath
$gaps = @()
if (-not $VerifyDemo) {
    $gaps += "Post-restore local demo verification was not executed."
}
if ($SkipMetadataRestore) {
    $gaps += "MariaDB metadata restore was skipped."
}
if ($SkipObjectRestore) {
    $gaps += "MinIO object restore was skipped."
}

$evidence = [ordered]@{
    formatVersion = "osmu.local-restore-drill.v1"
    environment = "local-demo"
    result = if ($gaps.Count -eq 0) { "SUCCESS" } else { "PARTIAL" }
    startedAt = $restoreStartedAt.ToString("o")
    completedAt = $restoreCompletedAt.ToString("o")
    backupTimestamp = [string]$manifest.createdAt
    backupManifestSha256 = $manifestSha256
    metadataRowCount = [long]$manifest.metadata.rowCount
    objectCount = [long]$manifest.objects.fileCount
    objectBytes = [long]$manifest.objects.bytes
    evidenceUri = $EvidenceOutputPath
    gaps = $gaps
    secretPolicy = "Secret values are not copied into this restore drill evidence."
}

$evidenceJson = $evidence | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($resolvedEvidenceOutputPath, $evidenceJson, [System.Text.UTF8Encoding]::new($false))

if ($RecordEvidence) {
    Step "Record restore drill evidence"
    $login = Invoke-Json "POST" "$ApiBase/auth/login" @{
        loginId = $AdminLoginId
        password = $AdminPassword
    }
    $token = $login.data.accessToken
    if (-not $token) {
        throw "Admin login did not return accessToken."
    }
    $requestBody = @{
        environment = $evidence.environment
        operator = $AdminLoginId
        result = $evidence.result
        startedAt = $evidence.startedAt
        completedAt = $evidence.completedAt
        backupTimestamp = $evidence.backupTimestamp
        metadataRowCount = $evidence.metadataRowCount
        objectCount = $evidence.objectCount
        objectBytes = $evidence.objectBytes
        backupManifestSha256 = $evidence.backupManifestSha256
        evidenceUri = $evidence.evidenceUri
        gaps = $evidence.gaps
    }
    Invoke-Json "POST" "$ApiBase/admin/backup/restore-drill-evidence" $requestBody $token | Out-Null
}

Step "Restore drill evidence"
Write-Host "Evidence: $resolvedEvidenceOutputPath"
Write-Host "Result:   $($evidence.result)"
Write-Host "Gaps:     $($gaps.Count)"
