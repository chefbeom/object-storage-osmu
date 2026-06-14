param(
    [string] $ApiBase = "http://localhost:8080/api",
    [string] $S3Endpoint = "",
    [string] $AdminLoginId = "admin",
    [string] $AdminPassword = "password",
    [string] $BucketName = "",
    [ValidateSet("auto", "aws", "mc", "all")]
    [string] $Client = "auto",
    [switch] $SkipManualSigV4,
    [switch] $SkipMultipartChecksumSmoke,
    [switch] $SkipVirtualHostedSmoke,
    [switch] $KeepBucket,
    [switch] $RequireClient
)

$ErrorActionPreference = "Stop"

if (-not $S3Endpoint) {
    $S3Endpoint = "$ApiBase/s3"
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

    $headResponse = Invoke-SignedHttp "HEAD" "$s3Endpoint/$bucketName/$objectKey" ([byte[]]::new(0)) $accessKey $secretKey
    if ($headResponse.StatusCode -ne 200 -or (Get-HeaderValue $headResponse.Headers "x-amz-checksum-sha256") -ne $objectChecksum) {
        throw "S3 multipart checksum HEAD did not expose stored checksum."
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
        $vhostUrl = "$($endpoint.Scheme)://$($endpoint.Authority)$($endpoint.AbsolutePath)/manual-vhost-smoke.txt"
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

        $downloadPath = Join-Path $tempDir "aws-cli-download.txt"
        Invoke-External $aws.Source @("--endpoint-url", $s3Endpoint, "s3api", "get-object", "--bucket", $bucketName, "--key", "aws-cli-smoke.txt", $downloadPath, "--output", "json") | Out-Null
        if ((Get-Content -Raw -LiteralPath $downloadPath) -ne "osmu aws cli smoke") {
            throw "AWS CLI get-object body mismatch."
        }

        Invoke-External $aws.Source @("--endpoint-url", $s3Endpoint, "s3api", "delete-object", "--bucket", $bucketName, "--key", "aws-cli-smoke.txt", "--output", "json") | Out-Null
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
    if ($Client -in @("auto", "mc", "all")) {
        if (Invoke-McSmoke $ApiBase $S3Endpoint $BucketName $accessKey $secretKey) {
            $ranClients.Add("mc")
        } elseif ($Client -eq "mc") {
            throw "MinIO Client mc not found on PATH."
        }
    }

    if ($ranClients.Count -eq 0) {
        $message = "No real S3 client found. Install AWS CLI (aws) or MinIO Client (mc) and rerun this script."
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
        foreach ($key in @("aws-cli-smoke.txt", "mc-smoke.txt", "manual-sigv4-smoke.txt", "manual-copy-sigv4-smoke.txt", "manual-copy-precondition-fail.txt", "manual-bad-payload.txt", "manual-bad-checksum.txt", "manual-vhost-smoke.txt", "manual-multipart-checksum.bin", "manual-delete-md5-a.txt", "manual-delete-md5-b.txt", "manual-delete-md5-protected.txt")) {
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
