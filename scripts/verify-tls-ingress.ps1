param(
    [string] $KubernetesIngressManifest = ".\infra\k8s\ingress.yaml",
    [string] $HelmValues = ".\infra\helm\osmu\values.yaml",
    [string] $HelmIngressTemplate = ".\infra\helm\osmu\templates\ingress.yaml"
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

$kubernetesIngress = Read-RequiredFile $KubernetesIngressManifest "Kubernetes ingress manifest"
Assert-Contains $kubernetesIngress "kind: Ingress" "Kubernetes ingress manifest"
Assert-Contains $kubernetesIngress "nginx.ingress.kubernetes.io/ssl-redirect: `"true`"" "Kubernetes ingress manifest"
Assert-Contains $kubernetesIngress "nginx.ingress.kubernetes.io/force-ssl-redirect: `"true`"" "Kubernetes ingress manifest"
Assert-Contains $kubernetesIngress "tls:" "Kubernetes ingress manifest"
Assert-Contains $kubernetesIngress "secretName: osmu-tls" "Kubernetes ingress manifest"
Assert-Contains $kubernetesIngress "host: osmu.local" "Kubernetes ingress manifest"

$helmValuesContent = Read-RequiredFile $HelmValues "Helm values"
Assert-Contains $helmValuesContent "ingress:" "Helm values"
Assert-Contains $helmValuesContent "nginx.ingress.kubernetes.io/ssl-redirect: `"true`"" "Helm values"
Assert-Contains $helmValuesContent "nginx.ingress.kubernetes.io/force-ssl-redirect: `"true`"" "Helm values"
Assert-Contains $helmValuesContent "tls:" "Helm values"
Assert-Contains $helmValuesContent "secretName: osmu-tls" "Helm values"
Assert-Contains $helmValuesContent "- osmu.local" "Helm values"

$helmIngress = Read-RequiredFile $HelmIngressTemplate "Helm ingress template"
Assert-Contains $helmIngress ".Values.ingress.annotations" "Helm ingress template"
Assert-Contains $helmIngress ".Values.ingress.tls" "Helm ingress template"
Assert-Contains $helmIngress ".Values.ingress.host" "Helm ingress template"

Write-Host "TLS ingress draft verified."
Write-Host "Kubernetes ingress: $(Resolve-ProjectPath $KubernetesIngressManifest)"
Write-Host "Helm ingress template: $(Resolve-ProjectPath $HelmIngressTemplate)"
