param(
    [string] $EnvFile = ".\infra\local\.env",
    [string] $EnvExample = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [switch] $NoBuild,
    [switch] $KeepRunning,
    [switch] $SkipDemoSmoke,
    [switch] $SkipS3AccessKeySmoke,
    [string] $DemoPassword = "DemoPassword!23",
    [string] $DemoOutputPath = ".\.osmu-run\latest-demo.json",
    [string] $OperationsConvergenceFixturePath = ".\.osmu-run\docker-local-demo\latest-operations-readiness-convergence.json",
    [int] $WaitTimeoutSeconds = 240,
    [string] $BrowserChannel = $env:OSMU_PLAYWRIGHT_CHANNEL,
    [switch] $SkipOperationsConvergenceFixture
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$frontendDir = Join-Path $root "osmu-frontend"
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Resolve-ProjectPath($path) {
    $path = Convert-OsmuPathSeparators $path
    if ([System.IO.Path]::IsPathRooted($path)) {
        return $path
    }
    return Join-Path $root $path
}

function Read-EnvValue($path, $name, $defaultValue) {
    $resolved = Resolve-Path -LiteralPath $path -ErrorAction Stop
    foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $resolved.Path) {
        if ($line -match "^\s*#" -or $line -match "^\s*$") {
            continue
        }
        if ($line -match "^\s*$([regex]::Escape($name))=(.*)$") {
            return $Matches[1].Trim()
        }
    }
    return $defaultValue
}

function Resolve-DefaultBrowserChannel() {
    if ($BrowserChannel) {
        return $BrowserChannel
    }

    if (-not (Test-OsmuWindows)) {
        return ""
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

function Invoke-ProjectScript([string] $ScriptName, [string[]] $Arguments = @()) {
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    Write-Host "    $ScriptName $($Arguments -join ' ')"
    $exitCode = Invoke-OsmuPowerShellScript $scriptPath $Arguments
    if ($exitCode -ne 0) {
        throw "$ScriptName failed with exit code $exitCode."
    }
}

function Invoke-FrontendCommand([string[]] $Arguments) {
    Push-Location $frontendDir
    try {
        $npm = Get-OsmuNpmExecutable
        & $npm @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "npm $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

function Resolve-ContainerReportPath([string] $Path) {
    $resolvedPath = Resolve-ProjectPath $Path
    $rootPath = [System.IO.Path]::GetFullPath($root)
    if (-not $rootPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootPath = "$rootPath$([System.IO.Path]::DirectorySeparatorChar)"
    }
    $relativeUri = ([Uri] $rootPath).MakeRelativeUri([Uri] ([System.IO.Path]::GetFullPath($resolvedPath)))
    $relativePath = [Uri]::UnescapeDataString($relativeUri.ToString()).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    if ($relativePath.StartsWith("..")) {
        throw "Operations convergence fixture must stay under the project root so Docker can mount it: $resolvedPath"
    }
    return ($relativePath -replace "\\", "/")
}

function Write-OperationsConvergenceFixture([string] $Path) {
    $resolvedPath = Resolve-ProjectPath $Path
    $directory = Split-Path -Parent $resolvedPath
    New-Item -ItemType Directory -Force -Path $directory | Out-Null

    $fixture = [ordered]@{
        formatVersion = "osmu.operations-readiness-convergence.v1"
        generatedAt = (Get-Date).ToString("o")
        result = "action-required"
        handoffReportPath = ".osmu-run/latest-operations-evidence-handoff.json"
        readinessReportPath = ".osmu-run/latest-operations-readiness.json"
        operationsReadinessFinalizeReportPath = ".osmu-run/latest-operations-readiness-finalize.json"
        handoffExists = $true
        handoffResult = "blocked"
        readinessExists = $true
        readinessResult = "pending"
        readinessSummary = "passed=36 pending=6"
        finalizerExists = $true
        finalizerResult = "pending"
        finalizerReadinessResult = "pending"
        finalizerFailedCount = 0
        finalizerGapCount = 1
        stageCount = 7
        readyStageCount = 1
        blockedActionCount = 5
        missingWorkflowRunCount = 6
        missingRequiredArtifactCount = 4
        failedImportCount = 0
        currentBottleneck = [ordered]@{
            code = "resolve-invocation-blockers"
            title = "Resolve invocation blockers"
            reason = "The invocation report still has blocked actions."
            command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-invocation-unblock-plan.ps1"
        }
        recommendedCommands = @(
            [ordered]@{
                order = 1
                name = "Resolve invocation blockers"
                command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-invocation-unblock-plan.ps1"
                reason = "The invocation report still has blocked actions."
            }
        )
        decisionRule = "Operations readiness convergence is ready only when handoff, readiness, and finalizer reports are ready."
        safetyPolicy = "This convergence writer does not execute kubectl, gh, workflow dispatch, or finalizer commands; it only reads local reports and writes JSON/Markdown guidance."
    }

    $fixture | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
    return $resolvedPath
}

function Assert-PlaywrightCli() {
    Push-Location $frontendDir
    try {
        $npx = Get-OsmuNpxExecutable
        & $npx playwright --version | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Playwright CLI is not available. Run 'npm install' from osmu-frontend first."
        }
    }
    finally {
        Pop-Location
    }
}

$resolvedBrowserChannel = Resolve-DefaultBrowserChannel
$resolvedEnvFile = Resolve-ProjectPath $EnvFile
$resolvedEnvExample = Resolve-ProjectPath $EnvExample
$previousBackendConvergenceReportPath = $env:OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH

try {
    $operationsConvergenceEnabled = -not $SkipOperationsConvergenceFixture
    if ($operationsConvergenceEnabled) {
        $fixturePath = Write-OperationsConvergenceFixture $OperationsConvergenceFixturePath
        $env:OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH = Resolve-ContainerReportPath $OperationsConvergenceFixturePath
        Write-Host "Operations convergence fixture: $fixturePath"
        Write-Host "Backend container report path: $env:OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH"
    }

    Step "Playwright CLI"
    Assert-PlaywrightCli
    if ($resolvedBrowserChannel) {
        Write-Host "Browser channel: $resolvedBrowserChannel"
    } else {
        Write-Host "Browser channel: bundled Playwright browser"
        Write-Host "If this fails with a missing browser executable, run 'npx playwright install chromium' or set OSMU_PLAYWRIGHT_CHANNEL=chrome/msedge."
    }

    Step "Start Docker local demo"
    $startArgs = @(
        "-EnvFile", $EnvFile,
        "-EnvExample", $EnvExample,
        "-ComposeFile", $ComposeFile,
        "-SeedDemo",
        "-DemoPassword", $DemoPassword,
        "-DemoOutputPath", $DemoOutputPath,
        "-WaitTimeoutSeconds", "$WaitTimeoutSeconds"
    )
    if ($NoBuild) {
        $startArgs += "-NoBuild"
    }
    if (-not $SkipDemoSmoke) {
        $startArgs += "-VerifyDemo"
    }
    if ($SkipS3AccessKeySmoke) {
        $startArgs += "-SkipS3AccessKeySmoke"
    }
    Invoke-ProjectScript "start-local-demo.ps1" $startArgs

    $envPathForRead = if (Test-Path -LiteralPath $resolvedEnvFile) {
        $resolvedEnvFile
    } else {
        $resolvedEnvExample
    }
    $frontendPort = Read-EnvValue $envPathForRead "FRONTEND_PORT" "5173"
    $adminLoginId = Read-EnvValue $envPathForRead "OSMU_ADMIN_LOGIN_ID" "admin"
    $adminPassword = Read-EnvValue $envPathForRead "OSMU_ADMIN_PASSWORD" "password"
    $frontendBase = "http://localhost:$frontendPort"

    Step "Browser E2E against Docker local demo"
    $previousFrontendBase = $env:OSMU_FRONTEND_BASE_URL
    $previousAdminLogin = $env:OSMU_ADMIN_LOGIN_ID
    $previousAdminPassword = $env:OSMU_ADMIN_PASSWORD
    $previousDeveloperLogin = $env:OSMU_DEVELOPER_LOGIN_ID
    $previousDeveloperPassword = $env:OSMU_DEVELOPER_PASSWORD
    $previousChannel = $env:OSMU_PLAYWRIGHT_CHANNEL
    $previousExpectOperationsConvergence = $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE
    try {
        $env:OSMU_FRONTEND_BASE_URL = $frontendBase
        $env:OSMU_ADMIN_LOGIN_ID = $adminLoginId
        $env:OSMU_ADMIN_PASSWORD = $adminPassword
        $env:OSMU_DEVELOPER_LOGIN_ID = "developer"
        $env:OSMU_DEVELOPER_PASSWORD = "password"
        if ($operationsConvergenceEnabled) {
            $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE = "true"
        }
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

    Write-Host "Docker local demo Browser E2E verified."
}
finally {
    $env:OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH = $previousBackendConvergenceReportPath
    if (-not $KeepRunning) {
        Step "Stop Docker local demo"
        try {
            Invoke-ProjectScript "stop-local-demo.ps1" @(
                "-EnvFile", $EnvFile,
                "-EnvExample", $EnvExample,
                "-ComposeFile", $ComposeFile
            )
        }
        catch {
            Write-Warning "Stop Docker local demo failed: $($_.Exception.Message)"
        }
    }
}
