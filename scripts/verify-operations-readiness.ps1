param(
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-readiness.md"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-CheckExists([object] $report, [string] $name, [string] $category) {
    $match = @($report.checks | Where-Object { $_.name -eq $name -and $_.category -eq $category })
    if ($match.Count -ne 1) {
        throw "Operations readiness report must contain one check named '$name' in category '$category'."
    }
}

function Assert-CheckRemediation(
    [object] $report,
    [string] $name,
    [string] $commandFragment,
    [string] $workflowPath,
    [string] $workflowCommandFragment
) {
    $match = @($report.checks | Where-Object { $_.name -eq $name })
    if ($match.Count -ne 1) {
        throw "Operations readiness report must contain one check named '$name'."
    }
    $remediation = $match[0].remediation
    if ($null -eq $remediation) {
        throw "Operations readiness check '$name' must include remediation metadata."
    }
    if (-not ([string] $remediation.command).Contains($commandFragment)) {
        throw "Operations readiness check '$name' remediation command must contain '$commandFragment'. Actual: $($remediation.command)"
    }
    if ($remediation.workflow -ne $workflowPath) {
        throw "Operations readiness check '$name' remediation workflow must be '$workflowPath'. Actual: $($remediation.workflow)"
    }
    if (-not ([string] $remediation.workflowCommand).Contains($workflowCommandFragment)) {
        throw "Operations readiness check '$name' remediation workflow command must contain '$workflowCommandFragment'. Actual: $($remediation.workflowCommand)"
    }
}

$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-readiness.ps1"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -JsonOutputPath $resolvedJsonOutputPath -MarkdownOutputPath $resolvedMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $resolvedJsonOutputPath)) {
    throw "Operations readiness JSON missing: $resolvedJsonOutputPath"
}
if (-not (Test-Path -LiteralPath $resolvedMarkdownOutputPath)) {
    throw "Operations readiness markdown missing: $resolvedMarkdownOutputPath"
}

$report = Get-Content -Raw -LiteralPath $resolvedJsonOutputPath | ConvertFrom-Json
$markdown = Get-Content -Raw -LiteralPath $resolvedMarkdownOutputPath

if ($report.formatVersion -ne "osmu.operations-readiness.v1") {
    throw "Unexpected operations readiness formatVersion: $($report.formatVersion)"
}
if ($report.result -notin @("ready", "pending")) {
    throw "Unexpected operations readiness result: $($report.result)"
}
if ($report.checks.Count -lt 20) {
    throw "Operations readiness report has too few checks: $($report.checks.Count)"
}

Assert-CheckExists $report "Release report available" "release"
Assert-CheckExists $report "Kubernetes manifest draft" "static-infra"
Assert-CheckExists $report "Helm chart draft" "static-infra"
Assert-CheckExists $report "NetworkPolicy draft" "security-hardening"
Assert-CheckExists $report "Container hardening draft" "security-hardening"
Assert-CheckExists $report "TLS ingress draft" "security-hardening"
Assert-CheckExists $report "Secret rotation policy draft" "security-hardening"
Assert-CheckExists $report "IAM/RBAC matrix verifier" "iam-rbac"
Assert-CheckExists $report "IAM/RBAC finalizer" "iam-rbac"
Assert-CheckExists $report "IAM/RBAC finalizer self-test" "iam-rbac"
Assert-CheckExists $report "IAM/RBAC finalizer workflow" "iam-rbac"
Assert-CheckExists $report "Kubernetes RBAC matrix verifier" "kubernetes-rbac"
Assert-CheckExists $report "Storage expansion finalizer workflow" "automation"
Assert-CheckExists $report "Kubernetes HA/DR readiness workflow" "ha-dr"
Assert-CheckExists $report "Kubernetes DR finalizer workflow" "automation"
Assert-CheckExists $report "Operations readiness finalizer workflow" "automation"
Assert-CheckExists $report "Operations readiness finalizer" "automation"
Assert-CheckExists $report "Operations readiness finalizer self-test" "automation"
Assert-CheckExists $report "Operations readiness artifact importer" "automation"
Assert-CheckExists $report "Operations readiness artifact importer self-test" "automation"
Assert-CheckExists $report "Operations readiness artifact finalizer workflow" "automation"
Assert-CheckExists $report "Container security evidence writer" "security-hardening"
Assert-CheckExists $report "Image signing evidence writer" "security-hardening"
Assert-CheckExists $report "Security evidence writer self-test" "security-hardening"
Assert-CheckExists $report "Secret rotation evidence writer" "security-hardening"
Assert-CheckExists $report "Secret rotation evidence writer self-test" "security-hardening"
Assert-CheckExists $report "Commercial integration evidence writer" "commercial-integration"
Assert-CheckExists $report "Commercial integration evidence writer self-test" "commercial-integration"
Assert-CheckExists $report "Commercial approval evidence writer" "commercial-approval"
Assert-CheckExists $report "Commercial approval evidence writer self-test" "commercial-approval"
Assert-CheckExists $report "Operations handoff package writer" "operations-handoff-package"
Assert-CheckExists $report "Operations handoff package writer self-test" "operations-handoff-package"
Assert-CheckExists $report "Security evidence finalizer" "security-hardening"
Assert-CheckExists $report "Security evidence finalizer self-test" "security-hardening"
Assert-CheckExists $report "Security evidence finalizer workflow" "security-hardening"
Assert-CheckExists $report "Enterprise auth smoke workflow" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth smoke evidence helper" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth smoke evidence helper self-test" "enterprise-auth"
Assert-CheckExists $report "Storage expansion finalizer live evidence" "storage-expansion"
Assert-CheckExists $report "Kubernetes HA/DR readiness live evidence" "ha-dr"
Assert-CheckExists $report "Kubernetes DR finalizer live evidence" "ha-dr"
Assert-CheckExists $report "IAM/RBAC finalizer report" "iam-rbac"
Assert-CheckExists $report "Security evidence finalizer report" "security-hardening"
Assert-CheckExists $report "Signed image evidence" "security-hardening"
Assert-CheckExists $report "Container scan/SBOM evidence" "security-hardening"
Assert-CheckExists $report "Secret/certificate rotation target evidence" "security-hardening"
Assert-CheckExists $report "Commercial integration target evidence" "commercial-integration"
Assert-CheckExists $report "Commercial approval target evidence" "commercial-approval"
Assert-CheckExists $report "Enterprise auth target smoke evidence" "enterprise-auth"
Assert-CheckExists $report "Operations handoff package target evidence" "operations-handoff-package"

Assert-CheckRemediation $report "Storage expansion finalizer live evidence" "finalize-storage-expansion.ps1" ".github/workflows/storage-expansion-finalizer-ci.yml" "gh workflow run storage-expansion-finalizer-ci.yml"
Assert-CheckRemediation $report "Kubernetes HA/DR readiness live evidence" "verify-kubernetes-ha-dr-readiness.ps1" ".github/workflows/kubernetes-ha-dr-readiness-ci.yml" "gh workflow run kubernetes-ha-dr-readiness-ci.yml"
Assert-CheckRemediation $report "Kubernetes DR finalizer live evidence" "finalize-kubernetes-dr-drill.ps1" ".github/workflows/kubernetes-dr-finalizer-ci.yml" "gh workflow run kubernetes-dr-finalizer-ci.yml"
Assert-CheckRemediation $report "Security evidence finalizer report" "finalize-security-evidence.ps1" ".github/workflows/security-evidence-finalizer-ci.yml" "gh workflow run security-evidence-finalizer-ci.yml"
Assert-CheckRemediation $report "Signed image evidence" "image-publish-sign-ci.yml" ".github/workflows/image-publish-sign-ci.yml" "gh workflow run image-publish-sign-ci.yml"
Assert-CheckRemediation $report "Container scan/SBOM evidence" "container-security-ci.yml" ".github/workflows/container-security-ci.yml" "gh workflow run container-security-ci.yml"
$secretRotationCheck = @($report.checks | Where-Object { $_.name -eq "Secret/certificate rotation target evidence" })
if ($secretRotationCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Secret/certificate rotation target evidence check."
}
if (-not ([string] $secretRotationCheck[0].remediation.command).Contains("write-secret-rotation-evidence.ps1")) {
    throw "Secret/certificate rotation target evidence remediation must point to write-secret-rotation-evidence.ps1."
}
if (-not ([string] $secretRotationCheck[0].requiredEvidence).Contains("target environment")) {
    throw "Secret/certificate rotation target evidence must require target environment evidence."
}
$commercialIntegrationCheck = @($report.checks | Where-Object { $_.name -eq "Commercial integration target evidence" })
if ($commercialIntegrationCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Commercial integration target evidence check."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.command).Contains("write-commercial-integration-evidence.ps1")) {
    throw "Commercial integration target evidence remediation must point to write-commercial-integration-evidence.ps1."
}
if (-not ([string] $commercialIntegrationCheck[0].requiredEvidence).Contains("target environment")) {
    throw "Commercial integration target evidence must require target environment evidence."
}
$commercialApprovalCheck = @($report.checks | Where-Object { $_.name -eq "Commercial approval target evidence" })
if ($commercialApprovalCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Commercial approval target evidence check."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.command).Contains("write-commercial-approval-evidence.ps1")) {
    throw "Commercial approval target evidence remediation must point to write-commercial-approval-evidence.ps1."
}
if (-not ([string] $commercialApprovalCheck[0].requiredEvidence).Contains("final pricing") -or -not ([string] $commercialApprovalCheck[0].requiredEvidence).Contains("legal approval")) {
    throw "Commercial approval target evidence must require final pricing and legal approval evidence."
}
$enterpriseAuthCheck = @($report.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($enterpriseAuthCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Enterprise auth target smoke evidence check."
}
if (-not ([string] $enterpriseAuthCheck[0].remediation.command).Contains("write-enterprise-auth-smoke-plan.ps1")) {
    throw "Enterprise auth target smoke evidence remediation must point to write-enterprise-auth-smoke-plan.ps1."
}
if ($enterpriseAuthCheck[0].remediation.workflow -ne ".github/workflows/enterprise-auth-smoke-ci.yml") {
    throw "Enterprise auth target smoke evidence remediation workflow must point to enterprise-auth-smoke-ci.yml."
}
if (-not ([string] $enterpriseAuthCheck[0].remediation.workflowCommand).Contains("gh workflow run enterprise-auth-smoke-ci.yml")) {
    throw "Enterprise auth target smoke evidence remediation workflow command must dispatch enterprise-auth-smoke-ci.yml."
}
if (-not ([string] $enterpriseAuthCheck[0].requiredEvidence).Contains("target IdP/directory") -or -not ([string] $enterpriseAuthCheck[0].requiredEvidence).Contains("scope-out")) {
    throw "Enterprise auth target smoke evidence must require target IdP/directory evidence or scope-out evidence."
}
$operationsHandoffPackageCheck = @($report.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($operationsHandoffPackageCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Operations handoff package target evidence check."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("write-operations-handoff-package.ps1")) {
    throw "Operations handoff package target evidence remediation must point to write-operations-handoff-package.ps1."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("-CommercialApprovalEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include CommercialApprovalEvidenceRef."
}
if (-not ([string] $operationsHandoffPackageCheck[0].requiredEvidence).Contains("target environment")) {
    throw "Operations handoff package target evidence must require target environment evidence."
}

Assert-Contains $markdown "# OSMU Operations Readiness" "Operations readiness markdown"
Assert-Contains $markdown "Production/B2B operations readiness" "Operations readiness markdown"
Assert-Contains $markdown "Storage expansion finalizer live evidence" "Operations readiness markdown"
Assert-Contains $markdown "Kubernetes DR finalizer live evidence" "Operations readiness markdown"
Assert-Contains $markdown "Security evidence finalizer report" "Operations readiness markdown"
Assert-Contains $markdown "Secret/certificate rotation target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Commercial integration target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Commercial approval target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Enterprise auth target smoke evidence" "Operations readiness markdown"
Assert-Contains $markdown "Operations handoff package target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Required Next Evidence" "Operations readiness markdown"
Assert-Contains $markdown "Remediation command" "Operations readiness markdown"
Assert-Contains $markdown "Workflow" "Operations readiness markdown"
Assert-Contains $markdown "Workflow command" "Operations readiness markdown"

$scopeOutFixtureDirectory = Resolve-ProjectPath ".\.osmu-run\operations-readiness-enterprise-auth-scope-out-self-test"
New-Item -ItemType Directory -Force -Path $scopeOutFixtureDirectory | Out-Null
$scopeOutEvidencePath = Join-Path $scopeOutFixtureDirectory "latest-enterprise-auth-smoke.json"
$scopeOutJsonOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness.json"
$scopeOutMarkdownOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness.md"
@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "scope-out"
    scopeOut = @{
        confirmed = $true
        reference = "pilot-contract-enterprise-auth-deferred-20260620"
        reason = "Pilot phase uses local password login."
        accepted = $true
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $scopeOutEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnterpriseAuthSmokeEvidencePath $scopeOutEvidencePath `
    -JsonOutputPath $scopeOutJsonOutputPath `
    -MarkdownOutputPath $scopeOutMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for enterprise auth scope-out fixture with exit code $LASTEXITCODE."
}
$scopeOutReport = Get-Content -Raw -LiteralPath $scopeOutJsonOutputPath | ConvertFrom-Json
$scopeOutEnterpriseAuthCheck = @($scopeOutReport.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($scopeOutEnterpriseAuthCheck.Count -ne 1 -or -not $scopeOutEnterpriseAuthCheck[0].passed) {
    throw "Enterprise auth scope-out evidence must satisfy the operations readiness enterprise-auth check."
}
if (-not ([string] $scopeOutEnterpriseAuthCheck[0].detail).Contains("result=scope-out")) {
    throw "Enterprise auth scope-out readiness detail must preserve result=scope-out."
}

Write-Host "Operations readiness artifact verified."
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"
