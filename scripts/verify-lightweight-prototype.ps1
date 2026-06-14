param(
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "password",
    [string] $BucketName = ""
)

$ErrorActionPreference = "Stop"

if (-not $BucketName) {
    $BucketName = "lightweight-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
}

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
        -Body ($body | ConvertTo-Json -Depth 10)
}

function Invoke-JsonStatus($method, $url, $body = $null, $token = $null, $extraHeaders = @{}) {
    $headers = @{}
    if ($token) {
        $headers.Authorization = "Bearer $token"
    }
    foreach ($name in $extraHeaders.Keys) {
        $headers[$name] = $extraHeaders[$name]
    }

    try {
        if ($null -eq $body) {
            $response = Invoke-WebRequest -Method $method -Uri $url -Headers $headers -UseBasicParsing
        } else {
            $response = Invoke-WebRequest `
                -Method $method `
                -Uri $url `
                -Headers $headers `
                -ContentType "application/json" `
                -Body ($body | ConvertTo-Json -Depth 10) `
                -UseBasicParsing
        }
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Body = [string]$response.Content
            Json = if ($response.Content) { $response.Content | ConvertFrom-Json } else { $null }
        }
    }
    catch {
        $response = $_.Exception.Response
        if (-not $response) {
            throw
        }
        $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
        try {
            $content = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Body = $content
            Json = if ($content) { $content | ConvertFrom-Json } else { $null }
        }
    }
}

function Send-SmokeObjectUpload(
    $apiBase,
    $bucketName,
    $token,
    $key = "hello.txt",
    $body = "hello osmu prototype",
    $tags = "project=osmu,stage=demo",
    $fileName = "hello.txt"
) {
    Add-Type -AssemblyName System.Net.Http

    $client = [System.Net.Http.HttpClient]::new()
    try {
        $client.DefaultRequestHeaders.Authorization =
            [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $token)

        $content = [System.Net.Http.MultipartFormDataContent]::new()
        $content.Add([System.Net.Http.StringContent]::new($key), "key")
        if ($tags) {
            $content.Add([System.Net.Http.StringContent]::new($tags), "tags")
        }

        $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        $fileContent = [System.Net.Http.ByteArrayContent]::new($bytes)
        $fileContent.Headers.ContentType =
            [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/plain")
        $content.Add($fileContent, "file", $fileName)

        $response = $client.PostAsync("$apiBase/buckets/$bucketName/objects", $content).GetAwaiter().GetResult()
        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Body = $responseBody
        }
    }
    finally {
        $client.Dispose()
    }
}

function Upload-SmokeObject(
    $apiBase,
    $bucketName,
    $token,
    $key = "hello.txt",
    $body = "hello osmu prototype",
    $tags = "project=osmu,stage=demo",
    $fileName = "hello.txt"
) {
    $response = Send-SmokeObjectUpload $apiBase $bucketName $token $key $body $tags $fileName
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
        throw "Upload failed: HTTP $($response.StatusCode) $($response.Body)"
    }
}

function Download-ObjectText($apiBase, $bucketName, $key, $token) {
    $download = Invoke-WebRequest `
        -Method GET `
        -Uri "$apiBase/buckets/$bucketName/objects/$key" `
        -Headers @{ Authorization = "Bearer $token" } `
        -UseBasicParsing
    return [string]$download.Content
}

function Download-PublicObjectText($url, $sharePassword = "", $forwardedFor = "") {
    $headers = @{}
    if ($sharePassword) {
        $headers["X-OSMU-Share-Password"] = $sharePassword
    }
    if ($forwardedFor) {
        $headers["X-Forwarded-For"] = $forwardedFor
    }
    $download = Invoke-WebRequest `
        -Method GET `
        -Uri $url `
        -Headers $headers `
        -UseBasicParsing
    return [string]$download.Content
}

function Download-ObjectVersionText($apiBase, $bucketName, $key, $versionId, $token) {
    $download = Invoke-WebRequest `
        -Method GET `
        -Uri "$apiBase/buckets/$bucketName/objects/versions/$versionId/download/$key" `
        -Headers @{ Authorization = "Bearer $token" } `
        -UseBasicParsing
    return [string]$download.Content
}

function Assert-AuditLog($apiBase, $token, $eventType, $actorId, $targetType, $targetId, $result = "SUCCESS") {
    $query = [ordered]@{
        eventType = $eventType
        actorId = $actorId
        targetType = $targetType
        targetId = $targetId
        result = $result
        limit = "10"
    }
    $queryString = ($query.GetEnumerator() | ForEach-Object {
        "$([System.Uri]::EscapeDataString($_.Key))=$([System.Uri]::EscapeDataString([string]$_.Value))"
    }) -join "&"
    $logs = Invoke-Json "GET" "$apiBase/admin/audit-logs?$queryString" $null $token
    $match = $logs.items | Where-Object {
        $_.eventType -eq $eventType `
            -and $_.actorId -eq $actorId `
            -and $_.targetType -eq $targetType `
            -and $_.targetId -eq $targetId `
            -and $_.result -eq $result
    } | Select-Object -First 1
    if (-not $match) {
        throw "Audit log not found: $eventType actor=$actorId target=$targetType/$targetId result=$result"
    }
    return $match
}

function Assert-AuditCsv($apiBase, $token, $eventType, $actorId, $targetType, $targetId) {
    $query = [ordered]@{
        eventType = $eventType
        actorId = $actorId
        targetType = $targetType
        targetId = $targetId
        result = "SUCCESS"
        limit = "10"
    }
    $queryString = ($query.GetEnumerator() | ForEach-Object {
        "$([System.Uri]::EscapeDataString($_.Key))=$([System.Uri]::EscapeDataString([string]$_.Value))"
    }) -join "&"
    $response = Invoke-WebRequest `
        -Method GET `
        -Uri "$apiBase/admin/audit-logs/export.csv?$queryString" `
        -Headers @{ Authorization = "Bearer $token" } `
        -UseBasicParsing
    $contentType = [string]$response.Headers["Content-Type"]
    $contentDisposition = [string]$response.Headers["Content-Disposition"]
    if ($response.StatusCode -ne 200 `
            -or -not $contentType.StartsWith("text/csv") `
            -or -not $contentDisposition.Contains("osmu-audit-logs.csv") `
            -or -not $response.Content.Contains("id,eventType,actorId,targetType,targetId,result,message,ipAddress,userAgent,requestId,createdAt") `
            -or -not $response.Content.Contains($eventType) `
            -or -not $response.Content.Contains($targetId)) {
        throw "Audit CSV export did not contain expected audit row."
    }
}

Step "Backend health"
Invoke-Json "GET" "$ApiBase/health" | Out-Null

Step "System health"
$storageHealth = Invoke-Json "GET" "$ApiBase/storage/health"
$databaseHealth = Invoke-Json "GET" "$ApiBase/database/health"
if ($storageHealth.data.status -ne "UP" -or $databaseHealth.data.status -ne "UP") {
    throw "System health check failed: storage=$($storageHealth.data.status), database=$($databaseHealth.data.status)"
}

Step "Auth login"
$login = Invoke-Json "POST" "$ApiBase/auth/login" @{
    loginId = $AdminLoginId
    password = $AdminPassword
}
$token = $login.data.accessToken
if (-not $token) {
    throw "Login did not return accessToken."
}

Step "Auth logout refresh revoke"
$logoutLogin = Invoke-Json "POST" "$ApiBase/auth/login" @{
    loginId = $AdminLoginId
    password = $AdminPassword
}
$logoutToken = $logoutLogin.data.accessToken
$logoutRefreshToken = $logoutLogin.data.refreshToken
if (-not $logoutToken) {
    throw "Logout smoke login did not return accessToken."
}
if (-not $logoutRefreshToken) {
    throw "Logout smoke login did not return refreshToken."
}

$logoutResult = Invoke-Json "POST" "$ApiBase/auth/logout" @{
    refreshToken = $logoutRefreshToken
} $logoutToken
if (-not $logoutResult.data.success) {
    throw "Logout smoke did not return success=true."
}
Assert-AuditLog $ApiBase $token "LOGOUT" $AdminLoginId "USER" $AdminLoginId | Out-Null

$refreshAfterLogout = Invoke-JsonStatus "POST" "$ApiBase/auth/refresh" @{
    refreshToken = $logoutRefreshToken
}
if ($refreshAfterLogout.StatusCode -ne 401 -or -not $refreshAfterLogout.Body.Contains("AUTHENTICATION_REQUIRED")) {
    throw "Logout refresh token was not revoked: HTTP $($refreshAfterLogout.StatusCode) $($refreshAfterLogout.Body)"
}

Step "Admin system status"
$systemStatus = Invoke-Json "GET" "$ApiBase/admin/system/status" $null $token
if ($systemStatus.data.backend -ne "UP" `
        -or $systemStatus.data.database -ne "UP" `
        -or $systemStatus.data.storage -ne "UP" `
        -or $systemStatus.data.accessKeyProvisioner -ne "UP") {
    throw "Admin system status is not UP: $($systemStatus.data | ConvertTo-Json -Compress)"
}
$initialUsage = Invoke-Json "GET" "$ApiBase/admin/usage" $null $token

$createdBucket = $false
$quotaBucketName = "quota-$([guid]::NewGuid().ToString("N").Substring(0, 12))"
$createdQuotaBucket = $false
$userQuotaBucketName = "userquota-$([guid]::NewGuid().ToString("N").Substring(0, 12))"
$createdUserQuotaBucket = $false
$createdUserQuotaPolicyTargetId = 0
$bucketQuotaPolicyBucketName = "bucketpolicy-$([guid]::NewGuid().ToString("N").Substring(0, 12))"
$createdBucketQuotaPolicyBucket = $false
$createdBucketQuotaPolicyTargetId = 0
$orgQuotaPolicyBucketName = "orgpolicy-$([guid]::NewGuid().ToString("N").Substring(0, 12))"
$createdOrgQuotaPolicyBucket = $false
$createdOrgQuotaPolicyOrganizationId = 0
$orgQuotaBucketName = "orgquota-$([guid]::NewGuid().ToString("N").Substring(0, 12))"
$createdOrgQuotaBucket = $false
$createdOrgQuotaOrganizationId = 0
$orgDeleteBucketName = "orgdelete-$([guid]::NewGuid().ToString("N").Substring(0, 12))"
$createdOrgDeleteBucket = $false
$createdOrgDeleteOrganizationId = 0
$createdLifecycleRuleId = ""
$createdReadAccessKeyId = 0
$createdPermissionId = 0
$createdShareLinkId = 0
$objectSharePolicyChanged = $false
try {
    Step "Bucket create"
    Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $BucketName
        quotaBytes = 10485760
    } $token | Out-Null
    $createdBucket = $true
    Assert-AuditLog $ApiBase $token "BUCKET_CREATE" $AdminLoginId "BUCKET" $BucketName | Out-Null

    Step "Bucket tags"
    Invoke-Json "PUT" "$ApiBase/buckets/$BucketName/tags" @{
        tags = @{
            project = "osmu"
            stage = "lightweight"
        }
    } $token | Out-Null
    $bucketTags = Invoke-Json "GET" "$ApiBase/buckets/$BucketName/tags" $null $token
    if ($bucketTags.data.tagCount -ne 2 -or $bucketTags.data.tags.project -ne "osmu" -or $bucketTags.data.tags.stage -ne "lightweight") {
        throw "Bucket tags did not round-trip."
    }

    Step "Object upload"
    Upload-SmokeObject $ApiBase $BucketName $token
    Assert-AuditLog $ApiBase $token "OBJECT_UPLOAD" $AdminLoginId "OBJECT" "$BucketName/hello.txt" | Out-Null
    Assert-AuditCsv $ApiBase $token "OBJECT_UPLOAD" $AdminLoginId "OBJECT" "$BucketName/hello.txt"

    Step "Object list"
    $objects = Invoke-Json "GET" "$ApiBase/buckets/$BucketName/objects" $null $token
    if (-not ($objects.items | Where-Object { $_.key -eq "hello.txt" })) {
        throw "Uploaded object not found in object list."
    }

    Step "Object share policy"
    $defaultSharePolicy = Invoke-Json "GET" "$ApiBase/admin/object-share-policy" $null $token
    if ($defaultSharePolicy.data.maxExpiresSeconds -lt 120) {
        throw "Default object share policy max expiry is too low for smoke."
    }
    $sharePolicy = Invoke-Json "PUT" "$ApiBase/admin/object-share-policy" @{
        requirePassword = $true
        requireIpAllowlist = $true
        maxExpiresSeconds = 120
        maxDownloadsLimit = 2
        reason = "lightweight smoke share policy"
    } $token
    $objectSharePolicyChanged = $true
    if ($sharePolicy.data.requirePassword -ne $true `
            -or $sharePolicy.data.requireIpAllowlist -ne $true `
            -or $sharePolicy.data.maxExpiresSeconds -ne 120 `
            -or $sharePolicy.data.maxDownloadsLimit -ne 2) {
        throw "Object share policy did not round-trip."
    }
    Assert-AuditLog $ApiBase $token "OBJECT_SHARE_POLICY_SAVE" $AdminLoginId "OBJECT_SHARE_POLICY" "global" | Out-Null
    $policyMissingRequired = Invoke-JsonStatus "POST" "$ApiBase/buckets/$BucketName/objects/share-links" @{
        key = "hello.txt"
        expiresInSeconds = 120
        maxDownloads = 1
    } $token
    if ($policyMissingRequired.StatusCode -ne 400 -or -not $policyMissingRequired.Body.Contains("VALIDATION_ERROR")) {
        throw "Object share policy did not require password/IP allowlist: HTTP $($policyMissingRequired.StatusCode) $($policyMissingRequired.Body)"
    }
    $policyMaxDenied = Invoke-JsonStatus "POST" "$ApiBase/buckets/$BucketName/objects/share-links" @{
        key = "hello.txt"
        expiresInSeconds = 120
        maxDownloads = 3
        password = "SharePass!23"
        allowedIpCidrs = "127.0.0.1/32,::1/128"
    } $token
    if ($policyMaxDenied.StatusCode -ne 400 -or -not $policyMaxDenied.Body.Contains("VALIDATION_ERROR")) {
        throw "Object share policy did not enforce max download limit: HTTP $($policyMaxDenied.StatusCode) $($policyMaxDenied.Body)"
    }

    Step "Object share link"
    $shareLink = Invoke-Json "POST" "$ApiBase/buckets/$BucketName/objects/share-links" @{
        key = "hello.txt"
        expiresInSeconds = 120
        note = "lightweight smoke share"
        maxDownloads = 2
        password = "SharePass!23"
        allowedIpCidrs = "127.0.0.1/32,::1/128"
    } $token
    $createdShareLinkId = $shareLink.data.id
    if (-not $shareLink.data.url `
            -or -not $shareLink.data.token `
            -or $shareLink.data.status -ne "ACTIVE" `
            -or $shareLink.data.note -ne "lightweight smoke share" `
            -or $shareLink.data.maxDownloads -ne 2 `
            -or $shareLink.data.passwordProtected -ne $true `
            -or $shareLink.data.ipRestricted -ne $true `
            -or $shareLink.data.downloadCount -ne 0) {
        throw "Object share link did not return active token/url."
    }
    $missingPasswordShareDownload = Invoke-JsonStatus "GET" $shareLink.data.url
    if ($missingPasswordShareDownload.StatusCode -ne 404 -or -not $missingPasswordShareDownload.Body.Contains("NOT_FOUND")) {
        throw "Password protected object share link was downloadable without password: HTTP $($missingPasswordShareDownload.StatusCode)"
    }
    $wrongIpShareDownload = Invoke-JsonStatus "GET" $shareLink.data.url $null $null @{
        "X-OSMU-Share-Password" = "SharePass!23"
        "X-Forwarded-For" = "198.51.100.10"
    }
    if ($wrongIpShareDownload.StatusCode -ne 404 -or -not $wrongIpShareDownload.Body.Contains("NOT_FOUND")) {
        throw "IP restricted object share link was downloadable from blocked IP: HTTP $($wrongIpShareDownload.StatusCode)"
    }
    if ((Download-PublicObjectText $shareLink.data.url "SharePass!23") -ne "hello osmu prototype") {
        throw "Object share link download body mismatch."
    }
    Assert-AuditLog $ApiBase $token "OBJECT_SHARE_LINK_CREATE" $AdminLoginId "OBJECT" "$BucketName/hello.txt" | Out-Null
    Assert-AuditLog $ApiBase $token "OBJECT_SHARE_LINK_DOWNLOAD" "anonymous" "OBJECT" "$BucketName/hello.txt" | Out-Null
    $shareLinks = Invoke-Json "GET" "$ApiBase/buckets/$BucketName/objects/share-links?key=hello.txt&limit=5" $null $token
    if (-not ($shareLinks.items | Where-Object { $_.id -eq $createdShareLinkId -and $_.status -eq "ACTIVE" -and $_.note -eq "lightweight smoke share" -and $_.maxDownloads -eq 2 -and $_.passwordProtected -eq $true -and $_.ipRestricted -eq $true -and $_.downloadCount -eq 1 -and $_.lastAccessedAt })) {
        throw "Object share link was not visible in share link list."
    }
    $shareAnalytics = Invoke-Json "GET" "$ApiBase/admin/object-share-analytics?limit=10&bucketName=$BucketName&status=ACTIVE" $null $token
    if ($shareAnalytics.data.totalLinks -lt 1 `
            -or $shareAnalytics.data.activeLinks -lt 1 `
            -or $shareAnalytics.data.passwordProtectedLinks -lt 1 `
            -or $shareAnalytics.data.ipRestrictedLinks -lt 1 `
            -or $shareAnalytics.data.totalDownloads -lt 1 `
            -or -not ($shareAnalytics.data.recentLinks | Where-Object { $_.id -eq $createdShareLinkId -and -not $_.token -and -not $_.url })) {
        throw "Object share analytics did not include protected share link evidence."
    }
    $shareCleanup = Invoke-Json "POST" "$ApiBase/buckets/$BucketName/objects/share-links/cleanup" $null $token
    if ($shareCleanup.data.bucketName -ne $BucketName -or $shareCleanup.data.expiredCount -ne 0) {
        throw "Object share link cleanup response mismatch."
    }
    Assert-AuditLog $ApiBase $token "OBJECT_SHARE_LINK_CLEANUP" $AdminLoginId "BUCKET" "$BucketName" | Out-Null
    Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/objects/share-links/$createdShareLinkId" $null $token | Out-Null
    Assert-AuditLog $ApiBase $token "OBJECT_SHARE_LINK_REVOKE" $AdminLoginId "OBJECT" "$BucketName/hello.txt" | Out-Null
    $revokedShareDownload = Invoke-JsonStatus "GET" $shareLink.data.url
    if ($revokedShareDownload.StatusCode -ne 404 -or -not $revokedShareDownload.Body.Contains("NOT_FOUND")) {
        throw "Revoked object share link was still downloadable: HTTP $($revokedShareDownload.StatusCode)"
    }
    $createdShareLinkId = 0

    Invoke-Json "PUT" "$ApiBase/admin/object-share-policy" @{
        requirePassword = $false
        requireIpAllowlist = $false
        maxExpiresSeconds = 604800
        maxDownloadsLimit = $null
        reason = "lightweight smoke reset"
    } $token | Out-Null
    $objectSharePolicyChanged = $false

    Step "Admin usage"
    $usageAfterUpload = Invoke-Json "GET" "$ApiBase/admin/usage" $null $token
    if ($usageAfterUpload.data.bucketCount -lt ($initialUsage.data.bucketCount + 1) `
            -or $usageAfterUpload.data.objectCount -lt ($initialUsage.data.objectCount + 1) `
            -or $usageAfterUpload.data.usedBytes -lt ($initialUsage.data.usedBytes + 20) `
            -or $usageAfterUpload.data.totalQuotaBytes -lt ($initialUsage.data.totalQuotaBytes + 10485760)) {
        throw "Admin usage did not reflect bucket/object upload."
    }

    Step "Quota enforcement"
    Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $quotaBucketName
        quotaBytes = 10
    } $token | Out-Null
    $createdQuotaBucket = $true
    Upload-SmokeObject $ApiBase $quotaBucketName $token "quota-ok.txt" "1234567890" "" "quota-ok.txt"
    $quotaDenied = Send-SmokeObjectUpload $ApiBase $quotaBucketName $token "quota-blocked.txt" "overflow" "" "quota-blocked.txt"
    if ($quotaDenied.StatusCode -ne 413 -or -not $quotaDenied.Body.Contains("QUOTA_EXCEEDED")) {
        throw "Quota exceeded upload was not denied: HTTP $($quotaDenied.StatusCode) $($quotaDenied.Body)"
    }
    Invoke-Json "DELETE" "$ApiBase/buckets/$quotaBucketName/objects/quota-ok.txt" $null $token | Out-Null
    Invoke-Json "POST" "$ApiBase/buckets/$quotaBucketName/objects/purge/quota-ok.txt" $null $token | Out-Null
    Invoke-Json "DELETE" "$ApiBase/buckets/$quotaBucketName" $null $token | Out-Null
    $createdQuotaBucket = $false

    Step "User quota policy"
    $userQuotaLoginId = "quota-user-$([guid]::NewGuid().ToString("N").Substring(0, 12))"
    $userQuotaPassword = "QuotaPassword!23"
    $userQuotaTarget = Invoke-Json "POST" "$ApiBase/admin/users" @{
        loginId = $userQuotaLoginId
        email = "$userQuotaLoginId@example.com"
        name = "Quota Smoke User"
        password = $userQuotaPassword
        role = "USER"
        organizationId = $null
    } $token
    if (-not $userQuotaTarget.data.id) {
        throw "User quota smoke did not return user id."
    }
    $createdUserQuotaPolicyTargetId = $userQuotaTarget.data.id
    $quotaPolicy = Invoke-Json "PUT" "$ApiBase/admin/quota-policies/USER/$createdUserQuotaPolicyTargetId" @{
        quotaBytes = 8
        reason = "lightweight smoke user quota"
    } $token
    if ($quotaPolicy.data.targetType -ne "USER" -or $quotaPolicy.data.targetId -ne $createdUserQuotaPolicyTargetId -or $quotaPolicy.data.quotaBytes -ne 8) {
        throw "User quota policy did not round-trip."
    }
    Assert-AuditLog $ApiBase $token "QUOTA_POLICY_SAVE" $AdminLoginId "QUOTA_POLICY" "USER:$createdUserQuotaPolicyTargetId" | Out-Null
    $quotaPolicies = Invoke-Json "GET" "$ApiBase/admin/quota-policies" $null $token
    if (-not ($quotaPolicies.items | Where-Object { $_.targetType -eq "USER" -and $_.targetId -eq $createdUserQuotaPolicyTargetId })) {
        throw "User quota policy was not visible in policy list."
    }
    $quotaPolicyHistory = Invoke-Json "GET" "$ApiBase/admin/quota-policies/history?limit=20" $null $token
    if (-not ($quotaPolicyHistory.items | Where-Object {
        $_.targetType -eq "USER" `
            -and $_.targetId -eq $createdUserQuotaPolicyTargetId `
            -and $_.action -eq "CREATE" `
            -and $_.newQuotaBytes -eq 8 `
            -and $_.actorId -eq $AdminLoginId `
            -and $_.reason -eq "lightweight smoke user quota"
    })) {
        throw "User quota policy create history was not visible."
    }
    $userQuotaLogin = Invoke-Json "POST" "$ApiBase/auth/login" @{
        loginId = $userQuotaLoginId
        password = $userQuotaPassword
    }
    $userQuotaToken = $userQuotaLogin.data.accessToken
    Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $userQuotaBucketName
        quotaBytes = 1024
    } $userQuotaToken | Out-Null
    $createdUserQuotaBucket = $true
    $userQuotaDenied = Send-SmokeObjectUpload $ApiBase $userQuotaBucketName $userQuotaToken "user-quota-blocked.txt" "too-large" "" "user-quota-blocked.txt"
    if ($userQuotaDenied.StatusCode -ne 413 -or -not $userQuotaDenied.Body.Contains("QUOTA_EXCEEDED")) {
        throw "User quota exceeded upload was not denied: HTTP $($userQuotaDenied.StatusCode) $($userQuotaDenied.Body)"
    }
    Invoke-Json "DELETE" "$ApiBase/buckets/$userQuotaBucketName" $null $token | Out-Null
    $createdUserQuotaBucket = $false
    Invoke-Json "DELETE" "$ApiBase/admin/quota-policies/USER/$($createdUserQuotaPolicyTargetId)?reason=lightweight-smoke-cleanup" $null $token | Out-Null
    Assert-AuditLog $ApiBase $token "QUOTA_POLICY_DELETE" $AdminLoginId "QUOTA_POLICY" "USER:$createdUserQuotaPolicyTargetId" | Out-Null
    $quotaPolicyHistory = Invoke-Json "GET" "$ApiBase/admin/quota-policies/history?limit=20" $null $token
    if (-not ($quotaPolicyHistory.items | Where-Object {
        $_.targetType -eq "USER" `
            -and $_.targetId -eq $createdUserQuotaPolicyTargetId `
            -and $_.action -eq "DELETE" `
            -and $_.previousQuotaBytes -eq 8 `
            -and $_.actorId -eq $AdminLoginId `
            -and $_.reason -eq "lightweight-smoke-cleanup"
    })) {
        throw "User quota policy delete history was not visible."
    }
    $createdUserQuotaPolicyTargetId = 0

    Step "Bucket quota policy"
    $bucketQuotaPolicyBucket = Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $bucketQuotaPolicyBucketName
        quotaBytes = 1024
    } $token
    if (-not $bucketQuotaPolicyBucket.data.id) {
        throw "Bucket quota policy smoke did not return bucket id."
    }
    $createdBucketQuotaPolicyTargetId = $bucketQuotaPolicyBucket.data.id
    $createdBucketQuotaPolicyBucket = $true
    $bucketQuotaPolicy = Invoke-Json "PUT" "$ApiBase/admin/quota-policies/BUCKET/$createdBucketQuotaPolicyTargetId" @{
        quotaBytes = 8
        reason = "lightweight smoke bucket quota"
    } $token
    if ($bucketQuotaPolicy.data.targetType -ne "BUCKET" -or $bucketQuotaPolicy.data.targetId -ne $createdBucketQuotaPolicyTargetId -or $bucketQuotaPolicy.data.quotaBytes -ne 8) {
        throw "Bucket quota policy did not round-trip."
    }
    Assert-AuditLog $ApiBase $token "QUOTA_POLICY_SAVE" $AdminLoginId "QUOTA_POLICY" "BUCKET:$createdBucketQuotaPolicyTargetId" | Out-Null
    $quotaPolicies = Invoke-Json "GET" "$ApiBase/admin/quota-policies" $null $token
    if (-not ($quotaPolicies.items | Where-Object { $_.targetType -eq "BUCKET" -and $_.targetId -eq $createdBucketQuotaPolicyTargetId })) {
        throw "Bucket quota policy was not visible in policy list."
    }
    $bucketQuotaPolicyDenied = Send-SmokeObjectUpload $ApiBase $bucketQuotaPolicyBucketName $token "bucket-policy-blocked.txt" "too-large" "" "bucket-policy-blocked.txt"
    if ($bucketQuotaPolicyDenied.StatusCode -ne 413 -or -not $bucketQuotaPolicyDenied.Body.Contains("QUOTA_EXCEEDED")) {
        throw "Bucket quota policy upload was not denied: HTTP $($bucketQuotaPolicyDenied.StatusCode) $($bucketQuotaPolicyDenied.Body)"
    }
    Invoke-Json "DELETE" "$ApiBase/buckets/$bucketQuotaPolicyBucketName" $null $token | Out-Null
    $createdBucketQuotaPolicyBucket = $false
    Invoke-Json "DELETE" "$ApiBase/admin/quota-policies/BUCKET/$createdBucketQuotaPolicyTargetId" $null $token | Out-Null
    Assert-AuditLog $ApiBase $token "QUOTA_POLICY_DELETE" $AdminLoginId "QUOTA_POLICY" "BUCKET:$createdBucketQuotaPolicyTargetId" | Out-Null
    $createdBucketQuotaPolicyTargetId = 0

    Step "Organization quota policy"
    $orgQuotaPolicyOrganization = Invoke-Json "POST" "$ApiBase/admin/organizations" @{
        name = "Policy Smoke $orgQuotaPolicyBucketName"
        description = "Smoke organization for quota policy checks"
        defaultQuotaBytes = 1024
    } $token
    if (-not $orgQuotaPolicyOrganization.data.id) {
        throw "Organization quota policy smoke did not return organization id."
    }
    $createdOrgQuotaPolicyOrganizationId = $orgQuotaPolicyOrganization.data.id
    Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $orgQuotaPolicyBucketName
        quotaBytes = 1024
        ownerType = "ORG"
        ownerId = $createdOrgQuotaPolicyOrganizationId
    } $token | Out-Null
    $createdOrgQuotaPolicyBucket = $true
    $orgQuotaPolicy = Invoke-Json "PUT" "$ApiBase/admin/quota-policies/ORGANIZATION/$createdOrgQuotaPolicyOrganizationId" @{
        quotaBytes = 8
        reason = "lightweight smoke organization quota"
    } $token
    if ($orgQuotaPolicy.data.targetType -ne "ORGANIZATION" -or $orgQuotaPolicy.data.targetId -ne $createdOrgQuotaPolicyOrganizationId -or $orgQuotaPolicy.data.quotaBytes -ne 8) {
        throw "Organization quota policy did not round-trip."
    }
    Assert-AuditLog $ApiBase $token "QUOTA_POLICY_SAVE" $AdminLoginId "QUOTA_POLICY" "ORGANIZATION:$createdOrgQuotaPolicyOrganizationId" | Out-Null
    $quotaPolicies = Invoke-Json "GET" "$ApiBase/admin/quota-policies" $null $token
    if (-not ($quotaPolicies.items | Where-Object { $_.targetType -eq "ORGANIZATION" -and $_.targetId -eq $createdOrgQuotaPolicyOrganizationId })) {
        throw "Organization quota policy was not visible in policy list."
    }
    $orgQuotaPolicyDenied = Send-SmokeObjectUpload $ApiBase $orgQuotaPolicyBucketName $token "org-policy-blocked.txt" "too-large" "" "org-policy-blocked.txt"
    if ($orgQuotaPolicyDenied.StatusCode -ne 413 -or -not $orgQuotaPolicyDenied.Body.Contains("QUOTA_EXCEEDED")) {
        throw "Organization quota policy upload was not denied: HTTP $($orgQuotaPolicyDenied.StatusCode) $($orgQuotaPolicyDenied.Body)"
    }
    Invoke-Json "DELETE" "$ApiBase/buckets/$orgQuotaPolicyBucketName" $null $token | Out-Null
    $createdOrgQuotaPolicyBucket = $false
    Invoke-Json "DELETE" "$ApiBase/admin/quota-policies/ORGANIZATION/$createdOrgQuotaPolicyOrganizationId" $null $token | Out-Null
    Assert-AuditLog $ApiBase $token "QUOTA_POLICY_DELETE" $AdminLoginId "QUOTA_POLICY" "ORGANIZATION:$createdOrgQuotaPolicyOrganizationId" | Out-Null
    $deleteOrgQuotaPolicyOrganization = Invoke-JsonStatus "DELETE" "$ApiBase/admin/organizations/$createdOrgQuotaPolicyOrganizationId" $null $token
    if ($deleteOrgQuotaPolicyOrganization.StatusCode -ne 204) {
        throw "Organization quota policy smoke cleanup did not delete organization: HTTP $($deleteOrgQuotaPolicyOrganization.StatusCode)"
    }
    $createdOrgQuotaPolicyOrganizationId = 0

    Step "Organization quota"
    $orgQuotaOrganization = Invoke-Json "POST" "$ApiBase/admin/organizations" @{
        name = "Quota Smoke $orgQuotaBucketName"
        description = "Smoke organization for quota checks"
        defaultQuotaBytes = 8
    } $token
    if (-not $orgQuotaOrganization.data.id) {
        throw "Organization quota smoke did not return organization id."
    }
    $createdOrgQuotaOrganizationId = $orgQuotaOrganization.data.id
    Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $orgQuotaBucketName
        quotaBytes = 1024
        ownerType = "ORG"
        ownerId = $orgQuotaOrganization.data.id
    } $token | Out-Null
    $createdOrgQuotaBucket = $true
    $organizationUsage = Invoke-Json "GET" "$ApiBase/admin/organizations/usage" $null $token
    $orgQuotaUsage = $organizationUsage.items | Where-Object { $_.id -eq $orgQuotaOrganization.data.id } | Select-Object -First 1
    if (-not $orgQuotaUsage `
            -or $orgQuotaUsage.defaultQuotaBytes -ne 8 `
            -or $orgQuotaUsage.bucketQuotaBytes -ne 1024 `
            -or $orgQuotaUsage.bucketCount -ne 1 `
            -or $orgQuotaUsage.usedBytes -ne 0 `
            -or $orgQuotaUsage.remainingBytes -ne 8) {
        throw "Organization usage did not reflect quota smoke bucket."
    }
    $orgQuotaDenied = Send-SmokeObjectUpload $ApiBase $orgQuotaBucketName $token "org-quota-blocked.txt" "too-large" "" "org-quota-blocked.txt"
    if ($orgQuotaDenied.StatusCode -ne 413 -or -not $orgQuotaDenied.Body.Contains("QUOTA_EXCEEDED")) {
        throw "Organization quota exceeded upload was not denied: HTTP $($orgQuotaDenied.StatusCode) $($orgQuotaDenied.Body)"
    }
    Invoke-Json "DELETE" "$ApiBase/buckets/$orgQuotaBucketName" $null $token | Out-Null
    $createdOrgQuotaBucket = $false
    $deleteOrgQuotaOrganization = Invoke-JsonStatus "DELETE" "$ApiBase/admin/organizations/$createdOrgQuotaOrganizationId" $null $token
    if ($deleteOrgQuotaOrganization.StatusCode -ne 204) {
        throw "Organization quota smoke cleanup did not delete organization: HTTP $($deleteOrgQuotaOrganization.StatusCode)"
    }
    $createdOrgQuotaOrganizationId = 0

    Step "Organization delete"
    $orgDeleteOrganization = Invoke-Json "POST" "$ApiBase/admin/organizations" @{
        name = "Delete Smoke $orgDeleteBucketName"
        description = "Smoke organization for delete checks"
        defaultQuotaBytes = 1024
    } $token
    if (-not $orgDeleteOrganization.data.id) {
        throw "Organization delete smoke did not return organization id."
    }
    $createdOrgDeleteOrganizationId = $orgDeleteOrganization.data.id
    Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $orgDeleteBucketName
        quotaBytes = 1024
        ownerType = "ORG"
        ownerId = $createdOrgDeleteOrganizationId
    } $token | Out-Null
    $createdOrgDeleteBucket = $true
    $blockedDelete = Invoke-JsonStatus "DELETE" "$ApiBase/admin/organizations/$createdOrgDeleteOrganizationId" $null $token
    if ($blockedDelete.StatusCode -ne 409 -or -not $blockedDelete.Body.Contains("CONFLICT")) {
        throw "Organization delete did not reject org with bucket: HTTP $($blockedDelete.StatusCode) $($blockedDelete.Body)"
    }
    Invoke-Json "DELETE" "$ApiBase/buckets/$orgDeleteBucketName" $null $token | Out-Null
    $createdOrgDeleteBucket = $false
    $deleteOrg = Invoke-JsonStatus "DELETE" "$ApiBase/admin/organizations/$createdOrgDeleteOrganizationId" $null $token
    if ($deleteOrg.StatusCode -ne 204) {
        throw "Organization delete smoke did not delete empty organization: HTTP $($deleteOrg.StatusCode)"
    }
    Assert-AuditLog $ApiBase $token "ORGANIZATION_DELETE" $AdminLoginId "ORGANIZATION" $orgDeleteOrganization.data.name | Out-Null
    $organizationsAfterDelete = Invoke-Json "GET" "$ApiBase/admin/organizations" $null $token
    if ($organizationsAfterDelete.items | Where-Object { $_.id -eq $createdOrgDeleteOrganizationId }) {
        throw "Deleted organization still appears in organization list."
    }
    $createdOrgDeleteOrganizationId = 0

    Step "Organization user and bucket permission"
    $safeBucketName = $BucketName -replace "[^a-z0-9-]", "-"
    $suffix = "$safeBucketName-$([guid]::NewGuid().ToString("N").Substring(0, 8))"
    $organization = Invoke-Json "POST" "$ApiBase/admin/organizations" @{
        name = "Lightweight Smoke $suffix"
        description = "Smoke organization for prototype permission checks"
        defaultQuotaBytes = 10485760
    } $token
    if (-not $organization.data.id) {
        throw "Organization create did not return id."
    }
    Assert-AuditLog $ApiBase $token "ORGANIZATION_CREATE" $AdminLoginId "ORGANIZATION" $organization.data.name | Out-Null

    $smokeLoginId = "smoke-user-$suffix"
    $smokePassword = "SmokePassword!23"
    $smokeUser = Invoke-Json "POST" "$ApiBase/admin/users" @{
        loginId = $smokeLoginId
        email = "$smokeLoginId@example.com"
        name = "Smoke User"
        password = $smokePassword
        role = "USER"
        organizationId = $organization.data.id
    } $token
    if (-not $smokeUser.data.id -or $smokeUser.data.organizationId -ne $organization.data.id) {
        throw "User create did not attach the smoke organization."
    }
    Assert-AuditLog $ApiBase $token "USER_CREATE" $AdminLoginId "USER" $smokeLoginId | Out-Null

    $permissions = Invoke-Json "POST" "$ApiBase/buckets/$BucketName/permissions" @{
        subjectType = "USER"
        subjectId = $smokeUser.data.id
        permissions = @("READ")
    } $token
    $permission = $permissions.items | Where-Object { $_.subjectType -eq "USER" -and $_.subjectId -eq $smokeUser.data.id -and $_.permission -eq "READ" } | Select-Object -First 1
    if (-not $permission) {
        throw "Bucket READ permission was not granted to the smoke user."
    }
    $createdPermissionId = $permission.id
    Assert-AuditLog $ApiBase $token "BUCKET_PERMISSION_GRANT" $AdminLoginId "BUCKET" $BucketName | Out-Null

    $smokeLogin = Invoke-Json "POST" "$ApiBase/auth/login" @{
        loginId = $smokeLoginId
        password = $smokePassword
    }
    $smokeToken = $smokeLogin.data.accessToken
    $smokeRefreshToken = $smokeLogin.data.refreshToken
    if (-not $smokeToken) {
        throw "Smoke user login did not return accessToken."
    }
    if (-not $smokeRefreshToken) {
        throw "Smoke user login did not return refreshToken."
    }

    $visibleBuckets = Invoke-Json "GET" "$ApiBase/buckets" $null $smokeToken
    if (-not ($visibleBuckets.items | Where-Object { $_.name -eq $BucketName })) {
        throw "Read-only smoke user could not see the granted bucket."
    }

    if ((Download-ObjectText $ApiBase $BucketName "hello.txt" $smokeToken) -ne "hello osmu prototype") {
        throw "Read-only smoke user could not download the granted object."
    }

    $deniedUpload = Send-SmokeObjectUpload $ApiBase $BucketName $smokeToken "readonly-blocked.txt" "blocked" "project=osmu" "readonly-blocked.txt"
    if ($deniedUpload.StatusCode -ne 403) {
        throw "Read-only smoke user upload was not denied: HTTP $($deniedUpload.StatusCode) $($deniedUpload.Body)"
    }

    $createdReadAccessKey = Invoke-Json "POST" "$ApiBase/access-keys" @{
        name = "lightweight-readonly-smoke"
        bucketScopes = @(
            @{
                bucketName = $BucketName
                permissions = @("READ")
            }
        )
        expiresAt = $null
    } $smokeToken
    $createdReadAccessKeyId = $createdReadAccessKey.data.id
    if (-not $createdReadAccessKey.data.secretKey) {
        throw "Read-only access key create did not return one-time secretKey."
    }
    Assert-AuditLog $ApiBase $token "ACCESS_KEY_CREATE" $smokeLoginId "ACCESS_KEY" $createdReadAccessKey.data.accessKey | Out-Null

    $accessKeys = Invoke-Json "GET" "$ApiBase/access-keys" $null $smokeToken
    $listedReadKey = $accessKeys.items | Where-Object { $_.id -eq $createdReadAccessKeyId } | Select-Object -First 1
    if (-not $listedReadKey -or $listedReadKey.secretKey) {
        throw "Access key list did not hide the secret key."
    }

    $writeKeyDenied = Invoke-JsonStatus "POST" "$ApiBase/access-keys" @{
        name = "lightweight-write-denied"
        bucketScopes = @(
            @{
                bucketName = $BucketName
                permissions = @("WRITE")
            }
        )
        expiresAt = $null
    } $smokeToken
    if ($writeKeyDenied.StatusCode -ne 403) {
        throw "Read-only smoke user could create a WRITE access key: HTTP $($writeKeyDenied.StatusCode)"
    }

    Step "User status enforcement"
    $inactiveUser = Invoke-Json "PATCH" "$ApiBase/admin/users/$($smokeUser.data.id)/status" @{
        status = "INACTIVE"
    } $token
    if ($inactiveUser.data.status -ne "INACTIVE") {
        throw "User status update did not return INACTIVE."
    }
    Assert-AuditLog $ApiBase $token "USER_STATUS_UPDATE" $AdminLoginId "USER" $smokeLoginId | Out-Null

    $adminAccessKeys = Invoke-Json "GET" "$ApiBase/access-keys" $null $token
    $deactivatedReadKey = $adminAccessKeys.items | Where-Object { $_.id -eq $createdReadAccessKeyId } | Select-Object -First 1
    if (-not $deactivatedReadKey -or $deactivatedReadKey.status -ne "INACTIVE") {
        throw "User status update did not deactivate the user's access key."
    }

    $inactiveLogin = Invoke-JsonStatus "POST" "$ApiBase/auth/login" @{
        loginId = $smokeLoginId
        password = $smokePassword
    }
    if ($inactiveLogin.StatusCode -ne 401 -or -not $inactiveLogin.Body.Contains("AUTHENTICATION_REQUIRED")) {
        throw "Inactive user login was not denied: HTTP $($inactiveLogin.StatusCode) $($inactiveLogin.Body)"
    }

    $inactiveRefresh = Invoke-JsonStatus "POST" "$ApiBase/auth/refresh" @{
        refreshToken = $smokeRefreshToken
    }
    if ($inactiveRefresh.StatusCode -ne 401 -or -not $inactiveRefresh.Body.Contains("AUTHENTICATION_REQUIRED")) {
        throw "Inactive user refresh token was not denied: HTTP $($inactiveRefresh.StatusCode) $($inactiveRefresh.Body)"
    }

    $inactiveTokenAccess = Invoke-JsonStatus "GET" "$ApiBase/buckets" $null $smokeToken
    if ($inactiveTokenAccess.StatusCode -ne 401 -or -not $inactiveTokenAccess.Body.Contains("AUTHENTICATION_REQUIRED")) {
        throw "Inactive user token was not denied: HTTP $($inactiveTokenAccess.StatusCode) $($inactiveTokenAccess.Body)"
    }

    Step "Object tags and metadata"
    $updatedObject = Invoke-Json "PUT" "$ApiBase/buckets/$BucketName/objects/tags" @{
        key = "hello.txt"
        tags = "project=osmu,stage=verified"
    } $token
    if ($updatedObject.data.tags.stage -ne "verified") {
        throw "Object tag update did not return the updated stage tag."
    }
    Assert-AuditLog $ApiBase $token "OBJECT_TAG_UPDATE" $AdminLoginId "OBJECT" "$BucketName/hello.txt" | Out-Null

    $metadata = Invoke-Json "GET" "$ApiBase/buckets/$BucketName/objects/metadata/hello.txt" $null $token
    if ($metadata.data.tags.project -ne "osmu" -or $metadata.data.tags.stage -ne "verified") {
        throw "Object metadata did not expose updated tags."
    }

    $tagFilter = [System.Uri]::EscapeDataString("stage=verified")
    $taggedObjects = Invoke-Json "GET" "$ApiBase/buckets/$BucketName/objects?tag=$tagFilter" $null $token
    if (-not ($taggedObjects.items | Where-Object { $_.key -eq "hello.txt" })) {
        throw "Object tag filter did not return the tagged object."
    }

    Step "Object versions"
    Upload-SmokeObject `
        $ApiBase `
        $BucketName `
        $token `
        "hello.txt" `
        "hello osmu prototype v2" `
        "project=osmu,stage=versioned" `
        "hello.txt"

    $versions = Invoke-Json "GET" "$ApiBase/buckets/$BucketName/objects/versions/hello.txt" $null $token
    if ($versions.data.Count -lt 1) {
        throw "Object overwrite did not create a previous version."
    }
    $firstVersion = $versions.data | Select-Object -First 1
    if (-not $firstVersion.versionId -or $firstVersion.tags.stage -ne "verified") {
        throw "Object version metadata did not preserve previous object tags."
    }

    $currentBody = Download-ObjectText $ApiBase $BucketName "hello.txt" $token
    if ($currentBody -ne "hello osmu prototype v2") {
        throw "Overwritten object body mismatch."
    }

    $versionBody = Download-ObjectVersionText $ApiBase $BucketName "hello.txt" $firstVersion.versionId $token
    if ($versionBody -ne "hello osmu prototype") {
        throw "Object version download body mismatch."
    }

    $restored = Invoke-Json "POST" "$ApiBase/buckets/$BucketName/objects/versions/$($firstVersion.versionId)/restore/hello.txt" $null $token
    if ($restored.data.sizeBytes -ne 20) {
        throw "Object version restore did not return the original object size."
    }
    Assert-AuditLog $ApiBase $token "OBJECT_VERSION_RESTORE" $AdminLoginId "OBJECT" "$BucketName/hello.txt" | Out-Null

    $restoredBody = Download-ObjectText $ApiBase $BucketName "hello.txt" $token
    if ($restoredBody -ne "hello osmu prototype") {
        throw "Object version restore body mismatch."
    }

    $versionsAfterRestore = Invoke-Json "GET" "$ApiBase/buckets/$BucketName/objects/versions/hello.txt" $null $token
    if ($versionsAfterRestore.data.Count -lt 2) {
        throw "Object version restore did not snapshot the overwritten object."
    }

    Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/objects/versions/$($firstVersion.versionId)/delete/hello.txt" $null $token | Out-Null
    Assert-AuditLog $ApiBase $token "OBJECT_VERSION_DELETE" $AdminLoginId "OBJECT" "$BucketName/hello.txt#$($firstVersion.versionId)" | Out-Null
    $versionsAfterDelete = Invoke-Json "GET" "$ApiBase/buckets/$BucketName/objects/versions/hello.txt" $null $token
    if ($versionsAfterDelete.data | Where-Object { $_.versionId -eq $firstVersion.versionId }) {
        throw "Object version delete did not remove the target version."
    }

    Step "Lifecycle rule"
    $lifecycleRuleId = "smoke-$([guid]::NewGuid().ToString("N"))"
    $lifecycleRule = Invoke-Json "POST" "$ApiBase/admin/object-lifecycle/rules" @{
        ruleId = $lifecycleRuleId
        name = "Lightweight smoke $BucketName"
        enabled = $true
        priority = 5000
        bucketName = $BucketName
        targetType = "TRASH_OBJECT"
        prefix = "hello"
        tags = "project=osmu,stage=verified"
        retentionDays = 1
        batchSize = 10
    } $token
    if ($lifecycleRule.data.ruleId -ne $lifecycleRuleId -or $lifecycleRule.data.bucketName -ne $BucketName) {
        throw "Lifecycle rule create did not round-trip."
    }
    $createdLifecycleRuleId = $lifecycleRule.data.ruleId
    Assert-AuditLog $ApiBase $token "OBJECT_LIFECYCLE_RULE_SAVE" $AdminLoginId "OBJECT_LIFECYCLE_RULE" $createdLifecycleRuleId | Out-Null

    $lifecycleRules = Invoke-Json "GET" "$ApiBase/admin/object-lifecycle/rules" $null $token
    if (-not ($lifecycleRules.data | Where-Object { $_.ruleId -eq $createdLifecycleRuleId })) {
        throw "Lifecycle rule not found in rule list."
    }

    $lifecycleConflicts = Invoke-Json "GET" "$ApiBase/admin/object-lifecycle/conflicts" $null $token
    if ($null -eq $lifecycleConflicts.data.conflictCount) {
        throw "Lifecycle conflict report did not return conflictCount."
    }

    $lifecycleDryRun = Invoke-Json "GET" "$ApiBase/admin/object-lifecycle/rules/$createdLifecycleRuleId/dry-run?limit=5" $null $token
    if ($lifecycleDryRun.data.rule.ruleId -ne $createdLifecycleRuleId -or $lifecycleDryRun.data.previewLimit -ne 5) {
        throw "Lifecycle dry run did not return expected rule preview."
    }

    Step "Object download"
    if ((Download-ObjectText $ApiBase $BucketName "hello.txt" $token) -ne "hello osmu prototype") {
        throw "Downloaded object body mismatch."
    }
    Assert-AuditLog $ApiBase $token "OBJECT_DOWNLOAD" $AdminLoginId "OBJECT" "$BucketName/hello.txt" | Out-Null

    Step "Object trash and restore"
    Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/objects/hello.txt" $null $token | Out-Null
    Assert-AuditLog $ApiBase $token "OBJECT_DELETE" $AdminLoginId "OBJECT" "$BucketName/hello.txt" | Out-Null
    $trashObjects = Invoke-Json "GET" "$ApiBase/buckets/$BucketName/objects?deleted=true" $null $token
    if (-not ($trashObjects.items | Where-Object { $_.key -eq "hello.txt" -and $_.deletedAt })) {
        throw "Deleted object was not visible in trash listing."
    }

    Invoke-Json "POST" "$ApiBase/buckets/$BucketName/objects/restore/hello.txt" $null $token | Out-Null
    Assert-AuditLog $ApiBase $token "OBJECT_RESTORE" $AdminLoginId "OBJECT" "$BucketName/hello.txt" | Out-Null
    if ((Download-ObjectText $ApiBase $BucketName "hello.txt" $token) -ne "hello osmu prototype") {
        throw "Restored object body mismatch."
    }

    Step "Cleanup"
    if ($createdReadAccessKeyId) {
        Invoke-Json "DELETE" "$ApiBase/access-keys/$createdReadAccessKeyId" $null $token | Out-Null
        $createdReadAccessKeyId = 0
    }
    if ($createdPermissionId) {
        Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/permissions/$createdPermissionId" $null $token | Out-Null
        $createdPermissionId = 0
    }
    Invoke-Json "DELETE" "$ApiBase/admin/object-lifecycle/rules/$createdLifecycleRuleId" $null $token | Out-Null
    $createdLifecycleRuleId = ""
    Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/tags" $null $token | Out-Null
    Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/objects/hello.txt" $null $token | Out-Null
    Invoke-Json "POST" "$ApiBase/buckets/$BucketName/objects/purge/hello.txt" $null $token | Out-Null
    Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName" $null $token | Out-Null
    $createdBucket = $false

    $usageAfterCleanup = Invoke-Json "GET" "$ApiBase/admin/usage" $null $token
    if ($usageAfterCleanup.data.bucketCount -ne $initialUsage.data.bucketCount `
            -or $usageAfterCleanup.data.objectCount -ne $initialUsage.data.objectCount `
            -or $usageAfterCleanup.data.usedBytes -ne $initialUsage.data.usedBytes) {
        throw "Admin usage did not return to baseline after cleanup."
    }

    Step "Lightweight prototype smoke passed"
}
finally {
    if ($objectSharePolicyChanged -and $token) {
        try {
            Invoke-Json "PUT" "$ApiBase/admin/object-share-policy" @{
                requirePassword = $false
                requireIpAllowlist = $false
                maxExpiresSeconds = 604800
                maxDownloadsLimit = $null
                reason = "lightweight smoke reset"
            } $token | Out-Null
        }
        catch {
            Write-Warning "Object share policy reset skipped: $($_.Exception.Message)"
        }
    }

    if ($createdReadAccessKeyId) {
        try {
            Invoke-Json "DELETE" "$ApiBase/access-keys/$createdReadAccessKeyId" $null $token | Out-Null
        }
        catch {
            Write-Warning "Access key cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdPermissionId) {
        try {
            Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/permissions/$createdPermissionId" $null $token | Out-Null
        }
        catch {
            Write-Warning "Permission cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdShareLinkId) {
        try {
            Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/objects/share-links/$createdShareLinkId" $null $token | Out-Null
        }
        catch {
            Write-Warning "Share link cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdLifecycleRuleId) {
        try {
            Invoke-Json "DELETE" "$ApiBase/admin/object-lifecycle/rules/$createdLifecycleRuleId" $null $token | Out-Null
        }
        catch {
            Write-Warning "Lifecycle cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdQuotaBucket) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/buckets/$quotaBucketName/objects/quota-ok.txt" $null $token | Out-Null
            Invoke-JsonStatus "POST" "$ApiBase/buckets/$quotaBucketName/objects/purge/quota-ok.txt" $null $token | Out-Null
            Invoke-JsonStatus "DELETE" "$ApiBase/buckets/$quotaBucketName" $null $token | Out-Null
        }
        catch {
            Write-Warning "Quota cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdUserQuotaBucket) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/buckets/$userQuotaBucketName" $null $token | Out-Null
        }
        catch {
            Write-Warning "User quota bucket cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdUserQuotaPolicyTargetId) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/admin/quota-policies/USER/$createdUserQuotaPolicyTargetId" $null $token | Out-Null
        }
        catch {
            Write-Warning "User quota policy cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdBucketQuotaPolicyBucket) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/buckets/$bucketQuotaPolicyBucketName" $null $token | Out-Null
        }
        catch {
            Write-Warning "Bucket quota policy bucket cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdBucketQuotaPolicyTargetId) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/admin/quota-policies/BUCKET/$createdBucketQuotaPolicyTargetId" $null $token | Out-Null
        }
        catch {
            Write-Warning "Bucket quota policy cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdOrgQuotaPolicyBucket) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/buckets/$orgQuotaPolicyBucketName" $null $token | Out-Null
        }
        catch {
            Write-Warning "Organization quota policy bucket cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdOrgQuotaPolicyOrganizationId) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/admin/quota-policies/ORGANIZATION/$createdOrgQuotaPolicyOrganizationId" $null $token | Out-Null
            Invoke-JsonStatus "DELETE" "$ApiBase/admin/organizations/$createdOrgQuotaPolicyOrganizationId" $null $token | Out-Null
        }
        catch {
            Write-Warning "Organization quota policy cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdOrgQuotaBucket) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/buckets/$orgQuotaBucketName/objects/org-quota-blocked.txt" $null $token | Out-Null
            Invoke-JsonStatus "POST" "$ApiBase/buckets/$orgQuotaBucketName/objects/purge/org-quota-blocked.txt" $null $token | Out-Null
            Invoke-JsonStatus "DELETE" "$ApiBase/buckets/$orgQuotaBucketName" $null $token | Out-Null
        }
        catch {
            Write-Warning "Organization quota cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdOrgQuotaOrganizationId) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/admin/organizations/$createdOrgQuotaOrganizationId" $null $token | Out-Null
        }
        catch {
            Write-Warning "Organization quota organization cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdOrgDeleteBucket) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/buckets/$orgDeleteBucketName" $null $token | Out-Null
        }
        catch {
            Write-Warning "Organization delete bucket cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdOrgDeleteOrganizationId) {
        try {
            Invoke-JsonStatus "DELETE" "$ApiBase/admin/organizations/$createdOrgDeleteOrganizationId" $null $token | Out-Null
        }
        catch {
            Write-Warning "Organization delete organization cleanup skipped: $($_.Exception.Message)"
        }
    }

    if ($createdBucket) {
        try {
            Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/objects/hello.txt" $null $token | Out-Null
            Invoke-Json "POST" "$ApiBase/buckets/$BucketName/objects/purge/hello.txt" $null $token | Out-Null
            Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName" $null $token | Out-Null
        }
        catch {
            Write-Warning "Cleanup skipped: $($_.Exception.Message)"
        }
    }
}
