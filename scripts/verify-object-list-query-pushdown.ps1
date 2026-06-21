$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$repositoryPath = Join-Path $root "osmu-backend\src\main\java\com\example\osmu\object\repository\MariaDbObjectMetadataRepository.java"

if (-not (Test-Path -LiteralPath $repositoryPath)) {
    throw "Repository source not found: $repositoryPath"
}

$source = Get-Content -Raw -LiteralPath $repositoryPath

function Assert-Count([string] $needle, [int] $expected, [string] $message) {
    $count = ([regex]::Matches($source, [regex]::Escape($needle))).Count
    if ($count -ne $expected) {
        throw "$message Expected $expected occurrence(s), found $count."
    }
}

function Assert-Match([string] $pattern, [string] $message) {
    if ($source -notmatch $pattern) {
        throw $message
    }
}

Assert-Count 'sql.append("AND LOWER(m.object_key) LIKE ? ESCAPE ''!''\n");' 2 "Active and deleted object search must be pushed into MariaDB SQL with literal wildcard escaping."
Assert-Count 'sql.append("AND m.object_key > ?\n");' 2 "Active and deleted object cursor windows must be pushed into MariaDB SQL."
Assert-Count 'sql.append("ORDER BY m.object_key LIMIT ?");' 2 "Active and deleted object list queries must be bounded by SQL LIMIT."
Assert-Count 'statement.setInt(parameterIndex, Math.max(1, rowLimit));' 2 "Active and deleted object list queries must bind rowLimit."

Assert-Match 'findCandidates\([\s\S]*normalizedCursor,\s*limit \+ 1' "Active object list must request only one extra row for nextCursor detection."
Assert-Match 'findDeletedCandidates\([\s\S]*normalizedCursor,\s*limit \+ 1' "Deleted object list must request only one extra row for nextCursor detection."
Assert-Match 'FROM object_metadata_tags t[\s\S]*t\.tag_key = \?[\s\S]*t\.tag_value = \?' "Object tag filter must use the object_metadata_tags inverted index path."
Assert-Match 'likePrefixPattern\([\s\S]*escapeLike' "Object prefix LIKE patterns must escape user-provided wildcard characters."
Assert-Match 'likeContainsPattern\([\s\S]*escapeLike' "Object search LIKE patterns must escape user-provided wildcard characters."

Write-Host "Object list query pushdown verification passed."
