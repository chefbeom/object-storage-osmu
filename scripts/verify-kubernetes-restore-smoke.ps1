param(
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "",
    [string] $ExpectedBucketName = "",
    [string] $ExpectedObjectKey = "",
    [string] $OutputPath = ".\.osmu-run\latest-kubernetes-restore-smoke.json",
    [string] $S3Endpoint = "",
    [ValidateSet("auto", "aws", "boto3", "mc", "docker-mc", "all")]
    [string] $S3Client = "auto",
    [switch] $RunS3ClientSmoke,
    [switch] $RequireS3Client,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
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

function Encode-PathSegment([string] $value) {
    return [System.Uri]::EscapeDataString($value)
}

function Encode-ObjectKey([string] $value) {
    return (($value -split "/") | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join "/"
}

function New-Check([string] $name, [string] $status, [string] $detail) {
    return [ordered]@{
        name = $name
        status = $status
        detail = $detail
    }
}

if ($PlanOnly) {
    Write-Host "Kubernetes restore smoke plan only."
    Write-Host "API base: $ApiBase"
    Write-Host "Output: $OutputPath"
    Write-Host "Expected bucket: $ExpectedBucketName"
    Write-Host "Expected object: $ExpectedObjectKey"
    Write-Host "Run S3 client smoke: $RunS3ClientSmoke"
    Write-Host "S3 client: $S3Client"
    Write-Host "[CHECK] GET $ApiBase/health"
    Write-Host "[CHECK] GET $ApiBase/storage/health"
    Write-Host "[CHECK] GET $ApiBase/database/health"
    Write-Host "[CHECK] POST $ApiBase/auth/login"
    Write-Host "[CHECK] GET $ApiBase/admin/backup/status"
    if ($ExpectedBucketName) {
        Write-Host "[CHECK] GET $ApiBase/buckets"
    }
    if ($ExpectedBucketName -and $ExpectedObjectKey) {
        Write-Host "[CHECK] GET $ApiBase/buckets/$ExpectedBucketName/objects/$ExpectedObjectKey"
    }
    if ($RunS3ClientSmoke) {
        Write-Host "[CHECK] scripts/verify-s3-client-smoke.ps1 against the restored target"
    }
    Write-Host "Plan only; no HTTP request, S3 smoke, or evidence file is written."
    return
}

$checks = New-Object System.Collections.Generic.List[object]
$token = ""
$apiSmokePassed = $true

function Add-Pass([string] $name, [string] $detail) {
    $script:checks.Add((New-Check $name "PASS" $detail))
}

function Add-Fail([string] $name, [string] $detail) {
    $script:checks.Add((New-Check $name "FAIL" $detail))
    $script:apiSmokePassed = $false
}

try {
    $health = Invoke-Json "GET" "$ApiBase/health"
    Add-Pass "backend-health" "GET /health returned $($health.data.status)."
}
catch {
    Add-Fail "backend-health" $_.Exception.Message
}

try {
    $storage = Invoke-Json "GET" "$ApiBase/storage/health"
    Add-Pass "storage-health" "GET /storage/health returned $($storage.data.status)."
}
catch {
    Add-Fail "storage-health" $_.Exception.Message
}

try {
    $database = Invoke-Json "GET" "$ApiBase/database/health"
    Add-Pass "database-health" "GET /database/health returned $($database.data.status)."
}
catch {
    Add-Fail "database-health" $_.Exception.Message
}

if (-not $AdminPassword) {
    Add-Fail "admin-login" "Admin password is required for authenticated restore smoke checks."
}
else {
    try {
        $login = Invoke-Json "POST" "$ApiBase/auth/login" @{
            loginId = $AdminLoginId
            password = $AdminPassword
        }
        $token = $login.data.accessToken
        if (-not $token) {
            Add-Fail "admin-login" "Login response did not include accessToken."
        }
        else {
            Add-Pass "admin-login" "Admin login returned an access token."
        }
    }
    catch {
        Add-Fail "admin-login" $_.Exception.Message
    }
}

if ($token) {
    try {
        $backupStatus = Invoke-Json "GET" "$ApiBase/admin/backup/status" $null $token
        Add-Pass "backup-status" "GET /admin/backup/status returned $($backupStatus.data.status)."
    }
    catch {
        Add-Fail "backup-status" $_.Exception.Message
    }

    try {
        $buckets = Invoke-Json "GET" "$ApiBase/buckets" $null $token
        $bucketText = $buckets | ConvertTo-Json -Depth 20
        if ($ExpectedBucketName -and -not $bucketText.Contains($ExpectedBucketName)) {
            Add-Fail "bucket-list" "Expected bucket was not found: $ExpectedBucketName"
        }
        else {
            $detail = if ($ExpectedBucketName) { "Expected bucket found: $ExpectedBucketName" } else { "Bucket list returned successfully." }
            Add-Pass "bucket-list" $detail
        }
    }
    catch {
        Add-Fail "bucket-list" $_.Exception.Message
    }

    if ($ExpectedBucketName -and $ExpectedObjectKey) {
        try {
            $bucketPath = Encode-PathSegment $ExpectedBucketName
            $objectPath = Encode-ObjectKey $ExpectedObjectKey
            $headers = @{ Authorization = "Bearer $token" }
            $download = Invoke-WebRequest -Method GET -Uri "$ApiBase/buckets/$bucketPath/objects/$objectPath" -Headers $headers
            if ($download.StatusCode -ge 200 -and $download.StatusCode -lt 300) {
                Add-Pass "object-download" "Expected object downloaded: $ExpectedBucketName/$ExpectedObjectKey"
            }
            else {
                Add-Fail "object-download" "Unexpected status code: $($download.StatusCode)"
            }
        }
        catch {
            Add-Fail "object-download" $_.Exception.Message
        }
    }
}

$s3ClientSmoke = [ordered]@{
    requested = [bool] $RunS3ClientSmoke
    status = "SKIPPED"
    client = $S3Client
    requireClient = [bool] $RequireS3Client
}

if ($RunS3ClientSmoke) {
    if (-not $AdminPassword) {
        $s3ClientSmoke.status = "FAILED"
        $s3ClientSmoke.detail = "Admin password is required to run S3 client smoke."
    }
    else {
        $smokeArgs = @(
            "-ApiBase", $ApiBase,
            "-AdminLoginId", $AdminLoginId,
            "-AdminPassword", $AdminPassword,
            "-Client", $S3Client
        )
        if ($S3Endpoint) {
            $smokeArgs += @("-S3Endpoint", $S3Endpoint)
        }
        if ($RequireS3Client) {
            $smokeArgs += "-RequireClient"
        }
        try {
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "verify-s3-client-smoke.ps1") @smokeArgs
            if ($LASTEXITCODE -ne 0) {
                throw "verify-s3-client-smoke.ps1 exited with code $LASTEXITCODE."
            }
            $s3ClientSmoke.status = "PASS"
            $s3ClientSmoke.detail = "S3 client smoke passed against the restored target."
        }
        catch {
            $s3ClientSmoke.status = "FAILED"
            $s3ClientSmoke.detail = $_.Exception.Message
        }
    }
}

$result = if ($apiSmokePassed -and ((-not $RunS3ClientSmoke) -or $s3ClientSmoke.status -eq "PASS")) { "passed" } else { "failed" }
$resolvedOutputPath = Resolve-ProjectPath $OutputPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null

$report = [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    result = $result
    apiBase = $ApiBase
    expectedBucketName = $ExpectedBucketName
    expectedObjectKey = $ExpectedObjectKey
    apiSmokePassed = [bool] $apiSmokePassed
    s3ClientSmoke = $s3ClientSmoke
    checks = @($checks)
    secretPolicy = "Secret values are not written to restore smoke evidence."
}

$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host "Kubernetes restore smoke evidence written."
Write-Host "Report: $resolvedOutputPath"
Write-Host "Result: $result"
if ($result -ne "passed") {
    throw "Kubernetes restore smoke failed."
}
