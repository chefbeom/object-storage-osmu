param()

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$selfTestRoot = Join-Path $root ".osmu-run\operations-workflow-run-id-plan-self-test"
$runListDirectory = Join-Path $selfTestRoot "run-lists"
$invocationPath = Join-Path $selfTestRoot "fixture-operations-evidence-plan-invocation.json"
$planOnlyJsonPath = Join-Path $selfTestRoot "plan-only-operations-workflow-run-ids.json"
$planOnlyMarkdownPath = Join-Path $selfTestRoot "plan-only-operations-workflow-run-ids.md"
$readyJsonPath = Join-Path $selfTestRoot "ready-operations-workflow-run-ids.json"
$readyMarkdownPath = Join-Path $selfTestRoot "ready-operations-workflow-run-ids.md"

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -ne $Expected) {
        throw "$Message. Expected '$Expected' but got '$Actual'."
    }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Message) {
    if (-not $Text.Contains($Expected)) {
        throw "$Message. Missing '$Expected'."
    }
}

function Write-RunListFixture([string] $Workflow, [int] $RunId, [string] $Sha) {
    $runs = @(
        [ordered]@{
            databaseId = $RunId
            workflowName = $Workflow
            status = "completed"
            conclusion = "success"
            createdAt = "2026-06-16T00:00:00Z"
            headSha = $Sha
            url = "https://github.example/osmu/actions/runs/$RunId"
            displayTitle = "Operations evidence"
        }
    )
    $runs | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runListDirectory "$Workflow.json") -Encoding UTF8
}

New-Item -ItemType Directory -Force -Path $selfTestRoot | Out-Null
New-Item -ItemType Directory -Force -Path $runListDirectory | Out-Null

@"
{
  "formatVersion": "osmu.operations-evidence-plan-invocation.v1",
  "result": "planned",
  "sourceSummary": "passed=36 pending=6",
  "selectedActionCount": 8,
  "plannedCount": 8,
  "blockedCount": 0,
  "executedCount": 0,
  "failedCount": 0,
  "actions": [
    {
      "order": 1,
      "name": "Storage expansion finalizer live evidence",
      "category": "storage-expansion",
      "command": "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true"
    },
    {
      "order": 2,
      "name": "Kubernetes HA/DR readiness live evidence",
      "category": "ha-dr",
      "command": "gh workflow run kubernetes-ha-dr-readiness-ci.yml -f run_live=true"
    },
    {
      "order": 3,
      "name": "Kubernetes DR finalizer live evidence",
      "category": "ha-dr",
      "command": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true"
    },
    {
      "order": 4,
      "name": "Signed image evidence",
      "category": "security-hardening",
      "command": "gh workflow run image-publish-sign-ci.yml -f version=v0.1.0-rc.1 -f publish=true"
    },
    {
      "order": 5,
      "name": "Container scan/SBOM evidence",
      "category": "security-hardening",
      "command": "gh workflow run container-security-ci.yml"
    },
    {
      "order": 6,
      "name": "Security evidence finalizer report",
      "category": "security-hardening",
      "command": "gh workflow run security-evidence-finalizer-ci.yml -f fail_if_not_passed=true"
    },
    {
      "order": 7,
      "name": "Enterprise auth target smoke evidence",
      "category": "enterprise-auth",
      "command": "gh workflow run enterprise-auth-smoke-ci.yml -f run_live=true -f require_oidc=true -f require_ldap=true"
    },
    {
      "order": 8,
      "name": "Kubernetes operations report sync evidence",
      "category": "operations",
      "command": "gh workflow run kubernetes-operations-report-sync-ci.yml -f run_live=true -f apply=true"
    }
  ]
}
"@ | Set-Content -LiteralPath $invocationPath -Encoding UTF8

$sha = "abc123abc123abc123abc123abc123abc123abcd"
Write-RunListFixture "storage-expansion-finalizer-ci.yml" 101 $sha
Write-RunListFixture "kubernetes-ha-dr-readiness-ci.yml" 102 $sha
Write-RunListFixture "kubernetes-dr-finalizer-ci.yml" 103 $sha
Write-RunListFixture "image-publish-sign-ci.yml" 104 $sha
Write-RunListFixture "container-security-ci.yml" 105 $sha
Write-RunListFixture "security-evidence-finalizer-ci.yml" 106 $sha
Write-RunListFixture "enterprise-auth-smoke-ci.yml" 107 $sha
Write-RunListFixture "kubernetes-operations-report-sync-ci.yml" 108 $sha

& (Join-Path $PSScriptRoot "write-operations-workflow-run-id-plan.ps1") `
    -InvocationReportPath $invocationPath `
    -JsonOutputPath $planOnlyJsonPath `
    -MarkdownOutputPath $planOnlyMarkdownPath `
    -Branch main `
    -ImageSigningVersion "v0.1.0-rc.1" | Out-Null

$planOnly = Get-Content -Raw -LiteralPath $planOnlyJsonPath | ConvertFrom-Json
$planOnlyMarkdown = Get-Content -Raw -LiteralPath $planOnlyMarkdownPath
Assert-Equal $planOnly.formatVersion "osmu.operations-workflow-run-id-plan.v1" "plan-only formatVersion"
Assert-Equal $planOnly.result "query-required" "plan-only result"
Assert-Equal $planOnly.workflowCount 8 "plan-only workflow count"
Assert-Equal $planOnly.missingWorkflowCount 8 "plan-only missing workflow count"
Assert-Contains $planOnly.workflows[0].queryCommand "gh run list --workflow storage-expansion-finalizer-ci.yml" "plan-only query command"
Assert-Contains $planOnly.workflows[0].artifactName "storage-expansion-finalizer-<run-id>" "plan-only artifact placeholder"
Assert-Contains $planOnlyMarkdown "Artifact collection plan" "plan-only markdown command section"

& (Join-Path $PSScriptRoot "write-operations-workflow-run-id-plan.ps1") `
    -InvocationReportPath $invocationPath `
    -JsonOutputPath $readyJsonPath `
    -MarkdownOutputPath $readyMarkdownPath `
    -RunListJsonDirectory $runListDirectory `
    -Branch main `
    -ImageSigningVersion "v0.1.0-rc.1" | Out-Null

$ready = Get-Content -Raw -LiteralPath $readyJsonPath | ConvertFrom-Json
$readyMarkdown = Get-Content -Raw -LiteralPath $readyMarkdownPath
Assert-Equal $ready.result "ready" "ready result"
Assert-Equal $ready.readyWorkflowCount 8 "ready workflow count"
Assert-Equal $ready.missingWorkflowCount 0 "ready missing workflow count"
Assert-Equal $ready.commitSha $sha "ready commit sha from run headSha"
Assert-Contains $ready.artifactCollectionPlanCommand "-StorageExpansionRunId 101" "storage expansion run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-HaDrReadinessRunId 102" "HA/DR run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-KubernetesDrRunId 103" "Kubernetes DR run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-ImageSigningRunId 104" "image signing run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-ContainerSecurityRunId 105" "container security run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-SecurityEvidenceRunId 106" "security evidence run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-EnterpriseAuthRunId 107" "enterprise auth run id argument"
Assert-Contains $ready.artifactCollectionPlanCommand "-KubernetesOperationsReportSyncRunId 108" "Kubernetes operations report sync run id argument"
Assert-Contains $ready.securityEvidenceFinalizerCommand "image_signing_run_id=104" "security finalizer image signing run id"
Assert-Contains $ready.securityEvidenceFinalizerCommand "container_security_run_id=105" "security finalizer container security run id"
Assert-Contains $ready.securityEvidenceFinalizerCommand "osmu-image-signing-v0.1.0-rc.1-$sha" "security finalizer image artifact"
Assert-Contains $ready.securityEvidenceFinalizerCommand "osmu-container-security-$sha" "security finalizer container artifact"
Assert-Contains $ready.workflows[0].artifactName "storage-expansion-finalizer-101" "ready storage artifact name"
Assert-Contains $readyMarkdown "enterprise-auth-smoke-107" "ready markdown enterprise auth artifact"
Assert-Contains $readyMarkdown "kubernetes-operations-report-sync-108" "ready markdown Kubernetes operations report sync artifact"
Assert-Contains $readyMarkdown "Recommended run id: 106" "ready markdown security evidence run id"

Write-Host "Operations workflow run id plan verified."
Write-Host "Plan-only report: $planOnlyJsonPath"
Write-Host "Ready report: $readyJsonPath"
