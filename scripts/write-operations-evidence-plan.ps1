param(
    [string] $ReadinessReportPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-evidence-plan.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-evidence-plan.md",
    [string] $GitHubRepository = "",
    [switch] $IncludePassed,
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

function Get-IntOrDefault([object] $Object, [string] $Name, [int] $DefaultValue) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return $DefaultValue
    }
    if ($value -is [int]) {
        return [int] $value
    }
    if ($value -is [long]) {
        return [int] $value
    }
    $parsed = 0
    if ([int]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return $DefaultValue
}

function Get-Placeholders([string[]] $Values) {
    $placeholders = New-Object System.Collections.Generic.List[string]
    foreach ($value in $Values) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }
        foreach ($match in [regex]::Matches($value, "<[^>]+>|YYYYMMDDTHHMMSSZ")) {
            if ($match.Value -eq "YYYYMMDDTHHMMSSZ" -and $placeholders.Contains("<YYYYMMDDTHHMMSSZ>")) {
                continue
            }
            if (-not $placeholders.Contains($match.Value)) {
                $placeholders.Add($match.Value)
            }
        }
    }
    return @($placeholders)
}

function Get-ActionType([string] $Category, [string] $Name) {
    $combined = "$Category $Name".ToLowerInvariant()
    if ($combined.Contains("security")) {
        return "security-ci"
    }
    if ($combined.Contains("ha-dr") -or $combined.Contains("dr") -or $combined.Contains("storage-expansion")) {
        return "kubernetes-live"
    }
    return "operator-remediation"
}

function Test-OperatorApprovalRequired([string[]] $Values) {
    $combined = ($Values -join " ").ToLowerInvariant()
    return (
        $combined.Contains("confirm") -or
        $combined.Contains("operator approval") -or
        $combined.Contains("run_live=true") -or
        $combined.Contains("publish=true") -or
        $combined.Contains("submit_evidence=true") -or
        $combined.Contains("-submitevidence")
    )
}

function Test-KubeconfigRequired([string] $Category, [string] $Name, [string[]] $Values) {
    $combined = ($Values -join " ").ToLowerInvariant()
    $identity = "$Category $Name".ToLowerInvariant()
    $kubernetesScoped = (
        $identity.Contains("kubernetes") -or
        $identity.Contains("ha-dr") -or
        $identity.Contains("storage-expansion") -or
        $combined.Contains("kubectl") -or
        $combined.Contains("kubernetes-") -or
        $combined.Contains("verify-kubernetes") -or
        $combined.Contains("finalize-kubernetes") -or
        $combined.Contains("storage-expansion-finalizer")
    )
    if (-not $kubernetesScoped) {
        return $false
    }
    return (
        $combined.Contains("osmu_kubeconfig_base64") -or
        $combined.Contains("kubectl") -or
        $combined.Contains("run_live=true") -or
        $combined.Contains("target cluster") -or
        $combined.Contains("kubernetes")
    )
}
function Get-PendingCategoryCounts([object[]] $Checks) {
    return @($Checks |
        Where-Object { -not $_.passed } |
        Group-Object category |
        Sort-Object Name |
        ForEach-Object {
            [ordered]@{
                category = $_.Name
                count = $_.Count
            }
        })
}

function Format-PendingCategorySummary([object[]] $CategoryCounts) {
    $summary = @($CategoryCounts | ForEach-Object { "$($_.category)=$($_.count)" }) -join ", "
    if ([string]::IsNullOrWhiteSpace($summary)) {
        return "none"
    }
    return $summary
}
function Get-WorkflowName([string] $Command) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return ""
    }
    $match = [regex]::Match($Command.Trim(), "^gh\s+workflow\s+run\s+([^\s]+)")
    if (-not $match.Success) {
        return ""
    }
    $workflow = $match.Groups[1].Value
    if ($workflow.Contains("/") -or $workflow.Contains("\")) {
        return [System.IO.Path]::GetFileName($workflow)
    }
    return $workflow
}

function Get-WorkflowFileName([string] $WorkflowPath, [string] $WorkflowCommand) {
    if (-not [string]::IsNullOrWhiteSpace($WorkflowPath)) {
        return [System.IO.Path]::GetFileName($WorkflowPath.Trim())
    }
    return Get-WorkflowName $WorkflowCommand
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

function Get-GitHubWorkflowDispatchUrl([string] $RepositorySlug, [string] $WorkflowName) {
    if ([string]::IsNullOrWhiteSpace($RepositorySlug) -or [string]::IsNullOrWhiteSpace($WorkflowName)) {
        return ""
    }
    return "https://github.com/$RepositorySlug/actions/workflows/$WorkflowName"
}

$resolvedReadinessReportPath = Resolve-ProjectPath $ReadinessReportPath
if (-not (Test-Path -LiteralPath $resolvedReadinessReportPath)) {
    throw "Operations readiness report not found: $resolvedReadinessReportPath"
}

$readiness = Read-Utf8Text $resolvedReadinessReportPath | ConvertFrom-Json
if ($readiness.formatVersion -ne "osmu.operations-readiness.v1") {
    throw "Unexpected operations readiness formatVersion: $($readiness.formatVersion)"
}

$githubRepositorySlug = Resolve-GitHubRepositorySlug $GitHubRepository
$actions = New-Object System.Collections.Generic.List[object]
$unplannedChecks = New-Object System.Collections.Generic.List[object]
$checks = @($readiness.checks)
$selectedChecks = if ($IncludePassed) { $checks } else { @($checks | Where-Object { -not $_.passed }) }
$order = 1

foreach ($check in $selectedChecks) {
    if ($check.passed -and -not $IncludePassed) {
        continue
    }

    $remediation = Get-JsonProperty $check "remediation"
    if ($null -eq $remediation) {
        if (-not $check.passed) {
            $unplannedChecks.Add([ordered]@{
                name = (Get-Text $check "name")
                category = (Get-Text $check "category")
                evidencePath = (Get-Text $check "evidencePath")
                requiredEvidence = (Get-Text $check "requiredEvidence")
                detail = (Get-Text $check "detail")
            })
        }
        continue
    }

    $command = Get-Text $remediation "command"
    $workflow = Get-Text $remediation "workflow"
    $workflowCommand = Get-Text $remediation "workflowCommand"
    $workflowName = Get-WorkflowFileName $workflow $workflowCommand
    $dispatchUrl = Get-GitHubWorkflowDispatchUrl $githubRepositorySlug $workflowName
    $note = Get-Text $remediation "note"
    $name = Get-Text $check "name"
    $category = Get-Text $check "category"
    $values = @(
        $command,
        $workflow,
        $workflowCommand,
        $note,
        (Get-Text $check "requiredEvidence"),
        (Get-Text $check "detail")
    )
    $placeholders = Get-Placeholders $values

    $actions.Add([ordered]@{
        order = $order
        name = $name
        category = $category
        actionType = (Get-ActionType $category $name)
        evidencePath = (Get-Text $check "evidencePath")
        requiredEvidence = (Get-Text $check "requiredEvidence")
        currentDetail = (Get-Text $check "detail")
        sourcePassed = [bool] $check.passed
        localCommand = $command
        workflow = $workflow
        workflowCommand = $workflowCommand
        dispatchUrl = $dispatchUrl
        recommendedCommand = if (-not [string]::IsNullOrWhiteSpace($workflowCommand)) { $workflowCommand } else { $command }
        operatorInputs = @($placeholders)
        hasPlaceholders = @($placeholders).Count -gt 0
        requiresOperatorApproval = (Test-OperatorApprovalRequired $values)
        requiresKubeconfigSecret = (Test-KubeconfigRequired $category $name $values)
        note = $note
    })
    $order++
}

$pendingCount = @($checks | Where-Object { -not $_.passed }).Count
$passedCount = @($checks | Where-Object { $_.passed }).Count
$sourcePassedCount = Get-IntOrDefault $readiness "passedCount" $passedCount
$sourcePendingCount = Get-IntOrDefault $readiness "pendingCount" $pendingCount
$sourceTotalCount = Get-IntOrDefault $readiness "totalCount" $checks.Count
$sourceCheckCount = Get-IntOrDefault $readiness "checkCount" $checks.Count
$sourcePendingRemediationCount = Get-IntOrDefault $readiness "pendingRemediationCount" $actions.Count
$sourcePendingRemediationNodes = Get-JsonProperty $readiness "pendingRemediations"
$sourcePendingRemediationEntryCount = if ($null -eq $sourcePendingRemediationNodes) { $sourcePendingRemediationCount } else { @($sourcePendingRemediationNodes).Count }
$actionCount = $actions.Count
$unplannedCount = $unplannedChecks.Count
$result = if ($pendingCount -eq 0) {
    "ready"
}
elseif ($actionCount -eq 0) {
    "no-remediation"
}
else {
    "action-required"
}

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
$actionArray = @($actions | ForEach-Object { $_ })
$unplannedCheckArray = @($unplannedChecks | ForEach-Object { $_ })
$sourcePendingRemediationActionCount = @($actionArray | Where-Object { -not $_.sourcePassed }).Count
$sourcePendingRemediationMissingActionCount = [Math]::Max(0, $sourcePendingRemediationCount - $sourcePendingRemediationActionCount)
$sourcePendingRemediationCoverageReady = (
    $sourcePendingRemediationCount -eq $sourcePendingRemediationEntryCount -and
    $sourcePendingRemediationCount -eq $sourcePendingRemediationActionCount -and
    ($sourcePendingRemediationCount + $unplannedCount) -eq $pendingCount
)
$pendingCategoryCounts = @(Get-PendingCategoryCounts $checks)
$pendingCategorySummary = Format-PendingCategorySummary $pendingCategoryCounts
$actionSummary = [ordered]@{
    totalActions = $actionCount
    kubernetesLiveActions = @($actionArray | Where-Object { $_.actionType -eq "kubernetes-live" }).Count
    securityCiActions = @($actionArray | Where-Object { $_.actionType -eq "security-ci" }).Count
    operatorRemediationActions = @($actionArray | Where-Object { $_.actionType -eq "operator-remediation" }).Count
    requiresOperatorApprovalCount = @($actionArray | Where-Object { $_.requiresOperatorApproval }).Count
    requiresKubeconfigSecretCount = @($actionArray | Where-Object { $_.requiresKubeconfigSecret }).Count
    actionsWithPlaceholdersCount = @($actionArray | Where-Object { $_.hasPlaceholders }).Count
    unplannedCheckCount = $unplannedCount
}
$report = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    generatedAt = $generatedAt
    result = $result
    sourceReport = $resolvedReadinessReportPath
    sourceResult = (Get-Text $readiness "result")
    sourceSummary = (Get-Text $readiness "summary")
    sourcePassedCount = $sourcePassedCount
    sourcePendingCount = $sourcePendingCount
    sourceTotalCount = $sourceTotalCount
    sourceCheckCount = $sourceCheckCount
    sourcePendingRemediationCount = $sourcePendingRemediationCount
    sourcePendingRemediationEntryCount = $sourcePendingRemediationEntryCount
    sourcePendingRemediationActionCount = $sourcePendingRemediationActionCount
    sourcePendingRemediationMissingActionCount = $sourcePendingRemediationMissingActionCount
    sourcePendingRemediationCoverageReady = $sourcePendingRemediationCoverageReady
    githubRepository = $githubRepositorySlug
    pendingCount = $pendingCount
    actionCount = $actionCount
    unplannedCount = $unplannedCount
    pendingCategorySummary = $pendingCategorySummary
    pendingCategoryCounts = $pendingCategoryCounts
    actionSummary = $actionSummary
    decisionRule = "Execute or import passing evidence for every pending operations readiness check, then regenerate operations readiness until result=ready."
    actions = $actionArray
    unplannedChecks = $unplannedCheckArray
}

$markdownLines = @(
    "# OSMU Operations Evidence Plan",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source report: $resolvedReadinessReportPath",
    "Source result: $($report.sourceResult)",
    "Source summary: $($report.sourceSummary)",
    "Source counts: passed=$sourcePassedCount pending=$sourcePendingCount total=$sourceTotalCount checks=$sourceCheckCount",
    "Source remediations: entries=$sourcePendingRemediationEntryCount actions=$sourcePendingRemediationActionCount missingActions=$sourcePendingRemediationMissingActionCount coverageReady=$sourcePendingRemediationCoverageReady",
    "",
    "## Action Summary",
    "",
    "- Total actions: $($actionSummary.totalActions)",
    "- By type: kubernetes-live=$($actionSummary.kubernetesLiveActions), security-ci=$($actionSummary.securityCiActions), operator-remediation=$($actionSummary.operatorRemediationActions)",
    "- Operator approval required: $($actionSummary.requiresOperatorApprovalCount)",
    "- Kubeconfig secret required: $($actionSummary.requiresKubeconfigSecretCount)",
    "- Actions with placeholders: $($actionSummary.actionsWithPlaceholdersCount)",
    "- Unplanned checks: $($actionSummary.unplannedCheckCount)",
    "- Pending categories: $pendingCategorySummary",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Execution Order",
    ""
)

if ($actionCount -eq 0) {
    $markdownLines += "- No remediation actions are required from the source report."
}
else {
    foreach ($action in $actions) {
        $approval = if ($action.requiresOperatorApproval) { "required" } else { "not required by plan" }
        $kubeconfig = if ($action.requiresKubeconfigSecret) { "required for live workflow/cluster evidence" } else { "not detected" }
        $inputs = if ($action.operatorInputs.Count -gt 0) { $action.operatorInputs -join ", " } else { "none" }
        $markdownLines += "- [$($action.order)] $($action.category) / $($action.name)"
        $markdownLines += "  - Evidence: $($action.requiredEvidence); path=$($action.evidencePath)"
        if (-not [string]::IsNullOrWhiteSpace($action.currentDetail)) {
            $markdownLines += "  - Current detail: $($action.currentDetail)"
        }
        if (-not [string]::IsNullOrWhiteSpace($action.recommendedCommand)) {
            $markdownLines += "  - Recommended command: ``$($action.recommendedCommand)``"
        }
        if (-not [string]::IsNullOrWhiteSpace($action.localCommand)) {
            $markdownLines += "  - Local command: ``$($action.localCommand)``"
        }
        if (-not [string]::IsNullOrWhiteSpace($action.workflow)) {
            $markdownLines += "  - Workflow: ``$($action.workflow)``"
        }
        if (-not [string]::IsNullOrWhiteSpace($action.workflowCommand)) {
            $markdownLines += "  - Workflow command: ``$($action.workflowCommand)``"
        }
        if (-not [string]::IsNullOrWhiteSpace($action.dispatchUrl)) {
            $markdownLines += "  - Web dispatch URL: $($action.dispatchUrl)"
        }
        $markdownLines += "  - Operator inputs: $inputs"
        $markdownLines += "  - Operator approval: $approval"
        $markdownLines += "  - Kubeconfig secret: $kubeconfig"
        if (-not [string]::IsNullOrWhiteSpace($action.note)) {
            $markdownLines += "  - Note: $($action.note)"
        }
    }
}

if ($unplannedCount -gt 0) {
    $markdownLines += ""
    $markdownLines += "## Unplanned Checks"
    $markdownLines += ""
    foreach ($check in $unplannedChecks) {
        $markdownLines += "- $($check.category) / $($check.name): $($check.requiredEvidence); path=$($check.evidencePath)"
    }
}

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations evidence plan JSON: $resolvedJsonOutputPath"
    Write-Host "Operations evidence plan markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)
