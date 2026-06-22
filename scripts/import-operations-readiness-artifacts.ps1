param(
    [string] $StorageExpansionArtifactPath = "",
    [string] $HaDrReadinessArtifactPath = "",
    [string] $KubernetesDrArtifactPath = "",
    [string] $IamRbacArtifactPath = "",
    [string] $SecurityEvidenceArtifactPath = "",
    [string] $StorageBackendTelemetryArtifactPath = "",
    [string] $MonitoringThresholdArtifactPath = "",
    [string] $SecretRotationArtifactPath = "",
    [string] $CommercialIntegrationArtifactPath = "",
    [string] $CommercialApprovalArtifactPath = "",
    [string] $EnterpriseAuthArtifactPath = "",
    [string] $OperationsHandoffPackageArtifactPath = "",
    [string] $KubernetesOperationsReportSyncArtifactPath = "",
    [string] $DataFlowStoragePlanArtifactPath = "",
    [string] $DataFlowStorageTransitionRunbookArtifactPath = "",
    [string] $OutputDirectory = ".\.osmu-run",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-readiness-artifact-import.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-readiness-artifact-import.md"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$entries = @()

function Resolve-ProjectPath([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        return ""
    }
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Add-Entry(
    [string] $Group,
    [string] $FileName,
    [string] $Status,
    [string] $Detail,
    [string] $SourcePath = "",
    [string] $DestinationPath = ""
) {
    $script:entries += [ordered]@{
        group = $Group
        fileName = $FileName
        status = $Status
        passed = $Status -in @("imported", "skipped")
        detail = $Detail
        sourcePath = $SourcePath
        destinationPath = $DestinationPath
    }
}

function Find-EvidenceFile([string] $SourceRoot, [string] $FileName, [string] $Group) {
    if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
        return $null
    }

    $resolvedSourceRoot = Resolve-ProjectPath $SourceRoot
    if (-not (Test-Path -LiteralPath $resolvedSourceRoot)) {
        Add-Entry $Group $FileName "failed" "artifact path not found" $resolvedSourceRoot ""
        return $null
    }

    $directPath = Join-Path $resolvedSourceRoot $FileName
    if (Test-Path -LiteralPath $directPath) {
        return (Resolve-Path -LiteralPath $directPath).Path
    }

    $matches = @(Get-ChildItem -LiteralPath $resolvedSourceRoot -Recurse -File -Filter $FileName)
    if ($matches.Count -eq 1) {
        return $matches[0].FullName
    }
    if ($matches.Count -gt 1) {
        Add-Entry $Group $FileName "failed" "multiple matching files found under artifact path" $resolvedSourceRoot ""
        return $null
    }

    return $null
}

function Get-JsonProperty([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-JsonInt([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return 0
    }
    $parsed = 0
    if ([int]::TryParse(([string] $value), [ref] $parsed)) {
        return $parsed
    }
    return 0
}

function Get-RequiredJsonInt([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return [pscustomobject]@{
            valid = $false
            value = $null
            raw = "<missing>"
        }
    }
    $integerTypeNames = @("Byte", "SByte", "Int16", "UInt16", "Int32", "UInt32", "Int64", "UInt64")
    if ($integerTypeNames -notcontains $value.GetType().Name) {
        return [pscustomobject]@{
            valid = $false
            value = $null
            raw = [string] $value
        }
    }
    try {
        return [pscustomobject]@{
            valid = $true
            value = [int64] $value
            raw = [string] $value
        }
    }
    catch {
        return [pscustomobject]@{
            valid = $false
            value = $null
            raw = [string] $value
        }
    }
}

function Get-RequiredJsonBool([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($value -is [bool]) {
        return [pscustomobject]@{
            valid = $true
            value = [bool] $value
            raw = [string] $value
        }
    }
    return [pscustomobject]@{
        valid = $false
        value = $false
        raw = if ($null -eq $value) { "<missing>" } else { [string] $value }
    }
}

function Test-ReadyText($Value) {
    return "ready".Equals([string] $Value, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-HttpUrl([string] $Value) {
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -match "^https?://"
}

function Test-CommitSha([string] $Value) {
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -match "^[0-9a-fA-F]{40}$" -and $Value -notmatch "^0{40}$"
}

function Test-Digest([string] $Value) {
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -match "^sha256:[0-9a-fA-F]{64}$" -and $Value -notmatch "^sha256:0{64}$"
}

function Test-Sha256([string] $Value) {
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -match "^[0-9a-fA-F]{64}$" -and $Value -notmatch "^0{64}$"
}

function Test-OperationsEvidenceRawContent([string] $Raw, [string] $Label) {
    $patterns = @(
        '(?i)"(password|passwd|secret|token|credential|clientSecret|client_secret|authorization|kubeconfig|privateKey|private_key)"\s*:',
        '(?i)\b(password|passwd|token|credential|client[_-]?secret|authorization|kubeconfig|private[_-]?key)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----',
        '(?i)client-certificate-data\s*:',
        '(?i)client-key-data\s*:'
    )
    foreach ($pattern in $patterns) {
        if ($Raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "$Label evidence contains credential-shaped or kubeconfig content"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "$Label evidence has no credential-shaped content"
    }
}

function Test-EvidenceJson([string] $Path, [string] $ExpectedProperty, [string] $ExpectedValue) {
    try {
        $json = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $actual = [string] (Get-JsonProperty $json $ExpectedProperty)
    $expectedValues = @($ExpectedValue -split "\|" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    return [pscustomobject]@{
        passed = $expectedValues -contains $actual
        detail = "$ExpectedProperty=$actual expected=$($expectedValues -join '|')"
    }
}

function Test-StorageExpansionRbacAuthEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "storage expansion RBAC"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }

    $passed = Get-RequiredJsonBool $json "passed"
    if (-not $passed.valid -or -not $passed.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "passed=$($passed.raw) expected boolean true"
        }
    }

    $failedCount = Get-RequiredJsonInt $json "failedCount"
    if (-not $failedCount.valid -or [int64] $failedCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "failedCount=$($failedCount.raw)(valid=$($failedCount.valid)) expected integer 0"
        }
    }

    foreach ($field in @("namespace", "serviceAccount", "subject", "kubectlPath")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $expectedAllowedCount = Get-RequiredJsonInt $json "expectedAllowedCount"
    $expectedDeniedCount = Get-RequiredJsonInt $json "expectedDeniedCount"
    if (-not $expectedAllowedCount.valid -or [int64] $expectedAllowedCount.value -le 0 -or -not $expectedDeniedCount.valid -or [int64] $expectedDeniedCount.value -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "expectedAllowedCount=$($expectedAllowedCount.raw) expectedDeniedCount=$($expectedDeniedCount.raw) expected positive integers"
        }
    }

    $resultsObject = Get-JsonProperty $json "results"
    $results = if ($null -eq $resultsObject) { @() } else { @($resultsObject) }
    if ($results.Count -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "results missing"
        }
    }

    foreach ($requiredId in @("tenant-get", "tenant-patch", "tenant-update", "secret-get-denied", "pod-exec-denied")) {
        $match = @($results | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredId })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "results.$requiredId missing"
            }
        }
    }

    for ($i = 0; $i -lt $results.Count; $i++) {
        $result = $results[$i]
        $resultPassed = Get-RequiredJsonBool $result "passed"
        if (-not $resultPassed.valid -or -not $resultPassed.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "results[$i].passed=$($resultPassed.raw) expected boolean true"
            }
        }

        $expectedAllowed = Get-RequiredJsonBool $result "expectedAllowed"
        $actualAllowed = Get-RequiredJsonBool $result "actualAllowed"
        if (-not $expectedAllowed.valid -or -not $actualAllowed.valid -or $expectedAllowed.value -ne $actualAllowed.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "results[$i] expectedAllowed=$($expectedAllowed.raw) actualAllowed=$($actualAllowed.raw) expected matching booleans"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "passed=$($passed.value) failedCount=$($failedCount.value) allowed=$($expectedAllowedCount.value) denied=$($expectedDeniedCount.value) resultCount=$($results.Count)"
    }
}

function Test-StorageExpansionServerDryRunEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "storage expansion server dry-run"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }

    $passed = Get-RequiredJsonBool $json "passed"
    if (-not $passed.valid -or -not $passed.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "passed=$($passed.raw) expected boolean true"
        }
    }

    $failedCount = Get-RequiredJsonInt $json "failedCount"
    if (-not $failedCount.valid -or [int64] $failedCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "failedCount=$($failedCount.raw)(valid=$($failedCount.valid)) expected integer 0"
        }
    }

    foreach ($field in @("namespace", "tenantName", "manifestPath", "kubectlPath", "serviceAccount")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    foreach ($field in @("manifestSha256", "effectiveManifestSha256")) {
        $sha = [string] (Get-JsonProperty $json $field)
        if (-not (Test-Sha256 $sha)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field=$sha expected nonzero sha256"
            }
        }
    }

    $impersonateRunner = Get-RequiredJsonBool $json "impersonateRunner"
    if (-not $impersonateRunner.valid -or -not $impersonateRunner.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "impersonateRunner=$($impersonateRunner.raw) expected boolean true"
        }
    }

    $subject = [string] (Get-JsonProperty $json "subject")
    if ([string]::IsNullOrWhiteSpace($subject)) {
        return [pscustomobject]@{
            passed = $false
            detail = "subject missing"
        }
    }

    $resultsObject = Get-JsonProperty $json "results"
    $results = if ($null -eq $resultsObject) { @() } else { @($resultsObject) }
    foreach ($requiredId in @("tenant-crd-present", "existing-tenant-present", "server-side-dry-run")) {
        $match = @($results | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredId })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "results.$requiredId missing"
            }
        }

        $resultPassed = Get-RequiredJsonBool $match[0] "passed"
        $exitCode = Get-RequiredJsonInt $match[0] "exitCode"
        if (-not $resultPassed.valid -or -not $resultPassed.value -or -not $exitCode.valid -or [int64] $exitCode.value -ne 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "results.$requiredId passed=$($resultPassed.raw) exitCode=$($exitCode.raw) expected boolean true and integer 0"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "passed=$($passed.value) failedCount=$($failedCount.value) manifestSha256=$($json.manifestSha256) resultCount=$($results.Count)"
    }
}

function Test-StorageExpansionFinalizeJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.storage-expansion-finalize.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.storage-expansion-finalize.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $failedCount = Get-RequiredJsonInt $json "failedCount"
    if (-not $failedCount.valid -or [int64] $failedCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "failedCount=$($failedCount.raw)(valid=$($failedCount.valid)) expected integer 0"
        }
    }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "storage expansion finalizer"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }

    foreach ($field in @("namespace", "tenantName", "manifestPath", "kubectlPath", "serviceAccount", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $impersonateRunner = Get-RequiredJsonBool $json "impersonateRunner"
    if (-not $impersonateRunner.valid -or -not $impersonateRunner.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "impersonateRunner=$($impersonateRunner.raw) expected boolean true"
        }
    }

    $evidence = Get-JsonProperty $json "evidence"
    foreach ($field in @("rbacAuth", "serverDryRun", "report", "summary")) {
        $value = [string] (Get-JsonProperty $evidence $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "evidence.$field missing"
            }
        }
    }

    $gapsObject = Get-JsonProperty $json "gaps"
    $gaps = if ($null -eq $gapsObject) { @() } else { @($gapsObject) }
    foreach ($gap in $gaps) {
        $gapText = [string] $gap
        if ($gapText -match "RBAC authorization evidence was skipped" -or $gapText -match "Server-side dry-run evidence was skipped") {
            return [pscustomobject]@{
                passed = $false
                detail = "gaps contains required evidence skip: $gapText"
            }
        }
    }

    $stepsObject = Get-JsonProperty $json "steps"
    $steps = if ($null -eq $stepsObject) { @() } else { @($stepsObject) }
    foreach ($requiredStep in @("Storage Expansion RBAC auth evidence", "Storage Expansion server-side dry-run evidence")) {
        $match = @($steps | Where-Object { [string] (Get-JsonProperty $_ "name") -eq $requiredStep })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "steps.$requiredStep missing"
            }
        }

        $stepResult = [string] (Get-JsonProperty $match[0] "result")
        $exitCode = Get-RequiredJsonInt $match[0] "exitCode"
        if ($stepResult -ne "passed" -or -not $exitCode.valid -or [int64] $exitCode.value -ne 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "steps.$requiredStep result=$stepResult exitCode=$($exitCode.raw) expected passed and integer 0"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result failedCount=$($failedCount.value) stepCount=$($steps.Count) namespace=$($json.namespace) tenant=$($json.tenantName)"
    }
}

function Test-SecurityEvidenceRawContent([string] $Raw, [string] $Label) {
    $patterns = @(
        '(?i)"(password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key|registryPassword|registry_password|signingKey|signing_key|cosignPrivateKey|cosign_private_key)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|registry[_-]?password|signing[_-]?key)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($Raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "$Label evidence contains registry credential, signing key, token, or credential-shaped content"
            }
        }
    }

    if ($Raw -match "example\.invalid" -or $Raw -match "self-test") {
        return [pscustomobject]@{
            passed = $false
            detail = "$Label evidence appears synthetic or self-test"
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "$Label evidence has no credential-shaped content"
    }
}

function Test-SecurityEvidenceFinalizerJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.security-evidence-finalize.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.security-evidence-finalize.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $failureCount = Get-RequiredJsonInt $json "failureCount"
    if (-not $failureCount.valid -or [int64] $failureCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "failureCount=$($failureCount.raw)(valid=$($failureCount.valid)) expected integer 0"
        }
    }

    $allowSyntheticEvidence = Get-RequiredJsonBool $json "allowSyntheticEvidence"
    if (-not $allowSyntheticEvidence.valid -or $allowSyntheticEvidence.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "allowSyntheticEvidence=$($allowSyntheticEvidence.raw) expected boolean false"
        }
    }

    $rawValidation = Test-SecurityEvidenceRawContent $raw "security finalizer"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }

    foreach ($field in @("decisionRule", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $source = Get-JsonProperty $json "source"
    foreach ($urlField in @("imageSigningRunUrl", "containerSecurityRunUrl")) {
        $url = [string] (Get-JsonProperty $source $urlField)
        if (-not (Test-HttpUrl $url)) {
            return [pscustomobject]@{
                passed = $false
                detail = "source.$urlField=$url expected http(s) URL"
            }
        }
    }

    $artifactName = [string] (Get-JsonProperty $source "containerSecurityArtifactName")
    if ([string]::IsNullOrWhiteSpace($artifactName)) {
        return [pscustomobject]@{
            passed = $false
            detail = "source.containerSecurityArtifactName missing"
        }
    }

    $images = Get-JsonProperty $json "images"
    foreach ($field in @("backendVersionRef", "backendShaRef", "frontendVersionRef", "frontendShaRef", "backendImage", "frontendImage")) {
        $value = [string] (Get-JsonProperty $images $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "images.$field missing"
            }
        }
    }

    foreach ($field in @("backendDigest", "frontendDigest")) {
        $digest = [string] (Get-JsonProperty $images $field)
        if (-not (Test-Digest $digest)) {
            return [pscustomobject]@{
                passed = $false
                detail = "images.$field=$digest expected nonzero sha256 digest"
            }
        }
    }

    $promoted = Get-JsonProperty $json "promoted"
    foreach ($field in @("imageSigningEvidence", "containerSecurityEvidence")) {
        $value = [string] (Get-JsonProperty $promoted $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "promoted.$field missing"
            }
        }
    }

    $actionsObject = Get-JsonProperty $promoted "actions"
    $actions = if ($null -eq $actionsObject) { @() } else { @($actionsObject) }
    if ($actions.Count -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "promoted.actions missing"
        }
    }
    foreach ($action in $actions) {
        $actionText = [string] $action
        if ([string]::IsNullOrWhiteSpace($actionText) -or $actionText -match "promotion disabled" -or $actionText -match "promotion skipped") {
            return [pscustomobject]@{
                passed = $false
                detail = "promoted.actions contains invalid promotion action: $actionText"
            }
        }
    }

    $checksObject = Get-JsonProperty $json "checks"
    $checks = if ($null -eq $checksObject) { @() } else { @($checksObject) }
    if ($checks.Count -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "checks missing"
        }
    }
    for ($i = 0; $i -lt $checks.Count; $i++) {
        $check = $checks[$i]
        $passed = Get-RequiredJsonBool $check "passed"
        if (-not $passed.valid -or -not $passed.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks[$i].passed=$($passed.raw) expected boolean true"
            }
        }

        $status = [string] (Get-JsonProperty $check "status")
        if ($status -ne "PASS") {
            return [pscustomobject]@{
                passed = $false
                detail = "checks[$i].status=$status expected PASS"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result failureCount=$($failureCount.value) checkCount=$($checks.Count) backendDigest=$($images.backendDigest) frontendDigest=$($images.frontendDigest)"
    }
}

function Test-ImageSigningEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.image-signing-evidence.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.image-signing-evidence.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $failureCount = Get-RequiredJsonInt $json "failureCount"
    if (-not $failureCount.valid -or [int64] $failureCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "failureCount=$($failureCount.raw)(valid=$($failureCount.valid)) expected integer 0"
        }
    }

    $rawValidation = Test-SecurityEvidenceRawContent $raw "image signing"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }

    $sourceRunUrl = [string] (Get-JsonProperty $json "sourceRunUrl")
    if (-not (Test-HttpUrl $sourceRunUrl)) {
        return [pscustomobject]@{
            passed = $false
            detail = "sourceRunUrl=$sourceRunUrl expected http(s) URL"
        }
    }

    $commitSha = [string] (Get-JsonProperty $json "commitSha")
    if (-not (Test-CommitSha $commitSha)) {
        return [pscustomobject]@{
            passed = $false
            detail = "commitSha=$commitSha expected nonzero 40-char SHA"
        }
    }

    foreach ($field in @("version", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    foreach ($imageName in @("backend", "frontend")) {
        $image = Get-JsonProperty $json $imageName
        foreach ($refField in @("versionRef", "shaRef")) {
            $ref = [string] (Get-JsonProperty $image $refField)
            if ([string]::IsNullOrWhiteSpace($ref)) {
                return [pscustomobject]@{
                    passed = $false
                    detail = "$imageName.$refField missing"
                }
            }
        }

        $digest = [string] (Get-JsonProperty $image "digest")
        if (-not (Test-Digest $digest)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$imageName.digest=$digest expected nonzero sha256 digest"
            }
        }

        foreach ($flagName in @("versionSignatureVerified", "shaSignatureVerified")) {
            $flag = Get-RequiredJsonBool $image $flagName
            if (-not $flag.valid -or -not $flag.value) {
                return [pscustomobject]@{
                    passed = $false
                    detail = "$imageName.$flagName=$($flag.raw) expected boolean true"
                }
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result failureCount=$($failureCount.value) backendDigest=$($json.backend.digest) frontendDigest=$($json.frontend.digest)"
    }
}

function Test-ContainerSecurityEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.container-security-evidence.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.container-security-evidence.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $failureCount = Get-RequiredJsonInt $json "failureCount"
    if (-not $failureCount.valid -or [int64] $failureCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "failureCount=$($failureCount.raw)(valid=$($failureCount.valid)) expected integer 0"
        }
    }

    $rawValidation = Test-SecurityEvidenceRawContent $raw "container security"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }

    $sourceRunUrl = [string] (Get-JsonProperty $json "sourceRunUrl")
    if (-not (Test-HttpUrl $sourceRunUrl)) {
        return [pscustomobject]@{
            passed = $false
            detail = "sourceRunUrl=$sourceRunUrl expected http(s) URL"
        }
    }

    $commitSha = [string] (Get-JsonProperty $json "commitSha")
    if (-not (Test-CommitSha $commitSha)) {
        return [pscustomobject]@{
            passed = $false
            detail = "commitSha=$commitSha expected nonzero 40-char SHA"
        }
    }

    foreach ($field in @("backendImage", "frontendImage", "artifactName", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $scans = Get-JsonProperty $json "scans"
    foreach ($flagName in @("backendScanPassed", "frontendScanPassed")) {
        $flag = Get-RequiredJsonBool $scans $flagName
        if (-not $flag.valid -or -not $flag.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "scans.$flagName=$($flag.raw) expected boolean true"
            }
        }
    }

    $sbom = Get-JsonProperty $json "sbom"
    foreach ($label in @("backend", "frontend")) {
        $summary = Get-JsonProperty $sbom $label
        $valid = Get-RequiredJsonBool $summary "valid"
        if (-not $valid.valid -or -not $valid.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "sbom.$label.valid=$($valid.raw) expected boolean true"
            }
        }

        $packageCount = Get-RequiredJsonInt $summary "packageCount"
        if (-not $packageCount.valid -or [int64] $packageCount.value -le 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "sbom.$label.packageCount=$($packageCount.raw)(valid=$($packageCount.valid)) expected positive integer"
            }
        }

        $byteSize = Get-RequiredJsonInt $summary "byteSize"
        if (-not $byteSize.valid -or [int64] $byteSize.value -le 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "sbom.$label.byteSize=$($byteSize.raw)(valid=$($byteSize.valid)) expected positive integer"
            }
        }

        $sha256 = [string] (Get-JsonProperty $summary "sha256")
        if (-not (Test-Sha256 $sha256)) {
            return [pscustomobject]@{
                passed = $false
                detail = "sbom.$label.sha256=$sha256 expected nonzero sha256"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result failureCount=$($failureCount.value) backendPackages=$($json.sbom.backend.packageCount) frontendPackages=$($json.sbom.frontend.packageCount)"
    }
}

function Test-StorageBackendTelemetryEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.storage-backend-telemetry.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.storage-backend-telemetry.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $patterns = @(
        '(?i)"(password|passwd|secretKey|secret_key|secretValue|secret_value|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key|kubeconfig|minioSecret|minio_secret|rootUser|root_user|rootPassword|root_password)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|root[_-]?password)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "storage backend telemetry contains raw admin info or credential-shaped content"
            }
        }
    }

    $source = Get-JsonProperty $json "source"
    $rawAdminInfoStored = Get-RequiredJsonBool $source "rawAdminInfoStored"
    if (-not $rawAdminInfoStored.valid -or $rawAdminInfoStored.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "source.rawAdminInfoStored=$($rawAdminInfoStored.raw) expected boolean false"
        }
    }
    foreach ($sourceField in @("mode", "minioAlias", "evidenceRef", "adminInfoJsonSha256")) {
        $value = [string] (Get-JsonProperty $source $sourceField)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "source.$sourceField missing"
            }
        }
    }

    $summary = Get-JsonProperty $json "summary"
    $poolCount = Get-RequiredJsonInt $summary "poolCount"
    $serverCount = Get-RequiredJsonInt $summary "serverCount"
    $onlineServerCount = Get-RequiredJsonInt $summary "onlineServerCount"
    $offlineServerCount = Get-RequiredJsonInt $summary "offlineServerCount"
    $driveCount = Get-RequiredJsonInt $summary "driveCount"
    $totalBytes = Get-RequiredJsonInt $summary "totalBytes"
    $usedBytes = Get-RequiredJsonInt $summary "usedBytes"
    $freeBytes = Get-RequiredJsonInt $summary "freeBytes"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $plannedCount = Get-RequiredJsonInt $summary "plannedCount"
    foreach ($countResult in @(
        @{ name = "poolCount"; value = $poolCount },
        @{ name = "serverCount"; value = $serverCount },
        @{ name = "onlineServerCount"; value = $onlineServerCount },
        @{ name = "offlineServerCount"; value = $offlineServerCount },
        @{ name = "driveCount"; value = $driveCount },
        @{ name = "totalBytes"; value = $totalBytes },
        @{ name = "usedBytes"; value = $usedBytes },
        @{ name = "freeBytes"; value = $freeBytes },
        @{ name = "failureCount"; value = $failureCount },
        @{ name = "plannedCount"; value = $plannedCount }
    )) {
        $name = [string] $countResult["name"]
        $value = $countResult["value"]
        if (-not $value.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.raw)(valid=False) expected integer"
            }
        }
    }

    $capacityKnown = Get-RequiredJsonBool $summary "capacityKnown"
    if (-not $capacityKnown.valid -or -not $capacityKnown.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "capacityKnown=$($capacityKnown.raw) expected boolean true"
        }
    }
    if ($poolCount.value -le 0 -or $serverCount.value -le 0 -or $onlineServerCount.value -ne $serverCount.value -or $offlineServerCount.value -ne 0 -or $driveCount.value -le 0 -or $totalBytes.value -le 0 -or $usedBytes.value -lt 0 -or $freeBytes.value -lt 0 -or $failureCount.value -ne 0 -or $plannedCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "storage telemetry incomplete pools=$($poolCount.value) servers=$($onlineServerCount.value)/$($serverCount.value) offline=$($offlineServerCount.value) drives=$($driveCount.value) total=$($totalBytes.value) used=$($usedBytes.value) free=$($freeBytes.value) failures=$($failureCount.value) planned=$($plannedCount.value)"
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result pools=$($poolCount.value) servers=$($onlineServerCount.value)/$($serverCount.value) drives=$($driveCount.value) totalBytes=$($totalBytes.value) rawAdminInfoStored=False failures=$($failureCount.value)"
    }
}

function Test-SecretRotationEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.secret-rotation-evidence.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.secret-rotation-evidence.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $patterns = @(
        '(?i)"(password|passwd|secretValue|secret_value|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key|kubeconfig|databasePassword|database_password|minioSecret|minio_secret|ldapPassword|ldap_password|smtpPass|smtp_pass|webhookSecret|webhook_secret)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|smtp[_-]?pass|webhook[_-]?secret)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "secret rotation evidence contains credential-shaped content"
            }
        }
    }

    $summary = Get-JsonProperty $json "summary"
    $rotatedCount = Get-RequiredJsonInt $summary "rotatedCount"
    $coreRotatedCount = Get-RequiredJsonInt $summary "coreRotatedCount"
    $coreRequiredCount = Get-RequiredJsonInt $summary "coreRequiredCount"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $plannedCount = Get-RequiredJsonInt $summary "plannedCount"
    foreach ($countResult in @(
        @{ name = "rotatedCount"; value = $rotatedCount },
        @{ name = "coreRotatedCount"; value = $coreRotatedCount },
        @{ name = "coreRequiredCount"; value = $coreRequiredCount },
        @{ name = "failureCount"; value = $failureCount },
        @{ name = "plannedCount"; value = $plannedCount }
    )) {
        $name = [string] $countResult["name"]
        $value = $countResult["value"]
        if (-not $value.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.raw)(valid=False) expected integer"
            }
        }
    }

    if ($coreRequiredCount.value -le 0 -or $coreRotatedCount.value -ne $coreRequiredCount.value -or $rotatedCount.value -lt $coreRequiredCount.value -or $failureCount.value -ne 0 -or $plannedCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "core rotation incomplete rotated=$($rotatedCount.value) coreRotated=$($coreRotatedCount.value)/$($coreRequiredCount.value) failures=$($failureCount.value) planned=$($plannedCount.value)"
        }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in @("noSecretValues", "workloadRestart", "smokePassed", "artifactLeakReview")) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result coreRotated=$($coreRotatedCount.value)/$($coreRequiredCount.value) failures=$($failureCount.value) planned=$($plannedCount.value)"
    }
}

function Test-CommercialIntegrationEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.commercial-integration-evidence.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.commercial-integration-evidence.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $patterns = @(
        '(?i)"(rawProviderResponse|raw_provider_response|providerResponse|provider_response|responseBody|response_body|responseHeaders|response_headers|webhookUrl|webhook_url|endpointUrl|endpoint_url|callbackUrl|callback_url|customerPaymentData|customer_payment_data|customerEmail|customer_email|customerName|customer_name|cardNumber|card_number|pan|bankAccount|bank_account|routingNumber|routing_number|taxId|tax_id|paymentTargetAccount|payment_target_account|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|webhook[_-]?secret|smtp[_-]?pass)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "commercial integration evidence contains raw provider/customer/payment or credential-shaped content"
            }
        }
    }

    $summary = Get-JsonProperty $json "summary"
    $integrationCount = Get-RequiredJsonInt $summary "integrationCount"
    $verifiedCount = Get-RequiredJsonInt $summary "verifiedCount"
    $requiredCount = Get-RequiredJsonInt $summary "requiredCount"
    $requiredVerifiedCount = Get-RequiredJsonInt $summary "requiredVerifiedCount"
    $webhookReadyProfileCount = Get-RequiredJsonInt $summary "paymentProviderAdapterWebhookReadyProfileCount"
    $nativeReadyProfileCount = Get-RequiredJsonInt $summary "paymentProviderAdapterNativeReadyProfileCount"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $plannedCount = Get-RequiredJsonInt $summary "plannedCount"
    foreach ($countResult in @(
        @{ name = "integrationCount"; value = $integrationCount },
        @{ name = "verifiedCount"; value = $verifiedCount },
        @{ name = "requiredCount"; value = $requiredCount },
        @{ name = "requiredVerifiedCount"; value = $requiredVerifiedCount },
        @{ name = "paymentProviderAdapterWebhookReadyProfileCount"; value = $webhookReadyProfileCount },
        @{ name = "paymentProviderAdapterNativeReadyProfileCount"; value = $nativeReadyProfileCount },
        @{ name = "failureCount"; value = $failureCount },
        @{ name = "plannedCount"; value = $plannedCount }
    )) {
        $name = [string] $countResult["name"]
        $value = $countResult["value"]
        if (-not $value.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.raw)(valid=False) expected integer"
            }
        }
    }

    if ($requiredCount.value -le 0 -or $requiredVerifiedCount.value -ne $requiredCount.value -or $verifiedCount.value -lt $requiredCount.value -or $failureCount.value -ne 0 -or $plannedCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "required integration coverage incomplete requiredVerified=$($requiredVerifiedCount.value)/$($requiredCount.value) verified=$($verifiedCount.value) failures=$($failureCount.value) planned=$($plannedCount.value)"
        }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in @("noSecretValues", "noRawProviderResponses", "payloadSizeCaps", "privateNetworkBlocking", "hmacSignatureHeaders", "paymentProviderAdapterReadinessReviewed", "adapterRetryWorkerRun", "requireAllImplementedAdapters", "requirePaymentProviderAdapterReadinessReview")) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true"
            }
        }
    }

    $readiness = Get-JsonProperty $json "paymentProviderAdapterReadiness"
    $readinessReviewed = Get-RequiredJsonBool $readiness "reviewed"
    if (-not $readinessReviewed.valid -or -not $readinessReviewed.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "paymentProviderAdapterReadiness.reviewed=$($readinessReviewed.raw) expected boolean true"
        }
    }
    $snapshot = Get-JsonProperty $readiness "snapshot"
    foreach ($snapshotBoolName in @("provided", "parsed", "validMode", "countsValid", "booleansValid")) {
        $snapshotBool = Get-RequiredJsonBool $snapshot $snapshotBoolName
        if (-not $snapshotBool.valid -or -not $snapshotBool.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "paymentProviderAdapterReadiness.snapshot.$snapshotBoolName=$($snapshotBool.raw) expected boolean true"
            }
        }
    }
    $snapshotProfileCount = Get-RequiredJsonInt $snapshot "profileCount"
    $snapshotWebhookReadyProfileCount = Get-RequiredJsonInt $snapshot "webhookReadyProfileCount"
    $snapshotNativeReadyProfileCount = Get-RequiredJsonInt $snapshot "nativeApiReadyProfileCount"
    foreach ($countResult in @(
        @{ name = "paymentProviderAdapterReadiness.snapshot.profileCount"; value = $snapshotProfileCount },
        @{ name = "paymentProviderAdapterReadiness.snapshot.webhookReadyProfileCount"; value = $snapshotWebhookReadyProfileCount },
        @{ name = "paymentProviderAdapterReadiness.snapshot.nativeApiReadyProfileCount"; value = $snapshotNativeReadyProfileCount }
    )) {
        $name = [string] $countResult["name"]
        $value = $countResult["value"]
        if (-not $value.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.raw)(valid=False) expected integer"
            }
        }
    }
    if ($snapshotProfileCount.value -le 0 -or $snapshotWebhookReadyProfileCount.value -le 0 -or $webhookReadyProfileCount.value -ne $snapshotWebhookReadyProfileCount.value -or $nativeReadyProfileCount.value -ne $snapshotNativeReadyProfileCount.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "payment provider adapter readiness incomplete profiles=$($snapshotProfileCount.value) webhookReady=$($snapshotWebhookReadyProfileCount.value) nativeReady=$($snapshotNativeReadyProfileCount.value)"
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result requiredVerified=$($requiredVerifiedCount.value)/$($requiredCount.value) webhookReadyProfiles=$($webhookReadyProfileCount.value) nativeReadyProfiles=$($nativeReadyProfileCount.value) failures=$($failureCount.value)"
    }
}

function Test-CommercialApprovalEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.commercial-approval-evidence.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.commercial-approval-evidence.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $patterns = @(
        '(?i)"(rawContractText|raw_contract_text|contractText|contract_text|legalTerms|legal_terms|termsText|terms_text|customerData|customer_data|customerEmail|customer_email|customerName|customer_name|licenseKey|license_key|licenseText|license_text|rawPriceTable|raw_price_table|paymentCard|payment_card|cardNumber|card_number|bankAccount|bank_account|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|license[_-]?key)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "commercial approval evidence contains raw contract/customer/payment/price or credential-shaped content"
            }
        }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in @("pricingApproved", "termsApproved", "supportSlaApproved", "licenseApproved", "legalApproved", "pricingPolicyProposalCommercialApproval", "requirePricingPolicyProposalApprovalSnapshot", "noSecretValues")) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true"
            }
        }
    }

    $summary = Get-JsonProperty $json "summary"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $checkCount = Get-RequiredJsonInt $summary "checkCount"
    $commercialApprovedCount = Get-RequiredJsonInt $summary "pricingPolicyProposalCommercialApprovedCount"
    $approvedPriceListCount = Get-RequiredJsonInt $summary "pricingPolicyProposalApprovedPriceListCount"
    foreach ($countResult in @(
        @{ name = "failureCount"; value = $failureCount },
        @{ name = "checkCount"; value = $checkCount },
        @{ name = "pricingPolicyProposalCommercialApprovedCount"; value = $commercialApprovedCount },
        @{ name = "pricingPolicyProposalApprovedPriceListCount"; value = $approvedPriceListCount }
    )) {
        $name = [string] $countResult["name"]
        $value = $countResult["value"]
        if (-not $value.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.raw)(valid=False) expected integer"
            }
        }
    }
    $proposalCommercialApproved = Get-RequiredJsonBool $summary "pricingPolicyProposalCommercialApproved"
    $approvalFlagsValid = Get-RequiredJsonBool $summary "pricingPolicyProposalApprovalFlagsValid"
    foreach ($boolResult in @(
        @{ name = "pricingPolicyProposalCommercialApproved"; value = $proposalCommercialApproved },
        @{ name = "pricingPolicyProposalApprovalFlagsValid"; value = $approvalFlagsValid }
    )) {
        $name = [string] $boolResult["name"]
        $value = $boolResult["value"]
        if (-not $value.valid -or -not $value.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.raw) expected boolean true"
            }
        }
    }
    if ($failureCount.value -ne 0 -or $checkCount.value -le 0 -or $commercialApprovedCount.value -le 0 -or $approvedPriceListCount.value -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "commercial approval incomplete commercialApproved=$($commercialApprovedCount.value) approvedPriceList=$($approvedPriceListCount.value) failures=$($failureCount.value) checks=$($checkCount.value)"
        }
    }

    $approval = Get-JsonProperty $json "pricingPolicyProposalApproval"
    $reviewed = Get-RequiredJsonBool $approval "reviewed"
    if (-not $reviewed.valid -or -not $reviewed.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "pricingPolicyProposalApproval.reviewed=$($reviewed.raw) expected boolean true"
        }
    }
    $snapshot = Get-JsonProperty $approval "snapshot"
    foreach ($snapshotBoolName in @("provided", "parsed", "approvalFlagsValid")) {
        $snapshotBool = Get-RequiredJsonBool $snapshot $snapshotBoolName
        if (-not $snapshotBool.valid -or -not $snapshotBool.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "pricingPolicyProposalApproval.snapshot.$snapshotBoolName=$($snapshotBool.raw) expected boolean true"
            }
        }
    }
    foreach ($countResult in @(
        @{ name = "pricingPolicyProposalApproval.snapshot.proposalCount"; value = Get-RequiredJsonInt $snapshot "proposalCount" },
        @{ name = "pricingPolicyProposalApproval.snapshot.approvedPriceListCount"; value = Get-RequiredJsonInt $snapshot "approvedPriceListCount" },
        @{ name = "pricingPolicyProposalApproval.snapshot.commercialApprovedCount"; value = Get-RequiredJsonInt $snapshot "commercialApprovedCount" }
    )) {
        $name = [string] $countResult["name"]
        $value = $countResult["value"]
        if (-not $value.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.raw)(valid=False) expected integer"
            }
        }
        if ($value.value -le 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.value) expected >0"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result commercialApproved=$($commercialApprovedCount.value) approvedPriceList=$($approvedPriceListCount.value) failures=$($failureCount.value)"
    }
}

function Test-EnterpriseAuthEvidenceJson([string] $Path) {
    try {
        $json = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -eq "passed") {
        $summary = Get-JsonProperty $json "summary"
        $passCount = Get-RequiredJsonInt $summary "passCount"
        $failCount = Get-RequiredJsonInt $summary "failCount"
        $blockedCount = Get-RequiredJsonInt $summary "blockedCount"
        $plannedCount = Get-RequiredJsonInt $summary "plannedCount"
        $skippedCount = Get-RequiredJsonInt $summary "skippedCount"
        $countsValid = $passCount.valid -and $failCount.valid -and $blockedCount.valid -and $plannedCount.valid -and $skippedCount.valid
        if (-not $countsValid) {
            return [pscustomobject]@{
                passed = $false
                detail = "result=passed passCount=$($passCount.raw)(valid=$($passCount.valid)) failCount=$($failCount.raw)(valid=$($failCount.valid)) blockedCount=$($blockedCount.raw)(valid=$($blockedCount.valid)) plannedCount=$($plannedCount.raw)(valid=$($plannedCount.valid)) skippedCount=$($skippedCount.raw)(valid=$($skippedCount.valid)) expected typed integer counts"
            }
        }
        if ($passCount.value -le 0 -or $failCount.value -ne 0 -or $blockedCount.value -ne 0 -or $plannedCount.value -ne 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "result=passed passCount=$($passCount.value) failCount=$($failCount.value) blockedCount=$($blockedCount.value) plannedCount=$($plannedCount.value) expected passCount>0 and fail/block/planned=0"
            }
        }
        return [pscustomobject]@{
            passed = $true
            detail = "result=passed passCount=$($passCount.value) failCount=0 blockedCount=0 plannedCount=0 expected=passed|scope-out"
        }
    }
    if ($result -ne "scope-out") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed|scope-out"
        }
    }

    $scopeOut = Get-JsonProperty $json "scopeOut"
    $accepted = Get-RequiredJsonBool $scopeOut "accepted"
    $reference = [string] (Get-JsonProperty $scopeOut "reference")
    $reason = [string] (Get-JsonProperty $scopeOut "reason")
    if (-not $accepted.valid -or -not $accepted.value -or [string]::IsNullOrWhiteSpace($reference) -or [string]::IsNullOrWhiteSpace($reason)) {
        return [pscustomobject]@{
            passed = $false
            detail = "result=scope-out accepted=$($accepted.raw)(valid=$($accepted.valid)) referencePresent=$(-not [string]::IsNullOrWhiteSpace($reference)) reasonPresent=$(-not [string]::IsNullOrWhiteSpace($reason)) expected accepted boolean true with reference and reason"
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "result=scope-out accepted=true expected=passed|scope-out"
    }
}

function Test-OperationsHandoffPackageSnapshots([object] $Json) {
    $operationsSnapshots = Get-JsonProperty $Json "operationsSnapshots"
    if ($null -eq $operationsSnapshots) {
        return [pscustomobject]@{
            passed = $false
            detail = "operationsSnapshots expected"
        }
    }

    $readiness = Get-JsonProperty $operationsSnapshots "readiness"
    $readinessResult = [string] (Get-JsonProperty $readiness "result")
    if (-not (Test-ReadyText $readinessResult)) {
        return [pscustomobject]@{
            passed = $false
            detail = "operations readiness snapshot result=$readinessResult expected=ready"
        }
    }

    $convergence = Get-JsonProperty $operationsSnapshots "convergence"
    $convergenceResult = [string] (Get-JsonProperty $convergence "result")
    $convergenceReadinessResult = [string] (Get-JsonProperty $convergence "readinessResult")
    $finalizerResult = [string] (Get-JsonProperty $convergence "finalizerResult")
    $finalizerReadinessResult = [string] (Get-JsonProperty $convergence "finalizerReadinessResult")
    $finalizerFailedCount = Get-RequiredJsonInt $convergence "finalizerFailedCount"
    $finalizerGapCount = Get-RequiredJsonInt $convergence "finalizerGapCount"
    $syncReady = Get-RequiredJsonBool $convergence "kubernetesReportSyncReady"
    $syncFailedCount = Get-RequiredJsonInt $convergence "kubernetesReportSyncFailedCount"
    $sourceReportResult = [string] (Get-JsonProperty $convergence "kubernetesReportSyncSourceReportResult")

    if (-not (Test-ReadyText $convergenceResult)) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence snapshot result=$convergenceResult expected=ready" }
    }
    if (-not (Test-ReadyText $convergenceReadinessResult)) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence readinessResult=$convergenceReadinessResult expected=ready" }
    }
    if (-not (Test-ReadyText $finalizerResult) -or -not (Test-ReadyText $finalizerReadinessResult)) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence finalizerResult=$finalizerResult finalizerReadinessResult=$finalizerReadinessResult expected=ready" }
    }
    if (-not $finalizerFailedCount.valid -or -not $finalizerGapCount.valid) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence finalizerFailedCount=$($finalizerFailedCount.raw) finalizerGapCount=$($finalizerGapCount.raw) expected integer 0" }
    }
    if ($finalizerFailedCount.value -ne 0 -or $finalizerGapCount.value -ne 0) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence finalizerFailedCount=$($finalizerFailedCount.value) finalizerGapCount=$($finalizerGapCount.value) expected=0" }
    }
    if (-not $syncReady.valid -or -not $syncFailedCount.valid) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence kubernetesReportSyncReady=$($syncReady.raw) failedSyncChecks=$($syncFailedCount.raw) expected boolean true and integer 0" }
    }
    if (-not $syncReady.value -or $syncFailedCount.value -ne 0) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence kubernetesReportSyncReady=$($syncReady.value) failedSyncChecks=$($syncFailedCount.value) expected ready/0" }
    }
    if (-not (Test-ReadyText $sourceReportResult)) {
        return [pscustomobject]@{ passed = $false; detail = "operations convergence sourceReportResult=$sourceReportResult expected=ready" }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "snapshotReadiness=ready, convergence=ready, finalizerFailed=0, finalizerGaps=0, sourceReportResult=ready"
    }
}

function Test-SanitizedQueryPlanEvidenceSummary([object] $QueryPlanEvidence) {
    if ($null -eq $QueryPlanEvidence) {
        return [pscustomobject]@{
            passed = $true
            detail = "queryPlanEvidence summary absent"
        }
    }

    $summaryText = $QueryPlanEvidence | ConvertTo-Json -Depth 20 -Compress
    $patterns = @(
        '(?i)"(sql|rawSql|raw_sql|explain|explainJson|explain_json|rawExplain|raw_explain|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key)\s*=\s*\S+',
        '(?i)\bSELECT\b[\s\S]{0,200}\bFROM\b'
    )
    foreach ($pattern in $patterns) {
        if ($summaryText -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "queryPlanEvidence summary contains raw SQL, raw EXPLAIN, or credential-shaped content"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "queryPlanEvidence summary is sanitized"
    }
}

function Test-DataFlowStoragePlanEvidenceJson([string] $Path, [bool] $RequirePassed = $false) {
    try {
        $json = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.data-flow-storage-plan.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.data-flow-storage-plan.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($RequirePassed -and $result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $candidateStore = [string] (Get-JsonProperty $json "candidateStore")
    if ($candidateStore -notin @("MARIADB_PARTITION", "EXTERNAL_TIME_SERIES", "DUAL_WRITE")) {
        return [pscustomobject]@{
            passed = $false
            detail = "candidateStore=$candidateStore expected=MARIADB_PARTITION|EXTERNAL_TIME_SERIES|DUAL_WRITE"
        }
    }

    $pendingCountResult = Get-RequiredJsonInt $json "pendingCount"
    if ($RequirePassed -and (-not $pendingCountResult.valid -or [int64] $pendingCountResult.value -ne 0)) {
        return [pscustomobject]@{
            passed = $false
            detail = "pendingCount=$($pendingCountResult.raw)(valid=$($pendingCountResult.valid)) expected integer 0"
        }
    }

    $queryPlanEvidence = Get-JsonProperty $json "queryPlanEvidence"
    $queryPlanEvidenceRequired = @("MARIADB_PARTITION", "DUAL_WRITE") -contains $candidateStore
    if ($queryPlanEvidenceRequired -and $null -eq $queryPlanEvidence) {
        return [pscustomobject]@{
            passed = $false
            detail = "candidateStore=$candidateStore requires queryPlanEvidence summary before import"
        }
    }

    if ($null -ne $queryPlanEvidence) {
        $expectedFormatVersion = [string] (Get-JsonProperty $queryPlanEvidence "expectedFormatVersion")
        if ($expectedFormatVersion -ne "osmu.mariadb-query-plan-evidence.v1") {
            return [pscustomobject]@{
                passed = $false
                detail = "queryPlanEvidence expectedFormatVersion=$expectedFormatVersion expected=osmu.mariadb-query-plan-evidence.v1"
            }
        }
        $sanitized = Test-SanitizedQueryPlanEvidenceSummary $queryPlanEvidence
        if (-not $sanitized.passed) {
            return $sanitized
        }
        if ($RequirePassed -and $queryPlanEvidenceRequired) {
            $queryPlanResult = [string] (Get-JsonProperty $queryPlanEvidence "result")
            if ($queryPlanResult -ne "passed") {
                return [pscustomobject]@{
                    passed = $false
                    detail = "queryPlanEvidence.result=$queryPlanResult expected=passed"
                }
            }

            $queryPlanFailedCount = Get-RequiredJsonInt $queryPlanEvidence "failedCount"
            if (-not $queryPlanFailedCount.valid -or [int64] $queryPlanFailedCount.value -ne 0) {
                return [pscustomobject]@{
                    passed = $false
                    detail = "queryPlanEvidence.failedCount=$($queryPlanFailedCount.raw)(valid=$($queryPlanFailedCount.valid)) expected integer 0"
                }
            }
        }
    }

    $pendingCountDetail = if ($pendingCountResult.valid) { [string] $pendingCountResult.value } else { $pendingCountResult.raw }
    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result candidateStore=$candidateStore pendingCount=$pendingCountDetail queryPlanEvidencePresent=$($null -ne $queryPlanEvidence)"
    }
}

function Test-DataFlowStorageTransitionRunbookEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.data-flow-storage-transition-runbook-evidence.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.data-flow-storage-transition-runbook-evidence.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $patterns = @(
        '(?i)"(sql|rawSql|raw_sql|queryText|query_text|explain|explainJson|explain_json|rawExplain|raw_explain|rawEventMessage|raw_event_message|objectKey|object_key|password|passwd|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:',
        '(?i)\b(password|passwd|credential|api[_-]?key|access[_-]?key|private[_-]?key)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '(?i)\bSELECT\b[\s\S]{0,200}\bFROM\b',
        '(?i)\bEXPLAIN\b[\s\S]{0,200}\bFORMAT\b'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "runbook evidence contains raw SQL, raw EXPLAIN, object keys, raw event messages, or credential-shaped content"
            }
        }
    }

    $planSnapshot = Get-JsonProperty $json "dataFlowStoragePlanSnapshot"
    $planResult = [string] (Get-JsonProperty $planSnapshot "result")
    if ($planResult -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "dataFlowStoragePlanSnapshot.result=$planResult expected=passed"
        }
    }

    $candidateStore = [string] (Get-JsonProperty $planSnapshot "candidateStore")
    if ($candidateStore -notin @("MARIADB_PARTITION", "EXTERNAL_TIME_SERIES", "DUAL_WRITE")) {
        return [pscustomobject]@{
            passed = $false
            detail = "dataFlowStoragePlanSnapshot.candidateStore=$candidateStore expected=MARIADB_PARTITION|EXTERNAL_TIME_SERIES|DUAL_WRITE"
        }
    }

    $summary = Get-JsonProperty $json "summary"
    $failureCountResult = Get-RequiredJsonInt $summary "failureCount"
    if (-not $failureCountResult.valid -or [int64] $failureCountResult.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "failureCount=$($failureCountResult.raw)(valid=$($failureCountResult.valid)) expected integer 0"
        }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    $requiredConfirmations = @(
        "backfillRehearsed",
        "dualWriteOrPartitionToggleReviewed",
        "rollbackRehearsed",
        "reconciliationPassed",
        "dashboardCutoverReviewed",
        "retentionDryRunReviewed",
        "noObjectKeysInAggregates",
        "noSecretValues"
    )
    foreach ($confirmationName in $requiredConfirmations) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result storagePlanResult=$planResult candidateStore=$candidateStore failureCount=$($failureCountResult.value) confirmations=$($requiredConfirmations.Count)/$($requiredConfirmations.Count)"
    }
}

function Test-KubernetesOperationsReportSyncEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.kubernetes-operations-report-sync.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.kubernetes-operations-report-sync.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "applied") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=applied"
        }
    }

    $patterns = @(
        '(?i)"(kubeconfig|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key|clientSecret|client_secret|adminPassword|admin_password)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|client[_-]?secret|admin[_-]?password)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "kubernetes operations report sync contains kubeconfig or credential-shaped content"
            }
        }
    }

    $failedCountResult = Get-RequiredJsonInt $json "failedCount"
    if (-not $failedCountResult.valid -or [int64] $failedCountResult.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "failedCount=$($failedCountResult.raw)(valid=$($failedCountResult.valid)) expected integer 0"
        }
    }

    $sourceReportFormatVersion = [string] (Get-JsonProperty $json "sourceReportFormatVersion")
    if ($sourceReportFormatVersion -ne "osmu.operations-readiness-convergence.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "sourceReportFormatVersion=$sourceReportFormatVersion expected=osmu.operations-readiness-convergence.v1"
        }
    }

    $sourceReportResult = [string] (Get-JsonProperty $json "sourceReportResult")
    if ($sourceReportResult -ne "ready") {
        return [pscustomobject]@{
            passed = $false
            detail = "sourceReportResult=$sourceReportResult expected=ready"
        }
    }

    $sourceReportBytesResult = Get-RequiredJsonInt $json "sourceReportBytes"
    if (-not $sourceReportBytesResult.valid -or [int64] $sourceReportBytesResult.value -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "sourceReportBytes=$($sourceReportBytesResult.raw)(valid=$($sourceReportBytesResult.valid)) expected positive integer"
        }
    }

    $sourceReportSha256 = [string] (Get-JsonProperty $json "sourceReportSha256")
    if ($sourceReportSha256 -notmatch '^[a-fA-F0-9]{64}$') {
        return [pscustomobject]@{
            passed = $false
            detail = "sourceReportSha256 missing or invalid"
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result failedCount=$($failedCountResult.value) sourceReportResult=$sourceReportResult sourceReportBytes=$($sourceReportBytesResult.value)"
    }
}

function Test-MonitoringThresholdEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.monitoring-threshold-evidence.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.monitoring-threshold-evidence.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $patterns = @(
        '(?i)"(password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key|webhookSecret|webhook_secret|smtpPass|smtp_pass)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|webhook[_-]?secret|smtp[_-]?pass)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "monitoring threshold evidence contains credential-shaped content"
            }
        }
    }

    $summary = Get-JsonProperty $json "thresholdTargetSummary"
    $reportSummary = Get-JsonProperty $json "summary"
    $requiredAlertCountResult = Get-RequiredJsonInt $summary "requiredAlertCount"
    $mappedAlertCountResult = Get-RequiredJsonInt $summary "mappedAlertCount"
    $routeCountResult = Get-RequiredJsonInt $summary "routeCount"
    $grafanaPanelCountResult = Get-RequiredJsonInt $summary "grafanaPanelCount"
    $tuningEvidenceCountResult = Get-RequiredJsonInt $summary "tuningEvidenceCount"
    $failureCountResult = Get-RequiredJsonInt $reportSummary "failureCount"
    foreach ($countResult in @(
        @{ name = "requiredAlertCount"; value = $requiredAlertCountResult },
        @{ name = "mappedAlertCount"; value = $mappedAlertCountResult },
        @{ name = "routeCount"; value = $routeCountResult },
        @{ name = "grafanaPanelCount"; value = $grafanaPanelCountResult },
        @{ name = "tuningEvidenceCount"; value = $tuningEvidenceCountResult },
        @{ name = "failureCount"; value = $failureCountResult }
    )) {
        $name = [string] $countResult["name"]
        $value = $countResult["value"]
        if (-not $value.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.raw)(valid=False) expected integer"
            }
        }
    }

    $requiredAlertCount = [int64] $requiredAlertCountResult.value
    $mappedAlertCount = [int64] $mappedAlertCountResult.value
    $routeCount = [int64] $routeCountResult.value
    $grafanaPanelCount = [int64] $grafanaPanelCountResult.value
    $tuningEvidenceCount = [int64] $tuningEvidenceCountResult.value
    $failureCount = [int64] $failureCountResult.value
    $missingAlerts = @(Get-JsonProperty $summary "missingAlerts")
    if ($requiredAlertCount -le 0 -or $mappedAlertCount -lt $requiredAlertCount -or $routeCount -le 0 -or $grafanaPanelCount -lt $requiredAlertCount -or $tuningEvidenceCount -lt $requiredAlertCount -or $missingAlerts.Count -gt 0 -or $failureCount -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "threshold target mapping incomplete required=$requiredAlertCount mapped=$mappedAlertCount routes=$routeCount grafanaPanels=$grafanaPanelCount tuningEvidence=$tuningEvidenceCount failures=$failureCount missing=$($missingAlerts -join ',')"
        }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in @("prometheusRulesLoaded", "grafanaDashboardImported", "alertmanagerRoutesReviewed", "targetBaselinesReviewed", "incidentRoutingReviewed", "noSecretValues")) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result requiredAlerts=$requiredAlertCount mappedAlerts=$mappedAlertCount routes=$routeCount grafanaPanels=$grafanaPanelCount tuningEvidence=$tuningEvidenceCount failures=$failureCount"
    }
}

function Test-OperationsHandoffPackageEvidenceJson([string] $Path) {
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.operations-handoff-package.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.operations-handoff-package.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $requiredConfirmations = @(
        "noSecretValues",
        "runbookReviewed",
        "troubleshootingReviewed",
        "rollbackReviewed",
        "supportEscalationReviewed",
        "knownGapsAccepted",
        "operationsReadinessSnapshotReviewed",
        "operationsConvergenceSnapshotReviewed",
        "dataFlowStoragePlanReviewed",
        "dataFlowStorageTransitionRunbookReviewed",
        "secretRotationSnapshotReviewed",
        "commercialIntegrationSnapshotReviewed",
        "commercialApprovalSnapshotReviewed",
        "enterpriseAuthSmokeSnapshotReviewed",
        "monitoringThresholdReviewed",
        "requireProductionEvidence",
        "requireOperationsSnapshotEvidence"
    )
    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in $requiredConfirmations) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true"
            }
        }
    }

    $snapshotValidation = Test-OperationsHandoffPackageSnapshots $json
    if (-not $snapshotValidation.passed) {
        return $snapshotValidation
    }

    $patterns = @(
        '(?i)"(rawClaimJson|raw_claim_json|idToken|id_token|accessToken|access_token|refreshToken|refresh_token|authorizationCode|authorization_code|oidcCode|oidc_code|oidcState|oidc_state|ldapPassword|ldap_password|adminPassword|admin_password|clientSecret|client_secret)"\s*:',
        '(?i)\b(password|passwd|credential|api[_-]?key|private[_-]?key|client[_-]?secret|ldap[_-]?password|admin[_-]?password)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "operations handoff package contains raw identity or credential-shaped content"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result requiredConfirmations=$($requiredConfirmations.Count) $($snapshotValidation.detail)"
    }
}

function Import-EvidenceFile(
    [string] $Group,
    [string] $SourceRoot,
    [string] $FileName,
    [bool] $Required,
    [string] $ExpectedProperty = "",
    [string] $ExpectedValue = "",
    [string] $ValidationKind = ""
) {
    if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
        Add-Entry $Group $FileName "skipped" "artifact path not selected" "" ""
        return
    }

    $sourcePath = Find-EvidenceFile $SourceRoot $FileName $Group
    if ([string]::IsNullOrWhiteSpace($sourcePath)) {
        if ($Required) {
            Add-Entry $Group $FileName "failed" "required evidence file not found" (Resolve-ProjectPath $SourceRoot) ""
        }
        else {
            Add-Entry $Group $FileName "skipped" "optional evidence file not found" (Resolve-ProjectPath $SourceRoot) ""
        }
        return
    }

    $validationDetails = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($ExpectedProperty)) {
        $validation = Test-EvidenceJson $sourcePath $ExpectedProperty $ExpectedValue
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }

    if ($ValidationKind -eq "storage-expansion-finalizer") {
        $validation = Test-StorageExpansionFinalizeJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "storage-expansion-rbac-auth") {
        $validation = Test-StorageExpansionRbacAuthEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "storage-expansion-server-dry-run") {
        $validation = Test-StorageExpansionServerDryRunEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "data-flow-storage-plan") {
        $validation = Test-DataFlowStoragePlanEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "data-flow-storage-plan-passed") {
        $validation = Test-DataFlowStoragePlanEvidenceJson $sourcePath $true
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "data-flow-storage-transition-runbook") {
        $validation = Test-DataFlowStorageTransitionRunbookEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "monitoring-threshold") {
        $validation = Test-MonitoringThresholdEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "storage-backend-telemetry") {
        $validation = Test-StorageBackendTelemetryEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "security-finalizer") {
        $validation = Test-SecurityEvidenceFinalizerJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "image-signing") {
        $validation = Test-ImageSigningEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "container-security") {
        $validation = Test-ContainerSecurityEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "secret-rotation") {
        $validation = Test-SecretRotationEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "commercial-integration") {
        $validation = Test-CommercialIntegrationEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "commercial-approval") {
        $validation = Test-CommercialApprovalEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "enterprise-auth") {
        $validation = Test-EnterpriseAuthEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "operations-handoff-package") {
        $validation = Test-OperationsHandoffPackageEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "kubernetes-operations-report-sync") {
        $validation = Test-KubernetesOperationsReportSyncEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }

    $resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
    New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null
    $destinationPath = Join-Path $resolvedOutputDirectory $FileName
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    $detail = "promoted to standard operations readiness path"
    if ($validationDetails.Count -gt 0) {
        $detail = "$detail; validation=$($validationDetails -join '; ')"
    }
    Add-Entry $Group $FileName "imported" $detail $sourcePath $destinationPath
}

Import-EvidenceFile "storage-expansion" $StorageExpansionArtifactPath "latest-storage-expansion-finalize.json" $true "" "" "storage-expansion-finalizer"
Import-EvidenceFile "storage-expansion" $StorageExpansionArtifactPath "latest-storage-expansion-finalize.md" $false
Import-EvidenceFile "storage-expansion" $StorageExpansionArtifactPath "latest-storage-expansion-rbac-auth.json" $true "" "" "storage-expansion-rbac-auth"
Import-EvidenceFile "storage-expansion" $StorageExpansionArtifactPath "latest-storage-expansion-server-dry-run.json" $true "" "" "storage-expansion-server-dry-run"

Import-EvidenceFile "ha-dr-readiness" $HaDrReadinessArtifactPath "latest-kubernetes-ha-dr-readiness.json" $true "result" "passed"

Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-finalize.json" $true "result" "ready"
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-finalize.md" $false
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-drill.json" $false
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-restore-smoke.json" $false
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-evidence-request.json" $false

Import-EvidenceFile "iam-rbac" $IamRbacArtifactPath "latest-iam-rbac-finalize.json" $true "result" "passed"
Import-EvidenceFile "iam-rbac" $IamRbacArtifactPath "latest-iam-rbac-finalize.md" $false
Import-EvidenceFile "iam-rbac" $IamRbacArtifactPath "latest-storage-expansion-rbac-auth.json" $false

Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-security-evidence-finalize.json" $true "" "" "security-finalizer"
Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-security-evidence-finalize.md" $false
Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-image-signing-evidence.json" $true "" "" "image-signing"
Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-container-security-evidence.json" $true "" "" "container-security"

Import-EvidenceFile "storage-backend-telemetry" $StorageBackendTelemetryArtifactPath "latest-storage-backend-telemetry.json" $true "" "" "storage-backend-telemetry"
Import-EvidenceFile "storage-backend-telemetry" $StorageBackendTelemetryArtifactPath "latest-storage-backend-telemetry.md" $false

Import-EvidenceFile "monitoring-threshold" $MonitoringThresholdArtifactPath "latest-monitoring-threshold-evidence.json" $true "" "" "monitoring-threshold"
Import-EvidenceFile "monitoring-threshold" $MonitoringThresholdArtifactPath "latest-monitoring-threshold-evidence.md" $false

Import-EvidenceFile "secret-rotation" $SecretRotationArtifactPath "latest-secret-rotation-evidence.json" $true "" "" "secret-rotation"
Import-EvidenceFile "secret-rotation" $SecretRotationArtifactPath "latest-secret-rotation-evidence.md" $false

Import-EvidenceFile "commercial-integration" $CommercialIntegrationArtifactPath "latest-commercial-integration-evidence.json" $true "" "" "commercial-integration"
Import-EvidenceFile "commercial-integration" $CommercialIntegrationArtifactPath "latest-commercial-integration-evidence.md" $false

Import-EvidenceFile "commercial-approval" $CommercialApprovalArtifactPath "latest-commercial-approval-evidence.json" $true "" "" "commercial-approval"
Import-EvidenceFile "commercial-approval" $CommercialApprovalArtifactPath "latest-commercial-approval-evidence.md" $false

Import-EvidenceFile "enterprise-auth" $EnterpriseAuthArtifactPath "latest-enterprise-auth-smoke.json" $true "" "" "enterprise-auth"
Import-EvidenceFile "enterprise-auth" $EnterpriseAuthArtifactPath "latest-enterprise-auth-smoke.md" $false

Import-EvidenceFile "operations-handoff-package" $OperationsHandoffPackageArtifactPath "latest-operations-handoff-package.json" $true "" "" "operations-handoff-package"
Import-EvidenceFile "operations-handoff-package" $OperationsHandoffPackageArtifactPath "latest-operations-handoff-package.md" $false

Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-kubernetes-operations-report-sync.json" $true "" "" "kubernetes-operations-report-sync"
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-kubernetes-operations-report-sync-plan.json" $false
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-kubernetes-operations-report-sync-server-dry-run.json" $false
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-data-flow-storage-plan.json" $false "" "" "data-flow-storage-plan"
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-data-flow-storage-transition-runbook-evidence.json" $false "" "" "data-flow-storage-transition-runbook"

Import-EvidenceFile "data-flow-storage-plan" $DataFlowStoragePlanArtifactPath "latest-data-flow-storage-plan.json" $true "" "" "data-flow-storage-plan-passed"
Import-EvidenceFile "data-flow-storage-transition-runbook" $DataFlowStorageTransitionRunbookArtifactPath "latest-data-flow-storage-transition-runbook-evidence.json" $true "" "" "data-flow-storage-transition-runbook"
Import-EvidenceFile "data-flow-storage-transition-runbook" $DataFlowStorageTransitionRunbookArtifactPath "latest-data-flow-storage-transition-runbook-evidence.md" $false

$failedEntries = @($entries | Where-Object { $_.status -eq "failed" })
$importedEntries = @($entries | Where-Object { $_.status -eq "imported" })
$selectedGroupCandidates = @(
    [pscustomobject]@{ group = "storage-expansion"; path = $StorageExpansionArtifactPath },
    [pscustomobject]@{ group = "ha-dr-readiness"; path = $HaDrReadinessArtifactPath },
    [pscustomobject]@{ group = "kubernetes-dr"; path = $KubernetesDrArtifactPath },
    [pscustomobject]@{ group = "iam-rbac"; path = $IamRbacArtifactPath },
    [pscustomobject]@{ group = "security-evidence"; path = $SecurityEvidenceArtifactPath },
    [pscustomobject]@{ group = "storage-backend-telemetry"; path = $StorageBackendTelemetryArtifactPath },
    [pscustomobject]@{ group = "monitoring-threshold"; path = $MonitoringThresholdArtifactPath },
    [pscustomobject]@{ group = "secret-rotation"; path = $SecretRotationArtifactPath },
    [pscustomobject]@{ group = "commercial-integration"; path = $CommercialIntegrationArtifactPath },
    [pscustomobject]@{ group = "commercial-approval"; path = $CommercialApprovalArtifactPath },
    [pscustomobject]@{ group = "enterprise-auth"; path = $EnterpriseAuthArtifactPath },
    [pscustomobject]@{ group = "operations-handoff-package"; path = $OperationsHandoffPackageArtifactPath },
    [pscustomobject]@{ group = "kubernetes-operations-report-sync"; path = $KubernetesOperationsReportSyncArtifactPath },
    [pscustomobject]@{ group = "data-flow-storage-plan"; path = $DataFlowStoragePlanArtifactPath },
    [pscustomobject]@{ group = "data-flow-storage-transition-runbook"; path = $DataFlowStorageTransitionRunbookArtifactPath }
)
$selectedGroups = @($selectedGroupCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_.path) })
$result = if ($failedEntries.Count -eq 0) { "passed" } else { "failed" }
$status = if ($failedEntries.Count -gt 0) {
    "artifact-import-failed"
}
elseif ($selectedGroups.Count -eq 0) {
    "no-artifacts-selected"
}
else {
    "artifact-imported"
}

$resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
$resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null

$report = [ordered]@{
    formatVersion = "osmu.operations-readiness-artifact-import.v1"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    result = $result
    status = $status
    selectedGroupCount = $selectedGroups.Count
    importedCount = $importedEntries.Count
    failedCount = $failedEntries.Count
    outputDirectory = Resolve-ProjectPath $OutputDirectory
    entries = $entries
    secretPolicy = "Artifact import copies only JSON/Markdown evidence files and does not read kubeconfig, registry tokens, DR secrets, or bearer tokens."
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8

$markdownLines = @(
    "# OSMU Operations Readiness Artifact Import",
    "",
    "Generated at: $($report.generatedAt)",
    "Result: $result",
    "Status: $status",
    "Imported count: $($report.importedCount)",
    "Failed count: $($report.failedCount)",
    "",
    "## Entries",
    ""
)
foreach ($entry in $entries) {
    $markdownLines += "- [$($entry.status)] $($entry.group) / $($entry.fileName): $($entry.detail)"
}
($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8

Write-Host "Operations readiness artifact import JSON: $resolvedJsonOutputPath"
Write-Host "Operations readiness artifact import markdown: $resolvedMarkdownOutputPath"
Write-Host "Result: $result"
Write-Host "Status: $status"
Write-Host "Imported: $($importedEntries.Count)"
Write-Host "Failed: $($failedEntries.Count)"

if ($failedEntries.Count -gt 0) {
    throw "Operations readiness artifact import failed: $($failedEntries.Count) failed entries."
}
