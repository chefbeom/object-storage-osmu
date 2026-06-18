param(
    [ValidateSet("Export", "Import", "ExportImport")]
    [string] $Mode = "ExportImport",
    [string] $SourceNamespace = "osmu",
    [string] $RestoreNamespace = "osmu-restore-drill",
    [string] $KubectlPath = "kubectl",
    [string] $RunId = "",
    [string] $BackupTimestamp = "YYYYMMDDTHHMMSSZ",
    [string] $DrSecretName = "osmu-dr-transfer-secret",
    [string] $RemotePrefix = "osmu",
    [string] $Image = "minio/mc:RELEASE.2025-05-21T01-59-54Z",
    [string] $DrEgressCidr = "",
    [int] $DrEgressPort = 443,
    [int] $TimeoutSeconds = 900,
    [int] $ActiveDeadlineSeconds = 960,
    [int] $TtlSecondsAfterFinished = 3600,
    [string] $CpuRequest = "100m",
    [string] $MemoryRequest = "256Mi",
    [string] $CpuLimit = "500m",
    [string] $MemoryLimit = "512Mi",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-backup-artifact-transfer.json",
    [switch] $ServerDryRunOnly,
    [switch] $CleanupJobs,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()
$failureCount = 0

if (-not $RunId) {
    $RunId = [DateTimeOffset]::UtcNow.ToString("yyyyMMddHHmmss")
}

$exportJobName = "osmu-backup-artifact-export-$RunId"
$importJobName = "osmu-backup-artifact-import-$RunId"

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

function Test-ModeIncludesExport() {
    return $Mode -in @("Export", "ExportImport")
}

function Test-ModeIncludesImport() {
    return $Mode -in @("Import", "ExportImport")
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
    Assert-KubernetesQuantity "CpuRequest" $CpuRequest
    Assert-KubernetesQuantity "MemoryRequest" $MemoryRequest
    Assert-KubernetesQuantity "CpuLimit" $CpuLimit
    Assert-KubernetesQuantity "MemoryLimit" $MemoryLimit
    if ($ActiveDeadlineSeconds -le 0) {
        throw "ActiveDeadlineSeconds must be greater than zero."
    }
    if ($TtlSecondsAfterFinished -lt 0) {
        throw "TtlSecondsAfterFinished must be zero or greater."
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
    if ((Test-ModeIncludesImport) -and $SourceNamespace -eq $RestoreNamespace) {
        throw "RestoreNamespace must differ from SourceNamespace for import or export-import mode."
    }
    if ($DrEgressCidr -and $DrEgressCidr -notmatch "^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$") {
        throw "DrEgressCidr must be an IPv4 CIDR such as 203.0.113.10/32."
    }
}

function Test-NamespaceReady([string] $Namespace) {
    $source = Read-KubeJson "namespace-$Namespace" @("get", "namespace", $Namespace, "-o", "json")
    if ($null -eq $source) {
        return
    }
    $phase = "$($source.json.status.phase)"
    Add-Check "namespace-$Namespace-active" ($phase -eq "Active") "phase=$phase" $source.command 0 ""
}

function Test-BackupPvcReady([string] $Namespace) {
    $source = Read-KubeJson "pvc-$Namespace-osmu-backup-data" @("-n", $Namespace, "get", "pvc", "osmu-backup-data", "-o", "json")
    if ($null -eq $source) {
        return
    }
    $phase = "$($source.json.status.phase)"
    Add-Check "pvc-$Namespace-osmu-backup-data-bound" ($phase -eq "Bound") "phase=$phase" $source.command 0 ""
}

function Test-ServiceAccountReady([string] $Namespace) {
    $result = Invoke-KubectlRaw "serviceaccount-$Namespace-osmu-backup" @("-n", $Namespace, "get", "serviceaccount", "osmu-backup", "-o", "name")
    $passed = ($result.exitCode -eq 0) -and ($result.output.Trim() -eq "serviceaccount/osmu-backup")
    Add-Check "serviceaccount-$Namespace-osmu-backup-exists" $passed "backup ServiceAccount exists." $result.command $result.exitCode $result.output
}

function Test-DrSecretReady([string] $Namespace) {
    $source = Read-KubeJson "secret-$Namespace-$DrSecretName" @("-n", $Namespace, "get", "secret", $DrSecretName, "-o", "json")
    if ($null -eq $source) {
        return
    }
    $keys = @("DR_S3_ENDPOINT", "DR_S3_ACCESS_KEY", "DR_S3_SECRET_KEY", "DR_S3_BUCKET")
    foreach ($key in $keys) {
        $hasKey = $null -ne $source.json.data.PSObject.Properties[$key]
        Add-Check "secret-$Namespace-$DrSecretName-$key" $hasKey "secret key exists; value is not read." $source.command 0 ""
    }
}

function New-DrEgressNetworkPolicyText([string] $Namespace) {
    if (-not $DrEgressCidr) {
        return ""
    }

    $template = @'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: osmu-dr-transfer-egress
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/name: osmu-backup
    app.kubernetes.io/component: dr-transfer
    app.kubernetes.io/part-of: osmu
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: osmu-backup
      app.kubernetes.io/component: dr-transfer
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: __DR_EGRESS_CIDR__
      ports:
        - protocol: TCP
          port: __DR_EGRESS_PORT__
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
'@

    return $template.
        Replace("__NAMESPACE__", $Namespace).
        Replace("__DR_EGRESS_CIDR__", $DrEgressCidr).
        Replace("__DR_EGRESS_PORT__", "$DrEgressPort")
}

function New-TransferJobText([string] $Namespace, [string] $JobName, [string] $Direction) {
    $marker = if ($Direction -eq "export") { "OSMU_BACKUP_TRANSFER_EXPORT_RESULT=passed" } else { "OSMU_BACKUP_TRANSFER_IMPORT_RESULT=passed" }
    $component = if ($Direction -eq "export") { "backup-artifact-export" } else { "backup-artifact-import" }
    $backupReadOnly = if ($Direction -eq "export") { "true" } else { "false" }
    $script = if ($Direction -eq "export") {
@'
              test "$BACKUP_TIMESTAMP" != "YYYYMMDDTHHMMSSZ"
              test -s "/backup/mariadb/${BACKUP_TIMESTAMP}/metadata.sql"
              test -d "/backup/minio/${BACKUP_TIMESTAMP}"

              remote_base="dr/${DR_S3_BUCKET}/${REMOTE_PREFIX}/${BACKUP_TIMESTAMP}"
              mc alias set dr "$DR_S3_ENDPOINT" "$DR_S3_ACCESS_KEY" "$DR_S3_SECRET_KEY" --api S3v4 >/dev/null
              mc ls "dr/${DR_S3_BUCKET}" >/dev/null
              mc mirror --overwrite "/backup/mariadb/${BACKUP_TIMESTAMP}" "${remote_base}/mariadb"
              mc mirror --overwrite "/backup/minio/${BACKUP_TIMESTAMP}" "${remote_base}/minio"

              object_count="$(find "/backup/minio/${BACKUP_TIMESTAMP}" -type f | wc -l | tr -d ' ')"
              object_bytes="$(find "/backup/minio/${BACKUP_TIMESTAMP}" -type f -exec wc -c {} \; | awk '{total += $1} END {print total + 0}')"
              metadata_sha256="$(sha256sum "/backup/mariadb/${BACKUP_TIMESTAMP}/metadata.sql" | awk '{print $1}')"
              echo "OSMU_BACKUP_TRANSFER_EXPORT_RESULT=passed"
              echo "OSMU_BACKUP_TRANSFER_BACKUP_TIMESTAMP=${BACKUP_TIMESTAMP}"
              echo "OSMU_BACKUP_TRANSFER_REMOTE_PREFIX=${REMOTE_PREFIX}"
              echo "OSMU_BACKUP_TRANSFER_METADATA_SHA256=${metadata_sha256}"
              echo "OSMU_BACKUP_TRANSFER_OBJECT_COUNT=${object_count}"
              echo "OSMU_BACKUP_TRANSFER_OBJECT_BYTES=${object_bytes}"
'@
    }
    else {
@'
              test "$BACKUP_TIMESTAMP" != "YYYYMMDDTHHMMSSZ"
              remote_base="dr/${DR_S3_BUCKET}/${REMOTE_PREFIX}/${BACKUP_TIMESTAMP}"
              mkdir -p "/backup/mariadb/${BACKUP_TIMESTAMP}" "/backup/minio/${BACKUP_TIMESTAMP}"
              mc alias set dr "$DR_S3_ENDPOINT" "$DR_S3_ACCESS_KEY" "$DR_S3_SECRET_KEY" --api S3v4 >/dev/null
              mc mirror --overwrite "${remote_base}/mariadb" "/backup/mariadb/${BACKUP_TIMESTAMP}"
              mc mirror --overwrite "${remote_base}/minio" "/backup/minio/${BACKUP_TIMESTAMP}"
              test -s "/backup/mariadb/${BACKUP_TIMESTAMP}/metadata.sql"
              test -d "/backup/minio/${BACKUP_TIMESTAMP}"

              object_count="$(find "/backup/minio/${BACKUP_TIMESTAMP}" -type f | wc -l | tr -d ' ')"
              object_bytes="$(find "/backup/minio/${BACKUP_TIMESTAMP}" -type f -exec wc -c {} \; | awk '{total += $1} END {print total + 0}')"
              metadata_sha256="$(sha256sum "/backup/mariadb/${BACKUP_TIMESTAMP}/metadata.sql" | awk '{print $1}')"
              echo "OSMU_BACKUP_TRANSFER_IMPORT_RESULT=passed"
              echo "OSMU_BACKUP_TRANSFER_BACKUP_TIMESTAMP=${BACKUP_TIMESTAMP}"
              echo "OSMU_BACKUP_TRANSFER_REMOTE_PREFIX=${REMOTE_PREFIX}"
              echo "OSMU_BACKUP_TRANSFER_METADATA_SHA256=${metadata_sha256}"
              echo "OSMU_BACKUP_TRANSFER_OBJECT_COUNT=${object_count}"
              echo "OSMU_BACKUP_TRANSFER_OBJECT_BYTES=${object_bytes}"
'@
    }

    $template = @'
apiVersion: batch/v1
kind: Job
metadata:
  name: __JOB_NAME__
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/name: osmu-backup
    app.kubernetes.io/component: __COMPONENT__
    app.kubernetes.io/part-of: osmu
spec:
  backoffLimit: 0
  activeDeadlineSeconds: __ACTIVE_DEADLINE_SECONDS__
  ttlSecondsAfterFinished: __TTL_SECONDS_AFTER_FINISHED__
  template:
    metadata:
      labels:
        app.kubernetes.io/name: osmu-backup
        app.kubernetes.io/component: dr-transfer
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
        - name: dr-transfer
          image: __IMAGE__
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
            - -ec
          args:
            - |
__SCRIPT__
          env:
            - name: BACKUP_TIMESTAMP
              value: "__BACKUP_TIMESTAMP__"
            - name: REMOTE_PREFIX
              value: "__REMOTE_PREFIX__"
            - name: MC_CONFIG_DIR
              value: /tmp/.mc
            - name: DR_S3_ENDPOINT
              valueFrom:
                secretKeyRef:
                  name: __DR_SECRET_NAME__
                  key: DR_S3_ENDPOINT
            - name: DR_S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: __DR_SECRET_NAME__
                  key: DR_S3_ACCESS_KEY
            - name: DR_S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: __DR_SECRET_NAME__
                  key: DR_S3_SECRET_KEY
            - name: DR_S3_BUCKET
              valueFrom:
                secretKeyRef:
                  name: __DR_SECRET_NAME__
                  key: DR_S3_BUCKET
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          resources:
            requests:
              cpu: "__CPU_REQUEST__"
              memory: "__MEMORY_REQUEST__"
            limits:
              cpu: "__CPU_LIMIT__"
              memory: "__MEMORY_LIMIT__"
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: backup-data
              mountPath: /backup
              readOnly: __BACKUP_READ_ONLY__
      volumes:
        - name: tmp
          emptyDir: {}
        - name: backup-data
          persistentVolumeClaim:
            claimName: osmu-backup-data
'@

    $indentedScript = (($script -split "`n") | ForEach-Object { "              $_" }) -join "`n"
    return $template.
        Replace("__JOB_NAME__", $JobName).
        Replace("__NAMESPACE__", $Namespace).
        Replace("__COMPONENT__", $component).
        Replace("__IMAGE__", $Image).
        Replace("__SCRIPT__", $indentedScript).
        Replace("__BACKUP_TIMESTAMP__", $BackupTimestamp).
        Replace("__ACTIVE_DEADLINE_SECONDS__", "$ActiveDeadlineSeconds").
        Replace("__TTL_SECONDS_AFTER_FINISHED__", "$TtlSecondsAfterFinished").
        Replace("__CPU_REQUEST__", $CpuRequest).
        Replace("__MEMORY_REQUEST__", $MemoryRequest).
        Replace("__CPU_LIMIT__", $CpuLimit).
        Replace("__MEMORY_LIMIT__", $MemoryLimit).
        Replace("__REMOTE_PREFIX__", $RemotePrefix.Trim("/")).
        Replace("__BACKUP_READ_ONLY__", $backupReadOnly).
        Replace("__DR_SECRET_NAME__", $DrSecretName)
}

function Write-Manifest([string] $Namespace, [string] $JobName, [string] $Direction) {
    $manifestDirectory = Resolve-ProjectPath ".\.osmu-run\kubernetes-backup-artifact-transfers"
    if (-not (Test-Path -LiteralPath $manifestDirectory)) {
        New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
    }

    $manifestPath = Join-Path $manifestDirectory "$JobName.yaml"
    $networkPolicy = New-DrEgressNetworkPolicyText $Namespace
    $job = New-TransferJobText $Namespace $JobName $Direction
    $manifest = if ($networkPolicy) { "$networkPolicy`n---`n$job" } else { $job }
    $manifest | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    return $manifestPath
}

function Invoke-ServerDryRun([string] $Name, [string] $ManifestPath) {
    $result = Invoke-KubectlRaw "$Name-server-dry-run" @("apply", "--server-side", "--dry-run=server", "-f", $ManifestPath)
    Add-Check "$Name-server-dry-run" ($result.exitCode -eq 0) "validated DR artifact transfer manifest with Kubernetes API server." $result.command $result.exitCode $result.output
    return $result.exitCode -eq 0
}

function Get-JobPods([string] $Namespace, [string] $JobName) {
    $source = Read-KubeJson "pods-$Namespace-$JobName" @("-n", $Namespace, "get", "pods", "-l", "job-name=$JobName", "-o", "json")
    if ($null -eq $source) {
        return @()
    }
    $items = @($source.json.items)
    Add-Check "pods-$Namespace-$JobName-found" ($items.Count -gt 0) "podCount=$($items.Count)" $source.command 0 ""
    return $items
}

function Get-PodLogs([string] $Namespace, [object[]] $Pods, [string] $Marker) {
    $logs = @()
    foreach ($pod in $Pods) {
        $podName = "$($pod.metadata.name)"
        if (-not $podName) {
            continue
        }
        $result = Invoke-KubectlRaw "logs-$Namespace-$podName" @("-n", $Namespace, "logs", $podName, "--all-containers=true", "--tail=200")
        $passedMarker = $result.output.Contains($Marker)
        $logs += [pscustomobject]@{
            podName = $podName
            command = $result.command
            exitCode = $result.exitCode
            passedMarker = $passedMarker
            output = (Limit-Text $result.output)
        }
        Add-Check "logs-$Namespace-$podName" (($result.exitCode -eq 0) -and $passedMarker) "collected DR transfer logs with pass marker." $result.command $result.exitCode $result.output
    }
    return $logs
}

function Invoke-TransferJob([string] $Namespace, [string] $JobName, [string] $ManifestPath, [string] $Marker) {
    $apply = Invoke-KubectlRaw "apply-$Namespace-$JobName" @("apply", "-f", $ManifestPath)
    Add-Check "apply-$Namespace-$JobName" ($apply.exitCode -eq 0) "created DR artifact transfer Job." $apply.command $apply.exitCode $apply.output
    if ($apply.exitCode -ne 0) {
        return [pscustomobject]@{
            namespace = $Namespace
            jobName = $JobName
            result = "failed"
            reason = "Job apply failed."
            logs = @()
        }
    }

    $wait = Invoke-KubectlRaw "wait-$Namespace-$JobName" @("-n", $Namespace, "wait", "--for=condition=complete", "--timeout=$($TimeoutSeconds)s", "job/$JobName")
    Add-Check "wait-$Namespace-$JobName" ($wait.exitCode -eq 0) "waited for DR transfer job completion." $wait.command $wait.exitCode $wait.output

    $jobSource = Read-KubeJson "job-$Namespace-$JobName" @("-n", $Namespace, "get", "job", $JobName, "-o", "json")
    $jobJson = if ($null -ne $jobSource) { $jobSource.json } else { $null }
    $pods = @(Get-JobPods $Namespace $JobName)
    $logs = @(Get-PodLogs $Namespace $pods $Marker)

    if ($CleanupJobs) {
        $delete = Invoke-KubectlRaw "delete-$Namespace-$JobName" @("-n", $Namespace, "delete", "job", $JobName, "--ignore-not-found=true")
        Add-Check "delete-$Namespace-$JobName" ($delete.exitCode -eq 0) "deleted DR transfer job after evidence collection." $delete.command $delete.exitCode $delete.output
    }

    return [pscustomobject]@{
        namespace = $Namespace
        jobName = $JobName
        result = if ($wait.exitCode -eq 0) { "completed" } else { "failed" }
        applyCommand = $apply.command
        waitCommand = $wait.command
        job = $jobJson
        pods = $pods
        logs = $logs
    }
}

function Test-Prerequisites([string] $Namespace) {
    Test-NamespaceReady $Namespace
    Test-BackupPvcReady $Namespace
    Test-ServiceAccountReady $Namespace
    Test-DrSecretReady $Namespace
}

function Get-PlanCommands() {
    $commands = @()
    if (Test-ModeIncludesExport) {
        $commands += ,@("get", "namespace", $SourceNamespace, "-o", "json")
        $commands += ,@("-n", $SourceNamespace, "get", "pvc", "osmu-backup-data", "-o", "json")
        $commands += ,@("-n", $SourceNamespace, "get", "secret", $DrSecretName, "-o", "json")
        $commands += ,@("apply", "--server-side", "--dry-run=server", "-f", ".\.osmu-run\kubernetes-backup-artifact-transfers\$exportJobName.yaml")
        if (-not $ServerDryRunOnly) {
            $commands += ,@("apply", "-f", ".\.osmu-run\kubernetes-backup-artifact-transfers\$exportJobName.yaml")
            $commands += ,@("-n", $SourceNamespace, "wait", "--for=condition=complete", "--timeout=$($TimeoutSeconds)s", "job/$exportJobName")
        }
    }
    if (Test-ModeIncludesImport) {
        $commands += ,@("get", "namespace", $RestoreNamespace, "-o", "json")
        $commands += ,@("-n", $RestoreNamespace, "get", "pvc", "osmu-backup-data", "-o", "json")
        $commands += ,@("-n", $RestoreNamespace, "get", "secret", $DrSecretName, "-o", "json")
        $commands += ,@("apply", "--server-side", "--dry-run=server", "-f", ".\.osmu-run\kubernetes-backup-artifact-transfers\$importJobName.yaml")
        if (-not $ServerDryRunOnly) {
            $commands += ,@("apply", "-f", ".\.osmu-run\kubernetes-backup-artifact-transfers\$importJobName.yaml")
            $commands += ,@("-n", $RestoreNamespace, "wait", "--for=condition=complete", "--timeout=$($TimeoutSeconds)s", "job/$importJobName")
        }
    }
    return $commands
}

Assert-InputsAreSafe

if ($PlanOnly) {
    Write-Host "Kubernetes backup artifact transfer plan only."
    Write-Host "Mode: $Mode"
    Write-Host "Source namespace: $SourceNamespace"
    Write-Host "Restore namespace: $RestoreNamespace"
    Write-Host "Run ID: $RunId"
    Write-Host "Backup timestamp: $BackupTimestamp"
    Write-Host "DR transfer secret: $DrSecretName"
    Write-Host "Remote prefix: $RemotePrefix"
    Write-Host "DR egress CIDR: $DrEgressCidr"
    Write-Host "Server dry-run only: $ServerDryRunOnly"
    Write-Host "Job active deadline seconds: $ActiveDeadlineSeconds"
    Write-Host "Job TTL seconds after finished: $TtlSecondsAfterFinished"
    Write-Host "Job resources: requests cpu=$CpuRequest memory=$MemoryRequest, limits cpu=$CpuLimit memory=$MemoryLimit"
    Write-Host "Secret keys required in each active namespace: DR_S3_ENDPOINT, DR_S3_ACCESS_KEY, DR_S3_SECRET_KEY, DR_S3_BUCKET."
    Write-Host "Secret values are not copied into manifests, logs, or evidence; Jobs read them through Kubernetes Secret references."
    foreach ($commandArguments in Get-PlanCommands) {
        Write-Host "[CHECK] $(Format-Command $commandArguments)"
    }
    Write-Host "Plan only; no transfer Job, NetworkPolicy, or evidence file is written."
    return
}

$exportManifestPath = ""
$importManifestPath = ""
$exportJob = $null
$importJob = $null

if (Test-ModeIncludesExport) {
    $exportManifestPath = Write-Manifest $SourceNamespace $exportJobName "export"
    Test-Prerequisites $SourceNamespace
    $exportDryRunPassed = Invoke-ServerDryRun "export" $exportManifestPath
    if ((-not $ServerDryRunOnly) -and $exportDryRunPassed -and ($failureCount -eq 0)) {
        $exportJob = Invoke-TransferJob $SourceNamespace $exportJobName $exportManifestPath "OSMU_BACKUP_TRANSFER_EXPORT_RESULT=passed"
    }
}

if (Test-ModeIncludesImport) {
    $importManifestPath = Write-Manifest $RestoreNamespace $importJobName "import"
    Test-Prerequisites $RestoreNamespace
    $importDryRunPassed = Invoke-ServerDryRun "import" $importManifestPath
    if ((-not $ServerDryRunOnly) -and $importDryRunPassed -and ($failureCount -eq 0)) {
        $importJob = Invoke-TransferJob $RestoreNamespace $importJobName $importManifestPath "OSMU_BACKUP_TRANSFER_IMPORT_RESULT=passed"
    }
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
}

$evidence = [pscustomobject]@{
    formatVersion = "osmu.kubernetes-backup-artifact-transfer.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    mode = $Mode
    sourceNamespace = $SourceNamespace
    restoreNamespace = $RestoreNamespace
    runId = $RunId
    backupTimestamp = $BackupTimestamp
    kubectlPath = $KubectlPath
    timeoutSeconds = $TimeoutSeconds
    activeDeadlineSeconds = $ActiveDeadlineSeconds
    ttlSecondsAfterFinished = $TtlSecondsAfterFinished
    resources = [pscustomobject]@{
        requests = [pscustomobject]@{
            cpu = $CpuRequest
            memory = $MemoryRequest
        }
        limits = [pscustomobject]@{
            cpu = $CpuLimit
            memory = $MemoryLimit
        }
    }
    image = $Image
    drSecretName = $DrSecretName
    remotePrefix = $RemotePrefix
    remotePath = "<DR_S3_BUCKET secret>/$($RemotePrefix.Trim("/"))/$BackupTimestamp"
    drEgressCidrConfigured = [bool] $DrEgressCidr
    drEgressPort = $DrEgressPort
    serverDryRunOnly = [bool] $ServerDryRunOnly
    cleanupJobs = [bool] $CleanupJobs
    generatedManifestPaths = @{
        export = $exportManifestPath
        import = $importManifestPath
    }
    result = if ($failureCount -eq 0) { "passed" } else { "failed" }
    failureCount = $failureCount
    secretPolicy = "DR S3 endpoint, access key, secret key, and bucket are read from Kubernetes Secret references and are not copied into evidence."
    transferPolicy = "Artifacts are exported from the source backup PVC to external S3-compatible DR storage and imported into the restore namespace backup PVC. Export mounts the backup PVC read-only; import mounts it read-write. Transfer Jobs have resource requests/limits, active deadline, TTL cleanup, read-only root filesystem, and writable /tmp emptyDir for mc config."
    checks = $checks
    jobs = @{
        export = $exportJob
        import = $importJob
    }
}

$evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

if ($failureCount -ne 0) {
    Write-Host "Kubernetes backup artifact transfer evidence written with failures: $resolvedEvidencePath"
    throw "Kubernetes backup artifact transfer failed: $failureCount failed checks."
}

Write-Host "Kubernetes backup artifact transfer completed."
Write-Host "Evidence: $resolvedEvidencePath"
