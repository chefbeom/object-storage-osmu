param(
    [string] $EnvironmentName = "",
    [string] $TargetCluster = "",
    [string] $Operator = "",
    [string] $MinioAlias = "",
    [string] $EvidenceRef = "",
    [string] $AdminInfoJsonPath = "",
    [string] $AdminInfoJson = "",
    [string] $McCommand = "mc",
    [int] $McTimeoutSeconds = 30,
    [string] $JsonOutputPath = ".\.osmu-run\latest-storage-backend-telemetry.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-storage-backend-telemetry.md",
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
function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
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
            throw "$Label appears to contain secret material. Store only non-secret telemetry or an external evidence reference."
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

function Get-Sha256Hex([string] $Text) {
    if ([string]::IsNullOrEmpty($Text)) {
        return ""
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return -join ($hash | ForEach-Object { $_.ToString("x2") })
    }
    finally {
        $sha.Dispose()
    }
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
    return [pscustomobject][ordered]@{
        exitCode = $process.ExitCode
        output = ($stdout + $stderr)
    }
}

function Test-ScalarLike([object] $Value) {
    return $null -eq $Value `
        -or $Value -is [string] `
        -or $Value -is [bool] `
        -or $Value -is [byte] `
        -or $Value -is [int16] `
        -or $Value -is [int] `
        -or $Value -is [long] `
        -or $Value -is [single] `
        -or $Value -is [double] `
        -or $Value -is [decimal] `
        -or $Value -is [datetime]
}

function Normalize-Array([object] $Value) {
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($entry in @($Value)) {
        if ($null -eq $entry) {
            continue
        }
        if ($entry -is [string]) {
            [void] $items.Add($entry)
        }
        elseif ($entry -is [System.Collections.IEnumerable] -and -not ($entry -is [System.Collections.IDictionary])) {
            foreach ($nested in $entry) {
                if ($null -ne $nested) {
                    [void] $items.Add($nested)
                }
            }
        }
        else {
            [void] $items.Add($entry)
        }
    }
    return $items.ToArray()
}

function Get-ObjectPropertyValue([object] $Object, [string[]] $Names) {
    if ($null -eq $Object) {
        return $null
    }

    foreach ($name in $Names) {
        if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($name)) {
            return $Object[$name]
        }

        $property = $Object.PSObject.Properties |
            Where-Object { $_.Name -ieq $name } |
            Select-Object -First 1
        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $null
}

function Convert-ToLongOrNull([object] $Value) {
    if ($null -eq $Value) {
        return $null
    }

    try {
        if ($Value -is [string]) {
            $clean = $Value.Trim().Replace(",", "")
            if ([string]::IsNullOrWhiteSpace($clean)) {
                return $null
            }
            $parsedDecimal = [decimal]::Zero
            if ([decimal]::TryParse($clean, [System.Globalization.NumberStyles]::Number, [System.Globalization.CultureInfo]::InvariantCulture, [ref] $parsedDecimal)) {
                return [long] [Math]::Round($parsedDecimal)
            }
            return $null
        }
        return [long] [System.Convert]::ToInt64($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $null
    }
}

function Add-NamedValues([object] $Node, [string[]] $Names, [System.Collections.Generic.List[object]] $Values) {
    if ($null -eq $Node -or (Test-ScalarLike $Node)) {
        return
    }

    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in $Node.Keys) {
            $value = $Node[$key]
            if (@($Names | Where-Object { $_ -ieq ([string] $key) }).Count -gt 0) {
                [void] $Values.Add($value)
            }
            Add-NamedValues $value $Names $Values
        }
        return
    }

    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($item in $Node) {
            Add-NamedValues $item $Names $Values
        }
        return
    }

    foreach ($property in $Node.PSObject.Properties) {
        if (@($Names | Where-Object { $_ -ieq $property.Name }).Count -gt 0) {
            [void] $Values.Add($property.Value)
        }
        Add-NamedValues $property.Value $Names $Values
    }
}

function Find-NamedValues([object] $Node, [string[]] $Names) {
    $values = New-Object System.Collections.Generic.List[object]
    Add-NamedValues $Node $Names $values
    return $values.ToArray()
}

function Get-StateText([object] $Object) {
    $value = Get-ObjectPropertyValue $Object @("state", "status", "health", "online")
    if ($null -eq $value) {
        return ""
    }
    if ($value -is [bool]) {
        return $(if ($value) { "online" } else { "offline" })
    }
    return ([string] $value).Trim()
}

function Test-OnlineState([string] $State) {
    if ([string]::IsNullOrWhiteSpace($State)) {
        return $false
    }
    return $State -match "(?i)^(online|ok|up|healthy|ready|running)$"
}

function Get-CapacityValue([object] $Object, [string[]] $Names) {
    return Convert-ToLongOrNull (Get-ObjectPropertyValue $Object $Names)
}

function Get-DriveSummary([object] $Drive, [int] $Index) {
    $path = Get-ObjectPropertyValue $Drive @("path", "endpoint", "name", "id", "uuid")
    if ([string]::IsNullOrWhiteSpace([string] $path)) {
        $path = "drive-$Index"
    }

    $total = Get-CapacityValue $Drive @("totalspace", "totalSpace", "total", "capacity", "size", "rawCapacity", "rawCapacityBytes", "totalBytes")
    $used = Get-CapacityValue $Drive @("usedspace", "usedSpace", "used", "usedBytes")
    $free = Get-CapacityValue $Drive @("availspace", "availableSpace", "availSpace", "free", "freeSpace", "freeBytes")

    if ($null -eq $used -and $null -ne $total -and $null -ne $free) {
        $used = [Math]::Max(0, $total - $free)
    }
    if ($null -eq $free -and $null -ne $total -and $null -ne $used) {
        $free = [Math]::Max(0, $total - $used)
    }

    return [pscustomobject][ordered]@{
        path = [string] $path
        state = (Get-StateText $Drive)
        totalBytes = $total
        usedBytes = $used
        freeBytes = $free
    }
}

function Get-ServerSummaries([object] $ParsedAdminInfo) {
    $serverValues = Find-NamedValues $ParsedAdminInfo @("servers", "nodes")
    $rawServers = Normalize-Array $serverValues | Where-Object { -not (Test-ScalarLike $_) }
    $servers = @()
    $seen = @{}
    $index = 0

    foreach ($server in $rawServers) {
        $endpoint = Get-ObjectPropertyValue $server @("endpoint", "address", "host", "name", "id")
        if ([string]::IsNullOrWhiteSpace([string] $endpoint)) {
            $endpoint = "server-$index"
        }

        $poolId = Get-ObjectPropertyValue $server @("poolNumber", "pool", "poolId", "poolID", "poolIndex")
        if ([string]::IsNullOrWhiteSpace([string] $poolId)) {
            $poolId = "unknown"
        }

        $dedupeKey = "$poolId|$endpoint"
        if ($seen.ContainsKey($dedupeKey)) {
            continue
        }
        $seen[$dedupeKey] = $true

        $driveValues = Find-NamedValues $server @("drives", "disks")
        $rawDrives = Normalize-Array $driveValues | Where-Object { -not (Test-ScalarLike $_) }
        $driveSummaries = @()
        $driveIndex = 0
        foreach ($drive in $rawDrives) {
            $driveSummaries += (Get-DriveSummary $drive $driveIndex)
            $driveIndex += 1
        }

        $total = 0L
        $used = 0L
        $free = 0L
        foreach ($driveSummary in $driveSummaries) {
            if ($null -ne $driveSummary.totalBytes) { $total += $driveSummary.totalBytes }
            if ($null -ne $driveSummary.usedBytes) { $used += $driveSummary.usedBytes }
            if ($null -ne $driveSummary.freeBytes) { $free += $driveSummary.freeBytes }
        }

        if ($driveSummaries.Count -eq 0) {
            $serverTotal = Get-CapacityValue $server @("totalspace", "totalSpace", "total", "capacity", "rawCapacity", "rawCapacityBytes", "totalBytes")
            $serverUsed = Get-CapacityValue $server @("usedspace", "usedSpace", "used", "usedBytes")
            $serverFree = Get-CapacityValue $server @("availspace", "availableSpace", "availSpace", "free", "freeSpace", "freeBytes")
            if ($null -ne $serverTotal) { $total = $serverTotal }
            if ($null -ne $serverUsed) { $used = $serverUsed }
            if ($null -ne $serverFree) { $free = $serverFree }
            if ($null -eq $serverUsed -and $null -ne $serverTotal -and $null -ne $serverFree) { $used = [Math]::Max(0, $serverTotal - $serverFree) }
            if ($null -eq $serverFree -and $null -ne $serverTotal -and $null -ne $serverUsed) { $free = [Math]::Max(0, $serverTotal - $serverUsed) }
        }

        $state = Get-StateText $server
        $servers += [pscustomobject][ordered]@{
            endpoint = [string] $endpoint
            poolId = [string] $poolId
            state = $state
            online = (Test-OnlineState $state)
            driveCount = $driveSummaries.Count
            totalBytes = $total
            usedBytes = $used
            freeBytes = $free
            drives = @($driveSummaries)
        }
        $index += 1
    }

    return @($servers)
}

foreach ($entry in @(
    @("EnvironmentName", $EnvironmentName),
    @("TargetCluster", $TargetCluster),
    @("Operator", $Operator),
    @("MinioAlias", $MinioAlias),
    @("EvidenceRef", $EvidenceRef),
    @("AdminInfoJsonPath", $AdminInfoJsonPath),
    @("McCommand", $McCommand)
)) {
    Assert-SafeText ([string] $entry[1]) ([string] $entry[0])
}

$hasTelemetryInput = -not [string]::IsNullOrWhiteSpace($AdminInfoJsonPath) -or -not [string]::IsNullOrWhiteSpace($AdminInfoJson) -or [bool] $Execute
$sourceMode = "plan-only"
$sourceRef = ""
$adminInfoText = ""
$parseError = ""
$parsed = $null
$serverSummaries = @()
$poolSummaries = @()

if ([bool] $Execute) {
    if ([string]::IsNullOrWhiteSpace($MinioAlias)) {
        throw "MinioAlias is required with -Execute."
    }
    $sourceMode = "mc-admin-info-execute"
    $sourceRef = "mc admin info $MinioAlias --json"
    $result = Invoke-CommandWithTimeout $McCommand @("admin", "info", $MinioAlias, "--json") $McTimeoutSeconds
    if ($result.exitCode -ne 0) {
        throw "mc admin info failed with exit code $($result.exitCode). Output: $($result.output)"
    }
    $adminInfoText = $result.output
}
elseif (-not [string]::IsNullOrWhiteSpace($AdminInfoJsonPath)) {
    $resolvedAdminInfoJsonPath = Resolve-ProjectPath $AdminInfoJsonPath
    if (-not (Test-Path -LiteralPath $resolvedAdminInfoJsonPath)) {
        throw "Admin info JSON path not found: $resolvedAdminInfoJsonPath"
    }
    $sourceMode = "admin-info-json-path"
    $sourceRef = $resolvedAdminInfoJsonPath
    $adminInfoText = Read-Utf8Text $resolvedAdminInfoJsonPath
}
elseif (-not [string]::IsNullOrWhiteSpace($AdminInfoJson)) {
    $sourceMode = "inline-admin-info-json"
    $sourceRef = "inline"
    $adminInfoText = $AdminInfoJson
}

$adminInfoSha256 = Get-Sha256Hex $adminInfoText

if ($hasTelemetryInput) {
    Assert-SafeText $adminInfoText "AdminInfoJson"
    try {
        $parsed = $adminInfoText | ConvertFrom-Json
    }
    catch {
        $parseError = $_.Exception.Message
    }

    if ($null -ne $parsed) {
        $serverSummaries = Get-ServerSummaries $parsed
        $poolIds = @($serverSummaries | ForEach-Object { $_.poolId } | Select-Object -Unique)
        foreach ($poolId in $poolIds) {
            $serversInPool = @($serverSummaries | Where-Object { $_.poolId -eq $poolId })
            $poolTotal = 0L
            $poolUsed = 0L
            $poolFree = 0L
            $poolDriveCount = 0
            foreach ($server in $serversInPool) {
                $poolTotal += $server.totalBytes
                $poolUsed += $server.usedBytes
                $poolFree += $server.freeBytes
                $poolDriveCount += $server.driveCount
            }
            $poolSummaries += [pscustomobject][ordered]@{
                poolId = [string] $poolId
                serverCount = $serversInPool.Count
                onlineServerCount = @($serversInPool | Where-Object { $_.online }).Count
                driveCount = $poolDriveCount
                totalBytes = $poolTotal
                usedBytes = $poolUsed
                freeBytes = $poolFree
            }
        }
    }
}

$serverCount = @($serverSummaries).Count
$onlineServerCount = @($serverSummaries | Where-Object { $_.online }).Count
$offlineServerCount = $serverCount - $onlineServerCount
$driveCount = 0
$totalBytes = 0L
$usedBytes = 0L
$freeBytes = 0L
foreach ($server in $serverSummaries) {
    $driveCount += $server.driveCount
    $totalBytes += $server.totalBytes
    $usedBytes += $server.usedBytes
    $freeBytes += $server.freeBytes
}
$capacityKnown = $totalBytes -gt 0

if (-not $hasTelemetryInput) {
    Add-PlannedCheck "admin-info-input" "MinIO admin info input available" "Provide -AdminInfoJsonPath, -AdminInfoJson, or -Execute with -MinioAlias."
    Add-PlannedCheck "pool-node-summary" "Pool/node telemetry summarized" "No telemetry input was parsed."
    Add-PlannedCheck "capacity-summary" "Capacity telemetry summarized" "No capacity telemetry was parsed."
}
else {
    Add-Check "environment-name" "Environment name recorded" (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) "environmentName=$EnvironmentName"
    Add-Check "target-cluster" "Target cluster recorded" (-not [string]::IsNullOrWhiteSpace($TargetCluster)) "targetCluster=$TargetCluster"
    Add-Check "operator" "Operator recorded" (-not [string]::IsNullOrWhiteSpace($Operator)) "operator=$Operator"
    Add-Check "evidence-ref" "External evidence reference recorded" (-not [string]::IsNullOrWhiteSpace($EvidenceRef)) "evidenceRef=$EvidenceRef"
    Add-Check "admin-info-json-parse" "MinIO admin info JSON parsed" ($null -ne $parsed) "sourceMode=$sourceMode; parseError=$parseError"
    Add-Check "server-telemetry" "Server/node telemetry found" ($serverCount -gt 0) "serverCount=$serverCount"
    Add-Check "pool-telemetry" "Pool grouping found or inferred" (@($poolSummaries).Count -gt 0) "poolCount=$(@($poolSummaries).Count)"
    Add-Check "drive-telemetry" "Drive telemetry found" ($driveCount -gt 0) "driveCount=$driveCount"
    Add-Check "server-health" "All reported servers are online" ($serverCount -gt 0 -and $offlineServerCount -eq 0) "onlineServerCount=$onlineServerCount; offlineServerCount=$offlineServerCount"
    Add-Check "capacity-telemetry" "Capacity telemetry found" $capacityKnown "totalBytes=$totalBytes; usedBytes=$usedBytes; freeBytes=$freeBytes"
    Add-Check "raw-admin-info-policy" "Raw admin info omitted from report" $true "Only summary, SHA-256, and external references are stored."
}

$failureCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$plannedCount = @($checks | Where-Object { $_.status -eq "PLANNED" }).Count
$result = if (-not $hasTelemetryInput) {
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

$report = New-Object System.Collections.Specialized.OrderedDictionary
[void] $report.Add("formatVersion", "osmu.storage-backend-telemetry.v1")
[void] $report.Add("generatedAt", $generatedAt)
[void] $report.Add("result", $result)
[void] $report.Add("environmentName", $EnvironmentName)
[void] $report.Add("targetCluster", $TargetCluster)
[void] $report.Add("operatorName", $Operator)
[void] $report.Add("source", [ordered]@{
    mode = $sourceMode
    minioAlias = $MinioAlias
    evidenceRef = $EvidenceRef
    sourceRef = $sourceRef
    adminInfoJsonSha256 = $adminInfoSha256
    rawAdminInfoStored = $false
    executeRequested = [bool] $Execute
    mcTimeoutSeconds = $McTimeoutSeconds
})
[void] $report.Add("summary", [ordered]@{
    poolCount = @($poolSummaries).Count
    serverCount = $serverCount
    onlineServerCount = $onlineServerCount
    offlineServerCount = $offlineServerCount
    driveCount = $driveCount
    totalBytes = $totalBytes
    usedBytes = $usedBytes
    freeBytes = $freeBytes
    capacityKnown = $capacityKnown
    failureCount = $failureCount
    plannedCount = $plannedCount
})
[void] $report.Add("pools", [object] @($poolSummaries))
[void] $report.Add("servers", [object] @($serverSummaries | ForEach-Object {
    [ordered]@{
        endpoint = $_.endpoint
        poolId = $_.poolId
        state = $_.state
        online = $_.online
        driveCount = $_.driveCount
        totalBytes = $_.totalBytes
        usedBytes = $_.usedBytes
        freeBytes = $_.freeBytes
    }
}))
[void] $report.Add("checks", [object] @($checks | ForEach-Object { $_ }))
[void] $report.Add("decisionRule", "Storage backend telemetry evidence passes when target environment, cluster, operator, external evidence reference, MinIO admin-info JSON parsing, pool/server/drive summaries, online server state, and capacity totals are all present.")
[void] $report.Add("scopePolicy", "This evidence captures MinIO pool/node operations telemetry for OSMU storage readiness. It is not AWS S3 parity work, and it does not store raw admin info, credentials, bearer tokens, private keys, kubeconfig, MinIO root credentials, or object data.")
[void] $report.Add("operatorCommands", [ordered]@{
    collectWithMc = "mc admin info <alias> --json > .\.osmu-run\minio-admin-info.json"
    recordFromFile = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-storage-backend-telemetry-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -MinioAlias <alias> -EvidenceRef <change-or-run-ref> -AdminInfoJsonPath .\.osmu-run\minio-admin-info.json -FailIfNotPassed"
    collectAndRecord = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-storage-backend-telemetry-evidence.ps1 -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -MinioAlias <alias> -EvidenceRef <change-or-run-ref> -Execute -FailIfNotPassed"
})

$markdownLines = @(
    "# OSMU Storage Backend Telemetry Evidence",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Environment: $EnvironmentName",
    "Target cluster: $TargetCluster",
    "Operator: $Operator",
    "Source mode: $sourceMode",
    "Evidence ref: $EvidenceRef",
    "Raw admin info stored: false",
    "",
    "## Summary",
    "",
    "- Pools: $(@($poolSummaries).Count)",
    "- Servers: $serverCount",
    "- Online servers: $onlineServerCount",
    "- Offline servers: $offlineServerCount",
    "- Drives: $driveCount",
    "- Total bytes: $totalBytes",
    "- Used bytes: $usedBytes",
    "- Free bytes: $freeBytes",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Scope Policy",
    "",
    $report.scopePolicy,
    "",
    "## Pools",
    ""
)

foreach ($pool in $poolSummaries) {
    $markdownLines += "- Pool $($pool.poolId): servers=$($pool.serverCount), online=$($pool.onlineServerCount), drives=$($pool.driveCount), totalBytes=$($pool.totalBytes), usedBytes=$($pool.usedBytes), freeBytes=$($pool.freeBytes)"
}

if (@($poolSummaries).Count -eq 0) {
    $markdownLines += "- No pool telemetry summarized."
}

$markdownLines += ""
$markdownLines += "## Servers"
$markdownLines += ""
foreach ($server in $serverSummaries) {
    $markdownLines += "- $($server.endpoint): pool=$($server.poolId), state=$($server.state), drives=$($server.driveCount), totalBytes=$($server.totalBytes), usedBytes=$($server.usedBytes), freeBytes=$($server.freeBytes)"
}

if (@($serverSummaries).Count -eq 0) {
    $markdownLines += "- No server telemetry summarized."
}

$markdownLines += ""
$markdownLines += "## Checks"
$markdownLines += ""
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.name): $($check.detail)"
}

$markdownLines += ""
$markdownLines += "## Operator Commands"
$markdownLines += ""
$markdownLines += "- Collect admin info: ``$($report.operatorCommands.collectWithMc)``"
$markdownLines += "- Record from file: ``$($report.operatorCommands.recordFromFile)``"
$markdownLines += "- Collect and record: ``$($report.operatorCommands.collectAndRecord)``"

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Storage backend telemetry JSON: $resolvedJsonOutputPath"
    Write-Host "Storage backend telemetry markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "Storage backend telemetry evidence did not pass: result=$result failureCount=$failureCount"
}
