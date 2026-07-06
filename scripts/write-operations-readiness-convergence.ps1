param(
    [string] $HandoffReportPath = ".\.osmu-run\latest-operations-evidence-handoff.json",
    [string] $ReadinessReportPath = ".\.osmu-run\latest-operations-readiness.json",
    [string] $OperationsReadinessFinalizeReportPath = ".\.osmu-run\latest-operations-readiness-finalize.json",
    [string] $KubernetesOperationsReportSyncReportPath = ".\.osmu-run\latest-kubernetes-operations-report-sync.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-readiness-convergence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-readiness-convergence.md",
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    $resolvedPath = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}
function Read-OptionalJson([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        return [ordered]@{
            path = $resolved
            exists = $false
            json = $null
        }
    }
    return [ordered]@{
        path = $resolved
        exists = $true
        json = (Read-Utf8Text $resolved | ConvertFrom-Json)
    }
}

function Get-JsonProperty([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-Text([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Get-Int([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return 0
    }
    try {
        return [int] $value
    }
    catch {
        return 0
    }
}

function Get-Bool([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return $false
    }
    if ($value -is [bool]) {
        return $value
    }
    $parsed = $false
    if ([bool]::TryParse([string] $value, [ref] $parsed)) {
        return $parsed
    }
    return $false
}
function Get-ReportTimestamp([object] $Report) {
    if ($null -eq $Report -or -not $Report.exists) {
        return [pscustomobject]@{
            valid = $false
            value = $null
            raw = ""
            source = "missing"
        }
    }
    $raw = Get-Text $Report.json "generatedAt"
    $parsed = [DateTimeOffset]::MinValue
    if ((-not [string]::IsNullOrWhiteSpace($raw)) -and [DateTimeOffset]::TryParse($raw, [ref] $parsed)) {
        return [pscustomobject]@{
            valid = $true
            value = $parsed.ToUniversalTime()
            raw = $raw
            source = "generatedAt"
        }
    }
    try {
        $lastWrite = (Get-Item -LiteralPath $Report.path).LastWriteTimeUtc
        $fallback = [DateTimeOffset]::new([DateTime]::SpecifyKind($lastWrite, [DateTimeKind]::Utc))
        return [pscustomobject]@{
            valid = $true
            value = $fallback
            raw = $fallback.ToString("o")
            source = "fileLastWriteTimeUtc"
        }
    }
    catch {
        return [pscustomobject]@{
            valid = $false
            value = $null
            raw = ""
            source = "unavailable"
        }
    }
}

function Format-ReportTimestamp([object] $Timestamp) {
    if ($null -eq $Timestamp -or -not $Timestamp.valid) {
        return "unknown"
    }
    return "$($Timestamp.raw) via $($Timestamp.source)"
}

function Get-RequiredInt([object] $Object, [string] $Name) {
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

function Get-ArrayCount([object] $Value) {
    if ($null -eq $Value) {
        return 0
    }
    return @($Value).Count
}


function Get-Array([object] $Value) {
    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [System.Array]) {
        return @($Value)
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value)
    }
    return @($Value)
}

function Get-TextListFromJsonArray([object] $Value) {
    return @(Get-Array $Value | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Join-TextListPreview([string[]] $Values, [int] $Limit = 8) {
    $items = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($items.Count -eq 0) { return "none" }
    $preview = @($items | Select-Object -First $Limit)
    $suffix = if ($items.Count -gt $Limit) { ",..." } else { "" }
    return ($preview -join ",") + $suffix
}

function New-OperatorInputValueActionSummary([object] $Action) {
    return [ordered]@{
        actionOrder = Get-Int $Action "actionOrder"
        actionName = Get-Text $Action "actionName"
        category = Get-Text $Action "category"
        workflow = Get-Text $Action "workflow"
        inputFree = Get-Bool $Action "inputFree"
        status = Get-Text $Action "status"
        valueCount = Get-Int $Action "valueCount"
        readyValueCount = Get-Int $Action "readyValueCount"
        missingValueCount = Get-Int $Action "missingValueCount"
        unsafeValueCount = Get-Int $Action "unsafeValueCount"
        invalidValueCount = Get-Int $Action "invalidValueCount"
        nonReadyValueKeys = @(Get-TextListFromJsonArray (Get-JsonProperty $Action "nonReadyValueKeys"))
    }
}
function Get-ReadyDispatchUrls([object] $HandoffReport) {
    $urls = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    $workflows = Get-JsonProperty $HandoffReport "readyDispatchWorkflows"
    foreach ($workflow in @($workflows)) {
        $url = Get-Text $workflow "dispatchUrl"
        if ([string]::IsNullOrWhiteSpace($url) -or $seen.ContainsKey($url)) {
            continue
        }
        $seen[$url] = $true
        [void] $urls.Add($url)
    }
    return @($urls)
}

function Get-BrowserDispatchDependencyNotes([object] $HandoffReport) {
    $notes = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    $checklist = Get-JsonProperty $HandoffReport "browserDispatchChecklist"
    foreach ($item in @($checklist)) {
        $note = Get-Text $item "securityFinalizerDependencyNote"
        if ([string]::IsNullOrWhiteSpace($note) -or $seen.ContainsKey($note)) {
            continue
        }
        $seen[$note] = $true
        [void] $notes.Add($note)
    }
    return @($notes)
}

function Join-NoteParts([string[]] $Parts) {
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($part in @($Parts)) {
        if (-not [string]::IsNullOrWhiteSpace($part)) {
            [void] $result.Add($part.Trim())
        }
    }
    return ($result -join " ").Trim()
}

function Is-ReadyResult([string] $Result) {
    return @("ready", "passed", "go") -contains $Result.ToLowerInvariant()
}

function New-Command([int] $Order, [string] $Name, [string] $Command, [string] $Reason, [string] $Note = "", [string[]] $DispatchUrls = @()) {
    $commandResult = [ordered]@{
        order = $Order
        name = $Name
        command = $Command
        reason = $Reason
        note = $Note
    }
    if (@($DispatchUrls).Count -gt 0) {
        $commandResult.dispatchUrls = @($DispatchUrls)
    }
    return $commandResult
}

function Quote-PowerShellArgument([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "''"
    }
    if ($Value -match '^[A-Za-z0-9_./:\\-]+$') {
        return $Value
    }
    return "'" + $Value.Replace("'", "''") + "'"
}

function New-KubernetesReportSyncCommand([object] $Report, [string] $Mode) {
    $arguments = @(
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ".\scripts\sync-kubernetes-operations-reports.ps1"
    )
    $namespace = Get-Text $Report "namespace"
    $configMapName = Get-Text $Report "configMapName"
    $configMapKey = Get-Text $Report "configMapKey"
    $sourceReportPath = Get-Text $Report "sourceReportPath"
    if (-not [string]::IsNullOrWhiteSpace($namespace)) {
        $arguments += @("-Namespace", $namespace)
    }
    if (-not [string]::IsNullOrWhiteSpace($configMapName)) {
        $arguments += @("-ConfigMapName", $configMapName)
    }
    if (-not [string]::IsNullOrWhiteSpace($configMapKey)) {
        $arguments += @("-ConfigMapKey", $configMapKey)
    }
    if (-not [string]::IsNullOrWhiteSpace($sourceReportPath)) {
        $arguments += @("-ReportPath", $sourceReportPath)
    }
    $arguments += $Mode
    return ($arguments | ForEach-Object { Quote-PowerShellArgument $_ }) -join " "
}

function Test-ExplicitFalse([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return $false
    }
    try {
        return -not [System.Convert]::ToBoolean($value)
    }
    catch {
        return $false
    }
}
function Get-KubernetesReportSyncNextCommand([object] $Report, [bool] $Exists) {
    if (-not $Exists) {
        return "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-kubernetes-operations-reports.ps1 -PlanOnly"
    }
    $result = Get-Text $Report "result"
    if ("planned".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)) {
        return New-KubernetesReportSyncCommand $Report "-ServerDryRunOnly"
    }
    if ("server-dry-run-passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)) {
        return New-KubernetesReportSyncCommand $Report "-Apply"
    }
    return New-KubernetesReportSyncCommand $Report "-PlanOnly"
}

function Get-KubernetesReportSyncWorkflowCommand([object] $Report, [bool] $Exists) {
    $namespace = Get-Text $Report "namespace"
    if ([string]::IsNullOrWhiteSpace($namespace)) {
        $namespace = "osmu"
    }
    $reportPath = Get-Text $Report "sourceReportPath"
    if ([string]::IsNullOrWhiteSpace($reportPath)) {
        $reportPath = "./.osmu-run/latest-operations-readiness-convergence.json"
    }

    $runLive = "false"
    $apply = "false"
    if ($Exists) {
        $result = Get-Text $Report "result"
        if ("planned".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)) {
            $runLive = "true"
        }
        elseif ("server-dry-run-passed".Equals($result, [System.StringComparison]::OrdinalIgnoreCase)) {
            $runLive = "true"
            $apply = "true"
        }
    }

    $fields = @(
        "namespace=$namespace",
        "report_path=$reportPath",
        "run_live=$runLive",
        "apply=$apply"
    )
    if ((-not $Exists) -or (-not (Test-ExplicitFalse $Report "publishDataFlowStoragePlanToConfigMap"))) {
        $fields += "data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json>"
    }
    if ((-not $Exists) -or (-not (Test-ExplicitFalse $Report "publishDataFlowQueryRetentionBudgetToConfigMap"))) {
        $fields += "data_flow_query_retention_budget_json_base64=<base64-latest-data-flow-query-retention-budget-json>"
    }
    if ((-not $Exists) -or (-not (Test-ExplicitFalse $Report "publishDataFlowStorageTransitionRunbookToConfigMap"))) {
        $fields += "data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>"
    }

    return "gh workflow run kubernetes-operations-report-sync-ci.yml " + (($fields | ForEach-Object { "-f $_" }) -join " ")
}

$handoff = Read-OptionalJson $HandoffReportPath
$readiness = Read-OptionalJson $ReadinessReportPath
$finalize = Read-OptionalJson $OperationsReadinessFinalizeReportPath
$kubernetesReportSync = Read-OptionalJson $KubernetesOperationsReportSyncReportPath

$handoffResult = Get-Text $handoff.json "result"
$readinessResult = Get-Text $readiness.json "result"
$readinessSummary = Get-Text $readiness.json "summary"
$readinessPassedCount = Get-Int $readiness.json "passedCount"
$readinessPendingCount = Get-Int $readiness.json "pendingCount"
$readinessTotalCount = Get-Int $readiness.json "totalCount"
$readinessCheckCount = Get-Int $readiness.json "checkCount"
$handoffTimestamp = Get-ReportTimestamp $handoff
$readinessTimestamp = Get-ReportTimestamp $readiness
$handoffStale = $handoff.exists -and $readiness.exists -and $handoffTimestamp.valid -and $readinessTimestamp.valid -and ($handoffTimestamp.value -lt $readinessTimestamp.value)
$refreshHandoffCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-handoff.ps1"
$refreshHandoffReason = "The operations readiness report is newer than the evidence handoff report, so the selected bottleneck may be stale."
$refreshHandoffNote = "Readiness timestamp: $(Format-ReportTimestamp $readinessTimestamp); handoff timestamp: $(Format-ReportTimestamp $handoffTimestamp)."
$finalizerTimestamp = Get-ReportTimestamp $finalize
$kubernetesReportSyncTimestamp = Get-ReportTimestamp $kubernetesReportSync
$latestSyncSourceTimestamp = @($handoffTimestamp, $readinessTimestamp, $finalizerTimestamp) | Where-Object { $_.valid } | Sort-Object -Property value -Descending | Select-Object -First 1
$kubernetesReportSyncStale = $kubernetesReportSync.exists -and $kubernetesReportSyncTimestamp.valid -and $null -ne $latestSyncSourceTimestamp -and $latestSyncSourceTimestamp.valid -and ($kubernetesReportSyncTimestamp.value -lt $latestSyncSourceTimestamp.value)
$kubernetesReportSyncFreshnessReason = if ($kubernetesReportSyncStale) {
    "Kubernetes operations report sync evidence is older than the latest handoff/readiness/finalizer input: sync=$(Format-ReportTimestamp $kubernetesReportSyncTimestamp); latest=$(Format-ReportTimestamp $latestSyncSourceTimestamp)."
}
else {
    ""
}
$finalizerResult = Get-Text $finalize.json "result"
$finalizerReadinessResult = Get-Text $finalize.json "readinessResult"
$finalizerFailedCountResult = Get-RequiredInt $finalize.json "failedCount"
$finalizerFailedCount = if ($null -eq $finalizerFailedCountResult.value) { 0 } else { [int64] $finalizerFailedCountResult.value }
$finalizerGapCount = Get-ArrayCount (Get-JsonProperty $finalize.json "gaps")
$kubernetesReportSyncResult = Get-Text $kubernetesReportSync.json "result"
$kubernetesReportSyncFailedCountResult = Get-RequiredInt $kubernetesReportSync.json "failedCount"
$kubernetesReportSyncFailedCount = if ($null -eq $kubernetesReportSyncFailedCountResult.value) { 0 } else { [int64] $kubernetesReportSyncFailedCountResult.value }
$kubernetesReportSyncSourceReportResult = Get-Text $kubernetesReportSync.json "sourceReportResult"
$nextStep = Get-JsonProperty $handoff.json "nextStep"
$nextCode = Get-Text $nextStep "code"
$nextCommand = Get-Text $nextStep "command"
$nextStepDispatchUrls = if ($nextCode -like "dispatch-ready-subset*") { Get-ReadyDispatchUrls $handoff.json } else { @() }
$handoffBrowserDispatchDependencyNotes = if ($nextCode -like "dispatch-ready-subset*") { Get-BrowserDispatchDependencyNotes $handoff.json } else { @() }
$handoffSecurityEvidenceFinalizerRunIdInputHints = @(Get-Array (Get-JsonProperty $handoff.json "securityEvidenceFinalizerRunIdInputHints"))
$handoffRequiredGitHubSecretCount = Get-Int $handoff.json "requiredGitHubSecretCount"
$handoffRequiredGitHubSecrets = @(Get-Array (Get-JsonProperty $handoff.json "requiredGitHubSecrets") | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($handoffRequiredGitHubSecretCount -eq 0) { $handoffRequiredGitHubSecretCount = $handoffRequiredGitHubSecrets.Count }
$handoffRequiredGitHubSecretSummaries = @(Get-Array (Get-JsonProperty $handoff.json "requiredGitHubSecretSummaries") | ForEach-Object {
    [ordered]@{
        secretName = Get-Text $_ "secretName"
        actionCount = Get-Int $_ "actionCount"
        actionOrders = @(Get-Array (Get-JsonProperty $_ "actionOrders") | ForEach-Object { try { [int] $_ } catch { 0 } } | Where-Object { $_ -gt 0 })
        inputFreeBlockedActionCount = Get-Int $_ "inputFreeBlockedActionCount"
        inputFreeBlockedActionOrders = @(Get-Array (Get-JsonProperty $_ "inputFreeBlockedActionOrders") | ForEach-Object { try { [int] $_ } catch { 0 } } | Where-Object { $_ -gt 0 })
    }
} | Where-Object { -not [string]::IsNullOrWhiteSpace($_.secretName) })
$handoffRequiredGitHubSecretsText = if ($handoffRequiredGitHubSecrets.Count -gt 0) { $handoffRequiredGitHubSecrets -join "," } else { "none" }
$handoffInputFreeBlockedActionCount = Get-Int $handoff.json "inputFreeBlockedActionCount"
$handoffInputFreeBlockedActionOrders = @(Get-Array (Get-JsonProperty $handoff.json "inputFreeBlockedActionOrders") | ForEach-Object { try { [int] $_ } catch { 0 } } | Where-Object { $_ -gt 0 })
$handoffInputFreeBlockedActionOrdersText = if ($handoffInputFreeBlockedActionOrders.Count -gt 0) { $handoffInputFreeBlockedActionOrders -join "," } else { "none" }
$handoffInputFreeBlockedReviewCommand = Get-Text $handoff.json "inputFreeBlockedReviewCommand"
$handoffInputFreeBlockedReviewReportCommand = Get-Text $handoff.json "inputFreeBlockedReviewReportCommand"
$handoffInputFreeBlockedReviewReportJsonPath = Get-Text $handoff.json "inputFreeBlockedReviewReportJsonPath"
$handoffInputFreeBlockedReviewReportMarkdownPath = Get-Text $handoff.json "inputFreeBlockedReviewReportMarkdownPath"
$handoffInputFreeBlockedConfirmedPlanCommand = Get-Text $handoff.json "inputFreeBlockedConfirmedPlanCommand"
$handoffInputFreeBlockedReviewReportExists = Get-Bool $handoff.json "inputFreeBlockedReviewReportExists"
$handoffInputFreeBlockedReviewReportResult = Get-Text $handoff.json "inputFreeBlockedReviewReportResult"
$handoffInputFreeBlockedReviewReportGeneratedAt = Get-Text $handoff.json "inputFreeBlockedReviewReportGeneratedAt"
$handoffInputFreeBlockedReviewReportSelectedActionCount = Get-Int $handoff.json "inputFreeBlockedReviewReportSelectedActionCount"
$handoffInputFreeBlockedReviewReportPlannedCount = Get-Int $handoff.json "inputFreeBlockedReviewReportPlannedCount"
$handoffInputFreeBlockedReviewReportBlockedCount = Get-Int $handoff.json "inputFreeBlockedReviewReportBlockedCount"
$handoffInputFreeBlockedReviewReportFailedCount = Get-Int $handoff.json "inputFreeBlockedReviewReportFailedCount"
$handoffInputFreeBlockedReviewReportExecutedCount = Get-Int $handoff.json "inputFreeBlockedReviewReportExecutedCount"
$handoffInputFreeBlockedReviewReportActionOrders = @(Get-Array (Get-JsonProperty $handoff.json "inputFreeBlockedReviewReportActionOrders") | ForEach-Object { try { [int] $_ } catch { 0 } } | Where-Object { $_ -gt 0 })
$handoffInputFreeBlockedReviewReportActionOrdersText = if ($handoffInputFreeBlockedReviewReportActionOrders.Count -gt 0) { $handoffInputFreeBlockedReviewReportActionOrders -join "," } else { "none" }
$handoffInputFreeBlockedReviewReportStale = Get-Bool $handoff.json "inputFreeBlockedReviewReportStale"
$handoffInputFreeBlockedReviewReportScopeMismatch = Get-Bool $handoff.json "inputFreeBlockedReviewReportScopeMismatch"
if ([string]::IsNullOrWhiteSpace($handoffInputFreeBlockedConfirmedPlanCommand)) { $handoffInputFreeBlockedConfirmedPlanCommand = Get-Text $handoff.json "inputFreeBlockedPlanCommand" }
$handoffInputFreeBlockedActions = @(Get-Array (Get-JsonProperty $handoff.json "inputFreeBlockedActions") | ForEach-Object {
    [ordered]@{
        actionOrder = Get-Int $_ "actionOrder"
        name = Get-Text $_ "name"
        blockReasonCount = Get-Int $_ "blockReasonCount"
        blockReasons = @(Get-Array (Get-JsonProperty $_ "blockReasons") | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        requiredSecretCount = Get-Int $_ "requiredSecretCount"
        requiredSecrets = @(Get-Array (Get-JsonProperty $_ "requiredSecrets") | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        needsOperatorApprovalConfirmation = Get-Bool $_ "needsOperatorApprovalConfirmation"
        needsKubeconfigSecretConfirmation = Get-Bool $_ "needsKubeconfigSecretConfirmation"
        defaultBranchWorkflowMissing = Get-Bool $_ "defaultBranchWorkflowMissing"
        reviewCommand = Get-Text $_ "reviewCommand"
        confirmedPlanCommand = if ([string]::IsNullOrWhiteSpace((Get-Text $_ "confirmedPlanCommand"))) { Get-Text $_ "planCommand" } else { Get-Text $_ "confirmedPlanCommand" }
        planCommand = Get-Text $_ "planCommand"
    }
})
$handoffOperatorInputValuesProfileReportPath = Get-Text $handoff.json "operatorInputValuesProfileReportPath"
$handoffOperatorInputValuesProfileExists = Get-Bool $handoff.json "operatorInputValuesProfileExists"
$handoffOperatorInputValuesProfileResult = Get-Text $handoff.json "operatorInputValuesProfileResult"
$handoffOperatorInputValuesProfileGeneratedAt = Get-Text $handoff.json "operatorInputValuesProfileGeneratedAt"
$handoffOperatorInputValuesProfileDefaultsUsed = Get-Bool $handoff.json "operatorInputValuesProfileDefaultsUsed"
$handoffOperatorInputValuesProfileDefaultsSkipped = Get-Bool $handoff.json "operatorInputValuesProfileDefaultsSkipped"
$handoffOperatorInputValuesProfileDefaultsSkipReason = Get-Text $handoff.json "operatorInputValuesProfileDefaultsSkipReason"
$handoffOperatorInputValuesProfileDefaultValueCount = Get-Int $handoff.json "operatorInputValuesProfileDefaultValueCount"
$handoffOperatorInputValuesProfileFilledValueCount = Get-Int $handoff.json "operatorInputValuesProfileFilledValueCount"
$handoffOperatorInputValuesProfileBlankValueCount = Get-Int $handoff.json "operatorInputValuesProfileBlankValueCount"
$handoffOperatorInputValuesCheckResult = Get-Text $handoff.json "operatorInputValuesCheckResult"
$handoffOperatorInputValuesCheckValueCount = Get-Int $handoff.json "operatorInputValuesCheckValueCount"
$handoffOperatorInputValuesCheckReadyValueCount = Get-Int $handoff.json "operatorInputValuesCheckReadyValueCount"
$handoffOperatorInputValuesCheckMissingValueCount = Get-Int $handoff.json "operatorInputValuesCheckMissingValueCount"
$handoffOperatorInputValuesCheckUnsafeValueCount = Get-Int $handoff.json "operatorInputValuesCheckUnsafeValueCount"
$handoffOperatorInputValuesCheckInvalidValueCount = Get-Int $handoff.json "operatorInputValuesCheckInvalidValueCount"
$handoffOperatorInputValuesCheckValueReadyActionCount = Get-Int $handoff.json "operatorInputValuesCheckValueReadyActionCount"
$handoffOperatorInputValuesCheckNonReadyActionCount = Get-Int $handoff.json "operatorInputValuesCheckNonReadyActionCount"
$handoffOperatorInputValuesCheckActionSummaryCount = Get-Int $handoff.json "operatorInputValuesCheckActionSummaryCount"
$handoffOperatorInputValuesCheckNonReadyActionOrders = @(Get-Array (Get-JsonProperty $handoff.json "operatorInputValuesCheckNonReadyActionOrders") | ForEach-Object { try { [int] $_ } catch { 0 } } | Where-Object { $_ -gt 0 })
$handoffOperatorInputValuesCheckNonReadyActionOrdersText = if ($handoffOperatorInputValuesCheckNonReadyActionOrders.Count -gt 0) { $handoffOperatorInputValuesCheckNonReadyActionOrders -join "," } else { "none" }
$handoffOperatorInputValuesCheckNonReadyActionSummaries = @(Get-Array (Get-JsonProperty $handoff.json "operatorInputValuesCheckNonReadyActionSummaries") | ForEach-Object { New-OperatorInputValueActionSummary $_ } | Where-Object { (Get-Int $_ "actionOrder") -gt 0 })
if ($handoffOperatorInputValuesCheckActionSummaryCount -eq 0) {
    $handoffOperatorInputValuesCheckActionSummaryCount = @(Get-Array (Get-JsonProperty $handoff.json "operatorInputValuesCheckActionSummaries")).Count
}
$handoffBrowserDispatchDependencyNote = Join-NoteParts $handoffBrowserDispatchDependencyNotes
$nextStepNote = Join-NoteParts @((Get-Text $nextStep "note"), $handoffBrowserDispatchDependencyNote)
$handoffWorkflowRunIdPlanQueryMode = Get-Text $handoff.json "workflowRunIdPlanQueryMode"
$handoffWorkflowRunIdPlanGithubApiTokenPresent = Get-Bool $handoff.json "workflowRunIdPlanGithubApiTokenPresent"
$handoffWorkflowRunIdPlanGithubApiUnauthenticated = Get-Bool $handoff.json "workflowRunIdPlanGithubApiUnauthenticated"
$handoffWorkflowRunIdPlanQueryExecuted = Get-Bool $handoff.json "workflowRunIdPlanQueryExecuted"
$handoffWorkflowRunIdPlanQueryExecutedCount = Get-Int $handoff.json "workflowRunIdPlanQueryExecutedCount"
$handoffWorkflowRunIdPlanQueryWorkflowCount = Get-Int $handoff.json "workflowRunIdPlanQueryWorkflowCount"
$handoffWorkflowRunIdPlanQuerySucceededCount = Get-Int $handoff.json "workflowRunIdPlanQuerySucceededCount"
$handoffWorkflowRunIdPlanQueryErrorCount = Get-Int $handoff.json "workflowRunIdPlanQueryErrorCount"
$handoffWorkflowRunIdPlanCandidateCount = Get-Int $handoff.json "workflowRunIdPlanCandidateCount"
$handoffPostDispatchCommands = @(Get-Array (Get-JsonProperty $handoff.json "postDispatchCommands") | ForEach-Object {
    [ordered]@{
        name = Get-Text $_ "name"
        command = Get-Text $_ "command"
        note = Get-Text $_ "note"
    }
} | Where-Object { -not [string]::IsNullOrWhiteSpace($_.name) -or -not [string]::IsNullOrWhiteSpace($_.command) -or -not [string]::IsNullOrWhiteSpace($_.note) })
$kubernetesReportSyncCommand = Get-KubernetesReportSyncNextCommand $kubernetesReportSync.json $kubernetesReportSync.exists
$kubernetesReportSyncWorkflowCommand = Get-KubernetesReportSyncWorkflowCommand $kubernetesReportSync.json $kubernetesReportSync.exists
$handoffReady = $handoff.exists -and (Is-ReadyResult $handoffResult) -and "none".Equals($nextCode, [System.StringComparison]::OrdinalIgnoreCase)
$readinessReady = $readiness.exists -and (Is-ReadyResult $readinessResult)
$finalizerReady = $finalize.exists -and (Is-ReadyResult $finalizerResult) -and (Is-ReadyResult $finalizerReadinessResult) -and $finalizerFailedCountResult.valid -and $finalizerFailedCount -eq 0 -and $finalizerGapCount -eq 0
$kubernetesReportSyncReady = $kubernetesReportSync.exists -and (-not $kubernetesReportSyncStale) -and "applied".Equals($kubernetesReportSyncResult, [System.StringComparison]::OrdinalIgnoreCase) -and $kubernetesReportSyncFailedCountResult.valid -and $kubernetesReportSyncFailedCount -eq 0 -and (Is-ReadyResult $kubernetesReportSyncSourceReportResult)
$kubernetesReportSyncRequiredReason = if ($kubernetesReportSyncStale) {
    $kubernetesReportSyncFreshnessReason
}
else {
    "The convergence report has not been confirmed as applied to the Kubernetes operations report ConfigMap."
}

$recommendedCommands = @()
$seenCommands = @{}

function Add-RecommendedCommand([string] $Name, [string] $Command, [string] $Reason, [string] $Note = "", [string[]] $DispatchUrls = @()) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return
    }
    if ($seenCommands.ContainsKey($Command)) {
        return
    }
    $seenCommands[$Command] = $true
    $script:recommendedCommands += New-Command (@($script:recommendedCommands).Count + 1) $Name $Command $Reason $Note $DispatchUrls
}

if (-not $handoff.exists) {
    Add-RecommendedCommand `
        "Generate operations evidence handoff" `
        $refreshHandoffCommand `
        "The handoff report is missing, so the current bottleneck cannot be selected yet."
}
elseif ($handoffStale) {
    Add-RecommendedCommand `
        "Refresh operations evidence handoff" `
        $refreshHandoffCommand `
        $refreshHandoffReason `
        $refreshHandoffNote
}
elseif (-not (Is-ReadyResult $handoffResult) -or -not "none".Equals($nextCode, [System.StringComparison]::OrdinalIgnoreCase)) {
    Add-RecommendedCommand `
        (Get-Text $nextStep "title") `
        $nextCommand `
        (Get-Text $nextStep "reason") `
        $nextStepNote `
        $nextStepDispatchUrls


    $stages = Get-JsonProperty $handoff.json "stages"
    foreach ($stage in @($stages)) {
        $stageReady = [bool] (Get-JsonProperty $stage "ready")
        if (-not $stageReady) {
            Add-RecommendedCommand `
                ("Review " + (Get-Text $stage "name")) `
                (Get-Text $stage "command") `
                (Get-Text $stage "note")
        }
    }
}
elseif ($handoffReady -and -not $readinessReady) {
    Add-RecommendedCommand `
        "Regenerate operations readiness" `
        "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1" `
        "The handoff is ready, but the latest operations readiness report is not ready."
}
elseif ($handoffReady -and $readinessReady -and -not $finalizerReady) {
    Add-RecommendedCommand `
        "Finalize operations readiness" `
        "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1" `
        "The readiness report is ready, but finalizer evidence is missing or not ready."
}
elseif ($handoffReady -and $readinessReady -and $finalizerReady -and -not $kubernetesReportSyncReady) {
    Add-RecommendedCommand `
        "Sync Kubernetes operations report ConfigMap" `
        $kubernetesReportSyncCommand `
        $kubernetesReportSyncRequiredReason
}

$result = if ((-not $handoffStale) -and $handoffReady -and $readinessReady -and $finalizerReady -and $kubernetesReportSyncReady) { "ready" } else { "action-required" }

$currentBottleneck = if (-not $handoff.exists) {
    [ordered]@{
        code = "write-handoff"
        title = "Generate operations evidence handoff"
        reason = "The handoff report is missing."
        command = $refreshHandoffCommand
    }
}
elseif ($handoffStale) {
    [ordered]@{
        code = "refresh-handoff"
        title = "Refresh operations evidence handoff"
        reason = $refreshHandoffReason
        command = $refreshHandoffCommand
        note = $refreshHandoffNote
    }
}
elseif ($handoffReady -and -not $readinessReady) {
    [ordered]@{
        code = "regenerate-readiness"
        title = "Regenerate operations readiness"
        reason = "The handoff is ready, but the latest operations readiness report is not ready."
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1"
    }
}
elseif ($handoffReady -and $readinessReady -and -not $finalizerReady) {
    [ordered]@{
        code = "finalize-operations-readiness"
        title = "Finalize operations readiness"
        reason = "The readiness report is ready, but finalizer evidence is missing or not ready."
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1"
    }
}
elseif ($handoffReady -and $readinessReady -and $finalizerReady -and -not $kubernetesReportSyncReady) {
    [ordered]@{
        code = "sync-kubernetes-operations-report"
        title = "Sync Kubernetes operations report ConfigMap"
        reason = $kubernetesReportSyncRequiredReason
        command = $kubernetesReportSyncCommand
    }
}
else {
    [ordered]@{
        code = $nextCode
        title = Get-Text $nextStep "title"
        reason = Get-Text $nextStep "reason"
        command = $nextCommand
        note = $nextStepNote
    }
}
if (@($nextStepDispatchUrls).Count -gt 0 -and $currentBottleneck.code -like "dispatch-ready-subset*") {
    $currentBottleneck.dispatchUrls = @($nextStepDispatchUrls)
}

$generatedAt = [DateTimeOffset]::Now.ToString("o")
$report = [ordered]@{
    formatVersion = "osmu.operations-readiness-convergence.v1"
    generatedAt = $generatedAt
    result = $result
    handoffReportPath = $handoff.path
    readinessReportPath = $readiness.path
    operationsReadinessFinalizeReportPath = $finalize.path
    kubernetesOperationsReportSyncReportPath = $kubernetesReportSync.path
    handoffExists = [bool] $handoff.exists
    handoffResult = $handoffResult
    handoffStale = [bool] $handoffStale
    handoffTimestamp = $handoffTimestamp.raw
    handoffTimestampSource = $handoffTimestamp.source
    readinessTimestamp = $readinessTimestamp.raw
    readinessTimestampSource = $readinessTimestamp.source
    readinessExists = [bool] $readiness.exists
    readinessResult = $readinessResult
    readinessSummary = $readinessSummary
    readinessPassedCount = $readinessPassedCount
    readinessPendingCount = $readinessPendingCount
    readinessTotalCount = $readinessTotalCount
    readinessCheckCount = $readinessCheckCount
    finalizerExists = [bool] $finalize.exists
    finalizerResult = $finalizerResult
    finalizerReadinessResult = $finalizerReadinessResult
    finalizerFailedCount = $finalizerFailedCount
    finalizerFailedCountValid = [bool] $finalizerFailedCountResult.valid
    finalizerFailedCountRaw = [string] $finalizerFailedCountResult.raw
    finalizerGapCount = $finalizerGapCount
    kubernetesReportSyncExists = [bool] $kubernetesReportSync.exists
    kubernetesReportSyncResult = $kubernetesReportSyncResult
    kubernetesReportSyncStale = [bool] $kubernetesReportSyncStale
    kubernetesReportSyncTimestamp = $kubernetesReportSyncTimestamp.raw
    kubernetesReportSyncTimestampSource = $kubernetesReportSyncTimestamp.source
    kubernetesReportSyncFreshnessReason = $kubernetesReportSyncFreshnessReason
    kubernetesReportSyncFailedCount = $kubernetesReportSyncFailedCount
    kubernetesReportSyncFailedCountValid = [bool] $kubernetesReportSyncFailedCountResult.valid
    kubernetesReportSyncFailedCountRaw = [string] $kubernetesReportSyncFailedCountResult.raw
    kubernetesReportSyncConfigMapName = Get-Text $kubernetesReportSync.json "configMapName"
    kubernetesReportSyncConfigMapKey = Get-Text $kubernetesReportSync.json "configMapKey"
    kubernetesReportSyncSourceReportResult = $kubernetesReportSyncSourceReportResult
    kubernetesReportSyncWorkflowCommand = $kubernetesReportSyncWorkflowCommand
    kubernetesReportSyncWorkflowNote = "For GitHub Actions sync, include data_flow_storage_plan_json_base64 only when .osmu-run/latest-data-flow-storage-plan.json should be carried into the operations report ConfigMap, include data_flow_query_retention_budget_json_base64 only when .osmu-run/latest-data-flow-query-retention-budget-evidence.json should be carried into the same ConfigMap, and include data_flow_storage_transition_runbook_json_base64 only when .osmu-run/latest-data-flow-storage-transition-runbook-evidence.json should be carried into the same ConfigMap. MariaDB partition or dual-write plans must include the sanitized query-plan evidence summary, and query/retention budget and transition runbook evidence must be result=passed with no raw SQL, raw EXPLAIN, object keys, raw event messages, or credential-shaped content. Omit inputs when no target analytics-storage evidence is ready."
    kubernetesReportSyncReady = [bool] $kubernetesReportSyncReady
    handoffFinalizerGapCount = Get-Int $handoff.json "finalizerGapCount"
    stageCount = Get-Int $handoff.json "stageCount"
    readyStageCount = Get-Int $handoff.json "readyStageCount"
    blockedActionCount = Get-Int $handoff.json "blockedActionCount"
    handoffRequiredGitHubSecretCount = $handoffRequiredGitHubSecretCount
    handoffRequiredGitHubSecrets = @($handoffRequiredGitHubSecrets)
    handoffRequiredGitHubSecretSummaries = @($handoffRequiredGitHubSecretSummaries)
    handoffInputFreeBlockedActionCount = $handoffInputFreeBlockedActionCount
    handoffInputFreeBlockedActionOrders = @($handoffInputFreeBlockedActionOrders)
    handoffInputFreeBlockedReviewCommand = $handoffInputFreeBlockedReviewCommand
    handoffInputFreeBlockedReviewReportCommand = $handoffInputFreeBlockedReviewReportCommand
    handoffInputFreeBlockedReviewReportJsonPath = $handoffInputFreeBlockedReviewReportJsonPath
    handoffInputFreeBlockedReviewReportMarkdownPath = $handoffInputFreeBlockedReviewReportMarkdownPath
    handoffInputFreeBlockedReviewReportExists = $handoffInputFreeBlockedReviewReportExists
    handoffInputFreeBlockedReviewReportResult = $handoffInputFreeBlockedReviewReportResult
    handoffInputFreeBlockedReviewReportGeneratedAt = $handoffInputFreeBlockedReviewReportGeneratedAt
    handoffInputFreeBlockedReviewReportSelectedActionCount = $handoffInputFreeBlockedReviewReportSelectedActionCount
    handoffInputFreeBlockedReviewReportPlannedCount = $handoffInputFreeBlockedReviewReportPlannedCount
    handoffInputFreeBlockedReviewReportBlockedCount = $handoffInputFreeBlockedReviewReportBlockedCount
    handoffInputFreeBlockedReviewReportFailedCount = $handoffInputFreeBlockedReviewReportFailedCount
    handoffInputFreeBlockedReviewReportExecutedCount = $handoffInputFreeBlockedReviewReportExecutedCount
    handoffInputFreeBlockedReviewReportActionOrders = @($handoffInputFreeBlockedReviewReportActionOrders)
    handoffInputFreeBlockedReviewReportStale = $handoffInputFreeBlockedReviewReportStale
    handoffInputFreeBlockedReviewReportScopeMismatch = $handoffInputFreeBlockedReviewReportScopeMismatch
    handoffInputFreeBlockedConfirmedPlanCommand = $handoffInputFreeBlockedConfirmedPlanCommand
    handoffInputFreeBlockedActions = @($handoffInputFreeBlockedActions)
    handoffOperatorInputValuesProfileReportPath = $handoffOperatorInputValuesProfileReportPath
    handoffOperatorInputValuesProfileExists = $handoffOperatorInputValuesProfileExists
    handoffOperatorInputValuesProfileResult = $handoffOperatorInputValuesProfileResult
    handoffOperatorInputValuesProfileGeneratedAt = $handoffOperatorInputValuesProfileGeneratedAt
    handoffOperatorInputValuesProfileDefaultsUsed = $handoffOperatorInputValuesProfileDefaultsUsed
    handoffOperatorInputValuesProfileDefaultsSkipped = $handoffOperatorInputValuesProfileDefaultsSkipped
    handoffOperatorInputValuesProfileDefaultsSkipReason = $handoffOperatorInputValuesProfileDefaultsSkipReason
    handoffOperatorInputValuesProfileDefaultValueCount = $handoffOperatorInputValuesProfileDefaultValueCount
    handoffOperatorInputValuesProfileFilledValueCount = $handoffOperatorInputValuesProfileFilledValueCount
    handoffOperatorInputValuesProfileBlankValueCount = $handoffOperatorInputValuesProfileBlankValueCount
    handoffOperatorInputValuesCheckResult = $handoffOperatorInputValuesCheckResult
    handoffOperatorInputValuesCheckValueCount = $handoffOperatorInputValuesCheckValueCount
    handoffOperatorInputValuesCheckReadyValueCount = $handoffOperatorInputValuesCheckReadyValueCount
    handoffOperatorInputValuesCheckMissingValueCount = $handoffOperatorInputValuesCheckMissingValueCount
    handoffOperatorInputValuesCheckUnsafeValueCount = $handoffOperatorInputValuesCheckUnsafeValueCount
    handoffOperatorInputValuesCheckInvalidValueCount = $handoffOperatorInputValuesCheckInvalidValueCount
    handoffOperatorInputValuesCheckValueReadyActionCount = $handoffOperatorInputValuesCheckValueReadyActionCount
    handoffOperatorInputValuesCheckNonReadyActionCount = $handoffOperatorInputValuesCheckNonReadyActionCount
    handoffOperatorInputValuesCheckActionSummaryCount = $handoffOperatorInputValuesCheckActionSummaryCount
    handoffOperatorInputValuesCheckNonReadyActionOrders = @($handoffOperatorInputValuesCheckNonReadyActionOrders)
    handoffOperatorInputValuesCheckNonReadyActionSummaries = @($handoffOperatorInputValuesCheckNonReadyActionSummaries)
    handoffWorkflowRunIdPlanQueryMode = $handoffWorkflowRunIdPlanQueryMode
    handoffWorkflowRunIdPlanGithubApiTokenPresent = $handoffWorkflowRunIdPlanGithubApiTokenPresent
    handoffWorkflowRunIdPlanGithubApiUnauthenticated = $handoffWorkflowRunIdPlanGithubApiUnauthenticated
    handoffWorkflowRunIdPlanQueryExecuted = $handoffWorkflowRunIdPlanQueryExecuted
    handoffWorkflowRunIdPlanQueryExecutedCount = $handoffWorkflowRunIdPlanQueryExecutedCount
    handoffWorkflowRunIdPlanQueryWorkflowCount = $handoffWorkflowRunIdPlanQueryWorkflowCount
    handoffWorkflowRunIdPlanQuerySucceededCount = $handoffWorkflowRunIdPlanQuerySucceededCount
    handoffWorkflowRunIdPlanQueryErrorCount = $handoffWorkflowRunIdPlanQueryErrorCount
    handoffWorkflowRunIdPlanCandidateCount = $handoffWorkflowRunIdPlanCandidateCount
    missingWorkflowRunCount = Get-Int $handoff.json "missingWorkflowRunCount"
    missingRequiredArtifactCount = Get-Int $handoff.json "missingRequiredArtifactCount"
    failedImportCount = Get-Int $handoff.json "failedImportCount"
    currentBottleneck = $currentBottleneck
    handoffBrowserDispatchDependencyNotes = @($handoffBrowserDispatchDependencyNotes)
    handoffSecurityEvidenceFinalizerRunIdInputHintCount = $handoffSecurityEvidenceFinalizerRunIdInputHints.Count
    handoffSecurityEvidenceFinalizerRunIdInputHints = @($handoffSecurityEvidenceFinalizerRunIdInputHints)
    handoffPostDispatchCommands = @($handoffPostDispatchCommands)
    recommendedCommands = $recommendedCommands
    decisionRule = "Operations readiness convergence is ready only when the handoff result is ready/none, the readiness report is ready, the operations readiness finalizer report exists with result=ready, readinessResult=ready, typed integer failedCount=0, and no gaps, and the Kubernetes operations report sync evidence is fresh against the latest handoff/readiness/finalizer inputs and confirms result=applied, typed integer failedCount=0, and sourceReportResult=ready."
    safetyPolicy = "This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance."
}

$markdownLines = @(
    "# OSMU Operations Readiness Convergence",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "",
    "## Current Bottleneck",
    "",
    "- Code: $($currentBottleneck.code)",
    "- Title: $($currentBottleneck.title)",
    "- Reason: $($currentBottleneck.reason)",
    "- Note: $($currentBottleneck.note)",
    "- Command: ``$($currentBottleneck.command)``",
    "",
    "## Status",
    "",
    "- Handoff: $handoffResult",
    "- Handoff stale: $handoffStale",
    "- Handoff timestamp: $(Format-ReportTimestamp $handoffTimestamp)",
    "- Readiness timestamp: $(Format-ReportTimestamp $readinessTimestamp)",
    "- Readiness: $readinessResult",
    "- Readiness summary: $($report.readinessSummary)",
    "- Readiness counts: passed=$($report.readinessPassedCount) pending=$($report.readinessPendingCount) total=$($report.readinessTotalCount) checks=$($report.readinessCheckCount)",
    "- Finalizer: $finalizerResult",
    "- Finalizer readiness: $finalizerReadinessResult",
    "- Kubernetes report sync: $kubernetesReportSyncResult",
    "- Kubernetes report sync stale: $kubernetesReportSyncStale",
    "- Kubernetes report sync timestamp: $(Format-ReportTimestamp $kubernetesReportSyncTimestamp)",
    "- Kubernetes report sync ready: $kubernetesReportSyncReady",
    "- Kubernetes report sync ConfigMap: $($report.kubernetesReportSyncConfigMapName)",
    "- Kubernetes report sync workflow: ``$($report.kubernetesReportSyncWorkflowCommand)``",
    "- Kubernetes report sync workflow note: $($report.kubernetesReportSyncWorkflowNote)",
    "- Kubernetes report sync freshness reason: $($report.kubernetesReportSyncFreshnessReason)",
    "- Stages: $($report.readyStageCount)/$($report.stageCount) ready",
    "- Blocked actions: $($report.blockedActionCount)",
    "- Handoff required GitHub secrets: count=$($report.handoffRequiredGitHubSecretCount), names=$handoffRequiredGitHubSecretsText",
    "- Input-free blocked actions: $($report.handoffInputFreeBlockedActionCount)",
    "- Input-free blocked action orders: $handoffInputFreeBlockedActionOrdersText",
    "- Input-free review command: ``$handoffInputFreeBlockedReviewCommand``",
    "- Input-free review report command: ``$handoffInputFreeBlockedReviewReportCommand``",
    "- Input-free review report JSON: $handoffInputFreeBlockedReviewReportJsonPath",
    "- Input-free review report Markdown: $handoffInputFreeBlockedReviewReportMarkdownPath",
    "- Input-free review report exists: $handoffInputFreeBlockedReviewReportExists",
    "- Input-free review report result: $handoffInputFreeBlockedReviewReportResult",
    "- Input-free review report generated at: $handoffInputFreeBlockedReviewReportGeneratedAt",
    "- Input-free review report selected actions: $handoffInputFreeBlockedReviewReportSelectedActionCount",
    "- Input-free review report action orders: $handoffInputFreeBlockedReviewReportActionOrdersText",
    "- Input-free review report planned/blocked/failed/executed: $handoffInputFreeBlockedReviewReportPlannedCount/$handoffInputFreeBlockedReviewReportBlockedCount/$handoffInputFreeBlockedReviewReportFailedCount/$handoffInputFreeBlockedReviewReportExecutedCount",
    "- Input-free review report stale: $handoffInputFreeBlockedReviewReportStale",
    "- Input-free review report scope mismatch: $handoffInputFreeBlockedReviewReportScopeMismatch",
    "- Input-free confirmed plan command: ``$handoffInputFreeBlockedConfirmedPlanCommand``",
    "- Handoff operator input values profile: exists=$handoffOperatorInputValuesProfileExists, result=$handoffOperatorInputValuesProfileResult, defaultsUsed=$handoffOperatorInputValuesProfileDefaultsUsed, defaultsSkipped=$handoffOperatorInputValuesProfileDefaultsSkipped, defaultValues=$handoffOperatorInputValuesProfileDefaultValueCount, filled=$handoffOperatorInputValuesProfileFilledValueCount, blank=$handoffOperatorInputValuesProfileBlankValueCount",
    "- Handoff operator input values profile skip reason: $handoffOperatorInputValuesProfileDefaultsSkipReason",
    "- Handoff operator input values: result=$handoffOperatorInputValuesCheckResult, values=$handoffOperatorInputValuesCheckValueCount, ready=$handoffOperatorInputValuesCheckReadyValueCount, missing=$handoffOperatorInputValuesCheckMissingValueCount, unsafe=$handoffOperatorInputValuesCheckUnsafeValueCount, invalid=$handoffOperatorInputValuesCheckInvalidValueCount, valueReadyActions=$handoffOperatorInputValuesCheckValueReadyActionCount, nonReadyActions=$handoffOperatorInputValuesCheckNonReadyActionCount",
    "- Handoff operator input non-ready action orders: $handoffOperatorInputValuesCheckNonReadyActionOrdersText",
    "- Workflow run-id query mode: $($report.handoffWorkflowRunIdPlanQueryMode)",
    "- Workflow run-id GitHub API token present: $($report.handoffWorkflowRunIdPlanGithubApiTokenPresent)",
    "- Workflow run-id GitHub API unauthenticated: $($report.handoffWorkflowRunIdPlanGithubApiUnauthenticated)",
    "- Workflow run-id query executed: $($report.handoffWorkflowRunIdPlanQueryExecuted)",
    "- Workflow run-id query executed workflows: $($report.handoffWorkflowRunIdPlanQueryExecutedCount)",
    "- Workflow run-id queried workflows: $($report.handoffWorkflowRunIdPlanQueryWorkflowCount)",
    "- Workflow run-id query succeeded: $($report.handoffWorkflowRunIdPlanQuerySucceededCount)/$($report.handoffWorkflowRunIdPlanQueryWorkflowCount)",
    "- Workflow run-id query errors: $($report.handoffWorkflowRunIdPlanQueryErrorCount)",
    "- Workflow run-id candidate runs: $($report.handoffWorkflowRunIdPlanCandidateCount)",
    "- Missing workflow runs: $($report.missingWorkflowRunCount)",
    "- Handoff security finalizer run-id hints: $($report.handoffSecurityEvidenceFinalizerRunIdInputHintCount)",
    "- Missing required artifacts: $($report.missingRequiredArtifactCount)",
    "- Finalizer gaps: $($report.finalizerGapCount)",
    "",
    "## Recommended Commands",
    ""
)
$bottleneckDispatchUrls = @($currentBottleneck.dispatchUrls) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) }
if ($bottleneckDispatchUrls.Count -gt 0) {
    $statusIndex = [Array]::IndexOf($markdownLines, "## Status")
    if ($statusIndex -gt 0) {
        $dispatchLines = @("- Dispatch URLs:")
        foreach ($url in $bottleneckDispatchUrls) {
            $dispatchLines += "  - $url"
        }
        $markdownLines = @(
            $markdownLines[0..($statusIndex - 2)] +
            $dispatchLines +
            $markdownLines[($statusIndex - 1)..($markdownLines.Count - 1)]
        )
    }
}
if ($handoffRequiredGitHubSecretSummaries.Count -gt 0) {
    $markdownLines += @("", "## Handoff Required GitHub Secrets", "")
    foreach ($summary in @($handoffRequiredGitHubSecretSummaries | Sort-Object { [string] $_.secretName })) {
        $actionText = if (@($summary.actionOrders).Count -gt 0) { @($summary.actionOrders) -join "," } else { "none" }
        $inputFreeText = if (@($summary.inputFreeBlockedActionOrders).Count -gt 0) { @($summary.inputFreeBlockedActionOrders) -join "," } else { "none" }
        $markdownLines += "- $($summary.secretName): actions=$actionText; inputFreeBlockedActions=$inputFreeText; actionCount=$($summary.actionCount); inputFreeBlockedCount=$($summary.inputFreeBlockedActionCount)"
    }
}
if ($handoffInputFreeBlockedActions.Count -gt 0) {
    $markdownLines += @("", "## Handoff Input-Free Blocked Actions", "")
    foreach ($action in @($handoffInputFreeBlockedActions | Sort-Object { [int] $_.actionOrder })) {
        $secretText = if (@($action.requiredSecrets).Count -gt 0) { @($action.requiredSecrets) -join "," } else { "none" }
        $reasonText = if (@($action.blockReasons).Count -gt 0) { @($action.blockReasons) -join "; " } else { "none" }
        $markdownLines += "- Action $($action.actionOrder): $($action.name); secrets=$secretText; operatorApproval=$($action.needsOperatorApprovalConfirmation); kubeconfig=$($action.needsKubeconfigSecretConfirmation); blockers=$reasonText; review=``$($action.reviewCommand)``; confirmedPlan=``$($action.confirmedPlanCommand)``"
    }
}
if ($handoffOperatorInputValuesCheckNonReadyActionSummaries.Count -gt 0) {
    $markdownLines += @("", "## Handoff Operator Input Non-Ready Actions", "")
    foreach ($action in @($handoffOperatorInputValuesCheckNonReadyActionSummaries | Sort-Object { [int] $_.actionOrder })) {
        $keyText = Join-TextListPreview @($action.nonReadyValueKeys)
        $markdownLines += "- Action $($action.actionOrder): $($action.actionName); status=$($action.status); values=$($action.valueCount); ready=$($action.readyValueCount); missing=$($action.missingValueCount); unsafe=$($action.unsafeValueCount); invalid=$($action.invalidValueCount); inputFree=$($action.inputFree); workflow=$($action.workflow); nonReadyValueKeys=$keyText"
    }
}
if ($recommendedCommands.Count -eq 0) {
    $markdownLines += "- None"
}
else {
    foreach ($command in $recommendedCommands) {
        $markdownLines += "- $($command.order). $($command.name): ``$($command.command)``"
        if (-not [string]::IsNullOrWhiteSpace($command.reason)) {
            $markdownLines += "  - Reason: $($command.reason)"
        }
        if (-not [string]::IsNullOrWhiteSpace($command.note)) {
            $markdownLines += "  - Note: $($command.note)"
        }
        $commandDispatchUrls = @($command.dispatchUrls) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) }
        if ($commandDispatchUrls.Count -gt 0) {
            $markdownLines += "  - Dispatch URLs:"
            foreach ($url in $commandDispatchUrls) {
                $markdownLines += "    - $url"
            }
        }
    }
}
$markdownLines += ""
$markdownLines += "## Handoff Security Finalizer Run-id Hints"
$markdownLines += ""
if ($handoffSecurityEvidenceFinalizerRunIdInputHints.Count -eq 0) {
    $markdownLines += "- None"
}
else {
    foreach ($hint in $handoffSecurityEvidenceFinalizerRunIdInputHints) {
        $runIdParameter = Get-Text $hint "runIdParameter"
        if ([string]::IsNullOrWhiteSpace($runIdParameter)) { $runIdParameter = "RunId" }
        $workflowName = Get-Text $hint "workflow"
        if ([string]::IsNullOrWhiteSpace($workflowName)) { $workflowName = "workflow unknown" }
        $sourceState = if (Get-Bool $hint "sourceSelected") { "selected" } elseif (Get-Bool $hint "supplementalForSecurityFinalizer") { "supplemental" } else { "hint" }
        $markdownLines += "- ${runIdParameter}: workflow=$workflowName / source=$sourceState"
        $runsUrl = Get-Text $hint "runsUrl"
        if (-not [string]::IsNullOrWhiteSpace($runsUrl)) { $markdownLines += "  - Runs URL: $runsUrl" }
        $runListJsonPath = Get-Text $hint "runListJsonPath"
        if (-not [string]::IsNullOrWhiteSpace($runListJsonPath)) { $markdownLines += "  - Run-list JSON path: $runListJsonPath" }
    }
}
$markdownLines += ""
$markdownLines += "## Handoff Post Dispatch Commands"
$markdownLines += ""
if ($handoffPostDispatchCommands.Count -eq 0) {
    $markdownLines += "- None"
}
else {
    foreach ($command in $handoffPostDispatchCommands) {
        $markdownLines += "- $($command.name): ``$($command.command)``"
        if (-not [string]::IsNullOrWhiteSpace($command.note)) {
            $markdownLines += "  - Note: $($command.note)"
        }
    }
}
$markdownLines += ""
$markdownLines += "## Safety Policy"
$markdownLines += ""
$markdownLines += "- $($report.safetyPolicy)"

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    $markdownLines | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations readiness convergence JSON: $resolvedJsonOutputPath"
    Write-Host "Operations readiness convergence markdown: $resolvedMarkdownOutputPath"
}

$report | ConvertTo-Json -Depth 12
