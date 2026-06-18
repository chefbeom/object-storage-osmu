function Use-OsmuDockerConfig([string] $RootPath = "") {
    $resolvedRoot = if ($RootPath) {
        if ([System.IO.Path]::IsPathRooted($RootPath)) {
            [System.IO.Path]::GetFullPath($RootPath)
        } else {
            [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $RootPath))
        }
    } else {
        (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }

    $dockerConfig = Join-Path (Join-Path $resolvedRoot ".osmu-run") "docker-config"
    New-Item -ItemType Directory -Force -Path $dockerConfig | Out-Null
    $env:DOCKER_CONFIG = $dockerConfig
    return $dockerConfig
}
