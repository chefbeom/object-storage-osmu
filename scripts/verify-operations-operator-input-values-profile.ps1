param(
    [string] $OutputDirectory = ".\.osmu-run\operations-operator-input-values-profile-self-test"
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

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-operator-input-values-profile.ps1"
$worksheetCsvPath = Join-Path $resolvedOutputDirectory "worksheet.csv"
$overridePath = Join-Path $resolvedOutputDirectory "overrides.json"
$profileCsvPath = Join-Path $resolvedOutputDirectory "profile.csv"
$jsonOutputPath = Join-Path $resolvedOutputDirectory "profile.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "profile.md"

@(
    [pscustomobject][ordered]@{ actionOrder = 8; actionName = "Data-flow query/retention budget target evidence"; category = "data-flow"; workflow = "manual-data-flow-query-retention-budget-evidence.yml"; workflowInput = "environment_name"; valueKey = "action-08.environment_name"; placeholder = "<env>"; parameter = ""; valueTemplate = "<env>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Target environment name."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 8; actionName = "Data-flow query/retention budget target evidence"; category = "data-flow"; workflow = "manual-data-flow-query-retention-budget-evidence.yml"; workflowInput = "target_cluster"; valueKey = "action-08.target_cluster"; placeholder = "<cluster>"; parameter = ""; valueTemplate = "<cluster>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Target cluster identifier."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 8; actionName = "Data-flow query/retention budget target evidence"; category = "data-flow"; workflow = "manual-data-flow-query-retention-budget-evidence.yml"; workflowInput = "operator"; valueKey = "action-08.operator"; placeholder = "<operator>"; parameter = ""; valueTemplate = "<operator>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Operator."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 8; actionName = "Data-flow query/retention budget target evidence"; category = "data-flow"; workflow = "manual-data-flow-query-retention-budget-evidence.yml"; workflowInput = "evidence_ref"; valueKey = "action-08.evidence_ref"; placeholder = "<run-ref>"; parameter = ""; valueTemplate = "<run-ref>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "External reference."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 9; actionName = "Data-flow storage transition runbook target evidence"; category = "data-flow"; workflow = "manual-data-flow-storage-transition-runbook-evidence.yml"; workflowInput = "change_approval_ref"; valueKey = "action-09.change_approval_ref"; placeholder = "<change-id>"; parameter = ""; valueTemplate = "<change-id>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Change approval."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 9; actionName = "Data-flow storage transition runbook target evidence"; category = "data-flow"; workflow = "manual-data-flow-storage-transition-runbook-evidence.yml"; workflowInput = "review_started_at"; valueKey = "action-09.review_started_at"; placeholder = "<iso-time>"; parameter = ""; valueTemplate = "<iso-time>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Start."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 9; actionName = "Data-flow storage transition runbook target evidence"; category = "data-flow"; workflow = "manual-data-flow-storage-transition-runbook-evidence.yml"; workflowInput = "review_completed_at"; valueKey = "action-09.review_completed_at"; placeholder = "<iso-time>"; parameter = ""; valueTemplate = "<iso-time>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Complete."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 13; actionName = "Commercial approval target evidence"; category = "commercial"; workflow = "manual-commercial-approval-evidence.yml"; workflowInput = "approved_at"; valueKey = "action-13.approved_at"; placeholder = "<iso-time>"; parameter = ""; valueTemplate = "<iso-time>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Approved at."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 13; actionName = "Commercial approval target evidence"; category = "commercial"; workflow = "manual-commercial-approval-evidence.yml"; workflowInput = "pricing_approval_ref"; valueKey = "action-13.pricing_approval_ref"; placeholder = "<ref>"; parameter = ""; valueTemplate = "<ref>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Pricing approval."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 14; actionName = "Chargeback closeout target evidence"; category = "commercial"; workflow = "manual-chargeback-closeout-evidence.yml"; workflowInput = "billing_period"; valueKey = "action-14.billing_period"; placeholder = "<yyyy-mm>"; parameter = ""; valueTemplate = "<yyyy-mm>"; value = ""; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Billing period."; note = "" }
    [pscustomobject][ordered]@{ actionOrder = 17; actionName = "Operations handoff package target evidence"; category = "operations"; workflow = "manual-operations-handoff-package.yml"; workflowInput = "known_gaps_ref"; valueKey = "action-17.known_gaps_ref"; placeholder = "<ref>"; parameter = ""; valueTemplate = "<ref>"; value = "existing-known-gap-ref"; occurrenceCount = 1; ambiguousRepeatedPlaceholder = $false; suggestedSource = "Known gaps."; note = "" }
) | Export-Csv -LiteralPath $worksheetCsvPath -NoTypeInformation -Encoding UTF8

@{
    "action-13.pricing_approval_ref" = "pricing-approval-123"
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $overridePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -WorksheetCsvPath $worksheetCsvPath `
    -CsvOutputPath $profileCsvPath `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -ValueOverridesJsonPath $overridePath `
    -EnvironmentName "pilot-prod" `
    -TargetCluster "cluster-a" `
    -Operator "ops-user" `
    -RunRef "run-ref-123" `
    -ChangeApprovalRef "CHG-123" `
    -StartTime "2026-07-03T00:00:00Z" `
    -CompletedTime "2026-07-03T00:30:00Z" `
    -ApprovedAt "2026-07-03T01:00:00Z" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-operator-input-values-profile.ps1 fixture failed with exit code $LASTEXITCODE."
}

$report = Read-Utf8Text $jsonOutputPath | ConvertFrom-Json
$markdown = Read-Utf8Text $markdownOutputPath
$profileRows = @(Import-Csv -LiteralPath $profileCsvPath -Encoding UTF8)

Assert-Equal $report.formatVersion "osmu.operations-operator-input-values-profile.v1" "formatVersion"
Assert-Equal $report.result "action-required" "result"
Assert-Equal $report.rowCount 11 "row count"
Assert-Equal $report.filledValueCount 10 "filled count"
Assert-Equal $report.blankValueCount 1 "blank count"
Assert-Equal $report.preservedValueCount 1 "preserved count"
Assert-Equal $report.profileFillCount 8 "profile fill count"
Assert-Equal $report.overrideFillCount 1 "override fill count"
Assert-Contains $report.valuesCheckCommand $profileCsvPath "values check command profile path"
Assert-True (@($profileRows | Where-Object { $_.valueKey -eq "action-08.environment_name" -and $_.value -eq "pilot-prod" }).Count -eq 1) "expected environment fill"
Assert-True (@($profileRows | Where-Object { $_.valueKey -eq "action-09.review_started_at" -and $_.value -eq "2026-07-03T00:00:00Z" }).Count -eq 1) "expected started_at fill"
Assert-True (@($profileRows | Where-Object { $_.valueKey -eq "action-13.pricing_approval_ref" -and $_.value -eq "pricing-approval-123" }).Count -eq 1) "expected override fill"
Assert-True (@($profileRows | Where-Object { $_.valueKey -eq "action-17.known_gaps_ref" -and $_.value -eq "existing-known-gap-ref" }).Count -eq 1) "expected preserved value"
Assert-True (@($profileRows | Where-Object { $_.valueKey -eq "action-14.billing_period" -and $_.value -eq "" }).Count -eq 1) "expected blank billing period"
Assert-Contains $markdown "Profile-filled values: 8" "markdown profile count"
Assert-Contains $markdown "Override-filled values: 1" "markdown override count"
Assert-Contains $markdown "Values check command:" "markdown values check command"

$handoffPackagePath = Join-Path $resolvedOutputDirectory "handoff-package.json"
$packageProfileCsvPath = Join-Path $resolvedOutputDirectory "package-profile.csv"
$packageJsonOutputPath = Join-Path $resolvedOutputDirectory "package-profile.json"
$packageMarkdownOutputPath = Join-Path $resolvedOutputDirectory "package-profile.md"
[ordered]@{
    formatVersion = "osmu.operations-handoff-package.v1"
    environmentName = "package-prod"
    targetCluster = "package-cluster"
    operatorName = "package-operator"
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $handoffPackagePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -WorksheetCsvPath $worksheetCsvPath `
    -CsvOutputPath $packageProfileCsvPath `
    -JsonOutputPath $packageJsonOutputPath `
    -MarkdownOutputPath $packageMarkdownOutputPath `
    -HandoffPackagePath $handoffPackagePath `
    -UseHandoffPackageDefaults | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-operator-input-values-profile.ps1 package defaults fixture failed with exit code $LASTEXITCODE."
}

$packageReport = Read-Utf8Text $packageJsonOutputPath | ConvertFrom-Json
$packageMarkdown = Read-Utf8Text $packageMarkdownOutputPath
$packageRows = @(Import-Csv -LiteralPath $packageProfileCsvPath -Encoding UTF8)
Assert-Equal $packageReport.handoffPackageDefaultsUsed $true "package defaults used"
Assert-Equal $packageReport.handoffPackageDefaultValueCount 3 "package default value count"
Assert-Equal $packageReport.profileFillCount 3 "package profile fill count"
Assert-Equal $packageReport.filledValueCount 4 "package filled count"
Assert-Equal $packageReport.blankValueCount 7 "package blank count"
Assert-True (@($packageRows | Where-Object { $_.valueKey -eq "action-08.environment_name" -and $_.value -eq "package-prod" }).Count -eq 1) "expected package environment fill"
Assert-True (@($packageRows | Where-Object { $_.valueKey -eq "action-08.target_cluster" -and $_.value -eq "package-cluster" }).Count -eq 1) "expected package cluster fill"
Assert-True (@($packageRows | Where-Object { $_.valueKey -eq "action-08.operator" -and $_.value -eq "package-operator" }).Count -eq 1) "expected package operator fill"
Assert-True (@($packageRows | Where-Object { $_.valueKey -eq "action-08.evidence_ref" -and $_.value -eq "" }).Count -eq 1) "expected package defaults not to fill evidence ref"
Assert-Contains $packageMarkdown "Handoff package defaults used: True" "package markdown defaults used"
Assert-Contains $packageMarkdown "Handoff package default values: 3" "package markdown default count"

$selfTestHandoffPackagePath = Join-Path $resolvedOutputDirectory "self-test-handoff-package.json"
$selfTestProfileCsvPath = Join-Path $resolvedOutputDirectory "self-test-package-profile.csv"
$selfTestJsonOutputPath = Join-Path $resolvedOutputDirectory "self-test-package-profile.json"
$selfTestMarkdownOutputPath = Join-Path $resolvedOutputDirectory "self-test-package-profile.md"
[ordered]@{
    formatVersion = "osmu.operations-handoff-package.v1"
    environmentName = "pilot-prod-self-test"
    targetCluster = "customer-cluster-a"
    operatorName = "ops-self-test"
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $selfTestHandoffPackagePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -WorksheetCsvPath $worksheetCsvPath `
    -CsvOutputPath $selfTestProfileCsvPath `
    -JsonOutputPath $selfTestJsonOutputPath `
    -MarkdownOutputPath $selfTestMarkdownOutputPath `
    -HandoffPackagePath $selfTestHandoffPackagePath `
    -UseHandoffPackageDefaults | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-operator-input-values-profile.ps1 self-test package defaults fixture failed with exit code $LASTEXITCODE."
}

$selfTestReport = Read-Utf8Text $selfTestJsonOutputPath | ConvertFrom-Json
$selfTestMarkdown = Read-Utf8Text $selfTestMarkdownOutputPath
$selfTestRows = @(Import-Csv -LiteralPath $selfTestProfileCsvPath -Encoding UTF8)
Assert-Equal $selfTestReport.handoffPackageDefaultsUsed $false "self-test package defaults not used"
Assert-Equal $selfTestReport.handoffPackageDefaultsSkipped $true "self-test package defaults skipped"
Assert-Equal $selfTestReport.handoffPackageDefaultsSkipReason "handoff package identity contains self-test marker" "self-test package defaults skip reason"
Assert-Equal $selfTestReport.handoffPackageDefaultValueCount 0 "self-test package default value count"
Assert-Equal $selfTestReport.profileFillCount 0 "self-test package profile fill count"
Assert-Equal $selfTestReport.filledValueCount 1 "self-test package filled count"
Assert-Equal $selfTestReport.blankValueCount 10 "self-test package blank count"
Assert-True (@($selfTestRows | Where-Object { $_.valueKey -eq "action-08.environment_name" -and $_.value -eq "" }).Count -eq 1) "expected self-test package environment to remain blank"
Assert-Contains $selfTestMarkdown "Handoff package defaults skipped: True" "self-test package markdown defaults skipped"
Assert-Contains $selfTestMarkdown "Handoff package defaults skip reason: handoff package identity contains self-test marker" "self-test package markdown skip reason"

Write-Host "Operations operator input values profile package defaults verified."

Write-Host "Operations operator input values profile verified."
Write-Host "Profile report: $jsonOutputPath"
Write-Host "Profile CSV: $profileCsvPath"
