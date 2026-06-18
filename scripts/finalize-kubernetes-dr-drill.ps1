param(
    [string] $SourceNamespace = "osmu",
    [string] $RestoreNamespace = "osmu-restore-drill",
    [string] $KubectlPath = "kubectl",
    [string] $RunId = "",
    [string] $BackupTimestamp = "YYYYMMDDTHHMMSSZ",
    [int] $TimeoutSeconds = 900,
    [string] $PowerShellCommand = "",
    [string] $DrDrillEvidencePath = ".\.osmu-run\latest-kubernetes-dr-drill.json",
    [string] $RestoreSmokeEvidencePath = ".\.osmu-run\latest-kubernetes-restore-smoke.json",
    [string] $DrEvidenceRequestPath = ".\.osmu-run\latest-kubernetes-dr-evidence-request.json",
    [string] $ReportPath = ".\.osmu-run\latest-kubernetes-dr-finalize.json",
    [string] $SummaryPath = ".\.osmu-run\latest-kubernetes-dr-finalize.md",
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
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "",
    [string] $ExpectedBucketName = "",
    [string] $ExpectedObjectKey = "",
    [string] $S3Endpoint = "",
    [ValidateSet("auto", "aws", "boto3", "aws-js", "mc", "docker-mc", "all")]
    [string] $S3Client = "auto",
    [string] $Environment = "kubernetes-drill",
    [string] $Operator = "",
    [ValidateSet("AUTO", "SUCCESS", "FAILED", "PARTIAL")]
    [string] $Result = "AUTO",
    [long] $MetadataRowCount = -1,
    [long] $ObjectCount = -1,
    [long] $ObjectBytes = -1,
    [string] $EvidenceUri = "",
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
    [switch] $RunS3ClientSmoke,
    [switch] $RequireS3Client,
    [switch] $SkipRestoreSmoke,
    [switch] $SkipEvidenceRequest,
    [switch] $PostRestoreSmokeVerified,
    [switch] $SubmitEvidence,
    [switch] $PlanOnly,
    [switch] $NoReport
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$steps = @()
$failureCount = 0
$startedAt = [DateTimeOffset]::UtcNow

if (-not $RunId) {
    $RunId = [DateTimeOffset]::UtcNow.ToString("yyyyMMddHHmmss")
}

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Format-Value([string] $value) {
    if ($null -eq $value) {
        return ""
    }
    if ($value -match "\s") {
        return '"' + ($value -replace '"', '\"') + '"'
    }
    return $value
}

function Get-PowerShellExecutable() {
    if (-not [string]::IsNullOrWhiteSpace($PowerShellCommand)) {
        return $PowerShellCommand
    }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        return "powershell"
    }
    return "pwsh"
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

function Mask-Arguments([string[]] $Arguments) {
    $masked = @()
    $maskNext = $false
    foreach ($argument in $Arguments) {
        if ($maskNext) {
            $masked += "<secret>"
            $maskNext = $false
            continue
        }
        $masked += $argument
        if ($argument -in @("-AdminPassword")) {
            $maskNext = $true
        }
    }
    return $masked
}

function Format-ProjectScriptCommand([string] $ScriptPath, [string[]] $Arguments) {
    $maskedArguments = Mask-Arguments $Arguments
    $parts = @(
        (Get-PowerShellExecutable),
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Format-Value $ScriptPath)
    )
    foreach ($argument in $maskedArguments) {
        $parts += Format-Value $argument
    }
    return ($parts -join " ").Trim()
}

function New-CommandEntry([string] $Name, [string] $ScriptPath, [string[]] $Arguments) {
    return [ordered]@{
        name = $Name
        script = $ScriptPath
        arguments = (Mask-Arguments $Arguments)
        command = Format-ProjectScriptCommand $ScriptPath $Arguments
    }
}

function Add-StepResult(
    [string] $Name,
    [string] $ScriptPath,
    [string[]] $Arguments,
    [string] $Result,
    [int] $ExitCode = 0,
    [string] $Output = "",
    [string] $Notes = ""
) {
    $script:steps += [ordered]@{
        name = $Name
        script = $ScriptPath
        arguments = (Mask-Arguments $Arguments)
        command = Format-ProjectScriptCommand $ScriptPath $Arguments
        result = $Result
        exitCode = $ExitCode
        output = Limit-Text $Output
        notes = $Notes
    }
    if ($Result -eq "failed") {
        $script:failureCount += 1
    }
}

function Invoke-ProjectScript([string] $Name, [string] $ScriptPath, [string[]] $Arguments) {
    $resolvedScript = Resolve-ProjectPath $ScriptPath
    $command = Format-ProjectScriptCommand $ScriptPath $Arguments
    Write-Host "    $command"
    $outputLines = & (Get-PowerShellExecutable) -NoProfile -ExecutionPolicy Bypass -File $resolvedScript @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output = ($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($output) {
        Write-Host $output
    }
    if ($exitCode -ne 0) {
        Add-StepResult $Name $ScriptPath $Arguments "failed" $exitCode $output ""
        throw "$Name failed with exit code $exitCode."
    }
    Add-StepResult $Name $ScriptPath $Arguments "passed" $exitCode $output ""
}

function Read-JsonFile([string] $Path, [string] $Label) {
    $resolved = Resolve-ProjectPath $Path
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "$Label not found: $resolved"
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $resolved | ConvertFrom-Json
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
    if ($PlanOnly) {
        return
    }
    if ($BackupTimestamp -eq "YYYYMMDDTHHMMSSZ") {
        throw "Set -BackupTimestamp to a real backup timestamp such as 20260615T010203Z."
    }
    if ($BackupTimestamp -notmatch "^\d{8}T\d{6}Z$") {
        throw "BackupTimestamp must match YYYYMMDDTHHMMSSZ, for example 20260615T010203Z."
    }
    if ($ServerDryRunOnly -and $ConfirmRestore) {
        throw "Use either -ServerDryRunOnly or -ConfirmRestore, not both."
    }
    if ((-not $ServerDryRunOnly) -and (-not $ConfirmRestore)) {
        throw "Choose -PlanOnly, -ServerDryRunOnly, or -ConfirmRestore."
    }
    if ((-not $ServerDryRunOnly) -and (-not $SkipRestoreSmoke) -and (-not $AdminPassword)) {
        throw "Restore smoke requires -AdminPassword unless -SkipRestoreSmoke is set."
    }
    if ($SubmitEvidence -and $SkipEvidenceRequest) {
        throw "Use either -SubmitEvidence or -SkipEvidenceRequest, not both."
    }
    if ($SubmitEvidence -and $ServerDryRunOnly) {
        throw "-SubmitEvidence cannot be used with -ServerDryRunOnly."
    }
    if ($SubmitEvidence -and (-not $AdminPassword)) {
        throw "-SubmitEvidence requires -AdminPassword."
    }
}

function New-DrDrillArguments([bool] $ForPlan) {
    $arguments = @(
        "-SourceNamespace", $SourceNamespace,
        "-RestoreNamespace", $RestoreNamespace,
        "-KubectlPath", $KubectlPath,
        "-RunId", $RunId,
        "-BackupTimestamp", $BackupTimestamp,
        "-TimeoutSeconds", "$TimeoutSeconds",
        "-EvidencePath", $DrDrillEvidencePath,
        "-DrSecretName", $DrSecretName,
        "-RemotePrefix", $RemotePrefix,
        "-DrEgressPort", "$DrEgressPort",
        "-DrBucketRequiredRetentionMode", $DrBucketRequiredRetentionMode,
        "-DrBucketRegion", $DrBucketRegion,
        "-DrBucketBootstrapRetentionMode", $DrBucketBootstrapRetentionMode,
        "-DrBucketBootstrapRetentionDuration", $DrBucketBootstrapRetentionDuration,
        "-TransferActiveDeadlineSeconds", "$TransferActiveDeadlineSeconds",
        "-TransferTtlSecondsAfterFinished", "$TransferTtlSecondsAfterFinished",
        "-TransferCpuRequest", $TransferCpuRequest,
        "-TransferMemoryRequest", $TransferMemoryRequest,
        "-TransferCpuLimit", $TransferCpuLimit,
        "-TransferMemoryLimit", $TransferMemoryLimit
    )
    if ($DrEgressCidr) {
        $arguments += @("-DrEgressCidr", $DrEgressCidr)
    }
    if ($RunBackupDrill) {
        $arguments += "-RunBackupDrill"
    }
    if ($BootstrapDrBucket) {
        $arguments += "-BootstrapDrBucket"
    }
    if ($SkipDrBucketCreate) {
        $arguments += "-SkipDrBucketCreate"
    }
    if ($VerifyDrBucketImmutability) {
        $arguments += "-VerifyDrBucketImmutability"
    }
    if ($TransferArtifacts) {
        $arguments += "-TransferArtifacts"
    }
    if ($IncludeAppWorkloads) {
        $arguments += "-IncludeAppWorkloads"
    }
    if ($AllowEmptyMinio) {
        $arguments += "-AllowEmptyMinio"
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
    else {
        $arguments += "-ConfirmRestore"
    }
    return $arguments
}

function New-RestoreSmokeArguments([bool] $ForPlan) {
    $arguments = @(
        "-ApiBase", $ApiBase,
        "-AdminLoginId", $AdminLoginId,
        "-OutputPath", $RestoreSmokeEvidencePath,
        "-S3Client", $S3Client
    )
    if ($AdminPassword) {
        $arguments += @("-AdminPassword", $AdminPassword)
    }
    if ($ExpectedBucketName) {
        $arguments += @("-ExpectedBucketName", $ExpectedBucketName)
    }
    if ($ExpectedObjectKey) {
        $arguments += @("-ExpectedObjectKey", $ExpectedObjectKey)
    }
    if ($S3Endpoint) {
        $arguments += @("-S3Endpoint", $S3Endpoint)
    }
    if ($RunS3ClientSmoke) {
        $arguments += "-RunS3ClientSmoke"
    }
    if ($RequireS3Client) {
        $arguments += "-RequireS3Client"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    return $arguments
}

function New-EvidenceRequestArguments([bool] $ForPlan) {
    $arguments = @(
        "-DrEvidencePath", $DrDrillEvidencePath,
        "-SmokeEvidencePath", $RestoreSmokeEvidencePath,
        "-OutputPath", $DrEvidenceRequestPath,
        "-Environment", $Environment,
        "-Result", $Result,
        "-MetadataRowCount", "$MetadataRowCount"
    )
    if ($Operator) {
        $arguments += @("-Operator", $Operator)
    }
    if ($ObjectCount -ge 0) {
        $arguments += @("-ObjectCount", "$ObjectCount")
    }
    if ($ObjectBytes -ge 0) {
        $arguments += @("-ObjectBytes", "$ObjectBytes")
    }
    if ($EvidenceUri) {
        $arguments += @("-EvidenceUri", $EvidenceUri)
    }
    if ($ConfirmRestore) {
        $arguments += "-ConfirmSuccessfulRestore"
    }
    if ($PostRestoreSmokeVerified) {
        $arguments += "-PostRestoreSmokeVerified"
    }
    if ($SubmitEvidence) {
        $arguments += @("-Submit", "-ApiBase", $ApiBase, "-AdminLoginId", $AdminLoginId)
        if ($AdminPassword) {
            $arguments += @("-AdminPassword", $AdminPassword)
        }
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    return $arguments
}

function Get-Commands([bool] $ForPlan) {
    $commands = @()
    $commands += New-CommandEntry "Kubernetes DR drill wrapper" ".\scripts\run-kubernetes-dr-drill.ps1" (New-DrDrillArguments $ForPlan)

    $shouldRunSmoke = (-not $SkipRestoreSmoke) -and (-not $ServerDryRunOnly)
    $shouldWriteEvidenceRequest = (-not $SkipEvidenceRequest) -and (-not $ServerDryRunOnly)

    if ($shouldRunSmoke -or $ForPlan) {
        $commands += New-CommandEntry "Kubernetes restore smoke" ".\scripts\verify-kubernetes-restore-smoke.ps1" (New-RestoreSmokeArguments $ForPlan)
    }
    if ($shouldWriteEvidenceRequest -or $ForPlan) {
        $commands += New-CommandEntry "Kubernetes DR evidence request" ".\scripts\write-kubernetes-dr-evidence-request.ps1" (New-EvidenceRequestArguments $ForPlan)
    }
    return $commands
}

function Write-FinalizeReport([string] $ResultValue, [string] $Status, [object[]] $Commands, [string[]] $Gaps) {
    $resolvedReportPath = Resolve-ProjectPath $ReportPath
    $resolvedSummaryPath = Resolve-ProjectPath $SummaryPath
    $completedAt = [DateTimeOffset]::UtcNow

    $report = [ordered]@{
        formatVersion = "osmu.kubernetes-dr-finalize.v1"
        generatedAt = $completedAt.ToString("o")
        startedAt = $startedAt.ToString("o")
        completedAt = $completedAt.ToString("o")
        result = $ResultValue
        status = $Status
        sourceNamespace = $SourceNamespace
        restoreNamespace = $RestoreNamespace
        runId = $RunId
        backupTimestamp = $BackupTimestamp
        powerShellCommand = Get-PowerShellExecutable
        serverDryRunOnly = [bool] $ServerDryRunOnly
        confirmRestore = [bool] $ConfirmRestore
        runBackupDrill = [bool] $RunBackupDrill
        bootstrapDrBucket = [bool] $BootstrapDrBucket
        verifyDrBucketImmutability = [bool] $VerifyDrBucketImmutability
        transferArtifacts = [bool] $TransferArtifacts
        runRestoreSmoke = [bool]((-not $SkipRestoreSmoke) -and (-not $ServerDryRunOnly))
        writeEvidenceRequest = [bool]((-not $SkipEvidenceRequest) -and (-not $ServerDryRunOnly))
        submitEvidence = [bool] $SubmitEvidence
        apiBase = $ApiBase
        adminLoginId = $AdminLoginId
        adminPasswordProvided = [bool] $AdminPassword
        expectedBucketName = $ExpectedBucketName
        expectedObjectKey = $ExpectedObjectKey
        runS3ClientSmoke = [bool] $RunS3ClientSmoke
        requireS3Client = [bool] $RequireS3Client
        paths = [ordered]@{
            drDrillEvidence = Resolve-ProjectPath $DrDrillEvidencePath
            restoreSmokeEvidence = Resolve-ProjectPath $RestoreSmokeEvidencePath
            drEvidenceRequest = Resolve-ProjectPath $DrEvidenceRequestPath
            report = $resolvedReportPath
            summary = $resolvedSummaryPath
        }
        commands = $Commands
        steps = $steps
        gaps = $Gaps
        secretPolicy = "Admin password and DR secret values are not written to this finalize report; displayed commands mask -AdminPassword."
    }

    $summaryLines = @(
        "# OSMU Kubernetes DR Finalize",
        "",
        "Generated at: $($report.generatedAt)",
        "Result: $ResultValue",
        "Status: $Status",
        "Source namespace: $SourceNamespace",
        "Restore namespace: $RestoreNamespace",
        "Backup timestamp: $BackupTimestamp",
        "",
        "## Artifact Paths",
        "",
        "- DR drill evidence: $($report.paths.drDrillEvidence)",
        "- Restore smoke evidence: $($report.paths.restoreSmokeEvidence)",
        "- DR evidence request: $($report.paths.drEvidenceRequest)",
        "- Finalize report: $($report.paths.report)",
        "",
        "## Commands",
        ""
    )
    foreach ($command in $Commands) {
        $summaryLines += "- $($command.name): ``$($command.command)``"
    }
    if ($Gaps.Count -gt 0) {
        $summaryLines += ""
        $summaryLines += "## Gaps"
        $summaryLines += ""
        foreach ($gap in $Gaps) {
            $summaryLines += "- $gap"
        }
    }

    if (-not $NoReport) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedSummaryPath) | Out-Null
        $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
        ($summaryLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedSummaryPath -Encoding UTF8
        Write-Host "Kubernetes DR finalize report: $resolvedReportPath"
        Write-Host "Kubernetes DR finalize summary: $resolvedSummaryPath"
    }

    Step "Kubernetes DR finalize summary"
    Write-Host ($summaryLines -join [Environment]::NewLine)
}

Assert-InputsAreSafe
$commands = @(Get-Commands $PlanOnly)

if ($PlanOnly) {
    Step "Kubernetes DR finalize plan"
    foreach ($command in $commands) {
        Write-Host "- $($command.name): $($command.command)"
    }
    Write-FinalizeReport "planned" "kubernetes-dr-finalize-plan" $commands @("Plan only; no Kubernetes resources, HTTP smoke, evidence request, or API submit was executed.")
    return
}

$gaps = @()
try {
    Step "Kubernetes DR drill wrapper"
    Invoke-ProjectScript "Kubernetes DR drill wrapper" ".\scripts\run-kubernetes-dr-drill.ps1" (New-DrDrillArguments $false)

    if ((-not $SkipRestoreSmoke) -and (-not $ServerDryRunOnly)) {
        Step "Kubernetes restore smoke"
        Invoke-ProjectScript "Kubernetes restore smoke" ".\scripts\verify-kubernetes-restore-smoke.ps1" (New-RestoreSmokeArguments $false)
    }
    else {
        Add-StepResult "Kubernetes restore smoke" ".\scripts\verify-kubernetes-restore-smoke.ps1" (New-RestoreSmokeArguments $true) "skipped" 0 "" "Skipped because -SkipRestoreSmoke or -ServerDryRunOnly was set."
        $gaps += "Restore smoke was skipped."
    }

    if ((-not $SkipEvidenceRequest) -and (-not $ServerDryRunOnly)) {
        Step "Kubernetes DR evidence request"
        Invoke-ProjectScript "Kubernetes DR evidence request" ".\scripts\write-kubernetes-dr-evidence-request.ps1" (New-EvidenceRequestArguments $false)
        $evidenceRequest = Read-JsonFile $DrEvidenceRequestPath "Kubernetes DR evidence request"
        if ("$($evidenceRequest.result)" -ne "SUCCESS") {
            $gaps += "DR evidence request result was $($evidenceRequest.result), not SUCCESS."
        }
    }
    else {
        Add-StepResult "Kubernetes DR evidence request" ".\scripts\write-kubernetes-dr-evidence-request.ps1" (New-EvidenceRequestArguments $true) "skipped" 0 "" "Skipped because -SkipEvidenceRequest or -ServerDryRunOnly was set."
        $gaps += "DR evidence request generation was skipped."
    }

    if ($ServerDryRunOnly) {
        $gaps += "Server-side dry-run only; no restore was executed."
    }
    if (-not $ConfirmRestore) {
        $gaps += "Restore was not confirmed."
    }

    $result = if ($failureCount -eq 0 -and $gaps.Count -eq 0) { "ready" } else { "partial" }
    $status = if ($result -eq "ready") { "kubernetes-dr-finalize-verified" } else { "kubernetes-dr-finalize-partial" }
    Write-FinalizeReport $result $status $commands $gaps
}
catch {
    $gaps += $_.Exception.Message
    Write-FinalizeReport "failed" "kubernetes-dr-finalize-failed" $commands $gaps
    throw
}
