param(
    [string] $EnvFile = ".\infra\local\.env.example",
    [string] $ComposeFile = ".\infra\local\docker-compose.yml",
    [switch] $NoBuild,
    [switch] $KeepRunning
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")
Use-OsmuDockerConfig $root | Out-Null

function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Read-EnvValue($path, $name, $defaultValue) {
    $resolved = Resolve-Path $path
    foreach ($line in Get-Content -Encoding UTF8 $resolved) {
        if ($line -match "^\s*#") {
            continue
        }
        if ($line -match "^\s*$([regex]::Escape($name))=(.*)$") {
            return $Matches[1].Trim()
        }
    }
    return $defaultValue
}

function Compose([string[]] $ComposeArgs) {
    Push-Location $root
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = & docker compose --env-file $EnvFile -f $ComposeFile @ComposeArgs 2>&1
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -ne 0) {
            throw "docker compose failed: $($ComposeArgs -join ' ')"
        }
    }
    finally {
        $ErrorActionPreference = "Stop"
        Pop-Location
    }
}

function Assert-ObjectTagIndex($apiBase, $bucketName, $token) {
    $rawKey = "tag-index/raw.txt"
    $otherKey = "tag-index/other.txt"
    Upload-SmokeObject $apiBase $bucketName $token $rawKey "raw tagged object" "project=osmu,stage=raw" "raw.txt"
    Upload-SmokeObject $apiBase $bucketName $token $otherKey "other tagged object" "project=osmu,stage=other" "other.txt"

    $rawTag = [System.Uri]::EscapeDataString("stage=raw")
    $rawTagged = Invoke-Json "GET" "$apiBase/buckets/$bucketName/objects?prefix=tag-index/&tag=$rawTag" $null $token
    if (-not ($rawTagged.items | Where-Object { $_.key -eq $rawKey }) `
            -or ($rawTagged.items | Where-Object { $_.key -eq $otherKey })) {
        throw "MariaDB object tag index did not return only raw-tagged object."
    }

    Invoke-Json "PUT" "$apiBase/buckets/$bucketName/objects/tags" @{
        key = $rawKey
        tags = "project=archive,stage=curated"
    } $token | Out-Null

    $staleRawTagged = Invoke-Json "GET" "$apiBase/buckets/$bucketName/objects?prefix=tag-index/&tag=$rawTag" $null $token
    if ($staleRawTagged.items | Where-Object { $_.key -eq $rawKey }) {
        throw "MariaDB object tag index still returned object by stale stage=raw tag."
    }

    $curatedTag = [System.Uri]::EscapeDataString("stage=curated")
    $curatedTagged = Invoke-Json "GET" "$apiBase/buckets/$bucketName/objects?prefix=tag-index/&tag=$curatedTag" $null $token
    $curatedObject = $curatedTagged.items | Where-Object { $_.key -eq $rawKey } | Select-Object -First 1
    if (-not $curatedObject -or $curatedObject.tags.stage -ne "curated" -or $curatedObject.tags.project -ne "archive") {
        throw "MariaDB object tag index did not return updated curated tag object."
    }
}

function Upload-MultipartPart($frontendUrl, $part) {
    $length = [int]($part.endByte - $part.startByte + 1)
    $chunk = [byte[]]::new($length)
    $headers = @{
        Origin = $frontendUrl
    }
    $putResponse = Invoke-WebRequest `
        -Method PUT `
        -Uri $part.url `
        -Headers $headers `
        -ContentType "application/octet-stream" `
        -Body $chunk `
        -UseBasicParsing

    if ($putResponse.StatusCode -lt 200 -or $putResponse.StatusCode -ge 300) {
        throw "Multipart part upload failed: HTTP $($putResponse.StatusCode)"
    }

    $etag = [string]$putResponse.Headers["ETag"]
    if (-not $etag) {
        throw "Multipart part upload did not return ETag."
    }

    $exposeHeaders = [string]$putResponse.Headers["Access-Control-Expose-Headers"]
    if (-not $exposeHeaders -or -not $exposeHeaders.ToLowerInvariant().Contains("etag")) {
        throw "MinIO CORS response does not expose ETag."
    }

    return [pscustomobject]@{
        partNumber = $part.partNumber
        etag = $etag
    }
}

function Upload-MultipartSmokeObject($apiBase, $frontendUrl, $bucketName, $token) {
    $objectKey = "multipart-smoke.bin"
    $totalBytes = 11 * 1024 * 1024
    $partSizeBytes = 5 * 1024 * 1024

    $created = Invoke-Json "POST" "$apiBase/buckets/$bucketName/objects/multipart-upload" @{
        key = $objectKey
        contentType = "application/octet-stream"
        sizeBytes = $totalBytes
        partSizeBytes = $partSizeBytes
        expiresInSeconds = 900
        tags = "smoke=multipart"
    } $token

    $completedParts = @()
    $firstPart = $created.data.parts | Sort-Object partNumber | Select-Object -First 1
    $completedParts += Upload-MultipartPart $frontendUrl $firstPart

    $listed = Invoke-Json "POST" "$apiBase/buckets/$bucketName/objects/multipart-upload/parts" @{
        uploadId = $created.data.uploadId
        key = $objectKey
    } $token
    $listedFirstPart = $listed.data.parts | Where-Object { $_.partNumber -eq $firstPart.partNumber } | Select-Object -First 1
    if (-not $listedFirstPart -or -not $listedFirstPart.etag) {
        throw "Multipart list-parts did not return the uploaded first part."
    }

    $refreshed = Invoke-Json "POST" "$apiBase/buckets/$bucketName/objects/multipart-upload/refresh" @{
        uploadId = $created.data.uploadId
        key = $objectKey
        expiresInSeconds = 900
    } $token

    foreach ($part in ($refreshed.data.parts | Sort-Object partNumber | Where-Object { $_.partNumber -ne $firstPart.partNumber })) {
        $completedParts += Upload-MultipartPart $frontendUrl $part
    }

    $listedAll = Invoke-Json "POST" "$apiBase/buckets/$bucketName/objects/multipart-upload/parts" @{
        uploadId = $created.data.uploadId
        key = $objectKey
    } $token
    if (($listedAll.data.parts | Measure-Object).Count -ne $created.data.partCount) {
        throw "Multipart list-parts did not return all uploaded parts."
    }

    Invoke-Json "POST" "$apiBase/buckets/$bucketName/objects/multipart-upload/complete" @{
        uploadId = $created.data.uploadId
        key = $objectKey
        parts = ($completedParts | Sort-Object partNumber)
    } $token | Out-Null
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

function Object-Path($key) {
    return (($key -split "/") | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join "/"
}

function Remove-SmokeObject($apiBase, $bucketName, $key, $token) {
    $objectPath = Object-Path $key
    try {
        Invoke-Json "DELETE" "$apiBase/buckets/$bucketName/objects/$objectPath" $null $token | Out-Null
    } catch {
    }
    try {
        Invoke-Json "POST" "$apiBase/buckets/$bucketName/objects/purge/$objectPath" $null $token | Out-Null
    } catch {
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
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
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

function New-S3SigV4PresignedQuery($method, $url, $accessKey, $secretKey) {
    $uri = [Uri] $url
    $hostHeader = if ($uri.IsDefaultPort) { $uri.Host } else { "$($uri.Host):$($uri.Port)" }
    $amzDate = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")
    $date = $amzDate.Substring(0, 8)
    $scope = "$date/us-east-1/s3/aws4_request"
    $signedHeaders = "host"
    $queryParts = [ordered]@{
        "X-Amz-Algorithm" = "AWS4-HMAC-SHA256"
        "X-Amz-Credential" = "$accessKey/$scope"
        "X-Amz-Date" = $amzDate
        "X-Amz-Expires" = "900"
        "X-Amz-SignedHeaders" = $signedHeaders
    }
    $canonicalQuery = ($queryParts.GetEnumerator() | Sort-Object Name | ForEach-Object {
        "$([System.Uri]::EscapeDataString($_.Name))=$([System.Uri]::EscapeDataString([string]$_.Value))"
    }) -join "&"
    $canonicalHeaders = "host:$hostHeader`n"
    $canonicalRequest = "$method`n$($uri.AbsolutePath)`n$canonicalQuery`n$canonicalHeaders`n$signedHeaders`nUNSIGNED-PAYLOAD"
    $stringToSign = "AWS4-HMAC-SHA256`n$amzDate`n$scope`n$(Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($canonicalRequest)))"

    $dateKey = Get-HmacSha256 ([System.Text.Encoding]::UTF8.GetBytes("AWS4$secretKey")) $date
    $regionKey = Get-HmacSha256 $dateKey "us-east-1"
    $serviceKey = Get-HmacSha256 $regionKey "s3"
    $signingKey = Get-HmacSha256 $serviceKey "aws4_request"
    $signature = ((Get-HmacSha256 $signingKey $stringToSign | ForEach-Object { $_.ToString("x2") }) -join "")
    return "$canonicalQuery&X-Amz-Signature=$signature"
}

function Invoke-S3MultiDeleteMd5Smoke($apiBase, $bucketName, $accessKey, $secretKey) {
    $deleteA = "sigv4-delete-md5-a.txt"
    $deleteB = "sigv4-delete-md5-b.txt"
    $protected = "sigv4-delete-md5-protected.txt"
    $emptyPayload = [byte[]]::new(0)

    foreach ($key in @($deleteA, $deleteB, $protected)) {
        $putResponse = Invoke-SignedHttp "PUT" "$apiBase/s3/$bucketName/$key" ([System.Text.Encoding]::UTF8.GetBytes($key)) $accessKey $secretKey $null $null "text/plain"
        if ($putResponse.StatusCode -ne 200) {
            throw "S3 multi-delete MD5 setup PUT failed for $key`: HTTP $($putResponse.StatusCode)."
        }
    }

    $deleteXml = @"
<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Quiet>true</Quiet>
  <Object><Key>$deleteA</Key></Object>
  <Object><Key>$deleteB</Key></Object>
  <Object><Key>sigv4-delete-md5-missing.txt</Key></Object>
  <Object><Key>.osmu/versions/sigv4-delete-md5-reserved.txt</Key></Object>
</Delete>
"@
    $deleteBytes = [System.Text.Encoding]::UTF8.GetBytes($deleteXml)
    $deleteResponse = Invoke-SignedHttp "POST" "${apiBase}/s3/${bucketName}?delete" $deleteBytes $accessKey $secretKey $null $null "application/xml" @{
        "Content-MD5" = Get-Md5Base64 $deleteBytes
    }
    if ($deleteResponse.StatusCode -ne 200 `
            -or -not $deleteResponse.Body.Contains("<DeleteResult") `
            -or $deleteResponse.Body.Contains("<Deleted>") `
            -or -not $deleteResponse.Body.Contains("<Error>") `
            -or -not $deleteResponse.Body.Contains("<Code>InvalidRequest</Code>")) {
        throw "S3 multi-delete Quiet/Content-MD5 per-key error failed: HTTP $($deleteResponse.StatusCode) $($deleteResponse.Body)"
    }

    $deletedHead = Invoke-SignedHttp "HEAD" "$apiBase/s3/$bucketName/$deleteA" $emptyPayload $accessKey $secretKey
    if ($deletedHead.StatusCode -ne 404) {
        throw "S3 multi-delete did not delete $deleteA."
    }

    $badDeleteXml = @"
<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Object><Key>$protected</Key></Object>
</Delete>
"@
    $badDeleteBytes = [System.Text.Encoding]::UTF8.GetBytes($badDeleteXml)
    $badDeleteResponse = Invoke-SignedHttp "POST" "${apiBase}/s3/${bucketName}?delete" $badDeleteBytes $accessKey $secretKey $null $null "application/xml" @{
        "Content-MD5" = Get-Md5Base64 ([System.Text.Encoding]::UTF8.GetBytes("different body"))
    }
    if ($badDeleteResponse.StatusCode -ne 400 -or -not $badDeleteResponse.Body.Contains("<Code>BadDigest</Code>")) {
        throw "S3 multi-delete mismatched Content-MD5 did not return BadDigest."
    }

    $protectedHead = Invoke-SignedHttp "HEAD" "$apiBase/s3/$bucketName/$protected" $emptyPayload $accessKey $secretKey
    if ($protectedHead.StatusCode -ne 200) {
        throw "S3 multi-delete mismatched Content-MD5 changed object state."
    }
}

function Invoke-S3BucketTaggingSmoke($apiBase, $bucketName, $accessKey, $secretKey) {
    $taggingXml = @"
<Tagging xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <TagSet>
    <Tag><Key>project</Key><Value>osmu</Value></Tag>
    <Tag><Key>stage</Key><Value>smoke</Value></Tag>
  </TagSet>
</Tagging>
"@
    $taggingBytes = [System.Text.Encoding]::UTF8.GetBytes($taggingXml)
    $taggingUrl = "${apiBase}/s3/${bucketName}?tagging"
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

function Invoke-S3MultipartChecksumSmoke($apiBase, $bucketName, $accessKey, $secretKey) {
    $objectKey = "sigv4-multipart-checksum.bin"
    $part1 = [byte[]]::new(5 * 1024 * 1024)
    $part2 = [System.Text.Encoding]::UTF8.GetBytes("tail")
    $allBytes = [byte[]]::new($part1.Length + $part2.Length)
    [Array]::Copy($part1, 0, $allBytes, 0, $part1.Length)
    [Array]::Copy($part2, 0, $allBytes, $part1.Length, $part2.Length)
    $part1Checksum = Get-Sha256Base64 $part1
    $part2Checksum = Get-Sha256Base64 $part2
    $objectChecksum = Get-Sha256Base64 $allBytes

    $initiateUrl = "${apiBase}/s3/${bucketName}/${objectKey}?uploads"
    $initiateHeaders = @{
        "x-amz-meta-osmu-size-bytes" = [string]$allBytes.Length
        "x-amz-meta-osmu-part-size-bytes" = [string]$part1.Length
    }
    $initiate = Invoke-SignedHttp "POST" $initiateUrl ([byte[]]::new(0)) $accessKey $secretKey $null $null "application/octet-stream" $initiateHeaders
    if ($initiate.StatusCode -ne 200 -or $initiate.Body -notmatch "<UploadId>([^<]+)</UploadId>") {
        throw "S3 multipart checksum initiate failed: HTTP $($initiate.StatusCode) $($initiate.Body)"
    }
    $uploadId = $Matches[1]

    $part1Url = "${apiBase}/s3/${bucketName}/${objectKey}?partNumber=1&uploadId=$([System.Uri]::EscapeDataString($uploadId))"
    $part1Response = Invoke-SignedHttp "PUT" $part1Url $part1 $accessKey $secretKey $null $null "application/octet-stream" @{
        "x-amz-checksum-sha256" = $part1Checksum
    }
    $part1Etag = Get-HeaderValue $part1Response.Headers "ETag"
    if ($part1Response.StatusCode -ne 200 -or -not $part1Etag -or (Get-HeaderValue $part1Response.Headers "x-amz-checksum-sha256") -ne $part1Checksum) {
        throw "S3 multipart checksum part 1 upload failed: HTTP $($part1Response.StatusCode)."
    }

    $part2Url = "${apiBase}/s3/${bucketName}/${objectKey}?partNumber=2&uploadId=$([System.Uri]::EscapeDataString($uploadId))"
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
    $completeUrl = "${apiBase}/s3/${bucketName}/${objectKey}?uploadId=$([System.Uri]::EscapeDataString($uploadId))"
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

    $headResponse = Invoke-SignedHttp "HEAD" "$apiBase/s3/$bucketName/$objectKey" ([byte[]]::new(0)) $accessKey $secretKey
    $headEtag = Normalize-Etag (Get-HeaderValue $headResponse.Headers "ETag")
    if ($headResponse.StatusCode -ne 200 `
            -or (Get-HeaderValue $headResponse.Headers "x-amz-checksum-sha256") -ne $objectChecksum `
            -or $headEtag -ne $expectedMultipartEtag) {
        throw "S3 multipart checksum HEAD did not expose stored checksum and multipart ETag."
    }
}

function Invoke-S3SigV4Smoke($apiBase, $bucketName, $token) {
    $createdKey = Invoke-Json "POST" "$apiBase/access-keys" @{
        name = "docker-sigv4-smoke"
        bucketScopes = @(
            @{
                bucketName = $bucketName
                permissions = @("READ", "WRITE", "DELETE", "ADMIN")
            }
        )
        expiresAt = $null
    } $token

    $accessKey = $createdKey.data.accessKey
    $secretKey = $createdKey.data.secretKey
    if (-not $accessKey -or -not $secretKey) {
        throw "Access key creation did not return accessKey and secretKey."
    }

    $emptyPayload = [byte[]]::new(0)
    $rootHeadResponse = Invoke-SignedHttp "HEAD" "$apiBase/s3" $emptyPayload $accessKey $secretKey
    if ($rootHeadResponse.StatusCode -ne 200) {
        throw "SigV4 root HEAD failed: HTTP $($rootHeadResponse.StatusCode)."
    }

    $rootResponse = Invoke-SignedHttp "GET" "$apiBase/s3" $emptyPayload $accessKey $secretKey
    if ($rootResponse.StatusCode -ne 200 -or -not $rootResponse.Body.Contains("<Name>$bucketName</Name>")) {
        throw "SigV4 root bucket listing did not return the smoke bucket."
    }

    Invoke-S3BucketTaggingSmoke $apiBase $bucketName $accessKey $secretKey

    $objectKey = "sigv4-smoke.txt"
    $objectUrl = "$apiBase/s3/$bucketName/$objectKey"
    $putBytes = [System.Text.Encoding]::UTF8.GetBytes("osmu sigv4 docker smoke")
    $putChecksum = Get-Sha256Base64 $putBytes
    $putHeaders = New-S3SigV4Headers "PUT" $objectUrl $putBytes $accessKey $secretKey $null $null @{
        "x-amz-checksum-sha256" = $putChecksum
    }
    $putResponse = Invoke-WebRequest `
        -Method PUT `
        -Uri $objectUrl `
        -Headers $putHeaders `
        -ContentType "text/plain" `
        -Body $putBytes `
        -UseBasicParsing
    if ($putResponse.StatusCode -ne 200) {
        throw "SigV4 object PUT failed: HTTP $($putResponse.StatusCode)."
    }
    if ((Get-HeaderValue $putResponse.Headers "x-amz-checksum-sha256") -ne $putChecksum) {
        throw "SigV4 object PUT did not echo x-amz-checksum-sha256."
    }

    $getHeaders = New-S3SigV4Headers "GET" $objectUrl $emptyPayload $accessKey $secretKey
    $getResponse = Invoke-WebRequest -Method GET -Uri $objectUrl -Headers $getHeaders -UseBasicParsing
    if ($getResponse.StatusCode -ne 200 -or $getResponse.Content -ne "osmu sigv4 docker smoke") {
        throw "SigV4 object GET did not return the uploaded body."
    }
    if ((Get-HeaderValue $getResponse.Headers "x-amz-checksum-sha256") -ne $putChecksum) {
        throw "SigV4 object GET did not expose stored checksum."
    }

    $headResponse = Invoke-SignedHttp "HEAD" $objectUrl $emptyPayload $accessKey $secretKey
    if ($headResponse.StatusCode -ne 200 -or (Get-HeaderValue $headResponse.Headers "x-amz-checksum-sha256") -ne $putChecksum) {
        throw "SigV4 object HEAD did not expose stored checksum."
    }

    Invoke-Json "POST" "$apiBase/buckets/$bucketName/sync" $null $token | Out-Null
    $headAfterSync = Invoke-SignedHttp "HEAD" $objectUrl $emptyPayload $accessKey $secretKey
    if ($headAfterSync.StatusCode -ne 200 -or (Get-HeaderValue $headAfterSync.Headers "x-amz-checksum-sha256") -ne $putChecksum) {
        throw "SigV4 object HEAD did not preserve checksum after bucket sync."
    }

    $presignedUrl = "${objectUrl}?$(New-S3SigV4PresignedQuery "GET" $objectUrl $accessKey $secretKey)"
    $presignedResponse = Invoke-WebRequest -Method GET -Uri $presignedUrl -UseBasicParsing
    if ($presignedResponse.StatusCode -ne 200 -or $presignedResponse.Content -ne "osmu sigv4 docker smoke") {
        throw "SigV4 presigned object GET did not return the uploaded body."
    }

    $badPayloadHash = Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes("different body"))
    $badResponse = Invoke-SignedHttp `
        "PUT" `
        "$apiBase/s3/$bucketName/sigv4-bad-payload.txt" `
        $putBytes `
        $accessKey `
        $secretKey `
        $null `
        $badPayloadHash `
        "text/plain"
    if ($badResponse.StatusCode -ne 400 -or -not $badResponse.Body.Contains("<Code>BadDigest</Code>")) {
        throw "SigV4 payload hash mismatch did not return BadDigest. HTTP $($badResponse.StatusCode)."
    }

    $badChecksum = Get-Sha256Base64 ([System.Text.Encoding]::UTF8.GetBytes("different body"))
    $badChecksumResponse = Invoke-SignedHttp `
        "PUT" `
        "$apiBase/s3/$bucketName/sigv4-bad-checksum.txt" `
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
        throw "SigV4 checksum mismatch did not return BadDigest. HTTP $($badChecksumResponse.StatusCode)."
    }

    $s3Root = [Uri] "$apiBase/s3"
    $hostOverride = if ($s3Root.IsDefaultPort) {
        "$bucketName.localhost"
    } else {
        "$bucketName.localhost:$($s3Root.Port)"
    }
    $vhostObjectUrl = "$($s3Root.Scheme)://$($s3Root.Authority)$($s3Root.AbsolutePath)/sigv4-vhost-smoke.txt"
    $vhostBytes = [System.Text.Encoding]::UTF8.GetBytes("osmu sigv4 virtual hosted smoke")
    $vhostPut = Invoke-SignedHttp "PUT" $vhostObjectUrl $vhostBytes $accessKey $secretKey $hostOverride $null "text/plain"
    if ($vhostPut.StatusCode -ne 200) {
        throw "SigV4 virtual-hosted-style object PUT failed: HTTP $($vhostPut.StatusCode)."
    }

    $vhostGet = Invoke-SignedHttp "GET" $vhostObjectUrl $emptyPayload $accessKey $secretKey $hostOverride
    if ($vhostGet.StatusCode -ne 200 -or $vhostGet.Body -ne "osmu sigv4 virtual hosted smoke") {
        throw "SigV4 virtual-hosted-style object GET did not return the uploaded body."
    }

    Invoke-S3MultipartChecksumSmoke $apiBase $bucketName $accessKey $secretKey
    Invoke-S3MultiDeleteMd5Smoke $apiBase $bucketName $accessKey $secretKey
}

function Wait-Json($url, $timeoutSeconds = 120) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    do {
        try {
            return Invoke-RestMethod -Method GET -Uri $url
        }
        catch {
            Start-Sleep -Seconds 2
        }
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for $url"
}

function Upload-SmokeObject(
    $apiBase,
    $bucketName,
    $token,
    [string] $key = "smoke.txt",
    [string] $body = "osmu docker smoke",
    [string] $tags = "",
    [string] $fileName = "smoke.txt"
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
        if (-not $response.IsSuccessStatusCode) {
            throw "Upload failed: HTTP $([int] $response.StatusCode) $responseBody"
        }
    }
    finally {
        $client.Dispose()
    }
}

Step "Docker daemon check"
Push-Location $root
try {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $dockerInfoOutput = & docker info 2>&1
    $dockerInfoExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($dockerInfoExitCode -ne 0) {
        $detail = ($dockerInfoOutput | Select-Object -Last 1)
        throw "Docker daemon is not running or not reachable. $detail"
    }
}
finally {
    $ErrorActionPreference = "Stop"
    Pop-Location
}

Step "Docker Compose config"
Compose -ComposeArgs @("config", "--quiet")

Step "Docker Compose up"
$upArgs = @("up", "-d")
if (-not $NoBuild) {
    $upArgs += "--build"
}
Compose -ComposeArgs $upArgs

$backendPort = Read-EnvValue (Join-Path $root $EnvFile) "BACKEND_PORT" "8080"
$frontendPort = Read-EnvValue (Join-Path $root $EnvFile) "FRONTEND_PORT" "5173"
$adminLoginId = Read-EnvValue (Join-Path $root $EnvFile) "OSMU_ADMIN_LOGIN_ID" "admin"
$adminPassword = Read-EnvValue (Join-Path $root $EnvFile) "OSMU_ADMIN_PASSWORD" "password"
$apiBase = "http://localhost:$backendPort/api"
$frontendUrl = "http://localhost:$frontendPort"
$bucketName = "smoke-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"

try {
    Step "Backend health"
    Wait-Json "$apiBase/health" | Out-Null
    Wait-Json "$apiBase/storage/health" | Out-Null
    Wait-Json "$apiBase/database/health" | Out-Null

    Step "Auth login"
    $login = Invoke-Json "POST" "$apiBase/auth/login" @{
        loginId = $adminLoginId
        password = $adminPassword
    }
    $token = $login.data.accessToken
    if (-not $token) {
        throw "Login did not return accessToken."
    }

    Step "Bucket create"
    Invoke-Json "POST" "$apiBase/buckets" @{
        name = $bucketName
        quotaBytes = 33554432
    } $token | Out-Null

    Step "Object upload/list"
    Upload-SmokeObject $apiBase $bucketName $token
    $objects = Invoke-Json "GET" "$apiBase/buckets/$bucketName/objects" $null $token
    if (-not ($objects.items | Where-Object { $_.key -eq "smoke.txt" })) {
        throw "Uploaded smoke object not found."
    }

    Step "MariaDB object tag index"
    Assert-ObjectTagIndex $apiBase $bucketName $token

    Step "Multipart upload with CORS ETag"
    Upload-MultipartSmokeObject $apiBase $frontendUrl $bucketName $token
    $objects = Invoke-Json "GET" "$apiBase/buckets/$bucketName/objects" $null $token
    if (-not ($objects.items | Where-Object { $_.key -eq "multipart-smoke.bin" })) {
        throw "Uploaded multipart smoke object not found."
    }

    Step "S3 SigV4 alias"
    Invoke-S3SigV4Smoke $apiBase $bucketName $token
    $objects = Invoke-Json "GET" "$apiBase/buckets/$bucketName/objects" $null $token
    if (-not ($objects.items | Where-Object { $_.key -eq "sigv4-smoke.txt" })) {
        throw "Uploaded SigV4 smoke object not found."
    }

    Step "Frontend reachable"
    $frontend = Invoke-WebRequest -Method GET -Uri $frontendUrl -UseBasicParsing
    if ($frontend.StatusCode -ne 200) {
        throw "Frontend returned HTTP $($frontend.StatusCode)."
    }

    Step "Cleanup smoke data"
    foreach ($key in @(
            "smoke.txt",
            "tag-index/raw.txt",
            "tag-index/other.txt",
            "multipart-smoke.bin",
            "sigv4-smoke.txt",
            "sigv4-multipart-checksum.bin",
            "sigv4-delete-md5-a.txt",
            "sigv4-delete-md5-b.txt",
            "sigv4-delete-md5-protected.txt",
            "sigv4-vhost-smoke.txt",
            "sigv4-bad-payload.txt",
            "sigv4-bad-checksum.txt"
        )) {
        Remove-SmokeObject $apiBase $bucketName $key $token
    }
    Invoke-Json "DELETE" "$apiBase/buckets/$bucketName" $null $token | Out-Null

    Step "Docker integration smoke passed"
}
finally {
    if (-not $KeepRunning) {
        Step "Docker Compose down"
        Compose -ComposeArgs @("down")
    }
}
