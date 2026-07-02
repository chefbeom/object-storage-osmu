param(
    [switch] $SkipDocker,
    [switch] $SkipBackend,
    [switch] $SkipFrontend,
    [string] $JavaHome = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "java-toolchain.ps1")
. (Join-Path $PSScriptRoot "docker-toolchain.ps1")

function Resolve-VerifyLocalPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    $resolvedPath = Resolve-VerifyLocalPath $PathValue
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8)
}

function Invoke-PowerShellScriptParseCheck() {
    Get-ChildItem (Join-Path $root "scripts") -Filter *.ps1 | ForEach-Object {
        [scriptblock]::Create((Read-Utf8Text $_.FullName)) | Out-Null
    }
}
function Step($message) {
    Write-Host ""
    Write-Host "==> $message"
}

function Run($command, $workingDirectory = $root) {
    Write-Host "    $command"
    Push-Location $workingDirectory
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $global:LASTEXITCODE = 0
        $output = Invoke-Expression "$command 2>&1"
        $exitCode = $LASTEXITCODE
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -ne 0) {
            throw "Command failed with exit code $exitCode`: $command"
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Pop-Location
    }
}
function Run-GitDiffCheck() {
    $command = "git diff --check"
    Write-Host "    $command"
    Push-Location $root
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $global:LASTEXITCODE = 0
        $output = & git diff --check 2>&1
        $exitCode = $LASTEXITCODE
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -ne 0) {
            throw "Command failed with exit code $exitCode`: $command"
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Pop-Location
    }
}

function Get-JsonFile($path) {
    $resolvedPath = Resolve-VerifyLocalPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return $null
    }
    try {
        return Read-Utf8Text $resolvedPath | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-JsonPropertyValue($object, [string] $name) {
    if ($null -eq $object) {
        return $null
    }
    $property = $object.PSObject.Properties[$name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Quote-RunArgument([string] $value) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }
    return "'" + ($value -replace "'", "''") + "'"
}

function New-RunArgument([string] $name, [string] $value) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }
    return " -$name $(Quote-RunArgument $value)"
}

function Get-OperationsSelectedActionOrders() {
    $candidateReports = @(
        @{ Path = ".osmu-run\latest-operations-evidence-plan-invocation.json"; Fields = @("selectedActionOrders") },
        @{ Path = ".osmu-run\latest-operations-dispatch-preflight.json"; Fields = @("selectedActionOrders", "readyActionOrders") },
        @{ Path = ".osmu-run\latest-operations-workflow-run-ids.json"; Fields = @("selectedActionOrders", "sourceActionOrders") },
        @{ Path = ".osmu-run\latest-operations-artifact-collection-plan.json"; Fields = @("selectedActionOrders", "sourceActionOrders") },
        @{ Path = ".osmu-run\latest-operations-evidence-handoff.json"; Fields = @("invocationSelectedActionOrders", "dispatchPreflightSelectedActionOrders", "workflowRunIdPlanActionOrders", "artifactCollectionActionOrders") }
    )

    foreach ($candidate in $candidateReports) {
        $report = Get-JsonFile $candidate.Path
        if ($null -eq $report) {
            continue
        }
        foreach ($field in $candidate.Fields) {
            $values = @(Get-JsonPropertyValue $report $field)
            $orders = @(
                $values |
                    Where-Object { $null -ne $_ -and "$($_)".Trim() -match '^\d+$' } |
                    ForEach-Object { [int] $_ } |
                    Sort-Object -Unique
            )
            if (@($orders).Count -gt 0) {
                return $orders
            }
        }
    }

    return @()
}

function New-ActionOrderArgument([int[]] $orders) {
    if (@($orders).Count -eq 0) {
        return ""
    }
    return " -ActionOrder $($orders -join ',')"
}
function Get-OperationsIntProperty($object, [string] $name) {
    $value = Get-JsonPropertyValue $object $name
    if ($null -eq $value) {
        return 0
    }
    try {
        return [int] $value
    }
    catch {
        throw "Operations latest evidence field $name is not an integer: $value"
    }
}

function Get-OperationsBoolProperty($object, [string] $name) {
    $value = Get-JsonPropertyValue $object $name
    if ($null -eq $value) {
        return $false
    }
    try {
        return [System.Convert]::ToBoolean($value)
    }
    catch {
        throw "Operations latest evidence field $name is not a boolean: $value"
    }
}

function Convert-OperationsTimestamp([string] $value, [string] $label) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Operations latest evidence $label timestamp is missing."
    }
    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($value, [ref] $parsed)) {
        throw "Operations latest evidence $label timestamp is invalid: $value"
    }
    return $parsed
}

function Get-OperationsIntArray($object, [string] $name) {
    $values = @(Get-JsonPropertyValue $object $name)
    return @(
        $values |
            Where-Object { $null -ne $_ -and "$($_)".Trim() -match '^\d+$' } |
            ForEach-Object { [int] $_ } |
            Sort-Object -Unique
    )
}

function Assert-OperationsIntArrayEqual([int[]] $expected, [int[]] $actual, [string] $label) {
    $expectedValues = @($expected | Sort-Object -Unique)
    $actualValues = @($actual | Sort-Object -Unique)
    $expectedText = if (@($expectedValues).Count -eq 0) { "" } else { $expectedValues -join "," }
    $actualText = if (@($actualValues).Count -eq 0) { "" } else { $actualValues -join "," }
    if ($expectedText -ne $actualText) {
        throw "Operations latest evidence selected action order mismatch for $label`: expected=[$expectedText] actual=[$actualText]"
    }
}

function Assert-OperationsSelectedActionScope([int[]] $expectedActionOrders, [object] $report, [string] $fieldName, [string] $label) {
    if (@($expectedActionOrders).Count -eq 0) {
        return
    }
    if ($null -eq $report) {
        throw "Operations latest evidence report missing while checking selected action scope: $label"
    }
    Assert-OperationsIntArrayEqual $expectedActionOrders (Get-OperationsIntArray $report $fieldName) $label
}

function Assert-OperationsLatestEvidenceFreshness([int[]] $expectedActionOrders) {
    $readiness = Get-JsonFile ".osmu-run\latest-operations-readiness.json"
    $invocation = Get-JsonFile ".osmu-run\latest-operations-evidence-plan-invocation.json"
    $dispatchPreflight = Get-JsonFile ".osmu-run\latest-operations-dispatch-preflight.json"
    $operatorWorksheet = Get-JsonFile ".osmu-run\latest-operations-operator-input-worksheet.json"
    $operatorValuesTemplate = Get-JsonFile ".osmu-run\latest-operations-operator-input-values-template.json"
    $operatorValuesCheck = Get-JsonFile ".osmu-run\latest-operations-operator-input-values-check.json"
    $workflowRunIds = Get-JsonFile ".osmu-run\latest-operations-workflow-run-ids.json"
    $artifactCollection = Get-JsonFile ".osmu-run\latest-operations-artifact-collection-plan.json"
    $handoff = Get-JsonFile ".osmu-run\latest-operations-evidence-handoff.json"
    $convergence = Get-JsonFile ".osmu-run\latest-operations-readiness-convergence.json"

    if ($null -eq $readiness -or $null -eq $operatorWorksheet -or $null -eq $operatorValuesTemplate -or $null -eq $operatorValuesCheck -or $null -eq $handoff -or $null -eq $convergence) {
        throw "Operations latest evidence refresh did not write readiness, operator input worksheet, operator input values template, operator input values check, handoff, and convergence reports."
    }

    $readinessTime = Convert-OperationsTimestamp ([string] (Get-JsonPropertyValue $readiness "generatedAt")) "readiness"
    $dispatchPreflightTime = Convert-OperationsTimestamp ([string] (Get-JsonPropertyValue $dispatchPreflight "generatedAt")) "dispatch preflight"
    $operatorWorksheetTime = Convert-OperationsTimestamp ([string] (Get-JsonPropertyValue $operatorWorksheet "generatedAt")) "operator input worksheet"
    $operatorValuesTemplateTime = Convert-OperationsTimestamp ([string] (Get-JsonPropertyValue $operatorValuesTemplate "generatedAt")) "operator input values template"
    $operatorValuesCheckTime = Convert-OperationsTimestamp ([string] (Get-JsonPropertyValue $operatorValuesCheck "generatedAt")) "operator input values check"
    $handoffTime = Convert-OperationsTimestamp ([string] (Get-JsonPropertyValue $handoff "generatedAt")) "handoff"
    $convergenceTime = Convert-OperationsTimestamp ([string] (Get-JsonPropertyValue $convergence "generatedAt")) "convergence"

    if ($operatorWorksheetTime -lt $dispatchPreflightTime) {
        throw "Operations latest evidence operator input worksheet is older than dispatch preflight after refresh: worksheet=$operatorWorksheetTime dispatch=$dispatchPreflightTime"
    }
    if ($operatorValuesTemplateTime -lt $operatorWorksheetTime) {
        throw "Operations latest evidence operator input values template is older than worksheet after refresh: valuesTemplate=$operatorValuesTemplateTime worksheet=$operatorWorksheetTime"
    }
    if ($operatorValuesCheckTime -lt $operatorValuesTemplateTime) {
        throw "Operations latest evidence operator input values check is older than values template after refresh: valuesCheck=$operatorValuesCheckTime valuesTemplate=$operatorValuesTemplateTime"
    }
    if ($handoffTime -lt $readinessTime) {
        throw "Operations latest evidence handoff is older than readiness after refresh: handoff=$handoffTime readiness=$readinessTime"
    }
    if ($convergenceTime -lt $handoffTime) {
        throw "Operations latest evidence convergence is older than handoff after refresh: convergence=$convergenceTime handoff=$handoffTime"
    }

    $staleReportCount = Get-OperationsIntProperty $handoff "staleReportCount"
    if ($staleReportCount -ne 0) {
        throw "Operations latest evidence handoff still has staleReportCount=$staleReportCount after refresh."
    }
    if (Get-OperationsBoolProperty $convergence "handoffStale") {
        throw "Operations latest evidence convergence still has handoffStale=true after refresh."
    }

    $handoffNextStep = Get-JsonPropertyValue $handoff "nextStep"
    $handoffCurrentBottleneck = Get-JsonPropertyValue $handoff "currentBottleneck"
    $handoffNextStepCode = [string] (Get-JsonPropertyValue $handoffNextStep "code")
    $handoffCurrentBottleneckCode = [string] (Get-JsonPropertyValue $handoffCurrentBottleneck "code")
    if ([string]::IsNullOrWhiteSpace($handoffCurrentBottleneckCode)) {
        throw "Operations latest evidence handoff currentBottleneck.code is missing after refresh."
    }
    if ($handoffNextStepCode -ne $handoffCurrentBottleneckCode) {
        throw "Operations latest evidence handoff currentBottleneck mismatch: nextStep=$handoffNextStepCode currentBottleneck=$handoffCurrentBottleneckCode"
    }

    $readinessSummary = [string] (Get-JsonPropertyValue $readiness "summary")
    $worksheetSummary = [string] (Get-JsonPropertyValue $operatorWorksheet "sourceSummary")
    $convergenceSummary = [string] (Get-JsonPropertyValue $convergence "readinessSummary")
    if ($readinessSummary -ne $worksheetSummary) {
        throw "Operations latest evidence operator worksheet source summary mismatch: readiness=$readinessSummary worksheet=$worksheetSummary"
    }
    if ($readinessSummary -ne $convergenceSummary) {
        throw "Operations latest evidence convergence readiness summary mismatch: readiness=$readinessSummary convergence=$convergenceSummary"
    }
    $worksheetInputRowCount = Get-OperationsIntProperty $operatorWorksheet "inputRowCount"
    $worksheetInputValueTemplateCount = Get-OperationsIntProperty $operatorWorksheet "inputValueTemplateCount"
    $operatorValuesTemplateCount = Get-OperationsIntProperty $operatorValuesTemplate "valueCount"
    $operatorValuesCheckCount = Get-OperationsIntProperty $operatorValuesCheck "valueCount"
    if ($worksheetInputRowCount -ne $worksheetInputValueTemplateCount -or $worksheetInputRowCount -ne $operatorValuesTemplateCount -or $worksheetInputRowCount -ne $operatorValuesCheckCount) {
        throw "Operations latest evidence operator input values template/check count mismatch: inputRows=$worksheetInputRowCount worksheetTemplate=$worksheetInputValueTemplateCount valuesTemplate=$operatorValuesTemplateCount valuesCheck=$operatorValuesCheckCount"
    }
    if (@($expectedActionOrders).Count -gt 0) {
        $worksheetSelectedActionCount = Get-OperationsIntProperty $operatorWorksheet "selectedActionCount"
        if ($worksheetSelectedActionCount -ne @($expectedActionOrders).Count) {
            throw "Operations latest evidence operator worksheet selected action count mismatch: expected=$(@($expectedActionOrders).Count) actual=$worksheetSelectedActionCount"
        }
    }

    Assert-OperationsSelectedActionScope $expectedActionOrders $invocation "selectedActionOrders" "invocation.selectedActionOrders"
    Assert-OperationsSelectedActionScope $expectedActionOrders $dispatchPreflight "selectedActionOrders" "dispatchPreflight.selectedActionOrders"
    Assert-OperationsSelectedActionScope $expectedActionOrders $workflowRunIds "selectedActionOrders" "workflowRunIds.selectedActionOrders"
    Assert-OperationsSelectedActionScope $expectedActionOrders $artifactCollection "selectedActionOrders" "artifactCollection.selectedActionOrders"
    Assert-OperationsSelectedActionScope $expectedActionOrders $handoff "invocationSelectedActionOrders" "handoff.invocationSelectedActionOrders"
    Assert-OperationsSelectedActionScope $expectedActionOrders $handoff "dispatchPreflightSelectedActionOrders" "handoff.dispatchPreflightSelectedActionOrders"
    Assert-OperationsSelectedActionScope $expectedActionOrders $handoff "workflowRunIdPlanActionOrders" "handoff.workflowRunIdPlanActionOrders"
    Assert-OperationsSelectedActionScope $expectedActionOrders $handoff "artifactCollectionActionOrders" "handoff.artifactCollectionActionOrders"
}
function Normalize-ProcessPath() {
    $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")
    if (-not $processPath) {
        $processPath = (([Environment]::GetEnvironmentVariable("Path", "Machine")),
            ([Environment]::GetEnvironmentVariable("Path", "User")) |
            Where-Object { $_ }) -join ";"
    }
    [Environment]::SetEnvironmentVariable("PATH", $null, "Process")
    [Environment]::SetEnvironmentVariable("Path", $processPath, "Process")
}

function Use-JavaHome($path) {
    $script:ResolvedJavaHome = Use-OsmuJavaHome $path
}

function Assert-JavaAvailable() {
    Assert-OsmuJavaAvailable -RequiredVersion 17 | Out-Null
}

function Format-ProcessArgument([string] $value) {
    if ($value -match "\s") {
        return '"' + ($value -replace '"', '\"') + '"'
    }
    return $value
}

function Run-BackendGradleTests() {
    Push-Location (Join-Path $root "osmu-backend")
    try {
        $arguments = New-Object System.Collections.Generic.List[string]
        if (-not [string]::IsNullOrWhiteSpace($script:ResolvedJavaHome)) {
            $arguments.Add("-Dorg.gradle.java.installations.paths=$script:ResolvedJavaHome") | Out-Null
            $arguments.Add("-Dorg.gradle.java.installations.auto-detect=false") | Out-Null
            $arguments.Add("-Dorg.gradle.java.installations.auto-download=false") | Out-Null
        }
        $arguments.Add("test") | Out-Null
        $arguments.Add("--no-daemon") | Out-Null

        $displayArguments = @($arguments | ForEach-Object { Format-ProcessArgument $_ })
        Write-Host "    .\gradlew.bat $($displayArguments -join ' ')"
        & .\gradlew.bat @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE`: .\gradlew.bat $($displayArguments -join ' ')"
        }
    }
    finally {
        Pop-Location
    }
}

Use-JavaHome $JavaHome
Normalize-ProcessPath
Use-OsmuDockerConfig $root | Out-Null

Step "Git whitespace check"
Run-GitDiffCheck

Step "Env ignore check"
Run "git check-ignore -v .\infra\local\.env .\osmu-backend\.env .\osmu-frontend\.env"

Step "PowerShell script parse check"
Write-Host "    Invoke-PowerShellScriptParseCheck"
Invoke-PowerShellScriptParseCheck

Step "Encoding hygiene check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-doc-encoding-hygiene.ps1"

Step "Encoding hygiene self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-doc-encoding-hygiene-self-test.ps1"

Step "Project doc file reference check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-dev-doc-file-references.ps1"

Step "MVP release decision self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-decision.ps1"

Step "Durable MVP finalize PlanOnly self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-durable-mvp-finalize-plan.ps1"

Step "MVP completion handoff check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-completion.ps1"

Step "CI workflow draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-ci-workflow.ps1"

Step "Image signing policy draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-image-signing-policy.ps1"

Step "Security evidence writer check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-security-evidence-writers.ps1"

Step "Security evidence finalizer check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-security-evidence-finalizer.ps1"

Step "Commercial readiness draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-commercial-readiness.ps1"

Step "Development roadmap check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-development-roadmap.ps1"

Step "Prototype status check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-status.ps1"

Step "MVP release checklist check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-checklist.ps1"

Step "OpenAPI MVP contract check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-openapi-contract.ps1"

Step "Kubernetes manifest draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1"

Step "Helm chart draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-chart.ps1"

Step "Helm values hardening evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-values-hardening-evidence.ps1"

Step "Cluster network access review evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-cluster-network-access-review-evidence.ps1"

Step "Container hardening draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-container-hardening.ps1"

Step "TLS ingress draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-tls-ingress.ps1"

Step "Secret rotation policy draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-secret-rotation-policy.ps1"

Step "Secret rotation evidence writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-secret-rotation-evidence.ps1"

Step "Commercial integration evidence writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-commercial-integration-evidence.ps1"

Step "Commercial approval evidence writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-commercial-approval-evidence.ps1"

Step "Chargeback closeout evidence writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-chargeback-closeout-evidence.ps1"

Step "Operations handoff package writer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-handoff-package.ps1"

Step "Support escalation handoff evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-support-escalation-handoff-evidence.ps1"

Step "IAM/RBAC matrix check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-iam-rbac-matrix.ps1"

Step "IAM/RBAC finalizer check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\finalize-iam-rbac-readiness.ps1 -FailIfNotPassed"

Step "IAM/RBAC finalizer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-iam-rbac-finalizer.ps1"

Step "Kubernetes RBAC matrix check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-rbac-matrix.ps1"

Step "Storage Expansion RBAC auth plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-rbac-auth.ps1 -PlanOnly"

Step "Storage Expansion server dry-run plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-server-dry-run.ps1 -PlanOnly"

Step "Storage Expansion finalize plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -PlanOnly"

Step "Storage Expansion finalizer self-test"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-finalizer.ps1"

Step "Kubernetes HA/DR readiness plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-ha-dr-readiness.ps1 -PlanOnly"

Step "Kubernetes backup drill plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-backup-drill.ps1 -PlanOnly"

Step "Kubernetes restore namespace preparation plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\prepare-kubernetes-restore-namespace.ps1 -PlanOnly"

Step "Kubernetes backup artifact preflight plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-backup-artifacts.ps1 -PlanOnly"

Step "Kubernetes restore drill plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-restore-drill.ps1 -PlanOnly"

Step "Kubernetes DR drill orchestration plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -PlanOnly"

Step "Kubernetes DR bucket bootstrap plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-kubernetes-dr-bucket.ps1 -PlanOnly"

Step "Kubernetes DR bucket immutability plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-dr-bucket-immutability.ps1 -PlanOnly"

Step "Kubernetes backup artifact transfer plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\transfer-kubernetes-backup-artifacts.ps1 -PlanOnly"

Step "Kubernetes restore smoke plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-restore-smoke.ps1 -PlanOnly"

Step "Kubernetes DR evidence API request plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-kubernetes-dr-evidence-request.ps1 -PlanOnly"

Step "Kubernetes DR finalize plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -PlanOnly"

Step "Operations readiness artifact check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness.ps1"

Step "Operations evidence plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-evidence-plan.ps1"

Step "Operations evidence plan invocation check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-evidence-plan-invocation.ps1"

Step "Enterprise auth smoke plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-enterprise-auth-smoke-plan.ps1"

Step "Enterprise auth JIT rollback evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-enterprise-auth-jit-rollback-evidence.ps1"

Step "Operations invocation unblock plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-invocation-unblock-plan.ps1"

Step "Operations dispatch preflight check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-dispatch-preflight.ps1"

Step "Operations operator input worksheet check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-operator-input-worksheet.ps1"

Step "Operations operator input values check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-operator-input-values-check.ps1"

Step "Operations workflow run id plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-workflow-run-id-plan.ps1"

Step "Operations artifact collection plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-artifact-collection-plan.ps1"

Step "Operations readiness finalizer plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness-finalizer.ps1"

Step "Operations readiness artifact import check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness-artifact-import.ps1"

Step "Operations evidence handoff check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-evidence-handoff.ps1"

Step "Operations readiness convergence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness-convergence.ps1"

Step "Kubernetes operations report sync check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-sync.ps1"

Step "Kubernetes operations report sync live verifier check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-sync-live-self-test.ps1"

Step "Kubernetes operations report mount verifier check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-mount-self-test.ps1"

Step "Backup restore drill draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-backup-restore-drill.ps1"

Step "Prometheus observability draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-prometheus-observability.ps1"

Step "Monitoring artifacts draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-monitoring-artifacts.ps1"

Step "Monitoring threshold evidence writer check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-monitoring-threshold-evidence.ps1"

Step "Prometheus Operator draft check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-prometheus-operator-draft.ps1"

Step "Flyway migration version check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-migrations.ps1"

Step "Migration rollback plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-migration-rollback-plan.ps1"

Step "Metadata index coverage check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-metadata-index-coverage.ps1 -NoWrite"

Step "MariaDB query plan evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-mariadb-query-plan-evidence.ps1"

Step "Object list query pushdown check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-object-list-query-pushdown.ps1"

Step "Data-flow storage plan check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-data-flow-storage-plan.ps1"

Step "Data-flow query and retention budget evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-data-flow-query-retention-budget-evidence.ps1"

Step "Data-flow storage transition runbook evidence check"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\verify-data-flow-storage-transition-runbook-evidence.ps1"

Step "Operations latest evidence refresh"
$operationsSelectedActionOrders = @(Get-OperationsSelectedActionOrders)
$operationsActionOrderArgument = New-ActionOrderArgument $operationsSelectedActionOrders
$operationsRunIdContext = Get-JsonFile ".osmu-run\latest-operations-workflow-run-ids.json"
$operationsGitHubRepository = [string] (Get-JsonPropertyValue $operationsRunIdContext "githubRepository")
$operationsBranch = [string] (Get-JsonPropertyValue $operationsRunIdContext "branch")
$operationsImageSigningVersion = [string] (Get-JsonPropertyValue $operationsRunIdContext "imageSigningVersion")
$operationsGitHubRepositoryArgument = New-RunArgument "GitHubRepository" $operationsGitHubRepository
$operationsBranchArgument = New-RunArgument "Branch" $operationsBranch
$operationsImageSigningVersionArgument = New-RunArgument "ImageSigningVersion" $operationsImageSigningVersion
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-plan.ps1$operationsGitHubRepositoryArgument"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1$operationsActionOrderArgument"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-invocation-unblock-plan.ps1"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-dispatch-preflight.ps1$operationsActionOrderArgument -CheckGitHubCli$operationsGitHubRepositoryArgument"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-operator-input-worksheet.ps1"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-operator-input-values-check.ps1"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1$operationsBranchArgument$operationsGitHubRepositoryArgument$operationsImageSigningVersionArgument"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1$operationsImageSigningVersionArgument"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-handoff.ps1"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness-convergence.ps1"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\sync-kubernetes-operations-reports.ps1 -PlanOnly -SkipDataFlowQueryRetentionBudgetConfigMapPublish"
Run "powershell -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness-convergence.ps1"
Assert-OperationsLatestEvidenceFreshness $operationsSelectedActionOrders
if (-not $SkipDocker) {
    Step "Docker Compose config check"
    Run "docker compose --env-file .\infra\local\.env.example -f .\infra\local\docker-compose.yml config --quiet"
}

if (-not $SkipFrontend) {
    Step "Frontend static syntax check"
    Run "node --check .\osmu-frontend\src\services\api.js"
    Run "node --check .\osmu-frontend\vite.config.js"
    Run "node --check .\osmu-frontend\mock-api\server.mjs"

    Step "Frontend mock API self-test"
    Run "npm.cmd run mock:api:self-test" (Join-Path $root "osmu-frontend")

    Step "Frontend unit tests"
    Run "npm.cmd run test:unit" (Join-Path $root "osmu-frontend")

    Step "Frontend build"
    Run "npm.cmd run build" (Join-Path $root "osmu-frontend")
}

if (-not $SkipBackend) {
    Step "Backend Java preflight"
    Assert-JavaAvailable

    Step "Backend tests"
    Run-BackendGradleTests
}

Step "Done"
