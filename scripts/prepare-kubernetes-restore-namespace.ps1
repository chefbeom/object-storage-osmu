param(
    [string] $SourceNamespace = "osmu",
    [string] $RestoreNamespace = "osmu-restore-drill",
    [string] $KubectlPath = "kubectl",
    [string] $RunId = "",
    [int] $TimeoutSeconds = 300,
    [string] $OverlayRoot = ".\.osmu-run\kubernetes-restore-targets",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-restore-namespace.json",
    [switch] $IncludeAppWorkloads,
    [switch] $ServerDryRunOnly,
    [switch] $Apply,
    [switch] $Wait,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()
$failureCount = 0

if (-not $RunId) {
    $RunId = [DateTimeOffset]::UtcNow.ToString("yyyyMMddHHmmss")
}

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

function Assert-ModeIsSafe() {
    if ($RestoreNamespace -eq $SourceNamespace) {
        throw "RestoreNamespace must differ from SourceNamespace. Use a disposable namespace such as osmu-restore-drill."
    }
    if ($Apply -and $ServerDryRunOnly) {
        throw "Use either -Apply or -ServerDryRunOnly, not both."
    }
    if ((-not $PlanOnly) -and (-not $Apply) -and (-not $ServerDryRunOnly)) {
        throw "Choose -PlanOnly, -ServerDryRunOnly, or -Apply."
    }
}

function New-RestoreNamespaceOverlay() {
    $overlayDirectory = Join-Path (Resolve-ProjectPath $OverlayRoot) $RunId
    if (-not (Test-Path -LiteralPath $overlayDirectory)) {
        New-Item -ItemType Directory -Path $overlayDirectory -Force | Out-Null
    }

    $resources = @(
        "../../../infra/k8s/namespace.yaml",
        "../../../infra/k8s/serviceaccount.yaml",
        "../../../infra/k8s/configmap.yaml",
        "../../../infra/k8s/mariadb.yaml",
        "../../../infra/k8s/minio.yaml",
        "../../../infra/k8s/backup.yaml",
        "../../../infra/k8s/ha.yaml",
        "../../../infra/k8s/networkpolicy.yaml"
    )

    if ($IncludeAppWorkloads) {
        $resources += "../../../infra/k8s/backend.yaml"
        $resources += "../../../infra/k8s/frontend.yaml"
        $resources += "../../../infra/k8s/ingress.yaml"
    }

    $resourceBlock = ($resources | ForEach-Object { "  - $_" }) -join [Environment]::NewLine
    $content = @"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $RestoreNamespace
resources:
$resourceBlock
patches:
  - target:
      kind: Namespace
      name: osmu
    patch: |-
      - op: replace
        path: /metadata/name
        value: $RestoreNamespace
  - target:
      kind: CronJob
      name: osmu-mariadb-backup
    patch: |-
      - op: add
        path: /spec/suspend
        value: true
  - target:
      kind: CronJob
      name: osmu-minio-backup
    patch: |-
      - op: add
        path: /spec/suspend
        value: true
"@

    $kustomizationPath = Join-Path $overlayDirectory "kustomization.yaml"
    $content | Set-Content -LiteralPath $kustomizationPath -Encoding UTF8
    return [pscustomobject]@{
        directory = $overlayDirectory
        kustomizationPath = $kustomizationPath
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

function Test-SecretExists() {
    $result = Invoke-KubectlRaw "secret-osmu-secret" @("-n", $RestoreNamespace, "get", "secret", "osmu-secret", "-o", "name")
    $passed = ($result.exitCode -eq 0) -and ($result.output.Trim() -eq "secret/osmu-secret")
    Add-Check "secret-osmu-secret-exists" $passed "restore namespace secret inventory exists; secret values are not read." $result.command $result.exitCode $result.output
}

function Test-ServiceAccountExists() {
    $result = Invoke-KubectlRaw "serviceaccount-osmu-backup" @("-n", $RestoreNamespace, "get", "serviceaccount", "osmu-backup", "-o", "name")
    $passed = ($result.exitCode -eq 0) -and ($result.output.Trim() -eq "serviceaccount/osmu-backup")
    Add-Check "serviceaccount-osmu-backup-exists" $passed "restore backup ServiceAccount exists." $result.command $result.exitCode $result.output
}

function Test-PvcBound([string] $Name) {
    $source = Read-KubeJson "pvc-$Name" @("-n", $RestoreNamespace, "get", "pvc", $Name, "-o", "json")
    if ($null -eq $source) {
        return
    }
    $phase = "$($source.json.status.phase)"
    Add-Check "pvc-$Name-bound" ($phase -eq "Bound") "phase=$phase" $source.command 0 ""
}

function Test-ServiceExists([string] $Name) {
    $result = Invoke-KubectlRaw "service-$Name" @("-n", $RestoreNamespace, "get", "service", $Name, "-o", "name")
    $passed = ($result.exitCode -eq 0) -and ($result.output.Trim() -eq "service/$Name")
    Add-Check "service-$Name-exists" $passed "restore target service exists." $result.command $result.exitCode $result.output
}

function Test-StatefulSetExists([string] $Name) {
    $source = Read-KubeJson "statefulset-$Name" @("-n", $RestoreNamespace, "get", "statefulset", $Name, "-o", "json")
    if ($null -eq $source) {
        return
    }
    $readyReplicas = 0
    if ($null -ne $source.json.status.readyReplicas) {
        $readyReplicas = [int] $source.json.status.readyReplicas
    }
    Add-Check "statefulset-$Name-found" $true "readyReplicas=$readyReplicas" $source.command 0 ""
}

function Invoke-ServerDryRun([string] $OverlayDirectory) {
    $result = Invoke-KubectlRaw "restore-namespace-server-dry-run" @("apply", "--server-side", "--dry-run=server", "-k", $OverlayDirectory)
    Add-Check "restore-namespace-server-dry-run" ($result.exitCode -eq 0) "validated restore namespace manifest set with Kubernetes API server." $result.command $result.exitCode $result.output
}

function Invoke-Apply([string] $OverlayDirectory) {
    $result = Invoke-KubectlRaw "apply-restore-namespace" @("apply", "-k", $OverlayDirectory)
    Add-Check "apply-restore-namespace" ($result.exitCode -eq 0) "applied restore namespace core resources." $result.command $result.exitCode $result.output
}

function Invoke-WaitForRestoreTarget() {
    $mariadbWait = Invoke-KubectlRaw "wait-osmu-mariadb" @("-n", $RestoreNamespace, "rollout", "status", "statefulset/osmu-mariadb", "--timeout=$($TimeoutSeconds)s")
    Add-Check "wait-osmu-mariadb" ($mariadbWait.exitCode -eq 0) "waited for MariaDB StatefulSet rollout." $mariadbWait.command $mariadbWait.exitCode $mariadbWait.output

    $minioWait = Invoke-KubectlRaw "wait-osmu-minio" @("-n", $RestoreNamespace, "rollout", "status", "statefulset/osmu-minio", "--timeout=$($TimeoutSeconds)s")
    Add-Check "wait-osmu-minio" ($minioWait.exitCode -eq 0) "waited for MinIO StatefulSet rollout." $minioWait.command $minioWait.exitCode $minioWait.output

    if ($IncludeAppWorkloads) {
        $backendWait = Invoke-KubectlRaw "wait-osmu-backend" @("-n", $RestoreNamespace, "rollout", "status", "deployment/osmu-backend", "--timeout=$($TimeoutSeconds)s")
        Add-Check "wait-osmu-backend" ($backendWait.exitCode -eq 0) "waited for backend Deployment rollout." $backendWait.command $backendWait.exitCode $backendWait.output

        $frontendWait = Invoke-KubectlRaw "wait-osmu-frontend" @("-n", $RestoreNamespace, "rollout", "status", "deployment/osmu-frontend", "--timeout=$($TimeoutSeconds)s")
        Add-Check "wait-osmu-frontend" ($frontendWait.exitCode -eq 0) "waited for frontend Deployment rollout." $frontendWait.command $frontendWait.exitCode $frontendWait.output
    }
}

function Test-RestoreTargetResources() {
    Test-NamespaceReady
    Test-SecretExists
    Test-ServiceAccountExists
    Test-ServiceExists "osmu-mariadb"
    Test-ServiceExists "osmu-minio"
    Test-StatefulSetExists "osmu-mariadb"
    Test-StatefulSetExists "osmu-minio"
    Test-PvcBound "osmu-backup-data"
}

function Get-PlanCommands([string] $OverlayDirectory) {
    $commands = @()
    $commands += ,@("apply", "--server-side", "--dry-run=server", "-k", $OverlayDirectory)
    if ($Apply) {
        $commands += ,@("apply", "-k", $OverlayDirectory)
        $commands += ,@("-n", $RestoreNamespace, "get", "secret", "osmu-secret", "-o", "name")
        $commands += ,@("-n", $RestoreNamespace, "get", "serviceaccount", "osmu-backup", "-o", "name")
        $commands += ,@("-n", $RestoreNamespace, "get", "service", "osmu-mariadb", "-o", "name")
        $commands += ,@("-n", $RestoreNamespace, "get", "service", "osmu-minio", "-o", "name")
        $commands += ,@("-n", $RestoreNamespace, "get", "pvc", "osmu-backup-data", "-o", "json")
        if ($Wait) {
            $commands += ,@("-n", $RestoreNamespace, "rollout", "status", "statefulset/osmu-mariadb", "--timeout=$($TimeoutSeconds)s")
            $commands += ,@("-n", $RestoreNamespace, "rollout", "status", "statefulset/osmu-minio", "--timeout=$($TimeoutSeconds)s")
        }
    }
    return $commands
}

Assert-ModeIsSafe

$plannedOverlayDirectory = Join-Path (Resolve-ProjectPath $OverlayRoot) $RunId
if ($PlanOnly) {
    Write-Host "Kubernetes restore namespace preparation plan only."
    Write-Host "Source namespace: $SourceNamespace"
    Write-Host "Restore namespace: $RestoreNamespace"
    Write-Host "Run ID: $RunId"
    Write-Host "Overlay directory: $plannedOverlayDirectory"
    Write-Host "Include app workloads: $IncludeAppWorkloads"
    Write-Host "Server dry-run only: $ServerDryRunOnly"
    Write-Host "Apply: $Apply"
    Write-Host "Wait: $Wait"
    Write-Host "Secret policy: create osmu-secret through the environment secret manager before restore; this script checks the secret name only and never reads values."
    Write-Host "Restore target backup PVC must later contain /backup/mariadb/<BACKUP_TIMESTAMP>/metadata.sql and /backup/minio/<BACKUP_TIMESTAMP>."
    foreach ($commandArguments in Get-PlanCommands $plannedOverlayDirectory) {
        Write-Host "[CHECK] $(Format-Command $commandArguments)"
    }
    Write-Host "Plan only; no restore namespace resources created and no evidence file written."
    return
}

$overlay = New-RestoreNamespaceOverlay
Invoke-ServerDryRun $overlay.directory

if ($Apply -and ($failureCount -eq 0)) {
    Invoke-Apply $overlay.directory
    if ($Wait) {
        Invoke-WaitForRestoreTarget
    }
    Test-RestoreTargetResources
}
elseif ($Apply) {
    Add-Check "apply-restore-namespace-skipped" $false "restore namespace apply skipped because server-side dry-run failed." "" 0 ""
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
}

$evidence = [pscustomobject]@{
    formatVersion = "osmu.kubernetes-restore-namespace.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    sourceNamespace = $SourceNamespace
    restoreNamespace = $RestoreNamespace
    runId = $RunId
    kubectlPath = $KubectlPath
    timeoutSeconds = $TimeoutSeconds
    includeAppWorkloads = [bool] $IncludeAppWorkloads
    serverDryRunOnly = [bool] $ServerDryRunOnly
    apply = [bool] $Apply
    wait = [bool] $Wait
    overlayDirectory = $overlay.directory
    kustomizationPath = $overlay.kustomizationPath
    result = if ($failureCount -eq 0) { "passed" } else { "failed" }
    failureCount = $failureCount
    secretPolicy = "Secret values are not copied into this restore namespace evidence. Provide osmu-secret through the target environment secret manager."
    backupArtifactRequirement = @(
        "/backup/mariadb/<BACKUP_TIMESTAMP>/metadata.sql",
        "/backup/minio/<BACKUP_TIMESTAMP>"
    )
    checks = $checks
}

$evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

if ($failureCount -ne 0) {
    Write-Host "Kubernetes restore namespace evidence written with failures: $resolvedEvidencePath"
    throw "Kubernetes restore namespace preparation failed: $failureCount failed checks."
}

Write-Host "Kubernetes restore namespace preparation completed."
Write-Host "Evidence: $resolvedEvidencePath"
