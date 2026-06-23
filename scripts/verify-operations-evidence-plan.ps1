param(
    [string] $OutputDirectory = ".\.osmu-run\operations-evidence-plan-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$fixturePath = Join-Path $resolvedOutputDirectory "fixture-operations-readiness.json"
$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-operations-evidence-plan.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-operations-evidence-plan.md"

$fixture = [ordered]@{
    formatVersion = "osmu.operations-readiness.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = "pending"
    passedCount = 1
    pendingCount = 5
    summary = "passed=1 pending=5"
    checks = @(
        [ordered]@{
            name = "Storage expansion finalizer live evidence"
            category = "storage-expansion"
            passed = $false
            status = "PENDING"
            detail = "report not found"
            evidencePath = ".osmu-run/latest-storage-expansion-finalize.json"
            requiredEvidence = "finalizer result=passed from target cluster"
            remediation = [ordered]@{
                command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -Namespace osmu -TenantName osmu-minio -ImpersonateRunner"
                workflow = ".github/workflows/storage-expansion-finalizer-ci.yml"
                workflowCommand = "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f impersonate_runner=true"
                note = "Run live against the target cluster with OSMU_KUBECONFIG_BASE64 configured."
            }
        },
        [ordered]@{
            name = "Kubernetes DR finalizer live evidence"
            category = "ha-dr"
            passed = $false
            status = "PENDING"
            detail = "result=planned"
            evidencePath = ".osmu-run/latest-kubernetes-dr-finalize.json"
            requiredEvidence = "finalizer result=ready from target cluster restore drill"
            remediation = [ordered]@{
                command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -BackupTimestamp <YYYYMMDDTHHMMSSZ> -ConfirmRestore -SubmitEvidence"
                workflow = ".github/workflows/kubernetes-dr-finalizer-ci.yml"
                workflowCommand = "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true -f submit_evidence=true"
                note = "Use a real backup timestamp and confirmed restore only after operator approval."
            }
        },
        [ordered]@{
            name = "Manual enterprise support sign-off"
            category = "commercial"
            passed = $false
            status = "PENDING"
            detail = "not approved"
            evidencePath = ".osmu-run/latest-commercial-signoff.json"
            requiredEvidence = "approved support and SLA sign-off"
        },
        [ordered]@{
            name = "Monitoring threshold target evidence"
            category = "monitoring"
            passed = $false
            status = "PENDING"
            detail = "report not found"
            evidencePath = ".osmu-run/latest-monitoring-threshold-evidence.json"
            requiredEvidence = "monitoring threshold evidence result=passed from target Prometheus/Grafana/Alertmanager/tenant baseline review"
            remediation = [ordered]@{
                command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-monitoring-threshold-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -PrometheusRuleEvidenceRef <ref> -GrafanaDashboardEvidenceRef <ref> -AlertmanagerRouteEvidenceRef <ref> -IncidentRoutingEvidenceRef <ref> -TenantBaselineEvidenceRef <ref> -ConfirmPrometheusRulesReviewed -ConfirmGrafanaDashboardsReviewed -ConfirmAlertmanagerRoutesReviewed -ConfirmIncidentRoutingReviewed -ConfirmTargetBaselinesReviewed -ConfirmNoAlertmanagerReceiverSecrets -ConfirmNoRawTenantObjectKeys -FailIfNotPassed"
                workflow = ".github/workflows/manual-monitoring-threshold-evidence.yml"
                workflowCommand = "gh workflow run manual-monitoring-threshold-evidence.yml -f environment_name=<env> -f target_cluster=<cluster> -f operator=<operator> -f review_started_at=<iso-time> -f review_completed_at=<iso-time> -f prometheus_rule_evidence_ref=<ref> -f grafana_dashboard_evidence_ref=<ref> -f alertmanager_route_evidence_ref=<ref> -f incident_routing_evidence_ref=<ref> -f tenant_baseline_evidence_ref=<ref> -f confirm_prometheus_rules_reviewed=true -f confirm_grafana_dashboards_reviewed=true -f confirm_alertmanager_routes_reviewed=true -f confirm_incident_routing_reviewed=true -f confirm_target_baselines_reviewed=true -f confirm_no_alertmanager_receiver_secrets=true -f confirm_no_raw_tenant_object_keys=true -f fail_if_not_passed=true"
                note = "Run after target Prometheus rules, Grafana dashboards, Alertmanager routes, incident routing, and tenant baselines are reviewed."
            }
        },
        [ordered]@{
            name = "Enterprise auth target smoke evidence"
            category = "enterprise-auth"
            passed = $false
            status = "PENDING"
            detail = "report not found"
            evidencePath = ".osmu-run/latest-enterprise-auth-smoke.json"
            requiredEvidence = "enterprise auth smoke result=passed from target IdP/directory"
            remediation = [ordered]@{
                command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-smoke-plan.ps1 -Execute -AdminLoginId <admin> -AdminPassword <secret> -RequireOidc -RequireLdap"
                workflow = ".github/workflows/enterprise-auth-smoke-ci.yml"
                workflowCommand = "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f api_base=<api-base> -f admin_login_id=<admin> -f require_oidc=true -f require_ldap=true -f fail_if_not_passed=true"
                note = "Requires OSMU_ENTERPRISE_AUTH_ADMIN_PASSWORD and optional LDAP/OIDC secrets, not OSMU_KUBECONFIG_BASE64."
            }
        },
        [ordered]@{
            name = "IAM/RBAC finalizer report"
            category = "iam-rbac"
            passed = $true
            status = "PASS"
            detail = "result=passed"
            evidencePath = ".osmu-run/latest-iam-rbac-finalize.json"
            requiredEvidence = "IAM/RBAC finalizer result=passed"
        }
    )
    decisionRule = "fixture"
}
$fixture | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $fixturePath -Encoding UTF8

$scriptPath = Resolve-ProjectPath ".\scripts\write-operations-evidence-plan.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ReadinessReportPath $fixturePath `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-operations-evidence-plan.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Operations evidence plan JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Operations evidence plan markdown missing."

$reportText = Get-Content -Raw -LiteralPath $jsonOutputPath
$markdown = Get-Content -Raw -LiteralPath $markdownOutputPath
$report = $reportText | ConvertFrom-Json

Assert-True ($report.formatVersion -eq "osmu.operations-evidence-plan.v1") "Unexpected operations evidence plan formatVersion."
Assert-True ($report.result -eq "action-required") "Expected action-required result."
Assert-True ($report.pendingCount -eq 5) "Expected five pending checks."
Assert-True ($report.actionCount -eq 4) "Expected four planned remediation actions."
Assert-True ($report.unplannedCount -eq 1) "Expected one unplanned check."

$actions = @($report.actions)
Assert-True ($actions[0].name -eq "Storage expansion finalizer live evidence") "Expected storage expansion as first action."
Assert-True ($actions[0].workflowCommand -like "gh workflow run storage-expansion-finalizer-ci.yml*") "Expected storage workflow command."
Assert-True ($actions[0].requiresKubeconfigSecret) "Storage expansion action should require kubeconfig."
Assert-True ($actions[0].requiresOperatorApproval) "Storage expansion run_live action should require operator approval."
Assert-True ($actions[1].name -eq "Kubernetes DR finalizer live evidence") "Expected Kubernetes DR as second action."
Assert-True ($actions[1].requiresOperatorApproval) "Kubernetes DR action should require operator approval."
Assert-True ($actions[1].hasPlaceholders) "Kubernetes DR action should keep placeholder markers."
Assert-True (@($actions[1].operatorInputs) -contains "<YYYYMMDDTHHMMSSZ>") "Kubernetes DR action should list backup timestamp placeholder."
Assert-True ($actions[2].name -eq "Monitoring threshold target evidence") "Expected monitoring threshold as third action."
Assert-True ($actions[2].workflowCommand -like "gh workflow run manual-monitoring-threshold-evidence.yml*") "Expected monitoring threshold workflow command."
Assert-True ($actions[2].requiresOperatorApproval) "Monitoring threshold action should require operator approval confirmations."
Assert-True (-not $actions[2].requiresKubeconfigSecret) "Monitoring threshold workflow should not require kubeconfig."
Assert-True (@($actions[2].operatorInputs) -contains "<env>") "Monitoring threshold action should list environment placeholder."
Assert-True ($actions[3].name -eq "Enterprise auth target smoke evidence") "Expected enterprise auth as fourth action."
Assert-True ($actions[3].workflowCommand -like "gh workflow run enterprise-auth-smoke-ci.yml*") "Expected enterprise auth workflow command."
Assert-True ($actions[3].requiresOperatorApproval) "Enterprise auth run_live action should require operator approval."
Assert-True (-not $actions[3].requiresKubeconfigSecret) "Enterprise auth workflow should not require kubeconfig just because it uses run_live=true."
Assert-True (@($actions[3].operatorInputs) -contains "<api-base>") "Enterprise auth action should list API base placeholder."

Assert-Contains $markdown "# OSMU Operations Evidence Plan" "Operations evidence plan markdown"
Assert-Contains $markdown "## Execution Order" "Operations evidence plan markdown"
Assert-Contains $markdown "gh workflow run kubernetes-dr-finalizer-ci.yml" "Operations evidence plan markdown"
Assert-Contains $markdown "gh workflow run manual-monitoring-threshold-evidence.yml" "Operations evidence plan markdown"
Assert-Contains $markdown "Operator approval: required" "Operations evidence plan markdown"
Assert-Contains $markdown "## Unplanned Checks" "Operations evidence plan markdown"

Write-Host "Operations evidence plan verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
