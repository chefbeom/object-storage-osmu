param(
    [string] $InvocationReportPath = ".\.osmu-run\latest-operations-evidence-plan-invocation.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-artifact-collection-plan.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-artifact-collection-plan.md",
    [string] $StorageExpansionRunId = "",
    [string] $HaDrReadinessRunId = "",
    [string] $KubernetesDrRunId = "",
    [string] $IamRbacRunId = "",
    [string] $ImageSigningRunId = "",
    [string] $ContainerSecurityRunId = "",
    [string] $SecurityEvidenceRunId = "",
    [string] $StorageBackendTelemetryRunId = "",
    [string] $MinioBucketCorsRunId = "",
    [string] $MonitoringThresholdRunId = "",
    [string] $SecretRotationRunId = "",
    [string] $ClusterNetworkAccessReviewRunId = "",
    [string] $HelmValuesHardeningRunId = "",
    [string] $SupportEscalationHandoffRunId = "",
    [string] $CommercialIntegrationRunId = "",
    [string] $CommercialApprovalRunId = "",
    [string] $ChargebackCloseoutRunId = "",
    [string] $EnterpriseAuthRunId = "",
    [string] $EnterpriseAuthJitRollbackRunId = "",
    [string] $OperationsHandoffPackageRunId = "",
    [string] $DataFlowStoragePlanRunId = "",
    [string] $DataFlowQueryRetentionBudgetRunId = "",
    [string] $DataFlowStorageTransitionRunbookRunId = "",
    [string] $KubernetesOperationsReportSyncRunId = "",
    [string] $ImageSigningVersion = "v0.1.0-rc.1",
    [string] $CommitSha = "<commit-sha>",
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}
function Get-JsonProperty([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-Text([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Get-Int([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return 0
    }
    try {
        return [int] $value
    }
    catch {
        return 0
    }
}

function Get-WorkflowName([string] $Command) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return ""
    }
    $match = [regex]::Match($Command, "gh\s+workflow\s+run\s+([^\s]+\.ya?ml)")
    if (-not $match.Success) {
        return ""
    }
    return $match.Groups[1].Value
}

function Test-CommandMentions([string] $Command, [string] $Needle) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $false
    }
    return $Command.Contains($Needle)
}

function Get-RunIdOrPlaceholder([string] $RunId, [string] $PlaceholderName) {
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        return "<$PlaceholderName>"
    }

    $trimmed = $RunId.Trim()
    if ($trimmed.StartsWith("<") -and $trimmed.EndsWith(">")) {
        return $trimmed
    }
    if ($trimmed -match "^\d+$") {
        return $trimmed
    }

    $runUrlMatch = [regex]::Match($trimmed, "(?i)(?:^|/)actions/runs/(\d+)(?:[/?#]|$)")
    if ($runUrlMatch.Success) {
        return $runUrlMatch.Groups[1].Value
    }

    throw "Invalid run id input for $PlaceholderName. Use a numeric GitHub Actions run id, a GitHub Actions run URL containing /actions/runs/<id>, or leave it blank for a placeholder."
}
function Test-ConcreteRunId([string] $RunId) {
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        return $false
    }
    return $RunId -match "^\d+$"
}

function Add-Artifact(
    [System.Collections.Generic.List[object]] $Artifacts,
    [string] $Group,
    [string] $Workflow,
    [string] $RunId,
    [string] $RunIdInput,
    [string] $ArtifactName,
    [string] $ArtifactNameInput,
    [string] $DownloadPath,
    [bool] $RequiredForReadiness,
    [string] $Note
) {
    $downloadCommand = if ($RunId.StartsWith("<") -or $ArtifactName.Contains("<")) {
        "gh run download $RunId -n $ArtifactName -D $DownloadPath"
    }
    else {
        "gh run download $RunId -n $ArtifactName -D $DownloadPath"
    }
    $Artifacts.Add([ordered]@{
        group = $Group
        workflow = $Workflow
        runId = $RunId
        runIdInput = $RunIdInput
        artifactName = $ArtifactName
        artifactNameInput = $ArtifactNameInput
        downloadPath = $DownloadPath
        downloadCommand = $downloadCommand
        requiredForReadiness = $RequiredForReadiness
        ready = (-not $RunId.StartsWith("<")) -and (-not $ArtifactName.Contains("<"))
        note = $Note
    })
}

function Add-SecurityEvidenceFinalizerInput(
    [System.Collections.Generic.List[object]] $Inputs,
    [string] $Name,
    [string] $RunIdParameter,
    [string] $Workflow,
    [string] $ArtifactName,
    [string] $ArtifactNameParameter,
    [string] $RunId,
    [bool] $SourceArtifactSelected
) {
    $ready = Test-ConcreteRunId $RunId
    $Inputs.Add([ordered]@{
        name = $Name
        runIdParameter = $RunIdParameter
        workflow = $Workflow
        artifactName = $ArtifactName
        artifactNameParameter = $ArtifactNameParameter
        runId = $RunId
        ready = $ready
        sourceArtifactSelected = $SourceArtifactSelected
        sourceArtifactReady = $ready
        requiredForSecurityFinalizer = $true
        note = "Source artifact for security-evidence-finalizer-ci.yml."
    }) | Out-Null
}

function Add-UniqueWorkflow([System.Collections.Generic.HashSet[string]] $Set, [string] $Workflow) {
    if (-not [string]::IsNullOrWhiteSpace($Workflow)) {
        [void] $Set.Add($Workflow)
    }
}

function Add-UniqueInt([System.Collections.Generic.List[int]] $List, [int] $Value) {
    if ($Value -le 0) {
        return
    }
    if (-not $List.Contains($Value)) {
        $List.Add($Value) | Out-Null
    }
}

function Get-ActionOrders([object[]] $Actions) {
    $orders = New-Object System.Collections.Generic.List[int]
    foreach ($action in @($Actions)) {
        Add-UniqueInt $orders (Get-Int $action "order")
    }
    return @($orders | ForEach-Object { [int] $_ })
}

$resolvedInvocationReportPath = Resolve-ProjectPath $InvocationReportPath
if (-not (Test-Path -LiteralPath $resolvedInvocationReportPath)) {
    throw "Operations evidence invocation report not found: $resolvedInvocationReportPath"
}

$invocation = Read-Utf8Text $resolvedInvocationReportPath | ConvertFrom-Json
if ($invocation.formatVersion -ne "osmu.operations-evidence-plan-invocation.v1") {
    throw "Unexpected operations evidence invocation formatVersion: $($invocation.formatVersion)"
}

$sourceActionOrders = @(Get-ActionOrders @($invocation.actions))

$workflows = New-Object System.Collections.Generic.HashSet[string]
$hasStorageBackendTelemetryEvidence = $false
$hasMinioBucketCorsVerification = $false
$hasSecretRotationEvidence = $false
$hasClusterNetworkAccessReviewEvidence = $false
$hasHelmValuesHardeningEvidence = $false
$hasSupportEscalationHandoffEvidence = $false
$hasCommercialIntegrationEvidence = $false
$hasCommercialApprovalEvidence = $false
$hasChargebackCloseoutEvidence = $false
$hasEnterpriseAuthSmoke = $false
$hasEnterpriseAuthJitRollback = $false
$hasOperationsHandoffPackage = $false
$hasDataFlowStoragePlan = $false
$hasDataFlowQueryRetentionBudget = $false
$hasDataFlowStorageTransitionRunbook = $false
$hasMonitoringThresholdEvidence = $false
foreach ($action in @($invocation.actions)) {
    $command = Get-Text $action "command"
    Add-UniqueWorkflow $workflows (Get-WorkflowName $command)
    if (Test-CommandMentions $command "write-secret-rotation-evidence.ps1") {
        $hasSecretRotationEvidence = $true
    }
    if (Test-CommandMentions $command "write-cluster-network-access-review-evidence.ps1") {
        $hasClusterNetworkAccessReviewEvidence = $true
    }
    if (Test-CommandMentions $command "write-helm-values-hardening-evidence.ps1") {
        $hasHelmValuesHardeningEvidence = $true
    }
    if (Test-CommandMentions $command "write-support-escalation-handoff-evidence.ps1") {
        $hasSupportEscalationHandoffEvidence = $true
    }
    if (Test-CommandMentions $command "write-storage-backend-telemetry-evidence.ps1") {
        $hasStorageBackendTelemetryEvidence = $true
    }
    if (Test-CommandMentions $command "verify-minio-bucket-cors.ps1") {
        $hasMinioBucketCorsVerification = $true
    }
    if (Test-CommandMentions $command "write-commercial-integration-evidence.ps1") {
        $hasCommercialIntegrationEvidence = $true
    }
    if (Test-CommandMentions $command "write-commercial-approval-evidence.ps1") {
        $hasCommercialApprovalEvidence = $true
    }
    if (Test-CommandMentions $command "write-chargeback-closeout-evidence.ps1") {
        $hasChargebackCloseoutEvidence = $true
    }
    if (Test-CommandMentions $command "write-enterprise-auth-smoke-plan.ps1") {
        $hasEnterpriseAuthSmoke = $true
    }
    if (Test-CommandMentions $command "write-enterprise-auth-jit-rollback-evidence.ps1") {
        $hasEnterpriseAuthJitRollback = $true
    }
    if (Test-CommandMentions $command "write-operations-handoff-package.ps1") {
        $hasOperationsHandoffPackage = $true
    }
    if (Test-CommandMentions $command "write-data-flow-storage-plan.ps1") {
        $hasDataFlowStoragePlan = $true
    }
    if (Test-CommandMentions $command "write-data-flow-query-retention-budget-evidence.ps1") {
        $hasDataFlowQueryRetentionBudget = $true
    }
    if (Test-CommandMentions $command "write-data-flow-storage-transition-runbook-evidence.ps1") {
        $hasDataFlowStorageTransitionRunbook = $true
    }
    if (Test-CommandMentions $command "write-monitoring-threshold-evidence.ps1") {
        $hasMonitoringThresholdEvidence = $true
    }
}

$artifacts = New-Object System.Collections.Generic.List[object]
$storageExpansionRun = Get-RunIdOrPlaceholder $StorageExpansionRunId "storage-expansion-run-id"
$haDrRun = Get-RunIdOrPlaceholder $HaDrReadinessRunId "ha-dr-readiness-run-id"
$kubernetesDrRun = Get-RunIdOrPlaceholder $KubernetesDrRunId "kubernetes-dr-run-id"
$iamRbacRun = Get-RunIdOrPlaceholder $IamRbacRunId "iam-rbac-run-id"
$imageSigningRun = Get-RunIdOrPlaceholder $ImageSigningRunId "image-signing-run-id"
$containerSecurityRun = Get-RunIdOrPlaceholder $ContainerSecurityRunId "container-security-run-id"
$securityEvidenceRun = Get-RunIdOrPlaceholder $SecurityEvidenceRunId "security-evidence-run-id"
$storageBackendTelemetryRun = Get-RunIdOrPlaceholder $StorageBackendTelemetryRunId "storage-backend-telemetry-run-id"
$minioBucketCorsRun = Get-RunIdOrPlaceholder $MinioBucketCorsRunId "minio-bucket-cors-run-id"
$monitoringThresholdRun = Get-RunIdOrPlaceholder $MonitoringThresholdRunId "monitoring-threshold-run-id"
$secretRotationRun = Get-RunIdOrPlaceholder $SecretRotationRunId "secret-rotation-run-id"
$clusterNetworkAccessReviewRun = Get-RunIdOrPlaceholder $ClusterNetworkAccessReviewRunId "cluster-network-access-review-run-id"
$helmValuesHardeningRun = Get-RunIdOrPlaceholder $HelmValuesHardeningRunId "helm-values-hardening-run-id"
$supportEscalationHandoffRun = Get-RunIdOrPlaceholder $SupportEscalationHandoffRunId "support-escalation-handoff-run-id"
$commercialIntegrationRun = Get-RunIdOrPlaceholder $CommercialIntegrationRunId "commercial-integration-run-id"
$commercialApprovalRun = Get-RunIdOrPlaceholder $CommercialApprovalRunId "commercial-approval-run-id"
$chargebackCloseoutRun = Get-RunIdOrPlaceholder $ChargebackCloseoutRunId "chargeback-closeout-run-id"
$enterpriseAuthRun = Get-RunIdOrPlaceholder $EnterpriseAuthRunId "enterprise-auth-run-id"
$enterpriseAuthJitRollbackRun = Get-RunIdOrPlaceholder $EnterpriseAuthJitRollbackRunId "enterprise-auth-jit-rollback-run-id"
$operationsHandoffPackageRun = Get-RunIdOrPlaceholder $OperationsHandoffPackageRunId "operations-handoff-package-run-id"
$dataFlowStoragePlanRun = Get-RunIdOrPlaceholder $DataFlowStoragePlanRunId "data-flow-storage-plan-run-id"
$dataFlowQueryRetentionBudgetRun = Get-RunIdOrPlaceholder $DataFlowQueryRetentionBudgetRunId "data-flow-query-retention-budget-run-id"
$dataFlowStorageTransitionRunbookRun = Get-RunIdOrPlaceholder $DataFlowStorageTransitionRunbookRunId "data-flow-storage-transition-runbook-run-id"
$kubernetesOperationsReportSyncRun = Get-RunIdOrPlaceholder $KubernetesOperationsReportSyncRunId "kubernetes-operations-report-sync-run-id"

if ($workflows.Contains("storage-expansion-finalizer-ci.yml")) {
    Add-Artifact $artifacts "storage-expansion" "storage-expansion-finalizer-ci.yml" $storageExpansionRun "storage_expansion_run_id" "storage-expansion-finalizer-$storageExpansionRun" "storage_expansion_artifact_name" ".osmu-run/operations-readiness-artifacts/storage-expansion" $true "Imports latest-storage-expansion-finalize.json."
}
if ($workflows.Contains("kubernetes-ha-dr-readiness-ci.yml")) {
    Add-Artifact $artifacts "ha-dr-readiness" "kubernetes-ha-dr-readiness-ci.yml" $haDrRun "ha_dr_readiness_run_id" "kubernetes-ha-dr-readiness-$haDrRun" "ha_dr_readiness_artifact_name" ".osmu-run/operations-readiness-artifacts/ha-dr-readiness" $true "Imports latest-kubernetes-ha-dr-readiness.json."
}
if ($workflows.Contains("kubernetes-dr-finalizer-ci.yml")) {
    Add-Artifact $artifacts "kubernetes-dr" "kubernetes-dr-finalizer-ci.yml" $kubernetesDrRun "kubernetes_dr_run_id" "kubernetes-dr-finalizer-$kubernetesDrRun" "kubernetes_dr_artifact_name" ".osmu-run/operations-readiness-artifacts/kubernetes-dr" $true "Imports latest-kubernetes-dr-finalize.json."
}
if ($workflows.Contains("iam-rbac-finalizer-ci.yml")) {
    Add-Artifact $artifacts "iam-rbac" "iam-rbac-finalizer-ci.yml" $iamRbacRun "iam_rbac_run_id" "iam-rbac-finalizer-$iamRbacRun" "iam_rbac_artifact_name" ".osmu-run/operations-readiness-artifacts/iam-rbac" $true "Imports latest-iam-rbac-finalize.json."
}
if ($workflows.Contains("image-publish-sign-ci.yml")) {
    Add-Artifact $artifacts "image-signing-source" "image-publish-sign-ci.yml" $imageSigningRun "image_signing_run_id" "osmu-image-signing-$ImageSigningVersion-$CommitSha" "image_signing_artifact_name" ".osmu-run/security-evidence-finalizer/source/image-signing" $false "Source artifact for security-evidence-finalizer-ci.yml."
}
if ($workflows.Contains("container-security-ci.yml")) {
    Add-Artifact $artifacts "container-security-source" "container-security-ci.yml" $containerSecurityRun "container_security_run_id" "osmu-container-security-$CommitSha" "container_security_artifact_name" ".osmu-run/security-evidence-finalizer/source/container-security" $false "Source artifact for security-evidence-finalizer-ci.yml."
}
if ($workflows.Contains("security-evidence-finalizer-ci.yml")) {
    Add-Artifact $artifacts "security-evidence" "security-evidence-finalizer-ci.yml" $securityEvidenceRun "security_evidence_run_id" "security-evidence-finalizer-$securityEvidenceRun" "security_evidence_artifact_name" ".osmu-run/operations-readiness-artifacts/security-evidence" $true "Imports latest-security-evidence-finalize.json, image signing evidence, and container security evidence."
}
if ($hasStorageBackendTelemetryEvidence -or $workflows.Contains("manual-storage-backend-telemetry-evidence.yml")) {
    Add-Artifact $artifacts "storage-backend-telemetry" "manual-storage-backend-telemetry-evidence.yml" $storageBackendTelemetryRun "storage_backend_telemetry_run_id" "storage-backend-telemetry-evidence-$storageBackendTelemetryRun" "storage_backend_telemetry_artifact_name" ".osmu-run/operations-readiness-artifacts/storage-backend-telemetry" $true "Imports latest-storage-backend-telemetry.json from target MinIO admin info telemetry evidence."
}
if ($hasMinioBucketCorsVerification -or $workflows.Contains("manual-minio-bucket-cors-verification.yml")) {
    Add-Artifact $artifacts "minio-bucket-cors" "manual-minio-bucket-cors-verification.yml" $minioBucketCorsRun "minio_bucket_cors_run_id" "minio-bucket-cors-verification-$minioBucketCorsRun" "minio_bucket_cors_artifact_name" ".osmu-run/operations-readiness-artifacts/minio-bucket-cors" $false "Imports latest-minio-bucket-cors-verification.json for dashboard browser multipart upload readiness. This is not a readiness gate or AWS S3 parity work."
}
if ($hasMonitoringThresholdEvidence -or $workflows.Contains("manual-monitoring-threshold-evidence.yml")) {
    Add-Artifact $artifacts "monitoring-threshold" "manual-monitoring-threshold-evidence.yml" $monitoringThresholdRun "monitoring_threshold_run_id" "monitoring-threshold-evidence-$monitoringThresholdRun" "monitoring_threshold_artifact_name" ".osmu-run/operations-readiness-artifacts/monitoring-threshold" $true "Imports latest-monitoring-threshold-evidence.json from target Prometheus rule, Grafana dashboard, Alertmanager route, incident routing, and tenant baseline review evidence."
}
if ($hasSecretRotationEvidence -or $workflows.Contains("manual-secret-rotation-evidence.yml")) {
    Add-Artifact $artifacts "secret-rotation" "manual-secret-rotation-evidence.yml" $secretRotationRun "secret_rotation_run_id" "secret-rotation-evidence-$secretRotationRun" "secret_rotation_artifact_name" ".osmu-run/operations-readiness-artifacts/secret-rotation" $true "Imports latest-secret-rotation-evidence.json from target secret/certificate rotation evidence."
}
if ($hasClusterNetworkAccessReviewEvidence -or $workflows.Contains("manual-cluster-network-access-review-evidence.yml")) {
    Add-Artifact $artifacts "cluster-network-access-review" "manual-cluster-network-access-review-evidence.yml" $clusterNetworkAccessReviewRun "cluster_network_access_review_run_id" "cluster-network-access-review-evidence-$clusterNetworkAccessReviewRun" "cluster_network_access_review_artifact_name" ".osmu-run/operations-readiness-artifacts/cluster-network-access-review" $true "Imports latest-cluster-network-access-review-evidence.json from target Kubernetes/Helm NetworkPolicy access review evidence."
}
if ($hasHelmValuesHardeningEvidence -or $workflows.Contains("manual-helm-values-hardening-evidence.yml")) {
    Add-Artifact $artifacts "helm-values-hardening" "manual-helm-values-hardening-evidence.yml" $helmValuesHardeningRun "helm_values_hardening_run_id" "helm-values-hardening-evidence-$helmValuesHardeningRun" "helm_values_hardening_artifact_name" ".osmu-run/operations-readiness-artifacts/helm-values-hardening" $true "Imports latest-helm-values-hardening-evidence.json from target Helm values hardening evidence."
}
if ($hasSupportEscalationHandoffEvidence -or $workflows.Contains("manual-support-escalation-handoff-evidence.yml")) {
    Add-Artifact $artifacts "support-escalation-handoff" "manual-support-escalation-handoff-evidence.yml" $supportEscalationHandoffRun "support_escalation_handoff_run_id" "support-escalation-handoff-evidence-$supportEscalationHandoffRun" "support_escalation_handoff_artifact_name" ".osmu-run/operations-readiness-artifacts/support-escalation-handoff" $true "Imports latest-support-escalation-handoff-evidence.json from support escalation, support SLA, runbook, troubleshooting, rollback, known-gap, and operations handoff reference review evidence."
}
if ($hasCommercialIntegrationEvidence -or $workflows.Contains("manual-commercial-integration-evidence.yml")) {
    Add-Artifact $artifacts "commercial-integration" "manual-commercial-integration-evidence.yml" $commercialIntegrationRun "commercial_integration_run_id" "commercial-integration-evidence-$commercialIntegrationRun" "commercial_integration_artifact_name" ".osmu-run/operations-readiness-artifacts/commercial-integration" $true "Imports latest-commercial-integration-evidence.json from target notification/payment handoff and payment-provider adapter readiness evidence."
}
if ($hasCommercialApprovalEvidence -or $workflows.Contains("manual-commercial-approval-evidence.yml")) {
    Add-Artifact $artifacts "commercial-approval" "manual-commercial-approval-evidence.yml" $commercialApprovalRun "commercial_approval_run_id" "commercial-approval-evidence-$commercialApprovalRun" "commercial_approval_artifact_name" ".osmu-run/operations-readiness-artifacts/commercial-approval" $true "Imports latest-commercial-approval-evidence.json from final pricing, terms, support SLA, license, legal, pilot contract, and billing pricing proposal commercial approval evidence."
}
if ($hasChargebackCloseoutEvidence -or $workflows.Contains("manual-chargeback-closeout-evidence.yml")) {
    Add-Artifact $artifacts "chargeback-closeout" "manual-chargeback-closeout-evidence.yml" $chargebackCloseoutRun "chargeback_closeout_run_id" "chargeback-closeout-evidence-$chargebackCloseoutRun" "chargeback_closeout_artifact_name" ".osmu-run/operations-readiness-artifacts/chargeback-closeout" $true "Imports latest-chargeback-closeout-evidence.json from target billing-period chargeback closeout evidence."
}
if ($hasEnterpriseAuthSmoke -or $workflows.Contains("enterprise-auth-smoke-ci.yml")) {
    Add-Artifact $artifacts "enterprise-auth" "enterprise-auth-smoke-ci.yml" $enterpriseAuthRun "enterprise_auth_run_id" "enterprise-auth-smoke-$enterpriseAuthRun" "enterprise_auth_artifact_name" ".osmu-run/operations-readiness-artifacts/enterprise-auth" $true "Imports latest-enterprise-auth-smoke.json from target IdP/directory smoke evidence or contractual scope-out evidence."
}
if ($hasEnterpriseAuthJitRollback -or $workflows.Contains("manual-enterprise-auth-jit-rollback-evidence.yml")) {
    Add-Artifact $artifacts "enterprise-auth-jit-rollback" "manual-enterprise-auth-jit-rollback-evidence.yml" $enterpriseAuthJitRollbackRun "enterprise_auth_jit_rollback_run_id" "enterprise-auth-jit-rollback-evidence-$enterpriseAuthJitRollbackRun" "enterprise_auth_jit_rollback_artifact_name" ".osmu-run/operations-readiness-artifacts/enterprise-auth-jit-rollback" $true "Imports latest-enterprise-auth-jit-rollback-evidence.json from target admin-approved JIT provisioning rollback/runbook evidence."
}
if ($hasOperationsHandoffPackage -or $workflows.Contains("manual-operations-handoff-package.yml")) {
    Add-Artifact $artifacts "operations-handoff-package" "manual-operations-handoff-package.yml" $operationsHandoffPackageRun "operations_handoff_package_run_id" "operations-handoff-package-$operationsHandoffPackageRun" "operations_handoff_package_artifact_name" ".osmu-run/operations-readiness-artifacts/operations-handoff-package" $true "Imports latest-operations-handoff-package.json from pilot or production handoff package evidence."
}
if ($hasDataFlowStoragePlan -or $workflows.Contains("manual-data-flow-storage-plan-evidence.yml")) {
    Add-Artifact $artifacts "data-flow-storage-plan" "manual-data-flow-storage-plan-evidence.yml" $dataFlowStoragePlanRun "data_flow_storage_plan_run_id" "data-flow-storage-plan-evidence-$dataFlowStoragePlanRun" "data_flow_storage_plan_artifact_name" ".osmu-run/operations-readiness-artifacts/data-flow-storage-plan" $true "Imports latest-data-flow-storage-plan.json from target analytics storage sizing, backfill, rollback, retention budget, and sanitized query-plan evidence."
}
if ($hasDataFlowQueryRetentionBudget -or $workflows.Contains("manual-data-flow-query-retention-budget-evidence.yml")) {
    Add-Artifact $artifacts "data-flow-query-retention-budget" "manual-data-flow-query-retention-budget-evidence.yml" $dataFlowQueryRetentionBudgetRun "data_flow_query_retention_budget_run_id" "data-flow-query-retention-budget-evidence-$dataFlowQueryRetentionBudgetRun" "data_flow_query_retention_budget_artifact_name" ".osmu-run/operations-readiness-artifacts/data-flow-query-retention-budget" $true "Imports latest-data-flow-query-retention-budget-evidence.json from target analytics query latency and detailed/daily/monthly retention budget evidence."
}
if ($hasDataFlowStorageTransitionRunbook -or $workflows.Contains("manual-data-flow-storage-transition-runbook-evidence.yml")) {
    Add-Artifact $artifacts "data-flow-storage-transition-runbook" "manual-data-flow-storage-transition-runbook-evidence.yml" $dataFlowStorageTransitionRunbookRun "data_flow_storage_transition_runbook_run_id" "data-flow-storage-transition-runbook-evidence-$dataFlowStorageTransitionRunbookRun" "data_flow_storage_transition_runbook_artifact_name" ".osmu-run/operations-readiness-artifacts/data-flow-storage-transition-runbook" $true "Imports latest-data-flow-storage-transition-runbook-evidence.json from target backfill, dual-write or partition toggle, rollback, reconciliation, dashboard cutover, and retention dry-run rehearsal evidence."
}
if ($workflows.Contains("kubernetes-operations-report-sync-ci.yml")) {
    Add-Artifact $artifacts "kubernetes-operations-report-sync" "kubernetes-operations-report-sync-ci.yml" $kubernetesOperationsReportSyncRun "kubernetes_operations_report_sync_run_id" "kubernetes-operations-report-sync-$kubernetesOperationsReportSyncRun" "kubernetes_operations_report_sync_artifact_name" ".osmu-run/operations-readiness-artifacts/kubernetes-operations-report-sync" $true "Imports latest-kubernetes-operations-report-sync.json for convergence-level deployed dashboard sync evidence plus optional latest-data-flow-storage-plan.json, latest-data-flow-query-retention-budget-evidence.json, and latest-data-flow-storage-transition-runbook-evidence.json for dashboard plan/query-retention/runbook visibility. MariaDB partition or dual-write plans must include the sanitized query-plan evidence summary, query-retention evidence must prove latency and retention budgets, and runbook evidence must be result=passed and sanitized."
}

$artifactArray = @($artifacts | ForEach-Object { $_ })
$requiredArtifacts = @($artifactArray | Where-Object { $_.requiredForReadiness })
$missingRequiredArtifacts = @($requiredArtifacts | Where-Object { -not $_.ready })
$readyArtifacts = @($artifactArray | Where-Object { $_.ready })
$securitySourceArtifactGroups = @("image-signing-source", "container-security-source")
$securitySourceArtifacts = @($artifactArray | Where-Object { $securitySourceArtifactGroups -contains ([string] $_.group) })
$readySecuritySourceArtifacts = @($securitySourceArtifacts | Where-Object { $_.ready })
$missingSecuritySourceArtifacts = @($securitySourceArtifacts | Where-Object { -not $_.ready })

$operationsArtifactFinalizerArgs = New-Object System.Collections.Generic.List[string]
foreach ($artifact in $requiredArtifacts) {
    $operationsArtifactFinalizerArgs.Add("-f $($artifact.runIdInput)=$($artifact.runId)")
    $operationsArtifactFinalizerArgs.Add("-f $($artifact.artifactNameInput)=$($artifact.artifactName)")
}
$operationsArtifactFinalizerCommand = if ($requiredArtifacts.Count -gt 0) {
    "gh workflow run operations-readiness-artifact-finalizer-ci.yml $($operationsArtifactFinalizerArgs -join ' ')"
}
else {
    ""
}
$dataFlowStoragePlanInputNote = "Optional direct data-flow plan input: add -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> to operations-readiness-artifact-finalizer-ci.yml when target data-flow storage transition evidence should be imported without waiting for a Kubernetes operations report sync artifact. MariaDB partition or dual-write plans must include the sanitized query-plan evidence summary."
$dataFlowQueryRetentionBudgetInputNote = "Optional direct data-flow query/retention budget input: add -f data_flow_query_retention_budget_json_base64=<base64-latest-data-flow-query-retention-budget-json> to operations-readiness-artifact-finalizer-ci.yml when target query latency and retention budget evidence should be imported without waiting for a manual workflow artifact. The snapshot must be sanitized and result=passed."
$dataFlowStorageTransitionRunbookInputNote = "Optional direct data-flow transition runbook input: add -f data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json> to operations-readiness-artifact-finalizer-ci.yml when target transition rehearsal evidence should be imported without waiting for a manual workflow artifact. The snapshot must be sanitized and result=passed."
$minioBucketCorsInputNote = ""
$minioBucketCorsArtifacts = @($artifactArray | Where-Object { $_.group -eq "minio-bucket-cors" })
if ($minioBucketCorsArtifacts.Count -gt 0) {
    $corsArtifact = $minioBucketCorsArtifacts[0]
    $minioBucketCorsInputNote = "Optional MinIO bucket CORS input: add -f minio_bucket_cors_run_id=$($corsArtifact.runId) -f minio_bucket_cors_artifact_name=$($corsArtifact.artifactName) to operations-readiness-artifact-finalizer-ci.yml to promote browser multipart upload CORS verification for dashboard visibility. This is not a readiness gate or AWS S3 parity work."
}

$securityFinalizerCommand = ""
if ($workflows.Contains("security-evidence-finalizer-ci.yml") -or $workflows.Contains("image-publish-sign-ci.yml") -or $workflows.Contains("container-security-ci.yml")) {
    $securityFinalizerCommand = "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=$imageSigningRun -f image_signing_artifact_name=osmu-image-signing-$ImageSigningVersion-$CommitSha -f container_security_run_id=$containerSecurityRun -f container_security_artifact_name=osmu-container-security-$CommitSha -f fail_if_not_passed=true"
}
$securityEvidenceFinalizerInputs = New-Object System.Collections.Generic.List[object]
if (-not [string]::IsNullOrWhiteSpace($securityFinalizerCommand)) {
    $imageSigningSourceSelected = $workflows.Contains("image-publish-sign-ci.yml")
    $containerSecuritySourceSelected = $workflows.Contains("container-security-ci.yml")
    Add-SecurityEvidenceFinalizerInput $securityEvidenceFinalizerInputs "ImageSigningRunId" "image_signing_run_id" "image-publish-sign-ci.yml" "osmu-image-signing-$ImageSigningVersion-$CommitSha" "image_signing_artifact_name" $imageSigningRun $imageSigningSourceSelected
    Add-SecurityEvidenceFinalizerInput $securityEvidenceFinalizerInputs "ContainerSecurityRunId" "container_security_run_id" "container-security-ci.yml" "osmu-container-security-$CommitSha" "container_security_artifact_name" $containerSecurityRun $containerSecuritySourceSelected
}
$securityEvidenceFinalizerMissingRunIdInputs = @()
if (-not [string]::IsNullOrWhiteSpace($securityFinalizerCommand)) {
    if (-not (Test-ConcreteRunId $imageSigningRun)) {
        $securityEvidenceFinalizerMissingRunIdInputs += "ImageSigningRunId"
    }
    if (-not (Test-ConcreteRunId $containerSecurityRun)) {
        $securityEvidenceFinalizerMissingRunIdInputs += "ContainerSecurityRunId"
    }
}
$securityEvidenceFinalizerReady = (-not [string]::IsNullOrWhiteSpace($securityFinalizerCommand)) -and $securityEvidenceFinalizerMissingRunIdInputs.Count -eq 0

$localImportArtifacts = New-Object System.Collections.Generic.List[object]
foreach ($artifact in $requiredArtifacts) {
    $localImportArtifacts.Add($artifact) | Out-Null
}
foreach ($artifact in @($artifactArray | Where-Object { $_.group -eq "minio-bucket-cors" -and $_.ready })) {
    $localImportArtifacts.Add($artifact) | Out-Null
}
$localImportArgs = New-Object System.Collections.Generic.List[string]
foreach ($artifact in $localImportArtifacts) {
    $group = [string] $artifact["group"]
    $downloadPath = ".\" + ([string] $artifact["downloadPath"]).Replace("/", "\")
    if ($group -eq "storage-expansion") {
        $localImportArgs.Add("-StorageExpansionArtifactPath $downloadPath")
    }
    elseif ($group -eq "ha-dr-readiness") {
        $localImportArgs.Add("-HaDrReadinessArtifactPath $downloadPath")
    }
    elseif ($group -eq "kubernetes-dr") {
        $localImportArgs.Add("-KubernetesDrArtifactPath $downloadPath")
    }
    elseif ($group -eq "iam-rbac") {
        $localImportArgs.Add("-IamRbacArtifactPath $downloadPath")
    }
    elseif ($group -eq "security-evidence") {
        $localImportArgs.Add("-SecurityEvidenceArtifactPath $downloadPath")
    }
    elseif ($group -eq "storage-backend-telemetry") {
        $localImportArgs.Add("-StorageBackendTelemetryArtifactPath $downloadPath")
    }
    elseif ($group -eq "minio-bucket-cors") {
        $localImportArgs.Add("-MinioBucketCorsArtifactPath $downloadPath")
    }
    elseif ($group -eq "monitoring-threshold") {
        $localImportArgs.Add("-MonitoringThresholdArtifactPath $downloadPath")
    }
    elseif ($group -eq "secret-rotation") {
        $localImportArgs.Add("-SecretRotationArtifactPath $downloadPath")
    }
    elseif ($group -eq "cluster-network-access-review") {
        $localImportArgs.Add("-ClusterNetworkAccessReviewArtifactPath $downloadPath")
    }
    elseif ($group -eq "helm-values-hardening") {
        $localImportArgs.Add("-HelmValuesHardeningArtifactPath $downloadPath")
    }
    elseif ($group -eq "support-escalation-handoff") {
        $localImportArgs.Add("-SupportEscalationHandoffArtifactPath $downloadPath")
    }
    elseif ($group -eq "commercial-integration") {
        $localImportArgs.Add("-CommercialIntegrationArtifactPath $downloadPath")
    }
    elseif ($group -eq "commercial-approval") {
        $localImportArgs.Add("-CommercialApprovalArtifactPath $downloadPath")
    }
    elseif ($group -eq "chargeback-closeout") {
        $localImportArgs.Add("-ChargebackCloseoutArtifactPath $downloadPath")
    }
    elseif ($group -eq "enterprise-auth") {
        $localImportArgs.Add("-EnterpriseAuthArtifactPath $downloadPath")
    }
    elseif ($group -eq "enterprise-auth-jit-rollback") {
        $localImportArgs.Add("-EnterpriseAuthJitRollbackArtifactPath $downloadPath")
    }
    elseif ($group -eq "operations-handoff-package") {
        $localImportArgs.Add("-OperationsHandoffPackageArtifactPath $downloadPath")
    }
    elseif ($group -eq "data-flow-storage-plan") {
        $localImportArgs.Add("-DataFlowStoragePlanArtifactPath $downloadPath")
    }
    elseif ($group -eq "data-flow-query-retention-budget") {
        $localImportArgs.Add("-DataFlowQueryRetentionBudgetArtifactPath $downloadPath")
    }
    elseif ($group -eq "data-flow-storage-transition-runbook") {
        $localImportArgs.Add("-DataFlowStorageTransitionRunbookArtifactPath $downloadPath")
    }
    elseif ($group -eq "kubernetes-operations-report-sync") {
        $localImportArgs.Add("-KubernetesOperationsReportSyncArtifactPath $downloadPath")
    }
}
$localImportCommand = if ($localImportArgs.Count -gt 0) {
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\import-operations-readiness-artifacts.ps1 $($localImportArgs -join ' ')"
}
else {
    ""
}

$result = if ($missingRequiredArtifacts.Count -eq 0 -and $requiredArtifacts.Count -gt 0) {
    "ready"
}
elseif ($requiredArtifacts.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($securityFinalizerCommand) -and -not $securityEvidenceFinalizerReady) {
    "security-source-action-required"
}
elseif ($requiredArtifacts.Count -eq 0 -and $securityEvidenceFinalizerReady) {
    "security-source-ready"
}
elseif ($requiredArtifacts.Count -eq 0) {
    "no-readiness-artifacts"
}
else {
    "action-required"
}

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$invocationResultText = Get-Text $invocation "result"
$invocationSourceSummaryText = Get-Text $invocation "sourceSummary"
$invocationSourcePassedCount = Get-Int $invocation "sourcePassedCount"
$invocationSourcePendingCount = Get-Int $invocation "sourcePendingCount"
$invocationSourceTotalCount = Get-Int $invocation "sourceTotalCount"
$invocationSourceCheckCount = Get-Int $invocation "sourceCheckCount"
$invocationSelectedActionCount = Get-Int $invocation "selectedActionCount"
$invocationPlannedCount = Get-Int $invocation "plannedCount"
$invocationBlockedCount = Get-Int $invocation "blockedCount"
$invocationExecutedCount = Get-Int $invocation "executedCount"
$invocationFailedCount = Get-Int $invocation "failedCount"
$sourceActionOrderArray = @($sourceActionOrders | ForEach-Object { [int] $_ })
$securityEvidenceFinalizerInputArray = @($securityEvidenceFinalizerInputs | ForEach-Object { $_ })
$securityEvidenceFinalizerMissingInputArray = @($securityEvidenceFinalizerMissingRunIdInputs | ForEach-Object { [string] $_ })
$artifactOutputArray = @($artifactArray | ForEach-Object { $_ })
$report = [ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    generatedAt = $generatedAt
    result = $result
    sourceInvocationReport = $resolvedInvocationReportPath
    invocationResult = $invocationResultText
    sourceSummary = $invocationSourceSummaryText
    sourcePassedCount = $invocationSourcePassedCount
    sourcePendingCount = $invocationSourcePendingCount
    sourceTotalCount = $invocationSourceTotalCount
    sourceCheckCount = $invocationSourceCheckCount
    invocationSummary = "selected=$invocationSelectedActionCount planned=$invocationPlannedCount blocked=$invocationBlockedCount executed=$invocationExecutedCount failed=$invocationFailedCount"
    sourceActionCount = @($invocation.actions).Count
    sourceActionOrders = $sourceActionOrderArray
    selectedActionOrders = $sourceActionOrderArray
    artifactCount = $artifactArray.Count
    requiredArtifactCount = $requiredArtifacts.Count
    readyArtifactCount = $readyArtifacts.Count
    missingRequiredArtifactCount = $missingRequiredArtifacts.Count
    securitySourceArtifactCount = $securitySourceArtifacts.Count
    readySecuritySourceArtifactCount = $readySecuritySourceArtifacts.Count
    missingSecuritySourceArtifactCount = $missingSecuritySourceArtifacts.Count
    securityEvidenceFinalizerReady = $securityEvidenceFinalizerReady
    securityEvidenceFinalizerInputs = $securityEvidenceFinalizerInputArray
    securityEvidenceFinalizerMissingRunIdInputs = $securityEvidenceFinalizerMissingInputArray
    securityEvidenceFinalizerCommand = $securityFinalizerCommand
    operationsArtifactFinalizerCommand = $operationsArtifactFinalizerCommand
    dataFlowStoragePlanInputNote = $dataFlowStoragePlanInputNote
    dataFlowQueryRetentionBudgetInputNote = $dataFlowQueryRetentionBudgetInputNote
    dataFlowStorageTransitionRunbookInputNote = $dataFlowStorageTransitionRunbookInputNote
    minioBucketCorsInputNote = $minioBucketCorsInputNote
    localImportCommand = $localImportCommand
    decisionRule = "After evidence workflows finish, fill missing run ids or paste GitHub Actions run URLs, verify artifact names, then either dispatch operations-readiness-artifact-finalizer-ci.yml or download artifacts locally and run import-operations-readiness-artifacts.ps1."
    artifacts = $artifactOutputArray
}

$markdownLines = @(
    "# OSMU Operations Artifact Collection Plan",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source invocation report: $resolvedInvocationReportPath",
    "Invocation result: $($report.invocationResult)",
    "Source summary: $($report.sourceSummary)",
    "Source counts: passed=$($report.sourcePassedCount) pending=$($report.sourcePendingCount) total=$($report.sourceTotalCount) checks=$($report.sourceCheckCount)",
    "Invocation summary: $($report.invocationSummary)",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Summary",
    "",
    "- Artifacts: $($report.artifactCount)",
    "- Required for readiness: $($report.requiredArtifactCount)",
    "- Ready artifacts: $($report.readyArtifactCount)",
    "- Missing required artifacts: $($report.missingRequiredArtifactCount)",
    "- Security source artifacts: ready=$($report.readySecuritySourceArtifactCount) total=$($report.securitySourceArtifactCount) missing=$($report.missingSecuritySourceArtifactCount)",
    "- Security evidence finalizer ready: $($report.securityEvidenceFinalizerReady)",
    "- Security evidence finalizer input count: $($report.securityEvidenceFinalizerInputs.Count)",
    "- Security evidence finalizer missing run id inputs: $(if ($report.securityEvidenceFinalizerMissingRunIdInputs.Count -gt 0) { $report.securityEvidenceFinalizerMissingRunIdInputs -join ', ' } else { 'none' })",
    "- Source action orders: $(if ($sourceActionOrders.Count -gt 0) { $sourceActionOrders -join ', ' } else { 'none' })",
    "- Selected action orders: $(if ($sourceActionOrders.Count -gt 0) { $sourceActionOrders -join ', ' } else { 'none' })",
    "",
    "## Commands",
    ""
)
if (-not [string]::IsNullOrWhiteSpace($securityFinalizerCommand)) {
    $markdownLines += "- Security evidence finalizer: ``$securityFinalizerCommand``"
}
if (-not [string]::IsNullOrWhiteSpace($operationsArtifactFinalizerCommand)) {
    $markdownLines += "- Operations artifact finalizer: ``$operationsArtifactFinalizerCommand``"
    $markdownLines += "- $dataFlowStoragePlanInputNote"
    $markdownLines += "- $dataFlowQueryRetentionBudgetInputNote"
    $markdownLines += "- $dataFlowStorageTransitionRunbookInputNote"
}
if (-not [string]::IsNullOrWhiteSpace($minioBucketCorsInputNote)) {
    $markdownLines += "- $minioBucketCorsInputNote"
}
if (-not [string]::IsNullOrWhiteSpace($localImportCommand)) {
    $markdownLines += "- Local import after downloads: ``$localImportCommand``"
}

if ($report.securityEvidenceFinalizerInputs.Count -gt 0) {
    $markdownLines += ""
    $markdownLines += "## Security Evidence Finalizer Inputs"
    $markdownLines += ""
    foreach ($input in $report.securityEvidenceFinalizerInputs) {
        $ready = if ($input.ready) { "ready" } else { "needs run id" }
        $selected = if ($input.sourceArtifactSelected) { "selected" } else { "not selected" }
        $markdownLines += "- [$ready] $($input.name): workflow=$($input.workflow); runId=$($input.runId); runIdParameter=$($input.runIdParameter); artifact=$($input.artifactName); artifactNameParameter=$($input.artifactNameParameter); source=$selected"
    }
}

$markdownLines += ""
$markdownLines += "## Artifacts"
$markdownLines += ""
if ($artifactArray.Count -eq 0) {
    $markdownLines += "- No workflow artifacts were inferred from the invocation report."
}
else {
    foreach ($artifact in $artifactArray) {
        $ready = if ($artifact.ready) { "ready" } else { "needs run id or concrete artifact name" }
        $markdownLines += "- [$ready] $($artifact.group) / $($artifact.workflow)"
        $markdownLines += "  - Run id input: $($artifact.runIdInput)=$($artifact.runId)"
        $markdownLines += "  - Artifact input: $($artifact.artifactNameInput)=$($artifact.artifactName)"
        $markdownLines += "  - Download: ``$($artifact.downloadCommand)``"
        $markdownLines += "  - Note: $($artifact.note)"
    }
}

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations artifact collection plan JSON: $resolvedJsonOutputPath"
    Write-Host "Operations artifact collection plan markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)
