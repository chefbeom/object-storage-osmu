param(
    [string] $JsonOutputPath = ".\.osmu-run\latest-iam-rbac-finalize.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-iam-rbac-finalize.md",
    [string] $Namespace = "osmu",
    [string] $ServiceAccount = "osmu-storage-expansion-runner",
    [string] $KubectlPath = "kubectl",
    [string] $PowerShellCommand = "",
    [string] $GradleCommand = "",
    [switch] $RunBackendPolicyTests,
    [switch] $RunKubernetesLiveAuth,
    [switch] $PlanOnly,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$startedAt = [DateTimeOffset]::UtcNow
$steps = @()
$failureCount = 0

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

function Limit-Text([string] $text) {
    if ($null -eq $text) {
        return ""
    }
    if ($text.Length -le 8000) {
        return $text
    }
    return $text.Substring(0, 8000) + "`n...truncated..."
}

function Format-Command([string] $Executable, [string[]] $Arguments) {
    $parts = @((Format-Value $Executable))
    foreach ($argument in $Arguments) {
        $parts += Format-Value $argument
    }
    return ($parts -join " ").Trim()
}

function New-StepCommand([string] $Name, [string] $Executable, [string[]] $Arguments, [string] $WorkingDirectory) {
    return [ordered]@{
        name = $Name
        executable = $Executable
        arguments = $Arguments
        workingDirectory = $WorkingDirectory
        command = Format-Command $Executable $Arguments
    }
}

function Get-GradleExecutable() {
    if (-not [string]::IsNullOrWhiteSpace($GradleCommand)) {
        return $GradleCommand
    }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        return ".\gradlew.bat"
    }
    return "./gradlew"
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

function Add-StepResult(
    [string] $Name,
    [string] $Command,
    [string] $WorkingDirectory,
    [string] $Result,
    [int] $ExitCode = 0,
    [string] $Output = "",
    [string] $Notes = ""
) {
    $script:steps += [ordered]@{
        name = $Name
        command = $Command
        workingDirectory = $WorkingDirectory
        result = $Result
        exitCode = $ExitCode
        output = Limit-Text $Output
        notes = $Notes
    }
    if ($Result -eq "failed") {
        $script:failureCount += 1
    }
}

function Invoke-Step([object] $Step) {
    $resolvedWorkingDirectory = Resolve-ProjectPath $Step.workingDirectory
    Write-Host ""
    Write-Host "==> $($Step.name)"
    Write-Host "    $($Step.command)"
    Push-Location $resolvedWorkingDirectory
    try {
        $outputLines = & $Step.executable @($Step.arguments) 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    $output = ($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($output) {
        Write-Host $output
    }
    if ($exitCode -ne 0) {
        Add-StepResult $Step.name $Step.command $resolvedWorkingDirectory "failed" $exitCode $output ""
        throw "$($Step.name) failed with exit code $exitCode."
    }
    Add-StepResult $Step.name $Step.command $resolvedWorkingDirectory "passed" $exitCode $output ""
}

function New-Commands() {
    $commands = @(
        (New-StepCommand "IAM/RBAC matrix verifier" (Get-PowerShellExecutable) @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            ".\scripts\verify-iam-rbac-matrix.ps1"
        ) "."),
        (New-StepCommand "Kubernetes RBAC matrix verifier" (Get-PowerShellExecutable) @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            ".\scripts\verify-kubernetes-rbac-matrix.ps1"
        ) ".")
    )

    if ($RunBackendPolicyTests) {
        $commands += New-StepCommand "Backend focused RBAC tests" (Get-GradleExecutable) @(
            "test",
            "--tests",
            "com.example.osmu.auth.AdminRbacPolicyTest",
            "--tests",
            "com.example.osmu.user.AdminUserControllerTest",
            "--tests",
            "com.example.osmu.dashboard.DashboardLayoutControllerTest"
        ) ".\osmu-backend"
    }

    if ($RunKubernetesLiveAuth) {
        $commands += New-StepCommand "Storage expansion live RBAC auth" (Get-PowerShellExecutable) @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            ".\scripts\verify-storage-expansion-rbac-auth.ps1",
            "-Namespace",
            $Namespace,
            "-ServiceAccount",
            $ServiceAccount,
            "-KubectlPath",
            $KubectlPath
        ) "."
    }

    return $commands
}

function Write-Report([string] $ResultValue, [string] $Status, [object[]] $Commands, [string[]] $Gaps) {
    if ($NoWrite) {
        return
    }

    $completedAt = [DateTimeOffset]::UtcNow
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    $report = [ordered]@{
        formatVersion = "osmu.iam-rbac-finalize.v1"
        generatedAt = $completedAt.ToString("o")
        startedAt = $startedAt.ToString("o")
        completedAt = $completedAt.ToString("o")
        result = $ResultValue
        status = $Status
        namespace = $Namespace
        serviceAccount = $ServiceAccount
        powerShellCommand = Get-PowerShellExecutable
        gradleCommand = Get-GradleExecutable
        runBackendPolicyTests = [bool] $RunBackendPolicyTests
        runKubernetesLiveAuth = [bool] $RunKubernetesLiveAuth
        commands = @($Commands | ForEach-Object {
            [ordered]@{
                name = $_.name
                executable = $_.executable
                arguments = $_.arguments
                workingDirectory = Resolve-ProjectPath $_.workingDirectory
                command = $_.command
            }
        })
        steps = $steps
        failedCount = $failureCount
        gaps = $Gaps
        decisionRule = "IAM/RBAC finalization passes when the application IAM/RBAC matrix and Kubernetes RBAC matrix verifiers pass. Backend focused tests and live kubectl auth can-i evidence are optional stronger evidence selected by flags."
        secretPolicy = "IAM/RBAC finalizer does not read or write passwords, API keys, kubeconfig contents, bearer tokens, or object storage credentials."
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8

    $markdownLines = @(
        "# OSMU IAM/RBAC Finalize",
        "",
        "Generated at: $($report.generatedAt)",
        "Result: $ResultValue",
        "Status: $Status",
        "Namespace: $Namespace",
        "ServiceAccount: $ServiceAccount",
        "",
        "## Decision Rule",
        "",
        $report.decisionRule,
        "",
        "## Commands",
        ""
    )
    foreach ($command in $Commands) {
        $markdownLines += "- $($command.name): ``$($command.command)``"
    }

    $markdownLines += ""
    $markdownLines += "## Steps"
    if ($steps.Count -eq 0) {
        $markdownLines += "- No steps executed."
    }
    else {
        foreach ($step in $steps) {
            $markdownLines += "- [$($step.result)] $($step.name): exitCode=$($step.exitCode)"
        }
    }

    $markdownLines += ""
    $markdownLines += "## Gaps"
    if ($Gaps.Count -eq 0) {
        $markdownLines += "- None"
    }
    else {
        foreach ($gap in $Gaps) {
            $markdownLines += "- $gap"
        }
    }

    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "IAM/RBAC finalizer JSON: $resolvedJsonOutputPath"
    Write-Host "IAM/RBAC finalizer markdown: $resolvedMarkdownOutputPath"
    Write-Host ($markdownLines -join [Environment]::NewLine)
}

$commands = @(New-Commands)
$gaps = @()

if (-not $RunBackendPolicyTests) {
    $gaps += "Backend focused RBAC JUnit tests were not selected."
}
if (-not $RunKubernetesLiveAuth) {
    $gaps += "Live kubectl auth can-i evidence was not selected."
}

if ($PlanOnly) {
    Write-Host "IAM/RBAC finalizer plan only."
    foreach ($command in $commands) {
        Write-Host "- $($command.name): $($command.command)"
    }
    $gaps += "Plan only; IAM/RBAC evidence commands were not executed."
    Write-Report "planned" "iam-rbac-finalize-plan" $commands $gaps
    return
}

try {
    foreach ($command in $commands) {
        Invoke-Step $command
    }

    $status = if ($RunBackendPolicyTests -and $RunKubernetesLiveAuth) {
        "iam-rbac-live-and-backend-passed"
    }
    elseif ($RunBackendPolicyTests) {
        "iam-rbac-backend-passed"
    }
    elseif ($RunKubernetesLiveAuth) {
        "iam-rbac-live-passed"
    }
    else {
        "iam-rbac-static-passed"
    }
    Write-Report "passed" $status $commands $gaps
}
catch {
    $gaps += $_.Exception.Message
    Write-Report "failed" "iam-rbac-finalize-failed" $commands $gaps
    if ($FailIfNotPassed) {
        throw
    }
    throw
}

if ($FailIfNotPassed -and $failureCount -gt 0) {
    throw "IAM/RBAC finalizer did not pass."
}
