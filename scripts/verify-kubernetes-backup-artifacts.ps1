param(
    [string] $RestoreNamespace = "osmu-restore-drill",
    [string] $KubectlPath = "kubectl",
    [string] $RunId = "",
    [string] $BackupTimestamp = "YYYYMMDDTHHMMSSZ",
    [int] $TimeoutSeconds = 300,
    [string] $Image = "alpine:3.20",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-backup-artifacts.json",
    [switch] $AllowEmptyMinio,
    [switch] $ServerDryRunOnly,
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

$jobName = "osmu-backup-artifact-preflight-$RunId"

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
}

function Test-NamespaceReady() {
    $source = Read-KubeJson "namespace-$RestoreNamespace" @("get", "namespace", $RestoreNamespace, "-o", "json")
    if ($null -eq $source) {
        return
    }
    $phase = "$($source.json.status.phase)"
    Add-Check "namespace-$RestoreNamespace-active" ($phase -eq "Active") "phase=$phase" $source.command 0 ""
}

function Test-BackupPvcReady() {
    $source = Read-KubeJson "pvc-osmu-backup-data" @("-n", $RestoreNamespace, "get", "pvc", "osmu-backup-data", "-o", "json")
    if ($null -eq $source) {
        return
    }
    $phase = "$($source.json.status.phase)"
    Add-Check "pvc-osmu-backup-data-bound" ($phase -eq "Bound") "phase=$phase" $source.command 0 ""
}

function Test-ServiceAccountReady() {
    $result = Invoke-KubectlRaw "serviceaccount-osmu-backup" @("-n", $RestoreNamespace, "get", "serviceaccount", "osmu-backup", "-o", "name")
    $passed = ($result.exitCode -eq 0) -and ($result.output.Trim() -eq "serviceaccount/osmu-backup")
    Add-Check "serviceaccount-osmu-backup-exists" $passed "restore namespace backup ServiceAccount exists." $result.command $result.exitCode $result.output
}

function New-ArtifactPreflightManifestText() {
    $allowEmpty = if ($AllowEmptyMinio) { "true" } else { "false" }
    $template = @'
apiVersion: batch/v1
kind: Job
metadata:
  name: __JOB_NAME__
  namespace: __RESTORE_NAMESPACE__
  labels:
    app.kubernetes.io/name: osmu-backup
    app.kubernetes.io/component: backup-artifact-preflight
    app.kubernetes.io/part-of: osmu
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: osmu-backup
        app.kubernetes.io/component: backup-artifact-preflight
        app.kubernetes.io/part-of: osmu
    spec:
      restartPolicy: Never
      serviceAccountName: osmu-backup
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: backup-artifact-preflight
          image: __IMAGE__
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
            - -ec
          args:
            - |
              metadata_file="/backup/mariadb/${BACKUP_TIMESTAMP}/metadata.sql"
              metadata_sha_file="/backup/mariadb/${BACKUP_TIMESTAMP}/metadata.sql.sha256"
              minio_dir="/backup/minio/${BACKUP_TIMESTAMP}"

              test "$BACKUP_TIMESTAMP" != "YYYYMMDDTHHMMSSZ"
              test -s "$metadata_file"
              test -d "$minio_dir"

              metadata_bytes="$(wc -c < "$metadata_file" | tr -d ' ')"
              metadata_sha256="$(sha256sum "$metadata_file" | awk '{print $1}')"
              object_count="$(find "$minio_dir" -type f | wc -l | tr -d ' ')"
              object_bytes="$(find "$minio_dir" -type f -exec wc -c {} \; | awk '{total += $1} END {print total + 0}')"

              if [ "$object_count" -eq 0 ] && [ "$ALLOW_EMPTY_MINIO" != "true" ]; then
                echo "OSMU_BACKUP_ARTIFACT_ERROR=minio mirror is empty"
                exit 12
              fi

              if [ -f "$metadata_sha_file" ]; then
                expected_sha256="$(awk '{print $1}' "$metadata_sha_file")"
                if [ "$expected_sha256" != "$metadata_sha256" ]; then
                  echo "OSMU_BACKUP_ARTIFACT_ERROR=metadata sha256 mismatch"
                  echo "OSMU_BACKUP_ARTIFACT_EXPECTED_METADATA_SHA256=$expected_sha256"
                  echo "OSMU_BACKUP_ARTIFACT_ACTUAL_METADATA_SHA256=$metadata_sha256"
                  exit 13
                fi
                echo "OSMU_BACKUP_ARTIFACT_METADATA_SHA256_FILE=present"
              else
                echo "OSMU_BACKUP_ARTIFACT_METADATA_SHA256_FILE=missing"
              fi

              echo "OSMU_BACKUP_ARTIFACT_PREFLIGHT_RESULT=passed"
              echo "OSMU_BACKUP_ARTIFACT_BACKUP_TIMESTAMP=$BACKUP_TIMESTAMP"
              echo "OSMU_BACKUP_ARTIFACT_METADATA_FILE=$metadata_file"
              echo "OSMU_BACKUP_ARTIFACT_METADATA_BYTES=$metadata_bytes"
              echo "OSMU_BACKUP_ARTIFACT_METADATA_SHA256=$metadata_sha256"
              echo "OSMU_BACKUP_ARTIFACT_MINIO_DIR=$minio_dir"
              echo "OSMU_BACKUP_ARTIFACT_OBJECT_COUNT=$object_count"
              echo "OSMU_BACKUP_ARTIFACT_OBJECT_BYTES=$object_bytes"
          env:
            - name: BACKUP_TIMESTAMP
              value: "__BACKUP_TIMESTAMP__"
            - name: ALLOW_EMPTY_MINIO
              value: "__ALLOW_EMPTY_MINIO__"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          volumeMounts:
            - name: backup-data
              mountPath: /backup
              readOnly: true
      volumes:
        - name: backup-data
          persistentVolumeClaim:
            claimName: osmu-backup-data
'@

    return $template.
        Replace("__JOB_NAME__", $jobName).
        Replace("__RESTORE_NAMESPACE__", $RestoreNamespace).
        Replace("__IMAGE__", $Image).
        Replace("__BACKUP_TIMESTAMP__", $BackupTimestamp).
        Replace("__ALLOW_EMPTY_MINIO__", $allowEmpty)
}

function Write-ArtifactPreflightManifest() {
    $manifestDirectory = Resolve-ProjectPath ".\.osmu-run\kubernetes-backup-artifact-preflights"
    if (-not (Test-Path -LiteralPath $manifestDirectory)) {
        New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
    }

    $manifestPath = Join-Path $manifestDirectory "$jobName.yaml"
    New-ArtifactPreflightManifestText | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    return $manifestPath
}

function Invoke-ServerDryRun([string] $ManifestPath) {
    $result = Invoke-KubectlRaw "artifact-preflight-server-dry-run" @("apply", "--server-side", "--dry-run=server", "-f", $ManifestPath)
    Add-Check "artifact-preflight-server-dry-run" ($result.exitCode -eq 0) "validated backup artifact preflight Job with Kubernetes API server." $result.command $result.exitCode $result.output
    return $result.exitCode -eq 0
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
        $passedMarker = $result.output.Contains("OSMU_BACKUP_ARTIFACT_PREFLIGHT_RESULT=passed")
        $logs += [pscustomobject]@{
            podName = $podName
            command = $result.command
            exitCode = $result.exitCode
            passedMarker = $passedMarker
            output = (Limit-Text $result.output)
        }
        Add-Check "logs-$podName" (($result.exitCode -eq 0) -and $passedMarker) "collected artifact preflight logs with pass marker." $result.command $result.exitCode $result.output
    }
    return $logs
}

function Invoke-ArtifactPreflightJob([string] $ManifestPath) {
    $apply = Invoke-KubectlRaw "apply-$jobName" @("apply", "-f", $ManifestPath)
    Add-Check "apply-$jobName" ($apply.exitCode -eq 0) "created read-only backup artifact preflight Job." $apply.command $apply.exitCode $apply.output
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
    Add-Check "wait-$jobName" ($wait.exitCode -eq 0) "waited for backup artifact preflight job completion." $wait.command $wait.exitCode $wait.output

    $jobSource = Read-KubeJson "job-$jobName" @("-n", $RestoreNamespace, "get", "job", $jobName, "-o", "json")
    $jobJson = if ($null -ne $jobSource) { $jobSource.json } else { $null }
    $pods = @(Get-JobPods $jobName)
    $logs = @(Get-PodLogs $pods)

    if ($CleanupJob) {
        $delete = Invoke-KubectlRaw "delete-$jobName" @("-n", $RestoreNamespace, "delete", "job", $jobName, "--ignore-not-found=true")
        Add-Check "delete-$jobName" ($delete.exitCode -eq 0) "deleted artifact preflight job after evidence collection." $delete.command $delete.exitCode $delete.output
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

function Test-PreflightPrerequisites() {
    Test-NamespaceReady
    Test-BackupPvcReady
    Test-ServiceAccountReady
}

function Get-PlanCommands() {
    $plannedManifestPath = ".\.osmu-run\kubernetes-backup-artifact-preflights\$jobName.yaml"
    $commands = @()
    $commands += ,@("get", "namespace", $RestoreNamespace, "-o", "json")
    $commands += ,@("-n", $RestoreNamespace, "get", "pvc", "osmu-backup-data", "-o", "json")
    $commands += ,@("-n", $RestoreNamespace, "get", "serviceaccount", "osmu-backup", "-o", "name")
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
    Write-Host "Kubernetes backup artifact preflight plan only."
    Write-Host "Restore namespace: $RestoreNamespace"
    Write-Host "Run ID: $RunId"
    Write-Host "Job name: $jobName"
    Write-Host "Backup timestamp: $BackupTimestamp"
    Write-Host "Image: $Image"
    Write-Host "Timeout seconds: $TimeoutSeconds"
    Write-Host "Allow empty MinIO mirror: $AllowEmptyMinio"
    Write-Host "Server dry-run only: $ServerDryRunOnly"
    Write-Host "Cleanup job: $CleanupJob"
    Write-Host "Checks: /backup/mariadb/$BackupTimestamp/metadata.sql, optional metadata.sql.sha256, and /backup/minio/$BackupTimestamp."
    foreach ($commandArguments in Get-PlanCommands) {
        Write-Host "[CHECK] $(Format-Command $commandArguments)"
    }
    Write-Host "Plan only; no artifact preflight Job created and no evidence file written."
    return
}

$manifestPath = Write-ArtifactPreflightManifest
Test-PreflightPrerequisites
$dryRunPassed = Invoke-ServerDryRun $manifestPath

$artifactPreflightJob = $null
if (-not $ServerDryRunOnly) {
    if ($dryRunPassed -and ($failureCount -eq 0)) {
        $artifactPreflightJob = Invoke-ArtifactPreflightJob $manifestPath
    }
    else {
        Add-Check "artifact-preflight-job-skipped" $false "artifact preflight Job was skipped because prerequisite checks or server-side dry-run failed." "" 0 ""
    }
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
}

$evidence = [pscustomobject]@{
    formatVersion = "osmu.kubernetes-backup-artifacts.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    restoreNamespace = $RestoreNamespace
    runId = $RunId
    jobName = $jobName
    backupTimestamp = $BackupTimestamp
    image = $Image
    kubectlPath = $KubectlPath
    timeoutSeconds = $TimeoutSeconds
    allowEmptyMinio = [bool] $AllowEmptyMinio
    serverDryRunOnly = [bool] $ServerDryRunOnly
    cleanupJob = [bool] $CleanupJob
    generatedManifestPath = $manifestPath
    result = if ($failureCount -eq 0) { "passed" } else { "failed" }
    failureCount = $failureCount
    secretPolicy = "Secret values are not copied into this backup artifact evidence."
    checkedPaths = @(
        "/backup/mariadb/$BackupTimestamp/metadata.sql",
        "/backup/mariadb/$BackupTimestamp/metadata.sql.sha256",
        "/backup/minio/$BackupTimestamp"
    )
    checks = $checks
    job = $artifactPreflightJob
}

$evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

if ($failureCount -ne 0) {
    Write-Host "Kubernetes backup artifact preflight evidence written with failures: $resolvedEvidencePath"
    throw "Kubernetes backup artifact preflight failed: $failureCount failed checks."
}

Write-Host "Kubernetes backup artifact preflight completed."
Write-Host "Evidence: $resolvedEvidencePath"
