param(
    [string] $PolicyPath = ".\dev-docs\secret-rotation-policy.md",
    [string] $DeploymentStrategyPath = ".\dev-docs\deployment-strategy.md",
    [string] $SecurityDesignPath = ".\dev-docs\security-design.md",
    [string] $HelmValuesPath = ".\infra\helm\osmu\values.yaml",
    [string] $KubernetesSecretExamplePath = ".\infra\k8s\secret.example.yaml",
    [string] $EvidenceWriterPath = ".\scripts\write-secret-rotation-evidence.ps1",
    [string] $EvidenceVerifierPath = ".\scripts\verify-secret-rotation-evidence.ps1"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Read-RequiredFile([string] $path, [string] $label) {
    $resolved = Resolve-ProjectPath $path
    Assert-True (Test-Path -LiteralPath $resolved) "$label not found: $resolved"
    $content = Get-Content -Raw -LiteralPath $resolved
    Assert-True (-not $content.Contains("`t")) "Tabs are not allowed in $label."
    return $content
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    Assert-True $content.Contains($expected) "$label does not contain expected text: $expected"
}

$policy = Read-RequiredFile $PolicyPath "Secret rotation policy"
Assert-Contains $policy "OSMU_ADMIN_PASSWORD" "Secret rotation policy"
Assert-Contains $policy "OSMU_JWT_SECRET" "Secret rotation policy"
Assert-Contains $policy "OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY" "Secret rotation policy"
Assert-Contains $policy "MARIADB_PASSWORD" "Secret rotation policy"
Assert-Contains $policy "MINIO_ROOT_PASSWORD" "Secret rotation policy"
Assert-Contains $policy "osmu-tls" "Secret rotation policy"
Assert-Contains $policy "Do not commit real secrets to git." "Secret rotation policy"
Assert-Contains $policy "Rotation Triggers" "Secret rotation policy"
Assert-Contains $policy "Rotation Runbook" "Secret rotation policy"
Assert-Contains $policy 'Changing `OSMU_JWT_SECRET` invalidates existing access and refresh tokens.' "Secret rotation policy"
Assert-Contains $policy 'Changing `OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY` prevents decrypting existing SigV4 secret material' "Secret rotation policy"
Assert-Contains $policy "Pilot readiness requires creating the TLS Secret and verifying HTTPS routing" "Secret rotation policy"
Assert-Contains $policy "write-secret-rotation-evidence.ps1" "Secret rotation policy"
Assert-Contains $policy "latest-secret-rotation-evidence.json" "Secret rotation policy"
Assert-Contains $policy "verify-secret-rotation-evidence.ps1" "Secret rotation policy"

$deploymentStrategy = Read-RequiredFile $DeploymentStrategyPath "Deployment strategy"
Assert-Contains $deploymentStrategy "secret-rotation-policy.md" "Deployment strategy"

$securityDesign = Read-RequiredFile $SecurityDesignPath "Security design"
Assert-Contains $securityDesign "Secret And Certificate Rotation Policy" "Security design"

$helmValues = Read-RequiredFile $HelmValuesPath "Helm values"
Assert-Contains $helmValues "secrets:" "Helm values"
Assert-Contains $helmValues "create: false" "Helm values"

$secretExample = Read-RequiredFile $KubernetesSecretExamplePath "Kubernetes secret example"
Assert-Contains $secretExample "kind: Secret" "Kubernetes secret example"
Assert-Contains $secretExample "change-me" "Kubernetes secret example"

$evidenceWriter = Read-RequiredFile $EvidenceWriterPath "Secret rotation evidence writer"
Assert-Contains $evidenceWriter "osmu.secret-rotation-evidence.v1" "Secret rotation evidence writer"
Assert-Contains $evidenceWriter "ConfirmNoSecretValues" "Secret rotation evidence writer"
Assert-Contains $evidenceWriter "does not contain password values" "Secret rotation evidence writer"

$evidenceVerifier = Read-RequiredFile $EvidenceVerifierPath "Secret rotation evidence verifier"
Assert-Contains $evidenceVerifier "write-secret-rotation-evidence.ps1" "Secret rotation evidence verifier"
Assert-Contains $evidenceVerifier "Secret-like evidence reference should be rejected." "Secret rotation evidence verifier"

Write-Host "Secret rotation policy draft verified."
Write-Host "Policy: $(Resolve-ProjectPath $PolicyPath)"
