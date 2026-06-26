param(
    [string] $StatusPath = ".\dev-docs\prototype-status.md",
    [string] $MvpCompletionReportPath = ".\.osmu-run\latest-mvp-completion.json",
    [string] $OperationsReadinessReportPath = ".\.osmu-run\latest-operations-readiness.json",
    [switch] $RequireEvidenceReports
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-Contains([string] $Content, [string] $Expected, [string] $Label) {
    if (-not $Content.Contains($Expected)) {
        throw "$Label does not contain expected text: $Expected"
    }
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-NotContains([string] $Content, [string] $Unexpected, [string] $Label) {
    if ($Content.Contains($Unexpected)) {
        throw "$Label contains unexpected text: $Unexpected"
    }
}

function Assert-OccurrenceCount([string] $Content, [string] $Expected, [int] $Count, [string] $Label) {
    $actual = ([regex]::Matches($Content, [regex]::Escape($Expected))).Count
    if ($actual -ne $Count) {
        throw "$Label contains '$Expected' $actual time(s), expected $Count."
    }
}

function Read-OptionalJsonReport([string] $PathValue, [string] $Label) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        if ($RequireEvidenceReports) {
            throw "$Label missing: $resolved"
        }
        return $null
    }

    try {
        return [pscustomobject]@{
            path = $resolved
            data = Get-Content -Raw -LiteralPath $resolved | ConvertFrom-Json
        }
    }
    catch {
        throw "$Label could not be parsed as JSON: $resolved. $($_.Exception.Message)"
    }
}

function Format-BoolLower([object] $Value) {
    if ($Value -eq $true) {
        return "true"
    }
    if ($Value -eq $false) {
        return "false"
    }
    return [string] $Value
}

$resolvedPath = Resolve-ProjectPath $StatusPath
if (-not (Test-Path -LiteralPath $resolvedPath)) {
    throw "Prototype status missing: $resolvedPath"
}

$content = Get-Content -Raw -LiteralPath $resolvedPath

Assert-Contains $content "OSMU Prototype Status" "Prototype status"
Assert-Contains $content "Last updated: 2026-06-23 KST" "Prototype status"
Assert-Contains $content "Local durable MVP: ready" "Prototype status"
Assert-Contains $content 'docker-durable-demo-verified' "Prototype status"
Assert-Contains $content "MVP demo estimate: 90-95%" "Prototype status"
Assert-Contains $content "Production/B2B readiness: pending target evidence" "Prototype status"
Assert-Contains $content "S3 compatibility role: replacement layer, not AWS edge parity" "Prototype status"
Assert-Contains $content "S3-compatible replacement layer" "Prototype status"
Assert-Contains $content "Latest Verification Snapshot" "Prototype status"
Assert-Contains $content "Snapshot date: 2026-06-23 KST" "Prototype status"
Assert-Contains $content "MVP completion latest verification: result=ready, classification=local-durable-mvp-ready, localDurableMvpReady=true." "Prototype status"
Assert-Contains $content "Operations readiness latest verification: result=pending, passed=67, pending=16, total=83." "Prototype status"
Assert-Contains $content "S3 boundary latest verification: verify-s3-compatibility-boundary.ps1 passed." "Prototype status"
Assert-Contains $content "B2B product estimate remains about 45%" "Prototype status"
Assert-Contains $content "do not expand AWS S3 parity unless a supported replacement-client smoke or migration blocker proves product impact" "Prototype status"
Assert-Contains $content "Enterprise auth implemented locally" "Prototype status"
Assert-Contains $content "OIDC callback" "Prototype status"
Assert-Contains $content "LDAP bind/search" "Prototype status"
Assert-Contains $content "admin-approved JIT" "Prototype status"
Assert-Contains $content "Data-flow analytics implemented locally" "Prototype status"
Assert-Contains $content "daily/materialized/monthly/stored monthly" "Prototype status"
Assert-Contains $content "target query-plan evidence" "Prototype status"
Assert-Contains $content "Operations evidence chain implemented locally" "Prototype status"
Assert-Contains $content "storage backend telemetry" "Prototype status"
Assert-Contains $content "monitoring threshold" "Prototype status"
Assert-Contains $content "secret rotation" "Prototype status"
Assert-Contains $content "commercial integration" "Prototype status"
Assert-Contains $content "commercial approval" "Prototype status"
Assert-Contains $content "operations handoff package" "Prototype status"
Assert-Contains $content "readiness convergence" "Prototype status"
Assert-Contains $content "Kubernetes operations report sync" "Prototype status"
Assert-Contains $content "Next Best Work" "Prototype status"
Assert-Contains $content "Production operations evidence chain" "Prototype status"
Assert-Contains $content "monitoring threshold" "Prototype status"
Assert-Contains $content "Data-flow storage transition plan" "Prototype status"
Assert-Contains $content "Commercial integration/approval target evidence" "Prototype status"
Assert-Contains $content "S3 replacement layer" "Prototype status"
Assert-NotContains $content "Last updated: 2026-06-18" "Prototype status"
Assert-NotContains $content "Last updated: 2026-06-21" "Prototype status"
Assert-NotContains $content "full Docker runtime verification is still pending" "Prototype status"
Assert-NotContains $content "Current sellable state: local lightweight demo only" "Prototype status"
Assert-NotContains $content "SSO/LDAP, final billing/licensing approval" "Prototype status"
Assert-NotContains $content "Backup/replication, production monitoring/alert validation, SSO/LDAP" "Prototype status"
Assert-OccurrenceCount $content "- Commercial readiness: B2B positioning, pilot packaging, licensing, and pricing draft with final approval still pending." 0 "Prototype status"

$mvpCompletion = Read-OptionalJsonReport $MvpCompletionReportPath "MVP completion report"
if ($null -ne $mvpCompletion) {
    $mvp = $mvpCompletion.data
    Assert-True ($mvp.formatVersion -eq "osmu.mvp-completion.v1") "Unexpected MVP completion formatVersion in $($mvpCompletion.path)."
    Assert-True ($mvp.result -eq "ready") "Prototype status expects MVP completion result=ready, but report has result=$($mvp.result)."
    Assert-True ($mvp.classification -eq "local-durable-mvp-ready") "Prototype status expects classification=local-durable-mvp-ready, but report has classification=$($mvp.classification)."
    Assert-True ($mvp.localDurableMvpReady -eq $true) "Prototype status expects localDurableMvpReady=true."

    $expectedMvpLine = "MVP completion latest verification: result=$($mvp.result), classification=$($mvp.classification), localDurableMvpReady=$(Format-BoolLower $mvp.localDurableMvpReady)."
    Assert-Contains $content $expectedMvpLine "Prototype status"
}

$operationsReadiness = Read-OptionalJsonReport $OperationsReadinessReportPath "Operations readiness report"
if ($null -ne $operationsReadiness) {
    $operations = $operationsReadiness.data
    $checks = @($operations.checks)
    Assert-True ($operations.formatVersion -eq "osmu.operations-readiness.v1") "Unexpected operations readiness formatVersion in $($operationsReadiness.path)."
    Assert-True ($operations.result -eq "pending") "Prototype status expects operations readiness result=pending, but report has result=$($operations.result)."
    Assert-True ($operations.summary -eq "passed=$($operations.passedCount) pending=$($operations.pendingCount)") "Operations readiness summary does not match passed/pending counts."
    Assert-True (($operations.passedCount + $operations.pendingCount) -eq $checks.Count) "Operations readiness passed+pending count does not match check count."

    $expectedOperationsLine = "Operations readiness latest verification: result=$($operations.result), passed=$($operations.passedCount), pending=$($operations.pendingCount), total=$($checks.Count)."
    Assert-Contains $content $expectedOperationsLine "Prototype status"
}

Write-Host "Prototype status verified."
Write-Host "Prototype status: $resolvedPath"
