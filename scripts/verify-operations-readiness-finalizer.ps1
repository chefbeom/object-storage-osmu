param(
    [string] $JsonOutputPath = ".\.osmu-run\operations-readiness-finalizer-self-test\latest-operations-readiness-finalize.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\operations-readiness-finalizer-self-test\latest-operations-readiness-finalize.md",
    [string] $SecretProbe = "do-not-write-this-secret"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}
function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-NotContains([string] $text, [string] $unexpected, [string] $label) {
    if ($text.Contains($unexpected)) {
        throw "$label must not contain text: $unexpected"
    }
}

$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$dataFlowStoragePlanPath = Resolve-ProjectPath ".\.osmu-run\operations-readiness-finalizer-self-test\custom-data-flow-storage-plan.json"
$dataFlowStorageTransitionRunbookPath = Resolve-ProjectPath ".\.osmu-run\operations-readiness-finalizer-self-test\custom-data-flow-storage-transition-runbook-evidence.json"
$dataFlowQueryRetentionBudgetPath = Resolve-ProjectPath ".\.osmu-run\operations-readiness-finalizer-self-test\custom-data-flow-query-retention-budget-evidence.json"
$operationsReadinessPath = Resolve-ProjectPath ".\.osmu-run\operations-readiness-finalizer-self-test\custom-operations-readiness.json"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $operationsReadinessPath) | Out-Null
@{
    formatVersion = "osmu.operations-readiness.v1"
    result = "pending"
    summary = "passed=2 pending=3"
    passedCount = 2
    pendingCount = 3
    checks = @(
        @{
            category = "release"
            name = "Release report available"
            passed = $true
            detail = "report parsed"
            path = ".osmu-run/latest-release.json"
            requiredEvidence = "release report"
        },
        @{
            category = "storage-backend"
            name = "Storage backend telemetry target evidence"
            passed = $false
            detail = "report not found"
            path = ".osmu-run/latest-storage-backend-telemetry.json"
            requiredEvidence = "target MinIO telemetry"
        },
        @{
            category = "chargeback-closeout"
            name = "Chargeback closeout target evidence"
            passed = $false
            detail = "result=failed; rejected=self-test-target-evidence markers=pilot-prod-self-test,customer-cluster-a,ops-self-test"
            path = ".osmu-run/latest-chargeback-closeout-evidence.json"
            requiredEvidence = "target billing period closeout"
        },
        @{
            category = "enterprise-auth"
            name = "Enterprise auth JIT rollback target evidence"
            passed = $false
            detail = "result=failed; rejected=self-test-target-evidence markers=pilot-prod-self-test,customer-cluster-a"
            path = ".osmu-run/latest-enterprise-auth-jit-rollback-evidence.json"
            requiredEvidence = "target admin-approved JIT rollback"
        }
    )
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $operationsReadinessPath -Encoding UTF8
$scriptPath = Resolve-ProjectPath ".\scripts\finalize-operations-readiness.ps1"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -PlanOnly `
    -RunStorageExpansionFinalizer `
    -RunHaDrReadiness `
    -RunKubernetesDrFinalizer `
    -RunIamRbacFinalizer `
    -RunIamKubernetesLiveAuth `
    -RunSecurityEvidenceFinalizer `
    -PowerShellCommand "pwsh" `
    -RunStorageBackendDryRunRunner `
    -StorageExpansionRequestId 1 `
    -AdminPassword $SecretProbe `
    -ServerDryRunOnly `
    -OperationsReadinessJsonPath $operationsReadinessPath `
    -DataFlowStoragePlanPath $dataFlowStoragePlanPath `
    -DataFlowQueryRetentionBudgetEvidencePath $dataFlowQueryRetentionBudgetPath `
    -DataFlowStorageTransitionRunbookEvidencePath $dataFlowStorageTransitionRunbookPath `
    -ReportPath $resolvedJsonOutputPath `
    -SummaryPath $resolvedMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "finalize-operations-readiness.ps1 plan check failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $resolvedJsonOutputPath)) {
    throw "Operations readiness finalizer JSON missing: $resolvedJsonOutputPath"
}
if (-not (Test-Path -LiteralPath $resolvedMarkdownOutputPath)) {
    throw "Operations readiness finalizer markdown missing: $resolvedMarkdownOutputPath"
}

$reportText = Read-Utf8Text $resolvedJsonOutputPath
$markdown = Read-Utf8Text $resolvedMarkdownOutputPath
$report = $reportText | ConvertFrom-Json

if ($report.formatVersion -ne "osmu.operations-readiness-finalize.v1") {
    throw "Unexpected operations readiness finalizer formatVersion: $($report.formatVersion)"
}
if ($report.result -ne "planned") {
    throw "Operations readiness finalizer plan report must be planned: $($report.result)"
}
if ($report.commands.Count -lt 6) {
    throw "Operations readiness finalizer plan must include selected evidence steps and readiness report."
}

Assert-Contains $reportText "Storage expansion finalizer" "Operations readiness finalizer JSON"
Assert-Contains $reportText "Kubernetes HA/DR readiness" "Operations readiness finalizer JSON"
Assert-Contains $reportText "Kubernetes DR finalizer" "Operations readiness finalizer JSON"
Assert-Contains $reportText "IAM/RBAC finalizer" "Operations readiness finalizer JSON"
Assert-Contains $reportText "Security evidence finalizer" "Operations readiness finalizer JSON"
Assert-Contains $reportText "Operations readiness report" "Operations readiness finalizer JSON"
Assert-Contains $reportText "DataFlowStoragePlanPath" "Operations readiness finalizer JSON"
Assert-Contains $reportText "custom-data-flow-storage-plan.json" "Operations readiness finalizer JSON"
Assert-Contains $reportText "DataFlowQueryRetentionBudgetEvidencePath" "Operations readiness finalizer JSON"
Assert-Contains $reportText "custom-data-flow-query-retention-budget-evidence.json" "Operations readiness finalizer JSON"
Assert-Contains $reportText "DataFlowStorageTransitionRunbookEvidencePath" "Operations readiness finalizer JSON"
Assert-Contains $reportText "custom-data-flow-storage-transition-runbook-evidence.json" "Operations readiness finalizer JSON"
if ($report.paths.dataFlowStoragePlan -ne $dataFlowStoragePlanPath) {
    throw "Operations readiness finalizer must preserve DataFlowStoragePlanPath: $($report.paths.dataFlowStoragePlan)"
}
if ($report.paths.dataFlowQueryRetentionBudgetEvidence -ne $dataFlowQueryRetentionBudgetPath) {
    throw "Operations readiness finalizer must preserve DataFlowQueryRetentionBudgetEvidencePath: $($report.paths.dataFlowQueryRetentionBudgetEvidence)"
}
if ($report.paths.dataFlowStorageTransitionRunbookEvidence -ne $dataFlowStorageTransitionRunbookPath) {
    throw "Operations readiness finalizer must preserve DataFlowStorageTransitionRunbookEvidencePath: $($report.paths.dataFlowStorageTransitionRunbookEvidence)"
}
if ($report.paths.operationsReadinessJson -ne $operationsReadinessPath) {
    throw "Operations readiness finalizer must preserve OperationsReadinessJsonPath: $($report.paths.operationsReadinessJson)"
}
if ($report.readinessPendingCount -ne 3) {
    throw "Operations readiness finalizer must summarize pending checks: $($report.readinessPendingCount)"
}
if ($report.readinessRejectedSelfTestTargetEvidenceCount -ne 2) {
    throw "Operations readiness finalizer must summarize rejected self-test target evidence: $($report.readinessRejectedSelfTestTargetEvidenceCount)"
}
Assert-Contains $reportText "Chargeback closeout target evidence" "Operations readiness finalizer JSON"
Assert-Contains $reportText "Enterprise auth JIT rollback target evidence" "Operations readiness finalizer JSON"
Assert-Contains $reportText "rejected=self-test-target-evidence" "Operations readiness finalizer JSON"
if ($report.powerShellCommand -ne "pwsh") {
    throw "Operations readiness finalizer must preserve PowerShellCommand override: $($report.powerShellCommand)"
}
Assert-Contains $markdown "pwsh -NoProfile -ExecutionPolicy Bypass" "Operations readiness finalizer markdown"
Assert-Contains $markdown "custom-data-flow-storage-plan.json" "Operations readiness finalizer markdown"
Assert-Contains $markdown "custom-data-flow-query-retention-budget-evidence.json" "Operations readiness finalizer markdown"
Assert-Contains $markdown "custom-data-flow-storage-transition-runbook-evidence.json" "Operations readiness finalizer markdown"
Assert-NotContains $reportText $SecretProbe "Operations readiness finalizer JSON"
Assert-NotContains $markdown $SecretProbe "Operations readiness finalizer markdown"
Assert-Contains $markdown "# OSMU Operations Readiness Finalize" "Operations readiness finalizer markdown"
Assert-Contains $markdown "<secret>" "Operations readiness finalizer markdown"
Assert-Contains $markdown "Plan only" "Operations readiness finalizer markdown"
Assert-Contains $markdown "Operations readiness pending checks: 3" "Operations readiness finalizer markdown"
Assert-Contains $markdown "Rejected self-test target evidence: 2" "Operations readiness finalizer markdown"
Assert-Contains $markdown "## Pending Readiness Checks" "Operations readiness finalizer markdown"
Assert-Contains $markdown "## Rejected Self-Test Target Evidence" "Operations readiness finalizer markdown"
Assert-Contains $markdown "Chargeback closeout target evidence" "Operations readiness finalizer markdown"
Assert-Contains $markdown "Enterprise auth JIT rollback target evidence" "Operations readiness finalizer markdown"

Write-Host "Operations readiness finalizer verified."
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"
