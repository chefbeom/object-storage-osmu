param(
    [string] $Namespace = "osmu",
    [string] $KubectlPath = "kubectl",
    [string] $RunId = "",
    [string] $DrSecretName = "osmu-dr-transfer-secret",
    [string] $Image = "minio/mc:RELEASE.2025-05-21T01-59-54Z",
    [ValidateSet("GOVERNANCE_OR_COMPLIANCE", "COMPLIANCE")]
    [string] $RequiredRetentionMode = "GOVERNANCE_OR_COMPLIANCE",
    [string] $DrEgressCidr = "",
    [int] $DrEgressPort = 443,
    [int] $TimeoutSeconds = 300,
    [int] $ActiveDeadlineSeconds = 360,
    [int] $TtlSecondsAfterFinished = 3600,
    [string] $CpuRequest = "50m",
    [string] $MemoryRequest = "128Mi",
    [string] $CpuLimit = "250m",
    [string] $MemoryLimit = "256Mi",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-dr-bucket-immutability.json",
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

$jobName = "osmu-dr-bucket-immutability-$RunId"

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
    if ($TimeoutSeconds -le 0) {
        throw "TimeoutSeconds must be greater than zero."
    }
    if ($ActiveDeadlineSeconds -le 0) {
        throw "ActiveDeadlineSeconds must be greater than zero."
    }
    if ($TtlSecondsAfterFinished -lt 0) {
        throw "TtlSecondsAfterFinished must be zero or greater."
    }
    if ($DrEgressCidr -and $DrEgressCidr -notmatch "^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$") {
        throw "DrEgressCidr must be an IPv4 CIDR such as 203.0.113.10/32."
    }
}

function Test-NamespaceReady([string] $TargetNamespace) {
    $source = Read-KubeJson "namespace-$TargetNamespace" @("get", "namespace", $TargetNamespace, "-o", "json")
    if ($null -eq $source) {
        return
    }
    $phase = "$($source.json.status.phase)"
    Add-Check "namespace-$TargetNamespace-active" ($phase -eq "Active") "phase=$phase" $source.command 0 ""
}

function Test-ServiceAccountReady([string] $TargetNamespace) {
    $result = Invoke-KubectlRaw "serviceaccount-$TargetNamespace-osmu-backup" @("-n", $TargetNamespace, "get", "serviceaccount", "osmu-backup", "-o", "name")
    $passed = ($result.exitCode -eq 0) -and ($result.output.Trim() -eq "serviceaccount/osmu-backup")
    Add-Check "serviceaccount-$TargetNamespace-osmu-backup-exists" $passed "backup ServiceAccount exists." $result.command $result.exitCode $result.output
}

function Test-DrSecretReady([string] $TargetNamespace) {
    $source = Read-KubeJson "secret-$TargetNamespace-$DrSecretName" @("-n", $TargetNamespace, "get", "secret", $DrSecretName, "-o", "json")
    if ($null -eq $source) {
        return
    }
    $keys = @("DR_S3_ENDPOINT", "DR_S3_ACCESS_KEY", "DR_S3_SECRET_KEY", "DR_S3_BUCKET")
    foreach ($key in $keys) {
        $hasKey = $null -ne $source.json.data.PSObject.Properties[$key]
        Add-Check "secret-$TargetNamespace-$DrSecretName-$key" $hasKey "secret key exists; value is not read." $source.command 0 ""
    }
}

function New-DrEgressNetworkPolicyText([string] $TargetNamespace) {
    if (-not $DrEgressCidr) {
        return ""
    }

    $template = @'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: osmu-dr-bucket-immutability-egress
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/name: osmu-backup
    app.kubernetes.io/component: dr-bucket-immutability
    app.kubernetes.io/part-of: osmu
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: osmu-backup
      app.kubernetes.io/component: dr-bucket-immutability
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
        Replace("__NAMESPACE__", $TargetNamespace).
        Replace("__DR_EGRESS_CIDR__", $DrEgressCidr).
        Replace("__DR_EGRESS_PORT__", "$DrEgressPort")
}

function New-ImmutabilityJobText([string] $TargetNamespace) {
    $modePattern = if ($RequiredRetentionMode -eq "COMPLIANCE") { "COMPLIANCE" } else { "GOVERNANCE|COMPLIANCE" }
    $template = @'
apiVersion: batch/v1
kind: Job
metadata:
  name: __JOB_NAME__
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/name: osmu-backup
    app.kubernetes.io/component: dr-bucket-immutability
    app.kubernetes.io/part-of: osmu
spec:
  backoffLimit: 0
  activeDeadlineSeconds: __ACTIVE_DEADLINE_SECONDS__
  ttlSecondsAfterFinished: __TTL_SECONDS_AFTER_FINISHED__
  template:
    metadata:
      labels:
        app.kubernetes.io/name: osmu-backup
        app.kubernetes.io/component: dr-bucket-immutability
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
        - name: dr-bucket-immutability
          image: __IMAGE__
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
            - -ec
          args:
            - |
              mc alias set dr "$DR_S3_ENDPOINT" "$DR_S3_ACCESS_KEY" "$DR_S3_SECRET_KEY" --api S3v4 >/dev/null
              mc ls "dr/${DR_S3_BUCKET}" >/dev/null

              mc version info --json "dr/${DR_S3_BUCKET}" > /tmp/version.json
              mc retention info --json "dr/${DR_S3_BUCKET}" > /tmp/retention.json

              grep -E '"status"[[:space:]]*:[[:space:]]*"Enabled"|"versioning"[[:space:]]*:[[:space:]]*"Enabled"|Enabled' /tmp/version.json >/dev/null
              grep -E '"mode"[[:space:]]*:[[:space:]]*"(__MODE_PATTERN__)"|__MODE_PATTERN__' /tmp/retention.json >/dev/null

              echo "OSMU_DR_BUCKET_IMMUTABILITY_RESULT=passed"
              echo "OSMU_DR_BUCKET_VERSIONING=enabled"
              echo "OSMU_DR_BUCKET_RETENTION_MODE_REQUIREMENT=__REQUIRED_RETENTION_MODE__"
          env:
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
      volumes:
        - name: tmp
          emptyDir: {}
'@

    return $template.
        Replace("__JOB_NAME__", $jobName).
        Replace("__NAMESPACE__", $TargetNamespace).
        Replace("__IMAGE__", $Image).
        Replace("__DR_SECRET_NAME__", $DrSecretName).
        Replace("__REQUIRED_RETENTION_MODE__", $RequiredRetentionMode).
        Replace("__MODE_PATTERN__", $modePattern).
        Replace("__ACTIVE_DEADLINE_SECONDS__", "$ActiveDeadlineSeconds").
        Replace("__TTL_SECONDS_AFTER_FINISHED__", "$TtlSecondsAfterFinished").
        Replace("__CPU_REQUEST__", $CpuRequest).
        Replace("__MEMORY_REQUEST__", $MemoryRequest).
        Replace("__CPU_LIMIT__", $CpuLimit).
        Replace("__MEMORY_LIMIT__", $MemoryLimit)
}

function Write-Manifest() {
    $manifestDirectory = Resolve-ProjectPath ".\.osmu-run\kubernetes-dr-bucket-immutability"
    if (-not (Test-Path -LiteralPath $manifestDirectory)) {
        New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
    }

    $manifestPath = Join-Path $manifestDirectory "$jobName.yaml"
    $networkPolicy = New-DrEgressNetworkPolicyText $Namespace
    $job = New-ImmutabilityJobText $Namespace
    $manifest = if ($networkPolicy) { "$networkPolicy`n---`n$job" } else { $job }
    $manifest | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    return $manifestPath
}

function Invoke-ServerDryRun([string] $ManifestPath) {
    $result = Invoke-KubectlRaw "immutability-server-dry-run" @("apply", "--server-side", "--dry-run=server", "-f", $ManifestPath)
    Add-Check "immutability-server-dry-run" ($result.exitCode -eq 0) "validated DR bucket immutability Job with Kubernetes API server." $result.command $result.exitCode $result.output
    return $result.exitCode -eq 0
}

function Get-JobPods() {
    $source = Read-KubeJson "pods-$Namespace-$jobName" @("-n", $Namespace, "get", "pods", "-l", "job-name=$jobName", "-o", "json")
    if ($null -eq $source) {
        return @()
    }
    $items = @($source.json.items)
    Add-Check "pods-$Namespace-$jobName-found" ($items.Count -gt 0) "podCount=$($items.Count)" $source.command 0 ""
    return $items
}

function Get-PodLogs([object[]] $Pods) {
    $logs = @()
    foreach ($pod in $Pods) {
        $podName = "$($pod.metadata.name)"
        if (-not $podName) {
            continue
        }
        $result = Invoke-KubectlRaw "logs-$Namespace-$podName" @("-n", $Namespace, "logs", $podName, "--all-containers=true", "--tail=200")
        $passedMarker = $result.output.Contains("OSMU_DR_BUCKET_IMMUTABILITY_RESULT=passed")
        $logs += [pscustomobject]@{
            podName = $podName
            command = $result.command
            exitCode = $result.exitCode
            passedMarker = $passedMarker
            output = (Limit-Text $result.output)
        }
        Add-Check "logs-$Namespace-$podName" (($result.exitCode -eq 0) -and $passedMarker) "collected DR bucket immutability logs with pass marker." $result.command $result.exitCode $result.output
    }
    return $logs
}

function Invoke-ImmutabilityJob([string] $ManifestPath) {
    $apply = Invoke-KubectlRaw "apply-$Namespace-$jobName" @("apply", "-f", $ManifestPath)
    Add-Check "apply-$Namespace-$jobName" ($apply.exitCode -eq 0) "created DR bucket immutability Job." $apply.command $apply.exitCode $apply.output
    if ($apply.exitCode -ne 0) {
        return [pscustomobject]@{
            namespace = $Namespace
            jobName = $jobName
            result = "failed"
            reason = "Job apply failed."
            logs = @()
        }
    }

    $wait = Invoke-KubectlRaw "wait-$Namespace-$jobName" @("-n", $Namespace, "wait", "--for=condition=complete", "--timeout=$($TimeoutSeconds)s", "job/$jobName")
    Add-Check "wait-$Namespace-$jobName" ($wait.exitCode -eq 0) "waited for DR bucket immutability job completion." $wait.command $wait.exitCode $wait.output

    $jobSource = Read-KubeJson "job-$Namespace-$jobName" @("-n", $Namespace, "get", "job", $jobName, "-o", "json")
    $jobJson = if ($null -ne $jobSource) { $jobSource.json } else { $null }
    $pods = @(Get-JobPods)
    $logs = @(Get-PodLogs $pods)

    if ($CleanupJob) {
        $delete = Invoke-KubectlRaw "delete-$Namespace-$jobName" @("-n", $Namespace, "delete", "job", $jobName, "--ignore-not-found=true")
        Add-Check "delete-$Namespace-$jobName" ($delete.exitCode -eq 0) "deleted DR bucket immutability job after evidence collection." $delete.command $delete.exitCode $delete.output
    }

    return [pscustomobject]@{
        namespace = $Namespace
        jobName = $jobName
        result = if ($wait.exitCode -eq 0) { "completed" } else { "failed" }
        applyCommand = $apply.command
        waitCommand = $wait.command
        job = $jobJson
        pods = $pods
        logs = $logs
    }
}

function Test-Prerequisites() {
    Test-NamespaceReady $Namespace
    Test-ServiceAccountReady $Namespace
    Test-DrSecretReady $Namespace
}

function Get-PlanCommands() {
    $commands = @(
        @("get", "namespace", $Namespace, "-o", "json"),
        @("-n", $Namespace, "get", "serviceaccount", "osmu-backup", "-o", "name"),
        @("-n", $Namespace, "get", "secret", $DrSecretName, "-o", "json"),
        @("apply", "--server-side", "--dry-run=server", "-f", ".\.osmu-run\kubernetes-dr-bucket-immutability\$jobName.yaml")
    )
    if (-not $ServerDryRunOnly) {
        $commands += ,@("apply", "-f", ".\.osmu-run\kubernetes-dr-bucket-immutability\$jobName.yaml")
        $commands += ,@("-n", $Namespace, "wait", "--for=condition=complete", "--timeout=$($TimeoutSeconds)s", "job/$jobName")
    }
    return $commands
}

Assert-InputsAreSafe

if ($PlanOnly) {
    Write-Host "Kubernetes DR bucket immutability plan only."
    Write-Host "Namespace: $Namespace"
    Write-Host "Run ID: $RunId"
    Write-Host "Job name: $jobName"
    Write-Host "DR transfer secret: $DrSecretName"
    Write-Host "Required retention mode: $RequiredRetentionMode"
    Write-Host "DR egress CIDR: $DrEgressCidr"
    Write-Host "Server dry-run only: $ServerDryRunOnly"
    Write-Host "Job active deadline seconds: $ActiveDeadlineSeconds"
    Write-Host "Job TTL seconds after finished: $TtlSecondsAfterFinished"
    Write-Host "Job resources: requests cpu=$CpuRequest memory=$MemoryRequest, limits cpu=$CpuLimit memory=$MemoryLimit"
    Write-Host "Secret keys required: DR_S3_ENDPOINT, DR_S3_ACCESS_KEY, DR_S3_SECRET_KEY, DR_S3_BUCKET."
    Write-Host "Secret values are not copied into manifests, logs, or evidence; the Job reads them through Kubernetes Secret references."
    Write-Host "Live check requires bucket versioning enabled and default retention mode matching $RequiredRetentionMode."
    foreach ($commandArguments in Get-PlanCommands) {
        Write-Host "[CHECK] $(Format-Command $commandArguments)"
    }
    Write-Host "Plan only; no immutability Job, NetworkPolicy, or evidence file is written."
    return
}

$manifestPath = Write-Manifest
Test-Prerequisites
$serverDryRunPassed = Invoke-ServerDryRun $manifestPath
$job = $null
if ((-not $ServerDryRunOnly) -and $serverDryRunPassed -and ($failureCount -eq 0)) {
    $job = Invoke-ImmutabilityJob $manifestPath
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
}

$evidence = [pscustomobject]@{
    formatVersion = "osmu.kubernetes-dr-bucket-immutability.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    namespace = $Namespace
    runId = $RunId
    jobName = $jobName
    kubectlPath = $KubectlPath
    image = $Image
    drSecretName = $DrSecretName
    requiredRetentionMode = $RequiredRetentionMode
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
    drEgressCidrConfigured = [bool] $DrEgressCidr
    drEgressPort = $DrEgressPort
    serverDryRunOnly = [bool] $ServerDryRunOnly
    cleanupJob = [bool] $CleanupJob
    generatedManifestPath = $manifestPath
    result = if ($failureCount -eq 0) { "passed" } else { "failed" }
    failureCount = $failureCount
    secretPolicy = "DR S3 endpoint, access key, secret key, and bucket are read from Kubernetes Secret references and are not copied into evidence."
    immutabilityPolicy = "Live Job checks that the external DR bucket exists, bucket versioning is enabled, and default object-lock retention mode matches the required mode."
    checks = $checks
    job = $job
}

$evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

if ($failureCount -ne 0) {
    Write-Host "Kubernetes DR bucket immutability evidence written with failures: $resolvedEvidencePath"
    throw "Kubernetes DR bucket immutability check failed: $failureCount failed checks."
}

Write-Host "Kubernetes DR bucket immutability check completed."
Write-Host "Evidence: $resolvedEvidencePath"
