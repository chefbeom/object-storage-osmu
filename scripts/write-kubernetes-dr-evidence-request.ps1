param(
    [string] $DrEvidencePath = ".\.osmu-run\latest-kubernetes-dr-drill.json",
    [string] $ArtifactEvidencePath = ".\.osmu-run\latest-kubernetes-backup-artifacts.json",
    [string] $DrBucketBootstrapEvidencePath = ".\.osmu-run\latest-kubernetes-dr-bucket-bootstrap.json",
    [string] $DrBucketImmutabilityEvidencePath = ".\.osmu-run\latest-kubernetes-dr-bucket-immutability.json",
    [string] $SmokeEvidencePath = ".\.osmu-run\latest-kubernetes-restore-smoke.json",
    [string] $OutputPath = ".\.osmu-run\latest-kubernetes-dr-evidence-request.json",
    [string] $Environment = "kubernetes-drill",
    [string] $Operator = "",
    [string] $Result = "AUTO",
    [long] $MetadataRowCount = -1,
    [long] $ObjectCount = -1,
    [long] $ObjectBytes = -1,
    [string] $EvidenceUri = "",
    [string] $ApiBase = "",
    [string] $AdminLoginId = "",
    [string] $AdminPassword = "",
    [switch] $ConfirmSuccessfulRestore,
    [switch] $PostRestoreSmokeVerified,
    [switch] $Submit,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-JsonFile([string] $path, [string] $label) {
    $resolved = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "$label not found: $resolved"
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $resolved | ConvertFrom-Json
}

function Convert-BackupTimestampToIso([string] $value) {
    if (-not $value -or $value -eq "YYYYMMDDTHHMMSSZ") {
        throw "A real backup timestamp is required."
    }
    if ($value -match "^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$") {
        return "$($Matches[1])-$($Matches[2])-$($Matches[3])T$($Matches[4]):$($Matches[5]):$($Matches[6])+00:00"
    }
    try {
        return ([DateTimeOffset]::Parse($value)).ToString("o")
    }
    catch {
        throw "backupTimestamp must be ISO-8601 or YYYYMMDDTHHMMSSZ: $value"
    }
}

function Convert-ToIsoOrNow([string] $value) {
    if ($value) {
        try {
            return ([DateTimeOffset]::Parse($value)).ToString("o")
        }
        catch {
            throw "Invalid ISO-8601 timestamp: $value"
        }
    }
    return [DateTimeOffset]::UtcNow.ToString("o")
}

function Get-ArtifactLogText([object] $artifactEvidence) {
    $texts = @()
    if ($null -ne $artifactEvidence.job -and $null -ne $artifactEvidence.job.logs) {
        foreach ($log in @($artifactEvidence.job.logs)) {
            if ($null -ne $log.output) {
                $texts += "$($log.output)"
            }
        }
    }
    return ($texts -join [Environment]::NewLine)
}

function Get-LogValue([string] $text, [string] $name) {
    if (-not $text) {
        return $null
    }
    $pattern = "(?m)^" + [regex]::Escape($name) + "=(.+)$"
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value.Trim()
}

function Get-LongOrDefault([object] $value, [long] $defaultValue) {
    if ($null -eq $value -or "$value" -eq "") {
        return $defaultValue
    }
    try {
        return [long] $value
    }
    catch {
        return $defaultValue
    }
}

function Normalize-RequestedResult([string] $value) {
    $normalized = if ($value) { $value.Trim().ToUpperInvariant() } else { "AUTO" }
    if (@("AUTO", "SUCCESS", "FAILED", "PARTIAL") -notcontains $normalized) {
        throw "Result must be AUTO, SUCCESS, FAILED, or PARTIAL."
    }
    return $normalized
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

if ($PlanOnly) {
    Write-Host "Kubernetes DR evidence request plan only."
    Write-Host "DR evidence: $DrEvidencePath"
    Write-Host "Artifact evidence: $ArtifactEvidencePath"
    Write-Host "DR bucket bootstrap evidence: $DrBucketBootstrapEvidencePath"
    Write-Host "DR bucket immutability evidence: $DrBucketImmutabilityEvidencePath"
    Write-Host "Restore smoke evidence: $SmokeEvidencePath"
    Write-Host "Output request: $OutputPath"
    Write-Host "Environment: $Environment"
    Write-Host "Result mode: $Result"
    Write-Host "Submit to API: $Submit"
    Write-Host "Success requires -ConfirmSuccessfulRestore, a live confirmed restore, explicit -MetadataRowCount, object evidence, required DR bucket bootstrap/immutability evidence for external transfer, and either -PostRestoreSmokeVerified or passed restore smoke evidence."
    Write-Host "Plan only; no evidence files read, no request written, and no API call made."
    return
}

$drEvidence = Read-JsonFile $DrEvidencePath "Kubernetes DR drill evidence"
$artifactEvidence = $null
$artifactLogText = ""
if (Test-Path -LiteralPath (Resolve-ProjectPath $ArtifactEvidencePath)) {
    $artifactEvidence = Read-JsonFile $ArtifactEvidencePath "Kubernetes backup artifact evidence"
    $artifactLogText = Get-ArtifactLogText $artifactEvidence
}
$drBucketBootstrapEvidence = $null
if (Test-Path -LiteralPath (Resolve-ProjectPath $DrBucketBootstrapEvidencePath)) {
    $drBucketBootstrapEvidence = Read-JsonFile $DrBucketBootstrapEvidencePath "Kubernetes DR bucket bootstrap evidence"
}
$drBucketImmutabilityEvidence = $null
if (Test-Path -LiteralPath (Resolve-ProjectPath $DrBucketImmutabilityEvidencePath)) {
    $drBucketImmutabilityEvidence = Read-JsonFile $DrBucketImmutabilityEvidencePath "Kubernetes DR bucket immutability evidence"
}
$smokeEvidence = $null
if (Test-Path -LiteralPath (Resolve-ProjectPath $SmokeEvidencePath)) {
    $smokeEvidence = Read-JsonFile $SmokeEvidencePath "Kubernetes restore smoke evidence"
}

$smokeEvidenceApiPassed = [bool]($null -ne $smokeEvidence -and "$($smokeEvidence.result)" -eq "passed" -and ([bool] $smokeEvidence.apiSmokePassed))
$smokeEvidenceS3Passed = [bool]($null -ne $smokeEvidence -and $null -ne $smokeEvidence.s3ClientSmoke -and "$($smokeEvidence.s3ClientSmoke.status)" -eq "PASS")
$postRestoreSmokeVerified = [bool]($PostRestoreSmokeVerified -or ($smokeEvidenceApiPassed -and $smokeEvidenceS3Passed))

$gaps = @()
if ($drEvidence.result -ne "passed") {
    $gaps += "Kubernetes DR drill wrapper did not pass."
}
if ($drEvidence.serverDryRunOnly) {
    $gaps += "Kubernetes DR drill was server-side dry-run only."
}
if (-not $drEvidence.confirmRestore) {
    $gaps += "Restore Job was not explicitly confirmed and executed by the DR wrapper."
}
if (-not $postRestoreSmokeVerified) {
    $gaps += "Post-restore API and S3 smoke verification was not confirmed."
}
$drBucketBootstrapRequired = [bool]([bool] $drEvidence.bootstrapDrBucket)
$drBucketBootstrapPassed = [bool]($null -ne $drBucketBootstrapEvidence -and "$($drBucketBootstrapEvidence.result)" -eq "passed")
if ($drBucketBootstrapRequired -and $null -eq $drBucketBootstrapEvidence) {
    $gaps += "External DR bucket bootstrap evidence file was not found."
}
elseif ($drBucketBootstrapRequired -and (-not $drBucketBootstrapPassed)) {
    $gaps += "External DR bucket bootstrap did not pass."
}
$drBucketImmutabilityRequired = [bool]([bool] $drEvidence.transferArtifacts -or [bool] $drEvidence.verifyDrBucketImmutability)
$drBucketImmutabilityPassed = [bool]($null -ne $drBucketImmutabilityEvidence -and "$($drBucketImmutabilityEvidence.result)" -eq "passed")
if ($drBucketImmutabilityRequired -and $null -eq $drBucketImmutabilityEvidence) {
    $gaps += "External DR bucket immutability evidence file was not found."
}
elseif ($drBucketImmutabilityRequired -and (-not $drBucketImmutabilityPassed)) {
    $gaps += "External DR bucket immutability preflight did not pass."
}
if ($MetadataRowCount -lt 0) {
    $gaps += "MariaDB metadata row count was not provided for Kubernetes DR evidence."
}
if ($null -eq $artifactEvidence) {
    $gaps += "Kubernetes backup artifact evidence file was not found."
}
elseif ($artifactEvidence.result -ne "passed") {
    $gaps += "Kubernetes backup artifact preflight did not pass."
}

$logObjectCount = Get-LongOrDefault (Get-LogValue $artifactLogText "OSMU_BACKUP_ARTIFACT_OBJECT_COUNT") -1
$logObjectBytes = Get-LongOrDefault (Get-LogValue $artifactLogText "OSMU_BACKUP_ARTIFACT_OBJECT_BYTES") -1
$logMetadataSha = Get-LogValue $artifactLogText "OSMU_BACKUP_ARTIFACT_METADATA_SHA256"

$effectiveMetadataRowCount = if ($MetadataRowCount -ge 0) { $MetadataRowCount } else { 0L }
$effectiveObjectCount = if ($ObjectCount -ge 0) { $ObjectCount } elseif ($logObjectCount -ge 0) { $logObjectCount } else { 0L }
$effectiveObjectBytes = if ($ObjectBytes -ge 0) { $ObjectBytes } elseif ($logObjectBytes -ge 0) { $logObjectBytes } else { 0L }

$requestedResult = Normalize-RequestedResult $Result
$artifactEvidencePassed = [bool]($null -ne $artifactEvidence -and "$($artifactEvidence.result)" -eq "passed")
$objectEvidenceAvailable = [bool]($artifactEvidencePassed -or ($ObjectCount -ge 0 -and $ObjectBytes -ge 0))
$canMarkSuccess = [bool](
    ($ConfirmSuccessfulRestore) `
        -and ($postRestoreSmokeVerified) `
        -and ([bool] $drEvidence.confirmRestore) `
        -and (-not ([bool] $drEvidence.serverDryRunOnly)) `
        -and ("$($drEvidence.result)" -eq "passed") `
        -and ((-not $drBucketBootstrapRequired) -or $drBucketBootstrapPassed) `
        -and ((-not $drBucketImmutabilityRequired) -or $drBucketImmutabilityPassed) `
        -and ($MetadataRowCount -ge 0) `
        -and ($objectEvidenceAvailable)
)

$effectiveResult = $requestedResult
if ($requestedResult -eq "AUTO") {
    if ($drEvidence.result -ne "passed") {
        $effectiveResult = "FAILED"
    }
    elseif ($canMarkSuccess -and $gaps.Count -eq 0) {
        $effectiveResult = "SUCCESS"
    }
    else {
        $effectiveResult = "PARTIAL"
    }
}
elseif ($requestedResult -eq "SUCCESS" -and (-not $canMarkSuccess)) {
    throw "SUCCESS requires -ConfirmSuccessfulRestore, -PostRestoreSmokeVerified, live confirmed restore evidence, required DR bucket bootstrap/immutability evidence, and explicit -MetadataRowCount."
}

$startedAt = Convert-ToIsoOrNow "$($drEvidence.startedAt)"
$completedAt = Convert-ToIsoOrNow "$($drEvidence.completedAt)"
$backupTimestamp = Convert-BackupTimestampToIso "$($drEvidence.backupTimestamp)"
$effectiveOperator = if ($Operator) { $Operator } elseif ($AdminLoginId) { $AdminLoginId } else { "kubernetes-operator" }
$effectiveEvidenceUri = if ($EvidenceUri) { $EvidenceUri } else { $DrEvidencePath }

$requestBody = [ordered]@{
    environment = $Environment
    operator = $effectiveOperator
    result = $effectiveResult
    startedAt = $startedAt
    completedAt = $completedAt
    backupTimestamp = $backupTimestamp
    metadataRowCount = $effectiveMetadataRowCount
    objectCount = $effectiveObjectCount
    objectBytes = $effectiveObjectBytes
    backupManifestSha256 = $null
    evidenceUri = $effectiveEvidenceUri
    gaps = $gaps
}

$resolvedOutputPath = Resolve-ProjectPath $OutputPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
$requestBody | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

if ($Submit) {
    if (-not $ApiBase -or -not $AdminLoginId -or -not $AdminPassword) {
        throw "-Submit requires -ApiBase, -AdminLoginId, and -AdminPassword."
    }
    $login = Invoke-Json "POST" "$ApiBase/auth/login" @{
        loginId = $AdminLoginId
        password = $AdminPassword
    }
    $token = $login.data.accessToken
    if (-not $token) {
        throw "Admin login did not return accessToken."
    }
    Invoke-Json "POST" "$ApiBase/admin/backup/restore-drill-evidence" $requestBody $token | Out-Null
}

Write-Host "Kubernetes DR evidence request written."
Write-Host "Request: $resolvedOutputPath"
Write-Host "Result:  $effectiveResult"
Write-Host "Gaps:    $($gaps.Count)"
if ($Submit) {
    Write-Host "Submitted to: $ApiBase/admin/backup/restore-drill-evidence"
}
