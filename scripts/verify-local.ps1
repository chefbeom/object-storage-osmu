param(
    [switch] $SkipDocker,
    [switch] $SkipBackend,
    [switch] $SkipFrontend,
    [string] $JavaHome = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "java-toolchain.ps1")
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Run($command, $workingDirectory = $root) {
    Write-Host "    $command"
    Push-Location $workingDirectory
    try {
        Invoke-Expression $command
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE`: $command"
        }
    }
    finally {
        Pop-Location
    }
}

function Normalize-ProcessPath() {
    $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")
    if (-not $processPath) {
        $processPath = (([Environment]::GetEnvironmentVariable("Path", "Machine")),
            ([Environment]::GetEnvironmentVariable("Path", "User")) |
            Where-Object { $_ }) -join ";"
    }
    [Environment]::SetEnvironmentVariable("PATH", $null, "Process")
    [Environment]::SetEnvironmentVariable("Path", $processPath, "Process")
}

function Use-JavaHome($path) {
    Use-OsmuJavaHome $path | Out-Null
}

function Assert-JavaAvailable() {
    Assert-OsmuJavaAvailable -RequiredVersion 17 | Out-Null
}

Use-JavaHome $JavaHome
Normalize-ProcessPath
Use-OsmuDockerConfig $root | Out-Null

Step "Git whitespace check"
Run "git diff --check"

Step "Env ignore check"
Run "git check-ignore -v .\infra\local\.env .\osmu-backend\.env .\osmu-frontend\.env"

Step "PowerShell script parse check"
Run "Get-ChildItem .\scripts -Filter *.ps1 | ForEach-Object { [scriptblock]::Create((Get-Content -Raw -LiteralPath `$_.FullName)) | Out-Null }"

Step "MVP release decision self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-decision.ps1"

Step "CI workflow draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-ci-workflow.ps1"

Step "Image signing policy draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-image-signing-policy.ps1"

Step "Security evidence writer check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-security-evidence-writers.ps1"

Step "Security evidence finalizer check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-security-evidence-finalizer.ps1"

Step "Commercial readiness draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-commercial-readiness.ps1"

Step "Development roadmap check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-development-roadmap.ps1"

Step "Prototype status check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-status.ps1"

Step "OpenAPI MVP contract check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-openapi-contract.ps1"

Step "Kubernetes manifest draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1"

Step "Helm chart draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-chart.ps1"

Step "Helm values hardening evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-values-hardening-evidence.ps1"

Step "Cluster network access review evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-cluster-network-access-review-evidence.ps1"

Step "Container hardening draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-container-hardening.ps1"

Step "TLS ingress draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-tls-ingress.ps1"

Step "Secret rotation policy draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-secret-rotation-policy.ps1"

Step "Secret rotation evidence writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-secret-rotation-evidence.ps1"

Step "Commercial integration evidence writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-commercial-integration-evidence.ps1"

Step "Commercial approval evidence writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-commercial-approval-evidence.ps1"

Step "Chargeback closeout evidence writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-chargeback-closeout-evidence.ps1"

Step "Operations handoff package writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-handoff-package.ps1"

Step "Support escalation handoff evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-support-escalation-handoff-evidence.ps1"

Step "IAM/RBAC matrix check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-iam-rbac-matrix.ps1"

Step "IAM/RBAC finalizer check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\finalize-iam-rbac-readiness.ps1 -FailIfNotPassed"

Step "IAM/RBAC finalizer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-iam-rbac-finalizer.ps1"

Step "Kubernetes RBAC matrix check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-rbac-matrix.ps1"

Step "Storage Expansion RBAC auth plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-rbac-auth.ps1 -PlanOnly"

Step "Storage Expansion server dry-run plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-server-dry-run.ps1 -PlanOnly"

Step "Storage Expansion finalize plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -PlanOnly"

Step "Storage Expansion finalizer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-finalizer.ps1"

Step "Kubernetes HA/DR readiness plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-ha-dr-readiness.ps1 -PlanOnly"

Step "Kubernetes backup drill plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-backup-drill.ps1 -PlanOnly"

Step "Kubernetes restore namespace preparation plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\prepare-kubernetes-restore-namespace.ps1 -PlanOnly"

Step "Kubernetes backup artifact preflight plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-backup-artifacts.ps1 -PlanOnly"

Step "Kubernetes restore drill plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-restore-drill.ps1 -PlanOnly"

Step "Kubernetes DR drill orchestration plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -PlanOnly"

Step "Kubernetes DR bucket bootstrap plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-kubernetes-dr-bucket.ps1 -PlanOnly"

Step "Kubernetes DR bucket immutability plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-dr-bucket-immutability.ps1 -PlanOnly"

Step "Kubernetes backup artifact transfer plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\transfer-kubernetes-backup-artifacts.ps1 -PlanOnly"

Step "Kubernetes restore smoke plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-restore-smoke.ps1 -PlanOnly"

Step "Kubernetes DR evidence API request plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-kubernetes-dr-evidence-request.ps1 -PlanOnly"

Step "Kubernetes DR finalize plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -PlanOnly"

Step "Operations readiness artifact check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness.ps1"

Step "Operations evidence plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-evidence-plan.ps1"

Step "Operations evidence plan invocation check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-evidence-plan-invocation.ps1"

Step "Enterprise auth smoke plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-enterprise-auth-smoke-plan.ps1"

Step "Enterprise auth JIT rollback evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-enterprise-auth-jit-rollback-evidence.ps1"

Step "Operations invocation unblock plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-invocation-unblock-plan.ps1"

Step "Operations dispatch preflight check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-dispatch-preflight.ps1"

Step "Operations workflow run id plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-workflow-run-id-plan.ps1"

Step "Operations artifact collection plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-artifact-collection-plan.ps1"

Step "Operations readiness finalizer plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness-finalizer.ps1"

Step "Operations readiness artifact import check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness-artifact-import.ps1"

Step "Operations evidence handoff check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-evidence-handoff.ps1"

Step "Operations readiness convergence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness-convergence.ps1"

Step "Kubernetes operations report sync check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-sync.ps1"

Step "Kubernetes operations report sync live verifier check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-sync-live-self-test.ps1"

Step "Kubernetes operations report mount verifier check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-mount-self-test.ps1"

Step "Backup restore drill draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-backup-restore-drill.ps1"

Step "Prometheus observability draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-prometheus-observability.ps1"

Step "Monitoring artifacts draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-monitoring-artifacts.ps1"

Step "Monitoring threshold evidence writer check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-monitoring-threshold-evidence.ps1"

Step "Prometheus Operator draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-prometheus-operator-draft.ps1"

Step "Flyway migration version check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-migrations.ps1"

Step "Migration rollback plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-migration-rollback-plan.ps1"

Step "Metadata index coverage check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-metadata-index-coverage.ps1 -NoWrite"

Step "MariaDB query plan evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-mariadb-query-plan-evidence.ps1"

Step "Object list query pushdown check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-object-list-query-pushdown.ps1"

Step "Data-flow storage plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-data-flow-storage-plan.ps1"

Step "Data-flow query and retention budget evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-data-flow-query-retention-budget-evidence.ps1"

Step "Data-flow storage transition runbook evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-data-flow-storage-transition-runbook-evidence.ps1"

if (-not $SkipDocker) {
    Step "Docker Compose config check"
    Run "docker compose --env-file .\infra\local\.env.example -f .\infra\local\docker-compose.yml config --quiet"
}

if (-not $SkipFrontend) {
    Step "Frontend static syntax check"
    Run "node --check .\osmu-frontend\src\services\api.js"
    Run "node --check .\osmu-frontend\vite.config.js"
    Run "node --check .\osmu-frontend\mock-api\server.mjs"

    Step "Frontend mock API self-test"
    Run "npm.cmd run mock:api:self-test" (Join-Path $root "osmu-frontend")

    Step "Frontend unit tests"
    Run "npm.cmd run test:unit" (Join-Path $root "osmu-frontend")

    Step "Frontend build"
    Run "npm.cmd run build" (Join-Path $root "osmu-frontend")
}

if (-not $SkipBackend) {
    Step "Backend Java preflight"
    Assert-JavaAvailable

    Step "Backend tests"
    Run ".\gradlew.bat test" (Join-Path $root "osmu-backend")
}

Step "Done"
