param(
    [string] $OutputDirectory = ".\.osmu-run\encoding-hygiene-self-test"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Contains([string] $Text, [string] $Expected, [string] $Label) {
    if (-not $Text.Contains($Expected)) {
        throw "$Label does not contain expected text: $Expected"
    }
}

function Invoke-HygieneCheck([string] $Path, [string[]] $Extensions, [switch] $AllowCjkIdeographs) {
    $scriptPath = Resolve-ProjectPath ".\scripts\verify-doc-encoding-hygiene.ps1"
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $scriptPath,
        "-Paths", $Path
    )
    foreach ($extension in $Extensions) {
        $arguments += @("-Extensions", $extension)
    }
    if ($AllowCjkIdeographs) {
        $arguments += "-AllowCjkIdeographs"
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

$resolvedOutputDirectory = Resolve-ProjectPath $OutputDirectory
$safeRoot = Resolve-ProjectPath ".\.osmu-run"
if (-not $resolvedOutputDirectory.StartsWith($safeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output directory outside .osmu-run: $resolvedOutputDirectory"
}
if (Test-Path -LiteralPath $resolvedOutputDirectory) {
    Remove-Item -LiteralPath $resolvedOutputDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$goodDirectory = Join-Path $resolvedOutputDirectory "good"
$badDirectory = Join-Path $resolvedOutputDirectory "bad"
New-Item -ItemType Directory -Force -Path $goodDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $badDirectory | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$hangulSample = [string][char]0xD55C + [string][char]0xAE00 + " " + [string][char]0xBB38 + [string][char]0xC11C
[System.IO.File]::WriteAllText((Join-Path $goodDirectory "README.md"), "# Encoding hygiene self-test`n`nEnglish and Hangul are allowed: $hangulSample.", $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $badDirectory "replacement.md"), "bad replacement " + [string][char]0xFFFD, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $badDirectory "c0-control.md"), "bad c0 control " + [string][char]0x0007, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $badDirectory "control.md"), "bad control " + [string][char]0x0085, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $badDirectory "compatibility.md"), "bad compatibility " + [string][char]0xF9CF, $utf8NoBom)
$cjkFixture = 'class Fixture { String marker = "' + [string][char]0x4E00 + '"; }'
[System.IO.File]::WriteAllText((Join-Path $badDirectory "cjk.java"), $cjkFixture, $utf8NoBom)

$goodResult = Invoke-HygieneCheck -Path $goodDirectory -Extensions @(".md")
Assert-True ($goodResult.ExitCode -eq 0) "Expected clean fixture to pass. Output: $($goodResult.Output)"
Assert-Contains $goodResult.Output "Encoding hygiene verified." "clean fixture output"

$replacementResult = Invoke-HygieneCheck -Path (Join-Path $badDirectory "replacement.md") -Extensions @(".md")
Assert-True ($replacementResult.ExitCode -ne 0) "Expected replacement fixture to fail."
Assert-Contains $replacementResult.Output "UTF-8 replacement character" "replacement fixture output"

$c0ControlResult = Invoke-HygieneCheck -Path (Join-Path $badDirectory "c0-control.md") -Extensions @(".md")
Assert-True ($c0ControlResult.ExitCode -ne 0) "Expected C0 control fixture to fail."
Assert-Contains $c0ControlResult.Output "C0/DEL control character" "C0 control fixture output"

$controlResult = Invoke-HygieneCheck -Path (Join-Path $badDirectory "control.md") -Extensions @(".md")
Assert-True ($controlResult.ExitCode -ne 0) "Expected C1 control fixture to fail."
Assert-Contains $controlResult.Output "C1 control character" "control fixture output"

$compatibilityResult = Invoke-HygieneCheck -Path (Join-Path $badDirectory "compatibility.md") -Extensions @(".md")
Assert-True ($compatibilityResult.ExitCode -ne 0) "Expected CJK compatibility fixture to fail by default."
Assert-Contains $compatibilityResult.Output "CJK unified/compatibility ideograph" "CJK compatibility fixture output"

$cjkResult = Invoke-HygieneCheck -Path (Join-Path $badDirectory "cjk.java") -Extensions @(".java")
Assert-True ($cjkResult.ExitCode -ne 0) "Expected CJK fixture to fail by default."
Assert-Contains $cjkResult.Output "CJK unified/compatibility ideograph" "CJK fixture output"

$cjkAllowedResult = Invoke-HygieneCheck -Path (Join-Path $badDirectory "cjk.java") -Extensions @(".java") -AllowCjkIdeographs
Assert-True ($cjkAllowedResult.ExitCode -eq 0) "Expected CJK fixture to pass when AllowCjkIdeographs is set. Output: $($cjkAllowedResult.Output)"

Write-Host "Encoding hygiene self-test verified."
Write-Host "Encoding hygiene self-test directory: $resolvedOutputDirectory"