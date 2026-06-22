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
Assert-CheckExists $report "Storage backend telemetry evidence writer" "storage-backend"
Assert-CheckExists $report "Storage backend telemetry evidence writer self-test" "storage-backend"
Assert-CheckExists $report "MariaDB query plan evidence writer" "data-flow"
Assert-CheckExists $report "MariaDB query plan evidence self-test" "data-flow"
Assert-CheckExists $report "Data-flow storage plan writer" "data-flow"
Assert-CheckExists $report "Data-flow storage plan self-test" "data-flow"
Assert-CheckExists $report "Secret rotation evidence writer" "security-hardening"
Assert-CheckExists $report "Secret rotation evidence writer self-test" "security-hardening"
Assert-CheckExists $report "Secret rotation evidence workflow" "security-hardening"
Assert-CheckExists $report "Commercial integration evidence writer" "commercial-integration"
Assert-CheckExists $report "Commercial integration evidence writer self-test" "commercial-integration"
Assert-CheckExists $report "Commercial integration evidence workflow" "commercial-integration"
Assert-CheckExists $report "Commercial approval evidence writer" "commercial-approval"
Assert-CheckExists $report "Commercial approval evidence writer self-test" "commercial-approval"
Assert-CheckExists $report "Commercial approval evidence workflow" "commercial-approval"
Assert-CheckExists $report "Operations handoff package writer" "operations-handoff-package"
Assert-CheckExists $report "Operations handoff package writer self-test" "operations-handoff-package"
Assert-CheckExists $report "Operations handoff package workflow" "operations-handoff-package"
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
Assert-CheckExists $report "Storage backend telemetry target evidence" "storage-backend"
Assert-CheckExists $report "Data-flow storage transition target evidence" "data-flow"
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
if (-not ([string] $commercialIntegrationCheck[0].remediation.note).Contains("does not claim or require native card/bank/tax/ERP processor API support")) {
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
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("EnterpriseAuthJsonPath")) {
    throw "Operations handoff package target evidence remediation must include enterprise auth smoke JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("MonitoringThresholdJsonPath")) {
    throw "Operations handoff package target evidence remediation must include monitoring threshold JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("ConfirmMonitoringThresholdReviewed")) {
    throw "Operations handoff package target evidence remediation must confirm monitoring threshold review."
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
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStorageTransitionRunbookEvidenceRef")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage transition runbook evidence reference."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStoragePlanJsonPath")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage plan JSON snapshot input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.command).Contains("DataFlowStorageTransitionRunbookJsonPath")) {
    throw "Operations handoff package target evidence remediation must include data-flow storage transition runbook JSON snapshot input."
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
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_transition_runbook_evidence_ref=<ref>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage transition runbook evidence reference input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage plan snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>")) {
    throw "Operations handoff package target evidence workflow command must include data-flow storage transition runbook snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("commercial_integration_json_base64=<base64-latest-commercial-integration-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include commercial integration snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("commercial_approval_json_base64=<base64-latest-commercial-approval-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include commercial approval snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("enterprise_auth_json_base64=<base64-latest-enterprise-auth-smoke-json>")) {
    throw "Operations handoff package target evidence workflow command must include enterprise auth smoke snapshot base64 input."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("monitoring_threshold_json_base64=<base64-latest-monitoring-threshold-evidence-json>")) {
    throw "Operations handoff package target evidence workflow command must include monitoring threshold snapshot base64 input."
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
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_data_flow_storage_transition_runbook_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm data-flow storage transition runbook review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("confirm_monitoring_threshold_reviewed=true")) {
    throw "Operations handoff package target evidence workflow command must confirm monitoring threshold review."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.workflowCommand).Contains("require_operations_snapshot_evidence=true")) {
    throw "Operations handoff package target evidence workflow command must require operations snapshot evidence."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-operations-readiness.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-operations-readiness-convergence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-data-flow-storage-plan.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-data-flow-storage-transition-runbook-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-commercial-integration-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-commercial-approval-evidence.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-enterprise-auth-smoke.json") -or -not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("latest-monitoring-threshold-evidence.json")) {
    throw "Operations handoff package target evidence remediation note must mention readiness/convergence/data-flow plan/data-flow runbook/commercial/enterprise auth/monitoring threshold snapshots."
}
if (-not ([string] $operationsHandoffPackageCheck[0].remediation.note).Contains("reduced to sanitized result/count/sync/query-plan/runbook/commercial/enterprise auth scope-out/monitoring threshold summary fields")) {
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

Assert-Contains $markdown "# OSMU Operations Readiness" "Operations readiness markdown"
Assert-Contains $markdown "Production/B2B operations readiness" "Operations readiness markdown"
Assert-Contains $markdown "Storage expansion finalizer live evidence" "Operations readiness markdown"
Assert-Contains $markdown "Kubernetes DR finalizer live evidence" "Operations readiness markdown"
Assert-Contains $markdown "Security evidence finalizer report" "Operations readiness markdown"
Assert-Contains $markdown "Storage backend telemetry target evidence" "Operations readiness markdown"
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
