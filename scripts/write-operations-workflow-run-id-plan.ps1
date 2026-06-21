param(
    [string] $InvocationReportPath = ".\.osmu-run\latest-operations-evidence-plan-invocation.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-workflow-run-ids.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-workflow-run-ids.md",
    [string] $RunListJsonDirectory = "",
    [string] $Branch = "",
    [int] $Limit = 20,
    [string] $ImageSigningVersion = "v0.1.0-rc.1",
    [string] $CommitSha = "",
    [switch] $Execute,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$jsonFields = "databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle"

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
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

function Get-ManualEvidenceWorkflowName([string] $Command) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return ""
    }
    if ($Command.Contains("write-storage-backend-telemetry-evidence.ps1")) {
        return "manual-storage-backend-telemetry-evidence.yml"
    }
    if ($Command.Contains("write-secret-rotation-evidence.ps1")) {
        return "manual-secret-rotation-evidence.yml"
    }
    if ($Command.Contains("write-commercial-integration-evidence.ps1")) {
        return "manual-commercial-integration-evidence.yml"
    }
    if ($Command.Contains("write-commercial-approval-evidence.ps1")) {
        return "manual-commercial-approval-evidence.yml"
    }
    if ($Command.Contains("write-operations-handoff-package.ps1")) {
        return "manual-operations-handoff-package.yml"
    }
    return ""
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
        "manual-secret-rotation-evidence.yml" = [ordered]@{
            group = "secret-rotation"
            runIdParameter = "SecretRotationRunId"
            artifactNameTemplate = "secret-rotation-evidence-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target secret/certificate rotation evidence is part of the invocation."
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
            note = "Required by operations readiness artifact import when final commercial approval evidence is part of the invocation."
        }
        "enterprise-auth-smoke-ci.yml" = [ordered]@{
            group = "enterprise-auth"
            runIdParameter = "EnterpriseAuthRunId"
            artifactNameTemplate = "enterprise-auth-smoke-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target IdP/directory smoke evidence is part of the invocation."
        }
        "manual-operations-handoff-package.yml" = [ordered]@{
            group = "operations-handoff-package"
            runIdParameter = "OperationsHandoffPackageRunId"
            artifactNameTemplate = "operations-handoff-package-{runId}"
            requiredForReadiness = $true
            note = "Required by operations readiness artifact import when target handoff package evidence is part of the invocation."
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
    $json = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
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

function Get-WorkflowReport(
    [string] $Workflow,
    [string] $BranchName,
    [int] $RunLimit,
    [string] $QueryMode,
    [object[]] $Runs,
    [string] $Version,
    [string] $Sha
) {
    $metadata = New-WorkflowMetadata $Workflow
    $queryCommand = "gh run list --workflow $Workflow --branch $BranchName --limit $RunLimit --json $jsonFields"
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
    return [ordered]@{
        workflow = $Workflow
        group = $metadata.group
        queryCommand = $queryCommand
        queryMode = $QueryMode
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

$invocation = Get-Content -Raw -LiteralPath $resolvedInvocationReportPath | ConvertFrom-Json
if ($invocation.formatVersion -ne "osmu.operations-evidence-plan-invocation.v1") {
    throw "Unexpected operations evidence invocation formatVersion: $($invocation.formatVersion)"
}

$branchName = Get-CurrentBranch
$effectiveCommitSha = Get-CurrentCommitSha
$workflows = New-Object System.Collections.Generic.List[string]
foreach ($action in @($invocation.actions)) {
    $command = Get-Text $action "command"
    $workflow = Get-WorkflowName $command
    if ([string]::IsNullOrWhiteSpace($workflow)) {
        $workflow = Get-ManualEvidenceWorkflowName $command
    }
    Add-UniqueWorkflow $workflows $workflow
}

$queryMode = if ($Execute) { "execute" } elseif (-not [string]::IsNullOrWhiteSpace($RunListJsonDirectory)) { "fixture" } else { "plan-only" }
$workflowReports = New-Object System.Collections.Generic.List[object]
foreach ($workflow in $workflows) {
    $runs = if ($Execute) {
        Invoke-GhRunList $workflow $branchName $Limit
    }
    else {
        Read-RunListJson $workflow $RunListJsonDirectory
    }
    $workflowReports.Add((Get-WorkflowReport $workflow $branchName $Limit $queryMode @($runs) $ImageSigningVersion $effectiveCommitSha)) | Out-Null
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

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$reportObject = [ordered]@{
    formatVersion = "osmu.operations-workflow-run-id-plan.v1"
    generatedAt = $generatedAt
    result = $result
    sourceInvocationReport = $resolvedInvocationReportPath
    invocationResult = Get-Text $invocation "result"
    branch = $branchName
    queryMode = $queryMode
    limit = $Limit
    workflowCount = $workflowReports.Count
    readyWorkflowCount = @($workflowReports | Where-Object { $_.readyForArtifactDownload }).Count
    missingWorkflowCount = $missingRecommended.Count
    staleWorkflowCount = $staleRecommended.Count
    imageSigningVersion = $ImageSigningVersion
    commitSha = $effectiveCommitSha
    artifactCollectionPlanCommand = $artifactCollectionPlanCommand
    securityEvidenceFinalizerCommand = $securityEvidenceFinalizerCommand
    decisionRule = "Use the query commands to identify latest successful workflow_dispatch runs, run the security evidence finalizer after image signing and container security artifacts are ready, then regenerate the artifact collection plan with the recommended run ids."
    workflows = @($workflowReports | ForEach-Object { $_ })
}

$markdownLines = @(
    "# OSMU Operations Workflow Run ID Plan",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source invocation report: $resolvedInvocationReportPath",
    "Invocation result: $($reportObject.invocationResult)",
    "Branch: $branchName",
    "Query mode: $queryMode",
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
    "- Commit SHA for security artifacts: $effectiveCommitSha",
    "",
    "## Commands",
    "",
    "- Artifact collection plan: ``$artifactCollectionPlanCommand``",
    "- Security evidence finalizer: ``$securityEvidenceFinalizerCommand``",
    "",
    "## Workflow Run Queries",
    ""
)
foreach ($workflowReport in $workflowReports) {
    $markdownLines += "- $($workflowReport.workflow): ``$($workflowReport.queryCommand)``"
}
$markdownLines += @("", "## Recommended Run IDs", "")
foreach ($workflowReport in $workflowReports) {
    $status = if ($workflowReport.readyForArtifactDownload) { "ready" } else { "missing" }
    $markdownLines += "- [$status] $($workflowReport.workflow)"
    $markdownLines += "  - Run id parameter: $($workflowReport.runIdParameter)"
    $markdownLines += "  - Recommended run id: $($workflowReport.recommendedRunId)"
    $markdownLines += "  - Latest run: $($workflowReport.latestRunId) / $($workflowReport.latestStatus) / $($workflowReport.latestConclusion)"
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.artifactName)) {
        $markdownLines += "  - Expected artifact: $($workflowReport.artifactName)"
    }
    if (-not [string]::IsNullOrWhiteSpace($workflowReport.recommendedUrl)) {
        $markdownLines += "  - URL: $($workflowReport.recommendedUrl)"
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
