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

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
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

function Get-CheckField([object] $Check, [string] $Name) {
    if ($Check -is [System.Collections.IDictionary] -and $Check.Contains($Name)) {
        return $Check[$Name]
    }
    $property = $Check.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }
    return $null
}

function Get-PendingCategoryCounts([object[]] $Checks) {
    $counts = @{}
    foreach ($check in @($Checks)) {
        if ([bool] (Get-CheckField $check "passed")) {
            continue
        }
        $category = [string] (Get-CheckField $check "category")
        if ([string]::IsNullOrWhiteSpace($category)) {
            $category = "uncategorized"
        }
        if (-not $counts.ContainsKey($category)) {
            $counts[$category] = 0
        }
        $counts[$category]++
    }
    return @($counts.Keys |
        Sort-Object |
        ForEach-Object {
            [ordered]@{
                category = $_
                count = $counts[$_]
            }
        })
}

function Format-PendingCategorySummary([object[]] $CategoryCounts) {
    $summary = @($CategoryCounts | ForEach-Object { "$($_.category)=$($_.count)" }) -join ", "
    if ([string]::IsNullOrWhiteSpace($summary)) {
        return "none"
    }
    return $summary
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

function New-PassedOperationsHandoffPackageConfirmations() {
    return [ordered]@{
        noSecretValues = $true
        runbookReviewed = $true
        troubleshootingReviewed = $true
        rollbackReviewed = $true
        supportEscalationReviewed = $true
        knownGapsAccepted = $true
        operationsReadinessSnapshotReviewed = $true
        operationsConvergenceSnapshotReviewed = $true
        dataFlowStoragePlanReviewed = $true
        dataFlowQueryRetentionBudgetReviewed = $true
        dataFlowStorageTransitionRunbookReviewed = $true
        secretRotationSnapshotReviewed = $true
        commercialIntegrationSnapshotReviewed = $true
        commercialApprovalSnapshotReviewed = $true
        chargebackCloseoutSnapshotReviewed = $true
        enterpriseAuthSmokeSnapshotReviewed = $true
        enterpriseAuthJitRollbackSnapshotReviewed = $true
        monitoringThresholdReviewed = $true
        clusterNetworkAccessReviewReviewed = $true
        helmValuesHardeningReviewed = $true
        requireProductionEvidence = $true
        requireOperationsSnapshotEvidence = $true
    }
}

function New-PassedOperationsHandoffPackageSnapshots(
    [string] $ConvergenceSourceReportResult = "ready",
    [object] $FinalizerFailedCount = 0,
    [object] $FinalizerGapCount = 0,
    [object] $KubernetesReportSyncReady = $true
) {
    return [ordered]@{
        readiness = [ordered]@{
            provided = $true
            parsed = $true
            result = "ready"
            ready = $true
            passedCount = 42
            pendingCount = 0
            checkCount = 42
        }
        convergence = [ordered]@{
            provided = $true
            parsed = $true
            result = "ready"
            ready = $true
            readinessResult = "ready"
            readinessSummary = "passed=42 pending=0"
            finalizerResult = "ready"
            finalizerReadinessResult = "ready"
            finalizerFailedCount = $FinalizerFailedCount
            finalizerGapCount = $FinalizerGapCount
            kubernetesReportSyncReady = $KubernetesReportSyncReady
            kubernetesReportSyncResult = "applied"
            kubernetesReportSyncFailedCount = 0
            kubernetesReportSyncSourceReportResult = $ConvergenceSourceReportResult
        }
    }
}

function New-PassedOperationsHandoffPackageTargetSnapshots() {
    return [ordered]@{
        clusterNetworkAccessReview = [ordered]@{
            result = "passed"
            failureCount = 0
            totalCount = 32
            staticControlsValid = $true
            confirmationsValid = $true
        }
        helmValuesHardening = [ordered]@{
            result = "passed"
            failureCount = 0
            totalCount = 31
            chartFileCount = 1
            staticHardeningValid = $true
            confirmationsValid = $true
        }
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

$report = Read-Utf8Text $resolvedJsonOutputPath | ConvertFrom-Json
$markdown = Read-Utf8Text $resolvedMarkdownOutputPath

if ($report.formatVersion -ne "osmu.operations-readiness.v1") {
    throw "Unexpected operations readiness formatVersion: $($report.formatVersion)"
}
if ($report.result -notin @("ready", "pending")) {
    throw "Unexpected operations readiness result: $($report.result)"
}
if ($report.checks.Count -lt 20) {
    throw "Operations readiness report has too few checks: $($report.checks.Count)"
}
if ($report.totalCount -ne $report.checks.Count) {
    throw "Operations readiness totalCount must equal checks.Count. totalCount=$($report.totalCount), checks=$($report.checks.Count)"
}
if ($report.checkCount -ne $report.checks.Count) {
    throw "Operations readiness checkCount must equal checks.Count. checkCount=$($report.checkCount), checks=$($report.checks.Count)"
}
if (($report.passedCount + $report.pendingCount) -ne $report.totalCount) {
    throw "Operations readiness passedCount+pendingCount must equal totalCount. passed=$($report.passedCount), pending=$($report.pendingCount), total=$($report.totalCount)"
}
$expectedPendingCategoryCounts = @(Get-PendingCategoryCounts @($report.checks))
$expectedPendingCategorySummary = Format-PendingCategorySummary $expectedPendingCategoryCounts
if ($report.pendingCategorySummary -ne $expectedPendingCategorySummary) {
    throw "Operations readiness pendingCategorySummary mismatch. expected=$expectedPendingCategorySummary actual=$($report.pendingCategorySummary)"
}
if (@($report.pendingCategoryCounts).Count -ne $expectedPendingCategoryCounts.Count) {
    throw "Operations readiness pendingCategoryCounts length mismatch. expected=$($expectedPendingCategoryCounts.Count) actual=$(@($report.pendingCategoryCounts).Count)"
}
for ($i = 0; $i -lt $expectedPendingCategoryCounts.Count; $i++) {
    $expected = $expectedPendingCategoryCounts[$i]
    $actual = @($report.pendingCategoryCounts)[$i]
    if ($actual.category -ne $expected.category -or [int] $actual.count -ne [int] $expected.count) {
        throw "Operations readiness pendingCategoryCounts[$i] mismatch. expected=$($expected.category)=$($expected.count) actual=$($actual.category)=$($actual.count)"
    }
}
Assert-Contains $markdown "Pending categories: $expectedPendingCategorySummary" "operations readiness markdown pending categories"
$pendingChecks = @($report.checks | Where-Object { -not [bool] (Get-CheckField $_ "passed") })
$pendingRemediations = @()
if ($null -ne $report.pendingRemediations) {
    $pendingRemediations = @($report.pendingRemediations)
}
if ([int] $report.pendingRemediationCount -ne $pendingChecks.Count) {
    throw "Operations readiness pendingRemediationCount must equal pending checks. expected=$($pendingChecks.Count) actual=$($report.pendingRemediationCount)"
}
if ($pendingRemediations.Count -ne $pendingChecks.Count) {
    throw "Operations readiness pendingRemediations length mismatch. expected=$($pendingChecks.Count) actual=$($pendingRemediations.Count)"
}
Assert-Contains $markdown "Pending remediation entries: $($report.pendingRemediationCount)" "operations readiness markdown pending remediation entries"
foreach ($pending in $pendingChecks) {
    $pendingName = [string] (Get-CheckField $pending "name")
    $pendingCategory = [string] (Get-CheckField $pending "category")
    $matches = @($pendingRemediations | Where-Object { ([string] (Get-CheckField $_ "name")) -eq $pendingName -and ([string] (Get-CheckField $_ "category")) -eq $pendingCategory })
    if ($matches.Count -ne 1) {
        throw "Operations readiness pendingRemediations must contain one summary for '$pendingName' in category '$pendingCategory'."
    }
    $summary = $matches[0]
    $remediation = Get-CheckField $pending "remediation"
    if ($null -eq $remediation) {
        throw "Operations readiness pending check '$pendingName' must include remediation metadata."
    }
    foreach ($field in @("evidencePath", "requiredEvidence", "detail")) {
        $expected = [string] (Get-CheckField $pending $field)
        $actual = [string] (Get-CheckField $summary $field)
        if ($actual -ne $expected) {
            throw "Operations readiness pendingRemediations '$pendingName' field '$field' mismatch. expected=$expected actual=$actual"
        }
    }
    foreach ($field in @("command", "workflow", "workflowCommand", "note")) {
        $expected = [string] (Get-CheckField $remediation $field)
        $actual = [string] (Get-CheckField $summary $field)
        if ($actual -ne $expected) {
            throw "Operations readiness pendingRemediations '$pendingName' remediation field '$field' mismatch. expected=$expected actual=$actual"
        }
    }
    foreach ($field in @("command", "workflowCommand", "note")) {
        if ([string]::IsNullOrWhiteSpace([string] (Get-CheckField $summary $field))) {
            throw "Operations readiness pendingRemediations '$pendingName' field '$field' must not be empty."
        }
    }
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
Assert-CheckExists $report "Storage backend telemetry evidence writer" "storage-backend"
Assert-CheckExists $report "Storage backend telemetry evidence writer self-test" "storage-backend"
Assert-CheckExists $report "MariaDB query plan evidence writer" "data-flow"
Assert-CheckExists $report "MariaDB query plan evidence self-test" "data-flow"
Assert-CheckExists $report "Data-flow storage plan writer" "data-flow"
Assert-CheckExists $report "Data-flow storage plan self-test" "data-flow"
Assert-CheckExists $report "Data-flow storage plan evidence workflow" "data-flow"
Assert-CheckExists $report "Data-flow query/retention budget writer" "data-flow"
Assert-CheckExists $report "Data-flow query/retention budget self-test" "data-flow"
Assert-CheckExists $report "Data-flow query/retention budget workflow" "data-flow"
Assert-CheckExists $report "Data-flow storage transition runbook writer" "data-flow"
Assert-CheckExists $report "Data-flow storage transition runbook self-test" "data-flow"
Assert-CheckExists $report "Data-flow storage transition runbook workflow" "data-flow"
Assert-CheckExists $report "Monitoring threshold evidence writer" "monitoring"
Assert-CheckExists $report "Monitoring threshold evidence writer self-test" "monitoring"
Assert-CheckExists $report "Monitoring threshold evidence workflow" "monitoring"
Assert-CheckExists $report "Secret rotation evidence writer" "security-hardening"
Assert-CheckExists $report "Secret rotation evidence writer self-test" "security-hardening"
Assert-CheckExists $report "Secret rotation evidence workflow" "security-hardening"
Assert-CheckExists $report "Commercial integration evidence writer" "commercial-integration"
Assert-CheckExists $report "Commercial integration evidence writer self-test" "commercial-integration"
Assert-CheckExists $report "Commercial integration evidence workflow" "commercial-integration"
Assert-CheckExists $report "Commercial approval evidence writer" "commercial-approval"
Assert-CheckExists $report "Commercial approval evidence writer self-test" "commercial-approval"
Assert-CheckExists $report "Commercial approval evidence workflow" "commercial-approval"
Assert-CheckExists $report "Chargeback closeout evidence writer" "chargeback-closeout"
Assert-CheckExists $report "Chargeback closeout evidence writer self-test" "chargeback-closeout"
Assert-CheckExists $report "Chargeback closeout target evidence" "chargeback-closeout"
Assert-CheckExists $report "Operations handoff package writer" "operations-handoff-package"
Assert-CheckExists $report "Operations handoff package writer self-test" "operations-handoff-package"
Assert-CheckExists $report "Operations handoff package workflow" "operations-handoff-package"
Assert-CheckExists $report "Support escalation handoff evidence writer" "operations-handoff-package"
Assert-CheckExists $report "Support escalation handoff evidence writer self-test" "operations-handoff-package"
Assert-CheckExists $report "Support escalation handoff evidence workflow" "operations-handoff-package"
Assert-CheckExists $report "Security evidence finalizer" "security-hardening"
Assert-CheckExists $report "Security evidence finalizer self-test" "security-hardening"
Assert-CheckExists $report "Security evidence finalizer workflow" "security-hardening"
Assert-CheckExists $report "Enterprise auth smoke workflow" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth smoke evidence helper" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth smoke evidence helper self-test" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth JIT rollback workflow" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth JIT rollback evidence helper" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth JIT rollback evidence helper self-test" "enterprise-auth"
Assert-CheckExists $report "Storage expansion finalizer live evidence" "storage-expansion"
Assert-CheckExists $report "Kubernetes HA/DR readiness live evidence" "ha-dr"
Assert-CheckExists $report "Kubernetes DR finalizer live evidence" "ha-dr"
Assert-CheckExists $report "IAM/RBAC finalizer report" "iam-rbac"
Assert-CheckExists $report "Security evidence finalizer report" "security-hardening"
Assert-CheckExists $report "Signed image evidence" "security-hardening"
Assert-CheckExists $report "Container scan/SBOM evidence" "security-hardening"
Assert-CheckExists $report "Storage backend telemetry target evidence" "storage-backend"
Assert-CheckExists $report "Data-flow storage transition target evidence" "data-flow"
Assert-CheckExists $report "Data-flow query/retention budget target evidence" "data-flow"
Assert-CheckExists $report "Data-flow storage transition runbook target evidence" "data-flow"
Assert-CheckExists $report "Monitoring threshold target evidence" "monitoring"
Assert-CheckExists $report "Secret/certificate rotation target evidence" "security-hardening"
Assert-CheckExists $report "Commercial integration target evidence" "commercial-integration"
Assert-CheckExists $report "Commercial approval target evidence" "commercial-approval"
Assert-CheckExists $report "Enterprise auth target smoke evidence" "enterprise-auth"
Assert-CheckExists $report "Enterprise auth JIT rollback target evidence" "enterprise-auth"
Assert-CheckExists $report "Operations handoff package target evidence" "operations-handoff-package"
Assert-CheckExists $report "Cluster network access review target evidence" "security-hardening"
Assert-CheckExists $report "Helm values hardening target evidence" "security-hardening"

Assert-Contains $markdown "Data-flow query/retention budget target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Cluster network access review target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Helm values hardening target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Total checks: $($report.totalCount)" "Operations readiness markdown"
Assert-Contains ([string] $report.decisionRule) "data-flow query/retention budget" "Operations readiness decision rule"
Assert-Contains ([string] $report.decisionRule) "enterprise auth smoke/JIT rollback" "Operations readiness decision rule"
Assert-Contains ([string] $report.decisionRule) "cluster network access review" "Operations readiness decision rule"
Assert-Contains ([string] $report.decisionRule) "Helm values hardening" "Operations readiness decision rule"

Assert-CheckRemediation $report "Storage expansion finalizer live evidence" "finalize-storage-expansion.ps1" ".github/workflows/storage-expansion-finalizer-ci.yml" "gh workflow run storage-expansion-finalizer-ci.yml"
Assert-CheckRemediation $report "Kubernetes HA/DR readiness live evidence" "verify-kubernetes-ha-dr-readiness.ps1" ".github/workflows/kubernetes-ha-dr-readiness-ci.yml" "gh workflow run kubernetes-ha-dr-readiness-ci.yml"
Assert-CheckRemediation $report "Kubernetes DR finalizer live evidence" "finalize-kubernetes-dr-drill.ps1" ".github/workflows/kubernetes-dr-finalizer-ci.yml" "gh workflow run kubernetes-dr-finalizer-ci.yml"
Assert-CheckRemediation $report "Security evidence finalizer report" "finalize-security-evidence.ps1" ".github/workflows/security-evidence-finalizer-ci.yml" "gh workflow run security-evidence-finalizer-ci.yml"
Assert-CheckRemediation $report "Signed image evidence" "image-publish-sign-ci.yml" ".github/workflows/image-publish-sign-ci.yml" "gh workflow run image-publish-sign-ci.yml"
Assert-CheckRemediation $report "Container scan/SBOM evidence" "container-security-ci.yml" ".github/workflows/container-security-ci.yml" "gh workflow run container-security-ci.yml"
$securityFinalizeCheck = @($report.checks | Where-Object { $_.name -eq "Security evidence finalizer report" })
if ($securityFinalizeCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Security evidence finalizer report check."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.workflowCommand).Contains("image_signing_artifact_name=<artifact-name>")) {
    throw "Security evidence finalizer workflow command must include image signing artifact name input."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.workflowCommand).Contains("container_security_artifact_name=<artifact-name>")) {
    throw "Security evidence finalizer workflow command must include container security artifact name input."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.workflowCommand).Contains("fail_if_not_passed=true")) {
    throw "Security evidence finalizer workflow command must fail if promoted evidence is not passed."
}
if (-not ([string] $securityFinalizeCheck[0].requiredEvidence).Contains("strict image signing and container SBOM import validation")) {
    throw "Security evidence finalizer required evidence must mention strict image signing and container SBOM import validation."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.note).Contains("GitHub OIDC keyless signing")) {
    throw "Security evidence finalizer remediation note must mention GitHub OIDC keyless signing."
}
if (-not ([string] $securityFinalizeCheck[0].remediation.note).Contains("SPDX SBOM")) {
    throw "Security evidence finalizer remediation note must mention SPDX SBOM validation."
}
$imageSigningCheck = @($report.checks | Where-Object { $_.name -eq "Signed image evidence" })
if ($imageSigningCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Signed image evidence check."
}
if (-not ([string] $imageSigningCheck[0].remediation.command).Contains("publish=true")) {
    throw "Signed image evidence remediation command must require publish=true."
}
if (-not ([string] $imageSigningCheck[0].remediation.workflowCommand).Contains("-f version=v0.1.0-rc.1")) {
    throw "Signed image evidence workflow command must include a release version input example."
}
if (-not ([string] $imageSigningCheck[0].remediation.workflowCommand).Contains("-f publish=true")) {
    throw "Signed image evidence workflow command must publish images."
}
if (-not ([string] $imageSigningCheck[0].requiredEvidence).Contains("GitHub OIDC keyless Cosign verification")) {
    throw "Signed image evidence must require GitHub OIDC keyless Cosign verification."
}
if (-not ([string] $imageSigningCheck[0].requiredEvidence).Contains("release-version and commit-SHA tags")) {
    throw "Signed image evidence must require release-version and commit-SHA tags."
}
if (-not ([string] $imageSigningCheck[0].remediation.note).Contains("commit-SHA tag verification")) {
    throw "Signed image evidence remediation note must mention commit-SHA tag verification."
}
$containerSecurityCheck = @($report.checks | Where-Object { $_.name -eq "Container scan/SBOM evidence" })
if ($containerSecurityCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Container scan/SBOM evidence check."
}
if (-not ([string] $containerSecurityCheck[0].requiredEvidence).Contains("Trivy CRITICAL,HIGH")) {
    throw "Container scan/SBOM evidence must require Trivy CRITICAL,HIGH scan evidence."
}
if (-not ([string] $containerSecurityCheck[0].requiredEvidence).Contains("commit-SHA image tag")) {
    throw "Container scan/SBOM evidence must require commit-SHA image tag evidence."
}
if (-not ([string] $containerSecurityCheck[0].requiredEvidence).Contains("backend/frontend SPDX SBOM")) {
    throw "Container scan/SBOM evidence must require backend/frontend SPDX SBOM evidence."
}
if (-not ([string] $containerSecurityCheck[0].remediation.note).Contains("ignore-unfixed policy")) {
    throw "Container scan/SBOM remediation note must mention ignore-unfixed policy recording."
}
if (-not ([string] $containerSecurityCheck[0].remediation.note).Contains("commit-SHA image tag")) {
    throw "Container scan/SBOM remediation note must mention commit-SHA image tag capture."
}
if (-not ([string] $containerSecurityCheck[0].remediation.note).Contains("SPDX SBOM metadata")) {
    throw "Container scan/SBOM remediation note must mention SPDX SBOM metadata generation."
}
$storageBackendTelemetryCheck = @($report.checks | Where-Object { $_.name -eq "Storage backend telemetry target evidence" })
if ($storageBackendTelemetryCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Storage backend telemetry target evidence check."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.command).Contains("write-storage-backend-telemetry-evidence.ps1")) {
    throw "Storage backend telemetry target evidence remediation must point to write-storage-backend-telemetry-evidence.ps1."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.workflow).Contains("manual-storage-backend-telemetry-evidence.yml")) {
    throw "Storage backend telemetry target evidence remediation workflow must point to manual-storage-backend-telemetry-evidence.yml."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-storage-backend-telemetry-evidence.yml")) {
    throw "Storage backend telemetry target evidence remediation workflow command must dispatch manual-storage-backend-telemetry-evidence.yml."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.workflowCommand).Contains("collection_mode=live")) {
    throw "Storage backend telemetry target evidence remediation workflow command must select live collection mode."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.workflowCommand).Contains("minio_endpoint=<minio-endpoint>")) {
    throw "Storage backend telemetry target evidence remediation workflow command must include target MinIO endpoint input."
}
if (-not ([string] $storageBackendTelemetryCheck[0].requiredEvidence).Contains("target MinIO admin info evidence")) {
    throw "Storage backend telemetry target evidence must require target MinIO admin info evidence."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.note).Contains("mc admin info --json")) {
    throw "Storage backend telemetry target evidence remediation note must mention mc admin info --json."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.note).Contains("OSMU_MINIO_ACCESS_KEY")) {
    throw "Storage backend telemetry target evidence remediation note must mention OSMU_MINIO_ACCESS_KEY."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.note).Contains("OSMU_MINIO_SECRET_KEY")) {
    throw "Storage backend telemetry target evidence remediation note must mention OSMU_MINIO_SECRET_KEY."
}
if (-not ([string] $storageBackendTelemetryCheck[0].remediation.note).Contains("OSMU_MINIO_ADMIN_INFO_JSON_BASE64")) {
    throw "Storage backend telemetry target evidence remediation note must mention OSMU_MINIO_ADMIN_INFO_JSON_BASE64."
}
$clusterNetworkAccessReviewCheck = @($report.checks | Where-Object { $_.name -eq "Cluster network access review target evidence" })
if ($clusterNetworkAccessReviewCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Cluster network access review target evidence check."
}
if (-not ([string] $report.inputs.clusterNetworkAccessReviewEvidence).Contains("latest-cluster-network-access-review-evidence.json")) {
    throw "Operations readiness report inputs must include cluster network access review evidence path."
}
if (-not ([string] $clusterNetworkAccessReviewCheck[0].remediation.command).Contains("write-cluster-network-access-review-evidence.ps1")) {
    throw "Cluster network access review remediation must point to write-cluster-network-access-review-evidence.ps1."
}
if (-not ([string] $clusterNetworkAccessReviewCheck[0].remediation.workflow).Contains(".github/workflows/manual-cluster-network-access-review-evidence.yml")) {
    throw "Cluster network access review remediation must point to the manual workflow."
}
if (-not ([string] $clusterNetworkAccessReviewCheck[0].remediation.workflowCommand).Contains("access_review_refs_json_base64=<base64-json-with-network-review-refs>")) {
    throw "Cluster network access review workflow command must include the base64 refs payload input."
}
if (-not ([string] $clusterNetworkAccessReviewCheck[0].remediation.workflowCommand).Contains("confirm_no_credential_values=true")) {
    throw "Cluster network access review workflow command must include no-credential confirmation."
}
if (-not ([string] $clusterNetworkAccessReviewCheck[0].remediation.command).Contains("ConfirmHelmNetworkPolicyEnabled")) {
    throw "Cluster network access review remediation must confirm Helm NetworkPolicy enablement."
}
if (-not ([string] $clusterNetworkAccessReviewCheck[0].requiredEvidence).Contains("Kubernetes/Helm NetworkPolicy hashes")) {
    throw "Cluster network access review required evidence must mention Kubernetes/Helm NetworkPolicy hashes."
}
if (-not ([string] $clusterNetworkAccessReviewCheck[0].remediation.note).Contains("live CNI enforcement output")) {
    throw "Cluster network access review remediation note must avoid live CNI enforcement claims."
}
$helmValuesHardeningCheck = @($report.checks | Where-Object { $_.name -eq "Helm values hardening target evidence" })
if ($helmValuesHardeningCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Helm values hardening target evidence check."
}
if (-not ([string] $report.inputs.helmValuesHardeningEvidence).Contains("latest-helm-values-hardening-evidence.json")) {
    throw "Operations readiness report inputs must include Helm values hardening evidence path."
}
if (-not ([string] $helmValuesHardeningCheck[0].remediation.command).Contains("write-helm-values-hardening-evidence.ps1")) {
    throw "Helm values hardening remediation must point to write-helm-values-hardening-evidence.ps1."
}
if (-not ([string] $helmValuesHardeningCheck[0].remediation.workflow).Contains(".github/workflows/manual-helm-values-hardening-evidence.yml")) {
    throw "Helm values hardening remediation must point to the manual workflow."
}
if (-not ([string] $helmValuesHardeningCheck[0].remediation.workflowCommand).Contains("hardening_refs_json_base64=<base64-json-with-helm-hardening-refs>")) {
    throw "Helm values hardening workflow command must include the base64 refs payload input."
}
if (-not ([string] $helmValuesHardeningCheck[0].remediation.workflowCommand).Contains("confirm_no_credential_values=true")) {
    throw "Helm values hardening workflow command must include no-credential confirmation."
}
if (-not ([string] $helmValuesHardeningCheck[0].remediation.command).Contains("ClusterNetworkAccessReviewEvidenceRef")) {
    throw "Helm values hardening remediation must reference cluster network access review evidence."
}
if (-not ([string] $helmValuesHardeningCheck[0].requiredEvidence).Contains("storage expansion RBAC defaults")) {
    throw "Helm values hardening required evidence must mention storage expansion RBAC defaults."
}
if (-not ([string] $helmValuesHardeningCheck[0].remediation.note).Contains("rendered secret manifests")) {
    throw "Helm values hardening remediation note must mention rendered secret manifest exclusion."
}
$dataFlowStoragePlanCheck = @($report.checks | Where-Object { $_.name -eq "Data-flow storage transition target evidence" })
if ($dataFlowStoragePlanCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Data-flow storage transition target evidence check."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.command).Contains("write-data-flow-storage-plan.ps1")) {
    throw "Data-flow storage transition target evidence remediation must point to write-data-flow-storage-plan.ps1."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.command).Contains("QueryPlanEvidenceJsonPath")) {
    throw "Data-flow storage transition target evidence remediation must include QueryPlanEvidenceJsonPath."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.command).Contains("RequireQueryPlanEvidence")) {
    throw "Data-flow storage transition target evidence remediation must require query-plan evidence for the MariaDB candidate."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.command).Contains("TargetP95QueryLatencyMs")) {
    throw "Data-flow storage transition target evidence remediation must include TargetP95QueryLatencyMs."
}
if ($dataFlowStoragePlanCheck[0].remediation.workflow -ne ".github/workflows/manual-data-flow-storage-plan-evidence.yml") {
    throw "Data-flow storage transition target evidence remediation must point to the manual data-flow storage plan workflow."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.workflowCommand).Contains("manual-data-flow-storage-plan-evidence.yml")) {
    throw "Data-flow storage transition target evidence remediation workflow command must dispatch manual-data-flow-storage-plan-evidence.yml."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.workflowCommand).Contains("query_plan_evidence_json_base64")) {
    throw "Data-flow storage transition target evidence workflow command must include query_plan_evidence_json_base64."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.workflowCommand).Contains("target_p95_query_latency_ms")) {
    throw "Data-flow storage transition target evidence workflow command must include target_p95_query_latency_ms."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].requiredEvidence).Contains("target query-plan evidence")) {
    throw "Data-flow storage transition target evidence must require target query-plan evidence."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].requiredEvidence).Contains("target p95 query latency budget")) {
    throw "Data-flow storage transition target evidence must require target p95 query latency budget."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("write-mariadb-query-plan-evidence.ps1")) {
    throw "Data-flow storage transition target evidence remediation note must mention write-mariadb-query-plan-evidence.ps1."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("raw SQL")) {
    throw "Data-flow storage transition target evidence remediation note must mention raw SQL exclusion."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("raw EXPLAIN")) {
    throw "Data-flow storage transition target evidence remediation note must mention raw EXPLAIN exclusion."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("credentials")) {
    throw "Data-flow storage transition target evidence remediation note must mention credential exclusion."
}
if (-not ([string] $dataFlowStoragePlanCheck[0].remediation.note).Contains("object keys")) {
    throw "Data-flow storage transition target evidence remediation note must mention object-key exclusion."
}
$dataFlowQueryRetentionBudgetCheck = @($report.checks | Where-Object { $_.name -eq "Data-flow query/retention budget target evidence" })
if ($dataFlowQueryRetentionBudgetCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Data-flow query/retention budget target evidence check."
}
if (-not ([string] $report.inputs.dataFlowQueryRetentionBudgetEvidence).Contains("latest-data-flow-query-retention-budget-evidence.json")) {
    throw "Operations readiness report inputs must include data-flow query/retention budget evidence path."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.command).Contains("write-data-flow-query-retention-budget-evidence.ps1")) {
    throw "Data-flow query/retention budget target evidence remediation must point to write-data-flow-query-retention-budget-evidence.ps1."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.command).Contains("ObservedP95QueryLatencyMs")) {
    throw "Data-flow query/retention budget remediation must include observed p95 latency."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.command).Contains("RetentionJobBudgetSeconds")) {
    throw "Data-flow query/retention budget remediation must include retention job budget seconds."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.command).Contains("ConfirmQueryLatencyReviewed")) {
    throw "Data-flow query/retention budget remediation must confirm query latency review."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.command).Contains("ConfirmRetentionJobsWithinBudget")) {
    throw "Data-flow query/retention budget remediation must confirm retention jobs within budget."
}
if ($dataFlowQueryRetentionBudgetCheck[0].remediation.workflow -ne ".github/workflows/manual-data-flow-query-retention-budget-evidence.yml") {
    throw "Data-flow query/retention budget target evidence remediation must point to the manual query/retention budget workflow."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.workflowCommand).Contains("manual-data-flow-query-retention-budget-evidence.yml")) {
    throw "Data-flow query/retention budget workflow command must dispatch manual-data-flow-query-retention-budget-evidence.yml."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.workflowCommand).Contains("data_flow_storage_plan_json_base64")) {
    throw "Data-flow query/retention budget workflow command must include data_flow_storage_plan_json_base64."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.workflowCommand).Contains("observed_p95_query_latency_ms")) {
    throw "Data-flow query/retention budget workflow command must include observed_p95_query_latency_ms."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.workflowCommand).Contains("retention_job_budget_seconds")) {
    throw "Data-flow query/retention budget workflow command must include retention_job_budget_seconds."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.workflowCommand).Contains("confirm_query_latency_reviewed=true")) {
    throw "Data-flow query/retention budget workflow command must confirm query latency review."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.workflowCommand).Contains("confirm_retention_jobs_within_budget=true")) {
    throw "Data-flow query/retention budget workflow command must confirm retention jobs within budget."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].requiredEvidence).Contains("observed p95 query latency")) {
    throw "Data-flow query/retention budget required evidence must mention observed p95 query latency."
}
if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].requiredEvidence).Contains("retention jobs within target budget")) {
    throw "Data-flow query/retention budget required evidence must mention retention jobs within target budget."
}
foreach ($excluded in @("raw SQL", "raw EXPLAIN", "object keys", "credentials")) {
    if (-not ([string] $dataFlowQueryRetentionBudgetCheck[0].remediation.note).Contains($excluded)) {
        throw "Data-flow query/retention budget remediation note must mention $excluded exclusion."
    }
}
$dataFlowStorageTransitionRunbookCheck = @($report.checks | Where-Object { $_.name -eq "Data-flow storage transition runbook target evidence" })
if ($dataFlowStorageTransitionRunbookCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Data-flow storage transition runbook target evidence check."
}
if (-not ([string] $report.inputs.dataFlowStorageTransitionRunbookEvidence).Contains("latest-data-flow-storage-transition-runbook-evidence.json")) {
    throw "Operations readiness report inputs must include data-flow storage transition runbook evidence path."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.command).Contains("write-data-flow-storage-transition-runbook-evidence.ps1")) {
    throw "Data-flow storage transition runbook target evidence remediation must point to write-data-flow-storage-transition-runbook-evidence.ps1."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.command).Contains("DataFlowStoragePlanJsonPath")) {
    throw "Data-flow storage transition runbook target evidence remediation must include data-flow storage plan JSON input."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.command).Contains("ConfirmBackfillRehearsed")) {
    throw "Data-flow storage transition runbook target evidence remediation must confirm backfill rehearsal."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.command).Contains("ConfirmReconciliationPassed")) {
    throw "Data-flow storage transition runbook target evidence remediation must confirm reconciliation."
}
if ($dataFlowStorageTransitionRunbookCheck[0].remediation.workflow -ne ".github/workflows/manual-data-flow-storage-transition-runbook-evidence.yml") {
    throw "Data-flow storage transition runbook target evidence remediation must point to the manual data-flow transition runbook workflow."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.workflowCommand).Contains("manual-data-flow-storage-transition-runbook-evidence.yml")) {
    throw "Data-flow storage transition runbook target evidence remediation workflow command must dispatch manual-data-flow-storage-transition-runbook-evidence.yml."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.workflowCommand).Contains("data_flow_storage_plan_json_base64")) {
    throw "Data-flow storage transition runbook target evidence workflow command must include data_flow_storage_plan_json_base64."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.workflowCommand).Contains("confirm_rollback_rehearsed=true")) {
    throw "Data-flow storage transition runbook target evidence workflow command must confirm rollback rehearsal."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].requiredEvidence).Contains("target backfill")) {
    throw "Data-flow storage transition runbook target evidence must require target backfill evidence."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].requiredEvidence).Contains("retention dry-run")) {
    throw "Data-flow storage transition runbook target evidence must require retention dry-run evidence."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.note).Contains("raw SQL")) {
    throw "Data-flow storage transition runbook remediation note must mention raw SQL exclusion."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.note).Contains("raw EXPLAIN")) {
    throw "Data-flow storage transition runbook remediation note must mention raw EXPLAIN exclusion."
}
if (-not ([string] $dataFlowStorageTransitionRunbookCheck[0].remediation.note).Contains("object keys")) {
    throw "Data-flow storage transition runbook remediation note must mention object-key exclusion."
}
$monitoringThresholdCheck = @($report.checks | Where-Object { $_.name -eq "Monitoring threshold target evidence" })
if ($monitoringThresholdCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Monitoring threshold target evidence check."
}
if (-not ([string] $report.inputs.monitoringThresholdEvidence).Contains("latest-monitoring-threshold-evidence.json")) {
    throw "Operations readiness report inputs must include monitoring threshold evidence path."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.command).Contains("write-monitoring-threshold-evidence.ps1")) {
    throw "Monitoring threshold target evidence remediation must point to write-monitoring-threshold-evidence.ps1."
}
if ($monitoringThresholdCheck[0].remediation.workflow -ne ".github/workflows/manual-monitoring-threshold-evidence.yml") {
    throw "Monitoring threshold target evidence remediation workflow must point to manual-monitoring-threshold-evidence.yml."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-monitoring-threshold-evidence.yml")) {
    throw "Monitoring threshold target evidence remediation workflow command must dispatch manual-monitoring-threshold-evidence.yml."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.workflowCommand).Contains("confirm_alertmanager_routes_reviewed=true")) {
    throw "Monitoring threshold target evidence workflow command must confirm Alertmanager route review."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.workflowCommand).Contains("confirm_target_baselines_reviewed=true")) {
    throw "Monitoring threshold target evidence workflow command must confirm target baseline review."
}
if (-not ([string] $monitoringThresholdCheck[0].requiredEvidence).Contains("target Prometheus/Grafana/Alertmanager/tenant baseline review")) {
    throw "Monitoring threshold target evidence must require target monitoring stack review."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.note).Contains("ReviewCompletedAt")) {
    throw "Monitoring threshold target evidence remediation note must mention review window ordering."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.note).Contains("typed counts")) {
    throw "Monitoring threshold target evidence remediation note must mention typed counts."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.note).Contains("Alertmanager receiver secrets")) {
    throw "Monitoring threshold target evidence remediation note must mention Alertmanager receiver secret exclusion."
}
if (-not ([string] $monitoringThresholdCheck[0].remediation.note).Contains("raw tenant object keys")) {
    throw "Monitoring threshold target evidence remediation note must mention raw tenant object key exclusion."
}
$secretRotationCheck = @($report.checks | Where-Object { $_.name -eq "Secret/certificate rotation target evidence" })
if ($secretRotationCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Secret/certificate rotation target evidence check."
}
if (-not ([string] $secretRotationCheck[0].remediation.command).Contains("write-secret-rotation-evidence.ps1")) {
    throw "Secret/certificate rotation target evidence remediation must point to write-secret-rotation-evidence.ps1."
}
if ($secretRotationCheck[0].remediation.workflow -ne ".github/workflows/manual-secret-rotation-evidence.yml") {
    throw "Secret/certificate rotation target evidence remediation workflow must point to manual-secret-rotation-evidence.yml."
}
if (-not ([string] $secretRotationCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-secret-rotation-evidence.yml")) {
    throw "Secret/certificate rotation target evidence remediation workflow command must dispatch manual-secret-rotation-evidence.yml."
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
if ($commercialIntegrationCheck[0].remediation.workflow -ne ".github/workflows/manual-commercial-integration-evidence.yml") {
    throw "Commercial integration target evidence remediation workflow must point to manual-commercial-integration-evidence.yml."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-commercial-integration-evidence.yml")) {
    throw "Commercial integration target evidence remediation workflow command must dispatch manual-commercial-integration-evidence.yml."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.command).Contains("PaymentProviderAdapterReadinessJsonPath")) {
    throw "Commercial integration target evidence remediation must include payment-provider adapter readiness JSON input."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.workflowCommand).Contains("payment_provider_adapter_readiness_json_base64=<base64-json>")) {
    throw "Commercial integration target evidence workflow command must include payment-provider adapter readiness base64 input."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.workflowCommand).Contains("confirm_payment_provider_adapter_readiness_reviewed=true")) {
    throw "Commercial integration target evidence workflow command must confirm payment-provider adapter readiness review."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.note).Contains("GET /api/admin/billing/payment-provider-adapter-readiness")) {
    throw "Commercial integration target evidence remediation note must mention the payment-provider adapter readiness API."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.note).Contains("does not claim vendor-specific fixed SDK/schema card/bank/tax/ERP processor implementation")) {
    throw "Commercial integration target evidence remediation note must preserve native provider scope boundary."
}
if (-not ([string] $commercialIntegrationCheck[0].remediation.note).Contains("decoded workflow input is deleted before artifact upload")) {
    throw "Commercial integration target evidence remediation note must mention decoded workflow input cleanup."
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
if ($commercialApprovalCheck[0].remediation.workflow -ne ".github/workflows/manual-commercial-approval-evidence.yml") {
    throw "Commercial approval target evidence remediation workflow must point to manual-commercial-approval-evidence.yml."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-commercial-approval-evidence.yml")) {
    throw "Commercial approval target evidence remediation workflow command must dispatch manual-commercial-approval-evidence.yml."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.command).Contains("PricingPolicyProposalJsonPath")) {
    throw "Commercial approval target evidence remediation must include pricing policy proposal JSON input."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.workflowCommand).Contains("pricing_policy_proposal_json_base64=<base64-json>")) {
    throw "Commercial approval target evidence workflow command must include pricing policy proposal base64 input."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.workflowCommand).Contains("confirm_pricing_policy_proposal_commercial_approval=true")) {
    throw "Commercial approval target evidence workflow command must confirm pricing policy proposal commercial approval."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.note).Contains("GET /api/admin/billing/pricing-policy-proposals?status=PRICE_LIST_APPROVED")) {
    throw "Commercial approval target evidence remediation note must mention the pricing policy proposal API."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.note).Contains("sanitized status/reference metadata")) {
    throw "Commercial approval target evidence remediation note must mention sanitized status/reference metadata."
}
if (-not ([string] $commercialApprovalCheck[0].remediation.note).Contains("decoded workflow input is deleted before artifact upload")) {
    throw "Commercial approval target evidence remediation note must mention decoded workflow input cleanup."
}
if (-not ([string] $commercialApprovalCheck[0].requiredEvidence).Contains("final pricing") -or -not ([string] $commercialApprovalCheck[0].requiredEvidence).Contains("legal approval")) {
    throw "Commercial approval target evidence must require final pricing and legal approval evidence."
}
$chargebackCloseoutCheck = @($report.checks | Where-Object { $_.name -eq "Chargeback closeout target evidence" })
if ($chargebackCloseoutCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Chargeback closeout target evidence check."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.command).Contains("write-chargeback-closeout-evidence.ps1")) {
    throw "Chargeback closeout target evidence remediation must point to write-chargeback-closeout-evidence.ps1."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.command).Contains("ChargebackCloseoutSnapshotJsonPath")) {
    throw "Chargeback closeout target evidence remediation must include sanitized closeout snapshot JSON input."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.command).Contains("ConfirmReconciliationReviewed")) {
    throw "Chargeback closeout target evidence remediation must require reconciliation review confirmation."
}
if ($chargebackCloseoutCheck[0].remediation.workflow -ne ".github/workflows/manual-chargeback-closeout-evidence.yml") {
    throw "Chargeback closeout target evidence remediation workflow must point to manual-chargeback-closeout-evidence.yml."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-chargeback-closeout-evidence.yml")) {
    throw "Chargeback closeout target evidence remediation workflow command must dispatch manual-chargeback-closeout-evidence.yml."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.workflowCommand).Contains("chargeback_closeout_snapshot_json_base64")) {
    throw "Chargeback closeout target evidence remediation workflow command must include sanitized closeout snapshot base64 input."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.workflowCommand).Contains("chargeback_closeout_payload_json_base64")) {
    throw "Chargeback closeout target evidence remediation workflow command must include refs and confirmations payload input."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.note).Contains("payment-provider adapter readiness") -or -not ([string] $chargebackCloseoutCheck[0].remediation.note).Contains("sanitized closeout snapshot")) {
    throw "Chargeback closeout target evidence remediation note must mention payment-provider adapter readiness and sanitized closeout snapshots."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.note).Contains("raw customer/payment/provider data")) {
    throw "Chargeback closeout target evidence remediation note must mention raw customer/payment/provider data exclusion."
}
if (-not ([string] $chargebackCloseoutCheck[0].remediation.note).Contains("does not claim vendor-specific fixed SDK/schema card/bank/tax/ERP provider implementation")) {
    throw "Chargeback closeout target evidence remediation note must preserve native provider scope boundary."
}
if (-not ([string] $chargebackCloseoutCheck[0].requiredEvidence).Contains("target billing period")) {
    throw "Chargeback closeout target evidence must require target billing period evidence."
}
$chargebackDetail = [string] $chargebackCloseoutCheck[0].detail
if (-not $chargebackDetail.Contains("result=planned")) {
    throw "Chargeback closeout target evidence detail must preserve planned state until target closeout evidence is recorded."
}
if (-not $chargebackDetail.Contains("billingPeriod=")) {
    throw "Chargeback closeout target evidence detail must include the billing period field, even before target input is supplied."
}
if (-not $chargebackDetail.Contains("window=->")) {
    throw "Chargeback closeout target evidence detail must include the empty closeout window shape for planned evidence."
}
if (-not $chargebackDetail.Contains("planned=3")) {
    throw "Chargeback closeout target evidence detail must include planned check count."
}
if (-not $chargebackDetail.Contains("refs=0/14")) {
    throw "Chargeback closeout target evidence detail must include missing required evidence refs."
}
if (-not $chargebackDetail.Contains("reconciliationDifferenceMinorUnits=0")) {
    throw "Chargeback closeout target evidence detail must include reconciliation difference."
}
if (-not $chargebackDetail.Contains("firstIssue=target-closeout-planned/PLANNED")) {
    throw "Chargeback closeout target evidence detail must include first planned check id/status."
}
if (-not $chargebackDetail.Contains("Run this writer after a target billing period has been closed")) {
    throw "Chargeback closeout target evidence detail must explain that target billing closeout evidence is still required."
}$enterpriseAuthCheck = @($report.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
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
if (-not ([string] $enterpriseAuthCheck[0].remediation.note).Contains("typed integer summary counts")) {
    throw "Enterprise auth target smoke remediation note must mention typed integer summary counts."
}
$enterpriseAuthJitRollbackCheck = @($report.checks | Where-Object { $_.name -eq "Enterprise auth JIT rollback target evidence" })
if ($enterpriseAuthJitRollbackCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Enterprise auth JIT rollback target evidence check."
}
if (-not ([string] $enterpriseAuthJitRollbackCheck[0].remediation.command).Contains("write-enterprise-auth-jit-rollback-evidence.ps1")) {
    throw "Enterprise auth JIT rollback target evidence remediation must point to write-enterprise-auth-jit-rollback-evidence.ps1."
}
if ($enterpriseAuthJitRollbackCheck[0].remediation.workflow -ne ".github/workflows/manual-enterprise-auth-jit-rollback-evidence.yml") {
    throw "Enterprise auth JIT rollback target evidence remediation workflow must point to manual-enterprise-auth-jit-rollback-evidence.yml."
}
if (-not ([string] $enterpriseAuthJitRollbackCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-enterprise-auth-jit-rollback-evidence.yml")) {
    throw "Enterprise auth JIT rollback target evidence remediation workflow command must dispatch manual-enterprise-auth-jit-rollback-evidence.yml."
}
if (-not ([string] $enterpriseAuthJitRollbackCheck[0].remediation.workflowCommand).Contains("enterprise_auth_smoke_json_base64")) {
    throw "Enterprise auth JIT rollback workflow command must include enterprise auth smoke snapshot base64 input."
}
if (-not ([string] $enterpriseAuthJitRollbackCheck[0].remediation.workflowCommand).Contains("jit_rollback_payload_json_base64")) {
    throw "Enterprise auth JIT rollback workflow command must include JIT rollback payload base64 input."
}
if (-not ([string] $enterpriseAuthJitRollbackCheck[0].requiredEvidence).Contains("result=passed") -or -not ([string] $enterpriseAuthJitRollbackCheck[0].requiredEvidence).Contains("scope-out")) {
    throw "Enterprise auth JIT rollback target evidence must describe passed evidence and scope-out behavior."
}
if (-not ([string] $enterpriseAuthJitRollbackCheck[0].remediation.note).Contains("no raw claims") -or -not ([string] $enterpriseAuthJitRollbackCheck[0].remediation.note).Contains("contractually deferred")) {
    throw "Enterprise auth JIT rollback remediation note must mention no raw claims and scope-out deferral."
}
$operationsHandoffPackageCheck = @($report.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($operationsHandoffPackageCheck.Count -ne 1) {
    throw "Operations readiness report must contain one Operations handoff package target evidence check."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("write-operations-handoff-package.ps1")) {
    throw "Operations handoff package target evidence remediation must point to write-operations-handoff-package.ps1."
}
if ($operationsHandoffPackageCheck[0].remediation.workflow -ne ".github/workflows/manual-operations-handoff-package.yml") {
    throw "Operations handoff package target evidence remediation workflow must point to manual-operations-handoff-package.yml."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("gh workflow run manual-operations-handoff-package.yml")) {
    throw "Operations handoff package target evidence remediation workflow command must dispatch manual-operations-handoff-package.yml."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("-CommercialApprovalEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include CommercialApprovalEvidenceRef."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("CommercialIntegrationJsonPath")) {
    throw "Operations handoff package target evidence remediation must include commercial integration JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("CommercialApprovalJsonPath")) {
    throw "Operations handoff package target evidence remediation must include commercial approval JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ChargebackCloseoutEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include chargeback closeout evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ChargebackCloseoutJsonPath")) {
    throw "Operations handoff package target evidence remediation must include chargeback closeout JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("EnterpriseAuthJsonPath")) {
    throw "Operations handoff package target evidence remediation must include enterprise auth smoke JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("EnterpriseAuthJitRollbackEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include enterprise auth JIT rollback evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("EnterpriseAuthJitRollbackJsonPath")) {
    throw "Operations handoff package target evidence remediation must include enterprise auth JIT rollback JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("MonitoringThresholdJsonPath")) {
    throw "Operations handoff package target evidence remediation must include monitoring threshold JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ClusterNetworkAccessReviewEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include cluster network access review evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ClusterNetworkAccessReviewJsonPath")) {
    throw "Operations handoff package target evidence remediation must include cluster network access review JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("HelmValuesHardeningEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include Helm values hardening evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("HelmValuesHardeningJsonPath")) {
    throw "Operations handoff package target evidence remediation must include Helm values hardening JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmCommercialIntegrationSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm commercial integration snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmCommercialApprovalSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm commercial approval snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmChargebackCloseoutSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm chargeback closeout snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmEnterpriseAuthSmokeSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm enterprise auth smoke snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmEnterpriseAuthJitRollbackSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm enterprise auth JIT rollback snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmMonitoringThresholdReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm monitoring threshold review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmClusterNetworkAccessReviewReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm cluster network access review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmHelmValuesHardeningReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm Helm values hardening review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("OperationsReadinessJsonPath")) {
    throw "Operations handoff package target evidence remediation must include operations readiness JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("OperationsConvergenceJsonPath")) {
    throw "Operations handoff package target evidence remediation must include operations convergence JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStoragePlanEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage plan evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowQueryRetentionBudgetEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include data-flow query/retention budget evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStorageTransitionRunbookEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage transition runbook evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStoragePlanJsonPath")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage plan JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowQueryRetentionBudgetJsonPath")) {
    throw "Operations handoff package target evidence remediation must include data-flow query/retention budget JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStorageTransitionRunbookJsonPath")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage transition runbook JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("SecretRotationJsonPath")) {
    throw "Operations handoff package target evidence remediation must include secret rotation JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmDataFlowQueryRetentionBudgetReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm data-flow query/retention budget review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmSecretRotationSnapshotReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm secret rotation snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("RequireOperationsSnapshotEvidence")) {
    throw "Operations handoff package target evidence remediation must require operations snapshot evidence."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("operations_readiness_json_base64=<base64-json>")) {
    throw "Operations handoff package target evidence workflow command must include operations readiness snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("operations_convergence_json_base64=<base64-json>")) {
    throw "Operations handoff package target evidence workflow command must include operations convergence snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_plan_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage plan evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_query_retention_budget_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow query/retention budget evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_transition_runbook_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage transition runbook evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage plan snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_query_retention_budget_json_base64=<base64-latest-data-flow-query-retention-budget-json>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow query/retention budget snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage transition runbook snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("secret_rotation_json_base64=<base64-latest-secret-rotation-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include secret rotation snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("commercial_integration_json_base64=<base64-latest-commercial-integration-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include commercial integration snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("commercial_approval_json_base64=<base64-latest-commercial-approval-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include commercial approval snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("chargeback_closeout_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include chargeback closeout evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("chargeback_closeout_json_base64=<base64-latest-chargeback-closeout-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include chargeback closeout snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("enterprise_auth_json_base64=<base64-latest-enterprise-auth-smoke-json>")) {
    throw "Operations handoff package target evidence workflow command must include enterprise auth smoke snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("enterprise_auth_jit_rollback_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include enterprise auth JIT rollback evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("enterprise_auth_jit_rollback_json_base64=<base64-latest-enterprise-auth-jit-rollback-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include enterprise auth JIT rollback snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("monitoring_threshold_json_base64=<base64-latest-monitoring-threshold-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include monitoring threshold snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("cluster_network_access_review_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include cluster network access review evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("helm_values_hardening_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include Helm values hardening evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("hardening_evidence_json_payload_base64=<base64-json-with-cluster-network-access-review-and-helm-values-hardening-snapshot-base64>")) {
    throw "Operations handoff package target evidence workflow command must include grouped hardening snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_operations_readiness_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm operations readiness snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_operations_convergence_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm operations convergence snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_data_flow_storage_plan_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm data-flow storage plan review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_data_flow_query_retention_budget_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm data-flow query/retention budget review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_data_flow_storage_transition_runbook_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm data-flow storage transition runbook review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_secret_rotation_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm secret rotation snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_commercial_integration_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm commercial integration snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_commercial_approval_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm commercial approval snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_chargeback_closeout_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm chargeback closeout snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_enterprise_auth_smoke_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm enterprise auth smoke snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_enterprise_auth_jit_rollback_snapshot_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm enterprise auth JIT rollback snapshot review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_monitoring_threshold_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm monitoring threshold review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_cluster_network_access_review_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm cluster network access review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_helm_values_hardening_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm Helm values hardening review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("require_operations_snapshot_evidence=true")) {
    throw "Operations handoff package target evidence workflow command must require operations snapshot evidence."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-operations-readiness.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-operations-readiness-convergence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-data-flow-storage-plan.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-data-flow-query-retention-budget-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-data-flow-storage-transition-runbook-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-secret-rotation-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-commercial-integration-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-commercial-approval-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-chargeback-closeout-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-enterprise-auth-smoke.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-monitoring-threshold-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-cluster-network-access-review-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-helm-values-hardening-evidence.json")) {
    throw "Operations handoff package target evidence remediation note must mention readiness/convergence/data-flow plan/data-flow query-retention/data-flow runbook/secret rotation/commercial/chargeback closeout/enterprise auth/monitoring threshold/cluster network access review/Helm values hardening snapshots."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-enterprise-auth-jit-rollback-evidence.json")) {
    throw "Operations handoff package target evidence remediation note must mention enterprise auth JIT rollback snapshot."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("chargeback closeout")) {
    throw "Operations handoff package target evidence remediation note must mention chargeback closeout review confirmation."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("enterprise auth smoke")) {
    throw "Operations handoff package target evidence remediation note must mention enterprise auth smoke review confirmation."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("reduced to sanitized result/count/sync/query-plan/query-retention/runbook/secret-rotation/commercial/chargeback closeout/enterprise auth smoke/JIT rollback/monitoring threshold/cluster network/Helm hardening summary fields")) {
    throw "Operations handoff package target evidence remediation note must describe sanitized snapshot reduction."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("object keys")) {
    throw "Operations handoff package target evidence remediation note must mention object-key exclusion."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("raw event messages")) {
    throw "Operations handoff package target evidence remediation note must mention raw event message exclusion."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("raw Alertmanager receiver secrets")) {
    throw "Operations handoff package target evidence remediation note must mention raw Alertmanager receiver secret exclusion."
}
if (-not ([string] $operationsHandoffPackageCheck[0].requiredEvidence).Contains("target environment")) {
    throw "Operations handoff package target evidence must require target environment evidence."
}
if (-not ([string] $operationsHandoffPackageCheck[0].requiredEvidence).Contains("required handoff review/production/snapshot confirmations")) {
    throw "Operations handoff package target evidence must require handoff review/production/snapshot confirmations."
}

Assert-Contains $markdown "# OSMU Operations Readiness" "Operations readiness markdown"
Assert-Contains $markdown "Production/B2B operations readiness" "Operations readiness markdown"
Assert-Contains $markdown "Storage expansion finalizer live evidence" "Operations readiness markdown"
Assert-Contains $markdown "Kubernetes DR finalizer live evidence" "Operations readiness markdown"
Assert-Contains $markdown "Security evidence finalizer report" "Operations readiness markdown"
Assert-Contains $markdown "Storage backend telemetry target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Monitoring threshold target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Secret/certificate rotation target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Commercial integration target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Commercial approval target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Chargeback closeout target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Enterprise auth target smoke evidence" "Operations readiness markdown"
Assert-Contains $markdown "Enterprise auth JIT rollback target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Operations handoff package target evidence" "Operations readiness markdown"
Assert-Contains $markdown "Required Next Evidence" "Operations readiness markdown"
Assert-Contains $markdown "Remediation command" "Operations readiness markdown"
Assert-Contains $markdown "Workflow" "Operations readiness markdown"
Assert-Contains $markdown "Workflow command" "Operations readiness markdown"

$targetGuardFixtureDirectory = Resolve-ProjectPath ".\.osmu-run\operations-readiness-target-guard-self-test"
New-Item -ItemType Directory -Force -Path $targetGuardFixtureDirectory | Out-Null

$selfTestChargebackCloseoutEvidencePath = Join-Path $targetGuardFixtureDirectory "self-test-chargeback-closeout.json"
$selfTestChargebackCloseoutJsonOutputPath = Join-Path $targetGuardFixtureDirectory "self-test-chargeback-readiness.json"
$selfTestChargebackCloseoutMarkdownOutputPath = Join-Path $targetGuardFixtureDirectory "self-test-chargeback-readiness.md"
@{
    formatVersion = "osmu.chargeback-closeout-evidence.v1"
    result = "passed"
    target = @{
        environmentName = "pilot-prod-self-test"
        targetCluster = "customer-cluster-a"
        operator = "ops-self-test"
        billingPeriod = "2026-06"
        closeoutStartedAt = "2026-06-30T01:00:00Z"
        closeoutCompletedAt = "2026-06-30T01:45:00Z"
    }
    summary = @{
        checkCount = 40
        passCount = 40
        failureCount = 0
        plannedCount = 0
        providedEvidenceRefCount = 14
        requiredEvidenceRefCount = 14
        paymentProviderAdapterReadinessSnapshotValid = $true
        paymentProviderAdapterReadinessReviewed = $true
        chargebackCloseoutSnapshotValid = $true
        chargebackCloseoutSnapshotReady = $true
        chargebackCloseoutSnapshotBlockerCount = 0
        chargebackCloseoutSnapshotScanLimit = 500
        chargebackCloseoutSnapshotSourceTruncated = $false
        chargebackCloseoutSnapshotTruncationBlockerCount = 0
        commercialEvidenceReviewed = $true
    }
    chargebackCloseoutSnapshot = @{
        valid = $true
        statusClosed = $true
        billingPeriodMatches = $true
        integersValid = $true
        booleansValid = $true
        failureCountZero = $true
        blockerCountZero = $true
        scanLimitPositive = $true
        sourceTruncated = $false
        sourceComplete = $true
        truncationBlockerCountZero = $true
        closeoutReady = $true
        readinessBooleansClosed = $true
        noRawDataStored = $true
        counts = @{
            scanLimit = 500
            failureCount = 0
            blockerCount = 0
            truncationBlockerCount = 0
            reconciliationDifferenceMinorUnits = 0
        }
        rawDataFlags = @{
            rawCustomerPaymentDataStored = $false
            rawProviderResponseStored = $false
            rawSecretValuesStored = $false
        }
    }
    checks = @()
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $selfTestChargebackCloseoutEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ChargebackCloseoutEvidencePath $selfTestChargebackCloseoutEvidencePath `
    -JsonOutputPath $selfTestChargebackCloseoutJsonOutputPath `
    -MarkdownOutputPath $selfTestChargebackCloseoutMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for self-test chargeback closeout fixture with exit code $LASTEXITCODE."
}
$selfTestChargebackCloseoutReport = Read-Utf8Text $selfTestChargebackCloseoutJsonOutputPath | ConvertFrom-Json
$selfTestChargebackCloseoutCheck = @($selfTestChargebackCloseoutReport.checks | Where-Object { $_.name -eq "Chargeback closeout target evidence" })
if ($selfTestChargebackCloseoutCheck.Count -ne 1 -or $selfTestChargebackCloseoutCheck[0].passed) {
    throw "Self-test chargeback closeout evidence must not satisfy the operations readiness target check."
}
if (-not ([string] $selfTestChargebackCloseoutCheck[0].detail).Contains("rejected=self-test-target-evidence")) {
    throw "Self-test chargeback closeout detail must explain target evidence rejection."
}

$completeChargebackCloseoutEvidencePath = Join-Path $targetGuardFixtureDirectory "complete-chargeback-closeout.json"
$completeChargebackCloseoutJsonOutputPath = Join-Path $targetGuardFixtureDirectory "complete-chargeback-readiness.json"
$completeChargebackCloseoutMarkdownOutputPath = Join-Path $targetGuardFixtureDirectory "complete-chargeback-readiness.md"
$completeChargebackCloseout = Read-Utf8Text $selfTestChargebackCloseoutEvidencePath | ConvertFrom-Json
$completeChargebackCloseout.target.environmentName = "pilot-prod"
$completeChargebackCloseout.target.operator = "billing-ops"
$completeChargebackCloseout | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $completeChargebackCloseoutEvidencePath -Encoding UTF8
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ChargebackCloseoutEvidencePath $completeChargebackCloseoutEvidencePath `
    -JsonOutputPath $completeChargebackCloseoutJsonOutputPath `
    -MarkdownOutputPath $completeChargebackCloseoutMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for complete chargeback closeout fixture with exit code $LASTEXITCODE."
}
$completeChargebackCloseoutReport = Read-Utf8Text $completeChargebackCloseoutJsonOutputPath | ConvertFrom-Json
$completeChargebackCloseoutCheck = @($completeChargebackCloseoutReport.checks | Where-Object { $_.name -eq "Chargeback closeout target evidence" })
if ($completeChargebackCloseoutCheck.Count -ne 1 -or -not $completeChargebackCloseoutCheck[0].passed) {
    throw "Complete chargeback closeout evidence must satisfy the operations readiness target check."
}
if (-not ([string] $completeChargebackCloseoutCheck[0].detail).Contains("scanLimit=500") -or -not ([string] $completeChargebackCloseoutCheck[0].detail).Contains("sourceTruncated=False")) {
    throw "Complete chargeback closeout detail must expose scan completeness."
}

$truncatedChargebackCloseoutEvidencePath = Join-Path $targetGuardFixtureDirectory "truncated-chargeback-closeout.json"
$truncatedChargebackCloseoutJsonOutputPath = Join-Path $targetGuardFixtureDirectory "truncated-chargeback-readiness.json"
$truncatedChargebackCloseoutMarkdownOutputPath = Join-Path $targetGuardFixtureDirectory "truncated-chargeback-readiness.md"
$completeChargebackCloseout.summary.chargebackCloseoutSnapshotReady = $false
$completeChargebackCloseout.summary.chargebackCloseoutSnapshotSourceTruncated = $true
$completeChargebackCloseout.summary.chargebackCloseoutSnapshotTruncationBlockerCount = 1
$completeChargebackCloseout.chargebackCloseoutSnapshot.sourceTruncated = $true
$completeChargebackCloseout.chargebackCloseoutSnapshot.sourceComplete = $false
$completeChargebackCloseout.chargebackCloseoutSnapshot.truncationBlockerCountZero = $false
$completeChargebackCloseout.chargebackCloseoutSnapshot.closeoutReady = $false
$completeChargebackCloseout.chargebackCloseoutSnapshot.counts.truncationBlockerCount = 1
$completeChargebackCloseout | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $truncatedChargebackCloseoutEvidencePath -Encoding UTF8
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ChargebackCloseoutEvidencePath $truncatedChargebackCloseoutEvidencePath `
    -JsonOutputPath $truncatedChargebackCloseoutJsonOutputPath `
    -MarkdownOutputPath $truncatedChargebackCloseoutMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for truncated chargeback closeout fixture with exit code $LASTEXITCODE."
}
$truncatedChargebackCloseoutReport = Read-Utf8Text $truncatedChargebackCloseoutJsonOutputPath | ConvertFrom-Json
$truncatedChargebackCloseoutCheck = @($truncatedChargebackCloseoutReport.checks | Where-Object { $_.name -eq "Chargeback closeout target evidence" })
if ($truncatedChargebackCloseoutCheck.Count -ne 1 -or $truncatedChargebackCloseoutCheck[0].passed) {
    throw "Truncated chargeback closeout evidence must not satisfy the operations readiness target check."
}
if (-not ([string] $truncatedChargebackCloseoutCheck[0].detail).Contains("sourceTruncated=True") -or -not ([string] $truncatedChargebackCloseoutCheck[0].detail).Contains("truncationBlockers=1")) {
    throw "Truncated chargeback closeout detail must explain the incomplete source."
}

$selfTestEnterpriseAuthSmokeEvidencePath = Join-Path $targetGuardFixtureDirectory "self-test-enterprise-auth-smoke.json"
$selfTestEnterpriseAuthSmokeJsonOutputPath = Join-Path $targetGuardFixtureDirectory "self-test-enterprise-auth-readiness.json"
$selfTestEnterpriseAuthSmokeMarkdownOutputPath = Join-Path $targetGuardFixtureDirectory "self-test-enterprise-auth-readiness.md"
@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "passed"
    target = @{
        environmentName = "pilot-prod-self-test"
        targetCluster = "customer-cluster-a"
        operator = "security-self-test"
    }
    summary = @{
        passCount = 4
        failCount = 0
        blockedCount = 0
        plannedCount = 0
        skippedCount = 0
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $selfTestEnterpriseAuthSmokeEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnterpriseAuthSmokeEvidencePath $selfTestEnterpriseAuthSmokeEvidencePath `
    -JsonOutputPath $selfTestEnterpriseAuthSmokeJsonOutputPath `
    -MarkdownOutputPath $selfTestEnterpriseAuthSmokeMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for self-test enterprise auth smoke fixture with exit code $LASTEXITCODE."
}
$selfTestEnterpriseAuthSmokeReport = Read-Utf8Text $selfTestEnterpriseAuthSmokeJsonOutputPath | ConvertFrom-Json
$selfTestEnterpriseAuthSmokeCheck = @($selfTestEnterpriseAuthSmokeReport.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($selfTestEnterpriseAuthSmokeCheck.Count -ne 1 -or $selfTestEnterpriseAuthSmokeCheck[0].passed) {
    throw "Self-test enterprise auth smoke evidence must not satisfy the operations readiness target check."
}
if (-not ([string] $selfTestEnterpriseAuthSmokeCheck[0].detail).Contains("rejected=self-test-target-evidence")) {
    throw "Self-test enterprise auth smoke detail must explain target evidence rejection."
}

$selfTestDataFlowRunbookEvidencePath = Join-Path $targetGuardFixtureDirectory "self-test-data-flow-storage-transition-runbook.json"
$selfTestDataFlowRunbookJsonOutputPath = Join-Path $targetGuardFixtureDirectory "self-test-data-flow-runbook-readiness.json"
$selfTestDataFlowRunbookMarkdownOutputPath = Join-Path $targetGuardFixtureDirectory "self-test-data-flow-runbook-readiness.md"
@{
    formatVersion = "osmu.data-flow-storage-transition-runbook-evidence.v1"
    result = "passed"
    target = @{
        environmentName = "pilot-prod-self-test"
        targetCluster = "customer-cluster-a"
        operator = "data-self-test"
    }
    dataFlowStoragePlanSnapshot = @{
        result = "passed"
        candidateStore = "mariadb-partition"
        queryPlanEvidence = @{
            result = "passed"
            failedCount = 0
            summary = "sanitized query plan evidence"
        }
    }
    summary = @{
        failureCount = 0
    }
    confirmations = @{
        backfillRehearsed = $true
        dualWriteOrPartitionToggleReviewed = $true
        rollbackRehearsed = $true
        reconciliationPassed = $true
        dashboardCutoverReviewed = $true
        retentionDryRunReviewed = $true
        noObjectKeysInAggregates = $true
        noSecretValues = $true
    }
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $selfTestDataFlowRunbookEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -DataFlowStorageTransitionRunbookEvidencePath $selfTestDataFlowRunbookEvidencePath `
    -JsonOutputPath $selfTestDataFlowRunbookJsonOutputPath `
    -MarkdownOutputPath $selfTestDataFlowRunbookMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for self-test data-flow runbook fixture with exit code $LASTEXITCODE."
}
$selfTestDataFlowRunbookReport = Read-Utf8Text $selfTestDataFlowRunbookJsonOutputPath | ConvertFrom-Json
$selfTestDataFlowRunbookCheck = @($selfTestDataFlowRunbookReport.checks | Where-Object { $_.name -eq "Data-flow storage transition runbook target evidence" })
if ($selfTestDataFlowRunbookCheck.Count -ne 1 -or $selfTestDataFlowRunbookCheck[0].passed) {
    throw "Self-test data-flow runbook evidence must not satisfy the operations readiness target check."
}
if (-not ([string] $selfTestDataFlowRunbookCheck[0].detail).Contains("rejected=self-test-target-evidence")) {
    throw "Self-test data-flow runbook detail must explain target evidence rejection."
}

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
$scopeOutReport = Read-Utf8Text $scopeOutJsonOutputPath | ConvertFrom-Json
$scopeOutEnterpriseAuthCheck = @($scopeOutReport.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($scopeOutEnterpriseAuthCheck.Count -ne 1 -or -not $scopeOutEnterpriseAuthCheck[0].passed) {
    throw "Enterprise auth scope-out evidence must satisfy the operations readiness enterprise-auth check."
}
if (-not ([string] $scopeOutEnterpriseAuthCheck[0].detail).Contains("result=scope-out")) {
    throw "Enterprise auth scope-out readiness detail must preserve result=scope-out."
}
$scopeOutEnterpriseAuthJitRollbackCheck = @($scopeOutReport.checks | Where-Object { $_.name -eq "Enterprise auth JIT rollback target evidence" })
if ($scopeOutEnterpriseAuthJitRollbackCheck.Count -ne 1 -or -not $scopeOutEnterpriseAuthJitRollbackCheck[0].passed) {
    throw "Enterprise auth scope-out evidence must satisfy the JIT rollback readiness check without requiring JIT evidence."
}
if (-not ([string] $scopeOutEnterpriseAuthJitRollbackCheck[0].detail).Contains("not required")) {
    throw "Enterprise auth scope-out JIT rollback detail must explain why JIT rollback is not required."
}

$stringAcceptedScopeOutEvidencePath = Join-Path $scopeOutFixtureDirectory "latest-enterprise-auth-smoke-string-accepted.json"
$stringAcceptedScopeOutJsonOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-string-accepted.json"
$stringAcceptedScopeOutMarkdownOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-string-accepted.md"
@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "scope-out"
    scopeOut = @{
        confirmed = $true
        reference = "pilot-contract-enterprise-auth-deferred-20260620"
        reason = "Pilot phase uses local password login."
        accepted = "false"
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $stringAcceptedScopeOutEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnterpriseAuthSmokeEvidencePath $stringAcceptedScopeOutEvidencePath `
    -JsonOutputPath $stringAcceptedScopeOutJsonOutputPath `
    -MarkdownOutputPath $stringAcceptedScopeOutMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for string-accepted enterprise auth scope-out fixture with exit code $LASTEXITCODE."
}
$stringAcceptedScopeOutReport = Read-Utf8Text $stringAcceptedScopeOutJsonOutputPath | ConvertFrom-Json
$stringAcceptedEnterpriseAuthCheck = @($stringAcceptedScopeOutReport.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($stringAcceptedEnterpriseAuthCheck.Count -ne 1 -or $stringAcceptedEnterpriseAuthCheck[0].passed) {
    throw "Enterprise auth scope-out evidence with string accepted=false must not satisfy the operations readiness enterprise-auth check."
}
if (-not ([string] $stringAcceptedEnterpriseAuthCheck[0].detail).Contains("scopeOut.accepted=false(valid=False)")) {
    throw "Enterprise auth string accepted readiness detail must name invalid accepted value."
}

$stringCountPassedEnterpriseAuthEvidencePath = Join-Path $scopeOutFixtureDirectory "latest-enterprise-auth-smoke-passed-string-count.json"
$stringCountPassedEnterpriseAuthJsonOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-passed-string-count.json"
$stringCountPassedEnterpriseAuthMarkdownOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-passed-string-count.md"
@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "passed"
    summary = @{
        passCount = 4
        failCount = "0"
        blockedCount = 0
        plannedCount = 0
        skippedCount = 0
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $stringCountPassedEnterpriseAuthEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnterpriseAuthSmokeEvidencePath $stringCountPassedEnterpriseAuthEvidencePath `
    -JsonOutputPath $stringCountPassedEnterpriseAuthJsonOutputPath `
    -MarkdownOutputPath $stringCountPassedEnterpriseAuthMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for string-count passed enterprise auth fixture with exit code $LASTEXITCODE."
}
$stringCountPassedEnterpriseAuthReport = Read-Utf8Text $stringCountPassedEnterpriseAuthJsonOutputPath | ConvertFrom-Json
$stringCountPassedEnterpriseAuthCheck = @($stringCountPassedEnterpriseAuthReport.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($stringCountPassedEnterpriseAuthCheck.Count -ne 1 -or $stringCountPassedEnterpriseAuthCheck[0].passed) {
    throw "Enterprise auth passed evidence with string count must not satisfy the operations readiness enterprise-auth check."
}
if (-not ([string] $stringCountPassedEnterpriseAuthCheck[0].detail).Contains("failCount=0(valid=False)")) {
    throw "Enterprise auth string count readiness detail must name invalid count value."
}

$passedEnterpriseAuthEvidencePath = Join-Path $scopeOutFixtureDirectory "latest-enterprise-auth-smoke-passed.json"
$passedEnterpriseAuthJitRollbackEvidencePath = Join-Path $scopeOutFixtureDirectory "latest-enterprise-auth-jit-rollback-evidence.json"
$passedEnterpriseAuthJitRollbackJsonOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-jit-rollback-passed.json"
$passedEnterpriseAuthJitRollbackMarkdownOutputPath = Join-Path $scopeOutFixtureDirectory "latest-operations-readiness-jit-rollback-passed.md"
@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    result = "passed"
    summary = @{
        passCount = 4
        failCount = 0
        blockedCount = 0
        plannedCount = 0
        skippedCount = 0
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $passedEnterpriseAuthEvidencePath -Encoding UTF8
@{
    formatVersion = "osmu.enterprise-auth-jit-rollback-evidence.v1"
    result = "passed"
    summary = @{
        failureCount = 0
        checkCount = 12
    }
    confirmations = @{
        adminApprovalRequired = $true
        callbackAutoJitDisabled = $true
        jitUserDisableOrLockRollbackReviewed = $true
        roleOrgTeamRollbackReviewed = $true
        localPasswordFallbackValidated = $true
        auditEventsReviewed = $true
        noRawClaims = $true
        noSecretValues = $true
    }
    enterpriseAuthSmokeSnapshot = @{
        provided = $true
        parsed = $true
        formatVersion = "osmu.enterprise-auth-smoke.v1"
        result = "passed"
        passCount = 4
        failCount = 0
        blockedCount = 0
        plannedCount = 0
        skippedCount = 0
        scopeOutAccepted = $false
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $passedEnterpriseAuthJitRollbackEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -EnterpriseAuthSmokeEvidencePath $passedEnterpriseAuthEvidencePath `
    -EnterpriseAuthJitRollbackEvidencePath $passedEnterpriseAuthJitRollbackEvidencePath `
    -JsonOutputPath $passedEnterpriseAuthJitRollbackJsonOutputPath `
    -MarkdownOutputPath $passedEnterpriseAuthJitRollbackMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for passed enterprise auth JIT rollback fixture with exit code $LASTEXITCODE."
}
$passedEnterpriseAuthJitRollbackReport = Read-Utf8Text $passedEnterpriseAuthJitRollbackJsonOutputPath | ConvertFrom-Json
$passedEnterpriseAuthSmokeCheck = @($passedEnterpriseAuthJitRollbackReport.checks | Where-Object { $_.name -eq "Enterprise auth target smoke evidence" })
if ($passedEnterpriseAuthSmokeCheck.Count -ne 1 -or -not $passedEnterpriseAuthSmokeCheck[0].passed) {
    throw "Passed enterprise auth smoke fixture must satisfy the readiness smoke check."
}
$passedEnterpriseAuthJitRollbackCheck = @($passedEnterpriseAuthJitRollbackReport.checks | Where-Object { $_.name -eq "Enterprise auth JIT rollback target evidence" })
if ($passedEnterpriseAuthJitRollbackCheck.Count -ne 1 -or -not $passedEnterpriseAuthJitRollbackCheck[0].passed) {
    throw "Passed enterprise auth JIT rollback fixture must satisfy the readiness JIT rollback check."
}
if (-not ([string] $passedEnterpriseAuthJitRollbackCheck[0].detail).Contains("smokeResult=passed") -or -not ([string] $passedEnterpriseAuthJitRollbackCheck[0].detail).Contains("confirmations=8/8")) {
    throw "Passed enterprise auth JIT rollback detail must preserve smoke result and confirmation count."
}

$handoffFixtureDirectory = Resolve-ProjectPath ".\.osmu-run\operations-readiness-handoff-package-self-test"
New-Item -ItemType Directory -Force -Path $handoffFixtureDirectory | Out-Null
$validHandoffEvidencePath = Join-Path $handoffFixtureDirectory "valid-operations-handoff-package.json"
$validHandoffJsonOutputPath = Join-Path $handoffFixtureDirectory "valid-operations-readiness.json"
$validHandoffMarkdownOutputPath = Join-Path $handoffFixtureDirectory "valid-operations-readiness.md"
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
    targetEvidenceSnapshots = (New-PassedOperationsHandoffPackageTargetSnapshots)
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $validHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $validHandoffEvidencePath `
    -JsonOutputPath $validHandoffJsonOutputPath `
    -MarkdownOutputPath $validHandoffMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for valid operations handoff package fixture with exit code $LASTEXITCODE."
}
$validHandoffReport = Read-Utf8Text $validHandoffJsonOutputPath | ConvertFrom-Json
$validHandoffCheck = @($validHandoffReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($validHandoffCheck.Count -ne 1 -or -not $validHandoffCheck[0].passed) {
    throw "Operations readiness must accept a passed handoff package only when required confirmations are present."
}
if (-not ([string] $validHandoffCheck[0].detail).Contains("requiredConfirmations=21") -or -not ([string] $validHandoffCheck[0].detail).Contains("sourceReportResult=ready")) {
    throw "Operations handoff package readiness detail must record required confirmation and strict snapshot validation."
}

$selfTestHandoffEvidencePath = Join-Path $handoffFixtureDirectory "self-test-operations-handoff-package.json"
$selfTestHandoffJsonOutputPath = Join-Path $handoffFixtureDirectory "self-test-operations-readiness.json"
$selfTestHandoffMarkdownOutputPath = Join-Path $handoffFixtureDirectory "self-test-operations-readiness.md"
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    target = @{
        environmentName = "pilot-prod-self-test"
        targetCluster = "customer-cluster-a"
        operator = "ops-self-test"
    }
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
    targetEvidenceSnapshots = (New-PassedOperationsHandoffPackageTargetSnapshots)
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $selfTestHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $selfTestHandoffEvidencePath `
    -JsonOutputPath $selfTestHandoffJsonOutputPath `
    -MarkdownOutputPath $selfTestHandoffMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for self-test operations handoff package fixture with exit code $LASTEXITCODE."
}
$selfTestHandoffReport = Read-Utf8Text $selfTestHandoffJsonOutputPath | ConvertFrom-Json
$selfTestHandoffCheck = @($selfTestHandoffReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($selfTestHandoffCheck.Count -ne 1 -or $selfTestHandoffCheck[0].passed) {
    throw "Self-test operations handoff package evidence must not satisfy the operations readiness target check."
}
if (-not ([string] $selfTestHandoffCheck[0].detail).Contains("rejected=self-test-target-evidence")) {
    throw "Self-test operations handoff package detail must explain target evidence rejection."
}

$staleHandoffEvidencePath = Join-Path $handoffFixtureDirectory "stale-operations-handoff-package.json"
$staleHandoffJsonOutputPath = Join-Path $handoffFixtureDirectory "stale-operations-readiness.json"
$staleHandoffMarkdownOutputPath = Join-Path $handoffFixtureDirectory "stale-operations-readiness.md"
$staleConfirmations = New-PassedOperationsHandoffPackageConfirmations
$staleConfirmations["commercialApprovalSnapshotReviewed"] = $false
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = $staleConfirmations
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots)
    targetEvidenceSnapshots = (New-PassedOperationsHandoffPackageTargetSnapshots)
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $staleHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $staleHandoffEvidencePath `
    -JsonOutputPath $staleHandoffJsonOutputPath `
    -MarkdownOutputPath $staleHandoffMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for stale operations handoff package fixture with exit code $LASTEXITCODE."
}
$staleHandoffReport = Read-Utf8Text $staleHandoffJsonOutputPath | ConvertFrom-Json
$staleHandoffCheck = @($staleHandoffReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($staleHandoffCheck.Count -ne 1 -or $staleHandoffCheck[0].passed) {
    throw "Operations readiness must not accept a passed handoff package when required confirmations are missing."
}
if (-not ([string] $staleHandoffCheck[0].detail).Contains("commercialApprovalSnapshotReviewed")) {
    throw "Operations readiness stale handoff package detail must name the missing confirmation."
}

$badConvergenceHandoffEvidencePath = Join-Path $handoffFixtureDirectory "bad-convergence-operations-handoff-package.json"
$badConvergenceJsonOutputPath = Join-Path $handoffFixtureDirectory "bad-convergence-operations-readiness.json"
$badConvergenceMarkdownOutputPath = Join-Path $handoffFixtureDirectory "bad-convergence-operations-readiness.md"
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots -ConvergenceSourceReportResult "action-required")
    targetEvidenceSnapshots = (New-PassedOperationsHandoffPackageTargetSnapshots)
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $badConvergenceHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $badConvergenceHandoffEvidencePath `
    -JsonOutputPath $badConvergenceJsonOutputPath `
    -MarkdownOutputPath $badConvergenceMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for bad convergence handoff package fixture with exit code $LASTEXITCODE."
}
$badConvergenceReport = Read-Utf8Text $badConvergenceJsonOutputPath | ConvertFrom-Json
$badConvergenceCheck = @($badConvergenceReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($badConvergenceCheck.Count -ne 1 -or $badConvergenceCheck[0].passed) {
    throw "Operations readiness must reject a handoff package whose convergence sync source is not ready."
}
if (-not ([string] $badConvergenceCheck[0].detail).Contains("sourceReportResult=action-required")) {
    throw "Operations readiness bad convergence handoff detail must name the non-ready source report result."
}

$stringBoolHandoffEvidencePath = Join-Path $handoffFixtureDirectory "string-bool-operations-handoff-package.json"
$stringBoolJsonOutputPath = Join-Path $handoffFixtureDirectory "string-bool-operations-readiness.json"
$stringBoolMarkdownOutputPath = Join-Path $handoffFixtureDirectory "string-bool-operations-readiness.md"
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    operationsSnapshots = (New-PassedOperationsHandoffPackageSnapshots -KubernetesReportSyncReady "false")
    targetEvidenceSnapshots = (New-PassedOperationsHandoffPackageTargetSnapshots)
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $stringBoolHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $stringBoolHandoffEvidencePath `
    -JsonOutputPath $stringBoolJsonOutputPath `
    -MarkdownOutputPath $stringBoolMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for string-bool handoff package fixture with exit code $LASTEXITCODE."
}
$stringBoolReport = Read-Utf8Text $stringBoolJsonOutputPath | ConvertFrom-Json
$stringBoolCheck = @($stringBoolReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($stringBoolCheck.Count -ne 1 -or $stringBoolCheck[0].passed) {
    throw "Operations readiness must reject a handoff package whose convergence sync boolean is a string."
}
if (-not ([string] $stringBoolCheck[0].detail).Contains("kubernetesReportSyncReady=false")) {
    throw "Operations readiness string-bool handoff detail must name the invalid sync ready value."
}

$missingCountHandoffEvidencePath = Join-Path $handoffFixtureDirectory "missing-count-operations-handoff-package.json"
$missingCountJsonOutputPath = Join-Path $handoffFixtureDirectory "missing-count-operations-readiness.json"
$missingCountMarkdownOutputPath = Join-Path $handoffFixtureDirectory "missing-count-operations-readiness.md"
$missingCountSnapshots = New-PassedOperationsHandoffPackageSnapshots
$missingCountSnapshots["convergence"].Remove("finalizerGapCount")
@{
    formatVersion = "osmu.operations-handoff-package.v1"
    result = "passed"
    confirmations = (New-PassedOperationsHandoffPackageConfirmations)
    operationsSnapshots = $missingCountSnapshots
    targetEvidenceSnapshots = (New-PassedOperationsHandoffPackageTargetSnapshots)
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $missingCountHandoffEvidencePath -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -OperationsHandoffPackagePath $missingCountHandoffEvidencePath `
    -JsonOutputPath $missingCountJsonOutputPath `
    -MarkdownOutputPath $missingCountMarkdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-readiness.ps1 failed for missing-count handoff package fixture with exit code $LASTEXITCODE."
}
$missingCountReport = Read-Utf8Text $missingCountJsonOutputPath | ConvertFrom-Json
$missingCountCheck = @($missingCountReport.checks | Where-Object { $_.name -eq "Operations handoff package target evidence" })
if ($missingCountCheck.Count -ne 1 -or $missingCountCheck[0].passed) {
    throw "Operations readiness must reject a handoff package whose convergence finalizer gap count is missing."
}
if (-not ([string] $missingCountCheck[0].detail).Contains("finalizerGapCount=<missing>")) {
    throw "Operations readiness missing-count handoff detail must name the missing finalizer gap count."
}

Write-Host "Operations readiness artifact verified."
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"
