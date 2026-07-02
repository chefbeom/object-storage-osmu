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
$securityOnlyInvocationPath = Join-Path $selfTestRoot "fixture-security-only-operations-evidence-plan-invocation.json"
$securityOnlyJsonPath = Join-Path $selfTestRoot "security-only-operations-workflow-run-ids.json"
$securityOnlyMarkdownPath = Join-Path $selfTestRoot "security-only-operations-workflow-run-ids.md"

function Read-Utf8Text([string] $PathValue) {
    $resolved = if ([System.IO.Path]::IsPathRooted($PathValue)) {
        [System.IO.Path]::GetFullPath($PathValue)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
    }
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
}
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
  "sourcePassedCount": 36,
  "sourcePendingCount": 6,
  "sourceTotalCount": 42,
  "sourceCheckCount": 42,
  "selectedActionCount": 18,
  "plannedCount": 18,
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
    },
    {
      "order": 18,
      "name": "Data-flow query/retention budget evidence",
      "category": "data-flow",
      "command": "gh workflow run manual-data-flow-query-retention-budget-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f storage_plan_evidence_ref=data-flow-plan-20260620 -f storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f query_p95_latency_ms=420 -f query_p99_latency_ms=470 -f target_p95_query_latency_ms=500 -f query_sample_count=120 -f retention_detailed_seconds=20 -f retention_daily_seconds=18 -f retention_monthly_seconds=12 -f retention_budget_seconds=30 -f evidence_ref=data-flow-query-retention-20260620 -f confirm_storage_plan_reviewed=true -f confirm_retention_jobs_reviewed=true -f confirm_no_raw_sql=true -f confirm_no_object_keys_in_evidence=true -f confirm_no_raw_event_messages=true -f confirm_no_secret_values=true -f fail_if_not_passed=true"
    }
  ]
}
"@ | Set-Content -LiteralPath $invocationPath -Encoding UTF8

$invocationFixture = Read-Utf8Text $invocationPath | ConvertFrom-Json
$chargebackAction = [pscustomobject]@{
    order = 19
    name = "Chargeback closeout target evidence"
    category = "chargeback-closeout"
    command = "gh workflow run manual-chargeback-closeout-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f billing_period=2026-06 -f closeout_started_at=2026-06-30T01:00:00Z -f closeout_completed_at=2026-06-30T01:45:00Z -f change_approval_ref=chargeback-closeout-change-20260630 -f payment_provider_adapter_readiness_json_base64=<base64-payment-provider-adapter-readiness-json> -f chargeback_closeout_snapshot_json_base64=<base64-chargeback-closeout-summary-json> -f chargeback_closeout_payload_json_base64=<base64-chargeback-closeout-refs-and-confirmations-json> -f fail_if_not_passed=true"
}
$invocationFixture.actions = @($invocationFixture.actions) + $chargebackAction
$jitRollbackAction = [pscustomobject]@{
    order = 20
    name = "Enterprise auth JIT rollback target evidence"
    category = "enterprise-auth"
    command = "gh workflow run manual-enterprise-auth-jit-rollback-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f review_started_at=2026-06-20T01:10:00Z -f review_completed_at=2026-06-20T01:40:00Z -f change_approval_ref=enterprise-auth-jit-change-20260620 -f enterprise_auth_smoke_json_base64=<base64-latest-enterprise-auth-smoke-json> -f jit_rollback_payload_json_base64=<base64-enterprise-auth-jit-rollback-refs-and-confirmations-json> -f require_enterprise_auth_smoke_evidence=true -f fail_if_not_passed=true"
}
$invocationFixture.actions = @($invocationFixture.actions) + $jitRollbackAction
$clusterNetworkAccessReviewAction = [pscustomobject]@{
    order = 21
    name = "Cluster network access review target evidence"
    category = "security-hardening"
    command = "gh workflow run manual-cluster-network-access-review-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f review_started_at=2026-06-20T04:00:00Z -f review_completed_at=2026-06-20T04:20:00Z -f change_approval_ref=cluster-network-review-change-20260620 -f evidence_ref=cluster-network-access-review-20260620 -f access_review_refs_json_base64=<base64-json-with-network-review-refs> -f confirm_backend_only_mariadb=true -f confirm_backend_only_minio=true -f confirm_backup_only_mariadb_minio=true -f confirm_dns_egress_scoped=true -f confirm_mariadb_ingress_backend_backup_only=true -f confirm_minio_ingress_backend_backup_only=true -f confirm_public_ingress_limited=true -f confirm_namespace_default_deny_reviewed=true -f confirm_observability_scrape_reviewed=true -f confirm_helm_network_policy_enabled=true -f confirm_no_credential_values=true -f fail_if_not_passed=true"
}
$invocationFixture.actions = @($invocationFixture.actions) + $clusterNetworkAccessReviewAction
$helmValuesHardeningAction = [pscustomobject]@{
    order = 22
    name = "Helm values hardening target evidence"
    category = "security-hardening"
    command = "gh workflow run manual-helm-values-hardening-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f review_started_at=2026-06-20T04:20:00Z -f review_completed_at=2026-06-20T04:40:00Z -f change_approval_ref=helm-values-hardening-change-20260620 -f evidence_ref=helm-values-hardening-20260620 -f hardening_refs_json_base64=<base64-json-with-helm-hardening-refs> -f confirm_secrets_externalized=true -f confirm_default_secret_placeholders_not_used=true -f confirm_ha_replicas_reviewed=true -f confirm_resources_bounded=true -f confirm_security_contexts_reviewed=true -f confirm_network_policy_enabled=true -f confirm_tls_ingress_reviewed=true -f confirm_operations_reports_read_only=true -f confirm_storage_expansion_rbac_disabled_by_default=true -f confirm_no_credential_values=true -f fail_if_not_passed=true"
}
$invocationFixture.actions = @($invocationFixture.actions) + $helmValuesHardeningAction
$supportEscalationHandoffAction = [pscustomobject]@{
    order = 23
    name = "Support escalation handoff evidence"
    category = "operations-handoff-package"
    command = "gh workflow run manual-support-escalation-handoff-evidence.yml -f environment_name=prod -f target_cluster=osmu-prod -f operator=ops-owner -f review_started_at=2026-06-20T04:40:00Z -f review_completed_at=2026-06-20T05:00:00Z -f change_approval_ref=support-handoff-change-20260620 -f evidence_ref=support-escalation-handoff-20260620 -f handoff_refs_json_base64=<base64-json-with-support-handoff-refs> -f confirm_runbook_reviewed=true -f confirm_troubleshooting_reviewed=true -f confirm_rollback_path_reviewed=true -f confirm_support_escalation_reviewed=true -f confirm_support_sla_reviewed=true -f confirm_known_gaps_accepted=true -f confirm_operations_handoff_reference_ready=true -f confirm_no_credential_values=true -f fail_if_not_passed=true"
}
$invocationFixture.actions = @($invocationFixture.actions) + $supportEscalationHandoffAction
$invocationFixture.selectedActionCount = @($invocationFixture.actions).Count
$invocationFixture.plannedCount = @($invocationFixture.actions).Count
$invocationFixture | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $invocationPath -Encoding UTF8

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
Write-RunListFixture "manual-chargeback-closeout-evidence.yml" 119 $sha
Write-RunListFixture "manual-enterprise-auth-jit-rollback-evidence.yml" 120 $sha
Write-RunListFixture "enterprise-auth-smoke-ci.yml" 112 $sha
Write-RunListFixture "manual-operations-handoff-package.yml" 113 $sha
Write-RunListFixture "manual-data-flow-storage-plan-evidence.yml" 114 $sha
Write-RunListFixture "manual-data-flow-query-retention-budget-evidence.yml" 118 $sha
Write-RunListFixture "manual-data-flow-storage-transition-runbook-evidence.yml" 115 $sha
Write-RunListFixture "kubernetes-operations-report-sync-ci.yml" 116 $sha
Write-RunListFixture "manual-monitoring-threshold-evidence.yml" 117 $sha
Write-RunListFixture "manual-cluster-network-access-review-evidence.yml" 121 $sha
Write-RunListFixture "manual-helm-values-hardening-evidence.yml" 122 $sha
Write-RunListFixture "manual-support-escalation-handoff-evidence.yml" 123 $sha

& (Join-Path $PSScriptRoot "write-operations-workflow-run-id-plan.ps1") `
    -InvocationReportPath $invocationPath `
    -JsonOutputPath $planOnlyJsonPath `
    -MarkdownOutputPath $planOnlyMarkdownPath `
    -Branch main `
    -GitHubRepository "chefbeom/object-storage-osmu" `
    -ImageSigningVersion "v0.1.0-rc.1" | Out-Null

$planOnly = Read-Utf8Text $planOnlyJsonPath | ConvertFrom-Json
$planOnlyMarkdown = Read-Utf8Text $planOnlyMarkdownPath
Assert-Equal $planOnly.formatVersion "osmu.operations-workflow-run-id-plan.v1" "plan-only formatVersion"
Assert-Equal $planOnly.result "query-required" "plan-only result"
Assert-Equal $planOnly.githubRepository "chefbeom/object-storage-osmu" "plan-only GitHub repository"
Assert-Equal $planOnly.workflowCount 23 "plan-only workflow count"
Assert-Equal $planOnly.missingWorkflowCount 23 "plan-only missing workflow count"
Assert-Equal $planOnly.sourceActionCount @($invocationFixture.actions).Count "plan-only source action count"
Assert-Equal $planOnly.sourceSummary "passed=36 pending=6" "plan-only source summary"
Assert-Equal $planOnly.sourcePassedCount 36 "plan-only source passed count"
Assert-Equal $planOnly.sourcePendingCount 6 "plan-only source pending count"
Assert-Equal $planOnly.sourceTotalCount 42 "plan-only source total count"
Assert-Equal $planOnly.sourceCheckCount 42 "plan-only source check count"
Assert-Contains $planOnlyMarkdown "Source summary: passed=36 pending=6" "plan-only markdown source summary"
Assert-Contains $planOnlyMarkdown "Source counts: passed=36 pending=6 total=42 checks=42" "plan-only markdown source counts"
Assert-True (@($planOnly.sourceActionOrders) -contains 1) "plan-only top-level source action orders should include first action"
Assert-True (@($planOnly.selectedActionOrders) -contains 1) "plan-only selected action orders should include first action"
Assert-Contains $planOnlyMarkdown "Source action orders: 1, 2" "plan-only markdown source action orders"
Assert-Contains $planOnlyMarkdown "Selected action orders: 1, 2" "plan-only markdown selected action orders"
Assert-Equal $planOnly.runListJsonDirectory ".\.osmu-run\workflow-run-lists" "plan-only run-list JSON directory"
Assert-Contains $planOnly.runListJsonDirectoryCommand "-RunListJsonDirectory .\.osmu-run\workflow-run-lists" "plan-only run-list JSON command"
Assert-Equal $planOnly.runListJsonFilePattern "<workflow>.json" "plan-only run-list JSON file pattern"
Assert-Contains $planOnly.runListJsonHandoffNote "<workflow>.json" "plan-only run-list JSON handoff note"
Assert-True (@($planOnly.browserWorkflowRunsUrls) -contains "https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml") "plan-only top-level browser workflow runs URLs should include storage expansion"
Assert-Equal $planOnly.workflowRunIdInputs[0].runIdParameter "StorageExpansionRunId" "plan-only top-level workflow run id input parameter"
Assert-Contains $planOnly.workflowRunIdInputs[0].runListJsonPath "storage-expansion-finalizer-ci.yml.json" "plan-only top-level workflow run id input JSON path"
Assert-Contains $planOnly.recommendedCommands[0].command "-RunListJsonDirectory" "plan-only top-level saved JSON recommended command"
Assert-True (@($planOnly.recommendedCommands[0].dispatchUrls) -contains "https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml") "plan-only recommended command dispatch URLs"
Assert-Contains $planOnly.githubApiRunListCommand "-UseGitHubApi" "plan-only GitHub REST API command"
Assert-Contains $planOnly.githubApiRunListCommand "-GitHubRepository chefbeom/object-storage-osmu" "plan-only GitHub REST API repository"
Assert-Contains $planOnly.recommendedCommands[1].name "GitHub REST API" "plan-only REST API recommended command name"
Assert-Contains $planOnly.recommendedCommands[1].command "-UseGitHubApi" "plan-only REST API recommended command"
Assert-True (@($planOnly.recommendedCommands[1].dispatchUrls) -contains "https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml") "plan-only REST API recommended command dispatch URLs"
Assert-Contains $planOnly.manualArtifactCollectionPlanCommand "-StorageExpansionRunId <StorageExpansionRunId>" "plan-only manual artifact collection command should expose run id placeholder"
Assert-Contains $planOnly.recommendedCommands[3].name "browser run ids" "plan-only browser run id recommended command name"
Assert-Contains $planOnly.recommendedCommands[3].command "-StorageExpansionRunId <StorageExpansionRunId>" "plan-only browser run id recommended command should expose run id placeholder"
Assert-Contains $planOnly.recommendedCommands[3].note "full workflow run URL" "plan-only browser run id recommended command should accept workflow run URL"
Assert-True (@($planOnly.recommendedCommands[3].dispatchUrls) -contains "https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml") "plan-only browser run id recommended command dispatch URLs"
Assert-Equal ([bool] $planOnly.securityEvidenceFinalizerReady) $false "plan-only security finalizer should wait for run id inputs"
Assert-True (@($planOnly.securityEvidenceFinalizerRunIdInputs) -contains "ImageSigningRunId") "plan-only security finalizer should require image signing run id"
Assert-True (@($planOnly.securityEvidenceFinalizerRunIdInputs) -contains "ContainerSecurityRunId") "plan-only security finalizer should require container security run id"
Assert-True (@($planOnly.securityEvidenceFinalizerMissingRunIdInputs) -contains "ImageSigningRunId") "plan-only security finalizer should report missing image signing run id"
Assert-True (@($planOnly.securityEvidenceFinalizerMissingRunIdInputs) -contains "ContainerSecurityRunId") "plan-only security finalizer should report missing container security run id"
Assert-Contains $planOnly.securityEvidenceFinalizerDependencyNote "also collect ImageSigningRunId" "plan-only security finalizer dependency note"
Assert-Contains $planOnly.recommendedCommands[3].note "ImageSigningRunId" "plan-only browser run id command should mention security finalizer image signing dependency"
Assert-Contains $planOnly.recommendedCommands[5].note "Missing run id inputs: ImageSigningRunId, ContainerSecurityRunId" "plan-only security finalizer command should summarize missing inputs"
Assert-Contains $planOnlyMarkdown "Security Evidence Finalizer Inputs" "plan-only markdown security finalizer input section"
Assert-Contains $planOnlyMarkdown "Missing run id inputs: ImageSigningRunId, ContainerSecurityRunId" "plan-only markdown security finalizer missing inputs"
Assert-Contains $planOnlyMarkdown "Browser workflow runs URLs: https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml" "plan-only markdown browser workflow runs URLs"
Assert-Contains $planOnlyMarkdown "Recommended Commands" "plan-only markdown recommended commands section"
Assert-Contains $planOnlyMarkdown "Collect run ids from saved run-list JSON" "plan-only markdown saved JSON recommended command"
Assert-Contains $planOnlyMarkdown "Write artifact collection plan with browser run ids" "plan-only markdown browser run id artifact command"
Assert-Contains $planOnlyMarkdown "GitHub REST API run-id query" "plan-only markdown GitHub REST API query command"
Assert-Contains $planOnlyMarkdown "GitHub CLI run-id query" "plan-only markdown GitHub CLI query command"
Assert-Contains $planOnlyMarkdown "Saved Run List JSON Handoff" "plan-only markdown saved run-list handoff section"
Assert-Contains $planOnlyMarkdown "Saved run-list JSON plan" "plan-only markdown saved run-list command"
Assert-Contains $planOnly.workflows[0].queryCommand "gh run list --workflow storage-expansion-finalizer-ci.yml" "plan-only query command"
Assert-Contains $planOnly.workflows[0].gitHubApiQueryUrl "/actions/workflows/storage-expansion-finalizer-ci.yml/runs" "plan-only GitHub API query URL"
Assert-Equal $planOnly.workflows[0].runsUrl "https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml" "plan-only workflow runs URL"
Assert-Equal $planOnly.workflows[0].runListJsonFile "storage-expansion-finalizer-ci.yml.json" "plan-only workflow run-list JSON file"
Assert-Contains $planOnly.workflows[0].runListJsonPath "storage-expansion-finalizer-ci.yml.json" "plan-only workflow run-list JSON path"
Assert-Equal ([bool] $planOnly.workflows[0].runListJsonExists) $false "plan-only workflow run-list JSON exists flag"
Assert-Contains $planOnlyMarkdown "Save run-list JSON as:" "plan-only markdown workflow run-list JSON path"
Assert-Equal $planOnly.workflows[0].sourceActionCount 1 "plan-only source action count"
Assert-Equal $planOnly.workflows[0].primaryActionOrder 1 "plan-only primary action order"
Assert-True (@($planOnly.workflows[0].actionOrders) -contains 1) "plan-only action orders should include source action"
Assert-Contains $planOnly.workflows[0].primaryActionName "Storage expansion" "plan-only primary action name"
Assert-Contains $planOnlyMarkdown "storage-expansion-finalizer-ci.yml (actions 1)" "plan-only markdown action order"
Assert-Contains $planOnlyMarkdown "Workflow runs URL: https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml" "plan-only markdown workflow runs URL"
Assert-Contains $planOnly.workflows[0].artifactName "storage-expansion-finalizer-<run-id>" "plan-only artifact placeholder"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-secret-rotation-evidence.yml" "plan-only manual secret rotation workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-storage-backend-telemetry-evidence.yml" "plan-only manual storage backend telemetry workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-minio-bucket-cors-verification.yml" "plan-only manual MinIO bucket CORS workflow"
$planOnlyCorsWorkflow = @($planOnly.workflows | Where-Object { $_.workflow -eq "manual-minio-bucket-cors-verification.yml" } | Select-Object -First 1)
Assert-Equal ([bool] $planOnlyCorsWorkflow[0].requiredForReadiness) $false "plan-only MinIO bucket CORS is optional"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-commercial-integration-evidence.yml" "plan-only manual commercial integration workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-commercial-approval-evidence.yml" "plan-only manual commercial approval workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-chargeback-closeout-evidence.yml" "plan-only manual chargeback closeout workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-enterprise-auth-jit-rollback-evidence.yml" "plan-only manual enterprise auth JIT rollback workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-operations-handoff-package.yml" "plan-only manual handoff workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-data-flow-storage-plan-evidence.yml" "plan-only manual data-flow storage plan workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-data-flow-query-retention-budget-evidence.yml" "plan-only manual data-flow query/retention budget workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-data-flow-storage-transition-runbook-evidence.yml" "plan-only manual data-flow storage transition runbook workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-monitoring-threshold-evidence.yml" "plan-only manual monitoring threshold workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-cluster-network-access-review-evidence.yml" "plan-only manual cluster network access review workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-helm-values-hardening-evidence.yml" "plan-only manual Helm values hardening workflow"
Assert-Contains ($planOnly.workflows | ConvertTo-Json -Depth 8) "manual-support-escalation-handoff-evidence.yml" "plan-only manual support escalation handoff workflow"
Assert-Contains $planOnlyMarkdown "Artifact collection plan" "plan-only markdown command section"

& (Join-Path $PSScriptRoot "write-operations-workflow-run-id-plan.ps1") `
    -InvocationReportPath $invocationPath `
    -JsonOutputPath $readyJsonPath `
    -MarkdownOutputPath $readyMarkdownPath `
    -RunListJsonDirectory $runListDirectory `
    -Branch main `
    -GitHubRepository "chefbeom/object-storage-osmu" `
    -ImageSigningVersion "v0.1.0-rc.1" | Out-Null

$ready = Read-Utf8Text $readyJsonPath | ConvertFrom-Json
$readyMarkdown = Read-Utf8Text $readyMarkdownPath
Assert-Equal $ready.result "ready" "ready result"
Assert-Equal $ready.githubRepository "chefbeom/object-storage-osmu" "ready GitHub repository"
Assert-Equal $ready.readyWorkflowCount 23 "ready workflow count"
Assert-Equal $ready.missingWorkflowCount 0 "ready missing workflow count"
Assert-Equal $ready.sourceActionCount @($invocationFixture.actions).Count "ready source action count"
Assert-Equal $ready.sourcePassedCount 36 "ready source passed count"
Assert-Equal $ready.sourcePendingCount 6 "ready source pending count"
Assert-Equal $ready.sourceTotalCount 42 "ready source total count"
Assert-Equal $ready.sourceCheckCount 42 "ready source check count"
Assert-Equal $ready.runListJsonDirectory $runListDirectory "ready run-list JSON directory"
Assert-Contains $ready.runListJsonDirectoryCommand "-RunListJsonDirectory $runListDirectory" "ready run-list JSON command"
Assert-Contains $ready.runListJsonHandoffNote "$runListDirectory" "ready run-list JSON handoff note"
Assert-True (@($ready.browserWorkflowRunsUrls) -contains "https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml") "ready top-level browser workflow runs URLs should include storage expansion"
Assert-Equal $ready.workflowRunIdInputs[0].recommendedRunId "101" "ready top-level workflow run id input recommended run id"
Assert-Equal ([bool] $ready.workflowRunIdInputs[0].readyForArtifactDownload) $true "ready top-level workflow run id input ready flag"
Assert-Contains $ready.recommendedCommands[0].command "-RunListJsonDirectory" "ready top-level saved JSON recommended command"
Assert-Contains $ready.githubApiRunListCommand "-UseGitHubApi" "ready GitHub REST API command"
Assert-Contains $ready.recommendedCommands[1].command "-UseGitHubApi" "ready REST API recommended command"
Assert-Contains $ready.manualArtifactCollectionPlanCommand "-StorageExpansionRunId 101" "ready manual artifact collection command should use recommended run id"
Assert-Contains $ready.recommendedCommands[3].command "-StorageExpansionRunId 101" "ready browser run id recommended command should use recommended run id"
Assert-Contains $ready.recommendedCommands[4].command "write-operations-artifact-collection-plan.ps1" "ready top-level artifact collection recommended command"
Assert-Contains $readyMarkdown "Browser workflow runs URLs: https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml" "ready markdown browser workflow runs URLs"
Assert-Contains $readyMarkdown "Recommended Commands" "ready markdown recommended commands section"
Assert-Contains $readyMarkdown "Write artifact collection plan with browser run ids" "ready markdown browser run id artifact collection recommended command"
Assert-Contains $readyMarkdown "Write artifact collection plan" "ready markdown artifact collection recommended command"
Assert-Contains $readyMarkdown "Source counts: passed=36 pending=6 total=42 checks=42" "ready markdown source counts"
Assert-True (@($ready.sourceActionOrders) -contains 23) "ready top-level source action orders should include last action"
Assert-True (@($ready.selectedActionOrders) -contains 23) "ready selected action orders should include last action"
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
Assert-Contains $ready.artifactCollectionPlanCommand "-ChargebackCloseoutRunId 119" "chargeback closeout run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-EnterpriseAuthJitRollbackRunId 120" "enterprise auth JIT rollback run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-EnterpriseAuthRunId 112" "enterprise auth run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-OperationsHandoffPackageRunId 113" "operations handoff package run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-DataFlowStoragePlanRunId 114" "data-flow storage plan run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-DataFlowQueryRetentionBudgetRunId 118" "data-flow query/retention budget run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-DataFlowStorageTransitionRunbookRunId 115" "data-flow storage transition runbook run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-KubernetesOperationsReportSyncRunId 116" "Kubernetes operations report sync run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-MonitoringThresholdRunId 117" "monitoring threshold run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-ClusterNetworkAccessReviewRunId 121" "cluster network access review run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-HelmValuesHardeningRunId 122" "Helm values hardening run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-SupportEscalationHandoffRunId 123" "support escalation handoff run id argument"
Assert-Contains $ready.securityEvidenceFinalizerCommand "image_signing_run_id=104" "security finalizer image signing run id"
Assert-Contains $ready.securityEvidenceFinalizerCommand "container_security_run_id=105" "security finalizer container security run id"
Assert-Contains $ready.securityEvidenceFinalizerCommand "osmu-image-signing-v0.1.0-rc.1-$sha" "security finalizer image artifact"
Assert-Contains $ready.securityEvidenceFinalizerCommand "osmu-container-security-$sha" "security finalizer container artifact"
Assert-Equal ([bool] $ready.securityEvidenceFinalizerReady) $true "ready security finalizer source inputs should be ready"
Assert-True (@($ready.securityEvidenceFinalizerRunIdInputs) -contains "ImageSigningRunId") "ready security finalizer should retain image signing run id input metadata"
Assert-True (@($ready.securityEvidenceFinalizerRunIdInputs) -contains "ContainerSecurityRunId") "ready security finalizer should retain container security run id input metadata"
Assert-Equal @($ready.securityEvidenceFinalizerMissingRunIdInputs).Count 0 "ready security finalizer should have no missing run id inputs"
Assert-Contains $ready.securityEvidenceFinalizerDependencyNote "also collect ImageSigningRunId" "ready security finalizer dependency note"
Assert-Contains $ready.recommendedCommands[5].note "Missing run id inputs: none" "ready security finalizer command should summarize no missing inputs"
Assert-Contains $readyMarkdown "Security Evidence Finalizer Inputs" "ready markdown security finalizer input section"
Assert-Contains $readyMarkdown "Missing run id inputs: none" "ready markdown security finalizer missing inputs"
Assert-Contains $ready.workflows[0].artifactName "storage-expansion-finalizer-101" "ready storage artifact name"
Assert-Equal $ready.workflows[0].runsUrl "https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml" "ready workflow runs URL"
Assert-Equal $ready.workflows[0].runListJsonFile "storage-expansion-finalizer-ci.yml.json" "ready workflow run-list JSON file"
Assert-Contains $ready.workflows[0].runListJsonPath "storage-expansion-finalizer-ci.yml.json" "ready workflow run-list JSON path"
Assert-Equal ([bool] $ready.workflows[0].runListJsonExists) $true "ready workflow run-list JSON exists flag"
Assert-Equal $ready.workflows[0].primaryActionOrder 1 "ready primary action order"
Assert-True (@($ready.workflows[4].actionOrders) -contains 5) "ready container security action order"
Assert-Contains $readyMarkdown "Source action orders: 1" "ready markdown source action order"
Assert-Contains $readyMarkdown "Selected action orders: 1" "ready markdown selected action order"
Assert-Contains $readyMarkdown "storage-backend-telemetry-evidence-107" "ready markdown storage backend telemetry artifact"
Assert-Contains $readyMarkdown "minio-bucket-cors-verification-108" "ready markdown MinIO bucket CORS artifact"
Assert-Contains $readyMarkdown "not a readiness gate or AWS S3 parity work" "ready markdown MinIO bucket CORS scope"
Assert-Contains $readyMarkdown "cluster-network-access-review-evidence-121" "ready markdown cluster network access review artifact"
Assert-Contains $readyMarkdown "helm-values-hardening-evidence-122" "ready markdown Helm values hardening artifact"
Assert-Contains $readyMarkdown "support-escalation-handoff-evidence-123" "ready markdown support escalation handoff artifact"
Assert-Contains $readyMarkdown "secret-rotation-evidence-109" "ready markdown secret rotation artifact"
Assert-Contains $readyMarkdown "commercial-integration-evidence-110" "ready markdown commercial integration artifact"
Assert-Contains $readyMarkdown "commercial-approval-evidence-111" "ready markdown commercial approval artifact"
Assert-Contains $readyMarkdown "chargeback-closeout-evidence-119" "ready markdown chargeback closeout artifact"
Assert-Contains $readyMarkdown "enterprise-auth-smoke-112" "ready markdown enterprise auth artifact"
Assert-Contains $readyMarkdown "enterprise-auth-jit-rollback-evidence-120" "ready markdown enterprise auth JIT rollback artifact"
Assert-Contains $readyMarkdown "operations-handoff-package-113" "ready markdown operations handoff package artifact"
Assert-Contains $readyMarkdown "data-flow-storage-plan-evidence-114" "ready markdown data-flow storage plan artifact"
Assert-Contains $readyMarkdown "data-flow-query-retention-budget-evidence-118" "ready markdown data-flow query/retention budget artifact"
Assert-Contains $readyMarkdown "data-flow-storage-transition-runbook-evidence-115" "ready markdown data-flow storage transition runbook artifact"
Assert-Contains $readyMarkdown "kubernetes-operations-report-sync-116" "ready markdown Kubernetes operations report sync artifact"
Assert-Contains $readyMarkdown "monitoring-threshold-evidence-117" "ready markdown monitoring threshold artifact"
Assert-Contains $readyMarkdown "Recommended run id: 106" "ready markdown security evidence run id"


$securityOnlyInvocation = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan-invocation.v1"
    generatedAt = "2026-06-16T00:00:00Z"
    result = "planned"
    sourceSummary = "passed=82 pending=20"
    sourcePassedCount = 82
    sourcePendingCount = 20
    sourceTotalCount = 102
    sourceCheckCount = 102
    selectedActionCount = 1
    plannedCount = 1
    blockedCount = 0
    executedCount = 0
    failedCount = 0
    actions = @(
        [ordered]@{
            order = 6
            name = "Container scan/SBOM evidence"
            category = "security-hardening"
            actionType = "security-ci"
            status = "planned"
            command = "gh workflow run container-security-ci.yml"
        }
    )
}
$securityOnlyInvocation | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $securityOnlyInvocationPath -Encoding UTF8

& (Join-Path $PSScriptRoot "write-operations-workflow-run-id-plan.ps1") `
    -InvocationReportPath $securityOnlyInvocationPath `
    -JsonOutputPath $securityOnlyJsonPath `
    -MarkdownOutputPath $securityOnlyMarkdownPath `
    -Branch main `
    -GitHubRepository "chefbeom/object-storage-osmu" `
    -ImageSigningVersion "v0.1.0-rc.1" `
    -CommitSha $sha | Out-Null

$securityOnly = Read-Utf8Text $securityOnlyJsonPath | ConvertFrom-Json
$securityOnlyMarkdown = Read-Utf8Text $securityOnlyMarkdownPath
Assert-Equal $securityOnly.result "query-required" "security-only result"
Assert-Equal $securityOnly.workflowCount 1 "security-only workflow count should stay scoped to selected action"
Assert-Equal $securityOnly.missingWorkflowCount 1 "security-only missing workflow count should stay scoped to selected action"
Assert-Equal $securityOnly.workflowRunIdInputs[0].runIdParameter "ContainerSecurityRunId" "security-only selected workflow run id input"
Assert-True (@($securityOnly.browserWorkflowRunsUrls) -contains "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml") "security-only browser URLs should include container security"
Assert-True (@($securityOnly.browserWorkflowRunsUrls) -contains "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml") "security-only browser URLs should include supplemental image signing"
Assert-Equal @($securityOnly.securityEvidenceFinalizerRunIdInputHints).Count 2 "security-only security finalizer run id hint count"
$securityOnlyImageHint = @($securityOnly.securityEvidenceFinalizerRunIdInputHints | Where-Object { $_.runIdParameter -eq "ImageSigningRunId" } | Select-Object -First 1)
$securityOnlyContainerHint = @($securityOnly.securityEvidenceFinalizerRunIdInputHints | Where-Object { $_.runIdParameter -eq "ContainerSecurityRunId" } | Select-Object -First 1)
Assert-Equal $securityOnlyImageHint.workflow "image-publish-sign-ci.yml" "security-only supplemental image signing workflow hint"
Assert-Equal ([bool] $securityOnlyImageHint.sourceSelected) $false "security-only image signing hint source selected flag"
Assert-Equal ([bool] $securityOnlyImageHint.supplementalForSecurityFinalizer) $true "security-only image signing hint supplemental flag"
Assert-Contains $securityOnlyImageHint.runListJsonPath "image-publish-sign-ci.yml.json" "security-only image signing run-list path"
Assert-Equal $securityOnlyContainerHint.workflow "container-security-ci.yml" "security-only container workflow hint"
Assert-Equal ([bool] $securityOnlyContainerHint.sourceSelected) $true "security-only container hint source selected flag"
Assert-Equal ([bool] $securityOnlyContainerHint.supplementalForSecurityFinalizer) $false "security-only container hint supplemental flag"
Assert-Contains $securityOnly.manualArtifactCollectionPlanCommand "-ImageSigningRunId <ImageSigningRunId>" "security-only manual artifact command should include image signing placeholder"
Assert-Contains $securityOnly.manualArtifactCollectionPlanCommand "-ContainerSecurityRunId <ContainerSecurityRunId>" "security-only manual artifact command should include container security placeholder"
Assert-Contains $securityOnly.recommendedCommands[3].command "-ImageSigningRunId <ImageSigningRunId>" "security-only browser artifact command should include image signing placeholder"
Assert-Contains $securityOnlyMarkdown "Security Evidence Finalizer Run ID Hints" "security-only markdown run id hint section"
Assert-Contains $securityOnlyMarkdown "image-publish-sign-ci.yml" "security-only markdown image signing workflow hint"
Assert-Contains $securityOnlyMarkdown "Supplemental: True" "security-only markdown supplemental flag"
Write-Host "Operations workflow run id plan verified."
Write-Host "Plan-only report: $planOnlyJsonPath"
Write-Host "Ready report: $readyJsonPath"
Write-Host "Security-only report: $securityOnlyJsonPath"
