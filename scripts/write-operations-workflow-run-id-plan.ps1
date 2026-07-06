param(
    [string] $InvocationReportPath = ".\.osmu-run\latest-operations-evidence-plan-invocation.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-workflow-run-ids.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-workflow-run-ids.md",
    [string] $GitHubRepository = "",
    [string] $RunListJsonDirectory = "",
    [string] $Branch = "",
    [int] $Limit = 20,
    [string] $ImageSigningVersion = "v0.1.0-rc.1",
    [string] $CommitSha = "",
    [switch] $UseGitHubApi,
    [string] $GitHubApiBaseUrl = "https://api.github.com",
    [switch] $Execute,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$jsonFields = "databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle"
$script:GitHubApiRunListErrors = @{}

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    $resolvedPath = Resolve-ProjectPath $PathValue
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

function Get-ManualEvidenceWorkflowName([string] $Command) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return ""
    }
    if ($Command.Contains("write-storage-backend-telemetry-evidence.ps1")) {
        return "manual-storage-backend-telemetry-evidence.yml"
    }
    if ($Command.Contains("verify-minio-bucket-cors.ps1")) {
        return "manual-minio-bucket-cors-verification.yml"
    }
    if ($Command.Contains("write-monitoring-threshold-evidence.ps1")) {
        return "manual-monitoring-threshold-evidence.yml"
    }
    if ($Command.Contains("write-secret-rotation-evidence.ps1")) {
        return "manual-secret-rotation-evidence.yml"
    }
    if ($Command.Contains("write-cluster-network-access-review-evidence.ps1")) {
        return "manual-cluster-network-access-review-evidence.yml"
    }
    if ($Command.Contains("write-helm-values-hardening-evidence.ps1")) {
        return "manual-helm-values-hardening-evidence.yml"
    }
    if ($Command.Contains("write-support-escalation-handoff-evidence.ps1")) {
        return "manual-support-escalation-handoff-evidence.yml"
    }
    if ($Command.Contains("write-commercial-integration-evidence.ps1")) {
        return "manual-commercial-integration-evidence.yml"
    }
    if ($Command.Contains("write-commercial-approval-evidence.ps1")) {
        return "manual-commercial-approval-evidence.yml"
    }
    if ($Command.Contains("write-chargeback-closeout-evidence.ps1")) {
        return "manual-chargeback-closeout-evidence.yml"
    }
    if ($Command.Contains("write-enterprise-auth-jit-rollback-evidence.ps1")) {
        return "manual-enterprise-auth-jit-rollback-evidence.yml"
    }
    if ($Command.Contains("write-operations-handoff-package.ps1")) {
        return "manual-operations-handoff-package.yml"
    }
    if ($Command.Contains("write-data-flow-storage-plan.ps1")) {
        return "manual-data-flow-storage-plan-evidence.yml"
    }
    if ($Command.Contains("write-data-flow-query-retention-budget-evidence.ps1")) {
        return "manual-data-flow-query-retention-budget-evidence.yml"
    }
    if ($Command.Contains("write-data-flow-storage-transition-runbook-evidence.ps1")) {
        return "manual-data-flow-storage-transition-runbook-evidence.yml"
    }
    return ""
}

function Normalize-GitHubRepositorySlug([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }
    $trimmed = $Value.Trim()
    if ($trimmed -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        if ($trimmed.EndsWith(".git", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $trimmed.Substring(0, $trimmed.Length - 4)
        }
        return $trimmed
    }
    if ($trimmed -match '^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?/?$') {
        return $matches[1]
    }
    if ($trimmed -match '^git@github\.com:([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?$') {
        return $matches[1]
    }
    return ""
}

function Resolve-GitHubRepositorySlug([string] $ExplicitRepository) {
    $explicit = Normalize-GitHubRepositorySlug $ExplicitRepository
    if (-not [string]::IsNullOrWhiteSpace($explicit)) {
        return $explicit
    }
    $environmentRepository = Normalize-GitHubRepositorySlug $env:GITHUB_REPOSITORY
    if (-not [string]::IsNullOrWhiteSpace($environmentRepository)) {
        return $environmentRepository
    }
    try {
        $remote = git -C $root config --get remote.origin.url 2>$null
        return Normalize-GitHubRepositorySlug ([string] $remote)
    }
    catch {
        return ""
    }
}

function Get-GitHubWorkflowRunsUrl([string] $RepositorySlug, [string] $WorkflowName) {
    if ([string]::IsNullOrWhiteSpace($RepositorySlug) -or [string]::IsNullOrWhiteSpace($WorkflowName)) {
        return ""
    }
    return "https://github.com/$RepositorySlug/actions/workflows/$WorkflowName"
}

function Add-UniqueString([System.Collections.Generic.List[string]] $List, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    if (-not $List.Contains($Value)) {
        $List.Add($Value) | Out-Null
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
function Add-UniqueWorkflow([System.Collections.Generic.List[string]] $Workflows, [string] $Workflow) {
    if ([string]::IsNullOrWhiteSpace($Workflow)) {
        return
    }
    if (-not $Workflows.Contains($Workflow)) {
        $Workflows.Add($Workflow) | Out-Null
    }
}

function Get-CurrentBranch {
    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
        return $Branch
    }
    try {
        $value = (& git -C $root rev-parse --abbrev-ref HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($value)) {
            return [string] $value
        }
    }
    catch {
    }
    return "main"
}

function Get-CurrentCommitSha {
    if (-not [string]::IsNullOrWhiteSpace($CommitSha)) {
        return $CommitSha
    }
    try {
        $value = (& git -C $root rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($value)) {
            return [string] $value
        }
    }
    catch {
    }
    return "<commit-sha>"
}

function New-WorkflowMetadata([string] $Workflow) {
    $metadata = @{
        "storage-expansion-finalizer-ci.yml" = [ordered]@{
            group = "storage-expansion"
            runIdParameter = "StorageExpansionRunId"
            artifactNameTemplate = "storage-expansion-finalizer-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import."
        }
        "kubernetes-ha-dr-readiness-ci.yml" = [ordered]@{
            group = "ha-dr-readiness"
            runIdParameter = "HaDrReadinessRunId"
            artifactNameTemplate = "kubernetes-ha-dr-readiness-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import."
        }
        "kubernetes-dr-finalizer-ci.yml" = [ordered]@{
            group = "kubernetes-dr"
            runIdParameter = "KubernetesDrRunId"
            artifactNameTemplate = "kubernetes-dr-finalizer-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import."
        }
        "iam-rbac-finalizer-ci.yml" = [ordered]@{
            group = "iam-rbac"
            runIdParameter = "IamRbacRunId"
            artifactNameTemplate = "iam-rbac-finalizer-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when IAM/RBAC evidence is part of the invocation."
        }
        "image-publish-sign-ci.yml" = [ordered]@{
            group = "image-signing-source"
            runIdParameter = "ImageSigningRunId"
            artifactNameTemplate = "osmu-image-signing-{version}-{commitSha}"
            requiredForReadiness = $false
            note = "Source artifact for security-evidence-finalizer-ci.yml."
        }
        "container-security-ci.yml" = [ordered]@{
            group = "container-security-source"
            runIdParameter = "ContainerSecurityRunId"
            artifactNameTemplate = "osmu-container-security-{commitSha}"
            requiredForReadiness = $false
            note = "Source artifact for security-evidence-finalizer-ci.yml."
        }
        "security-evidence-finalizer-ci.yml" = [ordered]@{
            group = "security-evidence"
            runIdParameter = "SecurityEvidenceRunId"
            artifactNameTemplate = "security-evidence-finalizer-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import."
        }
        "manual-storage-backend-telemetry-evidence.yml" = [ordered]@{
            group = "storage-backend-telemetry"
            runIdParameter = "StorageBackendTelemetryRunId"
            artifactNameTemplate = "storage-backend-telemetry-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target MinIO admin info telemetry evidence is part of the invocation."
        }
        "manual-minio-bucket-cors-verification.yml" = [ordered]@{
            group = "minio-bucket-cors"
            runIdParameter = "MinioBucketCorsRunId"
            artifactNameTemplate = "minio-bucket-cors-verification-{runId}"
            requiredForReadiness = $false
            note = "Optional dashboard evidence for OSMU browser multipart upload readiness; not a readiness gate or AWS S3 parity work."
        }
        "manual-monitoring-threshold-evidence.yml" = [ordered]@{
            group = "monitoring-threshold"
            runIdParameter = "MonitoringThresholdRunId"
            artifactNameTemplate = "monitoring-threshold-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target Prometheus, Grafana, Alertmanager, incident routing, and tenant baseline review evidence is part of the invocation."
        }
        "manual-secret-rotation-evidence.yml" = [ordered]@{
            group = "secret-rotation"
            runIdParameter = "SecretRotationRunId"
            artifactNameTemplate = "secret-rotation-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target secret/certificate rotation evidence is part of the invocation."
        }
        "manual-cluster-network-access-review-evidence.yml" = [ordered]@{
            group = "cluster-network-access-review"
            runIdParameter = "ClusterNetworkAccessReviewRunId"
            artifactNameTemplate = "cluster-network-access-review-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target cluster NetworkPolicy access review evidence is part of the invocation."
        }
        "manual-helm-values-hardening-evidence.yml" = [ordered]@{
            group = "helm-values-hardening"
            runIdParameter = "HelmValuesHardeningRunId"
            artifactNameTemplate = "helm-values-hardening-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target Helm values hardening evidence is part of the invocation."
        }
        "manual-commercial-integration-evidence.yml" = [ordered]@{
            group = "commercial-integration"
            runIdParameter = "CommercialIntegrationRunId"
            artifactNameTemplate = "commercial-integration-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target notification/payment handoff and payment-provider adapter readiness evidence is part of the invocation."
        }
        "manual-commercial-approval-evidence.yml" = [ordered]@{
            group = "commercial-approval"
            runIdParameter = "CommercialApprovalRunId"
            artifactNameTemplate = "commercial-approval-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when final commercial approval and billing pricing proposal approval evidence is part of the invocation."
        }
        "manual-chargeback-closeout-evidence.yml" = [ordered]@{
            group = "chargeback-closeout"
            runIdParameter = "ChargebackCloseoutRunId"
            artifactNameTemplate = "chargeback-closeout-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target billing-period chargeback closeout evidence is part of the invocation."
        }
        "enterprise-auth-smoke-ci.yml" = [ordered]@{
            group = "enterprise-auth"
            runIdParameter = "EnterpriseAuthRunId"
            artifactNameTemplate = "enterprise-auth-smoke-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target IdP/directory smoke evidence is part of the invocation."
        }
        "manual-enterprise-auth-jit-rollback-evidence.yml" = [ordered]@{
            group = "enterprise-auth-jit-rollback"
            runIdParameter = "EnterpriseAuthJitRollbackRunId"
            artifactNameTemplate = "enterprise-auth-jit-rollback-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target enterprise auth JIT rollback evidence is part of the invocation."
        }
        "manual-support-escalation-handoff-evidence.yml" = [ordered]@{
            group = "support-escalation-handoff"
            runIdParameter = "SupportEscalationHandoffRunId"
            artifactNameTemplate = "support-escalation-handoff-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when support escalation handoff review evidence is part of the invocation."
        }
        "manual-operations-handoff-package.yml" = [ordered]@{
            group = "operations-handoff-package"
            runIdParameter = "OperationsHandoffPackageRunId"
            artifactNameTemplate = "operations-handoff-package-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target handoff package evidence is part of the invocation."
        }
        "manual-data-flow-storage-plan-evidence.yml" = [ordered]@{
            group = "data-flow-storage-plan"
            runIdParameter = "DataFlowStoragePlanRunId"
            artifactNameTemplate = "data-flow-storage-plan-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target data-flow partition/time-series transition evidence is part of the invocation."
        }
        "manual-data-flow-query-retention-budget-evidence.yml" = [ordered]@{
            group = "data-flow-query-retention-budget"
            runIdParameter = "DataFlowQueryRetentionBudgetRunId"
            artifactNameTemplate = "data-flow-query-retention-budget-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target data-flow query latency and retention budget evidence is part of the invocation."
        }
        "manual-data-flow-storage-transition-runbook-evidence.yml" = [ordered]@{
            group = "data-flow-storage-transition-runbook"
            runIdParameter = "DataFlowStorageTransitionRunbookRunId"
            artifactNameTemplate = "data-flow-storage-transition-runbook-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target data-flow backfill, rollback, reconciliation, dashboard cutover, and retention dry-run rehearsal evidence is part of the invocation."
        }
        "kubernetes-operations-report-sync-ci.yml" = [ordered]@{
            group = "kubernetes-operations-report-sync"
            runIdParameter = "KubernetesOperationsReportSyncRunId"
            artifactNameTemplate = "kubernetes-operations-report-sync-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness convergence when deployed dashboard report sync evidence is part of the invocation."
        }
    }
    if ($metadata.ContainsKey($Workflow)) {
        return $metadata[$Workflow]
    }
    return [ordered]@{
        group = $Workflow
        runIdParameter = ""
        artifactNameTemplate = ""
        requiredForReadiness = $false
        note = "Workflow was found in the invocation report but has no known artifact mapping."
    }
}

function Get-DateSortValue([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [DateTimeOffset]::MinValue
    }
    try {
        return [DateTimeOffset]::Parse($Value)
    }
    catch {
        return [DateTimeOffset]::MinValue
    }
}

function Read-RunListJson([string] $Workflow, [string] $Directory) {
    if ([string]::IsNullOrWhiteSpace($Directory)) {
        return @()
    }
    $resolvedDirectory = Resolve-ProjectPath $Directory
    $path = Join-Path $resolvedDirectory "$Workflow.json"
    if (-not (Test-Path -LiteralPath $path)) {
        return @()
    }
    $json = Read-Utf8Text $path | ConvertFrom-Json
    if ($json.PSObject.Properties["runs"]) {
        return @($json.runs)
    }
    return @($json)
}

function Invoke-GhRunList([string] $Workflow, [string] $BranchName, [int] $RunLimit) {
    $output = & gh run list --workflow $Workflow --branch $BranchName --limit $RunLimit --json $jsonFields 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gh run list failed for ${Workflow}: $($output -join ' ')"
    }
    if ([string]::IsNullOrWhiteSpace(($output -join ""))) {
        return @()
    }
    return @(($output -join "`n") | ConvertFrom-Json)
}

function Get-GitHubApiWorkflowRunsQueryUrl([string] $RepositorySlug, [string] $Workflow, [string] $BranchName, [int] $RunLimit, [string] $BaseUrl) {
    if ([string]::IsNullOrWhiteSpace($RepositorySlug) -or [string]::IsNullOrWhiteSpace($Workflow)) {
        return ""
    }
    $base = if ([string]::IsNullOrWhiteSpace($BaseUrl)) { "https://api.github.com" } else { $BaseUrl.TrimEnd("/") }
    $encodedWorkflow = [System.Uri]::EscapeDataString($Workflow)
    $encodedBranch = [System.Uri]::EscapeDataString($BranchName)
    $boundedLimit = [Math]::Max(1, [Math]::Min(100, $RunLimit))
    return "$base/repos/$RepositorySlug/actions/workflows/$encodedWorkflow/runs?branch=$encodedBranch&event=workflow_dispatch&per_page=$boundedLimit"
}

function Convert-GitHubApiRun([object] $Run) {
    return [ordered]@{
        databaseId = Get-Text $Run "database_id"
        workflowName = Get-Text $Run "name"
        status = Get-Text $Run "status"
        conclusion = Get-Text $Run "conclusion"
        createdAt = Get-Text $Run "created_at"
        headSha = Get-Text $Run "head_sha"
        url = Get-Text $Run "html_url"
        displayTitle = Get-Text $Run "display_title"
    }
}

function Invoke-GitHubApiRunList([string] $RepositorySlug, [string] $Workflow, [string] $BranchName, [int] $RunLimit, [string] $BaseUrl) {
    $queryUrl = Get-GitHubApiWorkflowRunsQueryUrl $RepositorySlug $Workflow $BranchName $RunLimit $BaseUrl
    if ([string]::IsNullOrWhiteSpace($queryUrl)) {
        throw "GitHub repository is required for GitHub API run-id collection. Pass -GitHubRepository owner/repo."
    }

    $headers = @{ "User-Agent" = "OSMU-operations-workflow-run-id-plan" }
    $token = if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) { $env:GH_TOKEN } else { $env:GITHUB_TOKEN }
    if (-not [string]::IsNullOrWhiteSpace($token)) {
        $headers["Authorization"] = "Bearer $token"
    }

    try {
        $response = Invoke-RestMethod -Uri $queryUrl -Headers $headers -Method Get
    }
    catch {
        $queryError = "GitHub API run list failed for ${Workflow}; treating it as no discoverable workflow_dispatch runs: $($_.Exception.Message)"
        if ($null -ne $script:GitHubApiRunListErrors) {
            $script:GitHubApiRunListErrors[$Workflow] = $queryError
        }
        Write-Warning $queryError
        return @()
    }

    $runs = Get-JsonProperty $response "workflow_runs"
    if ($null -eq $runs) {
        return @()
    }
    return @($runs | ForEach-Object { Convert-GitHubApiRun $_ })
}

function Get-RunId([object] $Run) {
    $databaseId = Get-Text $Run "databaseId"
    if (-not [string]::IsNullOrWhiteSpace($databaseId)) {
        return $databaseId
    }
    return Get-Text $Run "id"
}

function Expand-ArtifactName([string] $Template, [string] $RunId, [string] $Version, [string] $Sha) {
    if ([string]::IsNullOrWhiteSpace($Template)) {
        return ""
    }
    $effectiveRunId = if ([string]::IsNullOrWhiteSpace($RunId)) { "<run-id>" } else { $RunId }
    return $Template.Replace("{runId}", $effectiveRunId).Replace("{version}", $Version).Replace("{commitSha}", $Sha)
}

function Add-RunIdArgumentIfMissing([System.Collections.Generic.List[string]] $ArgumentList, [string] $Parameter, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Parameter) -or [string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    $prefix = "-$Parameter "
    foreach ($arg in @($ArgumentList)) {
        if ([string] $arg -like "$prefix*") {
            return
        }
    }
    $ArgumentList.Add("-$Parameter $Value") | Out-Null
}

function Convert-WorkflowReportToRunIdInput([object] $Report, [bool] $SourceSelected, [bool] $SupplementalForSecurityFinalizer) {
    return [ordered]@{
        workflow = [string] $Report.workflow
        group = [string] $Report.group
        actionOrders = @($Report.actionOrders | ForEach-Object { [int] $_ })
        runIdParameter = [string] $Report.runIdParameter
        recommendedRunId = [string] $Report.recommendedRunId
        artifactName = [string] $Report.artifactName
        requiredForReadiness = [bool] $Report.requiredForReadiness
        readyForArtifactDownload = [bool] $Report.readyForArtifactDownload
        runsUrl = [string] $Report.runsUrl
        runListJsonPath = [string] $Report.runListJsonPath
        queryCommand = [string] $Report.queryCommand
        gitHubApiQueryUrl = [string] $Report.gitHubApiQueryUrl
        sourceSelected = [bool] $SourceSelected
        supplementalForSecurityFinalizer = [bool] $SupplementalForSecurityFinalizer
    }
}

function Get-WorkflowReport(
    [string] $Workflow,
    [object[]] $SourceActions,
    [string] $BranchName,
    [int] $RunLimit,
    [string] $QueryMode,
    [string] $RepositorySlug,
    [string] $GitHubApiBaseUrlValue,
    [string] $RunListJsonDirectoryForHandoff,
    [string] $RunListJsonDirectorySource,
    [object[]] $Runs,
    [string] $Version,
    [string] $Sha
) {
    $metadata = New-WorkflowMetadata $Workflow
    $queryCommand = "gh run list --workflow $Workflow --branch $BranchName --limit $RunLimit --json $jsonFields"
    $gitHubApiQueryUrl = Get-GitHubApiWorkflowRunsQueryUrl $RepositorySlug $Workflow $BranchName $RunLimit $GitHubApiBaseUrlValue
    $runListJsonFile = "$Workflow.json"
    $runListJsonPath = if ([string]::IsNullOrWhiteSpace($RunListJsonDirectoryForHandoff)) { "" } else { Join-Path $RunListJsonDirectoryForHandoff $runListJsonFile }
    $runListJsonExists = $false
    if (-not [string]::IsNullOrWhiteSpace($RunListJsonDirectorySource)) {
        $resolvedRunListPath = Join-Path (Resolve-ProjectPath $RunListJsonDirectorySource) $runListJsonFile
        $runListJsonExists = Test-Path -LiteralPath $resolvedRunListPath
    }
    $runListJsonNote = "Save a run-list JSON array or object with a runs array here when collecting run ids without GitHub CLI on this machine."
    $queryError = ""
    if ($null -ne $script:GitHubApiRunListErrors -and $script:GitHubApiRunListErrors.ContainsKey($Workflow)) {
        $queryError = [string] $script:GitHubApiRunListErrors[$Workflow]
    }
    $sortedRuns = @($Runs | Sort-Object -Property @{ Expression = { Get-DateSortValue (Get-Text $_ "createdAt") }; Descending = $true })
    $latestRun = if ($sortedRuns.Count -gt 0) { $sortedRuns[0] } else { $null }
    $latestSuccessfulRun = $null
    foreach ($run in $sortedRuns) {
        if ((Get-Text $run "status").ToLowerInvariant() -eq "completed" -and (Get-Text $run "conclusion").ToLowerInvariant() -eq "success") {
            $latestSuccessfulRun = $run
            break
        }
    }
    $latestRunId = Get-RunId $latestRun
    $recommendedRunId = Get-RunId $latestSuccessfulRun
    $recommendedHeadSha = Get-Text $latestSuccessfulRun "headSha"
    $artifactSha = if (-not [string]::IsNullOrWhiteSpace($recommendedHeadSha)) { $recommendedHeadSha } else { $Sha }
    $artifactName = Expand-ArtifactName ([string] $metadata.artifactNameTemplate) $recommendedRunId $Version $artifactSha
    $latestIsRecommended = -not [string]::IsNullOrWhiteSpace($latestRunId) -and $latestRunId -eq $recommendedRunId
    $actionOrders = New-Object System.Collections.Generic.List[int]
    $actionNames = New-Object System.Collections.Generic.List[string]
    $actionStatuses = New-Object System.Collections.Generic.List[string]
    $actionCategories = New-Object System.Collections.Generic.List[string]
    $actionTypes = New-Object System.Collections.Generic.List[string]
    foreach ($action in @($SourceActions)) {
        Add-UniqueInt $actionOrders (Get-Int $action "order")
        Add-UniqueString $actionNames (Get-Text $action "name")
        Add-UniqueString $actionStatuses (Get-Text $action "status")
        Add-UniqueString $actionCategories (Get-Text $action "category")
        Add-UniqueString $actionTypes (Get-Text $action "actionType")
    }
    $primaryAction = if (@($SourceActions).Count -gt 0) { @($SourceActions)[0] } else { $null }
    return [ordered]@{
        workflow = $Workflow
        sourceActionCount = @($SourceActions).Count
        primaryActionOrder = Get-Int $primaryAction "order"
        primaryActionName = Get-Text $primaryAction "name"
        primaryActionStatus = Get-Text $primaryAction "status"
        actionOrders = @($actionOrders | ForEach-Object { [int] $_ })
        actionNames = @($actionNames | ForEach-Object { [string] $_ })
        actionStatuses = @($actionStatuses | ForEach-Object { [string] $_ })
        actionCategories = @($actionCategories | ForEach-Object { [string] $_ })
        actionTypes = @($actionTypes | ForEach-Object { [string] $_ })
        group = $metadata.group
        queryCommand = $queryCommand
        gitHubApiQueryUrl = $gitHubApiQueryUrl
        runListJsonFile = $runListJsonFile
        runListJsonPath = $runListJsonPath
        runListJsonExists = $runListJsonExists
        runListJsonNote = $runListJsonNote
        runsUrl = Get-GitHubWorkflowRunsUrl $RepositorySlug $Workflow
        queryMode = $QueryMode
        querySucceeded = [string]::IsNullOrWhiteSpace($queryError)
        queryError = $queryError
        candidateCount = $sortedRuns.Count
        latestRunId = $latestRunId
        latestStatus = Get-Text $latestRun "status"
        latestConclusion = Get-Text $latestRun "conclusion"
        latestCreatedAt = Get-Text $latestRun "createdAt"
        latestHeadSha = Get-Text $latestRun "headSha"
        latestUrl = Get-Text $latestRun "url"
        recommendedRunId = $recommendedRunId
        recommendedHeadSha = $recommendedHeadSha
        recommendedCreatedAt = Get-Text $latestSuccessfulRun "createdAt"
        recommendedUrl = Get-Text $latestSuccessfulRun "url"
        latestRunIsRecommended = $latestIsRecommended
        readyForArtifactDownload = -not [string]::IsNullOrWhiteSpace($recommendedRunId)
        requiredForReadiness = [bool] $metadata.requiredForReadiness
        runIdParameter = $metadata.runIdParameter
        artifactName = $artifactName
        note = $metadata.note
    }
}

$resolvedInvocationReportPath = Resolve-ProjectPath $InvocationReportPath
if (-not (Test-Path -LiteralPath $resolvedInvocationReportPath)) {
    throw "Operations evidence invocation report not found: $resolvedInvocationReportPath"
}

$invocation = Read-Utf8Text $resolvedInvocationReportPath | ConvertFrom-Json
if ($invocation.formatVersion -ne "osmu.operations-evidence-plan-invocation.v1") {
    throw "Unexpected operations evidence invocation formatVersion: $($invocation.formatVersion)"
}

$branchName = Get-CurrentBranch
$effectiveCommitSha = Get-CurrentCommitSha
$githubRepositorySlug = Resolve-GitHubRepositorySlug $GitHubRepository
$githubApiTokenPresent = -not [string]::IsNullOrWhiteSpace($env:GH_TOKEN) -or -not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)
if ($Execute -and $UseGitHubApi) {
    throw "Use either -Execute or -UseGitHubApi, not both."
}
if ($UseGitHubApi -and -not [string]::IsNullOrWhiteSpace($RunListJsonDirectory)) {
    throw "Use either -UseGitHubApi or -RunListJsonDirectory, not both."
}
if ($UseGitHubApi -and [string]::IsNullOrWhiteSpace($githubRepositorySlug)) {
    throw "-UseGitHubApi requires -GitHubRepository owner/repo, GITHUB_REPOSITORY, or a GitHub remote origin."
}
$workflows = New-Object System.Collections.Generic.List[string]
$workflowActions = [ordered]@{}
foreach ($action in @($invocation.actions)) {
    $command = Get-Text $action "command"
    $workflow = Get-WorkflowName $command
    if ([string]::IsNullOrWhiteSpace($workflow)) {
        $workflow = Get-ManualEvidenceWorkflowName $command
    }
    Add-UniqueWorkflow $workflows $workflow
    if (-not [string]::IsNullOrWhiteSpace($workflow)) {
        if (-not $workflowActions.Contains($workflow)) {
            $workflowActions[$workflow] = New-Object System.Collections.ArrayList
        }
        $workflowActions[$workflow].Add($action) | Out-Null
    }
}

$queryMode = if ($Execute) { "execute" } elseif ($UseGitHubApi) { "github-api" } elseif (-not [string]::IsNullOrWhiteSpace($RunListJsonDirectory)) { "fixture" } else { "plan-only" }
$defaultRunListJsonDirectory = ".\.osmu-run\workflow-run-lists"
$runListJsonDirectoryForHandoff = if ([string]::IsNullOrWhiteSpace($RunListJsonDirectory)) { $defaultRunListJsonDirectory } else { $RunListJsonDirectory }
$runListJsonFilePattern = "<workflow>.json"
$runListJsonDirectoryCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory $runListJsonDirectoryForHandoff"
$githubApiRunListCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository $githubRepositorySlug -Branch $branchName -Limit $Limit -ImageSigningVersion $ImageSigningVersion"
$runListJsonHandoffNote = "Save each workflow run-list JSON as $runListJsonDirectoryForHandoff\<workflow>.json. Each file may contain an array of runs or an object with a runs array."
$workflowReports = New-Object System.Collections.Generic.List[object]
foreach ($workflow in $workflows) {
    $runs = if ($Execute) {
        Invoke-GhRunList $workflow $branchName $Limit
    }
    elseif ($UseGitHubApi) {
        Invoke-GitHubApiRunList $githubRepositorySlug $workflow $branchName $Limit $GitHubApiBaseUrl
    }
    else {
        Read-RunListJson $workflow $RunListJsonDirectory
    }
    $workflowReports.Add((Get-WorkflowReport `
        -Workflow $workflow `
        -SourceActions @($workflowActions[$workflow]) `
        -BranchName $branchName `
        -RunLimit $Limit `
        -QueryMode $queryMode `
        -RepositorySlug $githubRepositorySlug `
        -GitHubApiBaseUrlValue $GitHubApiBaseUrl `
        -RunListJsonDirectoryForHandoff $runListJsonDirectoryForHandoff `
        -RunListJsonDirectorySource $RunListJsonDirectory `
        -Runs @($runs) `
        -Version $ImageSigningVersion `
        -Sha $effectiveCommitSha)) | Out-Null
}

$imageSigningReport = @($workflowReports | Where-Object { $_.workflow -eq "image-publish-sign-ci.yml" } | Select-Object -First 1)
$containerSecurityReport = @($workflowReports | Where-Object { $_.workflow -eq "container-security-ci.yml" } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($CommitSha)) {
    if ($imageSigningReport.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($imageSigningReport[0].recommendedHeadSha)) {
        $effectiveCommitSha = $imageSigningReport[0].recommendedHeadSha
    }
    elseif ($containerSecurityReport.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($containerSecurityReport[0].recommendedHeadSha)) {
        $effectiveCommitSha = $containerSecurityReport[0].recommendedHeadSha
    }
}

if ($effectiveCommitSha -ne "<commit-sha>") {
    for ($index = 0; $index -lt $workflowReports.Count; $index++) {
        $report = $workflowReports[$index]
        if ($report.workflow -eq "image-publish-sign-ci.yml" -or $report.workflow -eq "container-security-ci.yml") {
            $metadata = New-WorkflowMetadata $report.workflow
            $report.artifactName = Expand-ArtifactName ([string] $metadata.artifactNameTemplate) $report.recommendedRunId $ImageSigningVersion $effectiveCommitSha
        }
    }
}

$missingRecommended = @($workflowReports | Where-Object { -not $_.readyForArtifactDownload })
$staleRecommended = @($workflowReports | Where-Object { $_.readyForArtifactDownload -and -not $_.latestRunIsRecommended })
$result = if ($workflowReports.Count -eq 0) {
    "no-workflows"
}
elseif ($queryMode -eq "plan-only") {
    "query-required"
}
elseif ($missingRecommended.Count -gt 0) {
    "action-required"
}
elseif ($staleRecommended.Count -gt 0) {
    "review-stale-success"
}
else {
    "ready"
}

$collectionArgs = New-Object System.Collections.Generic.List[string]
foreach ($report in $workflowReports) {
    if (-not [string]::IsNullOrWhiteSpace($report.runIdParameter) -and -not [string]::IsNullOrWhiteSpace($report.recommendedRunId)) {
        $collectionArgs.Add("-$($report.runIdParameter) $($report.recommendedRunId)") | Out-Null
    }
}
$collectionArgs.Add("-ImageSigningVersion $ImageSigningVersion") | Out-Null
$collectionArgs.Add("-CommitSha $effectiveCommitSha") | Out-Null
$artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 $($collectionArgs -join ' ')"

$manualRunIdCollectionArgs = New-Object System.Collections.Generic.List[string]
foreach ($report in $workflowReports) {
    if (-not [string]::IsNullOrWhiteSpace($report.runIdParameter)) {
        $manualRunIdValue = if (-not [string]::IsNullOrWhiteSpace($report.recommendedRunId)) { $report.recommendedRunId } else { "<$($report.runIdParameter)>" }
        $manualRunIdCollectionArgs.Add("-$($report.runIdParameter) $manualRunIdValue") | Out-Null
    }
}
$manualRunIdCollectionArgs.Add("-ImageSigningVersion $ImageSigningVersion") | Out-Null
$manualRunIdCollectionArgs.Add("-CommitSha $effectiveCommitSha") | Out-Null
$manualArtifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 $($manualRunIdCollectionArgs -join ' ')"

$imageSigningRunId = if ($imageSigningReport.Count -gt 0) { $imageSigningReport[0].recommendedRunId } else { "" }
$containerSecurityRunId = if ($containerSecurityReport.Count -gt 0) { $containerSecurityReport[0].recommendedRunId } else { "" }
$imageSigningArtifact = "osmu-image-signing-$ImageSigningVersion-$effectiveCommitSha"
$containerSecurityArtifact = "osmu-container-security-$effectiveCommitSha"
$securityEvidenceFinalizerCommand = if (-not [string]::IsNullOrWhiteSpace($imageSigningRunId) -and -not [string]::IsNullOrWhiteSpace($containerSecurityRunId)) {
    "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=$imageSigningRunId -f image_signing_artifact_name=$imageSigningArtifact -f container_security_run_id=$containerSecurityRunId -f container_security_artifact_name=$containerSecurityArtifact -f fail_if_not_passed=true"
}
else {
    "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id> -f image_signing_artifact_name=$imageSigningArtifact -f container_security_run_id=<container-security-run-id> -f container_security_artifact_name=$containerSecurityArtifact -f fail_if_not_passed=true"
}

$securitySourceSelected = ($imageSigningReport.Count -gt 0 -or $containerSecurityReport.Count -gt 0)
$securityEvidenceFinalizerRunIdInputs = if ($securitySourceSelected) { @("ImageSigningRunId", "ContainerSecurityRunId") } else { @() }
$securityEvidenceFinalizerMissingRunIdInputs = @()
if ($securitySourceSelected -and [string]::IsNullOrWhiteSpace($imageSigningRunId)) {
    $securityEvidenceFinalizerMissingRunIdInputs += "ImageSigningRunId"
}
if ($securitySourceSelected -and [string]::IsNullOrWhiteSpace($containerSecurityRunId)) {
    $securityEvidenceFinalizerMissingRunIdInputs += "ContainerSecurityRunId"
}
$securityEvidenceFinalizerReady = $securitySourceSelected -and $securityEvidenceFinalizerMissingRunIdInputs.Count -eq 0
$securityEvidenceFinalizerMissingRunIdText = if ($securityEvidenceFinalizerMissingRunIdInputs.Count -gt 0) { $securityEvidenceFinalizerMissingRunIdInputs -join ", " } else { "none" }
$securityEvidenceFinalizerDependencyNote = if ($securitySourceSelected) {
    "Security evidence finalizer needs both ImageSigningRunId and ContainerSecurityRunId. Browser dispatch for action 6 can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml."
} else {
    ""
}
$sourceActionOrders = @(Get-ActionOrders @($invocation.actions))
$securityEvidenceFinalizerRunIdInputHints = @()
if ($securitySourceSelected) {
    $imageSigningHintReport = if ($imageSigningReport.Count -gt 0) {
        $imageSigningReport[0]
    } else {
        Get-WorkflowReport `
            -Workflow "image-publish-sign-ci.yml" `
            -SourceActions @() `
            -BranchName $branchName `
            -RunLimit $Limit `
            -QueryMode $queryMode `
            -RepositorySlug $githubRepositorySlug `
            -GitHubApiBaseUrlValue $GitHubApiBaseUrl `
            -RunListJsonDirectoryForHandoff $runListJsonDirectoryForHandoff `
            -RunListJsonDirectorySource $RunListJsonDirectory `
            -Runs @() `
            -Version $ImageSigningVersion `
            -Sha $effectiveCommitSha
    }
    $containerSecurityHintReport = if ($containerSecurityReport.Count -gt 0) {
        $containerSecurityReport[0]
    } else {
        Get-WorkflowReport `
            -Workflow "container-security-ci.yml" `
            -SourceActions @() `
            -BranchName $branchName `
            -RunLimit $Limit `
            -QueryMode $queryMode `
            -RepositorySlug $githubRepositorySlug `
            -GitHubApiBaseUrlValue $GitHubApiBaseUrl `
            -RunListJsonDirectoryForHandoff $runListJsonDirectoryForHandoff `
            -RunListJsonDirectorySource $RunListJsonDirectory `
            -Runs @() `
            -Version $ImageSigningVersion `
            -Sha $effectiveCommitSha
    }
    $securityEvidenceFinalizerRunIdInputHints = @(
        Convert-WorkflowReportToRunIdInput $imageSigningHintReport ($imageSigningReport.Count -gt 0) ($imageSigningReport.Count -eq 0)
        Convert-WorkflowReportToRunIdInput $containerSecurityHintReport ($containerSecurityReport.Count -gt 0) ($containerSecurityReport.Count -eq 0)
    )
}

foreach ($hint in @($securityEvidenceFinalizerRunIdInputHints)) {
    $parameter = [string] $hint.runIdParameter
    $recommendedRunId = [string] $hint.recommendedRunId
    if (-not [string]::IsNullOrWhiteSpace($recommendedRunId)) {
        Add-RunIdArgumentIfMissing $collectionArgs $parameter $recommendedRunId
    }
    Add-RunIdArgumentIfMissing $manualRunIdCollectionArgs $parameter "<$parameter>"
}
$artifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 $($collectionArgs -join ' ')"
$manualArtifactCollectionPlanCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 $($manualRunIdCollectionArgs -join ' ')"

$workflowRunIdInputs = @($workflowReports | ForEach-Object { Convert-WorkflowReportToRunIdInput $_ $true $false })
$browserWorkflowRunsUrls = @(
    @($workflowReports | ForEach-Object { [string] $_.runsUrl })
    @($securityEvidenceFinalizerRunIdInputHints | ForEach-Object { [string] $_.runsUrl })
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
$recommendedCommands = @(
    [ordered]@{
        order = 1
        name = "Collect run ids from saved run-list JSON"
        command = $runListJsonDirectoryCommand
        reason = "Use after browser dispatch when GitHub CLI is unavailable locally."
        note = $runListJsonHandoffNote
        dispatchUrls = @($browserWorkflowRunsUrls)
    },
    [ordered]@{
        order = 2
        name = "Collect workflow run ids with GitHub REST API"
        command = $githubApiRunListCommand
        reason = "Use after browser dispatch when GitHub CLI is unavailable and the repository Actions API is readable."
        note = "Queries workflow_dispatch runs through the GitHub REST API, using GH_TOKEN or GITHUB_TOKEN if present, and never writes token values to the report."
        dispatchUrls = @($browserWorkflowRunsUrls)
    },
    [ordered]@{
        order = 3
        name = "Collect workflow run ids with GitHub CLI"
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -Execute"
        reason = "Use after workflow dispatch when gh is installed and authenticated."
        note = "Regenerates this plan by querying workflow_dispatch runs directly."
        dispatchUrls = @()
    },
    [ordered]@{
        order = 4
        name = "Write artifact collection plan with browser run ids"
        command = $manualArtifactCollectionPlanCommand
        reason = "Use when a browser workflow run page shows the run id but gh/run-list JSON is unavailable."
        note = "Replace each <RunIdParameter> placeholder with either the numeric GitHub Actions run id or the full workflow run URL; artifact collection normalizes /actions/runs/<id> before regenerating the same selected-action scope.$(if ([string]::IsNullOrWhiteSpace($securityEvidenceFinalizerDependencyNote)) { '' } else { ' ' + $securityEvidenceFinalizerDependencyNote })"
        dispatchUrls = @($browserWorkflowRunsUrls)
    },
    [ordered]@{
        order = 5
        name = "Write artifact collection plan"
        command = $artifactCollectionPlanCommand
        reason = "Use after recommended run ids are available."
        note = "Feeds run ids into the artifact collection/import chain."
        dispatchUrls = @()
    },
    [ordered]@{
        order = 6
        name = "Run security evidence finalizer"
        command = $securityEvidenceFinalizerCommand
        reason = "Use after image signing and container security source run ids are known."
        note = "Promotes signed-image and container scan/SBOM evidence into the security finalizer artifact.$(if ($securitySourceSelected) { ' Missing run id inputs: ' + $securityEvidenceFinalizerMissingRunIdText + '.' } else { '' })"
        dispatchUrls = @()
    }
)

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$queryWorkflowCount = @($workflowReports | Where-Object {
    -not [string]::IsNullOrWhiteSpace([string] $_.queryMode) -or
    $null -ne $_.querySucceeded -or
    -not [string]::IsNullOrWhiteSpace([string] $_.queryError)
}).Count
if ($queryWorkflowCount -eq 0 -and -not [string]::IsNullOrWhiteSpace($queryMode)) {
    $queryWorkflowCount = $workflowReports.Count
}
$querySucceededCount = @($workflowReports | Where-Object { [bool] $_.querySucceeded }).Count
$queryErrorCount = @($workflowReports | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_.queryError) }).Count
$candidateCount = 0
foreach ($workflowReport in $workflowReports) {
    try {
        $candidateCount += [int] $workflowReport.candidateCount
    } catch {
        $candidateCount += 0
    }
}
$queryExecutedCount = @($workflowReports | Where-Object {
    $rowQueryMode = [string] $_.queryMode
    -not [string]::IsNullOrWhiteSpace($rowQueryMode) -and -not "plan-only".Equals($rowQueryMode, [System.StringComparison]::OrdinalIgnoreCase)
}).Count
if ($queryExecutedCount -eq 0 -and -not [string]::IsNullOrWhiteSpace($queryMode) -and -not "plan-only".Equals($queryMode, [System.StringComparison]::OrdinalIgnoreCase)) {
    $queryExecutedCount = $queryWorkflowCount
}
$queryExecuted = $queryExecutedCount -gt 0
$reportObject = [ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    generatedAt = $generatedAt
    result = $result
    sourceInvocationReport = $resolvedInvocationReportPath
    invocationResult = Get-Text $invocation "result"
    sourceSummary = Get-Text $invocation "sourceSummary"
    sourcePassedCount = Get-Int $invocation "sourcePassedCount"
    sourcePendingCount = Get-Int $invocation "sourcePendingCount"
    sourceTotalCount = Get-Int $invocation "sourceTotalCount"
    sourceCheckCount = Get-Int $invocation "sourceCheckCount"
    sourceActionCount = @($invocation.actions).Count
    sourceActionOrders = @($sourceActionOrders)
    selectedActionOrders = @($sourceActionOrders)
    branch = $branchName
    githubRepository = $githubRepositorySlug
    queryMode = $queryMode
    githubApiTokenPresent = [bool] $githubApiTokenPresent
    githubApiUnauthenticated = [bool] ($UseGitHubApi -and -not $githubApiTokenPresent)
    queryExecuted = [bool] $queryExecuted
    queryExecutedCount = $queryExecutedCount
    queryWorkflowCount = $queryWorkflowCount
    querySucceededCount = $querySucceededCount
    queryErrorCount = $queryErrorCount
    candidateCount = $candidateCount
    runListJsonDirectory = $runListJsonDirectoryForHandoff
    runListJsonDirectoryCommand = $runListJsonDirectoryCommand
    githubApiRunListCommand = $githubApiRunListCommand
    githubApiBaseUrl = $GitHubApiBaseUrl
    runListJsonFilePattern = $runListJsonFilePattern
    runListJsonHandoffNote = $runListJsonHandoffNote
    browserWorkflowRunsUrls = @($browserWorkflowRunsUrls)
    workflowRunIdInputs = @($workflowRunIdInputs)
    recommendedCommands = @($recommendedCommands)
    limit = $Limit
    workflowCount = $workflowReports.Count
    readyWorkflowCount = @($workflowReports | Where-Object { $_.readyForArtifactDownload }).Count
    missingWorkflowCount = $missingRecommended.Count
    staleWorkflowCount = $staleRecommended.Count
    workflowQueryErrorCount = @($workflowReports | Where-Object { -not [bool] $_.querySucceeded }).Count
    imageSigningVersion = $ImageSigningVersion
    commitSha = $effectiveCommitSha
    artifactCollectionPlanCommand = $artifactCollectionPlanCommand
    manualArtifactCollectionPlanCommand = $manualArtifactCollectionPlanCommand
    securityEvidenceFinalizerReady = [bool] $securityEvidenceFinalizerReady
    securityEvidenceFinalizerRunIdInputs = @($securityEvidenceFinalizerRunIdInputs)
    securityEvidenceFinalizerRunIdInputHints = @($securityEvidenceFinalizerRunIdInputHints)
    securityEvidenceFinalizerMissingRunIdInputs = @($securityEvidenceFinalizerMissingRunIdInputs)
    securityEvidenceFinalizerDependencyNote = $securityEvidenceFinalizerDependencyNote
    securityEvidenceFinalizerCommand = $securityEvidenceFinalizerCommand
    decisionRule = "Use the query commands or workflow runs URLs to identify latest successful workflow_dispatch runs, run the security evidence finalizer after image signing and container security artifacts are ready, then regenerate the artifact collection plan with the recommended run ids."
    workflows = @($workflowReports | ForEach-Object { $_ })
}

$markdownLines = @(
    "# OSMU Operations Workflow Run ID Plan",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source invocation report: $resolvedInvocationReportPath",
    "Invocation result: $($reportObject.invocationResult)",
    "Source summary: $($reportObject.sourceSummary)",
    "Source counts: passed=$($reportObject.sourcePassedCount) pending=$($reportObject.sourcePendingCount) total=$($reportObject.sourceTotalCount) checks=$($reportObject.sourceCheckCount)",
    "Branch: $branchName",
    "GitHub repository: $(if ([string]::IsNullOrWhiteSpace($githubRepositorySlug)) { 'unknown' } else { $githubRepositorySlug })",
    "Query mode: $queryMode",
    "GitHub API token present: $githubApiTokenPresent",
    "GitHub API unauthenticated: $($UseGitHubApi -and -not $githubApiTokenPresent)",
    "Run-list JSON directory: $runListJsonDirectoryForHandoff",
    "Run-list JSON file pattern: $runListJsonFilePattern",
    "Browser workflow runs URLs: $(if ($browserWorkflowRunsUrls.Count -gt 0) { $browserWorkflowRunsUrls -join ', ' } else { 'none' })",
    "",
    "## Decision Rule",
    "",
    $reportObject.decisionRule,
    "",
    "## Summary",
    "",
    "- Workflows: $($reportObject.workflowCount)",
    "- Ready workflows: $($reportObject.readyWorkflowCount)",
    "- Missing successful runs: $($reportObject.missingWorkflowCount)",
    "- Stale successful runs: $($reportObject.staleWorkflowCount)",
    "- Workflow query errors: $($reportObject.workflowQueryErrorCount)",
    "- Query executed: $($reportObject.queryExecuted)",
    "- Query execution count: $($reportObject.queryExecutedCount)/$($reportObject.queryWorkflowCount)",
    "- Query success count: $($reportObject.querySucceededCount)/$($reportObject.queryWorkflowCount)",
    "- Query error count: $($reportObject.queryErrorCount)",
    "- Candidate runs: $($reportObject.candidateCount)",
    "- Source action orders: $(if ($sourceActionOrders.Count -gt 0) { $sourceActionOrders -join ', ' } else { 'none' })",
    "- Selected action orders: $(if ($sourceActionOrders.Count -gt 0) { $sourceActionOrders -join ', ' } else { 'none' })",
    "- Commit SHA for security artifacts: $effectiveCommitSha",
    "",
    "## Commands",
    "",
    "- Artifact collection plan: ``$artifactCollectionPlanCommand``",
    "- Security evidence finalizer: ``$securityEvidenceFinalizerCommand``",
    "- Security finalizer ready: $securityEvidenceFinalizerReady",
    "- Security finalizer missing run id inputs: $securityEvidenceFinalizerMissingRunIdText",
    "- Saved run-list JSON plan: ``$runListJsonDirectoryCommand``",
    "- GitHub REST API run-id query: ``$githubApiRunListCommand``",
    "- GitHub CLI run-id query: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -Execute``",
    "",
    "## Security Evidence Finalizer Inputs",
    "",
    "- Ready: $securityEvidenceFinalizerReady",
    "- Required run id inputs: $(if ($securityEvidenceFinalizerRunIdInputs.Count -gt 0) { $securityEvidenceFinalizerRunIdInputs -join ', ' } else { 'none' })",
    "- Missing run id inputs: $securityEvidenceFinalizerMissingRunIdText",
    "- Dependency note: $(if ([string]::IsNullOrWhiteSpace($securityEvidenceFinalizerDependencyNote)) { 'none' } else { $securityEvidenceFinalizerDependencyNote })",
    "- Run id hint count: $(@($securityEvidenceFinalizerRunIdInputHints).Count)",
    "",
    "## Recommended Commands",
    ""
)
foreach ($command in $recommendedCommands) {
    $markdownLines += "- $($command.order). $($command.name): ``$($command.command)``"
    $markdownLines += "  - Reason: $($command.reason)"
    if (-not [string]::IsNullOrWhiteSpace($command.note)) {
        $markdownLines += "  - Note: $($command.note)"
    }
    if (@($command.dispatchUrls).Count -gt 0) {
        $markdownLines += "  - Browser URLs: $(@($command.dispatchUrls) -join ', ')"
    }
}
$markdownLines += @(
    "",
    "## Saved Run List JSON Handoff",
    "",
    $runListJsonHandoffNote,
    "",
    "## Workflow Run Queries",
    ""
)
if (@($securityEvidenceFinalizerRunIdInputHints).Count -gt 0) {
    $markdownLines += ""
    $markdownLines += "## Security Evidence Finalizer Run ID Hints"
    foreach ($hint in @($securityEvidenceFinalizerRunIdInputHints)) {
        $markdownLines += ""
        $markdownLines += "### $($hint.runIdParameter)"
        $markdownLines += "- Workflow: $($hint.workflow)"
        $markdownLines += "- Source selected: $($hint.sourceSelected)"
        $markdownLines += "- Supplemental: $($hint.supplementalForSecurityFinalizer)"
        $markdownLines += "- Ready: $($hint.readyForArtifactDownload)"
        $markdownLines += "- Recommended run id: $(if ([string]::IsNullOrWhiteSpace($hint.recommendedRunId)) { 'none' } else { $hint.recommendedRunId })"
        $markdownLines += "- Artifact: $($hint.artifactName)"
        if (-not [string]::IsNullOrWhiteSpace($hint.runsUrl)) { $markdownLines += "- Workflow runs URL: $($hint.runsUrl)" }
        if (-not [string]::IsNullOrWhiteSpace($hint.runListJsonPath)) { $markdownLines += "- Save run-list JSON as: $($hint.runListJsonPath)" }
        if (-not [string]::IsNullOrWhiteSpace($hint.queryCommand)) { $markdownLines += "- Query command: ``$($hint.queryCommand)``" }
        if (-not [string]::IsNullOrWhiteSpace($hint.gitHubApiQueryUrl)) { $markdownLines += "- GitHub API query URL: $($hint.gitHubApiQueryUrl)" }
    }
}

foreach ($workflowReport in $workflowReports) {
    $actionOrderText = if (@($workflowReport.actionOrders).Count -gt 0) { "actions $(@($workflowReport.actionOrders) -join ', ')" } else { "actions unknown" }
    $markdownLines += "- $($workflowReport.workflow) ($actionOrderText): ``$($workflowReport.queryCommand)``"
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.runsUrl)) {
        $markdownLines += "  - Workflow runs URL: $($workflowReport.runsUrl)"
    }
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.gitHubApiQueryUrl)) {
        $markdownLines += "  - GitHub API URL: $($workflowReport.gitHubApiQueryUrl)"
        if (-not [string]::IsNullOrWhiteSpace($workflowReport.queryError)) {
            $markdownLines += "  - Query error: $($workflowReport.queryError)"
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.runListJsonPath)) {
        $markdownLines += "  - Save run-list JSON as: $($workflowReport.runListJsonPath)"
    }
}
$markdownLines += @("", "## Recommended Run IDs", "")
foreach ($workflowReport in $workflowReports) {
    $status = if ($workflowReport.readyForArtifactDownload) { "ready" } else { "missing" }
    $markdownLines += "- [$status] $($workflowReport.workflow)"
    if (@($workflowReport.actionOrders).Count -gt 0) {
        $markdownLines += "  - Source action orders: $(@($workflowReport.actionOrders) -join ', ')"
    }
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.primaryActionName)) {
        $markdownLines += "  - Primary action: $($workflowReport.primaryActionOrder). $($workflowReport.primaryActionName) / $($workflowReport.primaryActionStatus)"
    }
    $markdownLines += "  - Run id parameter: $($workflowReport.runIdParameter)"
    $markdownLines += "  - Recommended run id: $($workflowReport.recommendedRunId)"
    $markdownLines += "  - Latest run: $($workflowReport.latestRunId) / $($workflowReport.latestStatus) / $($workflowReport.latestConclusion)"
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.queryError)) {
        $markdownLines += "  - Query error: $($workflowReport.queryError)"
    }
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.runsUrl)) {
        $markdownLines += "  - Workflow runs URL: $($workflowReport.runsUrl)"
    }
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.artifactName)) {
        $markdownLines += "  - Expected artifact: $($workflowReport.artifactName)"
    }
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.recommendedUrl)) {
        $markdownLines += "  - URL: $($workflowReport.recommendedUrl)"
    }
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.note)) {
        $markdownLines += "  - Note: $($workflowReport.note)"
    }
}

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $reportObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    $markdownLines | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations workflow run id plan JSON: $resolvedJsonOutputPath"
    Write-Host "Operations workflow run id plan markdown: $resolvedMarkdownOutputPath"
}

$reportObject | ConvertTo-Json -Depth 12
