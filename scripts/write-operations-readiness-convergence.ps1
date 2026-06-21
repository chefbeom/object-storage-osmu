param(
    [string] $HandoffReportPath = ".\.osmu-run\latest-operations-evidence-handoff.json",
    [string] $ReadinessReportPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $OperationsReadinessFinalizeReportPath = ".\.osmu-run\latest-operations-readiness-finalize.json",
    [string] $KubernetesOperationsReportSyncReportPath = ".\.osmu-run\latest-kubernetes-operations-report-sync.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-readiness-convergence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-readiness-convergence.md",
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-OptionalJson([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        return [ordered]@{
            path = $resolved
            exists = $false
            json = $null
        }
    }
    return [ordered]@{
        path = $resolved
        exists = $true
        json = (Get-Content -Raw -LiteralPath $resolved | ConvertFrom-Json)
    }
}

function Get-JsonProperty([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-Text([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Get-Int([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return 0
    }
    try {
        return [int] $value
    }
    catch {
        return 0
    }
}

function Is-ReadyResult([string] $Result) {
    return @("ready", "passed", "go") -contains $Result.ToLowerInvariant()
}

function New-Command([int] $Order, [string] $Name, [string] $Command, [string] $Reason) {
    return [ordered]@{
        order = $Order
        name = $Name
        command = $Command
        reason = $Reason
    }
}

function Quote-PowerShellArgument([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "''"
    }
    if ($Value -match '^[A-Za-z0-9_./:\\-]+$') {
        return $Value
    }
    return "'" + $Value.Replace("'", "''") + "'"
}

function New-KubernetesReportSyncCommand([object] $Report, [string] $Mode) {
    $arguments = @(
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ".\scripts\sync-kubernetes-operations-reports.ps1"
    )
    $namespace = Get-Text $Report "namespace"
    $configMapName = Get-Text $Report "configMapName"
    $configMapKey = Get-Text $Report "configMapKey"
    $sourceReportPath = Get-Text $Report "sourceReportPath"
    if (-not [string]::IsNullOrWhiteSpace($namespace)) {
        $arguments += @("-Namespace", $namespace)
    }
    if (-not [string]::IsNullOrWhiteSpace($configMapName)) {
        $arguments += @("-ConfigMapName", $configMapName)
    }
    if (-not [string]::IsNullOrWhiteSpace($configMapKey)) {
        $arguments += @("-ConfigMapKey", $configMapKey)
    }
    if (-not [string]::IsNullOrWhiteSpace($sourceReportPath)) {
        $arguments += @("-ReportPath", $sourceReportPath)
    }
    $arguments += $Mode
    return ($arguments | ForEach-Object { Quote-PowerShellArgument $_ }) -join " "
}

function Get-KubernetesReportSyncNextCommand([object] $Report, [bool] $Exists) {
    if (-not $Exists) {
        return "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-kubernetes-operations-reports.ps1 -PlanOnly"
    }
    $result = Get-Text $Report "result"
    if ("planned".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)) {
        return New-KubernetesReportSyncCommand $Report "-ServerDryRunOnly"
    }
    if ("server-dry-run-passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)) {
        return New-KubernetesReportSyncCommand $Report "-Apply"
    }
    return New-KubernetesReportSyncCommand $Report "-PlanOnly"
}

function Get-KubernetesReportSyncWorkflowCommand([object] $Report, [bool] $Exists) {
    $namespace = Get-Text $Report "namespace"
    if ([string]::IsNullOrWhiteSpace($namespace)) {
        $namespace = "osmu"
    }
    $reportPath = Get-Text $Report "sourceReportPath"
    if ([string]::IsNullOrWhiteSpace($reportPath)) {
        $reportPath = "./.osmu-run/latest-operations-readiness-convergence.json"
    }

    $runLive = "false"
    $apply = "false"
    if ($Exists) {
        $result = Get-Text $Report "result"
        if ("planned".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)) {
            $runLive = "true"
        }
        elseif ("server-dry-run-passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)) {
            $runLive = "true"
            $apply = "true"
        }
    }

    return "gh workflow run kubernetes-operations-report-sync-ci.yml -f namespace=$namespace -f report_path=$reportPath -f run_live=$runLive -f apply=$apply -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>"
}

$handoff = Read-OptionalJson $HandoffReportPath
$readiness = Read-OptionalJson $ReadinessReportPath
$finalize = Read-OptionalJson $OperationsReadinessFinalizeReportPath
$kubernetesReportSync = Read-OptionalJson $KubernetesOperationsReportSyncReportPath

$handoffResult = Get-Text $handoff.json "result"
$readinessResult = Get-Text $readiness.json "result"
$finalizerResult = Get-Text $finalize.json "result"
$finalizerReadinessResult = Get-Text $finalize.json "readinessResult"
$kubernetesReportSyncResult = Get-Text $kubernetesReportSync.json "result"
$kubernetesReportSyncFailedCount = Get-Int $kubernetesReportSync.json "failedCount"
$nextStep = Get-JsonProperty $handoff.json "nextStep"
$nextCode = Get-Text $nextStep "code"
$nextCommand = Get-Text $nextStep "command"
$kubernetesReportSyncCommand = Get-KubernetesReportSyncNextCommand $kubernetesReportSync.json $kubernetesReportSync.exists
$kubernetesReportSyncWorkflowCommand = Get-KubernetesReportSyncWorkflowCommand $kubernetesReportSync.json $kubernetesReportSync.exists
$handoffReady = $handoff.exists -and (Is-ReadyResult $handoffResult) -and "none".Equals($nextCode, [System.StringComparison]::OrdinalIgnoreCase)
$readinessReady = $readiness.exists -and (Is-ReadyResult $readinessResult)
$finalizerReady = (-not $finalize.exists) -or ((Is-ReadyResult $finalizerResult) -and (Is-ReadyResult $finalizerReadinessResult))
$kubernetesReportSyncReady = $kubernetesReportSync.exists -and "applied".Equals($kubernetesReportSyncResult, [System.StringComparison]::OrdinalIgnoreCase) -and $kubernetesReportSyncFailedCount -eq 0

$recommendedCommands = @()
$seenCommands = @{}

function Add-RecommendedCommand([string] $Name, [string] $Command, [string] $Reason) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return
    }
    if ($seenCommands.ContainsKey($Command)) {
        return
    }
    $seenCommands[$Command] = $true
    $script:recommendedCommands += New-Command (@($script:recommendedCommands).Count + 1) $Name $Command $Reason
}

if (-not $handoff.exists) {
    Add-RecommendedCommand `
        "Generate operations evidence handoff" `
        "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-handoff.ps1" `
        "The handoff report is missing, so the current bottleneck cannot be selected yet."
}
elseif (-not (Is-ReadyResult $handoffResult) -or -not "none".Equals($nextCode, [System.StringComparison]::OrdinalIgnoreCase)) {
    Add-RecommendedCommand `
        (Get-Text $nextStep "title") `
        $nextCommand `
        (Get-Text $nextStep "reason")

    $stages = Get-JsonProperty $handoff.json "stages"
    foreach ($stage in @($stages)) {
        $stageReady = [bool] (Get-JsonProperty $stage "ready")
        if (-not $stageReady) {
            Add-RecommendedCommand `
                ("Review " + (Get-Text $stage "name")) `
                (Get-Text $stage "command") `
                (Get-Text $stage "note")
        }
    }
}
elseif ($handoffReady -and -not $readinessReady) {
    Add-RecommendedCommand `
        "Regenerate operations readiness" `
        "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1" `
        "The handoff is ready, but the latest operations readiness report is not ready."
}
elseif ($handoffReady -and $readinessReady -and -not $finalizerReady) {
    Add-RecommendedCommand `
        "Finalize operations readiness" `
        "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" `
        "The readiness report is ready, but finalizer evidence is missing or not ready."
}
elseif ($handoffReady -and $readinessReady -and $finalizerReady -and -not $kubernetesReportSyncReady) {
    Add-RecommendedCommand `
        "Sync Kubernetes operations report ConfigMap" `
        $kubernetesReportSyncCommand `
        "The convergence report has not been confirmed as applied to the Kubernetes operations report ConfigMap."
}

$result = if ($handoffReady -and $readinessReady -and $finalizerReady -and $kubernetesReportSyncReady) { "ready" } else { "action-required" }

$currentBottleneck = if (-not $handoff.exists) {
    [ordered]@{
        code = "write-handoff"
        title = "Generate operations evidence handoff"
        reason = "The handoff report is missing."
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-handoff.ps1"
    }
}
elseif ($handoffReady -and -not $readinessReady) {
    [ordered]@{
        code = "regenerate-readiness"
        title = "Regenerate operations readiness"
        reason = "The handoff is ready, but the latest operations readiness report is not ready."
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1"
    }
}
elseif ($handoffReady -and $readinessReady -and -not $finalizerReady) {
    [ordered]@{
        code = "finalize-operations-readiness"
        title = "Finalize operations readiness"
        reason = "The readiness report is ready, but finalizer evidence is missing or not ready."
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1"
    }
}
elseif ($handoffReady -and $readinessReady -and $finalizerReady -and -not $kubernetesReportSyncReady) {
    [ordered]@{
        code = "sync-kubernetes-operations-report"
        title = "Sync Kubernetes operations report ConfigMap"
        reason = "The convergence report has not been confirmed as applied to the Kubernetes operations report ConfigMap."
        command = $kubernetesReportSyncCommand
    }
}
else {
    [ordered]@{
        code = $nextCode
        title = Get-Text $nextStep "title"
        reason = Get-Text $nextStep "reason"
        command = $nextCommand
    }
}

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$report = [ordered]@{
    formatVersion = "osmu.operations-readiness-convergence.v1"
    generatedAt = $generatedAt
    result = $result
    handoffReportPath = $handoff.path
    readinessReportPath = $readiness.path
    operationsReadinessFinalizeReportPath = $finalize.path
    kubernetesOperationsReportSyncReportPath = $kubernetesReportSync.path
    handoffExists = [bool] $handoff.exists
    handoffResult = $handoffResult
    readinessExists = [bool] $readiness.exists
    readinessResult = $readinessResult
    readinessSummary = Get-Text $readiness.json "summary"
    finalizerExists = [bool] $finalize.exists
    finalizerResult = $finalizerResult
    finalizerReadinessResult = $finalizerReadinessResult
    finalizerFailedCount = Get-Int $finalize.json "failedCount"
    kubernetesReportSyncExists = [bool] $kubernetesReportSync.exists
    kubernetesReportSyncResult = $kubernetesReportSyncResult
    kubernetesReportSyncFailedCount = $kubernetesReportSyncFailedCount
    kubernetesReportSyncConfigMapName = Get-Text $kubernetesReportSync.json "configMapName"
    kubernetesReportSyncConfigMapKey = Get-Text $kubernetesReportSync.json "configMapKey"
    kubernetesReportSyncSourceReportResult = Get-Text $kubernetesReportSync.json "sourceReportResult"
    kubernetesReportSyncWorkflowCommand = $kubernetesReportSyncWorkflowCommand
    kubernetesReportSyncWorkflowNote = "For GitHub Actions sync, include data_flow_storage_plan_json_base64 only when .osmu-run/latest-data-flow-storage-plan.json should be carried into the operations report ConfigMap; omit the input when no target analytics-storage plan evidence is ready."
    kubernetesReportSyncReady = [bool] $kubernetesReportSyncReady
    finalizerGapCount = Get-Int $handoff.json "finalizerGapCount"
    stageCount = Get-Int $handoff.json "stageCount"
    readyStageCount = Get-Int $handoff.json "readyStageCount"
    blockedActionCount = Get-Int $handoff.json "blockedActionCount"
    missingWorkflowRunCount = Get-Int $handoff.json "missingWorkflowRunCount"
    missingRequiredArtifactCount = Get-Int $handoff.json "missingRequiredArtifactCount"
    failedImportCount = Get-Int $handoff.json "failedImportCount"
    currentBottleneck = $currentBottleneck
    recommendedCommands = $recommendedCommands
    decisionRule = "Operations readiness convergence is ready only when the handoff result is ready/none, the readiness report is ready, any finalizer report confirms readinessResult=ready, and the Kubernetes operations report sync evidence confirms result=applied with zero failed checks."
    safetyPolicy = "This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance."
}

$markdownLines = @(
    "# OSMU Operations Readiness Convergence",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "",
    "## Current Bottleneck",
    "",
    "- Code: $($currentBottleneck.code)",
    "- Title: $($currentBottleneck.title)",
    "- Reason: $($currentBottleneck.reason)",
    "- Command: ``$($currentBottleneck.command)``",
    "",
    "## Status",
    "",
    "- Handoff: $handoffResult",
    "- Readiness: $readinessResult",
    "- Readiness summary: $($report.readinessSummary)",
    "- Finalizer: $finalizerResult",
    "- Finalizer readiness: $finalizerReadinessResult",
    "- Kubernetes report sync: $kubernetesReportSyncResult",
    "- Kubernetes report sync ready: $kubernetesReportSyncReady",
    "- Kubernetes report sync ConfigMap: $($report.kubernetesReportSyncConfigMapName)",
    "- Kubernetes report sync workflow: ``$($report.kubernetesReportSyncWorkflowCommand)``",
    "- Kubernetes report sync workflow note: $($report.kubernetesReportSyncWorkflowNote)",
    "- Stages: $($report.readyStageCount)/$($report.stageCount) ready",
    "- Blocked actions: $($report.blockedActionCount)",
    "- Missing workflow runs: $($report.missingWorkflowRunCount)",
    "- Missing required artifacts: $($report.missingRequiredArtifactCount)",
    "- Finalizer gaps: $($report.finalizerGapCount)",
    "",
    "## Recommended Commands",
    ""
)
if ($recommendedCommands.Count -eq 0) {
    $markdownLines += "- None"
}
else {
    foreach ($command in $recommendedCommands) {
        $markdownLines += "- $($command.order). $($command.name): ``$($command.command)``"
        if (-not [string]::IsNullOrWhiteSpace($command.reason)) {
            $markdownLines += "  - Reason: $($command.reason)"
        }
    }
}
$markdownLines += ""
$markdownLines += "## Safety Policy"
$markdownLines += ""
$markdownLines += "- $($report.safetyPolicy)"

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    $markdownLines | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations readiness convergence JSON: $resolvedJsonOutputPath"
    Write-Host "Operations readiness convergence markdown: $resolvedMarkdownOutputPath"
}

$report | ConvertTo-Json -Depth 12
