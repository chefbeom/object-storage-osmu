param(
    [string] $DemoReadinessPath = ".\.osmu-run\latest-demo-readiness.json",
    [string] $DurableGateReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [string] $DurableFinalizeReportPath = ".\.osmu-run\latest-durable-mvp-finalize.json",
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $AuditPath = ".\.osmu-run\latest-mvp-audit.md",
    [string] $DecisionPath = ".\.osmu-run\latest-release-decision.md",
    [string] $ReleaseNotesPath = ".\.osmu-run\latest-release-notes.md",
    [string] $DemoPackageNotesPath = ".\.osmu-run\latest-demo-package-notes.md",
    [string] $OperationsReadinessPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-mvp-completion.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-mvp-completion.md",
    [switch] $FailIfLocalMvpNotReady,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()

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

function Read-OptionalJson([string] $PathValue, [string] $Label) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        return [pscustomobject]@{
            label = $Label
            path = $resolved
            exists = $false
            parsed = $false
            json = $null
            detail = "report not found"
        }
    }
    try {
        return [pscustomobject]@{
            label = $Label
            path = $resolved
            exists = $true
            parsed = $true
            json = (Get-Content -Raw -LiteralPath $resolved | ConvertFrom-Json)
            detail = "report parsed"
        }
    }
    catch {
        return [pscustomobject]@{
            label = $Label
            path = $resolved
            exists = $true
            parsed = $false
            json = $null
            detail = $_.Exception.Message
        }
    }
}

function Read-OptionalText([string] $PathValue, [string] $Label) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        return [pscustomobject]@{
            label = $Label
            path = $resolved
            exists = $false
            text = ""
            detail = "file not found"
        }
    }
    return [pscustomobject]@{
        label = $Label
        path = $resolved
        exists = $true
        text = (Get-Content -Raw -LiteralPath $resolved)
        detail = "file read"
    }
}

function Add-Check(
    [string] $Name,
    [string] $Category,
    [bool] $Passed,
    [string] $Detail,
    [string] $EvidencePath = "",
    [bool] $RequiredForLocalMvp = $true
) {
    $script:checks += [ordered]@{
        name = $Name
        category = $Category
        status = if ($Passed) { "PASS" } else { "PENDING" }
        passed = $Passed
        detail = $Detail
        evidencePath = $EvidencePath
        requiredForLocalMvp = $RequiredForLocalMvp
    }
}

function Test-Contains([object] $TextReport, [string] $Expected) {
    return $TextReport.exists -and $TextReport.text.Contains($Expected)
}

function Test-NotContains([object] $TextReport, [string] $Unexpected) {
    return $TextReport.exists -and -not $TextReport.text.Contains($Unexpected)
}

$demo = Read-OptionalJson $DemoReadinessPath "MVP demo readiness"
$durableGate = Read-OptionalJson $DurableGateReportPath "Durable demo gate"
$durableFinalize = Read-OptionalJson $DurableFinalizeReportPath "Durable MVP finalizer"
$release = Read-OptionalJson $ReleaseReportPath "MVP release report"
$operations = Read-OptionalJson $OperationsReadinessPath "Production operations readiness"
$audit = Read-OptionalText $AuditPath "MVP audit"
$decision = Read-OptionalText $DecisionPath "MVP release decision"
$releaseNotes = Read-OptionalText $ReleaseNotesPath "MVP release notes"
$demoPackageNotes = Read-OptionalText $DemoPackageNotesPath "MVP demo package notes"
$featureInventory = Read-OptionalText ".\dev-docs\feature-inventory.md" "Feature inventory"
$prototypeStatus = Read-OptionalText ".\dev-docs\prototype-status.md" "Prototype status"
$releaseChecklist = Read-OptionalText ".\dev-docs\mvp-release-checklist.md" "MVP release checklist"
$documentIndex = Read-OptionalText ".\dev-docs\document-index.md" "Document index"

$demoStatus = Get-Text $demo.json "currentDemoStatus"
$demoResult = Get-Text $demo.json "result"
$demoCompletion = Get-JsonProperty $demo.json "completionEstimate"
$demoMvpEstimate = Get-Text $demoCompletion "mvpDemo"
$pendingDurableChecks = @()
if ($demo.exists -and $demo.parsed) {
    $pendingDurableChecks = @(Get-JsonProperty $demo.json "pendingDurableChecks")
}

Add-Check "Demo readiness report ready" "local-mvp" ($demo.exists -and $demo.parsed -and $demoResult -eq "ready" -and $demoStatus -eq "docker-durable-demo-verified") "result=$demoResult, currentDemoStatus=$demoStatus, mvpDemo=$demoMvpEstimate" $demo.path
Add-Check "No pending durable checks" "local-mvp" ($demo.exists -and $demo.parsed -and @($pendingDurableChecks).Count -eq 0) "pendingDurableChecks=$(@($pendingDurableChecks).Count)" $demo.path
Add-Check "Durable demo gate ready" "local-mvp" ($durableGate.exists -and $durableGate.parsed -and (Get-Text $durableGate.json "result") -eq "ready" -and (Get-Text $durableGate.json "currentDemoStatus") -eq "docker-durable-demo-verified") "result=$(Get-Text $durableGate.json "result"), currentDemoStatus=$(Get-Text $durableGate.json "currentDemoStatus"), selectedS3Client=$(Get-Text $durableGate.json "selectedS3Client")" $durableGate.path
Add-Check "Durable MVP finalizer ready" "local-mvp" ($durableFinalize.exists -and $durableFinalize.parsed -and (Get-Text $durableFinalize.json "result") -eq "ready" -and (Get-Text $durableFinalize.json "currentDemoStatus") -eq "docker-durable-demo-verified") "result=$(Get-Text $durableFinalize.json "result"), currentDemoStatus=$(Get-Text $durableFinalize.json "currentDemoStatus")" $durableFinalize.path
Add-Check "Release report passed" "release-artifact" ($release.exists -and $release.parsed -and (Get-Text $release.json "result") -eq "passed") "result=$(Get-Text $release.json "result"), source=$(Get-Text $release.json "source")" $release.path
Add-Check "Audit marks durable and frontend evidence passed" "release-artifact" ((Test-Contains $audit "- PASS: Durable MVP demo gate") -and (Test-Contains $audit "- PASS: Frontend portal checks") -and (Test-Contains $audit "Browser click E2E passed") -and (Test-NotContains $audit "Browser click E2E pending")) "audit durable/frontend/browser status checked" $audit.path
Add-Check "Release decision marks durable MVP pilot GO" "release-artifact" (Test-Contains $decision "- Durable MVP pilot: GO") "durable MVP pilot decision line checked" $decision.path
Add-Check "Release notes preserve durable proof" "release-artifact" ((Test-Contains $releaseNotes "Durable MVP demo gate report: result=ready") -and (Test-Contains $releaseNotes "local durable MVP demo evidence")) "durable proof release note checked" $releaseNotes.path
Add-Check "Demo package notes preserve pilot handoff" "release-artifact" ((Test-Contains $demoPackageNotes "Package status: local-durable-mvp-ready") -and (Test-Contains $demoPackageNotes "S3 Replacement Boundary") -and (Test-Contains $demoPackageNotes "dev-docs/s3-compatibility.md")) "demo package handoff checked" $demoPackageNotes.path
Add-Check "Feature inventory local MVP state current" "documentation" ((Test-Contains $featureInventory "MVP demo current estimate: 90-95%") -and (Test-Contains $featureInventory "docker-durable-demo-verified") -and (Test-Contains $featureInventory "readiness-ready/finalizer-missing")) "feature inventory local MVP status checked" $featureInventory.path
Add-Check "Prototype status local MVP state current" "documentation" ((Test-Contains $prototypeStatus "docker-durable-demo-verified") -and (Test-NotContains $prototypeStatus "full Docker runtime verification is still pending")) "prototype status stale blocker check" $prototypeStatus.path
Add-Check "Release checklist local durable decision current" "documentation" ((Test-Contains $releaseChecklist "GO for local durable MVP demo") -and (Test-Contains $releaseChecklist 'operations readiness finalizer report exists with `result=ready` and `readinessResult=ready`') -and (Test-NotContains $releaseChecklist "NO-GO until every durable gate above passes")) "release checklist durable and convergence gate checked" $releaseChecklist.path
Add-Check "Document index operations convergence current" "documentation" ((Test-Contains $documentIndex "Kubernetes operations report sync reports") -and (Test-Contains $documentIndex "finalizer/sync gates") -and (Test-Contains $documentIndex "action-required, finalizer-required, sync-required")) "document index operations convergence checked" $documentIndex.path

$operationsResult = if ($operations.exists -and $operations.parsed) { Get-Text $operations.json "result" } else { "missing" }
$operationsSummary = if ($operations.exists -and $operations.parsed) { Get-Text $operations.json "summary" } else { $operations.detail }
Add-Check "Production operations readiness tracked separately" "production-readiness" ($operations.exists -and $operations.parsed) "result=$operationsResult, summary=$operationsSummary" $operations.path $false

$localRequiredChecks = @($checks | Where-Object { $_.requiredForLocalMvp })
$localPendingChecks = @($localRequiredChecks | Where-Object { -not $_.passed })
$productionChecks = @($checks | Where-Object { -not $_.requiredForLocalMvp })
$productionPendingChecks = @($productionChecks | Where-Object { -not $_.passed -or $_.detail -notmatch "result=ready" })
$localReady = $localPendingChecks.Count -eq 0
$result = if ($localReady) { "ready" } else { "pending" }
$classification = if ($localReady) { "local-durable-mvp-ready" } else { "local-durable-mvp-pending" }
$generatedAt = [DateTimeOffset]::Now.ToString("o")

$report = [ordered]@{
    formatVersion = "osmu.mvp-completion.v1"
    generatedAt = $generatedAt
    result = $result
    classification = $classification
    localDurableMvpReady = [bool] $localReady
    productionReadinessResult = $operationsResult
    productionReadinessSummary = $operationsSummary
    localRequiredCheckCount = $localRequiredChecks.Count
    localPendingCheckCount = $localPendingChecks.Count
    productionCheckCount = $productionChecks.Count
    productionPendingCheckCount = $productionPendingChecks.Count
    demoReadinessPath = $demo.path
    durableGateReportPath = $durableGate.path
    durableFinalizeReportPath = $durableFinalize.path
    releaseReportPath = $release.path
    auditPath = $audit.path
    decisionPath = $decision.path
    releaseNotesPath = $releaseNotes.path
    demoPackageNotesPath = $demoPackageNotes.path
    operationsReadinessPath = $operations.path
    checks = $checks
    decisionRule = "Local durable MVP completion is ready only when durable demo readiness, durable gate, durable finalizer, release artifacts, and key status documents all agree on docker-durable-demo-verified with no local durable pending checks. Production/B2B operations readiness is reported separately and does not block local MVP demo completion."
}

$markdownLines = @(
    "# OSMU MVP Completion",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Classification: $classification",
    "Local durable MVP ready: $localReady",
    "Production readiness: $operationsResult ($operationsSummary)",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Checks",
    ""
)

foreach ($check in $checks) {
    $requiredText = if ($check.requiredForLocalMvp) { "local-mvp" } else { "separate-production" }
    $markdownLines += "- [$($check.status)] $($check.category) / $($check.name) ($requiredText): $($check.detail)"
}

if ($localPendingChecks.Count -gt 0) {
    $markdownLines += ""
    $markdownLines += "## Local MVP Pending"
    $markdownLines += ""
    foreach ($check in $localPendingChecks) {
        $markdownLines += "- $($check.name): $($check.detail)"
    }
}

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "MVP completion JSON: $resolvedJsonOutputPath"
    Write-Host "MVP completion markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfLocalMvpNotReady -and -not $localReady) {
    throw "Local durable MVP completion is not ready: localPendingCheckCount=$($localPendingChecks.Count)"
}
