param(
    [string] $StorageExpansionArtifactPath = "",
    [string] $HaDrReadinessArtifactPath = "",
    [string] $KubernetesDrArtifactPath = "",
    [string] $IamRbacArtifactPath = "",
    [string] $SecurityEvidenceArtifactPath = "",
    [string] $StorageBackendTelemetryArtifactPath = "",
    [string] $MinioBucketCorsArtifactPath = "",
    [string] $MonitoringThresholdArtifactPath = "",
    [string] $SecretRotationArtifactPath = "",
    [string] $ClusterNetworkAccessReviewArtifactPath = "",
    [string] $HelmValuesHardeningArtifactPath = "",
    [string] $SupportEscalationHandoffArtifactPath = "",
    [string] $CommercialIntegrationArtifactPath = "",
    [string] $CommercialApprovalArtifactPath = "",
    [string] $ChargebackCloseoutArtifactPath = "",
    [string] $EnterpriseAuthArtifactPath = "",
    [string] $EnterpriseAuthJitRollbackArtifactPath = "",
    [string] $OperationsHandoffPackageArtifactPath = "",
    [string] $KubernetesOperationsReportSyncArtifactPath = "",
    [string] $DataFlowStoragePlanArtifactPath = "",
    [string] $DataFlowQueryRetentionBudgetArtifactPath = "",
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
function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false, $true))
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

function Get-TargetEvidenceFieldValues([object] $Json) {
    if ($null -eq $Json) {
        return @()
    }
    $values = New-Object System.Collections.ArrayList
    foreach ($source in @((Get-JsonProperty $Json "target"), $Json)) {
        if ($null -eq $source) { continue }
        foreach ($name in @("environmentName", "targetCluster", "cluster", "namespace", "sourceNamespace", "restoreNamespace", "operator", "operatorName", "reviewedBy", "approvedBy")) {
            $value = [string] (Get-JsonProperty $source $name)
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                [void] $values.Add($value)
            }
        }
    }
    return @($values)
}

function Test-SelfTestTargetEvidenceJson([object] $Json) {
    $selfTestPattern = "(?i)(^|[-_ .])(self[-_ .]?test|fixture|sample)([-_ .]|$)"
    $markers = @()
    foreach ($value in (Get-TargetEvidenceFieldValues $Json)) {
        if ($value -match $selfTestPattern) {
            $markers += $value
        }
    }
    if ($markers.Count -gt 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "self-test target evidence rejected markers=$($markers -join ',')"
        }
    }
    return [pscustomobject]@{
        passed = $true
        detail = "target evidence markers accepted"
    }
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

function Test-ImageRefTag([string] $Value, [string] $Tag) {
    return -not [string]::IsNullOrWhiteSpace($Value) -and -not [string]::IsNullOrWhiteSpace($Tag) -and $Value.EndsWith(":$Tag", [System.StringComparison]::Ordinal)
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
        $json = Read-Utf8Text $Path | ConvertFrom-Json
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
        $raw = Read-Utf8Text $Path
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
        $raw = Read-Utf8Text $Path
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
        $raw = Read-Utf8Text $Path
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

function Test-KubernetesHaDrReadinessEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.kubernetes-ha-dr-readiness.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.kubernetes-ha-dr-readiness.v1"
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

    $rawValidation = Test-OperationsEvidenceRawContent $raw "Kubernetes HA/DR readiness"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }

    foreach ($field in @("namespace", "kubectlPath", "restoreManifestPath")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $checksObject = Get-JsonProperty $json "checks"
    [object[]] $checks = if ($null -eq $checksObject) { @() } else { @($checksObject | ForEach-Object { $_ }) }
    if ($checks.Count -lt 12) {
        return [pscustomobject]@{
            passed = $false
            detail = "checkCount=$($checks.Count) expected at least 12"
        }
    }

    foreach ($requiredCheck in @(
        "deployment-osmu-backend-ready",
        "deployment-osmu-frontend-ready",
        "statefulset-osmu-mariadb-ready",
        "statefulset-osmu-minio-ready",
        "pdb-osmu-backend-effective",
        "pdb-osmu-frontend-effective",
        "pvc-osmu-backup-data-bound",
        "cronjob-osmu-mariadb-backup-scheduled",
        "cronjob-osmu-minio-backup-scheduled",
        "restore-job-server-dry-run"
    )) {
        $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "name") -eq $requiredCheck })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck missing"
            }
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

        $exitCode = Get-RequiredJsonInt $check "exitCode"
        if (-not $exitCode.valid -or [int64] $exitCode.value -ne 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks[$i].exitCode=$($exitCode.raw)(valid=$($exitCode.valid)) expected integer 0"
            }
        }

        foreach ($field in @("name", "category", "summary", "command")) {
            $value = [string] (Get-JsonProperty $check $field)
            if ([string]::IsNullOrWhiteSpace($value)) {
                return [pscustomobject]@{
                    passed = $false
                    detail = "checks[$i].$field missing"
                }
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result failureCount=$($failureCount.value) checkCount=$($checks.Count) namespace=$($json.namespace)"
    }
}

function Test-KubernetesDrFinalizeJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.kubernetes-dr-finalize.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.kubernetes-dr-finalize.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "ready") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=ready"
        }
    }

    $status = [string] (Get-JsonProperty $json "status")
    if ($status -ne "kubernetes-dr-finalize-verified") {
        return [pscustomobject]@{
            passed = $false
            detail = "status=$status expected=kubernetes-dr-finalize-verified"
        }
    }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "Kubernetes DR finalizer"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }

    foreach ($field in @("sourceNamespace", "restoreNamespace", "runId", "backupTimestamp", "powerShellCommand", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $backupTimestamp = [string] (Get-JsonProperty $json "backupTimestamp")
    if ($backupTimestamp -eq "YYYYMMDDTHHMMSSZ" -or $backupTimestamp -notmatch "^\d{8}T\d{6}Z$") {
        return [pscustomobject]@{
            passed = $false
            detail = "backupTimestamp=$backupTimestamp expected concrete YYYYMMDDTHHMMSSZ"
        }
    }

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $startedAt = [string] (Get-JsonProperty $json "startedAt")
    $completedAt = [string] (Get-JsonProperty $json "completedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    $parsedStartedAt = [DateTimeOffset]::MinValue
    $parsedCompletedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "generatedAt=$generatedAt expected ISO timestamp"
        }
    }
    if ([string]::IsNullOrWhiteSpace($startedAt) -or -not [DateTimeOffset]::TryParse($startedAt, [ref] $parsedStartedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "startedAt=$startedAt expected ISO timestamp"
        }
    }
    if ([string]::IsNullOrWhiteSpace($completedAt) -or -not [DateTimeOffset]::TryParse($completedAt, [ref] $parsedCompletedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "completedAt=$completedAt expected ISO timestamp"
        }
    }
    if ($parsedCompletedAt -lt $parsedStartedAt) {
        return [pscustomobject]@{
            passed = $false
            detail = "completedAt must be same as or later than startedAt"
        }
    }

    foreach ($flagName in @("serverDryRunOnly", "confirmRestore", "bootstrapDrBucket", "verifyDrBucketImmutability", "transferArtifacts", "runRestoreSmoke", "writeEvidenceRequest", "submitEvidence", "runS3ClientSmoke")) {
        $flag = Get-RequiredJsonBool $json $flagName
        if (-not $flag.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "$flagName=$($flag.raw) expected boolean"
            }
        }
        if (($flagName -eq "serverDryRunOnly" -and $flag.value) -or ($flagName -ne "serverDryRunOnly" -and -not $flag.value)) {
            $expectedFlagValue = if ($flagName -eq "serverDryRunOnly") { "False" } else { "True" }
            return [pscustomobject]@{
                passed = $false
                detail = "$flagName=$($flag.raw) expected $expectedFlagValue"
            }
        }
    }

    $paths = Get-JsonProperty $json "paths"
    foreach ($field in @("drDrillEvidence", "restoreSmokeEvidence", "drEvidenceRequest", "report", "summary")) {
        $value = [string] (Get-JsonProperty $paths $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "paths.$field missing"
            }
        }
    }

    $gapsObject = Get-JsonProperty $json "gaps"
    $gaps = if ($null -eq $gapsObject) { @() } else { @($gapsObject) }
    if ($gaps.Count -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "gapCount=$($gaps.Count) expected 0"
        }
    }

    $requiredStepContracts = @(
        [pscustomobject]@{ name = "Kubernetes DR drill wrapper"; script = ".\scripts\run-kubernetes-dr-drill.ps1"; flag = "-ConfirmRestore" },
        [pscustomobject]@{ name = "Kubernetes restore smoke"; script = ".\scripts\verify-kubernetes-restore-smoke.ps1"; flag = "-RunS3ClientSmoke" },
        [pscustomobject]@{ name = "Kubernetes DR evidence request"; script = ".\scripts\write-kubernetes-dr-evidence-request.ps1"; flag = "-Submit" }
    )

    $commandsObject = Get-JsonProperty $json "commands"
    $commands = if ($null -eq $commandsObject) { @() } else { @($commandsObject) }
    if ($commands.Count -lt $requiredStepContracts.Count) {
        return [pscustomobject]@{
            passed = $false
            detail = "commandCount=$($commands.Count) expected at least $($requiredStepContracts.Count)"
        }
    }
    foreach ($requiredStep in $requiredStepContracts) {
        $commandMatch = @($commands | Where-Object { [string] (Get-JsonProperty $_ "name") -eq $requiredStep.name })
        if ($commandMatch.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "commands.$($requiredStep.name) missing"
            }
        }

        $script = [string] (Get-JsonProperty $commandMatch[0] "script")
        $command = [string] (Get-JsonProperty $commandMatch[0] "command")
        $arguments = @((Get-JsonProperty $commandMatch[0] "arguments"))
        if ($script -ne $requiredStep.script -or [string]::IsNullOrWhiteSpace($command) -or -not ($arguments -contains $requiredStep.flag) -or -not $command.Contains($requiredStep.flag)) {
            return [pscustomobject]@{
                passed = $false
                detail = "commands.$($requiredStep.name) script=$script flag=$($requiredStep.flag) expected command and arguments"
            }
        }
    }

    $stepsObject = Get-JsonProperty $json "steps"
    $steps = if ($null -eq $stepsObject) { @() } else { @($stepsObject) }
    if ($steps.Count -lt $requiredStepContracts.Count) {
        return [pscustomobject]@{
            passed = $false
            detail = "stepCount=$($steps.Count) expected at least $($requiredStepContracts.Count)"
        }
    }
    foreach ($step in $steps) {
        $name = [string] (Get-JsonProperty $step "name")
        $script = [string] (Get-JsonProperty $step "script")
        $command = [string] (Get-JsonProperty $step "command")
        $stepResult = [string] (Get-JsonProperty $step "result")
        $exitCode = Get-RequiredJsonInt $step "exitCode"
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($script) -or [string]::IsNullOrWhiteSpace($command)) {
            return [pscustomobject]@{
                passed = $false
                detail = "steps row missing name/script/command"
            }
        }
        if ($stepResult -ne "passed" -or -not $exitCode.valid -or [int64] $exitCode.value -ne 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "steps.$name result=$stepResult exitCode=$($exitCode.raw) expected passed and integer 0"
            }
        }
    }
    foreach ($requiredStep in $requiredStepContracts) {
        $match = @($steps | Where-Object { [string] (Get-JsonProperty $_ "name") -eq $requiredStep.name })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "steps.$($requiredStep.name) missing"
            }
        }

        $script = [string] (Get-JsonProperty $match[0] "script")
        $command = [string] (Get-JsonProperty $match[0] "command")
        $arguments = @((Get-JsonProperty $match[0] "arguments"))
        if ($script -ne $requiredStep.script -or -not ($arguments -contains $requiredStep.flag) -or -not $command.Contains($requiredStep.flag)) {
            return [pscustomobject]@{
                passed = $false
                detail = "steps.$($requiredStep.name) script=$script flag=$($requiredStep.flag) expected command and arguments"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result status=$status commandCount=$($commands.Count) stepCount=$($steps.Count) backupTimestamp=$backupTimestamp"
    }
}

function Test-IamRbacFinalizeJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.iam-rbac-finalize.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.iam-rbac-finalize.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed"
        }
    }

    $allowedStatuses = @(
        "iam-rbac-static-passed",
        "iam-rbac-backend-passed",
        "iam-rbac-live-passed",
        "iam-rbac-live-and-backend-passed"
    )
    $status = [string] (Get-JsonProperty $json "status")
    if ($allowedStatuses -notcontains $status) {
        return [pscustomobject]@{
            passed = $false
            detail = "status=$status expected=$($allowedStatuses -join '|')"
        }
    }

    $failedCount = Get-RequiredJsonInt $json "failedCount"
    if (-not $failedCount.valid -or [int64] $failedCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "failedCount=$($failedCount.raw)(valid=$($failedCount.valid)) expected integer 0"
        }
    }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "IAM/RBAC finalizer"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }

    foreach ($field in @("namespace", "serviceAccount", "powerShellCommand", "gradleCommand", "decisionRule", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $runBackendPolicyTests = Get-RequiredJsonBool $json "runBackendPolicyTests"
    $runKubernetesLiveAuth = Get-RequiredJsonBool $json "runKubernetesLiveAuth"
    if (-not $runBackendPolicyTests.valid -or -not $runKubernetesLiveAuth.valid) {
        return [pscustomobject]@{
            passed = $false
            detail = "runBackendPolicyTests=$($runBackendPolicyTests.raw) runKubernetesLiveAuth=$($runKubernetesLiveAuth.raw) expected booleans"
        }
    }

    $expectedStatus = if ($runBackendPolicyTests.value -and $runKubernetesLiveAuth.value) {
        "iam-rbac-live-and-backend-passed"
    }
    elseif ($runBackendPolicyTests.value) {
        "iam-rbac-backend-passed"
    }
    elseif ($runKubernetesLiveAuth.value) {
        "iam-rbac-live-passed"
    }
    else {
        "iam-rbac-static-passed"
    }
    if ($status -ne $expectedStatus) {
        return [pscustomobject]@{
            passed = $false
            detail = "status=$status expected=$expectedStatus from backend/live flags"
        }
    }

    $commandsObject = Get-JsonProperty $json "commands"
    $commands = if ($null -eq $commandsObject) { @() } else { @($commandsObject) }
    foreach ($requiredCommand in @("IAM/RBAC matrix verifier", "Kubernetes RBAC matrix verifier")) {
        $match = @($commands | Where-Object { [string] (Get-JsonProperty $_ "name") -eq $requiredCommand })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "commands.$requiredCommand missing"
            }
        }
    }

    $stepsObject = Get-JsonProperty $json "steps"
    $steps = if ($null -eq $stepsObject) { @() } else { @($stepsObject) }
    foreach ($requiredStep in @("IAM/RBAC matrix verifier", "Kubernetes RBAC matrix verifier")) {
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

    if ($runBackendPolicyTests.value) {
        $backendStep = @($steps | Where-Object { [string] (Get-JsonProperty $_ "name") -eq "Backend focused RBAC tests" })
        if ($backendStep.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "steps.Backend focused RBAC tests missing while runBackendPolicyTests=true"
            }
        }
    }
    if ($runKubernetesLiveAuth.value) {
        $liveStep = @($steps | Where-Object { [string] (Get-JsonProperty $_ "name") -eq "Storage expansion live RBAC auth" })
        if ($liveStep.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "steps.Storage expansion live RBAC auth missing while runKubernetesLiveAuth=true"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result status=$status failedCount=$($failedCount.value) commandCount=$($commands.Count) stepCount=$($steps.Count)"
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
        $raw = Read-Utf8Text $Path
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
    [object[]] $checks = if ($null -eq $checksObject) { @() } else { @($checksObject | ForEach-Object { $_ }) }
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
        $raw = Read-Utf8Text $Path
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

    foreach ($field in @("version", "issuer", "signingMode", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }
    $version = [string] (Get-JsonProperty $json "version")
    $issuer = [string] (Get-JsonProperty $json "issuer")
    if ($issuer -ne "https://token.actions.githubusercontent.com") {
        return [pscustomobject]@{
            passed = $false
            detail = "issuer=$issuer expected=https://token.actions.githubusercontent.com"
        }
    }
    $signingMode = [string] (Get-JsonProperty $json "signingMode")
    if ($signingMode -ne "keyless-github-actions-oidc") {
        return [pscustomobject]@{
            passed = $false
            detail = "signingMode=$signingMode expected=keyless-github-actions-oidc"
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
        $versionRef = [string] (Get-JsonProperty $image "versionRef")
        if (-not (Test-ImageRefTag $versionRef $version)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$imageName.versionRef=$versionRef expected tag $version"
            }
        }
        $shaRef = [string] (Get-JsonProperty $image "shaRef")
        if (-not (Test-ImageRefTag $shaRef $commitSha)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$imageName.shaRef=$shaRef expected tag $commitSha"
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
        detail = "formatVersion=$formatVersion result=$result failureCount=$($failureCount.value) version=$version signingMode=$signingMode backendDigest=$($json.backend.digest) frontendDigest=$($json.frontend.digest)"
    }
}

function Test-ContainerSecurityEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
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
    foreach ($imageField in @("backendImage", "frontendImage")) {
        $imageRef = [string] (Get-JsonProperty $json $imageField)
        if (-not (Test-ImageRefTag $imageRef $commitSha)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$imageField=$imageRef expected commit SHA tag $commitSha"
            }
        }
    }
    $artifactName = [string] (Get-JsonProperty $json "artifactName")
    if (-not $artifactName.Contains($commitSha)) {
        return [pscustomobject]@{
            passed = $false
            detail = "artifactName=$artifactName expected to contain commit SHA $commitSha"
        }
    }

    $scans = Get-JsonProperty $json "scans"
    $severity = [string] (Get-JsonProperty $scans "severity")
    if ($severity -ne "CRITICAL,HIGH") {
        return [pscustomobject]@{
            passed = $false
            detail = "scans.severity=$severity expected=CRITICAL,HIGH"
        }
    }
    $ignoreUnfixed = Get-RequiredJsonBool $scans "ignoreUnfixed"
    if (-not $ignoreUnfixed.valid -or -not $ignoreUnfixed.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "scans.ignoreUnfixed=$($ignoreUnfixed.raw) expected boolean true"
        }
    }
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
    $sbomFormat = [string] (Get-JsonProperty $sbom "format")
    if ($sbomFormat -ne "SPDX JSON") {
        return [pscustomobject]@{
            passed = $false
            detail = "sbom.format=$sbomFormat expected=SPDX JSON"
        }
    }
    foreach ($label in @("backend", "frontend")) {
        $summary = Get-JsonProperty $sbom $label
        $summaryLabel = [string] (Get-JsonProperty $summary "label")
        if ($summaryLabel -ne $label) {
            return [pscustomobject]@{
                passed = $false
                detail = "sbom.$label.label=$summaryLabel expected=$label"
            }
        }
        $spdxVersion = [string] (Get-JsonProperty $summary "spdxVersion")
        if ([string]::IsNullOrWhiteSpace($spdxVersion) -or -not $spdxVersion.StartsWith("SPDX-", [System.StringComparison]::Ordinal)) {
            return [pscustomobject]@{
                passed = $false
                detail = "sbom.$label.spdxVersion=$spdxVersion expected SPDX-*"
            }
        }
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
        detail = "formatVersion=$formatVersion result=$result failureCount=$($failureCount.value) commitSha=$commitSha backendPackages=$($json.sbom.backend.packageCount) frontendPackages=$($json.sbom.frontend.packageCount)"
    }
}

function Test-StorageBackendTelemetryEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
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

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "generatedAt=$generatedAt expected ISO timestamp"
        }
    }

    foreach ($field in @("environmentName", "targetCluster", "operatorName", "decisionRule", "scopePolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
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
    foreach ($sourceField in @("mode", "minioAlias", "evidenceRef", "sourceRef", "adminInfoJsonSha256")) {
        $value = [string] (Get-JsonProperty $source $sourceField)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "source.$sourceField missing"
            }
        }
    }
    $sourceMode = [string] (Get-JsonProperty $source "mode")
    $allowedSourceModes = @("admin-info-json-path", "inline-admin-info-json", "mc-admin-info-execute")
    if ($allowedSourceModes -notcontains $sourceMode) {
        return [pscustomobject]@{
            passed = $false
            detail = "source.mode=$sourceMode expected=$($allowedSourceModes -join '|')"
        }
    }
    $adminInfoJsonSha256 = [string] (Get-JsonProperty $source "adminInfoJsonSha256")
    if (-not (Test-Sha256 $adminInfoJsonSha256)) {
        return [pscustomobject]@{
            passed = $false
            detail = "source.adminInfoJsonSha256=$adminInfoJsonSha256 expected nonzero sha256"
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

    $checksObject = Get-JsonProperty $json "checks"
    $checks = if ($null -eq $checksObject) { @() } else { @($checksObject) }
    foreach ($requiredCheck in @(
        "environment-name",
        "target-cluster",
        "operator",
        "evidence-ref",
        "admin-info-json-parse",
        "server-telemetry",
        "pool-telemetry",
        "drive-telemetry",
        "server-health",
        "capacity-telemetry",
        "raw-admin-info-policy"
    )) {
        $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheck })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck missing"
            }
        }

        $checkPassed = Get-RequiredJsonBool $match[0] "passed"
        $checkStatus = [string] (Get-JsonProperty $match[0] "status")
        if (-not $checkPassed.valid -or -not $checkPassed.value -or $checkStatus -ne "PASS") {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck status=$checkStatus passed=$($checkPassed.raw) expected PASS and boolean true"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result environmentName=$($json.environmentName) targetCluster=$($json.targetCluster) sourceMode=$sourceMode pools=$($poolCount.value) servers=$($onlineServerCount.value)/$($serverCount.value) drives=$($driveCount.value) totalBytes=$($totalBytes.value) rawAdminInfoStored=False failures=$($failureCount.value) checkCount=$($checks.Count)"
    }
}

function Test-SecretRotationEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
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

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "generatedAt=$generatedAt expected ISO timestamp"
        }
    }

    foreach ($field in @("environmentName", "targetCluster", "operatorName", "decisionRule", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $rotationWindow = Get-JsonProperty $json "rotationWindow"
    $rotationStartedAt = [string] (Get-JsonProperty $rotationWindow "startedAt")
    $rotationCompletedAt = [string] (Get-JsonProperty $rotationWindow "completedAt")
    $parsedRotationStartedAt = [DateTimeOffset]::MinValue
    $parsedRotationCompletedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($rotationStartedAt) -or -not [DateTimeOffset]::TryParse($rotationStartedAt, [ref] $parsedRotationStartedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "rotationWindow.startedAt=$rotationStartedAt expected ISO timestamp"
        }
    }
    if ([string]::IsNullOrWhiteSpace($rotationCompletedAt) -or -not [DateTimeOffset]::TryParse($rotationCompletedAt, [ref] $parsedRotationCompletedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "rotationWindow.completedAt=$rotationCompletedAt expected ISO timestamp"
        }
    }
    if ($parsedRotationCompletedAt -lt $parsedRotationStartedAt) {
        return [pscustomobject]@{
            passed = $false
            detail = "rotationWindow completedAt must be same as or later than startedAt"
        }
    }

    $evidenceRefs = Get-JsonProperty $json "evidenceRefs"
    foreach ($refName in @("changeApproval", "secretManagerAudit", "workloadRestart", "smoke", "artifactLeakReview")) {
        $refValue = [string] (Get-JsonProperty $evidenceRefs $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) {
            return [pscustomobject]@{
                passed = $false
                detail = "evidenceRefs.$refName missing"
            }
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

    $rotationsObject = Get-JsonProperty $json "rotations"
    $rotations = if ($null -eq $rotationsObject) { @() } else { @($rotationsObject) }
    foreach ($requiredRotation in @("admin-password", "jwt-signing-secret", "database-credentials", "minio-root-credentials", "tls-certificate")) {
        $match = @($rotations | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredRotation })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "rotations.$requiredRotation missing"
            }
        }

        $rotationCore = Get-RequiredJsonBool $match[0] "core"
        $rotationRotated = Get-RequiredJsonBool $match[0] "rotated"
        if (-not $rotationCore.valid -or -not $rotationCore.value -or -not $rotationRotated.valid -or -not $rotationRotated.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "rotations.$requiredRotation core=$($rotationCore.raw) rotated=$($rotationRotated.raw) expected booleans true"
            }
        }
    }

    $checksObject = Get-JsonProperty $json "checks"
    $checks = if ($null -eq $checksObject) { @() } else { @($checksObject) }
    foreach ($requiredCheck in @(
        "environment-name",
        "target-cluster",
        "operator",
        "rotation-started-at",
        "rotation-completed-at",
        "rotation-window-order",
        "change-approval-ref",
        "secret-manager-evidence-ref",
        "workload-restart-evidence-ref",
        "smoke-evidence-ref",
        "artifact-leak-review-evidence-ref",
        "no-secret-values-confirmed",
        "workload-restart-confirmed",
        "smoke-passed-confirmed",
        "artifact-leak-review-confirmed",
        "core-secret-rotation-coverage"
    )) {
        $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheck })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck missing"
            }
        }

        $checkPassed = Get-RequiredJsonBool $match[0] "passed"
        $checkStatus = [string] (Get-JsonProperty $match[0] "status")
        if (-not $checkPassed.valid -or -not $checkPassed.value -or $checkStatus -ne "PASS") {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck status=$checkStatus passed=$($checkPassed.raw) expected PASS and boolean true"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result environmentName=$($json.environmentName) targetCluster=$($json.targetCluster) coreRotated=$($coreRotatedCount.value)/$($coreRequiredCount.value) rotations=$($rotations.Count) failures=$($failureCount.value) planned=$($plannedCount.value) checkCount=$($checks.Count)"
    }
}

function Test-CommercialIntegrationEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
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

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "generatedAt=$generatedAt expected ISO timestamp"
        }
    }

    foreach ($field in @("environmentName", "targetCluster", "operatorName", "decisionRule", "scopePolicy", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $verificationWindow = Get-JsonProperty $json "verificationWindow"
    $verificationStartedAt = [string] (Get-JsonProperty $verificationWindow "startedAt")
    $verificationCompletedAt = [string] (Get-JsonProperty $verificationWindow "completedAt")
    $parsedVerificationStartedAt = [DateTimeOffset]::MinValue
    $parsedVerificationCompletedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($verificationStartedAt) -or -not [DateTimeOffset]::TryParse($verificationStartedAt, [ref] $parsedVerificationStartedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "verificationWindow.startedAt=$verificationStartedAt expected ISO timestamp"
        }
    }
    if ([string]::IsNullOrWhiteSpace($verificationCompletedAt) -or -not [DateTimeOffset]::TryParse($verificationCompletedAt, [ref] $parsedVerificationCompletedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "verificationWindow.completedAt=$verificationCompletedAt expected ISO timestamp"
        }
    }
    if ($parsedVerificationCompletedAt -lt $parsedVerificationStartedAt) {
        return [pscustomobject]@{
            passed = $false
            detail = "verificationWindow completedAt must be same as or later than startedAt"
        }
    }

    $evidenceRefs = Get-JsonProperty $json "evidenceRefs"
    foreach ($refName in @("changeApproval", "paymentProviderAdapterReadiness", "adapterRetryWorker", "payloadReview", "privateNetworkBlocking", "hmacSignature")) {
        $refValue = [string] (Get-JsonProperty $evidenceRefs $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) {
            return [pscustomobject]@{
                passed = $false
                detail = "evidenceRefs.$refName missing"
            }
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

    if ($integrationCount.value -ne 8 -or $requiredCount.value -ne 8 -or $requiredVerifiedCount.value -ne $requiredCount.value -or $verifiedCount.value -lt $requiredCount.value -or $failureCount.value -ne 0 -or $plannedCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "required integration coverage incomplete integrations=$($integrationCount.value) requiredVerified=$($requiredVerifiedCount.value)/$($requiredCount.value) verified=$($verifiedCount.value) failures=$($failureCount.value) planned=$($plannedCount.value)"
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

    $integrationsObject = Get-JsonProperty $json "integrations"
    $integrations = if ($null -eq $integrationsObject) { @() } else { @($integrationsObject) }
    foreach ($requiredIntegration in @(
        "notification-webhook",
        "notification-slack",
        "notification-email-smtp",
        "payment-generic-webhook",
        "payment-card-profile",
        "payment-bank-profile",
        "payment-tax-profile",
        "payment-erp-profile"
    )) {
        $match = @($integrations | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredIntegration })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "integrations.$requiredIntegration missing"
            }
        }

        $integrationRequired = Get-RequiredJsonBool $match[0] "required"
        $integrationVerified = Get-RequiredJsonBool $match[0] "verified"
        $integrationEvidenceRef = [string] (Get-JsonProperty $match[0] "evidenceRef")
        if (-not $integrationRequired.valid -or -not $integrationRequired.value -or -not $integrationVerified.valid -or -not $integrationVerified.value -or [string]::IsNullOrWhiteSpace($integrationEvidenceRef)) {
            return [pscustomobject]@{
                passed = $false
                detail = "integrations.$requiredIntegration required=$($integrationRequired.raw) verified=$($integrationVerified.raw) evidenceRefPresent=$(-not [string]::IsNullOrWhiteSpace($integrationEvidenceRef)) expected required/verified true with evidence ref"
            }
        }
    }

    $checksObject = Get-JsonProperty $json "checks"
    $checks = if ($null -eq $checksObject) { @() } else { @($checksObject) }
    foreach ($requiredCheck in @(
        "environment-name",
        "target-cluster",
        "operator",
        "verification-started-at",
        "verification-completed-at",
        "verification-window-order",
        "change-approval-ref",
        "no-secret-values-confirmed",
        "no-raw-provider-responses-confirmed",
        "payload-size-caps-confirmed",
        "private-network-blocking-confirmed",
        "hmac-signature-confirmed",
        "adapter-retry-worker-confirmed",
        "payment-provider-adapter-readiness-snapshot",
        "payment-provider-adapter-readiness-counts-typed",
        "payment-provider-adapter-readiness-booleans-typed",
        "payment-provider-adapter-readiness-profile-coverage",
        "payment-provider-adapter-readiness-reviewed",
        "integration-notification-webhook",
        "integration-notification-slack",
        "integration-notification-email-smtp",
        "integration-payment-generic-webhook",
        "integration-payment-card-profile",
        "integration-payment-bank-profile",
        "integration-payment-tax-profile",
        "integration-payment-erp-profile",
        "required-integration-coverage"
    )) {
        $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheck })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck missing"
            }
        }

        $checkPassed = Get-RequiredJsonBool $match[0] "passed"
        $checkStatus = [string] (Get-JsonProperty $match[0] "status")
        if (-not $checkPassed.valid -or -not $checkPassed.value -or $checkStatus -ne "PASS") {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck status=$checkStatus passed=$($checkPassed.raw) expected PASS and boolean true"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result environmentName=$($json.environmentName) targetCluster=$($json.targetCluster) requiredVerified=$($requiredVerifiedCount.value)/$($requiredCount.value) webhookReadyProfiles=$($webhookReadyProfileCount.value) nativeReadyProfiles=$($nativeReadyProfileCount.value) failures=$($failureCount.value) integrations=$($integrations.Count) checkCount=$($checks.Count)"
    }
}

function Test-CommercialApprovalEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
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

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "generatedAt=$generatedAt expected ISO timestamp"
        }
    }

    foreach ($field in @("productVersion", "approvedBy", "approvedAt", "decisionRule", "scopePolicy", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $approvedAt = [string] (Get-JsonProperty $json "approvedAt")
    $parsedApprovedAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($approvedAt, [ref] $parsedApprovedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "approvedAt=$approvedAt expected ISO timestamp"
        }
    }

    $evidenceRefs = Get-JsonProperty $json "evidenceRefs"
    foreach ($refName in @("approval", "pricing", "terms", "supportSla", "licenseAgreement", "legal", "pilotContract", "pricingPolicyProposal")) {
        $refValue = [string] (Get-JsonProperty $evidenceRefs $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) {
            return [pscustomobject]@{
                passed = $false
                detail = "evidenceRefs.$refName missing"
            }
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
    $passedCount = Get-RequiredJsonInt $summary "passedCount"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $checkCount = Get-RequiredJsonInt $summary "checkCount"
    $commercialApprovedCount = Get-RequiredJsonInt $summary "pricingPolicyProposalCommercialApprovedCount"
    $approvedPriceListCount = Get-RequiredJsonInt $summary "pricingPolicyProposalApprovedPriceListCount"
    foreach ($countResult in @(
        @{ name = "passedCount"; value = $passedCount },
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
    if ($failureCount.value -ne 0 -or $checkCount.value -ne 14 -or $passedCount.value -ne 14 -or $commercialApprovedCount.value -le 0 -or $approvedPriceListCount.value -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "commercial approval incomplete commercialApproved=$($commercialApprovedCount.value) approvedPriceList=$($approvedPriceListCount.value) failures=$($failureCount.value) passed=$($passedCount.value) checks=$($checkCount.value)"
        }
    }

    $approval = Get-JsonProperty $json "pricingPolicyProposalApproval"
    $required = Get-RequiredJsonBool $approval "required"
    if (-not $required.valid -or -not $required.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "pricingPolicyProposalApproval.required=$($required.raw) expected boolean true"
        }
    }
    $reviewed = Get-RequiredJsonBool $approval "reviewed"
    if (-not $reviewed.valid -or -not $reviewed.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "pricingPolicyProposalApproval.reviewed=$($reviewed.raw) expected boolean true"
        }
    }
    $proposalEvidenceRef = [string] (Get-JsonProperty $approval "evidenceRef")
    if ([string]::IsNullOrWhiteSpace($proposalEvidenceRef)) {
        return [pscustomobject]@{
            passed = $false
            detail = "pricingPolicyProposalApproval.evidenceRef missing"
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

    $proposalRowsObject = Get-JsonProperty $snapshot "proposals"
    $proposalRows = if ($null -eq $proposalRowsObject) { @() } else { @($proposalRowsObject) }
    $approvedRows = @($proposalRows | Where-Object {
        [string] (Get-JsonProperty $_ "status") -eq "PRICE_LIST_APPROVED" `
            -and (Get-RequiredJsonBool $_ "approvedPriceList").valid `
            -and (Get-RequiredJsonBool $_ "approvedPriceList").value `
            -and -not [string]::IsNullOrWhiteSpace([string] (Get-JsonProperty $_ "commercialApprovalReference"))
    })
    if ($approvedRows.Count -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "pricingPolicyProposalApproval.snapshot.proposals missing PRICE_LIST_APPROVED approved price-list row"
        }
    }
    $approvedRowTimestamp = [string] (Get-JsonProperty $approvedRows[0] "commercialApprovedAt")
    $parsedApprovedRowTimestamp = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($approvedRowTimestamp) -or -not [DateTimeOffset]::TryParse($approvedRowTimestamp, [ref] $parsedApprovedRowTimestamp)) {
        return [pscustomobject]@{
            passed = $false
            detail = "pricingPolicyProposalApproval.snapshot.proposals.commercialApprovedAt=$approvedRowTimestamp expected ISO timestamp"
        }
    }

    $checksObject = Get-JsonProperty $json "checks"
    $checks = if ($null -eq $checksObject) { @() } else { @($checksObject) }
    foreach ($requiredCheck in @(
        "product-version",
        "approval-ref",
        "approved-by",
        "approved-at",
        "pricing-approved",
        "terms-approved",
        "support-sla-approved",
        "license-agreement-approved",
        "legal-approval-confirmed",
        "pilot-contract-boundary-recorded",
        "no-secret-values-confirmed",
        "pricing-policy-proposal-snapshot",
        "pricing-policy-proposal-approval-fields-typed",
        "pricing-policy-proposal-commercial-approved"
    )) {
        $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheck })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck missing"
            }
        }

        $checkPassed = Get-RequiredJsonBool $match[0] "passed"
        $checkStatus = [string] (Get-JsonProperty $match[0] "status")
        if (-not $checkPassed.valid -or -not $checkPassed.value -or $checkStatus -ne "PASS") {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck status=$checkStatus passed=$($checkPassed.raw) expected PASS and boolean true"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result productVersion=$($json.productVersion) approvedBy=$($json.approvedBy) commercialApproved=$($commercialApprovedCount.value) approvedPriceList=$($approvedPriceListCount.value) failures=$($failureCount.value) checkCount=$($checks.Count)"
    }
}

function Test-ChargebackCloseoutEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{ passed = $false; detail = "invalid JSON: $($_.Exception.Message)" }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.chargeback-closeout-evidence.v1") {
        return [pscustomobject]@{ passed = $false; detail = "formatVersion=$formatVersion expected=osmu.chargeback-closeout-evidence.v1" }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{ passed = $false; detail = "result=$result expected=passed" }
    }

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "generatedAt=$generatedAt expected ISO timestamp" }
    }

    foreach ($field in @("decisionRule", "scopePolicy", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{ passed = $false; detail = "$field missing" }
        }
    }

    $patterns = @(
        '(?i)"(rawProviderResponse|raw_provider_response|providerResponse|provider_response|responseBody|response_body|responseHeaders|response_headers|webhookUrl|webhook_url|endpointUrl|endpoint_url|callbackUrl|callback_url|customerData|customer_data|customerEmail|customer_email|customerName|customer_name|customerPaymentData|customer_payment_data|paymentCard|payment_card|cardNumber|card_number|pan|bankAccount|bank_account|routingNumber|routing_number|taxId|tax_id|paymentTargetAccount|payment_target_account|rawPriceTable|raw_price_table|priceTable|price_table|rawInvoice|raw_invoice|invoicePdf|invoice_pdf|password|passwd|secret|token|credential|apiKey|api_key|accessKey|access_key|privateKey|private_key)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|api[_-]?key|access[_-]?key|private[_-]?key|webhook[_-]?secret|smtp[_-]?pass)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{ passed = $false; detail = "chargeback closeout evidence contains raw customer/payment/provider or credential-shaped content" }
        }
    }

    $target = Get-JsonProperty $json "target"
    foreach ($field in @("environmentName", "targetCluster", "operator", "billingPeriod", "closeoutStartedAt", "closeoutCompletedAt", "changeApprovalRef")) {
        $value = [string] (Get-JsonProperty $target $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{ passed = $false; detail = "target.$field missing" }
        }
    }
    $startedAt = [string] (Get-JsonProperty $target "closeoutStartedAt")
    $completedAt = [string] (Get-JsonProperty $target "closeoutCompletedAt")
    $parsedStartedAt = [DateTimeOffset]::MinValue
    $parsedCompletedAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($startedAt, [ref] $parsedStartedAt) -or -not [DateTimeOffset]::TryParse($completedAt, [ref] $parsedCompletedAt) -or $parsedCompletedAt -lt $parsedStartedAt) {
        return [pscustomobject]@{ passed = $false; detail = "target closeout window invalid startedAt=$startedAt completedAt=$completedAt" }
    }

    $summary = Get-JsonProperty $json "summary"
    $checkCount = Get-RequiredJsonInt $summary "checkCount"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $plannedCount = Get-RequiredJsonInt $summary "plannedCount"
    $requiredRefCount = Get-RequiredJsonInt $summary "requiredEvidenceRefCount"
    $providedRefCount = Get-RequiredJsonInt $summary "providedEvidenceRefCount"
    foreach ($countResult in @(
        @{ name = "checkCount"; value = $checkCount },
        @{ name = "failureCount"; value = $failureCount },
        @{ name = "plannedCount"; value = $plannedCount },
        @{ name = "requiredEvidenceRefCount"; value = $requiredRefCount },
        @{ name = "providedEvidenceRefCount"; value = $providedRefCount }
    )) {
        $name = [string] $countResult["name"]
        $value = $countResult["value"]
        if (-not $value.valid) {
            return [pscustomobject]@{ passed = $false; detail = "summary.$name=$($value.raw)(valid=False) expected integer" }
        }
    }
    if ($checkCount.value -lt 20 -or $failureCount.value -ne 0 -or $plannedCount.value -ne 0 -or $requiredRefCount.value -lt 14 -or $providedRefCount.value -ne $requiredRefCount.value) {
        return [pscustomobject]@{ passed = $false; detail = "summary incomplete checks=$($checkCount.value) failures=$($failureCount.value) planned=$($plannedCount.value) refs=$($providedRefCount.value)/$($requiredRefCount.value)" }
    }

    foreach ($summaryBoolName in @("chargebackCloseoutSnapshotValid", "chargebackCloseoutSnapshotReady", "paymentProviderAdapterReadinessSnapshotValid", "paymentProviderAdapterReadinessReviewed", "commercialEvidenceReviewed")) {
        $summaryBool = Get-RequiredJsonBool $summary $summaryBoolName
        if (-not $summaryBool.valid -or -not $summaryBool.value) {
            return [pscustomobject]@{ passed = $false; detail = "summary.$summaryBoolName=$($summaryBool.raw) expected boolean true" }
        }
    }

    $summaryScanLimit = Get-RequiredJsonInt $summary "chargebackCloseoutSnapshotScanLimit"
    $summaryBlockerCount = Get-RequiredJsonInt $summary "chargebackCloseoutSnapshotBlockerCount"
    $summaryTruncationBlockerCount = Get-RequiredJsonInt $summary "chargebackCloseoutSnapshotTruncationBlockerCount"
    $summarySourceTruncated = Get-RequiredJsonBool $summary "chargebackCloseoutSnapshotSourceTruncated"
    if (-not $summaryScanLimit.valid -or $summaryScanLimit.value -le 0) {
        return [pscustomobject]@{ passed = $false; detail = "summary.chargebackCloseoutSnapshotScanLimit=$($summaryScanLimit.raw) expected positive integer" }
    }
    if (-not $summaryBlockerCount.valid -or $summaryBlockerCount.value -ne 0 -or -not $summaryTruncationBlockerCount.valid -or $summaryTruncationBlockerCount.value -ne 0) {
        return [pscustomobject]@{ passed = $false; detail = "summary closeout blockers=$($summaryBlockerCount.raw) truncationBlockers=$($summaryTruncationBlockerCount.raw) expected integer zero" }
    }
    if (-not $summarySourceTruncated.valid -or $summarySourceTruncated.value) {
        return [pscustomobject]@{ passed = $false; detail = "summary.chargebackCloseoutSnapshotSourceTruncated=$($summarySourceTruncated.raw) expected boolean false" }
    }

    $evidenceRefs = Get-JsonProperty $json "evidenceRefs"
    foreach ($refName in @("pricingPolicy", "pricingProposalApproval", "chargebackPreview", "chargebackTrendExport", "invoiceDraft", "invoiceFinalization", "paymentRequest", "paymentProviderHandoff", "paymentProviderAdapterReadiness", "notificationDelivery", "adapterRetryWorker", "reconciliation", "commercialIntegration", "commercialApproval")) {
        $refValue = [string] (Get-JsonProperty $evidenceRefs $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) {
            return [pscustomobject]@{ passed = $false; detail = "evidenceRefs.$refName missing" }
        }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in @("pricingPolicyReviewed", "priceListApproved", "usageWindowReviewed", "chargebackPreviewReviewed", "trendExportReviewed", "invoiceDraftReviewed", "invoiceFinalized", "paymentRequestReviewed", "paymentProviderHandoffReviewed", "paymentProviderAdapterReadinessReviewed", "notificationDeliveryReviewed", "adapterRetryReviewed", "reconciliationReviewed", "commercialIntegrationReviewed", "commercialApprovalReviewed", "noRawCustomerPaymentData", "noRawProviderResponses", "noSecretValues", "requirePaymentProviderAdapterReadinessSnapshot")) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) {
            return [pscustomobject]@{ passed = $false; detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true" }
        }
    }

    $closeoutSnapshot = Get-JsonProperty $json "chargebackCloseoutSnapshot"
    $closeoutSnapshotValid = Get-RequiredJsonBool $closeoutSnapshot "valid"
    if (-not $closeoutSnapshotValid.valid -or -not $closeoutSnapshotValid.value) {
        return [pscustomobject]@{ passed = $false; detail = "chargebackCloseoutSnapshot.valid=$($closeoutSnapshotValid.raw) expected boolean true" }
    }
    foreach ($fieldName in @("sourceComplete", "scanLimitPositive", "truncationBlockerCountZero", "blockerCountZero", "closeoutReady", "readinessBooleansClosed")) {
        $field = Get-RequiredJsonBool $closeoutSnapshot $fieldName
        if (-not $field.valid -or -not $field.value) {
            return [pscustomobject]@{ passed = $false; detail = "chargebackCloseoutSnapshot.$fieldName=$($field.raw) expected boolean true" }
        }
    }
    $sourceTruncated = Get-RequiredJsonBool $closeoutSnapshot "sourceTruncated"
    if (-not $sourceTruncated.valid -or $sourceTruncated.value) {
        return [pscustomobject]@{ passed = $false; detail = "chargebackCloseoutSnapshot.sourceTruncated=$($sourceTruncated.raw) expected boolean false" }
    }
    $closeoutCounts = Get-JsonProperty $closeoutSnapshot "counts"
    foreach ($countName in @("invoiceDraftCount", "finalInvoiceCount", "paymentRequestedCount", "paymentHandoffCount", "paidInvoiceCount", "scanLimit")) {
        $count = Get-RequiredJsonInt $closeoutCounts $countName
        if (-not $count.valid -or $count.value -le 0) {
            return [pscustomobject]@{ passed = $false; detail = "chargebackCloseoutSnapshot.counts.$countName=$($count.raw) expected positive integer" }
        }
    }
    foreach ($countName in @("failureCount", "blockerCount", "truncationBlockerCount", "reconciliationDifferenceMinorUnits")) {
        $count = Get-RequiredJsonInt $closeoutCounts $countName
        if (-not $count.valid -or $count.value -ne 0) {
            return [pscustomobject]@{ passed = $false; detail = "chargebackCloseoutSnapshot.counts.$countName=$($count.raw) expected integer zero" }
        }
    }
    $rawDataFlags = Get-JsonProperty $closeoutSnapshot "rawDataFlags"
    foreach ($flagName in @("rawCustomerPaymentDataStored", "rawProviderResponseStored", "rawSecretValuesStored")) {
        $flag = Get-RequiredJsonBool $rawDataFlags $flagName
        if (-not $flag.valid -or $flag.value) {
            return [pscustomobject]@{ passed = $false; detail = "chargebackCloseoutSnapshot.rawDataFlags.$flagName=$($flag.raw) expected boolean false" }
        }
    }

    $paymentReadiness = Get-JsonProperty $json "paymentProviderAdapterReadiness"
    foreach ($fieldName in @("provided", "parsed", "valid", "profileCoverageValid")) {
        $field = Get-RequiredJsonBool $paymentReadiness $fieldName
        if (-not $field.valid -or -not $field.value) {
            return [pscustomobject]@{ passed = $false; detail = "paymentProviderAdapterReadiness.$fieldName=$($field.raw) expected boolean true" }
        }
    }

    $checksObject = Get-JsonProperty $json "checks"
    $checks = if ($null -eq $checksObject) { @() } else { @($checksObject) }
    foreach ($requiredCheck in @("target-metadata", "closeout-window-order", "change-approval-ref", "chargeback-closeout-snapshot-valid", "payment-provider-adapter-readiness-snapshot-valid", "payment-provider-adapter-readiness-reviewed", "commercial-integration-reviewed", "commercial-approval-reviewed", "no-raw-customer-payment-data", "no-raw-provider-responses", "no-secret-values")) {
        $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheck })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{ passed = $false; detail = "checks.$requiredCheck missing" }
        }
        $checkPassed = Get-RequiredJsonBool $match[0] "passed"
        $checkStatus = [string] (Get-JsonProperty $match[0] "status")
        if (-not $checkPassed.valid -or -not $checkPassed.value -or $checkStatus -ne "PASS") {
            return [pscustomobject]@{ passed = $false; detail = "checks.$requiredCheck status=$checkStatus passed=$($checkPassed.raw) expected PASS and boolean true" }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result billingPeriod=$($target.billingPeriod) environmentName=$($target.environmentName) targetCluster=$($target.targetCluster) refs=$($providedRefCount.value)/$($requiredRefCount.value) failures=$($failureCount.value) planned=$($plannedCount.value) scanLimit=$($summaryScanLimit.value) sourceTruncated=$($summarySourceTruncated.value) truncationBlockers=$($summaryTruncationBlockerCount.value) checkCount=$($checks.Count)"
    }
}
function Test-EnterpriseAuthEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.enterprise-auth-smoke.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected=osmu.enterprise-auth-smoke.v1"
        }
    }

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "generatedAt=$generatedAt expected ISO timestamp"
        }
    }

    foreach ($field in @("executionMode", "decisionRule", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$field missing"
            }
        }
    }

    $patterns = @(
        '(?i)"(adminPassword|ldapPassword|accessToken|access_token|refreshToken|refresh_token|idToken|id_token|oidcCallbackCode|oidcCallbackState|clientSecret|client_secret|rawClaims|raw_claims|claims|authorizationCode|authorization_code|password|passwd|token|credential|privateKey|private_key)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|client[_-]?secret|private[_-]?key)\s*=\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{
                passed = $false
                detail = "enterprise auth evidence contains raw password/token/claim or credential-shaped content"
            }
        }
    }

    $executionMode = [string] (Get-JsonProperty $json "executionMode")
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
            detail = "result=$([string] (Get-JsonProperty $json "result")) passCount=$($passCount.raw)(valid=$($passCount.valid)) failCount=$($failCount.raw)(valid=$($failCount.valid)) blockedCount=$($blockedCount.raw)(valid=$($blockedCount.valid)) plannedCount=$($plannedCount.raw)(valid=$($plannedCount.valid)) skippedCount=$($skippedCount.raw)(valid=$($skippedCount.valid)) expected typed integer counts"
        }
    }

    $checksObject = Get-JsonProperty $json "checks"
    [object[]] $checks = if ($null -eq $checksObject) { @() } else { @($checksObject | ForEach-Object { $_ }) }
    if ($checks.Count -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "checks missing"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -eq "passed") {
        if ($executionMode -ne "execute") {
            return [pscustomobject]@{
                passed = $false
                detail = "result=passed executionMode=$executionMode expected=execute"
            }
        }

        $apiBase = [string] (Get-JsonProperty $json "apiBase")
        if ([string]::IsNullOrWhiteSpace($apiBase)) {
            return [pscustomobject]@{
                passed = $false
                detail = "result=passed apiBase missing"
            }
        }

        $requireOidc = Get-RequiredJsonBool $json "requireOidc"
        $requireLdap = Get-RequiredJsonBool $json "requireLdap"
        $requireAuditEvents = Get-RequiredJsonBool $json "requireAuditEvents"
        if (-not $requireOidc.valid -or -not $requireLdap.valid -or -not $requireAuditEvents.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "result=passed requireOidc=$($requireOidc.raw)(valid=$($requireOidc.valid)) requireLdap=$($requireLdap.raw)(valid=$($requireLdap.valid)) requireAuditEvents=$($requireAuditEvents.raw)(valid=$($requireAuditEvents.valid)) expected typed booleans"
            }
        }
        if (-not $requireOidc.value -and -not $requireLdap.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "result=passed requires OIDC or LDAP target smoke selection"
            }
        }
        if ($passCount.value -le 0 -or $failCount.value -ne 0 -or $blockedCount.value -ne 0 -or $plannedCount.value -ne 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "result=passed passCount=$($passCount.value) failCount=$($failCount.value) blockedCount=$($blockedCount.value) plannedCount=$($plannedCount.value) expected passCount>0 and fail/block/planned=0"
            }
        }

        foreach ($statusName in @("FAIL", "BLOCKED", "PLANNED")) {
            if (@($checks | Where-Object { [string] (Get-JsonProperty $_ "status") -eq $statusName }).Count -gt 0) {
                return [pscustomobject]@{
                    passed = $false
                    detail = "result=passed contains $statusName check"
                }
            }
        }

        [object[]] $passRows = @($checks | Where-Object { [string] (Get-JsonProperty $_ "status") -eq "PASS" })
        [object[]] $skippedRows = @($checks | Where-Object { [string] (Get-JsonProperty $_ "status") -eq "SKIPPED" })
        if ($passRows.Count -ne $passCount.value -or $skippedRows.Count -ne $skippedCount.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "result=passed check status counts mismatch passRows=$($passRows.Count)/$($passCount.value) skippedRows=$($skippedRows.Count)/$($skippedCount.value)"
            }
        }

        foreach ($requiredCheck in @("admin-login", "enterprise-auth-plan")) {
            [object[]] $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheck -and [string] (Get-JsonProperty $_ "status") -eq "PASS" })
            if ($match.Count -ne 1) {
                return [pscustomobject]@{
                    passed = $false
                    detail = "checks.$requiredCheck missing PASS"
                }
            }
        }
        if ($requireOidc.value) {
            foreach ($requiredCheck in @("oidc-authorize", "oidc-callback")) {
                [object[]] $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheck -and [string] (Get-JsonProperty $_ "status") -eq "PASS" })
                if ($match.Count -ne 1) {
                    return [pscustomobject]@{
                        passed = $false
                        detail = "checks.$requiredCheck missing PASS"
                    }
                }
            }
        }
        if ($requireLdap.value) {
            [object[]] $ldapCheck = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq "ldap-login" -and [string] (Get-JsonProperty $_ "status") -eq "PASS" })
            if ($ldapCheck.Count -ne 1) {
                return [pscustomobject]@{
                    passed = $false
                    detail = "checks.ldap-login missing PASS"
                }
            }
        }
        if ($requireAuditEvents.value) {
            [object[]] $auditChecks = @($checks | Where-Object { ([string] (Get-JsonProperty $_ "id")).StartsWith("audit-log") -and [string] (Get-JsonProperty $_ "status") -eq "PASS" })
            if ($auditChecks.Count -le 0) {
                return [pscustomobject]@{
                    passed = $false
                    detail = "checks.audit-log missing PASS"
                }
            }
        }

        return [pscustomobject]@{
            passed = $true
            detail = "formatVersion=$formatVersion result=passed executionMode=$executionMode passCount=$($passCount.value) skippedCount=$($skippedCount.value) expected=passed|scope-out"
        }
    }
    if ($result -ne "scope-out") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected=passed|scope-out"
        }
    }
    if ($executionMode -ne "scope-out") {
        return [pscustomobject]@{
            passed = $false
            detail = "result=scope-out executionMode=$executionMode expected=scope-out"
        }
    }

    $scopeOut = Get-JsonProperty $json "scopeOut"
    $confirmed = Get-RequiredJsonBool $scopeOut "confirmed"
    $accepted = Get-RequiredJsonBool $scopeOut "accepted"
    $reference = [string] (Get-JsonProperty $scopeOut "reference")
    $reason = [string] (Get-JsonProperty $scopeOut "reason")
    if (-not $confirmed.valid -or -not $confirmed.value -or -not $accepted.valid -or -not $accepted.value -or [string]::IsNullOrWhiteSpace($reference) -or [string]::IsNullOrWhiteSpace($reason)) {
        return [pscustomobject]@{
            passed = $false
            detail = "result=scope-out confirmed=$($confirmed.raw)(valid=$($confirmed.valid)) accepted=$($accepted.raw)(valid=$($accepted.valid)) referencePresent=$(-not [string]::IsNullOrWhiteSpace($reference)) reasonPresent=$(-not [string]::IsNullOrWhiteSpace($reason)) expected confirmed/accepted boolean true with reference and reason"
        }
    }
    if ($passCount.value -ne 3 -or $failCount.value -ne 0 -or $blockedCount.value -ne 0 -or $plannedCount.value -ne 0 -or $skippedCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "result=scope-out passCount=$($passCount.value) failCount=$($failCount.value) blockedCount=$($blockedCount.value) plannedCount=$($plannedCount.value) skippedCount=$($skippedCount.value) expected pass=3 and fail/block/planned/skipped=0"
        }
    }
    foreach ($requiredCheck in @("enterprise-auth-scope-out-confirmed", "enterprise-auth-scope-out-ref", "enterprise-auth-scope-out-reason")) {
        [object[]] $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheck -and [string] (Get-JsonProperty $_ "status") -eq "PASS" })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheck missing PASS"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=scope-out executionMode=$executionMode accepted=true passCount=$($passCount.value) expected=passed|scope-out"
    }
}

function Test-EnterpriseAuthJitRollbackEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{ passed = $false; detail = "invalid JSON: $($_.Exception.Message)" }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.enterprise-auth-jit-rollback-evidence.v1") {
        return [pscustomobject]@{ passed = $false; detail = "formatVersion=$formatVersion expected=osmu.enterprise-auth-jit-rollback-evidence.v1" }
    }

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "generatedAt=$generatedAt expected ISO timestamp" }
    }

    foreach ($field in @("decisionRule", "scopePolicy", "secretPolicy", "environmentName", "targetCluster", "operatorName", "evidenceRef")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{ passed = $false; detail = "$field missing" }
        }
    }

    $patterns = @(
        '(?i)"(password|passwd|secret|token|credential|clientSecret|client_secret|ldapPassword|ldap_password|oidcCode|oidc_code|oidcState|oidc_state|rawClaim|rawClaims|claimPayload|claimJson|claimsJson|idToken|id_token|accessToken|access_token|refreshToken|refresh_token)"\s*:\s*"[^"]+"',
        '(?i)"(rawClaim|rawClaims|claimPayload|claimJson|claimsJson|idToken|id_token|accessToken|access_token|refreshToken|refresh_token)"\s*:',
        '(?i)\b(password|passwd|secret|token|credential|client[_-]?secret|ldap[_-]?password|oidc[_-]?code|oidc[_-]?state|private[_-]?key)\s*[=:]\s*\S+',
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    foreach ($pattern in $patterns) {
        if ($raw -match $pattern) {
            return [pscustomobject]@{ passed = $false; detail = "enterprise auth JIT rollback evidence contains raw claim, token, or credential-shaped content" }
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") {
        return [pscustomobject]@{ passed = $false; detail = "result=$result expected=passed" }
    }

    $reviewWindow = Get-JsonProperty $json "reviewWindow"
    $startedAt = [string] (Get-JsonProperty $reviewWindow "startedAt")
    $completedAt = [string] (Get-JsonProperty $reviewWindow "completedAt")
    $parsedStartedAt = [DateTimeOffset]::MinValue
    $parsedCompletedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($startedAt) -or -not [DateTimeOffset]::TryParse($startedAt, [ref] $parsedStartedAt) -or [string]::IsNullOrWhiteSpace($completedAt) -or -not [DateTimeOffset]::TryParse($completedAt, [ref] $parsedCompletedAt) -or $parsedCompletedAt -lt $parsedStartedAt) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow startedAt=$startedAt completedAt=$completedAt expected ordered ISO timestamps" }
    }

    $summary = Get-JsonProperty $json "summary"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $checkCount = Get-RequiredJsonInt $summary "checkCount"
    if (-not $failureCount.valid -or $failureCount.value -ne 0 -or -not $checkCount.valid -or $checkCount.value -le 0) {
        return [pscustomobject]@{ passed = $false; detail = "summary.failureCount=$($failureCount.raw)(valid=$($failureCount.valid)) summary.checkCount=$($checkCount.raw)(valid=$($checkCount.valid)) expected failures=0 and checkCount>0" }
    }

    $checksObject = Get-JsonProperty $json "checks"
    [object[]] $checks = if ($null -eq $checksObject) { @() } else { @($checksObject | ForEach-Object { $_ }) }
    if ($checks.Count -le 0 -or $checks.Count -ne $checkCount.value) {
        return [pscustomobject]@{ passed = $false; detail = "checks count=$($checks.Count) expected summary.checkCount=$($checkCount.value)" }
    }
    foreach ($check in $checks) {
        if ([string] (Get-JsonProperty $check "status") -ne "PASS") {
            return [pscustomobject]@{ passed = $false; detail = "check $([string] (Get-JsonProperty $check "id")) status=$([string] (Get-JsonProperty $check "status")) expected PASS" }
        }
    }

    $requiredChecks = @(
        "enterprise-auth-smoke-snapshot-accepted",
        "jit-provision-evidence-ref",
        "jit-rollback-runbook-ref",
        "user-disable-rollback-evidence-ref",
        "role-mapping-rollback-evidence-ref",
        "local-login-fallback-evidence-ref",
        "audit-review-evidence-ref",
        "admin-approval-required-confirmed",
        "callback-auto-jit-disabled-confirmed",
        "jit-user-disable-or-lock-rollback-confirmed",
        "role-org-team-rollback-confirmed",
        "local-login-fallback-confirmed",
        "audit-events-reviewed-confirmed",
        "no-raw-claims-confirmed",
        "no-secret-values-confirmed"
    )
    foreach ($requiredCheck in $requiredChecks) {
        [object[]] $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheck -and [string] (Get-JsonProperty $_ "status") -eq "PASS" })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{ passed = $false; detail = "checks.$requiredCheck missing PASS" }
        }
    }

    $refs = Get-JsonProperty $json "evidenceRefs"
    foreach ($field in @("changeApproval", "jitProvision", "jitRollbackRunbook", "userDisableRollback", "roleMappingRollback", "localLoginFallback", "auditReview")) {
        $value = [string] (Get-JsonProperty $refs $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{ passed = $false; detail = "evidenceRefs.$field missing" }
        }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($field in @("adminApprovalRequired", "callbackAutoJitDisabled", "jitUserDisableOrLockRollbackReviewed", "roleOrgTeamRollbackReviewed", "localPasswordFallbackValidated", "auditEventsReviewed", "noRawClaims", "noSecretValues")) {
        $value = Get-RequiredJsonBool $confirmations $field
        if (-not $value.valid -or -not $value.value) {
            return [pscustomobject]@{ passed = $false; detail = "confirmations.$field=$($value.raw)(valid=$($value.valid)) expected true" }
        }
    }

    $smoke = Get-JsonProperty $json "enterpriseAuthSmokeSnapshot"
    $smokeProvided = Get-RequiredJsonBool $smoke "provided"
    $smokeParsed = Get-RequiredJsonBool $smoke "parsed"
    $smokeFormatVersion = [string] (Get-JsonProperty $smoke "formatVersion")
    $smokeResult = [string] (Get-JsonProperty $smoke "result")
    if (-not $smokeProvided.valid -or -not $smokeProvided.value -or -not $smokeParsed.valid -or -not $smokeParsed.value -or $smokeFormatVersion -ne "osmu.enterprise-auth-smoke.v1") {
        return [pscustomobject]@{ passed = $false; detail = "enterpriseAuthSmokeSnapshot provided=$($smokeProvided.raw)(valid=$($smokeProvided.valid)) parsed=$($smokeParsed.raw)(valid=$($smokeParsed.valid)) formatVersion=$smokeFormatVersion expected accepted smoke snapshot" }
    }
    if ($smokeResult -eq "passed") {
        $passCount = Get-RequiredJsonInt $smoke "passCount"
        $failCount = Get-RequiredJsonInt $smoke "failCount"
        $blockedCount = Get-RequiredJsonInt $smoke "blockedCount"
        $plannedCount = Get-RequiredJsonInt $smoke "plannedCount"
        if (-not $passCount.valid -or $passCount.value -le 0 -or -not $failCount.valid -or $failCount.value -ne 0 -or -not $blockedCount.valid -or $blockedCount.value -ne 0 -or -not $plannedCount.valid -or $plannedCount.value -ne 0) {
            return [pscustomobject]@{ passed = $false; detail = "enterpriseAuthSmokeSnapshot result=passed pass=$($passCount.raw) fail=$($failCount.raw) blocked=$($blockedCount.raw) planned=$($plannedCount.raw) expected pass>0 and fail/block/planned=0" }
        }
    }
    elseif ($smokeResult -eq "scope-out") {
        $scopeOutAccepted = Get-RequiredJsonBool $smoke "scopeOutAccepted"
        if (-not $scopeOutAccepted.valid -or -not $scopeOutAccepted.value) {
            return [pscustomobject]@{ passed = $false; detail = "enterpriseAuthSmokeSnapshot scopeOutAccepted=$($scopeOutAccepted.raw)(valid=$($scopeOutAccepted.valid)) expected true" }
        }
    }
    else {
        return [pscustomobject]@{ passed = $false; detail = "enterpriseAuthSmokeSnapshot.result=$smokeResult expected passed|scope-out" }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=passed environmentName=$([string] (Get-JsonProperty $json "environmentName")) targetCluster=$([string] (Get-JsonProperty $json "targetCluster")) smokeResult=$smokeResult failures=$($failureCount.value) checkCount=$($checkCount.value)"
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

function Test-HandoffRequiredBoolTrue([object] $Object, [string] $Name, [string] $Label) {
    $value = Get-RequiredJsonBool $Object $Name
    if (-not $value.valid -or -not $value.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "$Label.$Name=$($value.raw) expected boolean true"
        }
    }
    return [pscustomobject]@{ passed = $true; detail = "$Label.$Name=true" }
}

function Test-HandoffRequiredIntEquals([object] $Object, [string] $Name, [int64] $Expected, [string] $Label) {
    $value = Get-RequiredJsonInt $Object $Name
    if (-not $value.valid -or [int64] $value.value -ne $Expected) {
        return [pscustomobject]@{
            passed = $false
            detail = "$Label.$Name=$($value.raw)(valid=$($value.valid)) expected integer $Expected"
        }
    }
    return [pscustomobject]@{ passed = $true; value = [int64] $value.value; detail = "$Label.$Name=$Expected" }
}

function Test-HandoffRequiredIntAtLeast([object] $Object, [string] $Name, [int64] $Minimum, [string] $Label) {
    $value = Get-RequiredJsonInt $Object $Name
    if (-not $value.valid -or [int64] $value.value -lt $Minimum) {
        return [pscustomobject]@{
            passed = $false
            detail = "$Label.$Name=$($value.raw)(valid=$($value.valid)) expected integer >= $Minimum"
        }
    }
    return [pscustomobject]@{ passed = $true; value = [int64] $value.value; detail = "$Label.$Name=$($value.value)" }
}

function Test-HandoffSnapshotBase([object] $Snapshot, [string] $Label, [string[]] $AllowedResults, [bool] $RequirePassedFlag) {
    if ($null -eq $Snapshot) {
        return [pscustomobject]@{
            passed = $false
            detail = "$Label missing"
        }
    }

    foreach ($field in @("provided", "parsed", "validFormatVersion")) {
        $fieldValidation = Test-HandoffRequiredBoolTrue $Snapshot $field $Label
        if (-not $fieldValidation.passed) {
            return $fieldValidation
        }
    }

    $result = [string] (Get-JsonProperty $Snapshot "result")
    $allowed = $false
    foreach ($allowedResult in $AllowedResults) {
        if ($allowedResult.Equals($result, [System.StringComparison]::OrdinalIgnoreCase)) {
            $allowed = $true
            break
        }
    }
    if (-not $allowed) {
        return [pscustomobject]@{
            passed = $false
            detail = "$Label.result=$result expected=$($AllowedResults -join '|')"
        }
    }

    if ($RequirePassedFlag) {
        $passedValidation = Test-HandoffRequiredBoolTrue $Snapshot "passed" $Label
        if (-not $passedValidation.passed) {
            return $passedValidation
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "$Label.result=$result"
    }
}

function Get-FirstJsonPropertyText([object] $Object, [string[]] $Names) {
    foreach ($name in $Names) {
        $value = [string] (Get-JsonProperty $Object $name)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }
    return ""
}

function Get-HandoffPackageIdentityText([object] $Json, [string] $FieldName) {
    $target = Get-JsonProperty $Json "target"
    switch ($FieldName) {
        "environmentName" {
            $value = Get-FirstJsonPropertyText $Json @("environmentName")
            if ([string]::IsNullOrWhiteSpace($value)) { $value = Get-FirstJsonPropertyText $target @("environmentName") }
            return $value
        }
        "targetCluster" {
            $value = Get-FirstJsonPropertyText $Json @("targetCluster", "cluster")
            if ([string]::IsNullOrWhiteSpace($value)) { $value = Get-FirstJsonPropertyText $target @("targetCluster", "cluster") }
            return $value
        }
        "operatorName" {
            $value = Get-FirstJsonPropertyText $Json @("operatorName", "operator")
            if ([string]::IsNullOrWhiteSpace($value)) { $value = Get-FirstJsonPropertyText $target @("operatorName", "operator") }
            return $value
        }
        default { return Get-FirstJsonPropertyText $Json @($FieldName) }
    }
}

function Get-HandoffSnapshotIdentityText([object] $Snapshot, [string] $FieldName) {
    switch ($FieldName) {
        "environmentName" { return Get-FirstJsonPropertyText $Snapshot @("environmentName") }
        "targetCluster" { return Get-FirstJsonPropertyText $Snapshot @("targetCluster", "cluster") }
        "operatorName" { return Get-FirstJsonPropertyText $Snapshot @("operatorName", "operator") }
        default { return Get-FirstJsonPropertyText $Snapshot @($FieldName) }
    }
}

function Test-HandoffTargetIdentityField([object] $Snapshot, [string] $Label, [string] $FieldName, [string] $ExpectedValue) {
    $actualValue = Get-HandoffSnapshotIdentityText $Snapshot $FieldName
    if ([string]::IsNullOrWhiteSpace($ExpectedValue)) {
        return "$Label.$FieldName cannot be checked because handoff $FieldName is missing"
    }
    if ([string]::IsNullOrWhiteSpace($actualValue)) {
        return "$Label.$FieldName missing; expected=$ExpectedValue"
    }
    if (-not $ExpectedValue.Equals($actualValue, [System.StringComparison]::Ordinal)) {
        return "$Label.$FieldName=$actualValue expected=$ExpectedValue"
    }
    return ""
}

function Test-OperationsHandoffPackageTargetIdentity([object] $Json, [object[]] $Entries) {
    $expectedEnvironmentName = Get-HandoffPackageIdentityText $Json "environmentName"
    $expectedTargetCluster = Get-HandoffPackageIdentityText $Json "targetCluster"
    $expectedOperatorName = Get-HandoffPackageIdentityText $Json "operatorName"
    $checked = 0
    foreach ($entry in $Entries) {
        if (-not [bool] $entry.required) {
            continue
        }
        $checked += 1
        $snapshot = $entry.snapshot
        foreach ($field in @(
            @("environmentName", $expectedEnvironmentName),
            @("targetCluster", $expectedTargetCluster),
            @("operatorName", $expectedOperatorName)
        )) {
            $failure = Test-HandoffTargetIdentityField $snapshot ([string] $entry.label) ([string] $field[0]) ([string] $field[1])
            if (-not [string]::IsNullOrWhiteSpace($failure)) {
                return [pscustomobject]@{ passed = $false; detail = $failure }
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "targetIdentity=$checked/$checked environmentName=$expectedEnvironmentName targetCluster=$expectedTargetCluster operatorName=$expectedOperatorName"
    }
}
function Test-OperationsHandoffPackageEvidenceRefs([object] $Json) {
    $evidenceRefs = Get-JsonProperty $Json "evidenceRefs"
    if ($null -eq $evidenceRefs) {
        return [pscustomobject]@{
            passed = $false
            detail = "evidenceRefs expected"
        }
    }

    $requiredRefs = @(
        "changeApproval",
        "deployment",
        "operationsReadiness",
        "operationsConvergence",
        "dataFlowStoragePlan",
        "dataFlowQueryRetentionBudget",
        "dataFlowStorageTransitionRunbook",
        "secretRotation",
        "commercialIntegration",
        "commercialApproval",
        "chargebackCloseout",
        "enterpriseAuth",
        "backupRestore",
        "haDr",
        "monitoring",
        "clusterNetworkAccessReview",
        "helmValuesHardening",
        "security",
        "iamRbac",
        "runbookReview",
        "troubleshootingReview",
        "supportEscalation",
        "supportSla",
        "knownGaps"
    )
    foreach ($refName in $requiredRefs) {
        $refValue = [string] (Get-JsonProperty $evidenceRefs $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) {
            return [pscustomobject]@{
                passed = $false
                detail = "evidenceRefs.$refName missing"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "evidenceRefs=$($requiredRefs.Count)/$($requiredRefs.Count)"
    }
}

function Test-OperationsHandoffPackageTargetSnapshots([object] $Json) {
    $targetSnapshots = Get-JsonProperty $Json "targetEvidenceSnapshots"
    if ($null -eq $targetSnapshots) {
        return [pscustomobject]@{
            passed = $false
            detail = "targetEvidenceSnapshots expected"
        }
    }
    $validatedSnapshotCount = 11

    $plan = Get-JsonProperty $targetSnapshots "dataFlowStoragePlan"
    $base = Test-HandoffSnapshotBase $plan "targetEvidenceSnapshots.dataFlowStoragePlan" @("passed") $true
    if (-not $base.passed) { return $base }
    $candidateStore = [string] (Get-JsonProperty $plan "candidateStore")
    if ($candidateStore -notin @("MARIADB_PARTITION", "EXTERNAL_TIME_SERIES", "DUAL_WRITE")) {
        return [pscustomobject]@{ passed = $false; detail = "targetEvidenceSnapshots.dataFlowStoragePlan.candidateStore=$candidateStore expected=MARIADB_PARTITION|EXTERNAL_TIME_SERIES|DUAL_WRITE" }
    }
    foreach ($field in @("queryPlanEvidencePassed")) {
        $validation = Test-HandoffRequiredBoolTrue $plan $field "targetEvidenceSnapshots.dataFlowStoragePlan"
        if (-not $validation.passed) { return $validation }
    }
    foreach ($field in @("checkCount", "passedCount")) {
        $validation = Test-HandoffRequiredIntAtLeast $plan $field 1 "targetEvidenceSnapshots.dataFlowStoragePlan"
        if (-not $validation.passed) { return $validation }
    }
    $validation = Test-HandoffRequiredIntEquals $plan "pendingCount" 0 "targetEvidenceSnapshots.dataFlowStoragePlan"
    if (-not $validation.passed) { return $validation }

    $queryRetentionBudget = Get-JsonProperty $targetSnapshots "dataFlowQueryRetentionBudget"
    $base = Test-HandoffSnapshotBase $queryRetentionBudget "targetEvidenceSnapshots.dataFlowQueryRetentionBudget" @("passed") $true
    if (-not $base.passed) { return $base }
    foreach ($field in @("queryLatencyWithinBudget", "retentionJobsWithinBudget", "confirmationsValid")) {
        $validation = Test-HandoffRequiredBoolTrue $queryRetentionBudget $field "targetEvidenceSnapshots.dataFlowQueryRetentionBudget"
        if (-not $validation.passed) { return $validation }
    }
    $targetP95 = Get-RequiredJsonInt $queryRetentionBudget "targetP95QueryLatencyMs"
    $observedP95 = Get-RequiredJsonInt $queryRetentionBudget "observedP95QueryLatencyMs"
    $observedP99 = Get-RequiredJsonInt $queryRetentionBudget "observedP99QueryLatencyMs"
    $sampleCount = Get-RequiredJsonInt $queryRetentionBudget "querySampleCount"
    $windowDays = Get-RequiredJsonInt $queryRetentionBudget "observedQueryWindowDays"
    if (-not $targetP95.valid -or -not $observedP95.valid -or -not $observedP99.valid -or -not $sampleCount.valid -or -not $windowDays.valid -or [int64] $targetP95.value -le 0 -or [int64] $observedP95.value -gt [int64] $targetP95.value -or [int64] $observedP99.value -lt [int64] $observedP95.value -or [int64] $sampleCount.value -le 0 -or [int64] $windowDays.value -le 0) {
        return [pscustomobject]@{ passed = $false; detail = "targetEvidenceSnapshots.dataFlowQueryRetentionBudget query metrics invalid targetP95=$($targetP95.raw) observedP95=$($observedP95.raw) observedP99=$($observedP99.raw) sampleCount=$($sampleCount.raw) windowDays=$($windowDays.raw)" }
    }
    $budgetSeconds = Get-RequiredJsonInt $queryRetentionBudget "retentionJobBudgetSeconds"
    $detailedSeconds = Get-RequiredJsonInt $queryRetentionBudget "detailedRetentionObservedSeconds"
    $dailySeconds = Get-RequiredJsonInt $queryRetentionBudget "dailyRollupRetentionObservedSeconds"
    $monthlySeconds = Get-RequiredJsonInt $queryRetentionBudget "monthlyRollupRetentionObservedSeconds"
    if (-not $budgetSeconds.valid -or -not $detailedSeconds.valid -or -not $dailySeconds.valid -or -not $monthlySeconds.valid -or [int64] $budgetSeconds.value -le 0 -or [int64] $detailedSeconds.value -gt [int64] $budgetSeconds.value -or [int64] $dailySeconds.value -gt [int64] $budgetSeconds.value -or [int64] $monthlySeconds.value -gt [int64] $budgetSeconds.value) {
        return [pscustomobject]@{ passed = $false; detail = "targetEvidenceSnapshots.dataFlowQueryRetentionBudget retention metrics invalid budget=$($budgetSeconds.raw) detailed=$($detailedSeconds.raw) daily=$($dailySeconds.raw) monthly=$($monthlySeconds.raw)" }
    }
    $validation = Test-HandoffRequiredIntEquals $queryRetentionBudget "failureCount" 0 "targetEvidenceSnapshots.dataFlowQueryRetentionBudget"
    if (-not $validation.passed) { return $validation }
    $validation = Test-HandoffRequiredIntAtLeast $queryRetentionBudget "checkCount" 1 "targetEvidenceSnapshots.dataFlowQueryRetentionBudget"
    if (-not $validation.passed) { return $validation }
    $runbook = Get-JsonProperty $targetSnapshots "dataFlowStorageTransitionRunbook"
    $base = Test-HandoffSnapshotBase $runbook "targetEvidenceSnapshots.dataFlowStorageTransitionRunbook" @("passed") $true
    if (-not $base.passed) { return $base }
    foreach ($field in @("confirmationsValid")) {
        $validation = Test-HandoffRequiredBoolTrue $runbook $field "targetEvidenceSnapshots.dataFlowStorageTransitionRunbook"
        if (-not $validation.passed) { return $validation }
    }
    foreach ($field in @("failureCount")) {
        $validation = Test-HandoffRequiredIntEquals $runbook $field 0 "targetEvidenceSnapshots.dataFlowStorageTransitionRunbook"
        if (-not $validation.passed) { return $validation }
    }
    $validation = Test-HandoffRequiredIntAtLeast $runbook "checkCount" 1 "targetEvidenceSnapshots.dataFlowStorageTransitionRunbook"
    if (-not $validation.passed) { return $validation }

    $secretRotation = Get-JsonProperty $targetSnapshots "secretRotation"
    $base = Test-HandoffSnapshotBase $secretRotation "targetEvidenceSnapshots.secretRotation" @("passed") $true
    if (-not $base.passed) { return $base }
    $validation = Test-HandoffRequiredBoolTrue $secretRotation "confirmationsValid" "targetEvidenceSnapshots.secretRotation"
    if (-not $validation.passed) { return $validation }
    $coreRequiredCount = Get-RequiredJsonInt $secretRotation "coreRequiredCount"
    $coreRotatedCount = Get-RequiredJsonInt $secretRotation "coreRotatedCount"
    if (-not $coreRequiredCount.valid -or -not $coreRotatedCount.valid -or [int64] $coreRequiredCount.value -le 0 -or [int64] $coreRotatedCount.value -lt [int64] $coreRequiredCount.value) {
        return [pscustomobject]@{ passed = $false; detail = "targetEvidenceSnapshots.secretRotation coreRotated=$($coreRotatedCount.raw)(valid=$($coreRotatedCount.valid))/coreRequired=$($coreRequiredCount.raw)(valid=$($coreRequiredCount.valid)) expected coreRotated>=coreRequired>0" }
    }
    foreach ($field in @("failureCount", "plannedCount")) {
        $validation = Test-HandoffRequiredIntEquals $secretRotation $field 0 "targetEvidenceSnapshots.secretRotation"
        if (-not $validation.passed) { return $validation }
    }

    $commercialIntegration = Get-JsonProperty $targetSnapshots "commercialIntegration"
    $base = Test-HandoffSnapshotBase $commercialIntegration "targetEvidenceSnapshots.commercialIntegration" @("passed") $true
    if (-not $base.passed) { return $base }
    foreach ($field in @("countsValid", "paymentProviderAdapterReadinessReviewed", "paymentProviderAdapterReadinessReviewedValid")) {
        $validation = Test-HandoffRequiredBoolTrue $commercialIntegration $field "targetEvidenceSnapshots.commercialIntegration"
        if (-not $validation.passed) { return $validation }
    }
    $requiredCount = Get-RequiredJsonInt $commercialIntegration "requiredCount"
    $requiredVerifiedCount = Get-RequiredJsonInt $commercialIntegration "requiredVerifiedCount"
    $verifiedCount = Get-RequiredJsonInt $commercialIntegration "verifiedCount"
    $integrationCount = Get-RequiredJsonInt $commercialIntegration "integrationCount"
    if (-not $requiredCount.valid -or -not $requiredVerifiedCount.valid -or -not $verifiedCount.valid -or -not $integrationCount.valid -or [int64] $requiredCount.value -le 0 -or [int64] $requiredVerifiedCount.value -lt [int64] $requiredCount.value -or [int64] $verifiedCount.value -lt [int64] $requiredVerifiedCount.value -or [int64] $integrationCount.value -lt [int64] $requiredCount.value) {
        return [pscustomobject]@{ passed = $false; detail = "targetEvidenceSnapshots.commercialIntegration counts invalid required=$($requiredCount.raw) requiredVerified=$($requiredVerifiedCount.raw) verified=$($verifiedCount.raw) integration=$($integrationCount.raw)" }
    }
    foreach ($field in @("failureCount", "plannedCount")) {
        $validation = Test-HandoffRequiredIntEquals $commercialIntegration $field 0 "targetEvidenceSnapshots.commercialIntegration"
        if (-not $validation.passed) { return $validation }
    }

    $commercialApproval = Get-JsonProperty $targetSnapshots "commercialApproval"
    $base = Test-HandoffSnapshotBase $commercialApproval "targetEvidenceSnapshots.commercialApproval" @("passed") $true
    if (-not $base.passed) { return $base }
    foreach ($field in @("countsValid", "pricingPolicyProposalCommercialApproved", "pricingPolicyProposalCommercialApprovedValid")) {
        $validation = Test-HandoffRequiredBoolTrue $commercialApproval $field "targetEvidenceSnapshots.commercialApproval"
        if (-not $validation.passed) { return $validation }
    }
    foreach ($field in @("passedCount", "checkCount", "pricingPolicyProposalCommercialApprovedCount", "pricingPolicyProposalApprovedPriceListCount")) {
        $validation = Test-HandoffRequiredIntAtLeast $commercialApproval $field 1 "targetEvidenceSnapshots.commercialApproval"
        if (-not $validation.passed) { return $validation }
    }
    $validation = Test-HandoffRequiredIntEquals $commercialApproval "failureCount" 0 "targetEvidenceSnapshots.commercialApproval"
    if (-not $validation.passed) { return $validation }

    $chargebackCloseout = Get-JsonProperty $targetSnapshots "chargebackCloseout"
    $base = Test-HandoffSnapshotBase $chargebackCloseout "targetEvidenceSnapshots.chargebackCloseout" @("passed") $true
    if (-not $base.passed) { return $base }
    foreach ($field in @("summaryValid", "confirmationsValid", "closeoutCountsValid", "rawDataFlagsValid", "noRawDataStored")) {
        $validation = Test-HandoffRequiredBoolTrue $chargebackCloseout $field "targetEvidenceSnapshots.chargebackCloseout"
        if (-not $validation.passed) { return $validation }
    }
    foreach ($field in @("failureCount", "plannedCount", "reconciliationDifferenceMinorUnits")) {
        $validation = Test-HandoffRequiredIntEquals $chargebackCloseout $field 0 "targetEvidenceSnapshots.chargebackCloseout"
        if (-not $validation.passed) { return $validation }
    }
    foreach ($field in @("checkCount", "passCount")) {
        $validation = Test-HandoffRequiredIntAtLeast $chargebackCloseout $field 1 "targetEvidenceSnapshots.chargebackCloseout"
        if (-not $validation.passed) { return $validation }
    }
    $closeoutSnapshot = Get-JsonProperty $chargebackCloseout "chargebackCloseoutSnapshot"
    foreach ($field in @("valid", "statusClosed", "billingPeriodMatches", "failureCountZero", "noRawDataStored")) {
        $validation = Test-HandoffRequiredBoolTrue $closeoutSnapshot $field "targetEvidenceSnapshots.chargebackCloseout.chargebackCloseoutSnapshot"
        if (-not $validation.passed) { return $validation }
    }
    $rawFlags = Get-JsonProperty $closeoutSnapshot "rawDataFlags"
    foreach ($field in @("rawCustomerPaymentDataStored", "rawProviderResponseStored", "rawSecretValuesStored")) {
        $flag = Get-RequiredJsonBool $rawFlags $field
        if (-not $flag.valid -or $flag.value) {
            return [pscustomobject]@{ passed = $false; detail = "targetEvidenceSnapshots.chargebackCloseout.chargebackCloseoutSnapshot.rawDataFlags.$field=$($flag.raw) expected boolean false" }
        }
    }

    $enterpriseAuth = Get-JsonProperty $targetSnapshots "enterpriseAuthSmoke"
    $base = Test-HandoffSnapshotBase $enterpriseAuth "targetEvidenceSnapshots.enterpriseAuthSmoke" @("passed", "scope-out") $false
    if (-not $base.passed) { return $base }
    $enterpriseAuthResult = [string] (Get-JsonProperty $enterpriseAuth "result")
    if ("scope-out".Equals($enterpriseAuthResult, [System.StringComparison]::OrdinalIgnoreCase)) {
        foreach ($field in @("scopeOutAccepted", "scopeOutAcceptedValid")) {
            $validation = Test-HandoffRequiredBoolTrue $enterpriseAuth $field "targetEvidenceSnapshots.enterpriseAuthSmoke"
            if (-not $validation.passed) { return $validation }
        }
    }
    else {
        foreach ($field in @("passed", "countsValid")) {
            $validation = Test-HandoffRequiredBoolTrue $enterpriseAuth $field "targetEvidenceSnapshots.enterpriseAuthSmoke"
            if (-not $validation.passed) { return $validation }
        }
        $validation = Test-HandoffRequiredIntAtLeast $enterpriseAuth "passCount" 1 "targetEvidenceSnapshots.enterpriseAuthSmoke"
        if (-not $validation.passed) { return $validation }
        foreach ($field in @("failCount", "blockedCount", "plannedCount")) {
            $validation = Test-HandoffRequiredIntEquals $enterpriseAuth $field 0 "targetEvidenceSnapshots.enterpriseAuthSmoke"
            if (-not $validation.passed) { return $validation }
        }
    }

    $enterpriseAuthJitRollback = Get-JsonProperty $targetSnapshots "enterpriseAuthJitRollback"
    $enterpriseAuthJitRollbackProvided = $false
    if ($null -ne $enterpriseAuthJitRollback) {
        $jitProvided = Get-RequiredJsonBool $enterpriseAuthJitRollback "provided"
        $jitResult = [string] (Get-JsonProperty $enterpriseAuthJitRollback "result")
        $enterpriseAuthJitRollbackProvided = ($jitProvided.valid -and $jitProvided.value) -or -not [string]::IsNullOrWhiteSpace($jitResult)
    }
    if ($enterpriseAuthJitRollbackProvided) {
        $validatedSnapshotCount = 12
        $base = Test-HandoffSnapshotBase $enterpriseAuthJitRollback "targetEvidenceSnapshots.enterpriseAuthJitRollback" @("passed") $true
        if (-not $base.passed) { return $base }
        $validation = Test-HandoffRequiredBoolTrue $enterpriseAuthJitRollback "confirmationsValid" "targetEvidenceSnapshots.enterpriseAuthJitRollback"
        if (-not $validation.passed) { return $validation }
        $validation = Test-HandoffRequiredIntEquals $enterpriseAuthJitRollback "failureCount" 0 "targetEvidenceSnapshots.enterpriseAuthJitRollback"
        if (-not $validation.passed) { return $validation }
        $validation = Test-HandoffRequiredIntAtLeast $enterpriseAuthJitRollback "checkCount" 1 "targetEvidenceSnapshots.enterpriseAuthJitRollback"
        if (-not $validation.passed) { return $validation }
        $jitSmoke = Get-JsonProperty $enterpriseAuthJitRollback "enterpriseAuthSmokeSnapshot"
        $jitSmokeResult = [string] (Get-JsonProperty $jitSmoke "result")
        if ([string]::IsNullOrWhiteSpace($jitSmokeResult)) {
            return [pscustomobject]@{ passed = $false; detail = "targetEvidenceSnapshots.enterpriseAuthJitRollback.enterpriseAuthSmokeSnapshot.result expected" }
        }
    }

    $monitoring = Get-JsonProperty $targetSnapshots "monitoringThreshold"
    $base = Test-HandoffSnapshotBase $monitoring "targetEvidenceSnapshots.monitoringThreshold" @("passed") $true
    if (-not $base.passed) { return $base }
    $validation = Test-HandoffRequiredBoolTrue $monitoring "complete" "targetEvidenceSnapshots.monitoringThreshold"
    if (-not $validation.passed) { return $validation }
    foreach ($field in @("alertTargetCoverageComplete", "routeCoverageComplete", "grafanaPanelCoverageComplete", "tuningEvidenceCoverageComplete", "thresholdMappingComplete")) {
        $validation = Test-HandoffRequiredBoolTrue $monitoring $field "targetEvidenceSnapshots.monitoringThreshold"
        if (-not $validation.passed) { return $validation }
    }
    $requiredAlertCount = Get-RequiredJsonInt $monitoring "requiredAlertCount"
    $mappedAlertCount = Get-RequiredJsonInt $monitoring "mappedAlertCount"
    $grafanaPanelCount = Get-RequiredJsonInt $monitoring "grafanaPanelCount"
    $tuningEvidenceCount = Get-RequiredJsonInt $monitoring "tuningEvidenceCount"
    if (-not $requiredAlertCount.valid -or -not $mappedAlertCount.valid -or -not $grafanaPanelCount.valid -or -not $tuningEvidenceCount.valid -or [int64] $requiredAlertCount.value -le 0 -or [int64] $mappedAlertCount.value -lt [int64] $requiredAlertCount.value -or [int64] $grafanaPanelCount.value -lt [int64] $requiredAlertCount.value -or [int64] $tuningEvidenceCount.value -lt [int64] $requiredAlertCount.value) {
        return [pscustomobject]@{ passed = $false; detail = "targetEvidenceSnapshots.monitoringThreshold counts invalid required=$($requiredAlertCount.raw) mapped=$($mappedAlertCount.raw) grafana=$($grafanaPanelCount.raw) tuning=$($tuningEvidenceCount.raw)" }
    }
    foreach ($field in @("missingAlertCount", "failureCount")) {
        $validation = Test-HandoffRequiredIntEquals $monitoring $field 0 "targetEvidenceSnapshots.monitoringThreshold"
        if (-not $validation.passed) { return $validation }
    }

    $clusterNetworkAccessReview = Get-JsonProperty $targetSnapshots "clusterNetworkAccessReview"
    $base = Test-HandoffSnapshotBase $clusterNetworkAccessReview "targetEvidenceSnapshots.clusterNetworkAccessReview" @("passed") $true
    if (-not $base.passed) { return $base }
    foreach ($field in @("staticControlsValid", "confirmationsValid")) {
        $validation = Test-HandoffRequiredBoolTrue $clusterNetworkAccessReview $field "targetEvidenceSnapshots.clusterNetworkAccessReview"
        if (-not $validation.passed) { return $validation }
    }
    $validation = Test-HandoffRequiredIntEquals $clusterNetworkAccessReview "failureCount" 0 "targetEvidenceSnapshots.clusterNetworkAccessReview"
    if (-not $validation.passed) { return $validation }
    $validation = Test-HandoffRequiredIntAtLeast $clusterNetworkAccessReview "totalCount" 1 "targetEvidenceSnapshots.clusterNetworkAccessReview"
    if (-not $validation.passed) { return $validation }

    $helmValuesHardening = Get-JsonProperty $targetSnapshots "helmValuesHardening"
    $base = Test-HandoffSnapshotBase $helmValuesHardening "targetEvidenceSnapshots.helmValuesHardening" @("passed") $true
    if (-not $base.passed) { return $base }
    foreach ($field in @("staticHardeningValid", "confirmationsValid")) {
        $validation = Test-HandoffRequiredBoolTrue $helmValuesHardening $field "targetEvidenceSnapshots.helmValuesHardening"
        if (-not $validation.passed) { return $validation }
    }
    $validation = Test-HandoffRequiredIntEquals $helmValuesHardening "failureCount" 0 "targetEvidenceSnapshots.helmValuesHardening"
    if (-not $validation.passed) { return $validation }
    foreach ($field in @("totalCount", "chartFileCount")) {
        $validation = Test-HandoffRequiredIntAtLeast $helmValuesHardening $field 1 "targetEvidenceSnapshots.helmValuesHardening"
        if (-not $validation.passed) { return $validation }
    }

    $identityValidation = Test-OperationsHandoffPackageTargetIdentity $Json @(
        [pscustomobject]@{ label = "targetEvidenceSnapshots.dataFlowStoragePlan"; snapshot = $plan; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.dataFlowQueryRetentionBudget"; snapshot = $queryRetentionBudget; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.dataFlowStorageTransitionRunbook"; snapshot = $runbook; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.secretRotation"; snapshot = $secretRotation; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.commercialIntegration"; snapshot = $commercialIntegration; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.commercialApproval"; snapshot = $commercialApproval; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.chargebackCloseout"; snapshot = $chargebackCloseout; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.enterpriseAuthSmoke"; snapshot = $enterpriseAuth; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.enterpriseAuthJitRollback"; snapshot = $enterpriseAuthJitRollback; required = $enterpriseAuthJitRollbackProvided },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.monitoringThreshold"; snapshot = $monitoring; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.clusterNetworkAccessReview"; snapshot = $clusterNetworkAccessReview; required = $true },
        [pscustomobject]@{ label = "targetEvidenceSnapshots.helmValuesHardening"; snapshot = $helmValuesHardening; required = $true }
    )
    if (-not $identityValidation.passed) {
        return $identityValidation
    }

    return [pscustomobject]@{
        passed = $true
        detail = "targetSnapshots=$validatedSnapshotCount/$validatedSnapshotCount; $($identityValidation.detail)"
    }
}
function Test-OperationsHandoffPackageSummary([object] $Json) {
    $summary = Get-JsonProperty $Json "summary"
    if ($null -eq $summary) {
        return [pscustomobject]@{
            passed = $false
            detail = "summary expected"
        }
    }

    $passedCount = Get-RequiredJsonInt $summary "passedCount"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $plannedCount = Get-RequiredJsonInt $summary "plannedCount"
    $checkCount = Get-RequiredJsonInt $summary "checkCount"
    if (-not $passedCount.valid -or -not $failureCount.valid -or -not $plannedCount.valid -or -not $checkCount.valid) {
        return [pscustomobject]@{ passed = $false; detail = "summary counts invalid passed=$($passedCount.raw) failure=$($failureCount.raw) planned=$($plannedCount.raw) check=$($checkCount.raw)" }
    }
    if ([int64] $failureCount.value -ne 0 -or [int64] $plannedCount.value -ne 0 -or [int64] $checkCount.value -le 0 -or [int64] $passedCount.value -ne [int64] $checkCount.value) {
        return [pscustomobject]@{ passed = $false; detail = "summary passed=$($passedCount.value) failure=$($failureCount.value) planned=$($plannedCount.value) check=$($checkCount.value) expected passed=check>0 and failure/planned=0" }
    }

    foreach ($field in @("operationsReadinessSnapshotResult", "operationsConvergenceSnapshotResult")) {
        $value = [string] (Get-JsonProperty $summary $field)
        if (-not (Test-ReadyText $value)) {
            return [pscustomobject]@{ passed = $false; detail = "summary.$field=$value expected=ready" }
        }
    }
    foreach ($field in @("operationsConvergenceFinalizerFailedCount", "operationsConvergenceFinalizerGapCount")) {
        $validation = Test-HandoffRequiredIntEquals $summary $field 0 "summary"
        if (-not $validation.passed) { return $validation }
    }
    $syncReady = Get-RequiredJsonBool $summary "operationsConvergenceKubernetesReportSyncReady"
    if (-not $syncReady.valid -or -not $syncReady.value) {
        return [pscustomobject]@{ passed = $false; detail = "summary.operationsConvergenceKubernetesReportSyncReady=$($syncReady.raw) expected boolean true" }
    }
    $sourceReportResult = [string] (Get-JsonProperty $summary "operationsConvergenceKubernetesReportSyncSourceReportResult")
    if (-not (Test-ReadyText $sourceReportResult)) {
        return [pscustomobject]@{ passed = $false; detail = "summary.operationsConvergenceKubernetesReportSyncSourceReportResult=$sourceReportResult expected=ready" }
    }

    foreach ($field in @(
        "dataFlowStoragePlanSnapshotResult",
        "dataFlowQueryRetentionBudgetSnapshotResult",
        "dataFlowStorageTransitionRunbookSnapshotResult",
        "secretRotationSnapshotResult",
        "commercialIntegrationSnapshotResult",
        "commercialApprovalSnapshotResult",
        "chargebackCloseoutSnapshotResult",
        "monitoringThresholdSnapshotResult",
        "clusterNetworkAccessReviewSnapshotResult",
        "helmValuesHardeningSnapshotResult"
    )) {
        $value = [string] (Get-JsonProperty $summary $field)
        if (-not "passed".Equals($value, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{ passed = $false; detail = "summary.$field=$value expected=passed" }
        }
    }

    $enterpriseAuthResult = [string] (Get-JsonProperty $summary "enterpriseAuthSmokeSnapshotResult")
    if (-not ("passed".Equals($enterpriseAuthResult, [System.StringComparison]::OrdinalIgnoreCase) -or "scope-out".Equals($enterpriseAuthResult, [System.StringComparison]::OrdinalIgnoreCase))) {
        return [pscustomobject]@{ passed = $false; detail = "summary.enterpriseAuthSmokeSnapshotResult=$enterpriseAuthResult expected=passed|scope-out" }
    }
    $targetSnapshots = Get-JsonProperty $Json "targetEvidenceSnapshots"
    $jitSnapshot = Get-JsonProperty $targetSnapshots "enterpriseAuthJitRollback"
    $jitProvided = $false
    if ($null -ne $jitSnapshot) {
        $jitProvidedResult = Get-RequiredJsonBool $jitSnapshot "provided"
        $jitSnapshotResult = [string] (Get-JsonProperty $jitSnapshot "result")
        $jitProvided = ($jitProvidedResult.valid -and $jitProvidedResult.value) -or -not [string]::IsNullOrWhiteSpace($jitSnapshotResult)
    }
    $jitSummaryResult = [string] (Get-JsonProperty $summary "enterpriseAuthJitRollbackSnapshotResult")
    if ($jitProvided -and -not "passed".Equals($jitSummaryResult, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ passed = $false; detail = "summary.enterpriseAuthJitRollbackSnapshotResult=$jitSummaryResult expected=passed" }
    }
    if (-not $jitProvided -and -not [string]::IsNullOrWhiteSpace($jitSummaryResult) -and -not "passed".Equals($jitSummaryResult, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ passed = $false; detail = "summary.enterpriseAuthJitRollbackSnapshotResult=$jitSummaryResult expected=passed or blank" }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "summaryCheckCount=$($checkCount.value) targetSnapshotResults=passed"
    }
}

function Test-OperationsHandoffPackageChecks([object] $Json) {
    $summary = Get-JsonProperty $Json "summary"
    $expectedCount = Get-RequiredJsonInt $summary "checkCount"
    if (-not $expectedCount.valid) {
        return [pscustomobject]@{
            passed = $false
            detail = "summary.checkCount=$($expectedCount.raw) expected integer"
        }
    }

    $checksRaw = Get-JsonProperty $Json "checks"
    if ($null -eq $checksRaw) {
        return [pscustomobject]@{
            passed = $false
            detail = "checks expected"
        }
    }
    [object[]] $checks = @($checksRaw)
    if ($checks.Count -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "checkCount=$($checks.Count) expected >0"
        }
    }
    if ($checks.Count -ne [int64] $expectedCount.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "checks.Count=$($checks.Count) summary.checkCount=$($expectedCount.value) expected equal"
        }
    }

    foreach ($check in $checks) {
        $id = [string] (Get-JsonProperty $check "id")
        $status = [string] (Get-JsonProperty $check "status")
        $passed = Get-RequiredJsonBool $check "passed"
        if ([string]::IsNullOrWhiteSpace($id)) {
            return [pscustomobject]@{ passed = $false; detail = "checks row missing id" }
        }
        if (-not "PASS".Equals($status, [System.StringComparison]::OrdinalIgnoreCase) -or -not $passed.valid -or -not $passed.value) {
            return [pscustomobject]@{ passed = $false; detail = "checks.$id status=$status passed=$($passed.raw) expected PASS and boolean true" }
        }
    }

    $requiredCheckIds = @(
        "environment-name",
        "target-cluster",
        "operator",
        "handoff-started-at",
        "handoff-completed-at",
        "handoff-window-order",
        "change-approval-ref",
        "no-secret-values-confirmed",
        "runbook-reviewed",
        "troubleshooting-reviewed",
        "rollback-reviewed",
        "support-escalation-reviewed",
        "known-gaps-accepted",
        "operations-readiness-evidence",
        "operations-convergence-evidence",
        "operations-readiness-snapshot-ready",
        "operations-convergence-snapshot-ready",
        "data-flow-storage-plan-evidence",
        "data-flow-storage-plan-snapshot-passed",
        "data-flow-storage-plan-reviewed",
        "data-flow-query-retention-budget-evidence",
        "data-flow-query-retention-budget-snapshot-passed",
        "data-flow-query-retention-budget-reviewed",
        "data-flow-storage-transition-runbook-evidence",
        "data-flow-storage-transition-runbook-snapshot-passed",
        "data-flow-storage-transition-runbook-reviewed",
        "secret-rotation-evidence",
        "secret-rotation-snapshot-passed",
        "secret-rotation-snapshot-reviewed",
        "commercial-integration-evidence",
        "commercial-integration-snapshot-passed",
        "commercial-integration-snapshot-reviewed",
        "commercial-approval-evidence",
        "commercial-approval-snapshot-passed",
        "commercial-approval-snapshot-reviewed",
        "enterprise-auth-evidence",
        "enterprise-auth-smoke-snapshot-accepted",
        "enterprise-auth-smoke-snapshot-reviewed",
        "backup-restore-evidence",
        "ha-dr-evidence",
        "monitoring-evidence",
        "monitoring-threshold-snapshot-passed",
        "monitoring-threshold-reviewed",
        "cluster-network-access-review-evidence",
        "cluster-network-access-review-snapshot-parsed",
        "cluster-network-access-review-snapshot-passed",
        "cluster-network-access-review-reviewed",
        "helm-values-hardening-evidence",
        "helm-values-hardening-snapshot-parsed",
        "helm-values-hardening-snapshot-passed",
        "helm-values-hardening-reviewed",
        "security-evidence",
        "iam-rbac-evidence"
    )
    foreach ($requiredCheckId in $requiredCheckIds) {
        [object[]] $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheckId -and "PASS".Equals([string] (Get-JsonProperty $_ "status"), [System.StringComparison]::OrdinalIgnoreCase) })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheckId missing PASS"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "checkRows=$($checks.Count) requiredChecks=$($requiredCheckIds.Count)"
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
        $json = Read-Utf8Text $Path | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
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

function Test-DataFlowQueryRetentionBudgetEvidenceJson([string] $Path, [bool] $RequirePassed = $false) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{ passed = $false; detail = "invalid JSON: $($_.Exception.Message)" }
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
            return [pscustomobject]@{ passed = $false; detail = "query/retention budget evidence contains raw SQL, raw EXPLAIN, object keys, raw event messages, or credential-shaped content" }
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.data-flow-query-retention-budget-evidence.v1") {
        return [pscustomobject]@{ passed = $false; detail = "formatVersion=$formatVersion expected=osmu.data-flow-query-retention-budget-evidence.v1" }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($RequirePassed -and $result -ne "passed") {
        return [pscustomobject]@{ passed = $false; detail = "result=$result expected=passed" }
    }

    $planSnapshot = Get-JsonProperty $json "dataFlowStoragePlanSnapshot"
    $planResult = [string] (Get-JsonProperty $planSnapshot "result")
    $planPending = Get-RequiredJsonInt $planSnapshot "pendingCount"
    if ($RequirePassed -and ($planResult -ne "passed" -or -not $planPending.valid -or [int64] $planPending.value -ne 0)) {
        return [pscustomobject]@{ passed = $false; detail = "dataFlowStoragePlanSnapshot.result=$planResult pendingCount=$($planPending.raw)(valid=$($planPending.valid)) expected passed/0" }
    }

    $queryLatencyBudget = Get-JsonProperty $json "queryLatencyBudget"
    $targetP95 = Get-RequiredJsonInt $queryLatencyBudget "targetP95QueryLatencyMs"
    $observedP95 = Get-RequiredJsonInt $queryLatencyBudget "observedP95QueryLatencyMs"
    $observedP99 = Get-RequiredJsonInt $queryLatencyBudget "observedP99QueryLatencyMs"
    $sampleCount = Get-RequiredJsonInt $queryLatencyBudget "querySampleCount"
    $windowDays = Get-RequiredJsonInt $queryLatencyBudget "observedQueryWindowDays"
    $queryWithin = Get-RequiredJsonBool $queryLatencyBudget "withinBudget"
    $queryCountsValid = $targetP95.valid -and $observedP95.valid -and $observedP99.valid -and $sampleCount.valid -and $windowDays.valid
    if (-not $queryCountsValid -or [int64] $targetP95.value -le 0 -or [int64] $observedP99.value -lt [int64] $observedP95.value -or [int64] $sampleCount.value -le 0 -or [int64] $windowDays.value -le 0) {
        return [pscustomobject]@{ passed = $false; detail = "queryLatencyBudget metrics invalid targetP95=$($targetP95.raw) observedP95=$($observedP95.raw) observedP99=$($observedP99.raw) sampleCount=$($sampleCount.raw) windowDays=$($windowDays.raw)" }
    }
    if ($RequirePassed -and (-not $queryWithin.valid -or -not $queryWithin.value -or [int64] $observedP95.value -gt [int64] $targetP95.value)) {
        return [pscustomobject]@{ passed = $false; detail = "queryLatencyBudget withinBudget=$($queryWithin.raw)(valid=$($queryWithin.valid)) observedP95=$($observedP95.raw) targetP95=$($targetP95.raw) expected within budget" }
    }

    $retentionBudget = Get-JsonProperty $json "retentionBudget"
    $budgetSeconds = Get-RequiredJsonInt $retentionBudget "budgetSeconds"
    $detailedSeconds = Get-RequiredJsonInt $retentionBudget "detailedRetentionObservedSeconds"
    $dailySeconds = Get-RequiredJsonInt $retentionBudget "dailyRollupRetentionObservedSeconds"
    $monthlySeconds = Get-RequiredJsonInt $retentionBudget "monthlyRollupRetentionObservedSeconds"
    $detailedDeletedRows = Get-RequiredJsonInt $retentionBudget "detailedRetentionDeletedRows"
    $dailyDeletedRows = Get-RequiredJsonInt $retentionBudget "dailyRollupRetentionDeletedRows"
    $monthlyDeletedRows = Get-RequiredJsonInt $retentionBudget "monthlyRollupRetentionDeletedRows"
    $retentionWithin = Get-RequiredJsonBool $retentionBudget "withinBudget"
    $retentionCountsValid = $budgetSeconds.valid -and $detailedSeconds.valid -and $dailySeconds.valid -and $monthlySeconds.valid -and $detailedDeletedRows.valid -and $dailyDeletedRows.valid -and $monthlyDeletedRows.valid
    if (-not $retentionCountsValid -or [int64] $budgetSeconds.value -le 0 -or [int64] $detailedDeletedRows.value -lt 0 -or [int64] $dailyDeletedRows.value -lt 0 -or [int64] $monthlyDeletedRows.value -lt 0) {
        return [pscustomobject]@{ passed = $false; detail = "retentionBudget metrics invalid budget=$($budgetSeconds.raw) detailedSeconds=$($detailedSeconds.raw) dailySeconds=$($dailySeconds.raw) monthlySeconds=$($monthlySeconds.raw)" }
    }
    if ($RequirePassed -and (-not $retentionWithin.valid -or -not $retentionWithin.value -or [int64] $detailedSeconds.value -gt [int64] $budgetSeconds.value -or [int64] $dailySeconds.value -gt [int64] $budgetSeconds.value -or [int64] $monthlySeconds.value -gt [int64] $budgetSeconds.value)) {
        return [pscustomobject]@{ passed = $false; detail = "retentionBudget withinBudget=$($retentionWithin.raw)(valid=$($retentionWithin.valid)) budget=$($budgetSeconds.raw) detailed=$($detailedSeconds.raw) daily=$($dailySeconds.raw) monthly=$($monthlySeconds.raw) expected within budget" }
    }

    $summary = Get-JsonProperty $json "summary"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $checkCount = Get-RequiredJsonInt $summary "checkCount"
    if (-not $failureCount.valid -or -not $checkCount.valid -or [int64] $checkCount.value -le 0) {
        return [pscustomobject]@{ passed = $false; detail = "summary failureCount=$($failureCount.raw)(valid=$($failureCount.valid)) checkCount=$($checkCount.raw)(valid=$($checkCount.valid)) expected typed checkCount>0" }
    }
    if ($RequirePassed -and [int64] $failureCount.value -ne 0) {
        return [pscustomobject]@{ passed = $false; detail = "summary.failureCount=$($failureCount.raw) expected 0" }
    }

    if ($RequirePassed) {
        $confirmations = Get-JsonProperty $json "confirmations"
        foreach ($confirmationName in @("queryLatencyReviewed", "retentionJobsWithinBudget", "noObjectKeysInEvidence", "noRawSqlOrExplain", "noSecretValues")) {
            $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
            if (-not $confirmation.valid -or -not $confirmation.value) {
                return [pscustomobject]@{ passed = $false; detail = "confirmations.$confirmationName=$($confirmation.raw) expected boolean true" }
            }
        }
    }

    return [pscustomobject]@{ passed = $true; detail = "formatVersion=$formatVersion result=$result p95=$($observedP95.raw)/$($targetP95.raw) retentionBudget=$($budgetSeconds.raw) failureCount=$($failureCount.raw)" }
}
function Test-DataFlowStorageTransitionRunbookEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
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

    $planPendingCount = Get-RequiredJsonInt $planSnapshot "pendingCount"
    $planCheckCount = Get-RequiredJsonInt $planSnapshot "checkCount"
    if (-not $planPendingCount.valid -or [int64] $planPendingCount.value -ne 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "dataFlowStoragePlanSnapshot.pendingCount=$($planPendingCount.raw)(valid=$($planPendingCount.valid)) expected integer 0"
        }
    }
    if (-not $planCheckCount.valid -or [int64] $planCheckCount.value -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "dataFlowStoragePlanSnapshot.checkCount=$($planCheckCount.raw)(valid=$($planCheckCount.valid)) expected integer >0"
        }
    }
    $queryPlanEvidenceResult = [string] (Get-JsonProperty $planSnapshot "queryPlanEvidenceResult")
    if ($candidateStore -in @("MARIADB_PARTITION", "DUAL_WRITE") -and -not "passed".Equals($queryPlanEvidenceResult, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{
            passed = $false
            detail = "dataFlowStoragePlanSnapshot.queryPlanEvidenceResult=$queryPlanEvidenceResult expected=passed for $candidateStore"
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
    $checkCountResult = Get-RequiredJsonInt $summary "checkCount"
    if (-not $checkCountResult.valid -or [int64] $checkCountResult.value -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "checkCount=$($checkCountResult.raw)(valid=$($checkCountResult.valid)) expected integer >0"
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

    foreach ($metadataName in @("environmentName", "targetCluster", "operatorName", "evidenceRef")) {
        $metadataValue = [string] (Get-JsonProperty $json $metadataName)
        if ([string]::IsNullOrWhiteSpace($metadataValue)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$metadataName missing"
            }
        }
    }

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "generatedAt=$generatedAt expected ISO timestamp"
        }
    }

    $reviewWindow = Get-JsonProperty $json "reviewWindow"
    $startedAt = [string] (Get-JsonProperty $reviewWindow "startedAt")
    $completedAt = [string] (Get-JsonProperty $reviewWindow "completedAt")
    $parsedStartedAt = [DateTimeOffset]::MinValue
    $parsedCompletedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($startedAt) -or -not [DateTimeOffset]::TryParse($startedAt, [ref] $parsedStartedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "reviewWindow.startedAt=$startedAt expected ISO timestamp"
        }
    }
    if ([string]::IsNullOrWhiteSpace($completedAt) -or -not [DateTimeOffset]::TryParse($completedAt, [ref] $parsedCompletedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "reviewWindow.completedAt=$completedAt expected ISO timestamp"
        }
    }
    if ($parsedCompletedAt -lt $parsedStartedAt) {
        return [pscustomobject]@{
            passed = $false
            detail = "reviewWindow completedAt must be same as or later than startedAt"
        }
    }

    $evidenceRefs = Get-JsonProperty $json "evidenceRefs"
    foreach ($refName in @("changeApproval", "dataFlowStoragePlan", "backfill", "dualWriteOrPartitionToggle", "rollback", "reconciliation", "dashboardCutover", "retentionDryRun")) {
        $refValue = [string] (Get-JsonProperty $evidenceRefs $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) {
            return [pscustomobject]@{
                passed = $false
                detail = "evidenceRefs.$refName missing"
            }
        }
    }

    $checksRaw = Get-JsonProperty $json "checks"
    if ($null -eq $checksRaw) {
        return [pscustomobject]@{
            passed = $false
            detail = "checks expected"
        }
    }
    [object[]] $checks = @($checksRaw)
    if ($checks.Count -ne [int64] $checkCountResult.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "checks.Count=$($checks.Count) summary.checkCount=$($checkCountResult.value) expected equal"
        }
    }
    foreach ($check in $checks) {
        $id = [string] (Get-JsonProperty $check "id")
        $status = [string] (Get-JsonProperty $check "status")
        $passed = Get-RequiredJsonBool $check "passed"
        if ([string]::IsNullOrWhiteSpace($id)) {
            return [pscustomobject]@{ passed = $false; detail = "checks row missing id" }
        }
        if (-not "PASS".Equals($status, [System.StringComparison]::OrdinalIgnoreCase) -or -not $passed.valid -or -not $passed.value) {
            return [pscustomobject]@{ passed = $false; detail = "checks.$id status=$status passed=$($passed.raw) expected PASS and boolean true" }
        }
    }

    $requiredCheckIds = @(
        "environment-name",
        "target-cluster",
        "operator",
        "review-started-at",
        "review-completed-at",
        "review-window-order",
        "change-approval-ref",
        "data-flow-storage-plan-evidence-ref",
        "data-flow-storage-plan-passed",
        "backfill-evidence-ref",
        "dual-write-or-partition-toggle-evidence-ref",
        "rollback-evidence-ref",
        "reconciliation-evidence-ref",
        "dashboard-cutover-evidence-ref",
        "retention-dry-run-evidence-ref",
        "backfill-rehearsed-confirmed",
        "dual-write-or-partition-toggle-reviewed-confirmed",
        "rollback-rehearsed-confirmed",
        "reconciliation-passed-confirmed",
        "dashboard-cutover-reviewed-confirmed",
        "retention-dry-run-reviewed-confirmed",
        "no-object-keys-in-aggregates-confirmed",
        "no-secret-values-confirmed"
    )
    foreach ($requiredCheckId in $requiredCheckIds) {
        [object[]] $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheckId -and "PASS".Equals([string] (Get-JsonProperty $_ "status"), [System.StringComparison]::OrdinalIgnoreCase) })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheckId missing PASS"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result environmentName=$($json.environmentName) targetCluster=$($json.targetCluster) storagePlanResult=$planResult candidateStore=$candidateStore failureCount=$($failureCountResult.value) planChecks=$($planCheckCount.value) checkRows=$($checks.Count) confirmations=$($requiredConfirmations.Count)/$($requiredConfirmations.Count)"
    }
}

function Test-KubernetesOperationsReportSyncEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
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

function Test-MinioBucketCorsVerificationJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "MinIO bucket CORS"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }
    if ($raw.Contains("<CORSConfiguration")) {
        return [pscustomobject]@{
            passed = $false
            detail = "MinIO bucket CORS evidence must not store raw CORS XML"
        }
    }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.minio-bucket-cors-verification.v1") {
        return [pscustomobject]@{
            passed = $false
            detail = "formatVersion=$formatVersion expected osmu.minio-bucket-cors-verification.v1"
        }
    }

    $result = [string] (Get-JsonProperty $json "result")
    if ($result -notin @("passed", "failed")) {
        return [pscustomobject]@{
            passed = $false
            detail = "result=$result expected passed|failed"
        }
    }

    $source = Get-JsonProperty $json "source"
    $summary = Get-JsonProperty $json "summary"
    $cors = Get-JsonProperty $json "cors"
    if ($null -eq $source -or $null -eq $summary -or $null -eq $cors) {
        return [pscustomobject]@{
            passed = $false
            detail = "source, summary, and cors sections are required"
        }
    }

    $rawCorsXmlStored = Get-RequiredJsonBool $source "rawCorsXmlStored"
    if (-not $rawCorsXmlStored.valid -or $rawCorsXmlStored.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "source.rawCorsXmlStored=$($rawCorsXmlStored.raw) expected boolean false"
        }
    }

    foreach ($field in @("bucketName", "minioAlias")) {
        $value = [string] (Get-JsonProperty $source $field)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                passed = $false
                detail = "source.$field missing"
            }
        }
    }

    $ruleCount = Get-RequiredJsonInt $summary "ruleCount"
    $exposedHeaderCount = Get-RequiredJsonInt $summary "exposedHeaderCount"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $plannedCount = Get-RequiredJsonInt $summary "plannedCount"
    foreach ($countResult in @(
        @{ name = "summary.ruleCount"; value = $ruleCount },
        @{ name = "summary.exposedHeaderCount"; value = $exposedHeaderCount },
        @{ name = "summary.failureCount"; value = $failureCount },
        @{ name = "summary.plannedCount"; value = $plannedCount }
    )) {
        if (-not $countResult.value.valid -or [int64] $countResult.value.value -lt 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "$($countResult.name)=$($countResult.value.raw)(valid=$($countResult.value.valid)) expected non-negative integer"
            }
        }
    }

    $corsRuleCount = Get-RequiredJsonInt $cors "ruleCount"
    if (-not $corsRuleCount.valid -or [int64] $corsRuleCount.value -ne [int64] $ruleCount.value) {
        return [pscustomobject]@{
            passed = $false
            detail = "cors.ruleCount=$($corsRuleCount.raw)(valid=$($corsRuleCount.valid)) summary.ruleCount=$($ruleCount.raw) expected matching integers"
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

    $actualFailureCount = 0
    $actualPlannedCount = 0
    foreach ($check in $checks) {
        $status = [string] (Get-JsonProperty $check "status")
        $checkPassed = Get-RequiredJsonBool $check "passed"
        if ($status -notin @("PASS", "FAIL", "PLANNED") -or -not $checkPassed.valid) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$([string] (Get-JsonProperty $check "id")) status=$status passed=$($checkPassed.raw) expected status PASS|FAIL|PLANNED and typed boolean"
            }
        }
        if ($status -eq "PASS" -and -not $checkPassed.value) {
            return [pscustomobject]@{ passed = $false; detail = "checks.$([string] (Get-JsonProperty $check "id")) PASS row must have passed=true" }
        }
        if ($status -eq "FAIL" -and $checkPassed.value) {
            return [pscustomobject]@{ passed = $false; detail = "checks.$([string] (Get-JsonProperty $check "id")) FAIL row must have passed=false" }
        }
        if ($status -eq "PLANNED" -and $checkPassed.value) {
            return [pscustomobject]@{ passed = $false; detail = "checks.$([string] (Get-JsonProperty $check "id")) PLANNED row must have passed=false" }
        }
        if ($status -eq "FAIL") { $actualFailureCount++ }
        if ($status -eq "PLANNED") { $actualPlannedCount++ }
    }

    if ([int64] $failureCount.value -ne $actualFailureCount -or [int64] $plannedCount.value -ne $actualPlannedCount) {
        return [pscustomobject]@{
            passed = $false
            detail = "summary counts do not match checks: failureCount=$($failureCount.value)/$actualFailureCount plannedCount=$($plannedCount.value)/$actualPlannedCount"
        }
    }

    if ($result -eq "passed") {
        if ([int64] $failureCount.value -ne 0 -or [int64] $plannedCount.value -ne 0) {
            return [pscustomobject]@{
                passed = $false
                detail = "passed CORS evidence requires zero failed and planned checks"
            }
        }
        $exposeHeaders = @((Get-JsonProperty $cors "exposeHeaders") | ForEach-Object { [string] $_ })
        foreach ($requiredHeader in @("ETag", "x-amz-request-id", "x-amz-id-2", "x-amz-version-id")) {
            $matched = @($exposeHeaders | Where-Object { $_.Equals($requiredHeader, [System.StringComparison]::OrdinalIgnoreCase) })
            if ($matched.Count -eq 0) {
                return [pscustomobject]@{
                    passed = $false
                    detail = "passed CORS evidence missing expose header $requiredHeader"
                }
            }
        }
    }

    $scopePolicy = [string] (Get-JsonProperty $json "scopePolicy")
    if (-not $scopePolicy.Contains("not AWS S3 parity work")) {
        return [pscustomobject]@{
            passed = $false
            detail = "scopePolicy must state this is not AWS S3 parity work"
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result bucket=$($source.bucketName) alias=$($source.minioAlias) rules=$($ruleCount.value) exposedHeaders=$($exposedHeaderCount.value) failures=$($failureCount.value) planned=$($plannedCount.value) rawCorsXmlStored=False"
    }
}

function Test-MinioBucketCorsVerificationMarkdown([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "could not read markdown: $($_.Exception.Message)"
        }
    }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "MinIO bucket CORS markdown"
    if (-not $rawValidation.passed) {
        return $rawValidation
    }
    if ($raw.Contains("<CORSConfiguration")) {
        return [pscustomobject]@{
            passed = $false
            detail = "MinIO bucket CORS markdown must not store raw CORS XML"
        }
    }
    if (-not $raw.Contains("not AWS S3 parity work")) {
        return [pscustomobject]@{
            passed = $false
            detail = "MinIO bucket CORS markdown must preserve the S3 parity boundary"
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "markdown has no raw CORS XML and preserves S3 parity boundary"
    }
}

function Test-MonitoringThresholdEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
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
    $alertTargetCoverageCompleteResult = Get-RequiredJsonBool $summary "alertTargetCoverageComplete"
    $routeCoverageCompleteResult = Get-RequiredJsonBool $summary "routeCoverageComplete"
    $grafanaPanelCoverageCompleteResult = Get-RequiredJsonBool $summary "grafanaPanelCoverageComplete"
    $tuningEvidenceCoverageCompleteResult = Get-RequiredJsonBool $summary "tuningEvidenceCoverageComplete"
    $thresholdMappingCompleteResult = Get-RequiredJsonBool $summary "thresholdMappingComplete"
    $failureCountResult = Get-RequiredJsonInt $reportSummary "failureCount"
    $checkCountResult = Get-RequiredJsonInt $reportSummary "checkCount"
    foreach ($countResult in @(
        @{ name = "requiredAlertCount"; value = $requiredAlertCountResult },
        @{ name = "mappedAlertCount"; value = $mappedAlertCountResult },
        @{ name = "routeCount"; value = $routeCountResult },
        @{ name = "grafanaPanelCount"; value = $grafanaPanelCountResult },
        @{ name = "tuningEvidenceCount"; value = $tuningEvidenceCountResult },
        @{ name = "failureCount"; value = $failureCountResult },
        @{ name = "checkCount"; value = $checkCountResult }
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

    foreach ($boolResult in @(
        @{ name = "alertTargetCoverageComplete"; value = $alertTargetCoverageCompleteResult },
        @{ name = "routeCoverageComplete"; value = $routeCoverageCompleteResult },
        @{ name = "grafanaPanelCoverageComplete"; value = $grafanaPanelCoverageCompleteResult },
        @{ name = "tuningEvidenceCoverageComplete"; value = $tuningEvidenceCoverageCompleteResult },
        @{ name = "thresholdMappingComplete"; value = $thresholdMappingCompleteResult }
    )) {
        $name = [string] $boolResult["name"]
        $value = $boolResult["value"]
        if (-not $value.valid -or -not $value.value) {
            return [pscustomobject]@{
                passed = $false
                detail = "$name=$($value.raw)(valid=$($value.valid)) expected boolean true"
            }
        }
    }

    $requiredAlertCount = [int64] $requiredAlertCountResult.value
    $mappedAlertCount = [int64] $mappedAlertCountResult.value
    $routeCount = [int64] $routeCountResult.value
    $grafanaPanelCount = [int64] $grafanaPanelCountResult.value
    $tuningEvidenceCount = [int64] $tuningEvidenceCountResult.value
    $failureCount = [int64] $failureCountResult.value
    $checkCount = [int64] $checkCountResult.value
    $missingAlerts = @(Get-JsonProperty $summary "missingAlerts")
    if ($requiredAlertCount -le 0 -or $mappedAlertCount -lt $requiredAlertCount -or $routeCount -le 0 -or $grafanaPanelCount -lt $requiredAlertCount -or $tuningEvidenceCount -lt $requiredAlertCount -or $missingAlerts.Count -gt 0 -or $failureCount -ne 0 -or $checkCount -le 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "threshold target mapping incomplete required=$requiredAlertCount mapped=$mappedAlertCount routes=$routeCount grafanaPanels=$grafanaPanelCount tuningEvidence=$tuningEvidenceCount failures=$failureCount checks=$checkCount missing=$($missingAlerts -join ',')"
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

    foreach ($metadataName in @("environmentName", "targetCluster", "operatorName", "evidenceRef")) {
        $metadataValue = [string] (Get-JsonProperty $json $metadataName)
        if ([string]::IsNullOrWhiteSpace($metadataValue)) {
            return [pscustomobject]@{
                passed = $false
                detail = "$metadataName missing"
            }
        }
    }

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "generatedAt=$generatedAt expected ISO timestamp"
        }
    }

    $reviewWindow = Get-JsonProperty $json "reviewWindow"
    $startedAt = [string] (Get-JsonProperty $reviewWindow "startedAt")
    $completedAt = [string] (Get-JsonProperty $reviewWindow "completedAt")
    $parsedStartedAt = [DateTimeOffset]::MinValue
    $parsedCompletedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($startedAt) -or -not [DateTimeOffset]::TryParse($startedAt, [ref] $parsedStartedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "reviewWindow.startedAt=$startedAt expected ISO timestamp"
        }
    }
    if ([string]::IsNullOrWhiteSpace($completedAt) -or -not [DateTimeOffset]::TryParse($completedAt, [ref] $parsedCompletedAt)) {
        return [pscustomobject]@{
            passed = $false
            detail = "reviewWindow.completedAt=$completedAt expected ISO timestamp"
        }
    }
    if ($parsedCompletedAt -lt $parsedStartedAt) {
        return [pscustomobject]@{
            passed = $false
            detail = "reviewWindow completedAt must be same as or later than startedAt"
        }
    }

    $evidenceRefs = Get-JsonProperty $json "evidenceRefs"
    foreach ($refName in @("changeApproval", "prometheusRules", "grafanaDashboard", "alertmanagerRoute", "targetBaseline", "incidentRouting")) {
        $refValue = [string] (Get-JsonProperty $evidenceRefs $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) {
            return [pscustomobject]@{
                passed = $false
                detail = "evidenceRefs.$refName missing"
            }
        }
    }

    $checksRaw = Get-JsonProperty $json "checks"
    if ($null -eq $checksRaw) {
        return [pscustomobject]@{
            passed = $false
            detail = "checks expected"
        }
    }
    [object[]] $checks = @($checksRaw)
    if ($checks.Count -ne $checkCount) {
        return [pscustomobject]@{
            passed = $false
            detail = "checks.Count=$($checks.Count) summary.checkCount=$checkCount expected equal"
        }
    }
    foreach ($check in $checks) {
        $id = [string] (Get-JsonProperty $check "id")
        $status = [string] (Get-JsonProperty $check "status")
        $passed = Get-RequiredJsonBool $check "passed"
        if ([string]::IsNullOrWhiteSpace($id)) {
            return [pscustomobject]@{ passed = $false; detail = "checks row missing id" }
        }
        if (-not "PASS".Equals($status, [System.StringComparison]::OrdinalIgnoreCase) -or -not $passed.valid -or -not $passed.value) {
            return [pscustomobject]@{ passed = $false; detail = "checks.$id status=$status passed=$($passed.raw) expected PASS and boolean true" }
        }
    }

    $requiredCheckIds = @(
        "environment-name",
        "target-cluster",
        "operator",
        "review-started-at",
        "review-completed-at",
        "review-window-order",
        "change-approval-ref",
        "threshold-targets-file-exists",
        "threshold-targets-format",
        "threshold-alert-targets-complete",
        "alertmanager-routes-mapped",
        "grafana-panels-mapped",
        "target-tuning-evidence-fields",
        "prometheus-rules-evidence-ref",
        "grafana-dashboard-evidence-ref",
        "alertmanager-route-evidence-ref",
        "target-baseline-evidence-ref",
        "incident-routing-evidence-ref",
        "prometheus-rules-loaded-confirmed",
        "grafana-dashboard-imported-confirmed",
        "alertmanager-routes-reviewed-confirmed",
        "target-baselines-reviewed-confirmed",
        "incident-routing-reviewed-confirmed",
        "no-secret-values-confirmed"
    )
    foreach ($requiredCheckId in $requiredCheckIds) {
        [object[]] $match = @($checks | Where-Object { [string] (Get-JsonProperty $_ "id") -eq $requiredCheckId -and "PASS".Equals([string] (Get-JsonProperty $_ "status"), [System.StringComparison]::OrdinalIgnoreCase) })
        if ($match.Count -ne 1) {
            return [pscustomobject]@{
                passed = $false
                detail = "checks.$requiredCheckId missing PASS"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result environmentName=$($json.environmentName) targetCluster=$($json.targetCluster) requiredAlerts=$requiredAlertCount mappedAlerts=$mappedAlertCount routes=$routeCount grafanaPanels=$grafanaPanelCount tuningEvidence=$tuningEvidenceCount mappingComplete=$($thresholdMappingCompleteResult.value) failures=$failureCount checkRows=$($checks.Count)"
    }
}

function Test-OperationsHandoffPackageEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            passed = $false
            detail = "invalid JSON: $($_.Exception.Message)"
        }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) {
        return $selfTestTarget
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
        "dataFlowQueryRetentionBudgetReviewed",
        "dataFlowStorageTransitionRunbookReviewed",
        "secretRotationSnapshotReviewed",
        "commercialIntegrationSnapshotReviewed",
        "commercialApprovalSnapshotReviewed",
        "chargebackCloseoutSnapshotReviewed",
        "enterpriseAuthSmokeSnapshotReviewed",
        "monitoringThresholdReviewed",
        "clusterNetworkAccessReviewReviewed",
        "helmValuesHardeningReviewed",
        "requireProductionEvidence",
        "requireOperationsSnapshotEvidence"
    )
    $targetSnapshots = Get-JsonProperty $json "targetEvidenceSnapshots"
    $jitSnapshot = Get-JsonProperty $targetSnapshots "enterpriseAuthJitRollback"
    if ($null -ne $jitSnapshot) {
        $jitProvided = Get-RequiredJsonBool $jitSnapshot "provided"
        $jitResult = [string] (Get-JsonProperty $jitSnapshot "result")
        if (($jitProvided.valid -and $jitProvided.value) -or -not [string]::IsNullOrWhiteSpace($jitResult)) {
            $requiredConfirmations += "enterpriseAuthJitRollbackSnapshotReviewed"
        }
    }

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

    $evidenceRefsValidation = Test-OperationsHandoffPackageEvidenceRefs $json
    if (-not $evidenceRefsValidation.passed) {
        return $evidenceRefsValidation
    }

    $targetSnapshotValidation = Test-OperationsHandoffPackageTargetSnapshots $json
    if (-not $targetSnapshotValidation.passed) {
        return $targetSnapshotValidation
    }

    $summaryValidation = Test-OperationsHandoffPackageSummary $json
    if (-not $summaryValidation.passed) {
        return $summaryValidation
    }

    $checksValidation = Test-OperationsHandoffPackageChecks $json
    if (-not $checksValidation.passed) {
        return $checksValidation
    }

    $patterns = @(
        '(?i)"(rawClaimJson|raw_claim_json|idToken|id_token|accessToken|access_token|refreshToken|refresh_token|authorizationCode|authorization_code|oidcCode|oidc_code|oidcState|oidc_state|ldapPassword|ldap_password|adminPassword|admin_password|clientSecret|client_secret|rawCustomerPaymentData|raw_customer_payment_data|rawProviderResponse|raw_provider_response|rawInvoice|raw_invoice|paymentReference|payment_reference|paymentTarget|payment_target|providerPayload|provider_payload|endpointUrl|endpoint_url)"\s*:',
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
        detail = "formatVersion=$formatVersion result=$result requiredConfirmations=$($requiredConfirmations.Count) $($snapshotValidation.detail); $($evidenceRefsValidation.detail); $($targetSnapshotValidation.detail); $($summaryValidation.detail); $($checksValidation.detail)"
    }
}

function Test-ClusterNetworkAccessReviewEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{ passed = $false; detail = "invalid JSON: $($_.Exception.Message)" }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) { return $selfTestTarget }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "cluster network access review"
    if (-not $rawValidation.passed) { return $rawValidation }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.cluster-network-access-review-evidence.v1") {
        return [pscustomobject]@{ passed = $false; detail = "formatVersion=$formatVersion expected=osmu.cluster-network-access-review-evidence.v1" }
    }
    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") { return [pscustomobject]@{ passed = $false; detail = "result=$result expected=passed" } }

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "generatedAt=$generatedAt expected ISO timestamp" }
    }

    foreach ($field in @("environmentName", "targetCluster", "operator", "decisionRule", "scopePolicy", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) { return [pscustomobject]@{ passed = $false; detail = "$field missing" } }
    }

    $reviewWindow = Get-JsonProperty $json "reviewWindow"
    $startedAt = [string] (Get-JsonProperty $reviewWindow "startedAt")
    $completedAt = [string] (Get-JsonProperty $reviewWindow "completedAt")
    $parsedStartedAt = [DateTimeOffset]::MinValue
    $parsedCompletedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($startedAt) -or -not [DateTimeOffset]::TryParse($startedAt, [ref] $parsedStartedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow.startedAt=$startedAt expected ISO timestamp" }
    }
    if ([string]::IsNullOrWhiteSpace($completedAt) -or -not [DateTimeOffset]::TryParse($completedAt, [ref] $parsedCompletedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow.completedAt=$completedAt expected ISO timestamp" }
    }
    if ($parsedCompletedAt -lt $parsedStartedAt) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow completedAt must be same as or later than startedAt" }
    }
    $ordered = Get-RequiredJsonBool $reviewWindow "ordered"
    if (-not $ordered.valid -or -not $ordered.value) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow.ordered=$($ordered.raw) expected boolean true" }
    }

    $evidence = Get-JsonProperty $json "evidence"
    foreach ($refName in @("changeApprovalRef", "dnsEgressReviewRef", "mariaDbAccessReviewRef", "minioAccessReviewRef", "backupAccessReviewRef", "publicIngressReviewRef", "defaultDenyReviewRef", "observabilityScrapeReviewRef", "k8sVerifierEvidenceRef", "helmVerifierEvidenceRef", "evidenceRef")) {
        $refValue = [string] (Get-JsonProperty $evidence $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) { return [pscustomobject]@{ passed = $false; detail = "evidence.$refName missing" } }
    }

    $summary = Get-JsonProperty $json "summary"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $totalCount = Get-RequiredJsonInt $summary "totalCount"
    if (-not $failureCount.valid -or [int64] $failureCount.value -ne 0 -or -not $totalCount.valid -or [int64] $totalCount.value -le 0) {
        return [pscustomobject]@{ passed = $false; detail = "summary failureCount=$($failureCount.raw) totalCount=$($totalCount.raw) expected integer 0 and positive integer" }
    }

    $snapshot = Get-JsonProperty $json "staticControlSnapshot"
    foreach ($shaField in @("networkPolicyManifestSha256", "helmValuesSha256", "helmNetworkPolicyTemplateSha256")) {
        $sha = [string] (Get-JsonProperty $snapshot $shaField)
        if (-not (Test-Sha256 $sha)) { return [pscustomobject]@{ passed = $false; detail = "staticControlSnapshot.$shaField=$sha expected nonzero sha256" } }
    }
    foreach ($flagName in @("requiredPolicyNamesPresent", "backendEgressScoped", "backupEgressScoped", "dnsEgressScoped", "mariaDbIngressScoped", "minioIngressScoped", "noBroadCidr", "helmNetworkPolicyEnabled")) {
        $flag = Get-RequiredJsonBool $snapshot $flagName
        if (-not $flag.valid -or -not $flag.value) { return [pscustomobject]@{ passed = $false; detail = "staticControlSnapshot.$flagName=$($flag.raw) expected boolean true" } }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in @("backendOnlyMariaDb", "backendOnlyMinio", "backupOnlyMariaDbMinio", "dnsEgressScoped", "mariaDbIngressBackendBackupOnly", "minioIngressBackendBackupOnly", "publicIngressLimited", "namespaceDefaultDenyReviewed", "observabilityScrapeReviewed", "helmNetworkPolicyEnabled", "noCredentialValues")) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) { return [pscustomobject]@{ passed = $false; detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true" } }
    }

    $checks = @((Get-JsonProperty $json "checks"))
    if ($checks.Count -le 0) { return [pscustomobject]@{ passed = $false; detail = "checks missing" } }
    foreach ($check in $checks) {
        $passed = Get-RequiredJsonBool $check "passed"
        if (-not $passed.valid -or -not $passed.value) { return [pscustomobject]@{ passed = $false; detail = "check $([string](Get-JsonProperty $check "id")) passed=$($passed.raw) expected boolean true" } }
    }

    return [pscustomobject]@{ passed = $true; detail = "formatVersion=$formatVersion result=$result failures=$($failureCount.value) checks=$($totalCount.value)" }
}

function Test-HelmValuesHardeningEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{ passed = $false; detail = "invalid JSON: $($_.Exception.Message)" }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) { return $selfTestTarget }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "Helm values hardening"
    if (-not $rawValidation.passed) { return $rawValidation }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.helm-values-hardening-evidence.v1") {
        return [pscustomobject]@{ passed = $false; detail = "formatVersion=$formatVersion expected=osmu.helm-values-hardening-evidence.v1" }
    }
    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") { return [pscustomobject]@{ passed = $false; detail = "result=$result expected=passed" } }

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "generatedAt=$generatedAt expected ISO timestamp" }
    }

    foreach ($field in @("environmentName", "targetCluster", "operator", "decisionRule", "scopePolicy", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) { return [pscustomobject]@{ passed = $false; detail = "$field missing" } }
    }

    $reviewWindow = Get-JsonProperty $json "reviewWindow"
    $startedAt = [string] (Get-JsonProperty $reviewWindow "startedAt")
    $completedAt = [string] (Get-JsonProperty $reviewWindow "completedAt")
    $parsedStartedAt = [DateTimeOffset]::MinValue
    $parsedCompletedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($startedAt) -or -not [DateTimeOffset]::TryParse($startedAt, [ref] $parsedStartedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow.startedAt=$startedAt expected ISO timestamp" }
    }
    if ([string]::IsNullOrWhiteSpace($completedAt) -or -not [DateTimeOffset]::TryParse($completedAt, [ref] $parsedCompletedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow.completedAt=$completedAt expected ISO timestamp" }
    }
    if ($parsedCompletedAt -lt $parsedStartedAt) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow completedAt must be same as or later than startedAt" }
    }
    $ordered = Get-RequiredJsonBool $reviewWindow "ordered"
    if (-not $ordered.valid -or -not $ordered.value) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow.ordered=$($ordered.raw) expected boolean true" }
    }

    $evidence = Get-JsonProperty $json "evidence"
    foreach ($refName in @("changeApprovalRef", "helmVerifierEvidenceRef", "kubernetesVerifierEvidenceRef", "containerHardeningEvidenceRef", "clusterNetworkAccessReviewEvidenceRef", "evidenceRef")) {
        $refValue = [string] (Get-JsonProperty $evidence $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) { return [pscustomobject]@{ passed = $false; detail = "evidence.$refName missing" } }
    }

    $summary = Get-JsonProperty $json "summary"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $totalCount = Get-RequiredJsonInt $summary "totalCount"
    if (-not $failureCount.valid -or [int64] $failureCount.value -ne 0 -or -not $totalCount.valid -or [int64] $totalCount.value -le 0) {
        return [pscustomobject]@{ passed = $false; detail = "summary failureCount=$($failureCount.raw) totalCount=$($totalCount.raw) expected integer 0 and positive integer" }
    }

    $chartSnapshot = Get-JsonProperty $json "chartSnapshot"
    $files = @((Get-JsonProperty $chartSnapshot "files"))
    if ($files.Count -le 0) { return [pscustomobject]@{ passed = $false; detail = "chartSnapshot.files missing" } }
    foreach ($file in $files) {
        $sha = [string] (Get-JsonProperty $file "sha256")
        if (-not (Test-Sha256 $sha)) { return [pscustomobject]@{ passed = $false; detail = "chartSnapshot.files sha256=$sha expected nonzero sha256" } }
    }

    $snapshot = Get-JsonProperty $json "staticHardeningSnapshot"
    foreach ($flagName in @("secretsExternalized", "defaultSecretPlaceholdersPresent", "haReplicas", "resourceBounds", "securityContexts", "serviceAccountTokensDisabled", "networkPolicyEnabled", "tlsIngress", "operationsReportsReadOnly", "storageExpansionRbacDisabled")) {
        $flag = Get-RequiredJsonBool $snapshot $flagName
        if (-not $flag.valid -or -not $flag.value) { return [pscustomobject]@{ passed = $false; detail = "staticHardeningSnapshot.$flagName=$($flag.raw) expected boolean true" } }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in @("secretsExternalized", "defaultSecretPlaceholdersNotUsed", "haReplicasReviewed", "resourcesBounded", "securityContextsReviewed", "networkPolicyEnabled", "tlsIngressReviewed", "operationsReportsReadOnly", "storageExpansionRbacDisabledByDefault", "noCredentialValues")) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) { return [pscustomobject]@{ passed = $false; detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true" } }
    }

    $checks = @((Get-JsonProperty $json "checks"))
    if ($checks.Count -le 0) { return [pscustomobject]@{ passed = $false; detail = "checks missing" } }
    foreach ($check in $checks) {
        $passed = Get-RequiredJsonBool $check "passed"
        if (-not $passed.valid -or -not $passed.value) { return [pscustomobject]@{ passed = $false; detail = "check $([string](Get-JsonProperty $check "id")) passed=$($passed.raw) expected boolean true" } }
    }

    return [pscustomobject]@{ passed = $true; detail = "formatVersion=$formatVersion result=$result failures=$($failureCount.value) checks=$($totalCount.value) chartFiles=$($files.Count)" }
}

function Test-SupportEscalationHandoffEvidenceJson([string] $Path) {
    try {
        $raw = Read-Utf8Text $Path
        $json = $raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{ passed = $false; detail = "invalid JSON: $($_.Exception.Message)" }
    }

    $selfTestTarget = Test-SelfTestTargetEvidenceJson $json
    if (-not $selfTestTarget.passed) { return $selfTestTarget }

    $rawValidation = Test-OperationsEvidenceRawContent $raw "support escalation handoff"
    if (-not $rawValidation.passed) { return $rawValidation }

    $formatVersion = [string] (Get-JsonProperty $json "formatVersion")
    if ($formatVersion -ne "osmu.support-escalation-handoff-evidence.v1") {
        return [pscustomobject]@{ passed = $false; detail = "formatVersion=$formatVersion expected=osmu.support-escalation-handoff-evidence.v1" }
    }
    $result = [string] (Get-JsonProperty $json "result")
    if ($result -ne "passed") { return [pscustomobject]@{ passed = $false; detail = "result=$result expected=passed" } }

    $generatedAt = [string] (Get-JsonProperty $json "generatedAt")
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($generatedAt) -or -not [DateTimeOffset]::TryParse($generatedAt, [ref] $parsedGeneratedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "generatedAt=$generatedAt expected ISO timestamp" }
    }

    foreach ($field in @("environmentName", "targetCluster", "operator", "decisionRule", "scopePolicy", "secretPolicy")) {
        $value = [string] (Get-JsonProperty $json $field)
        if ([string]::IsNullOrWhiteSpace($value)) { return [pscustomobject]@{ passed = $false; detail = "$field missing" } }
    }

    $reviewWindow = Get-JsonProperty $json "reviewWindow"
    $startedAt = [string] (Get-JsonProperty $reviewWindow "startedAt")
    $completedAt = [string] (Get-JsonProperty $reviewWindow "completedAt")
    $parsedStartedAt = [DateTimeOffset]::MinValue
    $parsedCompletedAt = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrWhiteSpace($startedAt) -or -not [DateTimeOffset]::TryParse($startedAt, [ref] $parsedStartedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow.startedAt=$startedAt expected ISO timestamp" }
    }
    if ([string]::IsNullOrWhiteSpace($completedAt) -or -not [DateTimeOffset]::TryParse($completedAt, [ref] $parsedCompletedAt)) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow.completedAt=$completedAt expected ISO timestamp" }
    }
    if ($parsedCompletedAt -lt $parsedStartedAt) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow completedAt must be same as or later than startedAt" }
    }
    $ordered = Get-RequiredJsonBool $reviewWindow "ordered"
    if (-not $ordered.valid -or -not $ordered.value) {
        return [pscustomobject]@{ passed = $false; detail = "reviewWindow.ordered=$($ordered.raw) expected boolean true" }
    }

    $evidence = Get-JsonProperty $json "evidence"
    foreach ($refName in @("changeApprovalRef", "operationsHandoffPackageRef", "runbookReviewRef", "troubleshootingReviewRef", "rollbackReviewRef", "supportEscalationRef", "supportSlaRef", "knownGapsRef", "evidenceRef")) {
        $refValue = [string] (Get-JsonProperty $evidence $refName)
        if ([string]::IsNullOrWhiteSpace($refValue)) { return [pscustomobject]@{ passed = $false; detail = "evidence.$refName missing" } }
    }

    $summary = Get-JsonProperty $json "summary"
    $passCount = Get-RequiredJsonInt $summary "passCount"
    $failureCount = Get-RequiredJsonInt $summary "failureCount"
    $totalCount = Get-RequiredJsonInt $summary "totalCount"
    if (-not $passCount.valid -or -not $failureCount.valid -or -not $totalCount.valid -or [int64] $failureCount.value -ne 0 -or [int64] $totalCount.value -le 0 -or [int64] $passCount.value -ne [int64] $totalCount.value) {
        return [pscustomobject]@{ passed = $false; detail = "summary passCount=$($passCount.raw) failureCount=$($failureCount.raw) totalCount=$($totalCount.raw) expected pass=total>0 and failure=0" }
    }

    $documentSnapshot = Get-JsonProperty $json "documentSnapshot"
    foreach ($flagName in @("runbookCoverage", "troubleshootingCoverage", "rollbackCoverage", "supportEscalationCoverage", "supportSlaCoverage", "knownGapsCoverage", "handoffPackageCoverage")) {
        $flag = Get-RequiredJsonBool $documentSnapshot $flagName
        if (-not $flag.valid -or -not $flag.value) { return [pscustomobject]@{ passed = $false; detail = "documentSnapshot.$flagName=$($flag.raw) expected boolean true" } }
    }
    $files = @((Get-JsonProperty $documentSnapshot "files"))
    if ($files.Count -le 0) { return [pscustomobject]@{ passed = $false; detail = "documentSnapshot.files missing" } }
    foreach ($file in $files) {
        $exists = Get-RequiredJsonBool $file "exists"
        if (-not $exists.valid -or -not $exists.value) { return [pscustomobject]@{ passed = $false; detail = "documentSnapshot.files exists=$($exists.raw) expected boolean true" } }
        $sha = [string] (Get-JsonProperty $file "sha256")
        if (-not (Test-Sha256 $sha)) { return [pscustomobject]@{ passed = $false; detail = "documentSnapshot.files sha256=$sha expected nonzero sha256" } }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in @("runbookReviewed", "troubleshootingReviewed", "rollbackPathReviewed", "supportEscalationReviewed", "supportSlaReviewed", "knownGapsAccepted", "operationsHandoffReferenceReady", "noCredentialValues")) {
        $confirmation = Get-RequiredJsonBool $confirmations $confirmationName
        if (-not $confirmation.valid -or -not $confirmation.value) { return [pscustomobject]@{ passed = $false; detail = "confirmation $confirmationName=$($confirmation.raw) expected boolean true" } }
    }

    $checks = @((Get-JsonProperty $json "checks"))
    if ($checks.Count -le 0) { return [pscustomobject]@{ passed = $false; detail = "checks missing" } }
    foreach ($check in $checks) {
        $passed = Get-RequiredJsonBool $check "passed"
        if (-not $passed.valid -or -not $passed.value) { return [pscustomobject]@{ passed = $false; detail = "check $([string](Get-JsonProperty $check "id")) passed=$($passed.raw) expected boolean true" } }
    }

    return [pscustomobject]@{ passed = $true; detail = "formatVersion=$formatVersion result=$result failures=$($failureCount.value) checks=$($totalCount.value) documentFiles=$($files.Count)" }
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
    elseif ($ValidationKind -eq "kubernetes-ha-dr-readiness") {
        $validation = Test-KubernetesHaDrReadinessEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "kubernetes-dr-finalizer") {
        $validation = Test-KubernetesDrFinalizeJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "iam-rbac-finalizer") {
        $validation = Test-IamRbacFinalizeJson $sourcePath
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
    elseif ($ValidationKind -eq "data-flow-query-retention-budget") {
        $validation = Test-DataFlowQueryRetentionBudgetEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "data-flow-query-retention-budget-passed") {
        $validation = Test-DataFlowQueryRetentionBudgetEvidenceJson $sourcePath $true
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
    elseif ($ValidationKind -eq "cluster-network-access-review") {
        $validation = Test-ClusterNetworkAccessReviewEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "helm-values-hardening") {
        $validation = Test-HelmValuesHardeningEvidenceJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "support-escalation-handoff") {
        $validation = Test-SupportEscalationHandoffEvidenceJson $sourcePath
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
    elseif ($ValidationKind -eq "chargeback-closeout") {
        $validation = Test-ChargebackCloseoutEvidenceJson $sourcePath
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
    elseif ($ValidationKind -eq "enterprise-auth-jit-rollback") {
        $validation = Test-EnterpriseAuthJitRollbackEvidenceJson $sourcePath
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
    elseif ($ValidationKind -eq "minio-bucket-cors") {
        $validation = Test-MinioBucketCorsVerificationJson $sourcePath
        if (-not $validation.passed) {
            Add-Entry $Group $FileName "failed" $validation.detail $sourcePath ""
            return
        }
        [void] $validationDetails.Add($validation.detail)
    }
    elseif ($ValidationKind -eq "minio-bucket-cors-markdown") {
        $validation = Test-MinioBucketCorsVerificationMarkdown $sourcePath
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

Import-EvidenceFile "ha-dr-readiness" $HaDrReadinessArtifactPath "latest-kubernetes-ha-dr-readiness.json" $true "" "" "kubernetes-ha-dr-readiness"

Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-finalize.json" $true "" "" "kubernetes-dr-finalizer"
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-finalize.md" $false
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-drill.json" $false
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-restore-smoke.json" $false
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-evidence-request.json" $false

Import-EvidenceFile "iam-rbac" $IamRbacArtifactPath "latest-iam-rbac-finalize.json" $true "" "" "iam-rbac-finalizer"
Import-EvidenceFile "iam-rbac" $IamRbacArtifactPath "latest-iam-rbac-finalize.md" $false
Import-EvidenceFile "iam-rbac" $IamRbacArtifactPath "latest-storage-expansion-rbac-auth.json" $false "" "" "storage-expansion-rbac-auth"

Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-security-evidence-finalize.json" $true "" "" "security-finalizer"
Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-security-evidence-finalize.md" $false
Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-image-signing-evidence.json" $true "" "" "image-signing"
Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-container-security-evidence.json" $true "" "" "container-security"

Import-EvidenceFile "storage-backend-telemetry" $StorageBackendTelemetryArtifactPath "latest-storage-backend-telemetry.json" $true "" "" "storage-backend-telemetry"
Import-EvidenceFile "storage-backend-telemetry" $StorageBackendTelemetryArtifactPath "latest-storage-backend-telemetry.md" $false

Import-EvidenceFile "minio-bucket-cors" $MinioBucketCorsArtifactPath "latest-minio-bucket-cors-verification.json" $true "" "" "minio-bucket-cors"
Import-EvidenceFile "minio-bucket-cors" $MinioBucketCorsArtifactPath "latest-minio-bucket-cors-verification.md" $false "" "" "minio-bucket-cors-markdown"

Import-EvidenceFile "monitoring-threshold" $MonitoringThresholdArtifactPath "latest-monitoring-threshold-evidence.json" $true "" "" "monitoring-threshold"
Import-EvidenceFile "monitoring-threshold" $MonitoringThresholdArtifactPath "latest-monitoring-threshold-evidence.md" $false

Import-EvidenceFile "secret-rotation" $SecretRotationArtifactPath "latest-secret-rotation-evidence.json" $true "" "" "secret-rotation"
Import-EvidenceFile "secret-rotation" $SecretRotationArtifactPath "latest-secret-rotation-evidence.md" $false

Import-EvidenceFile "cluster-network-access-review" $ClusterNetworkAccessReviewArtifactPath "latest-cluster-network-access-review-evidence.json" $true "" "" "cluster-network-access-review"
Import-EvidenceFile "cluster-network-access-review" $ClusterNetworkAccessReviewArtifactPath "latest-cluster-network-access-review-evidence.md" $false

Import-EvidenceFile "helm-values-hardening" $HelmValuesHardeningArtifactPath "latest-helm-values-hardening-evidence.json" $true "" "" "helm-values-hardening"
Import-EvidenceFile "helm-values-hardening" $HelmValuesHardeningArtifactPath "latest-helm-values-hardening-evidence.md" $false

Import-EvidenceFile "support-escalation-handoff" $SupportEscalationHandoffArtifactPath "latest-support-escalation-handoff-evidence.json" $true "" "" "support-escalation-handoff"
Import-EvidenceFile "support-escalation-handoff" $SupportEscalationHandoffArtifactPath "latest-support-escalation-handoff-evidence.md" $false

Import-EvidenceFile "commercial-integration" $CommercialIntegrationArtifactPath "latest-commercial-integration-evidence.json" $true "" "" "commercial-integration"
Import-EvidenceFile "commercial-integration" $CommercialIntegrationArtifactPath "latest-commercial-integration-evidence.md" $false

Import-EvidenceFile "commercial-approval" $CommercialApprovalArtifactPath "latest-commercial-approval-evidence.json" $true "" "" "commercial-approval"
Import-EvidenceFile "commercial-approval" $CommercialApprovalArtifactPath "latest-commercial-approval-evidence.md" $false

Import-EvidenceFile "chargeback-closeout" $ChargebackCloseoutArtifactPath "latest-chargeback-closeout-evidence.json" $true "" "" "chargeback-closeout"
Import-EvidenceFile "chargeback-closeout" $ChargebackCloseoutArtifactPath "latest-chargeback-closeout-evidence.md" $false

Import-EvidenceFile "enterprise-auth" $EnterpriseAuthArtifactPath "latest-enterprise-auth-smoke.json" $true "" "" "enterprise-auth"
Import-EvidenceFile "enterprise-auth" $EnterpriseAuthArtifactPath "latest-enterprise-auth-smoke.md" $false

Import-EvidenceFile "enterprise-auth-jit-rollback" $EnterpriseAuthJitRollbackArtifactPath "latest-enterprise-auth-jit-rollback-evidence.json" $true "" "" "enterprise-auth-jit-rollback"
Import-EvidenceFile "enterprise-auth-jit-rollback" $EnterpriseAuthJitRollbackArtifactPath "latest-enterprise-auth-jit-rollback-evidence.md" $false

Import-EvidenceFile "operations-handoff-package" $OperationsHandoffPackageArtifactPath "latest-operations-handoff-package.json" $true "" "" "operations-handoff-package"
Import-EvidenceFile "operations-handoff-package" $OperationsHandoffPackageArtifactPath "latest-operations-handoff-package.md" $false

Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-kubernetes-operations-report-sync.json" $true "" "" "kubernetes-operations-report-sync"
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-kubernetes-operations-report-sync-plan.json" $false
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-kubernetes-operations-report-sync-server-dry-run.json" $false
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-data-flow-storage-plan.json" $false "" "" "data-flow-storage-plan"
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-data-flow-query-retention-budget-evidence.json" $false "" "" "data-flow-query-retention-budget"
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-data-flow-storage-transition-runbook-evidence.json" $false "" "" "data-flow-storage-transition-runbook"

Import-EvidenceFile "data-flow-storage-plan" $DataFlowStoragePlanArtifactPath "latest-data-flow-storage-plan.json" $true "" "" "data-flow-storage-plan-passed"
Import-EvidenceFile "data-flow-query-retention-budget" $DataFlowQueryRetentionBudgetArtifactPath "latest-data-flow-query-retention-budget-evidence.json" $true "" "" "data-flow-query-retention-budget-passed"
Import-EvidenceFile "data-flow-query-retention-budget" $DataFlowQueryRetentionBudgetArtifactPath "latest-data-flow-query-retention-budget-evidence.md" $false
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
    [pscustomobject]@{ group = "minio-bucket-cors"; path = $MinioBucketCorsArtifactPath },
    [pscustomobject]@{ group = "monitoring-threshold"; path = $MonitoringThresholdArtifactPath },
    [pscustomobject]@{ group = "secret-rotation"; path = $SecretRotationArtifactPath },
    [pscustomobject]@{ group = "cluster-network-access-review"; path = $ClusterNetworkAccessReviewArtifactPath },
    [pscustomobject]@{ group = "helm-values-hardening"; path = $HelmValuesHardeningArtifactPath },
    [pscustomobject]@{ group = "support-escalation-handoff"; path = $SupportEscalationHandoffArtifactPath },
    [pscustomobject]@{ group = "commercial-integration"; path = $CommercialIntegrationArtifactPath },
    [pscustomobject]@{ group = "commercial-approval"; path = $CommercialApprovalArtifactPath },
    [pscustomobject]@{ group = "chargeback-closeout"; path = $ChargebackCloseoutArtifactPath },
    [pscustomobject]@{ group = "enterprise-auth"; path = $EnterpriseAuthArtifactPath },
    [pscustomobject]@{ group = "enterprise-auth-jit-rollback"; path = $EnterpriseAuthJitRollbackArtifactPath },
    [pscustomobject]@{ group = "operations-handoff-package"; path = $OperationsHandoffPackageArtifactPath },
    [pscustomobject]@{ group = "kubernetes-operations-report-sync"; path = $KubernetesOperationsReportSyncArtifactPath },
    [pscustomobject]@{ group = "data-flow-storage-plan"; path = $DataFlowStoragePlanArtifactPath },
    [pscustomobject]@{ group = "data-flow-query-retention-budget"; path = $DataFlowQueryRetentionBudgetArtifactPath },
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
