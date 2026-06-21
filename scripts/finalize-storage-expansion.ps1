param(
    [string] $Namespace = "osmu",
    [string] $TenantName = "osmu-minio",
    [string] $ManifestPath = ".\infra\k8s\examples\minio-tenant-pool-expansion.example.yaml",
    [string] $KubectlPath = "kubectl",
    [string] $PowerShellCommand = "",
    [string] $ServiceAccount = "osmu-storage-expansion-runner",
    [string] $RbacEvidencePath = ".\.osmu-run\latest-storage-expansion-rbac-auth.json",
    [string] $ServerDryRunEvidencePath = ".\.osmu-run\latest-storage-expansion-server-dry-run.json",
    [string] $ReportPath = ".\.osmu-run\latest-storage-expansion-finalize.json",
    [string] $SummaryPath = ".\.osmu-run\latest-storage-expansion-finalize.md",
    [string] $StorageBackendTelemetryAdminInfoJsonPath = "",
    [string] $StorageBackendTelemetryEnvironmentName = "",
    [string] $StorageBackendTelemetryTargetCluster = "",
    [string] $StorageBackendTelemetryOperator = "",
    [string] $StorageBackendTelemetryMinioAlias = "",
    [string] $StorageBackendTelemetryEvidenceRef = "",
    [string] $StorageBackendTelemetryJsonOutputPath = ".\.osmu-run\latest-storage-backend-telemetry.json",
    [string] $StorageBackendTelemetryMarkdownOutputPath = ".\.osmu-run\latest-storage-backend-telemetry.md",
    [string] $StorageBackendTelemetryMcCommand = "mc",
    [int] $StorageBackendTelemetryMcTimeoutSeconds = 30,
    [string] $ApiBase = "",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "",
    [long] $RequestId = 0,
    [ValidateSet("KUBECTL_DIFF", "HELM_DIFF")]
    [string] $DryRunType = "KUBECTL_DIFF",
    [ValidateSet("KUBECTL_APPLY", "HELM_UPGRADE")]
    [string] $ApplyType = "KUBECTL_APPLY",
    [switch] $ImpersonateRunner,
    [switch] $SkipRbacAuth,
    [switch] $SkipServerDryRun,
    [switch] $RunBackendDryRunRunner,
    [switch] $RunBackendApply,
    [switch] $ConfirmApply,
    [switch] $RunStorageBackendTelemetryEvidence,
    [switch] $StorageBackendTelemetryExecute,
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

function Test-UnsafeEvidenceText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "(?i)\b(password|passwd|secret|token|client_secret|x-amz-security-token|authorization)\s*[""':=]\s*\S+",
        "(?i)\b(secretKey|accessKey|sessionToken)\s*[""':=]\s*\S+",
        "(?i)Credential=[^,\s]+"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            return $true
        }
    }
    return $false
}

function Redact-UnsafeEvidenceText([string] $Value) {
    if (Test-UnsafeEvidenceText $Value) {
        return "<redacted>"
    }
    return $Value
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
        $masked += (Redact-UnsafeEvidenceText $argument)
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

function Add-StepResult(
    [string] $Name,
    [string] $Command,
    [string] $Result,
    [int] $ExitCode = 0,
    [string] $Output = "",
    [string] $Notes = ""
) {
    $script:steps += [ordered]@{
        name = $Name
        command = $Command
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
        Add-StepResult $Name $command "failed" $exitCode $output ""
        throw "$Name failed with exit code $exitCode."
    }
    Add-StepResult $Name $command "passed" $exitCode $output ""
}

function Invoke-Json($method, $url, $body = $null, $token = $null) {
    $headers = @{}
    if ($token) {
        $headers.Authorization = "Bearer $token"
    }
    if ($null -eq $body) {
        return Invoke-RestMethod -Method $method -Uri $url -Headers $headers
    }
    return Invoke-RestMethod `
        -Method $method `
        -Uri $url `
        -Headers $headers `
        -ContentType "application/json" `
        -Body ($body | ConvertTo-Json -Depth 10)
}

function Assert-BackendInputs() {
    if (-not $ApiBase) {
        throw "Backend runner steps require -ApiBase."
    }
    if (-not $AdminLoginId) {
        throw "Backend runner steps require -AdminLoginId."
    }
    if (-not $AdminPassword) {
        throw "Backend runner steps require -AdminPassword."
    }
    if ($RequestId -le 0) {
        throw "Backend runner steps require -RequestId greater than zero."
    }
}

function Assert-StorageBackendTelemetryInputs() {
    if (-not $RunStorageBackendTelemetryEvidence) {
        return
    }
    if ([string]::IsNullOrWhiteSpace($StorageBackendTelemetryAdminInfoJsonPath) -and -not $StorageBackendTelemetryExecute) {
        throw "-RunStorageBackendTelemetryEvidence requires -StorageBackendTelemetryAdminInfoJsonPath or -StorageBackendTelemetryExecute."
    }
}

function Invoke-BackendLogin() {
    $url = "$ApiBase/auth/login"
    $command = "POST $url loginId=$AdminLoginId password=<secret>"
    Write-Host ""
    Write-Host "==> Backend admin login"
    Write-Host "    $command"
    try {
        $login = Invoke-Json "POST" $url @{
            loginId = $AdminLoginId
            password = $AdminPassword
        }
        $token = $login.data.accessToken
        if (-not $token) {
            throw "Login response did not include accessToken."
        }
        Add-StepResult "backend-admin-login" $command "passed" 0 "Admin access token returned and redacted." ""
        return $token
    }
    catch {
        Add-StepResult "backend-admin-login" $command "failed" 1 $_.Exception.Message ""
        throw
    }
}

function Invoke-BackendJsonStep([string] $Name, [string] $Method, [string] $Url, $Body, [string] $Token) {
    $command = "$Method $Url"
    Write-Host ""
    Write-Host "==> $Name"
    Write-Host "    $command"
    try {
        $response = Invoke-Json $Method $Url $Body $Token
        $output = $response | ConvertTo-Json -Depth 20
        Add-StepResult $Name $command "passed" 0 $output ""
        return $response
    }
    catch {
        Add-StepResult $Name $command "failed" 1 $_.Exception.Message ""
        throw
    }
}

function Write-FinalReport([string] $Result, [string] $ErrorMessage) {
    if ($NoReport) {
        return
    }

    $resolvedManifestPath = Resolve-ProjectPath $ManifestPath
    $resolvedRbacEvidencePath = Resolve-ProjectPath $RbacEvidencePath
    $resolvedServerDryRunEvidencePath = Resolve-ProjectPath $ServerDryRunEvidencePath
    $resolvedReportPath = Resolve-ProjectPath $ReportPath
    $resolvedSummaryPath = Resolve-ProjectPath $SummaryPath
    $resolvedStorageBackendTelemetryJsonPath = Resolve-ProjectPath $StorageBackendTelemetryJsonOutputPath
    $resolvedStorageBackendTelemetryMarkdownPath = Resolve-ProjectPath $StorageBackendTelemetryMarkdownOutputPath
    $completedAt = [DateTimeOffset]::UtcNow

    $gaps = @()
    if ($SkipRbacAuth) {
        $gaps += "RBAC authorization evidence was skipped."
    }
    if ($SkipServerDryRun) {
        $gaps += "Server-side dry-run evidence was skipped."
    }
    if (-not $RunBackendDryRunRunner) {
        $gaps += "Backend dry-run runner was not executed."
    }
    if (-not $RunBackendApply) {
        $gaps += "Backend apply runner was not executed."
    }
    elseif (-not $ConfirmApply) {
        $gaps += "Backend apply runner was requested without ConfirmApply."
    }
    if (-not $RunStorageBackendTelemetryEvidence) {
        $gaps += "Storage backend telemetry evidence was not recorded by the finalizer."
    }
    if ($ErrorMessage) {
        $gaps += $ErrorMessage
    }

    $report = [ordered]@{
        generatedAt = $completedAt.ToString("o")
        startedAt = $startedAt.ToString("o")
        completedAt = $completedAt.ToString("o")
        result = $Result
        namespace = $Namespace
        tenantName = $TenantName
        manifestPath = $resolvedManifestPath
        kubectlPath = $KubectlPath
        powerShellCommand = Get-PowerShellExecutable
        serviceAccount = $ServiceAccount
        impersonateRunner = [bool] $ImpersonateRunner
        backend = [ordered]@{
            apiBase = $ApiBase
            requestId = $RequestId
            runDryRunRunner = [bool] $RunBackendDryRunRunner
            dryRunType = $DryRunType
            runApply = [bool] $RunBackendApply
            applyType = $ApplyType
            confirmApply = [bool] $ConfirmApply
        }
        storageBackendTelemetry = [ordered]@{
            runEvidence = [bool] $RunStorageBackendTelemetryEvidence
            executeRequested = [bool] $StorageBackendTelemetryExecute
            adminInfoJsonPath = Redact-UnsafeEvidenceText $StorageBackendTelemetryAdminInfoJsonPath
            environmentName = Redact-UnsafeEvidenceText $StorageBackendTelemetryEnvironmentName
            targetCluster = Redact-UnsafeEvidenceText $StorageBackendTelemetryTargetCluster
            operatorName = Redact-UnsafeEvidenceText $StorageBackendTelemetryOperator
            minioAlias = Redact-UnsafeEvidenceText $StorageBackendTelemetryMinioAlias
            evidenceRef = Redact-UnsafeEvidenceText $StorageBackendTelemetryEvidenceRef
            jsonOutputPath = if ($RunStorageBackendTelemetryEvidence) { $resolvedStorageBackendTelemetryJsonPath } else { "" }
            markdownOutputPath = if ($RunStorageBackendTelemetryEvidence) { $resolvedStorageBackendTelemetryMarkdownPath } else { "" }
        }
        evidence = [ordered]@{
            rbacAuth = if ($SkipRbacAuth) { "" } else { $resolvedRbacEvidencePath }
            serverDryRun = if ($SkipServerDryRun) { "" } else { $resolvedServerDryRunEvidencePath }
            storageBackendTelemetry = if ($RunStorageBackendTelemetryEvidence) { $resolvedStorageBackendTelemetryJsonPath } else { "" }
            report = $resolvedReportPath
            summary = $resolvedSummaryPath
        }
        failedCount = $failureCount
        gaps = $gaps
        steps = $steps
        secretPolicy = "Secret values, bearer tokens, and raw MinIO admin info are not written to storage expansion finalizer evidence."
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
    $report | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 -LiteralPath $resolvedReportPath

    $summaryLines = @(
        "# OSMU Storage Expansion Finalize",
        "",
        "- Result: $Result",
        "- Namespace: $Namespace",
        "- Tenant: $TenantName",
        "- Request ID: $RequestId",
        "- Backend dry-run runner: $RunBackendDryRunRunner",
        "- Backend apply runner: $RunBackendApply",
        "- Confirm apply: $ConfirmApply",
        "- Storage backend telemetry evidence: $RunStorageBackendTelemetryEvidence",
        "- Report: $resolvedReportPath",
        "",
        "## Steps"
    )
    foreach ($step in $steps) {
        $summaryLines += "- [$($step.result)] $($step.name)"
    }
    $summaryLines += ""
    $summaryLines += "## Gaps"
    if ($gaps.Count -eq 0) {
        $summaryLines += "- None"
    }
    else {
        foreach ($gap in $gaps) {
            $summaryLines += "- $gap"
        }
    }
    $summaryLines | Set-Content -Encoding UTF8 -LiteralPath $resolvedSummaryPath

    Write-Host ""
    Write-Host "Storage Expansion finalize report: $resolvedReportPath"
    Write-Host "Storage Expansion finalize summary: $resolvedSummaryPath"
}

if ($PlanOnly) {
    Write-Host "Storage Expansion finalize plan only."
    Write-Host "Namespace: $Namespace"
    Write-Host "Tenant: $TenantName"
    Write-Host "Manifest: $(Resolve-ProjectPath $ManifestPath)"
    Write-Host "Impersonate runner: $ImpersonateRunner"
    $psCommand = Get-PowerShellExecutable
    if (-not $SkipRbacAuth) {
        Write-Host "[STEP] RBAC auth evidence: $psCommand -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-rbac-auth.ps1 -Namespace $Namespace -ServiceAccount $ServiceAccount -KubectlPath $KubectlPath -EvidencePath $RbacEvidencePath"
    }
    if (-not $SkipServerDryRun) {
        $dryRunPlan = "$psCommand -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-server-dry-run.ps1 -Namespace $Namespace -TenantName $TenantName -ManifestPath $ManifestPath -KubectlPath $KubectlPath -EvidencePath $ServerDryRunEvidencePath"
        if ($ImpersonateRunner) {
            $dryRunPlan += " -ImpersonateRunner"
        }
        Write-Host "[STEP] Server-side dry-run evidence: $dryRunPlan"
    }
    if ($RunBackendDryRunRunner -or $RunBackendApply) {
        Write-Host "[STEP] Backend login: POST $ApiBase/auth/login"
        Write-Host "[STEP] Backend preflight: GET $ApiBase/admin/storage-expansion/runner-preflight"
    }
    if ($RunBackendDryRunRunner) {
        Write-Host "[STEP] Backend dry-run runner: POST $ApiBase/admin/storage-expansion/requests/$RequestId/dry-run-runner executionType=$DryRunType"
    }
    if ($RunBackendApply) {
        Write-Host "[STEP] Backend apply runner: POST $ApiBase/admin/storage-expansion/requests/$RequestId/apply-runner applyType=$ApplyType"
        Write-Host "[GUARD] Requires -ConfirmApply. Without it, this script fails before any apply request."
    }
    if ($RunStorageBackendTelemetryEvidence) {
        $telemetryPlan = "$psCommand -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-storage-backend-telemetry-evidence.ps1 -EnvironmentName $(Format-Value $StorageBackendTelemetryEnvironmentName) -TargetCluster $(Format-Value $StorageBackendTelemetryTargetCluster) -Operator $(Format-Value $StorageBackendTelemetryOperator) -MinioAlias $(Format-Value $StorageBackendTelemetryMinioAlias) -EvidenceRef $(Format-Value $StorageBackendTelemetryEvidenceRef) -JsonOutputPath $(Format-Value $StorageBackendTelemetryJsonOutputPath) -MarkdownOutputPath $(Format-Value $StorageBackendTelemetryMarkdownOutputPath) -FailIfNotPassed"
        if ($StorageBackendTelemetryExecute) {
            $telemetryPlan += " -Execute -McCommand $(Format-Value $StorageBackendTelemetryMcCommand) -McTimeoutSeconds $StorageBackendTelemetryMcTimeoutSeconds"
        }
        else {
            $telemetryPlan += " -AdminInfoJsonPath $(Format-Value $StorageBackendTelemetryAdminInfoJsonPath)"
        }
        Write-Host "[STEP] Storage backend telemetry evidence: $telemetryPlan"
    }
    Write-Host "Plan only; no Kubernetes command, HTTP request, evidence file, or report is written."
    return
}

$finalError = ""
try {
    if ($RunBackendApply -and -not $ConfirmApply) {
        throw "-RunBackendApply requires -ConfirmApply."
    }
    if ($RunBackendApply -and ($SkipRbacAuth -or $SkipServerDryRun)) {
        throw "-RunBackendApply requires RBAC auth and server-side dry-run evidence in the same finalizer run."
    }
    Assert-StorageBackendTelemetryInputs

    if (-not $SkipRbacAuth) {
        $rbacArgs = @(
            "-Namespace", $Namespace,
            "-ServiceAccount", $ServiceAccount,
            "-KubectlPath", $KubectlPath,
            "-EvidencePath", $RbacEvidencePath
        )
        Invoke-ProjectScript "Storage Expansion RBAC auth evidence" ".\scripts\verify-storage-expansion-rbac-auth.ps1" $rbacArgs
    }

    if (-not $SkipServerDryRun) {
        $dryRunArgs = @(
            "-Namespace", $Namespace,
            "-TenantName", $TenantName,
            "-ManifestPath", $ManifestPath,
            "-KubectlPath", $KubectlPath,
            "-EvidencePath", $ServerDryRunEvidencePath,
            "-ServiceAccount", $ServiceAccount
        )
        if ($ImpersonateRunner) {
            $dryRunArgs += "-ImpersonateRunner"
        }
        Invoke-ProjectScript "Storage Expansion server-side dry-run evidence" ".\scripts\verify-storage-expansion-server-dry-run.ps1" $dryRunArgs
    }

    if ($RunBackendDryRunRunner -or $RunBackendApply) {
        Assert-BackendInputs
        $token = Invoke-BackendLogin
        Invoke-BackendJsonStep "storage-expansion-runner-preflight" "GET" "$ApiBase/admin/storage-expansion/runner-preflight" $null $token | Out-Null
        if ($RunBackendDryRunRunner) {
            Invoke-BackendJsonStep `
                "storage-expansion-backend-dry-run-runner" `
                "POST" `
                "$ApiBase/admin/storage-expansion/requests/$RequestId/dry-run-runner" `
                @{ executionType = $DryRunType } `
                $token | Out-Null
        }
        if ($RunBackendApply) {
            Invoke-BackendJsonStep `
                "storage-expansion-backend-apply-runner" `
                "POST" `
                "$ApiBase/admin/storage-expansion/requests/$RequestId/apply-runner" `
                @{ applyType = $ApplyType } `
                $token | Out-Null
        }
    }

    if ($RunStorageBackendTelemetryEvidence) {
        $telemetryArgs = @(
            "-EnvironmentName", $StorageBackendTelemetryEnvironmentName,
            "-TargetCluster", $StorageBackendTelemetryTargetCluster,
            "-Operator", $StorageBackendTelemetryOperator,
            "-MinioAlias", $StorageBackendTelemetryMinioAlias,
            "-EvidenceRef", $StorageBackendTelemetryEvidenceRef,
            "-JsonOutputPath", $StorageBackendTelemetryJsonOutputPath,
            "-MarkdownOutputPath", $StorageBackendTelemetryMarkdownOutputPath,
            "-FailIfNotPassed"
        )
        if ($StorageBackendTelemetryExecute) {
            $telemetryArgs += @(
                "-Execute",
                "-McCommand", $StorageBackendTelemetryMcCommand,
                "-McTimeoutSeconds", ([string] $StorageBackendTelemetryMcTimeoutSeconds)
            )
        }
        else {
            $telemetryArgs += @(
                "-AdminInfoJsonPath", $StorageBackendTelemetryAdminInfoJsonPath
            )
        }
        Invoke-ProjectScript "Storage backend telemetry evidence" ".\scripts\write-storage-backend-telemetry-evidence.ps1" $telemetryArgs
    }

    Write-FinalReport "passed" ""
    Write-Host "Storage Expansion finalize completed."
}
catch {
    $finalError = $_.Exception.Message
    Write-FinalReport "failed" $finalError
    throw
}
