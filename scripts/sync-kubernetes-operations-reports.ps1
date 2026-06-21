param(
    [string] $Namespace = "osmu",
    [string] $KubectlPath = "kubectl",
    [string] $ConfigMapName = "osmu-operations-reports",
    [string] $ReportPath = ".\.osmu-run\latest-operations-readiness-convergence.json",
    [string] $ConfigMapKey = "latest-operations-readiness-convergence.json",
    [string] $EvidencePath = ".\.osmu-run\latest-kubernetes-operations-report-sync.json",
    [string] $EvidenceConfigMapKey = "latest-kubernetes-operations-report-sync.json",
    [string] $DataFlowStoragePlanPath = ".\.osmu-run\latest-data-flow-storage-plan.json",
    [string] $DataFlowStoragePlanConfigMapKey = "latest-data-flow-storage-plan.json",
    [switch] $SkipEvidenceConfigMapPublish,
    [switch] $SkipDataFlowStoragePlanConfigMapPublish,
    [switch] $ServerDryRunOnly,
    [switch] $Apply,
    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$checks = @()
$failureCount = 0

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Format-Command([string[]] $Arguments) {
    $renderedArgs = $Arguments | ForEach-Object {
        if ($_ -match "\s") {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }
    return "$KubectlPath " + ($renderedArgs -join " ")
}

function Limit-Text([string] $Text) {
    if ($null -eq $Text) {
        return ""
    }
    if ($Text.Length -le 6000) {
        return $Text
    }
    return $Text.Substring(0, 6000) + "`n...truncated..."
}

function Add-Check(
    [string] $Name,
    [bool] $Passed,
    [string] $Summary,
    [string] $Command = "",
    [int] $ExitCode = 0,
    [string] $Output = ""
) {
    $script:checks += [pscustomobject]@{
        name = $Name
        passed = $Passed
        summary = $Summary
        command = $Command
        exitCode = $ExitCode
        output = (Limit-Text $Output)
    }
    if (-not $Passed) {
        $script:failureCount += 1
    }
}

function Invoke-KubectlRaw([string] $Name, [string[]] $Arguments) {
    $command = Format-Command $Arguments
    $outputLines = & $KubectlPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output = ($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    return [pscustomobject]@{
        name = $Name
        command = $command
        exitCode = $exitCode
        output = $output
    }
}

function Assert-KubernetesName([string] $Name, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name must not be empty."
    }
    if ($Value -notmatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" -or $Value.Length -gt 253) {
        throw "$Name must be a valid Kubernetes DNS label/name: $Value"
    }
}

function Assert-ConfigMapKey([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "ConfigMapKey must not be empty."
    }
    if ($Value -notmatch "^[A-Za-z0-9._-]+$") {
        throw "ConfigMapKey must contain only letters, numbers, dot, underscore, or dash: $Value"
    }
}

function Get-FileSha256([string] $PathValue) {
    return (Get-FileHash -LiteralPath $PathValue -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ObjectInt([object] $Value) {
    if ($null -eq $Value -or "$Value" -eq "") {
        return 0
    }
    try {
        return [int] $Value
    }
    catch {
        return 0
    }
}

Assert-KubernetesName "Namespace" $Namespace
Assert-KubernetesName "ConfigMapName" $ConfigMapName
Assert-ConfigMapKey $ConfigMapKey
Assert-ConfigMapKey $EvidenceConfigMapKey
Assert-ConfigMapKey $DataFlowStoragePlanConfigMapKey

$selectedModeCount = 0
foreach ($selectedMode in @($PlanOnly.IsPresent, $ServerDryRunOnly.IsPresent, $Apply.IsPresent)) {
    if ($selectedMode) {
        $selectedModeCount += 1
    }
}
if ($selectedModeCount -gt 1) {
    throw "Use only one mode: -PlanOnly, -ServerDryRunOnly, or -Apply."
}

$resolvedReportPath = Resolve-ProjectPath $ReportPath
$resolvedEvidencePath = Resolve-ProjectPath $EvidencePath
$resolvedDataFlowStoragePlanPath = Resolve-ProjectPath $DataFlowStoragePlanPath
$publishEvidenceToConfigMap = [bool](-not $SkipEvidenceConfigMapPublish)
$publishDataFlowStoragePlanToConfigMap = [bool](-not $SkipDataFlowStoragePlanConfigMapPublish -and (Test-Path -LiteralPath $resolvedDataFlowStoragePlanPath))

if (-not (Test-Path -LiteralPath $resolvedReportPath)) {
    Add-Check "report-file-exists" $false "Report file is missing: $resolvedReportPath"
}
else {
    Add-Check "report-file-exists" $true "Report file exists."
}

$reportJson = $null
if (Test-Path -LiteralPath $resolvedReportPath) {
    try {
        $reportJson = Get-Content -Raw -LiteralPath $resolvedReportPath | ConvertFrom-Json
        Add-Check "report-json-valid" $true "Report file is valid JSON."
    }
    catch {
        Add-Check "report-json-valid" $false "Report file is not valid JSON: $($_.Exception.Message)"
    }
}

$formatVersion = ""
$reportResult = ""
if ($null -ne $reportJson) {
    $formatVersion = [string] $reportJson.formatVersion
    $reportResult = [string] $reportJson.result
    Add-Check `
        "report-format-version" `
        ($formatVersion -eq "osmu.operations-readiness-convergence.v1") `
        "formatVersion=$formatVersion"
}

$reportBytes = if (Test-Path -LiteralPath $resolvedReportPath) {
    (Get-Item -LiteralPath $resolvedReportPath).Length
}
else {
    0
}
$reportSha256 = if (Test-Path -LiteralPath $resolvedReportPath) {
    Get-FileSha256 $resolvedReportPath
}
else {
    ""
}

$dataFlowStoragePlanFormatVersion = ""
$dataFlowStoragePlanResult = ""
$dataFlowStoragePlanCandidateStore = ""
$dataFlowQueryPlanEvidencePresent = $false
$dataFlowQueryPlanEvidenceProvided = $false
$dataFlowQueryPlanEvidenceResult = ""
$dataFlowQueryPlanEvidenceFailedCount = 0
$dataFlowQueryPlanEvidenceExpectedFormatVersion = ""
$dataFlowQueryPlanEvidenceFormatVersion = ""
if ($SkipDataFlowStoragePlanConfigMapPublish) {
    Add-Check "data-flow-storage-plan-publish-skipped" $true "Data-flow storage plan ConfigMap publish skipped by parameter."
}
elseif (-not (Test-Path -LiteralPath $resolvedDataFlowStoragePlanPath)) {
    Add-Check "data-flow-storage-plan-optional" $true "Optional data-flow storage plan file is missing; ConfigMap will not include it."
}
else {
    Add-Check "data-flow-storage-plan-file-exists" $true "Data-flow storage plan file exists."
    try {
        $dataFlowStoragePlanJson = Get-Content -Raw -LiteralPath $resolvedDataFlowStoragePlanPath | ConvertFrom-Json
        $dataFlowStoragePlanFormatVersion = [string] $dataFlowStoragePlanJson.formatVersion
        $dataFlowStoragePlanResult = [string] $dataFlowStoragePlanJson.result
        $dataFlowStoragePlanCandidateStore = [string] $dataFlowStoragePlanJson.candidateStore
        $queryPlanEvidence = $dataFlowStoragePlanJson.queryPlanEvidence
        $dataFlowQueryPlanEvidencePresent = $null -ne $queryPlanEvidence
        if ($dataFlowQueryPlanEvidencePresent) {
            $dataFlowQueryPlanEvidenceProvided = [bool] $queryPlanEvidence.provided
            $dataFlowQueryPlanEvidenceResult = [string] $queryPlanEvidence.result
            $dataFlowQueryPlanEvidenceFailedCount = Get-ObjectInt $queryPlanEvidence.failedCount
            $dataFlowQueryPlanEvidenceExpectedFormatVersion = [string] $queryPlanEvidence.expectedFormatVersion
            $dataFlowQueryPlanEvidenceFormatVersion = [string] $queryPlanEvidence.formatVersion
        }
        $dataFlowQueryPlanEvidenceRequired = @("MARIADB_PARTITION", "DUAL_WRITE") -contains $dataFlowStoragePlanCandidateStore
        Add-Check "data-flow-storage-plan-json-valid" $true "Data-flow storage plan file is valid JSON."
        Add-Check `
            "data-flow-storage-plan-format-version" `
            ($dataFlowStoragePlanFormatVersion -eq "osmu.data-flow-storage-plan.v1") `
            "formatVersion=$dataFlowStoragePlanFormatVersion"
        if ($dataFlowQueryPlanEvidenceRequired) {
            Add-Check `
                "data-flow-query-plan-evidence-summary-present" `
                $dataFlowQueryPlanEvidencePresent `
                "candidateStore=$dataFlowStoragePlanCandidateStore requires queryPlanEvidence summary before ConfigMap publish."
        }
        if ($dataFlowQueryPlanEvidencePresent) {
            Add-Check `
                "data-flow-query-plan-evidence-format-contract" `
                ($dataFlowQueryPlanEvidenceExpectedFormatVersion -eq "osmu.mariadb-query-plan-evidence.v1") `
                "queryPlanEvidence expectedFormatVersion=$dataFlowQueryPlanEvidenceExpectedFormatVersion."
        }
    }
    catch {
        Add-Check "data-flow-storage-plan-json-valid" $false "Data-flow storage plan file is not valid JSON: $($_.Exception.Message)"
    }
}

$dataFlowStoragePlanBytes = if ($publishDataFlowStoragePlanToConfigMap) {
    (Get-Item -LiteralPath $resolvedDataFlowStoragePlanPath).Length
}
else {
    0
}
$dataFlowStoragePlanSha256 = if ($publishDataFlowStoragePlanToConfigMap) {
    Get-FileSha256 $resolvedDataFlowStoragePlanPath
}
else {
    ""
}

function New-CreateConfigMapArguments([bool] $IncludeEvidence, [string] $DryRunMode) {
    $arguments = @(
        "-n", $Namespace,
        "create", "configmap", $ConfigMapName,
        "--from-file=$ConfigMapKey=$resolvedReportPath"
    )
    if ($publishDataFlowStoragePlanToConfigMap) {
        $arguments += "--from-file=$DataFlowStoragePlanConfigMapKey=$resolvedDataFlowStoragePlanPath"
    }
    if ($IncludeEvidence) {
        $arguments += "--from-file=$EvidenceConfigMapKey=$resolvedEvidencePath"
    }
    $arguments += @(
        "--dry-run=$DryRunMode",
        "-o", "yaml"
    )
    return $arguments
}

$createClientArguments = New-CreateConfigMapArguments $false "client"
$serverDryRunArguments = New-CreateConfigMapArguments $false "server"
$publishEvidenceClientArguments = New-CreateConfigMapArguments $true "client"

$clientDryRunCommand = Format-Command $createClientArguments
$serverDryRunCommand = Format-Command $serverDryRunArguments
$applyCommand = "$clientDryRunCommand | $KubectlPath apply -f -"
$publishEvidenceClientDryRunCommand = Format-Command $publishEvidenceClientArguments
$publishEvidenceApplyCommand = "$publishEvidenceClientDryRunCommand | $KubectlPath apply -f -"

$result = "planned"
$serverDryRunOutput = ""
$applyOutput = ""
$publishEvidenceApplyOutput = ""

function New-ReportObject([string] $ResultValue) {
    return [ordered]@{
        formatVersion = "osmu.kubernetes-operations-report-sync.v1"
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        result = $ResultValue
        namespace = $Namespace
        configMapName = $ConfigMapName
        configMapKey = $ConfigMapKey
        evidenceConfigMapKey = $EvidenceConfigMapKey
        dataFlowStoragePlanConfigMapKey = $DataFlowStoragePlanConfigMapKey
        publishEvidenceToConfigMap = [bool] $publishEvidenceToConfigMap
        publishDataFlowStoragePlanToConfigMap = [bool] $publishDataFlowStoragePlanToConfigMap
        sourceReportPath = $resolvedReportPath
        sourceReportFormatVersion = $formatVersion
        sourceReportResult = $reportResult
        sourceReportBytes = $reportBytes
        sourceReportSha256 = $reportSha256
        dataFlowStoragePlanPath = $resolvedDataFlowStoragePlanPath
        dataFlowStoragePlanFormatVersion = $dataFlowStoragePlanFormatVersion
        dataFlowStoragePlanResult = $dataFlowStoragePlanResult
        dataFlowStoragePlanCandidateStore = $dataFlowStoragePlanCandidateStore
        dataFlowStoragePlanBytes = $dataFlowStoragePlanBytes
        dataFlowStoragePlanSha256 = $dataFlowStoragePlanSha256
        dataFlowQueryPlanEvidencePresent = [bool] $dataFlowQueryPlanEvidencePresent
        dataFlowQueryPlanEvidenceProvided = [bool] $dataFlowQueryPlanEvidenceProvided
        dataFlowQueryPlanEvidenceResult = $dataFlowQueryPlanEvidenceResult
        dataFlowQueryPlanEvidenceFailedCount = $dataFlowQueryPlanEvidenceFailedCount
        dataFlowQueryPlanEvidenceExpectedFormatVersion = $dataFlowQueryPlanEvidenceExpectedFormatVersion
        dataFlowQueryPlanEvidenceFormatVersion = $dataFlowQueryPlanEvidenceFormatVersion
        clientDryRunCommand = $clientDryRunCommand
        serverDryRunCommand = $serverDryRunCommand
        applyCommand = $applyCommand
        publishEvidenceClientDryRunCommand = $publishEvidenceClientDryRunCommand
        publishEvidenceApplyCommand = $publishEvidenceApplyCommand
        serverDryRunOutput = (Limit-Text $serverDryRunOutput)
        applyOutput = (Limit-Text $applyOutput)
        publishEvidenceApplyOutput = (Limit-Text $publishEvidenceApplyOutput)
        checkCount = @($checks).Count
        failedCount = $failureCount
        checks = $checks
        safetyPolicy = "This script writes to Kubernetes only when -Apply is supplied. -ServerDryRunOnly talks to the API server without persisting changes. The default and -PlanOnly modes do not execute kubectl. When present, the data-flow storage plan is included in the same ConfigMap so dashboard readiness can expose target analytics-storage planning evidence. After a successful apply, the sync evidence file is also published into the same ConfigMap unless -SkipEvidenceConfigMapPublish is supplied."
    }
}

if ($failureCount -eq 0 -and $ServerDryRunOnly) {
    $serverDryRun = Invoke-KubectlRaw "server-dry-run-configmap" $serverDryRunArguments
    $serverDryRunOutput = $serverDryRun.output
    Add-Check `
        "server-dry-run-configmap" `
        ($serverDryRun.exitCode -eq 0) `
        "Server-side dry-run validates ConfigMap create/update shape without writing." `
        $serverDryRun.command `
        $serverDryRun.exitCode `
        $serverDryRun.output
    $result = if ($failureCount -eq 0) { "server-dry-run-passed" } else { "failed" }
}
elseif ($failureCount -eq 0 -and $Apply) {
    $clientDryRun = Invoke-KubectlRaw "render-configmap" $createClientArguments
    Add-Check `
        "render-configmap" `
        ($clientDryRun.exitCode -eq 0) `
        "Rendered ConfigMap manifest from the local report file." `
        $clientDryRun.command `
        $clientDryRun.exitCode `
        $clientDryRun.output

    if ($clientDryRun.exitCode -eq 0) {
        $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "osmu"
        New-Item -ItemType Directory -Force -Path $tempDirectory | Out-Null
        $tempManifest = Join-Path $tempDirectory ("operations-reports-configmap-{0}.yaml" -f ([Guid]::NewGuid().ToString("N")))
        try {
            $clientDryRun.output | Set-Content -LiteralPath $tempManifest -Encoding UTF8
            $applyResult = Invoke-KubectlRaw "apply-configmap" @("apply", "-f", $tempManifest)
            $applyOutput = $applyResult.output
            Add-Check `
                "apply-configmap" `
                ($applyResult.exitCode -eq 0) `
                "Applied operations report ConfigMap." `
                $applyResult.command `
                $applyResult.exitCode `
                $applyResult.output
        }
        finally {
            if (Test-Path -LiteralPath $tempManifest) {
                Remove-Item -LiteralPath $tempManifest -Force
            }
        }
    }

    if ($failureCount -eq 0 -and $publishEvidenceToConfigMap) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedEvidencePath) | Out-Null
        $preliminaryReport = New-ReportObject "applied"
        $preliminaryReport | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

        $publishRender = Invoke-KubectlRaw "render-configmap-with-sync-evidence" $publishEvidenceClientArguments
        Add-Check `
            "render-configmap-with-sync-evidence" `
            ($publishRender.exitCode -eq 0) `
            "Rendered ConfigMap manifest with convergence report and sync evidence." `
            $publishRender.command `
            $publishRender.exitCode `
            $publishRender.output

        if ($publishRender.exitCode -eq 0) {
            $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "osmu"
            New-Item -ItemType Directory -Force -Path $tempDirectory | Out-Null
            $tempManifest = Join-Path $tempDirectory ("operations-reports-configmap-with-evidence-{0}.yaml" -f ([Guid]::NewGuid().ToString("N")))
            try {
                $publishRender.output | Set-Content -LiteralPath $tempManifest -Encoding UTF8
                $publishApply = Invoke-KubectlRaw "apply-configmap-with-sync-evidence" @("apply", "-f", $tempManifest)
                $publishEvidenceApplyOutput = $publishApply.output
                Add-Check `
                    "apply-configmap-with-sync-evidence" `
                    ($publishApply.exitCode -eq 0) `
                    "Applied operations report ConfigMap with sync evidence for dashboard visibility." `
                    $publishApply.command `
                    $publishApply.exitCode `
                    $publishApply.output
            }
            finally {
                if (Test-Path -LiteralPath $tempManifest) {
                    Remove-Item -LiteralPath $tempManifest -Force
                }
            }
        }
    }
    $result = if ($failureCount -eq 0) { "applied" } else { "failed" }
}
elseif ($failureCount -gt 0) {
    $result = "failed"
}
else {
    $result = "planned"
}

if ($PlanOnly) {
    $result = if ($failureCount -eq 0) { "planned" } else { "failed" }
}

$report = New-ReportObject $result

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedEvidencePath) | Out-Null
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

Write-Host "Kubernetes operations report sync evidence: $resolvedEvidencePath"
Write-Host "Result: $result"
if ($result -eq "planned") {
    Write-Host "Server dry-run command: $serverDryRunCommand"
    Write-Host "Apply command: $applyCommand"
    Write-Host "Publish evidence command: $publishEvidenceApplyCommand"
}

$report | ConvertTo-Json -Depth 12

if ($failureCount -gt 0) {
    exit 1
}
