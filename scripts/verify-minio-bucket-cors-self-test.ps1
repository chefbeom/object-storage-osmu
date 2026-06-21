param(
    [string] $OutputDirectory = ".\.osmu-run\minio-bucket-cors-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Assert-Contains([string] $text, [string] $expected, [string] $label) {
    if (-not $text.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-NotContains([string] $text, [string] $unexpected, [string] $label) {
    if ($text.Contains($unexpected)) {
        throw "$label contains unexpected text: $unexpected"
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$scriptPath = Resolve-ProjectPath ".\scripts\verify-minio-bucket-cors.ps1"
$goodFixturePath = Join-Path $resolvedOutputDirectory "bucket-cors-good.xml"
$badFixturePath = Join-Path $resolvedOutputDirectory "bucket-cors-missing-etag.xml"
$planJsonPath = Join-Path $resolvedOutputDirectory "planned.json"
$planMarkdownPath = Join-Path $resolvedOutputDirectory "planned.md"
$goodJsonPath = Join-Path $resolvedOutputDirectory "passed.json"
$goodMarkdownPath = Join-Path $resolvedOutputDirectory "passed.md"
$badJsonPath = Join-Path $resolvedOutputDirectory "failed.json"
$badMarkdownPath = Join-Path $resolvedOutputDirectory "failed.md"

$goodFixture = @'
<CORSConfiguration>
  <CORSRule>
    <AllowedOrigin>http://localhost:5173</AllowedOrigin>
    <AllowedOrigin>http://127.0.0.1:5173</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedMethod>DELETE</AllowedMethod>
    <AllowedMethod>HEAD</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <ExposeHeader>ETag</ExposeHeader>
    <ExposeHeader>x-amz-request-id</ExposeHeader>
    <ExposeHeader>x-amz-id-2</ExposeHeader>
    <ExposeHeader>x-amz-version-id</ExposeHeader>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
'@
$goodFixture | Set-Content -LiteralPath $goodFixturePath -Encoding UTF8

$badFixture = @'
<CORSConfiguration>
  <CORSRule>
    <AllowedOrigin>http://localhost:5173</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedMethod>DELETE</AllowedMethod>
    <AllowedMethod>HEAD</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <ExposeHeader>x-amz-request-id</ExposeHeader>
    <ExposeHeader>x-amz-id-2</ExposeHeader>
    <ExposeHeader>x-amz-version-id</ExposeHeader>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
'@
$badFixture | Set-Content -LiteralPath $badFixturePath -Encoding UTF8

& $scriptPath `
    -JsonOutputPath $planJsonPath `
    -MarkdownOutputPath $planMarkdownPath | Out-Host

Assert-True (Test-Path -LiteralPath $planJsonPath) "Plan JSON missing."
$planReport = (Get-Content -Raw -LiteralPath $planJsonPath) | ConvertFrom-Json
Assert-True ($planReport.result -eq "planned") "Expected plan-only result=planned."
Assert-True ($planReport.source.rawCorsXmlStored -eq $false) "Expected plan report raw CORS XML omission."

& $scriptPath `
    -BucketName "smoke-cors" `
    -MinioAlias "osmu-minio" `
    -CorsXmlPath $goodFixturePath `
    -ExpectedAllowedOrigins @("http://localhost:5173", "http://127.0.0.1:5173") `
    -JsonOutputPath $goodJsonPath `
    -MarkdownOutputPath $goodMarkdownPath `
    -FailIfNotPassed | Out-Host

Assert-True (Test-Path -LiteralPath $goodJsonPath) "Passed JSON missing."
Assert-True (Test-Path -LiteralPath $goodMarkdownPath) "Passed markdown missing."

$goodReportText = Get-Content -Raw -LiteralPath $goodJsonPath
$goodMarkdown = Get-Content -Raw -LiteralPath $goodMarkdownPath
$goodReport = $goodReportText | ConvertFrom-Json
$goodChecks = @($goodReport.checks)

Assert-True ($goodReport.formatVersion -eq "osmu.minio-bucket-cors-verification.v1") "Unexpected formatVersion."
Assert-True ($goodReport.result -eq "passed") "Expected good fixture result=passed."
Assert-True ($goodReport.summary.failureCount -eq 0) "Expected no failed checks."
Assert-True ($goodReport.cors.ruleCount -eq 1) "Expected one CORS rule."
Assert-True (@($goodReport.cors.exposeHeaders | Where-Object { $_ -eq "ETag" }).Count -eq 1) "Expected ETag expose header."
Assert-True (@($goodChecks | Where-Object { $_.id -eq "expose-headers" -and $_.passed }).Count -eq 1) "Expected expose-headers check pass."
Assert-True ($goodReport.source.rawCorsXmlStored -eq $false) "Expected raw CORS XML omission."
Assert-Contains $goodMarkdown "# OSMU MinIO Bucket CORS Verification" "CORS markdown"
Assert-Contains $goodReport.scopePolicy "not AWS S3 parity work" "CORS JSON"
Assert-NotContains $goodReportText "<CORSConfiguration>" "CORS JSON"
Assert-NotContains $goodMarkdown "<CORSConfiguration>" "CORS markdown"

& $scriptPath `
    -CorsXmlPath $badFixturePath `
    -JsonOutputPath $badJsonPath `
    -MarkdownOutputPath $badMarkdownPath | Out-Host

$badReport = (Get-Content -Raw -LiteralPath $badJsonPath) | ConvertFrom-Json
$badChecks = @($badReport.checks)
Assert-True ($badReport.result -eq "failed") "Expected bad fixture result=failed."
Assert-True (@($badChecks | Where-Object { $_.id -eq "expose-headers" -and -not $_.passed }).Count -eq 1) "Expected expose-headers check fail."
$badExposeCheck = $badChecks | Where-Object { $_.id -eq "expose-headers" } | Select-Object -First 1
Assert-Contains $badExposeCheck.detail "ETag" "bad expose-headers detail"

Write-Host "MinIO bucket CORS verifier self-test passed."
Write-Host "JSON: $goodJsonPath"
Write-Host "Markdown: $goodMarkdownPath"
