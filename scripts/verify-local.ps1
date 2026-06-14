param(
    [switch] $SkipDocker,
    [switch] $SkipBackend,
    [switch] $SkipFrontend,
    [string] $JavaHome = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

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
    Normalize-ProcessPath
    if (-not $path) {
        return
    }

    $resolved = Resolve-Path -LiteralPath $path -ErrorAction Stop
    $javaBin = Join-Path $resolved.Path "bin"
    $javaExe = Join-Path $javaBin "java.exe"
    if (-not (Test-Path -LiteralPath $javaExe)) {
        throw "JavaHome does not contain bin\java.exe: $($resolved.Path)"
    }

    $env:JAVA_HOME = $resolved.Path
    [Environment]::SetEnvironmentVariable("Path", "$javaBin;$([Environment]::GetEnvironmentVariable("Path", "Process"))", "Process")
}

function Assert-JavaAvailable() {
    $javaCommand = Get-Command java -ErrorAction SilentlyContinue
    if (-not $javaCommand) {
        throw "Java runtime not found on PATH. Install JDK 17+ or set JAVA_HOME before running backend tests."
    }

    $javaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME")
    if ($javaHome -and -not (Test-Path -LiteralPath $javaHome)) {
        throw "JAVA_HOME points to a missing path: $javaHome"
    }
}

Use-JavaHome $JavaHome
Normalize-ProcessPath

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

Step "Commercial readiness draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-commercial-readiness.ps1"

Step "OpenAPI MVP contract check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-openapi-contract.ps1"

Step "Kubernetes manifest draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1"

Step "Helm chart draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-chart.ps1"

Step "Container hardening draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-container-hardening.ps1"

Step "TLS ingress draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-tls-ingress.ps1"

Step "Secret rotation policy draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-secret-rotation-policy.ps1"

Step "Backup restore drill draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-backup-restore-drill.ps1"

Step "Prometheus observability draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-prometheus-observability.ps1"

Step "Monitoring artifacts draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-monitoring-artifacts.ps1"

Step "Prometheus Operator draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-prometheus-operator-draft.ps1"

Step "Flyway migration version check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-migrations.ps1"

if (-not $SkipDocker) {
    Step "Docker Compose config check"
    Run "docker compose --env-file .\infra\local\.env.example -f .\infra\local\docker-compose.yml config --quiet"
}

if (-not $SkipFrontend) {
    Step "Frontend static syntax check"
    Run "node --check .\osmu-frontend\src\services\api.js"
    Run "node --check .\osmu-frontend\vite.config.js"

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
