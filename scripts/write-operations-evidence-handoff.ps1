param(
    [string] $ReadinessReportPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $EvidencePlanPath = ".\.osmu-run\latest-operations-evidence-plan.json",
    [string] $InvocationReportPath = ".\.osmu-run\latest-operations-evidence-plan-invocation.json",
    [string] $InvocationUnblockPlanPath = ".\.osmu-run\latest-operations-invocation-unblock-plan.json",
    [string] $DispatchPreflightReportPath = ".\.osmu-run\latest-operations-dispatch-preflight.json",
    [string] $OperatorInputWorksheetReportPath = ".\.osmu-run\latest-operations-operator-input-worksheet.json",
    [string] $OperatorInputValuesProfileReportPath = ".\.osmu-run\latest-operations-operator-input-values-profile.json",
    [string] $OperatorInputValuesCheckReportPath = ".\.osmu-run\latest-operations-operator-input-values-check.json",
    [string] $WorkflowRunIdPlanPath = ".\.osmu-run\latest-operations-workflow-run-ids.json",
    [string] $ArtifactCollectionPlanPath = ".\.osmu-run\latest-operations-artifact-collection-plan.json",
    [string] $ArtifactImportReportPath = ".\.osmu-run\latest-operations-readiness-artifact-import.json",
    [string] $OperationsReadinessFinalizeReportPath = ".\.osmu-run\latest-operations-readiness-finalize.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-evidence-handoff.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-evidence-handoff.md",
    [string] $InputFreeBlockedReviewReportJsonPath = ".\.osmu-run\input-free-blocker-review\operations-evidence-plan-invocation.json",
    [string] $InputFreeBlockedReviewReportMarkdownPath = ".\.osmu-run\input-free-blocker-review\operations-evidence-plan-invocation.md",
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return [System.IO.Path]::GetFullPath($PathValue) }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    $resolvedPath = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}
function Read-OptionalJson([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) { return [ordered]@{ path = $resolved; exists = $false; json = $null } }
    return [ordered]@{ path = $resolved; exists = $true; json = (Read-Utf8Text $resolved | ConvertFrom-Json) }
}

function Get-JsonProperty([object] $Object, [string] $Name) {
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) { return $Object[$Name] }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-Text([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) { return "" }
    return [string] $value
}

function Get-Int([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) { return 0 }
    try { return [int] $value } catch { return 0 }
}

function Get-ArrayCount([object] $Value) {
    if ($null -eq $Value) { return 0 }
    return @($Value).Count
}

function Get-Array([object] $Value) {
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) { return @($Value) }
    return @($Value)
}

function Get-Bool([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) { return $false }
    try { return [System.Convert]::ToBoolean($value) } catch { return $false }
}

function Get-GeneratedAt([object] $Object) {
    $rawValue = Get-Text $Object "generatedAt"
    if ([string]::IsNullOrWhiteSpace($rawValue)) { return $null }
    try { return [DateTimeOffset]::Parse($rawValue, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind) } catch { return $null }
}

function Test-GeneratedBefore([object] $Candidate, [object] $Source) {
    $candidateGeneratedAt = Get-GeneratedAt $Candidate
    $sourceGeneratedAt = Get-GeneratedAt $Source
    if ($null -eq $candidateGeneratedAt -or $null -eq $sourceGeneratedAt) { return $false }
    return $candidateGeneratedAt -lt $sourceGeneratedAt
}

function Join-IntList([int[]] $Values) {
    if ($null -eq $Values -or $Values.Count -eq 0) { return "none" }
    return (@($Values) | ForEach-Object { [string] $_ }) -join ","
}

function Get-IntListFromJsonArray([object] $Value) {
    return @(Get-Array $Value | ForEach-Object { try { [int] $_ } catch { 0 } } | Where-Object { $_ -gt 0 })
}

function Get-TextListFromJsonArray([object] $Value) {
    return @(Get-Array $Value | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Join-TextListPreview([string[]] $Values, [int] $Limit = 8) {
    $items = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($items.Count -eq 0) { return "none" }
    $preview = @($items | Select-Object -First $Limit)
    $suffix = if ($items.Count -gt $Limit) { ",..." } else { "" }
    return ($preview -join ",") + $suffix
}

function New-OperatorInputValueActionSummary([object] $Action) {
    return [ordered]@{
        actionOrder = Get-Int $Action "actionOrder"
        actionName = Get-Text $Action "actionName"
        category = Get-Text $Action "category"
        workflow = Get-Text $Action "workflow"
        inputFree = Get-Bool $Action "inputFree"
        status = Get-Text $Action "status"
        valueCount = Get-Int $Action "valueCount"
        readyValueCount = Get-Int $Action "readyValueCount"
        missingValueCount = Get-Int $Action "missingValueCount"
        unsafeValueCount = Get-Int $Action "unsafeValueCount"
        invalidValueCount = Get-Int $Action "invalidValueCount"
        nonReadyValueKeys = @(Get-TextListFromJsonArray (Get-JsonProperty $Action "nonReadyValueKeys"))
    }
}

function Get-InvocationActionOrders([object] $InvocationReport) {
    $explicitOrders = @(Get-IntListFromJsonArray (Get-JsonProperty $InvocationReport "selectedActionOrders"))
    if ($explicitOrders.Count -gt 0) { return $explicitOrders }
    return @(Get-Array (Get-JsonProperty $InvocationReport "actions") | ForEach-Object { Get-Int $_ "order" } | Where-Object { $_ -gt 0 })
}

function Get-DispatchSelectedActionOrders([object] $DispatchReport) {
    return @(Get-IntListFromJsonArray (Get-JsonProperty $DispatchReport "selectedActionOrders"))
}

function Get-WorkflowRunIdActionOrders([object] $RunIdPlan) {
    $explicitOrders = @(Get-IntListFromJsonArray (Get-JsonProperty $RunIdPlan "selectedActionOrders"))
    if ($explicitOrders.Count -gt 0) { return $explicitOrders }
    $explicitOrders = @(Get-IntListFromJsonArray (Get-JsonProperty $RunIdPlan "sourceActionOrders"))
    if ($explicitOrders.Count -gt 0) { return $explicitOrders }
    $orders = New-Object System.Collections.Generic.List[int]
    foreach ($workflow in @(Get-JsonProperty $RunIdPlan "workflows")) {
        foreach ($order in @(Get-IntListFromJsonArray (Get-JsonProperty $workflow "actionOrders"))) {
            if (-not $orders.Contains($order)) { $orders.Add($order) | Out-Null }
        }
    }
    return @($orders | ForEach-Object { [int] $_ })
}

function Get-ArtifactCollectionActionOrders([object] $CollectionPlan) {
    $explicitOrders = @(Get-IntListFromJsonArray (Get-JsonProperty $CollectionPlan "selectedActionOrders"))
    if ($explicitOrders.Count -gt 0) { return $explicitOrders }
    $explicitOrders = @(Get-IntListFromJsonArray (Get-JsonProperty $CollectionPlan "sourceActionOrders"))
    if ($explicitOrders.Count -gt 0) { return $explicitOrders }
    $orders = New-Object System.Collections.Generic.List[int]
    foreach ($artifact in @(Get-JsonProperty $CollectionPlan "artifacts")) {
        foreach ($order in @(Get-IntListFromJsonArray (Get-JsonProperty $artifact "actionOrders"))) {
            if (-not $orders.Contains($order)) { $orders.Add($order) | Out-Null }
        }
    }
    return @($orders | ForEach-Object { [int] $_ })
}

function Get-CountOrArrayCount([object] $Object, [string] $CountName, [string] $ArrayName) {
    $countValue = Get-JsonProperty $Object $CountName
    if ($null -ne $countValue) {
        try { return [int] $countValue } catch { return 0 }
    }
    return @(Get-Array (Get-JsonProperty $Object $ArrayName)).Count
}

function New-UnblockActionSummary([object] $Action) {
    $order = Get-Int $Action "order"
    $reviewCommand = if ($order -gt 0) { "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder $order -NoWrite" } else { "" }
    return [ordered]@{
        actionOrder = $order
        name = Get-Text $Action "name"
        status = Get-Text $Action "status"
        blockReasonCount = Get-CountOrArrayCount $Action "blockReasonCount" "blockReasons"
        blockReasons = @(Get-TextListFromJsonArray (Get-JsonProperty $Action "blockReasons"))
        requiredInputCount = Get-CountOrArrayCount $Action "requiredInputCount" "requiredInputs"
        requiredSecretCount = Get-CountOrArrayCount $Action "requiredSecretCount" "requiredSecrets"
        requiredSecrets = @(Get-TextListFromJsonArray (Get-JsonProperty $Action "requiredSecrets"))
        needsOperatorApprovalConfirmation = Get-Bool $Action "needsOperatorApprovalConfirmation"
        needsKubeconfigSecretConfirmation = Get-Bool $Action "needsKubeconfigSecretConfirmation"
        defaultBranchWorkflowMissing = Get-Bool $Action "defaultBranchWorkflowMissing"
        reviewCommand = $reviewCommand
        confirmedPlanCommand = Get-Text $Action "planCommand"
        planCommand = Get-Text $Action "planCommand"
    }
}

function Sum-IntProperty([object[]] $Items, [string] $Name) {
    $sum = 0
    foreach ($item in @($Items)) { $sum += Get-Int $item $Name }
    return $sum
}

function New-RequiredSecretSummaries([object[]] $Templates, [int[]] $InputFreeBlockedActionOrders) {
    $groups = [ordered]@{}
    foreach ($template in @($Templates)) {
        $order = Get-Int $template "actionOrder"
        if ($order -le 0) { continue }
        foreach ($secret in @(Get-TextListFromJsonArray (Get-JsonProperty $template "requiredSecrets"))) {
            if ([string]::IsNullOrWhiteSpace($secret)) { continue }
            if (-not $groups.Contains($secret)) {
                $groups[$secret] = [ordered]@{
                    secretName = $secret
                    actionOrders = (New-Object System.Collections.Generic.List[int])
                    inputFreeBlockedActionOrders = (New-Object System.Collections.Generic.List[int])
                }
            }
            $group = $groups[$secret]
            if (-not $group.actionOrders.Contains($order)) { $group.actionOrders.Add($order) | Out-Null }
            if ($InputFreeBlockedActionOrders -contains $order -and -not $group.inputFreeBlockedActionOrders.Contains($order)) {
                $group.inputFreeBlockedActionOrders.Add($order) | Out-Null
            }
        }
    }
    $summaries = New-Object System.Collections.ArrayList
    foreach ($group in $groups.Values) {
        $orders = @($group.actionOrders | ForEach-Object { [int] $_ })
        $inputFreeOrders = @($group.inputFreeBlockedActionOrders | ForEach-Object { [int] $_ })
        $summaries.Add([ordered]@{
            secretName = [string] $group.secretName
            actionCount = $orders.Count
            actionOrders = $orders
            inputFreeBlockedActionCount = $inputFreeOrders.Count
            inputFreeBlockedActionOrders = $inputFreeOrders
        }) | Out-Null
    }
    return @($summaries | Sort-Object secretName)
}

function Get-ArtifactCollectionStageCommand([object] $CollectionPlan) {
    foreach ($name in @("operationsArtifactFinalizerCommand", "localImportCommand", "securityEvidenceFinalizerCommand")) {
        $command = Get-Text $CollectionPlan $name
        if (-not [string]::IsNullOrWhiteSpace($command)) { return $command }
    }
    return ""
}

function Test-SameIntSet([int[]] $Left, [int[]] $Right) {
    $leftValues = @($Left | Sort-Object -Unique)
    $rightValues = @($Right | Sort-Object -Unique)
    if ($leftValues.Count -ne $rightValues.Count) { return $false }
    for ($i = 0; $i -lt $leftValues.Count; $i++) { if ($leftValues[$i] -ne $rightValues[$i]) { return $false } }
    return $true
}

function New-Stage([string] $Name, [string] $ReportPath, [bool] $Exists, [string] $Result, [string] $Summary, [bool] $Ready, [string] $Command, [string] $Note) {
    return [ordered]@{ name = $Name; reportPath = $ReportPath; exists = $Exists; result = $Result; summary = $Summary; ready = $Ready; command = $Command; note = $Note }
}

function New-NextStep([string] $Code, [string] $Title, [string] $Command, [string] $Reason, [string] $Note, [string[]] $DispatchUrls = @()) {
    $step = [ordered]@{ code = $Code; title = $Title; command = $Command; reason = $Reason; note = $Note }
    $urls = @($DispatchUrls | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) } | Select-Object -Unique)
    if ($urls.Count -gt 0) { $step.dispatchUrls = $urls }
    return $step
}

function Is-ReadyResult([string] $Result) { return @("ready", "passed", "go") -contains $Result.ToLowerInvariant() }

function Quote-PowerShellArgument([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return "''" }
    if ($Value -match '^[A-Za-z0-9_./:\\-]+$') { return $Value }
    return "'" + $Value.Replace("'", "''") + "'"
}

function New-DispatchPreflightCommand([object] $Report, [int[]] $ActionOrders = @()) {
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add("powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-dispatch-preflight.ps1")
    $orders = @($ActionOrders | Where-Object { $_ -gt 0 })
    if ($orders.Count -eq 0) { $orders = @(Get-DispatchSelectedActionOrders $Report) }
    if ($orders.Count -gt 0) { $parts.Add("-ActionOrder $($orders -join ',')") }
    $githubCliPath = Get-Text $Report "githubCliPath"
    if (-not [string]::IsNullOrWhiteSpace($githubCliPath)) { $parts.Add("-GitHubCliPath $(Quote-PowerShellArgument $githubCliPath)") }
    $githubRepository = Get-Text $Report "githubRepository"
    if (-not [string]::IsNullOrWhiteSpace($githubRepository)) { $parts.Add("-GitHubRepository $(Quote-PowerShellArgument $githubRepository)") }
    $githubRef = Get-Text $Report "githubRef"
    if (-not [string]::IsNullOrWhiteSpace($githubRef)) { $parts.Add("-GitHubRef $(Quote-PowerShellArgument $githubRef)") }
    $parts.Add("-CheckGitHubCli")
    $gitRefSafety = Get-JsonProperty $Report "gitRefSafety"
    if (Get-Bool $gitRefSafety "checked") { $parts.Add("-CheckGitRefSafety") }
    return $parts -join " "
}

function New-InputFreeBlockedInvokeCommand([object[]] $Actions, [bool] $Execute, [bool] $IncludeConfirmations = $true, [string] $JsonOutputPath = "", [string] $MarkdownOutputPath = "") {
    $orders = New-Object System.Collections.Generic.List[int]
    $needsKubeconfigSecret = $false
    $needsOperatorApproval = $false
    foreach ($action in @($Actions)) {
        $order = Get-Int $action "actionOrder"
        if ($order -gt 0 -and -not $orders.Contains($order)) { $orders.Add($order) | Out-Null }
        if (Get-Bool $action "needsKubeconfigSecretConfirmation") { $needsKubeconfigSecret = $true }
        if (Get-Bool $action "needsOperatorApprovalConfirmation") { $needsOperatorApproval = $true }
    }
    if ($orders.Count -eq 0) { return "" }
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add("powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1")
    $parts.Add("-ActionOrder $(Join-IntList @($orders | Sort-Object -Unique))")
    if ($IncludeConfirmations -and $needsKubeconfigSecret) { $parts.Add("-KubeconfigSecretConfirmed") }
    if ($IncludeConfirmations -and $needsOperatorApproval) { $parts.Add("-ConfirmOperatorApproval") }
    if (-not [string]::IsNullOrWhiteSpace($JsonOutputPath)) { $parts.Add("-JsonOutputPath $(Quote-PowerShellArgument $JsonOutputPath)") }
    if (-not [string]::IsNullOrWhiteSpace($MarkdownOutputPath)) { $parts.Add("-MarkdownOutputPath $(Quote-PowerShellArgument $MarkdownOutputPath)") }
    if (-not $IncludeConfirmations -and -not $Execute -and [string]::IsNullOrWhiteSpace($JsonOutputPath) -and [string]::IsNullOrWhiteSpace($MarkdownOutputPath)) { $parts.Add("-NoWrite") }
    if ($Execute) { $parts.Add("-Execute") }
    return $parts -join " "
}

function Get-DispatchPreflightFailureSummary([object] $Report) {
    $failed = @(Get-Array (Get-JsonProperty $Report "checks") | Where-Object { "fail".Equals((Get-Text $_ "status"), [System.StringComparison]::OrdinalIgnoreCase) })
    if ($failed.Count -eq 0) { return "No failed dispatch preflight checks were listed." }
    return (@($failed | Select-Object -First 3 | ForEach-Object { $code = Get-Text $_ "code"; $message = Get-Text $_ "message"; if ([string]::IsNullOrWhiteSpace($message)) { return $code }; return "$($code): $message" })) -join " / "
}

function Test-OnlyGitHubCliUnavailableFailure([object] $Report) {
    $failed = @(Get-Array (Get-JsonProperty $Report "checks") | Where-Object { "fail".Equals((Get-Text $_ "status"), [System.StringComparison]::OrdinalIgnoreCase) })
    if ($failed.Count -ne 1) { return $false }
    return "GITHUB_CLI_AVAILABLE".Equals((Get-Text $failed[0] "code"), [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-ReadyDispatchUrlsAvailable([object[]] $Workflows) {
    $ready = @($Workflows)
    if ($ready.Count -eq 0) { return $false }
    return @($ready | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_.dispatchUrl) }).Count -eq $ready.Count
}

function New-DispatchWorkflowSummary([object] $Template) {
    return [ordered]@{
        actionOrder = Get-Int $Template "actionOrder"; name = Get-Text $Template "name"; category = Get-Text $Template "category"; actionType = Get-Text $Template "actionType"; commandMode = Get-Text $Template "commandMode"; workflow = Get-Text $Template "workflow"; dispatchUrl = Get-Text $Template "dispatchUrl"; readyToDispatch = Get-Bool $Template "readyToDispatch"; missingInputCount = Get-Int $Template "missingInputCount"; unsafeInputCount = Get-Int $Template "unsafeInputCount"; invalidInputCount = Get-Int $Template "invalidInputCount"; ambiguousInputCount = Get-Int $Template "ambiguousInputCount"
        requiredSecrets = @(Get-Array (Get-JsonProperty $Template "requiredSecrets") | ForEach-Object { [string] $_ })
        workflowInputNames = @(Get-Array (Get-JsonProperty $Template "workflowInputNames") | ForEach-Object { [string] $_ })
        missingInputParameters = @(Get-Array (Get-JsonProperty $Template "missingInputParameters") | ForEach-Object { [string] $_ })
        operatorChecklist = @(Get-Array (Get-JsonProperty $Template "operatorChecklist") | ForEach-Object { [string] $_ })
    }
}

function Get-ReadyDispatchUrls([object[]] $Workflows) {
    $urls = New-Object System.Collections.Generic.List[string]
    foreach ($workflow in @($Workflows)) { if ($null -eq $workflow) { continue }; $url = [string] $workflow.dispatchUrl; if (-not [string]::IsNullOrWhiteSpace($url) -and -not $urls.Contains($url)) { $urls.Add($url) | Out-Null } }
    return @($urls)
}

function Get-ReadyDispatchUrlHint([object[]] $Workflows) {
    $labels = New-Object System.Collections.Generic.List[string]
    foreach ($workflow in @($Workflows)) {
        if ($null -eq $workflow) { continue }
        $url = [string] $workflow.dispatchUrl
        if ([string]::IsNullOrWhiteSpace($url)) { continue }
        $order = [string] $workflow.actionOrder
        if ([string]::IsNullOrWhiteSpace($order) -or "0" -eq $order) { $labels.Add($url) | Out-Null } else { $labels.Add("action ${order}: $url") | Out-Null }
    }
    if ($labels.Count -eq 0) { return "" }
    $visible = @($labels | Select-Object -First 5)
    $suffix = if ($labels.Count -gt 5) { " / ..." } else { "" }
    return " Web dispatch URL(s) for ready templates: $($visible -join ' / ')$suffix. Review failed preflight checks and operator approvals before using browser dispatch."
}

function Get-WorkflowRunUrlHint([object] $RunIdPlan) {
    $labels = New-Object System.Collections.Generic.List[string]
    foreach ($workflow in @(Get-JsonProperty $RunIdPlan "workflows")) { $url = Get-Text $workflow "runsUrl"; if ([string]::IsNullOrWhiteSpace($url)) { continue }; $workflowName = Get-Text $workflow "workflow"; $label = if ([string]::IsNullOrWhiteSpace($workflowName)) { $url } else { "$($workflowName): $url" }; $labels.Add($label) | Out-Null }
    if ($labels.Count -eq 0) { return "" }
    $visible = @($labels | Select-Object -First 5)
    $suffix = if ($labels.Count -gt 5) { " / ..." } else { "" }
    return " Browser workflow runs URL(s): $($visible -join ' / ')$suffix."
}

function Get-DefaultBranchMissingWorkflows([object] $DispatchPreflightReport) {
    if ($null -eq $DispatchPreflightReport) { return @() }
    $defaultBranchRef = Get-Text $DispatchPreflightReport "defaultBranchRef"
    if ([string]::IsNullOrWhiteSpace($defaultBranchRef)) { $defaultBranchRef = "default branch" }
    $items = New-Object System.Collections.ArrayList
    foreach ($workflowFile in @(Get-JsonProperty $DispatchPreflightReport "workflowFiles")) {
        if ($null -eq $workflowFile) { continue }
        $existsOnDefaultBranchValue = Get-JsonProperty $workflowFile "existsOnDefaultBranch"
        if ($null -eq $existsOnDefaultBranchValue -or [System.Convert]::ToBoolean($existsOnDefaultBranchValue)) { continue }
        $workflow = Get-Text $workflowFile "workflow"
        if ([string]::IsNullOrWhiteSpace($workflow)) { $workflow = Get-Text $workflowFile "workflowFile" }
        if ([string]::IsNullOrWhiteSpace($workflow)) { continue }
        $workflowDefaultBranchRef = Get-Text $workflowFile "defaultBranchRef"
        if ([string]::IsNullOrWhiteSpace($workflowDefaultBranchRef)) { $workflowDefaultBranchRef = $defaultBranchRef }
        $orders = New-Object System.Collections.Generic.List[int]
        $primaryOrder = Get-Int $workflowFile "actionOrder"
        if ($primaryOrder -gt 0 -and -not $orders.Contains($primaryOrder)) { $orders.Add($primaryOrder) | Out-Null }
        foreach ($order in @(Get-IntListFromJsonArray (Get-JsonProperty $workflowFile "actionOrders"))) {
            if ($order -gt 0 -and -not $orders.Contains($order)) { $orders.Add($order) | Out-Null }
        }
        $items.Add([ordered]@{
            workflow = $workflow
            defaultBranchRef = $workflowDefaultBranchRef
            actionOrders = @($orders | ForEach-Object { [int] $_ })
            actionCount = $orders.Count
            note = "workflow_dispatch requires this workflow file on $workflowDefaultBranchRef before dispatch."
        }) | Out-Null
    }
    return @($items)
}

function Get-DefaultBranchMissingActionOrders([object[]] $Workflows) {
    $orders = New-Object System.Collections.Generic.List[int]
    foreach ($workflow in @($Workflows)) {
        foreach ($order in @(Get-IntListFromJsonArray (Get-JsonProperty $workflow "actionOrders"))) {
            if ($order -gt 0 -and -not $orders.Contains($order)) { $orders.Add($order) | Out-Null }
        }
    }
    return @($orders | Sort-Object -Unique | ForEach-Object { [int] $_ })
}

function Get-DefaultBranchMissingWorkflowHint([object[]] $Workflows) {
    $items = @($Workflows)
    if ($items.Count -eq 0) { return "" }
    $labels = @($items | Select-Object -First 5 | ForEach-Object {
        $orders = @(Get-IntListFromJsonArray (Get-JsonProperty $_ "actionOrders"))
        $orderText = if ($orders.Count -gt 0) { " actions=$($orders -join ',')" } else { "" }
        "$((Get-Text $_ "workflow")) on $((Get-Text $_ "defaultBranchRef"))$orderText"
    })
    $suffix = if ($items.Count -gt 5) { " / ..." } else { "" }
    return " Default-branch workflow blocker(s): $($labels -join ' / ')$suffix. Merge or publish these workflow files to the default branch before workflow_dispatch."
}
function Find-WorkflowRunIdInput([object] $RunIdPlan, [string] $WorkflowName, [int] $ActionOrder) {
    foreach ($input in @(Get-JsonProperty $RunIdPlan "workflowRunIdInputs")) {
        $inputWorkflow = Get-Text $input "workflow"
        $inputOrders = @(Get-IntListFromJsonArray (Get-JsonProperty $input "actionOrders"))
        if ((-not [string]::IsNullOrWhiteSpace($WorkflowName) -and $WorkflowName.Equals($inputWorkflow, [System.StringComparison]::OrdinalIgnoreCase)) -or ($ActionOrder -gt 0 -and $inputOrders -contains $ActionOrder)) {
            return $input
        }
    }
    foreach ($workflow in @(Get-JsonProperty $RunIdPlan "workflows")) {
        $candidateWorkflow = Get-Text $workflow "workflow"
        $workflowOrders = @(Get-IntListFromJsonArray (Get-JsonProperty $workflow "actionOrders"))
        $primaryOrder = Get-Int $workflow "primaryActionOrder"
        if ((-not [string]::IsNullOrWhiteSpace($WorkflowName) -and $WorkflowName.Equals($candidateWorkflow, [System.StringComparison]::OrdinalIgnoreCase)) -or ($ActionOrder -gt 0 -and ($workflowOrders -contains $ActionOrder -or $primaryOrder -eq $ActionOrder))) {
            return $workflow
        }
    }
    return $null
}

function First-NonBlank([string[]] $Values) {
    foreach ($value in @($Values)) {
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
    }
    return ""
}

function Get-SecurityFinalizerRunIdInputNames([object] $CollectionPlan) {
    return @(Get-Array (Get-JsonProperty $CollectionPlan "securityEvidenceFinalizerInputs") | ForEach-Object { Get-Text $_ "name" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function New-SecurityFinalizerDependencyNote([string] $RunIdParameter, [string[]] $SecurityFinalizerRunIdInputs, [string[]] $SecurityFinalizerMissingRunIdInputs) {
    if ([string]::IsNullOrWhiteSpace($RunIdParameter)) { return "" }
    $matchingInputs = @($SecurityFinalizerRunIdInputs | Where-Object { $_.Equals($RunIdParameter, [System.StringComparison]::OrdinalIgnoreCase) })
    if ($matchingInputs.Count -eq 0) { return "" }
    $otherMissingInputs = @($SecurityFinalizerMissingRunIdInputs | Where-Object { -not $_.Equals($RunIdParameter, [System.StringComparison]::OrdinalIgnoreCase) })
    $currentInputMissing = @($SecurityFinalizerMissingRunIdInputs | Where-Object { $_.Equals($RunIdParameter, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    if ($otherMissingInputs.Count -gt 0) {
        return "Security finalizer dependency: this dispatch can supply $RunIdParameter; also collect $($otherMissingInputs -join ', ') before running security-evidence-finalizer-ci.yml."
    }
    if ($currentInputMissing) {
        return "Security finalizer dependency: capture $RunIdParameter before running security-evidence-finalizer-ci.yml."
    }
    return "Security finalizer dependency: keep $RunIdParameter aligned with the artifact collection plan before running security-evidence-finalizer-ci.yml."
}

function New-BrowserDispatchChecklistItem([object] $Workflow, [object] $RunIdPlan, [object] $CollectionPlan, [string] $RunListJsonDirectoryCommand, [string] $ManualArtifactCollectionCommand) {
    $workflowName = Get-Text $Workflow "workflow"
    $actionOrder = Get-Int $Workflow "actionOrder"
    $runIdInput = Find-WorkflowRunIdInput $RunIdPlan $workflowName $actionOrder
    $runIdParameter = Get-Text $runIdInput "runIdParameter"
    if ([string]::IsNullOrWhiteSpace($runIdParameter)) { $runIdParameter = "RunId" }
    $dispatchUrl = Get-Text $Workflow "dispatchUrl"
    $runsUrl = First-NonBlank @((Get-Text $runIdInput "runsUrl"), $dispatchUrl)
    $artifactName = Get-Text $runIdInput "artifactName"
    $runListJsonPath = Get-Text $runIdInput "runListJsonPath"
    $branch = Get-Text $RunIdPlan "branch"
    if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "main" }
    $workflowInputNames = @(Get-Array (Get-JsonProperty $Workflow "workflowInputNames") | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $operatorChecklist = @(Get-Array (Get-JsonProperty $Workflow "operatorChecklist") | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $allSecurityFinalizerRunIdInputs = @(Get-SecurityFinalizerRunIdInputNames $CollectionPlan)
    $isSecurityFinalizerInput = @($allSecurityFinalizerRunIdInputs | Where-Object { $_.Equals($runIdParameter, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    $securityFinalizerRunIdInputs = @()
    $securityFinalizerMissingRunIdInputs = @()
    $securityFinalizerDependencyNote = ""
    if ($isSecurityFinalizerInput) {
        $securityFinalizerRunIdInputs = @($allSecurityFinalizerRunIdInputs)
        $securityFinalizerMissingRunIdInputs = @(Get-TextListFromJsonArray (Get-JsonProperty $CollectionPlan "securityEvidenceFinalizerMissingRunIdInputs"))
        $securityFinalizerDependencyNote = New-SecurityFinalizerDependencyNote $runIdParameter $securityFinalizerRunIdInputs $securityFinalizerMissingRunIdInputs
    }
    $steps = New-Object System.Collections.Generic.List[string]
    $steps.Add("Open the workflow dispatch URL and select branch $branch.") | Out-Null
    if ($workflowInputNames.Count -gt 0) { $steps.Add("Fill workflow input(s): $($workflowInputNames -join ', ').") | Out-Null } else { $steps.Add("No workflow inputs are required for this dispatch template.") | Out-Null }
    if ($operatorChecklist.Count -gt 0) { $steps.Add("Confirm checklist item(s): $($operatorChecklist -join ' / ').") | Out-Null }
    $steps.Add("Run the workflow and open the workflow run page from the runs URL.") | Out-Null
    $steps.Add("Copy the numeric run id or full workflow run URL into $runIdParameter.") | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($ManualArtifactCollectionCommand)) { $steps.Add("Regenerate artifact collection with the manual run-id command.") | Out-Null }
    if (-not [string]::IsNullOrWhiteSpace($securityFinalizerDependencyNote)) { $steps.Add($securityFinalizerDependencyNote) | Out-Null }
    return [ordered]@{
        actionOrder = $actionOrder
        name = Get-Text $Workflow "name"
        category = Get-Text $Workflow "category"
        actionType = Get-Text $Workflow "actionType"
        workflow = $workflowName
        dispatchUrl = $dispatchUrl
        runsUrl = $runsUrl
        runIdParameter = $runIdParameter
        artifactName = $artifactName
        runListJsonPath = $runListJsonPath
        runListJsonDirectoryCommand = $RunListJsonDirectoryCommand
        manualArtifactCollectionCommand = $ManualArtifactCollectionCommand
        workflowInputNames = $workflowInputNames
        operatorChecklist = $operatorChecklist
        securityFinalizerRunIdInputs = $securityFinalizerRunIdInputs
        securityFinalizerMissingRunIdInputs = $securityFinalizerMissingRunIdInputs
        securityFinalizerDependencyNote = $securityFinalizerDependencyNote
        steps = @($steps)
    }
}
$readiness = Read-OptionalJson $ReadinessReportPath
$evidencePlan = Read-OptionalJson $EvidencePlanPath
$invocation = Read-OptionalJson $InvocationReportPath
$invocationUnblockPlan = Read-OptionalJson $InvocationUnblockPlanPath
$dispatchPreflight = Read-OptionalJson $DispatchPreflightReportPath
if ($invocationUnblockPlan.exists) {
    if (-not $invocation.exists) {
        $invocationUnblockPlan = [ordered]@{ path = $invocationUnblockPlan.path; exists = $false; json = $null }
    }
    else {
        $sourceInvocationReport = Get-Text $invocationUnblockPlan.json "sourceInvocationReport"
        if (-not [string]::IsNullOrWhiteSpace($sourceInvocationReport)) {
            $resolvedSourceInvocationReport = Resolve-ProjectPath $sourceInvocationReport
            $resolvedInvocationReportPath = Resolve-ProjectPath $InvocationReportPath
            if (-not $resolvedSourceInvocationReport.Equals($resolvedInvocationReportPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $invocationUnblockPlan = [ordered]@{ path = $invocationUnblockPlan.path; exists = $false; json = $null }
            }
        }
    }
}
$operatorWorksheet = Read-OptionalJson $OperatorInputWorksheetReportPath
$operatorValuesProfile = Read-OptionalJson $OperatorInputValuesProfileReportPath
$operatorValuesCheck = Read-OptionalJson $OperatorInputValuesCheckReportPath
$runIds = Read-OptionalJson $WorkflowRunIdPlanPath
$collection = Read-OptionalJson $ArtifactCollectionPlanPath
$import = Read-OptionalJson $ArtifactImportReportPath
$finalize = Read-OptionalJson $OperationsReadinessFinalizeReportPath

if ($operatorWorksheet.exists) {
    $worksheetMatchesDispatchPreflight = $false
    if ($dispatchPreflight.exists) {
        $worksheetDispatchSource = Get-Text $operatorWorksheet.json "sourceDispatchPreflightReport"
        if (-not [string]::IsNullOrWhiteSpace($worksheetDispatchSource)) {
            $resolvedWorksheetDispatchSource = Resolve-ProjectPath $worksheetDispatchSource
            $worksheetMatchesDispatchPreflight = $resolvedWorksheetDispatchSource.Equals($dispatchPreflight.path, [System.StringComparison]::OrdinalIgnoreCase)
        }
    }
    if (-not $worksheetMatchesDispatchPreflight) {
        $operatorWorksheet = [ordered]@{ path = $operatorWorksheet.path; exists = $false; json = $null }
    }
}

if ($operatorValuesCheck.exists) {
    $valuesCheckMatchesWorksheet = $false
    if ($operatorWorksheet.exists) {
        $sourceValuesTemplate = Get-Text $operatorValuesCheck.json "sourceValuesTemplate"
        $worksheetValuesTemplate = Get-Text $operatorWorksheet.json "inputValuesTemplatePath"
        if (-not [string]::IsNullOrWhiteSpace($sourceValuesTemplate) -and -not [string]::IsNullOrWhiteSpace($worksheetValuesTemplate)) {
            $resolvedSourceValuesTemplate = Resolve-ProjectPath $sourceValuesTemplate
            $resolvedWorksheetValuesTemplate = Resolve-ProjectPath $worksheetValuesTemplate
            $valuesCheckMatchesWorksheet = $resolvedSourceValuesTemplate.Equals($resolvedWorksheetValuesTemplate, [System.StringComparison]::OrdinalIgnoreCase)
        }
    }
    if (-not $valuesCheckMatchesWorksheet) {
        $operatorValuesCheck = [ordered]@{ path = $operatorValuesCheck.path; exists = $false; json = $null }
    }
}

$readinessResult = Get-Text $readiness.json "result"
$readinessSummary = Get-Text $readiness.json "summary"
$readinessPassedCount = Get-Int $readiness.json "passedCount"
$readinessPendingCount = Get-Int $readiness.json "pendingCount"
$readinessTotalCount = Get-Int $readiness.json "totalCount"
$readinessCheckCount = Get-Int $readiness.json "checkCount"
$evidencePlanResult = Get-Text $evidencePlan.json "result"
$invocationResult = Get-Text $invocation.json "result"
$unblockActionSummaries = @()
if ($invocationUnblockPlan.exists) {
    $unblockActionSummaries = @(Get-Array (Get-JsonProperty $invocationUnblockPlan.json "actions") | ForEach-Object { New-UnblockActionSummary $_ })
}
$invocationUnblockPlanActionCount = $unblockActionSummaries.Count
$invocationUnblockPlanBlockReasonCount = Sum-IntProperty $unblockActionSummaries "blockReasonCount"
$invocationUnblockPlanRequiredInputCount = Sum-IntProperty $unblockActionSummaries "requiredInputCount"
$invocationUnblockPlanRequiredSecretCount = Sum-IntProperty $unblockActionSummaries "requiredSecretCount"
$invocationUnblockPlanOperatorApprovalActionCount = @($unblockActionSummaries | Where-Object { Get-Bool $_ "needsOperatorApprovalConfirmation" }).Count
$invocationUnblockPlanKubeconfigSecretActionCount = @($unblockActionSummaries | Where-Object { Get-Bool $_ "needsKubeconfigSecretConfirmation" }).Count
$invocationUnblockPlanDefaultBranchMissingActionCount = @($unblockActionSummaries | Where-Object { Get-Bool $_ "defaultBranchWorkflowMissing" }).Count
$inputFreeBlockedActions = @($unblockActionSummaries | Where-Object { (Get-Int $_ "requiredInputCount") -eq 0 -and (Get-Int $_ "blockReasonCount") -gt 0 -and -not (Get-Bool $_ "defaultBranchWorkflowMissing") })
$inputFreeBlockedActionCount = $inputFreeBlockedActions.Count
$inputFreeBlockedRequiredSecretCount = Sum-IntProperty $inputFreeBlockedActions "requiredSecretCount"
$inputFreeBlockedOperatorApprovalActionCount = @($inputFreeBlockedActions | Where-Object { Get-Bool $_ "needsOperatorApprovalConfirmation" }).Count
$inputFreeBlockedKubeconfigSecretActionCount = @($inputFreeBlockedActions | Where-Object { Get-Bool $_ "needsKubeconfigSecretConfirmation" }).Count
$inputFreeBlockedActionOrders = @($inputFreeBlockedActions | ForEach-Object { Get-Int $_ "actionOrder" } | Where-Object { $_ -gt 0 })
$inputFreeBlockedReviewCommand = New-InputFreeBlockedInvokeCommand $inputFreeBlockedActions $false $false
$inputFreeBlockedReviewReportJsonPath = $InputFreeBlockedReviewReportJsonPath
$inputFreeBlockedReviewReportMarkdownPath = $InputFreeBlockedReviewReportMarkdownPath
$inputFreeBlockedReviewReportCommand = New-InputFreeBlockedInvokeCommand $inputFreeBlockedActions $false $false $inputFreeBlockedReviewReportJsonPath $inputFreeBlockedReviewReportMarkdownPath
$inputFreeBlockedPlanCommand = New-InputFreeBlockedInvokeCommand $inputFreeBlockedActions $false $true
$inputFreeBlockedExecuteCommand = New-InputFreeBlockedInvokeCommand $inputFreeBlockedActions $true $true
$inputFreeBlockedReviewReport = Read-OptionalJson $inputFreeBlockedReviewReportJsonPath
if ($inputFreeBlockedReviewReport.exists -and $evidencePlan.exists) {
    $inputFreeBlockedReviewReportSourcePlan = Get-Text $inputFreeBlockedReviewReport.json "sourcePlan"
    if (-not [string]::IsNullOrWhiteSpace($inputFreeBlockedReviewReportSourcePlan)) {
        try {
            $resolvedReviewSourcePlan = Resolve-ProjectPath $inputFreeBlockedReviewReportSourcePlan
            if (-not $resolvedReviewSourcePlan.Equals($evidencePlan.path, [System.StringComparison]::OrdinalIgnoreCase)) {
                $inputFreeBlockedReviewReport = [ordered]@{ path = (Resolve-ProjectPath $inputFreeBlockedReviewReportJsonPath); exists = $false; json = $null }
            }
        }
        catch {
            $inputFreeBlockedReviewReport = [ordered]@{ path = (Resolve-ProjectPath $inputFreeBlockedReviewReportJsonPath); exists = $false; json = $null }
        }
    }
}
$inputFreeBlockedReviewReportResult = Get-Text $inputFreeBlockedReviewReport.json "result"
$inputFreeBlockedReviewReportGeneratedAt = Get-Text $inputFreeBlockedReviewReport.json "generatedAt"
$inputFreeBlockedReviewReportSelectedActionCount = Get-Int $inputFreeBlockedReviewReport.json "selectedActionCount"
$inputFreeBlockedReviewReportPlannedCount = Get-Int $inputFreeBlockedReviewReport.json "plannedCount"
$inputFreeBlockedReviewReportBlockedCount = Get-Int $inputFreeBlockedReviewReport.json "blockedCount"
$inputFreeBlockedReviewReportFailedCount = Get-Int $inputFreeBlockedReviewReport.json "failedCount"
$inputFreeBlockedReviewReportExecutedCount = Get-Int $inputFreeBlockedReviewReport.json "executedCount"
$inputFreeBlockedReviewReportActionOrders = @(Get-InvocationActionOrders $inputFreeBlockedReviewReport.json)
$inputFreeBlockedReviewReportStale = $inputFreeBlockedReviewReport.exists -and $invocation.exists -and (Test-GeneratedBefore $inputFreeBlockedReviewReport.json $invocation.json)
$inputFreeBlockedReviewReportScopeMismatch = $inputFreeBlockedReviewReport.exists -and $inputFreeBlockedActionOrders.Count -gt 0 -and $inputFreeBlockedReviewReportActionOrders.Count -gt 0 -and -not (Test-SameIntSet $inputFreeBlockedReviewReportActionOrders $inputFreeBlockedActionOrders)
$dispatchPreflightResult = Get-Text $dispatchPreflight.json "result"
$dispatchPreflightRequiredInputCount = Get-Int $dispatchPreflight.json "requiredInputCount"
$dispatchPreflightMissingInputCount = Get-Int $dispatchPreflight.json "missingInputCount"
$operatorWorksheetResult = Get-Text $operatorWorksheet.json "result"
$operatorWorksheetInputRowCount = Get-Int $operatorWorksheet.json "inputRowCount"
$operatorWorksheetAmbiguousInputRowCount = Get-Int $operatorWorksheet.json "ambiguousInputRowCount"
$operatorWorksheetInputFreeActionCount = Get-Int $operatorWorksheet.json "inputFreeActionCount"
$operatorWorksheetRequiredSecretCount = Get-Int $operatorWorksheet.json "requiredSecretCount"
$operatorWorksheetReportPath = if ($operatorWorksheet.exists) { $operatorWorksheet.path } else { "" }
$operatorWorksheetCsvPath = Get-Text $operatorWorksheet.json "csvPath"
$operatorWorksheetValuesTemplatePath = Get-Text $operatorWorksheet.json "inputValuesTemplatePath"
$operatorWorksheetValuesTemplateMarkdownPath = Get-Text $operatorWorksheet.json "inputValuesTemplateMarkdownPath"
$operatorValuesProfileResult = Get-Text $operatorValuesProfile.json "result"
$operatorValuesProfileGeneratedAt = Get-Text $operatorValuesProfile.json "generatedAt"
$operatorValuesProfileDefaultsUsed = Get-Bool $operatorValuesProfile.json "handoffPackageDefaultsUsed"
$operatorValuesProfileDefaultsSkipped = Get-Bool $operatorValuesProfile.json "handoffPackageDefaultsSkipped"
$operatorValuesProfileDefaultsSkipReason = Get-Text $operatorValuesProfile.json "handoffPackageDefaultsSkipReason"
$operatorValuesProfileDefaultValueCount = Get-Int $operatorValuesProfile.json "handoffPackageDefaultValueCount"
$operatorValuesProfileFilledValueCount = Get-Int $operatorValuesProfile.json "filledValueCount"
$operatorValuesProfileBlankValueCount = Get-Int $operatorValuesProfile.json "blankValueCount"
$operatorValuesProfilePath = if ($operatorValuesProfile.exists) { $operatorValuesProfile.path } else { "" }
$operatorInputWorksheetExpandedInputRowDelta = 0
if ($operatorWorksheet.exists -and $dispatchPreflight.exists) {
    $operatorInputWorksheetExpandedInputRowDelta = $operatorWorksheetInputRowCount - $dispatchPreflightRequiredInputCount
}
$operatorValuesCheckResult = Get-Text $operatorValuesCheck.json "result"
$operatorValuesCheckValueCount = Get-Int $operatorValuesCheck.json "valueCount"
$operatorValuesCheckReadyValueCount = Get-Int $operatorValuesCheck.json "readyValueCount"
$operatorValuesCheckMissingValueCount = Get-Int $operatorValuesCheck.json "missingValueCount"
$operatorValuesCheckUnsafeValueCount = Get-Int $operatorValuesCheck.json "unsafeValueCount"
$operatorValuesCheckInvalidValueCount = Get-Int $operatorValuesCheck.json "invalidValueCount"
$operatorValuesCheckValueReadyActionCount = Get-Int $operatorValuesCheck.json "valueReadyActionCount"
$operatorValuesCheckNonReadyActionCount = Get-Int $operatorValuesCheck.json "nonReadyActionCount"
$operatorValuesCheckActionSummaries = @()
if ($operatorValuesCheck.exists) {
    $operatorValuesCheckActionSummaries = @(Get-Array (Get-JsonProperty $operatorValuesCheck.json "actionSummaries") | ForEach-Object { New-OperatorInputValueActionSummary $_ } | Where-Object { (Get-Int $_ "actionOrder") -gt 0 })
}
$operatorValuesCheckNonReadyActionSummaries = @($operatorValuesCheckActionSummaries | Where-Object { -not "ready".Equals((Get-Text $_ "status"), [System.StringComparison]::OrdinalIgnoreCase) })
$operatorValuesCheckNonReadyActionOrders = @($operatorValuesCheckNonReadyActionSummaries | ForEach-Object { Get-Int $_ "actionOrder" } | Where-Object { $_ -gt 0 })
$operatorValuesCheckSourceCsvPath = Get-Text $operatorValuesCheck.json "sourceValuesCsv"
$operatorValuesCheckCommandCsvPath = if (-not [string]::IsNullOrWhiteSpace($operatorValuesCheckSourceCsvPath)) { $operatorValuesCheckSourceCsvPath } else { $operatorWorksheetCsvPath }
$operatorValuesCheckCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-operator-input-values-check.ps1"
if (-not [string]::IsNullOrWhiteSpace($operatorValuesCheckCommandCsvPath)) {
    $operatorValuesCheckCommand = "$operatorValuesCheckCommand -ValuesCsvPath $(Quote-PowerShellArgument $operatorValuesCheckCommandCsvPath)"
}
$operatorValuesProfileCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-operator-input-values-profile.ps1"
if (-not [string]::IsNullOrWhiteSpace($operatorWorksheetCsvPath)) {
    $operatorValuesProfileCommand = "$operatorValuesProfileCommand -WorksheetCsvPath $(Quote-PowerShellArgument $operatorWorksheetCsvPath)"
}
$operatorValuesProfilePackagePath = ".\.osmu-run\latest-operations-handoff-package.json"
$operatorValuesProfileCommand = "$operatorValuesProfileCommand -HandoffPackagePath $(Quote-PowerShellArgument $operatorValuesProfilePackagePath) -UseHandoffPackageDefaults"
$dispatchGithubRepository = Get-Text $dispatchPreflight.json "githubRepository"
$runIdResult = Get-Text $runIds.json "result"
$collectionResult = Get-Text $collection.json "result"
$importResult = Get-Text $import.json "result"
$finalizeResult = Get-Text $finalize.json "result"
$finalizeReadinessResult = Get-Text $finalize.json "readinessResult"
$finalizeFailedCount = Get-Int $finalize.json "failedCount"
$finalizeGapCount = Get-ArrayCount (Get-JsonProperty $finalize.json "gaps")
$readinessReady = $readiness.exists -and (Is-ReadyResult $readinessResult)
$finalizerReady = $finalize.exists -and (Is-ReadyResult $finalizeResult) -and (Is-ReadyResult $finalizeReadinessResult) -and $finalizeFailedCount -eq 0 -and $finalizeGapCount -eq 0
$dispatchTemplates = @(Get-Array (Get-JsonProperty $dispatchPreflight.json "inputTemplates"))
$requiredGitHubSecretNames = @(Get-TextListFromJsonArray (Get-JsonProperty $dispatchPreflight.json "requiredGitHubSecrets"))
$inputFreeBlockedActionOrdersText = Join-IntList $inputFreeBlockedActionOrders
$requiredGitHubSecretSummaries = @(New-RequiredSecretSummaries $dispatchTemplates $inputFreeBlockedActionOrders)
if ($requiredGitHubSecretNames.Count -eq 0 -and $requiredGitHubSecretSummaries.Count -gt 0) {
    $requiredGitHubSecretNames = @($requiredGitHubSecretSummaries | ForEach-Object { Get-Text $_ "secretName" })
}
$requiredGitHubSecretCount = $requiredGitHubSecretNames.Count
$readyDispatchTemplates = @($dispatchTemplates | Where-Object { Get-Bool $_ "readyToDispatch" })
$blockedDispatchTemplates = @($dispatchTemplates | Where-Object { -not (Get-Bool $_ "readyToDispatch") })
$readyDispatchActionOrders = @($readyDispatchTemplates | ForEach-Object { Get-Int $_ "actionOrder" } | Where-Object { $_ -gt 0 })
$blockedDispatchActionOrders = @($blockedDispatchTemplates | ForEach-Object { Get-Int $_ "actionOrder" } | Where-Object { $_ -gt 0 })
$readyDispatchWorkflows = @($readyDispatchTemplates | ForEach-Object { New-DispatchWorkflowSummary $_ })
$blockedDispatchWorkflows = @($blockedDispatchTemplates | ForEach-Object { New-DispatchWorkflowSummary $_ })
$readyDispatchTemplateCount = $readyDispatchTemplates.Count
$blockedDispatchTemplateCount = $blockedDispatchTemplates.Count
$readySubsetPlanCommand = Get-Text $dispatchPreflight.json "readySubsetPlanCommand"
$readySubsetExecuteCommand = Get-Text $dispatchPreflight.json "readySubsetExecuteCommand"
$readySubsetApiExecuteCommand = Get-Text $dispatchPreflight.json "readySubsetApiExecuteCommand"
$invocationSelectedActionOrders = @(Get-InvocationActionOrders $invocation.json)
$dispatchPreflightSelectedActionOrders = @(Get-DispatchSelectedActionOrders $dispatchPreflight.json)
$workflowRunIdPlanActionOrders = @(Get-WorkflowRunIdActionOrders $runIds.json)
$workflowRunIdPlanWorkflows = @(Get-Array (Get-JsonProperty $runIds.json "workflows"))
$workflowRunIdPlanQueryMode = Get-Text $runIds.json "queryMode"
$workflowRunIdPlanGithubApiTokenPresent = Get-Bool $runIds.json "githubApiTokenPresent"
$workflowRunIdPlanGithubApiUnauthenticated = Get-Bool $runIds.json "githubApiUnauthenticated"
$workflowRunIdPlanQueryWorkflowCount = @($workflowRunIdPlanWorkflows | Where-Object {
    -not [string]::IsNullOrWhiteSpace((Get-Text $_ "queryMode")) -or
    $null -ne (Get-JsonProperty $_ "querySucceeded") -or
    -not [string]::IsNullOrWhiteSpace((Get-Text $_ "queryError"))
}).Count
if ($workflowRunIdPlanQueryWorkflowCount -eq 0 -and -not [string]::IsNullOrWhiteSpace($workflowRunIdPlanQueryMode)) {
    $workflowRunIdPlanQueryWorkflowCount = Get-Int $runIds.json "workflowCount"
}
$workflowRunIdPlanQuerySucceededCount = @($workflowRunIdPlanWorkflows | Where-Object { Get-Bool $_ "querySucceeded" }).Count
$workflowRunIdPlanQueryErrorCount = @($workflowRunIdPlanWorkflows | Where-Object { -not [string]::IsNullOrWhiteSpace((Get-Text $_ "queryError")) }).Count
$workflowRunIdPlanCandidateCount = Sum-IntProperty $workflowRunIdPlanWorkflows "candidateCount"
$workflowRunIdPlanQueryExecutedCount = @($workflowRunIdPlanWorkflows | Where-Object {
    $rowQueryMode = Get-Text $_ "queryMode"
    -not [string]::IsNullOrWhiteSpace($rowQueryMode) -and -not "plan-only".Equals($rowQueryMode, [System.StringComparison]::OrdinalIgnoreCase)
}).Count
if ($workflowRunIdPlanQueryExecutedCount -eq 0 -and -not [string]::IsNullOrWhiteSpace($workflowRunIdPlanQueryMode) -and -not "plan-only".Equals($workflowRunIdPlanQueryMode, [System.StringComparison]::OrdinalIgnoreCase)) {
    $workflowRunIdPlanQueryExecutedCount = $workflowRunIdPlanQueryWorkflowCount
}
$workflowRunIdPlanQueryExecuted = $workflowRunIdPlanQueryExecutedCount -gt 0
$artifactCollectionActionOrders = @(Get-ArtifactCollectionActionOrders $collection.json)
$dispatchPreflightScopeMismatch = $dispatchPreflight.exists -and $invocation.exists -and $invocationSelectedActionOrders.Count -gt 0 -and $dispatchPreflightSelectedActionOrders.Count -gt 0 -and -not (Test-SameIntSet $invocationSelectedActionOrders $dispatchPreflightSelectedActionOrders)
$workflowRunIdPlanScopeMismatch = $runIds.exists -and $invocation.exists -and $invocationSelectedActionOrders.Count -gt 0 -and $workflowRunIdPlanActionOrders.Count -gt 0 -and -not (Test-SameIntSet $invocationSelectedActionOrders $workflowRunIdPlanActionOrders)
$artifactCollectionScopeMismatch = $collection.exists -and $invocation.exists -and $invocationSelectedActionOrders.Count -gt 0 -and $artifactCollectionActionOrders.Count -gt 0 -and -not (Test-SameIntSet $invocationSelectedActionOrders $artifactCollectionActionOrders)
$dispatchPreflightFailedCheckCount = Get-Int $dispatchPreflight.json "failedCheckCount"
$dispatchPreflightWarningCheckCount = Get-Int $dispatchPreflight.json "warningCheckCount"
$dispatchPreflightFixCommand = New-DispatchPreflightCommand $dispatchPreflight.json $invocationSelectedActionOrders
$dispatchPreflightFailureSummary = Get-DispatchPreflightFailureSummary $dispatchPreflight.json
$defaultBranchRef = Get-Text $dispatchPreflight.json "defaultBranchRef"
$defaultBranchMissingWorkflows = @(Get-DefaultBranchMissingWorkflows $dispatchPreflight.json)
$defaultBranchMissingWorkflowCount = $defaultBranchMissingWorkflows.Count
$defaultBranchMissingActionOrders = @(Get-DefaultBranchMissingActionOrders $defaultBranchMissingWorkflows)
$defaultBranchWorkflowHint = Get-DefaultBranchMissingWorkflowHint $defaultBranchMissingWorkflows
$readyDispatchUrlHint = Get-ReadyDispatchUrlHint $readyDispatchWorkflows
$readyDispatchUrls = @(Get-ReadyDispatchUrls $readyDispatchWorkflows)
$workflowRunUrlHint = Get-WorkflowRunUrlHint $runIds.json
$browserDispatchReady = $dispatchPreflight.exists -and (-not (Is-ReadyResult $dispatchPreflightResult)) -and (Test-OnlyGitHubCliUnavailableFailure $dispatchPreflight.json) -and (Test-ReadyDispatchUrlsAvailable $readyDispatchWorkflows)
$browserDispatchChecklist = @()
$artifactCollectionPlanCommand = ""
$manualArtifactCollectionPlanCommand = ""
$githubApiRunListCommand = Get-Text $runIds.json "githubApiRunListCommand"
$postDispatchCommands = @()
if ($readyDispatchUrls.Count -gt 0) {
    $artifactCollectionPlanCommand = Get-Text $runIds.json "artifactCollectionPlanCommand"
    if ([string]::IsNullOrWhiteSpace($artifactCollectionPlanCommand)) {
        $artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1"
    }
    $manualArtifactCollectionPlanCommand = Get-Text $runIds.json "manualArtifactCollectionPlanCommand"
    if ([string]::IsNullOrWhiteSpace($manualArtifactCollectionPlanCommand)) {
        $manualArtifactCollectionPlanCommand = $artifactCollectionPlanCommand
    }
    $postDispatchCommands = @(
        [ordered]@{
            name = "Collect workflow run ids from saved run-list JSON"
            command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>"
            note = "Use after browser dispatch when GitHub CLI is unavailable locally. Store gh run list JSON per workflow in the directory, then let the run-id plan derive artifact commands."
        }
    )
    if (-not [string]::IsNullOrWhiteSpace($githubApiRunListCommand)) {
        $postDispatchCommands += [ordered]@{
            name = "Collect workflow run ids with GitHub REST API"
            command = $githubApiRunListCommand
            note = "Use after browser dispatch when GitHub CLI is unavailable and the repository Actions API is readable. Uses GH_TOKEN or GITHUB_TOKEN if present and never writes token values."
        }
    }
    $postDispatchCommands += @(
        [ordered]@{
            name = "Collect workflow run ids with GitHub CLI"
            command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -Execute"
            note = "Use after browser dispatch when gh is installed and authenticated."
        },
        [ordered]@{
            name = "Regenerate artifact collection plan with browser run ids"
            command = $manualArtifactCollectionPlanCommand
            note = "Use when the workflow run page URL is available but gh/run-list JSON is not. Replace any <RunIdParameter> placeholders with numeric GitHub Actions run ids or full workflow run URLs before running."
        },
        [ordered]@{
            name = "Regenerate artifact collection plan after run id collection"
            command = $artifactCollectionPlanCommand
            note = "Use after one of the run-id collection commands has produced recommended run ids so artifact names, download commands, and finalizer commands stay in the same selected-action scope."
        }
    )
}
$runListJsonDirectoryCommand = Get-Text $runIds.json "runListJsonDirectoryCommand"
if ([string]::IsNullOrWhiteSpace($runListJsonDirectoryCommand)) {
    $runListJsonDirectoryCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>"
}
$securityEvidenceFinalizerRunIdInputHints = @(Get-Array (Get-JsonProperty $runIds.json "securityEvidenceFinalizerRunIdInputHints"))
$browserDispatchChecklist = @($readyDispatchWorkflows | ForEach-Object { New-BrowserDispatchChecklistItem $_ $runIds.json $collection.json $runListJsonDirectoryCommand $manualArtifactCollectionPlanCommand })
$workflowRunIdStageCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -Execute"
$workflowRunIdStageNote = "GitHub workflow run id handoff.$workflowRunUrlHint"
if (-not [string]::IsNullOrWhiteSpace($githubApiRunListCommand)) {
    $workflowRunIdStageCommand = $githubApiRunListCommand
    $workflowRunIdStageNote = "GitHub workflow run id handoff. Prefer the GitHub REST API command when gh is unavailable; it uses GH_TOKEN or GITHUB_TOKEN only if present and never writes token values.$workflowRunUrlHint"
}
$invocationStale = $invocation.exists -and $evidencePlan.exists -and (Test-GeneratedBefore $invocation.json $evidencePlan.json)
$dispatchPreflightStale = $dispatchPreflight.exists -and $invocation.exists -and (Test-GeneratedBefore $dispatchPreflight.json $invocation.json)
$operatorWorksheetStale = $operatorWorksheet.exists -and $dispatchPreflight.exists -and (Test-GeneratedBefore $operatorWorksheet.json $dispatchPreflight.json)
$operatorValuesCheckStale = $operatorValuesCheck.exists -and $operatorWorksheet.exists -and (Test-GeneratedBefore $operatorValuesCheck.json $operatorWorksheet.json)
$operatorValuesCheckCountMismatch = $operatorValuesCheck.exists -and $operatorWorksheet.exists -and $operatorWorksheetInputRowCount -ne $operatorValuesCheckValueCount
$workflowRunIdPlanStale = $runIds.exists -and $invocation.exists -and (Test-GeneratedBefore $runIds.json $invocation.json)
$artifactCollectionStale = $collection.exists -and (($invocation.exists -and (Test-GeneratedBefore $collection.json $invocation.json)) -or ($runIds.exists -and (Test-GeneratedBefore $collection.json $runIds.json)))
$staleReportCount = @(($invocationStale, $dispatchPreflightStale, $dispatchPreflightScopeMismatch, $operatorWorksheetStale, $operatorValuesCheckStale, $operatorValuesCheckCountMismatch, $inputFreeBlockedReviewReportStale, $inputFreeBlockedReviewReportScopeMismatch, $workflowRunIdPlanStale, $workflowRunIdPlanScopeMismatch, $artifactCollectionStale, $artifactCollectionScopeMismatch) | Where-Object { $_ }).Count
$invocationStaleText = if ($invocationStale) { " stale=true" } else { "" }
$dispatchPreflightStaleText = if ($dispatchPreflightStale) { " stale=true" } else { "" }
$dispatchPreflightScopeMismatchText = if ($dispatchPreflightScopeMismatch) { " scopeMismatch=true" } else { "" }
$operatorWorksheetStaleText = if ($operatorWorksheetStale) { " stale=true" } else { "" }
$operatorValuesCheckStaleText = if ($operatorValuesCheckStale) { " stale=true" } else { "" }
$operatorValuesCheckCountMismatchText = if ($operatorValuesCheckCountMismatch) { " countMismatch=true" } else { "" }
$workflowRunIdPlanStaleText = if ($workflowRunIdPlanStale) { " stale=true" } else { "" }
$workflowRunIdPlanScopeMismatchText = if ($workflowRunIdPlanScopeMismatch) { " scopeMismatch=true" } else { "" }
$workflowRunIdPlanQuerySummaryText = if ($workflowRunIdPlanQueryWorkflowCount -gt 0 -or -not [string]::IsNullOrWhiteSpace($workflowRunIdPlanQueryMode)) {
    " queryMode=$workflowRunIdPlanQueryMode queryExecuted=$workflowRunIdPlanQueryExecuted executedWorkflows=$workflowRunIdPlanQueryExecutedCount querySucceeded=$workflowRunIdPlanQuerySucceededCount/$workflowRunIdPlanQueryWorkflowCount queryErrors=$workflowRunIdPlanQueryErrorCount candidates=$workflowRunIdPlanCandidateCount"
}
else {
    ""
}
$artifactCollectionStaleText = if ($artifactCollectionStale) { " stale=true" } else { "" }
$artifactCollectionScopeMismatchText = if ($artifactCollectionScopeMismatch) { " scopeMismatch=true" } else { "" }

$stages = @(
    (New-Stage "operations-readiness" $readiness.path $readiness.exists $readinessResult $readinessSummary (Is-ReadyResult $readinessResult) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1" "Production/B2B readiness gate summary."),
    (New-Stage "evidence-plan" $evidencePlan.path $evidencePlan.exists $evidencePlanResult "pending=$((Get-Int $evidencePlan.json "pendingCount")) actions=$((Get-Int $evidencePlan.json "actionCount")) unplanned=$((Get-Int $evidencePlan.json "unplannedCount"))" ($evidencePlan.exists -and (Get-Int $evidencePlan.json "actionCount") -gt 0) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-plan.ps1" "Ordered remediation plan."),
    (New-Stage "evidence-invocation" $invocation.path $invocation.exists $invocationResult "selected=$((Get-Int $invocation.json "selectedActionCount")) planned=$((Get-Int $invocation.json "plannedCount")) blocked=$((Get-Int $invocation.json "blockedCount")) failed=$((Get-Int $invocation.json "failedCount"))$invocationStaleText" ($invocation.exists -and -not $invocationStale -and (Get-Int $invocation.json "blockedCount") -eq 0 -and (Get-Int $invocation.json "failedCount") -eq 0 -and (Get-Int $invocation.json "selectedActionCount") -gt 0) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1" "Guarded workflow/local command invocation report."),
    (New-Stage "dispatch-preflight" $dispatchPreflight.path $dispatchPreflight.exists $dispatchPreflightResult "selected=$((Get-Int $dispatchPreflight.json "selectedActionCount")) readyTemplates=$readyDispatchTemplateCount blockedTemplates=$blockedDispatchTemplateCount requiredInputs=$dispatchPreflightRequiredInputCount missingInputs=$dispatchPreflightMissingInputCount readyOrders=$(Join-IntList $readyDispatchActionOrders)$dispatchPreflightStaleText$dispatchPreflightScopeMismatchText" ($dispatchPreflight.exists -and -not $dispatchPreflightStale -and -not $dispatchPreflightScopeMismatch -and (Is-ReadyResult $dispatchPreflightResult)) $dispatchPreflightFixCommand "No-execute workflow dispatch preflight and input template readiness."),
    (New-Stage "operator-input-worksheet" $operatorWorksheet.path $operatorWorksheet.exists $operatorWorksheetResult "inputs=$operatorWorksheetInputRowCount expandedDelta=$operatorInputWorksheetExpandedInputRowDelta ambiguous=$operatorWorksheetAmbiguousInputRowCount inputFree=$operatorWorksheetInputFreeActionCount secrets=$operatorWorksheetRequiredSecretCount$operatorWorksheetStaleText" ($operatorWorksheet.exists -and -not $operatorWorksheetStale) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-operator-input-worksheet.ps1" "Expanded operator workflow-input worksheet for confirmations, secrets, and placeholder collection."),
    (New-Stage "operator-input-values-check" $operatorValuesCheck.path $operatorValuesCheck.exists $operatorValuesCheckResult "values=$operatorValuesCheckValueCount ready=$operatorValuesCheckReadyValueCount missing=$operatorValuesCheckMissingValueCount unsafe=$operatorValuesCheckUnsafeValueCount invalid=$operatorValuesCheckInvalidValueCount readyActions=$operatorValuesCheckValueReadyActionCount nonReadyActions=$operatorValuesCheckNonReadyActionCount$operatorValuesCheckStaleText$operatorValuesCheckCountMismatchText" ($operatorValuesCheck.exists -and -not $operatorValuesCheckStale -and -not $operatorValuesCheckCountMismatch -and (Is-ReadyResult $operatorValuesCheckResult)) $operatorValuesCheckCommand "Validates filled non-secret operator input values before dispatch planning without executing workflows."),
    (New-Stage "workflow-run-ids" $runIds.path $runIds.exists $runIdResult "workflows=$((Get-Int $runIds.json "workflowCount")) ready=$((Get-Int $runIds.json "readyWorkflowCount")) missing=$((Get-Int $runIds.json "missingWorkflowCount")) stale=$((Get-Int $runIds.json "staleWorkflowCount")) actionOrders=$(Join-IntList $workflowRunIdPlanActionOrders)$workflowRunIdPlanQuerySummaryText$workflowRunIdPlanStaleText$workflowRunIdPlanScopeMismatchText" ($runIds.exists -and -not $workflowRunIdPlanStale -and -not $workflowRunIdPlanScopeMismatch -and (Is-ReadyResult $runIdResult)) $workflowRunIdStageCommand $workflowRunIdStageNote),
    (New-Stage "artifact-collection" $collection.path $collection.exists $collectionResult "artifacts=$((Get-Int $collection.json "artifactCount")) ready=$((Get-Int $collection.json "readyArtifactCount")) missingRequired=$((Get-Int $collection.json "missingRequiredArtifactCount")) securitySources=$((Get-Int $collection.json "readySecuritySourceArtifactCount"))/$((Get-Int $collection.json "securitySourceArtifactCount")) missingSecuritySources=$((Get-Int $collection.json "missingSecuritySourceArtifactCount")) actionOrders=$(Join-IntList $artifactCollectionActionOrders)$artifactCollectionStaleText$artifactCollectionScopeMismatchText" ($collection.exists -and -not $artifactCollectionStale -and -not $artifactCollectionScopeMismatch -and (Is-ReadyResult $collectionResult)) (Get-ArtifactCollectionStageCommand $collection.json) "Artifact download/import or finalizer plan."),
    (New-Stage "artifact-import" $import.path $import.exists $importResult "failed=$((Get-Int $import.json "failedCount"))" ($import.exists -and (Is-ReadyResult $importResult)) "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\import-operations-readiness-artifacts.ps1" "Promotion of downloaded evidence artifacts into latest readiness paths."),
    (New-Stage "operations-finalizer" $finalize.path $finalize.exists $finalizeResult "readiness=$finalizeReadinessResult failed=$finalizeFailedCount gaps=$finalizeGapCount" $finalizerReady "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "Combined finalizer and final readiness regeneration.")
)

$nextStep = $null
$handoffResult = "action-required"

if ($readinessReady -and $finalizerReady) {
    $handoffResult = "ready"
    $nextStep = New-NextStep "none" "Operations readiness is ready" "" "The latest operations readiness and operations finalizer reports are ready." "No handoff action is required."
}
elseif ($readinessReady -and -not $finalize.exists) {
    $nextStep = New-NextStep "run-operations-finalizer" "Run operations readiness finalizer" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "The latest operations readiness report is ready, but the operations readiness finalizer report is missing." "Run the combined finalizer so final readiness evidence is recorded before convergence."
}
elseif ($readinessReady -and -not $finalizerReady) {
    $nextStep = New-NextStep "fix-operations-finalizer" "Fix operations readiness finalizer" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "Operations readiness is ready, but the finalizer is not ready: result=$finalizeResult, readiness=$finalizeReadinessResult, failed=$finalizeFailedCount, gaps=$finalizeGapCount." "Inspect finalizer gaps, rerun missing evidence finalizers, then rerun the combined finalizer."
}
elseif (-not $readiness.exists) { $nextStep = New-NextStep "write-readiness" "Generate operations readiness report" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1" "The operations readiness report is missing." "Generate the gate report before planning evidence collection." }
elseif (-not $evidencePlan.exists) { $nextStep = New-NextStep "write-evidence-plan" "Generate operations evidence plan" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-plan.ps1" "The evidence plan is missing." "Convert pending readiness checks into ordered commands." }
elseif (-not $invocation.exists) { $nextStep = New-NextStep "write-invocation" "Generate guarded invocation report" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1" "The invocation report is missing." "Review blockers before executing live workflow or local evidence commands." }
elseif ($invocationStale) { $nextStep = New-NextStep "refresh-invocation" "Refresh guarded invocation report" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1" "The invocation report is older than the latest operations evidence plan." "Regenerate invocation from the current evidence plan before trusting blocked, planned, or ready dispatch state." }
elseif ($dispatchPreflightStale -or $dispatchPreflightScopeMismatch) {
    if ($dispatchPreflightScopeMismatch) { $refreshReason = "The dispatch preflight selected action orders ($(Join-IntList $dispatchPreflightSelectedActionOrders)) do not match the latest invocation selected action orders ($(Join-IntList $invocationSelectedActionOrders))."; $refreshNote = "Regenerate dispatch preflight for the invocation-selected actions before using ready subset commands or workflow dispatch links." }
    else { $refreshReason = "The dispatch preflight report is older than the latest invocation report."; $refreshNote = "Regenerate dispatch preflight before using ready subset commands or workflow dispatch links." }
    $nextStep = New-NextStep "refresh-dispatch-preflight" "Refresh dispatch preflight" $dispatchPreflightFixCommand $refreshReason $refreshNote
}
elseif ((Get-Int $invocation.json "blockedCount") -gt 0 -or "blocked".Equals($invocationResult, [System.StringComparison]::OrdinalIgnoreCase)) {
    $handoffResult = "blocked"
    if ($readyDispatchTemplateCount -gt 0 -and -not [string]::IsNullOrWhiteSpace($readySubsetPlanCommand)) {
        $readyOrdersText = Join-IntList $readyDispatchActionOrders
        $executeHint = if (-not [string]::IsNullOrWhiteSpace($readySubsetExecuteCommand)) { "Execute command is available after plan review: $readySubsetExecuteCommand." } else { "Ready subset GitHub CLI execute command is unavailable until GitHub CLI/auth checks pass; rerun dispatch preflight with -CheckGitHubCli before live execution." }
        $apiExecuteHint = if (-not [string]::IsNullOrWhiteSpace($readySubsetApiExecuteCommand)) { " API dispatch is also available after setting GH_TOKEN or GITHUB_TOKEN: $readySubsetApiExecuteCommand." } else { "" }
        $nextStep = New-NextStep "dispatch-ready-subset" "Plan ready dispatch subset" $readySubsetPlanCommand "The invocation report still has blocked actions, but $readyDispatchTemplateCount action(s) are ready to dispatch: $readyOrdersText." "Run the ready subset plan command first without -Execute, then dispatch only after review and continue resolving the remaining blocked actions. $executeHint$apiExecuteHint$readyDispatchUrlHint$defaultBranchWorkflowHint" $readyDispatchUrls
    }
    elseif ($inputFreeBlockedActionCount -gt 0 -and -not [string]::IsNullOrWhiteSpace($inputFreeBlockedReviewCommand)) {
        $inputFreeOrdersText = Join-IntList $inputFreeBlockedActionOrders
        $reviewReportHint = if (-not [string]::IsNullOrWhiteSpace($inputFreeBlockedReviewReportCommand)) { " To preserve a review artifact without touching the latest invocation report, run: $inputFreeBlockedReviewReportCommand." } else { "" }
        $confirmedPlanHint = if (-not [string]::IsNullOrWhiteSpace($inputFreeBlockedPlanCommand)) { " After external confirmation, run the confirmed plan command without -Execute: $inputFreeBlockedPlanCommand." } else { "" }
        $executeHint = if (-not [string]::IsNullOrWhiteSpace($inputFreeBlockedExecuteCommand)) { " Execute only after the confirmed plan is reviewed: $inputFreeBlockedExecuteCommand." } else { "" }
        $nextStep = New-NextStep "confirm-input-free-blockers" "Review input-free blocked confirmations" $inputFreeBlockedReviewCommand "The invocation report still has blocked actions, and $inputFreeBlockedActionCount action(s) require no operator input values: $inputFreeOrdersText." "Run the review command first without confirmation flags or -Execute, confirm operator approvals and secret readiness outside the report, then continue filling workflow-input-level values for the remaining blocked actions.$reviewReportHint$confirmedPlanHint$executeHint$defaultBranchWorkflowHint"
    }
    else { $nextStep = New-NextStep "resolve-invocation-blockers" "Resolve invocation blockers" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-invocation-unblock-plan.ps1" "The invocation report still has blocked actions." "Generate the unblock plan and operator input worksheet, fill workflow-input-level placeholder rows, rerun the operator input values check, confirm operator approvals, confirm kubeconfig-secret readiness, and resolve default-branch workflow blockers before dispatch.$defaultBranchWorkflowHint" }
}
elseif ((Get-Int $invocation.json "plannedCount") -gt 0 -and (Get-Int $invocation.json "executedCount") -eq 0 -and "planned".Equals($invocationResult, [System.StringComparison]::OrdinalIgnoreCase)) {
    if ($dispatchPreflight.exists -and -not (Is-ReadyResult $dispatchPreflightResult)) {
        if ($browserDispatchReady) { $readyOrdersText = Join-IntList $readyDispatchActionOrders; $apiExecuteHint = if (-not [string]::IsNullOrWhiteSpace($readySubsetApiExecuteCommand)) { " Alternatively, set GH_TOKEN or GITHUB_TOKEN and run API dispatch: $readySubsetApiExecuteCommand." } else { "" }; $nextStep = New-NextStep "dispatch-ready-subset-browser" "Open browser or API dispatch for ready subset" $readySubsetPlanCommand "The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web/API dispatch exists for action(s): $readyOrdersText." "Run the ready subset plan command first without -Execute, then use the web dispatch URL(s) after operator review.$apiExecuteHint $dispatchPreflightFailureSummary$readyDispatchUrlHint$defaultBranchWorkflowHint" $readyDispatchUrls }
        else { $nextStep = New-NextStep "fix-dispatch-preflight" "Fix dispatch preflight before execution" $dispatchPreflightFixCommand "The invocation is planned, but dispatch preflight is ${dispatchPreflightResult}: failedChecks=$dispatchPreflightFailedCheckCount, warnings=$dispatchPreflightWarningCheckCount, missingInputs=$((Get-Int $dispatchPreflight.json "missingInputCount"))." "Fix failed preflight checks before live execution. $dispatchPreflightFailureSummary$readyDispatchUrlHint$defaultBranchWorkflowHint" $readyDispatchUrls }
    }
    else { $nextStep = New-NextStep "execute-invocation" "Execute guarded evidence invocation" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -Execute" "The invocation is planned but has not executed workflows yet." "Use only after reviewing generated commands and approval requirements." }
}
elseif (-not $runIds.exists) { $nextStep = New-NextStep "write-run-id-plan" "Generate workflow run id plan" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1" "The workflow run id plan is missing." "Collect the GitHub run id handoff after workflow dispatch." }
elseif ($workflowRunIdPlanStale -or $workflowRunIdPlanScopeMismatch) {
    if ($workflowRunIdPlanScopeMismatch) { $runIdRefreshReason = "The workflow run id plan action orders ($(Join-IntList $workflowRunIdPlanActionOrders)) do not match the latest invocation selected action orders ($(Join-IntList $invocationSelectedActionOrders))." }
    else { $runIdRefreshReason = "The workflow run id plan is older than the latest invocation report." }
    $nextStep = New-NextStep "refresh-run-id-plan" "Refresh workflow run id plan" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1" $runIdRefreshReason "Regenerate the run id plan from the current invocation before collecting workflow run ids or artifacts."
}
elseif (-not (Is-ReadyResult $runIdResult)) { $nextStep = New-NextStep "collect-run-ids" "Collect successful workflow run ids" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -Execute" "Workflow run ids are not ready: $runIdResult." "Run after workflow dispatch or provide fixture JSON from gh run list outputs.$workflowRunUrlHint" }
elseif (-not $collection.exists) { $nextStep = New-NextStep "write-artifact-collection-plan" "Generate artifact collection plan" (Get-Text $runIds.json "artifactCollectionPlanCommand") "The artifact collection plan is missing." "Use the run id plan's generated command to carry recommended run ids forward." }
elseif ($artifactCollectionStale -or $artifactCollectionScopeMismatch) {
    if ($artifactCollectionScopeMismatch) { $collectionRefreshReason = "The artifact collection plan action orders ($(Join-IntList $artifactCollectionActionOrders)) do not match the latest invocation selected action orders ($(Join-IntList $invocationSelectedActionOrders))." }
    else { $collectionRefreshReason = "The artifact collection plan is older than the latest invocation or workflow run id plan report." }
    $nextStep = New-NextStep "refresh-artifact-collection-plan" "Refresh artifact collection plan" (Get-Text $runIds.json "artifactCollectionPlanCommand") $collectionRefreshReason "Regenerate artifact collection from the current invocation/run-id scope before importing readiness artifacts."
}
elseif (-not (Is-ReadyResult $collectionResult)) { $nextStep = New-NextStep "complete-artifact-collection-plan" "Complete artifact collection plan" (Get-Text $runIds.json "artifactCollectionPlanCommand") "Artifact collection is not ready: $collectionResult." "Fill missing run ids and concrete artifact names." }
elseif (-not $import.exists) { $nextStep = New-NextStep "run-artifact-finalizer" "Run operations artifact finalizer or local import" (Get-ArtifactCollectionStageCommand $collection.json) "Artifacts are ready but the import report is missing." "Use the finalizer workflow command, local import command, or security evidence finalizer command from the artifact collection plan." }
elseif (-not (Is-ReadyResult $importResult)) { $nextStep = New-NextStep "fix-artifact-import" "Fix failed artifact import" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\import-operations-readiness-artifacts.ps1" "Artifact import is not passing: $importResult." "Inspect failed evidence artifacts before regenerating readiness." }
elseif (-not $finalize.exists) { $nextStep = New-NextStep "run-operations-finalizer" "Run operations readiness finalizer" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "Evidence import has passed but the operations readiness finalizer report is missing." "Run the combined finalizer so selected evidence finalizers and the final readiness regeneration are recorded together." }
elseif (-not $finalizerReady) { $nextStep = New-NextStep "fix-operations-finalizer" "Fix operations readiness finalizer" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" "Operations readiness finalizer is not ready: result=$finalizeResult, readiness=$finalizeReadinessResult, failed=$finalizeFailedCount, gaps=$finalizeGapCount." "Inspect finalizer gaps, rerun missing evidence finalizers, then rerun the combined finalizer." }
else { $nextStep = New-NextStep "regenerate-readiness" "Regenerate operations readiness" "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1" "Evidence import has passed but readiness is still not ready." "Refresh the operations readiness report from imported evidence." }

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$report = [ordered]@{
    formatVersion = "osmu.operations-evidence-handoff.v1"; generatedAt = $generatedAt; result = $handoffResult; nextStep = $nextStep; currentBottleneck = $nextStep; stageCount = $stages.Count; readyStageCount = @($stages | Where-Object { $_.ready }).Count; readinessSummary = $readinessSummary; readinessPassedCount = $readinessPassedCount; readinessPendingCount = $readinessPendingCount; readinessTotalCount = $readinessTotalCount; readinessCheckCount = $readinessCheckCount; dispatchPreflightResult = $dispatchPreflightResult; dispatchGithubRepository = $dispatchGithubRepository; requiredGitHubSecretCount = $requiredGitHubSecretCount; requiredGitHubSecrets = @($requiredGitHubSecretNames); requiredGitHubSecretSummaries = @($requiredGitHubSecretSummaries); dispatchPreflightRequiredInputCount = $dispatchPreflightRequiredInputCount; dispatchPreflightMissingInputCount = $dispatchPreflightMissingInputCount; readyDispatchTemplateCount = $readyDispatchTemplateCount; blockedDispatchTemplateCount = $blockedDispatchTemplateCount
    defaultBranchRef = $defaultBranchRef; defaultBranchMissingWorkflowCount = $defaultBranchMissingWorkflowCount; defaultBranchMissingActionOrders = @($defaultBranchMissingActionOrders); defaultBranchMissingWorkflows = @($defaultBranchMissingWorkflows)
    invocationUnblockPlanExists = [bool] $invocationUnblockPlan.exists; invocationUnblockPlanPath = $invocationUnblockPlan.path; invocationUnblockPlanActionCount = $invocationUnblockPlanActionCount; invocationUnblockPlanBlockReasonCount = $invocationUnblockPlanBlockReasonCount; invocationUnblockPlanRequiredInputCount = $invocationUnblockPlanRequiredInputCount; invocationUnblockPlanRequiredSecretCount = $invocationUnblockPlanRequiredSecretCount; invocationUnblockPlanOperatorApprovalActionCount = $invocationUnblockPlanOperatorApprovalActionCount; invocationUnblockPlanKubeconfigSecretActionCount = $invocationUnblockPlanKubeconfigSecretActionCount; invocationUnblockPlanDefaultBranchMissingActionCount = $invocationUnblockPlanDefaultBranchMissingActionCount; invocationUnblockActions = @($unblockActionSummaries); inputFreeBlockedActionCount = $inputFreeBlockedActionCount; inputFreeBlockedActionOrders = @($inputFreeBlockedActionOrders); inputFreeBlockedReviewCommand = $inputFreeBlockedReviewCommand; inputFreeBlockedReviewReportCommand = $inputFreeBlockedReviewReportCommand; inputFreeBlockedReviewReportJsonPath = $inputFreeBlockedReviewReportJsonPath; inputFreeBlockedReviewReportMarkdownPath = $inputFreeBlockedReviewReportMarkdownPath; inputFreeBlockedConfirmedPlanCommand = $inputFreeBlockedPlanCommand; inputFreeBlockedRequiredSecretCount = $inputFreeBlockedRequiredSecretCount; inputFreeBlockedOperatorApprovalActionCount = $inputFreeBlockedOperatorApprovalActionCount; inputFreeBlockedKubeconfigSecretActionCount = $inputFreeBlockedKubeconfigSecretActionCount; inputFreeBlockedPlanCommand = $inputFreeBlockedPlanCommand; inputFreeBlockedExecuteCommand = $inputFreeBlockedExecuteCommand; inputFreeBlockedActions = @($inputFreeBlockedActions)
    readyDispatchActionOrders = @($readyDispatchActionOrders); blockedDispatchActionOrders = @($blockedDispatchActionOrders); invocationSelectedActionOrders = @($invocationSelectedActionOrders); dispatchPreflightSelectedActionOrders = @($dispatchPreflightSelectedActionOrders); workflowRunIdPlanActionOrders = @($workflowRunIdPlanActionOrders); artifactCollectionActionOrders = @($artifactCollectionActionOrders); readyDispatchWorkflows = @($readyDispatchWorkflows); blockedDispatchWorkflows = @($blockedDispatchWorkflows)
    invocationStale = $invocationStale; dispatchPreflightStale = $dispatchPreflightStale; dispatchPreflightScopeMismatch = $dispatchPreflightScopeMismatch; operatorInputWorksheetStale = $operatorWorksheetStale; operatorInputWorksheetResult = $operatorWorksheetResult; operatorInputWorksheetReportPath = $operatorWorksheetReportPath; operatorInputWorksheetCsvPath = $operatorWorksheetCsvPath; operatorInputValuesTemplatePath = $operatorWorksheetValuesTemplatePath; operatorInputValuesTemplateMarkdownPath = $operatorWorksheetValuesTemplateMarkdownPath; operatorInputValuesProfileReportPath = $operatorValuesProfilePath; operatorInputValuesProfileExists = [bool] $operatorValuesProfile.exists; operatorInputValuesProfileResult = $operatorValuesProfileResult; operatorInputValuesProfileGeneratedAt = $operatorValuesProfileGeneratedAt; operatorInputValuesProfileDefaultsUsed = [bool] $operatorValuesProfileDefaultsUsed; operatorInputValuesProfileDefaultsSkipped = [bool] $operatorValuesProfileDefaultsSkipped; operatorInputValuesProfileDefaultsSkipReason = $operatorValuesProfileDefaultsSkipReason; operatorInputValuesProfileDefaultValueCount = $operatorValuesProfileDefaultValueCount; operatorInputValuesProfileFilledValueCount = $operatorValuesProfileFilledValueCount; operatorInputValuesProfileBlankValueCount = $operatorValuesProfileBlankValueCount; operatorInputValuesProfileCommand = $operatorValuesProfileCommand; operatorInputValuesCheckCommand = $operatorValuesCheckCommand; operatorInputWorksheetInputRowCount = $operatorWorksheetInputRowCount; operatorInputWorksheetAmbiguousInputRowCount = $operatorWorksheetAmbiguousInputRowCount; operatorInputWorksheetExpandedInputRowDelta = $operatorInputWorksheetExpandedInputRowDelta; operatorInputValuesCheckStale = $operatorValuesCheckStale; operatorInputValuesCheckCountMismatch = $operatorValuesCheckCountMismatch; operatorInputValuesCheckResult = $operatorValuesCheckResult; operatorInputValuesCheckValueCount = $operatorValuesCheckValueCount; operatorInputValuesCheckReadyValueCount = $operatorValuesCheckReadyValueCount; operatorInputValuesCheckMissingValueCount = $operatorValuesCheckMissingValueCount; operatorInputValuesCheckUnsafeValueCount = $operatorValuesCheckUnsafeValueCount; operatorInputValuesCheckInvalidValueCount = $operatorValuesCheckInvalidValueCount; operatorInputValuesCheckValueReadyActionCount = $operatorValuesCheckValueReadyActionCount; operatorInputValuesCheckNonReadyActionCount = $operatorValuesCheckNonReadyActionCount; operatorInputValuesCheckActionSummaryCount = $operatorValuesCheckActionSummaries.Count; operatorInputValuesCheckActionSummaries = @($operatorValuesCheckActionSummaries); operatorInputValuesCheckNonReadyActionOrders = @($operatorValuesCheckNonReadyActionOrders); operatorInputValuesCheckNonReadyActionSummaries = @($operatorValuesCheckNonReadyActionSummaries); workflowRunIdPlanStale = $workflowRunIdPlanStale; workflowRunIdPlanScopeMismatch = $workflowRunIdPlanScopeMismatch; workflowRunIdPlanQueryMode = $workflowRunIdPlanQueryMode; workflowRunIdPlanGithubApiTokenPresent = $workflowRunIdPlanGithubApiTokenPresent; workflowRunIdPlanGithubApiUnauthenticated = $workflowRunIdPlanGithubApiUnauthenticated; workflowRunIdPlanQueryExecuted = $workflowRunIdPlanQueryExecuted; workflowRunIdPlanQueryExecutedCount = $workflowRunIdPlanQueryExecutedCount; workflowRunIdPlanQueryWorkflowCount = $workflowRunIdPlanQueryWorkflowCount; workflowRunIdPlanQuerySucceededCount = $workflowRunIdPlanQuerySucceededCount; workflowRunIdPlanQueryErrorCount = $workflowRunIdPlanQueryErrorCount; workflowRunIdPlanCandidateCount = $workflowRunIdPlanCandidateCount; artifactCollectionStale = $artifactCollectionStale; artifactCollectionScopeMismatch = $artifactCollectionScopeMismatch; staleReportCount = $staleReportCount; blockedActionCount = Get-Int $invocation.json "blockedCount"; missingWorkflowRunCount = Get-Int $runIds.json "missingWorkflowCount"; missingRequiredArtifactCount = Get-Int $collection.json "missingRequiredArtifactCount"; failedImportCount = Get-Int $import.json "failedCount"; finalizerFailedCount = $finalizeFailedCount; finalizerGapCount = $finalizeGapCount; browserDispatchChecklistCount = $browserDispatchChecklist.Count; browserDispatchChecklist = @($browserDispatchChecklist); securityEvidenceFinalizerRunIdInputHintCount = $securityEvidenceFinalizerRunIdInputHints.Count; securityEvidenceFinalizerRunIdInputHints = @($securityEvidenceFinalizerRunIdInputHints); postDispatchCommands = @($postDispatchCommands); stages = $stages
}

$report["inputFreeBlockedReviewReportExists"] = [bool] $inputFreeBlockedReviewReport.exists
$report["inputFreeBlockedReviewReportResult"] = $inputFreeBlockedReviewReportResult
$report["inputFreeBlockedReviewReportGeneratedAt"] = $inputFreeBlockedReviewReportGeneratedAt
$report["inputFreeBlockedReviewReportSelectedActionCount"] = $inputFreeBlockedReviewReportSelectedActionCount
$report["inputFreeBlockedReviewReportPlannedCount"] = $inputFreeBlockedReviewReportPlannedCount
$report["inputFreeBlockedReviewReportBlockedCount"] = $inputFreeBlockedReviewReportBlockedCount
$report["inputFreeBlockedReviewReportFailedCount"] = $inputFreeBlockedReviewReportFailedCount
$report["inputFreeBlockedReviewReportExecutedCount"] = $inputFreeBlockedReviewReportExecutedCount
$report["inputFreeBlockedReviewReportActionOrders"] = @($inputFreeBlockedReviewReportActionOrders)
$report["inputFreeBlockedReviewReportStale"] = [bool] $inputFreeBlockedReviewReportStale
$report["inputFreeBlockedReviewReportScopeMismatch"] = [bool] $inputFreeBlockedReviewReportScopeMismatch

$dispatchGithubRepositoryLabel = if ([string]::IsNullOrWhiteSpace($dispatchGithubRepository)) { "none" } else { $dispatchGithubRepository }
$defaultBranchRefLabel = if ([string]::IsNullOrWhiteSpace($defaultBranchRef)) { "none" } else { $defaultBranchRef }
$markdownLines = @("# OSMU Operations Evidence Handoff", "", "Generated at: $generatedAt", "Result: $handoffResult", "", "## Current Bottleneck", "", "- Code: $($nextStep.code)", "- Title: $($nextStep.title)", "- Reason: $($nextStep.reason)", "- Command: ``$($nextStep.command)``", "- Note: $($nextStep.note)", "", "## Readiness Source", "", "- Summary: $readinessSummary", "- Counts: passed=$readinessPassedCount pending=$readinessPendingCount total=$readinessTotalCount checks=$readinessCheckCount", "", "## Next Step", "", "- Code: $($nextStep.code)", "- Title: $($nextStep.title)", "- Reason: $($nextStep.reason)", "- Command: ``$($nextStep.command)``", "- Note: $($nextStep.note)", "", "## Invocation Unblock Summary", "", "- Plan exists: $([bool] $invocationUnblockPlan.exists)", "- Actions: $invocationUnblockPlanActionCount", "- Block reasons: $invocationUnblockPlanBlockReasonCount", "- Required inputs: $invocationUnblockPlanRequiredInputCount", "- Required secrets: $invocationUnblockPlanRequiredSecretCount", "- Operator approval actions: $invocationUnblockPlanOperatorApprovalActionCount", "- Kubeconfig secret actions: $invocationUnblockPlanKubeconfigSecretActionCount", "- Default-branch missing actions: $invocationUnblockPlanDefaultBranchMissingActionCount")
if ($unblockActionSummaries.Count -eq 0) {
    $markdownLines += "- Action summaries: none"
}
else {
    foreach ($action in @($unblockActionSummaries | Sort-Object { [int] $_.actionOrder })) {
        $markdownLines += "- action $($action.actionOrder): status=$($action.status) blockers=$($action.blockReasonCount) inputs=$($action.requiredInputCount) secrets=$($action.requiredSecretCount) - $($action.name)"
    }
}
$markdownLines += @("", "## Operator Input Expansion", "", "- Dispatch required inputs: $dispatchPreflightRequiredInputCount", "- Dispatch missing inputs: $dispatchPreflightMissingInputCount", "- Worksheet report: $operatorWorksheetReportPath", "- Worksheet CSV: $operatorWorksheetCsvPath", "- Values template JSON: $operatorWorksheetValuesTemplatePath", "- Values template Markdown: $operatorWorksheetValuesTemplateMarkdownPath", "- Values profile report: $operatorValuesProfilePath", "- Values profile result: $operatorValuesProfileResult", "- Values profile defaults used/skipped: $operatorValuesProfileDefaultsUsed/$operatorValuesProfileDefaultsSkipped", "- Values profile defaults skip reason: $operatorValuesProfileDefaultsSkipReason", "- Values profile default values: $operatorValuesProfileDefaultValueCount", "- Values profile filled/blank: $operatorValuesProfileFilledValueCount/$operatorValuesProfileBlankValueCount", "- Values profile command: ``$operatorValuesProfileCommand``", "- Values check command: ``$operatorValuesCheckCommand``", "- Worksheet input rows: $operatorWorksheetInputRowCount", "- Expanded worksheet row delta: $operatorInputWorksheetExpandedInputRowDelta", "- Ambiguous worksheet rows: $operatorWorksheetAmbiguousInputRowCount", "- Values check result: $operatorValuesCheckResult", "- Values check rows: $operatorValuesCheckValueCount", "- Ready values: $operatorValuesCheckReadyValueCount", "- Missing values: $operatorValuesCheckMissingValueCount", "- Unsafe values: $operatorValuesCheckUnsafeValueCount", "- Invalid values: $operatorValuesCheckInvalidValueCount", "- Value-ready actions: $operatorValuesCheckValueReadyActionCount", "- Non-ready actions: $operatorValuesCheckNonReadyActionCount", "- Non-ready action orders: $(Join-IntList $operatorValuesCheckNonReadyActionOrders)")
if ($operatorValuesCheckNonReadyActionSummaries.Count -eq 0) {
    $markdownLines += "- Non-ready action summaries: none"
}
else {
    foreach ($action in @($operatorValuesCheckNonReadyActionSummaries | Sort-Object { [int] $_.actionOrder })) {
        $keyText = Join-TextListPreview @($action.nonReadyValueKeys)
        $markdownLines += "- action $($action.actionOrder): status=$($action.status) values=$($action.valueCount) ready=$($action.readyValueCount) missing=$($action.missingValueCount) unsafe=$($action.unsafeValueCount) invalid=$($action.invalidValueCount) inputFree=$($action.inputFree) - $($action.actionName)"
        $markdownLines += "  - Non-ready value keys: $keyText"
    }
}
$markdownLines += @("", "## Input-Free Blocked Actions", "", "- Actions: $inputFreeBlockedActionCount", "- Action orders: $inputFreeBlockedActionOrdersText", "- Review command before confirmations: ``$inputFreeBlockedReviewCommand``", "- Review report command: ``$inputFreeBlockedReviewReportCommand``", "- Review report JSON: $inputFreeBlockedReviewReportJsonPath", "- Review report Markdown: $inputFreeBlockedReviewReportMarkdownPath", "- Review report exists: $([bool] $inputFreeBlockedReviewReport.exists)", "- Review report result: $inputFreeBlockedReviewReportResult", "- Review report generated at: $inputFreeBlockedReviewReportGeneratedAt", "- Review report selected actions: $inputFreeBlockedReviewReportSelectedActionCount", "- Review report action orders: $(Join-IntList $inputFreeBlockedReviewReportActionOrders)", "- Review report planned/blocked/failed/executed: $inputFreeBlockedReviewReportPlannedCount/$inputFreeBlockedReviewReportBlockedCount/$inputFreeBlockedReviewReportFailedCount/$inputFreeBlockedReviewReportExecutedCount", "- Review report stale: $inputFreeBlockedReviewReportStale", "- Review report scope mismatch: $inputFreeBlockedReviewReportScopeMismatch", "- Confirmed plan command: ``$inputFreeBlockedPlanCommand``", "- Required secrets: $inputFreeBlockedRequiredSecretCount", "- Operator approval actions: $inputFreeBlockedOperatorApprovalActionCount", "- Kubeconfig secret actions: $inputFreeBlockedKubeconfigSecretActionCount", "- Execute command after confirmations: ``$inputFreeBlockedExecuteCommand``")
if ($inputFreeBlockedActions.Count -eq 0) {
    $markdownLines += "- Candidates: none"
}
else {
    foreach ($action in @($inputFreeBlockedActions | Sort-Object { [int] $_.actionOrder })) {
        $secretLabel = if (@($action.requiredSecrets).Count -eq 0) { "none" } else { @($action.requiredSecrets) -join "," }
        $blockerLabel = if (@($action.blockReasons).Count -eq 0) { "none" } else { @($action.blockReasons) -join "; " }
        $markdownLines += "- action $($action.actionOrder): blockers=$($action.blockReasonCount) secrets=$secretLabel - $($action.name)"
        $markdownLines += "  - Blockers: $blockerLabel"
        if (-not [string]::IsNullOrWhiteSpace($action.reviewCommand)) { $markdownLines += "  - Review command before confirmations: ``$($action.reviewCommand)``" }
        if (-not [string]::IsNullOrWhiteSpace($action.confirmedPlanCommand)) { $markdownLines += "  - Confirmed plan command: ``$($action.confirmedPlanCommand)``" }
    }
}
$markdownLines += @("", "## Required GitHub Secrets", "", "- Secrets: $requiredGitHubSecretCount")
if ($requiredGitHubSecretSummaries.Count -eq 0) {
    $markdownLines += "- Required secrets: none"
}
else {
    foreach ($secret in @($requiredGitHubSecretSummaries)) {
        $inputFreeOrders = if (@($secret.inputFreeBlockedActionOrders).Count -eq 0) { "none" } else { @($secret.inputFreeBlockedActionOrders) -join "," }
        $markdownLines += "- $($secret.secretName): actions=$(Join-IntList @($secret.actionOrders)) inputFreeBlocked=$inputFreeOrders"
    }
}
$markdownLines += @("", "## Dispatch Preflight", "", "- Result: $dispatchPreflightResult", "- GitHub repository: $dispatchGithubRepositoryLabel", "- Default branch ref: $defaultBranchRefLabel", "- Default-branch workflow files missing: $defaultBranchMissingWorkflowCount", "- Default-branch missing action orders: $(Join-IntList $defaultBranchMissingActionOrders)", "- Ready templates: $readyDispatchTemplateCount", "- Blocked templates: $blockedDispatchTemplateCount", "- Ready action orders: $(Join-IntList $readyDispatchActionOrders)", "- Blocked action orders: $(Join-IntList $blockedDispatchActionOrders)", "- Stale reports: $staleReportCount", "", "## Dispatch Workflow Handoff", "")
if ($readyDispatchWorkflows.Count -eq 0) { $markdownLines += "- Ready workflows: none" } else { foreach ($workflow in $readyDispatchWorkflows) { $workflowName = if ([string]::IsNullOrWhiteSpace($workflow.workflow)) { "local command" } else { $workflow.workflow }; $dispatchLabel = if ([string]::IsNullOrWhiteSpace($workflow.dispatchUrl)) { "" } else { " / dispatchUrl=$($workflow.dispatchUrl)" }; $markdownLines += "- ready action $($workflow.actionOrder): $workflowName - $($workflow.name)$dispatchLabel" } }
if ($blockedDispatchWorkflows.Count -eq 0) { $markdownLines += "- Blocked workflows: none" } else { foreach ($workflow in $blockedDispatchWorkflows) { $workflowName = if ([string]::IsNullOrWhiteSpace($workflow.workflow)) { "local command" } else { $workflow.workflow }; $dispatchLabel = if ([string]::IsNullOrWhiteSpace($workflow.dispatchUrl)) { "" } else { " / dispatchUrl=$($workflow.dispatchUrl)" }; $markdownLines += "- blocked action $($workflow.actionOrder): $workflowName - missingInputs=$($workflow.missingInputCount), unsafeInputs=$($workflow.unsafeInputCount), invalidInputs=$($workflow.invalidInputCount)$dispatchLabel" } }
$markdownLines += @("", "## Workflow Run-id Query", "", "- Query mode: $workflowRunIdPlanQueryMode", "- GitHub API token present: $workflowRunIdPlanGithubApiTokenPresent", "- GitHub API unauthenticated: $workflowRunIdPlanGithubApiUnauthenticated", "- Query executed: $workflowRunIdPlanQueryExecuted", "- Query executed workflows: $workflowRunIdPlanQueryExecutedCount", "- Queried workflows: $workflowRunIdPlanQueryWorkflowCount", "- Query succeeded: $workflowRunIdPlanQuerySucceededCount/$workflowRunIdPlanQueryWorkflowCount", "- Query errors: $workflowRunIdPlanQueryErrorCount", "- Candidate runs: $workflowRunIdPlanCandidateCount", "- Missing workflow runs: $((Get-Int $runIds.json "missingWorkflowCount"))")
$markdownLines += @("", "## Default Branch Workflow Readiness", "")
if ($defaultBranchMissingWorkflows.Count -eq 0) {
    $markdownLines += "- Missing default-branch workflow files: none"
}
else {
    foreach ($workflow in $defaultBranchMissingWorkflows) {
        $markdownLines += "- missing workflow: $($workflow.workflow) on $($workflow.defaultBranchRef) / actions=$(@($workflow.actionOrders) -join ', ')"
        if (-not [string]::IsNullOrWhiteSpace($workflow.note)) { $markdownLines += "  - Note: $($workflow.note)" }
    }
}
$markdownLines += @("", "## Browser Dispatch Checklist", "")
if ($browserDispatchChecklist.Count -eq 0) {
    $markdownLines += "- Checklist: none"
}
else {
    foreach ($item in $browserDispatchChecklist) {
        $workflowLabel = if ([string]::IsNullOrWhiteSpace($item.workflow)) { "workflow" } else { $item.workflow }
        $markdownLines += "- action $($item.actionOrder): $workflowLabel - runIdParameter=$($item.runIdParameter) / dispatchUrl=$($item.dispatchUrl) / runsUrl=$($item.runsUrl)"
        if (-not [string]::IsNullOrWhiteSpace($item.runListJsonPath)) { $markdownLines += "  - Run-list JSON path: $($item.runListJsonPath)" }
        if (-not [string]::IsNullOrWhiteSpace($item.manualArtifactCollectionCommand)) { $markdownLines += "  - Manual artifact command: ``$($item.manualArtifactCollectionCommand)``" }
        if (@($item.securityFinalizerMissingRunIdInputs).Count -gt 0) { $markdownLines += "  - Security finalizer missing run-id inputs: $(@($item.securityFinalizerMissingRunIdInputs) -join ', ')" }
        if (-not [string]::IsNullOrWhiteSpace($item.securityFinalizerDependencyNote)) { $markdownLines += "  - Security finalizer note: $($item.securityFinalizerDependencyNote)" }
        foreach ($step in @($item.steps)) { $markdownLines += "  - Step: $step" }
    }
}
$markdownLines += @("", "## Security Finalizer Run-id Hints", "")
if ($securityEvidenceFinalizerRunIdInputHints.Count -eq 0) {
    $markdownLines += "- Hints: none"
}
else {
    foreach ($hint in $securityEvidenceFinalizerRunIdInputHints) {
        $runIdParameter = Get-Text $hint "runIdParameter"
        if ([string]::IsNullOrWhiteSpace($runIdParameter)) { $runIdParameter = "RunId" }
        $workflowName = Get-Text $hint "workflow"
        if ([string]::IsNullOrWhiteSpace($workflowName)) { $workflowName = "workflow unknown" }
        $sourceState = if (Get-Bool $hint "sourceSelected") { "selected" } elseif (Get-Bool $hint "supplementalForSecurityFinalizer") { "supplemental" } else { "hint" }
        $markdownLines += "- ${runIdParameter}: workflow=$workflowName / source=$sourceState"
        $runsUrl = Get-Text $hint "runsUrl"
        if (-not [string]::IsNullOrWhiteSpace($runsUrl)) { $markdownLines += "  - Runs URL: $runsUrl" }
        $runListJsonPath = Get-Text $hint "runListJsonPath"
        if (-not [string]::IsNullOrWhiteSpace($runListJsonPath)) { $markdownLines += "  - Run-list JSON path: $runListJsonPath" }
    }
}
$markdownLines += @("", "## Post Dispatch Handoff", "")
if ($postDispatchCommands.Count -eq 0) {
    $markdownLines += "- Commands: none"
}
else {
    foreach ($command in $postDispatchCommands) {
        $markdownLines += "- $($command.name): ``$($command.command)``"
        if (-not [string]::IsNullOrWhiteSpace($command.note)) { $markdownLines += "  - Note: $($command.note)" }
    }
}
$markdownLines += @("", "## Stage Summary", "")
foreach ($stage in $stages) {
    $state = if ($stage.ready) { "ready" } elseif ($stage.exists) { "needs-action" } else { "missing" }
    $markdownLines += "- [$state] $($stage.name): $($stage.result)"
    if (-not [string]::IsNullOrWhiteSpace($stage.summary)) { $markdownLines += "  - Summary: $($stage.summary)" }
    $markdownLines += "  - Report: $($stage.reportPath)"
    if (-not [string]::IsNullOrWhiteSpace($stage.command)) { $markdownLines += "  - Command: ``$($stage.command)``" }
    if (-not [string]::IsNullOrWhiteSpace($stage.note)) { $markdownLines += "  - Note: $($stage.note)" }
}

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    $markdownLines | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations evidence handoff JSON: $resolvedJsonOutputPath"
    Write-Host "Operations evidence handoff markdown: $resolvedMarkdownOutputPath"
}

$report | ConvertTo-Json -Depth 12
