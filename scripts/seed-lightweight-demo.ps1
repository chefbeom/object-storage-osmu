param(
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "password",
    [string] $DemoPassword = "DemoPassword!23",
    [string] $Suffix = "",
    [string] $DemoOutputPath = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

if (-not $Suffix) {
    $Suffix = "$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())-$([guid]::NewGuid().ToString("N").Substring(0, 6))"
}
if (-not $DemoOutputPath) {
    $DemoOutputPath = Join-Path $root ".osmu-run\latest-demo.json"
}

$orgName = "OSMU Demo $Suffix"
$demoAdminLoginId = "demo-admin-$Suffix"
$demoUserLoginId = "demo-user-$Suffix"
$mediaBucketName = "osmu-demo-media-$Suffix"
$aiBucketName = "osmu-demo-ai-$Suffix"

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

function Upload-DemoObject($apiBase, $bucketName, $token, $key, $contentText, $tags, $contentType = "text/plain") {
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

        $bytes = [System.Text.Encoding]::UTF8.GetBytes($contentText)
        $fileContent = [System.Net.Http.ByteArrayContent]::new($bytes)
        $fileContent.Headers.ContentType =
            [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($contentType)
        $content.Add($fileContent, "file", [System.IO.Path]::GetFileName($key))

        $response = $client.PostAsync("$apiBase/buckets/$bucketName/objects", $content).GetAwaiter().GetResult()
        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            throw "Upload failed for $bucketName/$key`: HTTP $([int] $response.StatusCode) $responseBody"
        }
    }
    finally {
        $client.Dispose()
    }
}

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

Step "Organization"
$organization = Invoke-Json "POST" "$ApiBase/admin/organizations" @{
    name = $orgName
    description = "Seeded demo organization for OSMU prototype."
    defaultQuotaBytes = 107374182400
} $adminToken
$organizationId = $organization.data.id

Step "Demo users"
$demoAdmin = Invoke-Json "POST" "$ApiBase/admin/users" @{
    loginId = $demoAdminLoginId
    email = "$demoAdminLoginId@example.com"
    name = "Demo Organization Admin"
    password = $DemoPassword
    role = "ORG_ADMIN"
    organizationId = $organizationId
} $adminToken

$demoUser = Invoke-Json "POST" "$ApiBase/admin/users" @{
    loginId = $demoUserLoginId
    email = "$demoUserLoginId@example.com"
    name = "Demo Storage User"
    password = $DemoPassword
    role = "USER"
    organizationId = $organizationId
} $adminToken

Step "Demo buckets"
Invoke-Json "POST" "$ApiBase/buckets" @{
    name = $mediaBucketName
    quotaBytes = 52428800
    ownerType = "ORG"
    ownerId = $organizationId
} $adminToken | Out-Null

Invoke-Json "POST" "$ApiBase/buckets" @{
    name = $aiBucketName
    quotaBytes = 52428800
    ownerType = "USER"
    ownerId = $demoAdmin.data.id
} $adminToken | Out-Null

Step "Bucket tags"
Invoke-Json "PUT" "$ApiBase/buckets/$mediaBucketName/tags" @{
    tags = @{
        workload = "streaming"
        confidentiality = "internal"
        project = "osmu"
    }
} $adminToken | Out-Null

Invoke-Json "PUT" "$ApiBase/buckets/$aiBucketName/tags" @{
    tags = @{
        workload = "ai"
        confidentiality = "restricted"
        project = "osmu"
    }
} $adminToken | Out-Null

Step "Bucket permissions"
Invoke-Json "POST" "$ApiBase/buckets/$mediaBucketName/permissions" @{
    subjectType = "USER"
    subjectId = $demoUser.data.id
    permissions = @("READ", "WRITE", "DELETE")
} $adminToken | Out-Null

Invoke-Json "POST" "$ApiBase/buckets/$aiBucketName/permissions" @{
    subjectType = "USER"
    subjectId = $demoUser.data.id
    permissions = @("READ")
} $adminToken | Out-Null

Step "Demo objects"
Upload-DemoObject `
    $ApiBase `
    $mediaBucketName `
    $adminToken `
    "videos/raw/sample-video-manifest.txt" `
    "sampleId=video-001`ncodec=h264`nsource=prototype`n" `
    "type=video,stage=raw,project=osmu"

Upload-DemoObject `
    $ApiBase `
    $mediaBucketName `
    $adminToken `
    "videos/encoded/sample-rendition.txt" `
    "sampleId=video-001`nprofile=1080p`nstatus=ready`n" `
    "type=video,stage=encoded,project=osmu"

Upload-DemoObject `
    $ApiBase `
    $aiBucketName `
    $adminToken `
    "datasets/images/sample-dataset.json" `
    "{ `"dataset`": `"sample-images`", `"items`": 3, `"owner`": `"osmu`" }" `
    "type=ai,stage=curated,project=osmu" `
    "application/json"

Step "Lifecycle rules"
$mediaLifecycleXml = @"
<LifecycleConfiguration>
  <Rule>
    <ID>media-raw-trash-retention</ID>
    <Status>Enabled</Status>
    <Filter>
      <And>
        <Prefix>videos/raw/</Prefix>
        <Tag>
          <Key>stage</Key>
          <Value>raw</Value>
        </Tag>
      </And>
    </Filter>
    <Expiration>
      <Days>30</Days>
    </Expiration>
  </Rule>
</LifecycleConfiguration>
"@

Invoke-Json "PUT" "$ApiBase/buckets/$mediaBucketName/lifecycle" @{
    xml = $mediaLifecycleXml
} $adminToken | Out-Null

Invoke-Json "POST" "$ApiBase/admin/object-lifecycle/rules" @{
    name = "AI dataset version retention $Suffix"
    enabled = $true
    priority = 200
    bucketName = $aiBucketName
    targetType = "OBJECT_VERSION"
    prefix = "datasets/"
    tags = "project=osmu,type=ai"
    retentionDays = 90
    batchSize = 100
} $adminToken | Out-Null

Step "Demo user access key"
$demoUserLogin = Invoke-Json "POST" "$ApiBase/auth/login" @{
    loginId = $demoUserLoginId
    password = $DemoPassword
}
$demoUserToken = $demoUserLogin.data.accessToken

$accessKey = Invoke-Json "POST" "$ApiBase/access-keys" @{
    name = "demo-sdk-key-$Suffix"
    bucketScopes = @(
        @{
            bucketName = $mediaBucketName
            permissions = @("READ", "WRITE", "DELETE")
        },
        @{
            bucketName = $aiBucketName
            permissions = @("READ")
        }
    )
} $demoUserToken

$demoOutput = [pscustomobject]@{
    createdAt = [DateTimeOffset]::Now.ToString("o")
    apiBase = $ApiBase
    orgName = $orgName
    organizationId = $organizationId
    orgAdminLoginId = $demoAdminLoginId
    demoUserLoginId = $demoUserLoginId
    demoPassword = $DemoPassword
    mediaBucketName = $mediaBucketName
    aiBucketName = $aiBucketName
    accessKey = $accessKey.data.accessKey
    secretKey = $accessKey.data.secretKey
}
$demoOutputDirectory = Split-Path -Parent $DemoOutputPath
if ($demoOutputDirectory) {
    New-Item -ItemType Directory -Force -Path $demoOutputDirectory | Out-Null
}
$demoOutput | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $DemoOutputPath -Encoding UTF8

Step "Seed complete"
Write-Host "Organization: $orgName (id=$organizationId)"
Write-Host "Org admin:    $demoAdminLoginId / $DemoPassword"
Write-Host "Demo user:    $demoUserLoginId / $DemoPassword"
Write-Host "Buckets:      $mediaBucketName, $aiBucketName"
Write-Host "Access key:   $($accessKey.data.accessKey)"
Write-Host "Secret key:   $($accessKey.data.secretKey)"
Write-Host "Credential file: $DemoOutputPath"
Write-Host ""
Write-Host "Open frontend: http://localhost:5173"
