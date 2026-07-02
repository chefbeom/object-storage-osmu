param(
    [string] $JavaHome = "",
    [int] $BackendPort = 8080,
    [int] $FrontendPort = 5173,
    [string] $BrowserChannel = $env:OSMU_PLAYWRIGHT_CHANNEL,
    [string] $LogDir = ".\.osmu-run\browser-e2e-prototype",
    [string] $OperationsConvergenceFixturePath = ".\.osmu-run\browser-e2e-prototype\latest-operations-readiness-convergence.json",
    [switch] $SkipApiSmoke,
    [switch] $NoPreClean
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$frontendDir = Join-Path $root "osmu-frontend"
$frontendBase = "http://localhost:$FrontendPort"
$apiBase = "http://localhost:$BackendPort/api"

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Resolve-DefaultBrowserChannel() {
    if ($BrowserChannel) {
        return $BrowserChannel
    }

    $chromePaths = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
    )
    foreach ($path in $chromePaths) {
        if (Test-Path -LiteralPath $path) {
            return "chrome"
        }
    }

    $edgePaths = @(
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\Application\msedge.exe")
    )
    foreach ($path in $edgePaths) {
        if (Test-Path -LiteralPath $path) {
            return "msedge"
        }
    }

    return ""
}

function Invoke-FrontendCommand([string[]] $Arguments) {
    Push-Location $frontendDir
    try {
        & npm.cmd @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "npm $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

function Assert-PlaywrightCli() {
    Push-Location $frontendDir
    try {
        & npx.cmd playwright --version | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Playwright CLI is not available. Run 'npm install' from osmu-frontend first."
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-ProjectScript([string] $ScriptName, [string[]] $Arguments = @()) {
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    Write-Host "    $ScriptName $($Arguments -join ' ')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptName failed with exit code $LASTEXITCODE."
    }
}

function Resolve-ProjectPath([string] $Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $Path))
}

function Write-OperationsConvergenceFixture([string] $Path) {
    $resolvedPath = Resolve-ProjectPath $Path
    $directory = Split-Path -Parent $resolvedPath
    New-Item -ItemType Directory -Force -Path $directory | Out-Null

    $browserReadySubsetNote = "Run the ready subset plan command first without -Execute, then use the web dispatch URL(s) after operator review. GITHUB_CLI_AVAILABLE: GitHub CLI was not found on PATH. Web dispatch URL(s) for ready templates: action 6: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml. Review failed preflight checks and operator approvals before using browser dispatch."
    $securityFinalizerDependencyNote = "Security finalizer dependency: this dispatch can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml."
    $browserReadySubsetConvergenceNote = "$browserReadySubsetNote $securityFinalizerDependencyNote"

    $fixture = [ordered]@{
        formatVersion = "osmu.operations-readiness-convergence.v1"
        generatedAt = (Get-Date).ToString("o")
        result = "action-required"
        handoffReportPath = ".osmu-run/latest-operations-evidence-handoff.json"
        readinessReportPath = ".osmu-run/latest-operations-readiness.json"
        operationsReadinessFinalizeReportPath = ".osmu-run/latest-operations-readiness-finalize.json"
        handoffExists = $true
        handoffResult = "action-required"
        readinessExists = $true
        readinessResult = "pending"
        readinessSummary = "passed=82 pending=20"
        readinessPassedCount = 82
        readinessPendingCount = 20
        readinessTotalCount = 102
        readinessCheckCount = 102
        finalizerExists = $false
        finalizerResult = ""
        finalizerReadinessResult = ""
        finalizerFailedCount = 0
        kubernetesOperationsReportSyncReportPath = ".osmu-run/latest-kubernetes-operations-report-sync.json"
        kubernetesReportSyncExists = $true
        kubernetesReportSyncResult = "planned"
        kubernetesReportSyncFailedCount = 0
        kubernetesReportSyncConfigMapName = "osmu-operations-reports"
        kubernetesReportSyncConfigMapKey = "latest-operations-readiness-convergence.json"
        kubernetesReportSyncSourceReportResult = "action-required"
        kubernetesReportSyncStale = $false
        kubernetesReportSyncWorkflowCommand = "gh workflow run kubernetes-operations-report-sync-ci.yml -f namespace=osmu -f report_path=./.osmu-run/latest-operations-readiness-convergence.json -f run_live=true -f apply=false -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>"
        kubernetesReportSyncWorkflowNote = "Latest plan-mode sync evidence is fresh against the convergence report; production readiness still requires applied target Kubernetes operations report sync evidence."
        kubernetesReportSyncReady = $false
        finalizerGapCount = 0
        stageCount = 8
        readyStageCount = 2
        blockedActionCount = 0
        missingWorkflowRunCount = 1
        missingRequiredArtifactCount = 0
        failedImportCount = 0
        currentBottleneck = [ordered]@{
            code = "dispatch-ready-subset-browser"
            title = "Open browser dispatch for ready subset"
            reason = "The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web dispatch URL exists for action 6."
            command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 6"
            note = $browserReadySubsetConvergenceNote
            dispatchUrls = @("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml")
        }
        handoffBrowserDispatchDependencyNotes = @($securityFinalizerDependencyNote)
        handoffStale = $false
        handoffTimestamp = (Get-Date).AddSeconds(-1).ToString("o")
        readinessTimestamp = (Get-Date).AddSeconds(-4).ToString("o")
        recommendedCommands = @(
            [ordered]@{
                order = 1
                name = "Open browser dispatch for ready subset"
                command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 6"
                reason = "The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web dispatch URL exists for action 6."
                note = $browserReadySubsetConvergenceNote
                dispatchUrls = @("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml")
            }
        )
        decisionRule = "Operations readiness convergence is ready only when the handoff result is ready/none, the readiness report is ready, the operations readiness finalizer report exists with result=ready, readinessResult=ready, typed integer failedCount=0, and no gaps, and the Kubernetes operations report sync evidence confirms result=applied, typed integer failedCount=0, and sourceReportResult=ready."
        safetyPolicy = "This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance."
    }

    $fixture | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
    return $resolvedPath
}

$resolvedBrowserChannel = Resolve-DefaultBrowserChannel
$resolvedOperationsConvergenceFixturePath = Write-OperationsConvergenceFixture $OperationsConvergenceFixturePath
$previousBackendConvergenceReportPath = $env:OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH
$env:OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH = $resolvedOperationsConvergenceFixturePath

try {
    if (-not $NoPreClean) {
        Step "Pre-clean local prototype ports"
        Invoke-ProjectScript "stop-frontend-mock-demo.ps1" @("-ForcePorts")
        Invoke-ProjectScript "stop-local-prototype.ps1" @(
            "-LogDir", $LogDir,
            "-BackendPort", "$BackendPort",
            "-FrontendPort", "$FrontendPort",
            "-ForcePorts"
        )
    }

    Step "Playwright CLI"
    Assert-PlaywrightCli
    if ($resolvedBrowserChannel) {
        Write-Host "Browser channel: $resolvedBrowserChannel"
    } else {
        Write-Host "Browser channel: bundled Playwright browser"
        Write-Host "If this fails with a missing browser executable, run 'npx playwright install chromium' or set OSMU_PLAYWRIGHT_CHANNEL=chrome/msedge."
    }

    Step "Start local Java prototype"
    $startArgs = @(
        "-BackendPort", "$BackendPort",
        "-FrontendPort", "$FrontendPort",
        "-LogDir", $LogDir
    )
    if ($JavaHome) {
        $startArgs = @("-JavaHome", $JavaHome) + $startArgs
    }
    Invoke-ProjectScript "start-local-prototype.ps1" $startArgs

    if (-not $SkipApiSmoke) {
        Step "Backend API smoke against local prototype"
        Invoke-ProjectScript "verify-lightweight-prototype.ps1" @("-ApiBase", $apiBase)
    }

    Step "Browser E2E against local Java prototype"
    $previousFrontendBase = $env:OSMU_FRONTEND_BASE_URL
    $previousAdminLogin = $env:OSMU_ADMIN_LOGIN_ID
    $previousAdminPassword = $env:OSMU_ADMIN_PASSWORD
    $previousDeveloperLogin = $env:OSMU_DEVELOPER_LOGIN_ID
    $previousDeveloperPassword = $env:OSMU_DEVELOPER_PASSWORD
    $previousChannel = $env:OSMU_PLAYWRIGHT_CHANNEL
    $previousExpectOperationsConvergence = $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE
    try {
        $env:OSMU_FRONTEND_BASE_URL = $frontendBase
        $env:OSMU_ADMIN_LOGIN_ID = "admin"
        $env:OSMU_ADMIN_PASSWORD = "password"
        $env:OSMU_DEVELOPER_LOGIN_ID = "developer"
        $env:OSMU_DEVELOPER_PASSWORD = "password"
        $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE = "true"
        if ($resolvedBrowserChannel) {
            $env:OSMU_PLAYWRIGHT_CHANNEL = $resolvedBrowserChannel
        }

        Invoke-FrontendCommand @("run", "test:e2e")
    }
    finally {
        $env:OSMU_FRONTEND_BASE_URL = $previousFrontendBase
        $env:OSMU_ADMIN_LOGIN_ID = $previousAdminLogin
        $env:OSMU_ADMIN_PASSWORD = $previousAdminPassword
        $env:OSMU_DEVELOPER_LOGIN_ID = $previousDeveloperLogin
        $env:OSMU_DEVELOPER_PASSWORD = $previousDeveloperPassword
        $env:OSMU_PLAYWRIGHT_CHANNEL = $previousChannel
        $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE = $previousExpectOperationsConvergence
    }

    Write-Host "Browser E2E local Java prototype verified."
}
finally {
    Step "Stop local Java prototype"
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "stop-local-prototype.ps1") `
            -LogDir $LogDir
    }
    catch {
        Write-Warning "Stop local Java prototype failed: $($_.Exception.Message)"
    }
    $env:OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH = $previousBackendConvergenceReportPath
}
