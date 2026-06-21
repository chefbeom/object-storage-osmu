param(
    [string] $ReadinessReportPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-evidence-plan.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-evidence-plan.md",
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

$resolvedReadinessReportPath = Resolve-ProjectPath $ReadinessReportPath
if (-not (Test-Path -LiteralPath $resolvedReadinessReportPath)) {
    throw "Operations readiness report not found: $resolvedReadinessReportPath"
}

$readiness = Get-Content -Raw -LiteralPath $resolvedReadinessReportPath | ConvertFrom-Json
if ($readiness.formatVersion -ne "osmu.operations-readiness.v1") {
    throw "Unexpected operations readiness formatVersion: $($readiness.formatVersion)"
}

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
        localCommand = $command
        workflow = $workflow
        workflowCommand = $workflowCommand
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
$report = [ordered]@{
    formatVersion = "osmu.operations-evidence-plan.v1"
    generatedAt = $generatedAt
    result = $result
    sourceReport = $resolvedReadinessReportPath
    sourceResult = (Get-Text $readiness "result")
    sourceSummary = (Get-Text $readiness "summary")
    pendingCount = $pendingCount
    actionCount = $actionCount
    unplannedCount = $unplannedCount
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
        if (-not [string]::IsNullOrWhiteSpace($action.localCommand)) {
            $markdownLines += "  - Local command: ``$($action.localCommand)``"
        }
        if (-not [string]::IsNullOrWhiteSpace($action.workflow)) {
            $markdownLines += "  - Workflow: ``$($action.workflow)``"
        }
        if (-not [string]::IsNullOrWhiteSpace($action.workflowCommand)) {
            $markdownLines += "  - Workflow command: ``$($action.workflowCommand)``"
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
