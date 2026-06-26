param(
    [string] $RoadmapPath = ".\dev-docs\development-roadmap.md",
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

function Decode-Utf8Base64([string] $Value) {
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
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

$resolvedPath = Resolve-ProjectPath $RoadmapPath
if (-not (Test-Path -LiteralPath $resolvedPath)) {
    throw "Development roadmap missing: $resolvedPath"
}

$content = [System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8)

Assert-Contains $content "OSMU Development Roadmap" "Development roadmap"
Assert-Contains $content (Decode-Utf8Base64 "7J6R7ISx7J28OiAyMDI2LTA2LTIzIEtTVA==") "Development roadmap"
Assert-Contains $content (Decode-Utf8Base64 "6riw7KSAIHNuYXBzaG90OiAyMDI2LTA2LTIzIEtTVC4=") "Development roadmap"
Assert-Contains $content "S3-compatible replacement layer" "Development roadmap"
Assert-Contains $content 'docker-durable-demo-verified' "Development roadmap"
Assert-Contains $content "MVP completion latest verification: result=ready, classification=local-durable-mvp-ready, localDurableMvpReady=true." "Development roadmap"
Assert-Contains $content "Operations readiness latest verification: result=pending, passed=65, pending=15, total=80." "Development roadmap"
Assert-Contains $content "S3 boundary latest verification: verify-s3-compatibility-boundary.ps1 passed." "Development roadmap"
Assert-Contains $content "Production Operations Evidence" "Development roadmap"
Assert-Contains $content (Decode-Utf8Base64 "S3ViZXJuZXRlcyBEUiBmaW5hbGl6ZXIgYHJlc3VsdD1yZWFkeWA=") "Development roadmap"
Assert-Contains $content 'security evidence finalizer `result=passed`' "Development roadmap"
Assert-Contains $content 'IAM/RBAC finalizer `result=passed`' "Development roadmap"
Assert-NotContains $content 'security evidence finalizer `result=ready`' "Development roadmap"
Assert-NotContains $content 'IAM/RBAC finalizer `result=ready`' "Development roadmap"
Assert-Contains $content 'operations readiness convergence `result=ready`' "Development roadmap"
Assert-Contains $content 'Kubernetes operations report sync `result=applied`' "Development roadmap"
Assert-Contains $content "Data-flow storage transition plan" "Development roadmap"
Assert-Contains $content "target query latency" "Development roadmap"
Assert-Contains $content "data-flow query/retention budget evidence writer" "Development roadmap"
Assert-Contains $content "write-data-flow-query-retention-budget-evidence.ps1" "Development roadmap"
Assert-Contains $content "target query-plan evidence" "Development roadmap"
Assert-Contains $content "Alertmanager/Grafana threshold target contract" "Development roadmap"
Assert-Contains $content "monitoring threshold evidence writer" "Development roadmap"
Assert-Contains $content "data-flow storage transition runbook evidence writer" "Development roadmap"
Assert-Contains $content "threshold value/receiver" "Development roadmap"
Assert-Contains $content "Enterprise auth target smoke" "Development roadmap"
Assert-Contains $content "JIT rollback/runbook evidence writer" "Development roadmap"
Assert-Contains $content "write-enterprise-auth-jit-rollback-evidence.ps1" "Development roadmap"
Assert-Contains $content "scope-out evidence" "Development roadmap"
Assert-Contains $content "cluster network access review evidence writer" "Development roadmap"
Assert-Contains $content "write-cluster-network-access-review-evidence.ps1" "Development roadmap"
Assert-Contains $content "Helm values hardening evidence writer" "Development roadmap"
Assert-Contains $content "write-helm-values-hardening-evidence.ps1" "Development roadmap"
Assert-Contains $content "support escalation handoff evidence writer" "Development roadmap"
Assert-Contains $content "write-support-escalation-handoff-evidence.ps1" "Development roadmap"
Assert-Contains $content "S3 client smoke" "Development roadmap"
Assert-Contains $content "role scope" "Development roadmap"
Assert-NotContains $content "edge parity" "Development roadmap"
Assert-NotContains $content (Decode-Utf8Base64 "7J6R7ISx7J28OiAyMDI2LTA2LTIx") "Development roadmap"

$mvpCompletion = Read-OptionalJsonReport $MvpCompletionReportPath "MVP completion report"
if ($null -ne $mvpCompletion) {
    $mvp = $mvpCompletion.data
    Assert-True ($mvp.formatVersion -eq "osmu.mvp-completion.v1") "Unexpected MVP completion formatVersion in $($mvpCompletion.path)."
    Assert-True ($mvp.result -eq "ready") "Development roadmap expects MVP completion result=ready, but report has result=$($mvp.result)."
    Assert-True ($mvp.classification -eq "local-durable-mvp-ready") "Development roadmap expects classification=local-durable-mvp-ready, but report has classification=$($mvp.classification)."
    Assert-True ($mvp.localDurableMvpReady -eq $true) "Development roadmap expects localDurableMvpReady=true."

    $expectedMvpLine = "MVP completion latest verification: result=$($mvp.result), classification=$($mvp.classification), localDurableMvpReady=$(Format-BoolLower $mvp.localDurableMvpReady)."
    Assert-Contains $content $expectedMvpLine "Development roadmap"
}

$operationsReadiness = Read-OptionalJsonReport $OperationsReadinessReportPath "Operations readiness report"
if ($null -ne $operationsReadiness) {
    $operations = $operationsReadiness.data
    $checks = @($operations.checks)
    Assert-True ($operations.formatVersion -eq "osmu.operations-readiness.v1") "Unexpected operations readiness formatVersion in $($operationsReadiness.path)."
    Assert-True ($operations.result -eq "pending") "Development roadmap expects operations readiness result=pending, but report has result=$($operations.result)."
    Assert-True ($operations.summary -eq "passed=$($operations.passedCount) pending=$($operations.pendingCount)") "Operations readiness summary does not match passed/pending counts."
    Assert-True (($operations.passedCount + $operations.pendingCount) -eq $checks.Count) "Operations readiness passed+pending count does not match check count."

    $expectedOperationsLine = "Operations readiness latest verification: result=$($operations.result), passed=$($operations.passedCount), pending=$($operations.pendingCount), total=$($checks.Count)."
    Assert-Contains $content $expectedOperationsLine "Development roadmap"
}

Write-Host "Development roadmap verified."
Write-Host "Development roadmap: $resolvedPath"
