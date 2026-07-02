param(
    [string] $OutputPath = ".\.osmu-run\latest-demo-package-notes.md",
    [switch] $SelfTest
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}
function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
}

function Write-JsonFixture([string] $Path, [object] $Value) {
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Label) {
    if (-not $Text.Contains($Expected)) {
        throw "$Label does not contain expected text: $Expected"
    }
}

if ($SelfTest) {
    $selfTestDir = Join-Path $root ".osmu-run\demo-package-notes-self-test"
    New-Item -ItemType Directory -Force -Path $selfTestDir | Out-Null

    $demoPath = Join-Path $selfTestDir "demo-readiness.json"
    $durableGatePath = Join-Path $selfTestDir "durable-gate.json"
    $durableFinalizePath = Join-Path $selfTestDir "durable-finalize.json"
    $releasePath = Join-Path $selfTestDir "release.json"
    $auditPath = Join-Path $selfTestDir "audit.md"
    $decisionPath = Join-Path $selfTestDir "decision.md"
    $releaseNotesPath = Join-Path $selfTestDir "release-notes.md"
    $operationsPath = Join-Path $selfTestDir "operations-readiness.json"
    $completionPath = Join-Path $selfTestDir "completion.json"
    $OutputPath = Join-Path $selfTestDir "latest-demo-package-notes.md"

    Write-JsonFixture $demoPath ([ordered]@{
        result = "ready"
        currentDemoStatus = "docker-durable-demo-verified"
    })
    Write-JsonFixture $durableGatePath ([ordered]@{
        result = "ready"
        currentDemoStatus = "docker-durable-demo-verified"
        selectedS3Client = "docker-mc"
    })
    Write-JsonFixture $durableFinalizePath ([ordered]@{
        result = "ready"
        currentDemoStatus = "docker-durable-demo-verified"
    })
    Write-JsonFixture $releasePath ([ordered]@{
        result = "passed"
        source = "durable-demo-gate"
        apiBase = "http://localhost:8080/api"
        frontendBase = "http://localhost:5173"
        selectedS3Client = "docker-mc"
    })
    Set-Content -LiteralPath $auditPath -Encoding UTF8 -Value "# Audit`n- PASS: Durable MVP demo gate"
    Set-Content -LiteralPath $decisionPath -Encoding UTF8 -Value "# Decision`n- Durable MVP pilot: GO"
    Set-Content -LiteralPath $releaseNotesPath -Encoding UTF8 -Value "# Notes`n- Durable MVP demo gate report: result=ready"
    Write-JsonFixture $operationsPath ([ordered]@{
        result = "pending"
        summary = "passed=36 pending=6"
    })
    Write-JsonFixture $completionPath ([ordered]@{
        result = "ready"
        classification = "local-durable-mvp-ready"
    })

    & (Join-Path $PSScriptRoot "write-mvp-demo-package-notes.ps1") `
        -DemoReadinessPath $demoPath `
        -DurableGateReportPath $durableGatePath `
        -DurableFinalizeReportPath $durableFinalizePath `
        -ReleaseReportPath $releasePath `
        -AuditPath $auditPath `
        -DecisionPath $decisionPath `
        -ReleaseNotesPath $releaseNotesPath `
        -OperationsReadinessPath $operationsPath `
        -CompletionReportPath $completionPath `
        -OutputPath $OutputPath | Out-Host
}

$resolvedOutputPath = Resolve-ProjectPath $OutputPath
if (-not (Test-Path -LiteralPath $resolvedOutputPath)) {
    throw "Demo package notes were not written: $resolvedOutputPath"
}

$notes = Read-Utf8Text $resolvedOutputPath
Assert-Contains $notes "# OSMU MVP v0.1 Demo Package Notes" "demo package notes"
Assert-Contains $notes "Package status:" "demo package notes"
Assert-Contains $notes "It is not AWS S3 full behavioral parity" "demo package notes"
Assert-Contains $notes "Durable gate:" "demo package notes"
Assert-Contains $notes "Operations readiness:" "demo package notes"
Assert-Contains $notes "finalize-durable-mvp-demo.ps1 -S3Client docker-mc" "demo package notes"
Assert-Contains $notes ".osmu-run/latest-demo-package-notes.md" "demo package notes"
Assert-Contains $notes "dev-docs/s3-compatibility.md" "demo package notes"

if ($notes.Contains("MVP completion: result=pending") -or $notes.Contains("classification=local-durable-mvp-pending")) {
    Assert-Contains $notes "Package status: local-durable-mvp-pending" "demo package notes"
}
if ($notes.Contains("MVP completion: result=ready") -and $notes.Contains("classification=local-durable-mvp-ready")) {
    Assert-Contains $notes "Package status: local-durable-mvp-ready" "demo package notes"
}

if ($SelfTest) {
    Assert-Contains $notes "Package status: local-durable-mvp-ready" "demo package notes"
    Assert-Contains $notes "Durable gate: present; result=ready" "demo package notes"
    Assert-Contains $notes "Operations readiness: result=pending, summary=passed=36 pending=6" "demo package notes"

    $pendingCompletionPath = Join-Path $selfTestDir "completion-pending.json"
    $pendingOutputPath = Join-Path $selfTestDir "latest-demo-package-notes-pending.md"
    Write-JsonFixture $pendingCompletionPath ([ordered]@{
        result = "pending"
        classification = "local-durable-mvp-pending"
    })
    & (Join-Path $PSScriptRoot "write-mvp-demo-package-notes.ps1") `
        -DemoReadinessPath $demoPath `
        -DurableGateReportPath $durableGatePath `
        -DurableFinalizeReportPath $durableFinalizePath `
        -ReleaseReportPath $releasePath `
        -AuditPath $auditPath `
        -DecisionPath $decisionPath `
        -ReleaseNotesPath $releaseNotesPath `
        -OperationsReadinessPath $operationsPath `
        -CompletionReportPath $pendingCompletionPath `
        -OutputPath $pendingOutputPath | Out-Host
    $pendingNotes = Read-Utf8Text $pendingOutputPath
    Assert-Contains $pendingNotes "Package status: local-durable-mvp-pending" "pending demo package notes"
    Assert-Contains $pendingNotes "MVP completion: result=pending, classification=local-durable-mvp-pending" "pending demo package notes"
    Write-Host "MVP demo package notes self-test passed."
} else {
    Write-Host "MVP demo package notes verified: $resolvedOutputPath"
}
