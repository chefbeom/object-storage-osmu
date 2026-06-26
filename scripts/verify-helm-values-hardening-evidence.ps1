param(
    [string] $OutputDirectory = ".\.osmu-run\helm-values-hardening-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return [System.IO.Path]::GetFullPath($PathValue) }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
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

$scriptPath = Resolve-ProjectPath ".\scripts\write-helm-values-hardening-evidence.ps1"
$plannedJsonPath = Join-Path $resolvedOutputDirectory "planned.json"
$plannedMarkdownPath = Join-Path $resolvedOutputDirectory "planned.md"
$passedJsonPath = Join-Path $resolvedOutputDirectory "passed.json"
$passedMarkdownPath = Join-Path $resolvedOutputDirectory "passed.md"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -JsonOutputPath $plannedJsonPath `
    -MarkdownOutputPath $plannedMarkdownPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw "planned write-helm-values-hardening-evidence.ps1 failed with exit code $LASTEXITCODE." }

$plannedReport = Get-Content -Raw -LiteralPath $plannedJsonPath | ConvertFrom-Json
$plannedMarkdown = Get-Content -Raw -LiteralPath $plannedMarkdownPath
Assert-True ($plannedReport.formatVersion -eq "osmu.helm-values-hardening-evidence.v1") "Unexpected Helm values hardening formatVersion."
Assert-True ($plannedReport.result -eq "planned") "Default Helm values hardening evidence should be planned."
Assert-True ($plannedReport.summary.failureCount -gt 0) "Planned Helm values hardening evidence should include missing checks."
Assert-True ($plannedReport.staticHardeningSnapshot.secretsExternalized -eq $true) "Expected secrets externalization to be detected."
Assert-True ($plannedReport.staticHardeningSnapshot.networkPolicyEnabled -eq $true) "Expected networkPolicy.enabled to be detected."
Assert-True ($plannedReport.staticHardeningSnapshot.storageExpansionRbacDisabled -eq $true) "Expected storage expansion RBAC default disablement to be detected."
Assert-Contains $plannedMarkdown "Helm Values Hardening Evidence" "planned markdown"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnvironmentName "pilot-prod-self-test" `
    -TargetCluster "customer-cluster-a" `
    -Operator "platform-self-test" `
    -ReviewStartedAt "2026-06-23T01:00:00Z" `
    -ReviewCompletedAt "2026-06-23T01:25:00Z" `
    -ChangeApprovalRef "CHG-2026-HELM-HARDENING" `
    -HelmVerifierEvidenceRef "verify-helm-chart-20260623" `
    -KubernetesVerifierEvidenceRef "verify-k8s-manifests-20260623" `
    -ContainerHardeningEvidenceRef "verify-container-hardening-20260623" `
    -ClusterNetworkAccessReviewEvidenceRef "cluster-network-access-review-20260623" `
    -EvidenceRef "helm-values-hardening-20260623" `
    -ConfirmSecretsExternalized `
    -ConfirmDefaultSecretPlaceholdersNotUsed `
    -ConfirmHaReplicasReviewed `
    -ConfirmResourcesBounded `
    -ConfirmSecurityContextsReviewed `
    -ConfirmNetworkPolicyEnabled `
    -ConfirmTlsIngressReviewed `
    -ConfirmOperationsReportsReadOnly `
    -ConfirmStorageExpansionRbacDisabledByDefault `
    -ConfirmNoCredentialValues `
    -JsonOutputPath $passedJsonPath `
    -MarkdownOutputPath $passedMarkdownPath `
    -FailIfNotPassed | Out-Null
if ($LASTEXITCODE -ne 0) { throw "passed write-helm-values-hardening-evidence.ps1 failed with exit code $LASTEXITCODE." }

$reportText = Get-Content -Raw -LiteralPath $passedJsonPath
$markdown = Get-Content -Raw -LiteralPath $passedMarkdownPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)
Assert-True ($report.result -eq "passed") "Expected result=passed."
Assert-True ($report.summary.failureCount -eq 0) "Expected zero failed checks."
Assert-True ($report.staticHardeningSnapshot.secretsExternalized -eq $true) "Expected secretsExternalized=true."
Assert-True ($report.staticHardeningSnapshot.defaultSecretPlaceholdersPresent -eq $true) "Expected default placeholders to be present."
Assert-True ($report.staticHardeningSnapshot.haReplicas -eq $true) "Expected HA replicas snapshot."
Assert-True ($report.staticHardeningSnapshot.resourceBounds -eq $true) "Expected resource bounds snapshot."
Assert-True ($report.staticHardeningSnapshot.securityContexts -eq $true) "Expected security contexts snapshot."
Assert-True ($report.staticHardeningSnapshot.serviceAccountTokensDisabled -eq $true) "Expected service account token hardening snapshot."
Assert-True ($report.staticHardeningSnapshot.operationsReportsReadOnly -eq $true) "Expected read-only operations report mount snapshot."
Assert-True ($report.confirmations.noCredentialValues -eq $true) "Expected no credential confirmation."
Assert-True (@($checks | Where-Object { $_.id -eq "storage-expansion-rbac-disabled-confirmed" -and $_.passed }).Count -eq 1) "Expected storage expansion RBAC confirmation."
Assert-Contains $markdown "Static Hardening Snapshot" "passed markdown"
Assert-Contains $report.scopePolicy "does not render or apply" "Helm values JSON scope policy"
Assert-Contains $report.secretPolicy "Production secret values" "Helm values JSON secret policy"
Assert-Contains $report.decisionRule "Production/B2B Helm values hardening requires result=passed" "Helm values JSON decision rule"
foreach ($unexpected in @("password=super-secret", "Bearer abcdefghijklmnop", "-----BEGIN PRIVATE KEY-----", "kubeconfig=raw")) {
    Assert-NotContains $reportText $unexpected "Helm values JSON"
    Assert-NotContains $markdown $unexpected "Helm values markdown"
}

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
        -ReviewStartedAt "2026-06-23T01:25:00Z" `
        -ReviewCompletedAt "2026-06-23T01:00:00Z" `
        -ChangeApprovalRef "CHG-2026-HELM-HARDENING" `
        -HelmVerifierEvidenceRef "verify-helm-chart-20260623" `
        -KubernetesVerifierEvidenceRef "verify-k8s-manifests-20260623" `
        -ContainerHardeningEvidenceRef "verify-container-hardening-20260623" `
        -ClusterNetworkAccessReviewEvidenceRef "cluster-network-access-review-20260623" `
        -EvidenceRef "helm-values-hardening-20260623" `
        -ConfirmSecretsExternalized `
        -ConfirmDefaultSecretPlaceholdersNotUsed `
        -ConfirmHaReplicasReviewed `
        -ConfirmResourcesBounded `
        -ConfirmSecurityContextsReviewed `
        -ConfirmNetworkPolicyEnabled `
        -ConfirmTlsIngressReviewed `
        -ConfirmOperationsReportsReadOnly `
        -ConfirmStorageExpansionRbacDisabledByDefault `
        -ConfirmNoCredentialValues `
        -FailIfNotPassed 2>&1
    $invalidWindowExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($invalidWindowExitCode -ne 0) "Invalid review window should be rejected."
Assert-Contains ($invalidWindowOutput | Out-String) "review-window-order" "invalid window output"

$fixtureChart = Join-Path $resolvedOutputDirectory "tampered-chart"
Copy-Item -Recurse -LiteralPath (Resolve-ProjectPath ".\infra\helm\osmu") -Destination $fixtureChart
$fixtureValuesPath = Join-Path $fixtureChart "values.yaml"
$fixtureValues = Get-Content -Raw -LiteralPath $fixtureValuesPath
$fixtureValues = $fixtureValues -replace "(?ms)(networkPolicy:\s*\r?\n\s*)enabled:\s*true", '$1enabled: false'
Set-Content -Encoding UTF8 -LiteralPath $fixtureValuesPath -Value $fixtureValues

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $tamperedOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -ChartDirectory $fixtureChart `
        -EnvironmentName "pilot-prod-self-test" `
        -TargetCluster "customer-cluster-a" `
        -Operator "platform-self-test" `
        -ReviewStartedAt "2026-06-23T01:00:00Z" `
        -ReviewCompletedAt "2026-06-23T01:25:00Z" `
        -ChangeApprovalRef "CHG-2026-HELM-HARDENING" `
        -HelmVerifierEvidenceRef "verify-helm-chart-20260623" `
        -KubernetesVerifierEvidenceRef "verify-k8s-manifests-20260623" `
        -ContainerHardeningEvidenceRef "verify-container-hardening-20260623" `
        -ClusterNetworkAccessReviewEvidenceRef "cluster-network-access-review-20260623" `
        -EvidenceRef "helm-values-hardening-20260623" `
        -ConfirmSecretsExternalized `
        -ConfirmDefaultSecretPlaceholdersNotUsed `
        -ConfirmHaReplicasReviewed `
        -ConfirmResourcesBounded `
        -ConfirmSecurityContextsReviewed `
        -ConfirmNetworkPolicyEnabled `
        -ConfirmTlsIngressReviewed `
        -ConfirmOperationsReportsReadOnly `
        -ConfirmStorageExpansionRbacDisabledByDefault `
        -ConfirmNoCredentialValues `
        -FailIfNotPassed 2>&1
    $tamperedExitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $previousErrorActionPreference }
Assert-True ($tamperedExitCode -ne 0) "Tampered networkPolicy.enabled=false values should fail."
Assert-Contains ($tamperedOutput | Out-String) "network-policy-enabled" "tampered values output"

Write-Host "Helm values hardening evidence verification passed: $passedJsonPath"