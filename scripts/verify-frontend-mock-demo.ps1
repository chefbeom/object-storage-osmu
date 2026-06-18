param(
    [int] $ApiPort = 8080,
    [int] $FrontendPort = 5173,
    [string] $LogDir = ".\.osmu-run\frontend-mock-demo",
    [switch] $NoPreClean,
    [switch] $NoStart
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$apiBase = "http://localhost:$ApiPort/api"
$frontendBase = "http://localhost:$FrontendPort"
$started = -not $NoStart

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Invoke-Json($method, $url, $body = $null, $token = "") {
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
        -Body ($body | ConvertTo-Json -Depth 8)
}

function Invoke-MultipartUpload($url, $token, $key, $content, $tags) {
    Add-Type -AssemblyName System.Net.Http

    $client = [System.Net.Http.HttpClient]::new()
    try {
        if ($token) {
            $client.DefaultRequestHeaders.Authorization =
                [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $token)
        }

        $form = [System.Net.Http.MultipartFormDataContent]::new()
        $form.Add([System.Net.Http.StringContent]::new($key), "key")
        $form.Add([System.Net.Http.StringContent]::new($tags), "tags")
        $fileBytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        $fileContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)
        $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/plain")
        $form.Add($fileContent, "file", "hello.txt")

        $response = $client.PostAsync($url, $form).GetAwaiter().GetResult()
        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            throw "Multipart upload failed: HTTP $([int]$response.StatusCode) $responseBody"
        }
        return $responseBody | ConvertFrom-Json
    }
    finally {
        $client.Dispose()
    }
}

function Invoke-ProjectScript([string] $ScriptName, [string[]] $Arguments = @()) {
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    Write-Host "    $ScriptName $($Arguments -join ' ')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptName failed with exit code $LASTEXITCODE."
    }
}

try {
    if ($started) {
        if (-not $NoPreClean) {
            Step "Pre-clean frontend mock demo ports"
            Invoke-ProjectScript "stop-frontend-mock-demo.ps1" @(
                "-LogDir", $LogDir,
                "-ForcePorts",
                "-Ports", "$ApiPort", "$FrontendPort"
            )
        }

        Step "Start frontend mock demo"
        Invoke-ProjectScript "start-frontend-mock-demo.ps1" @(
            "-ApiPort", "$ApiPort",
            "-FrontendPort", "$FrontendPort",
            "-LogDir", $LogDir
        )
    }

    Step "Frontend document"
    $rootPage = Invoke-WebRequest -Method GET -Uri $frontendBase -UseBasicParsing
    if ($rootPage.StatusCode -ne 200 -or -not $rootPage.Content.Contains('<div id="app"></div>')) {
        throw "Frontend root page did not return the Vue app shell."
    }
    $loginPage = Invoke-WebRequest -Method GET -Uri "$frontendBase/login" -UseBasicParsing
    if ($loginPage.StatusCode -ne 200 -or -not $loginPage.Content.Contains('<div id="app"></div>')) {
        throw "Frontend login page did not return the Vue app shell."
    }

    Step "Mock API health"
    $health = Invoke-Json "GET" "$apiBase/health"
    if ($health.data.status -ne "UP" -or $health.data.storage -ne "MOCK" -or $health.data.database -ne "MOCK") {
        throw "Mock API health did not report expected mock runtime."
    }

    Step "Reset mock API state"
    $reset = Invoke-Json "POST" "$apiBase/mock/reset"
    if (-not $reset.data.reset -or $reset.data.bucketCount -lt 2 -or $reset.data.objectCount -lt 3) {
        throw "Mock API reset did not restore expected fixture state."
    }

    Step "Mock login"
    $login = Invoke-Json "POST" "$apiBase/auth/login" @{
        loginId = "admin"
        password = "password"
    }
    $token = $login.data.accessToken
    if (-not $token -or $login.data.user.role -ne "ADMIN") {
        throw "Mock login did not return an ADMIN session."
    }

    Step "Developer login and S3 config"
    $developerLogin = Invoke-Json "POST" "$apiBase/auth/login" @{
        loginId = "developer"
        password = "password"
    }
    $developerToken = $developerLogin.data.accessToken
    if (-not $developerToken -or $developerLogin.data.user.role -ne "USER") {
        throw "Mock developer login did not return a USER session."
    }

    $developerProfile = Invoke-Json "GET" "$apiBase/users/me" $null $developerToken
    if ($developerProfile.data.loginId -ne "developer" -or $developerProfile.data.role -ne "USER") {
        throw "Mock developer profile did not match the developer session."
    }

    $s3Config = Invoke-Json "GET" "$apiBase/developer/s3-client-config" $null $developerToken
    if ($s3Config.data.endpoint -notlike "*api/s3" -or $s3Config.data.signatureVersion -ne "AWS4-HMAC-SHA256") {
        throw "Mock developer S3 client config did not include expected S3 compatibility settings."
    }

    Step "Bucket and object flow"
    $bucketName = "mock-smoke-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
    $bucket = Invoke-Json "POST" "$apiBase/buckets" @{
        name = $bucketName
        quotaBytes = 1073741824
    } $token
    if ($bucket.data.name -ne $bucketName) {
        throw "Mock bucket create failed."
    }

    $objectKey = "smoke/hello.txt"
    $upload = Invoke-MultipartUpload "$apiBase/buckets/$bucketName/objects" $token $objectKey "hello mock api" "project=osmu,stage=mock"
    if ($upload.data.key -ne $objectKey) {
        throw "Mock object upload failed: $($upload | ConvertTo-Json -Depth 8)"
    }

    $objects = Invoke-Json "GET" "$apiBase/buckets/$bucketName/objects?search=hello" $null $token
    if (-not ($objects.items | Where-Object { $_.key -eq $objectKey })) {
        throw "Mock object list did not include uploaded object."
    }

    Step "Developer access key flow"
    $accessKey = Invoke-Json "POST" "$apiBase/access-keys" @{
        name = "developer-smoke-key"
        bucketScopes = @(
            @{
                bucketName = $bucketName
                permissions = @("READ", "WRITE")
            }
        )
    } $developerToken
    if (-not $accessKey.data.accessKey -or -not $accessKey.data.secretKey) {
        throw "Mock developer access key create did not return one-time credentials."
    }

    $accessKeyList = Invoke-Json "GET" "$apiBase/access-keys" $null $developerToken
    $listedKey = $accessKeyList.items | Where-Object { $_.name -eq "developer-smoke-key" } | Select-Object -First 1
    if (-not $listedKey -or $listedKey.secretKey) {
        throw "Mock developer access key list did not include redacted created key."
    }

    Step "Mock dashboard endpoints"
    $summary = Invoke-Json "GET" "$apiBase/admin/dashboard/summary" $null $token
    if ($summary.data.system.storage -ne "MOCK" -or $summary.data.readiness.status -ne "REVIEW") {
        throw "Mock dashboard summary did not include expected runtime evidence."
    }

    Write-Host "Frontend mock demo verified."
}
finally {
    if ($started) {
        Step "Stop frontend mock demo"
        try {
            Invoke-ProjectScript "stop-frontend-mock-demo.ps1" @(
                "-LogDir", $LogDir,
                "-ForcePorts",
                "-Ports", "$ApiPort", "$FrontendPort"
            )
        }
        catch {
            Write-Warning "Stop frontend mock demo failed: $($_.Exception.Message)"
        }
    }
}
