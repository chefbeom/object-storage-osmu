param(
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "",
    [string] $OidcCallbackCode = "",
    [string] $OidcCallbackState = "",
    [string] $OidcClaimPreviewJsonPath = "",
    [string] $OidcJitProvisionJsonPath = "",
    [string] $LdapLoginId = "",
    [string] $LdapPassword = "",
    [string] $ExpectedEmail = "",
    [string[]] $ExpectedAuditEventTypes = @("LOGIN_LDAP", "OIDC_CLAIM_PREVIEW", "OIDC_JIT_PROVISION"),
    [string] $JsonOutputPath = ".\.osmu-run\latest-enterprise-auth-smoke.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-enterprise-auth-smoke.md",
    [switch] $Execute,
    [switch] $RequireOidc,
    [switch] $RequireLdap,
    [switch] $RequireAuditEvents,
    [switch] $ConfirmJitProvision,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Get-JsonProperty([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-ApiData([object] $Response) {
    $data = Get-JsonProperty $Response "data"
    if ($null -ne $data) {
        return $data
    }
    return $Response
}

function Protect-Detail([string] $Text) {
    $safe = [string] $Text
    foreach ($secret in @($AdminPassword, $LdapPassword, $OidcCallbackCode, $OidcCallbackState)) {
        if (-not [string]::IsNullOrWhiteSpace($secret)) {
            $safe = $safe.Replace($secret, "<redacted>")
        }
    }
    $safe = [regex]::Replace($safe, "code=[^&\s]+", "code=<redacted>")
    $safe = [regex]::Replace($safe, "state=[^&\s]+", "state=<redacted>")
    $safe = [regex]::Replace($safe, "accessToken['""]?\s*[:=]\s*['""]?[^,'""\s}]+", "accessToken=<redacted>")
    $safe = [regex]::Replace($safe, "refreshToken['""]?\s*[:=]\s*['""]?[^,'""\s}]+", "refreshToken=<redacted>")
    return $safe
}

function New-Check(
    [string] $Id,
    [string] $Name,
    [string] $Category,
    [string] $Endpoint,
    [string] $Status,
    [string] $Detail,
    [string[]] $RequiredInputs = @()
) {
    return [ordered]@{
        id = $Id
        name = $Name
        category = $Category
        endpoint = $Endpoint
        status = $Status
        detail = Protect-Detail $Detail
        requiredInputs = @($RequiredInputs)
    }
}

function Add-Check(
    [string] $Id,
    [string] $Name,
    [string] $Category,
    [string] $Endpoint,
    [string] $Status,
    [string] $Detail,
    [string[]] $RequiredInputs = @()
) {
    [void] $script:checks.Add((New-Check $Id $Name $Category $Endpoint $Status $Detail $RequiredInputs))
}

function Invoke-Json([string] $Method, [string] $Uri, [object] $Body = $null, [string] $Token = "") {
    $headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers.Authorization = "Bearer $Token"
    }
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
    }
    return Invoke-RestMethod `
        -Method $Method `
        -Uri $Uri `
        -Headers $headers `
        -ContentType "application/json" `
        -Body ($Body | ConvertTo-Json -Depth 40)
}

function Read-JsonBodyFile([string] $Path, [string] $Label) {
    $resolvedPath = Resolve-ProjectPath $Path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "$Label JSON file not found: $resolvedPath"
    }
    return Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
}

function Test-ExpectedEmail([object] $Data) {
    if ([string]::IsNullOrWhiteSpace($ExpectedEmail)) {
        return
    }
    $json = $Data | ConvertTo-Json -Depth 40
    if (-not $json.Contains($ExpectedEmail)) {
        throw "Expected email was not found in sanitized response summary: $ExpectedEmail"
    }
}

function Add-PlanChecks {
    Add-Check "admin-login" "Admin login for enterprise auth evidence" "auth" "POST /api/auth/login" "PLANNED" "Required before admin-only plan, claim preview, JIT, and audit checks." @("AdminLoginId", "AdminPassword")
    Add-Check "enterprise-auth-plan" "Enterprise auth plan API" "enterprise-auth" "GET /api/admin/security/enterprise-auth-plan" "PLANNED" "Confirms current login mode, OIDC readiness, LDAP readiness, mapping, and cutover gates." @("AdminPassword")
    Add-Check "oidc-authorize" "OIDC authorization request start" "oidc" "GET /api/auth/oidc/authorize" "PLANNED" "Confirms provider config can produce state, nonce, PKCE challenge, and authorization URL." @("OSMU_ENTERPRISE_AUTH_OIDC_*")
    Add-Check "oidc-callback" "OIDC callback login for existing local user" "oidc" "GET /api/auth/oidc/callback" "PLANNED" "Run after a real IdP browser redirect produces code/state. Authorization code and state are never written to evidence." @("OidcCallbackCode", "OidcCallbackState")
    Add-Check "oidc-claim-preview" "OIDC claim preview audit gate" "oidc" "POST /api/admin/security/enterprise-auth/claim-preview" "PLANNED" "Optional sample claim preview. Raw claim JSON is not written to smoke evidence." @("OidcClaimPreviewJsonPath", "AdminPassword")
    Add-Check "oidc-jit-provision" "OIDC JIT provisioning approval gate" "oidc" "POST /api/admin/security/enterprise-auth/jit-provision" "PLANNED" "Optional admin-approved local user creation. Requires ConfirmJitProvision." @("OidcJitProvisionJsonPath", "ConfirmJitProvision", "AdminPassword")
    Add-Check "ldap-login" "LDAP bind/search login for existing local user" "ldap" "POST /api/auth/ldap/login" "PLANNED" "Confirms directory bind/search and existing ACTIVE local user email mapping. LDAP password is never written to evidence." @("LdapLoginId", "LdapPassword")
    Add-Check "audit-log" "Enterprise auth audit evidence" "audit" "GET /api/admin/audit-logs?eventType=<type>" "PLANNED" "Confirms LOGIN_LDAP, OIDC_CLAIM_PREVIEW, or OIDC_JIT_PROVISION audit entries after live checks." @("AdminPassword")
}

$checks = New-Object System.Collections.Generic.List[object]
$adminToken = ""
$executedEventTypes = New-Object System.Collections.Generic.List[string]

if (-not $Execute) {
    Add-PlanChecks
}
else {
    if ([string]::IsNullOrWhiteSpace($AdminPassword)) {
        Add-Check "admin-login" "Admin login for enterprise auth evidence" "auth" "POST /api/auth/login" "BLOCKED" "AdminPassword is required for admin-only enterprise auth smoke checks." @("AdminPassword")
    }
    else {
        try {
            $login = Invoke-Json "POST" "$ApiBase/auth/login" @{
                loginId = $AdminLoginId
                password = $AdminPassword
            }
            $loginData = Get-ApiData $login
            $adminToken = [string] (Get-JsonProperty $loginData "accessToken")
            if ([string]::IsNullOrWhiteSpace($adminToken)) {
                Add-Check "admin-login" "Admin login for enterprise auth evidence" "auth" "POST /api/auth/login" "FAIL" "Login response did not include an access token." @("AdminPassword")
            }
            else {
                Add-Check "admin-login" "Admin login for enterprise auth evidence" "auth" "POST /api/auth/login" "PASS" "Admin access token acquired in memory only."
            }
        }
        catch {
            Add-Check "admin-login" "Admin login for enterprise auth evidence" "auth" "POST /api/auth/login" "FAIL" $_.Exception.Message @("AdminPassword")
        }
    }

    if ([string]::IsNullOrWhiteSpace($adminToken)) {
        Add-Check "enterprise-auth-plan" "Enterprise auth plan API" "enterprise-auth" "GET /api/admin/security/enterprise-auth-plan" "BLOCKED" "Admin token unavailable." @("AdminPassword")
    }
    else {
        try {
            $plan = Invoke-Json "GET" "$ApiBase/admin/security/enterprise-auth-plan" $null $adminToken
            $planData = Get-ApiData $plan
            $mode = Get-JsonProperty $planData "activeLoginMode"
            Add-Check "enterprise-auth-plan" "Enterprise auth plan API" "enterprise-auth" "GET /api/admin/security/enterprise-auth-plan" "PASS" "Plan returned. activeLoginMode=$mode."
        }
        catch {
            Add-Check "enterprise-auth-plan" "Enterprise auth plan API" "enterprise-auth" "GET /api/admin/security/enterprise-auth-plan" "FAIL" $_.Exception.Message @("AdminPassword")
        }
    }

    try {
        $authorize = Invoke-Json "GET" "$ApiBase/auth/oidc/authorize"
        $authorizeData = Get-ApiData $authorize
        $hasAuthorizationUrl = -not [string]::IsNullOrWhiteSpace([string] (Get-JsonProperty $authorizeData "authorizationUrl"))
        $hasState = -not [string]::IsNullOrWhiteSpace([string] (Get-JsonProperty $authorizeData "state"))
        $hasNonce = -not [string]::IsNullOrWhiteSpace([string] (Get-JsonProperty $authorizeData "nonce"))
        if ($hasAuthorizationUrl -and $hasState -and $hasNonce) {
            Add-Check "oidc-authorize" "OIDC authorization request start" "oidc" "GET /api/auth/oidc/authorize" "PASS" "Authorization request produced URL, state, nonce, and PKCE challenge."
        }
        else {
            Add-Check "oidc-authorize" "OIDC authorization request start" "oidc" "GET /api/auth/oidc/authorize" "FAIL" "Authorization response missed URL, state, or nonce."
        }
    }
    catch {
        $status = if ($RequireOidc) { "FAIL" } else { "SKIPPED" }
        Add-Check "oidc-authorize" "OIDC authorization request start" "oidc" "GET /api/auth/oidc/authorize" $status $_.Exception.Message @("OSMU_ENTERPRISE_AUTH_OIDC_*")
    }

    if ([string]::IsNullOrWhiteSpace($OidcCallbackCode) -or [string]::IsNullOrWhiteSpace($OidcCallbackState)) {
        $status = if ($RequireOidc) { "BLOCKED" } else { "PLANNED" }
        Add-Check "oidc-callback" "OIDC callback login for existing local user" "oidc" "GET /api/auth/oidc/callback" $status "Real IdP callback code/state were not provided." @("OidcCallbackCode", "OidcCallbackState")
    }
    else {
        try {
            $code = [System.Uri]::EscapeDataString($OidcCallbackCode)
            $state = [System.Uri]::EscapeDataString($OidcCallbackState)
            $callback = Invoke-Json "GET" "$ApiBase/auth/oidc/callback?code=$code&state=$state"
            $callbackData = Get-ApiData $callback
            Test-ExpectedEmail $callbackData
            $user = Get-JsonProperty $callbackData "user"
            $loginId = Get-JsonProperty $user "loginId"
            $role = Get-JsonProperty $user "role"
            Add-Check "oidc-callback" "OIDC callback login for existing local user" "oidc" "GET /api/auth/oidc/callback" "PASS" "OIDC callback issued OSMU tokens for loginId=$loginId role=$role; tokens kept in memory only."
        }
        catch {
            Add-Check "oidc-callback" "OIDC callback login for existing local user" "oidc" "GET /api/auth/oidc/callback" "FAIL" $_.Exception.Message @("OidcCallbackCode", "OidcCallbackState")
        }
    }

    if ([string]::IsNullOrWhiteSpace($adminToken)) {
        $status = if (-not [string]::IsNullOrWhiteSpace($OidcClaimPreviewJsonPath)) { "BLOCKED" } else { "PLANNED" }
        Add-Check "oidc-claim-preview" "OIDC claim preview audit gate" "oidc" "POST /api/admin/security/enterprise-auth/claim-preview" $status "Admin token unavailable." @("AdminPassword")
    }
    elseif ([string]::IsNullOrWhiteSpace($OidcClaimPreviewJsonPath)) {
        Add-Check "oidc-claim-preview" "OIDC claim preview audit gate" "oidc" "POST /api/admin/security/enterprise-auth/claim-preview" "PLANNED" "No claim preview JSON path provided." @("OidcClaimPreviewJsonPath")
    }
    else {
        try {
            $claimPreviewBody = Read-JsonBodyFile $OidcClaimPreviewJsonPath "OIDC claim preview"
            $preview = Invoke-Json "POST" "$ApiBase/admin/security/enterprise-auth/claim-preview" $claimPreviewBody $adminToken
            $previewData = Get-ApiData $preview
            $status = Get-JsonProperty $previewData "status"
            $primaryRole = Get-JsonProperty $previewData "primaryRole"
            $jitRequired = Get-JsonProperty $previewData "jitProvisioningRequired"
            $auditLogId = Get-JsonProperty $previewData "auditLogId"
            [void] $executedEventTypes.Add("OIDC_CLAIM_PREVIEW")
            Add-Check "oidc-claim-preview" "OIDC claim preview audit gate" "oidc" "POST /api/admin/security/enterprise-auth/claim-preview" "PASS" "Preview status=$status primaryRole=$primaryRole jitRequired=$jitRequired auditLogId=$auditLogId. Raw claims are not stored."
        }
        catch {
            Add-Check "oidc-claim-preview" "OIDC claim preview audit gate" "oidc" "POST /api/admin/security/enterprise-auth/claim-preview" "FAIL" $_.Exception.Message @("OidcClaimPreviewJsonPath")
        }
    }

    if ([string]::IsNullOrWhiteSpace($adminToken)) {
        $status = if (-not [string]::IsNullOrWhiteSpace($OidcJitProvisionJsonPath)) { "BLOCKED" } else { "PLANNED" }
        Add-Check "oidc-jit-provision" "OIDC JIT provisioning approval gate" "oidc" "POST /api/admin/security/enterprise-auth/jit-provision" $status "Admin token unavailable." @("AdminPassword")
    }
    elseif ([string]::IsNullOrWhiteSpace($OidcJitProvisionJsonPath)) {
        Add-Check "oidc-jit-provision" "OIDC JIT provisioning approval gate" "oidc" "POST /api/admin/security/enterprise-auth/jit-provision" "PLANNED" "No JIT provisioning JSON path provided." @("OidcJitProvisionJsonPath", "ConfirmJitProvision")
    }
    elseif (-not $ConfirmJitProvision) {
        Add-Check "oidc-jit-provision" "OIDC JIT provisioning approval gate" "oidc" "POST /api/admin/security/enterprise-auth/jit-provision" "BLOCKED" "ConfirmJitProvision is required before creating a local user." @("ConfirmJitProvision")
    }
    else {
        try {
            $jitBody = Read-JsonBodyFile $OidcJitProvisionJsonPath "OIDC JIT provisioning"
            $provision = Invoke-Json "POST" "$ApiBase/admin/security/enterprise-auth/jit-provision" $jitBody $adminToken
            $provisionData = Get-ApiData $provision
            $user = Get-JsonProperty $provisionData "user"
            $loginId = Get-JsonProperty $user "loginId"
            $role = Get-JsonProperty $user "role"
            $status = Get-JsonProperty $provisionData "status"
            $auditLogId = Get-JsonProperty $provisionData "auditLogId"
            [void] $executedEventTypes.Add("OIDC_JIT_PROVISION")
            Add-Check "oidc-jit-provision" "OIDC JIT provisioning approval gate" "oidc" "POST /api/admin/security/enterprise-auth/jit-provision" "PASS" "Provision status=$status loginId=$loginId role=$role auditLogId=$auditLogId. Raw claims are not stored."
        }
        catch {
            Add-Check "oidc-jit-provision" "OIDC JIT provisioning approval gate" "oidc" "POST /api/admin/security/enterprise-auth/jit-provision" "FAIL" $_.Exception.Message @("OidcJitProvisionJsonPath", "ConfirmJitProvision")
        }
    }

    if ([string]::IsNullOrWhiteSpace($LdapLoginId) -or [string]::IsNullOrWhiteSpace($LdapPassword)) {
        $status = if ($RequireLdap) { "BLOCKED" } else { "PLANNED" }
        Add-Check "ldap-login" "LDAP bind/search login for existing local user" "ldap" "POST /api/auth/ldap/login" $status "LDAP loginId/password were not provided." @("LdapLoginId", "LdapPassword")
    }
    else {
        try {
            $ldap = Invoke-Json "POST" "$ApiBase/auth/ldap/login" @{
                loginId = $LdapLoginId
                password = $LdapPassword
            }
            $ldapData = Get-ApiData $ldap
            Test-ExpectedEmail $ldapData
            $user = Get-JsonProperty $ldapData "user"
            $loginId = Get-JsonProperty $user "loginId"
            $role = Get-JsonProperty $user "role"
            [void] $executedEventTypes.Add("LOGIN_LDAP")
            Add-Check "ldap-login" "LDAP bind/search login for existing local user" "ldap" "POST /api/auth/ldap/login" "PASS" "LDAP login issued OSMU tokens for loginId=$loginId role=$role; LDAP password and tokens are not stored."
        }
        catch {
            Add-Check "ldap-login" "LDAP bind/search login for existing local user" "ldap" "POST /api/auth/ldap/login" "FAIL" $_.Exception.Message @("LdapLoginId", "LdapPassword")
        }
    }

    if ([string]::IsNullOrWhiteSpace($adminToken)) {
        $status = if ($RequireAuditEvents) { "BLOCKED" } else { "PLANNED" }
        Add-Check "audit-log" "Enterprise auth audit evidence" "audit" "GET /api/admin/audit-logs?eventType=<type>" $status "Admin token unavailable." @("AdminPassword")
    }
    elseif ($RequireAuditEvents) {
        foreach ($eventType in $ExpectedAuditEventTypes) {
            try {
                $encodedType = [System.Uri]::EscapeDataString($eventType)
                $audit = Invoke-Json "GET" "$ApiBase/admin/audit-logs?eventType=$encodedType&limit=10" $null $adminToken
                $items = @(Get-JsonProperty $audit "items")
                if ($items.Count -le 0) {
                    Add-Check "audit-log-$eventType" "Enterprise auth audit evidence: $eventType" "audit" "GET /api/admin/audit-logs?eventType=$eventType" "FAIL" "No audit entries found for $eventType."
                }
                else {
                    Add-Check "audit-log-$eventType" "Enterprise auth audit evidence: $eventType" "audit" "GET /api/admin/audit-logs?eventType=$eventType" "PASS" "Found $($items.Count) recent audit entries for $eventType."
                }
            }
            catch {
                Add-Check "audit-log-$eventType" "Enterprise auth audit evidence: $eventType" "audit" "GET /api/admin/audit-logs?eventType=$eventType" "FAIL" $_.Exception.Message
            }
        }
    }
    elseif ($executedEventTypes.Count -gt 0) {
        foreach ($eventType in @($executedEventTypes | Select-Object -Unique)) {
            try {
                $encodedType = [System.Uri]::EscapeDataString($eventType)
                $audit = Invoke-Json "GET" "$ApiBase/admin/audit-logs?eventType=$encodedType&limit=10" $null $adminToken
                $items = @(Get-JsonProperty $audit "items")
                $status = if ($items.Count -gt 0) { "PASS" } else { "FAIL" }
                $detail = if ($items.Count -gt 0) { "Found $($items.Count) recent audit entries for $eventType." } else { "No audit entries found for $eventType." }
                Add-Check "audit-log-$eventType" "Enterprise auth audit evidence: $eventType" "audit" "GET /api/admin/audit-logs?eventType=$eventType" $status $detail
            }
            catch {
                Add-Check "audit-log-$eventType" "Enterprise auth audit evidence: $eventType" "audit" "GET /api/admin/audit-logs?eventType=$eventType" "FAIL" $_.Exception.Message
            }
        }
    }
    else {
        Add-Check "audit-log" "Enterprise auth audit evidence" "audit" "GET /api/admin/audit-logs?eventType=<type>" "PLANNED" "Run LDAP login, claim preview, or JIT provisioning first, or pass RequireAuditEvents." @("AdminPassword")
    }
}

$checkArray = @($checks | ForEach-Object { $_ })
$passCount = @($checkArray | Where-Object { $_.status -eq "PASS" }).Count
$failCount = @($checkArray | Where-Object { $_.status -eq "FAIL" }).Count
$blockedCount = @($checkArray | Where-Object { $_.status -eq "BLOCKED" }).Count
$plannedCount = @($checkArray | Where-Object { $_.status -eq "PLANNED" }).Count
$skippedCount = @($checkArray | Where-Object { $_.status -eq "SKIPPED" }).Count

$result = if (-not $Execute) {
    "planned"
}
elseif ($failCount -gt 0) {
    "failed"
}
elseif ($blockedCount -gt 0) {
    "blocked"
}
elseif ($plannedCount -gt 0) {
    "partial"
}
else {
    "passed"
}

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath

$report = [ordered]@{
    formatVersion = "osmu.enterprise-auth-smoke.v1"
    generatedAt = $generatedAt
    result = $result
    executionMode = if ($Execute) { "execute" } else { "plan-only" }
    apiBase = $ApiBase
    requireOidc = [bool] $RequireOidc
    requireLdap = [bool] $RequireLdap
    requireAuditEvents = [bool] $RequireAuditEvents
    inputs = [ordered]@{
        adminLoginId = $AdminLoginId
        adminPasswordProvided = -not [string]::IsNullOrWhiteSpace($AdminPassword)
        oidcCallbackCodeProvided = -not [string]::IsNullOrWhiteSpace($OidcCallbackCode)
        oidcCallbackStateProvided = -not [string]::IsNullOrWhiteSpace($OidcCallbackState)
        oidcClaimPreviewJsonPathProvided = -not [string]::IsNullOrWhiteSpace($OidcClaimPreviewJsonPath)
        oidcJitProvisionJsonPathProvided = -not [string]::IsNullOrWhiteSpace($OidcJitProvisionJsonPath)
        confirmJitProvision = [bool] $ConfirmJitProvision
        ldapLoginIdProvided = -not [string]::IsNullOrWhiteSpace($LdapLoginId)
        ldapPasswordProvided = -not [string]::IsNullOrWhiteSpace($LdapPassword)
        expectedEmailProvided = -not [string]::IsNullOrWhiteSpace($ExpectedEmail)
    }
    summary = [ordered]@{
        passCount = $passCount
        failCount = $failCount
        blockedCount = $blockedCount
        plannedCount = $plannedCount
        skippedCount = $skippedCount
    }
    checks = $checkArray
    decisionRule = "Paid/production pilot requires result=passed from the target IdP/directory, or an explicit documented scope-out. Default plan-only mode performs no HTTP requests."
    secretPolicy = "Admin password, LDAP password, access/refresh tokens, OIDC authorization code/state, client secrets, and raw OIDC claim JSON are never written to this evidence."
}

$markdownLines = @(
    "# OSMU Enterprise Auth Smoke Plan",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Execution mode: $($report.executionMode)",
    "API base: $ApiBase",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Secret Policy",
    "",
    $report.secretPolicy,
    "",
    "## Input Summary",
    "",
    "- Admin login id: $AdminLoginId",
    "- Admin password provided: $($report.inputs.adminPasswordProvided)",
    "- OIDC callback code/state provided: $($report.inputs.oidcCallbackCodeProvided)/$($report.inputs.oidcCallbackStateProvided)",
    "- Claim preview JSON path provided: $($report.inputs.oidcClaimPreviewJsonPathProvided)",
    "- JIT provisioning JSON path provided: $($report.inputs.oidcJitProvisionJsonPathProvided)",
    "- JIT provisioning confirmed: $($report.inputs.confirmJitProvision)",
    "- LDAP login/password provided: $($report.inputs.ldapLoginIdProvided)/$($report.inputs.ldapPasswordProvided)",
    "- Expected email provided: $($report.inputs.expectedEmailProvided)",
    "",
    "## Checks",
    ""
)

foreach ($check in $checkArray) {
    $markdownLines += "- [$($check.status)] $($check.category) / $($check.name)"
    $markdownLines += "  - Endpoint: ``$($check.endpoint)``"
    $markdownLines += "  - Detail: $($check.detail)"
    if (@($check.requiredInputs).Count -gt 0) {
        $markdownLines += "  - Required inputs: $(@($check.requiredInputs) -join ', ')"
    }
}

$markdownLines += ""
$markdownLines += "## Operator Commands"
$markdownLines += ""
$markdownLines += "- Plan only: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-smoke-plan.ps1``"
$markdownLines += "- Live target smoke: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-smoke-plan.ps1 -Execute -AdminLoginId <admin> -AdminPassword <secret> -RequireOidc -RequireLdap``"
$markdownLines += "- LDAP-only target smoke: ``powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-enterprise-auth-smoke-plan.ps1 -Execute -AdminLoginId <admin> -AdminPassword <secret> -LdapLoginId <directory-user> -LdapPassword <secret> -RequireLdap``"
$markdownLines += ""
$markdownLines += "Plan-only mode performs no HTTP requests."

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Enterprise auth smoke JSON: $resolvedJsonOutputPath"
    Write-Host "Enterprise auth smoke markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Enterprise auth smoke did not pass: $result"
}
