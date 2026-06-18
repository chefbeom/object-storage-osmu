param(
    [string] $Namespace = "osmu",
    [string] $KubectlPath = "kubectl",
    [string] $RunId = "",
    [int] $TimeoutSeconds = 900,
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-backup-drill.json",
    [switch] $CleanupJobs,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()
$jobResults = @()
$failureCount = 0

if (-not $RunId) {
    $RunId = [DateTimeOffset]::UtcNow.ToString("yyyyMMddHHmmss")
}

$backupJobs = @(
    [pscustomobject]@{
        name = "mariadb"
        cronJobName = "osmu-mariadb-backup"
        jobName = "osmu-mariadb-backup-drill-$RunId"
    },
    [pscustomobject]@{
        name = "minio"
        cronJobName = "osmu-minio-backup"
        jobName = "osmu-minio-backup-drill-$RunId"
    }
)

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Format-Command([string[]] $arguments) {
    $renderedArgs = $arguments | ForEach-Object {
        if ($_ -match "\s") {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }
    return "$KubectlPath " + ($renderedArgs -join " ")
}

function Limit-Text([string] $text) {
    if ($null -eq $text) {
        return ""
    }
    if ($text.Length -le 6000) {
        return $text
    }
    return $text.Substring(0, 6000) + "`n...truncated..."
}

function Add-Check(
    [string] $Name,
    [bool] $Passed,
    [string] $Summary,
    [string] $Command = "",
    [int] $ExitCode = 0,
    [string] $Output = ""
) {
    $script:checks += [pscustomobject]@{
        name = $Name
        passed = $Passed
        summary = $Summary
        command = $Command
        exitCode = $ExitCode
        output = (Limit-Text $Output)
    }
    if (-not $Passed) {
        $script:failureCount += 1
    }
}

function Invoke-KubectlRaw([string] $Name, [string[]] $Arguments) {
    $command = Format-Command $Arguments
    $outputLines = & $KubectlPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output = ($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    return [pscustomobject]@{
        name = $Name
        command = $command
        exitCode = $exitCode
        output = $output
    }
}

function Read-KubeJson([string] $Name, [string[]] $Arguments) {
    $result = Invoke-KubectlRaw $Name $Arguments
    if ($result.exitCode -ne 0) {
        Add-Check $Name $false "kubectl command failed." $result.command $result.exitCode $result.output
        return $null
    }

    try {
        return [pscustomobject]@{
            json = ($result.output | ConvertFrom-Json)
            command = $result.command
            output = $result.output
        }
    }
    catch {
        Add-Check $Name $false "kubectl returned invalid JSON: $($_.Exception.Message)" $result.command $result.exitCode $result.output
        return $null
    }
}

function Test-CronJobExists([string] $CronJobName) {
    $source = Read-KubeJson "cronjob-$CronJobName" @("-n", $Namespace, "get", "cronjob", $CronJobName, "-o", "json")
    if ($null -eq $source) {
        return $false
    }

    $cronJob = $source.json
    $schedule = "$($cronJob.spec.schedule)"
    $concurrencyPolicy = "$($cronJob.spec.concurrencyPolicy)"
    $suspend = $false
    if ($null -ne $cronJob.spec.suspend) {
        $suspend = [bool] $cronJob.spec.suspend
    }

    $passed = ($schedule.Length -gt 0) -and ($concurrencyPolicy -eq "Forbid") -and (-not $suspend)
    Add-Check "cronjob-$CronJobName-ready" $passed "schedule=$schedule concurrencyPolicy=$concurrencyPolicy suspend=$suspend" $source.command 0 ""
    return $passed
}

function Get-JobPods([string] $JobName) {
    $source = Read-KubeJson "pods-$JobName" @("-n", $Namespace, "get", "pods", "-l", "job-name=$JobName", "-o", "json")
    if ($null -eq $source) {
        return @()
    }

    $items = @($source.json.items)
    Add-Check "pods-$JobName-found" ($items.Count -gt 0) "podCount=$($items.Count)" $source.command 0 ""
    return $items
}

function Get-PodLogs([object[]] $Pods) {
    $logs = @()
    foreach ($pod in $Pods) {
        $podName = "$($pod.metadata.name)"
        if (-not $podName) {
            continue
        }
        $result = Invoke-KubectlRaw "logs-$podName" @("-n", $Namespace, "logs", $podName, "--all-containers=true", "--tail=200")
        $logs += [pscustomobject]@{
            podName = $podName
            command = $result.command
            exitCode = $result.exitCode
            output = (Limit-Text $result.output)
        }
        Add-Check "logs-$podName" ($result.exitCode -eq 0) "collected last 200 lines for all containers." $result.command $result.exitCode $result.output
    }
    return $logs
}

function Invoke-BackupJob([object] $BackupJob) {
    $cronReady = Test-CronJobExists $BackupJob.cronJobName
    if (-not $cronReady) {
        return [pscustomobject]@{
            name = $BackupJob.name
            cronJobName = $BackupJob.cronJobName
            jobName = $BackupJob.jobName
            result = "skipped"
            reason = "CronJob readiness check failed."
            pods = @()
            logs = @()
        }
    }

    $create = Invoke-KubectlRaw "create-$($BackupJob.jobName)" @("-n", $Namespace, "create", "job", $BackupJob.jobName, "--from=cronjob/$($BackupJob.cronJobName)")
    Add-Check "create-$($BackupJob.jobName)" ($create.exitCode -eq 0) "created backup drill job from CronJob $($BackupJob.cronJobName)." $create.command $create.exitCode $create.output
    if ($create.exitCode -ne 0) {
        return [pscustomobject]@{
            name = $BackupJob.name
            cronJobName = $BackupJob.cronJobName
            jobName = $BackupJob.jobName
            result = "failed"
            reason = "Job create failed."
            pods = @()
            logs = @()
        }
    }

    $wait = Invoke-KubectlRaw "wait-$($BackupJob.jobName)" @("-n", $Namespace, "wait", "--for=condition=complete", "--timeout=$($TimeoutSeconds)s", "job/$($BackupJob.jobName)")
    Add-Check "wait-$($BackupJob.jobName)" ($wait.exitCode -eq 0) "waited for backup drill job completion." $wait.command $wait.exitCode $wait.output

    $jobSource = Read-KubeJson "job-$($BackupJob.jobName)" @("-n", $Namespace, "get", "job", $BackupJob.jobName, "-o", "json")
    $jobJson = if ($null -ne $jobSource) { $jobSource.json } else { $null }
    $pods = @(Get-JobPods $BackupJob.jobName)
    $logs = @(Get-PodLogs $pods)

    if ($CleanupJobs) {
        $delete = Invoke-KubectlRaw "delete-$($BackupJob.jobName)" @("-n", $Namespace, "delete", "job", $BackupJob.jobName, "--ignore-not-found=true")
        Add-Check "delete-$($BackupJob.jobName)" ($delete.exitCode -eq 0) "deleted backup drill job after evidence collection." $delete.command $delete.exitCode $delete.output
    }

    return [pscustomobject]@{
        name = $BackupJob.name
        cronJobName = $BackupJob.cronJobName
        jobName = $BackupJob.jobName
        result = if ($wait.exitCode -eq 0) { "completed" } else { "failed" }
        createCommand = $create.command
        waitCommand = $wait.command
        job = $jobJson
        pods = $pods
        logs = $logs
    }
}

function Get-PlanCommands() {
    $commands = @()
    foreach ($backupJob in $backupJobs) {
        $commands += ,@("-n", $Namespace, "get", "cronjob", $backupJob.cronJobName, "-o", "json")
        $commands += ,@("-n", $Namespace, "create", "job", $backupJob.jobName, "--from=cronjob/$($backupJob.cronJobName)")
        $commands += ,@("-n", $Namespace, "wait", "--for=condition=complete", "--timeout=$($TimeoutSeconds)s", "job/$($backupJob.jobName)")
        $commands += ,@("-n", $Namespace, "get", "job", $backupJob.jobName, "-o", "json")
        $commands += ,@("-n", $Namespace, "get", "pods", "-l", "job-name=$($backupJob.jobName)", "-o", "json")
        $commands += ,@("-n", $Namespace, "logs", "-l", "job-name=$($backupJob.jobName)", "--all-containers=true", "--tail=200")
        if ($CleanupJobs) {
            $commands += ,@("-n", $Namespace, "delete", "job", $backupJob.jobName, "--ignore-not-found=true")
        }
    }
    return $commands
}

if ($PlanOnly) {
    Write-Host "Kubernetes backup drill plan only."
    Write-Host "Namespace: $Namespace"
    Write-Host "Run ID: $RunId"
    Write-Host "Timeout seconds: $TimeoutSeconds"
    Write-Host "Cleanup jobs: $CleanupJobs"
    foreach ($commandArguments in Get-PlanCommands) {
        Write-Host "[CHECK] $(Format-Command $commandArguments)"
    }
    Write-Host "Plan only; no backup Job created and no evidence file written."
    return
}

foreach ($backupJob in $backupJobs) {
    $jobResults += Invoke-BackupJob $backupJob
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
}

$evidence = [pscustomobject]@{
    formatVersion = "osmu.kubernetes-backup-drill.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    namespace = $Namespace
    runId = $RunId
    kubectlPath = $KubectlPath
    timeoutSeconds = $TimeoutSeconds
    cleanupJobs = [bool] $CleanupJobs
    result = if ($failureCount -eq 0) { "passed" } else { "failed" }
    failureCount = $failureCount
    checks = $checks
    jobs = $jobResults
}

$evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

if ($failureCount -ne 0) {
    Write-Host "Kubernetes backup drill evidence written with failures: $resolvedEvidencePath"
    throw "Kubernetes backup drill failed: $failureCount failed checks."
}

Write-Host "Kubernetes backup drill completed."
Write-Host "Evidence: $resolvedEvidencePath"
