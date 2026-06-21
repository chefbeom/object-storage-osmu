param(
    [string] $OutputDir = ".\.osmu-run\mariadb-query-plan-evidence-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Assert-Contains([string] $value, [string] $expected, [string] $label) {
    if (-not $value -or -not $value.Contains($expected)) {
        throw "$label must contain '$expected'."
    }
}

$resolvedOutputDir = Resolve-ProjectPath $OutputDir
$fixtureDir = Join-Path $resolvedOutputDir "explain-fixtures"
$badFixtureDir = Join-Path $resolvedOutputDir "bad-explain-fixtures"
New-Item -ItemType Directory -Force -Path $fixtureDir | Out-Null
New-Item -ItemType Directory -Force -Path $badFixtureDir | Out-Null

$planJsonPath = Join-Path $resolvedOutputDir "plan-only.json"
$planMarkdownPath = Join-Path $resolvedOutputDir "plan-only.md"
$passedJsonPath = Join-Path $resolvedOutputDir "passed.json"
$passedMarkdownPath = Join-Path $resolvedOutputDir "passed.md"
$failedJsonPath = Join-Path $resolvedOutputDir "failed.json"
$failedMarkdownPath = Join-Path $resolvedOutputDir "failed.md"

& (Join-Path $PSScriptRoot "write-mariadb-query-plan-evidence.ps1") `
    -EnvironmentName "self-test" `
    -TargetDatabase "osmu_test" `
    -Operator "query-plan-self-test" `
    -JsonOutputPath $planJsonPath `
    -MarkdownOutputPath $planMarkdownPath

$planReport = Get-Content -Raw -LiteralPath $planJsonPath | ConvertFrom-Json
$planMarkdown = Get-Content -Raw -LiteralPath $planMarkdownPath
Assert-True ($planReport.formatVersion -eq "osmu.mariadb-query-plan-evidence.v1") "Unexpected query plan evidence formatVersion."
Assert-True ($planReport.result -eq "plan-ready-execute-required") "Plan-only query plan evidence should require execution."
Assert-True ($planReport.checkCount -gt 0) "Plan-only query plan evidence should include checks."
Assert-Contains $planReport.scopePolicy "target-scale data" "scopePolicy"
Assert-Contains $planMarkdown "write-mariadb-query-plan-evidence.ps1 -Execute" "markdown execute command"

foreach ($check in $planReport.checks) {
    $fixture = [ordered]@{
        query_block = [ordered]@{
            table = [ordered]@{
                table_name = $check.table
                access_type = "range"
                key = $check.expectedIndex
                rows = 10
            }
        }
    }
    $fixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $fixtureDir "$($check.id).json") -Encoding UTF8
}

& (Join-Path $PSScriptRoot "write-mariadb-query-plan-evidence.ps1") `
    -EnvironmentName "self-test" `
    -TargetDatabase "osmu_test" `
    -Operator "query-plan-self-test" `
    -ExplainInputDir $fixtureDir `
    -JsonOutputPath $passedJsonPath `
    -MarkdownOutputPath $passedMarkdownPath `
    -FailIfNotPassed

$passedReport = Get-Content -Raw -LiteralPath $passedJsonPath | ConvertFrom-Json
Assert-True ($passedReport.result -eq "passed") "Fixture query plan evidence should pass."
Assert-True ($passedReport.failedCount -eq 0) "Fixture query plan evidence should have no failed checks."

foreach ($check in $planReport.checks) {
    $wrongIndex = if ($check.id -eq $planReport.checks[0].id) { "idx_wrong_index" } else { $check.expectedIndex }
    $fixture = [ordered]@{
        query_block = [ordered]@{
            table = [ordered]@{
                table_name = $check.table
                access_type = "ALL"
                key = $wrongIndex
                rows = 999999
            }
        }
    }
    $fixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $badFixtureDir "$($check.id).json") -Encoding UTF8
}

$failedAsExpected = $false
try {
    & (Join-Path $PSScriptRoot "write-mariadb-query-plan-evidence.ps1") `
        -EnvironmentName "self-test" `
        -TargetDatabase "osmu_test" `
        -Operator "query-plan-self-test" `
        -ExplainInputDir $badFixtureDir `
        -JsonOutputPath $failedJsonPath `
        -MarkdownOutputPath $failedMarkdownPath `
        -FailIfNotPassed
} catch {
    $failedAsExpected = $true
}
Assert-True $failedAsExpected "Bad fixture must fail query plan verification."

$failedReport = Get-Content -Raw -LiteralPath $failedJsonPath | ConvertFrom-Json
Assert-True ($failedReport.result -eq "failed") "Bad fixture report should be failed."
Assert-True ($failedReport.failedCount -gt 0) "Bad fixture report should include failed checks."

Write-Host "MariaDB query plan evidence verification passed: $passedJsonPath"
