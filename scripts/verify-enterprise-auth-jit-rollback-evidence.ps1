param(
    [string] $OutputDirectory = ".\.osmu-run\enterprise-auth-jit-rollback-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Label) {
    if (-not $Text.Contains($Expected)) {
        throw "$Label does not contain expected text: $Expected"
    }
}

function Assert-NotContains([string] $Text, [string] $Unexpected, [string] $Label) {
    if ($Text.Contains($Unexpected)) {
        throw "$Label contains unexpected secret/raw text: $Unexpected"
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

$scriptPath = Resolve-ProjectPath ".\scripts\write-enterprise-auth-jit-rollback-evidence.ps1"
$smokePath = Join-Path $resolvedOutputDirectory "latest-enterprise-auth-smoke.json"
$unsafeSmokePath = Join-Path $resolvedOutputDirectory "unsafe-enterprise-auth-smoke.json"
$plannedJsonPath = Join-Path $resolvedOutputDirectory "planned.json"
$plannedMarkdownPath = Join-Path $resolvedOutputDirectory "planned.md"
$passedJsonPath = Join-Path $resolvedOutputDirectory "passed.json"
$passedMarkdownPath = Join-Path $resolvedOutputDirectory "passed.md"

[ordered]@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "passed"
    executionMode = "execute"
    passCount = 8
    failCount = 0
    blockedCount = 0
    plannedCount = 0
    skippedCount = 0
    scopeOut = [ordered]@{
        accepted = $false
    }
    checks = @(
        [ordered]@{
            id = "oidc-callback"
            status = "PASS"
            endpoint = "GET /api/auth/oidc/callback"
            detail = "target OIDC callback passed"
        },
        [ordered]@{
            id = "jit-provision"
            status = "PASS"
            endpoint = "POST /api/admin/security/enterprise-auth/jit-provision"
            detail = "admin-approved JIT provisioning passed"
        }
    )
} | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $smokePath

[ordered]@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "passed"
    executionMode = "execute"
    passCount = 1
    failCount = 0
    blockedCount = 0
    plannedCount = 0
    rawClaims = [ordered]@{
        email = "jit.user@example.com"
    }
} | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $unsafeSmokePath

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -JsonOutputPath $plannedJsonPath `
    -MarkdownOutputPath $plannedMarkdownPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "planned write-enterprise-auth-jit-rollback-evidence.ps1 failed with exit code $LASTEXITCODE."
}

$plannedReport = Get-Content -Raw -LiteralPath $plannedJsonPath | ConvertFrom-Json
$plannedMarkdown = Get-Content -Raw -LiteralPath $plannedMarkdownPath
Assert-True ($plannedReport.formatVersion -eq "osmu.enterprise-auth-jit-rollback-evidence.v1") "Unexpected JIT rollback evidence formatVersion."
Assert-True ($plannedReport.result -eq "planned") "Default JIT rollback evidence should be planned."
Assert-True ($plannedReport.summary.failureCount -gt 0) "Planned JIT rollback evidence should include missing checks."
Assert-Contains $plannedMarkdown "Enterprise Auth JIT Rollback Evidence" "planned markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "security-self-test" `
    -ReviewStartedAt "2026-06-21T01:00:00Z" `
    -ReviewCompletedAt "2026-06-21T01:30:00Z" `
    -ChangeApprovalRef "CHG-2026-ENTERPRISE-AUTH-JIT" `
    -EnterpriseAuthSmokeJsonPath $smokePath `
    -RequireEnterpriseAuthSmokeEvidence `
    -JitProvisionEvidenceRef "jit-provision-target-20260621" `
    -JitRollbackRunbookRef "jit-rollback-runbook-20260621" `
    -UserDisableRollbackEvidenceRef "jit-user-disable-rollback-20260621" `
    -RoleMappingRollbackEvidenceRef "jit-role-org-team-rollback-20260621" `
    -LocalLoginFallbackEvidenceRef "local-login-fallback-20260621" `
    -AuditReviewEvidenceRef "oidc-jit-audit-review-20260621" `
    -EvidenceRef "enterprise-auth-jit-rollback-20260621" `
    -ConfirmAdminApprovalRequired `
    -ConfirmCallbackAutoJitDisabled `
    -ConfirmJitUserDisableOrLockRollbackReviewed `
    -ConfirmRoleOrgTeamRollbackReviewed `
    -ConfirmLocalPasswordFallbackValidated `
    -ConfirmAuditEventsReviewed `
    -ConfirmNoRawClaims `
    -ConfirmNoSecretValues `
    -JsonOutputPath $passedJsonPath `
    -MarkdownOutputPath $passedMarkdownPath `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "passed write-enterprise-auth-jit-rollback-evidence.ps1 failed with exit code $LASTEXITCODE."
}

$reportText = Get-Content -Raw -LiteralPath $passedJsonPath
$markdown = Get-Content -Raw -LiteralPath $passedMarkdownPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)

Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.enterpriseAuthSmokeSnapshot.result -eq "passed") "Expected enterprise auth smoke snapshot result."
Assert-True ($report.enterpriseAuthSmokeSnapshot.passCount -eq 8) "Expected enterprise auth smoke pass count."
Assert-True ($report.confirmations.adminApprovalRequired) "Expected admin approval confirmation."
Assert-True ($report.confirmations.callbackAutoJitDisabled) "Expected callback auto-JIT disabled confirmation."
Assert-True ($report.confirmations.localPasswordFallbackValidated) "Expected local login fallback confirmation."
Assert-True (@($checks | Where-Object { $_.id -eq "enterprise-auth-smoke-snapshot-accepted" -and $_.passed }).Count -eq 1) "Expected accepted smoke snapshot check."
Assert-True (@($checks | Where-Object { $_.id -eq "jit-user-disable-or-lock-rollback-confirmed" -and $_.passed }).Count -eq 1) "Expected JIT user rollback confirmation check."
Assert-Contains $markdown "JIT rollback runbook" "passed markdown"
Assert-Contains $report.scopePolicy "does not execute IdP" "JIT rollback JSON scope policy"
Assert-Contains $report.secretPolicy "does not contain passwords" "JIT rollback JSON secret policy"
Assert-Contains $report.decisionRule "Production/B2B enterprise auth JIT readiness requires result=passed" "JIT rollback JSON decision rule"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----", "unsafe-access-token", "rawClaims")) {
    Assert-NotContains $reportText $unexpected "JIT rollback JSON"
    Assert-NotContains $markdown $unexpected "JIT rollback markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingSmokeOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "security-self-test" `
        -ReviewStartedAt "2026-06-21T01:00:00Z" `
        -ReviewCompletedAt "2026-06-21T01:30:00Z" `
        -ChangeApprovalRef "CHG-2026-ENTERPRISE-AUTH-JIT" `
        -RequireEnterpriseAuthSmokeEvidence `
        -JitProvisionEvidenceRef "jit-provision-target-20260621" `
        -JitRollbackRunbookRef "jit-rollback-runbook-20260621" `
        -UserDisableRollbackEvidenceRef "jit-user-disable-rollback-20260621" `
        -RoleMappingRollbackEvidenceRef "jit-role-org-team-rollback-20260621" `
        -LocalLoginFallbackEvidenceRef "local-login-fallback-20260621" `
        -AuditReviewEvidenceRef "oidc-jit-audit-review-20260621" `
        -ConfirmAdminApprovalRequired `
        -ConfirmCallbackAutoJitDisabled `
        -ConfirmJitUserDisableOrLockRollbackReviewed `
        -ConfirmRoleOrgTeamRollbackReviewed `
        -ConfirmLocalPasswordFallbackValidated `
        -ConfirmAuditEventsReviewed `
        -ConfirmNoRawClaims `
        -ConfirmNoSecretValues `
        -FailIfNotPassed 2>&1
    $missingSmokeExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($missingSmokeExitCode -ne 0) "Required smoke evidence should be rejected when missing."
Assert-Contains ($missingSmokeOutput | Out-String) "enterprise-auth-smoke-snapshot-accepted" "missing smoke output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeSmokeOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnterpriseAuthSmokeJsonPath $unsafeSmokePath `
        -NoWrite 2>&1
    $unsafeSmokeExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeSmokeExitCode -ne 0) "Raw claim smoke snapshot should be rejected."
Assert-Contains ($unsafeSmokeOutput | Out-String) "raw claim" "unsafe smoke output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $secretRefOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EvidenceRef "password=super-secret" `
        -NoWrite 2>&1
    $secretRefExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($secretRefExitCode -ne 0) "Secret-like evidence reference should be rejected."
Assert-Contains ($secretRefOutput | Out-String) "credential material" "secret ref output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidWindowOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "security-self-test" `
        -ReviewStartedAt "2026-06-21T01:30:00Z" `
        -ReviewCompletedAt "2026-06-21T01:00:00Z" `
        -ChangeApprovalRef "CHG-2026-ENTERPRISE-AUTH-JIT" `
        -EnterpriseAuthSmokeJsonPath $smokePath `
        -RequireEnterpriseAuthSmokeEvidence `
        -JitProvisionEvidenceRef "jit-provision-target-20260621" `
        -JitRollbackRunbookRef "jit-rollback-runbook-20260621" `
        -UserDisableRollbackEvidenceRef "jit-user-disable-rollback-20260621" `
        -RoleMappingRollbackEvidenceRef "jit-role-org-team-rollback-20260621" `
        -LocalLoginFallbackEvidenceRef "local-login-fallback-20260621" `
        -AuditReviewEvidenceRef "oidc-jit-audit-review-20260621" `
        -ConfirmAdminApprovalRequired `
        -ConfirmCallbackAutoJitDisabled `
        -ConfirmJitUserDisableOrLockRollbackReviewed `
        -ConfirmRoleOrgTeamRollbackReviewed `
        -ConfirmLocalPasswordFallbackValidated `
        -ConfirmAuditEventsReviewed `
        -ConfirmNoRawClaims `
        -ConfirmNoSecretValues `
        -FailIfNotPassed 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidWindowExitCode -ne 0) "Invalid review window should be rejected."
Assert-Contains ($invalidWindowOutput | Out-String) "review-window-order" "invalid window output"

Write-Host "Enterprise auth JIT rollback evidence verification passed: $passedJsonPath"