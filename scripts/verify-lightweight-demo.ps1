param(
    [string] $FrontendBase = "http://localhost:5173",
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "password",
    [string] $DemoLoginId = "",
    [string] $DemoPassword = "DemoPassword!23",
    [string] $S3Endpoint = "",
    [string] $DemoCredentialPath = "",
    [string[]] $BackendLogPath = @(),
    [switch] $SeedIfMissing,
    [switch] $SkipS3AccessKeySmoke
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "runtime-toolchain.ps1")

if (-not $S3Endpoint) {
    $S3Endpoint = "$ApiBase/s3"
}
if (-not $DemoCredentialPath) {
    $DemoCredentialPath = Join-Path $root ".osmu-run\latest-demo.json"
}
$DemoCredentialPath = Convert-OsmuPathSeparators $DemoCredentialPath

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Invoke-Json($method, $url, $body = $null, $token = $null, $throwOnError = $true) {
    $headers = @{}
    if ($token) {
        $headers.Authorization = "Bearer $token"
    }

    try {
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
    catch {
        if ($throwOnError) {
            throw
        }
        return $_.Exception.Response
    }
}

function Assert-Contains($text, $needle, $label) {
    if (-not $text.Contains($needle)) {
        throw "$label did not contain expected text: $needle"
    }
}

function Assert-SecretAbsent($text, $secret, $label) {
    if ($secret -and $text -and $text.Contains($secret)) {
        throw "$label contained generated access key secret."
    }
}

function WebResponse-Text($response) {
    if ($response.Content -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($response.Content)
    }
    return [string]$response.Content
}

function Assert-SecretAbsentFromLogs($paths, $secret) {
    foreach ($path in $paths) {
        if (-not $path) {
            continue
        }
        $resolvedPath = if ([System.IO.Path]::IsPathRooted($path)) {
            $path
        } else {
            Join-Path $root $path
        }
        if (-not (Test-Path -LiteralPath $resolvedPath)) {
            throw "Backend log file was not found: $resolvedPath"
        }
        $logText = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedPath
        Assert-SecretAbsent $logText $secret "backend log $resolvedPath"
    }
}

function Resolve-FrontendUrl($baseUrl, $path) {
    $base = if ($baseUrl.EndsWith("/")) { $baseUrl } else { "$baseUrl/" }
    $uri = [System.Uri]::new([System.Uri] $base, $path.TrimStart("/"))
    return $uri.AbsoluteUri
}

function Frontend-Text($baseUrl, $path, $throwOnError = $true) {
    $url = Resolve-FrontendUrl $baseUrl $path
    try {
        return (Invoke-WebRequest -Method GET -Uri $url -UseBasicParsing).Content
    }
    catch {
        if ($throwOnError) {
            throw
        }
        return ""
    }
}

function Frontend-AssetBundle($baseUrl, $html, $extension) {
    $escapedExtension = [regex]::Escape($extension)
    $pattern = "(?:src|href)=`"([^`"]+\.$escapedExtension(?:\?[^`"]*)?)`""
    $assetPaths = [regex]::Matches($html, $pattern) | ForEach-Object { $_.Groups[1].Value }
    $texts = @()
    foreach ($assetPath in $assetPaths) {
        $texts += Frontend-Text $baseUrl $assetPath
    }
    return $texts -join "`n"
}

function Upload-ExpectForbidden($apiBase, $bucketName, $token) {
    Add-Type -AssemblyName System.Net.Http

    $client = [System.Net.Http.HttpClient]::new()
    try {
        $client.DefaultRequestHeaders.Authorization =
            [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $token)

        $content = [System.Net.Http.MultipartFormDataContent]::new()
        $content.Add([System.Net.Http.StringContent]::new("readonly-write-check.txt"), "key")
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("should be forbidden")
        $fileContent = [System.Net.Http.ByteArrayContent]::new($bytes)
        $fileContent.Headers.ContentType =
            [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/plain")
        $content.Add($fileContent, "file", "readonly-write-check.txt")

        $response = $client.PostAsync("$apiBase/buckets/$bucketName/objects", $content).GetAwaiter().GetResult()
        if ([int] $response.StatusCode -ne 403) {
            $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            throw "Expected forbidden write to $bucketName, got HTTP $([int] $response.StatusCode) $responseBody"
        }
    }
    finally {
        $client.Dispose()
    }
}

function Get-Sha256Hex([byte[]] $Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
        $sha.Dispose()
    }
}

function Get-HmacSha256([byte[]] $Key, [string] $Text) {
    $hmac = [System.Security.Cryptography.HMACSHA256]::new($Key)
    try {
        return $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    }
    finally {
        $hmac.Dispose()
    }
}

function Get-S3CanonicalQuery([Uri] $Uri) {
    if (-not $Uri.Query) {
        return ""
    }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($token in $Uri.Query.TrimStart("?").Split("&")) {
        if (-not $token) {
            continue
        }
        $separator = $token.IndexOf("=")
        $name = if ($separator -lt 0) { $token } else { $token.Substring(0, $separator) }
        $value = if ($separator -lt 0) { "" } else { $token.Substring($separator + 1) }
        $parts.Add("$([System.Uri]::EscapeDataString([System.Uri]::UnescapeDataString($name)))=$([System.Uri]::EscapeDataString([System.Uri]::UnescapeDataString($value)))")
    }
    return (($parts | Sort-Object) -join "&")
}

function New-S3SigV4Headers($method, $url, [byte[]] $PayloadBytes, $accessKey, $secretKey) {
    $uri = [Uri] $url
    $hostHeader = if ($uri.IsDefaultPort) { $uri.Host } else { "$($uri.Host):$($uri.Port)" }
    $amzDate = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")
    $date = $amzDate.Substring(0, 8)
    $payloadHash = Get-Sha256Hex $PayloadBytes
    $signedHeaders = "host;x-amz-content-sha256;x-amz-date"
    $canonicalHeaders = "host:$hostHeader`nx-amz-content-sha256:$payloadHash`nx-amz-date:$amzDate`n"
    $canonicalRequest = "$method`n$($uri.AbsolutePath)`n$(Get-S3CanonicalQuery $uri)`n$canonicalHeaders`n$signedHeaders`n$payloadHash"
    $scope = "$date/us-east-1/s3/aws4_request"
    $stringToSign = "AWS4-HMAC-SHA256`n$amzDate`n$scope`n$(Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($canonicalRequest)))"

    $dateKey = Get-HmacSha256 ([System.Text.Encoding]::UTF8.GetBytes("AWS4$secretKey")) $date
    $regionKey = Get-HmacSha256 $dateKey "us-east-1"
    $serviceKey = Get-HmacSha256 $regionKey "s3"
    $signingKey = Get-HmacSha256 $serviceKey "aws4_request"
    $signature = ((Get-HmacSha256 $signingKey $stringToSign | ForEach-Object { $_.ToString("x2") }) -join "")

    return @{
        Authorization = "AWS4-HMAC-SHA256 Credential=$accessKey/$scope, SignedHeaders=$signedHeaders, Signature=$signature"
        "x-amz-date" = $amzDate
        "x-amz-content-sha256" = $payloadHash
    }
}

function Invoke-SignedHttp($method, $url, [byte[]] $PayloadBytes, $accessKey, $secretKey, $contentType = "application/octet-stream") {
    Add-Type -AssemblyName System.Net.Http

    $client = [System.Net.Http.HttpClient]::new()
    try {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($method), $url)
        $headers = New-S3SigV4Headers $method $url $PayloadBytes $accessKey $secretKey
        foreach ($entry in $headers.GetEnumerator()) {
            [void]$request.Headers.TryAddWithoutValidation($entry.Key, [string]$entry.Value)
        }
        if ($PayloadBytes.Length -gt 0 -or $method -in @("PUT", "POST")) {
            $content = [System.Net.Http.ByteArrayContent]::new($PayloadBytes)
            $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($contentType)
            $request.Content = $content
        }
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    finally {
        $client.Dispose()
    }
}

function Read-DemoCredentials($path) {
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }
    return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
}

function Invoke-DemoS3Smoke($s3Endpoint, $credentials) {
    $emptyPayload = [byte[]]::new(0)
    $mediaBucketName = $credentials.mediaBucketName
    $aiBucketName = $credentials.aiBucketName
    $accessKey = $credentials.accessKey
    $secretKey = $credentials.secretKey

    if (-not $mediaBucketName -or -not $aiBucketName -or -not $accessKey -or -not $secretKey) {
        throw "Demo credential file is missing bucket or access key fields."
    }

    $rootResponse = Invoke-SignedHttp "GET" $s3Endpoint $emptyPayload $accessKey $secretKey
    if ($rootResponse.StatusCode -ne 200 `
            -or -not $rootResponse.Body.Contains("<Name>$mediaBucketName</Name>") `
            -or -not $rootResponse.Body.Contains("<Name>$aiBucketName</Name>")) {
        throw "S3 root bucket list did not include seeded buckets."
    }

    $mediaGet = Invoke-SignedHttp "GET" "$s3Endpoint/$mediaBucketName/videos/raw/sample-video-manifest.txt" $emptyPayload $accessKey $secretKey
    if ($mediaGet.StatusCode -ne 200 -or -not $mediaGet.Body.Contains("sampleId=video-001")) {
        throw "S3 seeded media object GET failed."
    }

    $mediaPutBytes = [System.Text.Encoding]::UTF8.GetBytes("seeded access key write smoke")
    $mediaPut = Invoke-SignedHttp "PUT" "$s3Endpoint/$mediaBucketName/s3-smoke/write-check.txt" $mediaPutBytes $accessKey $secretKey "text/plain"
    if ($mediaPut.StatusCode -ne 200) {
        throw "S3 seeded media object PUT failed: HTTP $($mediaPut.StatusCode) $($mediaPut.Body)"
    }

    $aiGet = Invoke-SignedHttp "GET" "$s3Endpoint/$aiBucketName/datasets/images/sample-dataset.json" $emptyPayload $accessKey $secretKey
    if ($aiGet.StatusCode -ne 200 -or -not $aiGet.Body.Contains("sample-images")) {
        throw "S3 seeded AI object GET failed."
    }

    $aiPut = Invoke-SignedHttp "PUT" "$s3Endpoint/$aiBucketName/s3-smoke/blocked-write.txt" $mediaPutBytes $accessKey $secretKey "text/plain"
    if ($aiPut.StatusCode -ne 403 -or -not $aiPut.Body.Contains("<Code>AccessDenied</Code>")) {
        throw "S3 seeded AI bucket write was not denied: HTTP $($aiPut.StatusCode) $($aiPut.Body)"
    }
}

function Latest-DemoUser($users) {
    return $users |
        Where-Object { $_.loginId -like "demo-user-*" } |
        Sort-Object -Property id -Descending |
        Select-Object -First 1
}

function Find-DemoUser($apiBase, $adminToken, $demoLoginId) {
    $users = Invoke-Json "GET" "$apiBase/admin/users" $null $adminToken
    if ($demoLoginId) {
        return $users.items | Where-Object { $_.loginId -eq $demoLoginId } | Select-Object -First 1
    }
    return Latest-DemoUser $users.items
}

Step "Frontend dev modules"
$homePage = Invoke-WebRequest -Method GET -Uri $FrontendBase -UseBasicParsing
if ($homePage.StatusCode -ne 200) {
    throw "Frontend did not return HTTP 200."
}
$loginPage = Invoke-WebRequest -Method GET -Uri (Resolve-FrontendUrl $FrontendBase "/login") -UseBasicParsing
if ($loginPage.StatusCode -ne 200) {
    throw "Frontend /login did not return HTTP 200."
}
$html = $homePage.Content
$loginHtml = $loginPage.Content
$mainModule = Frontend-Text $FrontendBase "/src/main.js" $false
$homeViewModule = Frontend-Text $FrontendBase "/src/views/HomeView.vue" $false
$loginViewModule = Frontend-Text $FrontendBase "/src/views/LoginView.vue" $false
$apiModule = Frontend-Text $FrontendBase "/src/services/api.js" $false
$cssModule = Frontend-Text $FrontendBase "/src/assets/main.css" $false
$jsBundle = Frontend-AssetBundle $FrontendBase $html "js"
$cssBundle = Frontend-AssetBundle $FrontendBase $html "css"

$mainText = "$mainModule`n$jsBundle"
$uiText = "$homeViewModule`n$loginViewModule`n$jsBundle"
$apiText = "$apiModule`n$jsBundle"
$styleText = "$cssModule`n$cssBundle"

Assert-Contains $html "<div id=`"app`"></div>" "frontend HTML"
Assert-Contains $loginHtml "<div id=`"app`"></div>" "frontend /login HTML"
Assert-Contains $mainText "createApp" "frontend JS"
Assert-Contains $uiText "login-form" "frontend login UI bundle"
Assert-Contains $uiText "login-auto-login-checkbox" "frontend login UI bundle"
Assert-Contains $uiText "login-remember-id-checkbox" "frontend login UI bundle"
Assert-Contains $uiText "login-password-toggle" "frontend login UI bundle"
Assert-Contains $uiText "login-mode-admin" "frontend login UI bundle"
Assert-Contains $uiText "login-mode-developer" "frontend login UI bundle"
Assert-Contains $uiText "login-info-alert" "frontend login UI bundle"
Assert-Contains $uiText "RAID 0-9" "frontend login UI bundle"
Assert-Contains $uiText "JBOD" "frontend login UI bundle"
Assert-Contains $uiText "IAM User" "frontend login UI bundle"
Assert-Contains $uiText "Access Key" "frontend login UI bundle"
Assert-Contains $uiText "Operations Dashboard" "frontend UI bundle"
Assert-Contains $uiText "Dashboard Palettes" "frontend UI bundle"
Assert-Contains $uiText "access-keys" "frontend UI bundle"
Assert-Contains $uiText "identity" "frontend UI bundle"
Assert-Contains $uiText "lifecycle" "frontend UI bundle"
Assert-Contains $uiText "dashboard-layout-preset-update-button" "frontend UI bundle"
Assert-Contains $uiText "dashboard-layout-preset-export-button" "frontend UI bundle"
Assert-Contains $uiText "dashboard-layout-preset-import-input" "frontend UI bundle"
Assert-Contains $uiText "dashboard-layout-preset-bundle-export-button" "frontend UI bundle"
Assert-Contains $uiText "dashboard-layout-preset-bundle-import-input" "frontend UI bundle"
Assert-Contains $uiText "dashboard-layout-default-panel" "frontend UI bundle"
Assert-Contains $uiText "dashboard-layout-default-save-button" "frontend UI bundle"
Assert-Contains $uiText "dashboard-widget-section-toggle-button" "frontend UI bundle"
Assert-Contains $uiText "object-panel" "frontend UI bundle"
Assert-Contains $uiText "Lifecycle Rules" "frontend UI bundle"
Assert-Contains $uiText "Bucket Tags" "frontend UI bundle"
Assert-Contains $uiText "Organizations" "frontend UI bundle"
Assert-Contains $uiText "organization-form" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-panel" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-create-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-apply-evidence-input" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-preview-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-execution-plan-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-gitops-plan-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-tenant-yaml" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-helm-yaml" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-download-tenant-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-download-helm-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-download-bundle-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-execution-plan-panel" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-execution-commands" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-dry-run-record-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-dry-run-runner-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-apply-run-type-select" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-apply-runner-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-dry-run-output-input" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-gitops-plan-panel" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-gitops-pr-body" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-gitops-pr-url-input" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-gitops-pr-record-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-gitops-pr-runner-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-gitops-bundle-download-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-execution-history-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-execution-history-panel" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-execution-record-form" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-execution-history-list" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-execution-apply-button" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-rollback-type-select" "frontend UI bundle"
Assert-Contains $uiText "storage-expansion-rollback-runner-button" "frontend UI bundle"
Assert-Contains $uiText "audit-filter" "frontend UI bundle"
Assert-Contains $uiText "CSV" "frontend UI bundle"
Assert-Contains $apiText "object-lifecycle/rules" "frontend API bundle"
Assert-Contains $apiText "dashboard/layout/widgets" "frontend API bundle"
Assert-Contains $apiText "dashboard/layout/presets/import" "frontend API bundle"
Assert-Contains $apiText "dashboard/layout/preset-bundle/import" "frontend API bundle"
Assert-Contains $apiText "dashboard/layout/defaults" "frontend API bundle"
Assert-Contains $apiText "admin/storage-expansion/requests" "frontend API bundle"
Assert-Contains $apiText "/manifest" "frontend API bundle"
Assert-Contains $apiText "/manifest/" "frontend API bundle"
Assert-Contains $apiText "/execution-plan" "frontend API bundle"
Assert-Contains $apiText "/dry-run-execution" "frontend API bundle"
Assert-Contains $apiText "/dry-run-runner" "frontend API bundle"
Assert-Contains $apiText "/apply-runner" "frontend API bundle"
Assert-Contains $apiText "/rollback-runner" "frontend API bundle"
Assert-Contains $apiText "/gitops-plan" "frontend API bundle"
Assert-Contains $apiText "/gitops-artifacts/bundle" "frontend API bundle"
Assert-Contains $apiText "/gitops-pr-runner" "frontend API bundle"
Assert-Contains $apiText "/gitops-pr-execution" "frontend API bundle"
Assert-Contains $apiText "/executions" "frontend API bundle"
Assert-Contains $apiText "/apply" "frontend API bundle"
Assert-Contains $apiText "/export" "frontend API bundle"
Assert-Contains $apiText "audit-logs" "frontend API bundle"
Assert-Contains $apiText "/admin/organizations/" "frontend API bundle"
Assert-Contains $apiText "/tags" "frontend API bundle"
Assert-Contains $styleText ".shell" "frontend CSS"

Step "Backend health"
Invoke-Json "GET" "$ApiBase/health" | Out-Null

Step "Admin login"
$adminLogin = Invoke-Json "POST" "$ApiBase/auth/login" @{
    loginId = $AdminLoginId
    password = $AdminPassword
}
$adminToken = $adminLogin.data.accessToken
if (-not $adminToken) {
    throw "Admin login did not return accessToken."
}

Step "User status token invalidation"
$tokenSmokeSuffix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$tokenSmokeUserLoginId = "smoke-token-user-$tokenSmokeSuffix"
$tokenSmokeAdminLoginId = "smoke-token-admin-$tokenSmokeSuffix"
$tokenSmokeUser = Invoke-Json "POST" "$ApiBase/admin/users" @{
    loginId = $tokenSmokeUserLoginId
    email = "$tokenSmokeUserLoginId@example.com"
    name = "Smoke Token User"
    password = "TokenSmoke!23"
    role = "USER"
    organizationId = $null
} $adminToken
$tokenSmokeUserId = $tokenSmokeUser.data.id
$tokenSmokeUserLogin = Invoke-Json "POST" "$ApiBase/auth/login" @{
    loginId = $tokenSmokeUserLoginId
    password = "TokenSmoke!23"
}
$tokenSmokeUserAccessToken = $tokenSmokeUserLogin.data.accessToken

$tokenSmokeAdmin = Invoke-Json "POST" "$ApiBase/admin/users" @{
    loginId = $tokenSmokeAdminLoginId
    email = "$tokenSmokeAdminLoginId@example.com"
    name = "Smoke Token Admin"
    password = "TokenSmoke!23"
    role = "ADMIN"
    organizationId = $null
} $adminToken
$tokenSmokeAdminId = $tokenSmokeAdmin.data.id
$tokenSmokeAdminLogin = Invoke-Json "POST" "$ApiBase/auth/login" @{
    loginId = $tokenSmokeAdminLoginId
    password = "TokenSmoke!23"
}
$tokenSmokeAdminAccessToken = $tokenSmokeAdminLogin.data.accessToken

Invoke-Json "PATCH" "$ApiBase/admin/users/$tokenSmokeUserId/status" @{
    status = "INACTIVE"
} $adminToken | Out-Null
Invoke-Json "PATCH" "$ApiBase/admin/users/$tokenSmokeAdminId/status" @{
    status = "INACTIVE"
} $adminToken | Out-Null

$inactiveUserMe = Invoke-Json "GET" "$ApiBase/users/me" $null $tokenSmokeUserAccessToken $false
if ([int]$inactiveUserMe.StatusCode -ne 401) {
    throw "Inactive user access token should return HTTP 401."
}
$inactiveAdminQuota = Invoke-Json "GET" "$ApiBase/admin/quota-policies" $null $tokenSmokeAdminAccessToken $false
if ([int]$inactiveAdminQuota.StatusCode -ne 401) {
    throw "Inactive admin access token should return HTTP 401."
}

Step "Storage expansion request planning"
$expansionSuffix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$expansionRequest = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests" @{
    requestedCapacityBytes = 107374182400
    serverCount = 4
    volumesPerServer = 1
    reason = "smoke expansion $expansionSuffix"
} $adminToken
$expansionRequestId = $expansionRequest.data.id
if (-not $expansionRequestId `
        -or $expansionRequest.data.status -ne "PLANNED" `
        -or $expansionRequest.data.serverCount -ne 4 `
        -or $expansionRequest.data.volumesPerServer -ne 1 `
        -or $expansionRequest.data.estimatedUsableCapacityBytes -lt 107374182400) {
    throw "Storage expansion request did not return expected plan."
}

$expansionList = Invoke-Json "GET" "$ApiBase/admin/storage-expansion/requests" $null $adminToken
if (-not ($expansionList.items | Where-Object { $_.id -eq $expansionRequestId -and $_.status -eq "PLANNED" })) {
    throw "Storage expansion request was not listed."
}

$approvedExpansion = Invoke-Json "PATCH" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/status" @{
    status = "APPROVED"
} $adminToken
if ($approvedExpansion.data.status -ne "APPROVED") {
    throw "Storage expansion status update did not persist."
}

$executionPlan = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/execution-plan" $null $adminToken
if ($executionPlan.data.requestId -ne $expansionRequestId `
        -or $executionPlan.data.ready -ne $true `
        -or $executionPlan.data.referenceOnly -ne $true `
        -or -not ($executionPlan.data.artifactSha256 -match "^[0-9a-f]{64}$") `
        -or -not ($executionPlan.data.evidenceTemplate -like "*sha256:*") `
        -or -not ($executionPlan.data.suggestedCommands -contains "kubectl -n osmu diff -f osmu-storage-expansion-$($expansionRequest.data.poolName)-bundle.yaml")) {
    throw "Storage expansion execution dry-run did not return expected plan."
}

$dryRunExecution = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/dry-run-execution" @{
    executionType = "KUBECTL_DIFF"
    result = "SUCCESS"
    output = "smoke kubectl diff clean"
    externalUrl = "https://example.invalid/osmu/storage-expansion/$expansionRequestId/dry-run"
    notes = "smoke dry-run evidence"
} $adminToken
if ($dryRunExecution.data.requestId -ne $expansionRequestId `
        -or $dryRunExecution.data.executionType -ne "KUBECTL_DIFF" `
        -or $dryRunExecution.data.result -ne "SUCCESS" `
        -or -not $dryRunExecution.data.command.Contains("kubectl -n osmu diff") `
        -or -not $dryRunExecution.data.output.Contains("smoke kubectl diff clean") `
        -or -not ($dryRunExecution.data.artifactSha256 -match "^[0-9a-f]{64}$")) {
    throw "Storage expansion dry-run execution record did not persist."
}

$dryRunRunnerExecution = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/dry-run-runner" @{
    executionType = "KUBECTL_DIFF"
} $adminToken
if ($dryRunRunnerExecution.data.requestId -ne $expansionRequestId `
        -or $dryRunRunnerExecution.data.executionType -ne "KUBECTL_DIFF" `
        -or $dryRunRunnerExecution.data.result -ne "SKIPPED" `
        -or -not $dryRunRunnerExecution.data.command.Contains("kubectl") `
        -or -not $dryRunRunnerExecution.data.output.Contains("runner disabled") `
        -or $dryRunRunnerExecution.data.timedOut -ne $false) {
    throw "Storage expansion dry-run runner did not return disabled SKIPPED record."
}

$applyRunnerExecution = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/apply-runner" @{
    applyType = "KUBECTL_APPLY"
} $adminToken
if ($applyRunnerExecution.data.execution.requestId -ne $expansionRequestId `
        -or $applyRunnerExecution.data.execution.executionType -ne "APPLY" `
        -or $applyRunnerExecution.data.execution.result -ne "SKIPPED" `
        -or -not $applyRunnerExecution.data.execution.command.Contains("kubectl") `
        -or -not $applyRunnerExecution.data.execution.output.Contains("apply runner disabled") `
        -or $applyRunnerExecution.data.execution.timedOut -ne $false `
        -or $applyRunnerExecution.data.request.status -ne "APPROVED") {
    throw "Storage expansion apply runner did not return disabled SKIPPED record."
}

$gitOpsPlan = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/gitops-plan" $null $adminToken
$expectedTenantPath = "infra/gitops/storage-expansion/$($expansionRequest.data.poolName)/tenant-patch.yaml"
$expectedValuesPath = "infra/gitops/storage-expansion/$($expansionRequest.data.poolName)/helm-values.yaml"
if ($gitOpsPlan.data.requestId -ne $expansionRequestId `
        -or $gitOpsPlan.data.ready -ne $true `
        -or $gitOpsPlan.data.referenceOnly -ne $true `
        -or -not $gitOpsPlan.data.branchName.Contains("storage-expansion/pool-") `
        -or -not $gitOpsPlan.data.commitMessage.Contains("[Feat][I]") `
        -or -not $gitOpsPlan.data.pullRequestBody.Contains("sha256") `
        -or -not ($gitOpsPlan.data.changedFiles -contains $expectedTenantPath) `
        -or -not ($gitOpsPlan.data.changedFiles -contains $expectedValuesPath) `
        -or -not (($gitOpsPlan.data.reviewChecklist -join "`n").Contains("helm diff"))) {
    throw "Storage expansion GitOps draft did not return expected plan."
}

$gitOpsPrRunnerExecution = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/gitops-pr-runner" $null $adminToken
if ($gitOpsPrRunnerExecution.data.requestId -ne $expansionRequestId `
        -or $gitOpsPrRunnerExecution.data.executionType -ne "GITOPS_PR" `
        -or $gitOpsPrRunnerExecution.data.result -ne "SKIPPED" `
        -or -not $gitOpsPrRunnerExecution.data.command.Contains("gh pr create") `
        -or -not $gitOpsPrRunnerExecution.data.output.Contains("GitOps PR runner disabled") `
        -or -not ($gitOpsPrRunnerExecution.data.artifactSha256 -match "^[0-9a-f]{64}$") `
        -or $gitOpsPrRunnerExecution.data.timedOut -ne $false) {
    throw "Storage expansion GitOps PR runner did not return disabled SKIPPED record."
}

$gitOpsPrExecution = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/gitops-pr-execution" @{
    externalUrl = "https://example.invalid/osmu/storage-expansion/$expansionRequestId/pull/42"
    mergeSha = "abcdef1234567890"
    pipelineUrl = "https://example.invalid/osmu/storage-expansion/$expansionRequestId/pipeline"
    notes = "smoke GitOps PR evidence"
} $adminToken
if ($gitOpsPrExecution.data.requestId -ne $expansionRequestId `
        -or $gitOpsPrExecution.data.executionType -ne "GITOPS_PR" `
        -or $gitOpsPrExecution.data.result -ne "SUCCESS" `
        -or -not $gitOpsPrExecution.data.externalUrl.Contains("/pull/42") `
        -or -not ($gitOpsPrExecution.data.artifactSha256 -match "^[0-9a-f]{64}$") `
        -or -not $gitOpsPrExecution.data.command.Contains("gh pr create") `
        -or -not $gitOpsPrExecution.data.output.Contains("tenant-patch.yaml")) {
    throw "Storage expansion GitOps PR execution record did not persist."
}

$gitOpsZipPath = Join-Path ([System.IO.Path]::GetTempPath()) "osmu-storage-expansion-$expansionSuffix-gitops.zip"
$gitOpsHeaders = @{ Authorization = "Bearer $adminToken" }
Invoke-WebRequest -Method GET -Uri "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/gitops-artifacts/bundle" -Headers $gitOpsHeaders -OutFile $gitOpsZipPath -UseBasicParsing
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $gitOpsZip = [System.IO.Compression.ZipFile]::OpenRead($gitOpsZipPath)
    try {
        $gitOpsEntryNames = @($gitOpsZip.Entries | ForEach-Object { $_.FullName })
        if (-not ($gitOpsEntryNames -contains $expectedTenantPath) `
                -or -not ($gitOpsEntryNames -contains $expectedValuesPath) `
                -or -not ($gitOpsEntryNames -contains "infra/gitops/storage-expansion/$($expansionRequest.data.poolName)/README.md")) {
            throw "Storage expansion GitOps bundle did not contain expected files."
        }
    } finally {
        $gitOpsZip.Dispose()
    }
} finally {
    Remove-Item -LiteralPath $gitOpsZipPath -ErrorAction SilentlyContinue
}

$executionRecord = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/executions" @{
    executionType = "HELM_DIFF"
    result = "SUCCESS"
    command = "helm diff upgrade osmu-minio ./infra/helm/osmu -f helm-values.yaml"
    output = "smoke dry-run result"
    externalUrl = "https://example.invalid/osmu/storage-expansion/$expansionRequestId"
    artifactSha256 = $gitOpsPlan.data.artifactSha256
    notes = "smoke execution history"
} $adminToken
if ($executionRecord.data.requestId -ne $expansionRequestId `
        -or $executionRecord.data.executionType -ne "HELM_DIFF" `
        -or $executionRecord.data.result -ne "SUCCESS" `
        -or $executionRecord.data.artifactSha256 -ne $gitOpsPlan.data.artifactSha256) {
    throw "Storage expansion execution history record did not persist."
}

$executionHistory = Invoke-Json "GET" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/executions" $null $adminToken
if (-not ($executionHistory.items | Where-Object { $_.id -eq $executionRecord.data.id -and $_.executionType -eq "HELM_DIFF" -and $_.result -eq "SUCCESS" })) {
    throw "Storage expansion execution history was not listed."
}
if (-not ($executionHistory.items | Where-Object { $_.id -eq $dryRunExecution.data.id -and $_.executionType -eq "KUBECTL_DIFF" -and $_.result -eq "SUCCESS" })) {
    throw "Storage expansion dry-run execution history was not listed."
}
if (-not ($executionHistory.items | Where-Object { $_.id -eq $dryRunRunnerExecution.data.id -and $_.executionType -eq "KUBECTL_DIFF" -and $_.result -eq "SKIPPED" })) {
    throw "Storage expansion dry-run runner execution history was not listed."
}
if (-not ($executionHistory.items | Where-Object { $_.id -eq $applyRunnerExecution.data.execution.id -and $_.executionType -eq "APPLY" -and $_.result -eq "SKIPPED" })) {
    throw "Storage expansion apply runner execution history was not listed."
}
if (-not ($executionHistory.items | Where-Object { $_.id -eq $gitOpsPrExecution.data.id -and $_.executionType -eq "GITOPS_PR" -and $_.result -eq "SUCCESS" })) {
    throw "Storage expansion GitOps PR execution history was not listed."
}

$expansionManifest = Invoke-Json "GET" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/manifest" $null $adminToken
if ($expansionManifest.data.requestId -ne $expansionRequestId `
        -or $expansionManifest.data.referenceOnly -ne $true `
        -or -not $expansionManifest.data.tenantPatchYaml.Contains("kind: Tenant") `
        -or -not $expansionManifest.data.tenantPatchYaml.Contains("storage: 50Gi") `
        -or -not $expansionManifest.data.helmValuesPatchYaml.Contains("enabled: true") `
        -or -not $expansionManifest.data.helmValuesPatchYaml.Contains("size: 50Gi")) {
    throw "Storage expansion manifest preview did not return expected YAML."
}

$manifestHeaders = @{ Authorization = "Bearer $adminToken" }
$tenantManifest = WebResponse-Text (Invoke-WebRequest -Method GET -Uri "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/manifest/tenant" -Headers $manifestHeaders -UseBasicParsing)
$helmManifest = WebResponse-Text (Invoke-WebRequest -Method GET -Uri "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/manifest/helm" -Headers $manifestHeaders -UseBasicParsing)
$bundleManifest = WebResponse-Text (Invoke-WebRequest -Method GET -Uri "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/manifest/bundle" -Headers $manifestHeaders -UseBasicParsing)
if (-not $tenantManifest.Contains("kind: Tenant") `
        -or -not $tenantManifest.Contains("storage: 50Gi") `
        -or -not $helmManifest.Contains("enabled: true") `
        -or -not $helmManifest.Contains("size: 50Gi") `
        -or -not $bundleManifest.Contains("OSMU storage expansion manifest bundle") `
        -or -not $bundleManifest.Contains("kind: Tenant") `
        -or -not $bundleManifest.Contains("size: 50Gi")) {
    throw "Storage expansion manifest download did not return expected YAML."
}

$applyExecution = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/executions" @{
    executionType = "APPLY"
    result = "SUCCESS"
    command = "helm upgrade osmu-minio --values pool-$($expansionRequest.data.poolName).yaml"
    externalUrl = "https://example.invalid/osmu/storage-expansion/$expansionRequestId/apply"
    artifactSha256 = $gitOpsPlan.data.artifactSha256
    notes = "smoke apply evidence"
} $adminToken
$appliedExpansion = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/executions/$($applyExecution.data.id)/apply" $null $adminToken
if ($appliedExpansion.data.status -ne "APPLIED" `
        -or $appliedExpansion.data.appliedBy -ne $AdminLoginId `
        -or -not $appliedExpansion.data.appliedEvidence.Contains("execution APPLY") `
        -or -not $appliedExpansion.data.appliedEvidence.Contains("https://example.invalid/osmu/storage-expansion/$expansionRequestId/apply")) {
    throw "Storage expansion applied evidence did not persist."
}

$rollbackRunnerExecution = Invoke-Json "POST" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/rollback-runner" @{
    rollbackType = "HELM_ROLLBACK"
    helmRevision = 1
} $adminToken
if ($rollbackRunnerExecution.data.execution.requestId -ne $expansionRequestId `
        -or $rollbackRunnerExecution.data.execution.executionType -ne "ROLLBACK" `
        -or $rollbackRunnerExecution.data.execution.result -ne "SKIPPED" `
        -or -not $rollbackRunnerExecution.data.execution.command.Contains("helm rollback") `
        -or -not $rollbackRunnerExecution.data.execution.output.Contains("rollback runner disabled") `
        -or $rollbackRunnerExecution.data.execution.timedOut -ne $false `
        -or $rollbackRunnerExecution.data.request.status -ne "APPLIED") {
    throw "Storage expansion rollback runner did not return disabled SKIPPED record."
}

$invalidExpansionStatus = Invoke-Json "PATCH" "$ApiBase/admin/storage-expansion/requests/$expansionRequestId/status" @{
    status = "RUNNING"
} $adminToken $false
if ([int]$invalidExpansionStatus.StatusCode -ne 400) {
    throw "Invalid storage expansion status should return HTTP 400."
}

Step "Access key secret redaction"
$secretSmokeSuffix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$secretSmokeBucketName = "smoke-secret-redaction-$secretSmokeSuffix"
$secretSmokeKeyId = $null
try {
    Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $secretSmokeBucketName
        quotaBytes = 1048576
        ownerType = "USER"
    } $adminToken | Out-Null

    $secretSmokeKey = Invoke-Json "POST" "$ApiBase/access-keys" @{
        name = "secret-redaction-smoke-$secretSmokeSuffix"
        allowedBuckets = @($secretSmokeBucketName)
        permissions = @("READ")
        expiresAt = $null
    } $adminToken
    $secretSmokeKeyId = $secretSmokeKey.data.id
    $secretSmokeAccessKey = $secretSmokeKey.data.accessKey
    $secretSmokeSecret = $secretSmokeKey.data.secretKey
    if (-not $secretSmokeKeyId -or -not $secretSmokeAccessKey -or -not $secretSmokeSecret) {
        throw "Access key secret redaction smoke did not receive one-time secret fields."
    }

    $secretKeyList = Invoke-Json "GET" "$ApiBase/access-keys" $null $adminToken
    $listedSecretKey = $secretKeyList.items | Where-Object { $_.id -eq $secretSmokeKeyId } | Select-Object -First 1
    if (-not $listedSecretKey) {
        throw "Access key secret redaction smoke key was not listed."
    }
    if ($listedSecretKey.PSObject.Properties.Name -contains "secretKey" `
            -or $listedSecretKey.PSObject.Properties.Name -contains "secretKeyHash" `
            -or $listedSecretKey.PSObject.Properties.Name -contains "secretKeyCiphertext") {
        throw "Access key list exposed secret fields."
    }

    $encodedAccessKey = [System.Uri]::EscapeDataString($secretSmokeAccessKey)
    $secretAudit = Invoke-Json "GET" "$ApiBase/admin/audit-logs?eventType=ACCESS_KEY_CREATE&targetId=$encodedAccessKey&limit=10" $null $adminToken
    $secretAuditText = $secretAudit | ConvertTo-Json -Depth 12 -Compress
    Assert-SecretAbsent $secretAuditText $secretSmokeSecret "access key create audit list"

    $auditCsvResponse = Invoke-WebRequest `
        -Method GET `
        -Uri "$ApiBase/admin/audit-logs/export.csv?eventType=ACCESS_KEY_CREATE&targetId=$encodedAccessKey&limit=10" `
        -Headers @{ Authorization = "Bearer $adminToken" } `
        -UseBasicParsing
    Assert-SecretAbsent $auditCsvResponse.Content $secretSmokeSecret "access key create audit CSV"
    Assert-SecretAbsentFromLogs $BackendLogPath $secretSmokeSecret
}
finally {
    if ($secretSmokeKeyId) {
        Invoke-Json "DELETE" "$ApiBase/access-keys/$secretSmokeKeyId" $null $adminToken $false | Out-Null
    }
    Invoke-Json "DELETE" "$ApiBase/buckets/$secretSmokeBucketName" $null $adminToken $false | Out-Null
}

Step "Dashboard layout preset CRUD"
$presetSmokeSuffix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$presetWidgets = @(
    @{
        id = "capacity"
        enabled = $true
        size = "wide"
        section = "overview"
        options = @{
            tone = "focus"
        }
    },
    @{
        id = "requests"
        enabled = $true
        size = "compact"
        section = "operations"
    }
)
$presetSections = @(
    @{
        id = "overview"
        collapsed = $false
    },
    @{
        id = "operations"
        collapsed = $true
    },
    @{
        id = "governance"
        collapsed = $false
    }
)
$createdPreset = Invoke-Json "POST" "$ApiBase/dashboard/layout/presets" @{
    schemaVersion = "osmu.dashboard-layout.v1"
    name = "Smoke Preset $presetSmokeSuffix"
    description = "smoke create"
    widgets = $presetWidgets
    sections = $presetSections
} $adminToken
$createdPresetId = $createdPreset.data.id
if (-not $createdPresetId -or -not $createdPreset.data.custom) {
    throw "Dashboard custom preset create did not return a custom preset id."
}

$updatedPreset = Invoke-Json "PATCH" "$ApiBase/dashboard/layout/presets/$createdPresetId" @{
    schemaVersion = "osmu.dashboard-layout.v1"
    name = "Smoke Preset Updated $presetSmokeSuffix"
    description = "smoke update"
    widgets = @(
        @{
            id = "quota"
            enabled = $true
            size = "wide"
            section = "governance"
            options = @{
                tone = "muted"
            }
        }
    )
    sections = @(
        @{
            id = "governance"
            collapsed = $true
        }
    )
} $adminToken
if ($updatedPreset.data.id -ne $createdPresetId `
        -or $updatedPreset.data.name -ne "Smoke Preset Updated $presetSmokeSuffix" `
        -or $updatedPreset.data.schemaVersion -ne "osmu.dashboard-layout.v1" `
        -or $updatedPreset.data.widgets[0].id -ne "quota" `
        -or $updatedPreset.data.widgets[0].section -ne "governance" `
        -or $updatedPreset.data.sections[2].collapsed -ne $true `
        -or $updatedPreset.data.widgets[0].options.tone -ne "muted") {
    throw "Dashboard custom preset update did not persist expected fields."
}

$exportedPreset = Invoke-Json "GET" "$ApiBase/dashboard/layout/presets/$createdPresetId/export" $null $adminToken
if ($exportedPreset.data.formatVersion -ne "osmu.dashboard-preset.v1" `
        -or $exportedPreset.data.preset.id -ne $createdPresetId `
        -or $exportedPreset.data.preset.schemaVersion -ne "osmu.dashboard-layout.v1" `
        -or $exportedPreset.data.preset.widgets[0].id -ne "quota" `
        -or $exportedPreset.data.preset.widgets[0].section -ne "governance" `
        -or $exportedPreset.data.preset.sections[2].collapsed -ne $true `
        -or $exportedPreset.data.preset.widgets[0].options.tone -ne "muted") {
    throw "Dashboard custom preset export did not include expected preset payload."
}

$importedPreset = Invoke-Json "POST" "$ApiBase/dashboard/layout/presets/import" @{
    formatVersion = $exportedPreset.data.formatVersion
    preset = @{
        name = "Smoke Preset Imported $presetSmokeSuffix"
        description = "smoke import"
        schemaVersion = $exportedPreset.data.preset.schemaVersion
        widgets = $exportedPreset.data.preset.widgets
        sections = $exportedPreset.data.preset.sections
    }
} $adminToken
$importedPresetId = $importedPreset.data.id
if (-not $importedPresetId `
        -or -not $importedPreset.data.custom `
        -or $importedPreset.data.name -ne "Smoke Preset Imported $presetSmokeSuffix" `
        -or $importedPreset.data.schemaVersion -ne "osmu.dashboard-layout.v1" `
        -or $importedPreset.data.widgets[0].id -ne "quota" `
        -or $importedPreset.data.widgets[0].section -ne "governance" `
        -or $importedPreset.data.sections[2].collapsed -ne $true `
        -or $importedPreset.data.widgets[0].options.tone -ne "muted") {
    throw "Dashboard custom preset import did not persist expected fields."
}

$bundleExportedPresets = Invoke-Json "GET" "$ApiBase/dashboard/layout/preset-bundle/export" $null $adminToken
if ($bundleExportedPresets.data.formatVersion -ne "osmu.dashboard-preset-bundle.v1" `
        -or -not ($bundleExportedPresets.data.presets | Where-Object { $_.id -eq $createdPresetId }) `
        -or -not ($bundleExportedPresets.data.presets | Where-Object { $_.id -eq $importedPresetId }) `
        -or ($bundleExportedPresets.data.presets | Where-Object { -not $_.custom })) {
    throw "Dashboard preset bundle export did not include expected custom presets."
}

$bundleImportedPresets = Invoke-Json "POST" "$ApiBase/dashboard/layout/preset-bundle/import" @{
    formatVersion = $bundleExportedPresets.data.formatVersion
    presets = @(
        @{
            name = "Smoke Preset Bundle One $presetSmokeSuffix"
            description = "smoke bundle import one"
            schemaVersion = "osmu.dashboard-layout.v1"
            widgets = $exportedPreset.data.preset.widgets
            sections = $exportedPreset.data.preset.sections
        },
        @{
            name = "Smoke Preset Bundle Two $presetSmokeSuffix"
            description = "smoke bundle import two"
            widgets = @(
                @{
                    id = "health"
                    enabled = $true
                    size = "normal"
                    section = "operations"
                }
            )
            sections = @(
                @{
                    id = "operations"
                    collapsed = $true
                }
            )
        }
    )
} $adminToken
$bundleImportedPresetIds = @($bundleImportedPresets.data.presets | ForEach-Object { $_.id })
if ($bundleImportedPresets.data.importedCount -ne 2 `
        -or $bundleImportedPresetIds.Count -ne 2 `
        -or $bundleImportedPresets.data.presets[0].schemaVersion -ne "osmu.dashboard-layout.v1" `
        -or $bundleImportedPresets.data.presets[0].widgets[0].id -ne "quota" `
        -or $bundleImportedPresets.data.presets[0].sections[2].collapsed -ne $true `
        -or $bundleImportedPresets.data.presets[1].widgets[0].id -ne "health" `
        -or $bundleImportedPresets.data.presets[1].sections[1].collapsed -ne $true) {
    throw "Dashboard preset bundle import did not persist expected presets."
}

$presetCatalog = Invoke-Json "GET" "$ApiBase/dashboard/layout/presets" $null $adminToken
$builtInPreset = $presetCatalog.data | Where-Object { -not $_.custom } | Select-Object -First 1
if (-not $builtInPreset) {
    throw "Dashboard built-in preset was not found."
}

$widgetCatalog = Invoke-Json "GET" "$ApiBase/dashboard/layout/widgets" $null $adminToken
if (-not ($widgetCatalog.data | Where-Object { $_.id -eq "access-keys" -and $_.category -eq "SECURITY" })) {
    throw "Dashboard widget catalog did not include access-keys security metadata."
}
if (-not ($widgetCatalog.data | Where-Object { $_.id -eq "identity" -and $_.adminOnly -eq $true })) {
    throw "Dashboard widget catalog did not include identity adminOnly metadata."
}
$accessKeyWidgetConfig = $widgetCatalog.data | Where-Object { $_.id -eq "access-keys" } | Select-Object -First 1
if (-not ($accessKeyWidgetConfig.configOptions | Where-Object { $_.key -eq "tone" -and $_.defaultValue -eq "default" })) {
    throw "Dashboard widget catalog did not include tone config option metadata."
}

$unknownWidgetLayout = Invoke-Json "PUT" "$ApiBase/dashboard/layout?scope=smoke-invalid-$presetSmokeSuffix" @{
    widgets = @(
        @{
            id = "unknown-widget"
            enabled = $true
            size = "normal"
        }
    )
} $adminToken $false
if ([int]$unknownWidgetLayout.StatusCode -ne 400) {
    throw "Dashboard unknown widget layout should return HTTP 400."
}

$invalidToneLayout = Invoke-Json "PUT" "$ApiBase/dashboard/layout?scope=smoke-invalid-tone-$presetSmokeSuffix" @{
    widgets = @(
        @{
            id = "capacity"
            enabled = $true
            size = "normal"
            options = @{
                tone = "neon"
            }
        }
    )
} $adminToken $false
if ([int]$invalidToneLayout.StatusCode -ne 400) {
    throw "Dashboard invalid widget tone should return HTTP 400."
}

$invalidSectionLayout = Invoke-Json "PUT" "$ApiBase/dashboard/layout?scope=smoke-invalid-section-$presetSmokeSuffix" @{
    widgets = @(
        @{
            id = "capacity"
            enabled = $true
            size = "normal"
            section = "executive"
        }
    )
} $adminToken $false
if ([int]$invalidSectionLayout.StatusCode -ne 400) {
    throw "Dashboard invalid widget section should return HTTP 400."
}

$builtInUpdate = Invoke-Json "PATCH" "$ApiBase/dashboard/layout/presets/$($builtInPreset.id)" @{
    name = "Should Not Update"
    description = "built-in update smoke"
    widgets = $presetWidgets
} $adminToken $false
if ([int]$builtInUpdate.StatusCode -ne 409) {
    throw "Dashboard built-in preset update should return HTTP 409."
}

$defaultScope = "smoke-default-$presetSmokeSuffix"
try {
    $savedDefault = Invoke-Json "PUT" "$ApiBase/dashboard/layout/defaults" @{
        targetType = "ROLE"
        targetId = "ADMIN"
        presetId = $importedPresetId
    } $adminToken
    if ($savedDefault.data.targetType -ne "ROLE" `
            -or $savedDefault.data.targetId -ne "ADMIN" `
            -or $savedDefault.data.presetId -ne $importedPresetId) {
        throw "Dashboard default preset assignment did not persist expected fields."
    }

    $defaultList = Invoke-Json "GET" "$ApiBase/dashboard/layout/defaults" $null $adminToken
    if (-not ($defaultList.data | Where-Object { $_.targetType -eq "ROLE" -and $_.targetId -eq "ADMIN" -and $_.presetId -eq $importedPresetId })) {
        throw "Dashboard default preset assignment was not listed."
    }

    $defaultLayout = Invoke-Json "GET" "$ApiBase/dashboard/layout?scope=$defaultScope" $null $adminToken
    if ($defaultLayout.data.source -ne "DEFAULT_PRESET" `
            -or $defaultLayout.data.widgets[0].id -ne "quota" `
            -or $defaultLayout.data.sections[2].collapsed -ne $true) {
        throw "Dashboard default preset assignment was not applied to a new admin layout scope."
    }
}
finally {
    Invoke-Json "DELETE" "$ApiBase/dashboard/layout/defaults/ROLE/ADMIN" $null $adminToken $false | Out-Null
}

$resetDefaultLayout = Invoke-Json "GET" "$ApiBase/dashboard/layout?scope=$defaultScope" $null $adminToken
if ($resetDefaultLayout.data.source -ne "DEFAULT") {
    throw "Dashboard default preset assignment was not removed."
}

$cleanupOrg = Invoke-Json "POST" "$ApiBase/admin/organizations" @{
    name = "Smoke Dashboard Default Org $presetSmokeSuffix"
    description = "dashboard default cleanup smoke"
    defaultQuotaBytes = 1048576
} $adminToken
$cleanupOrgId = $cleanupOrg.data.id
$cleanupPermissionBucketName = "smoke-permission-cleanup-$presetSmokeSuffix"
try {
    Invoke-Json "PUT" "$ApiBase/admin/quota-policies/ORGANIZATION/$cleanupOrgId" @{
        quotaBytes = 1048576
        reason = "dashboard default cleanup smoke"
    } $adminToken | Out-Null

    $quotaAuditTargetId = "ORGANIZATION:$cleanupOrgId"
    $quotaSaveAudit = Invoke-Json "GET" "$ApiBase/admin/audit-logs?targetType=QUOTA_POLICY&targetId=$quotaAuditTargetId&limit=10" $null $adminToken
    if (-not ($quotaSaveAudit.items | Where-Object { $_.eventType -eq "QUOTA_POLICY_SAVE" -and $_.targetId -eq $quotaAuditTargetId })) {
        throw "Quota policy save audit log was not recorded."
    }

    Invoke-Json "DELETE" "$ApiBase/admin/quota-policies/ORGANIZATION/$cleanupOrgId" $null $adminToken | Out-Null
    $quotaDeleteAudit = Invoke-Json "GET" "$ApiBase/admin/audit-logs?targetType=QUOTA_POLICY&targetId=$quotaAuditTargetId&limit=10" $null $adminToken
    if (-not ($quotaDeleteAudit.items | Where-Object { $_.eventType -eq "QUOTA_POLICY_DELETE" -and $_.targetId -eq $quotaAuditTargetId })) {
        throw "Quota policy delete audit log was not recorded."
    }

    Invoke-Json "PUT" "$ApiBase/admin/quota-policies/ORGANIZATION/$cleanupOrgId" @{
        quotaBytes = 1048576
        reason = "organization cleanup smoke"
    } $adminToken | Out-Null

    Invoke-Json "PUT" "$ApiBase/dashboard/layout/defaults" @{
        targetType = "ORGANIZATION"
        targetId = "$cleanupOrgId"
        presetId = $importedPresetId
    } $adminToken | Out-Null

    Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $cleanupPermissionBucketName
        quotaBytes = 1048576
        ownerType = "USER"
    } $adminToken | Out-Null

    Invoke-Json "POST" "$ApiBase/buckets/$cleanupPermissionBucketName/permissions" @{
        subjectType = "ORGANIZATION"
        subjectId = $cleanupOrgId
        permissions = @("READ", "WRITE")
    } $adminToken | Out-Null

    Invoke-Json "DELETE" "$ApiBase/admin/organizations/$cleanupOrgId" $null $adminToken | Out-Null

    $postDeleteDefaults = Invoke-Json "GET" "$ApiBase/dashboard/layout/defaults" $null $adminToken
    if ($postDeleteDefaults.data | Where-Object { $_.targetType -eq "ORGANIZATION" -and $_.targetId -eq "$cleanupOrgId" }) {
        throw "Dashboard organization default preset assignment was not removed with organization delete."
    }

    $postDeleteQuotaPolicies = Invoke-Json "GET" "$ApiBase/admin/quota-policies" $null $adminToken
    if ($postDeleteQuotaPolicies.items | Where-Object { $_.targetType -eq "ORGANIZATION" -and $_.targetId -eq $cleanupOrgId }) {
        throw "Organization quota policy was not removed with organization delete."
    }

    $quotaHistory = Invoke-Json "GET" "$ApiBase/admin/quota-policies/history?limit=20" $null $adminToken
    if (-not ($quotaHistory.items | Where-Object { $_.targetType -eq "ORGANIZATION" -and $_.targetId -eq $cleanupOrgId -and $_.action -eq "DELETE" })) {
        throw "Organization quota policy cleanup did not record DELETE history."
    }

    $postDeletePermissions = Invoke-Json "GET" "$ApiBase/buckets/$cleanupPermissionBucketName/permissions" $null $adminToken
    if ($postDeletePermissions.items | Where-Object { $_.subjectType -eq "ORGANIZATION" -and $_.subjectId -eq $cleanupOrgId }) {
        throw "Organization bucket permissions were not removed with organization delete."
    }
}
finally {
    Invoke-Json "DELETE" "$ApiBase/admin/organizations/$cleanupOrgId" $null $adminToken $false | Out-Null
    Invoke-Json "DELETE" "$ApiBase/buckets/$cleanupPermissionBucketName" $null $adminToken $false | Out-Null
}

Invoke-Json "DELETE" "$ApiBase/dashboard/layout/presets/$createdPresetId" $null $adminToken | Out-Null
Invoke-Json "DELETE" "$ApiBase/dashboard/layout/presets/$importedPresetId" $null $adminToken | Out-Null
foreach ($bundleImportedPresetId in $bundleImportedPresetIds) {
    Invoke-Json "DELETE" "$ApiBase/dashboard/layout/presets/$bundleImportedPresetId" $null $adminToken | Out-Null
}

$demoUser = Find-DemoUser $ApiBase $adminToken $DemoLoginId
if (-not $demoUser -and $SeedIfMissing) {
    Step "Seed missing demo data"
    $seedArgs = @(
        "-ApiBase", $ApiBase,
        "-AdminLoginId", $AdminLoginId,
        "-AdminPassword", $AdminPassword,
        "-DemoPassword", $DemoPassword,
        "-DemoOutputPath", $DemoCredentialPath
    )
    $seedExitCode = Invoke-OsmuPowerShellScript (Join-Path $PSScriptRoot "seed-lightweight-demo.ps1") $seedArgs
    if ($seedExitCode -ne 0) {
        throw "Seed missing demo data failed."
    }
    $demoUser = Find-DemoUser $ApiBase $adminToken $DemoLoginId
}

if (-not $demoUser) {
    throw "Demo user not found. Run scripts\seed-lightweight-demo.ps1 first or pass -SeedIfMissing."
}

$suffix = $demoUser.loginId -replace "^demo-user-", ""
$mediaBucketName = "osmu-demo-media-$suffix"
$aiBucketName = "osmu-demo-ai-$suffix"

Step "Demo user login"
$demoLogin = Invoke-Json "POST" "$ApiBase/auth/login" @{
    loginId = $demoUser.loginId
    password = $DemoPassword
}
$demoToken = $demoLogin.data.accessToken
if (-not $demoToken) {
    throw "Demo user login did not return accessToken."
}

Step "Demo buckets and objects"
$buckets = Invoke-Json "GET" "$ApiBase/buckets" $null $demoToken
$bucketNames = @($buckets.items | ForEach-Object { $_.name })
if ($bucketNames -notcontains $mediaBucketName -or $bucketNames -notcontains $aiBucketName) {
    throw "Demo user did not see expected demo buckets."
}

$mediaObjects = Invoke-Json "GET" "$ApiBase/buckets/$mediaBucketName/objects" $null $demoToken
$mediaObjectKeys = @($mediaObjects.items | ForEach-Object { $_.key })
if ($mediaObjectKeys -notcontains "videos/raw/sample-video-manifest.txt" `
        -or $mediaObjectKeys -notcontains "videos/encoded/sample-rendition.txt") {
    throw "Media bucket did not contain seeded objects."
}

$aiObjects = Invoke-Json "GET" "$ApiBase/buckets/$aiBucketName/objects" $null $demoToken
$aiObjectKeys = @($aiObjects.items | ForEach-Object { $_.key })
if ($aiObjectKeys -notcontains "datasets/images/sample-dataset.json") {
    throw "AI bucket did not contain seeded dataset object."
}

Step "Readonly permission boundary"
Upload-ExpectForbidden $ApiBase $aiBucketName $demoToken

Step "Tags and lifecycle"
$mediaTags = Invoke-Json "GET" "$ApiBase/buckets/$mediaBucketName/tags" $null $adminToken
if ($mediaTags.data.tags.workload -ne "streaming" -or $mediaTags.data.tags.project -ne "osmu") {
    throw "Media bucket tags did not match seed data."
}

$mediaLifecycle = Invoke-Json "GET" "$ApiBase/buckets/$mediaBucketName/lifecycle" $null $adminToken
if ($mediaLifecycle.data.ruleCount -lt 1 -or -not $mediaLifecycle.data.xml.Contains("media-raw-trash-retention")) {
    throw "Media bucket lifecycle rule did not match seed data."
}

$adminLifecycleRules = Invoke-Json "GET" "$ApiBase/admin/object-lifecycle/rules" $null $adminToken
if (-not ($adminLifecycleRules.data | Where-Object { $_.name -eq "AI dataset version retention $suffix" })) {
    throw "Admin lifecycle rule did not match seed data."
}

Step "Access key inventory"
$accessKeys = Invoke-Json "GET" "$ApiBase/access-keys" $null $demoToken
if (-not ($accessKeys.items | Where-Object { $_.name -eq "demo-sdk-key-$suffix" -and $_.status -eq "ACTIVE" })) {
    throw "Demo user access key did not match seed data."
}

if (-not $SkipS3AccessKeySmoke) {
    Step "Seeded S3 access key"
    $credentials = Read-DemoCredentials $DemoCredentialPath
    if (-not $credentials) {
        throw "Demo credential file not found: $DemoCredentialPath. Run scripts\seed-lightweight-demo.ps1 again or pass -SkipS3AccessKeySmoke."
    }
    if ($credentials.demoUserLoginId -ne $demoUser.loginId) {
        throw "Demo credential file is for $($credentials.demoUserLoginId), but current demo user is $($demoUser.loginId). Run scripts\seed-lightweight-demo.ps1 again."
    }
    Invoke-DemoS3Smoke $S3Endpoint $credentials
}

Step "Lightweight demo smoke passed"
Write-Host "Demo user: $($demoUser.loginId)"
Write-Host "Buckets: $mediaBucketName, $aiBucketName"
