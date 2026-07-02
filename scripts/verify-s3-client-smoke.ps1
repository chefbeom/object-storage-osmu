param(
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $S3Endpoint = "",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "password",
    [string] $BucketName = "",
    [ValidateSet("auto", "aws", "boto3", "aws-js", "aws-java", "mc", "docker-mc", "all")]
    [string] $Client = "auto",
    [string] $DockerMcImage = "minio/mc:RELEASE.2025-05-21T01-59-54Z",
    [switch] $SkipManualSigV4,
    [switch] $SkipMultipartChecksumSmoke,
    [switch] $SkipVirtualHostedSmoke,
    [switch] $KeepBucket,
    [switch] $RequireClient
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")
Use-OsmuDockerConfig $root | Out-Null

function Get-OriginEndpoint([string] $Url) {
    $uri = [Uri] $Url
    $builder = [System.UriBuilder]::new($uri)
    $builder.Path = ""
    $builder.Query = ""
    $builder.Fragment = ""
    return $builder.Uri.AbsoluteUri.TrimEnd("/")
}

if (-not $S3Endpoint) {
    $S3Endpoint = Get-OriginEndpoint $ApiBase
}
if (-not $BucketName) {
    $BucketName = "client-smoke-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
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

function Invoke-External([string] $Executable, [string[]] $Arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $Executable @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($output) {
        $output | ForEach-Object { Write-Host $_ }
    }
    if ($exitCode -ne 0) {
        throw "Command failed ($exitCode): $Executable $($Arguments -join ' ')"
    }
    return $output
}

function Invoke-ExternalText([string] $Executable, [string[]] $Arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $Executable @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($exitCode -ne 0) {
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        throw "Command failed ($exitCode): $Executable $($Arguments -join ' ')"
    }
    return ($output -join [Environment]::NewLine)
}

function Get-ContentMd5Base64([string] $Path) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        return [Convert]::ToBase64String($md5.ComputeHash([System.IO.File]::ReadAllBytes($Path)))
    }
    finally {
        $md5.Dispose()
    }
}

function Get-Md5Base64([byte[]] $Bytes) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        return [Convert]::ToBase64String($md5.ComputeHash($Bytes))
    }
    finally {
        $md5.Dispose()
    }
}

function Get-Md5Hex([byte[]] $Bytes) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        return (($md5.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
        $md5.Dispose()
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

function Get-Sha256Base64([byte[]] $Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToBase64String($sha.ComputeHash($Bytes))
    }
    finally {
        $sha.Dispose()
    }
}

function Get-CompositeSha256Base64([string[]] $PartChecksums) {
    $checksumBytes = [System.Collections.Generic.List[byte]]::new()
    foreach ($partChecksum in $PartChecksums) {
        foreach ($value in [Convert]::FromBase64String($partChecksum)) {
            $checksumBytes.Add($value)
        }
    }
    return Get-Sha256Base64 $checksumBytes.ToArray()
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

function Convert-HexToBytes([string] $Hex) {
    $normalized = $Hex.Trim()
    if ($normalized.Length % 2 -ne 0 -or $normalized -notmatch '^[0-9a-fA-F]+$') {
        throw "Invalid hex digest: $Hex"
    }
    $bytes = [byte[]]::new([int]($normalized.Length / 2))
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($normalized.Substring($i * 2, 2), 16)
    }
    return $bytes
}

function Normalize-Etag([string] $Etag) {
    if (-not $Etag) {
        return ""
    }
    $normalized = $Etag.Trim()
    if ($normalized.StartsWith("`"") -and $normalized.EndsWith("`"") -and $normalized.Length -ge 2) {
        return $normalized.Substring(1, $normalized.Length - 2)
    }
    return $normalized
}

function Get-S3MultipartEtag([string[]] $PartEtags) {
    $partDigestBytes = [System.Collections.Generic.List[byte]]::new()
    foreach ($partEtag in $PartEtags) {
        $clean = Normalize-Etag $partEtag
        if ($clean -notmatch '^[0-9a-fA-F]{32}$') {
            throw "Multipart part ETag is not an MD5 digest: $partEtag"
        }
        foreach ($value in (Convert-HexToBytes $clean)) {
            $partDigestBytes.Add($value)
        }
    }
    $aggregateBytes = $partDigestBytes.ToArray()
    return "$(Get-Md5Hex $aggregateBytes)-$($PartEtags.Count)"
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

function Get-HeaderValue($headers, [string] $name) {
    if ($null -eq $headers) {
        return ""
    }
    try {
        $values = $headers.GetValues($name)
        if ($values) {
            return [string]($values | Select-Object -First 1)
        }
    }
    catch {
    }
    try {
        $value = $headers[$name]
        if ($value -is [array]) {
            return [string]$value[0]
        }
        return [string]$value
    }
    catch {
        return ""
    }
}

function New-S3SigV4Headers($method, $url, [byte[]] $PayloadBytes, $accessKey, $secretKey, $hostOverride = $null, $payloadHashOverride = $null, $extraHeaders = $null) {
    $uri = [Uri] $url
    $hostHeader = if ($hostOverride) {
        $hostOverride
    } elseif ($uri.IsDefaultPort) {
        $uri.Host
    } else {
        "$($uri.Host):$($uri.Port)"
    }
    $amzDate = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")
    $date = $amzDate.Substring(0, 8)
    $payloadHash = if ($payloadHashOverride) { $payloadHashOverride } else { Get-Sha256Hex $PayloadBytes }
    $canonicalUri = $uri.AbsolutePath
    $canonicalQuery = Get-S3CanonicalQuery $uri
    $headerValues = @{}
    $headerValues["host"] = $hostHeader
    $headerValues["x-amz-content-sha256"] = $payloadHash
    $headerValues["x-amz-date"] = $amzDate
    if ($extraHeaders) {
        foreach ($entry in $extraHeaders.GetEnumerator()) {
            if ($null -ne $entry.Value) {
                $headerValues[$entry.Key.Trim().ToLowerInvariant()] = (([string]$entry.Value).Trim() -replace "\s+", " ")
            }
        }
    }
    $headerNames = $headerValues.Keys | Sort-Object
    $signedHeaders = $headerNames -join ";"
    $canonicalHeaders = ($headerNames | ForEach-Object { "$($_):$($headerValues[$_])`n" }) -join ""
    $canonicalRequest = "$method`n$canonicalUri`n$canonicalQuery`n$canonicalHeaders`n$signedHeaders`n$payloadHash"
    $scope = "$date/us-east-1/s3/aws4_request"
    $stringToSign = "AWS4-HMAC-SHA256`n$amzDate`n$scope`n$(Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($canonicalRequest)))"

    $dateKey = Get-HmacSha256 ([System.Text.Encoding]::UTF8.GetBytes("AWS4$secretKey")) $date
    $regionKey = Get-HmacSha256 $dateKey "us-east-1"
    $serviceKey = Get-HmacSha256 $regionKey "s3"
    $signingKey = Get-HmacSha256 $serviceKey "aws4_request"
    $signature = ((Get-HmacSha256 $signingKey $stringToSign | ForEach-Object { $_.ToString("x2") }) -join "")

    $headers = @{
        Authorization = "AWS4-HMAC-SHA256 Credential=$accessKey/$scope, SignedHeaders=$signedHeaders, Signature=$signature"
        "x-amz-date" = $amzDate
        "x-amz-content-sha256" = $payloadHash
    }
    if ($extraHeaders) {
        foreach ($entry in $extraHeaders.GetEnumerator()) {
            if ($null -ne $entry.Value) {
                $headers[$entry.Key] = [string]$entry.Value
            }
        }
    }
    return $headers
}

function Invoke-SignedHttp($method, $url, [byte[]] $PayloadBytes, $accessKey, $secretKey, $hostOverride = $null, $payloadHashOverride = $null, $contentType = "application/octet-stream", $extraHeaders = $null) {
    Add-Type -AssemblyName System.Net.Http

    $client = [System.Net.Http.HttpClient]::new()
    try {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($method), $url)
        $headers = New-S3SigV4Headers $method $url $PayloadBytes $accessKey $secretKey $hostOverride $payloadHashOverride $extraHeaders
        foreach ($entry in $headers.GetEnumerator()) {
            [void]$request.Headers.TryAddWithoutValidation($entry.Key, [string]$entry.Value)
        }
        if ($hostOverride) {
            $request.Headers.Host = $hostOverride
        }
        if ($PayloadBytes.Length -gt 0 -or $method -in @("PUT", "POST")) {
            $content = [System.Net.Http.ByteArrayContent]::new($PayloadBytes)
            $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($contentType)
            if ($extraHeaders) {
                foreach ($entry in $extraHeaders.GetEnumerator()) {
                    if ($entry.Key -ieq "Content-MD5" -and $null -ne $entry.Value) {
                        [void]$content.Headers.TryAddWithoutValidation("Content-MD5", [string]$entry.Value)
                    }
                }
            }
            $request.Content = $content
        }
        try {
            $response = $client.SendAsync(
                $request,
                [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
            ).GetAwaiter().GetResult()
        }
        catch {
            $signedHeaderNames = if ($extraHeaders) { ($extraHeaders.Keys | Sort-Object) -join "," } else { "" }
            throw "$method $url failed [$signedHeaderNames]: $($_.Exception.Message)"
        }
        try {
            $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
        catch {
            $contentLength = $response.Content.Headers.ContentLength
            throw "$method $url response body read failed: HTTP $([int]$response.StatusCode), Content-Length=$contentLength, $($_.Exception.Message)"
        }
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Body = $responseBody
            Headers = $response.Headers
        }
    }
    finally {
        $client.Dispose()
    }
}

function New-SmokeFile($directory, $name, $content) {
    $path = Join-Path $directory $name
    Set-Content -LiteralPath $path -Value $content -NoNewline -Encoding UTF8
    return $path
}

function Invoke-S3MultiDeleteMd5Smoke($s3Endpoint, $bucketName, $accessKey, $secretKey) {
    $deleteA = "manual-delete-md5-a.txt"
    $deleteB = "manual-delete-md5-b.txt"
    $protected = "manual-delete-md5-protected.txt"
    $emptyPayload = [byte[]]::new(0)

    foreach ($key in @($deleteA, $deleteB, $protected)) {
        $putResponse = Invoke-SignedHttp "PUT" "$s3Endpoint/$bucketName/$key" ([System.Text.Encoding]::UTF8.GetBytes($key)) $accessKey $secretKey $null $null "text/plain"
        if ($putResponse.StatusCode -ne 200) {
            throw "S3 multi-delete MD5 setup PUT failed for $key`: HTTP $($putResponse.StatusCode)."
        }
    }

    $deleteXml = @"
<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Quiet>true</Quiet>
  <Object><Key>$deleteA</Key></Object>
  <Object><Key>$deleteB</Key></Object>
  <Object><Key>manual-delete-md5-missing.txt</Key></Object>
  <Object><Key>.osmu/versions/manual-delete-md5-reserved.txt</Key></Object>
</Delete>
"@
    $deleteBytes = [System.Text.Encoding]::UTF8.GetBytes($deleteXml)
    $deleteResponse = Invoke-SignedHttp "POST" "$s3Endpoint/${bucketName}?delete" $deleteBytes $accessKey $secretKey $null $null "application/xml" @{
        "Content-MD5" = Get-Md5Base64 $deleteBytes
    }
    if ($deleteResponse.StatusCode -ne 200 `
            -or -not $deleteResponse.Body.Contains("<DeleteResult") `
            -or $deleteResponse.Body.Contains("<Deleted>") `
            -or -not $deleteResponse.Body.Contains("<Error>") `
            -or -not $deleteResponse.Body.Contains("<Code>InvalidRequest</Code>")) {
        throw "S3 multi-delete Quiet/Content-MD5 per-key error failed: HTTP $($deleteResponse.StatusCode) $($deleteResponse.Body)"
    }

    $deletedHead = Invoke-SignedHttp "HEAD" "$s3Endpoint/$bucketName/$deleteA" $emptyPayload $accessKey $secretKey
    if ($deletedHead.StatusCode -ne 404) {
        throw "S3 multi-delete did not delete $deleteA."
    }

    $badDeleteXml = @"
<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Object><Key>$protected</Key></Object>
</Delete>
"@
    $badDeleteBytes = [System.Text.Encoding]::UTF8.GetBytes($badDeleteXml)
    $badDeleteResponse = Invoke-SignedHttp "POST" "$s3Endpoint/${bucketName}?delete" $badDeleteBytes $accessKey $secretKey $null $null "application/xml" @{
        "Content-MD5" = Get-Md5Base64 ([System.Text.Encoding]::UTF8.GetBytes("different body"))
    }
    if ($badDeleteResponse.StatusCode -ne 400 -or -not $badDeleteResponse.Body.Contains("<Code>BadDigest</Code>")) {
        throw "S3 multi-delete mismatched Content-MD5 did not return BadDigest."
    }

    $protectedHead = Invoke-SignedHttp "HEAD" "$s3Endpoint/$bucketName/$protected" $emptyPayload $accessKey $secretKey
    if ($protectedHead.StatusCode -ne 200) {
        throw "S3 multi-delete mismatched Content-MD5 changed object state."
    }
}

function Invoke-S3BucketTaggingSmoke($s3Endpoint, $bucketName, $accessKey, $secretKey) {
    $taggingXml = @"
<Tagging xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <TagSet>
    <Tag><Key>project</Key><Value>osmu</Value></Tag>
    <Tag><Key>stage</Key><Value>smoke</Value></Tag>
  </TagSet>
</Tagging>
"@
    $taggingBytes = [System.Text.Encoding]::UTF8.GetBytes($taggingXml)
    $taggingUrl = "$s3Endpoint/${bucketName}?tagging"
    $putResponse = Invoke-SignedHttp "PUT" $taggingUrl $taggingBytes $accessKey $secretKey $null $null "application/xml"
    if ($putResponse.StatusCode -ne 200) {
        throw "S3 bucket tagging PUT failed: HTTP $($putResponse.StatusCode) $($putResponse.Body)"
    }
    $getResponse = Invoke-SignedHttp "GET" $taggingUrl ([byte[]]::new(0)) $accessKey $secretKey
    if ($getResponse.StatusCode -ne 200 -or -not $getResponse.Body.Contains("<Key>project</Key>") -or -not $getResponse.Body.Contains("<Value>osmu</Value>")) {
        throw "S3 bucket tagging GET failed: HTTP $($getResponse.StatusCode) $($getResponse.Body)"
    }
    $deleteResponse = Invoke-SignedHttp "DELETE" $taggingUrl ([byte[]]::new(0)) $accessKey $secretKey
    if ($deleteResponse.StatusCode -ne 204) {
        throw "S3 bucket tagging DELETE failed: HTTP $($deleteResponse.StatusCode) $($deleteResponse.Body)"
    }
    $emptyResponse = Invoke-SignedHttp "GET" $taggingUrl ([byte[]]::new(0)) $accessKey $secretKey
    if ($emptyResponse.StatusCode -ne 200 -or $emptyResponse.Body.Contains("<Key>project</Key>")) {
        throw "S3 bucket tagging DELETE did not clear tags: HTTP $($emptyResponse.StatusCode) $($emptyResponse.Body)"
    }
}

function Invoke-S3ObjectCompatibilitySmoke($s3Endpoint, $bucketName, $objectUrl, $accessKey, $secretKey, $etag) {
    $emptyPayload = [byte[]]::new(0)

    if (-not $etag) {
        throw "S3 object compatibility smoke requires an ETag."
    }

    $notModified = Invoke-SignedHttp "HEAD" $objectUrl $emptyPayload $accessKey $secretKey $null $null "application/octet-stream" @{
        "If-None-Match" = $etag
    }
    if ($notModified.StatusCode -ne 304) {
        throw "S3 conditional HEAD If-None-Match did not return 304."
    }

    $preconditionFailed = Invoke-SignedHttp "GET" $objectUrl $emptyPayload $accessKey $secretKey $null $null "application/octet-stream" @{
        "If-Match" = "`"different`""
    }
    if ($preconditionFailed.StatusCode -ne 412) {
        throw "S3 conditional GET If-Match did not return 412."
    }

    $rangeResponse = Invoke-SignedHttp "GET" $objectUrl $emptyPayload $accessKey $secretKey $null $null "application/octet-stream" @{
        "Range" = "bytes=5-10"
    }
    if ($rangeResponse.StatusCode -ne 206 -or $rangeResponse.Body -ne "manual") {
        throw "S3 Range GET failed: HTTP $($rangeResponse.StatusCode) $($rangeResponse.Body)"
    }

    $objectTaggingXml = @"
<Tagging xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <TagSet>
    <Tag><Key>project</Key><Value>osmu</Value></Tag>
    <Tag><Key>stage</Key><Value>sigv4</Value></Tag>
  </TagSet>
</Tagging>
"@
    $objectTaggingUrl = "${objectUrl}?tagging"
    $objectTaggingBytes = [System.Text.Encoding]::UTF8.GetBytes($objectTaggingXml)
    $taggingPut = Invoke-SignedHttp "PUT" $objectTaggingUrl $objectTaggingBytes $accessKey $secretKey $null $null "application/xml"
    if ($taggingPut.StatusCode -ne 200 -or (Get-HeaderValue $taggingPut.Headers "x-amz-tagging-count") -ne "2") {
        throw "S3 object tagging PUT failed: HTTP $($taggingPut.StatusCode) $($taggingPut.Body)"
    }

    $taggingGet = Invoke-SignedHttp "GET" $objectTaggingUrl $emptyPayload $accessKey $secretKey
    if ($taggingGet.StatusCode -ne 200 `
            -or -not $taggingGet.Body.Contains("<Key>project</Key>") `
            -or -not $taggingGet.Body.Contains("<Value>osmu</Value>")) {
        throw "S3 object tagging GET failed: HTTP $($taggingGet.StatusCode) $($taggingGet.Body)"
    }

    $copyKey = "manual-copy-sigv4-smoke.txt"
    $copyUrl = "$s3Endpoint/$bucketName/$copyKey"
    $copySource = "/$bucketName/manual-sigv4-smoke.txt"
    $copyResponse = Invoke-SignedHttp "PUT" $copyUrl $emptyPayload $accessKey $secretKey $null $null "application/octet-stream" @{
        "x-amz-copy-source" = $copySource
    }
    if ($copyResponse.StatusCode -ne 200 `
            -or -not $copyResponse.Body.Contains("<CopyObjectResult") `
            -or -not $copyResponse.Body.Contains("<ETag>")) {
        throw "S3 CopyObject failed: HTTP $($copyResponse.StatusCode) $($copyResponse.Body)"
    }

    $copiedObject = Invoke-SignedHttp "GET" $copyUrl $emptyPayload $accessKey $secretKey
    if ($copiedObject.StatusCode -ne 200 -or $copiedObject.Body -ne "osmu manual sigv4 smoke") {
        throw "S3 copied object GET body mismatch."
    }

    $copiedTags = Invoke-SignedHttp "GET" "${copyUrl}?tagging" $emptyPayload $accessKey $secretKey
    if ($copiedTags.StatusCode -ne 200 -or -not $copiedTags.Body.Contains("<Value>sigv4</Value>")) {
        throw "S3 CopyObject did not preserve source tags."
    }

    $badCopy = Invoke-SignedHttp "PUT" "$s3Endpoint/$bucketName/manual-copy-precondition-fail.txt" $emptyPayload $accessKey $secretKey $null $null "application/octet-stream" @{
        "x-amz-copy-source" = $copySource
        "x-amz-copy-source-if-match" = "`"different`""
    }
    if ($badCopy.StatusCode -ne 412 -or -not $badCopy.Body.Contains("<Code>PreconditionFailed</Code>")) {
        throw "S3 CopyObject source precondition did not fail as expected: HTTP $($badCopy.StatusCode) $($badCopy.Body)"
    }
}

function Invoke-S3MultipartChecksumSmoke($apiBase, $s3Endpoint, $bucketName, $accessKey, $secretKey) {
    $objectKey = "manual-multipart-checksum.bin"
    $part1 = [byte[]]::new(5 * 1024 * 1024)
    $part2 = [System.Text.Encoding]::UTF8.GetBytes("tail")
    $allBytes = [byte[]]::new($part1.Length + $part2.Length)
    [Array]::Copy($part1, 0, $allBytes, 0, $part1.Length)
    [Array]::Copy($part2, 0, $allBytes, $part1.Length, $part2.Length)
    $part1Checksum = Get-Sha256Base64 $part1
    $part2Checksum = Get-Sha256Base64 $part2
    $objectChecksum = Get-Sha256Base64 $allBytes

    $initiateUrl = "$s3Endpoint/$bucketName/${objectKey}?uploads"
    $initiateHeaders = @{
        "x-amz-meta-osmu-size-bytes" = [string]$allBytes.Length
        "x-amz-meta-osmu-part-size-bytes" = [string]$part1.Length
    }
    $initiate = Invoke-SignedHttp "POST" $initiateUrl ([byte[]]::new(0)) $accessKey $secretKey $null $null "application/octet-stream" $initiateHeaders
    if ($initiate.StatusCode -ne 200 -or $initiate.Body -notmatch "<UploadId>([^<]+)</UploadId>") {
        throw "S3 multipart checksum initiate failed: HTTP $($initiate.StatusCode) $($initiate.Body)"
    }
    $uploadId = $Matches[1]

    $part1Url = "$s3Endpoint/$bucketName/${objectKey}?partNumber=1&uploadId=$([System.Uri]::EscapeDataString($uploadId))"
    $part1Response = Invoke-SignedHttp "PUT" $part1Url $part1 $accessKey $secretKey $null $null "application/octet-stream" @{
        "x-amz-checksum-sha256" = $part1Checksum
    }
    $part1Etag = Get-HeaderValue $part1Response.Headers "ETag"
    if ($part1Response.StatusCode -ne 200 -or -not $part1Etag -or (Get-HeaderValue $part1Response.Headers "x-amz-checksum-sha256") -ne $part1Checksum) {
        throw "S3 multipart checksum part 1 upload failed: HTTP $($part1Response.StatusCode)."
    }

    $part2Url = "$s3Endpoint/$bucketName/${objectKey}?partNumber=2&uploadId=$([System.Uri]::EscapeDataString($uploadId))"
    $part2Response = Invoke-SignedHttp "PUT" $part2Url $part2 $accessKey $secretKey $null $null "application/octet-stream" @{
        "x-amz-checksum-sha256" = $part2Checksum
    }
    $part2Etag = Get-HeaderValue $part2Response.Headers "ETag"
    if ($part2Response.StatusCode -ne 200 -or -not $part2Etag -or (Get-HeaderValue $part2Response.Headers "x-amz-checksum-sha256") -ne $part2Checksum) {
        throw "S3 multipart checksum part 2 upload failed: HTTP $($part2Response.StatusCode)."
    }
    $expectedMultipartEtag = Get-S3MultipartEtag -PartEtags @($part1Etag, $part2Etag)

    $completeXml = @"
<CompleteMultipartUpload xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Part>
    <PartNumber>1</PartNumber>
    <ETag>$part1Etag</ETag>
    <ChecksumSHA256>$part1Checksum</ChecksumSHA256>
  </Part>
  <Part>
    <PartNumber>2</PartNumber>
    <ETag>$part2Etag</ETag>
    <ChecksumSHA256>$part2Checksum</ChecksumSHA256>
  </Part>
</CompleteMultipartUpload>
"@
    $completeBytes = [System.Text.Encoding]::UTF8.GetBytes($completeXml)
    $completeUrl = "$s3Endpoint/$bucketName/${objectKey}?uploadId=$([System.Uri]::EscapeDataString($uploadId))"
    $completeResponse = Invoke-SignedHttp "POST" $completeUrl $completeBytes $accessKey $secretKey $null $null "application/xml" @{
        "x-amz-checksum-sha256" = $objectChecksum
    }
    if ($completeResponse.StatusCode -ne 200 `
            -or (Get-HeaderValue $completeResponse.Headers "x-amz-checksum-sha256") -ne $objectChecksum `
            -or -not $completeResponse.Body.Contains("<ChecksumSHA256>$objectChecksum</ChecksumSHA256>")) {
        throw "S3 multipart checksum complete failed: HTTP $($completeResponse.StatusCode) $($completeResponse.Body)"
    }
    $completeEtag = Normalize-Etag (Get-HeaderValue $completeResponse.Headers "ETag")
    if ($completeEtag -ne $expectedMultipartEtag -or -not $completeResponse.Body.Contains("<ETag>`"$expectedMultipartEtag`"</ETag>")) {
        throw "S3 multipart complete ETag mismatch. expected=$expectedMultipartEtag actual=$completeEtag body=$($completeResponse.Body)"
    }

    $headResponse = Invoke-SignedHttp "HEAD" "$s3Endpoint/$bucketName/$objectKey" ([byte[]]::new(0)) $accessKey $secretKey
    $headEtag = Normalize-Etag (Get-HeaderValue $headResponse.Headers "ETag")
    if ($headResponse.StatusCode -ne 200 `
            -or (Get-HeaderValue $headResponse.Headers "x-amz-checksum-sha256") -ne $objectChecksum `
            -or $headEtag -ne $expectedMultipartEtag) {
        throw "S3 multipart checksum HEAD did not expose stored checksum and multipart ETag."
    }

    $sdkObjectKey = "manual-multipart-sdk-checksum.bin"
    $sdkInitiateUrl = "$s3Endpoint/$bucketName/${sdkObjectKey}?uploads"
    $sdkInitiateHeaders = @{
        "x-amz-meta-osmu-size-bytes" = [string]$allBytes.Length
        "x-amz-meta-osmu-part-size-bytes" = [string]$part1.Length
        "x-amz-checksum-algorithm" = "SHA256"
        "x-amz-checksum-type" = "COMPOSITE"
    }
    $sdkInitiate = Invoke-SignedHttp "POST" $sdkInitiateUrl ([byte[]]::new(0)) $accessKey $secretKey $null $null "application/octet-stream" $sdkInitiateHeaders
    if ($sdkInitiate.StatusCode -ne 200 -or $sdkInitiate.Body -notmatch "<UploadId>([^<]+)</UploadId>") {
        throw "S3 multipart SDK checksum initiate failed: HTTP $($sdkInitiate.StatusCode) $($sdkInitiate.Body)"
    }
    $sdkUploadId = $Matches[1]

    $sdkPart1Url = "$s3Endpoint/$bucketName/${sdkObjectKey}?partNumber=1&uploadId=$([System.Uri]::EscapeDataString($sdkUploadId))"
    $sdkPart1Response = Invoke-SignedHttp "PUT" $sdkPart1Url $part1 $accessKey $secretKey $null $null "application/octet-stream" @{
        "x-amz-sdk-checksum-algorithm" = "SHA256"
    }
    $sdkPart1Etag = Get-HeaderValue $sdkPart1Response.Headers "ETag"
    if ($sdkPart1Response.StatusCode -ne 200 -or -not $sdkPart1Etag -or (Get-HeaderValue $sdkPart1Response.Headers "x-amz-checksum-sha256") -ne $part1Checksum) {
        throw "S3 multipart SDK checksum part 1 upload failed: HTTP $($sdkPart1Response.StatusCode)."
    }

    $sdkPart2Url = "$s3Endpoint/$bucketName/${sdkObjectKey}?partNumber=2&uploadId=$([System.Uri]::EscapeDataString($sdkUploadId))"
    $sdkPart2Response = Invoke-SignedHttp "PUT" $sdkPart2Url $part2 $accessKey $secretKey $null $null "application/octet-stream" @{
        "x-amz-sdk-checksum-algorithm" = "SHA256"
    }
    $sdkPart2Etag = Get-HeaderValue $sdkPart2Response.Headers "ETag"
    if ($sdkPart2Response.StatusCode -ne 200 -or -not $sdkPart2Etag -or (Get-HeaderValue $sdkPart2Response.Headers "x-amz-checksum-sha256") -ne $part2Checksum) {
        throw "S3 multipart SDK checksum part 2 upload failed: HTTP $($sdkPart2Response.StatusCode)."
    }

    $listPartsResponse = Invoke-SignedHttp "GET" "$s3Endpoint/$bucketName/${sdkObjectKey}?uploadId=$([System.Uri]::EscapeDataString($sdkUploadId))" ([byte[]]::new(0)) $accessKey $secretKey
    if ($listPartsResponse.StatusCode -ne 200 `
            -or -not $listPartsResponse.Body.Contains("<ChecksumSHA256>$part1Checksum</ChecksumSHA256>") `
            -or -not $listPartsResponse.Body.Contains("<ChecksumSHA256>$part2Checksum</ChecksumSHA256>")) {
        throw "S3 multipart SDK checksum ListParts did not expose stored part checksums: HTTP $($listPartsResponse.StatusCode) $($listPartsResponse.Body)"
    }

    $sdkExpectedMultipartEtag = Get-S3MultipartEtag -PartEtags @($sdkPart1Etag, $sdkPart2Etag)
    $sdkCompositeChecksum = Get-CompositeSha256Base64 @($part1Checksum, $part2Checksum)
    $sdkCompleteXml = @"
<CompleteMultipartUpload xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Part>
    <PartNumber>1</PartNumber>
    <ETag>$sdkPart1Etag</ETag>
  </Part>
  <Part>
    <PartNumber>2</PartNumber>
    <ETag>$sdkPart2Etag</ETag>
  </Part>
</CompleteMultipartUpload>
"@
    $sdkCompleteBytes = [System.Text.Encoding]::UTF8.GetBytes($sdkCompleteXml)
    $sdkCompleteUrl = "$s3Endpoint/$bucketName/${sdkObjectKey}?uploadId=$([System.Uri]::EscapeDataString($sdkUploadId))"
    $sdkCompleteResponse = Invoke-SignedHttp "POST" $sdkCompleteUrl $sdkCompleteBytes $accessKey $secretKey $null $null "application/xml" @{
        "x-amz-checksum-type" = "COMPOSITE"
    }
    if ($sdkCompleteResponse.StatusCode -ne 200 `
            -or (Get-HeaderValue $sdkCompleteResponse.Headers "x-amz-checksum-sha256") -ne $sdkCompositeChecksum `
            -or -not $sdkCompleteResponse.Body.Contains("<ChecksumSHA256>$sdkCompositeChecksum</ChecksumSHA256>") `
            -or -not $sdkCompleteResponse.Body.Contains("<ChecksumType>COMPOSITE</ChecksumType>")) {
        throw "S3 multipart SDK checksum complete failed: HTTP $($sdkCompleteResponse.StatusCode) $($sdkCompleteResponse.Body)"
    }
    $sdkCompleteEtag = Normalize-Etag (Get-HeaderValue $sdkCompleteResponse.Headers "ETag")
    if ($sdkCompleteEtag -ne $sdkExpectedMultipartEtag -or -not $sdkCompleteResponse.Body.Contains("<ETag>`"$sdkExpectedMultipartEtag`"</ETag>")) {
        throw "S3 multipart SDK checksum complete ETag mismatch. expected=$sdkExpectedMultipartEtag actual=$sdkCompleteEtag body=$($sdkCompleteResponse.Body)"
    }

    $sdkHeadResponse = Invoke-SignedHttp "HEAD" "$s3Endpoint/$bucketName/$sdkObjectKey" ([byte[]]::new(0)) $accessKey $secretKey
    $sdkHeadEtag = Normalize-Etag (Get-HeaderValue $sdkHeadResponse.Headers "ETag")
    if ($sdkHeadResponse.StatusCode -ne 200 `
            -or (Get-HeaderValue $sdkHeadResponse.Headers "x-amz-checksum-sha256") -ne $sdkCompositeChecksum `
            -or $sdkHeadEtag -ne $sdkExpectedMultipartEtag) {
        throw "S3 multipart SDK checksum HEAD did not expose stored checksum and multipart ETag."
    }
}

function Invoke-ManualSigV4Smoke($apiBase, $s3Endpoint, $bucketName, $accessKey, $secretKey, $token, [bool] $includeVirtualHosted, [bool] $includeMultipartChecksum) {
    Step "Manual SigV4 compatibility smoke"
    $emptyPayload = [byte[]]::new(0)

    $headResponse = Invoke-SignedHttp "HEAD" $s3Endpoint $emptyPayload $accessKey $secretKey
    if ($headResponse.StatusCode -ne 200) {
        throw "SigV4 root HEAD failed: HTTP $($headResponse.StatusCode)."
    }

    $rootResponse = Invoke-SignedHttp "GET" $s3Endpoint $emptyPayload $accessKey $secretKey
    if ($rootResponse.StatusCode -ne 200 -or -not $rootResponse.Body.Contains("<Name>$bucketName</Name>")) {
        throw "SigV4 root bucket listing did not include $bucketName."
    }

    Invoke-S3BucketTaggingSmoke $s3Endpoint $bucketName $accessKey $secretKey

    $objectUrl = "$s3Endpoint/$bucketName/manual-sigv4-smoke.txt"
    $putBytes = [System.Text.Encoding]::UTF8.GetBytes("osmu manual sigv4 smoke")
    $putChecksum = Get-Sha256Base64 $putBytes
    $putResponse = Invoke-SignedHttp "PUT" $objectUrl $putBytes $accessKey $secretKey $null $null "text/plain" @{
        "x-amz-checksum-sha256" = $putChecksum
    }
    if ($putResponse.StatusCode -ne 200) {
        throw "SigV4 object PUT failed: HTTP $($putResponse.StatusCode) $($putResponse.Body)"
    }
    if ((Get-HeaderValue $putResponse.Headers "x-amz-checksum-sha256") -ne $putChecksum) {
        throw "SigV4 object PUT did not echo x-amz-checksum-sha256."
    }

    $getResponse = Invoke-SignedHttp "GET" $objectUrl $emptyPayload $accessKey $secretKey
    if ($getResponse.StatusCode -ne 200 -or $getResponse.Body -ne "osmu manual sigv4 smoke") {
        throw "SigV4 object GET body mismatch."
    }
    if ((Get-HeaderValue $getResponse.Headers "x-amz-checksum-sha256") -ne $putChecksum) {
        throw "SigV4 object GET did not expose stored checksum."
    }

    $objectHead = Invoke-SignedHttp "HEAD" $objectUrl $emptyPayload $accessKey $secretKey
    if ($objectHead.StatusCode -ne 200 -or (Get-HeaderValue $objectHead.Headers "x-amz-checksum-sha256") -ne $putChecksum) {
        throw "SigV4 object HEAD did not expose stored checksum."
    }
    $objectEtag = Get-HeaderValue $objectHead.Headers "ETag"

    Invoke-S3ObjectCompatibilitySmoke $s3Endpoint $bucketName $objectUrl $accessKey $secretKey $objectEtag

    Invoke-Json "POST" "$apiBase/buckets/$bucketName/sync" $null $token | Out-Null
    $objectHeadAfterSync = Invoke-SignedHttp "HEAD" $objectUrl $emptyPayload $accessKey $secretKey
    if ($objectHeadAfterSync.StatusCode -ne 200 -or (Get-HeaderValue $objectHeadAfterSync.Headers "x-amz-checksum-sha256") -ne $putChecksum) {
        throw "SigV4 object HEAD did not preserve checksum after bucket sync."
    }

    $badPayloadHash = Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes("different body"))
    $badResponse = Invoke-SignedHttp "PUT" "$s3Endpoint/$bucketName/manual-bad-payload.txt" $putBytes $accessKey $secretKey $null $badPayloadHash "text/plain"
    if ($badResponse.StatusCode -ne 400 -or -not $badResponse.Body.Contains("<Code>BadDigest</Code>")) {
        throw "SigV4 mismatched payload hash did not return BadDigest."
    }

    $badChecksum = Get-Sha256Base64 ([System.Text.Encoding]::UTF8.GetBytes("different body"))
    $badChecksumResponse = Invoke-SignedHttp `
        "PUT" `
        "$s3Endpoint/$bucketName/manual-bad-checksum.txt" `
        $putBytes `
        $accessKey `
        $secretKey `
        $null `
        $null `
        "text/plain" `
        @{
            "x-amz-checksum-sha256" = $badChecksum
        }
    if ($badChecksumResponse.StatusCode -ne 400 -or -not $badChecksumResponse.Body.Contains("<Code>BadDigest</Code>")) {
        throw "SigV4 mismatched checksum did not return BadDigest."
    }

    if ($includeVirtualHosted) {
        $endpoint = [Uri] $s3Endpoint
        $hostOverride = if ($endpoint.IsDefaultPort) { "$bucketName.localhost" } else { "$bucketName.localhost:$($endpoint.Port)" }
        $vhostPathPrefix = if ($endpoint.AbsolutePath -eq "/") { "" } else { $endpoint.AbsolutePath.TrimEnd("/") }
        $vhostUrl = "$($endpoint.Scheme)://$($endpoint.Authority)$vhostPathPrefix/manual-vhost-smoke.txt"
        $vhostBytes = [System.Text.Encoding]::UTF8.GetBytes("osmu virtual hosted smoke")
        $vhostPut = Invoke-SignedHttp "PUT" $vhostUrl $vhostBytes $accessKey $secretKey $hostOverride $null "text/plain"
        if ($vhostPut.StatusCode -ne 200) {
            throw "Virtual-hosted SigV4 object PUT failed: HTTP $($vhostPut.StatusCode) $($vhostPut.Body)"
        }
        $vhostGet = Invoke-SignedHttp "GET" $vhostUrl $emptyPayload $accessKey $secretKey $hostOverride
        if ($vhostGet.StatusCode -ne 200 -or $vhostGet.Body -ne "osmu virtual hosted smoke") {
            throw "Virtual-hosted SigV4 object GET body mismatch."
        }
    }

    if ($includeMultipartChecksum) {
        Invoke-S3MultipartChecksumSmoke $apiBase $s3Endpoint $bucketName $accessKey $secretKey
    } else {
        Write-Warning "Skipping multipart checksum smoke because this backend is running without MinIO multipart support."
    }
    Invoke-S3MultiDeleteMd5Smoke $s3Endpoint $bucketName $accessKey $secretKey
}

function Invoke-AwsCliSmoke($apiBase, $s3Endpoint, $bucketName, $accessKey, $secretKey) {
    $aws = Get-Command aws -ErrorAction SilentlyContinue
    if (-not $aws) {
        return $false
    }

    Step "AWS CLI S3 client smoke"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "osmu-aws-smoke-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    $previousAccessKey = $env:AWS_ACCESS_KEY_ID
    $previousSecretKey = $env:AWS_SECRET_ACCESS_KEY
    $previousRegion = $env:AWS_DEFAULT_REGION
    $previousMetadata = $env:AWS_EC2_METADATA_DISABLED
    try {
        $env:AWS_ACCESS_KEY_ID = $accessKey
        $env:AWS_SECRET_ACCESS_KEY = $secretKey
        $env:AWS_DEFAULT_REGION = "us-east-1"
        $env:AWS_EC2_METADATA_DISABLED = "true"

        $listBucketsJson = Invoke-ExternalText $aws.Source @("--endpoint-url", $s3Endpoint, "s3api", "list-buckets", "--output", "json")
        $listBuckets = $listBucketsJson | ConvertFrom-Json
        if (-not ($listBuckets.Buckets | Where-Object { $_.Name -eq $bucketName })) {
            throw "AWS CLI list-buckets did not include $bucketName."
        }

        $bodyPath = New-SmokeFile $tempDir "aws-cli-smoke.txt" "osmu aws cli smoke"
        Invoke-External $aws.Source @(
            "--endpoint-url", $s3Endpoint,
            "s3api", "put-object",
            "--bucket", $bucketName,
            "--key", "aws-cli-smoke.txt",
            "--body", $bodyPath,
            "--content-md5", (Get-ContentMd5Base64 $bodyPath),
            "--content-type", "text/plain",
            "--output", "json"
        ) | Out-Null

        Invoke-External $aws.Source @("--endpoint-url", $s3Endpoint, "s3api", "head-object", "--bucket", $bucketName, "--key", "aws-cli-smoke.txt", "--output", "json") | Out-Null

        $checksumBodyPath = New-SmokeFile $tempDir "aws-cli-checksum-smoke.txt" "osmu aws cli checksum smoke"
        $checksumValue = Get-Sha256Base64 ([System.IO.File]::ReadAllBytes($checksumBodyPath))
        $checksumPutJson = Invoke-ExternalText $aws.Source @(
            "--endpoint-url", $s3Endpoint,
            "s3api", "put-object",
            "--bucket", $bucketName,
            "--key", "aws-cli-checksum-smoke.txt",
            "--body", $checksumBodyPath,
            "--checksum-algorithm", "SHA256",
            "--content-type", "text/plain",
            "--output", "json"
        )
        $checksumPut = $checksumPutJson | ConvertFrom-Json
        if ($checksumPut.ChecksumSHA256 -and $checksumPut.ChecksumSHA256 -ne $checksumValue) {
            throw "AWS CLI checksum put-object returned unexpected ChecksumSHA256."
        }
        $checksumHeadJson = Invoke-ExternalText $aws.Source @("--endpoint-url", $s3Endpoint, "s3api", "head-object", "--bucket", $bucketName, "--key", "aws-cli-checksum-smoke.txt", "--output", "json")
        $checksumHead = $checksumHeadJson | ConvertFrom-Json
        if ($checksumHead.ChecksumSHA256 -ne $checksumValue) {
            throw "AWS CLI checksum head-object did not expose stored ChecksumSHA256."
        }

        $objectsJson = Invoke-ExternalText $aws.Source @(
            "--endpoint-url", $s3Endpoint,
            "s3api", "list-objects-v2",
            "--bucket", $bucketName,
            "--max-keys", "1000",
            "--fetch-owner",
            "--encoding-type", "url",
            "--output", "json"
        )
        $objects = $objectsJson | ConvertFrom-Json
        if (-not ($objects.Contents | Where-Object { $_.Key -eq "aws-cli-smoke.txt" })) {
            throw "AWS CLI list-objects-v2 did not include aws-cli-smoke.txt."
        }
        if (-not ($objects.Contents | Where-Object { $_.Key -eq "aws-cli-checksum-smoke.txt" })) {
            throw "AWS CLI list-objects-v2 did not include aws-cli-checksum-smoke.txt."
        }

        $downloadPath = Join-Path $tempDir "aws-cli-download.txt"
        Invoke-External $aws.Source @("--endpoint-url", $s3Endpoint, "s3api", "get-object", "--bucket", $bucketName, "--key", "aws-cli-smoke.txt", $downloadPath, "--output", "json") | Out-Null
        if ((Get-Content -Raw -LiteralPath $downloadPath) -ne "osmu aws cli smoke") {
            throw "AWS CLI get-object body mismatch."
        }
        $checksumDownloadPath = Join-Path $tempDir "aws-cli-checksum-download.txt"
        $checksumGetJson = Invoke-ExternalText $aws.Source @("--endpoint-url", $s3Endpoint, "s3api", "get-object", "--bucket", $bucketName, "--key", "aws-cli-checksum-smoke.txt", $checksumDownloadPath, "--output", "json")
        $checksumGet = $checksumGetJson | ConvertFrom-Json
        if ((Get-Content -Raw -LiteralPath $checksumDownloadPath) -ne "osmu aws cli checksum smoke") {
            throw "AWS CLI checksum get-object body mismatch."
        }
        if ($checksumGet.ChecksumSHA256 -ne $checksumValue) {
            throw "AWS CLI checksum get-object did not expose stored ChecksumSHA256."
        }

        Invoke-External $aws.Source @("--endpoint-url", $s3Endpoint, "s3api", "delete-object", "--bucket", $bucketName, "--key", "aws-cli-smoke.txt", "--output", "json") | Out-Null
        Invoke-External $aws.Source @("--endpoint-url", $s3Endpoint, "s3api", "delete-object", "--bucket", $bucketName, "--key", "aws-cli-checksum-smoke.txt", "--output", "json") | Out-Null
        return $true
    }
    finally {
        $env:AWS_ACCESS_KEY_ID = $previousAccessKey
        $env:AWS_SECRET_ACCESS_KEY = $previousSecretKey
        $env:AWS_DEFAULT_REGION = $previousRegion
        $env:AWS_EC2_METADATA_DISABLED = $previousMetadata
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
    }
}

function Get-PythonWithBoto3() {
    foreach ($candidate in @("python", "python3", "py")) {
        $python = Get-Command $candidate -ErrorAction SilentlyContinue
        if (-not $python) {
            continue
        }
        $arguments = if ($candidate -eq "py") {
            @("-3", "-c", "import boto3, botocore")
        } else {
            @("-c", "import boto3, botocore")
        }
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & $python.Source @arguments *> $null
            if ($LASTEXITCODE -eq 0) {
                $prefix = if ($candidate -eq "py") { @("-3") } else { @() }
                return [pscustomobject]@{
                    Source = $python.Source
                    Prefix = $prefix
                }
            }
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }
    return $null
}

function Invoke-Boto3Smoke($apiBase, $s3Endpoint, $bucketName, $accessKey, $secretKey) {
    $python = Get-PythonWithBoto3
    if (-not $python) {
        return $false
    }

    Step "boto3 S3 SDK smoke"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "osmu-boto3-smoke-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    try {
        $scriptPath = Join-Path $tempDir "boto3-smoke.py"
        Set-Content -LiteralPath $scriptPath -Encoding UTF8 -Value @'
import base64
import hashlib
import json
import sys

import boto3
from botocore.config import Config

endpoint, bucket, access_key, secret_key = sys.argv[1:5]
key = "boto3-checksum-smoke.txt"
body = b"osmu boto3 checksum smoke"
expected = base64.b64encode(hashlib.sha256(body).digest()).decode("ascii")

s3 = boto3.client(
    "s3",
    endpoint_url=endpoint,
    aws_access_key_id=access_key,
    aws_secret_access_key=secret_key,
    region_name="us-east-1",
    config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
)

buckets = s3.list_buckets().get("Buckets", [])
if not any(item.get("Name") == bucket for item in buckets):
    raise SystemExit(f"boto3 list_buckets did not include {bucket}.")

put_result = s3.put_object(
    Bucket=bucket,
    Key=key,
    Body=body,
    ContentType="text/plain",
    ChecksumAlgorithm="SHA256",
)
put_checksum = put_result.get("ChecksumSHA256")
if put_checksum and put_checksum != expected:
    raise SystemExit("boto3 put_object returned unexpected ChecksumSHA256.")

head_result = s3.head_object(Bucket=bucket, Key=key, ChecksumMode="ENABLED")
if head_result.get("ChecksumSHA256") != expected:
    raise SystemExit("boto3 head_object did not expose stored ChecksumSHA256.")

listed = s3.list_objects_v2(Bucket=bucket, MaxKeys=1000, EncodingType="url")
if not any(item.get("Key") == key for item in listed.get("Contents", [])):
    raise SystemExit("boto3 list_objects_v2 did not include checksum object.")

get_result = s3.get_object(Bucket=bucket, Key=key, ChecksumMode="ENABLED")
try:
    if get_result["Body"].read() != body:
        raise SystemExit("boto3 get_object body mismatch.")
finally:
    get_result["Body"].close()
if get_result.get("ChecksumSHA256") != expected:
    raise SystemExit("boto3 get_object did not expose stored ChecksumSHA256.")

s3.delete_object(Bucket=bucket, Key=key)
print(json.dumps({"ChecksumSHA256": expected}))
'@
        $arguments = @()
        if ($python.Prefix) {
            $arguments += $python.Prefix
        }
        $arguments += @($scriptPath, $s3Endpoint, $bucketName, $accessKey, $secretKey)
        $result = Invoke-ExternalText $python.Source $arguments
        $parsed = $result | ConvertFrom-Json
        if (-not $parsed.ChecksumSHA256) {
            throw "boto3 checksum smoke did not return checksum evidence."
        }
        return $true
    }
    finally {
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
    }
}

function Get-NodeWithAwsSdkS3() {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        return $null
    }

    foreach ($moduleRoot in @($root, (Join-Path $root "osmu-frontend"))) {
        if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot "node_modules\@aws-sdk\client-s3\package.json"))) {
            continue
        }

        Push-Location $moduleRoot
        try {
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                & $node.Source "--input-type=module" "-e" "import('@aws-sdk/client-s3').then(() => process.exit(0)).catch(() => process.exit(1));" *> $null
                if ($LASTEXITCODE -eq 0) {
                    return [pscustomobject]@{
                        Source = $node.Source
                        ModuleRoot = $moduleRoot
                    }
                }
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }
        }
        finally {
            Pop-Location
        }
    }

    return $null
}

function Invoke-AwsJsSdkSmoke($apiBase, $s3Endpoint, $bucketName, $accessKey, $secretKey) {
    $nodeSdk = Get-NodeWithAwsSdkS3
    if (-not $nodeSdk) {
        return $false
    }

    Step "AWS SDK JavaScript S3 smoke"
    $tempDir = Join-Path $nodeSdk.ModuleRoot ".osmu-run\aws-js-s3-smoke-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    try {
        $scriptPath = Join-Path $tempDir "aws-js-s3-smoke.mjs"
        Set-Content -LiteralPath $scriptPath -Encoding UTF8 -Value @'
import crypto from "node:crypto";
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  ListBucketsCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";

const [endpoint, bucket, accessKey, secretKey] = process.argv.slice(2);
const key = "aws-js-checksum-smoke.txt";
const body = Buffer.from("osmu aws sdk js checksum smoke", "utf8");
const expected = crypto.createHash("sha256").update(body).digest("base64");

const client = new S3Client({
  endpoint,
  region: "us-east-1",
  forcePathStyle: true,
  credentials: {
    accessKeyId: accessKey,
    secretAccessKey: secretKey,
  },
});

const buckets = await client.send(new ListBucketsCommand({}));
if (!buckets.Buckets?.some((item) => item.Name === bucket)) {
  throw new Error(`AWS SDK JS list_buckets did not include ${bucket}.`);
}

const putResult = await client.send(new PutObjectCommand({
  Bucket: bucket,
  Key: key,
  Body: body,
  ContentType: "text/plain",
  ChecksumAlgorithm: "SHA256",
}));
if (putResult.ChecksumSHA256 && putResult.ChecksumSHA256 !== expected) {
  throw new Error("AWS SDK JS putObject returned unexpected ChecksumSHA256.");
}

const headResult = await client.send(new HeadObjectCommand({
  Bucket: bucket,
  Key: key,
  ChecksumMode: "ENABLED",
}));
if (headResult.ChecksumSHA256 !== expected) {
  throw new Error("AWS SDK JS headObject did not expose stored ChecksumSHA256.");
}

const listed = await client.send(new ListObjectsV2Command({
  Bucket: bucket,
  MaxKeys: 1000,
  EncodingType: "url",
}));
if (!listed.Contents?.some((item) => item.Key === key)) {
  throw new Error("AWS SDK JS listObjectsV2 did not include checksum object.");
}

const getResult = await client.send(new GetObjectCommand({
  Bucket: bucket,
  Key: key,
  ChecksumMode: "ENABLED",
}));
const chunks = [];
for await (const chunk of getResult.Body) {
  chunks.push(Buffer.from(chunk));
}
if (!Buffer.concat(chunks).equals(body)) {
  throw new Error("AWS SDK JS getObject body mismatch.");
}
if (getResult.ChecksumSHA256 !== expected) {
  throw new Error("AWS SDK JS getObject did not expose stored ChecksumSHA256.");
}

await client.send(new DeleteObjectCommand({
  Bucket: bucket,
  Key: key,
}));
console.log(JSON.stringify({ ChecksumSHA256: expected }));
'@
        $result = Invoke-ExternalText $nodeSdk.Source @($scriptPath, $s3Endpoint, $bucketName, $accessKey, $secretKey)
        $parsed = $result | ConvertFrom-Json
        if (-not $parsed.ChecksumSHA256) {
            throw "AWS SDK JavaScript checksum smoke did not return checksum evidence."
        }
        return $true
    }
    finally {
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
    }
}

function Get-JavaWithAwsSdkS3() {
    $classpath = $env:OSMU_AWS_SDK_JAVA_CLASSPATH
    if ([string]::IsNullOrWhiteSpace($classpath)) {
        return $null
    }

    $java = Get-Command java -ErrorAction SilentlyContinue
    $javac = Get-Command javac -ErrorAction SilentlyContinue
    if (-not $java -or -not $javac) {
        return $null
    }

    return [pscustomobject]@{
        Java = $java.Source
        Javac = $javac.Source
        Classpath = $classpath
    }
}

function Invoke-AwsJavaSdkSmoke($apiBase, $s3Endpoint, $bucketName, $accessKey, $secretKey) {
    $javaSdk = Get-JavaWithAwsSdkS3
    if (-not $javaSdk) {
        return $false
    }

    Step "AWS SDK Java S3 smoke"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "osmu-aws-java-s3-smoke-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    try {
        $sourcePath = Join-Path $tempDir "OsmuAwsSdkJavaChecksumSmoke.java"
        Set-Content -LiteralPath $sourcePath -Encoding UTF8 -Value @'
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Base64;

import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.ChecksumAlgorithm;
import software.amazon.awssdk.services.s3.model.ChecksumMode;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

public final class OsmuAwsSdkJavaChecksumSmoke {
    private OsmuAwsSdkJavaChecksumSmoke() {
    }

    public static void main(String[] args) throws Exception {
        String endpoint = args[0];
        String bucket = args[1];
        String accessKey = args[2];
        String secretKey = args[3];
        String key = "aws-java-checksum-smoke.txt";
        byte[] body = "osmu aws sdk java checksum smoke".getBytes(StandardCharsets.UTF_8);
        String expected = Base64.getEncoder().encodeToString(MessageDigest.getInstance("SHA-256").digest(body));

        try (S3Client client = S3Client.builder()
            .endpointOverride(URI.create(endpoint))
            .region(Region.US_EAST_1)
            .credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create(accessKey, secretKey)))
            .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build())
            .build()) {

            boolean bucketListed = client.listBuckets().buckets().stream()
                .anyMatch(item -> bucket.equals(item.name()));
            if (!bucketListed) {
                throw new IllegalStateException("AWS SDK Java listBuckets did not include " + bucket + ".");
            }

            String putChecksum = client.putObject(PutObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .contentType("text/plain")
                    .checksumAlgorithm(ChecksumAlgorithm.SHA256)
                    .build(),
                RequestBody.fromBytes(body))
                .checksumSHA256();
            if (putChecksum != null && !expected.equals(putChecksum)) {
                throw new IllegalStateException("AWS SDK Java putObject returned unexpected ChecksumSHA256.");
            }

            String headChecksum = client.headObject(HeadObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .checksumMode(ChecksumMode.ENABLED)
                    .build())
                .checksumSHA256();
            if (!expected.equals(headChecksum)) {
                throw new IllegalStateException("AWS SDK Java headObject did not expose stored ChecksumSHA256.");
            }

            boolean objectListed = client.listObjectsV2(ListObjectsV2Request.builder()
                    .bucket(bucket)
                    .maxKeys(1000)
                    .build())
                .contents()
                .stream()
                .anyMatch(item -> key.equals(item.key()));
            if (!objectListed) {
                throw new IllegalStateException("AWS SDK Java listObjectsV2 did not include checksum object.");
            }

            ResponseBytes<GetObjectResponse> getResult = client.getObjectAsBytes(GetObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .checksumMode(ChecksumMode.ENABLED)
                .build());
            if (!Arrays.equals(body, getResult.asByteArray())) {
                throw new IllegalStateException("AWS SDK Java getObject body mismatch.");
            }
            if (!expected.equals(getResult.response().checksumSHA256())) {
                throw new IllegalStateException("AWS SDK Java getObject did not expose stored ChecksumSHA256.");
            }

            client.deleteObject(DeleteObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build());
        }

        System.out.println("{\"ChecksumSHA256\":\"" + expected + "\"}");
    }
}
'@
        Invoke-External $javaSdk.Javac @("-cp", $javaSdk.Classpath, $sourcePath) | Out-Null
        $runtimeClasspath = "$tempDir$([System.IO.Path]::PathSeparator)$($javaSdk.Classpath)"
        $result = Invoke-ExternalText $javaSdk.Java @("-cp", $runtimeClasspath, "OsmuAwsSdkJavaChecksumSmoke", $s3Endpoint, $bucketName, $accessKey, $secretKey)
        $parsed = $result | ConvertFrom-Json
        if (-not $parsed.ChecksumSHA256) {
            throw "AWS SDK Java checksum smoke did not return checksum evidence."
        }
        return $true
    }
    finally {
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
    }
}

function Invoke-McSmoke($apiBase, $s3Endpoint, $bucketName, $accessKey, $secretKey) {
    $mc = Get-Command mc -ErrorAction SilentlyContinue
    if (-not $mc) {
        return $false
    }

    Step "MinIO Client smoke"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "osmu-mc-smoke-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    $previousConfigDir = $env:MC_CONFIG_DIR
    try {
        $env:MC_CONFIG_DIR = $tempDir
        $alias = "osmu-smoke"
        try {
            Invoke-External $mc.Source @("alias", "set", $alias, $s3Endpoint, $accessKey, $secretKey, "--api", "S3v4", "--path", "on") | Out-Null
        }
        catch {
            Invoke-External $mc.Source @("alias", "set", $alias, $s3Endpoint, $accessKey, $secretKey, "--api", "S3v4") | Out-Null
        }

        $bucketList = Invoke-ExternalText $mc.Source @("ls", $alias)
        $bucketNamePattern = "(^|\s)$([regex]::Escape($bucketName))/?(\s|$)"
        if ($bucketList -notmatch $bucketNamePattern) {
            throw "MinIO Client root bucket listing did not include $bucketName."
        }
        Invoke-External $mc.Source @("ls", "$alias/$bucketName") | Out-Null

        $bodyPath = New-SmokeFile $tempDir "mc-smoke.txt" "osmu mc smoke"
        Invoke-External $mc.Source @("cp", $bodyPath, "$alias/$bucketName/mc-smoke.txt") | Out-Null
        Invoke-External $mc.Source @("stat", "$alias/$bucketName/mc-smoke.txt") | Out-Null
        $body = Invoke-ExternalText $mc.Source @("cat", "$alias/$bucketName/mc-smoke.txt")
        if ($body -ne "osmu mc smoke") {
            throw "mc cat body mismatch."
        }
        Invoke-External $mc.Source @("rm", "$alias/$bucketName/mc-smoke.txt") | Out-Null
        return $true
    }
    finally {
        $env:MC_CONFIG_DIR = $previousConfigDir
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
    }
}

function Test-DockerDaemonForClient() {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        return $false
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $docker.Source info --format "{{json .ServerVersion}}" *> $null
        return $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Convert-S3EndpointForDockerClient([string] $Endpoint) {
    $uri = [Uri] $Endpoint
    if ($uri.Host -in @("localhost", "127.0.0.1", "::1")) {
        $builder = [System.UriBuilder]::new($uri)
        $builder.Host = "host.docker.internal"
        return $builder.Uri.AbsoluteUri.TrimEnd("/")
    }
    return $Endpoint.TrimEnd("/")
}

function Invoke-DockerCommand([string[]] $Arguments, [switch] $ReturnText) {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        throw "Docker CLI not found on PATH."
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $docker.Source @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        if ($output -and -not $ReturnText) {
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -ne 0) {
            if ($output) {
                $output | ForEach-Object { Write-Host $_ }
            }
            throw "Command failed ($exitCode): docker $($Arguments -join ' ')"
        }
        if ($ReturnText) {
            return ($output -join [Environment]::NewLine)
        }
        return $output
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Invoke-DockerMc($tempDir, [string[]] $McArguments, [switch] $ReturnText) {
    $volume = "$($tempDir):/work"
    $arguments = @(
        "run",
        "--rm",
        "-e", "MC_CONFIG_DIR=/work/.mc",
        "-v", $volume,
        $DockerMcImage
    ) + $McArguments

    return Invoke-DockerCommand $arguments -ReturnText:$ReturnText
}

function Invoke-DockerizedMcSmoke($apiBase, $s3Endpoint, $bucketName, $accessKey, $secretKey) {
    if (-not (Test-DockerDaemonForClient)) {
        return $false
    }

    Step "Dockerized MinIO Client smoke"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "osmu-docker-mc-smoke-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    try {
        $alias = "osmu-smoke"
        $dockerS3Endpoint = Convert-S3EndpointForDockerClient $s3Endpoint
        try {
            Invoke-DockerMc $tempDir @("alias", "set", $alias, $dockerS3Endpoint, $accessKey, $secretKey, "--api", "S3v4", "--path", "on") | Out-Null
        }
        catch {
            Invoke-DockerMc $tempDir @("alias", "set", $alias, $dockerS3Endpoint, $accessKey, $secretKey, "--api", "S3v4") | Out-Null
        }

        $bucketList = Invoke-DockerMc $tempDir @("ls", $alias) -ReturnText
        $bucketNamePattern = "(^|\s)$([regex]::Escape($bucketName))/?(\s|$)"
        if ($bucketList -notmatch $bucketNamePattern) {
            throw "Dockerized MinIO Client root bucket listing did not include $bucketName."
        }
        Invoke-DockerMc $tempDir @("ls", "$alias/$bucketName") | Out-Null

        $bodyPath = New-SmokeFile $tempDir "docker-mc-smoke.txt" "osmu docker mc smoke"
        Invoke-DockerMc $tempDir @("cp", "/work/$(Split-Path -Leaf $bodyPath)", "$alias/$bucketName/docker-mc-smoke.txt") | Out-Null
        Invoke-DockerMc $tempDir @("stat", "$alias/$bucketName/docker-mc-smoke.txt") | Out-Null
        $body = Invoke-DockerMc $tempDir @("cat", "$alias/$bucketName/docker-mc-smoke.txt") -ReturnText
        if ($body -ne "osmu docker mc smoke") {
            throw "dockerized mc cat body mismatch."
        }
        Invoke-DockerMc $tempDir @("rm", "$alias/$bucketName/docker-mc-smoke.txt") | Out-Null
        return $true
    }
    finally {
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
    }
}

Step "Backend health"
Invoke-Json "GET" "$ApiBase/health" | Out-Null
$storageHealth = Invoke-Json "GET" "$ApiBase/storage/health"
$storageEngine = [string]$storageHealth.data.engine
$includeMultipartChecksum = -not $SkipMultipartChecksumSmoke -and $storageEngine -notlike "*in-memory*"

Step "Auth login"
$login = Invoke-Json "POST" "$ApiBase/auth/login" @{
    loginId = $AdminLoginId
    password = $AdminPassword
}
$token = $login.data.accessToken
if (-not $token) {
    throw "Login did not return accessToken."
}

$createdBucket = $false
try {
    Step "Bucket create"
    Invoke-Json "POST" "$ApiBase/buckets" @{
        name = $BucketName
        quotaBytes = 33554432
    } $token | Out-Null
    $createdBucket = $true

    Step "Access key create"
    $createdKey = Invoke-Json "POST" "$ApiBase/access-keys" @{
        name = "s3-client-smoke"
        bucketScopes = @(
            @{
                bucketName = $BucketName
                permissions = @("ADMIN")
            }
        )
        expiresAt = $null
    } $token
    $accessKey = $createdKey.data.accessKey
    $secretKey = $createdKey.data.secretKey
    if (-not $accessKey -or -not $secretKey) {
        throw "Access key creation did not return accessKey and secretKey."
    }

    if (-not $SkipManualSigV4) {
        Invoke-ManualSigV4Smoke $ApiBase $S3Endpoint $BucketName $accessKey $secretKey $token (-not $SkipVirtualHostedSmoke) $includeMultipartChecksum
    }

    $ranClients = New-Object System.Collections.Generic.List[string]
    if ($Client -in @("auto", "aws", "all")) {
        if (Invoke-AwsCliSmoke $ApiBase $S3Endpoint $BucketName $accessKey $secretKey) {
            $ranClients.Add("aws")
        } elseif ($Client -eq "aws") {
            throw "AWS CLI not found on PATH."
        }
    }
    if ($Client -in @("auto", "boto3", "all")) {
        if (Invoke-Boto3Smoke $ApiBase $S3Endpoint $BucketName $accessKey $secretKey) {
            $ranClients.Add("boto3")
        } elseif ($Client -eq "boto3") {
            throw "Python with boto3 is not available on PATH."
        }
    }
    if ($Client -in @("auto", "aws-js", "all")) {
        if (Invoke-AwsJsSdkSmoke $ApiBase $S3Endpoint $BucketName $accessKey $secretKey) {
            $ranClients.Add("aws-js")
        } elseif ($Client -eq "aws-js") {
            throw "Node.js with @aws-sdk/client-s3 is not available in repo node_modules."
        }
    }
    if ($Client -in @("auto", "aws-java", "all")) {
        if (Invoke-AwsJavaSdkSmoke $ApiBase $S3Endpoint $BucketName $accessKey $secretKey) {
            $ranClients.Add("aws-java")
        } elseif ($Client -eq "aws-java") {
            throw "Java with AWS SDK Java v2 is not available. Set OSMU_AWS_SDK_JAVA_CLASSPATH to the SDK v2 classpath and ensure java+javac are on PATH."
        }
    }
    if ($Client -in @("auto", "mc", "all")) {
        if (Invoke-McSmoke $ApiBase $S3Endpoint $BucketName $accessKey $secretKey) {
            $ranClients.Add("mc")
        } elseif ($Client -eq "mc") {
            throw "MinIO Client mc not found on PATH."
        }
    }
    if ($Client -in @("auto", "docker-mc", "all")) {
        if (Invoke-DockerizedMcSmoke $ApiBase $S3Endpoint $BucketName $accessKey $secretKey) {
            $ranClients.Add("docker-mc")
        } elseif ($Client -eq "docker-mc") {
            throw "Docker daemon is not available for Dockerized MinIO Client smoke."
        }
    }

    if ($ranClients.Count -eq 0) {
        $message = "No real S3 client found. Install AWS CLI (aws), install Python+boto3, install Node.js with @aws-sdk/client-s3 in repo node_modules, set OSMU_AWS_SDK_JAVA_CLASSPATH for AWS SDK Java v2, install MinIO Client (mc), or start Docker Desktop for Dockerized MinIO Client smoke."
        if ($RequireClient) {
            throw $message
        }
        Write-Warning $message
    } else {
        Step "S3 client smoke passed: $($ranClients -join ', ')"
    }
}
finally {
    if ($createdBucket -and -not $KeepBucket) {
        Step "Cleanup smoke data"
        foreach ($key in @("aws-cli-smoke.txt", "aws-cli-checksum-smoke.txt", "boto3-checksum-smoke.txt", "aws-js-checksum-smoke.txt", "aws-java-checksum-smoke.txt", "mc-smoke.txt", "docker-mc-smoke.txt", "manual-sigv4-smoke.txt", "manual-copy-sigv4-smoke.txt", "manual-copy-precondition-fail.txt", "manual-bad-payload.txt", "manual-bad-checksum.txt", "manual-vhost-smoke.txt", "manual-multipart-checksum.bin", "manual-multipart-sdk-checksum.bin", "manual-delete-md5-a.txt", "manual-delete-md5-b.txt", "manual-delete-md5-protected.txt")) {
            try {
                Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName/objects/$key" $null $token | Out-Null
            } catch {
                if ($_.Exception.Response.StatusCode.value__ -ne 404) {
                    Write-Warning "Cleanup object skipped for $key`: $($_.Exception.Message)"
                }
            }
            try {
                Invoke-Json "POST" "$ApiBase/buckets/$BucketName/objects/purge/$key" $null $token | Out-Null
            } catch {
                if ($_.Exception.Response.StatusCode.value__ -ne 404) {
                    Write-Warning "Cleanup purge skipped for $key`: $($_.Exception.Message)"
                }
            }
        }
        try {
            Invoke-Json "DELETE" "$ApiBase/buckets/$BucketName" $null $token | Out-Null
        } catch {
            Write-Warning "Cleanup bucket skipped for $BucketName`: $($_.Exception.Message)"
        }
    }
}
