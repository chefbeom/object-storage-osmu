param()

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$selfTestRoot = Join-Path $root ".osmu-run\operations-workflow-run-id-plan-self-test"
$runListDirectory = Join-Path $selfTestRoot "run-lists"
$invocationPath = Join-Path $selfTestRoot "fixture-operations-evidence-plan-invocation.json"
$planOnlyJsonPath = Join-Path $selfTestRoot "plan-only-operations-workflow-run-ids.json"
$planOnlyMarkdownPath = Join-Path $selfTestRoot "plan-only-operations-workflow-run-ids.md"
$readyJsonPath = Join-Path $selfTestRoot "ready-operations-workflow-run-ids.json"
$readyMarkdownPath = Join-Path $selfTestRoot "ready-operations-workflow-run-ids.md"

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message. Expected '$Expected' but got '$Actual'."
    }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Message) {
    if (-not $Text.Contains($Expected)) {
        throw "$Message. Missing '$Expected'."
    }
}

function Write-RunListFixture([string] $Workflow, [int] $RunId, [string] $Sha) {
    $runs = @(
        [ordered]@{
            databaseId = $RunId
            workflowName = $Workflow
            status = "completed"
            conclusion = "success"
            createdAt = "2026-06-16T00:00:00Z"
            headSha = $Sha
            url = "https://github.example/osmu/actions/runs/$RunId"
            displayTitle = "Operations evidence"
        }
    )
    $runs | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runListDirectory "$Workflow.json") -Encoding UTF8
}

New-Item -ItemType Directory -Force -Path $selfTestRoot | Out-Null
New-Item -ItemType Directory -Force -Path $runListDirectory | Out-Null

@"
{
  "formatVersion": "osmu.operations-evidence-plan-invocation.v1",
  "result": "planned",
  "sourceSummary": "passed=36 pending=6",
  "selectedActionCount": 13,
  "plannedCount": 13,
  "blockedCount": 0,
  "executedCount": 0,
  "failedCount": 0,
  "actions": [
    {
      "order": 1,
      "name": "Storage expansion finalizer live evidence",
      "category": "storage-expansion",
      "command": "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true"
    },
    {
      "order": 2,
      "name": "Kubernetes HA/DR readiness live evidence",
      "category": "ha-dr",
      "command": "gh workflow run kubernetes-ha-dr-readiness-ci.yml -f run_live=true"
    },
    {
      "order": 3,
      "name": "Kubernetes DR finalizer live evidence",
      "category": "ha-dr",
      "command": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true"
    },
    {
      "order": 4,
      "name": "Signed image evidence",
      "category": "security-hardening",
      "command": "gh workflow run image-publish-sign-ci.yml -f version=v0.1.0-rc.1 -f publish=true"
    },
    {
      "order": 5,
      "name": "Container scan/SBOM evidence",
      "category": "security-hardening",
      "command": "gh workflow run container-security-ci.yml"
    },
    {
      "order": 6,
      "name": "Security evidence finalizer report",
      "category": "security-hardening",
      "command": "gh workflow run security-evidence-finalizer-ci.yml -f fail_if_not_passed=true"
    },
    {
      "order": 7,
      "name": "Storage backend telemetry target evidence",
      "category": "storage-backend",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-storage-backend-telemetry-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -MinioAlias osmu-minio -EvidenceRef storage-telemetry-20260620 -AdminInfoJsonPath .\\.osmu-run\\minio-admin-info.json -FailIfNotPassed"
    },
    {
      "order": 8,
      "name": "Secret/certificate rotation target evidence",
      "category": "security-hardening",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-secret-rotation-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -FailIfNotPassed"
    },
    {
      "order": 9,
      "name": "Commercial integration target evidence",
      "category": "commercial-integration",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-commercial-integration-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -FailIfNotPassed"
    },
    {
      "order": 10,
      "name": "Commercial approval target evidence",
      "category": "commercial-approval",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-commercial-approval-evidence.ps1 -ProductVersion v0.1.0-rc.1 -ApprovalRef commercial-approval-20260620 -FailIfNotPassed"
    },
    {
      "order": 11,
      "name": "Enterprise auth target smoke evidence",
      "category": "enterprise-auth",
      "command": "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f require_oidc=true -f require_ldap=true"
    },
    {
      "order": 12,
      "name": "Operations handoff package target evidence",
      "category": "operations-handoff-package",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-handoff-package.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -FailIfNotPassed"
    },
    {
      "order": 13,
      "name": "Kubernetes operations report sync evidence",
      "category": "operations",
      "command": "gh workflow run kubernetes-operations-report-sync-ci.yml -f run_live=true -f apply=true"
    }
  ]
}
"@ | Set-Content -LiteralPath $invocationPath -Encoding UTF8

$sha = "abc123abc123abc123abc123abc123abc123abcd"
Write-RunListFixture "storage-expansion-finalizer-ci.yml" 101 $sha
Write-RunListFixture "kubernetes-ha-dr-readiness-ci.yml" 102 $sha
Write-RunListFixture "kubernetes-dr-finalizer-ci.yml" 103 $sha
Write-RunListFixture "image-publish-sign-ci.yml" 104 $sha
Write-RunListFixture "container-security-ci.yml" 105 $sha
Write-RunListFixture "security-evidence-finalizer-ci.yml" 106 $sha
Write-RunListFixture "manual-storage-backend-telemetry-evidence.yml" 107 $sha
Write-RunListFixture "manual-secret-rotation-evidence.yml" 108 $sha
Write-RunListFixture "manual-commercial-integration-evidence.yml" 109 $sha
Write-RunListFixture "manual-commercial-approval-evidence.yml" 110 $sha
Write-RunListFixture "enterprise-auth-smoke-ci.yml" 111 $sha
Write-RunListFixture "manual-operations-handoff-package.yml" 112 $sha
Write-RunListFixture "kubernetes-operations-report-sync-ci.yml" 113 $sha

& (Join-Path $PSScriptRoot "write-operations-workflow-run-id-plan.ps1") `
    -InvocationReportPath $invocationPath `
    -JsonOutputPath $planOnlyJsonPath `
    -MarkdownOutputPath $planOnlyMarkdownPath `
    -Branch main `
    -ImageSigningVersion "v0.1.0-rc.1" | Out-Null

$planOnly = Get-Content -Raw -LiteralPath $planOnlyJsonPath | ConvertFrom-Json
$planOnlyMarkdown = Get-Content -Raw -LiteralPath $planOnlyMarkdownPath
Assert-Equal $planOnly.formatVersion "osmu.operations-workflow-run-id-plan.v1" "plan-only formatVersion"
Assert-Equal $planOnly.result "query-required" "plan-only result"
Assert-Equal $planOnly.workflowCount 13 "plan-only workflow count"
Assert-Equal $planOnly.missingWorkflowCount 13 "plan-only missing workflow count"
Assert-Contains $planOnly.workflows[0].queryCommand "gh run list --workflow storage-expansion-finalizer-ci.yml" "plan-only query command"
Assert-Contains $planOnly.workflows[0].artifactName "storage-expansion-finalizer-<run-id>" "plan-only artifact placeholder"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-secret-rotation-evidence.yml" "plan-only manual secret rotation workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-storage-backend-telemetry-evidence.yml" "plan-only manual storage backend telemetry workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-commercial-integration-evidence.yml" "plan-only manual commercial integration workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-commercial-approval-evidence.yml" "plan-only manual commercial approval workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-operations-handoff-package.yml" "plan-only manual handoff workflow"
Assert-Contains $planOnlyMarkdown "Artifact collection plan" "plan-only markdown command section"

& (Join-Path $PSScriptRoot "write-operations-workflow-run-id-plan.ps1") `
    -InvocationReportPath $invocationPath `
    -JsonOutputPath $readyJsonPath `
    -MarkdownOutputPath $readyMarkdownPath `
    -RunListJsonDirectory $runListDirectory `
    -Branch main `
    -ImageSigningVersion "v0.1.0-rc.1" | Out-Null

$ready = Get-Content -Raw -LiteralPath $readyJsonPath | ConvertFrom-Json
$readyMarkdown = Get-Content -Raw -LiteralPath $readyMarkdownPath
Assert-Equal $ready.result "ready" "ready result"
Assert-Equal $ready.readyWorkflowCount 13 "ready workflow count"
Assert-Equal $ready.missingWorkflowCount 0 "ready missing workflow count"
Assert-Equal $ready.commitSha $sha "ready commit sha from run headSha"
Assert-Contains $ready.artifactCollectionPlanCommand "-StorageExpansionRunId 101" "storage expansion run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-HaDrReadinessRunId 102" "HA/DR run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-KubernetesDrRunId 103" "Kubernetes DR run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-ImageSigningRunId 104" "image signing run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-ContainerSecurityRunId 105" "container security run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-SecurityEvidenceRunId 106" "security evidence run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-StorageBackendTelemetryRunId 107" "storage backend telemetry run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-SecretRotationRunId 108" "secret rotation run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-CommercialIntegrationRunId 109" "commercial integration run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-CommercialApprovalRunId 110" "commercial approval run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-EnterpriseAuthRunId 111" "enterprise auth run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-OperationsHandoffPackageRunId 112" "operations handoff package run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-KubernetesOperationsReportSyncRunId 113" "Kubernetes operations report sync run id argument"
Assert-Contains $ready.securityEvidenceFinalizerCommand "image_signing_run_id=104" "security finalizer image signing run id"
Assert-Contains $ready.securityEvidenceFinalizerCommand "container_security_run_id=105" "security finalizer container security run id"
Assert-Contains $ready.securityEvidenceFinalizerCommand "osmu-image-signing-v0.1.0-rc.1-$sha" "security finalizer image artifact"
Assert-Contains $ready.securityEvidenceFinalizerCommand "osmu-container-security-$sha" "security finalizer container artifact"
Assert-Contains $ready.workflows[0].artifactName "storage-expansion-finalizer-101" "ready storage artifact name"
Assert-Contains $readyMarkdown "storage-backend-telemetry-evidence-107" "ready markdown storage backend telemetry artifact"
Assert-Contains $readyMarkdown "secret-rotation-evidence-108" "ready markdown secret rotation artifact"
Assert-Contains $readyMarkdown "commercial-integration-evidence-109" "ready markdown commercial integration artifact"
Assert-Contains $readyMarkdown "commercial-approval-evidence-110" "ready markdown commercial approval artifact"
Assert-Contains $readyMarkdown "enterprise-auth-smoke-111" "ready markdown enterprise auth artifact"
Assert-Contains $readyMarkdown "operations-handoff-package-112" "ready markdown operations handoff package artifact"
Assert-Contains $readyMarkdown "kubernetes-operations-report-sync-113" "ready markdown Kubernetes operations report sync artifact"
Assert-Contains $readyMarkdown "Recommended run id: 106" "ready markdown security evidence run id"

Write-Host "Operations workflow run id plan verified."
Write-Host "Plan-only report: $planOnlyJsonPath"
Write-Host "Ready report: $readyJsonPath"
