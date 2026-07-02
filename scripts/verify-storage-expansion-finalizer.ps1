param(
    [string] $OutputDirectory = ".\.osmu-run\storage-expansion-finalizer-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Label) {
    if (-not $Text.Contains($Expected)) {
        throw "$Label missing expected text: $Expected"
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$adminInfoPath = Join-Path $resolvedOutputDirectory "minio-admin-info.json"
$reportPath = Join-Path $resolvedOutputDirectory "latest-storage-expansion-finalize.json"
$summaryPath = Join-Path $resolvedOutputDirectory "latest-storage-expansion-finalize.md"
$telemetryJsonPath = Join-Path $resolvedOutputDirectory "latest-storage-backend-telemetry.json"
$telemetryMarkdownPath = Join-Path $resolvedOutputDirectory "latest-storage-backend-telemetry.md"

@"
{
  "servers": [
    {
      "endpoint": "minio-0.osmu-minio-hl.osmu.svc.cluster.local",
      "poolNumber": 0,
      "state": "online",
      "drives": [
        {
          "path": "/export1",
          "state": "online",
          "totalSpace": 4096,
          "usedSpace": 1024,
          "availableSpace": 3072
        },
        {
          "path": "/export2",
          "state": "online",
          "totalSpace": 4096,
          "usedSpace": 1024,
          "availableSpace": 3072
        }
      ]
    },
    {
      "endpoint": "minio-1.osmu-minio-hl.osmu.svc.cluster.local",
      "poolNumber": 0,
      "state": "online",
      "drives": [
        {
          "path": "/export1",
          "state": "online",
          "totalSpace": 4096,
          "usedSpace": 512,
          "availableSpace": 3584
        },
        {
          "path": "/export2",
          "state": "online",
          "totalSpace": 4096,
          "usedSpace": 512,
          "availableSpace": 3584
        }
      ]
    }
  ]
}
"@ | Set-Content -Encoding UTF8 -LiteralPath $adminInfoPath

$planOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-ProjectPath ".\scripts\finalize-storage-expansion.ps1") `
    -PlanOnly `
    -RunStorageBackendTelemetryEvidence `
    -StorageBackendTelemetryAdminInfoJsonPath $adminInfoPath `
    -StorageBackendTelemetryEnvironmentName "pilot-prod" `
    -StorageBackendTelemetryTargetCluster "customer-cluster-a" `
    -StorageBackendTelemetryOperator "ops-admin" `
    -StorageBackendTelemetryMinioAlias "osmu-minio" `
    -StorageBackendTelemetryEvidenceRef "change-123" 2>&1

$planText = ($planOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
Assert-Contains $planText "[STEP] Storage backend telemetry evidence" "Storage expansion finalizer plan"
Assert-Contains $planText "write-storage-backend-telemetry-evidence.ps1" "Storage expansion finalizer plan"
Assert-Contains $planText "-AdminInfoJsonPath" "Storage expansion finalizer plan"

$missingInputFailed = $false
try {
    & (Resolve-ProjectPath ".\scripts\finalize-storage-expansion.ps1") `
        -SkipRbacAuth `
        -SkipServerDryRun `
        -RunStorageBackendTelemetryEvidence `
        -NoReport | Out-Null
}
catch {
    if ($_.Exception.Message.Contains("requires -StorageBackendTelemetryAdminInfoJsonPath or -StorageBackendTelemetryExecute")) {
        $missingInputFailed = $true
    }
    else {
        throw
    }
}
Assert-True $missingInputFailed "Telemetry evidence missing-input guard did not fail."

& powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-ProjectPath ".\scripts\finalize-storage-expansion.ps1") `
    -SkipRbacAuth `
    -SkipServerDryRun `
    -RunStorageBackendTelemetryEvidence `
    -StorageBackendTelemetryAdminInfoJsonPath $adminInfoPath `
    -StorageBackendTelemetryEnvironmentName "pilot-prod" `
    -StorageBackendTelemetryTargetCluster "customer-cluster-a" `
    -StorageBackendTelemetryOperator "ops-admin" `
    -StorageBackendTelemetryMinioAlias "osmu-minio" `
    -StorageBackendTelemetryEvidenceRef "change-123" `
    -ReportPath $reportPath `
    -SummaryPath $summaryPath `
    -StorageBackendTelemetryJsonOutputPath $telemetryJsonPath `
    -StorageBackendTelemetryMarkdownOutputPath $telemetryMarkdownPath | Out-Null

Assert-True (Test-Path -LiteralPath $reportPath) "Storage expansion finalizer report missing."
Assert-True (Test-Path -LiteralPath $summaryPath) "Storage expansion finalizer summary missing."
Assert-True (Test-Path -LiteralPath $telemetryJsonPath) "Storage backend telemetry JSON missing."
Assert-True (Test-Path -LiteralPath $telemetryMarkdownPath) "Storage backend telemetry markdown missing."

$report = Read-Utf8Text $reportPath | ConvertFrom-Json
$telemetry = Read-Utf8Text $telemetryJsonPath | ConvertFrom-Json
$summaryText = Read-Utf8Text $summaryPath

Assert-True ($report.formatVersion -eq "osmu.storage-expansion-finalize.v1") "Expected storage expansion finalizer formatVersion."
Assert-True ($report.result -eq "passed") "Expected finalizer result=passed."
Assert-True ($report.storageBackendTelemetry.runEvidence -eq $true) "Expected telemetry runEvidence=true."
Assert-True ($report.storageBackendTelemetry.jsonOutputPath -eq $telemetryJsonPath) "Expected telemetry JSON path in finalizer report."
Assert-True ($report.evidence.storageBackendTelemetry -eq $telemetryJsonPath) "Expected telemetry evidence path in finalizer evidence block."
Assert-True (@($report.steps | Where-Object { $_.name -eq "Storage backend telemetry evidence" -and $_.result -eq "passed" }).Count -eq 1) "Expected passed telemetry step."
Assert-True ($telemetry.result -eq "passed") "Expected telemetry evidence result=passed."
Assert-True ($telemetry.source.rawAdminInfoStored -eq $false) "Expected raw admin info omitted."
Assert-True ($telemetry.summary.totalBytes -eq 16384) "Expected telemetry total bytes from fixture."
Assert-Contains $summaryText "Storage backend telemetry evidence: True" "Storage expansion finalizer summary"
Assert-Contains $summaryText "[passed] Storage backend telemetry evidence" "Storage expansion finalizer summary"

Write-Host "Storage expansion finalizer verified."
