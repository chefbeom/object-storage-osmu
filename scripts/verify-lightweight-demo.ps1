param(
    [string] $FrontendBase = "http://localhost:5173",
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "password",
    [string] $DemoLoginId = "",
    [string] $DemoPassword = "DemoPassword!23",
    [string] $S3Endpoint = "",
    [string] $DemoCredentialPath = "",
    [switch] $SeedIfMissing,
    [switch] $SkipS3AccessKeySmoke
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

if (-not $S3Endpoint) {
    $S3Endpoint = "$ApiBase/s3"
}
if (-not $DemoCredentialPath) {
    $DemoCredentialPath = Join-Path $root ".osmu-run\latest-demo.json"
}

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
$html = $homePage.Content
$mainModule = Frontend-Text $FrontendBase "/src/main.js" $false
$homeViewModule = Frontend-Text $FrontendBase "/src/views/HomeView.vue" $false
$apiModule = Frontend-Text $FrontendBase "/src/services/api.js" $false
$cssModule = Frontend-Text $FrontendBase "/src/assets/main.css" $false
$jsBundle = Frontend-AssetBundle $FrontendBase $html "js"
$cssBundle = Frontend-AssetBundle $FrontendBase $html "css"

$mainText = "$mainModule`n$jsBundle"
$uiText = "$homeViewModule`n$jsBundle"
$apiText = "$apiModule`n$jsBundle"
$styleText = "$cssModule`n$cssBundle"

Assert-Contains $html "<div id=`"app`"></div>" "frontend HTML"
Assert-Contains $mainText "createApp" "frontend JS"
Assert-Contains $uiText "Storage Dashboard" "frontend UI bundle"
Assert-Contains $uiText "Lifecycle Rules" "frontend UI bundle"
Assert-Contains $uiText "Bucket Tags" "frontend UI bundle"
Assert-Contains $uiText "Organizations" "frontend UI bundle"
Assert-Contains $uiText "Delete organization" "frontend UI bundle"
Assert-Contains $uiText "Audit Logs" "frontend UI bundle"
Assert-Contains $uiText "Export CSV" "frontend UI bundle"
Assert-Contains $apiText "object-lifecycle/rules" "frontend API bundle"
Assert-Contains $apiText "audit-logs/export.csv" "frontend API bundle"
Assert-Contains $apiText "downloadAuditLogsCsv" "frontend API bundle"
Assert-Contains $apiText "/admin/organizations/" "frontend API bundle"
Assert-Contains $apiText "deleteOrganization" "frontend API bundle"
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

$demoUser = Find-DemoUser $ApiBase $adminToken $DemoLoginId
if (-not $demoUser -and $SeedIfMissing) {
    Step "Seed missing demo data"
    powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\seed-lightweight-demo.ps1" `
        -ApiBase $ApiBase `
        -AdminLoginId $AdminLoginId `
        -AdminPassword $AdminPassword `
        -DemoPassword $DemoPassword `
        -DemoOutputPath $DemoCredentialPath | Out-Null
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
