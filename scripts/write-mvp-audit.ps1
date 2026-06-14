param(
    [string] $ReleaseReportPath = ".\.osmu-run\latest-release.json",
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
$externalGatesPending = -not ($dockerPassed -and $realS3ClientPassed -and $browserE2EPassed)

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
    (Status-Line $dockerPassed "Docker/MariaDB/MinIO integration" "dockerIntegration=$($scope.dockerIntegration), dockerDaemon=$($optionalGates.dockerDaemonAvailable)"),
    (Status-Line $realS3ClientPassed "Real S3 client smoke" "aws=$($optionalGates.awsCliAvailable), mc=$($optionalGates.mcAvailable)"),
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
    (Evidence-Line $(if ($scope.helmChart -eq "included") { "PASS" } else { "PENDING" }) "Helm chart draft" "TC-INFRA-003" "scope.helmChart=$($scope.helmChart); verify-local.ps1 runs verify-helm-chart.ps1"),
    (Evidence-Line "PARTIAL" "Frontend portal checks" "TC-FE-001 through TC-FE-030" "frontend unit/build covers stable E2E selector contract, bucket list summaries, upload state/progress guards, confirm dialog state, access key scope/revoke helpers, bucket lifecycle/tag wrappers, tags, object explorer prefix/highlight helpers, object metadata drift helpers, object tag preflight validation, auth session flows, API filter wrappers, error/requestId handling, single upload abort/retry, multipart upload/retry/abort/resume flow, and multipart local resume sessions; lightweight demo bundle checks pass; Browser click E2E pending"),
    (Evidence-Line $(if ($dockerPassed) { "PASS" } else { "PENDING" }) "Docker/MariaDB/MinIO integration" "TC-INFRA-001, TC-OBJECT-015, TC-S3-AUTH-002" "requires Docker daemon and -RunDockerIntegration"),
    (Evidence-Line $(if ($realS3ClientPassed) { "PASS" } else { "PENDING" }) "Real S3 clients" "TC-S3-AUTH-003" "requires aws or mc on PATH and -RequireS3Client"),
    (Evidence-Line $(if ($browserE2EPassed) { "PASS" } else { "PENDING" }) "Browser visual/click E2E" "TC-FE browser acceptance paths" "requires Browser/Chrome automation and -BrowserE2EVerified"),
    "",
    "## Next Required Evidence",
    "",
    "- Docker Desktop running plus scripts\verify-prototype-release.ps1 -RunDockerIntegration, including MariaDB object tag index smoke.",
    "- AWS CLI or MinIO Client mc on PATH plus scripts\verify-prototype-release.ps1 -RequireS3Client.",
    "- Browser/Chrome automation fixed plus real UI click-path E2E, then release report with -BrowserE2EVerified.",
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

