param(
    [string] $OutputDirectory = ".\.osmu-run\secret-rotation-evidence-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
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

function Assert-NotContains([string] $text, [string] $unexpected, [string] $label) {
    if ($text.Contains($unexpected)) {
        throw "$label contains unexpected secret text: $unexpected"
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

$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-secret-rotation-evidence.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-secret-rotation-evidence.md"
$scriptPath = Resolve-ProjectPath ".\scripts\write-secret-rotation-evidence.ps1"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "ops-self-test" `
    -RotationStartedAt "2026-06-20T00:00:00Z" `
    -RotationCompletedAt "2026-06-20T00:30:00Z" `
    -ChangeApprovalRef "CHG-2026-SECRET-ROTATION-SELF-TEST" `
    -SecretManagerEvidenceRef "vault-audit-run-20260620" `
    -WorkloadRestartEvidenceRef "rollout-status-run-20260620" `
    -SmokeEvidenceRef "latest-restore-smoke-20260620" `
    -ArtifactLeakReviewEvidenceRef "artifact-leak-review-20260620" `
    -AccessKeyEncryptionDecisionRef "access-key-encryption-key-reissue-deferred-20260620" `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath `
    -RotateAdminPassword `
    -RotateJwtSigningSecret `
    -RotateDatabaseCredentials `
    -RotateMinioRootCredentials `
    -RotateTlsCertificate `
    -ConfirmNoSecretValues `
    -ConfirmWorkloadRestart `
    -ConfirmSmokePassed `
    -ConfirmArtifactLeakReview `
    -RequireAllCoreSecrets `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-secret-rotation-evidence.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Secret rotation evidence JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Secret rotation evidence markdown missing."

$reportText = Read-Utf8Text $jsonOutputPath
$markdown = Read-Utf8Text $markdownOutputPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)
$rotations = @($report.rotations)

Assert-True ($report.formatVersion -eq "osmu.secret-rotation-evidence.v1") "Unexpected secret rotation evidence formatVersion."
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.summary.coreRotatedCount -eq $report.summary.coreRequiredCount) "Expected all core rotations."
Assert-True ($checks.Count -ge 15) "Expected secret rotation checks."
Assert-True (@($checks | Where-Object { $_.id -eq "rotation-window-order" -and $_.passed }).Count -eq 1) "Expected rotation window order check to pass."
Assert-True (@($rotations | Where-Object { $_.core -and $_.rotated }).Count -ge 5) "Expected core rotation entries."
Assert-True ($report.confirmations.noSecretValues) "Expected no-secret-values confirmation."
Assert-True ($report.confirmations.workloadRestart) "Expected workload restart confirmation."
Assert-True ($report.confirmations.smokePassed) "Expected smoke confirmation."
Assert-True ($report.confirmations.artifactLeakReview) "Expected artifact leak review confirmation."

Assert-Contains $markdown "# OSMU Secret Rotation Evidence" "secret rotation evidence markdown"
Assert-Contains $markdown "Secret Policy" "secret rotation evidence markdown"
Assert-Contains $markdown "Record passed target evidence" "secret rotation evidence markdown"
Assert-Contains $report.secretPolicy "does not contain password values" "secret rotation evidence JSON"
Assert-Contains $report.decisionRule "Production/B2B readiness requires result=passed" "secret rotation evidence JSON"

foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----")) {
    Assert-NotContains $reportText $unexpected "secret rotation evidence JSON"
    Assert-NotContains $markdown $unexpected "secret rotation evidence markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -SecretManagerEvidenceRef "password=super-secret" `
        -NoWrite 2>&1
    $invalidExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) "Secret-like evidence reference should be rejected."

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidWindowOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "ops-self-test" `
        -RotationStartedAt "2026-06-20T00:30:00Z" `
        -RotationCompletedAt "2026-06-20T00:00:00Z" `
        -ChangeApprovalRef "CHG-2026-SECRET-ROTATION-SELF-TEST" `
        -SecretManagerEvidenceRef "vault-audit-run-20260620" `
        -WorkloadRestartEvidenceRef "rollout-status-run-20260620" `
        -SmokeEvidenceRef "latest-restore-smoke-20260620" `
        -ArtifactLeakReviewEvidenceRef "artifact-leak-review-20260620" `
        -JsonOutputPath (Join-Path $resolvedOutputDirectory "invalid-window.json") `
        -MarkdownOutputPath (Join-Path $resolvedOutputDirectory "invalid-window.md") `
        -RotateAdminPassword `
        -RotateJwtSigningSecret `
        -RotateDatabaseCredentials `
        -RotateMinioRootCredentials `
        -RotateTlsCertificate `
        -ConfirmNoSecretValues `
        -ConfirmWorkloadRestart `
        -ConfirmSmokePassed `
        -ConfirmArtifactLeakReview `
        -RequireAllCoreSecrets `
        -FailIfNotPassed 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidWindowExitCode -ne 0) "Reversed rotation window should be rejected."
Assert-Contains ($invalidWindowOutput | Out-String) "Rotation window order valid" "invalid rotation window output"

Write-Host "Secret rotation evidence writer verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
exit 0
