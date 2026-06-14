param(
    [string] $PolicyPath = ".\dev-docs\image-signing-policy.md",
    [string] $WorkflowPath = ".\.github\workflows\image-publish-sign-ci.yml"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-RequiredFile([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "$label missing: $resolvedPath"
    }
    return [pscustomobject]@{
        Path = $resolvedPath
        Content = Get-Content -Raw -LiteralPath $resolvedPath
    }
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    if (-not $content.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

function Assert-NotContains([string] $content, [string] $unexpected, [string] $label) {
    if ($content.Contains($unexpected)) {
        throw "$label must not contain text: $unexpected"
    }
}

$policy = Read-RequiredFile $PolicyPath "Image signing policy"
$policyContent = $policy.Content

Assert-Contains $policyContent "GitHub Container Registry" "Image signing policy"
Assert-Contains $policyContent "ghcr.io/<owner>/osmu-backend" "Image signing policy"
Assert-Contains $policyContent "ghcr.io/<owner>/osmu-frontend" "Image signing policy"
Assert-Contains $policyContent "Sigstore Cosign" "Image signing policy"
Assert-Contains $policyContent "keyless signing through GitHub Actions OIDC" "Image signing policy"
Assert-Contains $policyContent "contents: read" "Image signing policy"
Assert-Contains $policyContent "packages: write" "Image signing policy"
Assert-Contains $policyContent "id-token: write" "Image signing policy"
Assert-Contains $policyContent "Actual signed image evidence: pending successful GitHub-hosted workflow run." "Image signing policy"

$workflow = Read-RequiredFile $WorkflowPath "Image publish/sign workflow"
$workflowContent = $workflow.Content

if ($workflowContent.Contains("`t")) {
    throw "Tabs are not allowed in Image publish/sign workflow: $($workflow.Path)"
}

Assert-Contains $workflowContent "name: Image Publish and Sign CI" "Image publish/sign workflow"
Assert-Contains $workflowContent "workflow_dispatch:" "Image publish/sign workflow"
Assert-NotContains $workflowContent "pull_request:" "Image publish/sign workflow"
Assert-NotContains $workflowContent "push:" "Image publish/sign workflow"
Assert-Contains $workflowContent "contents: read" "Image publish/sign workflow"
Assert-Contains $workflowContent "packages: write" "Image publish/sign workflow"
Assert-Contains $workflowContent "id-token: write" "Image publish/sign workflow"
Assert-Contains $workflowContent "runs-on: ubuntu-latest" "Image publish/sign workflow"
Assert-Contains $workflowContent "timeout-minutes: 45" "Image publish/sign workflow"
Assert-Contains $workflowContent "REGISTRY: ghcr.io" "Image publish/sign workflow"
Assert-Contains $workflowContent "docker/setup-buildx-action@v3" "Image publish/sign workflow"
Assert-Contains $workflowContent "docker/login-action@v3" "Image publish/sign workflow"
Assert-Contains $workflowContent "sigstore/cosign-installer@v3" "Image publish/sign workflow"
Assert-Contains $workflowContent "docker build" "Image publish/sign workflow"
Assert-Contains $workflowContent "docker push" "Image publish/sign workflow"
Assert-Contains $workflowContent "cosign sign --yes" "Image publish/sign workflow"
Assert-Contains $workflowContent "cosign verify" "Image publish/sign workflow"
Assert-Contains $workflowContent "--certificate-oidc-issuer `"https://token.actions.githubusercontent.com`"" "Image publish/sign workflow"
Assert-Contains $workflowContent "if: inputs.publish == 'true'" "Image publish/sign workflow"

Write-Host "Image signing policy verified."
Write-Host "Policy: $($policy.Path)"
Write-Host "Workflow: $($workflow.Path)"
