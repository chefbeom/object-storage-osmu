param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $DurableGateReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [string] $StorageExpansionFinalizeReportPath = ".\.osmu-run\latest-storage-expansion-finalize.json",
    [string] $KubernetesDrFinalizeReportPath = ".\.osmu-run\latest-kubernetes-dr-finalize.json",
    [string] $SecurityEvidenceFinalizeReportPath = ".\.osmu-run\latest-security-evidence-finalize.json",
    [string] $AuditPath = ".\.osmu-run\latest-mvp-audit.md",
    [string] $DecisionPath = ".\.osmu-run\latest-release-decision.md",
    [string] $ReleaseNotesPath = ".\.osmu-run\latest-release-notes.md"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}
function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
}

function Assert-FileExists([string] $path) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required release artifact not found: $path"
    }
}

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-NotContains([string] $text, [string] $unexpected, [string] $label) {
    if ($text.Contains($unexpected)) {
        throw "$label contains unexpected text: $unexpected"
    }
}

function Read-DurableGateReport([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $false
            passed = $false
            result = "missing"
            currentDemoStatus = "missing"
            selectedS3Client = ""
            durablePreflightReportPath = ""
            detail = "report not found"
        }
    }

    try {
        $gateReport = Read-Utf8Text $resolvedPath | ConvertFrom-Json
        $passed = $gateReport.result -eq "ready" -and $gateReport.currentDemoStatus -eq "docker-durable-demo-verified"
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$gateReport.result
            currentDemoStatus = [string]$gateReport.currentDemoStatus
            selectedS3Client = [string]$gateReport.selectedS3Client
            durablePreflightReportPath = [string]$gateReport.durablePreflightReportPath
            detail = "result=$($gateReport.result), currentDemoStatus=$($gateReport.currentDemoStatus)"
        }
    }
    catch {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $false
            result = "unreadable"
            currentDemoStatus = "unreadable"
            selectedS3Client = ""
            durablePreflightReportPath = ""
            detail = $_.Exception.Message
        }
    }
}

function Read-StorageExpansionFinalizeReport([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $false
            passed = $false
            result = "missing"
            detail = "report not found"
        }
    }

    try {
        $finalizeReport = Read-Utf8Text $resolvedPath | ConvertFrom-Json
        $passed = $finalizeReport.result -eq "passed"
        $backend = $finalizeReport.backend
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$finalizeReport.result
            detail = "result=$($finalizeReport.result), namespace=$($finalizeReport.namespace), tenant=$($finalizeReport.tenantName), runDryRunRunner=$($backend.runDryRunRunner), runApply=$($backend.runApply)"
        }
    }
    catch {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $false
            result = "unreadable"
            detail = $_.Exception.Message
        }
    }
}

function Read-KubernetesDrFinalizeReport([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $false
            passed = $false
            result = "missing"
            detail = "report not found"
        }
    }

    try {
        $finalizeReport = Read-Utf8Text $resolvedPath | ConvertFrom-Json
        $passed = $finalizeReport.result -eq "ready"
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$finalizeReport.result
            detail = "result=$($finalizeReport.result), status=$($finalizeReport.status), sourceNamespace=$($finalizeReport.sourceNamespace), restoreNamespace=$($finalizeReport.restoreNamespace), backupTimestamp=$($finalizeReport.backupTimestamp), serverDryRunOnly=$($finalizeReport.serverDryRunOnly), confirmRestore=$($finalizeReport.confirmRestore), submitEvidence=$($finalizeReport.submitEvidence)"
        }
    }
    catch {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $false
            result = "unreadable"
            detail = $_.Exception.Message
        }
    }
}

function Read-SecurityEvidenceFinalizeReport([string] $path) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $false
            passed = $false
            result = "missing"
            detail = "report not found"
        }
    }

    try {
        $finalizeReport = Read-Utf8Text $resolvedPath | ConvertFrom-Json
        $passed = $finalizeReport.result -eq "passed"
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$finalizeReport.result
            detail = "result=$($finalizeReport.result), failureCount=$($finalizeReport.failureCount)"
        }
    }
    catch {
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $false
            result = "unreadable"
            detail = $_.Exception.Message
        }
    }
}

$resolvedReleaseReportPath = Resolve-ProjectPath $ReleaseReportPath
$durableGate = Read-DurableGateReport $DurableGateReportPath
$storageExpansionFinalize = Read-StorageExpansionFinalizeReport $StorageExpansionFinalizeReportPath
$kubernetesDrFinalize = Read-KubernetesDrFinalizeReport $KubernetesDrFinalizeReportPath
$securityEvidenceFinalize = Read-SecurityEvidenceFinalizeReport $SecurityEvidenceFinalizeReportPath
$resolvedAuditPath = Resolve-ProjectPath $AuditPath
$resolvedDecisionPath = Resolve-ProjectPath $DecisionPath
$resolvedReleaseNotesPath = Resolve-ProjectPath $ReleaseNotesPath

Assert-FileExists $resolvedReleaseReportPath
Assert-FileExists $resolvedAuditPath
Assert-FileExists $resolvedDecisionPath
Assert-FileExists $resolvedReleaseNotesPath

$report = Read-Utf8Text $resolvedReleaseReportPath | ConvertFrom-Json
$audit = Read-Utf8Text $resolvedAuditPath
$decision = Read-Utf8Text $resolvedDecisionPath
$releaseNotes = Read-Utf8Text $resolvedReleaseNotesPath

if ($durableGate.passed) {
    if ($durableGate.selectedS3Client -and [string]$report.selectedS3Client -ne $durableGate.selectedS3Client) {
        throw "Release report selectedS3Client does not match durable gate report: release=$($report.selectedS3Client), gate=$($durableGate.selectedS3Client)"
    }
    if ($durableGate.durablePreflightReportPath) {
        $expectedPreflightPath = Resolve-ProjectPath $durableGate.durablePreflightReportPath
        if ([string]$report.durablePreflightReportPath -ne $expectedPreflightPath) {
            throw "Release report durablePreflightReportPath does not match durable gate report: release=$($report.durablePreflightReportPath), gate=$expectedPreflightPath"
        }
    }
}

$releasePathLine = "Release report: $resolvedReleaseReportPath"
Assert-Contains $audit $releasePathLine "MVP audit"
Assert-Contains $decision $releasePathLine "MVP release decision"
Assert-Contains $releaseNotes $releasePathLine "MVP release notes"
Assert-Contains $releaseNotes "Durable gate report: $($durableGate.path)" "MVP release notes"
Assert-Contains $releaseNotes "Storage expansion finalizer report: $($storageExpansionFinalize.path)" "MVP release notes"
Assert-Contains $releaseNotes "Kubernetes DR finalizer report: $($kubernetesDrFinalize.path)" "MVP release notes"
Assert-Contains $releaseNotes "Security evidence finalizer report: $($securityEvidenceFinalize.path)" "MVP release notes"
Assert-Contains $releaseNotes "MVP audit: $resolvedAuditPath" "MVP release notes"
Assert-Contains $releaseNotes "MVP release decision: $resolvedDecisionPath" "MVP release notes"
Assert-Contains $audit "Storage expansion finalizer evidence" "MVP audit"
Assert-Contains $audit "Kubernetes DR finalizer evidence" "MVP audit"
Assert-Contains $audit "Security evidence finalizer" "MVP audit"
Assert-Contains $decision "Storage expansion finalizer evidence" "MVP release decision"
Assert-Contains $decision "Kubernetes DR finalizer evidence" "MVP release decision"
Assert-Contains $decision "Security evidence finalizer" "MVP release decision"
Assert-Contains $releaseNotes "- Storage expansion finalizer report: $($storageExpansionFinalize.detail)" "MVP release notes"
Assert-Contains $releaseNotes "- Kubernetes DR finalizer report: $($kubernetesDrFinalize.detail)" "MVP release notes"
Assert-Contains $releaseNotes "- Security evidence finalizer report: $($securityEvidenceFinalize.detail)" "MVP release notes"

$lightweightGo = $report.result -eq "passed" `
    -and $report.scope.preflight -eq "included" `
    -and $report.scope.runtime -eq "included" `
    -and $report.scope.lightweightApiSmoke -eq "included" `
    -and $report.scope.seededDemoSmoke -eq "included" `
    -and $report.scope.s3Smoke -eq "included" `
    -and $report.scope.buildVerify -eq "included" `
    -and $report.scope.ciWorkflow -eq "included" `
    -and $report.scope.openApiContract -eq "included" `
    -and $report.scope.kubernetesManifests -eq "included" `
    -and $report.scope.helmChart -eq "included" `
    -and $report.scope.networkPolicies -eq "included" `
    -and $report.scope.containerHardening -eq "included" `
    -and $report.scope.tlsIngress -eq "included" `
    -and $report.scope.secretRotationPolicy -eq "included" `
    -and $report.scope.backupRestoreDrill -eq "included" `
    -and $report.scope.prometheusObservability -eq "included" `
    -and $report.scope.monitoringArtifacts -eq "included" `
    -and $report.scope.prometheusOperatorDraft -eq "included" `
    -and $report.scope.backendTests -eq "included"

$durableGo = $lightweightGo `
    -and ((
        [bool]$report.optionalGates.dockerDaemonAvailable `
        -and $report.scope.dockerIntegration -eq "included" `
        -and [bool]$report.optionalGates.realS3ClientAvailable `
        -and [bool]$report.scope.realS3ClientRequired `
        -and $report.scope.browserE2E -eq "verified"
    ) -or [bool]$durableGate.passed)

$expectedLightweightDecision = if ($lightweightGo) { "GO" } else { "NO-GO" }
$expectedDurableDecision = if ($durableGo) { "GO" } else { "NO-GO" }

Assert-Contains $decision "- Lightweight demo candidate: $expectedLightweightDecision" "MVP release decision"
Assert-Contains $decision "- Durable MVP pilot: $expectedDurableDecision" "MVP release decision"
Assert-Contains $releaseNotes "- Lightweight demo candidate: $expectedLightweightDecision" "MVP release notes"
Assert-Contains $releaseNotes "- Durable MVP pilot: $expectedDurableDecision" "MVP release notes"

if ($lightweightGo) {
    Assert-Contains $audit "- PASS: Lightweight MVP prototype" "MVP audit"
    Assert-Contains $audit "- PASS: Prototype CI workflow" "MVP audit"
    Assert-Contains $audit "- PASS: MVP API contract" "MVP audit"
    Assert-Contains $audit "- PASS: Kubernetes manifest draft" "MVP audit"
    Assert-Contains $audit "- PASS: Helm chart draft" "MVP audit"
    Assert-Contains $audit "- PASS: NetworkPolicy draft" "MVP audit"
    Assert-Contains $audit "- PASS: Container hardening draft" "MVP audit"
    Assert-Contains $audit "- PASS: TLS ingress draft" "MVP audit"
    Assert-Contains $audit "- PASS: Secret rotation policy draft" "MVP audit"
    Assert-Contains $audit "- PASS: Backup restore drill draft" "MVP audit"
    Assert-Contains $audit "- PASS: Prometheus observability draft" "MVP audit"
    Assert-Contains $audit "- PASS: Monitoring artifacts draft" "MVP audit"
    Assert-Contains $audit "- PASS: Prometheus Operator draft" "MVP audit"
    Assert-Contains $decision "- [PASS] OpenAPI contract included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Kubernetes manifest draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Helm chart draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] NetworkPolicy draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Container hardening draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] TLS ingress draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Secret rotation policy draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Backup restore drill draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Prometheus observability draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Monitoring artifacts draft included" "MVP release decision"
    Assert-Contains $decision "- [PASS] Prometheus Operator draft included" "MVP release decision"
    Assert-Contains $releaseNotes "- OpenAPI MVP contract: included" "MVP release notes"
    Assert-Contains $releaseNotes "- Helm chart draft: included" "MVP release notes"
    Assert-Contains $releaseNotes "- Backend tests: included" "MVP release notes"
} else {
    Assert-Contains $audit "- PENDING: Lightweight MVP prototype" "MVP audit"
}

if ($durableGo) {
    Assert-Contains $audit "- PASS: Durable MVP demo gate" "MVP audit"
    Assert-Contains $decision "- [PASS] Durable MVP demo gate report" "MVP release decision"
    Assert-Contains $releaseNotes "- Durable MVP demo gate report: result=ready, currentDemoStatus=docker-durable-demo-verified" "MVP release notes"
    Assert-Contains $audit "- PASS: Docker/MariaDB/MinIO integration" "MVP audit"
    Assert-Contains $audit "- PASS: Real S3 client smoke" "MVP audit"
    Assert-Contains $audit "- PASS: Browser visual/click E2E" "MVP audit"
    Assert-Contains $audit "- PASS: Frontend portal checks" "MVP audit"
    Assert-Contains $audit "Browser click E2E passed" "MVP audit"
    Assert-NotContains $audit "Browser click E2E pending" "MVP audit"
} else {
    Assert-Contains $audit "- PENDING: Durable MVP demo gate" "MVP audit"
    Assert-Contains $decision "- [PENDING] Durable MVP demo gate report" "MVP release decision"
    Assert-Contains $decision "Durable MVP pilot: NO-GO" "MVP release decision"
    Assert-Contains $releaseNotes "Durable MVP pilot: NO-GO" "MVP release notes"
}

Write-Host "MVP release artifacts verified."
Write-Host "Release report: $resolvedReleaseReportPath"
Write-Host "Audit: $resolvedAuditPath"
Write-Host "Decision: $resolvedDecisionPath"
Write-Host "Release notes: $resolvedReleaseNotesPath"
