param(
    [string] $BackendDockerfile = ".\osmu-backend\Dockerfile",
    [string] $FrontendDockerfile = ".\osmu-frontend\Dockerfile",
    [string] $FrontendNginxConfig = ".\osmu-frontend\nginx.conf",
    [string] $KubernetesBackendManifest = ".\infra\k8s\backend.yaml",
    [string] $KubernetesFrontendManifest = ".\infra\k8s\frontend.yaml",
    [string] $HelmValues = ".\infra\helm\osmu\values.yaml",
    [string] $HelmBackendTemplate = ".\infra\helm\osmu\templates\backend.yaml",
    [string] $HelmFrontendTemplate = ".\infra\helm\osmu\templates\frontend.yaml"
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
    $content = [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
    Assert-True (-not $content.Contains("`t")) "Tabs are not allowed in $label."
    return $content
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    Assert-True $content.Contains($expected) "$label does not contain expected text: $expected"
}

$dockerfile = Read-RequiredFile $BackendDockerfile "Backend Dockerfile"
Assert-Contains $dockerfile "groupadd --system --gid 10001 osmu" "Backend Dockerfile"
Assert-Contains $dockerfile "useradd --system --uid 10001 --gid osmu" "Backend Dockerfile"
Assert-Contains $dockerfile "COPY --from=build --chown=osmu:osmu" "Backend Dockerfile"
Assert-Contains $dockerfile "ENV HOME=/home/osmu" "Backend Dockerfile"
Assert-Contains $dockerfile "USER 10001" "Backend Dockerfile"
Assert-Contains $dockerfile 'ENTRYPOINT ["java", "-jar", "/app/app.jar"]' "Backend Dockerfile"

$frontendDockerfileContent = Read-RequiredFile $FrontendDockerfile "Frontend Dockerfile"
Assert-Contains $frontendDockerfileContent "COPY nginx.conf /etc/nginx/nginx.conf" "Frontend Dockerfile"
Assert-Contains $frontendDockerfileContent "COPY --chown=nginx:nginx --from=build" "Frontend Dockerfile"
Assert-Contains $frontendDockerfileContent "chown -R nginx:nginx /tmp/nginx" "Frontend Dockerfile"
Assert-Contains $frontendDockerfileContent "USER 101:101" "Frontend Dockerfile"
Assert-Contains $frontendDockerfileContent "EXPOSE 8080" "Frontend Dockerfile"

$frontendNginx = Read-RequiredFile $FrontendNginxConfig "Frontend nginx config"
Assert-Contains $frontendNginx "pid /tmp/nginx.pid" "Frontend nginx config"
Assert-Contains $frontendNginx "listen 8080" "Frontend nginx config"
Assert-Contains $frontendNginx "client_body_temp_path /tmp/nginx/client_temp" "Frontend nginx config"

$kubernetesBackend = Read-RequiredFile $KubernetesBackendManifest "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend "runAsNonRoot: true" "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend "runAsUser: 10001" "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend "runAsGroup: 10001" "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend "fsGroup: 10001" "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend "type: RuntimeDefault" "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend "allowPrivilegeEscalation: false" "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend "capabilities:" "Kubernetes backend manifest"
Assert-Contains $kubernetesBackend "- ALL" "Kubernetes backend manifest"

$kubernetesFrontend = Read-RequiredFile $KubernetesFrontendManifest "Kubernetes frontend manifest"
Assert-Contains $kubernetesFrontend "runAsNonRoot: true" "Kubernetes frontend manifest"
Assert-Contains $kubernetesFrontend "runAsUser: 101" "Kubernetes frontend manifest"
Assert-Contains $kubernetesFrontend "runAsGroup: 101" "Kubernetes frontend manifest"
Assert-Contains $kubernetesFrontend "type: RuntimeDefault" "Kubernetes frontend manifest"
Assert-Contains $kubernetesFrontend "allowPrivilegeEscalation: false" "Kubernetes frontend manifest"
Assert-Contains $kubernetesFrontend "capabilities:" "Kubernetes frontend manifest"
Assert-Contains $kubernetesFrontend "- ALL" "Kubernetes frontend manifest"
Assert-Contains $kubernetesFrontend "containerPort: 8080" "Kubernetes frontend manifest"

$helmValuesContent = Read-RequiredFile $HelmValues "Helm values"
Assert-Contains $helmValuesContent "podSecurityContext:" "Helm values"
Assert-Contains $helmValuesContent "containerSecurityContext:" "Helm values"
Assert-Contains $helmValuesContent "runAsNonRoot: true" "Helm values"
Assert-Contains $helmValuesContent "runAsUser: 10001" "Helm values"
Assert-Contains $helmValuesContent "runAsUser: 101" "Helm values"
Assert-Contains $helmValuesContent "allowPrivilegeEscalation: false" "Helm values"

$helmBackend = Read-RequiredFile $HelmBackendTemplate "Helm backend template"
Assert-Contains $helmBackend ".Values.backend.podSecurityContext" "Helm backend template"
Assert-Contains $helmBackend ".Values.backend.containerSecurityContext" "Helm backend template"

$helmFrontend = Read-RequiredFile $HelmFrontendTemplate "Helm frontend template"
Assert-Contains $helmFrontend ".Values.frontend.podSecurityContext" "Helm frontend template"
Assert-Contains $helmFrontend ".Values.frontend.containerSecurityContext" "Helm frontend template"
Assert-Contains $helmFrontend "containerPort: 8080" "Helm frontend template"

Write-Host "Container hardening draft verified."
Write-Host "Backend Dockerfile: $(Resolve-ProjectPath $BackendDockerfile)"
Write-Host "Frontend Dockerfile: $(Resolve-ProjectPath $FrontendDockerfile)"
Write-Host "Kubernetes backend: $(Resolve-ProjectPath $KubernetesBackendManifest)"
Write-Host "Kubernetes frontend: $(Resolve-ProjectPath $KubernetesFrontendManifest)"
Write-Host "Helm backend template: $(Resolve-ProjectPath $HelmBackendTemplate)"
Write-Host "Helm frontend template: $(Resolve-ProjectPath $HelmFrontendTemplate)"

