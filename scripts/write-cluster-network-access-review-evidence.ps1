param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $ReviewStartedAt = "",
    [string] $ReviewCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $NetworkPolicyManifestPath = ".\infra\k8s\networkpolicy.yaml",
    [string] $HelmValuesPath = ".\infra\helm\osmu\values.yaml",
    [string] $HelmNetworkPolicyTemplatePath = ".\infra\helm\osmu\templates\networkpolicy.yaml",
    [string] $DnsEgressReviewRef = "",
    [string] $MariaDbAccessReviewRef = "",
    [string] $MinioAccessReviewRef = "",
    [string] $BackupAccessReviewRef = "",
    [string] $PublicIngressReviewRef = "",
    [string] $DefaultDenyReviewRef = "",
    [string] $ObservabilityScrapeReviewRef = "",
    [string] $K8sVerifierEvidenceRef = "",
    [string] $HelmVerifierEvidenceRef = "",
    [string] $EvidenceRef = "",
    [switch] $ConfirmBackendOnlyMariaDb,
    [switch] $ConfirmBackendOnlyMinio,
    [switch] $ConfirmBackupOnlyMariaDbMinio,
    [switch] $ConfirmDnsEgressScoped,
    [switch] $ConfirmMariaDbIngressBackendBackupOnly,
    [switch] $ConfirmMinioIngressBackendBackupOnly,
    [switch] $ConfirmPublicIngressLimited,
    [switch] $ConfirmNamespaceDefaultDenyReviewed,
    [switch] $ConfirmObservabilityScrapeReviewed,
    [switch] $ConfirmHelmNetworkPolicyEnabled,
    [switch] $ConfirmNoCredentialValues,
    [string] $JsonOutputPath = ".\.osmu-run\latest-cluster-network-access-review-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-cluster-network-access-review-evidence.md",
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return [System.IO.Path]::GetFullPath($PathValue) }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-SafeText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b",
        "(?i)\b(password|passwd|secret|token|credential|client_secret|access_key|secret_key|kubeconfig)\s*[=:]\s*\S+"
    )
    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) { throw "$Label appears to contain credential material. Store only a non-secret evidence reference." }
    }
}

function Get-ParsedDateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($Value, [ref] $parsed)) { return $parsed }
    return $null
}

function Test-DateText([string] $Value) { return $null -ne (Get-ParsedDateText $Value) }

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail, [string] $EvidenceRef = "") {
    [void] $script:checks.Add([ordered]@{
        id = $Id
        name = $Name
        status = if ($Passed) { "PASS" } else { "FAIL" }
        passed = $Passed
        detail = $Detail
        evidenceRef = $EvidenceRef
    })
}

function Read-Snapshot([string] $PathValue, [string] $Id) {
    $resolved = Resolve-ProjectPath $PathValue
    $exists = Test-Path -LiteralPath $resolved
    $text = ""
    $sha256 = ""
    $byteCount = 0
    if ($exists) {
        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $byteCount = $bytes.Length
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $sha256 = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLowerInvariant() }
        finally { $sha.Dispose() }
        $text = [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
    }
    Add-Check "$Id-present" "$Id exists" $exists "$Id path: $resolved" $resolved
    return [ordered]@{ path = $resolved; exists = $exists; byteCount = $byteCount; sha256 = $sha256; text = $text }
}

function Has([string] $Text, [string] $Needle) { return (-not [string]::IsNullOrEmpty($Text)) -and $Text.Contains($Needle) }
function NoBroadCidr([string] $Text) { return (-not [string]::IsNullOrEmpty($Text)) -and -not ($Text -match "0\.0\.0\.0/0|::/0") }

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName), @("TargetCluster", $TargetCluster), @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef), @("DnsEgressReviewRef", $DnsEgressReviewRef),
    @("MariaDbAccessReviewRef", $MariaDbAccessReviewRef), @("MinioAccessReviewRef", $MinioAccessReviewRef),
    @("BackupAccessReviewRef", $BackupAccessReviewRef), @("PublicIngressReviewRef", $PublicIngressReviewRef),
    @("DefaultDenyReviewRef", $DefaultDenyReviewRef), @("ObservabilityScrapeReviewRef", $ObservabilityScrapeReviewRef),
    @("K8sVerifierEvidenceRef", $K8sVerifierEvidenceRef), @("HelmVerifierEvidenceRef", $HelmVerifierEvidenceRef),
    @("EvidenceRef", $EvidenceRef)
)) { Assert-SafeText ([string] $entry[1]) ([string] $entry[0]) }

$k8sSnapshot = Read-Snapshot $NetworkPolicyManifestPath "networkpolicy-manifest"
$helmValuesSnapshot = Read-Snapshot $HelmValuesPath "helm-values"
$helmTemplateSnapshot = Read-Snapshot $HelmNetworkPolicyTemplatePath "helm-networkpolicy-template"
$k8s = [string] $k8sSnapshot.text
$helmValues = [string] $helmValuesSnapshot.text
$helmTemplate = [string] $helmTemplateSnapshot.text

$requiredPolicyNames = (Has $k8s "kind: NetworkPolicy") -and (Has $k8s "name: osmu-backend-egress") -and (Has $k8s "name: osmu-backup-egress") -and (Has $k8s "name: osmu-mariadb-ingress") -and (Has $k8s "name: osmu-minio-ingress")
$backendEgressScoped = (Has $k8s "name: osmu-backend-egress") -and (Has $k8s "app.kubernetes.io/name: osmu-mariadb") -and (Has $k8s "app.kubernetes.io/name: osmu-minio") -and (Has $k8s "port: 3306") -and (Has $k8s "port: 9000")
$backupEgressScoped = (Has $k8s "name: osmu-backup-egress") -and (Has $k8s "app.kubernetes.io/name: osmu-backup") -and (Has $k8s "port: 3306") -and (Has $k8s "port: 9000")
$dnsEgressScoped = (Has $k8s "kubernetes.io/metadata.name: kube-system") -and (Has $k8s "k8s-app: kube-dns") -and (Has $k8s "port: 53")
$mariaDbIngressScoped = (Has $k8s "name: osmu-mariadb-ingress") -and (Has $k8s "app.kubernetes.io/name: osmu-backend") -and (Has $k8s "app.kubernetes.io/name: osmu-backup") -and (Has $k8s "port: 3306")
$minioIngressScoped = (Has $k8s "name: osmu-minio-ingress") -and (Has $k8s "app.kubernetes.io/name: osmu-backend") -and (Has $k8s "app.kubernetes.io/name: osmu-backup") -and (Has $k8s "port: 9000")
$helmNetworkPolicyEnabled = ($helmValues -match "(?ms)networkPolicy:\s*\r?\n\s*enabled:\s*true") -and (Has $helmTemplate "{{- if .Values.networkPolicy.enabled }}") -and (Has $helmTemplate ".Values.networkPolicy.dns.namespaceName") -and (Has $helmTemplate ".Values.networkPolicy.dns.podLabelKey") -and (Has $helmTemplate ".Values.networkPolicy.dns.podLabelValue")
$noBroadCidr = (NoBroadCidr $k8s) -and (NoBroadCidr $helmTemplate)

Add-Check "networkpolicy-names-present" "Required NetworkPolicy names are present" $requiredPolicyNames "Expected backend/backup egress and MariaDB/MinIO ingress policies." $k8sSnapshot.path
Add-Check "backend-egress-static-scope" "Backend egress static scope is limited" $backendEgressScoped "Backend egress should target MariaDB 3306, MinIO 9000, and DNS 53 only." $k8sSnapshot.path
Add-Check "backup-egress-static-scope" "Backup egress static scope is limited" $backupEgressScoped "Backup egress should target MariaDB 3306, MinIO 9000, and DNS 53 only." $k8sSnapshot.path
Add-Check "dns-egress-static-scope" "DNS egress static scope is explicit" $dnsEgressScoped "DNS egress should be scoped to kube-system/kube-dns on 53." $k8sSnapshot.path
Add-Check "mariadb-ingress-static-scope" "MariaDB ingress static scope is limited" $mariaDbIngressScoped "MariaDB ingress should allow backend and backup on 3306." $k8sSnapshot.path
Add-Check "minio-ingress-static-scope" "MinIO ingress static scope is limited" $minioIngressScoped "MinIO ingress should allow backend and backup on 9000." $k8sSnapshot.path
Add-Check "networkpolicy-no-broad-cidr" "NetworkPolicy does not include broad CIDR" $noBroadCidr "Reviewed NetworkPolicy text must not include 0.0.0.0/0 or ::/0." $k8sSnapshot.path
Add-Check "helm-networkpolicy-static-enabled" "Helm NetworkPolicy is enabled by default" $helmNetworkPolicyEnabled "Helm values should enable networkPolicy and render DNS selector values through chart values." $helmValuesSnapshot.path

$started = Get-ParsedDateText $ReviewStartedAt
$completed = Get-ParsedDateText $ReviewCompletedAt
$windowOrdered = $null -ne $started -and $null -ne $completed -and $completed -ge $started
$hasInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ReviewStartedAt + $ReviewCompletedAt + $ChangeApprovalRef + $DnsEgressReviewRef + $MariaDbAccessReviewRef + $MinioAccessReviewRef + $BackupAccessReviewRef + $PublicIngressReviewRef + $DefaultDenyReviewRef + $ObservabilityScrapeReviewRef + $K8sVerifierEvidenceRef + $HelmVerifierEvidenceRef + $EvidenceRef) -or $ConfirmBackendOnlyMariaDb -or $ConfirmBackendOnlyMinio -or $ConfirmBackupOnlyMariaDbMinio -or $ConfirmDnsEgressScoped -or $ConfirmMariaDbIngressBackendBackupOnly -or $ConfirmMinioIngressBackendBackupOnly -or $ConfirmPublicIngressLimited -or $ConfirmNamespaceDefaultDenyReviewed -or $ConfirmObservabilityScrapeReviewed -or $ConfirmHelmNetworkPolicyEnabled -or $ConfirmNoCredentialValues

Add-Check "environment-name-present" "Environment name supplied" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "Target environment is required."
Add-Check "target-cluster-present" "Target cluster supplied" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "Target cluster label is required."
Add-Check "operator-present" "Operator supplied" (-not [string]::IsNullOrWhiteSpace($Operator)) "Operator/reviewer identity is required."
Add-Check "review-started-at-valid" "Review start timestamp is valid" (Test-DateText $ReviewStartedAt) "ReviewStartedAt must be parseable."
Add-Check "review-completed-at-valid" "Review completion timestamp is valid" (Test-DateText $ReviewCompletedAt) "ReviewCompletedAt must be parseable."
Add-Check "review-window-order" "Review window is ordered" $windowOrdered "ReviewCompletedAt must be equal to or after ReviewStartedAt."
Add-Check "change-approval-present" "Change approval reference supplied" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "Change approval or review ticket reference is required." $ChangeApprovalRef
Add-Check "dns-review-ref-present" "DNS egress review reference supplied" (-not [string]::IsNullOrWhiteSpace($DnsEgressReviewRef)) "DNS egress review reference is required." $DnsEgressReviewRef
Add-Check "mariadb-review-ref-present" "MariaDB access review reference supplied" (-not [string]::IsNullOrWhiteSpace($MariaDbAccessReviewRef)) "MariaDB ingress/egress review reference is required." $MariaDbAccessReviewRef
Add-Check "minio-review-ref-present" "MinIO access review reference supplied" (-not [string]::IsNullOrWhiteSpace($MinioAccessReviewRef)) "MinIO ingress/egress review reference is required." $MinioAccessReviewRef
Add-Check "backup-review-ref-present" "Backup access review reference supplied" (-not [string]::IsNullOrWhiteSpace($BackupAccessReviewRef)) "Backup workload access review reference is required." $BackupAccessReviewRef
Add-Check "public-ingress-review-ref-present" "Public ingress review reference supplied" (-not [string]::IsNullOrWhiteSpace($PublicIngressReviewRef)) "Ingress/TLS public exposure review reference is required." $PublicIngressReviewRef
Add-Check "default-deny-review-ref-present" "Namespace default-deny behavior reviewed" (-not [string]::IsNullOrWhiteSpace($DefaultDenyReviewRef)) "Namespace default-deny behavior or tracked exception reference is required." $DefaultDenyReviewRef
Add-Check "observability-review-ref-present" "Observability scrape review reference supplied" (-not [string]::IsNullOrWhiteSpace($ObservabilityScrapeReviewRef)) "Prometheus/monitoring scrape access review reference is required." $ObservabilityScrapeReviewRef
Add-Check "evidence-ref-present" "Evidence reference supplied" (-not [string]::IsNullOrWhiteSpace($EvidenceRef)) "External or internal evidence reference is required." $EvidenceRef
Add-Check "backend-mariadb-review-confirmed" "Backend to MariaDB access confirmed" (([bool] $ConfirmBackendOnlyMariaDb)) "Operator must confirm backend MariaDB access is scoped."
Add-Check "backend-minio-review-confirmed" "Backend to MinIO access confirmed" (([bool] $ConfirmBackendOnlyMinio)) "Operator must confirm backend MinIO access is scoped."
Add-Check "backup-store-review-confirmed" "Backup to data stores access confirmed" (([bool] $ConfirmBackupOnlyMariaDbMinio)) "Operator must confirm backup data-store access is scoped."
Add-Check "dns-egress-review-confirmed" "DNS egress scope confirmed" (([bool] $ConfirmDnsEgressScoped)) "Operator must confirm DNS egress is scoped to cluster DNS."
Add-Check "mariadb-ingress-review-confirmed" "MariaDB ingress scope confirmed" (([bool] $ConfirmMariaDbIngressBackendBackupOnly)) "Operator must confirm MariaDB ingress is limited to backend and backup."
Add-Check "minio-ingress-review-confirmed" "MinIO ingress scope confirmed" (([bool] $ConfirmMinioIngressBackendBackupOnly)) "Operator must confirm MinIO ingress is limited to backend and backup."
Add-Check "public-ingress-review-confirmed" "Public ingress scope confirmed" (([bool] $ConfirmPublicIngressLimited)) "Operator must confirm public ingress is limited to approved ingress/TLS boundary."
Add-Check "namespace-default-deny-reviewed" "Namespace default-deny behavior confirmed" (([bool] $ConfirmNamespaceDefaultDenyReviewed)) "Operator must confirm default-deny behavior or tracked gap/exception has been reviewed."
Add-Check "observability-scrape-reviewed" "Observability scrape scope confirmed" (([bool] $ConfirmObservabilityScrapeReviewed)) "Operator must confirm metrics scraping scope is reviewed."
Add-Check "helm-networkpolicy-review-confirmed" "Helm NetworkPolicy enablement confirmed" (([bool] $ConfirmHelmNetworkPolicyEnabled)) "Operator must confirm Helm networkPolicy.enabled remains true."
Add-Check "no-credential-values-confirmed" "No credential values included" (([bool] $ConfirmNoCredentialValues)) "Operator must confirm evidence references contain no kubeconfig, token, password, private key, or secret value."

$passCount = @($checks | Where-Object { $_.passed }).Count
$failureCount = @($checks | Where-Object { -not $_.passed }).Count
$result = if ($failureCount -eq 0) { "passed" } elseif ($hasInput) { "failed" } else { "planned" }
function New-OrderedDictionary() { return New-Object System.Collections.Specialized.OrderedDictionary }

$reviewWindow = New-OrderedDictionary
$reviewWindow.Add("startedAt", $ReviewStartedAt)
$reviewWindow.Add("completedAt", $ReviewCompletedAt)
$reviewWindow.Add("ordered", $windowOrdered)

$evidence = New-OrderedDictionary
$evidence.Add("changeApprovalRef", $ChangeApprovalRef)
$evidence.Add("dnsEgressReviewRef", $DnsEgressReviewRef)
$evidence.Add("mariaDbAccessReviewRef", $MariaDbAccessReviewRef)
$evidence.Add("minioAccessReviewRef", $MinioAccessReviewRef)
$evidence.Add("backupAccessReviewRef", $BackupAccessReviewRef)
$evidence.Add("publicIngressReviewRef", $PublicIngressReviewRef)
$evidence.Add("defaultDenyReviewRef", $DefaultDenyReviewRef)
$evidence.Add("observabilityScrapeReviewRef", $ObservabilityScrapeReviewRef)
$evidence.Add("k8sVerifierEvidenceRef", $K8sVerifierEvidenceRef)
$evidence.Add("helmVerifierEvidenceRef", $HelmVerifierEvidenceRef)
$evidence.Add("evidenceRef", $EvidenceRef)

$staticControlSnapshot = New-OrderedDictionary
$staticControlSnapshot.Add("networkPolicyManifestPath", $k8sSnapshot["path"])
$staticControlSnapshot.Add("networkPolicyManifestSha256", $k8sSnapshot["sha256"])
$staticControlSnapshot.Add("helmValuesPath", $helmValuesSnapshot["path"])
$staticControlSnapshot.Add("helmValuesSha256", $helmValuesSnapshot["sha256"])
$staticControlSnapshot.Add("helmNetworkPolicyTemplatePath", $helmTemplateSnapshot["path"])
$staticControlSnapshot.Add("helmNetworkPolicyTemplateSha256", $helmTemplateSnapshot["sha256"])
$staticControlSnapshot.Add("requiredPolicyNamesPresent", $requiredPolicyNames)
$staticControlSnapshot.Add("backendEgressScoped", $backendEgressScoped)
$staticControlSnapshot.Add("backupEgressScoped", $backupEgressScoped)
$staticControlSnapshot.Add("dnsEgressScoped", $dnsEgressScoped)
$staticControlSnapshot.Add("mariaDbIngressScoped", $mariaDbIngressScoped)
$staticControlSnapshot.Add("minioIngressScoped", $minioIngressScoped)
$staticControlSnapshot.Add("noBroadCidr", $noBroadCidr)
$staticControlSnapshot.Add("helmNetworkPolicyEnabled", $helmNetworkPolicyEnabled)

$confirmations = New-OrderedDictionary
$confirmations.Add("backendOnlyMariaDb", ([bool] $ConfirmBackendOnlyMariaDb))
$confirmations.Add("backendOnlyMinio", ([bool] $ConfirmBackendOnlyMinio))
$confirmations.Add("backupOnlyMariaDbMinio", ([bool] $ConfirmBackupOnlyMariaDbMinio))
$confirmations.Add("dnsEgressScoped", ([bool] $ConfirmDnsEgressScoped))
$confirmations.Add("mariaDbIngressBackendBackupOnly", ([bool] $ConfirmMariaDbIngressBackendBackupOnly))
$confirmations.Add("minioIngressBackendBackupOnly", ([bool] $ConfirmMinioIngressBackendBackupOnly))
$confirmations.Add("publicIngressLimited", ([bool] $ConfirmPublicIngressLimited))
$confirmations.Add("namespaceDefaultDenyReviewed", ([bool] $ConfirmNamespaceDefaultDenyReviewed))
$confirmations.Add("observabilityScrapeReviewed", ([bool] $ConfirmObservabilityScrapeReviewed))
$confirmations.Add("helmNetworkPolicyEnabled", ([bool] $ConfirmHelmNetworkPolicyEnabled))
$confirmations.Add("noCredentialValues", ([bool] $ConfirmNoCredentialValues))

$summary = New-OrderedDictionary
$summary.Add("passCount", $passCount)
$summary.Add("failureCount", $failureCount)
$summary.Add("totalCount", $checks.Count)

$report = New-OrderedDictionary
$report.Add("formatVersion", "osmu.cluster-network-access-review-evidence.v1")
$report.Add("generatedAt", [DateTimeOffset]::UtcNow.ToString("o"))
$report.Add("result", $result)
$report.Add("environmentName", $EnvironmentName)
$report.Add("targetCluster", $TargetCluster)
$report.Add("operator", $Operator)
$report.Add("reviewWindow", $reviewWindow)
$report.Add("evidence", $evidence)
$report.Add("staticControlSnapshot", $staticControlSnapshot)
$report.Add("confirmations", $confirmations)
$report.Add("summary", $summary)
$checkSnapshot = New-Object System.Collections.ArrayList
foreach ($check in $checks) { [void] $checkSnapshot.Add($check) }
$report.Add("checks", $checkSnapshot)
$report.Add("scopePolicy", "Reviews static Kubernetes/Helm NetworkPolicy and operator-approved access references; it does not execute kubectl or prove live CNI enforcement.")
$report.Add("secretPolicy", "Evidence must contain references only, never kubeconfig, bearer tokens, passwords, private keys, access keys, or raw secret values.")
$report.Add("decisionRule", "Production/B2B cluster network access review requires result=passed, zero failed checks, current static manifest hashes, and typed operator confirmations.")
$lines = @("# Cluster Network Access Review Evidence", "", "- Result: $result", "- Environment: $EnvironmentName", "- Target cluster: $TargetCluster", "- Operator: $Operator", "- Review window: $ReviewStartedAt to $ReviewCompletedAt", "- Change approval: $ChangeApprovalRef", "- Evidence ref: $EvidenceRef", "", "## Static Control Snapshot", "", "- requiredPolicyNamesPresent: $requiredPolicyNames", "- backendEgressScoped: $backendEgressScoped", "- backupEgressScoped: $backupEgressScoped", "- dnsEgressScoped: $dnsEgressScoped", "- mariaDbIngressScoped: $mariaDbIngressScoped", "- minioIngressScoped: $minioIngressScoped", "- noBroadCidr: $noBroadCidr", "- helmNetworkPolicyEnabled: $helmNetworkPolicyEnabled", "", "## Checks", "")
foreach ($check in $checks) { $lines += "- [$($check.status)] $($check.id): $($check.detail)" }
$lines += @("", "## Policy", "", "- Scope: $($report["scopePolicy"])", "- Secret handling: $($report["secretPolicy"])", "- Decision: $($report["decisionRule"])")
$markdown = ($lines -join [Environment]::NewLine) + [Environment]::NewLine

if (-not $NoWrite) {
    $jsonPath = Resolve-ProjectPath $JsonOutputPath
    $mdPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $mdPath) | Out-Null
    $report | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $jsonPath
    $markdown | Set-Content -Encoding UTF8 -LiteralPath $mdPath
    Write-Host "Cluster network access review evidence written: $jsonPath"
    Write-Host "Cluster network access review markdown written: $mdPath"
}
else { Write-Host "Cluster network access review evidence result: $result" }

if ($FailIfNotPassed -and $result -ne "passed") {
    $failed = @($checks | Where-Object { -not $_.passed } | ForEach-Object { $_.id }) -join ", "
    throw "Cluster network access review evidence did not pass: result=$result; failed=$failed"
}

return $report