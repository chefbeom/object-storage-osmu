param(
    [string] $PlanPath = ".\.osmu-run\latest-operations-evidence-plan.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-evidence-plan-invocation.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-evidence-plan-invocation.md",
    [ValidateSet("Workflow", "Local", "Recommended")]
    [string] $CommandMode = "Workflow",
    [int[]] $ActionOrder = @(),
    [string[]] $Category = @(),
    [string[]] $Placeholder = @(),
    [string] $BackupTimestamp = "",
    [string] $RestoreApiBase = "",
    [string] $AdminLoginId = "",
    [string] $AdminPassword = "",
    [string] $ExpectedObjectCount = "",
    [switch] $ConfirmOperatorApproval,
    [switch] $KubeconfigSecretConfirmed,
    [switch] $Execute,
    [switch] $ContinueOnError,
    [switch] $AllowUnsafeCommand,
    [switch] $NoWrite,
    [string] $PowerShellCommand = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
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

function Get-Bool([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return $false
    }
    return [System.Convert]::ToBoolean($value)
}

function Get-ObjectValue([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    return Get-JsonProperty $Object $Name
}

function Count-ActionResultStatus([System.Collections.IEnumerable] $Results, [string] $Status) {
    $count = 0
    foreach ($result in $Results) {
        if ([string] (Get-ObjectValue $result "status") -eq $Status) {
            $count++
        }
    }
    return $count
}

function Add-Replacement([hashtable] $Map, [string] $Name, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    $Map[$Name] = $Value
}

function New-ReplacementMap {
    $map = @{}
    Add-Replacement $map "<YYYYMMDDTHHMMSSZ>" $BackupTimestamp
    Add-Replacement $map "YYYYMMDDTHHMMSSZ" $BackupTimestamp
    Add-Replacement $map "<restore-api-base>" $RestoreApiBase
    Add-Replacement $map "<admin>" $AdminLoginId
    Add-Replacement $map "<secret>" $AdminPassword
    Add-Replacement $map "<count>" $ExpectedObjectCount

    foreach ($entry in $Placeholder) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }
        $separatorIndex = $entry.IndexOf("=")
        if ($separatorIndex -le 0) {
            throw "Placeholder entries must use '<placeholder>=value' format. Invalid entry: $entry"
        }
        $name = $entry.Substring(0, $separatorIndex).Trim()
        $value = $entry.Substring($separatorIndex + 1)
        Add-Replacement $map $name $value
    }
    return $map
}

function Apply-Replacements([string] $Command, [hashtable] $Map) {
    $result = $Command
    foreach ($key in $Map.Keys) {
        $result = $result.Replace([string] $key, [string] $Map[$key])
    }
    return $result
}

function Get-UnresolvedPlaceholders([string] $Command) {
    $placeholders = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return @($placeholders)
    }
    foreach ($match in [regex]::Matches($Command, "<[^>]+>|YYYYMMDDTHHMMSSZ")) {
        $value = $match.Value
        if ($value -eq "YYYYMMDDTHHMMSSZ" -and $placeholders.Contains("<YYYYMMDDTHHMMSSZ>")) {
            continue
        }
        if (-not $placeholders.Contains($value)) {
            $placeholders.Add($value)
        }
    }
    return @($placeholders)
}

function Select-ActionCommand([object] $Action) {
    $recommendedCommand = Get-Text $Action "recommendedCommand"
    $workflowCommand = Get-Text $Action "workflowCommand"
    $localCommand = Get-Text $Action "localCommand"

    if ($CommandMode -eq "Local") {
        if (-not [string]::IsNullOrWhiteSpace($localCommand)) {
            return $localCommand
        }
        return $recommendedCommand
    }
    if ($CommandMode -eq "Recommended") {
        if (-not [string]::IsNullOrWhiteSpace($recommendedCommand)) {
            return $recommendedCommand
        }
        if (-not [string]::IsNullOrWhiteSpace($workflowCommand)) {
            return $workflowCommand
        }
        return $localCommand
    }
    if (-not [string]::IsNullOrWhiteSpace($workflowCommand)) {
        return $workflowCommand
    }
    if (-not [string]::IsNullOrWhiteSpace($recommendedCommand)) {
        return $recommendedCommand
    }
    return $localCommand
}

function Test-ActionSelected([object] $Action) {
    $order = [int] (Get-JsonProperty $Action "order")
    $categoryValue = Get-Text $Action "category"
    $hasOrderFilter = $ActionOrder -and $ActionOrder.Count -gt 0
    $hasCategoryFilter = $Category -and $Category.Count -gt 0

    if ($hasOrderFilter -and -not ($ActionOrder -contains $order)) {
        return $false
    }
    if ($hasCategoryFilter -and -not ($Category -contains $categoryValue)) {
        return $false
    }
    return $true
}

function Test-SafeCommand([string] $Command) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $false
    }
    $trimmed = $Command.Trim()
    $lower = $trimmed.ToLowerInvariant()
    $unsafeFragments = @("`r", "`n", ";", "&&", "||", "|", "'", '"', '`', '$(', '@(')
    foreach ($fragment in $unsafeFragments) {
        if ($trimmed.Contains($fragment)) {
            return $false
        }
    }
    if ($trimmed -match '(^|\s)(\d|\*)?>{1,2}(\s|$)') {
        return $false
    }
    return (
        $lower.StartsWith("gh workflow run ") -or
        $lower.StartsWith("powershell -noprofile -executionpolicy bypass -file .\scripts\") -or
        $lower.StartsWith("pwsh -noprofile -executionpolicy bypass -file .\scripts\")
    )
}

function Invoke-CommandString([string] $Command) {
    $pwsh = $PowerShellCommand
    if ([string]::IsNullOrWhiteSpace($pwsh)) {
        if ($PSVersionTable.PSEdition -eq "Core") {
            $pwsh = "pwsh"
        }
        else {
            $pwsh = "powershell"
        }
    }

    $arguments = @("-NoProfile", "-Command", $Command)
    if ($pwsh -eq "powershell") {
        $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $Command)
    }

    $output = & $pwsh @arguments 2>&1
    $exitCode = if ($null -eq $global:LASTEXITCODE) { 0 } else { [int] $global:LASTEXITCODE }
    return [ordered]@{
        exitCode = $exitCode
        output = @($output | ForEach-Object { [string] $_ })
    }
}

$resolvedPlanPath = Resolve-ProjectPath $PlanPath
if (-not (Test-Path -LiteralPath $resolvedPlanPath)) {
    throw "Operations evidence plan not found: $resolvedPlanPath"
}

$plan = Get-Content -Raw -LiteralPath $resolvedPlanPath | ConvertFrom-Json
if ($plan.formatVersion -ne "osmu.operations-evidence-plan.v1") {
    throw "Unexpected operations evidence plan formatVersion: $($plan.formatVersion)"
}

$replacementMap = New-ReplacementMap
$actionResults = New-Object System.Collections.Generic.List[object]
$allActions = @($plan.actions)
$selectedActions = @($allActions | Where-Object { Test-ActionSelected $_ })

foreach ($action in $selectedActions) {
    $command = Select-ActionCommand $action
    $resolvedCommand = Apply-Replacements $command $replacementMap
    $unresolvedPlaceholders = @(Get-UnresolvedPlaceholders $resolvedCommand)
    $blockReasons = New-Object System.Collections.Generic.List[string]
    $requiresOperatorApproval = Get-Bool $action "requiresOperatorApproval"
    $requiresKubeconfigSecret = Get-Bool $action "requiresKubeconfigSecret"
    $safeCommand = Test-SafeCommand $resolvedCommand

    if ([string]::IsNullOrWhiteSpace($resolvedCommand)) {
        $blockReasons.Add("missing command")
    }
    if ($unresolvedPlaceholders.Count -gt 0) {
        $blockReasons.Add("unresolved placeholders: $($unresolvedPlaceholders -join ', ')")
    }
    if ($requiresOperatorApproval -and -not $ConfirmOperatorApproval) {
        $blockReasons.Add("operator approval not confirmed")
    }
    if ($requiresKubeconfigSecret -and -not $KubeconfigSecretConfirmed) {
        $blockReasons.Add("kubeconfig secret not confirmed")
    }
    if (-not $safeCommand -and -not $AllowUnsafeCommand) {
        $blockReasons.Add("command failed allowlist/shell metacharacter check")
    }

    $status = "planned"
    $exitCode = $null
    $output = @()

    if ($blockReasons.Count -gt 0) {
        $status = "blocked"
    }
    elseif ($Execute) {
        $execution = Invoke-CommandString $resolvedCommand
        $exitCode = $execution.exitCode
        $output = @($execution.output)
        if ($exitCode -eq 0) {
            $status = "executed"
        }
        else {
            $status = "failed"
            if (-not $ContinueOnError) {
                $actionResults.Add([ordered]@{
                    order = [int] (Get-JsonProperty $action "order")
                    name = Get-Text $action "name"
                    category = Get-Text $action "category"
                    actionType = Get-Text $action "actionType"
                    evidencePath = Get-Text $action "evidencePath"
                    commandMode = $CommandMode
                    command = $resolvedCommand
                    status = $status
                    blockReasons = @($blockReasons)
                    unresolvedPlaceholders = @($unresolvedPlaceholders)
                    requiresOperatorApproval = $requiresOperatorApproval
                    requiresKubeconfigSecret = $requiresKubeconfigSecret
                    exitCode = $exitCode
                    output = $output
                })
                break
            }
        }
    }

    $actionResults.Add([ordered]@{
        order = [int] (Get-JsonProperty $action "order")
        name = Get-Text $action "name"
        category = Get-Text $action "category"
        actionType = Get-Text $action "actionType"
        evidencePath = Get-Text $action "evidencePath"
        commandMode = $CommandMode
        command = $resolvedCommand
        status = $status
        blockReasons = @($blockReasons)
        unresolvedPlaceholders = @($unresolvedPlaceholders)
        requiresOperatorApproval = $requiresOperatorApproval
        requiresKubeconfigSecret = $requiresKubeconfigSecret
        exitCode = $exitCode
        output = $output
    })
}

$plannedCount = Count-ActionResultStatus $actionResults "planned"
$blockedCount = Count-ActionResultStatus $actionResults "blocked"
$executedCount = Count-ActionResultStatus $actionResults "executed"
$failedCount = Count-ActionResultStatus $actionResults "failed"
$selectedCount = $actionResults.Count
$result = if ($selectedCount -eq 0) {
    "ready"
}
elseif ($failedCount -gt 0) {
    "failed"
}
elseif ($blockedCount -gt 0) {
    "blocked"
}
elseif ($Execute) {
    "executed"
}
else {
    "planned"
}

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$report = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = $generatedAt
    result = $result
    sourcePlan = $resolvedPlanPath
    sourceResult = Get-Text $plan "result"
    sourceSummary = Get-Text $plan "sourceSummary"
    commandMode = $CommandMode
    executionMode = if ($Execute) { "execute" } else { "plan-only" }
    selectedActionCount = $selectedCount
    plannedCount = $plannedCount
    blockedCount = $blockedCount
    executedCount = $executedCount
    failedCount = $failedCount
    decisionRule = "Only execute actions after placeholders are resolved, operator approval is confirmed when required, kubeconfig secret readiness is confirmed when required, and the command passes the allowlist check. Regenerate operations readiness after execution."
    actions = @($actionResults | ForEach-Object { $_ })
}

$markdownLines = @(
    "# OSMU Operations Evidence Plan Invocation",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source plan: $resolvedPlanPath",
    "Source result: $($report.sourceResult)",
    "Source summary: $($report.sourceSummary)",
    "Command mode: $CommandMode",
    "Execution mode: $($report.executionMode)",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Summary",
    "",
    "- Selected actions: $selectedCount",
    "- Planned: $plannedCount",
    "- Blocked: $blockedCount",
    "- Executed: $executedCount",
    "- Failed: $failedCount",
    "",
    "## Actions",
    ""
)

if ($selectedCount -eq 0) {
    $markdownLines += "- No actions matched the selected filters."
}
else {
    foreach ($action in $actionResults) {
        $markdownLines += "- [$($action.order)] $($action.status) / $($action.category) / $($action.name)"
        $markdownLines += "  - Evidence path: $($action.evidencePath)"
        $markdownLines += "  - Command: ``$($action.command)``"
        if (@($action.blockReasons).Count -gt 0) {
            $markdownLines += "  - Blocked by: $(@($action.blockReasons) -join '; ')"
        }
        if ($null -ne $action.exitCode) {
            $markdownLines += "  - Exit code: $($action.exitCode)"
        }
    }
}

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations evidence plan invocation JSON: $resolvedJsonOutputPath"
    Write-Host "Operations evidence plan invocation markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($Execute -and $failedCount -gt 0) {
    exit 1
}
