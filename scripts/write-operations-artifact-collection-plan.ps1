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
    [string] $SecretRotationRunId = "",
    [string] $CommercialIntegrationRunId = "",
    [string] $CommercialApprovalRunId = "",
    [string] $EnterpriseAuthRunId = "",
    [string] $OperationsHandoffPackageRunId = "",
    [string] $DataFlowStoragePlanRunId = "",
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
    if (-not [string]::IsNullOrWhiteSpace($RunId)) {
        return $RunId
    }
    return "<$PlaceholderName>"
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

function Add-UniqueWorkflow([System.Collections.Generic.HashSet[string]] $Set, [string] $Workflow) {
    if (-not [string]::IsNullOrWhiteSpace($Workflow)) {
        [void] $Set.Add($Workflow)
    }
}

$resolvedInvocationReportPath = Resolve-ProjectPath $InvocationReportPath
if (-not (Test-Path -LiteralPath $resolvedInvocationReportPath)) {
    throw "Operations evidence invocation report not found: $resolvedInvocationReportPath"
}

$invocation = Get-Content -Raw -LiteralPath $resolvedInvocationReportPath | ConvertFrom-Json
if ($invocation.formatVersion -ne "osmu.operations-evidence-plan-invocation.v1") {
    throw "Unexpected operations evidence invocation formatVersion: $($invocation.formatVersion)"
}

$workflows = New-Object System.Collections.Generic.HashSet[string]
$hasStorageBackendTelemetryEvidence = $false
$hasSecretRotationEvidence = $false
$hasCommercialIntegrationEvidence = $false
$hasCommercialApprovalEvidence = $false
$hasEnterpriseAuthSmoke = $false
$hasOperationsHandoffPackage = $false
$hasDataFlowStoragePlan = $false
foreach ($action in @($invocation.actions)) {
    $command = Get-Text $action "command"
    Add-UniqueWorkflow $workflows (Get-WorkflowName $command)
    if (Test-CommandMentions $command "write-secret-rotation-evidence.ps1") {
        $hasSecretRotationEvidence = $true
    }
    if (Test-CommandMentions $command "write-storage-backend-telemetry-evidence.ps1") {
        $hasStorageBackendTelemetryEvidence = $true
    }
    if (Test-CommandMentions $command "write-commercial-integration-evidence.ps1") {
        $hasCommercialIntegrationEvidence = $true
    }
    if (Test-CommandMentions $command "write-commercial-approval-evidence.ps1") {
        $hasCommercialApprovalEvidence = $true
    }
    if (Test-CommandMentions $command "write-enterprise-auth-smoke-plan.ps1") {
        $hasEnterpriseAuthSmoke = $true
    }
    if (Test-CommandMentions $command "write-operations-handoff-package.ps1") {
        $hasOperationsHandoffPackage = $true
    }
    if (Test-CommandMentions $command "write-data-flow-storage-plan.ps1") {
        $hasDataFlowStoragePlan = $true
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
$secretRotationRun = Get-RunIdOrPlaceholder $SecretRotationRunId "secret-rotation-run-id"
$commercialIntegrationRun = Get-RunIdOrPlaceholder $CommercialIntegrationRunId "commercial-integration-run-id"
$commercialApprovalRun = Get-RunIdOrPlaceholder $CommercialApprovalRunId "commercial-approval-run-id"
$enterpriseAuthRun = Get-RunIdOrPlaceholder $EnterpriseAuthRunId "enterprise-auth-run-id"
$operationsHandoffPackageRun = Get-RunIdOrPlaceholder $OperationsHandoffPackageRunId "operations-handoff-package-run-id"
$dataFlowStoragePlanRun = Get-RunIdOrPlaceholder $DataFlowStoragePlanRunId "data-flow-storage-plan-run-id"
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
if ($hasSecretRotationEvidence -or $workflows.Contains("manual-secret-rotation-evidence.yml")) {
    Add-Artifact $artifacts "secret-rotation" "manual-secret-rotation-evidence.yml" $secretRotationRun "secret_rotation_run_id" "secret-rotation-evidence-$secretRotationRun" "secret_rotation_artifact_name" ".osmu-run/operations-readiness-artifacts/secret-rotation" $true "Imports latest-secret-rotation-evidence.json from target secret/certificate rotation evidence."
}
if ($hasCommercialIntegrationEvidence -or $workflows.Contains("manual-commercial-integration-evidence.yml")) {
    Add-Artifact $artifacts "commercial-integration" "manual-commercial-integration-evidence.yml" $commercialIntegrationRun "commercial_integration_run_id" "commercial-integration-evidence-$commercialIntegrationRun" "commercial_integration_artifact_name" ".osmu-run/operations-readiness-artifacts/commercial-integration" $true "Imports latest-commercial-integration-evidence.json from target notification/payment handoff and payment-provider adapter readiness evidence."
}
if ($hasCommercialApprovalEvidence -or $workflows.Contains("manual-commercial-approval-evidence.yml")) {
    Add-Artifact $artifacts "commercial-approval" "manual-commercial-approval-evidence.yml" $commercialApprovalRun "commercial_approval_run_id" "commercial-approval-evidence-$commercialApprovalRun" "commercial_approval_artifact_name" ".osmu-run/operations-readiness-artifacts/commercial-approval" $true "Imports latest-commercial-approval-evidence.json from final pricing, terms, support SLA, license, legal, pilot contract, and billing pricing proposal commercial approval evidence."
}
if ($hasEnterpriseAuthSmoke -or $workflows.Contains("enterprise-auth-smoke-ci.yml")) {
    Add-Artifact $artifacts "enterprise-auth" "enterprise-auth-smoke-ci.yml" $enterpriseAuthRun "enterprise_auth_run_id" "enterprise-auth-smoke-$enterpriseAuthRun" "enterprise_auth_artifact_name" ".osmu-run/operations-readiness-artifacts/enterprise-auth" $true "Imports latest-enterprise-auth-smoke.json from target IdP/directory smoke evidence or contractual scope-out evidence."
}
if ($hasOperationsHandoffPackage -or $workflows.Contains("manual-operations-handoff-package.yml")) {
    Add-Artifact $artifacts "operations-handoff-package" "manual-operations-handoff-package.yml" $operationsHandoffPackageRun "operations_handoff_package_run_id" "operations-handoff-package-$operationsHandoffPackageRun" "operations_handoff_package_artifact_name" ".osmu-run/operations-readiness-artifacts/operations-handoff-package" $true "Imports latest-operations-handoff-package.json from pilot or production handoff package evidence."
}
if ($hasDataFlowStoragePlan -or $workflows.Contains("manual-data-flow-storage-plan-evidence.yml")) {
    Add-Artifact $artifacts "data-flow-storage-plan" "manual-data-flow-storage-plan-evidence.yml" $dataFlowStoragePlanRun "data_flow_storage_plan_run_id" "data-flow-storage-plan-evidence-$dataFlowStoragePlanRun" "data_flow_storage_plan_artifact_name" ".osmu-run/operations-readiness-artifacts/data-flow-storage-plan" $true "Imports latest-data-flow-storage-plan.json from target analytics storage sizing, backfill, rollback, retention budget, and sanitized query-plan evidence."
}
if ($workflows.Contains("kubernetes-operations-report-sync-ci.yml")) {
    Add-Artifact $artifacts "kubernetes-operations-report-sync" "kubernetes-operations-report-sync-ci.yml" $kubernetesOperationsReportSyncRun "kubernetes_operations_report_sync_run_id" "kubernetes-operations-report-sync-$kubernetesOperationsReportSyncRun" "kubernetes_operations_report_sync_artifact_name" ".osmu-run/operations-readiness-artifacts/kubernetes-operations-report-sync" $true "Imports latest-kubernetes-operations-report-sync.json for convergence-level deployed dashboard sync evidence and optional latest-data-flow-storage-plan.json for dashboard plan visibility. MariaDB partition or dual-write plans must include the sanitized query-plan evidence summary."
}

$artifactArray = @($artifacts | ForEach-Object { $_ })
$requiredArtifacts = @($artifactArray | Where-Object { $_.requiredForReadiness })
$missingRequiredArtifacts = @($requiredArtifacts | Where-Object { -not $_.ready })
$readyArtifacts = @($artifactArray | Where-Object { $_.ready })

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

$securityFinalizerCommand = ""
if ($workflows.Contains("security-evidence-finalizer-ci.yml") -or $workflows.Contains("image-publish-sign-ci.yml") -or $workflows.Contains("container-security-ci.yml")) {
    $securityFinalizerCommand = "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=$imageSigningRun -f image_signing_artifact_name=osmu-image-signing-$ImageSigningVersion-$CommitSha -f container_security_run_id=$containerSecurityRun -f container_security_artifact_name=osmu-container-security-$CommitSha -f fail_if_not_passed=true"
}

$localImportArgs = New-Object System.Collections.Generic.List[string]
foreach ($artifact in $requiredArtifacts) {
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
    elseif ($group -eq "secret-rotation") {
        $localImportArgs.Add("-SecretRotationArtifactPath $downloadPath")
    }
    elseif ($group -eq "commercial-integration") {
        $localImportArgs.Add("-CommercialIntegrationArtifactPath $downloadPath")
    }
    elseif ($group -eq "commercial-approval") {
        $localImportArgs.Add("-CommercialApprovalArtifactPath $downloadPath")
    }
    elseif ($group -eq "enterprise-auth") {
        $localImportArgs.Add("-EnterpriseAuthArtifactPath $downloadPath")
    }
    elseif ($group -eq "operations-handoff-package") {
        $localImportArgs.Add("-OperationsHandoffPackageArtifactPath $downloadPath")
    }
    elseif ($group -eq "data-flow-storage-plan") {
        $localImportArgs.Add("-DataFlowStoragePlanArtifactPath $downloadPath")
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
elseif ($requiredArtifacts.Count -eq 0) {
    "no-readiness-artifacts"
}
else {
    "action-required"
}

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$report = [ordered]@{
    formatVersion = "osmu.operations-artifact-collection-plan.v1"
    generatedAt = $generatedAt
    result = $result
    sourceInvocationReport = $resolvedInvocationReportPath
    invocationResult = Get-Text $invocation "result"
    invocationSummary = "selected=$($invocation.selectedActionCount) planned=$($invocation.plannedCount) blocked=$($invocation.blockedCount) executed=$($invocation.executedCount) failed=$($invocation.failedCount)"
    artifactCount = $artifactArray.Count
    requiredArtifactCount = $requiredArtifacts.Count
    readyArtifactCount = $readyArtifacts.Count
    missingRequiredArtifactCount = $missingRequiredArtifacts.Count
    securityEvidenceFinalizerCommand = $securityFinalizerCommand
    operationsArtifactFinalizerCommand = $operationsArtifactFinalizerCommand
    dataFlowStoragePlanInputNote = $dataFlowStoragePlanInputNote
    localImportCommand = $localImportCommand
    decisionRule = "After evidence workflows finish, fill missing run ids, verify artifact names, then either dispatch operations-readiness-artifact-finalizer-ci.yml or download artifacts locally and run import-operations-readiness-artifacts.ps1."
    artifacts = $artifactArray
}

$markdownLines = @(
    "# OSMU Operations Artifact Collection Plan",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source invocation report: $resolvedInvocationReportPath",
    "Invocation result: $($report.invocationResult)",
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
}
if (-not [string]::IsNullOrWhiteSpace($localImportCommand)) {
    $markdownLines += "- Local import after downloads: ``$localImportCommand``"
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
