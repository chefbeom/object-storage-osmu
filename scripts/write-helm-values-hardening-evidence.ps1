param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $ReviewStartedAt = "",
    [string] $ReviewCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $ChartDirectory = ".\infra\helm\osmu",
    [string] $HelmVerifierEvidenceRef = "",
    [string] $KubernetesVerifierEvidenceRef = "",
    [string] $ContainerHardeningEvidenceRef = "",
    [string] $ClusterNetworkAccessReviewEvidenceRef = "",
    [string] $EvidenceRef = "",
    [switch] $ConfirmSecretsExternalized,
    [switch] $ConfirmDefaultSecretPlaceholdersNotUsed,
    [switch] $ConfirmHaReplicasReviewed,
    [switch] $ConfirmResourcesBounded,
    [switch] $ConfirmSecurityContextsReviewed,
    [switch] $ConfirmNetworkPolicyEnabled,
    [switch] $ConfirmTlsIngressReviewed,
    [switch] $ConfirmOperationsReportsReadOnly,
    [switch] $ConfirmStorageExpansionRbacDisabledByDefault,
    [switch] $ConfirmNoCredentialValues,
    [string] $JsonOutputPath = ".\.osmu-run\latest-helm-values-hardening-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-helm-values-hardening-evidence.md",
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

function Read-ChartFile([string] $ResolvedChartDirectory, [string] $RelativePath, [string] $Id) {
    $path = Join-Path $ResolvedChartDirectory $RelativePath
    $exists = Test-Path -LiteralPath $path
    $text = ""
    $sha256 = ""
    $byteCount = 0
    if ($exists) {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $byteCount = $bytes.Length
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $sha256 = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLowerInvariant() }
        finally { $sha.Dispose() }
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    }
    Add-Check "$Id-present" "$RelativePath exists" $exists "Helm chart source path: $path" $path
    if ($exists) { Add-Check "$Id-no-tabs" "$RelativePath has no tabs" (-not $text.Contains("`t")) "Helm chart source should not contain tabs." $path }
    return [ordered]@{ relativePath = $RelativePath; path = $path; exists = $exists; byteCount = $byteCount; sha256 = $sha256; text = $text }
}

function Has([string] $Text, [string] $Needle) { return (-not [string]::IsNullOrEmpty($Text)) -and $Text.Contains($Needle) }
function Matches([string] $Text, [string] $Pattern) { return (-not [string]::IsNullOrEmpty($Text)) -and ($Text -match $Pattern) }

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName), @("TargetCluster", $TargetCluster), @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef), @("HelmVerifierEvidenceRef", $HelmVerifierEvidenceRef),
    @("KubernetesVerifierEvidenceRef", $KubernetesVerifierEvidenceRef), @("ContainerHardeningEvidenceRef", $ContainerHardeningEvidenceRef),
    @("ClusterNetworkAccessReviewEvidenceRef", $ClusterNetworkAccessReviewEvidenceRef), @("EvidenceRef", $EvidenceRef)
)) { Assert-SafeText ([string] $entry[1]) ([string] $entry[0]) }

$resolvedChartDirectory = Resolve-ProjectPath $ChartDirectory
Add-Check "chart-directory-present" "Helm chart directory exists" (Test-Path -LiteralPath $resolvedChartDirectory) "Chart directory: $resolvedChartDirectory" $resolvedChartDirectory

$chart = Read-ChartFile $resolvedChartDirectory "Chart.yaml" "chart-yaml"
$valuesSnapshot = Read-ChartFile $resolvedChartDirectory "values.yaml" "values-yaml"
$serviceAccount = Read-ChartFile $resolvedChartDirectory "templates\serviceaccount.yaml" "serviceaccount-template"
$secretTemplate = Read-ChartFile $resolvedChartDirectory "templates\secret.yaml" "secret-template"
$backendTemplate = Read-ChartFile $resolvedChartDirectory "templates\backend.yaml" "backend-template"
$frontendTemplate = Read-ChartFile $resolvedChartDirectory "templates\frontend.yaml" "frontend-template"
$backupTemplate = Read-ChartFile $resolvedChartDirectory "templates\backup.yaml" "backup-template"
$ingressTemplate = Read-ChartFile $resolvedChartDirectory "templates\ingress.yaml" "ingress-template"
$networkPolicyTemplate = Read-ChartFile $resolvedChartDirectory "templates\networkpolicy.yaml" "networkpolicy-template"
$storageExpansionRbacTemplate = Read-ChartFile $resolvedChartDirectory "templates\storage-expansion-rbac.yaml" "storage-expansion-rbac-template"

$values = [string] $valuesSnapshot.text
$secretText = [string] $secretTemplate.text
$backendText = [string] $backendTemplate.text
$frontendText = [string] $frontendTemplate.text
$backupText = [string] $backupTemplate.text
$ingressText = [string] $ingressTemplate.text
$networkPolicyText = [string] $networkPolicyTemplate.text
$storageExpansionRbacText = [string] $storageExpansionRbacTemplate.text
$serviceAccountText = [string] $serviceAccount.text

$secretsExternalized = (Matches $values "(?ms)secrets:\s*\r?\n\s*create:\s*false") -and (Has $secretText "{{- if .Values.secrets.create }}") -and (Has $values "name: osmu-secret")
$placeholderValuesPresent = (Has $values "mariadbPassword: change-me") -and (Has $values "mariadbRootPassword: change-me") -and (Has $values "minioRootPassword: change-me") -and (Has $values "adminPassword: change-me") -and (Has $values "jwtSecret: change-me-at-least-32-bytes") -and (Has $values "accessKeySecretEncryptionKey: change-me-32-byte-key")
$haReplicas = (Matches $values "(?m)^backend:\s*\r?\n\s*replicas:\s*2") -and (Matches $values "(?m)^frontend:\s*\r?\n\s*replicas:\s*2") -and (Has $values "podDisruptionBudgets:") -and (Has $values "topologySpread:")
$resourceBounds = (Has $values "backend:") -and (Has $values "frontend:") -and (Has $values "mariadb:") -and (Has $values "minio:") -and (Has $values "backup:") -and (@($values -split "requests:").Count -ge 6) -and (@($values -split "limits:").Count -ge 6)
$securityContexts = (Has $values "runAsNonRoot: true") -and (Has $values "allowPrivilegeEscalation: false") -and (Has $values "seccompProfile:") -and (Has $values "type: RuntimeDefault") -and (Has $values "drop:") -and (Has $values "- ALL") -and (Has $backendText ".Values.backend.podSecurityContext") -and (Has $backendText ".Values.backend.containerSecurityContext") -and (Has $frontendText ".Values.frontend.podSecurityContext") -and (Has $frontendText ".Values.frontend.containerSecurityContext") -and (Has $backupText ".Values.backup.containerSecurityContext")
$serviceAccountTokensDisabled = (Has $serviceAccountText "automountServiceAccountToken: false") -and (Has $backendText "automountServiceAccountToken: false") -and (Has $frontendText "automountServiceAccountToken: false") -and (Has $backupText "automountServiceAccountToken: false")
$networkPolicyEnabled = (Matches $values "(?ms)networkPolicy:\s*\r?\n\s*enabled:\s*true") -and (Has $networkPolicyText "{{- if .Values.networkPolicy.enabled }}") -and (Has $networkPolicyText ".Values.networkPolicy.dns.namespaceName")
$tlsIngress = (Has $values 'nginx.ingress.kubernetes.io/ssl-redirect: "true"') -and (Has $values 'nginx.ingress.kubernetes.io/force-ssl-redirect: "true"') -and (Has $values "secretName: osmu-tls") -and (Has $ingressText "tls:")
$operationsReportsReadOnly = (Matches $values "(?ms)operationsReports:\s*\r?\n\s*enabled:\s*true") -and (Has $values "type: configMap") -and (Has $values "configMapName: osmu-operations-reports") -and (Has $values "optional: true") -and (Has $backendText "readOnly: true")
$storageExpansionRbacDisabled = (Has $values "storageExpansion:") -and (Has $values "runner:") -and (Has $values "rbac:") -and (Has $values "enabled: false") -and (Has $storageExpansionRbacText "{{- if .Values.storageExpansion.runner.rbac.enabled }}") -and (-not $storageExpansionRbacText.Contains("- delete")) -and (-not $storageExpansionRbacText.Contains("- create")) -and (-not $storageExpansionRbacText.Contains("pods/exec"))

Add-Check "secrets-externalized" "Secrets are externalized by default" $secretsExternalized "secrets.create must remain false and the Secret template must be conditional." $valuesSnapshot.path
Add-Check "default-secret-placeholders" "Default secret values are placeholders only" $placeholderValuesPresent "Default secret values must remain change-me placeholders and not production credentials." $valuesSnapshot.path
Add-Check "ha-replicas-reviewed" "HA replica defaults and PDB/topology settings exist" $haReplicas "Backend/frontend replicas, PDBs, and topology spread defaults should be present." $valuesSnapshot.path
Add-Check "resource-bounds-present" "Resource requests and limits are present" $resourceBounds "Backend, frontend, MariaDB, MinIO, and backup workloads should carry requests/limits." $valuesSnapshot.path
Add-Check "security-contexts-present" "Security contexts are wired" $securityContexts "Pod/container security contexts should use non-root, RuntimeDefault seccomp, no privilege escalation, and drop ALL capabilities where chart values apply." $valuesSnapshot.path
Add-Check "service-account-tokens-disabled" "Service account tokens are disabled" $serviceAccountTokensDisabled "ServiceAccounts and workload pods should disable automountServiceAccountToken." $serviceAccount.path
Add-Check "network-policy-enabled" "NetworkPolicy is enabled by default" $networkPolicyEnabled "networkPolicy.enabled should be true and the template should render DNS selector values." $valuesSnapshot.path
Add-Check "tls-ingress-enabled" "TLS ingress hardening is present" $tlsIngress "Ingress defaults should force SSL redirect and use osmu-tls." $valuesSnapshot.path
Add-Check "operations-reports-read-only" "Operations report mount is read-only" $operationsReportsReadOnly "Backend operations report mount should default to ConfigMap, optional, and readOnly." $backendTemplate.path
Add-Check "storage-expansion-rbac-disabled" "Storage expansion RBAC is disabled by default" $storageExpansionRbacDisabled "In-cluster storage expansion RBAC should be opt-in and avoid create/delete/secret/pod-exec grants." $storageExpansionRbacTemplate.path

$started = Get-ParsedDateText $ReviewStartedAt
$completed = Get-ParsedDateText $ReviewCompletedAt
$windowOrdered = $null -ne $started -and $null -ne $completed -and $completed -ge $started
$hasInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ReviewStartedAt + $ReviewCompletedAt + $ChangeApprovalRef + $HelmVerifierEvidenceRef + $KubernetesVerifierEvidenceRef + $ContainerHardeningEvidenceRef + $ClusterNetworkAccessReviewEvidenceRef + $EvidenceRef) -or $ConfirmSecretsExternalized -or $ConfirmDefaultSecretPlaceholdersNotUsed -or $ConfirmHaReplicasReviewed -or $ConfirmResourcesBounded -or $ConfirmSecurityContextsReviewed -or $ConfirmNetworkPolicyEnabled -or $ConfirmTlsIngressReviewed -or $ConfirmOperationsReportsReadOnly -or $ConfirmStorageExpansionRbacDisabledByDefault -or $ConfirmNoCredentialValues

Add-Check "environment-name-present" "Environment name supplied" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "Target environment is required."
Add-Check "target-cluster-present" "Target cluster supplied" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "Target cluster label is required."
Add-Check "operator-present" "Operator supplied" (-not [string]::IsNullOrWhiteSpace($Operator)) "Operator/reviewer identity is required."
Add-Check "review-started-at-valid" "Review start timestamp is valid" (Test-DateText $ReviewStartedAt) "ReviewStartedAt must be parseable."
Add-Check "review-completed-at-valid" "Review completion timestamp is valid" (Test-DateText $ReviewCompletedAt) "ReviewCompletedAt must be parseable."
Add-Check "review-window-order" "Review window is ordered" $windowOrdered "ReviewCompletedAt must be equal to or after ReviewStartedAt."
Add-Check "change-approval-present" "Change approval reference supplied" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "Change approval or review ticket reference is required." $ChangeApprovalRef
Add-Check "helm-verifier-ref-present" "Helm verifier evidence reference supplied" (-not [string]::IsNullOrWhiteSpace($HelmVerifierEvidenceRef)) "Helm verifier evidence reference is required." $HelmVerifierEvidenceRef
Add-Check "kubernetes-verifier-ref-present" "Kubernetes verifier evidence reference supplied" (-not [string]::IsNullOrWhiteSpace($KubernetesVerifierEvidenceRef)) "Kubernetes verifier evidence reference is required." $KubernetesVerifierEvidenceRef
Add-Check "container-hardening-ref-present" "Container hardening evidence reference supplied" (-not [string]::IsNullOrWhiteSpace($ContainerHardeningEvidenceRef)) "Container hardening verifier reference is required." $ContainerHardeningEvidenceRef
Add-Check "network-review-ref-present" "Cluster network access review evidence reference supplied" (-not [string]::IsNullOrWhiteSpace($ClusterNetworkAccessReviewEvidenceRef)) "Cluster network access review evidence reference is required." $ClusterNetworkAccessReviewEvidenceRef
Add-Check "evidence-ref-present" "Evidence reference supplied" (-not [string]::IsNullOrWhiteSpace($EvidenceRef)) "External or internal evidence reference is required." $EvidenceRef

Add-Check "secrets-externalized-confirmed" "Secrets externalization confirmed" (([bool] $ConfirmSecretsExternalized)) "Operator must confirm production values use external secret material."
Add-Check "default-secret-placeholders-confirmed" "Default placeholders not used confirmed" (([bool] $ConfirmDefaultSecretPlaceholdersNotUsed)) "Operator must confirm production deploys do not use change-me placeholders."
Add-Check "ha-replicas-confirmed" "HA replica review confirmed" (([bool] $ConfirmHaReplicasReviewed)) "Operator must confirm HA replica/PDB/topology settings are reviewed."
Add-Check "resource-bounds-confirmed" "Resource bounds review confirmed" (([bool] $ConfirmResourcesBounded)) "Operator must confirm workload resources are reviewed for the target cluster."
Add-Check "security-contexts-confirmed" "Security context review confirmed" (([bool] $ConfirmSecurityContextsReviewed)) "Operator must confirm security contexts are reviewed."
Add-Check "network-policy-confirmed" "NetworkPolicy enablement confirmed" (([bool] $ConfirmNetworkPolicyEnabled)) "Operator must confirm networkPolicy.enabled remains true."
Add-Check "tls-ingress-confirmed" "TLS ingress review confirmed" (([bool] $ConfirmTlsIngressReviewed)) "Operator must confirm TLS/ingress settings are reviewed."
Add-Check "operations-reports-read-only-confirmed" "Operations reports read-only mount confirmed" (([bool] $ConfirmOperationsReportsReadOnly)) "Operator must confirm operations report mount stays read-only."
Add-Check "storage-expansion-rbac-disabled-confirmed" "Storage expansion RBAC opt-in confirmed" (([bool] $ConfirmStorageExpansionRbacDisabledByDefault)) "Operator must confirm in-cluster storage expansion RBAC stays disabled unless explicitly approved."
Add-Check "no-credential-values-confirmed" "No credential values included" (([bool] $ConfirmNoCredentialValues)) "Operator must confirm references contain no kubeconfig, token, password, private key, or secret value."

$passCount = @($checks | Where-Object { $_.passed }).Count
$failureCount = @($checks | Where-Object { -not $_.passed }).Count
$result = if ($failureCount -eq 0) { "passed" } elseif ($hasInput) { "failed" } else { "planned" }
$checkSnapshot = New-Object System.Collections.ArrayList
foreach ($check in $checks) { [void] $checkSnapshot.Add($check) }
$fileSnapshots = New-Object System.Collections.ArrayList
foreach ($snapshot in @($chart, $valuesSnapshot, $serviceAccount, $secretTemplate, $backendTemplate, $frontendTemplate, $backupTemplate, $ingressTemplate, $networkPolicyTemplate, $storageExpansionRbacTemplate)) {
    [void] $fileSnapshots.Add([ordered]@{ relativePath = $snapshot.relativePath; path = $snapshot.path; exists = $snapshot.exists; byteCount = $snapshot.byteCount; sha256 = $snapshot.sha256 })
}

$report = [ordered]@{
    formatVersion = "osmu.helm-values-hardening-evidence.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    result = $result
    environmentName = $EnvironmentName
    targetCluster = $TargetCluster
    operator = $Operator
    reviewWindow = [ordered]@{ startedAt = $ReviewStartedAt; completedAt = $ReviewCompletedAt; ordered = $windowOrdered }
    evidence = [ordered]@{ changeApprovalRef = $ChangeApprovalRef; helmVerifierEvidenceRef = $HelmVerifierEvidenceRef; kubernetesVerifierEvidenceRef = $KubernetesVerifierEvidenceRef; containerHardeningEvidenceRef = $ContainerHardeningEvidenceRef; clusterNetworkAccessReviewEvidenceRef = $ClusterNetworkAccessReviewEvidenceRef; evidenceRef = $EvidenceRef }
    chartSnapshot = [ordered]@{ chartDirectory = $resolvedChartDirectory; files = $fileSnapshots }
    staticHardeningSnapshot = [ordered]@{ secretsExternalized = $secretsExternalized; defaultSecretPlaceholdersPresent = $placeholderValuesPresent; haReplicas = $haReplicas; resourceBounds = $resourceBounds; securityContexts = $securityContexts; serviceAccountTokensDisabled = $serviceAccountTokensDisabled; networkPolicyEnabled = $networkPolicyEnabled; tlsIngress = $tlsIngress; operationsReportsReadOnly = $operationsReportsReadOnly; storageExpansionRbacDisabled = $storageExpansionRbacDisabled }
    confirmations = [ordered]@{ secretsExternalized = ([bool] $ConfirmSecretsExternalized); defaultSecretPlaceholdersNotUsed = ([bool] $ConfirmDefaultSecretPlaceholdersNotUsed); haReplicasReviewed = ([bool] $ConfirmHaReplicasReviewed); resourcesBounded = ([bool] $ConfirmResourcesBounded); securityContextsReviewed = ([bool] $ConfirmSecurityContextsReviewed); networkPolicyEnabled = ([bool] $ConfirmNetworkPolicyEnabled); tlsIngressReviewed = ([bool] $ConfirmTlsIngressReviewed); operationsReportsReadOnly = ([bool] $ConfirmOperationsReportsReadOnly); storageExpansionRbacDisabledByDefault = ([bool] $ConfirmStorageExpansionRbacDisabledByDefault); noCredentialValues = ([bool] $ConfirmNoCredentialValues) }
    summary = [ordered]@{ passCount = $passCount; failureCount = $failureCount; totalCount = $checks.Count }
    checks = $checkSnapshot
    scopePolicy = "Reviews static Helm values/templates and operator-approved hardening references; it does not render or apply the chart and does not prove live cluster admission/enforcement."
    secretPolicy = "Evidence stores references and file hashes only. Production secret values, kubeconfig, bearer tokens, private keys, or raw credentials must never be embedded."
    decisionRule = "Production/B2B Helm values hardening requires result=passed, zero failed checks, current chart hashes, and typed operator confirmations."
}

$lines = @(
    "# Helm Values Hardening Evidence",
    "",
    "- Result: $result",
    "- Environment: $EnvironmentName",
    "- Target cluster: $TargetCluster",
    "- Operator: $Operator",
    "- Review window: $ReviewStartedAt to $ReviewCompletedAt",
    "- Change approval: $ChangeApprovalRef",
    "- Evidence ref: $EvidenceRef",
    "- Chart directory: $resolvedChartDirectory",
    "",
    "## Static Hardening Snapshot",
    "",
    "- secretsExternalized: $secretsExternalized",
    "- defaultSecretPlaceholdersPresent: $placeholderValuesPresent",
    "- haReplicas: $haReplicas",
    "- resourceBounds: $resourceBounds",
    "- securityContexts: $securityContexts",
    "- serviceAccountTokensDisabled: $serviceAccountTokensDisabled",
    "- networkPolicyEnabled: $networkPolicyEnabled",
    "- tlsIngress: $tlsIngress",
    "- operationsReportsReadOnly: $operationsReportsReadOnly",
    "- storageExpansionRbacDisabled: $storageExpansionRbacDisabled",
    "",
    "## Checks",
    ""
)
foreach ($check in $checks) { $lines += "- [$($check.status)] $($check.id): $($check.detail)" }
$lines += @("", "## Policy", "", "- Scope: $($report.scopePolicy)", "- Secret handling: $($report.secretPolicy)", "- Decision: $($report.decisionRule)")
$markdown = ($lines -join [Environment]::NewLine) + [Environment]::NewLine

if (-not $NoWrite) {
    $jsonPath = Resolve-ProjectPath $JsonOutputPath
    $mdPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $mdPath) | Out-Null
    $report | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -LiteralPath $jsonPath
    $markdown | Set-Content -Encoding UTF8 -LiteralPath $mdPath
    Write-Host "Helm values hardening evidence written: $jsonPath"
    Write-Host "Helm values hardening markdown written: $mdPath"
}
else { Write-Host "Helm values hardening evidence result: $result" }

if ($FailIfNotPassed -and $result -ne "passed") {
    $failed = @($checks | Where-Object { -not $_.passed } | ForEach-Object { $_.id }) -join ", "
    throw "Helm values hardening evidence did not pass: result=$result; failed=$failed"
}