param(
    [string[]] $Paths = @(".\README.md", ".\dev-docs", ".\osmu-frontend\src", ".\osmu-backend\src\main", ".\scripts"),
    [string[]] $Extensions = @(".md", ".json", ".vue", ".js", ".java", ".ps1"),
    [switch] $AllowCjkIdeographs
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function New-Snippet([string] $Line, [int] $Index) {
    $start = [Math]::Max(0, $Index - 40)
    $length = [Math]::Min($Line.Length - $start, 100)
    $snippet = $Line.Substring($start, $length)
    $snippet = $snippet -replace "`t", " "
    return $snippet -replace "[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]", "?"
}

function Get-DocFiles([string[]] $PathValues, [hashtable] $ExtensionSet) {
    $files = New-Object System.Collections.Generic.List[object]
    foreach ($pathValue in $PathValues) {
        $resolved = Resolve-ProjectPath $pathValue
        if (-not (Test-Path -LiteralPath $resolved)) {
            throw "Encoding hygiene path missing: $resolved"
        }

        $item = Get-Item -LiteralPath $resolved
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $item.FullName -Recurse -File |
                Where-Object { $ExtensionSet.ContainsKey($_.Extension.ToLowerInvariant()) } |
                ForEach-Object { $files.Add($_) }
        }
        elseif ($ExtensionSet.ContainsKey($item.Extension.ToLowerInvariant())) {
            $files.Add($item)
        }
    }

    return $files | Sort-Object FullName -Unique
}

function Get-EncodingFindingReason([int] $CodePoint, [bool] $AllowCjk) {
    if ($CodePoint -eq 0xFFFD) {
        return "UTF-8 replacement character"
    }
    if (($CodePoint -lt 0x20 -and $CodePoint -ne 0x09 -and $CodePoint -ne 0x0A -and $CodePoint -ne 0x0D) -or $CodePoint -eq 0x7F) {
        return "C0/DEL control character"
    }
    if ($CodePoint -ge 0x80 -and $CodePoint -le 0x9F) {
        return "C1 control character"
    }
    if (-not $AllowCjk -and (($CodePoint -ge 0x4E00 -and $CodePoint -le 0x9FFF) -or ($CodePoint -ge 0xF900 -and $CodePoint -le 0xFAFF))) {
        return "CJK unified/compatibility ideograph in English/Hangul docs and source"
    }
    return $null
}

$extensionSet = @{}
foreach ($extension in $Extensions) {
    if ([string]::IsNullOrWhiteSpace($extension)) {
        continue
    }
    $normalized = $extension.Trim()
    if (-not $normalized.StartsWith(".")) {
        $normalized = ".$normalized"
    }
    $extensionSet[$normalized.ToLowerInvariant()] = $true
}

if ($extensionSet.Count -eq 0) {
    throw "At least one extension is required."
}

$scanPattern = if ($AllowCjkIdeographs) {
    "[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\uFFFD]"
}
else {
    "[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\uFFFD\u4E00-\u9FFF\uF900-\uFAFF]"
}

$findings = New-Object System.Collections.Generic.List[object]
$files = @(Get-DocFiles $Paths $extensionSet)

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $lines = [regex]::Split($content, "\r\n|\n|\r")

    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = $lines[$lineIndex]
        foreach ($match in [regex]::Matches($line, $scanPattern)) {
            $codePoint = [int][char]$match.Value[0]
            $reason = Get-EncodingFindingReason $codePoint ([bool] $AllowCjkIdeographs)
            if ($null -eq $reason) {
                continue
            }

            $findings.Add([pscustomobject]@{
                Path = $file.FullName
                Line = $lineIndex + 1
                Column = $match.Index + 1
                CodePoint = ("U+{0:X4}" -f $codePoint)
                Reason = $reason
                Snippet = New-Snippet $line $match.Index
            })
        }
    }
}

if ($findings.Count -gt 0) {
    Write-Host "Encoding hygiene failed. Findings:"
    $findings |
        Select-Object Path, Line, Column, CodePoint, Reason, Snippet |
        Format-Table -AutoSize |
        Out-String -Width 220 |
        Write-Host
    throw "Encoding hygiene found $($findings.Count) suspicious character(s)."
}

Write-Host "Encoding hygiene verified."
Write-Host "Encoding hygiene scanned files: $($files.Count)"