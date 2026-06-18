param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
    [string] $DurableGateReportPath = ".\.osmu-run\latest-durable-demo-gate.json",
    [string] $StorageExpansionFinalizeReportPath = ".\.osmu-run\latest-storage-expansion-finalize.json",
    [string] $KubernetesDrFinalizeReportPath = ".\.osmu-run\latest-kubernetes-dr-finalize.json",
    [string] $SecurityEvidenceFinalizeReportPath = ".\.osmu-run\latest-security-evidence-finalize.json",
    [string] $OutputPath = ".\.osmu-run\latest-mvp-audit.md",
    [switch] $FailIfExternalGatesPending,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Status-Line([bool] $passed, [string] $label, [string] $detail = "") {
    $prefix = if ($passed) { "PASS" } else { "PENDING" }
    if ($detail) {
        return "- ${prefix}: $label - $detail"
    }
    return "- ${prefix}: $label"
}

function Evidence-Line([string] $status, [string] $label, [string] $testCases, [string] $evidence) {
    return "- ${status}: $label - $testCases - $evidence"
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
            detail = "report not found"
        }
    }

    try {
        $gateReport = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
        $passed = $gateReport.result -eq "ready" -and $gateReport.currentDemoStatus -eq "docker-durable-demo-verified"
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$gateReport.result
            currentDemoStatus = [string]$gateReport.currentDemoStatus
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
        $finalizeReport = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
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
        $finalizeReport = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
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
        $finalizeReport = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
        $passed = $finalizeReport.result -eq "passed"
        return [pscustomobject]@{
            path = $resolvedPath
            exists = $true
            passed = $passed
            result = [string]$finalizeReport.result
            detail = "result=$($finalizeReport.result), failureCount=$($finalizeReport.failureCount), imageSigningRunUrl=$($finalizeReport.source.imageSigningRunUrl), containerSecurityRunUrl=$($finalizeReport.source.containerSecurityRunUrl)"
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
if (-not (Test-Path -LiteralPath $resolvedReleaseReportPath)) {
    throw "Release report not found: $resolvedReleaseReportPath. Run scripts\verify-prototype-release.ps1 first."
}

$report = Get-Content -Raw -LiteralPath $resolvedReleaseReportPath | ConvertFrom-Json
$scope = $report.scope
$optionalGates = $report.optionalGates

$corePrototypePassed = $report.result -eq "passed" `
    -and $scope.preflight -eq "included" `
    -and $scope.runtime -eq "included" `
    -and $scope.lightweightApiSmoke -eq "included" `
    -and $scope.seededDemoSmoke -eq "included" `
    -and $scope.s3Smoke -eq "included" `
    -and $scope.buildVerify -eq "included" `
    -and $scope.openApiContract -eq "included" `
    -and $scope.kubernetesManifests -eq "included" `
    -and $scope.helmChart -eq "included"

$backendTestsPassedOrSkipped = $scope.backendTests -eq "included"
$dockerPassed = [bool]$optionalGates.dockerDaemonAvailable -and $scope.dockerIntegration -eq "included"
$realS3ClientPassed = [bool]$optionalGates.realS3ClientAvailable
$browserE2EPassed = $scope.browserE2E -eq "verified"
$durableGate = Read-DurableGateReport $DurableGateReportPath
$durableGatePassed = [bool]$durableGate.passed
$storageExpansionFinalize = Read-StorageExpansionFinalizeReport $StorageExpansionFinalizeReportPath
$storageExpansionFinalizePassed = [bool]$storageExpansionFinalize.passed
$kubernetesDrFinalize = Read-KubernetesDrFinalizeReport $KubernetesDrFinalizeReportPath
$kubernetesDrFinalizePassed = [bool]$kubernetesDrFinalize.passed
$securityEvidenceFinalize = Read-SecurityEvidenceFinalizeReport $SecurityEvidenceFinalizeReportPath
$securityEvidenceFinalizePassed = [bool]$securityEvidenceFinalize.passed
if ($durableGatePassed) {
    $dockerPassed = $true
    $realS3ClientPassed = $true
    $browserE2EPassed = $true
}
$externalGatesPending = -not (($dockerPassed -and $realS3ClientPassed -and $browserE2EPassed) -or $durableGatePassed)
$frontendPortalStatus = if ($browserE2EPassed) { "PASS" } else { "PARTIAL" }
$frontendPortalEvidence = if ($browserE2EPassed) {
    "frontend unit/build covers stable E2E selector contract, bucket list summaries, upload state/progress guards, confirm dialog state, access key scope/revoke helpers, bucket lifecycle/tag wrappers, tags, object explorer prefix/highlight helpers, object metadata drift helpers, object tag preflight validation, auth session flows, API filter wrappers, error/requestId handling, single upload abort/retry, multipart upload/retry/abort/resume flow, and multipart local resume sessions; lightweight demo bundle checks pass; Browser click E2E passed"
}
else {
    "frontend unit/build covers stable E2E selector contract, bucket list summaries, upload state/progress guards, confirm dialog state, access key scope/revoke helpers, bucket lifecycle/tag wrappers, tags, object explorer prefix/highlight helpers, object metadata drift helpers, object tag preflight validation, auth session flows, API filter wrappers, error/requestId handling, single upload abort/retry, multipart upload/retry/abort/resume flow, and multipart local resume sessions; lightweight demo bundle checks pass; Browser click E2E pending"
}

$auditLines = @(
    "# OSMU MVP Audit",
    "",
    "Generated at: $([DateTimeOffset]::Now.ToString("o"))",
    "Release report: $resolvedReleaseReportPath",
    "",
    "## Summary",
    "",
    (Status-Line $corePrototypePassed "Lightweight MVP prototype" "runtime, API smoke, seeded demo, S3 smoke, build verify, OpenAPI contract, Kubernetes manifest draft, Helm chart draft"),
    (Status-Line $backendTestsPassedOrSkipped "Backend tests in latest report" "scope.backendTests=$($scope.backendTests)"),
    (Status-Line ($scope.ciWorkflow -eq "included") "Prototype CI workflow" "scope.ciWorkflow=$($scope.ciWorkflow)"),
    (Status-Line ($scope.durableDockerCiWorkflow -eq "included") "Durable Docker CI workflow draft" "scope.durableDockerCiWorkflow=$($scope.durableDockerCiWorkflow)"),
    (Status-Line ($scope.realS3ClientCiWorkflow -eq "included") "Real S3 client CI workflow draft" "scope.realS3ClientCiWorkflow=$($scope.realS3ClientCiWorkflow)"),
    (Status-Line ($scope.containerSecurityCiWorkflow -eq "included") "Container security CI workflow draft" "scope.containerSecurityCiWorkflow=$($scope.containerSecurityCiWorkflow)"),
    (Status-Line ($scope.browserE2ECiWorkflow -eq "included") "Browser E2E CI workflow draft" "scope.browserE2ECiWorkflow=$($scope.browserE2ECiWorkflow)"),
    (Status-Line ($scope.imageSigningPolicy -eq "included") "Image signing policy draft" "scope.imageSigningPolicy=$($scope.imageSigningPolicy)"),
    (Status-Line ($scope.releaseNotes -eq "included") "Release notes generation" "scope.releaseNotes=$($scope.releaseNotes)"),
    (Status-Line ($scope.commercialReadiness -eq "included") "Commercial readiness draft" "scope.commercialReadiness=$($scope.commercialReadiness)"),
    (Status-Line ($scope.openApiContract -eq "included") "MVP API contract" "scope.openApiContract=$($scope.openApiContract)"),
    (Status-Line ($scope.kubernetesManifests -eq "included") "Kubernetes manifest draft" "scope.kubernetesManifests=$($scope.kubernetesManifests)"),
    (Status-Line ($scope.helmChart -eq "included") "Helm chart draft" "scope.helmChart=$($scope.helmChart)"),
    (Status-Line ($scope.networkPolicies -eq "included") "NetworkPolicy draft" "scope.networkPolicies=$($scope.networkPolicies)"),
    (Status-Line ($scope.containerHardening -eq "included") "Container hardening draft" "scope.containerHardening=$($scope.containerHardening)"),
    (Status-Line ($scope.tlsIngress -eq "included") "TLS ingress draft" "scope.tlsIngress=$($scope.tlsIngress)"),
    (Status-Line ($scope.secretRotationPolicy -eq "included") "Secret rotation policy draft" "scope.secretRotationPolicy=$($scope.secretRotationPolicy)"),
    (Status-Line ($scope.backupRestoreDrill -eq "included") "Backup restore drill draft" "scope.backupRestoreDrill=$($scope.backupRestoreDrill)"),
    (Status-Line ($scope.prometheusObservability -eq "included") "Prometheus observability draft" "scope.prometheusObservability=$($scope.prometheusObservability)"),
    (Status-Line ($scope.monitoringArtifacts -eq "included") "Monitoring artifacts draft" "scope.monitoringArtifacts=$($scope.monitoringArtifacts)"),
    (Status-Line ($scope.prometheusOperatorDraft -eq "included") "Prometheus Operator draft" "scope.prometheusOperatorDraft=$($scope.prometheusOperatorDraft)"),
    (Status-Line $storageExpansionFinalizePassed "Storage expansion finalizer evidence" "$($storageExpansionFinalize.detail), report=$($storageExpansionFinalize.path)"),
    (Status-Line $kubernetesDrFinalizePassed "Kubernetes DR finalizer evidence" "$($kubernetesDrFinalize.detail), report=$($kubernetesDrFinalize.path)"),
    (Status-Line $securityEvidenceFinalizePassed "Security evidence finalizer" "$($securityEvidenceFinalize.detail), report=$($securityEvidenceFinalize.path)"),
    (Status-Line $durableGatePassed "Durable MVP demo gate" "$($durableGate.detail), report=$($durableGate.path)"),
    (Status-Line $dockerPassed "Docker/MariaDB/MinIO integration" "dockerIntegration=$($scope.dockerIntegration), dockerDaemon=$($optionalGates.dockerDaemonAvailable)"),
    (Status-Line $realS3ClientPassed "Real S3 client smoke" "aws=$($optionalGates.awsCliAvailable), mc=$($optionalGates.mcAvailable), dockerizedMc=$($optionalGates.dockerizedMcAvailable)"),
    (Status-Line $browserE2EPassed "Browser visual/click E2E" "browserE2E=$($scope.browserE2E)"),
    "",
    "## Implemented Prototype Scope",
    "",
    "- Auth, refresh, logout, current user, JWT guard.",
    "- Admin user, organization, quota, safe organization delete.",
    "- Bucket/object CRUD, tags, permissions, object versions, trash/restore/purge.",
    "- Access keys with scoped S3-style permissions.",
    "- Audit logs with filters and CSV export.",
    "- Lifecycle rules, dry run, conflict report, S3 lifecycle XML.",
    "- Built-in S3 SigV4 compatibility smoke.",
    "- Frontend dashboard bundle and unit/build verification.",
    "- Machine-readable MVP OpenAPI contract and verifier.",
    "- Kubernetes deployment draft manifests and verifier.",
    "- Helm chart draft and verifier.",
    "",
    "## Test Case Evidence Map",
    "",
    (Evidence-Line $(if ($corePrototypePassed) { "PASS" } else { "PENDING" }) "Health and runtime" "TC-HEALTH-001, TC-HEALTH-002, TC-HEALTH-003" "verify-prototype-release.ps1 runtime health"),
    (Evidence-Line $(if ($corePrototypePassed) { "PASS" } else { "PENDING" }) "Auth session workflows" "TC-AUTH-001, TC-AUTH-002, TC-AUTH-003, TC-AUTH-004, TC-KEY-007A" "verify-lightweight-prototype.ps1 plus backend auth tests"),
    (Evidence-Line $(if ($corePrototypePassed) { "PASS" } else { "PENDING" }) "Organization and quota workflows" "TC-ORG-001, TC-ORG-003, TC-ORG-004, TC-ORG-005, TC-ORG-006, TC-ORG-007, TC-QUOTA-001, TC-QUOTA-002" "verify-lightweight-prototype.ps1"),
    (Evidence-Line $(if ($corePrototypePassed) { "PASS" } else { "PENDING" }) "Bucket workflows" "TC-BUCKET-001, TC-BUCKET-002, TC-BUCKET-003, TC-BUCKET-004, TC-BUCKET-005, TC-BUCKET-007, TC-BUCKET-008, TC-BUCKET-009, TC-BUCKET-010" "verify-lightweight-prototype.ps1"),
    (Evidence-Line $(if ($corePrototypePassed) { "PASS" } else { "PENDING" }) "Object workflows" "TC-OBJECT-001 through TC-OBJECT-022, lifecycle rule extensions" "verify-lightweight-prototype.ps1 plus backend tests"),
    (Evidence-Line $(if ($corePrototypePassed) { "PASS" } else { "PENDING" }) "Access key and audit workflows" "TC-KEY-001, TC-KEY-002, TC-KEY-004, TC-KEY-005, TC-KEY-006, TC-KEY-007, TC-AUDIT-004, TC-AUDIT-005, TC-AUDIT-006" "verify-lightweight-prototype.ps1"),
    (Evidence-Line $(if ($corePrototypePassed) { "PASS" } else { "PENDING" }) "Built-in S3 compatibility" "TC-S3-BUCKET-001/002/003, TC-S3-AUTH-001*, TC-S3-OBJECT-001 through TC-S3-OBJECT-008C" "verify-s3-client-smoke.ps1 manual SigV4 probes"),
    (Evidence-Line $(if ($backendTestsPassedOrSkipped) { "PASS" } else { "PENDING" }) "Backend automated tests" "Controller/service/repository test suite" "verify-prototype-release.ps1 backendTests=$($scope.backendTests)"),
    (Evidence-Line $(if ($scope.openApiContract -eq "included") { "PASS" } else { "PENDING" }) "MVP API contract" "TC-DOC-001" "scope.openApiContract=$($scope.openApiContract); verify-local.ps1 runs verify-openapi-contract.ps1"),
    (Evidence-Line $(if ($scope.kubernetesManifests -eq "included") { "PASS" } else { "PENDING" }) "Kubernetes manifest draft" "TC-INFRA-002" "scope.kubernetesManifests=$($scope.kubernetesManifests); verify-local.ps1 runs verify-k8s-manifests.ps1"),
    (Evidence-Line $(if ($scope.helmChart -eq "included") { "PASS" } else { "PENDING" }) "Helm chart draft" "TC-INFRA-003" "scope.helmChart=$($scope.helmChart); verify-local.ps1 runs verify-helm-chart.ps1"),
    (Evidence-Line $(if ($storageExpansionFinalizePassed) { "PASS" } else { "PENDING" }) "Storage expansion finalizer" "TC-INFRA-STORAGE-EXPANSION-FINALIZE" "$($storageExpansionFinalize.detail); report=$($storageExpansionFinalize.path)"),
    (Evidence-Line $(if ($kubernetesDrFinalizePassed) { "PASS" } else { "PENDING" }) "Kubernetes DR finalizer" "TC-INFRA-KUBERNETES-DR-FINALIZE" "$($kubernetesDrFinalize.detail); report=$($kubernetesDrFinalize.path)"),
    (Evidence-Line $(if ($securityEvidenceFinalizePassed) { "PASS" } else { "PENDING" }) "Security evidence finalizer" "TC-SECURITY-EVIDENCE-FINALIZE" "$($securityEvidenceFinalize.detail); report=$($securityEvidenceFinalize.path)"),
    (Evidence-Line $(if ($durableGatePassed) { "PASS" } else { "PENDING" }) "Durable MVP demo gate" "TC-DEMO-002" "$($durableGate.detail); report=$($durableGate.path)"),
    (Evidence-Line $frontendPortalStatus "Frontend portal checks" "TC-FE-001 through TC-FE-030" $frontendPortalEvidence),
    (Evidence-Line $(if ($dockerPassed) { "PASS" } else { "PENDING" }) "Docker/MariaDB/MinIO integration" "TC-INFRA-001, TC-OBJECT-015, TC-S3-AUTH-002" "requires Docker daemon and -RunDockerIntegration"),
    (Evidence-Line $(if ($realS3ClientPassed) { "PASS" } else { "PENDING" }) "Real S3 clients" "TC-S3-AUTH-003" "requires aws, host mc, or Dockerized mc and -RequireS3Client"),
    (Evidence-Line $(if ($browserE2EPassed) { "PASS" } else { "PENDING" }) "Browser visual/click E2E" "TC-FE browser acceptance paths" "requires Browser/Chrome automation and -BrowserE2EVerified"),
    "",
    "## Next Required Evidence",
    "",
    "- Durable MVP demo gate report: $($durableGate.detail); path=$($durableGate.path).",
    "- Storage expansion finalizer report: $($storageExpansionFinalize.detail); path=$($storageExpansionFinalize.path).",
    "- Kubernetes DR finalizer report: $($kubernetesDrFinalize.detail); path=$($kubernetesDrFinalize.path).",
    "- Security evidence finalizer report: $($securityEvidenceFinalize.detail); path=$($securityEvidenceFinalize.path).",
    "- If the durable gate report is not ready, run Docker Desktop plus scripts\verify-durable-demo-gate.ps1.",
    "- If using the legacy release report path instead of durable gate evidence, run scripts\verify-prototype-release.ps1 with -RunDockerIntegration, -RequireS3Client, and -BrowserE2EVerified after the corresponding evidence passes.",
    "- Full release report with backend tests included by omitting -SkipBackendTests."
)

$audit = $auditLines -join [Environment]::NewLine

if (-not $NoWrite) {
    $resolvedOutputPath = Resolve-ProjectPath $OutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
    Set-Content -LiteralPath $resolvedOutputPath -Value $audit -Encoding UTF8
    Write-Host "MVP audit: $resolvedOutputPath"
}

Write-Host $audit

if ($FailIfExternalGatesPending -and $externalGatesPending) {
    throw "MVP external gates are still pending."
}

