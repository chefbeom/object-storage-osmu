param(
    [string] $SourceNamespace = "osmu",
    [string] $RestoreNamespace = "osmu-restore-drill",
    [string] $KubectlPath = "kubectl",
    [string] $RunId = "",
    [string] $BackupTimestamp = "YYYYMMDDTHHMMSSZ",
    [int] $TimeoutSeconds = 900,
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-dr-drill.json",
    [string] $DrSecretName = "osmu-dr-transfer-secret",
    [string] $RemotePrefix = "osmu",
    [string] $DrEgressCidr = "",
    [int] $DrEgressPort = 443,
    [ValidateSet("GOVERNANCE_OR_COMPLIANCE", "COMPLIANCE")]
    [string] $DrBucketRequiredRetentionMode = "GOVERNANCE_OR_COMPLIANCE",
    [string] $DrBucketRegion = "us-east-1",
    [ValidateSet("GOVERNANCE", "COMPLIANCE")]
    [string] $DrBucketBootstrapRetentionMode = "GOVERNANCE",
    [string] $DrBucketBootstrapRetentionDuration = "30d",
    [int] $TransferActiveDeadlineSeconds = 960,
    [int] $TransferTtlSecondsAfterFinished = 3600,
    [string] $TransferCpuRequest = "100m",
    [string] $TransferMemoryRequest = "256Mi",
    [string] $TransferCpuLimit = "500m",
    [string] $TransferMemoryLimit = "512Mi",
    [switch] $RunBackupDrill,
    [switch] $BootstrapDrBucket,
    [switch] $SkipDrBucketCreate,
    [switch] $VerifyDrBucketImmutability,
    [switch] $TransferArtifacts,
    [switch] $IncludeAppWorkloads,
    [switch] $AllowEmptyMinio,
    [switch] $ServerDryRunOnly,
    [switch] $ConfirmRestore,
    [switch] $CleanupJobs,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$stepResults = @()
$failureCount = 0
$drillStartedAt = [DateTimeOffset]::UtcNow

if (-not $RunId) {
    $RunId = [DateTimeOffset]::UtcNow.ToString("yyyyMMddHHmmss")
}

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Limit-Text([string] $text) {
    if ($null -eq $text) {
        return ""
    }
    if ($text.Length -le 8000) {
        return $text
    }
    return $text.Substring(0, 8000) + "`n...truncated..."
}

function Format-Value([string] $value) {
    if ($value -match "\s") {
        return '"' + ($value -replace '"', '\"') + '"'
    }
    return $value
}

function Format-ProjectScriptCommand([string] $ScriptPath, [string[]] $Arguments) {
    $parts = @(
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Format-Value $ScriptPath)
    )
    foreach ($argument in $Arguments) {
        $parts += Format-Value $argument
    }
    return $parts -join " "
}

function Assert-KubernetesQuantity([string] $Name, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name must not be empty."
    }
    if ($Value -notmatch "^\d+(\.\d+)?(m|Ki|Mi|Gi|Ti|Pi|Ei|K|M|G|T|P|E)?$") {
        throw "$Name must be a Kubernetes quantity such as 100m, 1, 256Mi, or 1Gi."
    }
}

function Assert-InputsAreSafe() {
    Assert-KubernetesQuantity "TransferCpuRequest" $TransferCpuRequest
    Assert-KubernetesQuantity "TransferMemoryRequest" $TransferMemoryRequest
    Assert-KubernetesQuantity "TransferCpuLimit" $TransferCpuLimit
    Assert-KubernetesQuantity "TransferMemoryLimit" $TransferMemoryLimit
    if ($TransferActiveDeadlineSeconds -le 0) {
        throw "TransferActiveDeadlineSeconds must be greater than zero."
    }
    if ($TransferTtlSecondsAfterFinished -lt 0) {
        throw "TransferTtlSecondsAfterFinished must be zero or greater."
    }
    if ($DrBucketBootstrapRetentionDuration -notmatch "^\d+(d|y)$") {
        throw "DrBucketBootstrapRetentionDuration must use MinIO validity format such as 30d or 1y."
    }
    if ($DrBucketRegion -notmatch "^[A-Za-z0-9][A-Za-z0-9-]{0,62}$") {
        throw "DrBucketRegion must be a simple S3 region identifier such as us-east-1."
    }
    if ($PlanOnly) {
        return
    }
    if ($SourceNamespace -eq $RestoreNamespace) {
        throw "RestoreNamespace must differ from SourceNamespace. Use a disposable namespace such as osmu-restore-drill."
    }
    if ($ServerDryRunOnly -and $ConfirmRestore) {
        throw "Use either -ServerDryRunOnly or -ConfirmRestore, not both."
    }
    if ((-not $ServerDryRunOnly) -and (-not $ConfirmRestore)) {
        throw "Choose -PlanOnly, -ServerDryRunOnly, or -ConfirmRestore."
    }
    if ($ServerDryRunOnly -and $RunBackupDrill) {
        throw "-RunBackupDrill creates live backup Jobs and cannot be combined with -ServerDryRunOnly."
    }
    if ($BackupTimestamp -eq "YYYYMMDDTHHMMSSZ") {
        throw "Set -BackupTimestamp to a real backup timestamp such as 20260615T010203Z."
    }
    if ($BackupTimestamp -notmatch "^\d{8}T\d{6}Z$") {
        throw "BackupTimestamp must match YYYYMMDDTHHMMSSZ, for example 20260615T010203Z."
    }
}

function Add-StepResult(
    [string] $Name,
    [string] $ScriptPath,
    [string[]] $Arguments,
    [string] $Command,
    [string] $Result,
    [int] $ExitCode = 0,
    [string] $Output = "",
    [string] $Notes = ""
) {
    $script:stepResults += [pscustomobject]@{
        name = $Name
        script = $ScriptPath
        arguments = $Arguments
        command = $Command
        result = $Result
        exitCode = $ExitCode
        output = (Limit-Text $Output)
        notes = $Notes
    }
    if ($Result -eq "failed") {
        $script:failureCount += 1
    }
}

function New-Step([string] $Name, [string] $ScriptPath, [string[]] $Arguments) {
    return [pscustomobject]@{
        name = $Name
        scriptPath = $ScriptPath
        arguments = $Arguments
    }
}

function New-BackupDrillArguments([bool] $ForPlan) {
    $arguments = @("-Namespace", $SourceNamespace, "-KubectlPath", $KubectlPath, "-RunId", $RunId, "-TimeoutSeconds", "$TimeoutSeconds")
    if ($CleanupJobs) {
        $arguments += "-CleanupJobs"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    return $arguments
}

function New-RestoreNamespaceArguments([bool] $ForPlan) {
    $arguments = @(
        "-SourceNamespace", $SourceNamespace,
        "-RestoreNamespace", $RestoreNamespace,
        "-KubectlPath", $KubectlPath,
        "-RunId", $RunId,
        "-TimeoutSeconds", "$TimeoutSeconds"
    )
    if ($IncludeAppWorkloads) {
        $arguments += "-IncludeAppWorkloads"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    elseif ($ServerDryRunOnly) {
        $arguments += "-ServerDryRunOnly"
    }
    else {
        $arguments += "-Apply"
        $arguments += "-Wait"
    }
    return $arguments
}

function New-ArtifactPreflightArguments([bool] $ForPlan) {
    $arguments = @(
        "-RestoreNamespace", $RestoreNamespace,
        "-KubectlPath", $KubectlPath,
        "-RunId", $RunId,
        "-BackupTimestamp", $BackupTimestamp,
        "-TimeoutSeconds", "$TimeoutSeconds"
    )
    if ($AllowEmptyMinio) {
        $arguments += "-AllowEmptyMinio"
    }
    if ($CleanupJobs) {
        $arguments += "-CleanupJob"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    elseif ($ServerDryRunOnly) {
        $arguments += "-ServerDryRunOnly"
    }
    return $arguments
}

function New-TransferArtifactsArguments([bool] $ForPlan) {
    $arguments = @(
        "-Mode", "ExportImport",
        "-SourceNamespace", $SourceNamespace,
        "-RestoreNamespace", $RestoreNamespace,
        "-KubectlPath", $KubectlPath,
        "-RunId", $RunId,
        "-BackupTimestamp", $BackupTimestamp,
        "-TimeoutSeconds", "$TimeoutSeconds",
        "-DrSecretName", $DrSecretName,
        "-RemotePrefix", $RemotePrefix,
        "-DrEgressPort", "$DrEgressPort",
        "-ActiveDeadlineSeconds", "$TransferActiveDeadlineSeconds",
        "-TtlSecondsAfterFinished", "$TransferTtlSecondsAfterFinished",
        "-CpuRequest", $TransferCpuRequest,
        "-MemoryRequest", $TransferMemoryRequest,
        "-CpuLimit", $TransferCpuLimit,
        "-MemoryLimit", $TransferMemoryLimit
    )
    if ($DrEgressCidr) {
        $arguments += @("-DrEgressCidr", $DrEgressCidr)
    }
    if ($CleanupJobs) {
        $arguments += "-CleanupJobs"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    elseif ($ServerDryRunOnly) {
        $arguments += "-ServerDryRunOnly"
    }
    return $arguments
}

function New-DrBucketBootstrapArguments([bool] $ForPlan) {
    $arguments = @(
        "-Namespace", $SourceNamespace,
        "-KubectlPath", $KubectlPath,
        "-RunId", $RunId,
        "-DrSecretName", $DrSecretName,
        "-Region", $DrBucketRegion,
        "-RetentionMode", $DrBucketBootstrapRetentionMode,
        "-RetentionDuration", $DrBucketBootstrapRetentionDuration,
        "-DrEgressPort", "$DrEgressPort",
        "-TimeoutSeconds", "$TimeoutSeconds",
        "-ActiveDeadlineSeconds", "$TransferActiveDeadlineSeconds",
        "-TtlSecondsAfterFinished", "$TransferTtlSecondsAfterFinished",
        "-CpuRequest", $TransferCpuRequest,
        "-MemoryRequest", $TransferMemoryRequest,
        "-CpuLimit", $TransferCpuLimit,
        "-MemoryLimit", $TransferMemoryLimit
    )
    if ($DrEgressCidr) {
        $arguments += @("-DrEgressCidr", $DrEgressCidr)
    }
    if ($SkipDrBucketCreate) {
        $arguments += "-SkipBucketCreate"
    }
    if ($CleanupJobs) {
        $arguments += "-CleanupJob"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    elseif ($ServerDryRunOnly) {
        $arguments += "-ServerDryRunOnly"
    }
    return $arguments
}

function New-DrBucketImmutabilityArguments([bool] $ForPlan) {
    $arguments = @(
        "-Namespace", $SourceNamespace,
        "-KubectlPath", $KubectlPath,
        "-RunId", $RunId,
        "-DrSecretName", $DrSecretName,
        "-RequiredRetentionMode", $DrBucketRequiredRetentionMode,
        "-DrEgressPort", "$DrEgressPort",
        "-TimeoutSeconds", "$TimeoutSeconds",
        "-ActiveDeadlineSeconds", "$TransferActiveDeadlineSeconds",
        "-TtlSecondsAfterFinished", "$TransferTtlSecondsAfterFinished",
        "-CpuRequest", $TransferCpuRequest,
        "-MemoryRequest", $TransferMemoryRequest,
        "-CpuLimit", $TransferCpuLimit,
        "-MemoryLimit", $TransferMemoryLimit
    )
    if ($DrEgressCidr) {
        $arguments += @("-DrEgressCidr", $DrEgressCidr)
    }
    if ($CleanupJobs) {
        $arguments += "-CleanupJob"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    elseif ($ServerDryRunOnly) {
        $arguments += "-ServerDryRunOnly"
    }
    return $arguments
}

function New-RestoreDrillArguments([bool] $ForPlan) {
    $arguments = @(
        "-SourceNamespace", $SourceNamespace,
        "-RestoreNamespace", $RestoreNamespace,
        "-KubectlPath", $KubectlPath,
        "-RunId", $RunId,
        "-BackupTimestamp", $BackupTimestamp,
        "-TimeoutSeconds", "$TimeoutSeconds"
    )
    if ($CleanupJobs) {
        $arguments += "-CleanupJob"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    elseif ($ServerDryRunOnly) {
        $arguments += "-ServerDryRunOnly"
    }
    else {
        $arguments += "-ConfirmRestore"
    }
    return $arguments
}

function Get-DrillSteps([bool] $ForPlan) {
    $steps = @()
    if ($RunBackupDrill) {
        $steps += New-Step "source-backup-drill" ".\scripts\run-kubernetes-backup-drill.ps1" (New-BackupDrillArguments $ForPlan)
    }
    if ($BootstrapDrBucket) {
        $steps += New-Step "bootstrap-dr-bucket" ".\scripts\bootstrap-kubernetes-dr-bucket.ps1" (New-DrBucketBootstrapArguments $ForPlan)
    }
    $steps += New-Step "prepare-restore-namespace" ".\scripts\prepare-kubernetes-restore-namespace.ps1" (New-RestoreNamespaceArguments $ForPlan)
    if ($VerifyDrBucketImmutability) {
        $steps += New-Step "verify-dr-bucket-immutability" ".\scripts\verify-kubernetes-dr-bucket-immutability.ps1" (New-DrBucketImmutabilityArguments $ForPlan)
    }
    if ($TransferArtifacts) {
        $steps += New-Step "transfer-backup-artifacts" ".\scripts\transfer-kubernetes-backup-artifacts.ps1" (New-TransferArtifactsArguments $ForPlan)
    }
    $steps += New-Step "verify-backup-artifacts" ".\scripts\verify-kubernetes-backup-artifacts.ps1" (New-ArtifactPreflightArguments $ForPlan)
    $steps += New-Step "restore-drill" ".\scripts\run-kubernetes-restore-drill.ps1" (New-RestoreDrillArguments $ForPlan)
    return $steps
}

function Invoke-DrillStep([object] $Step) {
    $resolvedScript = Resolve-ProjectPath $Step.scriptPath
    $command = Format-ProjectScriptCommand $Step.scriptPath $Step.arguments
    $outputLines = & powershell -NoProfile -ExecutionPolicy Bypass -File $resolvedScript @($Step.arguments) 2>&1
    $exitCode = $LASTEXITCODE
    $output = ($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $result = if ($exitCode -eq 0) { "passed" } else { "failed" }
    Add-StepResult $Step.name $Step.scriptPath $Step.arguments $command $result $exitCode $output ""
    return $exitCode -eq 0
}

Assert-InputsAreSafe

if ($PlanOnly) {
    Write-Host "Kubernetes DR drill plan only."
    Write-Host "Source namespace: $SourceNamespace"
    Write-Host "Restore namespace: $RestoreNamespace"
    Write-Host "Run ID: $RunId"
    Write-Host "Backup timestamp: $BackupTimestamp"
    Write-Host "Run backup drill: $RunBackupDrill"
    Write-Host "Bootstrap DR bucket: $BootstrapDrBucket"
    Write-Host "Skip DR bucket create: $SkipDrBucketCreate"
    Write-Host "Verify DR bucket immutability: $VerifyDrBucketImmutability"
    Write-Host "Transfer artifacts: $TransferArtifacts"
    Write-Host "DR transfer secret: $DrSecretName"
    Write-Host "DR transfer remote prefix: $RemotePrefix"
    Write-Host "DR bucket bootstrap region: $DrBucketRegion"
    Write-Host "DR bucket bootstrap retention: mode=$DrBucketBootstrapRetentionMode duration=$DrBucketBootstrapRetentionDuration"
    Write-Host "DR bucket required retention mode: $DrBucketRequiredRetentionMode"
    Write-Host "DR transfer resources: requests cpu=$TransferCpuRequest memory=$TransferMemoryRequest, limits cpu=$TransferCpuLimit memory=$TransferMemoryLimit"
    Write-Host "DR transfer job deadline/TTL: activeDeadlineSeconds=$TransferActiveDeadlineSeconds ttlSecondsAfterFinished=$TransferTtlSecondsAfterFinished"
    Write-Host "Include app workloads: $IncludeAppWorkloads"
    Write-Host "Allow empty MinIO mirror: $AllowEmptyMinio"
    Write-Host "Cleanup jobs: $CleanupJobs"
    Write-Host "Plan sequence: backup drill optional -> DR bucket bootstrap optional -> restore namespace -> DR bucket immutability optional -> artifact transfer optional -> artifact preflight -> restore drill."
    foreach ($step in Get-DrillSteps $true) {
        Write-Host "[STEP] $($step.name): $(Format-ProjectScriptCommand $step.scriptPath $step.arguments)"
    }
    Write-Host "Plan only; no Kubernetes resources changed and no evidence file written."
    return
}

if (-not $RunBackupDrill) {
    Add-StepResult "source-backup-drill" "" @() "" "skipped" 0 "" "Skipped by default. Backup artifacts must already be copied or snapshotted into the restore namespace PVC."
}
if (-not $BootstrapDrBucket) {
    Add-StepResult "bootstrap-dr-bucket" "" @() "" "skipped" 0 "" "Skipped by default. Use -BootstrapDrBucket to create or configure the external DR bucket with object locking, versioning, and default retention before transfer."
}
if (-not $VerifyDrBucketImmutability) {
    Add-StepResult "verify-dr-bucket-immutability" "" @() "" "skipped" 0 "" "Skipped by default. Use -VerifyDrBucketImmutability to check external DR bucket versioning and default object-lock retention before transfer."
}
if (-not $TransferArtifacts) {
    Add-StepResult "transfer-backup-artifacts" "" @() "" "skipped" 0 "" "Skipped by default. Use -TransferArtifacts to export/import the selected timestamp through external S3-compatible DR storage."
}

foreach ($step in Get-DrillSteps $false) {
    $passed = Invoke-DrillStep $step
    if (-not $passed) {
        break
    }
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
}

$evidence = [pscustomobject]@{
    formatVersion = "osmu.kubernetes-dr-drill.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    startedAt = $drillStartedAt.ToString("o")
    completedAt = [DateTimeOffset]::UtcNow.ToString("o")
    sourceNamespace = $SourceNamespace
    restoreNamespace = $RestoreNamespace
    runId = $RunId
    backupTimestamp = $BackupTimestamp
    kubectlPath = $KubectlPath
    timeoutSeconds = $TimeoutSeconds
    runBackupDrill = [bool] $RunBackupDrill
    bootstrapDrBucket = [bool] $BootstrapDrBucket
    verifyDrBucketImmutability = [bool] $VerifyDrBucketImmutability
    transferArtifacts = [bool] $TransferArtifacts
    drSecretName = $DrSecretName
    remotePrefix = $RemotePrefix
    drBucketRegion = $DrBucketRegion
    drBucketBootstrapRetentionMode = $DrBucketBootstrapRetentionMode
    drBucketBootstrapRetentionDuration = $DrBucketBootstrapRetentionDuration
    skipDrBucketCreate = [bool] $SkipDrBucketCreate
    drBucketRequiredRetentionMode = $DrBucketRequiredRetentionMode
    transferJobPolicy = [pscustomobject]@{
        activeDeadlineSeconds = $TransferActiveDeadlineSeconds
        ttlSecondsAfterFinished = $TransferTtlSecondsAfterFinished
        resources = [pscustomobject]@{
            requests = [pscustomobject]@{
                cpu = $TransferCpuRequest
                memory = $TransferMemoryRequest
            }
            limits = [pscustomobject]@{
                cpu = $TransferCpuLimit
                memory = $TransferMemoryLimit
            }
        }
    }
    drEgressCidrConfigured = [bool] $DrEgressCidr
    includeAppWorkloads = [bool] $IncludeAppWorkloads
    allowEmptyMinio = [bool] $AllowEmptyMinio
    serverDryRunOnly = [bool] $ServerDryRunOnly
    confirmRestore = [bool] $ConfirmRestore
    cleanupJobs = [bool] $CleanupJobs
    result = if ($failureCount -eq 0) { "passed" } else { "failed" }
    failureCount = $failureCount
    secretPolicy = "Secret values are not copied into this DR drill evidence."
    drBucketBootstrapPolicy = if ($BootstrapDrBucket) { "This wrapper creates or reuses the external DR bucket with object locking, enables versioning, sets default object-lock retention, and verifies the result before restore-side checks." } else { "This wrapper did not bootstrap the external DR bucket. Run bootstrap-kubernetes-dr-bucket.ps1 before first production DR transfer." }
    drBucketPolicy = if ($VerifyDrBucketImmutability) { "This wrapper verifies the external DR bucket is reachable, has versioning enabled, and has the required default object-lock retention mode before transfer." } else { "This wrapper did not verify external DR bucket immutability. Use -VerifyDrBucketImmutability before production DR transfers." }
    artifactPolicy = if ($TransferArtifacts) { "This wrapper exports/imports the selected timestamp through external S3-compatible DR storage before artifact preflight." } else { "This wrapper did not copy backup artifacts. The restore namespace PVC must already contain the selected timestamp before artifact preflight." }
    steps = $stepResults
    childEvidencePaths = @{
        backupDrill = ".\.osmu-run\latest-kubernetes-backup-drill.json"
        drBucketBootstrap = ".\.osmu-run\latest-kubernetes-dr-bucket-bootstrap.json"
        restoreNamespace = ".\.osmu-run\latest-kubernetes-restore-namespace.json"
        drBucketImmutability = ".\.osmu-run\latest-kubernetes-dr-bucket-immutability.json"
        backupArtifactTransfer = ".\.osmu-run\latest-kubernetes-backup-artifact-transfer.json"
        backupArtifacts = ".\.osmu-run\latest-kubernetes-backup-artifacts.json"
        restoreDrill = ".\.osmu-run\latest-kubernetes-restore-drill.json"
    }
}

$evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

if ($failureCount -ne 0) {
    Write-Host "Kubernetes DR drill evidence written with failures: $resolvedEvidencePath"
    throw "Kubernetes DR drill failed: $failureCount failed checks."
}

Write-Host "Kubernetes DR drill completed."
Write-Host "Evidence: $resolvedEvidencePath"
