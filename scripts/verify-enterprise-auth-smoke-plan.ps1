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
Assert-Contains $markdown "Plan-only and scope-out modes perform no HTTP requests." "enterprise auth smoke markdown"
Assert-Contains $markdown "Admin password, LDAP password, access/refresh tokens, OIDC authorization code/state" "enterprise auth smoke markdown"
Assert-Contains $markdown "token or credential-like OIDC claim/JIT JSON input fields are rejected before request execution" "enterprise auth smoke markdown"

foreach ($secret in @($adminSecret, $ldapSecret, $oidcCode, $oidcState)) {
    Assert-NotContains $reportText $secret "enterprise auth smoke JSON"
    Assert-NotContains $markdown $secret "enterprise auth smoke markdown"
}

$unsafeClaimPreviewPath = Join-Path $resolvedOutputDirectory "unsafe-claim-preview.json"
[ordered]@{
    claims = [ordered]@{
        sub = "enterprise-auth-user"
        email = "admin@example.com"
        access_token = "unsafe-access-token-self-test"
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $unsafeClaimPreviewPath -Encoding UTF8

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $unsafeClaimOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -OidcClaimPreviewJsonPath $unsafeClaimPreviewPath `
        -NoWrite 2>&1
    $unsafeClaimExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($unsafeClaimExitCode -ne 0) "Token-bearing OIDC claim preview input should be rejected."
Assert-Contains ($unsafeClaimOutput | Out-String) "token or credential-like property" "unsafe OIDC claim preview output"
Assert-NotContains ($unsafeClaimOutput | Out-String) "unsafe-access-token-self-test" "unsafe OIDC claim preview output"

$scopeOutJsonOutputPath = Join-Path $resolvedOutputDirectory "latest-enterprise-auth-smoke-scope-out.json"
$scopeOutMarkdownOutputPath = Join-Path $resolvedOutputDirectory "latest-enterprise-auth-smoke-scope-out.md"
& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -ConfirmScopeOut `
    -ScopeOutRef "pilot-contract-enterprise-auth-deferred-20260620" `
    -ScopeOutReason "Pilot phase uses local password login; IdP and LDAP smoke move to production onboarding." `
    -JsonOutputPath $scopeOutJsonOutputPath `
    -MarkdownOutputPath $scopeOutMarkdownOutputPath `
    -FailIfNotPassed | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "write-enterprise-auth-smoke-plan.ps1 scope-out mode failed with exit code $LASTEXITCODE."
}

$scopeOutReportText = Get-Content -Raw -LiteralPath $scopeOutJsonOutputPath
$scopeOutMarkdown = Get-Content -Raw -LiteralPath $scopeOutMarkdownOutputPath
$scopeOutReport = $scopeOutReportText | ConvertFrom-Json
$scopeOutChecks = @($scopeOutReport.checks)

Assert-True ($scopeOutReport.result -eq "scope-out") "Expected result=scope-out."
Assert-True ($scopeOutReport.executionMode -eq "scope-out") "Expected scope-out execution mode."
Assert-True ($scopeOutReport.scopeOut.confirmed) "Expected confirmed scope-out."
Assert-True ($scopeOutReport.scopeOut.accepted) "Expected accepted scope-out."
Assert-True (@($scopeOutChecks | Where-Object { $_.id -eq "enterprise-auth-scope-out-confirmed" -and $_.status -eq "PASS" }).Count -eq 1) "Expected scope-out confirmation check to pass."
Assert-Contains $scopeOutMarkdown "Explicit commercial scope-out" "enterprise auth scope-out markdown"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $invalidScopeOutOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
        -ConfirmScopeOut `
        -ScopeOutRef "pilot-contract-enterprise-auth-deferred-20260620" `
        -ScopeOutReason "password=super-secret" `
        -NoWrite 2>&1
    $invalidScopeOutExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidScopeOutExitCode -ne 0) "Credential-like scope-out reason should be rejected."
Assert-Contains ($invalidScopeOutOutput | Out-String) "ScopeOutReason appears to contain credential material" "invalid enterprise auth scope-out output"

Write-Host "Enterprise auth smoke plan verified."
Write-Host "JSON: $jsonOutputPath"
Write-Host "Markdown: $markdownOutputPath"
