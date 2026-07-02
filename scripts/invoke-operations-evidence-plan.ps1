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
    [string] $PowerShellCommand = "",
    [string] $GitHubCliPath = "",
    [switch] $UseGitHubApi,
    [string] $GitHubRepository = "",
    [string] $GitHubRef = "main",
    [string] $GitHubApiBaseUrl = "https://api.github.com"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
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

function Get-IntOrDefault([object] $Object, [string] $Name, [int] $DefaultValue) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return $DefaultValue
    }
    if ($value -is [int]) {
        return [int] $value
    }
    if ($value -is [long]) {
        return [int] $value
    }
    $parsed = 0
    if ([int]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return $DefaultValue
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

function Resolve-GitHubCliCandidate([string] $PathValue) {
    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ""
    }
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $PathValue))
}

function Test-GitHubWorkflowCommand([string] $Command) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $false
    }
    return $Command.Trim().ToLowerInvariant().StartsWith("gh workflow run ")
}
function Normalize-GitHubRepositorySlug([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }
    $trimmed = $Value.Trim()
    if ($trimmed -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        if ($trimmed.EndsWith(".git", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $trimmed.Substring(0, $trimmed.Length - 4)
        }
        return $trimmed
    }
    if ($trimmed -match '^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?/?$') {
        return $matches[1]
    }
    if ($trimmed -match '^git@github\.com:([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?$') {
        return $matches[1]
    }
    return ""
}

function Resolve-GitHubRepositorySlug([string] $ExplicitRepository) {
    $explicit = Normalize-GitHubRepositorySlug $ExplicitRepository
    if (-not [string]::IsNullOrWhiteSpace($explicit)) {
        return $explicit
    }
    $environmentRepository = Normalize-GitHubRepositorySlug $env:GITHUB_REPOSITORY
    if (-not [string]::IsNullOrWhiteSpace($environmentRepository)) {
        return $environmentRepository
    }
    try {
        $remote = git -C $root config --get remote.origin.url 2>$null
        return Normalize-GitHubRepositorySlug ([string] $remote)
    }
    catch {
        return ""
    }
}

function Convert-GitHubWorkflowCommandToDispatch([string] $Command) {
    $parts = @($Command.Trim() -split '\s+')
    if ($parts.Count -lt 4 -or $parts[0] -ne "gh" -or $parts[1] -ne "workflow" -or $parts[2] -ne "run") {
        throw "Unsupported GitHub workflow command: $Command"
    }

    $workflow = [string] $parts[3]
    if ($workflow.Contains("/") -or $workflow.Contains("\")) {
        $workflow = [System.IO.Path]::GetFileName($workflow)
    }

    $inputs = [ordered]@{}
    for ($i = 4; $i -lt $parts.Count; $i++) {
        $part = [string] $parts[$i]
        if ($part -eq "-f" -or $part -eq "--field" -or $part -eq "-F") {
            if ($i + 1 -ge $parts.Count) {
                throw "Missing value after $part in GitHub workflow command."
            }
            $field = [string] $parts[$i + 1]
            $separatorIndex = $field.IndexOf("=")
            if ($separatorIndex -le 0) {
                throw "Workflow input must use name=value format: $field"
            }
            $name = $field.Substring(0, $separatorIndex)
            $value = $field.Substring($separatorIndex + 1)
            $inputs[$name] = $value
            $i++
        }
        else {
            throw "Unsupported gh workflow run argument for API dispatch: $part"
        }
    }

    return [ordered]@{
        workflow = $workflow
        inputs = $inputs
    }
}

function Invoke-GitHubWorkflowDispatchApi([string] $Command) {
    $repositorySlug = $script:ResolvedGitHubRepositorySlug
    if ([string]::IsNullOrWhiteSpace($repositorySlug)) {
        throw "GitHub repository is required for API dispatch. Pass -GitHubRepository owner/repo or set GITHUB_REPOSITORY."
    }
    $token = if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) { $env:GH_TOKEN } else { $env:GITHUB_TOKEN }
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "GH_TOKEN or GITHUB_TOKEN is required for GitHub workflow dispatch through the REST API."
    }
    if ([string]::IsNullOrWhiteSpace($GitHubRef)) {
        throw "GitHubRef is required for GitHub workflow dispatch through the REST API."
    }

    $dispatch = Convert-GitHubWorkflowCommandToDispatch $Command
    $encodedWorkflow = [System.Uri]::EscapeDataString([string] $dispatch.workflow)
    $base = if ([string]::IsNullOrWhiteSpace($GitHubApiBaseUrl)) { "https://api.github.com" } else { $GitHubApiBaseUrl.TrimEnd("/") }
    $uri = "$base/repos/$repositorySlug/actions/workflows/$encodedWorkflow/dispatches"
    $body = [ordered]@{
        ref = $GitHubRef
    }
    if ($dispatch.inputs.Count -gt 0) {
        $body.inputs = $dispatch.inputs
    }

    $headers = @{
        "Accept" = "application/vnd.github+json"
        "Authorization" = "Bearer $token"
        "User-Agent" = "OSMU-operations-evidence-plan-invocation"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    $json = $body | ConvertTo-Json -Depth 10 -Compress
    try {
        Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -ContentType "application/json" -Body $json | Out-Null
        return [ordered]@{
            exitCode = 0
            output = @("workflow dispatch accepted: workflow=$($dispatch.workflow) ref=$GitHubRef repository=$repositorySlug")
        }
    }
    catch {
        return [ordered]@{
            exitCode = 1
            output = @("GitHub workflow dispatch failed for $($dispatch.workflow): $($_.Exception.Message)")
        }
    }
}

function Get-GitHubCliExecutionSource {
    if (-not [string]::IsNullOrWhiteSpace($script:ResolvedGitHubCliPath)) {
        if (Test-Path -LiteralPath $script:ResolvedGitHubCliPath) {
            return $script:ResolvedGitHubCliPath
        }
        return ""
    }
    $command = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return ""
    }
    return [string] $command.Source
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

function Test-KnownPlaceholderValue([string] $Placeholder, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }
    switch ($Placeholder) {
        "<YYYYMMDDTHHMMSSZ>" { return $Value -match '^\d{8}T\d{6}Z$' }
        "YYYYMMDDTHHMMSSZ" { return $Value -match '^\d{8}T\d{6}Z$' }
        "<restore-api-base>" { return $Value -match '^https?://[^\s]+$' }
        "<count>" { return $Value -match '^\d+$' }
        default { return $true }
    }
}

function Get-InvalidReplacementPlaceholders([string] $Command, [hashtable] $Map) {
    $invalid = New-Object System.Collections.Generic.List[string]
    foreach ($placeholder in @(Get-UnresolvedPlaceholders $Command)) {
        if (-not $Map.ContainsKey($placeholder)) {
            continue
        }
        $value = [string] $Map[$placeholder]
        if (-not (Test-KnownPlaceholderValue $placeholder $value)) {
            $invalid.Add($placeholder)
        }
    }
    return @($invalid)
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
    if ($UseGitHubApi -and (Test-GitHubWorkflowCommand $Command)) {
        return Invoke-GitHubWorkflowDispatchApi $Command
    }

    $previousPath = $env:Path
    if ((Test-GitHubWorkflowCommand $Command) -and -not [string]::IsNullOrWhiteSpace($script:ResolvedGitHubCliPath)) {
        $githubCliDirectory = Split-Path -Parent $script:ResolvedGitHubCliPath
        $env:Path = "$githubCliDirectory;$env:Path"
    }

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

    try {
        $output = & $pwsh @arguments 2>&1
        $exitCode = if ($null -eq $global:LASTEXITCODE) { 0 } else { [int] $global:LASTEXITCODE }
        return [ordered]@{
            exitCode = $exitCode
            output = @($output | ForEach-Object { [string] $_ })
        }
    }
    finally {
        $env:Path = $previousPath
    }
}

$resolvedPlanPath = Resolve-ProjectPath $PlanPath
if (-not (Test-Path -LiteralPath $resolvedPlanPath)) {
    throw "Operations evidence plan not found: $resolvedPlanPath"
}

$plan = Read-Utf8Text $resolvedPlanPath | ConvertFrom-Json
if ($plan.formatVersion -ne "osmu.operations-evidence-plan.v1") {
    throw "Unexpected operations evidence plan formatVersion: $($plan.formatVersion)"
}

$replacementMap = New-ReplacementMap
$script:ResolvedGitHubCliPath = Resolve-GitHubCliCandidate $GitHubCliPath
$script:ResolvedGitHubRepositorySlug = Resolve-GitHubRepositorySlug $GitHubRepository
$githubCliExecutionSource = Get-GitHubCliExecutionSource
$actionResults = New-Object System.Collections.Generic.List[object]
$allActions = @($plan.actions)
$selectedActions = @($allActions | Where-Object { Test-ActionSelected $_ })
$selectedActionOrders = @($selectedActions | ForEach-Object { [int] (Get-JsonProperty $_ "order") } | Where-Object { $_ -gt 0 } | Sort-Object -Unique)

foreach ($action in $selectedActions) {
    $command = Select-ActionCommand $action
    $resolvedCommand = Apply-Replacements $command $replacementMap
    $unresolvedPlaceholders = @(Get-UnresolvedPlaceholders $resolvedCommand)
    $invalidPlaceholders = @(Get-InvalidReplacementPlaceholders $command $replacementMap)
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
    foreach ($placeholder in $invalidPlaceholders) {
        $blockReasons.Add("invalid placeholder value for $placeholder")
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
    if ($Execute -and $UseGitHubApi -and (Test-GitHubWorkflowCommand $resolvedCommand)) {
        if ([string]::IsNullOrWhiteSpace($script:ResolvedGitHubRepositorySlug)) {
            $blockReasons.Add("GitHub repository not resolved for API dispatch")
        }
        $tokenPresent = (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) -or (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN))
        if (-not $tokenPresent) {
            $blockReasons.Add("GH_TOKEN or GITHUB_TOKEN not set for API dispatch")
        }
        if ([string]::IsNullOrWhiteSpace($GitHubRef)) {
            $blockReasons.Add("GitHubRef not set for API dispatch")
        }
    }
    elseif ($Execute -and (Test-GitHubWorkflowCommand $resolvedCommand) -and [string]::IsNullOrWhiteSpace($githubCliExecutionSource)) {
        if ([string]::IsNullOrWhiteSpace($script:ResolvedGitHubCliPath)) {
            $blockReasons.Add("GitHub CLI not found on PATH")
        }
        else {
            $blockReasons.Add("GitHub CLI not found at explicit path: $script:ResolvedGitHubCliPath")
        }
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
                    invalidPlaceholders = @($invalidPlaceholders)
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
        invalidPlaceholders = @($invalidPlaceholders)
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
$sourcePassedCount = Get-IntOrDefault $plan "sourcePassedCount" 0
$sourcePendingCount = Get-IntOrDefault $plan "sourcePendingCount" 0
$sourceTotalCount = Get-IntOrDefault $plan "sourceTotalCount" 0
$sourceCheckCount = Get-IntOrDefault $plan "sourceCheckCount" 0
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
    sourcePassedCount = $sourcePassedCount
    sourcePendingCount = $sourcePendingCount
    sourceTotalCount = $sourceTotalCount
    sourceCheckCount = $sourceCheckCount
    commandMode = $CommandMode
    executionMode = if ($Execute) { "execute" } else { "plan-only" }
    githubCliPath = $script:ResolvedGitHubCliPath
    githubCliExecutionSource = $githubCliExecutionSource
    useGitHubApi = [bool] $UseGitHubApi
    githubRepository = $script:ResolvedGitHubRepositorySlug
    githubRef = $GitHubRef
    githubApiBaseUrl = $GitHubApiBaseUrl
    selectedActionCount = $selectedCount
    selectedActionOrders = @($selectedActionOrders)
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
    "Source counts: passed=$sourcePassedCount pending=$sourcePendingCount total=$sourceTotalCount checks=$sourceCheckCount",
    "Command mode: $CommandMode",
    "Execution mode: $($report.executionMode)",
    "GitHub CLI path: $(if ([string]::IsNullOrWhiteSpace($script:ResolvedGitHubCliPath)) { 'PATH lookup' } else { $script:ResolvedGitHubCliPath })",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Summary",
    "",
    "- Selected actions: $selectedCount",
    "- Selected action orders: $(if ($selectedActionOrders.Count -gt 0) { $selectedActionOrders -join ', ' } else { 'none' })",
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
