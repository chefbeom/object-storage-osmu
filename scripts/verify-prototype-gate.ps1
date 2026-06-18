param(
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $FrontendBase = "http://localhost:5173",
    [string] $JavaHome = "",
    [switch] $ReseedDemo,
    [switch] $SkipS3ClientSmoke,
    [switch] $IncludeVirtualHostedS3Smoke,
    [switch] $IncludeBuildVerify,
    [switch] $IncludeBackendTests,
    [switch] $TryDocker
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$demoCredentialPath = Join-Path $root ".osmu-run\latest-demo.json"
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Invoke-Json($method, $url, $body = $null, $token = $null) {
    $headers = @{}
    if ($token) {
        $headers.Authorization = "Bearer $token"
    }

    if ($null -eq $body) {
        return Invoke-RestMethod -Method $method -Uri $url -Headers $headers
    }

    return Invoke-RestMethod `
        -Method $method `
        -Uri $url `
        -Headers $headers `
        -ContentType "application/json" `
        -Body ($body | ConvertTo-Json -Depth 12)
}

function Invoke-ProjectScript($scriptName, [string[]] $arguments = @()) {
    $scriptPath = Join-Path $PSScriptRoot $scriptName
    Write-Host "    $scriptName $($arguments -join ' ')"
    & powershell -ExecutionPolicy Bypass -File $scriptPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$scriptName failed with exit code $LASTEXITCODE."
    }
}

function Docker-Available() {
    Use-OsmuDockerConfig $root | Out-Null
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = docker info --format "{{json .ServerVersion}}" 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($exitCode -ne 0) {
        Write-Warning "Docker unavailable: $($output -join ' ')"
        return $false
    }
    return $true
}

function Read-DemoSnapshot() {
    if (-not (Test-Path -LiteralPath $demoCredentialPath)) {
        return $null
    }
    try {
        return Get-Content -Raw -LiteralPath $demoCredentialPath | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Gate-Value($enabled) {
    if ($enabled) {
        return "included"
    }
    return "skipped"
}

Step "Flyway migration version check"
Invoke-ProjectScript "verify-migrations.ps1"

Step "Runtime health"
Invoke-Json "GET" "$ApiBase/health" | Out-Null
$storageHealth = Invoke-Json "GET" "$ApiBase/storage/health"
$frontend = Invoke-WebRequest -Method GET -Uri $FrontendBase -UseBasicParsing
if ($frontend.StatusCode -ne 200) {
    throw "Frontend did not return HTTP 200."
}
Write-Host "Backend: $ApiBase/health"
Write-Host "Frontend: $FrontendBase"
Write-Host "Storage: $($storageHealth.data.engine) / $($storageHealth.data.status)"

if ($ReseedDemo -or -not (Test-Path -LiteralPath $demoCredentialPath)) {
    Step "Seed demo data"
    Invoke-ProjectScript "seed-lightweight-demo.ps1" @(
        "-ApiBase", $ApiBase,
        "-DemoOutputPath", $demoCredentialPath
    )
}

Step "Lightweight API smoke"
Invoke-ProjectScript "verify-lightweight-prototype.ps1" @(
    "-ApiBase", $ApiBase
)

Step "Lightweight demo smoke"
Invoke-ProjectScript "verify-lightweight-demo.ps1" @(
    "-FrontendBase", $FrontendBase,
    "-ApiBase", $ApiBase,
    "-DemoCredentialPath", $demoCredentialPath,
    "-SeedIfMissing"
)

if (-not $SkipS3ClientSmoke) {
    Step "S3 SigV4 smoke"
    $s3Arguments = @(
        "-ApiBase", $ApiBase,
        "-Client", "auto"
    )
    if (-not $IncludeVirtualHostedS3Smoke) {
        $s3Arguments += "-SkipVirtualHostedSmoke"
    }
    Invoke-ProjectScript "verify-s3-client-smoke.ps1" $s3Arguments
}

if ($IncludeBuildVerify) {
    Step "Build verify"
    $localVerifyArguments = @("-SkipDocker")
    if ($JavaHome) {
        $localVerifyArguments += @("-JavaHome", $JavaHome)
    }
    if (-not $IncludeBackendTests) {
        $localVerifyArguments += "-SkipBackend"
    }
    Invoke-ProjectScript "verify-local.ps1" $localVerifyArguments
}

if ($TryDocker) {
    Step "Docker smoke"
    if (Docker-Available) {
        Invoke-ProjectScript "verify-docker-integration.ps1"
    } else {
        Write-Warning "Docker smoke skipped because Docker daemon is not reachable."
    }
}

Step "Prototype summary"
$demoSnapshot = Read-DemoSnapshot
Write-Host "Runtime: passed"
Write-Host "Lightweight API smoke: passed"
Write-Host "Seeded demo smoke: passed"
Write-Host "S3 client smoke: $(Gate-Value (-not $SkipS3ClientSmoke))"
Write-Host "Build verify: $(Gate-Value $IncludeBuildVerify)"
Write-Host "Backend tests: $(Gate-Value ($IncludeBuildVerify -and $IncludeBackendTests))"
Write-Host "Docker smoke: $(Gate-Value $TryDocker)"
if ($demoSnapshot) {
    Write-Host "Demo user: $($demoSnapshot.demoUserLoginId) / $($demoSnapshot.demoPassword)"
    Write-Host "Demo buckets: $($demoSnapshot.mediaBucketName), $($demoSnapshot.aiBucketName)"
}
Write-Host "Backend: $ApiBase"
Write-Host "Frontend: $FrontendBase"

Step "Prototype gate passed"
Write-Host "Runtime, lightweight API, seeded demo, and configured optional gates passed."
