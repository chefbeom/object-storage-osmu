param(
    [string] $InvocationReportPath = ".\.osmu-run\latest-operations-evidence-plan-invocation.json",
    [string] $DispatchPreflightReportPath = ".\.osmu-run\latest-operations-dispatch-preflight.json",
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

function Read-Utf8Text([string] $PathValue) {
    $resolvedPath = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}
function Read-OptionalJson([string] $PathValue) {
    $resolvedPath = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [ordered]@{
            path = $resolvedPath
            exists = $false
            json = $null
        }
    }
    return [ordered]@{
        path = $resolvedPath
        exists = $true
        json = (Read-Utf8Text $resolvedPath | ConvertFrom-Json)
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

function Get-ObjectValue([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    return Get-JsonProperty $Object $Name
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

function Get-ArrayValue([object] $Value) {
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) { return @($Value) }
    return @($Value)
}

function Get-DispatchTemplateByAction([object] $DispatchReport) {
    $map = @{}
    if ($null -eq $DispatchReport) { return $map }
    foreach ($template in @(Get-ArrayValue (Get-JsonProperty $DispatchReport "inputTemplates"))) {
        $order = Get-Int $template "actionOrder"
        if ($order -gt 0) { $map[$order] = $template }
    }
    return $map
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

function Add-UniqueInt([System.Collections.Generic.List[int]] $List, [int] $Value) {
    if ($Value -le 0) {
        return
    }
    if (-not $List.Contains($Value)) {
        $List.Add($Value)
    }
}

function Get-IntArrayFromValue([object] $Value) {
    if ($null -eq $Value) {
        return @()
    }
    $items = if ($Value -is [System.Array]) {
        @($Value)
    }
    elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        @($Value)
    }
    else {
        @($Value)
    }
    return @($items | ForEach-Object {
        try {
            [int] $_
        }
        catch {
            0
        }
    } | Where-Object { $_ -gt 0 })
}

function Get-DefaultBranchWorkflowGroups([object] $DispatchPreflightReport) {
    if ($null -eq $DispatchPreflightReport) {
        return @()
    }
    $defaultBranchRef = Get-Text $DispatchPreflightReport "defaultBranchRef"
    if ([string]::IsNullOrWhiteSpace($defaultBranchRef)) {
        $defaultBranchRef = "default branch"
    }
    $groups = New-Object System.Collections.ArrayList
    foreach ($workflowFile in @(Get-ObjectValue $DispatchPreflightReport "workflowFiles")) {
        if ($null -eq $workflowFile) {
            continue
        }
        $existsOnDefaultBranchValue = Get-ObjectValue $workflowFile "existsOnDefaultBranch"
        if ($null -eq $existsOnDefaultBranchValue -or [System.Convert]::ToBoolean($existsOnDefaultBranchValue)) {
            continue
        }
        $workflow = Get-Text $workflowFile "workflow"
        if ([string]::IsNullOrWhiteSpace($workflow)) {
            $workflow = Get-Text $workflowFile "workflowFile"
        }
        if ([string]::IsNullOrWhiteSpace($workflow)) {
            continue
        }
        $workflowDefaultBranchRef = Get-Text $workflowFile "defaultBranchRef"
        if ([string]::IsNullOrWhiteSpace($workflowDefaultBranchRef)) {
            $workflowDefaultBranchRef = $defaultBranchRef
        }
        $orders = New-Object System.Collections.Generic.List[int]
        Add-UniqueInt $orders (Get-Int $workflowFile "actionOrder")
        foreach ($order in @(Get-IntArrayFromValue (Get-ObjectValue $workflowFile "actionOrders"))) {
            Add-UniqueInt $orders $order
        }
        $orderArray = @($orders | ForEach-Object { [int] $_ })
        $groups.Add([ordered]@{
            kind = "default-branch-workflow"
            workflow = $workflow
            defaultBranchRef = $workflowDefaultBranchRef
            actionCount = $orderArray.Count
            actionOrders = $orderArray
            note = "Publish or merge this workflow file onto $workflowDefaultBranchRef before using GitHub workflow_dispatch for the listed action orders."
        }) | Out-Null
    }
    return @($groups)
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

function New-ConfirmationGroup(
    [string] $Kind,
    [string] $Label,
    [string] $Flag,
    [string] $FlagProperty,
    [string] $Note,
    [object[]] $Actions
) {
    $orders = New-Object System.Collections.Generic.List[int]
    foreach ($action in @($Actions)) {
        $neededValue = Get-ObjectValue $action $FlagProperty
        $needed = $false
        if ($null -ne $neededValue) {
            $needed = [System.Convert]::ToBoolean($neededValue)
        }
        if (-not $needed) {
            continue
        }
        Add-UniqueInt $orders ([int] (Get-ObjectValue $action "order"))
    }
    if ($orders.Count -eq 0) {
        return $null
    }
    return [ordered]@{
        kind = $Kind
        label = $Label
        flag = $Flag
        actionCount = $orders.Count
        actionOrders = @($orders | ForEach-Object { [int] $_ })
        note = $Note
    }
}

function New-RequiredInputGroups([object[]] $Actions) {
    $groupsByKey = [ordered]@{}
    foreach ($action in @($Actions)) {
        $order = [int] (Get-ObjectValue $action "order")
        $requiredInputs = @(Get-ObjectValue $action "requiredInputs")
        foreach ($input in $requiredInputs) {
            $placeholder = [string] (Get-ObjectValue $input "placeholder")
            $parameter = [string] (Get-ObjectValue $input "parameter")
            if ([string]::IsNullOrWhiteSpace($placeholder) -and [string]::IsNullOrWhiteSpace($parameter)) {
                continue
            }
            $key = "$parameter|$placeholder"
            if (-not $groupsByKey.Contains($key)) {
                $groupsByKey[$key] = [ordered]@{
                    placeholder = $placeholder
                    parameter = $parameter
                    valueTemplate = [string] (Get-ObjectValue $input "valueTemplate")
                    actionOrders = (New-Object System.Collections.Generic.List[int])
                    workflowInputs = (New-Object System.Collections.Generic.List[string])
                    occurrenceCount = 0
                    ambiguousRepeatedPlaceholder = $false
                }
            }
            $group = $groupsByKey[$key]
            Add-UniqueInt $group["actionOrders"] $order
            foreach ($workflowInput in @(Get-ObjectValue $input "workflowInputs")) {
                Add-UniqueString $group["workflowInputs"] ([string] $workflowInput)
            }
            $group["occurrenceCount"] = [int] $group["occurrenceCount"] + [int] (Get-ObjectValue $input "occurrenceCount")
            $ambiguousValue = Get-ObjectValue $input "ambiguousRepeatedPlaceholder"
            if ($null -ne $ambiguousValue -and [System.Convert]::ToBoolean($ambiguousValue)) {
                $group["ambiguousRepeatedPlaceholder"] = $true
            }
        }
    }

    $groups = New-Object System.Collections.ArrayList
    foreach ($group in $groupsByKey.Values) {
        $orders = @($group["actionOrders"] | ForEach-Object { [int] $_ })
        $workflowInputs = @($group["workflowInputs"] | ForEach-Object { [string] $_ })
        $ambiguous = [System.Convert]::ToBoolean($group["ambiguousRepeatedPlaceholder"])
        $note = if ($ambiguous) {
            "Repeated generic placeholder may need workflow run id/artifact collection helpers instead of one shared replacement value."
        }
        else {
            "Provide this value once to cover the listed blocked action orders."
        }
        $groups.Add([ordered]@{
            placeholder = [string] $group["placeholder"]
            parameter = [string] $group["parameter"]
            valueTemplate = [string] $group["valueTemplate"]
            actionCount = $orders.Count
            actionOrders = $orders
            workflowInputs = $workflowInputs
            occurrenceCount = [int] $group["occurrenceCount"]
            ambiguousRepeatedPlaceholder = $ambiguous
            note = $note
        }) | Out-Null
    }
    return @($groups)
}
$resolvedInvocationPath = Resolve-ProjectPath $InvocationReportPath
if (-not (Test-Path -LiteralPath $resolvedInvocationPath)) {
    throw "Operations evidence invocation report not found: $resolvedInvocationPath"
}

$invocation = Read-Utf8Text $resolvedInvocationPath | ConvertFrom-Json
if ($invocation.formatVersion -ne "osmu.operations-evidence-plan-invocation.v1") {
    throw "Unexpected operations evidence invocation formatVersion: $($invocation.formatVersion)"
}
$dispatchPreflight = Read-OptionalJson $DispatchPreflightReportPath
$dispatchTemplateByAction = Get-DispatchTemplateByAction $dispatchPreflight.json
$defaultBranchWorkflowGroups = @(Get-DefaultBranchWorkflowGroups $dispatchPreflight.json)
$defaultBranchWorkflowMissingOrders = New-Object System.Collections.Generic.List[int]
foreach ($group in $defaultBranchWorkflowGroups) {
    foreach ($order in @(Get-ObjectValue $group "actionOrders")) {
        Add-UniqueInt $defaultBranchWorkflowMissingOrders ([int] $order)
    }
}
$defaultBranchWorkflowMissingOrdersArray = @($defaultBranchWorkflowMissingOrders | ForEach-Object { [int] $_ })

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
    $defaultBranchMissingForAction = $defaultBranchWorkflowMissingOrdersArray -contains $order
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
    $dispatchTemplate = if ($dispatchTemplateByAction.ContainsKey($order)) { $dispatchTemplateByAction[$order] } else { $null }
    $requiredSecrets = @()
    if ($null -ne $dispatchTemplate) {
        $requiredSecrets = @(Get-ArrayValue (Get-JsonProperty $dispatchTemplate "requiredSecrets") | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
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
        blockReasonCount = $blockReasons.Count
        blockReasons = $blockReasons
        unresolvedPlaceholderCount = $placeholders.Count
        unresolvedPlaceholders = $placeholders
        invalidPlaceholderCount = $invalidPlaceholders.Count
        invalidPlaceholders = $invalidPlaceholders
        requiresOperatorApproval = $requiresOperatorApproval
        requiresKubeconfigSecret = $requiresKubeconfigSecret
        needsOperatorApprovalConfirmation = $needsActionApproval
        needsKubeconfigSecretConfirmation = $needsActionKubeconfig
        defaultBranchWorkflowMissing = $defaultBranchMissingForAction
        requiredInputCount = @($requiredInputs).Count
        requiredInputs = @($requiredInputs)
        requiredSecretCount = $requiredSecrets.Count
        requiredSecrets = @($requiredSecrets)
        ambiguousRepeatedPlaceholders = $actionHasAmbiguousPlaceholders
        planCommand = $actionPlanCommand
    }) | Out-Null
}

$allPlaceholdersArray = @($allRequiredPlaceholders | ForEach-Object { [string] $_ })
$blockedOrdersArray = @($blockedOrders | ForEach-Object { [int] $_ })
$plannedOrdersArray = @($plannedOrders | ForEach-Object { [int] $_ })
$allSelectedOrdersArray = @($allSelectedOrders | ForEach-Object { [int] $_ })
$result = if ((Get-Int $invocation "blockedCount") -gt 0 -or $defaultBranchWorkflowGroups.Count -gt 0) { "action-required" } else { "ready" }
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

$confirmationGroups = @()
$operatorApprovalGroup = New-ConfirmationGroup `
    -Kind "operator-approval" `
    -Label "Operator approval" `
    -Flag "-ConfirmOperatorApproval" `
    -FlagProperty "needsOperatorApprovalConfirmation" `
    -Note "Review the action evidence target and rerun the plan with -ConfirmOperatorApproval." `
    -Actions @($actionPlans)
if ($null -ne $operatorApprovalGroup) {
    $confirmationGroups += $operatorApprovalGroup
}
$kubeconfigSecretGroup = New-ConfirmationGroup `
    -Kind "kubeconfig-secret" `
    -Label "Kubeconfig secret confirmation" `
    -Flag "-KubeconfigSecretConfirmed" `
    -FlagProperty "needsKubeconfigSecretConfirmation" `
    -Note "Confirm OSMU_KUBECONFIG_BASE64 is present for live Kubernetes workflow dispatch." `
    -Actions @($actionPlans)
if ($null -ne $kubeconfigSecretGroup) {
    $confirmationGroups += $kubeconfigSecretGroup
}
$requiredInputGroups = @(New-RequiredInputGroups -Actions @($actionPlans))

$report = [ordered]@{
    formatVersion = "osmu.operations-invocation-unblock-plan.v1"
    generatedAt = $generatedAt
    result = $result
    sourceInvocationReport = $resolvedInvocationPath
    sourceResult = (Get-Text $invocation "result")
    sourceSummary = (Get-Text $invocation "sourceSummary")
    sourcePassedCount = (Get-Int $invocation "sourcePassedCount")
    sourcePendingCount = (Get-Int $invocation "sourcePendingCount")
    sourceTotalCount = (Get-Int $invocation "sourceTotalCount")
    sourceCheckCount = (Get-Int $invocation "sourceCheckCount")
    selectedActionCount = (Get-Int $invocation "selectedActionCount")
    plannedCount = (Get-Int $invocation "plannedCount")
    blockedCount = (Get-Int $invocation "blockedCount")
    failedCount = (Get-Int $invocation "failedCount")
    sourceDispatchPreflightReport = $dispatchPreflight.path
    dispatchPreflightExists = [bool] $dispatchPreflight.exists
    needsKubeconfigSecretConfirmation = $needsKubeconfig
    needsOperatorApprovalConfirmation = $needsApproval
    requiredPlaceholderCount = $allPlaceholdersArray.Count
    ambiguousRepeatedPlaceholderCount = $ambiguousRepeatedPlaceholderCount
    defaultBranchWorkflowMissingCount = $defaultBranchWorkflowGroups.Count
    defaultBranchWorkflowMissingActionOrders = $defaultBranchWorkflowMissingOrdersArray
    confirmationGroupCount = $confirmationGroups.Count
    requiredInputGroupCount = $requiredInputGroups.Count
    defaultBranchWorkflowGroupCount = $defaultBranchWorkflowGroups.Count
    blockedActionOrders = $blockedOrdersArray
    plannedActionOrders = $plannedOrdersArray
    confirmedPlanCommand = $confirmedPlanCommand
    blockedOnlyPlanCommand = $blockedOnlyCommand
    plannedOnlyCommand = $plannedOnlyCommand
    decisionRule = "Resolve placeholders, confirm operator approval when required, confirm OSMU_KUBECONFIG_BASE64 readiness when required, publish selected workflow files to the default branch when required, then rerun invoke-operations-evidence-plan.ps1 in plan-only mode before using -Execute."
    confirmationGroups = @($confirmationGroups)
    requiredInputGroups = @($requiredInputGroups)
    defaultBranchWorkflowGroups = @($defaultBranchWorkflowGroups)
    actions = @($actionPlans)
}

$markdownLines = @(
    "# OSMU Operations Invocation Unblock Plan",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source invocation report: $resolvedInvocationPath",
    "Source counts: passed=$($report.sourcePassedCount) pending=$($report.sourcePendingCount) total=$($report.sourceTotalCount) checks=$($report.sourceCheckCount)",
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
    "- Default-branch workflow files missing: $($report.defaultBranchWorkflowMissingCount)",
    "- Confirmation groups: $($report.confirmationGroupCount)",
    "- Required input groups: $($report.requiredInputGroupCount)",
    "- Default-branch workflow groups: $($report.defaultBranchWorkflowGroupCount)",
    "",
    "## Unblock Groups",
    ""
)
if (@($confirmationGroups).Count -eq 0 -and @($requiredInputGroups).Count -eq 0 -and @($defaultBranchWorkflowGroups).Count -eq 0) {
    $markdownLines += "- No grouped blockers detected."
}
foreach ($group in @($confirmationGroups)) {
    $markdownLines += "- Confirmation: $($group.label) for actions $(@($group.actionOrders) -join ', ') via ``$($group.flag)``"
    if (-not [string]::IsNullOrWhiteSpace($group.note)) {
        $markdownLines += "  - Note: $($group.note)"
    }
}
foreach ($group in @($requiredInputGroups)) {
    $workflowInputText = if (@($group.workflowInputs).Count -gt 0) { " workflow inputs: $(@($group.workflowInputs) -join ', ')" } else { " workflow inputs: n/a" }
    $ambiguityText = if ($group.ambiguousRepeatedPlaceholder) { " ambiguous" } else { "" }
    $markdownLines += "- Input: $($group.parameter) $($group.placeholder) for actions $(@($group.actionOrders) -join ', ') ($($group.actionCount) actions,$workflowInputText,$ambiguityText occurrenceCount=$($group.occurrenceCount))"
    if (-not [string]::IsNullOrWhiteSpace($group.note)) {
        $markdownLines += "  - Note: $($group.note)"
    }
}
foreach ($group in @($defaultBranchWorkflowGroups)) {
    $markdownLines += "- Default branch workflow: $($group.workflow) missing from $($group.defaultBranchRef) for actions $(@($group.actionOrders) -join ', ')"
    if (-not [string]::IsNullOrWhiteSpace($group.note)) {
        $markdownLines += "  - Note: $($group.note)"
    }
}
$markdownLines += @(
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
    $markdownLines += "- [$($action.status)] $($action.order). $($action.name) (blockers=$($action.blockReasonCount), inputs=$($action.requiredInputCount), secrets=$($action.requiredSecretCount))"
    if (@($action.blockReasons).Count -gt 0) {
        $markdownLines += "  - Blocked by: $(@($action.blockReasons) -join '; ')"
    }
    if (@($action.requiredSecrets).Count -gt 0) {
        $markdownLines += "  - Required GitHub secrets: $(@($action.requiredSecrets) -join ', ')"
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
    if ($action.defaultBranchWorkflowMissing) {
        $markdownLines += "  - Note: workflow_dispatch requires the workflow file to exist on the default branch before dispatch."
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
