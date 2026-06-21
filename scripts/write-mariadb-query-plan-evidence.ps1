param(
    [string] $EnvironmentName = "local",
    [string] $TargetDatabase = "osmu",
    [string] $Operator = "",
    [string] $ExplainInputDir = "",
    [switch] $Execute,
    [string] $MysqlPath = "mysql",
    [string] $HostName = "127.0.0.1",
    [int] $Port = 3306,
    [string] $Database = "osmu",
    [string] $User = "osmu",
    [string] $PasswordEnvVar = "OSMU_MARIADB_PASSWORD",
    [string] $JsonOutputPath = ".\.osmu-run\latest-mariadb-query-plan-evidence.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-mariadb-query-plan-evidence.md",
    [switch] $NoWrite,
    [switch] $FailIfNotPassed
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Normalize-Optional([string] $value) {
    if ($null -eq $value) {
        return ""
    }
    return $value.Trim()
}

function Assert-PlainReference([string] $value, [string] $name) {
    $normalized = Normalize-Optional $value
    if (-not $normalized) {
        return
    }
    $secretPattern = "(?i)(password|passwd|secret|token|apikey|api_key|access[_-]?key|private[_-]?key)\s*[:=]"
    if ($normalized -match $secretPattern) {
        throw "$name must be a non-secret reference, not credential material."
    }
}

function Sql-Literal([string] $value) {
    return "'" + ($value -replace "'", "''") + "'"
}

function New-QueryCheck(
    [string] $id,
    [string] $table,
    [string] $expectedIndex,
    [string] $queryPath,
    [string] $sql,
    [int] $slowQueryBudgetMs
) {
    return [pscustomobject][ordered]@{
        id = $id
        table = $table
        expectedIndex = $expectedIndex
        queryPath = $queryPath
        sql = $sql
        explainSql = "EXPLAIN FORMAT=JSON $sql"
        slowQueryBudgetMs = $slowQueryBudgetMs
    }
}

function Test-ExplainUsesIndex([string] $explainText, [string] $expectedIndex) {
    if (-not $explainText -or -not $expectedIndex) {
        return $false
    }
    $escaped = [regex]::Escape($expectedIndex)
    return $explainText -match "(?is)""key""\s*:\s*""$escaped""" -or
        $explainText -match "(?is)\b$escaped\b"
}

function Find-ExplainInputFile([string] $inputDir, [string] $id) {
    foreach ($extension in @(".explain.json", ".json", ".txt", ".out")) {
        $path = Join-Path $inputDir ($id + $extension)
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    return ""
}

function Invoke-MysqlExplain([object] $query) {
    $password = [Environment]::GetEnvironmentVariable($PasswordEnvVar, "Process")
    if (-not $password) {
        $password = [Environment]::GetEnvironmentVariable($PasswordEnvVar, "User")
    }
    if (-not $password) {
        $password = [Environment]::GetEnvironmentVariable($PasswordEnvVar, "Machine")
    }
    if (-not $password) {
        throw "Environment variable $PasswordEnvVar must be set for -Execute."
    }

    $previousPassword = $env:MYSQL_PWD
    $env:MYSQL_PWD = $password
    try {
        $arguments = @(
            "--host=$HostName",
            "--port=$Port",
            "--user=$User",
            "--database=$Database",
            "--batch",
            "--raw",
            "--skip-column-names",
            "--execute=$($query.explainSql)"
        )
        $output = & $MysqlPath @arguments 2>&1
        $exitCode = $LASTEXITCODE
        return [pscustomobject][ordered]@{
            exitCode = $exitCode
            output = ($output | Out-String).Trim()
        }
    }
    finally {
        $env:MYSQL_PWD = $previousPassword
    }
}

$operatorName = Normalize-Optional $Operator
if (-not $operatorName) {
    $operatorName = Normalize-Optional ([Environment]::UserName)
}
Assert-PlainReference $operatorName "Operator"

if ($Execute -and $ExplainInputDir) {
    throw "Use either -Execute or -ExplainInputDir, not both."
}

$sampleBucket = "osmu-smoke-bucket"
$sampleHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
$startTime = "2026-01-01 00:00:00"
$endTime = "2026-02-01 00:00:00"
$startDate = "2026-01-01"
$endDate = "2026-02-01"
$startMonth = "2026-01-01"
$endMonth = "2026-03-01"

$queries = @(
    New-QueryCheck "object-list-prefix" "object_metadata" "idx_object_metadata_bucket_key" "GET /api/buckets/{bucketName}/objects prefix list" "SELECT object_key, size_bytes FROM object_metadata WHERE bucket_name = $(Sql-Literal $sampleBucket) AND deleted_at IS NULL AND object_key >= 'docs/' AND object_key < 'docs0' ORDER BY object_key LIMIT 101" 200
    New-QueryCheck "object-search-window" "object_metadata" "idx_object_metadata_bucket_key" "GET /api/buckets/{bucketName}/objects search/cursor page" "SELECT object_key, size_bytes FROM object_metadata WHERE bucket_name = $(Sql-Literal $sampleBucket) AND object_key LIKE 'docs/%' AND deleted_at IS NULL AND LOWER(object_key) LIKE '%report%' AND object_key > 'docs/2026/report-0001.txt' ORDER BY object_key LIMIT 101" 250
    New-QueryCheck "object-tag-filter" "object_metadata_tags" "idx_object_metadata_tags_lookup" "object tag exact filter candidate lookup" "SELECT object_key_hash FROM object_metadata_tags WHERE bucket_name = $(Sql-Literal $sampleBucket) AND tag_key = 'project' AND tag_value = 'osmu' ORDER BY object_key_hash LIMIT 1000" 250
    New-QueryCheck "object-trash-retention" "object_metadata" "idx_object_metadata_deleted_at" "trash retention/purge candidate scan" "SELECT object_key FROM object_metadata WHERE bucket_name = $(Sql-Literal $sampleBucket) AND deleted_at IS NOT NULL AND deleted_at <= TIMESTAMP('2030-01-01 00:00:00') ORDER BY deleted_at, bucket_name, object_key LIMIT 100" 250
    New-QueryCheck "object-version-list" "object_versions" "idx_object_versions_object" "object version history list" "SELECT version_id FROM object_versions WHERE bucket_name = $(Sql-Literal $sampleBucket) AND object_key_hash = $(Sql-Literal $sampleHash) ORDER BY created_at DESC, version_id DESC LIMIT 100" 200
    New-QueryCheck "audit-request-trace" "audit_logs" "idx_audit_logs_request_id" "audit lookup by request id" "SELECT id FROM audit_logs WHERE request_id = 'req-smoke' ORDER BY id DESC LIMIT 100" 200
    New-QueryCheck "audit-result-filter" "audit_logs" "idx_audit_logs_result" "admin audit result filter" "SELECT id FROM audit_logs WHERE result = 'FAILURE' ORDER BY id DESC LIMIT 100" 250
    New-QueryCheck "data-flow-time-window" "data_flow_events" "idx_data_flow_events_created_at" "data-flow recent event window/export" "SELECT id FROM data_flow_events WHERE created_at >= TIMESTAMP('$startTime') AND created_at < TIMESTAMP('$endTime') ORDER BY created_at DESC, id DESC LIMIT 100" 300
    New-QueryCheck "data-flow-bucket-filter" "data_flow_events" "idx_data_flow_events_bucket" "data-flow bucket analytics window" "SELECT id FROM data_flow_events WHERE bucket_name = $(Sql-Literal $sampleBucket) AND created_at >= TIMESTAMP('$startTime') AND created_at < TIMESTAMP('$endTime') ORDER BY created_at DESC, id DESC LIMIT 100" 300
    New-QueryCheck "daily-rollup-bucket-window" "data_flow_daily_rollups" "idx_data_flow_daily_rollups_bucket" "materialized daily rollup read/export" "SELECT rollup_day FROM data_flow_daily_rollups WHERE bucket_name = $(Sql-Literal $sampleBucket) AND rollup_day >= DATE('$startDate') AND rollup_day < DATE('$endDate') ORDER BY rollup_day DESC LIMIT 100" 250
    New-QueryCheck "monthly-rollup-bucket-window" "data_flow_monthly_rollups" "idx_data_flow_monthly_rollups_bucket" "materialized monthly rollup read/export" "SELECT rollup_month FROM data_flow_monthly_rollups WHERE bucket_name = $(Sql-Literal $sampleBucket) AND rollup_month >= DATE('$startMonth') AND rollup_month < DATE('$endMonth') ORDER BY rollup_month DESC LIMIT 100" 250
    New-QueryCheck "storage-expansion-summary" "storage_expansion_requests" "idx_storage_expansion_summary" "storage expansion dashboard summary" "SELECT id FROM storage_expansion_requests WHERE status = 'PENDING_APPROVAL' ORDER BY requested_capacity_bytes DESC, estimated_usable_capacity_bytes DESC, id DESC LIMIT 100" 250
    New-QueryCheck "storage-expansion-execution-timeout" "storage_expansion_executions" "idx_storage_expansion_execution_timeout" "storage expansion execution timeout summary" "SELECT id FROM storage_expansion_executions WHERE timed_out = TRUE ORDER BY id DESC LIMIT 100" 250
    New-QueryCheck "notification-retry-worker" "chargeback_notification_deliveries" "idx_chargeback_notification_deliveries_status_next" "chargeback notification retry worker due rows" "SELECT id FROM chargeback_notification_deliveries WHERE status IN ('PENDING_DELIVERY_ADAPTER','DELIVERY_ADAPTER_RETRY') AND (next_attempt_at IS NULL OR next_attempt_at <= TIMESTAMP('$startTime')) ORDER BY next_attempt_at ASC, id ASC LIMIT 100" 300
    New-QueryCheck "payment-handoff-retry-worker" "chargeback_payment_provider_handoffs" "idx_chargeback_payment_handoffs_status_next" "payment provider handoff retry worker due rows" "SELECT id FROM chargeback_payment_provider_handoffs WHERE status IN ('PENDING_PAYMENT_PROVIDER_ADAPTER','PAYMENT_PROVIDER_ADAPTER_RETRY') AND (next_attempt_at IS NULL OR next_attempt_at <= TIMESTAMP('$startTime')) ORDER BY next_attempt_at ASC, id ASC LIMIT 100" 300
)

$mode = if ($Execute) {
    "execute"
} elseif ($ExplainInputDir) {
    "explain-input"
} else {
    "plan-only"
}

$resolvedExplainInputDir = ""
if ($ExplainInputDir) {
    $resolvedExplainInputDir = Resolve-ProjectPath $ExplainInputDir
    if (-not (Test-Path -LiteralPath $resolvedExplainInputDir)) {
        throw "Explain input directory not found: $resolvedExplainInputDir"
    }
}

$checks = @()
foreach ($query in $queries) {
    $explainText = ""
    $sourcePath = ""
    $exitCode = $null
    $errorMessage = ""

    try {
        if ($mode -eq "execute") {
            $executed = Invoke-MysqlExplain $query
            $exitCode = $executed.exitCode
            $explainText = $executed.output
            if ($exitCode -ne 0) {
                $errorMessage = "mysql exited with code $exitCode"
            }
        } elseif ($mode -eq "explain-input") {
            $sourcePath = Find-ExplainInputFile $resolvedExplainInputDir $query.id
            if (-not $sourcePath) {
                $errorMessage = "Missing explain input file for $($query.id)."
            } else {
                $explainText = Get-Content -Raw -LiteralPath $sourcePath
            }
        }
    } catch {
        $errorMessage = $_.Exception.Message
    }

    $usesExpectedIndex = Test-ExplainUsesIndex $explainText $query.expectedIndex
    $executedOrLoaded = $mode -ne "plan-only" -and -not [string]::IsNullOrWhiteSpace($explainText) -and -not $errorMessage
    $passed = $mode -ne "plan-only" -and $executedOrLoaded -and $usesExpectedIndex
    $status = if ($mode -eq "plan-only") {
        "PENDING"
    } elseif ($passed) {
        "PASS"
    } else {
        "FAIL"
    }

    $checks += [pscustomobject][ordered]@{
        id = $query.id
        table = $query.table
        queryPath = $query.queryPath
        expectedIndex = $query.expectedIndex
        slowQueryBudgetMs = $query.slowQueryBudgetMs
        status = $status
        passed = $passed
        usesExpectedIndex = $usesExpectedIndex
        sourcePath = $sourcePath
        exitCode = $exitCode
        errorMessage = $errorMessage
        explainSql = $query.explainSql
    }
}

$failed = @($checks | Where-Object { $_.status -eq "FAIL" })
$passedChecks = @($checks | Where-Object { $_.status -eq "PASS" })
$result = if ($mode -eq "plan-only") {
    "plan-ready-execute-required"
} elseif ($failed.Count -eq 0 -and $passedChecks.Count -eq $checks.Count) {
    "passed"
} else {
    "failed"
}

$generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
$decisionRule = "MariaDB query plan evidence passes only when every listed high-volume or operations query path has EXPLAIN output showing the expected migration-backed index."
$scopePolicy = "Plan-only mode does not prove live MariaDB performance. Production readiness still requires this script to run with -Execute or verified operator-collected EXPLAIN output against target-scale data, followed by separate slow-query log review if latency exceeds the listed budget."
$secretPolicy = "Database password is read only from PasswordEnvVar in -Execute mode and is never written to JSON or Markdown evidence."

$report = [pscustomobject][ordered]@{
    formatVersion = "osmu.mariadb-query-plan-evidence.v1"
    generatedAt = $generatedAt
    result = $result
    mode = $mode
    environmentName = Normalize-Optional $EnvironmentName
    targetDatabase = Normalize-Optional $TargetDatabase
    operator = $operatorName
    mysqlClient = if ($mode -eq "execute") { $MysqlPath } else { "" }
    hostName = if ($mode -eq "execute") { $HostName } else { "" }
    port = if ($mode -eq "execute") { $Port } else { 0 }
    database = if ($mode -eq "execute") { $Database } else { "" }
    user = if ($mode -eq "execute") { $User } else { "" }
    passwordEnvVar = if ($mode -eq "execute") { $PasswordEnvVar } else { "" }
    explainInputDir = $resolvedExplainInputDir
    checkCount = $checks.Count
    passedCount = $passedChecks.Count
    failedCount = $failed.Count
    decisionRule = $decisionRule
    scopePolicy = $scopePolicy
    secretPolicy = $secretPolicy
    checks = @($checks)
}

$markdownLines = @(
    "# OSMU MariaDB Query Plan Evidence",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Mode: $mode",
    "Environment: $($report.environmentName)",
    "Target database: $($report.targetDatabase)",
    "Checks: $($checks.Count)",
    "Passed: $($passedChecks.Count)",
    "Failed: $($failed.Count)",
    "",
    "## Decision Rule",
    "",
    $decisionRule,
    "",
    "## Scope Policy",
    "",
    $scopePolicy,
    "",
    "## Secret Policy",
    "",
    $secretPolicy,
    "",
    "## Checks",
    ""
)

foreach ($check in $checks) {
    $detail = if ($check.errorMessage) { "; error=$($check.errorMessage)" } else { "" }
    $markdownLines += "- [$($check.status)] $($check.id): table=$($check.table); expectedIndex=$($check.expectedIndex); usesExpectedIndex=$($check.usesExpectedIndex); budgetMs=$($check.slowQueryBudgetMs)$detail"
}

if ($mode -eq "plan-only") {
    $markdownLines += ""
    $markdownLines += "## Execute Command"
    $markdownLines += ""
    $markdownLines += "powershell -ExecutionPolicy Bypass -File .\scripts\write-mariadb-query-plan-evidence.ps1 -Execute -HostName <host> -Port <port> -Database <db> -User <user> -PasswordEnvVar OSMU_MARIADB_PASSWORD -FailIfNotPassed"
}

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "MariaDB query plan evidence JSON: $resolvedJsonOutputPath"
    Write-Host "MariaDB query plan evidence markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($FailIfNotPassed -and $result -ne "passed") {
    throw "MariaDB query plan evidence did not pass: $result"
}
