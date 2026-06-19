param(
    [string] $OutputDirectory = ".\.osmu-run\operations-artifact-collection-plan-self-test"
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

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
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

$fixturePath = Join-Path $resolvedOutputDirectory "fixture-operations-evidence-plan-invocation.json"
$missingJsonOutputPath = Join-Path $resolvedOutputDirectory "missing-operations-artifact-collection-plan.json"
$missingMarkdownOutputPath = Join-Path $resolvedOutputDirectory "missing-operations-artifact-collection-plan.md"
$readyJsonOutputPath = Join-Path $resolvedOutputDirectory "ready-operations-artifact-collection-plan.json"
$readyMarkdownOutputPath = Join-Path $resolvedOutputDirectory "ready-operations-artifact-collection-plan.md"

$commands = @(
    "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true",
    "gh workflow run kubernetes-ha-dr-readiness-ci.yml -f run_live=true",
    "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true",
    "gh workflow run image-publish-sign-ci.yml -f version=v0.1.0-rc.1 -f publish=true",
    "gh workflow run container-security-ci.yml",
    "gh workflow run security-evidence-finalizer-ci.yml -f fail_if_not_passed=true",
    "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f require_oidc=true -f require_ldap=true",
    "gh workflow run kubernetes-operations-report-sync-ci.yml -f run_live=true -f apply=true"
)
$actions = New-Object System.Collections.Generic.List[object]
$order = 1
foreach ($command in $commands) {
    $actions.Add([ordered]@{
        order = $order
        name = "Action $order"
        category = "operations"
        actionType = "workflow"
        evidencePath = ".osmu-run/action-$order.json"
        commandMode = "Workflow"
        command = $command
        status = "planned"
        blockReasons = @()
        unresolvedPlaceholders = @()
        requiresOperatorApproval = $false
        requiresKubeconfigSecret = $false
    })
    $order++
}

$fixture = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = "planned"
    sourcePlan = ".osmu-run/latest-operations-evidence-plan.json"
    sourceSummary = "passed=36 pending=6"
    commandMode = "Workflow"
    executionMode = "plan-only"
    selectedActionCount = $actions.Count
    plannedCount = $actions.Count
    blockedCount = 0
    executedCount = 0
    failedCount = 0
    actions = @($actions | ForEach-Object { $_ })
}
$fixture | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $fixturePath -Encoding UTF8

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-artifact-collection-plan.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $fixturePath `
    -JsonOutputPath $missingJsonOutputPath `
    -MarkdownOutputPath $missingMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-artifact-collection-plan.ps1 missing-run-id check failed with exit code $LASTEXITCODE."
}

$missingReport = Get-Content -Raw -LiteralPath $missingJsonOutputPath | ConvertFrom-Json
$missingMarkdown = Get-Content -Raw -LiteralPath $missingMarkdownOutputPath
Assert-True ($missingReport.formatVersion -eq "osmu.operations-artifact-collection-plan.v1") "Unexpected collection plan formatVersion."
Assert-True ($missingReport.result -eq "action-required") "Expected action-required result without run ids."
Assert-True ($missingReport.artifactCount -eq 8) "Expected eight inferred artifacts."
Assert-True ($missingReport.requiredArtifactCount -eq 6) "Expected six required readiness/convergence artifacts."
Assert-True ($missingReport.missingRequiredArtifactCount -eq 6) "Expected six missing required artifacts."
Assert-Contains $missingMarkdown "storage-expansion-finalizer-<storage-expansion-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "enterprise-auth-smoke-<enterprise-auth-run-id>" "missing collection markdown"
Assert-Contains $missingMarkdown "operations-readiness-artifact-finalizer-ci.yml" "missing collection markdown"
Assert-Contains $missingMarkdown ".\.osmu-run\operations-readiness-artifacts\storage-expansion" "missing collection markdown"
Assert-True (-not $missingMarkdown.Contains("OrderedDictionary.downloadPath")) "Local import command should render concrete download paths."

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InvocationReportPath $fixturePath `
    -JsonOutputPath $readyJsonOutputPath `
    -MarkdownOutputPath $readyMarkdownOutputPath `
    -StorageExpansionRunId "101" `
    -HaDrReadinessRunId "102" `
    -KubernetesDrRunId "103" `
    -ImageSigningRunId "104" `
    -ContainerSecurityRunId "105" `
    -SecurityEvidenceRunId "106" `
    -EnterpriseAuthRunId "107" `
    -KubernetesOperationsReportSyncRunId "108" `
    -ImageSigningVersion "v0.1.0-rc.1" `
    -CommitSha "abc123" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-artifact-collection-plan.ps1 ready check failed with exit code $LASTEXITCODE."
}

$readyReport = Get-Content -Raw -LiteralPath $readyJsonOutputPath | ConvertFrom-Json
$readyMarkdown = Get-Content -Raw -LiteralPath $readyMarkdownOutputPath
Assert-True ($readyReport.result -eq "ready") "Expected ready result when all required run ids are supplied."
Assert-True ($readyReport.missingRequiredArtifactCount -eq 0) "Expected no missing required artifacts."
Assert-True ($readyReport.readyArtifactCount -eq 8) "Expected all artifacts to be concrete."
Assert-Contains $readyMarkdown "storage_expansion_run_id=101" "ready collection markdown"
Assert-Contains $readyMarkdown "security_evidence_run_id=106" "ready collection markdown"
Assert-Contains $readyMarkdown "enterprise_auth_run_id=107" "ready collection markdown"
Assert-Contains $readyMarkdown "kubernetes_operations_report_sync_run_id=108" "ready collection markdown"
Assert-Contains $readyMarkdown "osmu-image-signing-v0.1.0-rc.1-abc123" "ready collection markdown"
Assert-Contains $readyMarkdown "osmu-container-security-abc123" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 106 -n security-evidence-finalizer-106" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 107 -n enterprise-auth-smoke-107" "ready collection markdown"
Assert-Contains $readyMarkdown "gh run download 108 -n kubernetes-operations-report-sync-108" "ready collection markdown"

Write-Host "Operations artifact collection plan verified."
Write-Host "Missing report: $missingJsonOutputPath"
Write-Host "Ready report: $readyJsonOutputPath"
