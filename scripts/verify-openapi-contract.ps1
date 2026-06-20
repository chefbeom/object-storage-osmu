param(
    [string] $OpenApiPath = ".\dev-docs\openapi-mvp.json"
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

function Assert-Operation($spec, [string] $path, [string] $method, [string] $operationId) {
    $pathItem = $spec.paths.PSObject.Properties[$path]
    Assert-True ([bool]$pathItem) "OpenAPI path missing: $path"

    $operation = $pathItem.Value.PSObject.Properties[$method]
    Assert-True ([bool]$operation) "OpenAPI operation missing: $($method.ToUpperInvariant()) $path"
    Assert-True ($operation.Value.operationId -eq $operationId) "OpenAPI operationId mismatch for $($method.ToUpperInvariant()) $path. Expected $operationId, found $($operation.Value.operationId)."
}

function Assert-FrontendFunction([string] $source, [string] $functionName) {
    $pattern = "export (async )?function $([regex]::Escape($functionName))\("
    Assert-True ([regex]::IsMatch($source, $pattern)) "Frontend API function missing: $functionName"
}

$resolvedOpenApiPath = Resolve-ProjectPath $OpenApiPath
Assert-True (Test-Path -LiteralPath $resolvedOpenApiPath) "OpenAPI file missing: $resolvedOpenApiPath"

$rawSpec = Get-Content -Raw -LiteralPath $resolvedOpenApiPath
$spec = $rawSpec | ConvertFrom-Json

Assert-True ($spec.openapi -like "3.0.*") "OpenAPI version must be 3.0.x."
Assert-True ($spec.info.title -eq "OSMU MVP API") "OpenAPI title mismatch."
Assert-True ([bool]$spec.components.securitySchemes.bearerAuth) "bearerAuth security scheme missing."
Assert-True ([bool]$spec.components.securitySchemes.osmuAccessKey) "osmuAccessKey security scheme missing."
Assert-True ([bool]$spec.components.securitySchemes.awsSigV4) "awsSigV4 security scheme missing."

$requiredOperations = @(
    @("/api/health", "get", "getHealth"),
    @("/api/storage/health", "get", "getStorageHealth"),
    @("/api/database/health", "get", "getDatabaseHealth"),
    @("/api/auth/login", "post", "login"),
    @("/api/auth/refresh", "post", "refreshSession"),
    @("/api/auth/logout", "post", "logout"),
    @("/api/users/me", "get", "getCurrentUser"),
    @("/api/developer/s3-client-config", "get", "getS3ClientConfig"),
    @("/api/dashboard/layout", "get", "getDashboardLayout"),
    @("/api/dashboard/layout/widgets", "get", "getDashboardWidgetCatalog"),
    @("/api/dashboard/layout/presets", "get", "getDashboardLayoutPresets"),
    @("/api/dashboard/layout/defaults", "get", "getDashboardLayoutDefaults"),
    @("/api/dashboard/layout/defaults", "put", "saveDashboardLayoutDefault"),
    @("/api/dashboard/layout/defaults/{targetType}/{targetId}", "delete", "deleteDashboardLayoutDefault"),
    @("/api/dashboard/layout/presets", "post", "createDashboardLayoutPreset"),
    @("/api/dashboard/layout/presets/import", "post", "importDashboardLayoutPreset"),
    @("/api/dashboard/layout/preset-bundle/export", "get", "exportDashboardLayoutPresetBundle"),
    @("/api/dashboard/layout/preset-bundle/import", "post", "importDashboardLayoutPresetBundle"),
    @("/api/dashboard/layout", "put", "saveDashboardLayout"),
    @("/api/dashboard/layout/presets/{presetId}", "put", "applyDashboardLayoutPreset"),
    @("/api/dashboard/layout/presets/{presetId}", "patch", "updateDashboardLayoutPreset"),
    @("/api/dashboard/layout/presets/{presetId}/export", "get", "exportDashboardLayoutPreset"),
    @("/api/dashboard/layout", "delete", "deleteDashboardLayout"),
    @("/api/dashboard/layout/presets/{presetId}", "delete", "deleteDashboardLayoutPreset"),
    @("/api/admin/users", "get", "getUsers"),
    @("/api/admin/users", "post", "createUser"),
    @("/api/admin/users/{userId}/status", "patch", "updateUserStatus"),
    @("/api/admin/organizations", "get", "getOrganizations"),
    @("/api/admin/organizations", "post", "createOrganization"),
    @("/api/admin/organizations/usage", "get", "getOrganizationUsage"),
    @("/api/admin/billing/pricing-policy", "get", "getBillingPricingPolicy"),
    @("/api/admin/billing/pricing-policy", "put", "saveBillingPricingPolicy"),
    @("/api/admin/billing/pricing-policy-proposals", "get", "getBillingPricingPolicyProposals"),
    @("/api/admin/billing/pricing-policy-proposals", "post", "createBillingPricingPolicyProposal"),
    @("/api/admin/billing/pricing-policy-proposals/{proposalId}/approve", "post", "approveBillingPricingPolicyProposal"),
    @("/api/admin/billing/pricing-policy-proposals/{proposalId}/commercial-approval", "post", "approveBillingPricingPolicyProposalPriceList"),
    @("/api/admin/billing/chargeback-preview", "get", "getChargebackPreview"),
    @("/api/admin/billing/chargeback-alerts", "get", "getChargebackAlerts"),
    @("/api/admin/billing/chargeback-alert-notifications/preview", "get", "getChargebackAlertNotificationPreview"),
    @("/api/admin/billing/chargeback-alert-notifications/outbox", "get", "getChargebackAlertNotificationOutbox"),
    @("/api/admin/billing/chargeback-alert-notifications/outbox", "post", "queueChargebackAlertNotifications"),
    @("/api/admin/billing/chargeback-alert-notifications/outbox/{deliveryId}/adapter-result", "post", "recordChargebackAlertNotificationAdapterResult"),
    @("/api/admin/billing/chargeback-alert-notifications/outbox/{deliveryId}/adapter-send", "post", "sendChargebackAlertNotificationAdapter"),
    @("/api/admin/billing/chargeback-adapter-retry-worker/status", "get", "getChargebackAdapterRetryWorkerStatus"),
    @("/api/admin/billing/chargeback-adapter-retry-worker/run", "post", "runChargebackAdapterRetryWorker"),
    @("/api/admin/billing/payment-provider-adapter-readiness", "get", "getChargebackPaymentProviderAdapterReadiness"),
    @("/api/admin/billing/chargeback-invoice-drafts", "get", "getChargebackInvoiceDrafts"),
    @("/api/admin/billing/chargeback-invoice-drafts", "post", "createChargebackInvoiceDrafts"),
    @("/api/admin/billing/chargeback-invoice-drafts/{invoiceId}/approve", "post", "approveChargebackInvoiceDraft"),
    @("/api/admin/billing/chargeback-invoice-drafts/{invoiceId}/finalize", "post", "finalizeChargebackInvoiceDraft"),
    @("/api/admin/billing/chargeback-invoices", "get", "getChargebackFinalInvoices"),
    @("/api/admin/billing/chargeback-invoices/{invoiceId}/payment-request", "post", "requestChargebackInvoicePayment"),
    @("/api/admin/billing/chargeback-invoices/{invoiceId}/payment-provider-handoff/preview", "get", "getChargebackPaymentProviderHandoffPreview"),
    @("/api/admin/billing/chargeback-invoices/{invoiceId}/payment-provider-handoff", "post", "queueChargebackPaymentProviderHandoff"),
    @("/api/admin/billing/chargeback-payment-provider-handoffs", "get", "getChargebackPaymentProviderHandoffs"),
    @("/api/admin/billing/chargeback-payment-provider-handoffs/{handoffId}/adapter-result", "post", "recordChargebackPaymentProviderHandoffAdapterResult"),
    @("/api/admin/billing/chargeback-payment-provider-handoffs/{handoffId}/adapter-send", "post", "sendChargebackPaymentProviderHandoffAdapter"),
    @("/api/admin/billing/chargeback-invoices/{invoiceId}/payment-record", "post", "recordChargebackInvoicePayment"),
    @("/api/admin/billing/chargeback-preview/export.csv", "get", "downloadChargebackPreviewCsv"),
    @("/api/admin/billing/chargeback-invoice-draft/export.csv", "get", "downloadChargebackInvoiceDraftCsv"),
    @("/api/admin/organizations/{organizationId}", "delete", "deleteOrganization"),
    @("/api/admin/storage-expansion/requests", "get", "getStorageExpansionRequests"),
    @("/api/admin/storage-expansion/summary", "get", "getStorageExpansionSummary"),
    @("/api/admin/storage-expansion/runner-preflight", "get", "getStorageExpansionRunnerPreflight"),
    @("/api/admin/storage-expansion/requests", "post", "createStorageExpansionRequest"),
    @("/api/admin/storage-expansion/requests/{requestId}/manifest", "get", "getStorageExpansionRequestManifest"),
    @("/api/admin/storage-expansion/requests/{requestId}/manifest/{artifact}", "get", "downloadStorageExpansionManifestArtifact"),
    @("/api/admin/storage-expansion/requests/{requestId}/execution-plan", "post", "createStorageExpansionExecutionPlan"),
    @("/api/admin/storage-expansion/requests/{requestId}/gitops-plan", "post", "createStorageExpansionGitOpsPlan"),
    @("/api/admin/storage-expansion/requests/{requestId}/gitops-artifacts/bundle", "get", "downloadStorageExpansionGitOpsArtifactBundle"),
    @("/api/admin/storage-expansion/requests/{requestId}/dry-run-execution", "post", "recordStorageExpansionDryRunExecution"),
    @("/api/admin/storage-expansion/requests/{requestId}/dry-run-runner", "post", "runStorageExpansionDryRunExecution"),
    @("/api/admin/storage-expansion/requests/{requestId}/apply-runner", "post", "runStorageExpansionApplyExecution"),
    @("/api/admin/storage-expansion/requests/{requestId}/rollback-runner", "post", "runStorageExpansionRollbackExecution"),
    @("/api/admin/storage-expansion/requests/{requestId}/gitops-pr-runner", "post", "runStorageExpansionGitOpsPrExecution"),
    @("/api/admin/storage-expansion/requests/{requestId}/gitops-pr-execution", "post", "recordStorageExpansionGitOpsPrExecution"),
    @("/api/admin/storage-expansion/requests/{requestId}/executions", "get", "getStorageExpansionExecutions"),
    @("/api/admin/storage-expansion/requests/{requestId}/executions", "post", "createStorageExpansionExecutionRecord"),
    @("/api/admin/storage-expansion/requests/{requestId}/executions/{executionId}/apply", "post", "applyStorageExpansionExecutionRecord"),
    @("/api/admin/storage-expansion/requests/{requestId}/status", "patch", "updateStorageExpansionRequestStatus"),
    @("/api/admin/storage-expansion/execution-log-retention/status", "get", "getStorageExpansionExecutionLogRetentionStatus"),
    @("/api/admin/storage-expansion/execution-log-retention/run", "post", "runStorageExpansionExecutionLogRetention"),
    @("/api/storage-profiles", "get", "getStorageProfiles"),
    @("/api/storage-profile-requests", "get", "getStorageProfileRequests"),
    @("/api/buckets/{bucketName}/storage-profile", "get", "getBucketStorageProfile"),
    @("/api/buckets/{bucketName}/storage-profile-requests", "post", "createStorageProfileRequest"),
    @("/api/admin/storage-profile-requests", "get", "getAdminStorageProfileRequests"),
    @("/api/admin/storage-profile-requests/{requestId}/status", "patch", "updateStorageProfileRequestStatus"),
    @("/api/admin/storage-profile-requests/{requestId}/apply", "post", "applyStorageProfileRequest"),
    @("/api/buckets", "get", "getBuckets"),
    @("/api/buckets", "post", "createBucket"),
    @("/api/buckets/{bucketName}", "get", "getBucket"),
    @("/api/buckets/{bucketName}", "delete", "deleteBucket"),
    @("/api/buckets/{bucketName}/sync", "post", "syncBucketUsage"),
    @("/api/buckets/{bucketName}/permissions", "get", "getBucketPermissions"),
    @("/api/buckets/{bucketName}/permissions", "post", "grantBucketPermissions"),
    @("/api/buckets/{bucketName}/permissions/{permissionId}", "delete", "revokeBucketPermission"),
    @("/api/buckets/{bucketName}/tags", "get", "getBucketTags"),
    @("/api/buckets/{bucketName}/tags", "put", "putBucketTags"),
    @("/api/buckets/{bucketName}/tags", "delete", "deleteBucketTags"),
    @("/api/buckets/{bucketName}/lifecycle", "get", "getBucketLifecycleS3Xml"),
    @("/api/buckets/{bucketName}/lifecycle", "put", "putBucketLifecycleS3Xml"),
    @("/api/buckets/{bucketName}/lifecycle", "delete", "deleteBucketLifecycleS3Xml"),
    @("/api/buckets/{bucketName}/objects", "get", "getObjects"),
    @("/api/buckets/{bucketName}/objects", "post", "uploadObject"),
    @("/api/buckets/{bucketName}/objects/{objectKey}", "get", "downloadObject"),
    @("/api/buckets/{bucketName}/objects/{objectKey}", "delete", "deleteObject"),
    @("/api/buckets/{bucketName}/objects/tags", "put", "updateObjectTags"),
    @("/api/buckets/{bucketName}/objects/metadata/{objectKey}", "get", "getObjectMetadata"),
    @("/api/buckets/{bucketName}/objects/versions/{objectKey}", "get", "listObjectVersions"),
    @("/api/buckets/{bucketName}/objects/versions/{versionId}/restore/{objectKey}", "post", "restoreObjectVersion"),
    @("/api/buckets/{bucketName}/objects/versions/{versionId}/download/{objectKey}", "get", "downloadObjectVersion"),
    @("/api/buckets/{bucketName}/objects/versions/{versionId}/delete/{objectKey}", "delete", "deleteObjectVersion"),
    @("/api/buckets/{bucketName}/objects/restore/{objectKey}", "post", "restoreObject"),
    @("/api/buckets/{bucketName}/objects/purge/{objectKey}", "post", "purgeObject"),
    @("/api/buckets/{bucketName}/objects/presigned-upload", "post", "createPresignedUploadUrl"),
    @("/api/buckets/{bucketName}/objects/presigned-download", "post", "createPresignedDownloadUrl"),
    @("/api/buckets/{bucketName}/objects/share-links", "post", "createObjectShareLink"),
    @("/api/buckets/{bucketName}/objects/share-links", "get", "getObjectShareLinks"),
    @("/api/buckets/{bucketName}/objects/share-links/cleanup", "post", "cleanupObjectShareLinks"),
    @("/api/buckets/{bucketName}/objects/share-links/{linkId}", "delete", "deleteObjectShareLink"),
    @("/api/public/share-links/{token}", "get", "downloadObjectShareLink"),
    @("/api/buckets/{bucketName}/objects/presigned-upload/complete", "post", "completePresignedUpload"),
    @("/api/buckets/{bucketName}/objects/multipart-upload", "post", "createMultipartUpload"),
    @("/api/buckets/{bucketName}/objects/multipart-upload/refresh", "post", "refreshMultipartUpload"),
    @("/api/buckets/{bucketName}/objects/multipart-upload/parts", "post", "listMultipartUploadParts"),
    @("/api/buckets/{bucketName}/objects/multipart-upload/complete", "post", "completeMultipartUpload"),
    @("/api/buckets/{bucketName}/objects/multipart-upload/abort", "post", "abortMultipartUpload"),
    @("/api/access-keys", "get", "getAccessKeys"),
    @("/api/access-keys", "post", "createAccessKey"),
    @("/api/access-keys/bulk-disable", "post", "bulkDisableAccessKeys"),
    @("/api/access-keys/{keyId}", "delete", "deleteAccessKey"),
    @("/api/access-keys/{keyId}/rotate", "post", "rotateAccessKey"),
    @("/api/admin/usage", "get", "getUsage"),
    @("/api/admin/monitoring/data-flow", "get", "getDataFlowMonitoring"),
    @("/api/admin/monitoring/data-flow/daily-rollup", "get", "getDataFlowDailyRollup"),
    @("/api/admin/monitoring/data-flow/daily-rollup/materialize", "post", "materializeDataFlowDailyRollup"),
    @("/api/admin/monitoring/data-flow/daily-rollup/materialized", "get", "getMaterializedDataFlowDailyRollup"),
    @("/api/admin/monitoring/data-flow/daily-rollup/export.csv", "get", "downloadDataFlowDailyRollupCsv"),
    @("/api/admin/quota-policies", "get", "getQuotaPolicies"),
    @("/api/admin/quota-policies/history", "get", "getQuotaPolicyHistory"),
    @("/api/admin/quota-policies/{targetType}/{targetId}", "put", "saveQuotaPolicy"),
    @("/api/admin/quota-policies/{targetType}/{targetId}", "delete", "deleteQuotaPolicy"),
    @("/api/admin/object-share-policy", "get", "getObjectSharePolicy"),
    @("/api/admin/object-share-policy", "put", "saveObjectSharePolicy"),
    @("/api/admin/object-share-analytics", "get", "getObjectShareAnalytics"),
    @("/api/admin/system/status", "get", "getSystemStatus"),
    @("/api/admin/backup/status", "get", "getBackupStatus"),
    @("/api/admin/backup/restore-drill-evidence", "get", "getBackupRestoreDrillEvidence"),
    @("/api/admin/audit-logs", "get", "getAuditLogs"),
    @("/api/admin/audit-logs/export.csv", "get", "downloadAuditLogsCsv"),
    @("/api/admin/object-retention/status", "get", "getObjectRetentionStatus"),
    @("/api/admin/object-retention/policy", "put", "updateObjectRetentionPolicy"),
    @("/api/admin/object-retention/purge", "post", "runObjectRetentionPurge"),
    @("/api/admin/object-lifecycle/rules", "get", "getObjectLifecycleRules"),
    @("/api/admin/object-lifecycle/rules", "post", "saveObjectLifecycleRule"),
    @("/api/admin/object-lifecycle/conflicts", "get", "getObjectLifecycleConflicts"),
    @("/api/admin/object-lifecycle/s3-xml", "get", "getObjectLifecycleS3Xml"),
    @("/api/admin/object-lifecycle/s3-xml", "post", "importObjectLifecycleS3Xml"),
    @("/api/admin/object-lifecycle/rules/{ruleId}", "delete", "deleteObjectLifecycleRule"),
    @("/api/admin/object-lifecycle/rules/{ruleId}/dry-run", "get", "dryRunObjectLifecycleRule"),
    @("/api/s3", "get", "s3ListBuckets"),
    @("/api/s3", "head", "s3HeadService"),
    @("/api/s3/{bucketName}", "put", "s3CreateBucket"),
    @("/api/s3/{bucketName}", "head", "s3HeadBucket"),
    @("/api/s3/{bucketName}", "get", "s3ListObjectsOrBucketConfig"),
    @("/api/s3/{bucketName}", "post", "s3DeleteMultipleObjects"),
    @("/api/s3/{bucketName}", "delete", "s3DeleteBucketOrBucketConfig"),
    @("/api/s3/{bucketName}/{objectKey}", "put", "s3PutObjectCopyObjectOrUploadPart"),
    @("/api/s3/{bucketName}/{objectKey}", "head", "s3HeadObject"),
    @("/api/s3/{bucketName}/{objectKey}", "get", "s3GetObjectTaggingOrListParts"),
    @("/api/s3/{bucketName}/{objectKey}", "post", "s3InitiateOrCompleteMultipartUpload"),
    @("/api/s3/{bucketName}/{objectKey}", "delete", "s3DeleteObjectTaggingOrAbortMultipartUpload")
)

foreach ($operation in $requiredOperations) {
    Assert-Operation $spec $operation[0] $operation[1] $operation[2]
}

$operationIds = New-Object System.Collections.Generic.List[string]
foreach ($pathProperty in $spec.paths.PSObject.Properties) {
    foreach ($methodProperty in $pathProperty.Value.PSObject.Properties) {
        $operationId = $methodProperty.Value.operationId
        if ($operationId) {
            $operationIds.Add([string]$operationId)
        }
    }
}

$duplicates = $operationIds | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name
Assert-True (-not $duplicates) "Duplicate OpenAPI operationId values: $($duplicates -join ', ')"

$frontendSourcePath = Join-Path $root "osmu-frontend\src\services\api.js"
$frontendSource = Get-Content -Raw -LiteralPath $frontendSourcePath
$frontendFunctions = @(
    "getHealth",
    "getStorageHealth",
    "getDatabaseHealth",
    "login",
    "refreshSession",
    "logout",
    "getCurrentUser",
    "getS3ClientConfig",
    "getDashboardLayout",
    "getDashboardWidgetCatalog",
    "getDashboardLayoutPresets",
    "getDashboardLayoutDefaults",
    "saveDashboardLayoutDefault",
    "deleteDashboardLayoutDefault",
    "createDashboardLayoutPreset",
    "importDashboardLayoutPreset",
    "saveDashboardLayout",
    "applyDashboardLayoutPreset",
    "updateDashboardLayoutPreset",
    "exportDashboardLayoutPreset",
    "deleteDashboardLayout",
    "deleteDashboardLayoutPreset",
    "getBuckets",
    "createBucket",
    "deleteBucket",
    "syncBucketUsage",
    "getBucketPermissions",
    "grantBucketPermissions",
    "revokeBucketPermission",
    "getBucketLifecycleS3Xml",
    "putBucketLifecycleS3Xml",
    "deleteBucketLifecycleS3Xml",
    "getBucketTags",
    "putBucketTags",
    "deleteBucketTags",
    "getObjects",
    "uploadObject",
    "updateObjectTags",
    "getObjectMetadata",
    "listObjectVersions",
    "restoreObjectVersion",
    "downloadObjectVersion",
    "deleteObjectVersion",
    "createPresignedUploadUrl",
    "createObjectShareLink",
    "getObjectShareLinks",
    "cleanupObjectShareLinks",
    "deleteObjectShareLink",
    "completePresignedUpload",
    "createMultipartUpload",
    "refreshMultipartUpload",
    "listMultipartUploadParts",
    "completeMultipartUpload",
    "abortMultipartUpload",
    "getAccessKeys",
    "createAccessKey",
    "bulkDisableAccessKeys",
    "deleteAccessKey",
    "rotateAccessKey",
    "getUsage",
    "getQuotaPolicies",
    "getQuotaPolicyHistory",
    "saveQuotaPolicy",
    "deleteQuotaPolicy",
    "getObjectSharePolicy",
    "saveObjectSharePolicy",
    "getObjectShareAnalytics",
    "getBackupStatus",
    "getBackupRestoreDrillEvidence",
    "getObjectRetentionStatus",
    "updateObjectRetentionPolicy",
    "runObjectRetentionPurge",
    "getObjectLifecycleRules",
    "getObjectLifecycleConflicts",
    "getObjectLifecycleS3Xml",
    "importObjectLifecycleS3Xml",
    "saveObjectLifecycleRule",
    "deleteObjectLifecycleRule",
    "dryRunObjectLifecycleRule",
    "getAuditLogs",
    "downloadAuditLogsCsv",
    "materializeDataFlowDailyRollup",
    "getMaterializedDataFlowDailyRollup",
    "downloadDataFlowDailyRollupCsv",
    "getUsers",
    "getOrganizations",
    "getOrganizationUsage",
    "getChargebackPreview",
    "getChargebackAlerts",
    "getChargebackAlertNotificationPreview",
    "queueChargebackAlertNotifications",
    "getChargebackAlertNotificationOutbox",
    "recordChargebackAlertNotificationAdapterResult",
    "getChargebackAdapterRetryWorkerStatus",
    "runChargebackAdapterRetryWorker",
    "getBillingPricingPolicyProposals",
    "createBillingPricingPolicyProposal",
    "approveBillingPricingPolicyProposal",
    "approveBillingPricingPolicyProposalPriceList",
    "getChargebackInvoiceDrafts",
    "createChargebackInvoiceDrafts",
    "approveChargebackInvoiceDraft",
    "finalizeChargebackInvoiceDraft",
    "getChargebackFinalInvoices",
    "requestChargebackInvoicePayment",
    "getChargebackPaymentProviderHandoffPreview",
    "queueChargebackPaymentProviderHandoff",
    "getChargebackPaymentProviderHandoffs",
    "recordChargebackPaymentProviderHandoffAdapterResult",
    "recordChargebackInvoicePayment",
    "downloadChargebackPreviewCsv",
    "createOrganization",
    "deleteOrganization",
    "getStorageExpansionRequests",
    "createStorageExpansionRequest",
    "getStorageExpansionRequestManifest",
    "downloadStorageExpansionManifestArtifact",
    "createStorageExpansionExecutionPlan",
    "createStorageExpansionGitOpsPlan",
    "downloadStorageExpansionGitOpsArtifactBundle",
    "recordStorageExpansionDryRunExecution",
    "runStorageExpansionDryRunExecution",
    "runStorageExpansionApplyExecution",
    "runStorageExpansionRollbackExecution",
    "recordStorageExpansionGitOpsPrExecution",
    "getStorageExpansionExecutions",
    "createStorageExpansionExecutionRecord",
    "applyStorageExpansionExecutionRecord",
    "updateStorageExpansionRequestStatus",
    "getStorageExpansionExecutionLogRetentionStatus",
    "runStorageExpansionExecutionLogRetention",
    "getStorageProfiles",
    "getStorageProfileRequests",
    "getBucketStorageProfile",
    "createStorageProfileRequest",
    "getAdminStorageProfileRequests",
    "updateStorageProfileRequestStatus",
    "applyStorageProfileRequest",
    "createUser",
    "updateUserStatus"
)

foreach ($functionName in $frontendFunctions) {
    Assert-FrontendFunction $frontendSource $functionName
}

Write-Host "OpenAPI MVP contract verified."
Write-Host "Spec: $resolvedOpenApiPath"
Write-Host "Operations: $($operationIds.Count)"
Write-Host "Frontend API functions checked: $($frontendFunctions.Count)"
