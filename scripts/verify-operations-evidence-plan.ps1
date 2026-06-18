param(
    [string] $OutputDirectory = ".\.osmu-run\operations-evidence-plan-self-test"
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

$fixturePath = Join-Path $resolvedOutputDirectory "fixture-operations-readiness.json"
$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-operations-evidence-plan.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-operations-evidence-plan.md"

$fixture = [ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = "pending"
    passedCount = 1
    pendingCount = 3
    summary = "passed=1 pending=3"
    checks = @(
        [ordered]@{
            name = "Storage expansion finalizer live evidence"
            category = "storage-expansion"
            passed = $false
            status = "PENDING"
            detail = "report not found"
            evidencePath = ".osmu-run/latest-storage-expansion-finalize.json"
            requiredEvidence = "finalizer result=passed from target cluster"
            remediation = [ordered]@{
                command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -Namespace osmu -TenantName osmu-minio -ImpersonateRunner"
                workflow = ".github/workflows/storage-expansion-finalizer-ci.yml"
                workflowCommand = "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f impersonate_runner=true"
                note = "Run live against the target cluster with OSMU_KUBECONFIG_BASE64 configured."
            }
        },
        [ordered]@{
            name = "Kubernetes DR finalizer live evidence"
            category = "ha-dr"
            passed = $false
            status = "PENDING"
            detail = "result=planned"
            evidencePath = ".osmu-run/latest-kubernetes-dr-finalize.json"
            requiredEvidence = "finalizer result=ready from target cluster restore drill"
            remediation = [ordered]@{
                command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -BackupTimestamp <YYYYMMDDTHHMMSSZ> -ConfirmRestore -SubmitEvidence"
                workflow = ".github/workflows/kubernetes-dr-finalizer-ci.yml"
                workflowCommand = "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true -f submit_evidence=true"
                note = "Use a real backup timestamp and confirmed restore only after operator approval."
            }
        },
        [ordered]@{
            name = "Manual enterprise support sign-off"
            category = "commercial"
            passed = $false
            status = "PENDING"
            detail = "not approved"
            evidencePath = ".osmu-run/latest-commercial-signoff.json"
            requiredEvidence = "approved support and SLA sign-off"
        },
        [ordered]@{
            name = "IAM/RBAC finalizer report"
            category = "iam-rbac"
            passed = $true
            status = "PASS"
            detail = "result=passed"
            evidencePath = ".osmu-run/latest-iam-rbac-finalize.json"
            requiredEvidence = "IAM/RBAC finalizer result=passed"
        }
    )
    decisionRule = "fixture"
}
$fixture | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $fixturePath -Encoding UTF8

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-evidence-plan.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $fixturePath `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-plan.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Operations evidence plan JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Operations evidence plan markdown missing."

$reportText = Get-Content -Raw -LiteralPath $jsonOutputPath
$markdown = Get-Content -Raw -LiteralPath $markdownOutputPath
$report = $reportText | ConvertFrom-Json

Assert-True ($report.formatVersion -eq "osmu.operations-evidence-plan.v1") "Unexpected operations evidence plan formatVersion."
Assert-True ($report.result -eq "action-required") "Expected action-required result."
Assert-True ($report.pendingCount -eq 3) "Expected three pending checks."
Assert-True ($report.actionCount -eq 2) "Expected two planned remediation actions."
Assert-True ($report.unplannedCount -eq 1) "Expected one unplanned check."

$actions = @($report.actions)
Assert-True ($actions[0].name -eq "Storage expansion finalizer live evidence") "Expected storage expansion as first action."
Assert-True ($actions[0].workflowCommand -like "gh workflow run storage-expansion-finalizer-ci.yml*") "Expected storage workflow command."
Assert-True ($actions[0].requiresKubeconfigSecret) "Storage expansion action should require kubeconfig."
Assert-True ($actions[1].name -eq "Kubernetes DR finalizer live evidence") "Expected Kubernetes DR as second action."
Assert-True ($actions[1].requiresOperatorApproval) "Kubernetes DR action should require operator approval."
Assert-True ($actions[1].hasPlaceholders) "Kubernetes DR action should keep placeholder markers."
Assert-True (@($actions[1].operatorInputs) -contains "<YYYYMMDDTHHMMSSZ>") "Kubernetes DR action should list backup timestamp placeholder."

Assert-Contains $markdown "# OSMU Operations Evidence Plan" "Operations evidence plan markdown"
Assert-Contains $markdown "## Execution Order" "Operations evidence plan markdown"
Assert-Contains $markdown "gh workflow run kubernetes-dr-finalizer-ci.yml" "Operations evidence plan markdown"
Assert-Contains $markdown "Operator approval: required" "Operations evidence plan markdown"
Assert-Contains $markdown "## Unplanned Checks" "Operations evidence plan markdown"

Write-Host "Operations evidence plan verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
