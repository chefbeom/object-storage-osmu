param(
    [string] $OutputDirectory = ".\.osmu-run\operations-operator-input-values-check-self-test"
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

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) { throw "$Message. Expected '$Expected' but got '$Actual'." }
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Message) {
    if (-not $Text.Contains($Expected)) { throw "$Message. Missing '$Expected'." }
}

function Write-JsonFixture([string] $PathValue, [object] $Value) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $PathValue) | Out-Null
    $Value | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $PathValue -Encoding UTF8
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
$safeRootWithSeparator = $safeRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$isSafeOutputDirectory = $resolvedOutputDirectory.Equals($safeRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $resolvedOutputDirectory.StartsWith($safeRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
if (-not $isSafeOutputDirectory) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-operator-input-values-check.ps1"
$valuesTemplatePath = Join-Path $resolvedOutputDirectory "input-values-template.json"
$jsonOutputPath = Join-Path $resolvedOutputDirectory "input-values-check.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "input-values-check.md"
$readyValuesTemplatePath = Join-Path $resolvedOutputDirectory "ready-input-values-template.json"
$readyJsonOutputPath = Join-Path $resolvedOutputDirectory "ready-input-values-check.json"
$readyMarkdownOutputPath = Join-Path $resolvedOutputDirectory "ready-input-values-check.md"
$csvValuesPath = Join-Path $resolvedOutputDirectory "operator-values.csv"
$csvJsonOutputPath = Join-Path $resolvedOutputDirectory "csv-input-values-check.json"
$csvMarkdownOutputPath = Join-Path $resolvedOutputDirectory "csv-input-values-check.md"

$baseEntries = @(
    [ordered]@{ valueKey = "action-02.backup_timestamp"; value = ""; actionOrder = 2; actionName = "Kubernetes DR finalizer live evidence"; workflowInput = "backup_timestamp"; placeholder = "<YYYYMMDDTHHMMSSZ>"; suggestedSource = "Target backup timestamp in UTC basic format." },
    [ordered]@{ valueKey = "action-02.api_base"; value = ""; actionOrder = 2; actionName = "Kubernetes DR finalizer live evidence"; workflowInput = "api_base"; placeholder = "<restore-api-base>"; suggestedSource = "Restore environment API base URL." },
    [ordered]@{ valueKey = "action-08.observed_p95_query_latency_ms"; value = ""; actionOrder = 8; actionName = "Data-flow query/retention budget target evidence"; workflowInput = "observed_p95_query_latency_ms"; placeholder = "<ms>"; suggestedSource = "Latency value in milliseconds." },
    [ordered]@{ valueKey = "action-08.review_started_at"; value = ""; actionOrder = 8; actionName = "Data-flow query/retention budget target evidence"; workflowInput = "review_started_at"; placeholder = "<iso-time>"; suggestedSource = "ISO timestamp." }
)

Write-JsonFixture $valuesTemplatePath ([ordered]@{
    formatVersion = "osmu.operations-operator-input-values-template.v1"
    generatedAt = "2026-07-02T10:00:00+09:00"
    result = "action-required"
    sourceSummary = "passed=83 pending=19"
    selectedActionCount = 4
    valueCount = 4
    values = [ordered]@{
        "action-02.backup_timestamp" = "not-a-timestamp"
        "action-02.api_base" = "https://restore.example.test"
        "action-08.observed_p95_query_latency_ms" = "42 | Write-Host unsafe"
        "action-08.review_started_at" = ""
    }
    entries = $baseEntries
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ValuesTemplatePath $valuesTemplatePath `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-operator-input-values-check.ps1 action-required fixture failed with exit code $LASTEXITCODE."
}

$report = Read-Utf8Text $jsonOutputPath | ConvertFrom-Json
$markdown = Read-Utf8Text $markdownOutputPath

Assert-Equal $report.formatVersion "osmu.operations-operator-input-values-check.v1" "formatVersion"
Assert-Equal $report.result "action-required" "result"
Assert-Equal $report.valueCount 4 "value count"
Assert-Equal $report.readyValueCount 1 "ready value count"
Assert-Equal $report.missingValueCount 1 "missing value count"
Assert-Equal $report.unsafeValueCount 1 "unsafe value count"
Assert-Equal $report.invalidValueCount 1 "invalid value count"
Assert-Equal $report.actionSummaryCount 2 "action summary count"
Assert-Equal $report.valueReadyActionCount 0 "value-ready action count"
Assert-Equal $report.nonReadyActionCount 2 "non-ready action count"
Assert-True (@($report.actionSummaries | Where-Object { $_.actionOrder -eq 2 -and $_.missingValueCount -eq 0 -and $_.invalidValueCount -eq 1 }).Count -eq 1) "expected action 2 invalid summary"
Assert-True (@($report.actionSummaries | Where-Object { $_.actionOrder -eq 8 -and $_.missingValueCount -eq 1 -and $_.unsafeValueCount -eq 1 }).Count -eq 1) "expected action 8 missing/unsafe summary"
Assert-True (@($report.entries | Where-Object { $_.valueKey -eq "action-02.backup_timestamp" -and $_.status -eq "invalid" }).Count -eq 1) "expected invalid backup timestamp"
Assert-True (@($report.entries | Where-Object { $_.valueKey -eq "action-08.observed_p95_query_latency_ms" -and $_.status -eq "unsafe" }).Count -eq 1) "expected unsafe p95 latency"
Assert-Contains $markdown "## Action Summary" "markdown missing action summary"
Assert-Contains $markdown "action-08.review_started_at" "markdown missing review_started_at"
Assert-Contains $markdown "unsafe" "markdown unsafe status"

Write-JsonFixture $readyValuesTemplatePath ([ordered]@{
    formatVersion = "osmu.operations-operator-input-values-template.v1"
    generatedAt = "2026-07-02T10:05:00+09:00"
    result = "action-required"
    sourceSummary = "passed=83 pending=19"
    selectedActionCount = 4
    valueCount = 4
    values = [ordered]@{
        "action-02.backup_timestamp" = "20260702T010203Z"
        "action-02.api_base" = "https://restore.example.test"
        "action-08.observed_p95_query_latency_ms" = "42"
        "action-08.review_started_at" = "2026-07-02T01:02:03Z"
    }
    entries = $baseEntries
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ValuesTemplatePath $readyValuesTemplatePath `
    -JsonOutputPath $readyJsonOutputPath `
    -MarkdownOutputPath $readyMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-operator-input-values-check.ps1 ready fixture failed with exit code $LASTEXITCODE."
}

$readyReport = Read-Utf8Text $readyJsonOutputPath | ConvertFrom-Json
$readyMarkdown = Read-Utf8Text $readyMarkdownOutputPath
Assert-Equal $readyReport.result "ready" "ready result"
Assert-Equal $readyReport.readyValueCount 4 "ready ready value count"
Assert-Equal $readyReport.missingValueCount 0 "ready missing value count"
Assert-Equal $readyReport.unsafeValueCount 0 "ready unsafe value count"
Assert-Equal $readyReport.invalidValueCount 0 "ready invalid value count"
Assert-Equal $readyReport.actionSummaryCount 2 "ready action summary count"
Assert-Equal $readyReport.valueReadyActionCount 2 "ready value-ready action count"
Assert-Equal $readyReport.nonReadyActionCount 0 "ready non-ready action count"
Assert-Contains $readyMarkdown "| ready | n/a | n/a | n/a | n/a | none |" "ready markdown non-ready empty row"
@(
    [pscustomobject][ordered]@{ valueKey = "action-02.backup_timestamp"; value = "20260702T010203Z" }
    [pscustomobject][ordered]@{ valueKey = "action-02.api_base"; value = "https://restore.example.test" }
    [pscustomobject][ordered]@{ valueKey = "action-08.observed_p95_query_latency_ms"; value = "42" }
    [pscustomobject][ordered]@{ valueKey = "action-08.review_started_at"; value = "2026-07-02T01:02:03Z" }
) | Export-Csv -LiteralPath $csvValuesPath -NoTypeInformation -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ValuesTemplatePath $valuesTemplatePath `
    -ValuesCsvPath $csvValuesPath `
    -JsonOutputPath $csvJsonOutputPath `
    -MarkdownOutputPath $csvMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-operator-input-values-check.ps1 CSV overlay fixture failed with exit code $LASTEXITCODE."
}

$csvReport = Read-Utf8Text $csvJsonOutputPath | ConvertFrom-Json
$csvMarkdown = Read-Utf8Text $csvMarkdownOutputPath
Assert-Equal $csvReport.result "ready" "CSV overlay ready result"
Assert-Equal $csvReport.csvValueCount 4 "CSV overlay value count"
Assert-Equal $csvReport.readyValueCount 4 "CSV overlay ready value count"
Assert-Equal $csvReport.missingValueCount 0 "CSV overlay missing value count"
Assert-Equal $csvReport.unsafeValueCount 0 "CSV overlay unsafe value count"
Assert-Equal $csvReport.invalidValueCount 0 "CSV overlay invalid value count"
Assert-Contains $csvReport.sourceValuesCsv $csvValuesPath "CSV overlay source path"
Assert-Contains $csvMarkdown "CSV values: 4" "CSV overlay markdown value count"

Write-Host "Operations operator input values check verified."
Write-Host "Action-required report: $jsonOutputPath"
Write-Host "Ready report: $readyJsonOutputPath"
