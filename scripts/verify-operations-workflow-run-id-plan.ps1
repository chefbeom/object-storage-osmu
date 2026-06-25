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

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
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
  "selectedActionCount": 17,
  "plannedCount": 17,
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
      "name": "MinIO bucket CORS browser upload evidence",
      "category": "storage-backend",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\verify-minio-bucket-cors.ps1 -BucketName osmu-prod -MinioAlias osmu-minio -CorsXmlPath .\\.osmu-run\\minio-bucket-cors.xml -FailIfNotPassed"
    },
    {
      "order": 9,
      "name": "Secret/certificate rotation target evidence",
      "category": "security-hardening",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-secret-rotation-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -FailIfNotPassed"
    },
    {
      "order": 10,
      "name": "Commercial integration target evidence",
      "category": "commercial-integration",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-commercial-integration-evidence.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -FailIfNotPassed"
    },
    {
      "order": 11,
      "name": "Commercial approval target evidence",
      "category": "commercial-approval",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-commercial-approval-evidence.ps1 -ProductVersion v0.1.0-rc.1 -ApprovalRef commercial-approval-20260620 -FailIfNotPassed"
    },
    {
      "order": 12,
      "name": "Enterprise auth target smoke evidence",
      "category": "enterprise-auth",
      "command": "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f require_oidc=true -f require_ldap=true"
    },
    {
      "order": 13,
      "name": "Operations handoff package target evidence",
      "category": "operations-handoff-package",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-handoff-package.ps1 -EnvironmentName prod -TargetCluster osmu-prod -Operator ops-owner -FailIfNotPassed"
    },
    {
      "order": 14,
      "name": "Data-flow storage transition target evidence",
      "category": "data-flow",
      "command": "gh workflow run manual-data-flow-storage-plan-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f candidate_store=MARIADB_PARTITION -f expected_peak_events_per_day=100000 -f expected_query_window_days=180 -f target_p95_query_latency_ms=500 -f evidence_ref=data-flow-plan-20260620 -f query_plan_evidence_json_base64=<base64-json> -f confirm_no_object_key_in_aggregates=true -f confirm_backfill_plan=true -f confirm_rollback_plan=true -f confirm_dashboard_cutover_plan=true -f confirm_retention_job_budget=true -f confirm_explain_evidence=true -f require_query_plan_evidence=true -f fail_if_not_passed=true"
    },
    {
      "order": 15,
      "name": "Data-flow storage transition runbook evidence",
      "category": "data-flow",
      "command": "gh workflow run manual-data-flow-storage-transition-runbook-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f review_started_at=2026-06-20T02:00:00Z -f review_completed_at=2026-06-20T02:30:00Z -f change_approval_ref=data-flow-runbook-change-20260620 -f data_flow_storage_plan_evidence_ref=data-flow-plan-20260620 -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f backfill_evidence_ref=backfill-20260620 -f dual_write_or_partition_toggle_evidence_ref=dual-write-20260620 -f rollback_evidence_ref=rollback-20260620 -f reconciliation_evidence_ref=reconciliation-20260620 -f dashboard_cutover_evidence_ref=dashboard-cutover-20260620 -f retention_dry_run_evidence_ref=retention-dry-run-20260620 -f evidence_ref=data-flow-runbook-20260620 -f confirm_backfill_rehearsed=true -f confirm_dual_write_or_partition_toggle_reviewed=true -f confirm_rollback_rehearsed=true -f confirm_reconciliation_passed=true -f confirm_dashboard_cutover_reviewed=true -f confirm_retention_dry_run_reviewed=true -f confirm_no_object_keys_in_aggregates=true -f confirm_no_secret_values=true -f fail_if_not_passed=true"
    },
    {
      "order": 16,
      "name": "Kubernetes operations report sync evidence",
      "category": "operations",
      "command": "gh workflow run kubernetes-operations-report-sync-ci.yml -f run_live=true -f apply=true"
    },
    {
      "order": 17,
      "name": "Monitoring threshold target evidence",
      "category": "monitoring",
      "command": "gh workflow run manual-monitoring-threshold-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f review_started_at=2026-06-20T03:00:00Z -f review_completed_at=2026-06-20T03:20:00Z -f change_approval_ref=monitoring-threshold-change-20260620 -f prometheus_rules_evidence_ref=prometheus-rules-20260620 -f grafana_dashboard_evidence_ref=grafana-dashboard-20260620 -f alertmanager_route_evidence_ref=alertmanager-route-20260620 -f target_baseline_evidence_ref=target-baseline-20260620 -f incident_routing_evidence_ref=incident-routing-20260620 -f evidence_ref=monitoring-threshold-20260620 -f confirm_prometheus_rules_loaded=true -f confirm_grafana_dashboard_imported=true -f confirm_alertmanager_routes_reviewed=true -f confirm_target_baselines_reviewed=true -f confirm_incident_routing_reviewed=true -f confirm_no_secret_values=true -f fail_if_not_passed=true"
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
Write-RunListFixture "manual-minio-bucket-cors-verification.yml" 108 $sha
Write-RunListFixture "manual-secret-rotation-evidence.yml" 109 $sha
Write-RunListFixture "manual-commercial-integration-evidence.yml" 110 $sha
Write-RunListFixture "manual-commercial-approval-evidence.yml" 111 $sha
Write-RunListFixture "enterprise-auth-smoke-ci.yml" 112 $sha
Write-RunListFixture "manual-operations-handoff-package.yml" 113 $sha
Write-RunListFixture "manual-data-flow-storage-plan-evidence.yml" 114 $sha
Write-RunListFixture "manual-data-flow-storage-transition-runbook-evidence.yml" 115 $sha
Write-RunListFixture "kubernetes-operations-report-sync-ci.yml" 116 $sha
Write-RunListFixture "manual-monitoring-threshold-evidence.yml" 117 $sha

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
Assert-Equal $planOnly.workflowCount 17 "plan-only workflow count"
Assert-Equal $planOnly.missingWorkflowCount 17 "plan-only missing workflow count"
Assert-Contains $planOnly.workflows[0].queryCommand "gh run list --workflow storage-expansion-finalizer-ci.yml" "plan-only query command"
Assert-Equal $planOnly.workflows[0].sourceActionCount 1 "plan-only source action count"
Assert-Equal $planOnly.workflows[0].primaryActionOrder 1 "plan-only primary action order"
Assert-True (@($planOnly.workflows[0].actionOrders) -contains 1) "plan-only action orders should include source action"
Assert-Contains $planOnly.workflows[0].primaryActionName "Storage expansion" "plan-only primary action name"
Assert-Contains $planOnlyMarkdown "storage-expansion-finalizer-ci.yml (actions 1)" "plan-only markdown action order"
Assert-Contains $planOnly.workflows[0].artifactName "storage-expansion-finalizer-<run-id>" "plan-only artifact placeholder"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-secret-rotation-evidence.yml" "plan-only manual secret rotation workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-storage-backend-telemetry-evidence.yml" "plan-only manual storage backend telemetry workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-minio-bucket-cors-verification.yml" "plan-only manual MinIO bucket CORS workflow"
$planOnlyCorsWorkflow = @($planOnly.workflows | Where-Object { $_.workflow -eq "manual-minio-bucket-cors-verification.yml" } | Select-Object -First 1)
Assert-Equal ([bool] $planOnlyCorsWorkflow[0].requiredForReadiness) $false "plan-only MinIO bucket CORS is optional"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-commercial-integration-evidence.yml" "plan-only manual commercial integration workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-commercial-approval-evidence.yml" "plan-only manual commercial approval workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-operations-handoff-package.yml" "plan-only manual handoff workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-data-flow-storage-plan-evidence.yml" "plan-only manual data-flow storage plan workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-data-flow-storage-transition-runbook-evidence.yml" "plan-only manual data-flow storage transition runbook workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-monitoring-threshold-evidence.yml" "plan-only manual monitoring threshold workflow"
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
Assert-Equal $ready.readyWorkflowCount 17 "ready workflow count"
Assert-Equal $ready.missingWorkflowCount 0 "ready missing workflow count"
Assert-Equal $ready.commitSha $sha "ready commit sha from run headSha"
Assert-Contains $ready.artifactCollectionPlanCommand "-StorageExpansionRunId 101" "storage expansion run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-HaDrReadinessRunId 102" "HA/DR run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-KubernetesDrRunId 103" "Kubernetes DR run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-ImageSigningRunId 104" "image signing run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-ContainerSecurityRunId 105" "container security run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-SecurityEvidenceRunId 106" "security evidence run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-StorageBackendTelemetryRunId 107" "storage backend telemetry run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-MinioBucketCorsRunId 108" "MinIO bucket CORS run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-SecretRotationRunId 109" "secret rotation run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-CommercialIntegrationRunId 110" "commercial integration run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-CommercialApprovalRunId 111" "commercial approval run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-EnterpriseAuthRunId 112" "enterprise auth run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-OperationsHandoffPackageRunId 113" "operations handoff package run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-DataFlowStoragePlanRunId 114" "data-flow storage plan run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-DataFlowStorageTransitionRunbookRunId 115" "data-flow storage transition runbook run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-KubernetesOperationsReportSyncRunId 116" "Kubernetes operations report sync run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-MonitoringThresholdRunId 117" "monitoring threshold run id argument"
Assert-Contains $ready.securityEvidenceFinalizerCommand "image_signing_run_id=104" "security finalizer image signing run id"
Assert-Contains $ready.securityEvidenceFinalizerCommand "container_security_run_id=105" "security finalizer container security run id"
Assert-Contains $ready.securityEvidenceFinalizerCommand "osmu-image-signing-v0.1.0-rc.1-$sha" "security finalizer image artifact"
Assert-Contains $ready.securityEvidenceFinalizerCommand "osmu-container-security-$sha" "security finalizer container artifact"
Assert-Contains $ready.workflows[0].artifactName "storage-expansion-finalizer-101" "ready storage artifact name"
Assert-Equal $ready.workflows[0].primaryActionOrder 1 "ready primary action order"
Assert-True (@($ready.workflows[4].actionOrders) -contains 5) "ready container security action order"
Assert-Contains $readyMarkdown "Source action orders: 1" "ready markdown source action order"
Assert-Contains $readyMarkdown "storage-backend-telemetry-evidence-107" "ready markdown storage backend telemetry artifact"
Assert-Contains $readyMarkdown "minio-bucket-cors-verification-108" "ready markdown MinIO bucket CORS artifact"
Assert-Contains $readyMarkdown "not a readiness gate or AWS S3 parity work" "ready markdown MinIO bucket CORS scope"
Assert-Contains $readyMarkdown "secret-rotation-evidence-109" "ready markdown secret rotation artifact"
Assert-Contains $readyMarkdown "commercial-integration-evidence-110" "ready markdown commercial integration artifact"
Assert-Contains $readyMarkdown "commercial-approval-evidence-111" "ready markdown commercial approval artifact"
Assert-Contains $readyMarkdown "enterprise-auth-smoke-112" "ready markdown enterprise auth artifact"
Assert-Contains $readyMarkdown "operations-handoff-package-113" "ready markdown operations handoff package artifact"
Assert-Contains $readyMarkdown "data-flow-storage-plan-evidence-114" "ready markdown data-flow storage plan artifact"
Assert-Contains $readyMarkdown "data-flow-storage-transition-runbook-evidence-115" "ready markdown data-flow storage transition runbook artifact"
Assert-Contains $readyMarkdown "kubernetes-operations-report-sync-116" "ready markdown Kubernetes operations report sync artifact"
Assert-Contains $readyMarkdown "monitoring-threshold-evidence-117" "ready markdown monitoring threshold artifact"
Assert-Contains $readyMarkdown "Recommended run id: 106" "ready markdown security evidence run id"

Write-Host "Operations workflow run id plan verified."
Write-Host "Plan-only report: $planOnlyJsonPath"
Write-Host "Ready report: $readyJsonPath"
