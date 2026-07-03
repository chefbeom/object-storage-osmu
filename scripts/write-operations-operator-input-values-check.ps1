param(
    [string] $ValuesTemplatePath = ".\.osmu-run\latest-operations-operator-input-values-template.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-operator-input-values-check.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-operator-input-values-check.md",
    [string] $ValuesCsvPath = "",
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return [System.IO.Path]::GetFullPath($PathValue) }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    return [System.IO.File]::ReadAllText((Resolve-ProjectPath $PathValue), [System.Text.UTF8Encoding]::new($false, $true))
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

function Get-ArrayValue([object] $Value) {
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) { return @($Value) }
    return @($Value)
}
function Read-ValuesCsv([string] $PathValue) {
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return [ordered]@{} }
    $resolvedPath = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Operator input values CSV not found: $resolvedPath"
    }
    $values = [ordered]@{}
    foreach ($row in @(Import-Csv -LiteralPath $resolvedPath -Encoding UTF8)) {
        $valueKey = Get-Text $row "valueKey"
        if ([string]::IsNullOrWhiteSpace($valueKey)) { $valueKey = Get-Text $row "key" }
        if ([string]::IsNullOrWhiteSpace($valueKey)) { continue }
        $value = Get-Text $row "value"
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $values[$valueKey] = $value
    }
    return $values
}

function Test-SafeInputValue([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    $unsafeFragments = @("`r", "`n", ";", "&&", "||", "|", "'", '"', '`', '$(', '@(')
    foreach ($fragment in $unsafeFragments) {
        if ($Value.Contains($fragment)) { return $false }
    }
    return -not ($Value -match '(^|\s)(\d|\*)?>{1,2}(\s|$)')
}

function Test-KnownInputValue([string] $Placeholder, [string] $WorkflowInput, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    if ($Placeholder -eq "<YYYYMMDDTHHMMSSZ>") { return $Value -match '^\d{8}T\d{6}Z$' }
    if ($Placeholder -eq "<restore-api-base>" -or $WorkflowInput -eq "api_base") { return $Value -match '^https?://[^\s]+$' }
    if ($Placeholder -eq "<count>" -or $Placeholder -eq "<n>" -or $WorkflowInput -match '(count|rows)$') { return $Value -match '^\d+$' }
    if ($Placeholder -eq "<ms>" -or $WorkflowInput -match '_ms$') { return $Value -match '^\d+$' }
    if ($Placeholder -eq "<days>" -or $WorkflowInput -match '_days$') { return $Value -match '^\d+$' }
    if ($Placeholder -eq "<seconds>" -or $WorkflowInput -match '_seconds$') { return $Value -match '^\d+$' }
    if ($Placeholder -eq "<yyyy-mm>") { return $Value -match '^\d{4}-(0[1-9]|1[0-2])$' }
    if ($Placeholder -eq "<iso-time>" -or $WorkflowInput -match '(_at|started_at|completed_at)$') {
        $parsed = [DateTimeOffset]::MinValue
        return [DateTimeOffset]::TryParse($Value, [ref] $parsed)
    }
    if ($Placeholder -like "<base64-*>" -or $WorkflowInput -match 'base64$') {
        return $Value -match '^[A-Za-z0-9+/]+={0,2}$'
    }
    return $true
}

function Get-ValuePreview([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    if ($Value.Length -le 120) { return $Value }
    return $Value.Substring(0, 120) + "...<truncated>"
}

function New-ActionValueSummary([int] $ActionOrder, [string] $ActionName, [string] $Category, [string] $Workflow, [bool] $InputFree, [object[]] $ActionEntries) {
    $actionEntryArray = @($ActionEntries)
    $missing = @($actionEntryArray | Where-Object { $_.status -eq "missing" })
    $unsafe = @($actionEntryArray | Where-Object { $_.status -eq "unsafe" })
    $invalid = @($actionEntryArray | Where-Object { $_.status -eq "invalid" })
    $ready = @($actionEntryArray | Where-Object { $_.status -eq "ready" })
    $status = if ($missing.Count -eq 0 -and $unsafe.Count -eq 0 -and $invalid.Count -eq 0) { "ready" } else { "action-required" }
    return [pscustomobject][ordered]@{
        actionOrder = $ActionOrder
        actionName = $ActionName
        category = $Category
        workflow = $Workflow
        inputFree = $InputFree
        status = $status
        valueCount = $actionEntryArray.Count
        readyValueCount = $ready.Count
        missingValueCount = $missing.Count
        unsafeValueCount = $unsafe.Count
        invalidValueCount = $invalid.Count
        nonReadyValueKeys = @($actionEntryArray | Where-Object { $_.status -ne "ready" } | ForEach-Object { [string] $_.valueKey })
    }
}

$resolvedValuesTemplatePath = Resolve-ProjectPath $ValuesTemplatePath
if (-not (Test-Path -LiteralPath $resolvedValuesTemplatePath)) {
    throw "Operator input values template not found: $resolvedValuesTemplatePath"
}

$template = Read-Utf8Text $resolvedValuesTemplatePath | ConvertFrom-Json
if ($template.formatVersion -ne "osmu.operations-operator-input-values-template.v1") {
    throw "Unexpected operator input values template formatVersion: $($template.formatVersion)"
}

$valueObject = Get-JsonProperty $template "values"
$csvValues = Read-ValuesCsv $ValuesCsvPath
$entries = New-Object System.Collections.Generic.List[object]
foreach ($entry in @(Get-ArrayValue (Get-JsonProperty $template "entries"))) {
    $valueKey = Get-Text $entry "valueKey"
    $value = ""
    if (-not [string]::IsNullOrWhiteSpace($valueKey)) {
        $value = Get-Text $csvValues $valueKey
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = Get-Text $valueObject $valueKey
        }
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = Get-Text $entry "value"
        }
    }
    $missing = [string]::IsNullOrWhiteSpace($value)
    $safe = (-not $missing) -and (Test-SafeInputValue $value)
    $valid = (-not $missing) -and (Test-KnownInputValue (Get-Text $entry "placeholder") (Get-Text $entry "workflowInput") $value)
    $status = if ($missing) { "missing" } elseif (-not $safe) { "unsafe" } elseif (-not $valid) { "invalid" } else { "ready" }
    $entries.Add([pscustomobject][ordered]@{
        valueKey = $valueKey
        status = $status
        actionOrder = Get-Int $entry "actionOrder"
        actionName = Get-Text $entry "actionName"
        workflowInput = Get-Text $entry "workflowInput"
        placeholder = Get-Text $entry "placeholder"
        valuePreview = Get-ValuePreview $value
        suggestedSource = Get-Text $entry "suggestedSource"
    }) | Out-Null
}

$entryArray = @($entries.ToArray())
$missingCount = @($entryArray | Where-Object { $_.status -eq "missing" }).Count
$unsafeCount = @($entryArray | Where-Object { $_.status -eq "unsafe" }).Count
$invalidCount = @($entryArray | Where-Object { $_.status -eq "invalid" }).Count
$readyCount = @($entryArray | Where-Object { $_.status -eq "ready" }).Count

$worksheetActions = @()
$sourceWorksheetPath = Get-Text $template "sourceOperatorInputWorksheet"
if (-not [string]::IsNullOrWhiteSpace($sourceWorksheetPath)) {
    $resolvedSourceWorksheetPath = Resolve-ProjectPath $sourceWorksheetPath
    if (Test-Path -LiteralPath $resolvedSourceWorksheetPath) {
        try {
            $sourceWorksheet = Read-Utf8Text $resolvedSourceWorksheetPath | ConvertFrom-Json
            if ($sourceWorksheet.formatVersion -eq "osmu.operations-operator-input-worksheet.v1") {
                $worksheetActions = @(Get-ArrayValue (Get-JsonProperty $sourceWorksheet "actionWorklist"))
            }
        }
        catch {
            $worksheetActions = @()
        }
    }
}

$actionSummaries = New-Object System.Collections.Generic.List[object]
$seenActionOrders = New-Object System.Collections.Generic.List[int]
foreach ($action in @($worksheetActions)) {
    $order = Get-Int $action "actionOrder"
    if ($order -le 0) { continue }
    $matchingEntries = @($entryArray | Where-Object { $_.actionOrder -eq $order })
    $actionSummaries.Add((New-ActionValueSummary $order (Get-Text $action "name") (Get-Text $action "category") (Get-Text $action "workflow") (Get-Bool $action "inputFree") $matchingEntries)) | Out-Null
    if (-not $seenActionOrders.Contains($order)) { $seenActionOrders.Add($order) | Out-Null }
}
foreach ($group in @($entryArray | Group-Object actionOrder | Sort-Object { [int] $_.Name })) {
    $order = 0
    try { $order = [int] $group.Name } catch { $order = 0 }
    if ($order -le 0 -or $seenActionOrders.Contains($order)) { continue }
    $firstEntry = @($group.Group | Select-Object -First 1)[0]
    $actionSummaries.Add((New-ActionValueSummary $order (Get-Text $firstEntry "actionName") "" "" $false @($group.Group))) | Out-Null
}
$actionSummaryArray = @($actionSummaries.ToArray())
$valueReadyActionCount = @($actionSummaryArray | Where-Object { $_.status -eq "ready" }).Count
$nonReadyActionCount = @($actionSummaryArray | Where-Object { $_.status -ne "ready" }).Count

$result = if ($missingCount -eq 0 -and $unsafeCount -eq 0 -and $invalidCount -eq 0) { "ready" } else { "action-required" }
$generatedAt = [DateTimeOffset]::Now.ToString("o")

$report = [ordered]@{
    formatVersion = "osmu.operations-operator-input-values-check.v1"
    generatedAt = $generatedAt
    result = $result
    sourceValuesTemplate = $resolvedValuesTemplatePath
    sourceValuesCsv = if ([string]::IsNullOrWhiteSpace($ValuesCsvPath)) { "" } else { Resolve-ProjectPath $ValuesCsvPath }
    csvValueCount = $csvValues.Count
    sourceSummary = Get-Text $template "sourceSummary"
    selectedActionCount = Get-Int $template "selectedActionCount"
    valueCount = $entryArray.Count
    readyValueCount = $readyCount
    missingValueCount = $missingCount
    unsafeValueCount = $unsafeCount
    invalidValueCount = $invalidCount
    actionSummaryCount = $actionSummaryArray.Count
    valueReadyActionCount = $valueReadyActionCount
    nonReadyActionCount = $nonReadyActionCount
    actionSummaries = @($actionSummaryArray)
    entries = @($entryArray)
    decisionRule = "This check validates operator-provided non-secret input values before dispatch planning. It does not execute workflows or mark readiness evidence as passed."
}

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add("# OSMU Operations Operator Input Values Check") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("Generated at: $generatedAt") | Out-Null
$markdown.Add("Result: $result") | Out-Null
$markdown.Add("Source summary: $($report.sourceSummary)") | Out-Null
$markdown.Add("CSV values: $($report.csvValueCount)") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("## Summary") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("- Values: $($report.valueCount)") | Out-Null
$markdown.Add("- Ready: $readyCount") | Out-Null
$markdown.Add("- Missing: $missingCount") | Out-Null
$markdown.Add("- Unsafe: $unsafeCount") | Out-Null
$markdown.Add("- Invalid: $invalidCount") | Out-Null
$markdown.Add("- Actions: $($report.actionSummaryCount)") | Out-Null
$markdown.Add("- Value-ready actions: $valueReadyActionCount") | Out-Null
$markdown.Add("- Non-ready actions: $nonReadyActionCount") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("## Action Summary") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("| Status | Action | Values | Ready | Missing | Unsafe | Invalid | Workflow |") | Out-Null
$markdown.Add("| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |") | Out-Null
foreach ($action in @($actionSummaryArray | Sort-Object actionOrder)) {
    $workflow = if ([string]::IsNullOrWhiteSpace($action.workflow)) { "n/a" } else { $action.workflow }
    $markdown.Add("| $($action.status) | $($action.actionOrder) | $($action.valueCount) | $($action.readyValueCount) | $($action.missingValueCount) | $($action.unsafeValueCount) | $($action.invalidValueCount) | $workflow |") | Out-Null
}
if ($actionSummaryArray.Count -eq 0) { $markdown.Add("| ready | n/a | 0 | 0 | 0 | 0 | 0 | none |") | Out-Null }
$markdown.Add("") | Out-Null
$markdown.Add("## Non-Ready Values") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("| Status | Value key | Action | Workflow input | Placeholder | Suggested source |") | Out-Null
$markdown.Add("| --- | --- | --- | --- | --- | --- |") | Out-Null
foreach ($entry in @($entryArray | Where-Object { $_.status -ne "ready" })) {
    $markdown.Add("| $($entry.status) | ``$($entry.valueKey)`` | $($entry.actionOrder) | $($entry.workflowInput) | ``$($entry.placeholder)`` | $($entry.suggestedSource) |") | Out-Null
}
if (@($entryArray | Where-Object { $_.status -ne "ready" }).Count -eq 0) { $markdown.Add("| ready | n/a | n/a | n/a | n/a | none |") | Out-Null }
$markdown.Add("") | Out-Null
$markdown.Add("## Decision Rule") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add($report.decisionRule) | Out-Null

if (-not $NoWrite) {
    $jsonPath = Resolve-ProjectPath $JsonOutputPath
    $markdownPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonPath) | Out-Null
    $report | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8
    Write-Host "Operations operator input values check JSON: $jsonPath"
    Write-Host "Operations operator input values check markdown: $markdownPath"
}

$report | ConvertTo-Json -Depth 18
