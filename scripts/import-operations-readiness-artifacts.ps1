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

function Test-DataFlowStoragePlanEvidenceJson([string] $Path) {
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

    $candidateStore = [string] (Get-JsonProperty $json "candidateStore")
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
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion candidateStore=$candidateStore queryPlanEvidencePresent=$($null -ne $queryPlanEvidence)"
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

    $summary = Get-JsonProperty $json "summary"
    $failureCount = [string] (Get-JsonProperty $summary "failureCount")
    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result storagePlanResult=$planResult failureCount=$failureCount"
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
    $requiredAlertCount = [int] (Get-JsonProperty $summary "requiredAlertCount")
    $mappedAlertCount = [int] (Get-JsonProperty $summary "mappedAlertCount")
    $missingAlerts = @(Get-JsonProperty $summary "missingAlerts")
    if ($requiredAlertCount -le 0 -or $mappedAlertCount -lt $requiredAlertCount -or $missingAlerts.Count -gt 0) {
        return [pscustomobject]@{
            passed = $false
            detail = "threshold target mapping incomplete required=$requiredAlertCount mapped=$mappedAlertCount missing=$($missingAlerts -join ',')"
        }
    }

    $confirmations = Get-JsonProperty $json "confirmations"
    foreach ($confirmationName in @("prometheusRulesLoaded", "grafanaDashboardImported", "alertmanagerRoutesReviewed", "targetBaselinesReviewed", "incidentRoutingReviewed", "noSecretValues")) {
        if (-not [bool] (Get-JsonProperty $confirmations $confirmationName)) {
            return [pscustomobject]@{
                passed = $false
                detail = "confirmation $confirmationName expected=true"
            }
        }
    }

    return [pscustomobject]@{
        passed = $true
        detail = "formatVersion=$formatVersion result=$result requiredAlerts=$requiredAlertCount mappedAlerts=$mappedAlertCount"
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

    if ($ValidationKind -eq "data-flow-storage-plan") {
        $validation = Test-DataFlowStoragePlanEvidenceJson $sourcePath
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
    elseif ($ValidationKind -eq "operations-handoff-package") {
        $validation = Test-OperationsHandoffPackageEvidenceJson $sourcePath
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

Import-EvidenceFile "storage-expansion" $StorageExpansionArtifactPath "latest-storage-expansion-finalize.json" $true "result" "passed"
Import-EvidenceFile "storage-expansion" $StorageExpansionArtifactPath "latest-storage-expansion-finalize.md" $false
Import-EvidenceFile "storage-expansion" $StorageExpansionArtifactPath "latest-storage-expansion-rbac-auth.json" $false
Import-EvidenceFile "storage-expansion" $StorageExpansionArtifactPath "latest-storage-expansion-server-dry-run.json" $false

Import-EvidenceFile "ha-dr-readiness" $HaDrReadinessArtifactPath "latest-kubernetes-ha-dr-readiness.json" $true "result" "passed"

Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-finalize.json" $true "result" "ready"
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-finalize.md" $false
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-drill.json" $false
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-restore-smoke.json" $false
Import-EvidenceFile "kubernetes-dr" $KubernetesDrArtifactPath "latest-kubernetes-dr-evidence-request.json" $false

Import-EvidenceFile "iam-rbac" $IamRbacArtifactPath "latest-iam-rbac-finalize.json" $true "result" "passed"
Import-EvidenceFile "iam-rbac" $IamRbacArtifactPath "latest-iam-rbac-finalize.md" $false
Import-EvidenceFile "iam-rbac" $IamRbacArtifactPath "latest-storage-expansion-rbac-auth.json" $false

Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-security-evidence-finalize.json" $true "result" "passed"
Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-security-evidence-finalize.md" $false
Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-image-signing-evidence.json" $true "result" "passed"
Import-EvidenceFile "security-evidence" $SecurityEvidenceArtifactPath "latest-container-security-evidence.json" $true "result" "passed"

Import-EvidenceFile "storage-backend-telemetry" $StorageBackendTelemetryArtifactPath "latest-storage-backend-telemetry.json" $true "result" "passed"
Import-EvidenceFile "storage-backend-telemetry" $StorageBackendTelemetryArtifactPath "latest-storage-backend-telemetry.md" $false

Import-EvidenceFile "monitoring-threshold" $MonitoringThresholdArtifactPath "latest-monitoring-threshold-evidence.json" $true "" "" "monitoring-threshold"
Import-EvidenceFile "monitoring-threshold" $MonitoringThresholdArtifactPath "latest-monitoring-threshold-evidence.md" $false

Import-EvidenceFile "secret-rotation" $SecretRotationArtifactPath "latest-secret-rotation-evidence.json" $true "result" "passed"
Import-EvidenceFile "secret-rotation" $SecretRotationArtifactPath "latest-secret-rotation-evidence.md" $false

Import-EvidenceFile "commercial-integration" $CommercialIntegrationArtifactPath "latest-commercial-integration-evidence.json" $true "result" "passed"
Import-EvidenceFile "commercial-integration" $CommercialIntegrationArtifactPath "latest-commercial-integration-evidence.md" $false

Import-EvidenceFile "commercial-approval" $CommercialApprovalArtifactPath "latest-commercial-approval-evidence.json" $true "result" "passed"
Import-EvidenceFile "commercial-approval" $CommercialApprovalArtifactPath "latest-commercial-approval-evidence.md" $false

Import-EvidenceFile "enterprise-auth" $EnterpriseAuthArtifactPath "latest-enterprise-auth-smoke.json" $true "result" "passed|scope-out"
Import-EvidenceFile "enterprise-auth" $EnterpriseAuthArtifactPath "latest-enterprise-auth-smoke.md" $false

Import-EvidenceFile "operations-handoff-package" $OperationsHandoffPackageArtifactPath "latest-operations-handoff-package.json" $true "" "" "operations-handoff-package"
Import-EvidenceFile "operations-handoff-package" $OperationsHandoffPackageArtifactPath "latest-operations-handoff-package.md" $false

Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-kubernetes-operations-report-sync.json" $true "result" "applied"
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-kubernetes-operations-report-sync-plan.json" $false
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-kubernetes-operations-report-sync-server-dry-run.json" $false
Import-EvidenceFile "kubernetes-operations-report-sync" $KubernetesOperationsReportSyncArtifactPath "latest-data-flow-storage-plan.json" $false "" "" "data-flow-storage-plan"

Import-EvidenceFile "data-flow-storage-plan" $DataFlowStoragePlanArtifactPath "latest-data-flow-storage-plan.json" $true "" "" "data-flow-storage-plan"
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
