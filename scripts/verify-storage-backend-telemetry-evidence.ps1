param(
    [string] $OutputDirectory = ".\.osmu-run\storage-backend-telemetry-self-test"
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

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-NotContains([string] $text, [string] $unexpected, [string] $label) {
    if ($text.Contains($unexpected)) {
        throw "$label contains unexpected secret text: $unexpected"
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$fixturePath = Join-Path $resolvedOutputDirectory "minio-admin-info.json"
$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-storage-backend-telemetry.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-storage-backend-telemetry.md"
$scriptPath = Resolve-ProjectPath ".\scripts\write-storage-backend-telemetry-evidence.ps1"

$fixture = @'
{
  "status": "success",
  "info": {
    "mode": "online",
    "deploymentID": "self-test-deployment",
    "servers": [
      {
        "endpoint": "http://minio-pool-0-0.osmu-minio:9000",
        "state": "online",
        "poolNumber": 0,
        "drives": [
          {
            "path": "/data0",
            "state": "ok",
            "totalspace": 1099511627776,
            "usedspace": 274877906944,
            "availspace": 824633720832
          },
          {
            "path": "/data1",
            "state": "ok",
            "totalspace": 1099511627776,
            "usedspace": 137438953472,
            "availspace": 962072674304
          }
        ]
      },
      {
        "endpoint": "http://minio-pool-0-1.osmu-minio:9000",
        "state": "online",
        "poolNumber": 0,
        "drives": [
          {
            "path": "/data0",
            "state": "ok",
            "totalspace": 1099511627776,
            "usedspace": 343597383680,
            "availspace": 755914244096
          },
          {
            "path": "/data1",
            "state": "ok",
            "totalspace": 1099511627776,
            "usedspace": 171798691840,
            "availspace": 927712935936
          }
        ]
      }
    ]
  }
}
'@
$fixture | Set-Content -LiteralPath $fixturePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "ops-self-test" `
    -MinioAlias "osmu-target" `
    -EvidenceRef "mc-admin-info-run-20260621" `
    -AdminInfoJsonPath $fixturePath `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-storage-backend-telemetry-evidence.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Storage backend telemetry JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Storage backend telemetry markdown missing."

$reportText = Read-Utf8Text $jsonOutputPath
$markdown = Read-Utf8Text $markdownOutputPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)
$pools = @($report.pools)
$servers = @($report.servers)

Assert-True ($report.formatVersion -eq "osmu.storage-backend-telemetry.v1") "Unexpected storage telemetry formatVersion."
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.summary.poolCount -eq 1) "Expected one inferred pool."
Assert-True ($report.summary.serverCount -eq 2) "Expected two servers."
Assert-True ($report.summary.onlineServerCount -eq 2) "Expected two online servers."
Assert-True ($report.summary.driveCount -eq 4) "Expected four drives."
Assert-True ($report.summary.totalBytes -eq 4398046511104) "Unexpected total bytes."
Assert-True ($report.summary.usedBytes -eq 927712935936) "Unexpected used bytes."
Assert-True ($report.summary.freeBytes -eq 3470333575168) "Unexpected free bytes."
Assert-True ($report.source.rawAdminInfoStored -eq $false) "Expected raw admin info to be omitted."
Assert-True (-not [string]::IsNullOrWhiteSpace($report.source.adminInfoJsonSha256)) "Expected admin info SHA-256."
Assert-True ($pools.Count -eq 1) "Expected pool summary."
Assert-True ($servers.Count -eq 2) "Expected server summaries."
Assert-True (@($checks | Where-Object { $_.id -eq "server-health" -and $_.passed }).Count -eq 1) "Expected server-health check to pass."
Assert-True (@($checks | Where-Object { $_.id -eq "raw-admin-info-policy" -and $_.passed }).Count -eq 1) "Expected raw-admin-info-policy check to pass."

Assert-Contains $markdown "# OSMU Storage Backend Telemetry Evidence" "storage telemetry markdown"
Assert-Contains $markdown "Raw admin info stored: false" "storage telemetry markdown"
Assert-Contains $markdown "Pool 0" "storage telemetry markdown"
Assert-Contains $report.scopePolicy "not AWS S3 parity work" "storage telemetry JSON"
Assert-Contains $report.decisionRule "MinIO admin-info JSON parsing" "storage telemetry JSON"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----")) {
    Assert-NotContains $reportText $unexpected "storage telemetry JSON"
    Assert-NotContains $markdown $unexpected "storage telemetry markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -EvidenceRef "password=super-secret" `
        -AdminInfoJsonPath $fixturePath `
        -NoWrite 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Secret-like evidence reference should be rejected."
Assert-Contains ($invalidOutput | Out-String) "appears to contain secret material" "invalid secret-like reference output"

$unsafeFixturePath = Join-Path $resolvedOutputDirectory "unsafe-minio-admin-info.json"
'{"secretKey":"super-secret"}' | Set-Content -LiteralPath $unsafeFixturePath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -EvidenceRef "mc-admin-info-run-20260621" `
        -AdminInfoJsonPath $unsafeFixturePath `
        -NoWrite 2>&1
    $unsafeExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeExitCode -ne 0) "Secret-like admin info payload should be rejected."
Assert-Contains ($unsafeOutput | Out-String) "appears to contain secret material" "unsafe admin info output"

Write-Host "Storage backend telemetry evidence writer verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
exit 0
