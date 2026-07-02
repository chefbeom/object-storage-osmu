param(
    [string] $OutputDirectory = ".\.osmu-run\cluster-network-access-review-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return [System.IO.Path]::GetFullPath($PathValue) }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    $resolvedPath = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}

function Assert-True([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Assert-Contains([string] $Text, [string] $Expected, [string] $Label) { if (-not $Text.Contains($Expected)) { throw "$Label does not contain expected text: $Expected" } }
function Assert-NotContains([string] $Text, [string] $Unexpected, [string] $Label) { if ($Text.Contains($Unexpected)) { throw "$Label contains unexpected secret/raw text: $Unexpected" } }

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) { Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force }
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$scriptPath = Resolve-ProjectPath ".\scripts\write-cluster-network-access-review-evidence.ps1"
$plannedJsonPath = Join-Path $resolvedOutputDirectory "planned.json"
$plannedMarkdownPath = Join-Path $resolvedOutputDirectory "planned.md"
$passedJsonPath = Join-Path $resolvedOutputDirectory "passed.json"
$passedMarkdownPath = Join-Path $resolvedOutputDirectory "passed.md"
$missingConfirmationJsonPath = Join-Path $resolvedOutputDirectory "missing-confirmation.json"
$missingConfirmationMarkdownPath = Join-Path $resolvedOutputDirectory "missing-confirmation.md"
$invalidWindowJsonPath = Join-Path $resolvedOutputDirectory "invalid-window.json"
$invalidWindowMarkdownPath = Join-Path $resolvedOutputDirectory "invalid-window.md"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -JsonOutputPath $plannedJsonPath `
    -MarkdownOutputPath $plannedMarkdownPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw "planned write-cluster-network-access-review-evidence.ps1 failed with exit code $LASTEXITCODE." }

$plannedReport = Read-Utf8Text $plannedJsonPath | ConvertFrom-Json
$plannedMarkdown = Read-Utf8Text $plannedMarkdownPath
Assert-True ($plannedReport.formatVersion -eq "osmu.cluster-network-access-review-evidence.v1") "Unexpected cluster network evidence formatVersion."
Assert-True ($plannedReport.result -eq "planned") "Default cluster network evidence should be planned."
Assert-True ($plannedReport.summary.failureCount -gt 0) "Planned cluster network evidence should include missing checks."
Assert-True ($plannedReport.staticControlSnapshot.requiredPolicyNamesPresent -eq $true) "Expected static NetworkPolicy names to be detected."
Assert-True ($plannedReport.staticControlSnapshot.helmNetworkPolicyEnabled -eq $true) "Expected Helm networkPolicy.enabled to be detected."
Assert-Contains $plannedMarkdown "Cluster Network Access Review Evidence" "planned markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "platform-self-test" `
    -ReviewStartedAt "2026-06-22T01:00:00Z" `
    -ReviewCompletedAt "2026-06-22T01:20:00Z" `
    -ChangeApprovalRef "CHG-2026-CLUSTER-NETWORK" `
    -DnsEgressReviewRef "dns-egress-review-20260622" `
    -MariaDbAccessReviewRef "mariadb-access-review-20260622" `
    -MinioAccessReviewRef "minio-access-review-20260622" `
    -BackupAccessReviewRef "backup-access-review-20260622" `
    -PublicIngressReviewRef "ingress-tls-review-20260622" `
    -DefaultDenyReviewRef "namespace-default-deny-review-20260622" `
    -ObservabilityScrapeReviewRef "prometheus-scrape-review-20260622" `
    -K8sVerifierEvidenceRef "verify-k8s-manifests-20260622" `
    -HelmVerifierEvidenceRef "verify-helm-chart-20260622" `
    -EvidenceRef "cluster-network-access-review-20260622" `
    -ConfirmBackendOnlyMariaDb `
    -ConfirmBackendOnlyMinio `
    -ConfirmBackupOnlyMariaDbMinio `
    -ConfirmDnsEgressScoped `
    -ConfirmMariaDbIngressBackendBackupOnly `
    -ConfirmMinioIngressBackendBackupOnly `
    -ConfirmPublicIngressLimited `
    -ConfirmNamespaceDefaultDenyReviewed `
    -ConfirmObservabilityScrapeReviewed `
    -ConfirmHelmNetworkPolicyEnabled `
    -ConfirmNoCredentialValues `
    -JsonOutputPath $passedJsonPath `
    -MarkdownOutputPath $passedMarkdownPath `
    -FailIfNotPassed | Out-Null
if ($LASTEXITCODE -ne 0) { throw "passed write-cluster-network-access-review-evidence.ps1 failed with exit code $LASTEXITCODE." }

$reportText = Read-Utf8Text $passedJsonPath
$markdown = Read-Utf8Text $passedMarkdownPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.staticControlSnapshot.backendEgressScoped -eq $true) "Expected backend egress static scope."
Assert-True ($report.staticControlSnapshot.backupEgressScoped -eq $true) "Expected backup egress static scope."
Assert-True ($report.staticControlSnapshot.dnsEgressScoped -eq $true) "Expected DNS egress static scope."
Assert-True ($report.staticControlSnapshot.noBroadCidr -eq $true) "Expected no broad CIDR."
Assert-True ($report.confirmations.noCredentialValues -eq $true) "Expected no credential confirmation."
Assert-True (@($checks | Where-Object { $_.id -eq "namespace-default-deny-reviewed" -and $_.passed }).Count -eq 1) "Expected namespace default-deny review confirmation."
Assert-Contains $markdown "Static Control Snapshot" "passed markdown"
Assert-Contains $report.scopePolicy "does not execute kubectl" "cluster network JSON scope policy"
Assert-Contains $report.secretPolicy "never kubeconfig" "cluster network JSON secret policy"
Assert-Contains $report.decisionRule "Production/B2B cluster network access review requires result=passed" "cluster network JSON decision rule"
foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----", "kubeconfig=raw")) {
    Assert-NotContains $reportText $unexpected "cluster network JSON"
    Assert-NotContains $markdown $unexpected "cluster network markdown"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $missingConfirmationOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "platform-self-test" `
        -ReviewStartedAt "2026-06-22T01:00:00Z" `
        -ReviewCompletedAt "2026-06-22T01:20:00Z" `
        -ChangeApprovalRef "CHG-2026-CLUSTER-NETWORK" `
        -DnsEgressReviewRef "dns-egress-review-20260622" `
        -MariaDbAccessReviewRef "mariadb-access-review-20260622" `
        -MinioAccessReviewRef "minio-access-review-20260622" `
        -BackupAccessReviewRef "backup-access-review-20260622" `
        -PublicIngressReviewRef "ingress-tls-review-20260622" `
        -DefaultDenyReviewRef "namespace-default-deny-review-20260622" `
        -ObservabilityScrapeReviewRef "prometheus-scrape-review-20260622" `
        -EvidenceRef "cluster-network-access-review-20260622" `
        -ConfirmBackendOnlyMariaDb `
        -ConfirmBackendOnlyMinio `
        -ConfirmBackupOnlyMariaDbMinio `
        -ConfirmDnsEgressScoped `
        -ConfirmMariaDbIngressBackendBackupOnly `
        -ConfirmMinioIngressBackendBackupOnly `
        -ConfirmPublicIngressLimited `
        -ConfirmNamespaceDefaultDenyReviewed `
        -ConfirmObservabilityScrapeReviewed `
        -ConfirmHelmNetworkPolicyEnabled `
        -JsonOutputPath $missingConfirmationJsonPath `
        -MarkdownOutputPath $missingConfirmationMarkdownPath `
        -FailIfNotPassed 2>&1
    $missingConfirmationExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($missingConfirmationExitCode -ne 0) "Missing no-credential confirmation should fail."
Assert-Contains ($missingConfirmationOutput | Out-String) "Cluster network access review evidence did not pass" "missing confirmation output"
Assert-True (Test-Path -LiteralPath $missingConfirmationJsonPath) "Missing-confirmation JSON should stay isolated under the self-test output directory."

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $secretRefOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -EvidenceRef "password=super-secret" -NoWrite 2>&1
    $secretRefExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($secretRefExitCode -ne 0) "Secret-like evidence reference should be rejected."
Assert-Contains ($secretRefOutput | Out-String) "credential material" "secret ref output"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidWindowOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "platform-self-test" `
        -ReviewStartedAt "2026-06-22T01:20:00Z" `
        -ReviewCompletedAt "2026-06-22T01:00:00Z" `
        -ChangeApprovalRef "CHG-2026-CLUSTER-NETWORK" `
        -DnsEgressReviewRef "dns-egress-review-20260622" `
        -MariaDbAccessReviewRef "mariadb-access-review-20260622" `
        -MinioAccessReviewRef "minio-access-review-20260622" `
        -BackupAccessReviewRef "backup-access-review-20260622" `
        -PublicIngressReviewRef "ingress-tls-review-20260622" `
        -DefaultDenyReviewRef "namespace-default-deny-review-20260622" `
        -ObservabilityScrapeReviewRef "prometheus-scrape-review-20260622" `
        -EvidenceRef "cluster-network-access-review-20260622" `
        -ConfirmBackendOnlyMariaDb `
        -ConfirmBackendOnlyMinio `
        -ConfirmBackupOnlyMariaDbMinio `
        -ConfirmDnsEgressScoped `
        -ConfirmMariaDbIngressBackendBackupOnly `
        -ConfirmMinioIngressBackendBackupOnly `
        -ConfirmPublicIngressLimited `
        -ConfirmNamespaceDefaultDenyReviewed `
        -ConfirmObservabilityScrapeReviewed `
        -ConfirmHelmNetworkPolicyEnabled `
        -ConfirmNoCredentialValues `
        -JsonOutputPath $invalidWindowJsonPath `
        -MarkdownOutputPath $invalidWindowMarkdownPath `
        -FailIfNotPassed 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($invalidWindowExitCode -ne 0) "Invalid review window should be rejected."
Assert-Contains ($invalidWindowOutput | Out-String) "review-window-order" "invalid window output"
Assert-True (Test-Path -LiteralPath $invalidWindowJsonPath) "Invalid-window JSON should stay isolated under the self-test output directory."

Write-Host "Cluster network access review evidence verification passed: $passedJsonPath"
exit 0
