param(
    [string] $MigrationDir = "",
    [string] $JsonOutputPath = ".\.osmu-run\latest-metadata-index-coverage.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-metadata-index-coverage.md",
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Read-Utf8Text([string] $PathValue) {
    $resolved = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolved, [System.Text.Encoding]::UTF8)
}
function Normalize-Sql([string] $sql) {
    $value = $sql -replace "`r", " "
    $value = $value -replace "`n", " "
    $value = $value -replace "`t", " "
    $value = $value -replace [char]96, ""
    $value = $value -replace "\s+", " "
    return $value.ToLowerInvariant()
}

function Normalize-Column([string] $column) {
    $value = $column.Trim().ToLowerInvariant()
    $value = $value -replace [char]96, ""
    $value = $value -replace "\([0-9]+\)", ""
    $value = $value -replace "\([0-9]+$", ""
    return $value.Trim()
}

function Find-IndexDefinition([string] $sql, [string] $indexName) {
    $escaped = [regex]::Escape($indexName.ToLowerInvariant())
    $pattern = "(?is)(?:unique\s+key\s+$escaped|unique\s+index\s+$escaped|key\s+$escaped|index\s+$escaped|create\s+(?:unique\s+)?index(?:\s+if\s+not\s+exists)?\s+$escaped\s+on\s+[a-z0-9_]+)\s*\((?<columns>[^;]+?)\)"
    $match = [regex]::Match($sql, $pattern)
    if (-not $match.Success) {
        return $null
    }

    $columns = @($match.Groups["columns"].Value.Split(",") | ForEach-Object { Normalize-Column $_ })
    return [pscustomobject][ordered]@{
        name = $indexName
        columns = $columns
    }
}

function Test-IndexPrefix([object] $definition, [string[]] $expectedColumns) {
    if ($null -eq $definition) {
        return $false
    }
    if (@($definition.columns).Count -lt $expectedColumns.Count) {
        return $false
    }
    for ($index = 0; $index -lt $expectedColumns.Count; $index += 1) {
        if ($definition.columns[$index] -ne (Normalize-Column $expectedColumns[$index])) {
            return $false
        }
    }
    return $true
}

if (-not $MigrationDir) {
    $MigrationDir = Join-Path $root "osmu-backend\src\main\resources\db\migration"
}

$resolvedMigrationDir = Resolve-ProjectPath $MigrationDir
if (-not (Test-Path -LiteralPath $resolvedMigrationDir)) {
    throw "Migration directory not found: $resolvedMigrationDir"
}

$migrationFiles = @(Get-ChildItem -LiteralPath $resolvedMigrationDir -Filter "V*__*.sql" | Sort-Object Name)
if ($migrationFiles.Count -eq 0) {
    throw "No migration files found: $resolvedMigrationDir"
}

$migrationSql = ($migrationFiles | ForEach-Object { Read-Utf8Text $_.FullName }) -join "`n"
$normalizedSql = Normalize-Sql $migrationSql

$requirements = @(
    [ordered]@{ id = "bucket-owner-usage"; table = "buckets"; index = "idx_buckets_owner"; expectedPrefix = @("owner_type", "owner_id"); queryPath = "owner quota/organization usage/chargeback reads and delete existence"; reason = "Quota, organization usage, chargeback, and delete guards use scoped owner queries without loading all bucket rows." },
    [ordered]@{ id = "bucket-access-permission-subject"; table = "bucket_permissions"; index = "idx_bucket_permissions_subject"; expectedPrefix = @("subject_type", "subject_id"); queryPath = "non-admin visible bucket permission subjects"; reason = "Visible bucket lookup resolves user, organization, and team grants in one indexed subject query." },
    [ordered]@{ id = "bucket-access-team-membership"; table = "team_members"; index = "idx_team_members_user"; expectedPrefix = @("user_id"); queryPath = "non-admin visible bucket team membership"; reason = "Visible bucket lookup resolves all team ids for one user without checking each team separately." },
    [ordered]@{ id = "user-organization-exists"; table = "users"; index = "idx_users_organization_id"; expectedPrefix = @("organization_id"); queryPath = "organization delete assigned-user guard and access-key owner expansion"; reason = "Organization delete and access-key reconciliation use indexed organization user queries without loading every user row." },
    [ordered]@{ id = "access-key-owner-reconciliation"; table = "access_keys"; index = "idx_access_keys_owner_id"; expectedPrefix = @("owner_id"); queryPath = "organization and team access-key policy reconciliation"; reason = "Policy reconciliation loads access keys for all affected owners in one indexed bulk query instead of one query per owner." },
    [ordered]@{ id = "storage-profile-visible-requests"; table = "storage_profile_requests"; index = "idx_storage_profile_requests_bucket"; expectedPrefix = @("bucket_name", "id"); queryPath = "selected-bucket and non-admin visible storage profile request cursor pages"; reason = "Storage history applies bucket scope and descending id cursor before a bounded limit instead of loading every visible request row." },
    [ordered]@{ id = "storage-profile-admin-status-cursor"; table = "storage_profile_requests"; index = "idx_storage_profile_requests_status"; expectedPrefix = @("status", "id"); queryPath = "admin storage profile approval queue"; reason = "Admin queue applies status and id cursor filters before the bounded limit instead of loading global request history." },
    [ordered]@{ id = "storage-layout-plan-status-cursor"; table = "storage_layout_plans"; index = "idx_storage_layout_plans_status"; expectedPrefix = @("status", "id"); queryPath = "admin storage layout plan cursor page"; reason = "Storage layout plans filter status and continue with a descending ID cursor before the bounded limit." },
    [ordered]@{ id = "user-list-organization-cursor"; table = "users"; index = "idx_users_organization_cursor"; expectedPrefix = @("organization_id", "id"); queryPath = "organization-scoped admin user cursor page"; reason = "ORG_ADMIN user listing filters by organization and id cursor before applying the bounded limit." },
    [ordered]@{ id = "user-list-status-cursor"; table = "users"; index = "idx_users_status_cursor"; expectedPrefix = @("status", "id"); queryPath = "status-filtered admin user cursor page"; reason = "Status-filtered user listing uses indexed status and id ordering instead of loading all user rows." },
    [ordered]@{ id = "team-organization-exists"; table = "teams"; index = "idx_teams_organization"; expectedPrefix = @("organization_id"); queryPath = "organization-scoped team list and delete guard"; reason = "Team listing and organization delete use indexed organization queries without loading every team row." },
    [ordered]@{ id = "team-organization-cursor"; table = "teams"; index = "idx_teams_organization_cursor"; expectedPrefix = @("organization_id", "id"); queryPath = "organization-scoped team cursor page"; reason = "Team pages apply organization scope and ascending id cursor before the bounded limit." },
    [ordered]@{ id = "quota-policy-target-cursor"; table = "quota_policies"; index = "uk_quota_target"; expectedPrefix = @("target_type", "target_id"); queryPath = "admin quota policy composite cursor page"; reason = "Quota policy inventory continues by target_type and target_id before the bounded limit, while dashboard totals use an explicit snapshot path." },
    [ordered]@{ id = "lifecycle-enabled-target-order"; table = "object_lifecycle_rules"; index = "idx_object_lifecycle_rules_target_order"; expectedPrefix = @("enabled", "target_type", "priority", "created_at", "rule_id"); queryPath = "scheduled trash/version lifecycle purge rules"; reason = "Each purge job loads only enabled rules for its target type in deterministic priority order." },
    [ordered]@{ id = "lifecycle-bucket-order"; table = "object_lifecycle_rules"; index = "idx_object_lifecycle_rules_bucket_order"; expectedPrefix = @("bucket_name", "priority", "created_at", "rule_id"); queryPath = "bucket lifecycle export/replace/delete"; reason = "Bucket lifecycle operations load only the selected bucket rules in deterministic priority order." },
    [ordered]@{ id = "lifecycle-inventory-order"; table = "object_lifecycle_rules"; index = "idx_object_lifecycle_rules_inventory_order"; expectedPrefix = @("priority", "created_at", "rule_id"); queryPath = "unfiltered admin lifecycle rule cursor page"; reason = "Admin inventory continues in deterministic priority order before applying the bounded limit." },
    [ordered]@{ id = "lifecycle-inventory-enabled-order"; table = "object_lifecycle_rules"; index = "idx_object_lifecycle_rules_enabled_order"; expectedPrefix = @("enabled", "priority", "created_at", "rule_id"); queryPath = "status-filtered admin lifecycle rule cursor page"; reason = "Enabled or disabled inventory filters execute before the composite cursor and limit." },
    [ordered]@{ id = "lifecycle-inventory-target-order"; table = "object_lifecycle_rules"; index = "idx_object_lifecycle_rules_target_inventory_order"; expectedPrefix = @("target_type", "priority", "created_at", "rule_id"); queryPath = "target-filtered admin lifecycle rule cursor page"; reason = "Target-only inventory filters execute before the composite cursor and limit." },
    [ordered]@{ id = "object-share-bucket-recent"; table = "object_share_links"; index = "idx_object_share_links_bucket_id"; expectedPrefix = @("bucket_name", "id"); queryPath = "bucket-filtered object share analytics and recent links"; reason = "Bucket-only analytics filters and newest-first recent links use bucket_name and id without loading every share row." },
    [ordered]@{ id = "object-share-status-recent"; table = "object_share_links"; index = "idx_object_share_links_status_id"; expectedPrefix = @("status", "id"); queryPath = "status-filtered object share analytics and recent links"; reason = "Status-only analytics filters and newest-first recent links use status and id." },
    [ordered]@{ id = "object-share-bucket-status-recent"; table = "object_share_links"; index = "idx_object_share_links_bucket_status_id"; expectedPrefix = @("bucket_name", "status", "id"); queryPath = "bucket-and-status object share analytics and recent links"; reason = "Combined analytics filters use one composite index before returning a bounded recent list." },
    [ordered]@{ id = "object-list-prefix"; table = "object_metadata"; index = "idx_object_metadata_bucket_key"; expectedPrefix = @("bucket_name", "object_key"); queryPath = "GET /api/buckets/{bucketName}/objects prefix/key listing"; reason = "Bucket-scoped object listing and prefix search must start with bucket_name and object_key." },
    [ordered]@{ id = "object-trash-retention"; table = "object_metadata"; index = "idx_object_metadata_deleted_at"; expectedPrefix = @("bucket_name", "deleted_at"); queryPath = "trash retention/purge candidate scan"; reason = "Trash cleanup scans by bucket and deleted_at instead of scanning all object metadata." },
    [ordered]@{ id = "object-tag-filter"; table = "object_metadata_tags"; index = "idx_object_metadata_tags_lookup"; expectedPrefix = @("bucket_name", "tag_key", "tag_value", "object_key_hash"); queryPath = "object tag exact filter"; reason = "Tag filter uses inverted lookup before joining back to object metadata." },
    [ordered]@{ id = "object-version-list"; table = "object_versions"; index = "idx_object_versions_object"; expectedPrefix = @("bucket_name", "object_key_hash", "created_at"); queryPath = "object version history and retention scan"; reason = "Version history reads newest/oldest versions within one object key hash." },
    [ordered]@{ id = "audit-request-trace"; table = "audit_logs"; index = "idx_audit_logs_request_id"; expectedPrefix = @("request_id"); queryPath = "audit lookup by request id"; reason = "Operator remediation uses request id to locate one failed action." },
    [ordered]@{ id = "audit-result-filter"; table = "audit_logs"; index = "idx_audit_logs_result"; expectedPrefix = @("result"); queryPath = "admin audit result filter"; reason = "Audit result filters should not scan the append-only audit table." },
    [ordered]@{ id = "data-flow-time-window"; table = "data_flow_events"; index = "idx_data_flow_events_created_at"; expectedPrefix = @("created_at", "id"); queryPath = "data-flow recent events, export, and retention delete"; reason = "Detailed event windows and retention batches are bounded by created_at." },
    [ordered]@{ id = "data-flow-bucket-filter"; table = "data_flow_events"; index = "idx_data_flow_events_bucket"; expectedPrefix = @("bucket_name", "created_at"); queryPath = "data-flow bucket analytics"; reason = "Bucket-scoped analytics filter by bucket first, then time." },
    [ordered]@{ id = "daily-rollup-bucket-window"; table = "data_flow_daily_rollups"; index = "idx_data_flow_daily_rollups_bucket"; expectedPrefix = @("bucket_name", "rollup_day"); queryPath = "materialized daily rollup read/export"; reason = "Stored daily aggregate reads use bucket and day window." },
    [ordered]@{ id = "monthly-rollup-bucket-window"; table = "data_flow_monthly_rollups"; index = "idx_data_flow_monthly_rollups_bucket"; expectedPrefix = @("bucket_name", "rollup_month"); queryPath = "materialized monthly rollup read/export"; reason = "Stored monthly aggregate reads use bucket and month window." },
    [ordered]@{ id = "storage-expansion-summary"; table = "storage_expansion_requests"; index = "idx_storage_expansion_summary"; expectedPrefix = @("status", "requested_capacity_bytes", "estimated_usable_capacity_bytes", "id"); queryPath = "storage expansion dashboard summary"; reason = "Capacity summary groups open/planned/applied requests without loading full rows." },
    [ordered]@{ id = "storage-expansion-request-page"; table = "storage_expansion_requests"; index = "idx_storage_expansion_status"; expectedPrefix = @("status", "id"); queryPath = "storage expansion status and cursor page"; reason = "Operator request pages filter by status and continue with descending id cursor without loading full history." },
    [ordered]@{ id = "storage-expansion-execution-page"; table = "storage_expansion_executions"; index = "idx_storage_expansion_execution_request"; expectedPrefix = @("request_id", "id"); queryPath = "storage expansion request execution cursor page"; reason = "Execution history remains request-scoped and bounded by descending id cursor before loading output rows." },
    [ordered]@{ id = "storage-expansion-execution-timeout"; table = "storage_expansion_executions"; index = "idx_storage_expansion_execution_timeout"; expectedPrefix = @("timed_out", "id"); queryPath = "storage expansion execution timeout summary"; reason = "Execution dashboard highlights timed-out runs without scanning execution output." },
    [ordered]@{ id = "chargeback-closeout-draft-window"; table = "chargeback_invoice_drafts"; index = "idx_chargeback_invoice_drafts_window"; expectedPrefix = @("window_from", "window_to", "id"); queryPath = "chargeback closeout draft billing window"; reason = "Closeout applies billing-window overlap before the bounded limit and detects truncation with limit plus one." },
    [ordered]@{ id = "chargeback-closeout-final-window"; table = "chargeback_final_invoices"; index = "idx_chargeback_final_invoices_window"; expectedPrefix = @("window_from", "window_to", "id"); queryPath = "chargeback closeout final invoice billing window"; reason = "Final invoice closeout input is bounded only after billing-window filtering." },
    [ordered]@{ id = "chargeback-closeout-notification-created"; table = "chargeback_notification_deliveries"; index = "idx_chargeback_notification_deliveries_created"; expectedPrefix = @("created_at", "id"); queryPath = "chargeback closeout notification window"; reason = "Closeout notification rows use a created-at window before bounded retrieval." },
    [ordered]@{ id = "chargeback-closeout-handoff-created"; table = "chargeback_payment_provider_handoffs"; index = "idx_chargeback_payment_handoffs_created"; expectedPrefix = @("created_at", "id"); queryPath = "chargeback closeout handoff fallback window"; reason = "When no final invoice ids exist, handoff closeout rows use a created-at window before bounded retrieval." },
    [ordered]@{ id = "notification-retry-worker"; table = "chargeback_notification_deliveries"; index = "idx_chargeback_notification_deliveries_status_next"; expectedPrefix = @("status", "next_attempt_at"); queryPath = "chargeback notification retry worker"; reason = "Retry worker selects due notification rows by status and next attempt time." },
    [ordered]@{ id = "payment-handoff-retry-worker"; table = "chargeback_payment_provider_handoffs"; index = "idx_chargeback_payment_handoffs_status_next"; expectedPrefix = @("status", "next_attempt_at"); queryPath = "payment provider handoff retry worker"; reason = "Retry worker selects due payment handoff rows by status and next attempt time." }
)

$checks = @()
foreach ($requirement in $requirements) {
    $definition = Find-IndexDefinition $normalizedSql $requirement.index
    $passed = Test-IndexPrefix $definition $requirement.expectedPrefix
    $checks += [pscustomobject][ordered]@{
        id = $requirement.id
        table = $requirement.table
        index = $requirement.index
        expectedPrefix = @($requirement.expectedPrefix)
        actualColumns = if ($null -eq $definition) { @() } else { @($definition.columns) }
        queryPath = $requirement.queryPath
        reason = $requirement.reason
        status = if ($passed) { "PASS" } else { "FAIL" }
        passed = $passed
    }
}

$failed = @($checks | Where-Object { -not $_.passed })
$generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
$result = if ($failed.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    formatVersion = "osmu.metadata-index-coverage.v1"
    generatedAt = $generatedAt
    result = $result
    migrationDirectory = $resolvedMigrationDir
    migrationCount = $migrationFiles.Count
    checkedIndexCount = $checks.Count
    failedIndexCount = $failed.Count
    decisionRule = "Metadata index coverage passes when every listed high-volume or operations query path has a migration-backed index whose leading columns match the expected filter/order prefix."
    scopePolicy = "This is a static migration coverage gate. It does not replace a live MariaDB EXPLAIN plan or slow-query review against production-scale data."
    checks = @($checks)
}

$markdownLines = @(
    "# OSMU Metadata Index Coverage",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Migration count: $($migrationFiles.Count)",
    "Checked indexes: $($checks.Count)",
    "Failed indexes: $($failed.Count)",
    "",
    "## Decision Rule",
    "",
    $report.decisionRule,
    "",
    "## Scope Policy",
    "",
    $report.scopePolicy,
    "",
    "## Checks",
    ""
)

foreach ($check in $checks) {
    $expected = ($check.expectedPrefix -join ", ")
    $actual = if (@($check.actualColumns).Count -eq 0) { "missing" } else { $check.actualColumns -join ", " }
    $markdownLines += "- [$($check.status)] $($check.id): $($check.index) on $($check.table); expected=($expected); actual=($actual); query=$($check.queryPath)"
}

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    ($markdownLines -join [Environment]::NewLine) | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Metadata index coverage JSON: $resolvedJsonOutputPath"
    Write-Host "Metadata index coverage markdown: $resolvedMarkdownOutputPath"
}

Write-Host ($markdownLines -join [Environment]::NewLine)

if ($result -ne "passed") {
    $failedIds = ($failed | ForEach-Object { $_.id }) -join ", "
    throw "Metadata index coverage failed: $failedIds"
}
