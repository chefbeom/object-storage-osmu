param(
    [string] $BucketName = "",
    [string] $MinioAlias = "osmu-minio",
    [string] $CorsXmlPath = "",
    [string] $McCommand = "mc",
    [int] $McTimeoutSeconds = 30,
    [string[]] $ExpectedAllowedOrigins = @(),
    [string[]] $ExpectedMethods = @("GET", "PUT", "POST", "DELETE", "HEAD"),
    [string[]] $ExpectedAllowedHeaders = @("*"),
    [string[]] $ExpectedExposeHeaders = @("ETag", "x-amz-request-id", "x-amz-id-2", "x-amz-version-id"),
    [int] $ExpectedMaxAgeSeconds = 3000,
    [string] $JsonOutputPath = ".\.osmu-run\latest-minio-bucket-cors-verification.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-minio-bucket-cors-verification.md",
    [switch] $Execute,
    [switch] $FailIfNotPassed,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = New-Object System.Collections.Generic.List[object]

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-SafeText([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $patterns = @(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
        "\bA(KIA|SIA)[0-9A-Z]{16}\b",
        "\bBearer\s+[A-Za-z0-9._~+/=-]{12,}",
        "(?i)\b(password|passwd|secret|token|client_secret|x-amz-security-token|authorization)\s*[""':=]\s*\S+",
        "(?i)\b(secretKey|accessKey|sessionToken)\s*[""':=]\s*\S+",
        "(?i)Credential=[^,\s]+"
    )

    foreach ($pattern in $patterns) {
        if ($Value -match $pattern) {
            throw "$Label appears to contain secret material. Store only bucket CORS metadata or an external evidence reference."
        }
    }
}

function New-Check([string] $Id, [string] $Name, [string] $Status, [string] $Detail) {
    return [ordered]@{
        id = $Id
        name = $Name
        status = $Status
        passed = $Status -eq "PASS"
        detail = $Detail
    }
}

function Add-Check([string] $Id, [string] $Name, [bool] $Passed, [string] $Detail) {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    [void] $script:checks.Add((New-Check $Id $Name $status $Detail))
}

function Add-PlannedCheck([string] $Id, [string] $Name, [string] $Detail) {
    [void] $script:checks.Add((New-Check $Id $Name "PLANNED" $Detail))
}

function Quote-CommandArgument([string] $Argument) {
    if ($null -eq $Argument) {
        return '""'
    }
    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }
    return '"' + ($Argument -replace '\\', '\\' -replace '"', '\"') + '"'
}

function Invoke-CommandWithTimeout([string] $FilePath, [string[]] $Arguments, [int] $TimeoutSeconds) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = (($Arguments | ForEach-Object { Quote-CommandArgument $_ }) -join " ")
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void] $process.Start()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try {
            $process.Kill()
        }
        catch {
        }
        throw "Command timed out after $TimeoutSeconds seconds: $FilePath $($psi.Arguments)"
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    return [pscustomobject]([ordered]@{
        exitCode = $process.ExitCode
        output = ($stdout + $stderr)
    })
}

function Get-NormalizedUnique([object[]] $Values) {
    return @($Values |
        Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string] $_) } |
        ForEach-Object { ([string] $_).Trim() } |
        Sort-Object -Unique)
}

function Test-ValuePresent([string[]] $Actual, [string] $Expected, [bool] $WildcardMatches) {
    foreach ($item in @($Actual | Where-Object { $null -ne $_ })) {
        $text = [string] $item
        if ($WildcardMatches -and $item -eq "*") {
            return $true
        }
        if ($text.Equals($Expected, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-MissingValues([string[]] $Expected, [string[]] $Actual, [bool] $WildcardMatches) {
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($expectedValue in (Get-NormalizedUnique $Expected)) {
        if (-not (Test-ValuePresent $Actual $expectedValue $WildcardMatches)) {
            [void] $missing.Add($expectedValue)
        }
    }
    return $missing.ToArray()
}

function Get-XmlChildValues([System.Xml.XmlNode] $Node, [string] $LocalName) {
    $values = New-Object System.Collections.Generic.List[string]
    foreach ($child in $Node.ChildNodes) {
        if ($child.LocalName -eq $LocalName -and -not [string]::IsNullOrWhiteSpace($child.InnerText)) {
            [void] $values.Add($child.InnerText.Trim())
        }
    }
    return $values.ToArray()
}

function Read-CorsConfiguration([string] $Text) {
    Assert-SafeText $Text "CorsXml"
    $xmlText = $Text
    if ($Text -match "(?s)<CORSConfiguration[\s\S]*?</CORSConfiguration>") {
        $xmlText = $Matches[0]
    }

    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $stringReader = [System.IO.StringReader]::new($xmlText)
    $reader = [System.Xml.XmlReader]::Create([System.IO.TextReader] $stringReader, $settings)
    $document = [System.Xml.XmlDocument]::new()
    try {
        $document.PreserveWhitespace = $false
        $document.Load($reader)
    }
    finally {
        $reader.Dispose()
        $stringReader.Dispose()
    }

    $rules = New-Object System.Collections.Generic.List[object]
    $ruleNodes = $document.SelectNodes("//*[local-name()='CORSRule']")
    foreach ($ruleNode in $ruleNodes) {
        $allowedOrigins = Get-NormalizedUnique (Get-XmlChildValues $ruleNode "AllowedOrigin")
        $allowedMethods = Get-NormalizedUnique (Get-XmlChildValues $ruleNode "AllowedMethod")
        $allowedHeaders = Get-NormalizedUnique (Get-XmlChildValues $ruleNode "AllowedHeader")
        $exposeHeaders = Get-NormalizedUnique (Get-XmlChildValues $ruleNode "ExposeHeader")
        $maxAgeValues = Get-XmlChildValues $ruleNode "MaxAgeSeconds"
        $parsedMaxAge = @()
        foreach ($value in $maxAgeValues) {
            $number = 0
            if ([int]::TryParse($value, [ref] $number)) {
                $parsedMaxAge += $number
            }
        }

        [void] $rules.Add([pscustomobject]([ordered]@{
            allowedOrigins = $allowedOrigins
            allowedMethods = $allowedMethods
            allowedHeaders = $allowedHeaders
            exposeHeaders = $exposeHeaders
            maxAgeSeconds = @($parsedMaxAge)
        }))
    }

    $allAllowedOrigins = Get-NormalizedUnique @($rules | ForEach-Object { $_.allowedOrigins })
    $allAllowedMethods = Get-NormalizedUnique @($rules | ForEach-Object { $_.allowedMethods })
    $allAllowedHeaders = Get-NormalizedUnique @($rules | ForEach-Object { $_.allowedHeaders })
    $allExposeHeaders = Get-NormalizedUnique @($rules | ForEach-Object { $_.exposeHeaders })
    $allMaxAgeSeconds = Get-NormalizedUnique @($rules | ForEach-Object { $_.maxAgeSeconds })
    $ruleArray = $rules.ToArray()

    return [pscustomobject]([ordered]@{
        ruleCount = $rules.Count
        rules = [object[]] $ruleArray
        allowedOrigins = $allAllowedOrigins
        allowedMethods = $allAllowedMethods
        allowedHeaders = $allAllowedHeaders
        exposeHeaders = $allExposeHeaders
        maxAgeSeconds = $allMaxAgeSeconds
    })
}

foreach ($entry in @(
    @("BucketName", $BucketName),
    @("MinioAlias", $MinioAlias),
    @("CorsXmlPath", $CorsXmlPath),
    @("McCommand", $McCommand)
)) {
    Assert-SafeText ([string] $entry[1]) ([string] $entry[0])
}

$hasInput = -not [string]::IsNullOrWhiteSpace($CorsXmlPath) -or [bool] $Execute
$sourceMode = "plan-only"
$sourceRef = ""
$corsText = ""
$parseError = ""
$parsedCors = $null

if ([bool] $Execute) {
    if ([string]::IsNullOrWhiteSpace($BucketName)) {
        throw "BucketName is required with -Execute."
    }
    if ([string]::IsNullOrWhiteSpace($MinioAlias)) {
        throw "MinioAlias is required with -Execute."
    }

    $sourceMode = "mc-cors-info-execute"
    $sourceRef = "mc cors info $MinioAlias/$BucketName"
    $commandResult = Invoke-CommandWithTimeout $McCommand @("cors", "info", "$MinioAlias/$BucketName") $McTimeoutSeconds
    if ($commandResult.exitCode -ne 0) {
        throw "mc cors info failed with exit code $($commandResult.exitCode). Output: $($commandResult.output)"
    }
    $corsText = $commandResult.output
}
elseif (-not [string]::IsNullOrWhiteSpace($CorsXmlPath)) {
    $resolvedCorsXmlPath = Resolve-ProjectPath $CorsXmlPath
    if (-not (Test-Path -LiteralPath $resolvedCorsXmlPath)) {
        throw "CORS XML path not found: $resolvedCorsXmlPath"
    }
    $sourceMode = "cors-xml-path"
    $sourceRef = $resolvedCorsXmlPath
    $corsText = Get-Content -Raw -LiteralPath $resolvedCorsXmlPath
}

if ($hasInput) {
    try {
        $parsedCors = Read-CorsConfiguration $corsText
    }
    catch {
        $parseError = "$($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)"
    }
}

if (-not $hasInput) {
    Add-PlannedCheck "cors-input" "Bucket CORS input available" "Provide -CorsXmlPath, or use -Execute with -BucketName and -MinioAlias."
    Add-PlannedCheck "cors-rule" "Bucket CORS rule inspected" "No CORS XML was parsed."
    Add-PlannedCheck "browser-upload-headers" "Browser multipart upload headers exposed" "Expected expose headers: $((Get-NormalizedUnique $ExpectedExposeHeaders) -join ', ')."
}
else {
    $expectedOrigins = Get-NormalizedUnique $ExpectedAllowedOrigins
    $expectedMethods = Get-NormalizedUnique $ExpectedMethods
    $expectedAllowedHeaders = Get-NormalizedUnique $ExpectedAllowedHeaders
    $expectedExposeHeaders = Get-NormalizedUnique $ExpectedExposeHeaders

    $actualOrigins = if ($null -ne $parsedCors) { $parsedCors.allowedOrigins } else { @() }
    $actualMethods = if ($null -ne $parsedCors) { $parsedCors.allowedMethods } else { @() }
    $actualAllowedHeaders = if ($null -ne $parsedCors) { $parsedCors.allowedHeaders } else { @() }
    $actualExposeHeaders = if ($null -ne $parsedCors) { $parsedCors.exposeHeaders } else { @() }
    $actualMaxAgeSeconds = if ($null -ne $parsedCors) { @($parsedCors.maxAgeSeconds | ForEach-Object { [int] $_ }) } else { @() }

    $missingOrigins = if ($expectedOrigins.Count -gt 0) { Get-MissingValues $expectedOrigins $actualOrigins $true } else { @() }
    $missingMethods = Get-MissingValues $expectedMethods $actualMethods $false
    $missingAllowedHeaders = Get-MissingValues $expectedAllowedHeaders $actualAllowedHeaders $true
    $missingExposeHeaders = Get-MissingValues $expectedExposeHeaders $actualExposeHeaders $false
    $maxAgeMatches = $ExpectedMaxAgeSeconds -le 0 -or (@($actualMaxAgeSeconds | Where-Object { $_ -eq $ExpectedMaxAgeSeconds }).Count -gt 0)

    Add-Check "cors-xml-parse" "Bucket CORS XML parsed" ($null -ne $parsedCors) "sourceMode=$sourceMode; parseError=$parseError"
    Add-Check "cors-rule" "Bucket CORS rule present" ($null -ne $parsedCors -and $parsedCors.ruleCount -gt 0) "ruleCount=$(if ($null -ne $parsedCors) { $parsedCors.ruleCount } else { 0 })"
    Add-Check "allowed-origin" "Expected browser origins allowed" ($expectedOrigins.Count -eq 0 -or $missingOrigins.Count -eq 0) "expected=$($expectedOrigins -join ', '); missing=$($missingOrigins -join ', '); actual=$($actualOrigins -join ', ')"
    Add-Check "allowed-methods" "Expected methods allowed" ($missingMethods.Count -eq 0) "expected=$($expectedMethods -join ', '); missing=$($missingMethods -join ', '); actual=$($actualMethods -join ', ')"
    Add-Check "allowed-headers" "Expected request headers allowed" ($missingAllowedHeaders.Count -eq 0) "expected=$($expectedAllowedHeaders -join ', '); missing=$($missingAllowedHeaders -join ', '); actual=$($actualAllowedHeaders -join ', ')"
    Add-Check "expose-headers" "Browser multipart upload response headers exposed" ($missingExposeHeaders.Count -eq 0) "expected=$($expectedExposeHeaders -join ', '); missing=$($missingExposeHeaders -join ', '); actual=$($actualExposeHeaders -join ', ')"
    Add-Check "max-age" "Expected CORS max-age present" $maxAgeMatches "expected=$ExpectedMaxAgeSeconds; actual=$($actualMaxAgeSeconds -join ', ')"
    Add-Check "raw-cors-policy" "Raw CORS XML omitted from report" $true "Only normalized rule summary is stored."
}

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$plannedCount = @($checks | Where-Object { $_.status -eq "PLANNED" }).Count
$result = if (-not $hasInput) {
    "planned"
}
elseif ($failureCount -eq 0) {
    "passed"
}
else {
    "failed"
}

$generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath

$corsSummary = if ($null -ne $parsedCors) {
    [ordered]@{
        ruleCount = $parsedCors.ruleCount
        allowedOrigins = [object] @($parsedCors.allowedOrigins)
        allowedMethods = [object] @($parsedCors.allowedMethods)
        allowedHeaders = [object] @($parsedCors.allowedHeaders)
        exposeHeaders = [object] @($parsedCors.exposeHeaders)
        maxAgeSeconds = [object] @($parsedCors.maxAgeSeconds)
        rules = [object] @($parsedCors.rules)
    }
}
else {
    [ordered]@{
        ruleCount = 0
        allowedOrigins = @()
        allowedMethods = @()
        allowedHeaders = @()
        exposeHeaders = @()
        maxAgeSeconds = @()
        rules = @()
    }
}

$report = New-Object System.Collections.Specialized.OrderedDictionary
[void] $report.Add("formatVersion", "osmu.minio-bucket-cors-verification.v1")
[void] $report.Add("generatedAt", $generatedAt)
[void] $report.Add("result", $result)
[void] $report.Add("source", [ordered]@{
    mode = $sourceMode
    bucketName = $BucketName
    minioAlias = $MinioAlias
    sourceRef = $sourceRef
    executeRequested = [bool] $Execute
    mcTimeoutSeconds = $McTimeoutSeconds
    rawCorsXmlStored = $false
})
[void] $report.Add("expected", [ordered]@{
    allowedOrigins = [object] @(Get-NormalizedUnique $ExpectedAllowedOrigins)
    methods = [object] @(Get-NormalizedUnique $ExpectedMethods)
    allowedHeaders = [object] @(Get-NormalizedUnique $ExpectedAllowedHeaders)
    exposeHeaders = [object] @(Get-NormalizedUnique $ExpectedExposeHeaders)
    maxAgeSeconds = $ExpectedMaxAgeSeconds
})
[void] $report.Add("summary", [ordered]@{
    ruleCount = $corsSummary.ruleCount
    exposedHeaderCount = @($corsSummary.exposeHeaders).Count
    failureCount = $failureCount
    plannedCount = $plannedCount
})
[void] $report.Add("cors", $corsSummary)
[void] $report.Add("checks", [object] @($checks | ForEach-Object { $_ }))
[void] $report.Add("decisionRule", "MinIO bucket CORS verification passes when CORS XML is parseable, at least one rule exists, OSMU browser upload methods are allowed, request headers are allowed, and response headers ETag/x-amz-request-id/x-amz-id-2/x-amz-version-id are exposed.")
[void] $report.Add("scopePolicy", "This evidence verifies MinIO bucket CORS needed by OSMU browser multipart upload and traceability. It is not AWS S3 parity work, and it does not store raw CORS XML, credentials, bearer tokens, private keys, MinIO root credentials, or object data.")
[void] $report.Add("operatorCommands", [ordered]@{
    collectWithMc = "mc cors info <alias>/<bucket> > .\.osmu-run\minio-bucket-cors.xml"
    verifyFromFile = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-minio-bucket-cors.ps1 -CorsXmlPath .\.osmu-run\minio-bucket-cors.xml -ExpectedAllowedOrigins http://localhost:5173,http://127.0.0.1:5173 -FailIfNotPassed"
    collectAndVerify = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-minio-bucket-cors.ps1 -BucketName <bucket> -MinioAlias <alias> -Execute -FailIfNotPassed"
})

$markdownLines = @(
    "# OSMU MinIO Bucket CORS Verification",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source mode: $sourceMode",
    "Bucket: $BucketName",
    "MinIO alias: $MinioAlias",
    "Raw CORS XML stored: false",
    "",
    "## Summary",
    "",
    "- Rules: $($corsSummary.ruleCount)",
    "- Allowed origins: $((@($corsSummary.allowedOrigins) -join ', '))",
    "- Allowed methods: $((@($corsSummary.allowedMethods) -join ', '))",
    "- Allowed headers: $((@($corsSummary.allowedHeaders) -join ', '))",
    "- Expose headers: $((@($corsSummary.exposeHeaders) -join ', '))",
    "- Max age seconds: $((@($corsSummary.maxAgeSeconds) -join ', '))",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Scope Policy",
    "",
    $report.scopePolicy,
    "",
    "## Checks",
    ""
)

foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}

$markdownLines += ""
$markdownLines += "## Operator Commands"
$markdownLines += ""
$markdownLines += "- Collect CORS XML: ``$($report.operatorCommands.collectWithMc)``"
$markdownLines += "- Verify from file: ``$($report.operatorCommands.verifyFromFile)``"
$markdownLines += "- Collect and verify: ``$($report.operatorCommands.collectAndVerify)``"

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "MinIO bucket CORS verification JSON: $resolvedJsonOutputPath"
    Write-Host "MinIO bucket CORS verification markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "MinIO bucket CORS verification did not pass: result=$result failureCount=$failureCount"
}
