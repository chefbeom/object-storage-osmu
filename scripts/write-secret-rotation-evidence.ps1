param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $RotationStartedAt = "",
    [string] $RotationCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $SecretManagerEvidenceRef = "",
    [string] $WorkloadRestartEvidenceRef = "",
    [string] $SmokeEvidenceRef = "",
    [string] $ArtifactLeakReviewEvidenceRef = "",
    [string] $AccessKeyEncryptionDecisionRef = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-secret-rotation-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-secret-rotation-evidence.md",
    [switch] $RotateAdminPassword,
    [switch] $RotateJwtSigningSecret,
    [switch] $RotateDatabaseCredentials,
    [switch] $RotateMinioRootCredentials,
    [switch] $RotateTlsCertificate,
    [switch] $RotateAccessKeyEncryptionKey,
    [switch] $RotateOidcOrLdapSecrets,
    [switch] $RotateSmtpOrWebhookSecrets,
    [switch] $ConfirmNoSecretValues,
    [switch] $ConfirmWorkloadRestart,
    [switch] $ConfirmSmokePassed,
    [switch] $ConfirmArtifactLeakReview,
    [switch] $RequireAllCoreSecrets,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-SafeReference([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "(?i)\b(password|passwd|secret|token|client_secret|x-amz-security-token)\s*[=:]\s*\S+"
    )

    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain secret material. Store only an external evidence reference."
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

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail) {
    return [ordered]@{
        id = $Id
        name = $Name
        status = $Status
        passed = $Status -eq "PASS"
        detail = $Detail
    }
}

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail) {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    [void] $script:checks.Add((New-Check $Id $Name $status $Detail))
}

function Add-OptionalCheck([string] $Id, [string] $Name, [bool] $Passed, [bool] $Required, [string] $Detail) {
    if ($Required -or $Passed) {
        Add-Check $Id $Name $Passed $Detail
    }
    else {
        [void] $script:checks.Add((New-Check $Id $Name "PLANNED" $Detail))
    }
}

function New-RotationItem([string] $Id, [string] $Name, [bool] $Core, [bool] $Rotated, [string] $Note) {
    return [ordered]@{
        id = $Id
        name = $Name
        core = $Core
        rotated = $Rotated
        note = $Note
    }
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef),
    @("SecretManagerEvidenceRef", $SecretManagerEvidenceRef),
    @("WorkloadRestartEvidenceRef", $WorkloadRestartEvidenceRef),
    @("SmokeEvidenceRef", $SmokeEvidenceRef),
    @("ArtifactLeakReviewEvidenceRef", $ArtifactLeakReviewEvidenceRef),
    @("AccessKeyEncryptionDecisionRef", $AccessKeyEncryptionDecisionRef)
)) {
    Assert-SafeReference ([string] $entry[1]) ([string] $entry[0])
}

$rotations = @(
    (New-RotationItem "admin-password" "Admin password" $true ([bool] $RotateAdminPassword) "Rotate before shared demo, pilot handoff, suspected exposure, or owner change."),
    (New-RotationItem "jwt-signing-secret" "JWT signing secret" $true ([bool] $RotateJwtSigningSecret) "Rotation invalidates active access and refresh tokens."),
    (New-RotationItem "database-credentials" "MariaDB credentials" $true ([bool] $RotateDatabaseCredentials) "Rotate user/root credentials in the target secret manager."),
    (New-RotationItem "minio-root-credentials" "MinIO root credentials" $true ([bool] $RotateMinioRootCredentials) "Applications must use scoped access keys after bootstrap."),
    (New-RotationItem "tls-certificate" "TLS certificate" $true ([bool] $RotateTlsCertificate) "Rotate or renew the osmu-tls Secret and verify HTTPS routing."),
    (New-RotationItem "access-key-encryption-key" "Access key encryption key" $false ([bool] $RotateAccessKeyEncryptionKey) "Routine rotation is avoided unless a migration or access-key reissue is planned."),
    (New-RotationItem "oidc-ldap-secrets" "OIDC/LDAP client and bind secrets" $false ([bool] $RotateOidcOrLdapSecrets) "Required only when enterprise auth is in production scope."),
    (New-RotationItem "smtp-webhook-signing-secrets" "SMTP and webhook signing secrets" $false ([bool] $RotateSmtpOrWebhookSecrets) "Required when outbound billing notification/payment handoff adapters are enabled.")
)

$coreRotations = @($rotations | Where-Object { $_.core })
$rotatedCoreCount = @($coreRotations | Where-Object { $_.rotated }).Count
$rotatedCount = @($rotations | Where-Object { $_.rotated }).Count
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ChangeApprovalRef + $SecretManagerEvidenceRef + $WorkloadRestartEvidenceRef + $SmokeEvidenceRef + $ArtifactLeakReviewEvidenceRef + $AccessKeyEncryptionDecisionRef + $RotationStartedAt + $RotationCompletedAt) -or $rotatedCount -gt 0
$rotationStartedAtParsed = Get-ParsedDateText $RotationStartedAt
$rotationCompletedAtParsed = Get-ParsedDateText $RotationCompletedAt
$rotationWindowOrdered = $null -ne $rotationStartedAtParsed -and $null -ne $rotationCompletedAtParsed -and $rotationCompletedAtParsed -ge $rotationStartedAtParsed

Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($Operator)) "operator=$Operator"
Add-Check "rotation-started-at" "Rotation start timestamp recorded" (Test-DateText $RotationStartedAt) "rotationStartedAt=$RotationStartedAt"
Add-Check "rotation-completed-at" "Rotation completion timestamp recorded" (Test-DateText $RotationCompletedAt) "rotationCompletedAt=$RotationCompletedAt"
Add-Check "rotation-window-order" "Rotation window order valid" $rotationWindowOrdered "rotationStartedAt=$RotationStartedAt; rotationCompletedAt=$RotationCompletedAt"
Add-Check "change-approval-ref" "Change approval reference recorded" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "changeApprovalRef=$ChangeApprovalRef"
Add-Check "secret-manager-evidence-ref" "Secret manager audit reference recorded" (-not [string]::IsNullOrWhiteSpace($SecretManagerEvidenceRef)) "secretManagerEvidenceRef=$SecretManagerEvidenceRef"
Add-Check "workload-restart-evidence-ref" "Workload restart evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($WorkloadRestartEvidenceRef)) "workloadRestartEvidenceRef=$WorkloadRestartEvidenceRef"
Add-Check "smoke-evidence-ref" "Post-rotation smoke evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($SmokeEvidenceRef)) "smokeEvidenceRef=$SmokeEvidenceRef"
Add-Check "artifact-leak-review-evidence-ref" "Artifact leak review reference recorded" (-not [string]::IsNullOrWhiteSpace($ArtifactLeakReviewEvidenceRef)) "artifactLeakReviewEvidenceRef=$ArtifactLeakReviewEvidenceRef"
Add-Check "no-secret-values-confirmed" "No secret values recorded confirmation" ([bool] $ConfirmNoSecretValues) "Evidence stores references and booleans only."
Add-Check "workload-restart-confirmed" "Workloads restarted or reloaded confirmation" ([bool] $ConfirmWorkloadRestart) "Workloads that read secrets at startup were restarted or reloaded."
Add-Check "smoke-passed-confirmed" "Post-rotation smoke passed confirmation" ([bool] $ConfirmSmokePassed) "Required smoke checks passed after rotation."
Add-Check "artifact-leak-review-confirmed" "Release/log artifact leak review confirmation" ([bool] $ConfirmArtifactLeakReview) "Release artifacts, logs, worklogs, reports, and screenshots were checked for secret leakage."
Add-Check "core-secret-rotation-coverage" "Core secret/certificate rotation coverage" ($rotatedCoreCount -eq $coreRotations.Count) "rotatedCore=$rotatedCoreCount/$($coreRotations.Count)"
Add-OptionalCheck "access-key-encryption-decision-ref" "Access key encryption key migration decision recorded" (-not [string]::IsNullOrWhiteSpace($AccessKeyEncryptionDecisionRef)) ([bool] $RotateAccessKeyEncryptionKey -or [bool] $RequireAllCoreSecrets) "accessKeyEncryptionDecisionRef=$AccessKeyEncryptionDecisionRef"

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$plannedCount = @($checks | Where-Object { $_.status -eq "PLANNED" }).Count
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
$rotationArray = @($rotations)
$checkArray = @($checks | ForEach-Object { $_ })

$report = New-Object System.Collections.Specialized.OrderedDictionary
[void] $report.Add("formatVersion", "osmu.secret-rotation-evidence.v1")
[void] $report.Add("generatedAt", $generatedAt)
[void] $report.Add("result", $result)
[void] $report.Add("environmentName", $EnvironmentName)
[void] $report.Add("targetCluster", $TargetCluster)
[void] $report.Add("operatorName", $Operator)
[void] $report.Add("rotationWindow", [ordered]@{
    startedAt = $RotationStartedAt
    completedAt = $RotationCompletedAt
})
[void] $report.Add("evidenceRefs", [ordered]@{
    changeApproval = $ChangeApprovalRef
    secretManagerAudit = $SecretManagerEvidenceRef
    workloadRestart = $WorkloadRestartEvidenceRef
    smoke = $SmokeEvidenceRef
    artifactLeakReview = $ArtifactLeakReviewEvidenceRef
    accessKeyEncryptionDecision = $AccessKeyEncryptionDecisionRef
})
[void] $report.Add("confirmations", [ordered]@{
    noSecretValues = [bool] $ConfirmNoSecretValues
    workloadRestart = [bool] $ConfirmWorkloadRestart
    smokePassed = [bool] $ConfirmSmokePassed
    artifactLeakReview = [bool] $ConfirmArtifactLeakReview
    requireAllCoreSecrets = [bool] $RequireAllCoreSecrets
})
[void] $report.Add("rotations", [object] $rotationArray)
[void] $report.Add("summary", [ordered]@{
    rotatedCount = $rotatedCount
    coreRotatedCount = $rotatedCoreCount
    coreRequiredCount = $coreRotations.Count
    failureCount = $failureCount
    plannedCount = $plannedCount
})
[void] $report.Add("checks", [object] $checkArray)
[void] $report.Add("decisionRule", "Production/B2B readiness requires result=passed from the target environment after core secret/certificate rotation, workload restart, post-rotation smoke, and artifact leak review are confirmed.")
[void] $report.Add("secretPolicy", "Evidence stores only environment labels, operator/change references, timestamps, booleans, and external evidence references; it does not contain password values, API keys, private keys, bearer tokens, kubeconfig, database credentials, MinIO credentials, OIDC/LDAP secrets, SMTP credentials, or webhook signing secrets.")

$markdownLines = @(
    "# OSMU Secret Rotation Evidence",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Environment: $EnvironmentName",
    "Target cluster: $TargetCluster",
    "Operator: $Operator",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Secret Policy",
    "",
    $report.secretPolicy,
    "",
    "## Evidence References",
    "",
    "- Change approval: $ChangeApprovalRef",
    "- Secret manager audit: $SecretManagerEvidenceRef",
    "- Workload restart: $WorkloadRestartEvidenceRef",
    "- Smoke: $SmokeEvidenceRef",
    "- Artifact leak review: $ArtifactLeakReviewEvidenceRef",
    "- Access key encryption decision: $AccessKeyEncryptionDecisionRef",
    "",
    "## Rotations",
    ""
)

foreach ($rotation in $rotations) {
    $markdownLines += "- [$($rotation.rotated)] $($rotation.name): $($rotation.note)"
}

$markdownLines += ""
$markdownLines += "## Checks"
$markdownLines += ""
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}

$markdownLines += ""
$markdownLines += "## Operator Command"
$markdownLines += ""
$markdownLines += "- Record passed target evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-secret-rotation-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -RotationStartedAt <iso-time> -RotationCompletedAt <iso-time> -ChangeApprovalRef <change-id> -SecretManagerEvidenceRef <audit-ref> -WorkloadRestartEvidenceRef <rollout-ref> -SmokeEvidenceRef <smoke-ref> -ArtifactLeakReviewEvidenceRef <scan-ref> -AccessKeyEncryptionDecisionRef <decision-ref> -RotateAdminPassword -RotateJwtSigningSecret -RotateDatabaseCredentials -RotateMinioRootCredentials -RotateTlsCertificate -ConfirmNoSecretValues -ConfirmWorkloadRestart -ConfirmSmokePassed -ConfirmArtifactLeakReview -FailIfNotPassed``"

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Secret rotation evidence JSON: $resolvedJsonOutputPath"
    Write-Host "Secret rotation evidence markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Secret rotation evidence did not pass: result=$result failureCount=$failureCount"
}
