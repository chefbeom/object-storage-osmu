param(
    [string] $Namespace = "osmu",
    [string] $TenantName = "osmu-minio",
    [string] $StorageExpansionManifestPath = ".\infra\k8s\examples\minio-tenant-pool-expansion.example.yaml",
    [string] $RestoreManifestPath = ".\infra\k8s\examples\restore-from-backup.example.yaml",
    [string] $SourceNamespace = "osmu",
    [string] $RestoreNamespace = "osmu-restore-drill",
    [string] $BackupTimestamp = "YYYYMMDDTHHMMSSZ",
    [string] $KubectlPath = "kubectl",
    [string] $PowerShellCommand = "",
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "",
    [long] $StorageExpansionRequestId = 0,
    [string] $ImageSigningEvidencePath = ".\.osmu-run\latest-image-signing-evidence.json",
    [string] $ContainerSecurityEvidencePath = ".\.osmu-run\latest-container-security-evidence.json",
    [string] $IamRbacFinalizeReportPath = ".\.osmu-run\latest-iam-rbac-finalize.json",
    [string] $IamRbacFinalizeSummaryPath = ".\.osmu-run\latest-iam-rbac-finalize.md",
    [string] $SecurityFinalizeReportPath = ".\.osmu-run\latest-security-evidence-finalize.json",
    [string] $SecurityFinalizeSummaryPath = ".\.osmu-run\latest-security-evidence-finalize.md",
    [string] $OperationsReadinessJsonPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $OperationsReadinessMarkdownPath = ".\.osmu-run\latest-operations-readiness.md",
    [string] $DataFlowStoragePlanPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $ReportPath = ".\.osmu-run\latest-operations-readiness-finalize.json",
    [string] $SummaryPath = ".\.osmu-run\latest-operations-readiness-finalize.md",
    [switch] $RunStorageExpansionFinalizer,
    [switch] $RunHaDrReadiness,
    [switch] $RunKubernetesDrFinalizer,
    [switch] $RunIamRbacFinalizer,
    [switch] $RunSecurityEvidenceFinalizer,
    [switch] $RunIamBackendPolicyTests,
    [switch] $RunIamKubernetesLiveAuth,
    [switch] $ImpersonateRunner,
    [switch] $RunStorageBackendDryRunRunner,
    [switch] $RunStorageBackendApply,
    [switch] $ConfirmStorageApply,
    [switch] $ServerDryRunOnly,
    [switch] $ConfirmRestore,
    [switch] $RunDrBackupDrill,
    [switch] $BootstrapDrBucket,
    [switch] $VerifyDrBucketImmutability,
    [switch] $TransferDrArtifacts,
    [switch] $SkipRestoreSmoke,
    [switch] $SkipEvidenceRequest,
    [switch] $RunS3ClientSmoke,
    [switch] $SubmitDrEvidence,
    [switch] $FailIfNotReady,
    [switch] $PlanOnly,
    [switch] $NoReport
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$steps = @()
$failureCount = 0
$startedAt = [DateTimeOffset]::UtcNow

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
    $parts = @(
        (Get-PowerShellExecutable),
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Format-Value $ScriptPath)
    )
    foreach ($argument in (Mask-Arguments $Arguments)) {
        $parts += Format-Value $argument
    }
    return ($parts -join " ").Trim()
}

function New-CommandEntry([string] $Name, [string] $ScriptPath, [string[]] $Arguments) {
    return [ordered]@{
        name = $Name
        script = $ScriptPath
        rawArguments = $Arguments
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
    Write-Host ""
    Write-Host "==> $Name"
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

function Read-JsonReport([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return $null
    }
    return Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
}

function New-StorageExpansionArguments([bool] $ForPlan) {
    $arguments = @(
        "-Namespace", $Namespace,
        "-TenantName", $TenantName,
        "-ManifestPath", $StorageExpansionManifestPath,
        "-KubectlPath", $KubectlPath,
        "-PowerShellCommand", (Get-PowerShellExecutable)
    )
    if ($ImpersonateRunner) {
        $arguments += "-ImpersonateRunner"
    }
    if ($RunStorageBackendDryRunRunner) {
        $arguments += @(
            "-RunBackendDryRunRunner",
            "-ApiBase", $ApiBase,
            "-AdminLoginId", $AdminLoginId,
            "-AdminPassword", $AdminPassword,
            "-RequestId", "$StorageExpansionRequestId"
        )
    }
    if ($RunStorageBackendApply) {
        $arguments += @(
            "-RunBackendApply",
            "-ApiBase", $ApiBase,
            "-AdminLoginId", $AdminLoginId,
            "-AdminPassword", $AdminPassword,
            "-RequestId", "$StorageExpansionRequestId"
        )
        if ($ConfirmStorageApply) {
            $arguments += "-ConfirmApply"
        }
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    return $arguments
}

function New-HaDrReadinessArguments([bool] $ForPlan) {
    $arguments = @(
        "-Namespace", $Namespace,
        "-KubectlPath", $KubectlPath,
        "-RestoreManifestPath", $RestoreManifestPath
    )
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    return $arguments
}

function New-KubernetesDrArguments([bool] $ForPlan) {
    $arguments = @(
        "-SourceNamespace", $SourceNamespace,
        "-RestoreNamespace", $RestoreNamespace,
        "-KubectlPath", $KubectlPath,
        "-BackupTimestamp", $BackupTimestamp,
        "-PowerShellCommand", (Get-PowerShellExecutable),
        "-ApiBase", $ApiBase,
        "-AdminLoginId", $AdminLoginId
    )
    if ($AdminPassword) {
        $arguments += @("-AdminPassword", $AdminPassword)
    }
    if ($RunDrBackupDrill) {
        $arguments += "-RunBackupDrill"
    }
    if ($BootstrapDrBucket) {
        $arguments += "-BootstrapDrBucket"
    }
    if ($VerifyDrBucketImmutability) {
        $arguments += "-VerifyDrBucketImmutability"
    }
    if ($TransferDrArtifacts) {
        $arguments += "-TransferArtifacts"
    }
    if ($SkipRestoreSmoke) {
        $arguments += "-SkipRestoreSmoke"
    }
    if ($SkipEvidenceRequest) {
        $arguments += "-SkipEvidenceRequest"
    }
    if ($RunS3ClientSmoke) {
        $arguments += "-RunS3ClientSmoke"
    }
    if ($SubmitDrEvidence) {
        $arguments += "-SubmitEvidence"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    elseif ($ServerDryRunOnly) {
        $arguments += "-ServerDryRunOnly"
    }
    elseif ($ConfirmRestore) {
        $arguments += "-ConfirmRestore"
    }
    return $arguments
}

function New-SecurityFinalizerArguments() {
    return @(
        "-ImageSigningEvidencePath", $ImageSigningEvidencePath,
        "-ContainerSecurityEvidencePath", $ContainerSecurityEvidencePath,
        "-JsonOutputPath", $SecurityFinalizeReportPath,
        "-MarkdownOutputPath", $SecurityFinalizeSummaryPath,
        "-FailIfNotPassed"
    )
}

function New-IamRbacFinalizerArguments([bool] $ForPlan) {
    $arguments = @(
        "-JsonOutputPath", $IamRbacFinalizeReportPath,
        "-MarkdownOutputPath", $IamRbacFinalizeSummaryPath,
        "-Namespace", $Namespace,
        "-PowerShellCommand", (Get-PowerShellExecutable),
        "-KubectlPath", $KubectlPath
    )
    if ($RunIamBackendPolicyTests) {
        $arguments += "-RunBackendPolicyTests"
    }
    if ($RunIamKubernetesLiveAuth) {
        $arguments += "-RunKubernetesLiveAuth"
    }
    if ($ForPlan) {
        $arguments += "-PlanOnly"
    }
    return $arguments
}

function New-OperationsReadinessArguments() {
    $arguments = @(
        "-JsonOutputPath", $OperationsReadinessJsonPath,
        "-MarkdownOutputPath", $OperationsReadinessMarkdownPath,
        "-DataFlowStoragePlanPath", $DataFlowStoragePlanPath
    )
    if ($FailIfNotReady) {
        $arguments += "-FailIfNotReady"
    }
    return $arguments
}

function Get-Commands([bool] $ForPlan) {
    $commands = @()
    if ($RunStorageExpansionFinalizer) {
        $commands += New-CommandEntry "Storage expansion finalizer" ".\scripts\finalize-storage-expansion.ps1" (New-StorageExpansionArguments $ForPlan)
    }
    if ($RunHaDrReadiness) {
        $commands += New-CommandEntry "Kubernetes HA/DR readiness" ".\scripts\verify-kubernetes-ha-dr-readiness.ps1" (New-HaDrReadinessArguments $ForPlan)
    }
    if ($RunKubernetesDrFinalizer) {
        $commands += New-CommandEntry "Kubernetes DR finalizer" ".\scripts\finalize-kubernetes-dr-drill.ps1" (New-KubernetesDrArguments $ForPlan)
    }
    if ($RunIamRbacFinalizer) {
        $commands += New-CommandEntry "IAM/RBAC finalizer" ".\scripts\finalize-iam-rbac-readiness.ps1" (New-IamRbacFinalizerArguments $ForPlan)
    }
    if ($RunSecurityEvidenceFinalizer) {
        $commands += New-CommandEntry "Security evidence finalizer" ".\scripts\finalize-security-evidence.ps1" (New-SecurityFinalizerArguments)
    }
    $commands += New-CommandEntry "Operations readiness report" ".\scripts\write-operations-readiness.ps1" (New-OperationsReadinessArguments)
    return $commands
}

function Assert-Inputs() {
    if ($RunStorageBackendApply -and -not $ConfirmStorageApply) {
        throw "-RunStorageBackendApply requires -ConfirmStorageApply."
    }
    if (($RunStorageBackendDryRunRunner -or $RunStorageBackendApply) -and $StorageExpansionRequestId -le 0) {
        throw "Storage backend runner calls require -StorageExpansionRequestId greater than zero."
    }
    if (($RunStorageBackendDryRunRunner -or $RunStorageBackendApply -or $ConfirmRestore -or $SubmitDrEvidence) -and -not $AdminPassword) {
        throw "Backend runner, confirmed restore, or evidence submission requires -AdminPassword."
    }
    if ($RunKubernetesDrFinalizer -and -not $PlanOnly -and $BackupTimestamp -eq "YYYYMMDDTHHMMSSZ") {
        throw "RunKubernetesDrFinalizer requires a real -BackupTimestamp outside -PlanOnly."
    }
    if ($RunKubernetesDrFinalizer -and -not $PlanOnly -and -not $ServerDryRunOnly -and -not $ConfirmRestore) {
        throw "RunKubernetesDrFinalizer requires -ServerDryRunOnly or -ConfirmRestore outside -PlanOnly."
    }
}

function Write-FinalReport([string] $ResultValue, [string] $Status, [object[]] $Commands, [string[]] $Gaps) {
    if ($NoReport) {
        return
    }

    $resolvedReportPath = Resolve-ProjectPath $ReportPath
    $resolvedSummaryPath = Resolve-ProjectPath $SummaryPath
    $readinessReport = Read-JsonReport $OperationsReadinessJsonPath
    $completedAt = [DateTimeOffset]::UtcNow
    $readinessResult = if ($null -eq $readinessReport) { "missing" } else { [string] $readinessReport.result }

    $report = [ordered]@{
        formatVersion = "osmu.operations-readiness-finalize.v1"
        generatedAt = $completedAt.ToString("o")
        startedAt = $startedAt.ToString("o")
        completedAt = $completedAt.ToString("o")
        result = $ResultValue
        status = $Status
        readinessResult = $readinessResult
        readinessSummary = if ($null -eq $readinessReport) { "" } else { [string] $readinessReport.summary }
        namespace = $Namespace
        sourceNamespace = $SourceNamespace
        restoreNamespace = $RestoreNamespace
        backupTimestamp = $BackupTimestamp
        powerShellCommand = Get-PowerShellExecutable
        selectedSteps = [ordered]@{
            storageExpansionFinalizer = [bool] $RunStorageExpansionFinalizer
            haDrReadiness = [bool] $RunHaDrReadiness
            kubernetesDrFinalizer = [bool] $RunKubernetesDrFinalizer
            iamRbacFinalizer = [bool] $RunIamRbacFinalizer
            securityEvidenceFinalizer = [bool] $RunSecurityEvidenceFinalizer
        }
        paths = [ordered]@{
            iamRbacFinalizeReport = Resolve-ProjectPath $IamRbacFinalizeReportPath
            iamRbacFinalizeSummary = Resolve-ProjectPath $IamRbacFinalizeSummaryPath
            operationsReadinessJson = Resolve-ProjectPath $OperationsReadinessJsonPath
            operationsReadinessMarkdown = Resolve-ProjectPath $OperationsReadinessMarkdownPath
            dataFlowStoragePlan = Resolve-ProjectPath $DataFlowStoragePlanPath
            report = $resolvedReportPath
            summary = $resolvedSummaryPath
        }
        commands = @($Commands | ForEach-Object {
            [ordered]@{
                name = $_.name
                script = $_.script
                arguments = $_.arguments
                command = $_.command
            }
        })
        steps = $steps
        failedCount = $failureCount
        gaps = $Gaps
        secretPolicy = "Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens."
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedSummaryPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8

    $summaryLines = @(
        "# OSMU Operations Readiness Finalize",
        "",
        "Generated at: $($report.generatedAt)",
        "Result: $ResultValue",
        "Status: $Status",
        "Operations readiness result: $readinessResult",
        "Operations readiness summary: $($report.readinessSummary)",
        "",
        "## Commands",
        ""
    )
    foreach ($command in $Commands) {
        $summaryLines += "- $($command.name): ``$($command.command)``"
    }
    $summaryLines += ""
    $summaryLines += "## Gaps"
    if ($Gaps.Count -eq 0) {
        $summaryLines += "- None"
    }
    else {
        foreach ($gap in $Gaps) {
            $summaryLines += "- $gap"
        }
    }
    ($summaryLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedSummaryPath -Encoding UTF8

    Write-Host "Operations readiness finalizer JSON: $resolvedReportPath"
    Write-Host "Operations readiness finalizer markdown: $resolvedSummaryPath"
    Write-Host ($summaryLines -join [Environment]::NewLine)
}

Assert-Inputs
$commands = @(Get-Commands $PlanOnly)
$gaps = @()

if ($PlanOnly) {
    Write-Host "Operations readiness finalizer plan only."
    foreach ($command in $commands) {
        Write-Host "- $($command.name): $($command.command)"
    }
    $gaps += "Plan only; selected evidence steps were not executed."
    Write-FinalReport "planned" "operations-readiness-finalize-plan" $commands $gaps
    return
}

try {
    foreach ($command in $commands) {
        Invoke-ProjectScript $command.name $command.script ([string[]] $command.rawArguments)
    }

    $readinessReport = Read-JsonReport $OperationsReadinessJsonPath
    if ($null -eq $readinessReport) {
        $gaps += "Operations readiness report was not generated."
    }
    elseif ($readinessReport.result -ne "ready") {
        $gaps += "Operations readiness result is $($readinessReport.result): $($readinessReport.summary)."
    }

    $result = if ($failureCount -eq 0 -and $gaps.Count -eq 0) { "ready" } else { "pending" }
    $status = if ($result -eq "ready") { "operations-readiness-finalize-ready" } else { "operations-readiness-finalize-pending" }
    Write-FinalReport $result $status $commands $gaps

    if ($FailIfNotReady -and $result -ne "ready") {
        throw "Operations readiness finalizer is not ready."
    }
}
catch {
    $gaps += $_.Exception.Message
    Write-FinalReport "failed" "operations-readiness-finalize-failed" $commands $gaps
    throw
}
