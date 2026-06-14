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
    @("/api/admin/users", "get", "getUsers"),
    @("/api/admin/users", "post", "createUser"),
    @("/api/admin/users/{userId}/status", "patch", "updateUserStatus"),
    @("/api/admin/organizations", "get", "getOrganizations"),
    @("/api/admin/organizations", "post", "createOrganization"),
    @("/api/admin/organizations/usage", "get", "getOrganizationUsage"),
    @("/api/admin/organizations/{organizationId}", "delete", "deleteOrganization"),
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
    @("/api/access-keys/{keyId}", "delete", "deleteAccessKey"),
    @("/api/admin/usage", "get", "getUsage"),
    @("/api/admin/quota-policies", "get", "getQuotaPolicies"),
    @("/api/admin/quota-policies/history", "get", "getQuotaPolicyHistory"),
    @("/api/admin/quota-policies/{targetType}/{targetId}", "put", "saveQuotaPolicy"),
    @("/api/admin/quota-policies/{targetType}/{targetId}", "delete", "deleteQuotaPolicy"),
    @("/api/admin/object-share-policy", "get", "getObjectSharePolicy"),
    @("/api/admin/object-share-policy", "put", "saveObjectSharePolicy"),
    @("/api/admin/object-share-analytics", "get", "getObjectShareAnalytics"),
    @("/api/admin/system/status", "get", "getSystemStatus"),
    @("/api/admin/backup/status", "get", "getBackupStatus"),
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
    "deleteAccessKey",
    "getUsage",
    "getQuotaPolicies",
    "getQuotaPolicyHistory",
    "saveQuotaPolicy",
    "deleteQuotaPolicy",
    "getObjectSharePolicy",
    "saveObjectSharePolicy",
    "getObjectShareAnalytics",
    "getBackupStatus",
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
    "getUsers",
    "getOrganizations",
    "getOrganizationUsage",
    "createOrganization",
    "deleteOrganization",
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
