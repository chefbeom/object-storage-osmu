param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $ReviewStartedAt = "",
    [string] $ReviewCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $EnterpriseAuthSmokeJsonPath = "",
    [string] $JitProvisionEvidenceRef = "",
    [string] $JitRollbackRunbookRef = "",
    [string] $UserDisableRollbackEvidenceRef = "",
    [string] $RoleMappingRollbackEvidenceRef = "",
    [string] $LocalLoginFallbackEvidenceRef = "",
    [string] $AuditReviewEvidenceRef = "",
    [string] $EvidenceRef = "",
    [switch] $RequireEnterpriseAuthSmokeEvidence,
    [switch] $ConfirmAdminApprovalRequired,
    [switch] $ConfirmCallbackAutoJitDisabled,
    [switch] $ConfirmJitUserDisableOrLockRollbackReviewed,
    [switch] $ConfirmRoleOrgTeamRollbackReviewed,
    [switch] $ConfirmLocalPasswordFallbackValidated,
    [switch] $ConfirmAuditEventsReviewed,
    [switch] $ConfirmNoRawClaims,
    [switch] $ConfirmNoSecretValues,
    [string] $JsonOutputPath = ".\.osmu-run\latest-enterprise-auth-jit-rollback-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-enterprise-auth-jit-rollback-evidence.md",
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-SafeText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b",
        "(?i)\b(password|passwd|secret|token|credential|client_secret|ldap_password|oidc_code|oidc_state|refresh_token|access_token|id_token)\s*[=:]\s*\S+"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain credential material. Store only a non-secret evidence reference."
        }
    }
}

function Assert-SanitizedEnterpriseAuthJson([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b",
        '(?i)"(password|passwd|secret|token|credential|clientSecret|client_secret|ldapPassword|ldap_password|oidcCode|oidc_code|oidcState|oidc_state|rawClaim|rawClaims|claimPayload|claimJson|idToken|id_token|accessToken|access_token|refreshToken|refresh_token)"\s*:\s*"[^"]+"',
        '(?i)"(rawClaim|rawClaims|claimPayload|claimJson|claimsJson|idToken|id_token|accessToken|access_token|refreshToken|refresh_token)"\s*:',
        "(?i)\b(password|passwd|secret|token|credential|client_secret|ldap_password|oidc_code|oidc_state|refresh_token|access_token|id_token)\s*[=:]\s*\S+"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "EnterpriseAuthSmokeJson appears to contain raw claim, token, or credential-shaped content. Store only sanitized enterprise auth smoke evidence."
        }
    }
}

function Test-DateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse($Value, [ref] $parsed)
}

function Get-ParsedDateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($Value, [ref] $parsed)) {
        return $parsed
    }
    return $null
}

function Get-PropertyValue([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-PropertyText([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Get-PropertyInt([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return 0
    }
    $parsed = 0
    if ([int]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return 0
}

function Get-PropertyBool([object] $Object, [string] $Name) {
    $value = Get-PropertyValue $Object $Name
    if ($null -eq $value) {
        return $false
    }
    if ($value -is [bool]) {
        return [bool] $value
    }
    $parsed = $false
    if ([bool]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return $false
}

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail, [string] $EvidenceRef = "") {
    return [ordered]@{
        id = $Id
        name = $Name
        status = $Status
        passed = $Status -eq "PASS"
        detail = $Detail
        evidenceRef = $EvidenceRef
    }
}

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail, [string] $EvidenceRef = "") {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    [void] $script:checks.Add((New-Check $Id $Name $status $Detail $EvidenceRef))
}

function Read-EnterpriseAuthSmokeSummary([string] $PathValue) {
    $summary = [ordered]@{
        provided = $false
        path = ""
        parsed = $false
        formatVersion = ""
        result = ""
        executionMode = ""
        passCount = 0
        failCount = 0
        blockedCount = 0
        plannedCount = 0
        skippedCount = 0
        scopeOutAccepted = $false
        detail = "No enterprise auth smoke evidence JSON supplied."
    }
    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $summary
    }
    $resolvedPath = Resolve-ProjectPath $PathValue
    $summary["provided"] = $true
    $summary["path"] = $resolvedPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $summary["detail"] = "Enterprise auth smoke evidence JSON not found."
        return $summary
    }
    $raw = Get-Content -Raw -LiteralPath $resolvedPath
    Assert-SanitizedEnterpriseAuthJson $raw
    try {
        $payload = $raw | ConvertFrom-Json
    }
    catch {
        $summary["detail"] = "Enterprise auth smoke evidence JSON parse failed: $($_.Exception.Message)"
        return $summary
    }
    $summary["parsed"] = $true
    $summary["formatVersion"] = Get-PropertyText $payload "formatVersion"
    $summary["result"] = Get-PropertyText $payload "result"
    $summary["executionMode"] = Get-PropertyText $payload "executionMode"
    $summary["passCount"] = Get-PropertyInt $payload "passCount"
    $summary["failCount"] = Get-PropertyInt $payload "failCount"
    $summary["blockedCount"] = Get-PropertyInt $payload "blockedCount"
    $summary["plannedCount"] = Get-PropertyInt $payload "plannedCount"
    $summary["skippedCount"] = Get-PropertyInt $payload "skippedCount"
    $summary["scopeOutAccepted"] = Get-PropertyBool (Get-PropertyValue $payload "scopeOut") "accepted"
    $summary["detail"] = "formatVersion=$($summary["formatVersion"]); result=$($summary["result"]); executionMode=$($summary["executionMode"]); pass=$($summary["passCount"]); fail=$($summary["failCount"]); blocked=$($summary["blockedCount"]); planned=$($summary["plannedCount"]); scopeOutAccepted=$($summary["scopeOutAccepted"])"
    return $summary
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef),
    @("JitProvisionEvidenceRef", $JitProvisionEvidenceRef),
    @("JitRollbackRunbookRef", $JitRollbackRunbookRef),
    @("UserDisableRollbackEvidenceRef", $UserDisableRollbackEvidenceRef),
    @("RoleMappingRollbackEvidenceRef", $RoleMappingRollbackEvidenceRef),
    @("LocalLoginFallbackEvidenceRef", $LocalLoginFallbackEvidenceRef),
    @("AuditReviewEvidenceRef", $AuditReviewEvidenceRef),
    @("EvidenceRef", $EvidenceRef)
)) {
    Assert-SafeText ([string] $entry[1]) ([string] $entry[0])
}

$enterpriseAuthSmokeSummary = Read-EnterpriseAuthSmokeSummary $EnterpriseAuthSmokeJsonPath
$smokeEvidenceAccepted = -not [bool] $RequireEnterpriseAuthSmokeEvidence -and -not [bool] $enterpriseAuthSmokeSummary["provided"]
if (-not $smokeEvidenceAccepted) {
    $smokeResult = [string] $enterpriseAuthSmokeSummary["result"]
    $smokeEvidenceAccepted = [bool] $enterpriseAuthSmokeSummary["provided"] -and
        [bool] $enterpriseAuthSmokeSummary["parsed"] -and
        $enterpriseAuthSmokeSummary["formatVersion"] -eq "osmu.enterprise-auth-smoke.v1" -and
        (
            (
                $smokeResult -eq "passed" -and
                [int] $enterpriseAuthSmokeSummary["passCount"] -gt 0 -and
                [int] $enterpriseAuthSmokeSummary["failCount"] -eq 0 -and
                [int] $enterpriseAuthSmokeSummary["blockedCount"] -eq 0 -and
                [int] $enterpriseAuthSmokeSummary["plannedCount"] -eq 0
            ) -or (
                $smokeResult -eq "scope-out" -and
                [bool] $enterpriseAuthSmokeSummary["scopeOutAccepted"]
            )
        )
}

$reviewStartedAtParsed = Get-ParsedDateText $ReviewStartedAt
$reviewCompletedAtParsed = Get-ParsedDateText $ReviewCompletedAt
$reviewWindowOrdered = $null -ne $reviewStartedAtParsed -and $null -ne $reviewCompletedAtParsed -and $reviewCompletedAtParsed -ge $reviewStartedAtParsed
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ReviewStartedAt + $ReviewCompletedAt + $ChangeApprovalRef + $EnterpriseAuthSmokeJsonPath + $JitProvisionEvidenceRef + $JitRollbackRunbookRef + $UserDisableRollbackEvidenceRef + $RoleMappingRollbackEvidenceRef + $LocalLoginFallbackEvidenceRef + $AuditReviewEvidenceRef + $EvidenceRef) -or
    $RequireEnterpriseAuthSmokeEvidence -or
    $ConfirmAdminApprovalRequired -or
    $ConfirmCallbackAutoJitDisabled -or
    $ConfirmJitUserDisableOrLockRollbackReviewed -or
    $ConfirmRoleOrgTeamRollbackReviewed -or
    $ConfirmLocalPasswordFallbackValidated -or
    $ConfirmAuditEventsReviewed -or
    $ConfirmNoRawClaims -or
    $ConfirmNoSecretValues

Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($Operator)) "operator=$Operator"
Add-Check "review-started-at" "Review start timestamp recorded" (Test-DateText $ReviewStartedAt) "reviewStartedAt=$ReviewStartedAt"
Add-Check "review-completed-at" "Review completion timestamp recorded" (Test-DateText $ReviewCompletedAt) "reviewCompletedAt=$ReviewCompletedAt"
Add-Check "review-window-order" "Review window order valid" $reviewWindowOrdered "reviewStartedAt=$ReviewStartedAt; reviewCompletedAt=$ReviewCompletedAt"
Add-Check "change-approval-ref" "Change approval reference recorded" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "changeApprovalRef=$ChangeApprovalRef" $ChangeApprovalRef
if ([bool] $RequireEnterpriseAuthSmokeEvidence -or [bool] $enterpriseAuthSmokeSummary["provided"]) {
    Add-Check "enterprise-auth-smoke-snapshot-accepted" "Enterprise auth smoke or scope-out evidence snapshot accepted" $smokeEvidenceAccepted $enterpriseAuthSmokeSummary["detail"]
}
Add-Check "jit-provision-evidence-ref" "JIT provisioning evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($JitProvisionEvidenceRef)) "jitProvisionEvidenceRef=$JitProvisionEvidenceRef" $JitProvisionEvidenceRef
Add-Check "jit-rollback-runbook-ref" "JIT rollback runbook reference recorded" (-not [string]::IsNullOrWhiteSpace($JitRollbackRunbookRef)) "jitRollbackRunbookRef=$JitRollbackRunbookRef" $JitRollbackRunbookRef
Add-Check "user-disable-rollback-evidence-ref" "JIT user disable or lock rollback evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($UserDisableRollbackEvidenceRef)) "userDisableRollbackEvidenceRef=$UserDisableRollbackEvidenceRef" $UserDisableRollbackEvidenceRef
Add-Check "role-mapping-rollback-evidence-ref" "Role/org/team mapping rollback evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($RoleMappingRollbackEvidenceRef)) "roleMappingRollbackEvidenceRef=$RoleMappingRollbackEvidenceRef" $RoleMappingRollbackEvidenceRef
Add-Check "local-login-fallback-evidence-ref" "Local password fallback evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($LocalLoginFallbackEvidenceRef)) "localLoginFallbackEvidenceRef=$LocalLoginFallbackEvidenceRef" $LocalLoginFallbackEvidenceRef
Add-Check "audit-review-evidence-ref" "JIT audit review evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($AuditReviewEvidenceRef)) "auditReviewEvidenceRef=$AuditReviewEvidenceRef" $AuditReviewEvidenceRef
Add-Check "admin-approval-required-confirmed" "Admin approval required for JIT provisioning" ([bool] $ConfirmAdminApprovalRequired) "JIT apply remains admin-only and privileged roles require explicit approval."
Add-Check "callback-auto-jit-disabled-confirmed" "OIDC callback auto-JIT disabled" ([bool] $ConfirmCallbackAutoJitDisabled) "OIDC callback continues to issue tokens only for existing active local users."
Add-Check "jit-user-disable-or-lock-rollback-confirmed" "JIT user disable or lock rollback reviewed" ([bool] $ConfirmJitUserDisableOrLockRollbackReviewed) "Rollback can disable/lock the provisioned local user without deleting audit history."
Add-Check "role-org-team-rollback-confirmed" "Role, organization, and team mapping rollback reviewed" ([bool] $ConfirmRoleOrgTeamRollbackReviewed) "Rollback covers role downgrade and organization/team membership removal or correction."
Add-Check "local-login-fallback-confirmed" "Local password fallback validated" ([bool] $ConfirmLocalPasswordFallbackValidated) "Local password login remains available for break-glass/admin continuity."
Add-Check "audit-events-reviewed-confirmed" "JIT audit events reviewed" ([bool] $ConfirmAuditEventsReviewed) "OIDC_CLAIM_PREVIEW and OIDC_JIT_PROVISION audit records were reviewed without raw claim payload storage."
Add-Check "no-raw-claims-confirmed" "No raw claims recorded confirmation" ([bool] $ConfirmNoRawClaims) "Evidence stores only references and reduced smoke summary fields."
Add-Check "no-secret-values-confirmed" "No secret values recorded confirmation" ([bool] $ConfirmNoSecretValues) "Evidence stores no passwords, tokens, OIDC codes/states, LDAP secrets, or client secrets."

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$result = if (-not $hasAnyInput) {
    "planned"
}
elseif ($failureCount -eq 0) {
    "passed"
}
else {
    "failed"
}

$generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$checkArray = @($checks | ForEach-Object { $_ })

$report = [ordered]@{
    formatVersion = "osmu.enterprise-auth-jit-rollback-evidence.v1"
    generatedAt = $generatedAt
    result = $result
    environmentName = $EnvironmentName
    targetCluster = $TargetCluster
    operatorName = $Operator
    evidenceRef = $EvidenceRef
    reviewWindow = [ordered]@{
        startedAt = $ReviewStartedAt
        completedAt = $ReviewCompletedAt
    }
    enterpriseAuthSmokeSnapshot = $enterpriseAuthSmokeSummary
    evidenceRefs = [ordered]@{
        changeApproval = $ChangeApprovalRef
        jitProvision = $JitProvisionEvidenceRef
        jitRollbackRunbook = $JitRollbackRunbookRef
        userDisableRollback = $UserDisableRollbackEvidenceRef
        roleMappingRollback = $RoleMappingRollbackEvidenceRef
        localLoginFallback = $LocalLoginFallbackEvidenceRef
        auditReview = $AuditReviewEvidenceRef
    }
    confirmations = [ordered]@{
        adminApprovalRequired = [bool] $ConfirmAdminApprovalRequired
        callbackAutoJitDisabled = [bool] $ConfirmCallbackAutoJitDisabled
        jitUserDisableOrLockRollbackReviewed = [bool] $ConfirmJitUserDisableOrLockRollbackReviewed
        roleOrgTeamRollbackReviewed = [bool] $ConfirmRoleOrgTeamRollbackReviewed
        localPasswordFallbackValidated = [bool] $ConfirmLocalPasswordFallbackValidated
        auditEventsReviewed = [bool] $ConfirmAuditEventsReviewed
        noRawClaims = [bool] $ConfirmNoRawClaims
        noSecretValues = [bool] $ConfirmNoSecretValues
    }
    summary = [ordered]@{
        failureCount = $failureCount
        checkCount = $checkArray.Count
    }
    checks = [object] $checkArray
    decisionRule = "Production/B2B enterprise auth JIT readiness requires result=passed after admin-approved JIT provisioning evidence, rollback runbook review, user disable/lock rollback evidence, role/org/team mapping rollback review, local password fallback validation, audit review, and no-raw-claim/no-secret confirmations. If target enterprise auth is contractually deferred, use enterprise auth smoke scope-out evidence instead of claiming JIT rollback readiness."
    scopePolicy = "Enterprise auth JIT rollback/runbook evidence only. It does not execute IdP, LDAP, user, role, organization, or team changes; it records operator-reviewed target evidence references and reduced smoke summary only."
    secretPolicy = "Evidence stores only environment labels, operator/change references, timestamps, booleans, reduced enterprise auth smoke summary, and external evidence references; it does not contain passwords, bearer tokens, OIDC codes/states, access/refresh/id tokens, LDAP/admin passwords, client secrets, raw OIDC claims, raw identity provider responses, or raw directory data."
}

$markdownLines = @(
    "# OSMU Enterprise Auth JIT Rollback Evidence",
    "",
    "- Result: $result",
    "- Generated at: $generatedAt",
    "- Environment: $EnvironmentName",
    "- Target cluster: $TargetCluster",
    "- Operator: $Operator",
    "- Evidence ref: $EvidenceRef",
    "- Change approval: $ChangeApprovalRef",
    "- Enterprise auth smoke: result=$($enterpriseAuthSmokeSummary["result"]); executionMode=$($enterpriseAuthSmokeSummary["executionMode"]); pass=$($enterpriseAuthSmokeSummary["passCount"]); fail=$($enterpriseAuthSmokeSummary["failCount"]); scopeOutAccepted=$($enterpriseAuthSmokeSummary["scopeOutAccepted"])",
    "",
    "## Evidence References",
    "",
    "- JIT provisioning: $JitProvisionEvidenceRef",
    "- JIT rollback runbook: $JitRollbackRunbookRef",
    "- User disable/lock rollback: $UserDisableRollbackEvidenceRef",
    "- Role/org/team rollback: $RoleMappingRollbackEvidenceRef",
    "- Local login fallback: $LocalLoginFallbackEvidenceRef",
    "- Audit review: $AuditReviewEvidenceRef",
    "",
    "## Checks"
)
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}
$markdownLines += @(
    "",
    "## Secret Policy",
    "",
    $report.secretPolicy,
    "",
    "## Next Command",
    "",
    "- Feed this evidence reference into the enterprise auth pilot package when JIT provisioning is in production scope.",
    "- Record passed target evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-jit-rollback-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -ChangeApprovalRef <change-id> -EnterpriseAuthSmokeJsonPath .\.osmu-run\latest-enterprise-auth-smoke.json -RequireEnterpriseAuthSmokeEvidence -JitProvisionEvidenceRef <ref> -JitRollbackRunbookRef <ref> -UserDisableRollbackEvidenceRef <ref> -RoleMappingRollbackEvidenceRef <ref> -LocalLoginFallbackEvidenceRef <ref> -AuditReviewEvidenceRef <ref> -EvidenceRef <run-ref> -ConfirmAdminApprovalRequired -ConfirmCallbackAutoJitDisabled -ConfirmJitUserDisableOrLockRollbackReviewed -ConfirmRoleOrgTeamRollbackReviewed -ConfirmLocalPasswordFallbackValidated -ConfirmAuditEventsReviewed -ConfirmNoRawClaims -ConfirmNoSecretValues -FailIfNotPassed``"
)

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($resolvedJsonOutputPath)) | Out-Null
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($resolvedMarkdownOutputPath)) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 -LiteralPath $resolvedJsonOutputPath
    $markdownLines -join [Environment]::NewLine | Set-Content -Encoding UTF8 -LiteralPath $resolvedMarkdownOutputPath
}

if ($FailIfNotPassed -and $result -ne "passed") {
    $failedDetails = ($checks | Where-Object { $_.status -eq "FAIL" } | ForEach-Object { "$($_.id): $($_.detail)" }) -join "; "
    throw "Enterprise auth JIT rollback evidence result is $result. $failedDetails"
}

Write-Host "Enterprise auth JIT rollback evidence result: $result"
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"