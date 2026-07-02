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
    [switch] $SkipOperationsConvergenceFixture,
    [switch] $EnableRealMultipartFixture,
    [switch] $RunFullSuiteWithRealMultipartFixture,
    [int] $MultipartUploadThresholdBytes = 1048576,
    [int] $MultipartUploadPartSizeBytes = 5242880,
    [int] $MultipartUploadConcurrency = 1,
    [int] $RealMultipartFixtureFileBytes = 12582912,
    [int] $RealMultipartPartDelayMs = 1500,
    [string] $TestGrep = "",
    [string] $BrowserMultipartResumeEvidenceJsonPath = ".\.osmu-run\latest-browser-multipart-resume-evidence.json",
    [string] $BrowserMultipartResumeEvidenceMarkdownPath = ".\.osmu-run\latest-browser-multipart-resume-evidence.md"
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

function Read-DemoCredential($Path) {
    $resolvedPath = Resolve-ProjectPath $Path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Demo credential file is required for real multipart Browser E2E: $resolvedPath"
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedPath | ConvertFrom-Json
}

function Write-BrowserMultipartResumeEvidence(
    [string] $JsonPath,
    [string] $MarkdownPath,
    [string] $FrontendBaseUrl,
    [string] $BucketName,
    [string] $BrowserChannelName,
    [string] $ResolvedTestGrep,
    [string] $MinioPort
) {
    $resolvedJsonPath = Resolve-ProjectPath $JsonPath
    $resolvedMarkdownPath = Resolve-ProjectPath $MarkdownPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownPath) | Out-Null

    $generatedAt = (Get-Date).ToString("o")
    $report = [ordered]@{
        formatVersion = "osmu.browser-multipart-resume-evidence.v1"
        result = "passed"
        generatedAt = $generatedAt
        sourceMode = "docker-local-demo"
        evidenceKind = "real-minio-browser-multipart-pause-resume"
        frontendBaseUrl = $FrontendBaseUrl
        bucketName = $BucketName
        minioApiPort = $MinioPort
        browserChannel = if ($BrowserChannelName) { $BrowserChannelName } else { "playwright-default" }
        testGrep = $ResolvedTestGrep
        fixture = [ordered]@{
            multipartUploadThresholdBytes = $MultipartUploadThresholdBytes
            multipartUploadPartSizeBytes = $MultipartUploadPartSizeBytes
            multipartUploadConcurrency = $MultipartUploadConcurrency
            fileBytes = $RealMultipartFixtureFileBytes
            partDelayMs = $RealMultipartPartDelayMs
        }
        checks = @(
            [ordered]@{ id = "real-multipart-fixture-enabled"; status = "PASS"; detail = "EnableRealMultipartFixture was supplied." },
            [ordered]@{ id = "real-minio-bucket-selected"; status = "PASS"; detail = "Seeded writable demo bucket was selected without storing credentials." },
            [ordered]@{ id = "browser-e2e-completed"; status = "PASS"; detail = "Playwright real MinIO multipart pause/resume test completed successfully." },
            [ordered]@{ id = "no-secret-values-stored"; status = "PASS"; detail = "Evidence stores endpoint labels, fixture sizes, bucket name, and test metadata only." }
        )
        scopePolicy = "This evidence records the Docker local demo browser path for real MinIO multipart pause/resume. It proves OSMU browser upload operations readiness and is not AWS S3 parity expansion."
        secretPolicy = "Do not store demo passwords, access keys, secret keys, presigned URLs, bearer tokens, MinIO root credentials, object bytes, or raw request/response bodies in this report."
        operatorCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-local-demo.ps1 -EnableRealMultipartFixture -TestGrep `"real MinIO multipart`""
    }

    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedJsonPath -Encoding UTF8

    $markdownLines = @(
        "# OSMU Browser Multipart Resume Evidence",
        "",
        "Generated at: $generatedAt",
        "Result: passed",
        "Source mode: docker-local-demo",
        "Bucket: $BucketName",
        "Browser channel: $($report.browserChannel)",
        "Test grep: $ResolvedTestGrep",
        "",
        "## Fixture",
        "",
        "- Multipart threshold bytes: $MultipartUploadThresholdBytes",
        "- Multipart part size bytes: $MultipartUploadPartSizeBytes",
        "- Multipart concurrency: $MultipartUploadConcurrency",
        "- Fixture file bytes: $RealMultipartFixtureFileBytes",
        "- Real part delay ms: $RealMultipartPartDelayMs",
        "",
        "## Policy",
        "",
        $report.scopePolicy,
        "",
        $report.secretPolicy
    )
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownPath -Encoding UTF8
    Write-Host "Browser multipart resume evidence JSON: $resolvedJsonPath"
    Write-Host "Browser multipart resume evidence markdown: $resolvedMarkdownPath"
}

$resolvedBrowserChannel = Resolve-DefaultBrowserChannel
$resolvedEnvFile = Resolve-ProjectPath $EnvFile
$resolvedEnvExample = Resolve-ProjectPath $EnvExample
$previousBackendConvergenceReportPath = $env:OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH
$previousMultipartThreshold = $env:VITE_MULTIPART_UPLOAD_THRESHOLD_BYTES
$previousMultipartPartSize = $env:VITE_MULTIPART_UPLOAD_PART_SIZE_BYTES
$previousMultipartConcurrency = $env:VITE_MULTIPART_UPLOAD_CONCURRENCY

try {
    if ($EnableRealMultipartFixture) {
        $env:VITE_MULTIPART_UPLOAD_THRESHOLD_BYTES = "$MultipartUploadThresholdBytes"
        $env:VITE_MULTIPART_UPLOAD_PART_SIZE_BYTES = "$MultipartUploadPartSizeBytes"
        $env:VITE_MULTIPART_UPLOAD_CONCURRENCY = "$MultipartUploadConcurrency"
        Write-Host "Real multipart fixture frontend build args: threshold=$MultipartUploadThresholdBytes partSize=$MultipartUploadPartSizeBytes concurrency=$MultipartUploadConcurrency"
        if ($NoBuild) {
            Write-Warning "Real multipart fixture needs a frontend image built with the same VITE_MULTIPART_UPLOAD_* values."
        }
    }

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
    $minioApiPort = Read-EnvValue $envPathForRead "MINIO_API_PORT" "9000"
    $frontendBase = "http://localhost:$frontendPort"
    $developerLoginId = "developer"
    $developerPassword = "password"
    $realMultipartBucketName = ""
    if ($EnableRealMultipartFixture) {
        $demoCredential = Read-DemoCredential $DemoOutputPath
        $developerLoginId = [string] $demoCredential.demoUserLoginId
        $developerPassword = [string] $demoCredential.demoPassword
        $realMultipartBucketName = [string] $demoCredential.mediaBucketName
        if (-not $developerLoginId -or -not $developerPassword -or -not $realMultipartBucketName) {
            throw "Demo credential file does not contain demoUserLoginId, demoPassword, and mediaBucketName."
        }
        Write-Host "Real multipart fixture bucket: $realMultipartBucketName"
    }

    Step "Browser E2E against Docker local demo"
    $previousFrontendBase = $env:OSMU_FRONTEND_BASE_URL
    $previousAdminLogin = $env:OSMU_ADMIN_LOGIN_ID
    $previousAdminPassword = $env:OSMU_ADMIN_PASSWORD
    $previousDeveloperLogin = $env:OSMU_DEVELOPER_LOGIN_ID
    $previousDeveloperPassword = $env:OSMU_DEVELOPER_PASSWORD
    $previousChannel = $env:OSMU_PLAYWRIGHT_CHANNEL
    $previousExpectOperationsConvergence = $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE
    $previousRealMultipartFixture = $env:OSMU_BROWSER_REAL_MULTIPART_FIXTURE
    $previousRealMultipartBucket = $env:OSMU_BROWSER_REAL_MULTIPART_BUCKET
    $previousRealMultipartFileBytes = $env:OSMU_BROWSER_REAL_MULTIPART_FILE_BYTES
    $previousRealMultipartPartDelayMs = $env:OSMU_BROWSER_REAL_MULTIPART_PART_DELAY_MS
    $previousMinioApiPort = $env:OSMU_MINIO_API_PORT
    try {
        $env:OSMU_FRONTEND_BASE_URL = $frontendBase
        $env:OSMU_ADMIN_LOGIN_ID = $adminLoginId
        $env:OSMU_ADMIN_PASSWORD = $adminPassword
        $env:OSMU_DEVELOPER_LOGIN_ID = $developerLoginId
        $env:OSMU_DEVELOPER_PASSWORD = $developerPassword
        if ($operationsConvergenceEnabled) {
            $env:OSMU_EXPECT_OPERATIONS_CONVERGENCE = "true"
        }
        if ($EnableRealMultipartFixture) {
            $env:OSMU_BROWSER_REAL_MULTIPART_FIXTURE = "true"
            $env:OSMU_BROWSER_REAL_MULTIPART_BUCKET = $realMultipartBucketName
            $env:OSMU_BROWSER_REAL_MULTIPART_FILE_BYTES = "$RealMultipartFixtureFileBytes"
            $env:OSMU_BROWSER_REAL_MULTIPART_PART_DELAY_MS = "$RealMultipartPartDelayMs"
            $env:OSMU_MINIO_API_PORT = "$minioApiPort"
        }
        if ($resolvedBrowserChannel) {
            $env:OSMU_PLAYWRIGHT_CHANNEL = $resolvedBrowserChannel
        }

        $resolvedTestGrep = $TestGrep
        if ($EnableRealMultipartFixture -and -not $RunFullSuiteWithRealMultipartFixture -and -not $resolvedTestGrep) {
            $resolvedTestGrep = "real MinIO multipart"
        }
        if ($resolvedTestGrep) {
            Invoke-FrontendCommand @("run", "test:e2e", "--", "-g", $resolvedTestGrep)
        } else {
            Invoke-FrontendCommand @("run", "test:e2e")
        }

        if ($EnableRealMultipartFixture) {
            Write-BrowserMultipartResumeEvidence `
                -JsonPath $BrowserMultipartResumeEvidenceJsonPath `
                -MarkdownPath $BrowserMultipartResumeEvidenceMarkdownPath `
                -FrontendBaseUrl $frontendBase `
                -BucketName $realMultipartBucketName `
                -BrowserChannelName $resolvedBrowserChannel `
                -ResolvedTestGrep $resolvedTestGrep `
                -MinioPort $minioApiPort
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
        $env:OSMU_BROWSER_REAL_MULTIPART_FIXTURE = $previousRealMultipartFixture
        $env:OSMU_BROWSER_REAL_MULTIPART_BUCKET = $previousRealMultipartBucket
        $env:OSMU_BROWSER_REAL_MULTIPART_FILE_BYTES = $previousRealMultipartFileBytes
        $env:OSMU_BROWSER_REAL_MULTIPART_PART_DELAY_MS = $previousRealMultipartPartDelayMs
        $env:OSMU_MINIO_API_PORT = $previousMinioApiPort
    }

    Write-Host "Docker local demo Browser E2E verified."
}
finally {
    $env:OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH = $previousBackendConvergenceReportPath
    $env:VITE_MULTIPART_UPLOAD_THRESHOLD_BYTES = $previousMultipartThreshold
    $env:VITE_MULTIPART_UPLOAD_PART_SIZE_BYTES = $previousMultipartPartSize
    $env:VITE_MULTIPART_UPLOAD_CONCURRENCY = $previousMultipartConcurrency
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
