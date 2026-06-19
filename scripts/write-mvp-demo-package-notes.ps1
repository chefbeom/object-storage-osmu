param(
    [string] $DemoReadinessPath = ".\.osmu-run\latest-demo-readiness.json",
    [string] $DurableGateReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [string] $DurableFinalizeReportPath = ".\.osmu-run\latest-durable-mvp-finalize.json",
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $AuditPath = ".\.osmu-run\latest-mvp-audit.md",
    [string] $DecisionPath = ".\.osmu-run\latest-release-decision.md",
    [string] $ReleaseNotesPath = ".\.osmu-run\latest-release-notes.md",
    [string] $OperationsReadinessPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $CompletionReportPath = ".\.osmu-run\latest-mvp-completion.json",
    [string] $OutputPath = ".\.osmu-run\latest-demo-package-notes.md",
    [string] $Version = "MVP v0.1",
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
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
            detail = "missing"
        }
    }
    try {
        return [pscustomobject]@{
            label = $Label
            path = $resolved
            exists = $true
            parsed = $true
            json = (Get-Content -Raw -LiteralPath $resolved | ConvertFrom-Json)
            detail = "parsed"
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
            detail = "missing"
        }
    }
    return [pscustomobject]@{
        label = $Label
        path = $resolved
        exists = $true
        text = (Get-Content -Raw -LiteralPath $resolved)
        detail = "read"
    }
}

function Get-JsonText([object] $Object, [string] $Name, [string] $DefaultValue = "") {
    if ($null -eq $Object) {
        return $DefaultValue
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }
    return [string] $property.Value
}

function Evidence-Line([object] $Report, [string] $Summary) {
    $status = if ($Report.exists -and $Report.parsed) { "present" } elseif ($Report.exists) { "unreadable" } else { "missing" }
    return "- $($Report.label): $status; $Summary; path=$($Report.path)"
}

$demo = Read-OptionalJson $DemoReadinessPath "Demo readiness"
$durableGate = Read-OptionalJson $DurableGateReportPath "Durable gate"
$durableFinalize = Read-OptionalJson $DurableFinalizeReportPath "Durable finalizer"
$release = Read-OptionalJson $ReleaseReportPath "Release report"
$operations = Read-OptionalJson $OperationsReadinessPath "Operations readiness"
$completion = Read-OptionalJson $CompletionReportPath "MVP completion"
$audit = Read-OptionalText $AuditPath "MVP audit"
$decision = Read-OptionalText $DecisionPath "MVP release decision"
$releaseNotes = Read-OptionalText $ReleaseNotesPath "MVP release notes"

$demoReady = $demo.parsed -and (Get-JsonText $demo.json "result") -eq "ready" -and (Get-JsonText $demo.json "currentDemoStatus") -eq "docker-durable-demo-verified"
$durableGateReady = $durableGate.parsed -and (Get-JsonText $durableGate.json "result") -eq "ready" -and (Get-JsonText $durableGate.json "currentDemoStatus") -eq "docker-durable-demo-verified"
$releasePassed = $release.parsed -and (Get-JsonText $release.json "result") -eq "passed"
$decisionGo = $decision.exists -and $decision.text.Contains("- Durable MVP pilot: GO")
$localReady = $demoReady -or ($durableGateReady -and $releasePassed -and $decisionGo)
$packageStatus = if ($localReady) { "local-durable-mvp-ready" } else { "local-durable-mvp-pending" }

$releaseApiBase = Get-JsonText $release.json "apiBase" "http://localhost:8080/api"
$releaseFrontendBase = Get-JsonText $release.json "frontendBase" "http://localhost:5173"
$selectedS3Client = Get-JsonText $release.json "selectedS3Client" (Get-JsonText $durableGate.json "selectedS3Client" "docker-mc")
$operationsResult = Get-JsonText $operations.json "result" "missing"
$operationsSummary = Get-JsonText $operations.json "summary" $operations.detail
$completionResult = Get-JsonText $completion.json "result" "missing"
$completionClass = Get-JsonText $completion.json "classification" "missing"

$notesLines = @(
    "# OSMU $Version Demo Package Notes",
    "",
    "Generated at: $([DateTimeOffset]::Now.ToString("o"))",
    "Package status: $packageStatus",
    "",
    "## S3 Replacement Boundary",
    "",
    "OSMU targets replacement use for common S3 clients and SDKs. It is not AWS S3 full behavioral parity; only bucket/object CRUD, multipart, copy, tagging, lifecycle XML subset, SigV4, presigned URL, and basic checksum flows proven by supported smoke tests should be presented as supported.",
    "",
    "## Runtime",
    "",
    "- Frontend: $releaseFrontendBase",
    "- Backend API: $releaseApiBase",
    "- Selected S3 smoke client: $selectedS3Client",
    '- Demo credentials: use `.osmu-run/latest-demo.json` from the generated local evidence; do not commit runtime secrets.',
    "",
    "## Required Evidence Bundle",
    "",
    (Evidence-Line $demo "result=$(Get-JsonText $demo.json "result"), currentDemoStatus=$(Get-JsonText $demo.json "currentDemoStatus")"),
    (Evidence-Line $durableGate "result=$(Get-JsonText $durableGate.json "result"), currentDemoStatus=$(Get-JsonText $durableGate.json "currentDemoStatus"), selectedS3Client=$(Get-JsonText $durableGate.json "selectedS3Client")"),
    (Evidence-Line $durableFinalize "result=$(Get-JsonText $durableFinalize.json "result"), currentDemoStatus=$(Get-JsonText $durableFinalize.json "currentDemoStatus")"),
    (Evidence-Line $release "result=$(Get-JsonText $release.json "result"), source=$(Get-JsonText $release.json "source")"),
    "- MVP audit: $(if ($audit.exists) { "present" } else { "missing" }); path=$($audit.path)",
    "- MVP release decision: $(if ($decision.exists) { "present" } else { "missing" }); durableDecision=$(if ($decisionGo) { "GO" } else { "NO-GO-or-missing" }); path=$($decision.path)",
    "- MVP release notes: $(if ($releaseNotes.exists) { "present" } else { "missing" }); path=$($releaseNotes.path)",
    "- MVP completion: result=$completionResult, classification=$completionClass; path=$($completion.path)",
    "- Operations readiness: result=$operationsResult, summary=$operationsSummary; path=$($operations.path)",
    "",
    "## Rebuild Commands",
    "",
    '```powershell',
    "powershell -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -S3Client docker-mc",
    "powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-completion.ps1 -FailIfLocalMvpNotReady",
    "powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-demo-package-notes.ps1",
    '```',
    "",
    "## Pilot Attachment Checklist",
    "",
    '- Attach `.osmu-run/latest-release.json`.',
    '- Attach `.osmu-run/latest-mvp-audit.md`.',
    '- Attach `.osmu-run/latest-release-decision.md`.',
    '- Attach `.osmu-run/latest-release-notes.md`.',
    '- Attach `.osmu-run/latest-demo-package-notes.md`.',
    "- Attach durable gate/finalizer/readiness JSON and Markdown reports when available.",
    "- Attach operations readiness, image signing, container scan/SBOM, and security finalizer evidence for hosted or production pilot review.",
    "",
    "## Go/No-Go Reminder",
    "",
    '- Local durable MVP demo: GO only when package status is `local-durable-mvp-ready` and release decision marks `Durable MVP pilot: GO`.',
    "- Hosted or production pilot: still requires GitHub-hosted workflow evidence, signed-image evidence, container scan/SBOM evidence, and operations readiness finalizers.",
    '- S3 support claims must stay within the replacement boundary above and the matrix in `dev-docs/s3-compatibility.md`.'
)

$notes = $notesLines -join [Environment]::NewLine

if (-not $NoWrite) {
    $resolvedOutputPath = Resolve-ProjectPath $OutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
    Set-Content -LiteralPath $resolvedOutputPath -Value $notes -Encoding UTF8
    Write-Host "MVP demo package notes: $resolvedOutputPath"
}

Write-Host $notes
