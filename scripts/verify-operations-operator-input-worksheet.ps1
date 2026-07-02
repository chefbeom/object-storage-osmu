param(
    [string] $OutputDirectory = ".\.osmu-run\operations-operator-input-worksheet-self-test"
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
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
}

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message. Expected '$Expected' but got '$Actual'."
    }
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Message) {
    if (-not $Text.Contains($Expected)) {
        throw "$Message. Missing '$Expected'."
    }
}

function Write-JsonFixture([string] $PathValue, [object] $Value) {
    $directory = Split-Path -Parent $PathValue
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $Value | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $PathValue -Encoding UTF8
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-operator-input-worksheet.ps1"
$unblockPlanPath = Join-Path $resolvedOutputDirectory "unblock-plan.json"
$dispatchPreflightPath = Join-Path $resolvedOutputDirectory "dispatch-preflight.json"
$jsonOutputPath = Join-Path $resolvedOutputDirectory "worksheet.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "worksheet.md"
$csvOutputPath = Join-Path $resolvedOutputDirectory "worksheet.csv"
$valuesTemplateOutputPath = Join-Path $resolvedOutputDirectory "input-values-template.json"
$valuesTemplateMarkdownOutputPath = Join-Path $resolvedOutputDirectory "input-values-template.md"

Write-JsonFixture $unblockPlanPath ([ordered]@{
    formatVersion = "osmu.operations-invocation-unblock-plan.v1"
    generatedAt = "2026-06-16T08:00:00+09:00"
    result = "action-required"
    sourceSummary = "passed=83 pending=19"
    sourcePassedCount = 83
    sourcePendingCount = 19
    sourceTotalCount = 102
    selectedActionCount = 3
    confirmationGroups = @(
        [ordered]@{
            kind = "operator-approval"
            label = "Operator approval"
            flag = "-ConfirmOperatorApproval"
            actionOrders = @(1, 2)
            note = "Confirm operator approval."
        }
    )
    actions = @(
        [ordered]@{
            order = 1
            name = "Storage expansion finalizer live evidence"
            category = "storage-expansion"
            command = "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true"
            requiresOperatorApproval = $true
            requiresKubeconfigSecret = $true
            requiredInputs = @()
        },
        [ordered]@{
            order = 2
            name = "Data-flow query/retention budget target evidence"
            category = "data-flow"
            command = "gh workflow run manual-data-flow-query-retention-budget-evidence.yml -f review_started_at=<iso-time> -f review_completed_at=<iso-time> -f observed_p95_query_latency_ms=<ms> -f observed_p99_query_latency_ms=<ms>"
            requiresOperatorApproval = $true
            requiresKubeconfigSecret = $false
            requiredInputs = @(
                [ordered]@{
                    placeholder = "<iso-time>"
                    parameter = "Placeholder"
                    valueTemplate = "<iso-time>"
                    workflowInputs = @("review_started_at", "review_completed_at")
                    occurrenceCount = 2
                    ambiguousRepeatedPlaceholder = $true
                    note = "Repeated timestamp placeholder."
                },
                [ordered]@{
                    placeholder = "<ms>"
                    parameter = "Placeholder"
                    valueTemplate = "<ms>"
                    workflowInputs = @("observed_p95_query_latency_ms", "observed_p99_query_latency_ms")
                    occurrenceCount = 2
                    ambiguousRepeatedPlaceholder = $true
                    note = "Repeated metric placeholder."
                }
            )
        },
        [ordered]@{
            order = 3
            name = "Storage backend telemetry target evidence"
            category = "storage-backend"
            command = "gh workflow run manual-storage-backend-telemetry-evidence.yml -f minio_endpoint=<minio-endpoint>"
            requiresOperatorApproval = $false
            requiresKubeconfigSecret = $false
            requiredInputs = @(
                [ordered]@{
                    placeholder = "<minio-endpoint>"
                    parameter = "Placeholder"
                    valueTemplate = "<minio-endpoint>"
                    workflowInputs = @("minio_endpoint")
                    occurrenceCount = 1
                    ambiguousRepeatedPlaceholder = $false
                    note = "MinIO endpoint."
                }
            )
        }
    )
})

Write-JsonFixture $dispatchPreflightPath ([ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    result = "action-required"
    githubCliAvailableForDispatch = $false
    githubApiDispatchUnavailableReasons = @("GH_TOKEN or GITHUB_TOKEN is not set")
    inputTemplates = @(
        [ordered]@{ actionOrder = 1; requiredSecrets = @("OSMU_KUBECONFIG_BASE64") },
        [ordered]@{ actionOrder = 2; requiredSecrets = @() },
        [ordered]@{ actionOrder = 3; requiredSecrets = @("OSMU_MINIO_ACCESS_KEY", "OSMU_MINIO_SECRET_KEY") }
    )
})

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -UnblockPlanPath $unblockPlanPath `
    -DispatchPreflightReportPath $dispatchPreflightPath `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -CsvOutputPath $csvOutputPath `
    -ValuesTemplateOutputPath $valuesTemplateOutputPath `
    -ValuesTemplateMarkdownOutputPath $valuesTemplateMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-operator-input-worksheet.ps1 fixture failed with exit code $LASTEXITCODE."
}

$report = Read-Utf8Text $jsonOutputPath | ConvertFrom-Json
$markdown = Read-Utf8Text $markdownOutputPath
$csv = Read-Utf8Text $csvOutputPath
$valuesTemplate = Read-Utf8Text $valuesTemplateOutputPath | ConvertFrom-Json
$valuesTemplateMarkdown = Read-Utf8Text $valuesTemplateMarkdownOutputPath

Assert-Equal $report.formatVersion "osmu.operations-operator-input-worksheet.v1" "formatVersion"
Assert-Equal $report.result "action-required" "result"
Assert-Equal $report.sourceSummary "passed=83 pending=19" "source summary"
Assert-Equal $report.actionWorklistCount 3 "action worklist count"
Assert-Equal $report.inputValueTemplateCount 5 "input value template count"
Assert-Equal $report.csvPath (Resolve-ProjectPath $csvOutputPath) "csv path"
Assert-Equal $report.inputValuesTemplatePath (Resolve-ProjectPath $valuesTemplateOutputPath) "values template path"
Assert-Equal $report.inputValuesTemplateMarkdownPath (Resolve-ProjectPath $valuesTemplateMarkdownOutputPath) "values template markdown path"
Assert-Equal $report.confirmationCount 1 "confirmation count"
Assert-Equal $report.inputFreeActionCount 1 "input-free action count"
Assert-Equal $report.inputRowCount 5 "input row count"
Assert-Equal $report.ambiguousInputRowCount 4 "ambiguous row count"
Assert-Equal $report.requiredSecretCount 3 "required secret count"
Assert-Equal $report.dispatchUnavailableReasonCount 2 "dispatch unavailable count"
Assert-True (@($report.requiredSecrets) -contains "OSMU_KUBECONFIG_BASE64") "expected kubeconfig secret"
Assert-True (@($report.requiredSecrets) -contains "OSMU_MINIO_ACCESS_KEY") "expected MinIO access key secret"
Assert-True (@($report.actionWorklist | Where-Object { $_.actionOrder -eq 1 -and $_.inputFree -eq $true -and $_.requiredSecretCount -eq 1 }).Count -eq 1) "expected action 1 input-free summary"
Assert-True (@($report.actionWorklist | Where-Object { $_.actionOrder -eq 2 -and $_.inputRowCount -eq 4 -and $_.ambiguousInputRowCount -eq 4 }).Count -eq 1) "expected action 2 input summary"
Assert-True (@($report.inputRows | Where-Object { $_.workflowInput -eq "review_started_at" -and $_.valueKey -eq "action-02.review_started_at" }).Count -eq 1) "expected review_started_at row"
Assert-True (@($report.inputRows | Where-Object { $_.workflowInput -eq "review_completed_at" }).Count -eq 1) "expected review_completed_at row"
Assert-True (@($report.inputRows | Where-Object { $_.workflowInput -eq "observed_p99_query_latency_ms" -and $_.placeholder -eq "<ms>" -and $_.valueKey -eq "action-02.observed_p99_query_latency_ms" }).Count -eq 1) "expected p99 ms row"
Assert-Contains $markdown "## Action Worklist" "markdown action worklist section"
Assert-Contains $markdown "## Input-Free Actions" "markdown input-free section"
Assert-Contains $markdown "storage-expansion-finalizer-ci.yml" "markdown storage workflow"
Assert-Contains $markdown "action-02.observed_p95_query_latency_ms" "markdown p95 value key"
Assert-Contains $markdown "observed_p95_query_latency_ms" "markdown p95 input"
Assert-Contains $markdown "GitHub CLI is not available" "markdown dispatch unavailable"
Assert-Contains $csv "manual-data-flow-query-retention-budget-evidence.yml" "csv workflow"
Assert-Contains $csv "action-02.observed_p99_query_latency_ms" "csv p99 value key"
Assert-Contains $csv "observed_p99_query_latency_ms" "csv p99 input"
Assert-Equal $valuesTemplate.formatVersion "osmu.operations-operator-input-values-template.v1" "values template formatVersion"
Assert-Equal $valuesTemplate.valueCount 5 "values template count"
Assert-Equal $valuesTemplate.values.PSObject.Properties["action-02.review_started_at"].Value "" "values template review start value"
Assert-True (@($valuesTemplate.entries | Where-Object { $_.valueKey -eq "action-02.observed_p99_query_latency_ms" }).Count -eq 1) "values template p99 entry"
Assert-Contains $valuesTemplateMarkdown "action-02.review_completed_at" "values markdown review completed key"

Write-Host "Operations operator input worksheet verified."
Write-Host "Worksheet report: $jsonOutputPath"
Write-Host "Input values template: $valuesTemplateOutputPath"
