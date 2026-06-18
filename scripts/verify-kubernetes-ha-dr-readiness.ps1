param(
    [string] $Namespace = "osmu",
    [string] $KubectlPath = "kubectl",
    [string] $RestoreManifestPath = ".\infra\k8s\examples\restore-from-backup.example.yaml",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-ha-dr-readiness.json",
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()
$failureCount = 0
$tempRestoreManifest = $null

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
    if ($text.Length -le 4000) {
        return $text
    }
    return $text.Substring(0, 4000) + "`n...truncated..."
}

function Add-Check(
    [string] $Name,
    [string] $Category,
    [bool] $Passed,
    [string] $Summary,
    [string] $Command = "",
    [int] $ExitCode = 0,
    [string] $Output = ""
) {
    $script:checks += [pscustomobject]@{
        name = $Name
        category = $Category
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
        Add-Check $Name "kubectl" $false "kubectl command failed." $result.command $result.exitCode $result.output
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
        Add-Check $Name "kubectl" $false "kubectl returned invalid JSON: $($_.Exception.Message)" $result.command $result.exitCode $result.output
        return $null
    }
}

function Get-IntOrZero($value) {
    if ($null -eq $value) {
        return 0
    }
    return [int] $value
}

function Test-Deployment([string] $Name, [int] $MinimumReplicas) {
    $source = Read-KubeJson "deployment-$Name" @("-n", $Namespace, "get", "deployment", $Name, "-o", "json")
    if ($null -eq $source) {
        return
    }

    $deployment = $source.json
    $desired = Get-IntOrZero $deployment.spec.replicas
    $ready = Get-IntOrZero $deployment.status.readyReplicas
    $available = Get-IntOrZero $deployment.status.availableReplicas
    $hasSpread = $null -ne $deployment.spec.template.spec.topologySpreadConstraints
    $passed = ($desired -ge $MinimumReplicas) -and ($ready -ge $MinimumReplicas) -and ($available -ge $MinimumReplicas) -and $hasSpread
    $summary = "desired=$desired ready=$ready available=$available minimum=$MinimumReplicas topologySpread=$hasSpread"
    Add-Check "deployment-$Name-ready" "ha" $passed $summary $source.command 0 ""
}

function Test-StatefulSet([string] $Name) {
    $source = Read-KubeJson "statefulset-$Name" @("-n", $Namespace, "get", "statefulset", $Name, "-o", "json")
    if ($null -eq $source) {
        return
    }

    $statefulSet = $source.json
    $desired = Get-IntOrZero $statefulSet.spec.replicas
    $ready = Get-IntOrZero $statefulSet.status.readyReplicas
    $current = Get-IntOrZero $statefulSet.status.currentReplicas
    $passed = ($desired -ge 1) -and ($ready -ge 1)
    $summary = "desired=$desired ready=$ready current=$current"
    Add-Check "statefulset-$Name-ready" "ha" $passed $summary $source.command 0 ""
}

function Test-PodDisruptionBudget([string] $Name, [int] $MinimumDisruptionsAllowed) {
    $source = Read-KubeJson "pdb-$Name" @("-n", $Namespace, "get", "pdb", $Name, "-o", "json")
    if ($null -eq $source) {
        return
    }

    $pdb = $source.json
    $minAvailable = "$($pdb.spec.minAvailable)"
    $currentHealthy = Get-IntOrZero $pdb.status.currentHealthy
    $desiredHealthy = Get-IntOrZero $pdb.status.desiredHealthy
    $disruptionsAllowed = Get-IntOrZero $pdb.status.disruptionsAllowed
    $passed = ($minAvailable -eq "1") -and ($currentHealthy -ge 1) -and ($disruptionsAllowed -ge $MinimumDisruptionsAllowed)
    $summary = "minAvailable=$minAvailable currentHealthy=$currentHealthy desiredHealthy=$desiredHealthy disruptionsAllowed=$disruptionsAllowed expectedDisruptionsAllowedAtLeast=$MinimumDisruptionsAllowed"
    Add-Check "pdb-$Name-effective" "ha" $passed $summary $source.command 0 ""
}

function Test-PersistentVolumeClaim([string] $Name) {
    $source = Read-KubeJson "pvc-$Name" @("-n", $Namespace, "get", "pvc", $Name, "-o", "json")
    if ($null -eq $source) {
        return
    }

    $pvc = $source.json
    $phase = "$($pvc.status.phase)"
    $storage = "$($pvc.spec.resources.requests.storage)"
    $passed = $phase -eq "Bound"
    Add-Check "pvc-$Name-bound" "dr" $passed "phase=$phase storage=$storage" $source.command 0 ""
}

function Test-CronJob([string] $Name) {
    $source = Read-KubeJson "cronjob-$Name" @("-n", $Namespace, "get", "cronjob", $Name, "-o", "json")
    if ($null -eq $source) {
        return
    }

    $cronJob = $source.json
    $schedule = "$($cronJob.spec.schedule)"
    $concurrencyPolicy = "$($cronJob.spec.concurrencyPolicy)"
    $suspend = $false
    if ($null -ne $cronJob.spec.suspend) {
        $suspend = [bool] $cronJob.spec.suspend
    }
    $lastScheduleTime = "$($cronJob.status.lastScheduleTime)"
    $lastSuccessfulTime = "$($cronJob.status.lastSuccessfulTime)"
    $passed = ($schedule.Length -gt 0) -and ($concurrencyPolicy -eq "Forbid") -and (-not $suspend)
    $summary = "schedule=$schedule concurrencyPolicy=$concurrencyPolicy suspend=$suspend lastScheduleTime=$lastScheduleTime lastSuccessfulTime=$lastSuccessfulTime"
    Add-Check "cronjob-$Name-scheduled" "dr" $passed $summary $source.command 0 ""
}

function New-EffectiveRestoreManifest() {
    $resolvedRestoreManifest = Resolve-ProjectPath $RestoreManifestPath
    if (-not (Test-Path -LiteralPath $resolvedRestoreManifest)) {
        throw "Restore manifest missing: $resolvedRestoreManifest"
    }

    $content = Get-Content -Raw -LiteralPath $resolvedRestoreManifest
    if (-not $content.Contains("kind: Job")) {
        throw "Restore manifest must be a Job example."
    }
    if (-not $content.Contains("Restoring can overwrite")) {
        throw "Restore manifest must keep the destructive restore warning."
    }

    if ($Namespace -eq "osmu") {
        return $resolvedRestoreManifest
    }

    $script:tempRestoreManifest = Join-Path ([System.IO.Path]::GetTempPath()) ("osmu-restore-dry-run-{0}.yaml" -f ([Guid]::NewGuid().ToString("N")))
    $effective = $content -replace "(?m)^  namespace: .*$", "  namespace: $Namespace"
    Set-Content -LiteralPath $script:tempRestoreManifest -Value $effective -Encoding UTF8
    return $script:tempRestoreManifest
}

function Test-RestoreServerDryRun() {
    $effectiveRestoreManifest = New-EffectiveRestoreManifest
    $result = Invoke-KubectlRaw "restore-server-dry-run" @("-n", $Namespace, "apply", "--server-side", "--dry-run=server", "-f", $effectiveRestoreManifest)
    $passed = $result.exitCode -eq 0
    Add-Check "restore-job-server-dry-run" "dr" $passed "kubectl apply --server-side --dry-run=server for restore Job example." $result.command $result.exitCode $result.output
}

function Get-PlanCommands() {
    $restorePlanPath = Resolve-ProjectPath $RestoreManifestPath
    if ($Namespace -ne "osmu") {
        $restorePlanPath = "<generated restore manifest with metadata.namespace=$Namespace>"
    }

    return @(
        @("-n", $Namespace, "get", "deployment", "osmu-backend", "-o", "json"),
        @("-n", $Namespace, "get", "deployment", "osmu-frontend", "-o", "json"),
        @("-n", $Namespace, "get", "statefulset", "osmu-mariadb", "-o", "json"),
        @("-n", $Namespace, "get", "statefulset", "osmu-minio", "-o", "json"),
        @("-n", $Namespace, "get", "pdb", "osmu-backend", "-o", "json"),
        @("-n", $Namespace, "get", "pdb", "osmu-frontend", "-o", "json"),
        @("-n", $Namespace, "get", "pdb", "osmu-mariadb", "-o", "json"),
        @("-n", $Namespace, "get", "pdb", "osmu-minio", "-o", "json"),
        @("-n", $Namespace, "get", "pvc", "osmu-backup-data", "-o", "json"),
        @("-n", $Namespace, "get", "cronjob", "osmu-mariadb-backup", "-o", "json"),
        @("-n", $Namespace, "get", "cronjob", "osmu-minio-backup", "-o", "json"),
        @("-n", $Namespace, "apply", "--server-side", "--dry-run=server", "-f", $restorePlanPath)
    )
}

if ($PlanOnly) {
    Write-Host "Kubernetes HA/DR readiness check plan only."
    Write-Host "Namespace: $Namespace"
    Write-Host "Restore manifest: $(Resolve-ProjectPath $RestoreManifestPath)"
    foreach ($commandArguments in Get-PlanCommands) {
        Write-Host "[CHECK] $(Format-Command $commandArguments)"
    }
    Write-Host "Plan only; no evidence file written."
    return
}

try {
    Test-Deployment "osmu-backend" 2
    Test-Deployment "osmu-frontend" 2
    Test-StatefulSet "osmu-mariadb"
    Test-StatefulSet "osmu-minio"
    Test-PodDisruptionBudget "osmu-backend" 1
    Test-PodDisruptionBudget "osmu-frontend" 1
    Test-PodDisruptionBudget "osmu-mariadb" 0
    Test-PodDisruptionBudget "osmu-minio" 0
    Test-PersistentVolumeClaim "osmu-backup-data"
    Test-CronJob "osmu-mariadb-backup"
    Test-CronJob "osmu-minio-backup"
    Test-RestoreServerDryRun
}
finally {
    if ($null -ne $tempRestoreManifest -and (Test-Path -LiteralPath $tempRestoreManifest)) {
        Remove-Item -LiteralPath $tempRestoreManifest -Force
    }
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
}

$evidence = [pscustomobject]@{
    formatVersion = "osmu.kubernetes-ha-dr-readiness.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    namespace = $Namespace
    kubectlPath = $KubectlPath
    restoreManifestPath = (Resolve-ProjectPath $RestoreManifestPath)
    result = if ($failureCount -eq 0) { "passed" } else { "failed" }
    failureCount = $failureCount
    checks = $checks
}

$evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

if ($failureCount -ne 0) {
    Write-Host "Kubernetes HA/DR readiness evidence written with failures: $resolvedEvidencePath"
    throw "Kubernetes HA/DR readiness check failed: $failureCount failed checks."
}

Write-Host "Kubernetes HA/DR readiness verified."
Write-Host "Evidence: $resolvedEvidencePath"
