param(
    [string] $Namespace = "osmu",
    [string] $KubectlPath = "kubectl",
    [string] $ConfigMapName = "osmu-operations-reports",
    [string] $ReportPath = ".\.osmu-run\latest-operations-readiness-convergence.json",
    [string] $SyncEvidencePath = ".\.osmu-run\latest-kubernetes-operations-report-sync.json",
    [string] $DataFlowStoragePlanPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-operations-report-sync-live.json",
    [string] $ApiBase = "",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "",
    [string] $DashboardReadinessFixturePath = "",
    [ValidateRange(1, 120)]
    [int] $DashboardRetryCount = 6,
    [ValidateRange(0, 300)]
    [int] $DashboardRetryDelaySeconds = 10,
    [switch] $RunSyncServerDryRun,
    [switch] $RunSyncApply,
    [switch] $SkipSync,
    [switch] $SkipDashboardCheck,
    [switch] $SkipDataFlowStoragePlanDashboardCheck,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()
$failureCount = 0

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Limit-Text([string] $Text) {
    if ($null -eq $Text) {
        return ""
    }
    if ($Text.Length -le 4000) {
        return $Text
    }
    return $Text.Substring(0, 4000) + "`n...truncated..."
}

function Add-Check(
    [string] $Name,
    [bool] $Passed,
    [string] $Summary,
    [string] $Command = "",
    [int] $ExitCode = 0,
    [string] $Output = ""
) {
    $script:checks += [pscustomobject]@{
        name = $Name
        passed = $Passed
        summary = $Summary
        command = $Command
        exitCode = $ExitCode
        output = (Limit-Text $Output)
    }
    if (-not $Passed) {
        $script:failureCount += 1
    }
}

function Read-JsonFile([string] $PathValue, [string] $Label) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "$Label not found: $resolved"
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $resolved | ConvertFrom-Json
}

function Invoke-Json($Method, $Url, $Body = $null, $Token = $null) {
    $headers = @{}
    if ($Token) {
        $headers.Authorization = "Bearer $Token"
    }
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers
    }
    return Invoke-RestMethod `
        -Method $Method `
        -Uri $Url `
        -Headers $headers `
        -ContentType "application/json" `
        -Body ($Body | ConvertTo-Json -Depth 10)
}

function Get-ResponseData([object] $Response) {
    if ($null -eq $Response) {
        return $null
    }
    if ($Response.PSObject.Properties.Name -contains "data") {
        return $Response.data
    }
    return $Response
}

function Get-ObjectText([object] $Value) {
    if ($null -eq $Value) {
        return ""
    }
    return [string] $Value
}

function Get-ObjectInt([object] $Value) {
    if ($null -eq $Value -or "$Value" -eq "") {
        return 0
    }
    try {
        return [int] $Value
    }
    catch {
        return 0
    }
}

function Get-ObjectBool([object] $Value) {
    if ($null -eq $Value -or "$Value" -eq "") {
        return $false
    }
    if ($Value -is [bool]) {
        return [bool] $Value
    }
    return ([string] $Value).Equals("true", [System.StringComparison]::OrdinalIgnoreCase)
}

function New-SyncCommand([string] $Mode) {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "sync-kubernetes-operations-reports.ps1"),
        "-Namespace", $Namespace,
        "-KubectlPath", $KubectlPath,
        "-ConfigMapName", $ConfigMapName,
        "-ReportPath", $ReportPath,
        "-EvidencePath", $SyncEvidencePath
    )
    if ($Mode -eq "server-dry-run") {
        $arguments += "-ServerDryRunOnly"
    }
    elseif ($Mode -eq "apply") {
        $arguments += "-Apply"
    }
    return $arguments
}

function Test-DashboardDataMatchesExpected(
    [object] $Data,
    [string] $ExpectedResult,
    [string] $ExpectedConfigMapName,
    [string] $ExpectedConfigMapKey,
    [bool] $ShouldCheckDataFlowStoragePlan,
    [string] $ExpectedDataFlowStoragePlanResult,
    [string] $ExpectedDataFlowStoragePlanCandidateStore,
    [int] $ExpectedDataFlowStoragePlanPendingCount,
    [bool] $ShouldCheckDataFlowQueryPlanEvidence,
    [bool] $ExpectedDataFlowQueryPlanEvidenceProvided,
    [string] $ExpectedDataFlowQueryPlanEvidenceResult,
    [int] $ExpectedDataFlowQueryPlanEvidenceFailedCount
) {
    $details = @()
    if ($null -eq $Data) {
        return [pscustomobject]@{
            matched = $false
            summary = "Dashboard data is empty."
            details = @("dashboard data is empty")
        }
    }

    $convergence = $Data.operationsReadinessConvergence
    $reportSync = $Data.kubernetesOperationsReportSync
    $dataFlowStoragePlan = $Data.dataFlowStoragePlan
    if ($null -eq $convergence) {
        $details += "operationsReadinessConvergence missing"
    }
    else {
        if (-not ([bool] $convergence.kubernetesReportSyncReady)) {
            $details += "kubernetesReportSyncReady=$([bool] $convergence.kubernetesReportSyncReady)"
        }
        $convergenceResult = Get-ObjectText $convergence.kubernetesReportSyncResult
        if ($convergenceResult -ne $ExpectedResult) {
            $details += "convergence result=$convergenceResult expected=$ExpectedResult"
        }
    }

    if ($null -eq $reportSync) {
        $details += "kubernetesOperationsReportSync missing"
    }
    else {
        $reportSyncResult = Get-ObjectText $reportSync.result
        if ($reportSyncResult -ne $ExpectedResult) {
            $details += "sync result=$reportSyncResult expected=$ExpectedResult"
        }
        $reportSyncFailedCount = Get-ObjectInt $reportSync.failedCount
        if ($reportSyncFailedCount -ne 0) {
            $details += "sync failedCount=$reportSyncFailedCount"
        }
        if ($ExpectedConfigMapName) {
            $reportSyncConfigMapName = Get-ObjectText $reportSync.configMapName
            if ($reportSyncConfigMapName -ne $ExpectedConfigMapName) {
                $details += "sync configMapName=$reportSyncConfigMapName expected=$ExpectedConfigMapName"
            }
        }
        if ($ExpectedConfigMapKey) {
            $reportSyncConfigMapKey = Get-ObjectText $reportSync.configMapKey
            if ($reportSyncConfigMapKey -ne $ExpectedConfigMapKey) {
                $details += "sync configMapKey=$reportSyncConfigMapKey expected=$ExpectedConfigMapKey"
            }
        }
    }

    if ($ShouldCheckDataFlowStoragePlan) {
        if ($null -eq $dataFlowStoragePlan) {
            $details += "dataFlowStoragePlan missing"
        }
        else {
            $dataFlowStoragePlanResult = Get-ObjectText $dataFlowStoragePlan.result
            if ($dataFlowStoragePlanResult -ne $ExpectedDataFlowStoragePlanResult) {
                $details += "data-flow storage plan result=$dataFlowStoragePlanResult expected=$ExpectedDataFlowStoragePlanResult"
            }
            $dataFlowStoragePlanCandidateStore = Get-ObjectText $dataFlowStoragePlan.candidateStore
            if ($ExpectedDataFlowStoragePlanCandidateStore -and $dataFlowStoragePlanCandidateStore -ne $ExpectedDataFlowStoragePlanCandidateStore) {
                $details += "data-flow storage plan candidateStore=$dataFlowStoragePlanCandidateStore expected=$ExpectedDataFlowStoragePlanCandidateStore"
            }
            $dataFlowStoragePlanPendingCount = Get-ObjectInt $dataFlowStoragePlan.pendingCount
            if ($dataFlowStoragePlanPendingCount -ne $ExpectedDataFlowStoragePlanPendingCount) {
                $details += "data-flow storage plan pendingCount=$dataFlowStoragePlanPendingCount expected=$ExpectedDataFlowStoragePlanPendingCount"
            }
            if ($ShouldCheckDataFlowQueryPlanEvidence) {
                $queryPlanEvidence = $dataFlowStoragePlan.queryPlanEvidence
                if ($null -eq $queryPlanEvidence) {
                    $details += "data-flow query plan evidence missing"
                }
                else {
                    $queryPlanProvided = Get-ObjectBool $queryPlanEvidence.provided
                    if ($queryPlanProvided -ne $ExpectedDataFlowQueryPlanEvidenceProvided) {
                        $details += "data-flow query plan provided=$queryPlanProvided expected=$ExpectedDataFlowQueryPlanEvidenceProvided"
                    }
                    $queryPlanResult = Get-ObjectText $queryPlanEvidence.result
                    if ($queryPlanResult -ne $ExpectedDataFlowQueryPlanEvidenceResult) {
                        $details += "data-flow query plan result=$queryPlanResult expected=$ExpectedDataFlowQueryPlanEvidenceResult"
                    }
                    $queryPlanFailedCount = Get-ObjectInt $queryPlanEvidence.failedCount
                    if ($queryPlanFailedCount -ne $ExpectedDataFlowQueryPlanEvidenceFailedCount) {
                        $details += "data-flow query plan failedCount=$queryPlanFailedCount expected=$ExpectedDataFlowQueryPlanEvidenceFailedCount"
                    }
                }
            }
        }

        if ($ExpectedDataFlowStoragePlanResult -and $ExpectedDataFlowStoragePlanResult -ne "passed") {
            $hasDataFlowStoragePlanItem = @($Data.items | Where-Object { (Get-ObjectText $_.code) -eq "DATA_FLOW_STORAGE_PLAN" }).Count -gt 0
            if (-not $hasDataFlowStoragePlanItem) {
                $details += "DATA_FLOW_STORAGE_PLAN readiness item missing"
            }
        }
    }

    if (@($details).Count -eq 0) {
        return [pscustomobject]@{
            matched = $true
            summary = "Dashboard readiness reflects expected Kubernetes report sync and data-flow storage plan state."
            details = @()
        }
    }
    return [pscustomobject]@{
        matched = $false
        summary = "Dashboard readiness does not yet reflect expected Kubernetes report sync and data-flow storage plan state."
        details = $details
    }
}

$selectedSyncModeCount = 0
foreach ($mode in @($RunSyncServerDryRun.IsPresent, $RunSyncApply.IsPresent, $SkipSync.IsPresent)) {
    if ($mode) {
        $selectedSyncModeCount += 1
    }
}
if ($selectedSyncModeCount -gt 1) {
    throw "Use only one sync mode: -RunSyncServerDryRun, -RunSyncApply, or -SkipSync."
}
if ($PlanOnly -and ($RunSyncServerDryRun -or $RunSyncApply)) {
    throw "Do not combine -PlanOnly with -RunSyncServerDryRun or -RunSyncApply."
}

$resolvedReportPath = Resolve-ProjectPath $ReportPath
$resolvedSyncEvidencePath = Resolve-ProjectPath $SyncEvidencePath
$resolvedDataFlowStoragePlanPath = Resolve-ProjectPath $DataFlowStoragePlanPath
$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$resolvedDashboardFixturePath = if ($DashboardReadinessFixturePath) { Resolve-ProjectPath $DashboardReadinessFixturePath } else { "" }
$dashboardCheckRequested = [bool]((-not $SkipDashboardCheck) -and ($ApiBase -or $DashboardReadinessFixturePath))
$shouldCheckDataFlowStoragePlanDashboard = [bool]((-not $SkipDataFlowStoragePlanDashboardCheck) -and (Test-Path -LiteralPath $resolvedDataFlowStoragePlanPath))

if ($PlanOnly) {
    Add-Check "plan-only" $true "Plan-only mode does not call kubectl or the dashboard API."
}
elseif ($RunSyncServerDryRun -or $RunSyncApply) {
    $syncMode = if ($RunSyncApply) { "apply" } else { "server-dry-run" }
    $syncArguments = New-SyncCommand $syncMode
    $syncCommand = "powershell " + ($syncArguments -join " ")
    $syncOutputLines = & powershell @syncArguments 2>&1
    $syncExitCode = $LASTEXITCODE
    $syncOutput = ($syncOutputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    Add-Check "run-sync-$syncMode" ($syncExitCode -eq 0) "Ran Kubernetes operations report sync in $syncMode mode." $syncCommand $syncExitCode $syncOutput
}
elseif (-not $SkipSync) {
    Add-Check "reuse-sync-evidence" $true "Using existing Kubernetes operations report sync evidence."
}
else {
    Add-Check "skip-sync" $true "Sync execution was skipped; validating supplied sync/dashboard evidence only."
}

$syncEvidence = $null
if (-not $PlanOnly) {
    if (-not (Test-Path -LiteralPath $resolvedSyncEvidencePath)) {
        Add-Check "sync-evidence-exists" $false "Sync evidence file is missing: $resolvedSyncEvidencePath"
    }
    else {
        try {
            $syncEvidence = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedSyncEvidencePath | ConvertFrom-Json
            Add-Check "sync-evidence-valid-json" $true "Sync evidence file is valid JSON."
        }
        catch {
            Add-Check "sync-evidence-valid-json" $false "Sync evidence JSON is invalid: $($_.Exception.Message)"
        }
    }
}

$dataFlowStoragePlanEvidence = $null
$expectedDataFlowStoragePlanResult = ""
$expectedDataFlowStoragePlanCandidateStore = ""
$expectedDataFlowStoragePlanPendingCount = 0
$expectedDataFlowQueryPlanEvidence = $false
$expectedDataFlowQueryPlanEvidenceProvided = $false
$expectedDataFlowQueryPlanEvidenceResult = ""
$expectedDataFlowQueryPlanEvidenceFailedCount = 0
if ($SkipDataFlowStoragePlanDashboardCheck) {
    Add-Check "data-flow-storage-plan-dashboard-skipped" $true "Dashboard data-flow storage plan check skipped by parameter."
}
elseif ($shouldCheckDataFlowStoragePlanDashboard) {
    try {
        $dataFlowStoragePlanEvidence = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedDataFlowStoragePlanPath | ConvertFrom-Json
        $expectedDataFlowStoragePlanResult = Get-ObjectText $dataFlowStoragePlanEvidence.result
        $expectedDataFlowStoragePlanCandidateStore = Get-ObjectText $dataFlowStoragePlanEvidence.candidateStore
        $expectedDataFlowStoragePlanPendingCount = Get-ObjectInt $dataFlowStoragePlanEvidence.pendingCount
        $queryPlanEvidence = $dataFlowStoragePlanEvidence.queryPlanEvidence
        if ($null -ne $queryPlanEvidence) {
            $expectedDataFlowQueryPlanEvidence = $true
            $expectedDataFlowQueryPlanEvidenceProvided = Get-ObjectBool $queryPlanEvidence.provided
            $expectedDataFlowQueryPlanEvidenceResult = Get-ObjectText $queryPlanEvidence.result
            $expectedDataFlowQueryPlanEvidenceFailedCount = Get-ObjectInt $queryPlanEvidence.failedCount
        }
        Add-Check "data-flow-storage-plan-valid-json" $true "Local data-flow storage plan evidence is valid JSON."
        Add-Check "data-flow-storage-plan-format-version" ((Get-ObjectText $dataFlowStoragePlanEvidence.formatVersion) -eq "osmu.data-flow-storage-plan.v1") "Data-flow storage plan formatVersion=$(Get-ObjectText $dataFlowStoragePlanEvidence.formatVersion)."
        if ($expectedDataFlowQueryPlanEvidence) {
            Add-Check "data-flow-query-plan-evidence-summary" $true "Local data-flow storage plan includes query plan evidence summary result=$expectedDataFlowQueryPlanEvidenceResult, provided=$expectedDataFlowQueryPlanEvidenceProvided, failed=$expectedDataFlowQueryPlanEvidenceFailedCount."
        }
        if ($PlanOnly) {
            Add-Check "data-flow-storage-plan-dashboard-plan" $true "Dashboard data-flow storage plan check planned from local evidence."
        }
    }
    catch {
        Add-Check "data-flow-storage-plan-valid-json" $false "Data-flow storage plan JSON is invalid: $($_.Exception.Message)"
    }
}
else {
    Add-Check "data-flow-storage-plan-dashboard-optional" $true "Local data-flow storage plan evidence is absent; dashboard data-flow plan check is optional."
}
$dataFlowStoragePlanDashboardExpected = [bool]($shouldCheckDataFlowStoragePlanDashboard -and $null -ne $dataFlowStoragePlanEvidence)

$expectedSyncResult = if ($RunSyncServerDryRun) { "server-dry-run-passed" } else { "applied" }
$syncResult = ""
$syncFailedCount = 0
$syncConfigMapName = ""
$syncConfigMapKey = ""
if ($null -ne $syncEvidence) {
    $syncResult = Get-ObjectText $syncEvidence.result
    $syncFailedCount = Get-ObjectInt $syncEvidence.failedCount
    $syncConfigMapName = Get-ObjectText $syncEvidence.configMapName
    $syncConfigMapKey = Get-ObjectText $syncEvidence.configMapKey
    Add-Check "sync-evidence-result" ($syncResult -eq $expectedSyncResult) "Sync evidence result=$syncResult, expected=$expectedSyncResult."
    Add-Check "sync-evidence-failed-count" ($syncFailedCount -eq 0) "Sync evidence failedCount=$syncFailedCount."
    Add-Check "sync-evidence-configmap" ($syncConfigMapName -eq $ConfigMapName) "Sync evidence configMapName=$syncConfigMapName."
}

$dashboardData = $null
$dashboardSource = ""
$tokenReceived = $false
$dashboardAttemptCount = 0
$dashboardMatchedExpected = $false
$dashboardPollingOutput = ""
if ($PlanOnly) {
    if ($dashboardCheckRequested) {
        Add-Check "dashboard-plan" $true "Dashboard check planned but not executed."
    }
}
elseif ($dashboardCheckRequested) {
    if ($DashboardReadinessFixturePath) {
        try {
            $dashboardData = Get-ResponseData (Read-JsonFile $resolvedDashboardFixturePath "Dashboard readiness fixture")
            $dashboardSource = $resolvedDashboardFixturePath
            $dashboardAttemptCount = 1
            $dashboardMatch = Test-DashboardDataMatchesExpected $dashboardData $expectedSyncResult $syncConfigMapName $syncConfigMapKey $dataFlowStoragePlanDashboardExpected $expectedDataFlowStoragePlanResult $expectedDataFlowStoragePlanCandidateStore $expectedDataFlowStoragePlanPendingCount $expectedDataFlowQueryPlanEvidence $expectedDataFlowQueryPlanEvidenceProvided $expectedDataFlowQueryPlanEvidenceResult $expectedDataFlowQueryPlanEvidenceFailedCount
            $dashboardMatchedExpected = [bool] $dashboardMatch.matched
            Add-Check "dashboard-fixture" $true "Loaded dashboard readiness fixture."
        }
        catch {
            Add-Check "dashboard-fixture" $false $_.Exception.Message
        }
    }
    else {
        if (-not $AdminPassword) {
            Add-Check "dashboard-admin-login" $false "Admin password is required when -ApiBase is used."
        }
        else {
            try {
                $login = Invoke-Json "POST" "$ApiBase/auth/login" @{
                    loginId = $AdminLoginId
                    password = $AdminPassword
                }
                $token = $login.data.accessToken
                if (-not $token) {
                    Add-Check "dashboard-admin-login" $false "Login response did not include accessToken."
                }
                else {
                    $tokenReceived = $true
                    Add-Check "dashboard-admin-login" $true "Admin login returned an access token." "POST $ApiBase/auth/login loginId=$AdminLoginId password=<secret>"
                    $dashboardSource = "$ApiBase/admin/dashboard/readiness"
                    $attemptSummaries = @()
                    for ($attempt = 1; $attempt -le $DashboardRetryCount; $attempt += 1) {
                        $dashboardAttemptCount = $attempt
                        try {
                            $dashboard = Invoke-Json "GET" "$ApiBase/admin/dashboard/readiness" $null $token
                            $dashboardData = Get-ResponseData $dashboard
                            $dashboardMatch = Test-DashboardDataMatchesExpected $dashboardData $expectedSyncResult $syncConfigMapName $syncConfigMapKey $dataFlowStoragePlanDashboardExpected $expectedDataFlowStoragePlanResult $expectedDataFlowStoragePlanCandidateStore $expectedDataFlowStoragePlanPendingCount $expectedDataFlowQueryPlanEvidence $expectedDataFlowQueryPlanEvidenceProvided $expectedDataFlowQueryPlanEvidenceResult $expectedDataFlowQueryPlanEvidenceFailedCount
                            $dashboardMatchedExpected = [bool] $dashboardMatch.matched
                            $attemptSummaries += "attempt $attempt/$DashboardRetryCount`: $($dashboardMatch.summary) $(@($dashboardMatch.details) -join '; ')".Trim()
                            if ($dashboardMatchedExpected) {
                                break
                            }
                        }
                        catch {
                            $attemptSummaries += "attempt $attempt/$DashboardRetryCount`: request failed: $($_.Exception.Message)"
                        }
                        if ($attempt -lt $DashboardRetryCount -and $DashboardRetryDelaySeconds -gt 0) {
                            Start-Sleep -Seconds $DashboardRetryDelaySeconds
                        }
                    }
                    $dashboardPollingOutput = ($attemptSummaries -join [Environment]::NewLine)
                    Add-Check "dashboard-readiness-api" ($null -ne $dashboardData) "Dashboard readiness API polling completed after $dashboardAttemptCount attempt(s)." "GET $ApiBase/admin/dashboard/readiness" 0 $dashboardPollingOutput
                    Add-Check "dashboard-readiness-poll" $dashboardMatchedExpected "Dashboard readiness matched expected sync state after $dashboardAttemptCount attempt(s)." "GET $ApiBase/admin/dashboard/readiness" 0 $dashboardPollingOutput
                }
            }
            catch {
                Add-Check "dashboard-readiness-api" $false $_.Exception.Message
            }
        }
    }
}
else {
    Add-Check "dashboard-check-skipped" $true "Dashboard check skipped because no -ApiBase or fixture was supplied."
}

$dashboardConvergenceResult = ""
$dashboardSyncReady = $false
$dashboardSyncResult = ""
$dashboardSyncFailedCount = 0
$dashboardSyncConfigMapName = ""
$dashboardSyncConfigMapKey = ""
$dashboardDataFlowStoragePlanResult = ""
$dashboardDataFlowStoragePlanCandidateStore = ""
$dashboardDataFlowStoragePlanPendingCount = 0
$dashboardDataFlowStoragePlanItemPresent = $false
$dashboardDataFlowQueryPlanEvidenceProvided = $false
$dashboardDataFlowQueryPlanEvidenceResult = ""
$dashboardDataFlowQueryPlanEvidenceFailedCount = 0
if ($null -ne $dashboardData) {
    $convergence = $dashboardData.operationsReadinessConvergence
    $reportSync = $dashboardData.kubernetesOperationsReportSync
    if ($null -eq $convergence) {
        Add-Check "dashboard-convergence-present" $false "operationsReadinessConvergence is missing from dashboard readiness response."
    }
    else {
        $dashboardConvergenceResult = Get-ObjectText $convergence.result
        $dashboardSyncReady = [bool] $convergence.kubernetesReportSyncReady
        Add-Check "dashboard-convergence-present" $true "operationsReadinessConvergence is present."
        Add-Check "dashboard-convergence-sync-ready" $dashboardSyncReady "Dashboard convergence kubernetesReportSyncReady=$dashboardSyncReady."
        Add-Check "dashboard-convergence-sync-result" ((Get-ObjectText $convergence.kubernetesReportSyncResult) -eq $expectedSyncResult) "Dashboard convergence kubernetesReportSyncResult=$(Get-ObjectText $convergence.kubernetesReportSyncResult), expected=$expectedSyncResult."
    }
    if ($null -eq $reportSync) {
        Add-Check "dashboard-sync-evidence-present" $false "kubernetesOperationsReportSync is missing from dashboard readiness response."
    }
    else {
        $dashboardSyncResult = Get-ObjectText $reportSync.result
        $dashboardSyncFailedCount = Get-ObjectInt $reportSync.failedCount
        $dashboardSyncConfigMapName = Get-ObjectText $reportSync.configMapName
        $dashboardSyncConfigMapKey = Get-ObjectText $reportSync.configMapKey
        Add-Check "dashboard-sync-evidence-present" $true "kubernetesOperationsReportSync is present."
        Add-Check "dashboard-sync-evidence-result" ($dashboardSyncResult -eq $expectedSyncResult) "Dashboard sync evidence result=$dashboardSyncResult, expected=$expectedSyncResult."
        Add-Check "dashboard-sync-evidence-failed-count" ($dashboardSyncFailedCount -eq 0) "Dashboard sync evidence failedCount=$dashboardSyncFailedCount."
        if ($syncConfigMapName) {
            Add-Check "dashboard-sync-configmap-name" ($dashboardSyncConfigMapName -eq $syncConfigMapName) "Dashboard sync configMapName=$dashboardSyncConfigMapName."
        }
        if ($syncConfigMapKey) {
            Add-Check "dashboard-sync-configmap-key" ($dashboardSyncConfigMapKey -eq $syncConfigMapKey) "Dashboard sync configMapKey=$dashboardSyncConfigMapKey."
        }
    }

    if ($dataFlowStoragePlanDashboardExpected) {
        $dashboardDataFlowStoragePlan = $dashboardData.dataFlowStoragePlan
        $dashboardDataFlowStoragePlanItemPresent = @($dashboardData.items | Where-Object { (Get-ObjectText $_.code) -eq "DATA_FLOW_STORAGE_PLAN" }).Count -gt 0
        if ($null -eq $dashboardDataFlowStoragePlan) {
            Add-Check "dashboard-data-flow-storage-plan-present" $false "dataFlowStoragePlan is missing from dashboard readiness response."
        }
        else {
            $dashboardDataFlowStoragePlanResult = Get-ObjectText $dashboardDataFlowStoragePlan.result
            $dashboardDataFlowStoragePlanCandidateStore = Get-ObjectText $dashboardDataFlowStoragePlan.candidateStore
            $dashboardDataFlowStoragePlanPendingCount = Get-ObjectInt $dashboardDataFlowStoragePlan.pendingCount
            Add-Check "dashboard-data-flow-storage-plan-present" $true "dataFlowStoragePlan is present."
            Add-Check "dashboard-data-flow-storage-plan-result" ($dashboardDataFlowStoragePlanResult -eq $expectedDataFlowStoragePlanResult) "Dashboard data-flow storage plan result=$dashboardDataFlowStoragePlanResult, expected=$expectedDataFlowStoragePlanResult."
            if ($expectedDataFlowStoragePlanCandidateStore) {
                Add-Check "dashboard-data-flow-storage-plan-candidate-store" ($dashboardDataFlowStoragePlanCandidateStore -eq $expectedDataFlowStoragePlanCandidateStore) "Dashboard data-flow storage plan candidateStore=$dashboardDataFlowStoragePlanCandidateStore, expected=$expectedDataFlowStoragePlanCandidateStore."
            }
            Add-Check "dashboard-data-flow-storage-plan-pending-count" ($dashboardDataFlowStoragePlanPendingCount -eq $expectedDataFlowStoragePlanPendingCount) "Dashboard data-flow storage plan pendingCount=$dashboardDataFlowStoragePlanPendingCount, expected=$expectedDataFlowStoragePlanPendingCount."
            if ($expectedDataFlowQueryPlanEvidence) {
                $dashboardDataFlowQueryPlanEvidence = $dashboardDataFlowStoragePlan.queryPlanEvidence
                if ($null -eq $dashboardDataFlowQueryPlanEvidence) {
                    Add-Check "dashboard-data-flow-query-plan-evidence-present" $false "dataFlowStoragePlan.queryPlanEvidence is missing from dashboard readiness response."
                }
                else {
                    $dashboardDataFlowQueryPlanEvidenceProvided = Get-ObjectBool $dashboardDataFlowQueryPlanEvidence.provided
                    $dashboardDataFlowQueryPlanEvidenceResult = Get-ObjectText $dashboardDataFlowQueryPlanEvidence.result
                    $dashboardDataFlowQueryPlanEvidenceFailedCount = Get-ObjectInt $dashboardDataFlowQueryPlanEvidence.failedCount
                    Add-Check "dashboard-data-flow-query-plan-evidence-present" $true "dataFlowStoragePlan.queryPlanEvidence is present."
                    Add-Check "dashboard-data-flow-query-plan-evidence-provided" ($dashboardDataFlowQueryPlanEvidenceProvided -eq $expectedDataFlowQueryPlanEvidenceProvided) "Dashboard query plan evidence provided=$dashboardDataFlowQueryPlanEvidenceProvided, expected=$expectedDataFlowQueryPlanEvidenceProvided."
                    Add-Check "dashboard-data-flow-query-plan-evidence-result" ($dashboardDataFlowQueryPlanEvidenceResult -eq $expectedDataFlowQueryPlanEvidenceResult) "Dashboard query plan evidence result=$dashboardDataFlowQueryPlanEvidenceResult, expected=$expectedDataFlowQueryPlanEvidenceResult."
                    Add-Check "dashboard-data-flow-query-plan-evidence-failed-count" ($dashboardDataFlowQueryPlanEvidenceFailedCount -eq $expectedDataFlowQueryPlanEvidenceFailedCount) "Dashboard query plan evidence failedCount=$dashboardDataFlowQueryPlanEvidenceFailedCount, expected=$expectedDataFlowQueryPlanEvidenceFailedCount."
                }
            }
            if ($expectedDataFlowStoragePlanResult -ne "passed") {
                Add-Check "dashboard-data-flow-storage-plan-item" $dashboardDataFlowStoragePlanItemPresent "Dashboard DATA_FLOW_STORAGE_PLAN readiness item present=$dashboardDataFlowStoragePlanItemPresent."
            }
        }
    }
}

$result = if ($failureCount -eq 0) {
    if ($PlanOnly) { "planned" } elseif ($RunSyncServerDryRun) { "server-dry-run-passed" } else { "passed" }
}
else {
    "failed"
}

$report = [ordered]@{
    formatVersion = "osmu.kubernetes-operations-report-sync-live.v1"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    result = $result
    namespace = $Namespace
    configMapName = $ConfigMapName
    sourceReportPath = $resolvedReportPath
    syncEvidencePath = $resolvedSyncEvidencePath
    dataFlowStoragePlanPath = $resolvedDataFlowStoragePlanPath
    dataFlowStoragePlanExpected = [bool] $dataFlowStoragePlanDashboardExpected
    dataFlowStoragePlanExpectedResult = $expectedDataFlowStoragePlanResult
    dataFlowStoragePlanExpectedCandidateStore = $expectedDataFlowStoragePlanCandidateStore
    dataFlowStoragePlanExpectedPendingCount = $expectedDataFlowStoragePlanPendingCount
    dataFlowQueryPlanEvidenceExpected = [bool] $expectedDataFlowQueryPlanEvidence
    dataFlowQueryPlanEvidenceExpectedProvided = [bool] $expectedDataFlowQueryPlanEvidenceProvided
    dataFlowQueryPlanEvidenceExpectedResult = $expectedDataFlowQueryPlanEvidenceResult
    dataFlowQueryPlanEvidenceExpectedFailedCount = $expectedDataFlowQueryPlanEvidenceFailedCount
    syncResult = $syncResult
    syncFailedCount = $syncFailedCount
    syncConfigMapName = $syncConfigMapName
    syncConfigMapKey = $syncConfigMapKey
    dashboardChecked = [bool] $dashboardCheckRequested
    dashboardSource = $dashboardSource
    dashboardTokenReceived = [bool] $tokenReceived
    dashboardRetryCount = $DashboardRetryCount
    dashboardRetryDelaySeconds = $DashboardRetryDelaySeconds
    dashboardAttemptCount = $dashboardAttemptCount
    dashboardMatchedExpected = [bool] $dashboardMatchedExpected
    dashboardPollingOutput = (Limit-Text $dashboardPollingOutput)
    dashboardConvergenceResult = $dashboardConvergenceResult
    dashboardSyncReady = [bool] $dashboardSyncReady
    dashboardSyncResult = $dashboardSyncResult
    dashboardSyncFailedCount = $dashboardSyncFailedCount
    dashboardSyncConfigMapName = $dashboardSyncConfigMapName
    dashboardSyncConfigMapKey = $dashboardSyncConfigMapKey
    dashboardDataFlowStoragePlanChecked = [bool]($dataFlowStoragePlanDashboardExpected -and $null -ne $dashboardData)
    dashboardDataFlowStoragePlanResult = $dashboardDataFlowStoragePlanResult
    dashboardDataFlowStoragePlanCandidateStore = $dashboardDataFlowStoragePlanCandidateStore
    dashboardDataFlowStoragePlanPendingCount = $dashboardDataFlowStoragePlanPendingCount
    dashboardDataFlowStoragePlanItemPresent = [bool] $dashboardDataFlowStoragePlanItemPresent
    dashboardDataFlowQueryPlanEvidenceProvided = [bool] $dashboardDataFlowQueryPlanEvidenceProvided
    dashboardDataFlowQueryPlanEvidenceResult = $dashboardDataFlowQueryPlanEvidenceResult
    dashboardDataFlowQueryPlanEvidenceFailedCount = $dashboardDataFlowQueryPlanEvidenceFailedCount
    checkCount = @($checks).Count
    failedCount = $failureCount
    checks = $checks
    safetyPolicy = "This verifier writes to Kubernetes only when -RunSyncApply is supplied. It does not store admin passwords or bearer tokens in evidence output."
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedEvidencePath) | Out-Null
$report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

Write-Host "Kubernetes operations report sync live verification evidence: $resolvedEvidencePath"
Write-Host "Result: $result"
$report | ConvertTo-Json -Depth 14

if ($failureCount -gt 0) {
    exit 1
}
