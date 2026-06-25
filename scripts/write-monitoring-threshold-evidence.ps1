param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $ReviewStartedAt = "",
    [string] $ReviewCompletedAt = "",
    [string] $ChangeApprovalRef = "",
    [string] $ThresholdTargetsPath = ".\infra\monitoring\alert-threshold-targets.yaml",
    [string] $PrometheusRulesEvidenceRef = "",
    [string] $GrafanaDashboardEvidenceRef = "",
    [string] $AlertmanagerRouteEvidenceRef = "",
    [string] $TargetBaselineEvidenceRef = "",
    [string] $IncidentRoutingEvidenceRef = "",
    [string] $EvidenceRef = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-monitoring-threshold-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-monitoring-threshold-evidence.md",
    [switch] $ConfirmPrometheusRulesLoaded,
    [switch] $ConfirmGrafanaDashboardImported,
    [switch] $ConfirmAlertmanagerRoutesReviewed,
    [switch] $ConfirmTargetBaselinesReviewed,
    [switch] $ConfirmIncidentRoutingReviewed,
    [switch] $ConfirmNoSecretValues,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-SafeText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "(?i)\b(password|passwd|secret|token|client_secret|x-amz-security-token|smtp_pass|webhook_secret)\s*[=:]\s*\S+"
    )

    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain credential material. Store only an external evidence reference."
        }
    }
}

function Test-DateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse($Value, [ref] $parsed)
}

function Get-ParsedDateText([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($Value, [ref] $parsed)) {
        return $parsed
    }
    return $null
}

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail) {
    return [ordered]@{
        id = $Id
        name = $Name
        status = $Status
        passed = $Status -eq "PASS"
        detail = $Detail
    }
}

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail) {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    [void] $script:checks.Add((New-Check $Id $Name $status $Detail))
}

function Get-Matches([string] $Content, [string] $Pattern) {
    return @([regex]::Matches($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline))
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("Operator", $Operator),
    @("ChangeApprovalRef", $ChangeApprovalRef),
    @("PrometheusRulesEvidenceRef", $PrometheusRulesEvidenceRef),
    @("GrafanaDashboardEvidenceRef", $GrafanaDashboardEvidenceRef),
    @("AlertmanagerRouteEvidenceRef", $AlertmanagerRouteEvidenceRef),
    @("TargetBaselineEvidenceRef", $TargetBaselineEvidenceRef),
    @("IncidentRoutingEvidenceRef", $IncidentRoutingEvidenceRef),
    @("EvidenceRef", $EvidenceRef)
)) {
    Assert-SafeText ([string] $entry[1]) ([string] $entry[0])
}

$resolvedThresholdTargetsPath = Resolve-ProjectPath $ThresholdTargetsPath
$thresholdTargetsExists = Test-Path -LiteralPath $resolvedThresholdTargetsPath
$thresholdTargetsContent = ""
if ($thresholdTargetsExists) {
    $thresholdTargetsContent = Get-Content -Raw -LiteralPath $resolvedThresholdTargetsPath
    Assert-SafeText $thresholdTargetsContent "ThresholdTargetsPath"
}

$requiredAlerts = @(
    "OsmuBackendHighErrorRate",
    "OsmuBackendHighLatencyP95",
    "OsmuDataFlowFailureSpike",
    "OsmuDataFlowCancelSpike",
    "OsmuDataFlowAbnormalEgress",
    "OsmuDataFlowBucketTrafficAnomaly",
    "OsmuDataFlowRetentionFailures",
    "OsmuDataFlowDailyRollupRetentionFailures",
    "OsmuDataFlowMonthlyRollupRetentionFailures",
    "OsmuBackupCronJobFailed",
    "OsmuBackupCronJobStale"
)

$alertMatches = Get-Matches $thresholdTargetsContent '^\s*-\s+alert:\s+([A-Za-z0-9_]+)\s*$'
$targetAlerts = @($alertMatches | ForEach-Object { $_.Groups[1].Value })
$missingAlerts = @($requiredAlerts | Where-Object { $targetAlerts -notcontains $_ })
$routeMatches = Get-Matches $thresholdTargetsContent '^\s*-\s+route:\s+([A-Za-z0-9_-]+)\s*$'
$routes = @($routeMatches | ForEach-Object { $_.Groups[1].Value })
$grafanaPanelCount = (Get-Matches $thresholdTargetsContent '^\s*grafanaPanel:\s+(.+)$').Count
$tuningEvidenceCount = (Get-Matches $thresholdTargetsContent '^\s*tuningEvidence:\s+(.+)$').Count
$alertTargetCoverageComplete = $missingAlerts.Count -eq 0
$routeCoverageComplete = ($routes -contains "osmu-backend") -and ($routes -contains "osmu-data-flow") -and ($routes -contains "osmu-backup")
$grafanaPanelCoverageComplete = $grafanaPanelCount -ge $requiredAlerts.Count
$tuningEvidenceCoverageComplete = $tuningEvidenceCount -ge $requiredAlerts.Count
$thresholdMappingComplete = $alertTargetCoverageComplete -and $routeCoverageComplete -and $grafanaPanelCoverageComplete -and $tuningEvidenceCoverageComplete

$reviewStartedAtParsed = Get-ParsedDateText $ReviewStartedAt
$reviewCompletedAtParsed = Get-ParsedDateText $ReviewCompletedAt
$reviewWindowOrdered = $null -ne $reviewStartedAtParsed -and $null -ne $reviewCompletedAtParsed -and $reviewCompletedAtParsed -ge $reviewStartedAtParsed
$hasAnyInput = -not [string]::IsNullOrWhiteSpace($EnvironmentName + $TargetCluster + $Operator + $ReviewStartedAt + $ReviewCompletedAt + $ChangeApprovalRef + $PrometheusRulesEvidenceRef + $GrafanaDashboardEvidenceRef + $AlertmanagerRouteEvidenceRef + $TargetBaselineEvidenceRef + $IncidentRoutingEvidenceRef + $EvidenceRef) -or $ConfirmPrometheusRulesLoaded -or $ConfirmGrafanaDashboardImported -or $ConfirmAlertmanagerRoutesReviewed -or $ConfirmTargetBaselinesReviewed -or $ConfirmIncidentRoutingReviewed -or $ConfirmNoSecretValues

Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($Operator)) "operator=$Operator"
Add-Check "review-started-at" "Review start timestamp recorded" (Test-DateText $ReviewStartedAt) "reviewStartedAt=$ReviewStartedAt"
Add-Check "review-completed-at" "Review completion timestamp recorded" (Test-DateText $ReviewCompletedAt) "reviewCompletedAt=$ReviewCompletedAt"
Add-Check "review-window-order" "Review window order valid" $reviewWindowOrdered "reviewStartedAt=$ReviewStartedAt; reviewCompletedAt=$ReviewCompletedAt"
Add-Check "change-approval-ref" "Change approval reference recorded" (-not [string]::IsNullOrWhiteSpace($ChangeApprovalRef)) "changeApprovalRef=$ChangeApprovalRef"
Add-Check "threshold-targets-file-exists" "Threshold target contract exists" $thresholdTargetsExists "thresholdTargetsPath=$resolvedThresholdTargetsPath"
Add-Check "threshold-targets-format" "Threshold target format version recorded" ($thresholdTargetsContent.Contains("formatVersion: osmu.monitoring.threshold-targets.v1")) "formatVersion=osmu.monitoring.threshold-targets.v1"
Add-Check "threshold-alert-targets-complete" "Required alert targets mapped" $alertTargetCoverageComplete "required=$($requiredAlerts.Count); found=$($targetAlerts.Count); missing=$($missingAlerts -join ',')"
Add-Check "alertmanager-routes-mapped" "Alertmanager routes mapped" $routeCoverageComplete "routes=$($routes -join ',')"
Add-Check "grafana-panels-mapped" "Grafana panels mapped" $grafanaPanelCoverageComplete "grafanaPanelCount=$grafanaPanelCount"
Add-Check "target-tuning-evidence-fields" "Target tuning evidence fields mapped" $tuningEvidenceCoverageComplete "tuningEvidenceCount=$tuningEvidenceCount"
Add-Check "prometheus-rules-evidence-ref" "Prometheus rules evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($PrometheusRulesEvidenceRef)) "prometheusRulesEvidenceRef=$PrometheusRulesEvidenceRef"
Add-Check "grafana-dashboard-evidence-ref" "Grafana dashboard evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($GrafanaDashboardEvidenceRef)) "grafanaDashboardEvidenceRef=$GrafanaDashboardEvidenceRef"
Add-Check "alertmanager-route-evidence-ref" "Alertmanager route evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($AlertmanagerRouteEvidenceRef)) "alertmanagerRouteEvidenceRef=$AlertmanagerRouteEvidenceRef"
Add-Check "target-baseline-evidence-ref" "Target baseline evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($TargetBaselineEvidenceRef)) "targetBaselineEvidenceRef=$TargetBaselineEvidenceRef"
Add-Check "incident-routing-evidence-ref" "Incident routing evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($IncidentRoutingEvidenceRef)) "incidentRoutingEvidenceRef=$IncidentRoutingEvidenceRef"
Add-Check "prometheus-rules-loaded-confirmed" "Prometheus rules loaded confirmation" ([bool] $ConfirmPrometheusRulesLoaded) "Rules were loaded into target Prometheus or PrometheusRule."
Add-Check "grafana-dashboard-imported-confirmed" "Grafana dashboard imported confirmation" ([bool] $ConfirmGrafanaDashboardImported) "Dashboard was imported or provisioned in target Grafana."
Add-Check "alertmanager-routes-reviewed-confirmed" "Alertmanager routes reviewed confirmation" ([bool] $ConfirmAlertmanagerRoutesReviewed) "Routes and receivers were reviewed for target on-call ownership."
Add-Check "target-baselines-reviewed-confirmed" "Target baselines reviewed confirmation" ([bool] $ConfirmTargetBaselinesReviewed) "Threshold values were reviewed against target tenant baselines."
Add-Check "incident-routing-reviewed-confirmed" "Incident routing reviewed confirmation" ([bool] $ConfirmIncidentRoutingReviewed) "Escalation path and incident owner mapping were reviewed."
Add-Check "no-secret-values-confirmed" "No secret values recorded confirmation" ([bool] $ConfirmNoSecretValues) "Evidence stores references and booleans only."

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$result = if (-not $hasAnyInput) {
    "planned"
}
elseif ($failureCount -eq 0) {
    "passed"
}
else {
    "failed"
}

$generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$checkArray = @($checks | ForEach-Object { $_ })

$report = New-Object System.Collections.Specialized.OrderedDictionary
[void] $report.Add("formatVersion", "osmu.monitoring-threshold-evidence.v1")
[void] $report.Add("generatedAt", $generatedAt)
[void] $report.Add("result", $result)
[void] $report.Add("environmentName", $EnvironmentName)
[void] $report.Add("targetCluster", $TargetCluster)
[void] $report.Add("operatorName", $Operator)
[void] $report.Add("evidenceRef", $EvidenceRef)
[void] $report.Add("reviewWindow", [ordered]@{
    startedAt = $ReviewStartedAt
    completedAt = $ReviewCompletedAt
})
[void] $report.Add("thresholdTargetsPath", $ThresholdTargetsPath)
[void] $report.Add("thresholdTargetSummary", [ordered]@{
    requiredAlertCount = $requiredAlerts.Count
    mappedAlertCount = $targetAlerts.Count
    missingAlerts = [object] $missingAlerts
    routeCount = $routes.Count
    routes = [object] $routes
    grafanaPanelCount = $grafanaPanelCount
    tuningEvidenceCount = $tuningEvidenceCount
    alertTargetCoverageComplete = $alertTargetCoverageComplete
    routeCoverageComplete = $routeCoverageComplete
    grafanaPanelCoverageComplete = $grafanaPanelCoverageComplete
    tuningEvidenceCoverageComplete = $tuningEvidenceCoverageComplete
    thresholdMappingComplete = $thresholdMappingComplete
})
[void] $report.Add("evidenceRefs", [ordered]@{
    changeApproval = $ChangeApprovalRef
    prometheusRules = $PrometheusRulesEvidenceRef
    grafanaDashboard = $GrafanaDashboardEvidenceRef
    alertmanagerRoute = $AlertmanagerRouteEvidenceRef
    targetBaseline = $TargetBaselineEvidenceRef
    incidentRouting = $IncidentRoutingEvidenceRef
})
[void] $report.Add("confirmations", [ordered]@{
    prometheusRulesLoaded = [bool] $ConfirmPrometheusRulesLoaded
    grafanaDashboardImported = [bool] $ConfirmGrafanaDashboardImported
    alertmanagerRoutesReviewed = [bool] $ConfirmAlertmanagerRoutesReviewed
    targetBaselinesReviewed = [bool] $ConfirmTargetBaselinesReviewed
    incidentRoutingReviewed = [bool] $ConfirmIncidentRoutingReviewed
    noSecretValues = [bool] $ConfirmNoSecretValues
})
[void] $report.Add("summary", [ordered]@{
    failureCount = $failureCount
    checkCount = $checkArray.Count
})
[void] $report.Add("checks", [object] $checkArray)
[void] $report.Add("decisionRule", "Production/B2B monitoring readiness requires result=passed after the target Prometheus rules, Grafana dashboard, Alertmanager routes, incident routing, and tenant baseline threshold values are reviewed.")
[void] $report.Add("secretPolicy", "Evidence stores only environment labels, operator/change references, timestamps, booleans, target threshold metadata, and external evidence references; it does not contain passwords, bearer tokens, kubeconfig, private keys, webhook secrets, SMTP credentials, provider credentials, raw alert receiver secrets, or raw customer data.")

$markdownLines = @(
    "# OSMU Monitoring Threshold Evidence",
    "",
    "- Result: $result",
    "- Generated at: $generatedAt",
    "- Environment: $EnvironmentName",
    "- Target cluster: $TargetCluster",
    "- Operator: $Operator",
    "- Evidence ref: $EvidenceRef",
    "- Threshold target contract: $ThresholdTargetsPath",
    "- Required alert targets: $($requiredAlerts.Count)",
    "- Mapped alert targets: $($targetAlerts.Count)",
    "- Alertmanager routes: $($routes -join ', ')",
    "- Grafana panel mappings: $grafanaPanelCount",
    "- Threshold mapping complete: $thresholdMappingComplete",
    "- Tuning evidence mappings: $tuningEvidenceCount",
    "",
    "## Checks"
)

foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}

$markdownLines += @(
    "",
    "## Alertmanager Routes",
    "",
    "- osmu-backend: backend API errors and p95 latency",
    "- osmu-data-flow: data-flow failure/cancel/egress/bucket/retention signals",
    "- osmu-backup: backup CronJob failure and stale-success signals",
    "",
    "## Secret Policy",
    "",
    $report.secretPolicy,
    "",
    "## Next Command",
    "",
    "- Feed this evidence reference into operations handoff as ``-MonitoringEvidenceRef $EvidenceRef``.",
    "- Record passed target evidence: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-monitoring-threshold-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -ReviewStartedAt <iso-time> -ReviewCompletedAt <iso-time> -ChangeApprovalRef <change-id> -EvidenceRef <run-ref> -PrometheusRulesEvidenceRef <ref> -GrafanaDashboardEvidenceRef <ref> -AlertmanagerRouteEvidenceRef <ref> -TargetBaselineEvidenceRef <ref> -IncidentRoutingEvidenceRef <ref> -ConfirmPrometheusRulesLoaded -ConfirmGrafanaDashboardImported -ConfirmAlertmanagerRoutesReviewed -ConfirmTargetBaselinesReviewed -ConfirmIncidentRoutingReviewed -ConfirmNoSecretValues -FailIfNotPassed``"
)

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($resolvedJsonOutputPath)) | Out-Null
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($resolvedMarkdownOutputPath)) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 -LiteralPath $resolvedJsonOutputPath
    $markdownLines -join [Environment]::NewLine | Set-Content -Encoding UTF8 -LiteralPath $resolvedMarkdownOutputPath
}

if ($FailIfNotPassed -and $result -ne "passed") {
    $failedDetails = ($checks | Where-Object { $_.status -eq "FAIL" } | ForEach-Object { "$($_.id): $($_.detail)" }) -join "; "
    throw "Monitoring threshold evidence result is $result. $failedDetails"
}

Write-Host "Monitoring threshold evidence result: $result"
Write-Host "JSON: $resolvedJsonOutputPath"
Write-Host "Markdown: $resolvedMarkdownOutputPath"
