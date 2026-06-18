param(
    [string] $Namespace = "osmu",
    [string] $ServiceAccount = "osmu-storage-expansion-runner",
    [string] $KubectlPath = "kubectl",
    [string] $EvidencePath = ".\.osmu-run\latest-storage-expansion-rbac-auth.json",
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

# Live evidence command pattern: kubectl auth can-i --as=<storage-expansion-runner-service-account>

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function New-CanICheck(
    [string] $Id,
    [bool] $ExpectedAllowed,
    [string] $Verb,
    [string] $Resource,
    [bool] $NamespaceScoped = $true,
    [string] $Subresource = ""
) {
    return [pscustomobject]@{
        Id = $Id
        ExpectedAllowed = $ExpectedAllowed
        Verb = $Verb
        Resource = $Resource
        NamespaceScoped = $NamespaceScoped
        Subresource = $Subresource
    }
}

function Get-CanIArguments($check, [string] $subject) {
    $arguments = @("auth", "can-i", $check.Verb, $check.Resource, "--as=$subject")
    if ($check.Subresource) {
        $arguments += "--subresource=$($check.Subresource)"
    }
    if ($check.NamespaceScoped) {
        $arguments += @("-n", $Namespace)
    }
    return $arguments
}

function Invoke-CanICheck($check, [string] $subject) {
    $arguments = Get-CanIArguments $check $subject
    $outputLines = & $KubectlPath @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output = ($outputLines | ForEach-Object { $_.ToString() }) -join "`n"
    $nonEmptyLines = @($output -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })
    $answer = ""
    if ($nonEmptyLines.Count -gt 0) {
        $answer = $nonEmptyLines[$nonEmptyLines.Count - 1].Trim().ToLowerInvariant()
    }

    if ($answer -ne "yes" -and $answer -ne "no") {
        throw "kubectl auth can-i returned unexpected output for $($check.Id) (exit $exitCode): $output"
    }

    $allowed = $answer -eq "yes"
    $passed = $allowed -eq $check.ExpectedAllowed
    return [pscustomobject]@{
        id = $check.Id
        expectedAllowed = $check.ExpectedAllowed
        actualAllowed = $allowed
        passed = $passed
        command = "$KubectlPath $($arguments -join ' ')"
        exitCode = $exitCode
        output = $output
    }
}

$subject = "system:serviceaccount:$Namespace`:$ServiceAccount"

$checks = @(
    (New-CanICheck "tenant-get" $true "get" "tenants.minio.min.io/osmu-minio")
    (New-CanICheck "tenant-patch" $true "patch" "tenants.minio.min.io/osmu-minio")
    (New-CanICheck "tenant-update" $true "update" "tenants.minio.min.io/osmu-minio")
    (New-CanICheck "statefulset-get" $true "get" "statefulsets.apps/osmu-minio")
    (New-CanICheck "statefulset-patch" $true "patch" "statefulsets.apps/osmu-minio")
    (New-CanICheck "statefulset-update" $true "update" "statefulsets.apps/osmu-minio")
    (New-CanICheck "statefulset-status-get" $true "get" "statefulsets.apps/osmu-minio" $true "status")
    (New-CanICheck "tenant-create-denied" $false "create" "tenants.minio.min.io")
    (New-CanICheck "tenant-delete-denied" $false "delete" "tenants.minio.min.io/osmu-minio")
    (New-CanICheck "secret-get-denied" $false "get" "secrets/osmu-secret")
    (New-CanICheck "secret-list-denied" $false "list" "secrets")
    (New-CanICheck "pod-exec-denied" $false "create" "pods" $true "exec")
    (New-CanICheck "pod-log-denied" $false "get" "pods" $true "log")
    (New-CanICheck "job-create-denied" $false "create" "jobs.batch")
    (New-CanICheck "clusterrole-create-denied" $false "create" "clusterroles.rbac.authorization.k8s.io" $false)
    (New-CanICheck "clusterrolebinding-create-denied" $false "create" "clusterrolebindings.rbac.authorization.k8s.io" $false)
)

if ($PlanOnly) {
    Write-Host "Storage Expansion RBAC auth check plan only."
    Write-Host "Subject: $subject"
    foreach ($check in $checks) {
        $arguments = Get-CanIArguments $check $subject
        $expected = if ($check.ExpectedAllowed) { "ALLOW" } else { "DENY" }
        Write-Host "[$expected] $($check.Id): $KubectlPath $($arguments -join ' ')"
    }
    Write-Host "Plan only; no evidence file written."
    exit 0
}

$command = Get-Command $KubectlPath -ErrorAction SilentlyContinue
if (-not $command) {
    throw "kubectl executable not found: $KubectlPath"
}

$results = foreach ($check in $checks) {
    Invoke-CanICheck $check $subject
}

$failed = @($results | Where-Object { -not $_.passed })
$evidence = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    namespace = $Namespace
    serviceAccount = $ServiceAccount
    subject = $subject
    kubectlPath = $KubectlPath
    expectedAllowedCount = @($checks | Where-Object { $_.ExpectedAllowed }).Count
    expectedDeniedCount = @($checks | Where-Object { -not $_.ExpectedAllowed }).Count
    passed = $failed.Count -eq 0
    failedCount = $failed.Count
    results = $results
}

$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -ItemType Directory -Path $evidenceDirectory | Out-Null
}
$evidence | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -LiteralPath $resolvedEvidencePath

if ($failed.Count -gt 0) {
    $failedIds = ($failed | ForEach-Object { $_.id }) -join ", "
    throw "Storage Expansion RBAC auth check failed: $failedIds. Evidence: $resolvedEvidencePath"
}

Write-Host "Storage Expansion RBAC auth check passed."
Write-Host "Evidence: $resolvedEvidencePath"
