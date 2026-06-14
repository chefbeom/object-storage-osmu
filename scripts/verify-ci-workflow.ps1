param(
    [string] $LightweightWorkflowPath = ".\.github\workflows\prototype-ci.yml",
    [string] $DurableDockerWorkflowPath = ".\.github\workflows\durable-docker-ci.yml",
    [string] $RealS3ClientWorkflowPath = ".\.github\workflows\real-s3-client-ci.yml",
    [string] $ContainerSecurityWorkflowPath = ".\.github\workflows\container-security-ci.yml",
    [string] $BrowserE2EWorkflowPath = ".\.github\workflows\browser-e2e-ci.yml",
    [string] $BrowserE2ESpecPath = ".\osmu-frontend\e2e\lightweight-demo.spec.js"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    if (-not $content.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Read-RequiredFile([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "$label missing: $resolvedPath"
    }
    $content = Get-Content -Raw -LiteralPath $resolvedPath
    return [pscustomobject]@{
        Path = $resolvedPath
        Content = $content
    }
}

function Assert-NotContains([string] $content, [string] $unexpected, [string] $label) {
    if ($content.Contains($unexpected)) {
        throw "$label must not contain text: $unexpected"
    }
}

function Read-Workflow([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "$label missing: $resolvedPath"
    }
    $content = Get-Content -Raw -LiteralPath $resolvedPath
    if ($content.Contains("`t")) {
        throw "Tabs are not allowed in $label`: $resolvedPath"
    }
    return [pscustomobject]@{
        Path = $resolvedPath
        Content = $content
    }
}

$lightweightWorkflow = Read-Workflow $LightweightWorkflowPath "Lightweight CI workflow"
$workflow = $lightweightWorkflow.Content

Assert-Contains $workflow "name: Prototype CI" "Lightweight CI workflow"
Assert-Contains $workflow "push:" "Lightweight CI workflow"
Assert-Contains $workflow "pull_request:" "Lightweight CI workflow"
Assert-Contains $workflow "workflow_dispatch:" "Lightweight CI workflow"
Assert-Contains $workflow "contents: read" "Lightweight CI workflow"
Assert-Contains $workflow "cancel-in-progress: true" "Lightweight CI workflow"
Assert-Contains $workflow "runs-on: windows-latest" "Lightweight CI workflow"
Assert-Contains $workflow "timeout-minutes: 30" "Lightweight CI workflow"
Assert-Contains $workflow "actions/checkout@v4" "Lightweight CI workflow"
Assert-Contains $workflow "actions/setup-java@v4" "Lightweight CI workflow"
Assert-Contains $workflow "distribution: temurin" "Lightweight CI workflow"
Assert-Contains $workflow 'java-version: "17"' "Lightweight CI workflow"
Assert-Contains $workflow "actions/setup-node@v4" "Lightweight CI workflow"
Assert-Contains $workflow 'node-version: "24"' "Lightweight CI workflow"
Assert-Contains $workflow "cache-dependency-path: osmu-frontend/package-lock.json" "Lightweight CI workflow"
Assert-Contains $workflow "working-directory: osmu-frontend" "Lightweight CI workflow"
Assert-Contains $workflow "run: npm ci" "Lightweight CI workflow"
Assert-Contains $workflow "run: .\scripts\verify-local.ps1 -SkipDocker" "Lightweight CI workflow"
Assert-NotContains $workflow "RunDockerIntegration" "Lightweight CI workflow"
Assert-NotContains $workflow "RequireDocker" "Lightweight CI workflow"

$durableWorkflow = Read-Workflow $DurableDockerWorkflowPath "Durable Docker CI workflow"
$dockerWorkflow = $durableWorkflow.Content

Assert-Contains $dockerWorkflow "name: Durable Docker CI" "Durable Docker CI workflow"
Assert-Contains $dockerWorkflow "workflow_dispatch:" "Durable Docker CI workflow"
Assert-NotContains $dockerWorkflow "pull_request:" "Durable Docker CI workflow"
Assert-NotContains $dockerWorkflow "push:" "Durable Docker CI workflow"
Assert-Contains $dockerWorkflow "contents: read" "Durable Docker CI workflow"
Assert-Contains $dockerWorkflow "runs-on: ubuntu-latest" "Durable Docker CI workflow"
Assert-Contains $dockerWorkflow "timeout-minutes: 45" "Durable Docker CI workflow"
Assert-Contains $dockerWorkflow "actions/checkout@v4" "Durable Docker CI workflow"
Assert-Contains $dockerWorkflow "shell: pwsh" "Durable Docker CI workflow"
Assert-Contains $dockerWorkflow "verify-docker-integration.ps1 -EnvFile ./infra/local/.env.example -ComposeFile ./infra/local/docker-compose.yml" "Durable Docker CI workflow"
Assert-Contains $dockerWorkflow "docker compose --env-file ./infra/local/.env.example -f ./infra/local/docker-compose.yml logs --no-color" "Durable Docker CI workflow"
Assert-Contains $dockerWorkflow "docker compose --env-file ./infra/local/.env.example -f ./infra/local/docker-compose.yml down -v --remove-orphans" "Durable Docker CI workflow"

$realS3Workflow = Read-Workflow $RealS3ClientWorkflowPath "Real S3 client CI workflow"
$s3Workflow = $realS3Workflow.Content

Assert-Contains $s3Workflow "name: Real S3 Client CI" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "workflow_dispatch:" "Real S3 client CI workflow"
Assert-NotContains $s3Workflow "pull_request:" "Real S3 client CI workflow"
Assert-NotContains $s3Workflow "push:" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "contents: read" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "runs-on: windows-latest" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "timeout-minutes: 45" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "actions/checkout@v4" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "actions/setup-java@v4" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "distribution: temurin" "Real S3 client CI workflow"
Assert-Contains $s3Workflow 'java-version: "17"' "Real S3 client CI workflow"
Assert-Contains $s3Workflow "actions/setup-node@v4" "Real S3 client CI workflow"
Assert-Contains $s3Workflow 'node-version: "24"' "Real S3 client CI workflow"
Assert-Contains $s3Workflow "cache-dependency-path: osmu-frontend/package-lock.json" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "working-directory: osmu-frontend" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "run: npm ci" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "Invoke-WebRequest -Uri `"https://dl.min.io/client/mc/release/windows-amd64/mc.exe`"" "Real S3 client CI workflow"
Assert-Contains $s3Workflow '$env:GITHUB_PATH' "Real S3 client CI workflow"
Assert-Contains $s3Workflow "run: .\scripts\start-local-prototype.ps1" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "run: .\scripts\verify-s3-client-smoke.ps1 -Client mc -RequireClient" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "Get-ChildItem .\.osmu-run -Filter *.log" "Real S3 client CI workflow"
Assert-Contains $s3Workflow "run: .\scripts\stop-local-prototype.ps1 -ForcePorts" "Real S3 client CI workflow"

$containerSecurityWorkflow = Read-Workflow $ContainerSecurityWorkflowPath "Container Security CI workflow"
$securityWorkflow = $containerSecurityWorkflow.Content

Assert-Contains $securityWorkflow "name: Container Security CI" "Container Security CI workflow"
Assert-Contains $securityWorkflow "workflow_dispatch:" "Container Security CI workflow"
Assert-NotContains $securityWorkflow "pull_request:" "Container Security CI workflow"
Assert-NotContains $securityWorkflow "push:" "Container Security CI workflow"
Assert-Contains $securityWorkflow "contents: read" "Container Security CI workflow"
Assert-Contains $securityWorkflow "runs-on: ubuntu-latest" "Container Security CI workflow"
Assert-Contains $securityWorkflow "timeout-minutes: 45" "Container Security CI workflow"
Assert-Contains $securityWorkflow "actions/checkout@v4" "Container Security CI workflow"
Assert-Contains $securityWorkflow 'BACKEND_IMAGE: osmu-backend:${{ github.sha }}' "Container Security CI workflow"
Assert-Contains $securityWorkflow 'FRONTEND_IMAGE: osmu-frontend:${{ github.sha }}' "Container Security CI workflow"
Assert-Contains $securityWorkflow 'docker build -t "$BACKEND_IMAGE" ./osmu-backend' "Container Security CI workflow"
Assert-Contains $securityWorkflow 'docker build -t "$FRONTEND_IMAGE" ./osmu-frontend' "Container Security CI workflow"
Assert-Contains $securityWorkflow "aquasec/trivy:latest image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed" "Container Security CI workflow"
Assert-Contains $securityWorkflow "anchore/syft:latest" "Container Security CI workflow"
Assert-Contains $securityWorkflow "spdx-json=/out/backend.spdx.json" "Container Security CI workflow"
Assert-Contains $securityWorkflow "spdx-json=/out/frontend.spdx.json" "Container Security CI workflow"
Assert-Contains $securityWorkflow "actions/upload-artifact@v4" "Container Security CI workflow"
Assert-Contains $securityWorkflow "if-no-files-found: error" "Container Security CI workflow"

$browserWorkflow = Read-Workflow $BrowserE2EWorkflowPath "Browser E2E CI workflow"
$browserWorkflowContent = $browserWorkflow.Content

Assert-Contains $browserWorkflowContent "name: Browser E2E CI" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "workflow_dispatch:" "Browser E2E CI workflow"
Assert-NotContains $browserWorkflowContent "pull_request:" "Browser E2E CI workflow"
Assert-NotContains $browserWorkflowContent "push:" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "contents: read" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "runs-on: windows-latest" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "timeout-minutes: 45" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "actions/checkout@v4" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "actions/setup-java@v4" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "actions/setup-node@v4" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "npm install --no-save @playwright/test@1.56.1" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "npx playwright install chromium" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "run: .\scripts\start-local-prototype.ps1" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "OSMU_FRONTEND_BASE_URL: http://localhost:5173" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "run: npx playwright test .\e2e\lightweight-demo.spec.js --browser=chromium --reporter=line" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "Get-ChildItem .\.osmu-run -Filter *.log" "Browser E2E CI workflow"
Assert-Contains $browserWorkflowContent "run: .\scripts\stop-local-prototype.ps1 -ForcePorts" "Browser E2E CI workflow"

$browserSpec = Read-RequiredFile $BrowserE2ESpecPath "Browser E2E spec"
$browserSpecContent = $browserSpec.Content

Assert-Contains $browserSpecContent "admin can complete lightweight storage portal click path" "Browser E2E spec"
Assert-Contains $browserSpecContent "login-submit-button" "Browser E2E spec"
Assert-Contains $browserSpecContent "bucket-create-button" "Browser E2E spec"
Assert-Contains $browserSpecContent "object-upload-button" "Browser E2E spec"
Assert-Contains $browserSpecContent "audit-search-button" "Browser E2E spec"
Assert-Contains $browserSpecContent "backup-status-panel" "Browser E2E spec"

Write-Host "CI workflows verified."
Write-Host "Lightweight workflow: $($lightweightWorkflow.Path)"
Write-Host "Durable Docker workflow: $($durableWorkflow.Path)"
Write-Host "Real S3 client workflow: $($realS3Workflow.Path)"
Write-Host "Container security workflow: $($containerSecurityWorkflow.Path)"
Write-Host "Browser E2E workflow: $($browserWorkflow.Path)"
Write-Host "Browser E2E spec: $($browserSpec.Path)"
