param(
    [string] $OutputDirectory = ".\.osmu-run\enterprise-auth-smoke-self-test"
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
        throw "$label contains unexpected secret text: $unexpected"
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

$jsonOutputPath = Join-Path $resolvedOutputDirectory "latest-enterprise-auth-smoke.json"
$markdownOutputPath = Join-Path $resolvedOutputDirectory "latest-enterprise-auth-smoke.md"
$scriptPath = Resolve-ProjectPath ".\scripts\write-enterprise-auth-smoke-plan.ps1"

$adminSecret = "admin-secret-self-test"
$ldapSecret = "ldap-secret-self-test"
$oidcCode = "oidc-code-self-test"
$oidcState = "oidc-state-self-test"

& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -AdminLoginId "admin-self-test" `
    -AdminPassword $adminSecret `
    -LdapLoginId "ldap-self-test" `
    -LdapPassword $ldapSecret `
    -OidcCallbackCode $oidcCode `
    -OidcCallbackState $oidcState `
    -ExpectedEmail "admin@example.com" `
    -JsonOutputPath $jsonOutputPath `
    -MarkdownOutputPath $markdownOutputPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-enterprise-auth-smoke-plan.ps1 failed with exit code $LASTEXITCODE."
}

Assert-True (Test-Path -LiteralPath $jsonOutputPath) "Enterprise auth smoke JSON missing."
Assert-True (Test-Path -LiteralPath $markdownOutputPath) "Enterprise auth smoke markdown missing."

$reportText = Get-Content -Raw -LiteralPath $jsonOutputPath
$markdown = Get-Content -Raw -LiteralPath $markdownOutputPath
$report = $reportText | ConvertFrom-Json
$checks = @($report.checks)
$endpoints = ($checks | ForEach-Object { [string] $_.endpoint }) -join "`n"

Assert-True ($report.formatVersion -eq "osmu.enterprise-auth-smoke.v1") "Unexpected enterprise auth smoke formatVersion."
Assert-True ($report.result -eq "planned") "Expected planned result."
Assert-True ($report.executionMode -eq "plan-only") "Expected plan-only mode."
Assert-True ($checks.Count -ge 8) "Expected at least eight enterprise auth smoke checks."
Assert-True ($report.inputs.adminPasswordProvided) "Expected admin password provided flag."
Assert-True ($report.inputs.ldapPasswordProvided) "Expected LDAP password provided flag."
Assert-True ($report.inputs.oidcCallbackCodeProvided) "Expected OIDC callback code provided flag."
Assert-True ($report.inputs.oidcCallbackStateProvided) "Expected OIDC callback state provided flag."

Assert-Contains $endpoints "POST /api/auth/login" "enterprise auth smoke endpoints"
Assert-Contains $endpoints "GET /api/admin/security/enterprise-auth-plan" "enterprise auth smoke endpoints"
Assert-Contains $endpoints "GET /api/auth/oidc/authorize" "enterprise auth smoke endpoints"
Assert-Contains $endpoints "GET /api/auth/oidc/callback" "enterprise auth smoke endpoints"
Assert-Contains $endpoints "POST /api/auth/ldap/login" "enterprise auth smoke endpoints"
Assert-Contains $endpoints "POST /api/admin/security/enterprise-auth/claim-preview" "enterprise auth smoke endpoints"
Assert-Contains $endpoints "POST /api/admin/security/enterprise-auth/jit-provision" "enterprise auth smoke endpoints"
Assert-Contains $endpoints "GET /api/admin/audit-logs?eventType=<type>" "enterprise auth smoke endpoints"
Assert-Contains $markdown "# OSMU Enterprise Auth Smoke Plan" "enterprise auth smoke markdown"
Assert-Contains $markdown "Plan-only mode performs no HTTP requests." "enterprise auth smoke markdown"
Assert-Contains $markdown "Admin password, LDAP password, access/refresh tokens, OIDC authorization code/state" "enterprise auth smoke markdown"

foreach ($secret in @($adminSecret, $ldapSecret, $oidcCode, $oidcState)) {
    Assert-NotContains $reportText $secret "enterprise auth smoke JSON"
    Assert-NotContains $markdown $secret "enterprise auth smoke markdown"
}

Write-Host "Enterprise auth smoke plan verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
