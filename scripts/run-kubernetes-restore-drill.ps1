param(
    [string] $SourceNamespace = "osmu",
    [string] $RestoreNamespace = "osmu-restore-drill",
    [string] $KubectlPath = "kubectl",
    [string] $RunId = "",
    [string] $BackupTimestamp = "YYYYMMDDTHHMMSSZ",
    [int] $TimeoutSeconds = 900,
    [string] $RestoreManifestPath = ".\infra\k8s\examples\restore-from-backup.example.yaml",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-restore-drill.json",
    [switch] $ServerDryRunOnly,
    [switch] $ConfirmRestore,
    [switch] $AllowSourceNamespaceRestore,
    [switch] $CleanupJob,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()
$failureCount = 0

if (-not $RunId) {
    $RunId = [DateTimeOffset]::UtcNow.ToString("yyyyMMddHHmmss")
}

$jobName = "osmu-restore-drill-$RunId"

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

function Test-KubeName([string] $Kind, [string] $Name) {
    $result = Invoke-KubectlRaw "$Kind-$Name" @("-n", $RestoreNamespace, "get", $Kind, $Name, "-o", "name")
    $expected = "$Kind/$Name"
    $passed = ($result.exitCode -eq 0) -and ($result.output.Trim() -eq $expected)
    Add-Check "$Kind-$Name-exists" $passed "$expected in restore namespace." $result.command $result.exitCode $result.output
    return $passed
}

function Test-NamespaceReady() {
    $source = Read-KubeJson "namespace-$RestoreNamespace" @("get", "namespace", $RestoreNamespace, "-o", "json")
    if ($null -eq $source) {
        return $false
    }
    $phase = "$($source.json.status.phase)"
    $passed = $phase -eq "Active"
    Add-Check "namespace-$RestoreNamespace-active" $passed "phase=$phase" $source.command 0 ""
    return $passed
}

function Test-BackupPvcReady() {
    $source = Read-KubeJson "pvc-osmu-backup-data" @("-n", $RestoreNamespace, "get", "pvc", "osmu-backup-data", "-o", "json")
    if ($null -eq $source) {
        return $false
    }
    $phase = "$($source.json.status.phase)"
    $passed = $phase -eq "Bound"
    Add-Check "pvc-osmu-backup-data-bound" $passed "phase=$phase" $source.command 0 ""
    return $passed
}

function Assert-InputsAreSafe() {
    if ($PlanOnly) {
        return
    }
    if ($BackupTimestamp -eq "YYYYMMDDTHHMMSSZ") {
        throw "Set -BackupTimestamp to a real backup timestamp such as 20260615T010203Z."
    }
    if ($BackupTimestamp -notmatch "^\d{8}T\d{6}Z$") {
        throw "BackupTimestamp must match YYYYMMDDTHHMMSSZ, for example 20260615T010203Z."
    }
    if (($SourceNamespace -eq $RestoreNamespace) -and (-not $AllowSourceNamespaceRestore)) {
        throw "RestoreNamespace must differ from SourceNamespace for isolated drills. Use -AllowSourceNamespaceRestore only after explicit manual approval."
    }
    if ((-not $ServerDryRunOnly) -and (-not $ConfirmRestore)) {
        throw "This command can overwrite restore target data. Rerun with -ConfirmRestore after confirming the target namespace is isolated."
    }
}

function New-RestoreManifestText() {
    $resolvedManifestPath = Resolve-ProjectPath $RestoreManifestPath
    if (-not (Test-Path -LiteralPath $resolvedManifestPath)) {
        throw "Restore manifest template not found: $resolvedManifestPath"
    }

    $manifest = Get-Content -Raw -LiteralPath $resolvedManifestPath
    if (-not $manifest.Contains("osmu-restore-from-backup-example")) {
        throw "Restore manifest template does not contain expected example job name."
    }
    if (-not $manifest.Contains("YYYYMMDDTHHMMSSZ")) {
        throw "Restore manifest template does not contain expected BACKUP_TIMESTAMP placeholder."
    }
    if (-not $manifest.Contains("claimName: osmu-backup-data")) {
        throw "Restore manifest template must mount the osmu-backup-data PVC."
    }

    $manifest = $manifest.Replace("name: osmu-restore-from-backup-example", "name: $jobName")
    $manifest = $manifest.Replace("namespace: osmu", "namespace: $RestoreNamespace")
    $manifest = $manifest.Replace('value: "YYYYMMDDTHHMMSSZ"', "value: `"$BackupTimestamp`"")
    return $manifest
}

function Write-RestoreManifest() {
    $manifestDirectory = Resolve-ProjectPath ".\.osmu-run\kubernetes-restore-drills"
    if (-not (Test-Path -LiteralPath $manifestDirectory)) {
        New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
    }

    $manifestPath = Join-Path $manifestDirectory "$jobName.yaml"
    New-RestoreManifestText | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    return $manifestPath
}

function Test-RestoreTargetPrerequisites() {
    Test-NamespaceReady | Out-Null
    Test-BackupPvcReady | Out-Null
    Test-KubeName "configmap" "osmu-config" | Out-Null
    Test-KubeName "secret" "osmu-secret" | Out-Null
    Test-KubeName "serviceaccount" "osmu-backup" | Out-Null
    Test-KubeName "service" "osmu-mariadb" | Out-Null
    Test-KubeName "service" "osmu-minio" | Out-Null
}

function Invoke-ServerDryRun([string] $ManifestPath) {
    $dryRun = Invoke-KubectlRaw "restore-server-dry-run" @("apply", "--server-side", "--dry-run=server", "-f", $ManifestPath)
    Add-Check "restore-server-dry-run" ($dryRun.exitCode -eq 0) "validated restore Job manifest with Kubernetes API server." $dryRun.command $dryRun.exitCode $dryRun.output
    return $dryRun.exitCode -eq 0
}

function Get-JobPods([string] $Name) {
    $source = Read-KubeJson "pods-$Name" @("-n", $RestoreNamespace, "get", "pods", "-l", "job-name=$Name", "-o", "json")
    if ($null -eq $source) {
        return @()
    }

    $items = @($source.json.items)
    Add-Check "pods-$Name-found" ($items.Count -gt 0) "podCount=$($items.Count)" $source.command 0 ""
    return $items
}

function Get-PodLogs([object[]] $Pods) {
    $logs = @()
    foreach ($pod in $Pods) {
        $podName = "$($pod.metadata.name)"
        if (-not $podName) {
            continue
        }
        $result = Invoke-KubectlRaw "logs-$podName" @("-n", $RestoreNamespace, "logs", $podName, "--all-containers=true", "--tail=200")
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

function Invoke-RestoreJob([string] $ManifestPath) {
    $apply = Invoke-KubectlRaw "apply-$jobName" @("apply", "-f", $ManifestPath)
    Add-Check "apply-$jobName" ($apply.exitCode -eq 0) "created restore drill Job in isolated target namespace." $apply.command $apply.exitCode $apply.output
    if ($apply.exitCode -ne 0) {
        return [pscustomobject]@{
            jobName = $jobName
            result = "failed"
            reason = "Job apply failed."
            pods = @()
            logs = @()
        }
    }

    $wait = Invoke-KubectlRaw "wait-$jobName" @("-n", $RestoreNamespace, "wait", "--for=condition=complete", "--timeout=$($TimeoutSeconds)s", "job/$jobName")
    Add-Check "wait-$jobName" ($wait.exitCode -eq 0) "waited for restore drill job completion." $wait.command $wait.exitCode $wait.output

    $jobSource = Read-KubeJson "job-$jobName" @("-n", $RestoreNamespace, "get", "job", $jobName, "-o", "json")
    $jobJson = if ($null -ne $jobSource) { $jobSource.json } else { $null }
    $pods = @(Get-JobPods $jobName)
    $logs = @(Get-PodLogs $pods)

    if ($CleanupJob) {
        $delete = Invoke-KubectlRaw "delete-$jobName" @("-n", $RestoreNamespace, "delete", "job", $jobName, "--ignore-not-found=true")
        Add-Check "delete-$jobName" ($delete.exitCode -eq 0) "deleted restore drill job after evidence collection." $delete.command $delete.exitCode $delete.output
    }

    return [pscustomobject]@{
        jobName = $jobName
        result = if ($wait.exitCode -eq 0) { "completed" } else { "failed" }
        applyCommand = $apply.command
        waitCommand = $wait.command
        job = $jobJson
        pods = $pods
        logs = $logs
    }
}

function Get-PlanCommands() {
    $plannedManifestPath = ".\.osmu-run\kubernetes-restore-drills\$jobName.yaml"
    $commands = @()
    $commands += ,@("get", "namespace", $RestoreNamespace, "-o", "json")
    $commands += ,@("-n", $RestoreNamespace, "get", "pvc", "osmu-backup-data", "-o", "json")
    $commands += ,@("-n", $RestoreNamespace, "get", "configmap", "osmu-config", "-o", "name")
    $commands += ,@("-n", $RestoreNamespace, "get", "secret", "osmu-secret", "-o", "name")
    $commands += ,@("-n", $RestoreNamespace, "get", "serviceaccount", "osmu-backup", "-o", "name")
    $commands += ,@("-n", $RestoreNamespace, "get", "service", "osmu-mariadb", "-o", "name")
    $commands += ,@("-n", $RestoreNamespace, "get", "service", "osmu-minio", "-o", "name")
    $commands += ,@("apply", "--server-side", "--dry-run=server", "-f", $plannedManifestPath)
    if (-not $ServerDryRunOnly) {
        $commands += ,@("apply", "-f", $plannedManifestPath)
        $commands += ,@("-n", $RestoreNamespace, "wait", "--for=condition=complete", "--timeout=$($TimeoutSeconds)s", "job/$jobName")
        $commands += ,@("-n", $RestoreNamespace, "get", "job", $jobName, "-o", "json")
        $commands += ,@("-n", $RestoreNamespace, "get", "pods", "-l", "job-name=$jobName", "-o", "json")
        $commands += ,@("-n", $RestoreNamespace, "logs", "-l", "job-name=$jobName", "--all-containers=true", "--tail=200")
        if ($CleanupJob) {
            $commands += ,@("-n", $RestoreNamespace, "delete", "job", $jobName, "--ignore-not-found=true")
        }
    }
    return $commands
}

Assert-InputsAreSafe

if ($PlanOnly) {
    Write-Host "Kubernetes restore drill plan only."
    Write-Host "Source namespace: $SourceNamespace"
    Write-Host "Restore namespace: $RestoreNamespace"
    Write-Host "Run ID: $RunId"
    Write-Host "Job name: $jobName"
    Write-Host "Backup timestamp: $BackupTimestamp"
    Write-Host "Timeout seconds: $TimeoutSeconds"
    Write-Host "Server dry-run only: $ServerDryRunOnly"
    Write-Host "Confirm restore: $ConfirmRestore"
    Write-Host "Cleanup job: $CleanupJob"
    Write-Host "Restore target must contain a clean OSMU stack and an osmu-backup-data PVC with /backup/mariadb/$BackupTimestamp/metadata.sql and /backup/minio/$BackupTimestamp."
    foreach ($commandArguments in Get-PlanCommands) {
        Write-Host "[CHECK] $(Format-Command $commandArguments)"
    }
    Write-Host "Plan only; no restore Job created and no evidence file written."
    return
}

$manifestPath = Write-RestoreManifest
Test-RestoreTargetPrerequisites
$dryRunPassed = Invoke-ServerDryRun $manifestPath

$restoreJob = $null
if (-not $ServerDryRunOnly) {
    if ($dryRunPassed -and ($failureCount -eq 0)) {
        $restoreJob = Invoke-RestoreJob $manifestPath
    }
    else {
        Add-Check "restore-job-skipped" $false "restore Job was skipped because prerequisite checks or server-side dry-run failed." "" 0 ""
    }
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
}

$evidence = [pscustomobject]@{
    formatVersion = "osmu.kubernetes-restore-drill.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    sourceNamespace = $SourceNamespace
    restoreNamespace = $RestoreNamespace
    runId = $RunId
    jobName = $jobName
    backupTimestamp = $BackupTimestamp
    kubectlPath = $KubectlPath
    timeoutSeconds = $TimeoutSeconds
    serverDryRunOnly = [bool] $ServerDryRunOnly
    confirmRestore = [bool] $ConfirmRestore
    allowSourceNamespaceRestore = [bool] $AllowSourceNamespaceRestore
    cleanupJob = [bool] $CleanupJob
    generatedManifestPath = $manifestPath
    result = if ($failureCount -eq 0) { "passed" } else { "failed" }
    failureCount = $failureCount
    secretPolicy = "Secret values are not copied into this restore drill evidence."
    expectedBackupPaths = @(
        "/backup/mariadb/$BackupTimestamp/metadata.sql",
        "/backup/minio/$BackupTimestamp"
    )
    checks = $checks
    job = $restoreJob
}

$evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

if ($failureCount -ne 0) {
    Write-Host "Kubernetes restore drill evidence written with failures: $resolvedEvidencePath"
    throw "Kubernetes restore drill failed: $failureCount failed checks."
}

Write-Host "Kubernetes restore drill completed."
Write-Host "Evidence: $resolvedEvidencePath"
