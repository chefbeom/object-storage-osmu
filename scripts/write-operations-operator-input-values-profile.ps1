param(
    [string] $WorksheetCsvPath = ".\.osmu-run\latest-operations-operator-input-worksheet.csv",
    [string] $CsvOutputPath = ".\.osmu-run\latest-operations-operator-input-values-profile.csv",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-operator-input-values-profile.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-operator-input-values-profile.md",
    [string] $ValueOverridesJsonPath = "",
    [string] $HandoffPackagePath = ".\.osmu-run\latest-operations-handoff-package.json",
    [switch] $UseHandoffPackageDefaults,
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $RunRef = "",
    [string] $ChangeApprovalRef = "",
    [string] $StartTime = "",
    [string] $CompletedTime = "",
    [string] $ApprovedAt = "",
    [switch] $Overwrite,
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

function Test-SafeInputValue([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    $unsafeFragments = @("`r", "`n", ";", "&&", "||", "|", "'", '"', '`', '$(', '@(')
    foreach ($fragment in $unsafeFragments) {
        if ($Value.Contains($fragment)) { return $false }
    }
    return -not ($Value -match '(^|\s)(\d|\*)?>{1,2}(\s|$)')
}

function Assert-SafeParameter([string] $Name, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    if (-not (Test-SafeInputValue $Value)) {
        throw "Unsafe operator input profile value for ${Name}: value contains shell-control characters."
    }
}

function Get-ValuePreview([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    if ($Value.Length -le 120) { return $Value }
    return $Value.Substring(0, 120) + "...<truncated>"
}

function Quote-PowerShellArgument([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return "''" }
    if ($Value -match '^[A-Za-z0-9_./:\\-]+$') { return $Value }
    return "'" + $Value.Replace("'", "''") + "'"
}

function Read-Overrides([string] $PathValue) {
    $values = [ordered]@{}
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $values }
    $resolvedPath = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Value overrides JSON not found: $resolvedPath"
    }
    $json = Read-Utf8Text $resolvedPath | ConvertFrom-Json
    foreach ($property in @($json.PSObject.Properties)) {
        $value = [string] $property.Value
        Assert-SafeParameter "override $($property.Name)" $value
        if (-not [string]::IsNullOrWhiteSpace($value)) { $values[$property.Name] = $value }
    }
    return $values
}

function Get-ProfileValue([object] $Row, [hashtable] $Overrides) {
    $valueKey = Get-Text $Row "valueKey"
    if (-not [string]::IsNullOrWhiteSpace($valueKey) -and $Overrides.Contains($valueKey)) {
        return [ordered]@{ value = $Overrides[$valueKey]; source = "override" }
    }

    $workflowInput = Get-Text $Row "workflowInput"
    switch ($workflowInput) {
        "environment_name" { return [ordered]@{ value = $EnvironmentName; source = "EnvironmentName" } }
        "target_cluster" { return [ordered]@{ value = $TargetCluster; source = "TargetCluster" } }
        "operator" { return [ordered]@{ value = $Operator; source = "Operator" } }
        "evidence_ref" { return [ordered]@{ value = $RunRef; source = "RunRef" } }
        "change_approval_ref" { return [ordered]@{ value = $ChangeApprovalRef; source = "ChangeApprovalRef" } }
        "approved_at" { return [ordered]@{ value = $ApprovedAt; source = "ApprovedAt" } }
    }

    if ($workflowInput -match 'started_at$') { return [ordered]@{ value = $StartTime; source = "StartTime" } }
    if ($workflowInput -match 'completed_at$') { return [ordered]@{ value = $CompletedTime; source = "CompletedTime" } }
    return [ordered]@{ value = ""; source = "" }
}

$handoffPackageDefaultsUsed = $false
$handoffPackageDefaultsSkipped = $false
$handoffPackageDefaultsSkipReason = ""
$handoffPackageDefaultValueCount = 0
$resolvedHandoffPackagePath = if ([string]::IsNullOrWhiteSpace($HandoffPackagePath)) { "" } else { Resolve-ProjectPath $HandoffPackagePath }
if ($UseHandoffPackageDefaults -and -not [string]::IsNullOrWhiteSpace($resolvedHandoffPackagePath) -and (Test-Path -LiteralPath $resolvedHandoffPackagePath)) {
    $handoffPackage = Read-Utf8Text $resolvedHandoffPackagePath | ConvertFrom-Json
    $packageEnvironmentName = Get-Text $handoffPackage "environmentName"
    $packageTargetCluster = Get-Text $handoffPackage "targetCluster"
    $packageOperatorName = Get-Text $handoffPackage "operatorName"
    $selfTestValues = @($packageEnvironmentName, $packageTargetCluster, $packageOperatorName) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) -and ([string] $_).IndexOf("self-test", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }
    if (@($selfTestValues).Count -gt 0) {
        $handoffPackageDefaultsSkipped = $true
        $handoffPackageDefaultsSkipReason = "handoff package identity contains self-test marker"
    }
    else {
        if ([string]::IsNullOrWhiteSpace($EnvironmentName)) {
            $EnvironmentName = $packageEnvironmentName
            if (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) { $handoffPackageDefaultValueCount++ }
        }
        if ([string]::IsNullOrWhiteSpace($TargetCluster)) {
            $TargetCluster = $packageTargetCluster
            if (-not [string]::IsNullOrWhiteSpace($TargetCluster)) { $handoffPackageDefaultValueCount++ }
        }
        if ([string]::IsNullOrWhiteSpace($Operator)) {
            $Operator = $packageOperatorName
            if (-not [string]::IsNullOrWhiteSpace($Operator)) { $handoffPackageDefaultValueCount++ }
        }
        $handoffPackageDefaultsUsed = $handoffPackageDefaultValueCount -gt 0
    }
}
$resolvedWorksheetCsvPath = Resolve-ProjectPath $WorksheetCsvPath
if (-not (Test-Path -LiteralPath $resolvedWorksheetCsvPath)) {
    throw "Operator input worksheet CSV not found: $resolvedWorksheetCsvPath"
}

foreach ($pair in @{
    EnvironmentName = $EnvironmentName
    TargetCluster = $TargetCluster
    Operator = $Operator
    RunRef = $RunRef
    ChangeApprovalRef = $ChangeApprovalRef
    StartTime = $StartTime
    CompletedTime = $CompletedTime
    ApprovedAt = $ApprovedAt
}.GetEnumerator()) {
    Assert-SafeParameter $pair.Key ([string] $pair.Value)
}

$overrides = Read-Overrides $ValueOverridesJsonPath
$rows = @(Import-Csv -LiteralPath $resolvedWorksheetCsvPath -Encoding UTF8)
$outputRows = New-Object System.Collections.Generic.List[object]
$summaryRows = New-Object System.Collections.Generic.List[object]
$filledCount = 0
$preservedCount = 0
$blankCount = 0
$overrideFillCount = 0
$profileFillCount = 0

foreach ($row in $rows) {
    $existingValue = Get-Text $row "value"
    $profile = Get-ProfileValue $row $overrides
    $profileValue = [string] $profile.value
    $profileSource = [string] $profile.source
    $nextValue = $existingValue
    $valueSource = if ([string]::IsNullOrWhiteSpace($existingValue)) { "" } else { "existing" }

    if (($Overwrite -or [string]::IsNullOrWhiteSpace($existingValue)) -and -not [string]::IsNullOrWhiteSpace($profileValue)) {
        $nextValue = $profileValue
        $valueSource = $profileSource
    }

    if ([string]::IsNullOrWhiteSpace($nextValue)) {
        $blankCount++
    }
    else {
        $filledCount++
        if ($valueSource -eq "existing") { $preservedCount++ }
        elseif ($valueSource -eq "override") { $overrideFillCount++ }
        else { $profileFillCount++ }
    }

    $outputRows.Add([pscustomobject][ordered]@{
        actionOrder = Get-Text $row "actionOrder"
        actionName = Get-Text $row "actionName"
        category = Get-Text $row "category"
        workflow = Get-Text $row "workflow"
        workflowInput = Get-Text $row "workflowInput"
        valueKey = Get-Text $row "valueKey"
        placeholder = Get-Text $row "placeholder"
        parameter = Get-Text $row "parameter"
        valueTemplate = Get-Text $row "valueTemplate"
        value = $nextValue
        occurrenceCount = Get-Text $row "occurrenceCount"
        ambiguousRepeatedPlaceholder = Get-Text $row "ambiguousRepeatedPlaceholder"
        suggestedSource = Get-Text $row "suggestedSource"
        note = Get-Text $row "note"
    }) | Out-Null

    $summaryRows.Add([pscustomobject][ordered]@{
        actionOrder = Get-Text $row "actionOrder"
        valueKey = Get-Text $row "valueKey"
        workflowInput = Get-Text $row "workflowInput"
        placeholder = Get-Text $row "placeholder"
        valueSource = $valueSource
        hasValue = -not [string]::IsNullOrWhiteSpace($nextValue)
        valuePreview = Get-ValuePreview $nextValue
    }) | Out-Null
}

$csvOutputPathResolved = Resolve-ProjectPath $CsvOutputPath
$jsonOutputPathResolved = Resolve-ProjectPath $JsonOutputPath
$markdownOutputPathResolved = Resolve-ProjectPath $MarkdownOutputPath
$generatedAt = [DateTimeOffset]::Now.ToString("o")
$valuesCheckCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-operator-input-values-check.ps1 -ValuesCsvPath $(Quote-PowerShellArgument $csvOutputPathResolved)"
$report = [ordered]@{
    formatVersion = "osmu.operations-operator-input-values-profile.v1"
    generatedAt = $generatedAt
    result = if ($blankCount -eq 0) { "ready" } else { "action-required" }
    sourceWorksheetCsv = $resolvedWorksheetCsvPath
    outputCsvPath = $csvOutputPathResolved
    valueOverridesJsonPath = if ([string]::IsNullOrWhiteSpace($ValueOverridesJsonPath)) { "" } else { Resolve-ProjectPath $ValueOverridesJsonPath }
    handoffPackagePath = if ($UseHandoffPackageDefaults) { $resolvedHandoffPackagePath } else { "" }
    handoffPackageDefaultsUsed = [bool] $handoffPackageDefaultsUsed
    handoffPackageDefaultsSkipped = [bool] $handoffPackageDefaultsSkipped
    handoffPackageDefaultsSkipReason = $handoffPackageDefaultsSkipReason
    handoffPackageDefaultValueCount = $handoffPackageDefaultValueCount
    rowCount = $rows.Count
    filledValueCount = $filledCount
    blankValueCount = $blankCount
    preservedValueCount = $preservedCount
    profileFillCount = $profileFillCount
    overrideFillCount = $overrideFillCount
    overwrite = [bool] $Overwrite
    valuesCheckCommand = $valuesCheckCommand
    rows = @($summaryRows.ToArray())
    decisionRule = "This profile writer only fills non-secret operator worksheet values supplied by the operator, an explicit override map, or environment/cluster/operator labels from the operations handoff package when -UseHandoffPackageDefaults is supplied, the package exists, and the package identity is not a self-test target. It does not execute workflows or mark readiness evidence as passed."
}

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add("# OSMU Operations Operator Input Values Profile") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("Generated at: $generatedAt") | Out-Null
$markdown.Add("Result: $($report.result)") | Out-Null
$markdown.Add("Source worksheet CSV: $resolvedWorksheetCsvPath") | Out-Null
$markdown.Add("Output CSV: $csvOutputPathResolved") | Out-Null
$markdown.Add("Values check command: ``$valuesCheckCommand``") | Out-Null
$markdown.Add("Handoff package defaults used: $handoffPackageDefaultsUsed") | Out-Null
$markdown.Add("Handoff package defaults skipped: $handoffPackageDefaultsSkipped") | Out-Null
$markdown.Add("Handoff package defaults skip reason: $handoffPackageDefaultsSkipReason") | Out-Null
$markdown.Add("Handoff package default values: $handoffPackageDefaultValueCount") | Out-Null
$markdown.Add("Handoff package path: $($report.handoffPackagePath)") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("## Summary") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("- Rows: $($report.rowCount)") | Out-Null
$markdown.Add("- Filled values: $filledCount") | Out-Null
$markdown.Add("- Blank values: $blankCount") | Out-Null
$markdown.Add("- Preserved values: $preservedCount") | Out-Null
$markdown.Add("- Profile-filled values: $profileFillCount") | Out-Null
$markdown.Add("- Override-filled values: $overrideFillCount") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("## Filled Values") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add("| Source | Value key | Action | Workflow input | Preview |") | Out-Null
$markdown.Add("| --- | --- | ---: | --- | --- |") | Out-Null
foreach ($row in @($summaryRows.ToArray() | Where-Object { $_.hasValue })) {
    $markdown.Add("| $($row.valueSource) | ``$($row.valueKey)`` | $($row.actionOrder) | $($row.workflowInput) | ``$($row.valuePreview)`` |") | Out-Null
}
if ($filledCount -eq 0) { $markdown.Add("| none | n/a | n/a | n/a | n/a |") | Out-Null }
$markdown.Add("") | Out-Null
$markdown.Add("## Decision Rule") | Out-Null
$markdown.Add("") | Out-Null
$markdown.Add($report.decisionRule) | Out-Null

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $csvOutputPathResolved) | Out-Null
    @($outputRows.ToArray()) | Export-Csv -LiteralPath $csvOutputPathResolved -NoTypeInformation -Encoding UTF8
    $report | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $jsonOutputPathResolved -Encoding UTF8
    $markdown | Set-Content -LiteralPath $markdownOutputPathResolved -Encoding UTF8
    Write-Host "Operations operator input values profile CSV: $csvOutputPathResolved"
    Write-Host "Operations operator input values profile JSON: $jsonOutputPathResolved"
    Write-Host "Operations operator input values profile markdown: $markdownOutputPathResolved"
}

$report | ConvertTo-Json -Depth 18
