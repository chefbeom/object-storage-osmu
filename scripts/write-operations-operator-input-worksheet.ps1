param(
    [string] $UnblockPlanPath = ".\.osmu-run\latest-operations-invocation-unblock-plan.json",
    [string] $DispatchPreflightReportPath = ".\.osmu-run\latest-operations-dispatch-preflight.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-operator-input-worksheet.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-operator-input-worksheet.md",
    [string] $CsvOutputPath = ".\.osmu-run\latest-operations-operator-input-worksheet.csv",
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
        return [ordered]@{ path = $resolvedPath; exists = $false; json = $null }
    }
    return [ordered]@{ path = $resolvedPath; exists = $true; json = (Read-Utf8Text $resolvedPath | ConvertFrom-Json) }
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

function Get-Bool([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) { return $false }
    try { return [System.Convert]::ToBoolean($value) } catch { return $false }
}

function Get-Array([object] $Value) {
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) { return @($Value) }
    return @($Value)
}

function Add-UniqueString([System.Collections.Generic.List[string]] $List, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    if (-not $List.Contains($Value)) { $List.Add($Value) | Out-Null }
}

function Get-WorkflowName([string] $Command) {
    if ([string]::IsNullOrWhiteSpace($Command)) { return "" }
    $match = [regex]::Match($Command, "gh\s+workflow\s+run\s+([^\s]+\.ya?ml)")
    if (-not $match.Success) { return "" }
    return [string] $match.Groups[1].Value
}

function Get-SourceHint([string] $Placeholder, [string] $WorkflowInput) {
    switch ($Placeholder) {
        "<YYYYMMDDTHHMMSSZ>" { return "Target backup timestamp in UTC basic format." }
        "<restore-api-base>" { return "Restore environment API base URL." }
        "<admin>" { return "Non-secret admin login id; password stays in GitHub secret." }
        "<count>" { return "Expected metadata/object count from restore drill." }
        "<run-id>" { return "Completed GitHub Actions run id; use latest operations workflow run-id plan." }
        "<artifact-name>" { return "Artifact name from the artifact collection plan for that run." }
        "<minio-endpoint>" { return "Target MinIO endpoint; do not include credentials." }
        "<env>" { return "Target environment name, for example pilot-prod." }
        "<cluster>" { return "Target cluster identifier." }
        "<operator>" { return "Operator or reviewer name/id." }
        "<alias>" { return "MinIO admin alias name used for telemetry." }
        "<run-ref>" { return "External non-secret evidence/run reference." }
        "<events-per-day>" { return "Expected peak data-flow event volume." }
        "<query-window-days>" { return "Expected analytics query window in days." }
        "<p95-ms>" { return "Target p95 latency budget in milliseconds." }
        "<iso-time>" { return "ISO-8601 timestamp; use distinct start/end values when workflow inputs differ." }
        "<ref>" { return "External non-secret evidence reference; use distinct refs when workflow inputs differ." }
        "<ms>" { return "Latency value in milliseconds; p95 and p99 usually need different values." }
        "<n>" { return "Count value; use the count that matches the workflow input." }
        "<days>" { return "Observed query window in days." }
        "<seconds>" { return "Duration value in seconds; use the value that matches the workflow input." }
        "<change-id>" { return "Change approval or ticket reference." }
        "<audit-ref>" { return "Secret manager audit evidence reference." }
        "<rollout-ref>" { return "Workload restart/rollout evidence reference." }
        "<smoke-ref>" { return "Smoke verification evidence reference." }
        "<scan-ref>" { return "Artifact leak scan/review evidence reference." }
        "<decision-ref>" { return "Access-key encryption decision reference." }
        "<version>" { return "Product/release version." }
        "<approval-ref>" { return "Commercial approval reference." }
        "<approver>" { return "Commercial approver name/id." }
        "<yyyy-mm>" { return "Billing period in YYYY-MM format." }
    }
    if ($Placeholder -like "<base64-latest-*-json>") {
        $name = $Placeholder.Trim("<>").Replace("base64-", "")
        if ($name.EndsWith("-json", [System.StringComparison]::OrdinalIgnoreCase)) {
            $name = $name.Substring(0, $name.Length - 5)
        }
        $fileName = "$name.json"
        return "Base64 of sanitized .osmu-run/$fileName after that evidence result is passed."
    }
    if ($Placeholder -like "<base64-*>") {
        return "Base64 of the named sanitized JSON payload; do not include secrets or raw customer/provider data."
    }
    if ([string]::IsNullOrWhiteSpace($WorkflowInput)) {
        return "Provide a concrete non-secret value."
    }
    return "Provide value for workflow input '$WorkflowInput'."
}

function Get-DispatchTemplateByAction([object] $DispatchReport) {
    $map = @{}
    if ($null -eq $DispatchReport) { return $map }
    foreach ($template in @(Get-Array (Get-JsonProperty $DispatchReport "inputTemplates"))) {
        $order = Get-Int $template "actionOrder"
        if ($order -gt 0) { $map[$order] = $template }
    }
    return $map
}

function New-InputValueKey([int] $ActionOrder, [string] $WorkflowInput, [string] $Placeholder) {
    $suffix = if ([string]::IsNullOrWhiteSpace($WorkflowInput)) { $Placeholder.Trim("<", ">") } else { $WorkflowInput }
    $suffix = ([regex]::Replace($suffix.ToLowerInvariant(), "[^a-z0-9_.-]+", "-")).Trim("-", ".", "_")
    if ([string]::IsNullOrWhiteSpace($suffix)) { $suffix = "input" }
    return "action-{0:00}.{1}" -f $ActionOrder, $suffix
}

$unblock = Read-OptionalJson $UnblockPlanPath
if (-not $unblock.exists) {
    throw "Unblock plan not found: $($unblock.path)"
}
$dispatch = Read-OptionalJson $DispatchPreflightReportPath
$dispatchTemplateByAction = Get-DispatchTemplateByAction $dispatch.json

$rows = New-Object System.Collections.Generic.List[object]
$inputFreeActions = New-Object System.Collections.Generic.List[object]
$requiredSecrets = New-Object System.Collections.Generic.List[string]

foreach ($action in @(Get-Array (Get-JsonProperty $unblock.json "actions"))) {
    $order = Get-Int $action "order"
    $name = Get-Text $action "name"
    $category = Get-Text $action "category"
    $command = Get-Text $action "command"
    $workflow = Get-WorkflowName $command
    $requiredInputs = @(Get-Array (Get-JsonProperty $action "requiredInputs"))
    $template = if ($dispatchTemplateByAction.ContainsKey($order)) { $dispatchTemplateByAction[$order] } else { $null }
    foreach ($secret in @(Get-Array (Get-JsonProperty $template "requiredSecrets"))) {
        Add-UniqueString $requiredSecrets ([string] $secret)
    }
    if ($requiredInputs.Count -eq 0) {
        $inputFreeActions.Add([pscustomobject][ordered]@{
            actionOrder = $order
            name = $name
            category = $category
            workflow = $workflow
            requiresOperatorApproval = Get-Bool $action "requiresOperatorApproval"
            requiresKubeconfigSecret = Get-Bool $action "requiresKubeconfigSecret"
            requiredSecrets = @(Get-Array (Get-JsonProperty $template "requiredSecrets") | ForEach-Object { [string] $_ })
        }) | Out-Null
        continue
    }
    foreach ($input in $requiredInputs) {
        $placeholder = Get-Text $input "placeholder"
        $workflowInputs = @(Get-Array (Get-JsonProperty $input "workflowInputs") | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($workflowInputs.Count -eq 0) { $workflowInputs = @("") }
        foreach ($workflowInput in $workflowInputs) {
            $rows.Add([pscustomobject][ordered]@{
                actionOrder = $order
                actionName = $name
                category = $category
                workflow = $workflow
                workflowInput = $workflowInput
                valueKey = New-InputValueKey $order $workflowInput $placeholder
                placeholder = $placeholder
                parameter = Get-Text $input "parameter"
                valueTemplate = Get-Text $input "valueTemplate"
                occurrenceCount = Get-Int $input "occurrenceCount"
                ambiguousRepeatedPlaceholder = Get-Bool $input "ambiguousRepeatedPlaceholder"
                suggestedSource = Get-SourceHint $placeholder $workflowInput
                note = Get-Text $input "note"
            }) | Out-Null
        }
    }
}

$confirmationGroups = @(Get-Array (Get-JsonProperty $unblock.json "confirmationGroups") | ForEach-Object {
    [ordered]@{
        kind = Get-Text $_ "kind"
        label = Get-Text $_ "label"
        flag = Get-Text $_ "flag"
        actionOrders = @(Get-Array (Get-JsonProperty $_ "actionOrders") | ForEach-Object { [int] $_ })
        note = Get-Text $_ "note"
    }
})

$dispatchUnavailableReasons = New-Object System.Collections.Generic.List[string]
if ($dispatch.exists) {
    if (-not (Get-Bool $dispatch.json "githubCliAvailableForDispatch")) {
        Add-UniqueString $dispatchUnavailableReasons "GitHub CLI is not available for dispatch."
    }
    foreach ($reason in @(Get-Array (Get-JsonProperty $dispatch.json "githubApiDispatchUnavailableReasons"))) {
        Add-UniqueString $dispatchUnavailableReasons ([string] $reason)
    }
}

$result = if ($rows.Count -eq 0 -and $confirmationGroups.Count -eq 0 -and $dispatchUnavailableReasons.Count -eq 0) { "ready" } else { "action-required" }
$rowArray = @($rows.ToArray())
$inputFreeActionArray = @($inputFreeActions.ToArray())
$requiredSecretArray = @($requiredSecrets.ToArray())
$dispatchUnavailableReasonArray = @($dispatchUnavailableReasons.ToArray())
$ambiguousInputRowCount = 0
foreach ($row in $rowArray) {
    if ([bool] $row.ambiguousRepeatedPlaceholder) {
        $ambiguousInputRowCount++
    }
}

$actionWorklist = New-Object System.Collections.Generic.List[object]
foreach ($action in @(Get-Array (Get-JsonProperty $unblock.json "actions"))) {
    $order = Get-Int $action "order"
    $template = if ($dispatchTemplateByAction.ContainsKey($order)) { $dispatchTemplateByAction[$order] } else { $null }
    $actionRows = @($rowArray | Where-Object { [int] $_.actionOrder -eq $order })
    $actionRequiredSecrets = @(Get-Array (Get-JsonProperty $template "requiredSecrets") | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $workflowInputs = @($actionRows | ForEach-Object { [string] $_.workflowInput } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $placeholders = @($actionRows | ForEach-Object { [string] $_.placeholder } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $ambiguousRows = @($actionRows | Where-Object { [bool] $_.ambiguousRepeatedPlaceholder })
    $isInputFree = @($inputFreeActionArray | Where-Object { [int] $_.actionOrder -eq $order }).Count -gt 0
    $actionWorklist.Add([pscustomobject][ordered]@{
        actionOrder = $order
        name = Get-Text $action "name"
        category = Get-Text $action "category"
        workflow = Get-WorkflowName (Get-Text $action "command")
        inputFree = $isInputFree
        inputRowCount = $actionRows.Count
        ambiguousInputRowCount = $ambiguousRows.Count
        workflowInputCount = $workflowInputs.Count
        workflowInputs = @($workflowInputs)
        placeholderCount = $placeholders.Count
        placeholders = @($placeholders)
        requiresOperatorApproval = Get-Bool $action "requiresOperatorApproval"
        requiresKubeconfigSecret = Get-Bool $action "requiresKubeconfigSecret"
        requiredSecretCount = $actionRequiredSecrets.Count
        requiredSecrets = @($actionRequiredSecrets)
    }) | Out-Null
}
$actionWorklistArray = @($actionWorklist.ToArray())
$report = [ordered]@{
    formatVersion = "osmu.operations-operator-input-worksheet.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = $result
    sourceUnblockPlan = $unblock.path
    sourceDispatchPreflightReport = $dispatch.path
    sourceSummary = Get-Text $unblock.json "sourceSummary"
    sourcePassedCount = Get-Int $unblock.json "sourcePassedCount"
    sourcePendingCount = Get-Int $unblock.json "sourcePendingCount"
    sourceTotalCount = Get-Int $unblock.json "sourceTotalCount"
    selectedActionCount = Get-Int $unblock.json "selectedActionCount"
    actionWorklistCount = $actionWorklistArray.Count
    confirmationCount = $confirmationGroups.Count
    inputRowCount = $rows.Count
    ambiguousInputRowCount = $ambiguousInputRowCount
    inputFreeActionCount = $inputFreeActionArray.Count
    requiredSecretCount = $requiredSecretArray.Count
    dispatchUnavailableReasonCount = $dispatchUnavailableReasonArray.Count
    confirmations = @($confirmationGroups)
    actionWorklist = @($actionWorklistArray)
    requiredSecrets = @($requiredSecretArray)
    dispatchUnavailableReasons = @($dispatchUnavailableReasonArray)
    inputFreeActions = @($inputFreeActionArray)
    inputRows = @($rowArray)
    decisionRule = "Use this worksheet for operator data collection and manual workflow dispatch only. It does not mark readiness evidence as passed; every pending action still requires target evidence, workflow run ids, artifact import, finalization, and convergence."
}

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add("# OSMU Operations Operator Input Worksheet") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("Generated at: $($report.generatedAt)") | Out-Null
$markdown.Add("Result: $($report.result)") | Out-Null
$markdown.Add("Source summary: $($report.sourceSummary)") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("## Summary") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("- Selected actions: $($report.selectedActionCount)") | Out-Null
$markdown.Add("- Confirmation groups: $($report.confirmationCount)") | Out-Null
$markdown.Add("- Input rows: $($report.inputRowCount)") | Out-Null
$markdown.Add("- Ambiguous expanded rows: $($report.ambiguousInputRowCount)") | Out-Null
$markdown.Add("- Input-free actions: $($report.inputFreeActionCount)") | Out-Null
$markdown.Add("- Required GitHub secrets: $($report.requiredSecretCount)") | Out-Null
$markdown.Add("- Dispatch unavailable reasons: $($report.dispatchUnavailableReasonCount)") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("## Action Worklist") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("| Action | Category | Workflow | Inputs | Ambiguous | Secrets | Confirmations |") | Out-Null
$markdown.Add("| --- | --- | --- | --- | --- | --- | --- |") | Out-Null
foreach ($action in $actionWorklistArray) {
    $workflow = if ([string]::IsNullOrWhiteSpace($action.workflow)) { "local" } else { $action.workflow }
    $secretsText = if ($action.requiredSecrets.Count -gt 0) { $action.requiredSecrets -join "," } else { "none" }
    $confirmations = New-Object System.Collections.Generic.List[string]
    if ([bool] $action.requiresOperatorApproval) { $confirmations.Add("operator") | Out-Null }
    if ([bool] $action.requiresKubeconfigSecret) { $confirmations.Add("kubeconfig") | Out-Null }
    $confirmationText = if ($confirmations.Count -gt 0) { $confirmations -join "," } else { "none" }
    $markdown.Add("| $($action.actionOrder) | $($action.category) | $workflow | $($action.inputRowCount) | $($action.ambiguousInputRowCount) | $secretsText | $confirmationText |") | Out-Null
}
if ($actionWorklistArray.Count -eq 0) { $markdown.Add("| n/a | n/a | n/a | 0 | 0 | none | none |") | Out-Null }
$markdown.Add("") | Out-Null
$markdown.Add("## Confirmations") | Out-Null
$markdown.Add("") | Out-Null
foreach ($confirmation in $confirmationGroups) {
    $markdown.Add(("- {0}: actions {1} via ``{2}``" -f $confirmation.label, ($confirmation.actionOrders -join ","), $confirmation.flag)) | Out-Null
}
if ($confirmationGroups.Count -eq 0) { $markdown.Add("- none") | Out-Null }
$markdown.Add("") | Out-Null
$markdown.Add("## Input-Free Actions") | Out-Null
$markdown.Add("") | Out-Null
foreach ($action in $inputFreeActionArray) {
    $secretsText = if ($action.requiredSecrets.Count -gt 0) { $action.requiredSecrets -join "," } else { "none" }
    $markdown.Add("- [$($action.actionOrder)] $($action.name) / workflow=$($action.workflow) / secrets=$secretsText") | Out-Null
}
if ($inputFreeActionArray.Count -eq 0) { $markdown.Add("- none") | Out-Null }
$markdown.Add("") | Out-Null
$markdown.Add("## Required Secrets") | Out-Null
$markdown.Add("") | Out-Null
foreach ($secret in $requiredSecretArray) { $markdown.Add("- $secret") | Out-Null }
if ($requiredSecretArray.Count -eq 0) { $markdown.Add("- none") | Out-Null }
$markdown.Add("") | Out-Null
$markdown.Add("## Inputs") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("| Action | Value key | Category | Workflow | Workflow input | Placeholder | Ambiguous | Suggested source |") | Out-Null
$markdown.Add("| --- | --- | --- | --- | --- | --- | --- | --- |") | Out-Null
foreach ($row in $rowArray) {
    $workflowInput = if ([string]::IsNullOrWhiteSpace($row.workflowInput)) { "n/a" } else { $row.workflowInput }
    $markdown.Add("| $($row.actionOrder) | ``$($row.valueKey)`` | $($row.category) | $($row.workflow) | $workflowInput | ``$($row.placeholder)`` | $($row.ambiguousRepeatedPlaceholder) | $($row.suggestedSource) |") | Out-Null
}
if ($rowArray.Count -eq 0) { $markdown.Add("| n/a | n/a | n/a | n/a | n/a | n/a | n/a | none |") | Out-Null }
$markdown.Add("") | Out-Null
$markdown.Add("## Dispatch Availability") | Out-Null
$markdown.Add("") | Out-Null
foreach ($reason in $dispatchUnavailableReasonArray) { $markdown.Add("- $reason") | Out-Null }
if ($dispatchUnavailableReasonArray.Count -eq 0) { $markdown.Add("- ready") | Out-Null }
$markdown.Add("") | Out-Null
$markdown.Add("## Decision Rule") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add($report.decisionRule) | Out-Null

if (-not $NoWrite) {
    $jsonPath = Resolve-ProjectPath $JsonOutputPath
    $markdownPath = Resolve-ProjectPath $MarkdownOutputPath
    $csvPath = Resolve-ProjectPath $CsvOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonPath) | Out-Null
    $report | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8
    $rows | ForEach-Object { [pscustomobject] $_ } | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Operations operator input worksheet JSON: $jsonPath"
    Write-Host "Operations operator input worksheet markdown: $markdownPath"
    Write-Host "Operations operator input worksheet CSV: $csvPath"
}

$report | ConvertTo-Json -Depth 18
