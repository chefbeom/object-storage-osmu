param(
    [string] $BuildGradlePath = ".\osmu-backend\build.gradle",
    [string] $ApplicationYamlPath = ".\osmu-backend\src\main\resources\application.yaml",
    [string] $KubernetesBackendPath = ".\infra\k8s\backend.yaml",
    [string] $HelmValuesPath = ".\infra\helm\osmu\values.yaml",
    [string] $HelmBackendTemplatePath = ".\infra\helm\osmu\templates\backend.yaml"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
}
function Read-RequiredFile([string] $path, [string] $label) {
    $resolvedPath = Resolve-ProjectPath $path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "$label missing: $resolvedPath"
    }
    return [pscustomobject]@{
        Path = $resolvedPath
        Content = Read-Utf8Text $resolvedPath
    }
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    if (-not $content.Contains($expected)) {
        throw "$label does not contain expected text: $expected"
    }
}

$buildGradle = Read-RequiredFile $BuildGradlePath "Backend Gradle file"
$applicationYaml = Read-RequiredFile $ApplicationYamlPath "Backend application yaml"
$kubernetesBackend = Read-RequiredFile $KubernetesBackendPath "Kubernetes backend manifest"
$helmValues = Read-RequiredFile $HelmValuesPath "Helm values"
$helmBackend = Read-RequiredFile $HelmBackendTemplatePath "Helm backend template"

Assert-Contains $buildGradle.Content "micrometer-registry-prometheus" "Backend Gradle file"
Assert-Contains $applicationYaml.Content "health,info,metrics,prometheus" "Backend application yaml"

Assert-Contains $kubernetesBackend.Content 'prometheus.io/scrape: "true"' "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend.Content "prometheus.io/path: /actuator/prometheus" "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend.Content 'prometheus.io/port: "8080"' "Kubernetes backend manifest"

Assert-Contains $helmValues.Content "metrics:" "Helm values"
Assert-Contains $helmValues.Content "path: /actuator/prometheus" "Helm values"
Assert-Contains $helmValues.Content 'port: "8080"' "Helm values"
Assert-Contains $helmBackend.Content ".Values.backend.metrics.enabled" "Helm backend template"
Assert-Contains $helmBackend.Content "prometheus.io/scrape" "Helm backend template"
Assert-Contains $helmBackend.Content ".Values.backend.metrics.path" "Helm backend template"
Assert-Contains $helmBackend.Content ".Values.backend.metrics.port" "Helm backend template"

Write-Host "Prometheus observability draft verified."
Write-Host "Backend Gradle: $($buildGradle.Path)"
Write-Host "Application yaml: $($applicationYaml.Path)"
Write-Host "Kubernetes backend: $($kubernetesBackend.Path)"
Write-Host "Helm backend template: $($helmBackend.Path)"
