param(
    [string[]] $DocsPath = @(".\README.md", ".\dev-docs", ".\infra")
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    $normalized = $PathValue.Trim().Replace('/', '\')
    while ($normalized.StartsWith(".\")) {
        $normalized = $normalized.Substring(2)
    }
    while ($normalized.StartsWith("..\")) {
        $normalized = $normalized.Substring(3)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $normalized))
}

function Get-MarkdownFiles([string[]] $PathValues) {
    $files = New-Object System.Collections.Generic.List[object]
    foreach ($pathValue in $PathValues) {
        $resolved = Resolve-ProjectPath $pathValue
        if (-not (Test-Path -LiteralPath $resolved)) {
            throw "Project doc reference path missing: $resolved"
        }

        $item = Get-Item -LiteralPath $resolved
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Filter *.md |
                ForEach-Object { $files.Add($_) }
        }
        elseif ($item.Extension -eq ".md") {
            $files.Add($item)
        }
        else {
            throw "Project doc reference path must be a Markdown file or directory: $resolved"
        }
    }

    return @($files | Sort-Object FullName -Unique)
}

$referencePattern = '(?:\.\.?[\\/])?(?:scripts[\\/][A-Za-z0-9_.-]+\.ps1|\.github[\\/]workflows[\\/][A-Za-z0-9_.-]+\.ya?ml)'
$findings = New-Object System.Collections.Generic.List[object]
$referenceCount = 0
$files = @(Get-MarkdownFiles $DocsPath)

$documentIndexPath = Resolve-ProjectPath ".\dev-docs\document-index.md"
$verifyLocalPath = Resolve-ProjectPath ".\scripts\verify-local.ps1"
if ((Test-Path -LiteralPath $documentIndexPath) -and (Test-Path -LiteralPath $verifyLocalPath)) {
    $documentIndexContent = [System.IO.File]::ReadAllText($documentIndexPath, [System.Text.Encoding]::UTF8)
    $verifyLocalContent = [System.IO.File]::ReadAllText($verifyLocalPath, [System.Text.Encoding]::UTF8)
    $verifyLocalScripts = @(
        [regex]::Matches($verifyLocalContent, 'scripts\\([A-Za-z0-9_.-]+\.ps1)') |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique
    )
    $documentIndexScripts = @(
        [regex]::Matches($documentIndexContent, '(?:scripts/|scripts\\)([A-Za-z0-9_.-]+\.ps1)') |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique
    )
    foreach ($scriptName in $verifyLocalScripts) {
        if ($documentIndexScripts -notcontains $scriptName) {
            $findings.Add([pscustomobject]@{
                Path = $documentIndexPath
                Line = 1
                Reference = "../scripts/$scriptName"
                ResolvedReference = Resolve-ProjectPath ".\scripts\$scriptName"
            })
        }
    }
}
foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $lines = [regex]::Split($content, "\r\n|\n|\r")
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        foreach ($match in [regex]::Matches($lines[$lineIndex], $referencePattern)) {
            $referenceCount++
            $reference = $match.Value
            $resolvedReference = Resolve-ProjectPath $reference
            if (-not (Test-Path -LiteralPath $resolvedReference -PathType Leaf)) {
                $findings.Add([pscustomobject]@{
                    Path = $file.FullName
                    Line = $lineIndex + 1
                    Reference = $reference
                    ResolvedReference = $resolvedReference
                })
            }
        }
    }
}

if ($findings.Count -gt 0) {
    Write-Host "Project doc file reference check failed. Missing references:"
    $findings |
        Select-Object Path, Line, Reference, ResolvedReference |
        Format-Table -AutoSize |
        Out-String -Width 240 |
        Write-Host
    throw "Project doc file reference check found $($findings.Count) missing reference(s)."
}

Write-Host "Project doc file references verified."
Write-Host "Project doc files scanned: $($files.Count)"
Write-Host "Project doc file references checked: $referenceCount"