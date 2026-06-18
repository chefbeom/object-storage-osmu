function Normalize-OsmuProcessPath() {
    $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")
    if (-not $processPath) {
        $processPath = (([Environment]::GetEnvironmentVariable("Path", "Machine")),
            ([Environment]::GetEnvironmentVariable("Path", "User")) |
            Where-Object { $_ }) -join ";"
    }
    [Environment]::SetEnvironmentVariable("PATH", $null, "Process")
    [Environment]::SetEnvironmentVariable("Path", $processPath, "Process")
}

function Get-OsmuJavaHomeCandidates([string] $JavaHome = "") {
    $candidates = New-Object System.Collections.Generic.List[string]

    if ($JavaHome) {
        $candidates.Add($JavaHome) | Out-Null
    }

    $envJavaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME")
    if ($envJavaHome) {
        $candidates.Add($envJavaHome) | Out-Null
    }

    $envOsmuJavaHome = [Environment]::GetEnvironmentVariable("OSMU_JAVA_HOME")
    if ($envOsmuJavaHome) {
        $candidates.Add($envOsmuJavaHome) | Out-Null
    }

    $javaCommand = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCommand) {
        $javaExe = Resolve-Path -LiteralPath $javaCommand.Source -ErrorAction SilentlyContinue
        if ($javaExe) {
            $binPath = Split-Path -Parent $javaExe.Path
            $homePath = Split-Path -Parent $binPath
            $candidates.Add($homePath) | Out-Null
        }
    }

    $roots = @(
        "C:\Program Files\Java",
        "C:\Program Files\Eclipse Adoptium",
        "C:\Program Files\Microsoft",
        "C:\Program Files\Amazon Corretto",
        "C:\Program Files\Zulu",
        "C:\Program Files\BellSoft"
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { $candidates.Add($_.FullName) | Out-Null }
    }

    $directRoots = @(
        "C:\jdk-17",
        "C:\jdk-21",
        "C:\Java\jdk-17",
        "C:\Java\jdk-21"
    )
    foreach ($root in $directRoots) {
        if (Test-Path -LiteralPath $root) {
            $candidates.Add($root) | Out-Null
        }
    }

    $tempBases = @(
        $env:TEMP,
        $env:TMP
    )
    if ($env:LOCALAPPDATA) {
        $tempBases += (Join-Path $env:LOCALAPPDATA "Temp")
    }

    foreach ($tempBase in ($tempBases | Where-Object { $_ } | Select-Object -Unique)) {
        foreach ($jdkRootName in @("temurin-jdk17", "temurin-jdk21")) {
            $jdkRoot = Join-Path $tempBase $jdkRootName
            if (-not (Test-Path -LiteralPath $jdkRoot)) {
                continue
            }

            $candidates.Add($jdkRoot) | Out-Null
            Get-ChildItem -LiteralPath $jdkRoot -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                ForEach-Object { $candidates.Add($_.FullName) | Out-Null }
        }
    }

    $candidates | Where-Object { $_ } | Select-Object -Unique
}

function Use-OsmuJavaHome([string] $JavaHome = "") {
    Normalize-OsmuProcessPath

    foreach ($candidate in Get-OsmuJavaHomeCandidates $JavaHome) {
        $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
        if (-not $resolved) {
            if ($JavaHome -and $candidate -eq $JavaHome) {
                throw "JavaHome path does not exist: $JavaHome"
            }
            continue
        }

        $javaBin = Join-Path $resolved.Path "bin"
        $javaExe = Join-Path $javaBin "java.exe"
        if (-not (Test-Path -LiteralPath $javaExe)) {
            if ($JavaHome -and $candidate -eq $JavaHome) {
                throw "JavaHome does not contain bin\java.exe: $($resolved.Path)"
            }
            continue
        }

        $env:JAVA_HOME = $resolved.Path
        [Environment]::SetEnvironmentVariable("Path", "$javaBin;$([Environment]::GetEnvironmentVariable("Path", "Process"))", "Process")
        return $resolved.Path
    }

    return $null
}

function Assert-OsmuJavaAvailable([int] $RequiredVersion = 17) {
    $javaCommand = Get-Command java -ErrorAction SilentlyContinue
    if (-not $javaCommand) {
        $message = "Java runtime not found. Install JDK $RequiredVersion+ or pass -JavaHome C:\path\to\jdk-$RequiredVersion before running backend tests."
        throw $message
    }

    $javaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME")
    if ($javaHome -and -not (Test-Path -LiteralPath $javaHome)) {
        throw "JAVA_HOME points to a missing path: $javaHome"
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $javaCommand.Source -version 2>&1
        $javaExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($javaExitCode -ne 0) {
        throw "Java version check failed with exit code ${javaExitCode}: $(($output | ForEach-Object { [string]$_ }) -join ' ')"
    }
    $versionText = ($output -join " ")
    $hasVersion = $versionText -match 'version "((1\.)?([0-9]+))'
    $major = if ($hasVersion) {
        if ($Matches[2]) { [int]$Matches[3] } else { [int]$Matches[1] }
    } else {
        0
    }

    if ($major -lt $RequiredVersion) {
        throw "Java version is below $RequiredVersion or unreadable: $versionText"
    }

    return $versionText
}
