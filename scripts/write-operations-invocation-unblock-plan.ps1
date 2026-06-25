param(
    [string] $InvocationReportPath = ".\.osmu-run\latest-operations-evidence-plan-invocation.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-invocation-unblock-plan.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-invocation-unblock-plan.md",
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

function Get-Bool([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return $false
    }
    return [System.Convert]::ToBoolean($value)
}

function Get-TextArray([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return @()
    }
    if ($value -is [System.Array]) {
        return @($value | ForEach-Object { [string] $_ })
    }
    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
        return @($value | ForEach-Object { [string] $_ })
    }
    return @([string] $value)
}

function Get-PlaceholderParameter([string] $Placeholder) {
    switch ($Placeholder) {
        "<YYYYMMDDTHHMMSSZ>" { return "BackupTimestamp" }
        "YYYYMMDDTHHMMSSZ" { return "BackupTimestamp" }
        "<restore-api-base>" { return "RestoreApiBase" }
        "<admin>" { return "AdminLoginId" }
        "<secret>" { return "AdminPassword" }
        "<count>" { return "ExpectedObjectCount" }
        default { return "Placeholder" }
    }
}

function Get-PlaceholderValueTemplate([string] $Placeholder) {
    switch ($Placeholder) {
        "<YYYYMMDDTHHMMSSZ>" { return "<YYYYMMDDTHHMMSSZ>" }
        "YYYYMMDDTHHMMSSZ" { return "<YYYYMMDDTHHMMSSZ>" }
        "<restore-api-base>" { return "<restore-api-base>" }
        "<admin>" { return "<admin>" }
        "<secret>" { return "<secret>" }
        "<count>" { return "<count>" }
        default { return $Placeholder }
    }
}

function Count-PlaceholderOccurrences([string] $Command, [string] $Placeholder) {
    if ([string]::IsNullOrWhiteSpace($Command) -or [string]::IsNullOrWhiteSpace($Placeholder)) {
        return 0
    }
    return ([regex]::Matches($Command, [regex]::Escape($Placeholder))).Count
}

function Get-PlaceholderWorkflowInputs([string] $Command, [string] $Placeholder) {
    if ([string]::IsNullOrWhiteSpace($Command) -or [string]::IsNullOrWhiteSpace($Placeholder)) {
        return @()
    }
    $names = New-Object System.Collections.Generic.List[string]
    $pattern = '(?<!\S)-f\s+([A-Za-z0-9_-]+)=["'']?' + [regex]::Escape($Placeholder)
    foreach ($match in [regex]::Matches($Command, $pattern)) {
        $name = [string] $match.Groups[1].Value
        if (-not [string]::IsNullOrWhiteSpace($name) -and -not $names.Contains($name)) {
            $names.Add($name)
        }
    }
    return @($names)
}

function New-RequiredInput([string] $Placeholder, [string] $Command, [string] $ActionName) {
    $parameter = Get-PlaceholderParameter $Placeholder
    $occurrenceCount = Count-PlaceholderOccurrences $Command $Placeholder
    $workflowInputs = @(Get-PlaceholderWorkflowInputs $Command $Placeholder)
    $workflowInputNote = if ($workflowInputs.Count -gt 0) {
        " Workflow inputs: $($workflowInputs -join ', ')."
    }
    else {
        ""
    }
    $ambiguous = $occurrenceCount -gt 1 -and $parameter -eq "Placeholder"
    $note = if ($ambiguous) {
        "This placeholder appears $occurrenceCount times in '$ActionName'. The invocation helper replaces identical placeholder names with one value; prefer workflow run id/artifact collection helpers when values differ.$workflowInputNote"
    }
    else {
        "Provide a concrete value before planning or executing this action.$workflowInputNote"
    }
    return [ordered]@{
        placeholder = $Placeholder
        parameter = $parameter
        valueTemplate = (Get-PlaceholderValueTemplate $Placeholder)
        workflowInputs = @($workflowInputs)
        occurrenceCount = $occurrenceCount
        ambiguousRepeatedPlaceholder = $ambiguous
        note = $note
    }
}

function Join-ActionOrders([int[]] $Orders) {
    if ($null -eq $Orders -or $Orders.Count -eq 0) {
        return ""
    }
    return ($Orders | ForEach-Object { [string] $_ }) -join ","
}

function Add-UniqueString([System.Collections.Generic.List[string]] $List, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    if (-not $List.Contains($Value)) {
        $List.Add($Value)
    }
}

function New-InvokeCommand([int[]] $Orders, [bool] $NeedKubeconfig, [bool] $NeedApproval, [string[]] $Placeholders) {
    if ($null -eq $Orders -or $Orders.Count -eq 0) {
        return ""
    }
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add("powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1")
    $parts.Add("-ActionOrder $(Join-ActionOrders $Orders)")
    if ($NeedKubeconfig) {
        $parts.Add("-KubeconfigSecretConfirmed")
    }
    if ($NeedApproval) {
        $parts.Add("-ConfirmOperatorApproval")
    }
    foreach ($placeholder in $Placeholders) {
        $parameter = Get-PlaceholderParameter $placeholder
        $valueTemplate = Get-PlaceholderValueTemplate $placeholder
        if ($parameter -eq "Placeholder") {
            $parts.Add("-Placeholder '$placeholder=$valueTemplate'")
        }
        else {
            $parts.Add("-$parameter $valueTemplate")
        }
    }
    return ($parts -join " ")
}

$resolvedInvocationPath = Resolve-ProjectPath $InvocationReportPath
if (-not (Test-Path -LiteralPath $resolvedInvocationPath)) {
    throw "Operations evidence invocation report not found: $resolvedInvocationPath"
}

$invocation = Get-Content -Raw -LiteralPath $resolvedInvocationPath | ConvertFrom-Json
if ($invocation.formatVersion -ne "osmu.operations-evidence-plan-invocation.v1") {
    throw "Unexpected operations evidence invocation formatVersion: $($invocation.formatVersion)"
}

$actionPlans = New-Object System.Collections.ArrayList
$blockedOrders = New-Object System.Collections.Generic.List[int]
$plannedOrders = New-Object System.Collections.Generic.List[int]
$allSelectedOrders = New-Object System.Collections.Generic.List[int]
$allRequiredPlaceholders = New-Object System.Collections.Generic.List[string]
$needsKubeconfig = $false
$needsApproval = $false
$ambiguousRepeatedPlaceholderCount = 0

foreach ($action in @($invocation.actions)) {
    $order = Get-Int $action "order"
    $name = Get-Text $action "name"
    $status = Get-Text $action "status"
    $command = Get-Text $action "command"
    $blockReasons = @(Get-TextArray $action "blockReasons")
    $placeholders = @(Get-TextArray $action "unresolvedPlaceholders")
    $invalidPlaceholders = @(Get-TextArray $action "invalidPlaceholders")
    $requiresOperatorApproval = Get-Bool $action "requiresOperatorApproval"
    $requiresKubeconfigSecret = Get-Bool $action "requiresKubeconfigSecret"
    $needsActionKubeconfig = $requiresKubeconfigSecret -and ($blockReasons -contains "kubeconfig secret not confirmed")
    $needsActionApproval = $requiresOperatorApproval -and ($blockReasons -contains "operator approval not confirmed")
    $requiredInputs = New-Object System.Collections.ArrayList
    $actionHasAmbiguousPlaceholders = $false

    if ($order -gt 0) {
        $allSelectedOrders.Add($order)
        if ("blocked".Equals($status, [System.StringComparison]::OrdinalIgnoreCase)) {
            $blockedOrders.Add($order)
        }
        elseif ("planned".Equals($status, [System.StringComparison]::OrdinalIgnoreCase)) {
            $plannedOrders.Add($order)
        }
    }

    if ($needsActionKubeconfig) {
        $needsKubeconfig = $true
    }
    if ($needsActionApproval) {
        $needsApproval = $true
    }

    foreach ($placeholder in $placeholders) {
        Add-UniqueString $allRequiredPlaceholders $placeholder
        $input = New-RequiredInput $placeholder $command $name
        if ($input.ambiguousRepeatedPlaceholder) {
            $actionHasAmbiguousPlaceholders = $true
            $ambiguousRepeatedPlaceholderCount++
        }
        $requiredInputs.Add($input) | Out-Null
    }
    foreach ($placeholder in $invalidPlaceholders) {
        Add-UniqueString $allRequiredPlaceholders $placeholder
        $input = New-RequiredInput $placeholder $command $name
        if ($input.ambiguousRepeatedPlaceholder) {
            $actionHasAmbiguousPlaceholders = $true
            $ambiguousRepeatedPlaceholderCount++
        }
        $requiredInputs.Add($input) | Out-Null
    }

    $actionPlaceholderValues = New-Object System.Collections.Generic.List[string]
    foreach ($placeholder in $placeholders) {
        Add-UniqueString $actionPlaceholderValues $placeholder
    }
    foreach ($placeholder in $invalidPlaceholders) {
        Add-UniqueString $actionPlaceholderValues $placeholder
    }
    $actionPlanCommand = New-InvokeCommand `
        -Orders @($order) `
        -NeedKubeconfig $needsActionKubeconfig `
        -NeedApproval $needsActionApproval `
        -Placeholders @($actionPlaceholderValues | ForEach-Object { [string] $_ })

    $actionPlans.Add([ordered]@{
        order = $order
        name = $name
        category = (Get-Text $action "category")
        actionType = (Get-Text $action "actionType")
        evidencePath = (Get-Text $action "evidencePath")
        status = $status
        commandMode = (Get-Text $action "commandMode")
        command = $command
        blockReasons = $blockReasons
        unresolvedPlaceholders = $placeholders
        invalidPlaceholders = $invalidPlaceholders
        requiresOperatorApproval = $requiresOperatorApproval
        requiresKubeconfigSecret = $requiresKubeconfigSecret
        needsOperatorApprovalConfirmation = $needsActionApproval
        needsKubeconfigSecretConfirmation = $needsActionKubeconfig
        requiredInputs = @($requiredInputs)
        ambiguousRepeatedPlaceholders = $actionHasAmbiguousPlaceholders
        planCommand = $actionPlanCommand
    }) | Out-Null
}

$allPlaceholdersArray = @($allRequiredPlaceholders | ForEach-Object { [string] $_ })
$blockedOrdersArray = @($blockedOrders | ForEach-Object { [int] $_ })
$plannedOrdersArray = @($plannedOrders | ForEach-Object { [int] $_ })
$allSelectedOrdersArray = @($allSelectedOrders | ForEach-Object { [int] $_ })
$result = if ((Get-Int $invocation "blockedCount") -gt 0) { "action-required" } else { "ready" }
$generatedAt = [DateTimeOffset]::Now.ToString("o")
$confirmedPlanCommand = New-InvokeCommand `
    -Orders $allSelectedOrdersArray `
    -NeedKubeconfig $needsKubeconfig `
    -NeedApproval $needsApproval `
    -Placeholders $allPlaceholdersArray
$blockedOnlyCommand = New-InvokeCommand `
    -Orders $blockedOrdersArray `
    -NeedKubeconfig $needsKubeconfig `
    -NeedApproval $needsApproval `
    -Placeholders $allPlaceholdersArray
$plannedOnlyCommand = New-InvokeCommand `
    -Orders $plannedOrdersArray `
    -NeedKubeconfig $false `
    -NeedApproval $false `
    -Placeholders @()

$report = [ordered]@{
    formatVersion = "osmu.operations-invocation-unblock-plan.v1"
    generatedAt = $generatedAt
    result = $result
    sourceInvocationReport = $resolvedInvocationPath
    sourceResult = (Get-Text $invocation "result")
    sourceSummary = (Get-Text $invocation "sourceSummary")
    selectedActionCount = (Get-Int $invocation "selectedActionCount")
    plannedCount = (Get-Int $invocation "plannedCount")
    blockedCount = (Get-Int $invocation "blockedCount")
    failedCount = (Get-Int $invocation "failedCount")
    needsKubeconfigSecretConfirmation = $needsKubeconfig
    needsOperatorApprovalConfirmation = $needsApproval
    requiredPlaceholderCount = $allPlaceholdersArray.Count
    ambiguousRepeatedPlaceholderCount = $ambiguousRepeatedPlaceholderCount
    blockedActionOrders = $blockedOrdersArray
    plannedActionOrders = $plannedOrdersArray
    confirmedPlanCommand = $confirmedPlanCommand
    blockedOnlyPlanCommand = $blockedOnlyCommand
    plannedOnlyCommand = $plannedOnlyCommand
    decisionRule = "Resolve placeholders, confirm operator approval when required, confirm OSMU_KUBECONFIG_BASE64 readiness when required, then rerun invoke-operations-evidence-plan.ps1 in plan-only mode before using -Execute."
    actions = @($actionPlans)
}

$markdownLines = @(
    "# OSMU Operations Invocation Unblock Plan",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source invocation report: $resolvedInvocationPath",
    "",
    "## Summary",
    "",
    "- Selected actions: $($report.selectedActionCount)",
    "- Planned actions: $($report.plannedCount)",
    "- Blocked actions: $($report.blockedCount)",
    "- Failed actions: $($report.failedCount)",
    "- Needs kubeconfig secret confirmation: $($report.needsKubeconfigSecretConfirmation)",
    "- Needs operator approval confirmation: $($report.needsOperatorApprovalConfirmation)",
    "- Required placeholder values: $($report.requiredPlaceholderCount)",
    "- Ambiguous repeated placeholders: $($report.ambiguousRepeatedPlaceholderCount)",
    "",
    "## Suggested Commands",
    ""
)
if (-not [string]::IsNullOrWhiteSpace($plannedOnlyCommand)) {
    $markdownLines += "- Planned-only actions: ``$plannedOnlyCommand``"
}
if (-not [string]::IsNullOrWhiteSpace($blockedOnlyCommand)) {
    $markdownLines += "- Blocked-only plan after inputs: ``$blockedOnlyCommand``"
}
if (-not [string]::IsNullOrWhiteSpace($confirmedPlanCommand)) {
    $markdownLines += "- Full confirmed plan after inputs: ``$confirmedPlanCommand``"
}
$markdownLines += @(
    "",
    "## Actions",
    ""
)
foreach ($action in $actionPlans) {
    $markdownLines += "- [$($action.status)] $($action.order). $($action.name)"
    if (@($action.blockReasons).Count -gt 0) {
        $markdownLines += "  - Blocked by: $(@($action.blockReasons) -join '; ')"
    }
    if (@($action.requiredInputs).Count -gt 0) {
        $inputSummaries = @($action.requiredInputs | ForEach-Object {
            $workflowInputs = @($_.workflowInputs | ForEach-Object { [string] $_ })
            $targets = if ($workflowInputs.Count -gt 0) { " [workflow inputs: $($workflowInputs -join ', ')]" } else { "" }
            "$($_.placeholder) via $($_.parameter)$targets"
        })
        $markdownLines += "  - Inputs: $($inputSummaries -join ', ')"
    }
    if ($action.ambiguousRepeatedPlaceholders) {
        $markdownLines += "  - Note: repeated generic placeholders may need workflow run id/artifact collection helpers instead of one shared replacement value."
    }
    if (-not [string]::IsNullOrWhiteSpace($action.planCommand)) {
        $markdownLines += "  - Plan command: ``$($action.planCommand)``"
    }
}

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    $markdownLines | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations invocation unblock plan JSON: $resolvedJsonOutputPath"
    Write-Host "Operations invocation unblock plan markdown: $resolvedMarkdownOutputPath"
}

$report | ConvertTo-Json -Depth 16
