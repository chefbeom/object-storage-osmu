param(
    [int] $ApiPort = 8080,
    [int] $FrontendPort = 5173,
    [int] $MultipartUploadThresholdBytes = 64,
    [int] $MultipartUploadPartSizeBytes = 32,
    [switch] $EnableMultipartFixture,
    [string] $TestGrep = "",
    [string] $BrowserChannel = $env:OSMU_PLAYWRIGHT_CHANNEL,
    [string] $LogDir = ".\.osmu-run\frontend-mock-demo",
    [switch] $NoPreClean
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$frontendDir = Join-Path $root "osmu-frontend"
$frontendBase = "http://localhost:$FrontendPort"

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

function Invoke-Json($method, $url) {
    return Invoke-RestMethod -Method $method -Uri $url
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

$resolvedBrowserChannel = Resolve-DefaultBrowserChannel

try {
    if (-not $NoPreClean) {
        Step "Pre-clean frontend mock demo ports"
        Invoke-ProjectScript "stop-frontend-mock-demo.ps1" @(
            "-LogDir", $LogDir,
            "-ForcePorts",
            "-Ports", "$ApiPort", "$FrontendPort"
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

    Step "Start frontend mock demo"
    $startArguments = @(
        "-ApiPort", "$ApiPort",
        "-FrontendPort", "$FrontendPort",
        "-LogDir", $LogDir
    )
    if ($EnableMultipartFixture) {
        $startArguments += @(
            "-MultipartUploadThresholdBytes", "$MultipartUploadThresholdBytes",
            "-MultipartUploadPartSizeBytes", "$MultipartUploadPartSizeBytes"
        )
    }
    Invoke-ProjectScript "start-frontend-mock-demo.ps1" $startArguments

    Step "Reset mock API state"
    $reset = Invoke-Json "POST" "http://localhost:$ApiPort/api/mock/reset"
    if (-not $reset.data.reset -or $reset.data.bucketCount -lt 2 -or $reset.data.objectCount -lt 3) {
        throw "Mock API reset did not restore expected fixture state."
    }

    Step "Browser E2E against frontend mock demo"
    $previousFrontendBase = $env:OSMU_FRONTEND_BASE_URL
    $previousAdminLogin = $env:OSMU_ADMIN_LOGIN_ID
    $previousAdminPassword = $env:OSMU_ADMIN_PASSWORD
    $previousDeveloperLogin = $env:OSMU_DEVELOPER_LOGIN_ID
    $previousDeveloperPassword = $env:OSMU_DEVELOPER_PASSWORD
    $previousChannel = $env:OSMU_PLAYWRIGHT_CHANNEL
    $previousExpectOperationsConvergence = $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE
    $previousMultipartFixture = $env:OSMU_BROWSER_MULTIPART_FIXTURE
    try {
        $env:OSMU_FRONTEND_BASE_URL = $frontendBase
        $env:OSMU_ADMIN_LOGIN_ID = "admin"
        $env:OSMU_ADMIN_PASSWORD = "password"
        $env:OSMU_DEVELOPER_LOGIN_ID = "developer"
        $env:OSMU_DEVELOPER_PASSWORD = "password"
        $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE = "true"
        if ($EnableMultipartFixture) {
            $env:OSMU_BROWSER_MULTIPART_FIXTURE = "true"
        }
        if ($resolvedBrowserChannel) {
            $env:OSMU_PLAYWRIGHT_CHANNEL = $resolvedBrowserChannel
        }

        if ($TestGrep) {
            Invoke-FrontendCommand @("run", "test:e2e", "--", "-g", $TestGrep)
        } else {
            Invoke-FrontendCommand @("run", "test:e2e")
        }
    }
    finally {
        $env:OSMU_FRONTEND_BASE_URL = $previousFrontendBase
        $env:OSMU_ADMIN_LOGIN_ID = $previousAdminLogin
        $env:OSMU_ADMIN_PASSWORD = $previousAdminPassword
        $env:OSMU_DEVELOPER_LOGIN_ID = $previousDeveloperLogin
        $env:OSMU_DEVELOPER_PASSWORD = $previousDeveloperPassword
        $env:OSMU_PLAYWRIGHT_CHANNEL = $previousChannel
        $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE = $previousExpectOperationsConvergence
        $env:OSMU_BROWSER_MULTIPART_FIXTURE = $previousMultipartFixture
    }

    Write-Host "Browser E2E mock demo verified."
}
finally {
    Step "Stop frontend mock demo"
    try {
        Invoke-ProjectScript "stop-frontend-mock-demo.ps1" @(
            "-LogDir", $LogDir,
            "-ForcePorts",
            "-Ports", "$ApiPort", "$FrontendPort"
        )
    }
    catch {
        Write-Warning "Stop frontend mock demo failed: $($_.Exception.Message)"
    }
}
