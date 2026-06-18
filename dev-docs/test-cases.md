### TC-OBJECT-004D-2

- Feature: Prefix/tag scoped object lifecycle rule CRUD and purge.
- Preconditions: ADMIN user is logged in. Objects or object versions exist with mixed prefixes/tags.
- Input: `POST /api/admin/object-lifecycle/rules`, `GET /api/admin/object-lifecycle/rules`, `DELETE /api/admin/object-lifecycle/rules/{ruleId}`.
- Steps: Create a rule with prefix `videos/raw/` and tag `stage=raw`, run matching retention job, list rules, then delete the rule.
- Expected: Rules list in priority order. Only matching trash objects or object versions older than the rule retention window are purged. Non-matching prefix/tag data remains. Save/delete audit events are written.
- Priority: P1
- Automated: `AdminObjectRetentionControllerTest.adminCanManageLifecycleRules`, `ObjectRetentionPurgeJobTest.lifecycleRulePurgesMatchingDeletedObjectByPrefixAndTags`, `ObjectVersionRetentionPurgeJobTest.lifecycleRulePurgesMatchingVersionByPrefixAndTags`

### TC-OBJECT-004D-3

- Feature: Lifecycle rule dry-run preview.
- Preconditions: ADMIN user is logged in. A lifecycle rule exists. Matching and non-matching trash objects or object versions exist.
- Input: `GET /api/admin/object-lifecycle/rules/{ruleId}/dry-run?limit=50`
- Steps: Call dry-run for a `TRASH_OBJECT` rule and an `OBJECT_VERSION` rule before purge.
- Expected: API returns cutoff, previewLimit, purgeBatchSize, candidateCount, candidateBytes, truncated flag, and matched candidates only. No object/version metadata or storage is deleted.
- Priority: P1
- Automated: `AdminObjectLifecycleRuleDryRunControllerTest.adminCanDryRunTrashLifecycleRule`, `AdminObjectLifecycleRuleDryRunControllerTest.adminCanDryRunVersionLifecycleRule`

### TC-OBJECT-004D-4

- Feature: Lifecycle rule conflict report.
- Preconditions: ADMIN user is logged in. Two enabled rules share target type and overlapping prefix/tag scope.
- Input: `GET /api/admin/object-lifecycle/conflicts`
- Steps: Create a broad rule and a narrower rule with compatible tags, then request conflict report.
- Expected: API returns ruleCount, conflictCount, conflictType, severity, targetType, firstRule, secondRule, and reason. Rules with different target type or incompatible shared tag values are not reported.
- Priority: P1
- Automated: `AdminObjectRetentionControllerTest.adminCanReadLifecycleRuleConflictReport`

### TC-OBJECT-004D-5

- Feature: S3 Lifecycle XML export/import.
- Preconditions: ADMIN user is logged in. Lifecycle rules can be created.
- Input: `GET /api/admin/object-lifecycle/s3-xml`, `POST /api/admin/object-lifecycle/s3-xml`
- Steps: Create a rule, export XML, then import XML with `Expiration/Days` and `NoncurrentVersionExpiration/NoncurrentDays`.
- Expected: Export includes LifecycleConfiguration XML. Import creates OSMU rules with generated ids, priority from XML order, default batch size 100, correct target type, prefix, tags, and retention days.
- Priority: P1
- Automated: `AdminObjectRetentionControllerTest.adminCanExportAndImportS3LifecycleXml`

### TC-OBJECT-004D-6

- Feature: Bucket-scoped S3 lifecycle API.
- Preconditions: ADMIN user is logged in. Target bucket exists.
- Input: `PUT /api/buckets/{bucketName}/lifecycle`, `GET /api/buckets/{bucketName}/lifecycle`, `DELETE /api/buckets/{bucketName}/lifecycle`
- Steps: Put LifecycleConfiguration XML for one bucket, get the bucket XML, replace it with another XML, then delete it.
- Expected: Imported rules have `bucketName` equal to the path bucket. PUT replaces only that bucket's lifecycle rules. GET returns only bucket-scoped XML. DELETE removes the bucket-scoped rules and writes audit log.
- Priority: P1
- Automated: `BucketLifecycleControllerTest.adminCanPutGetAndDeleteBucketLifecycleConfiguration`

### TC-OBJECT-004D-7

- Feature: Raw XML bucket lifecycle compatibility.
- Preconditions: ADMIN user is logged in. Target bucket exists.
- Input: `PUT /api/buckets/{bucketName}/lifecycle` with `Content-Type: application/xml`, `GET /api/buckets/{bucketName}/lifecycle` with `Accept: application/xml`.
- Steps: Put raw LifecycleConfiguration XML, then request raw XML response and JSON response.
- Expected: Raw PUT returns `200 OK`. Raw GET returns XML content type and LifecycleConfiguration body. JSON GET still returns `ruleCount` and XML wrapper.
- Priority: P1
- Automated: `BucketLifecycleControllerTest.adminCanUseRawXmlBucketLifecycleConfiguration`

### TC-OBJECT-004D-8

- Feature: S3-style lifecycle query alias.
- Preconditions: ADMIN user is logged in. Target bucket exists.
- Input: `PUT/GET/DELETE /api/s3/{bucketName}?lifecycle` with raw XML.
- Steps: Put raw LifecycleConfiguration XML through query alias, get raw XML through query alias, then delete through query alias.
- Expected: Alias uses the same bucket lifecycle rules. GET returns XML content type. DELETE removes the bucket-scoped lifecycle config.
- Priority: P1
- Automated: `BucketLifecycleControllerTest.adminCanUseS3StyleLifecycleQueryAlias`

### TC-OBJECT-004D-9

- Feature: S3-style lifecycle query alias access key auth.
- Preconditions: Target bucket exists. Active access keys exist for the bucket with `ADMIN` scope and with `READ`-only scope.
- Input: `PUT/GET/DELETE /api/s3/{bucketName}?lifecycle` with `X-OSMU-Access-Key` and `X-OSMU-Secret-Key`.
- Steps: Use the `ADMIN` scoped key to put/get/delete lifecycle XML, then use the `READ`-only key to request lifecycle XML.
- Expected: `ADMIN` scoped key succeeds without Bearer JWT. `READ`-only key is rejected with `403`.
- Expected error body: S3 XML with `AccessDenied`.
- Priority: P1
- Automated: `BucketLifecycleControllerTest.accessKeyWithAdminScopeCanUseS3StyleLifecycleQueryAlias`, `BucketLifecycleControllerTest.accessKeyWithoutAdminScopeCannotUseS3StyleLifecycleQueryAlias`

### TC-OBJECT-004D-10

- Feature: Bucket-scoped lifecycle purge safety.
- Preconditions: Two buckets contain matching prefix/tag deleted objects or historical versions.
- Input: A lifecycle rule with `bucketName = bucket-a`.
- Steps: Run object trash purge and object version purge jobs.
- Expected: Only candidates in `bucket-a` are purged. Matching candidates in `bucket-b` remain.
- Priority: P1
- Automated: `ObjectRetentionPurgeJobTest.bucketScopedLifecycleRuleOnlyPurgesMatchingBucket`, `ObjectVersionRetentionPurgeJobTest.bucketScopedLifecycleRuleOnlyPurgesMatchingBucketVersions`

### TC-DEVELOPER-001

- Feature: Developer S3 client config.
- Preconditions: User is logged in. Backend has `OSMU_S3_PUBLIC_ENDPOINT`, `OSMU_S3_REGION`, and virtual-hosted-style suffix settings.
- Input: `GET /api/developer/s3-client-config`.
- Steps: Login, call the config endpoint, then open DeveloperPage and verify the endpoint summary and client snippets.
- Expected: API returns endpoint, region, signature version, service name, path-style support, and virtual-hosted-style suffixes without exposing secret values. DeveloperPage displays the returned values and renders AWS CLI, s3fs-fuse, and goofys snippets with placeholder credentials.
- Priority: P1
- Automated: `DeveloperControllerTest.s3ClientConfigReturnsPublicEndpointAndRegion`, `api-query.test.js getS3ClientConfig reads developer S3 client settings endpoint`, `HomeView.test.js stable selectors`

### TC-S3-BUCKET-001

- Feature: S3 bucket existence and location compatibility.
- Preconditions: Target bucket exists. Active access key has at least one bucket scope permission.
- Input: `HEAD /api/s3/{bucketName}`, `GET /api/s3/{bucketName}?location` with `X-OSMU-Access-Key` and `X-OSMU-Secret-Key`.
- Steps: Create a bucket, create a write-only access key, call bucket HEAD, then call bucket location XML.
- Expected: HEAD returns `200` and `x-amz-bucket-region`. Location returns `200`, `x-amz-bucket-region`, and S3-compatible `LocationConstraint` XML.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanCheckBucketAndLocationThroughS3StylePath`

### TC-S3-BUCKET-002

- Feature: S3 root bucket listing and service HEAD probe.
- Preconditions: Two buckets exist. Active access key is scoped to only one bucket.
- Input: `GET /api/s3` and `HEAD /api/s3` with `X-OSMU-Access-Key` and `X-OSMU-Secret-Key`, plus SigV4 signed `HEAD /api/s3`.
- Steps: Create two buckets, create an access key scoped to the first bucket, request the S3 root bucket list, then call root service HEAD through Access Key headers and SigV4 headers.
- Expected: `GET` response returns S3-compatible `ListAllMyBucketsResult` XML. The scoped bucket is present and the unscoped bucket is not present. `HEAD /api/s3` returns `200 OK` with no body when credentials are valid.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanListScopedBucketsThroughS3Root`, `S3ObjectControllerTest.accessKeyCanHeadS3RootService`, `S3ObjectControllerTest.awsSigV4AuthorizationCanHeadS3RootService`

### TC-S3-BUCKET-003

- Feature: S3-style bucket create/delete alias.
- Preconditions: Admin can authenticate with Bearer JWT. Empty target bucket can receive an access key with `ADMIN` scope after creation.
- Input: `PUT /api/s3/{bucketName}` with `Authorization: Bearer <token>`, then `DELETE /api/s3/{bucketName}` with `X-OSMU-Access-Key` and `X-OSMU-Secret-Key`.
- Steps: Create a bucket through the S3-style path, create an access key with `ADMIN` scope for the bucket, HEAD the bucket through the access key, delete the empty bucket through the S3-style path, then HEAD the bucket again.
- Expected: Create returns `200`, `Location: /{bucketName}`, and `x-amz-bucket-region`. Access key HEAD returns `200`. Delete returns `204`. HEAD after delete returns `404 NoSuchBucket`.
- Priority: P1
- Automated: `S3ObjectControllerTest.bearerCanCreateAndAccessKeyCanDeleteBucketThroughS3StylePath`

### TC-S3-AUTH-001

- Feature: AWS SigV4 header authorization for S3-style alias.
- Preconditions: Target bucket exists. Active access key was created after encrypted signing secret support and has required bucket scopes.
- Input: `Authorization: AWS4-HMAC-SHA256 Credential=<accessKey>/<date>/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=<signature>` without `X-OSMU-Secret-Key`.
- Steps: Sign `GET /api/s3` and `PUT/GET /api/s3/{bucketName}/{objectKey}` with the returned access key secret. Send the requests without OSMU secret header.
- Expected: Backend validates the SigV4 canonical request and applies the same bucket scope permissions. Root list returns only scoped buckets. PUT and GET object succeed.
- Priority: P1
- Automated: `S3ObjectControllerTest.awsSigV4AuthorizationCanListScopedBucketsWithoutSecretHeader`, `S3ObjectControllerTest.awsSigV4AuthorizationCanPutAndGetObjectWithoutSecretHeader`

### TC-S3-AUTH-001A

- Feature: AWS SigV4 query/presigned URL authorization for S3-style alias.
- Preconditions: Target bucket exists. Active access key was created after encrypted signing secret support and has `READ` scope. Object exists.
- Input: `GET /api/s3/{bucketName}/{objectKey}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...&X-Amz-Date=...&X-Amz-Expires=...&X-Amz-SignedHeaders=host&X-Amz-Signature=...` without `Authorization` or `X-OSMU-Secret-Key`.
- Steps: Upload an object, sign a presigned URL query using the returned access key secret, then GET the object through the S3-style alias.
- Expected: Backend validates the SigV4 query canonical request with `UNSIGNED-PAYLOAD`, applies access key `READ` scope, and returns the object body.
- Expected error body: expired presigned URL returns S3 XML with `AccessDenied`.
- Priority: P1
- Automated: `S3ObjectControllerTest.awsSigV4PresignedUrlCanGetObjectWithoutSecretHeader`, `S3ObjectControllerTest.awsSigV4PresignedUrlRejectsExpiredSignature`

### TC-S3-AUTH-001B

- Feature: Virtual-hosted-style S3 object routing.
- Preconditions: Target bucket exists. `osmu.s3.virtual-hosted-style.enabled=true` and `osmu.s3.virtual-hosted-style.domain-suffixes=localhost`.
- Input: `Host: {bucket}.localhost`, `PUT/GET /api/s3/{objectKey}` with Access Key headers or AWS SigV4 headers.
- Steps: Upload and download an object through virtual-hosted-style path, list bucket contents through `GET /api/s3` with the bucket host, then upload/download again using SigV4 signed headers where canonical URI excludes the bucket name.
- Expected: Requests route to the bucket from `Host`, object content round-trips, bucket list returns `ListBucketResult`, and SigV4 validates against the original virtual-hosted-style URI.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanUseVirtualHostedStyleObjectPath`, `S3ObjectControllerTest.awsSigV4AuthorizationCanUseVirtualHostedStyleObjectPath`

### TC-S3-OBJECT-001

- Feature: S3-style object path with Access Key auth.
- Preconditions: Target bucket exists. Active access key has `READ`, `WRITE`, and `DELETE` scope.
- Input: `PUT/HEAD/GET/DELETE /api/s3/{bucketName}/{objectKey}` with `X-OSMU-Access-Key` and `X-OSMU-Secret-Key`.
- Steps: PUT raw text object with `x-amz-tagging`, HEAD metadata, GET object body, DELETE object, then GET again.
- Expected: PUT returns `ETag` and tag count. HEAD returns content length and `ETag`. GET streams the original body and returns tags and `ETag` headers. DELETE returns `204`. GET after delete returns `404`.
- Expected error body: S3 XML with `NoSuchKey`.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanPutHeadGetAndDeleteObjectThroughS3StylePath`

### TC-S3-OBJECT-001C

- Feature: S3-style object Content-MD5 integrity check.
- Preconditions: Target bucket exists. Active access key has `READ` and `WRITE` scope.
- Input: `PUT /api/s3/{bucketName}/{objectKey}` with valid `Content-MD5`, mismatched `Content-MD5`, and invalid base64 `Content-MD5`.
- Steps: Upload one object with matching MD5, upload another object with mismatched MD5, verify the failed object was not stored, then upload with invalid digest syntax.
- Expected: Matching digest succeeds and returns the MD5 `ETag`. Mismatched digest returns `400 BadDigest`. Invalid digest syntax returns `400 InvalidDigest`. Failed checksum upload does not create the object.
- Expected error body: S3 XML with `BadDigest` or `InvalidDigest`.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanUploadWithContentMd5AndRejectMismatch`

### TC-S3-OBJECT-001A

- Feature: S3-style ETag conditional HEAD/GET.
- Preconditions: Target bucket exists. Active access key has `READ` and `WRITE` scope. Object exists and has an `ETag`.
- Input: `HEAD/GET /api/s3/{bucketName}/{objectKey}` with `If-None-Match` or `If-Match`.
- Steps: Upload an object, capture the returned `ETag`, call HEAD and GET with matching `If-None-Match`, then call HEAD and GET with non-matching `If-Match`.
- Expected: Matching `If-None-Match` returns `304 Not Modified` with `ETag`. Non-matching `If-Match` returns `412 Precondition Failed` with `ETag`.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanPutHeadGetAndDeleteObjectThroughS3StylePath`

### TC-S3-OBJECT-001B

- Feature: S3-style Last-Modified conditional HEAD/GET.
- Preconditions: Target bucket exists. Active access key has `READ` and `WRITE` scope. Object exists and has a `Last-Modified` value.
- Input: `HEAD/GET /api/s3/{bucketName}/{objectKey}` with `If-Modified-Since` or `If-Unmodified-Since`.
- Steps: Upload an object, call HEAD and GET with a future `If-Modified-Since`, then call HEAD and GET with a past `If-Unmodified-Since`.
- Expected: Future `If-Modified-Since` returns `304 Not Modified` with `ETag`. Past `If-Unmodified-Since` returns `412 Precondition Failed` with `ETag`.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanPutHeadGetAndDeleteObjectThroughS3StylePath`

### TC-S3-OBJECT-002

- Feature: S3-style object Access Key scope enforcement.
- Preconditions: Target bucket exists. One access key has `READ` only, another has `WRITE` only.
- Input: `PUT /api/s3/{bucketName}/blocked.txt`, `GET /api/s3/{bucketName}/write-only.txt`.
- Steps: Try PUT with read-only key, PUT with write-only key, then GET with write-only key.
- Expected: Read-only PUT is `403`, write-only PUT succeeds, write-only GET is `403`.
- Expected error body: S3 XML with `AccessDenied`.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyScopeControlsS3StyleObjectActions`

### TC-S3-OBJECT-003

- Feature: S3-style object path with JWT auth.
- Preconditions: Admin user and target bucket exist.
- Input: `PUT/GET /api/s3/{bucketName}/{objectKey}` with Bearer token.
- Steps: PUT object through S3-style path, then GET it through the same path.
- Expected: PUT succeeds and GET returns original body.
- Priority: P1
- Automated: `S3ObjectControllerTest.bearerTokenCanUseS3StyleObjectPath`

### TC-S3-OBJECT-003B

- Feature: S3 ListObjects V1 XML prototype.
- Preconditions: Target bucket exists. Active access key has `READ` and `WRITE` scope. Objects exist under multiple prefixes.
- Input: `GET /api/s3/{bucketName}?prefix=docs/&delimiter=/`, then `GET /api/s3/{bucketName}?max-keys=1`.
- Steps: Upload three objects through the S3-style path, list with prefix and delimiter, then list with pagination and marker.
- Expected: XML response includes `ListBucketResult`, matching `Contents`, `ETag`, `CommonPrefixes`, `IsTruncated`, and `NextMarker`. Non-matching prefix objects are not returned.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanListObjectsThroughS3ListObjectsV1Xml`

### TC-S3-OBJECT-004

- Feature: S3 ListObjectsV2 XML prototype.
- Preconditions: Target bucket exists. Active access key has `READ` and `WRITE` scope. Objects exist under multiple prefixes.
- Input: `GET /api/s3/{bucketName}?list-type=2&prefix=docs/&delimiter=/`, then `GET /api/s3/{bucketName}?list-type=2&max-keys=1`.
- Steps: Upload three objects through the S3-style path, list with prefix and delimiter, then list with pagination and continuation token.
- Expected: XML response includes `ListBucketResult`, matching `Contents`, `ETag`, `CommonPrefixes`, `IsTruncated`, and `NextContinuationToken`. Non-matching prefix objects are not returned.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanListObjectsThroughS3ListObjectsV2Xml`

### TC-S3-OBJECT-004A

- Feature: S3 ListObjects URL encoding compatibility.
- Preconditions: Target bucket exists. Active access key has `READ` and `WRITE` scope. Object key contains spaces and reserved characters.
- Input: `GET /api/s3/{bucketName}?prefix=docs/&encoding-type=url` and `GET /api/s3/{bucketName}?list-type=2&prefix=docs/&encoding-type=url`.
- Steps: Upload an object with key `docs/special file(1).txt`, then list through both ListObjects V1 and V2 with URL encoding enabled.
- Expected: XML response includes `EncodingType=url` and percent-encoded `Prefix` and `Key` values.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanListObjectsWithUrlEncoding`

### TC-S3-OBJECT-004B

- Feature: S3 ListObjects owner field compatibility.
- Preconditions: Target bucket exists. Active access key has `READ` and `WRITE` scope. Object exists.
- Input: `GET /api/s3/{bucketName}?fetch-owner=true` and `GET /api/s3/{bucketName}?list-type=2&fetch-owner=true`.
- Steps: Upload one object, list through both ListObjects V1 and V2 with owner fetch enabled, then list V2 without owner fetch.
- Expected: `fetch-owner=true` response includes `Contents/Owner/ID` and `Contents/Owner/DisplayName`; default listing omits `Owner`.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanListObjectsWithOwnerWhenRequested`

### TC-S3-OBJECT-004C

- Feature: S3 ListObjects max-keys compatibility.
- Preconditions: Target bucket exists. Active access key has `READ` and `WRITE` scope. Object exists.
- Input: `GET /api/s3/{bucketName}?max-keys=1000`, `GET /api/s3/{bucketName}?list-type=2&max-keys=1000`, and invalid `max-keys=1001`.
- Steps: Upload one object, list through both ListObjects V1 and V2 with AWS default max key limit, then request one above the supported limit.
- Expected: `max-keys=1000` succeeds and XML includes `MaxKeys=1000`. `max-keys=1001` returns S3 XML `InvalidRequest`.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanUseAwsMaxKeysLimit`

### TC-S3-OBJECT-005

- Feature: S3-style single Range GET.
- Preconditions: Target bucket exists. Active access key has `READ` and `WRITE` scope. Object body is `hello s3 alias`.
- Input: `GET /api/s3/{bucketName}/video/sample.txt` with `Range: bytes=6-7`, `Range: bytes=-5`, and invalid `Range: bytes=99-100`.
- Steps: Upload object, request middle byte range, suffix byte range, then invalid range.
- Expected: Valid ranges return `206 Partial Content`, `Accept-Ranges: bytes`, correct `Content-Range`, and partial body. Invalid range returns `416 RANGE_NOT_SATISFIABLE`.
- Expected error body: S3 XML with `InvalidRange`.
- Priority: P1
- Automated: `S3ObjectControllerTest.accessKeyCanUseSingleRangeGetThroughS3StylePath`

### TC-FE-024

- Feature: Bucket Lifecycle XML panel.
- Preconditions: User is logged in and selected bucket is manageable.
- Input: Selected bucket, lifecycle XML textarea.
- Steps: Load bucket lifecycle XML, edit XML, save, then delete lifecycle config.
- Expected: UI calls `GET/PUT/DELETE /api/buckets/{bucketName}/lifecycle`, shows rule count, shows saved count after save, and clears/reloads XML after delete.
- Priority: P1
- Automated: `npm run test:unit` covers bucket lifecycle REST API wrapper methods and XML payload. Browser E2E pending.

### TC-FE-028

- Feature: Bucket Tags panel.
- Preconditions: User is logged in and selected bucket is manageable or has bucket `ADMIN` permission.
- Input: Selected bucket, bucket tag input such as `project=osmu,stage=raw`.
- Steps: Load bucket tags, save edited tags, delete tags, and try invalid duplicate or malformed tag input.
- Expected: UI calls `GET/PUT/DELETE /api/buckets/{bucketName}/tags`, converts input to a JSON tag map on save, shows tag count and saved count, clears tags after delete, and blocks invalid input before sending the request.
- Priority: P1
- Automated: `npm run test:unit` covers tag parsing/validation, bucket tag REST API wrappers, and S3 XML tagging wrappers. Browser E2E pending.

### TC-FE-029

- Feature: Frontend tag utility unit tests.
- Preconditions: Node dependencies are installed.
- Input: `npm run test:unit`
- Steps: Run frontend unit tests for tag parsing, formatting, object tag limit, bucket tag limit, duplicate key rejection, malformed input, invalid key, and control character rejection.
- Expected: All tag utility tests pass.
- Priority: P1
- Automated: `npm run test:unit`

### TC-FE-033

- Feature: Java/Docker-free frontend mock demo smoke.
- Preconditions: Node dependencies are installed. Ports `8080` and `5173` are free when running the full smoke script.
- Input: `npm run mock:api:self-test`, `powershell -ExecutionPolicy Bypass -File .\scripts\verify-frontend-mock-demo.ps1`.
- Steps: Run the mock API self-test, then start the mock API and Vite frontend, verify the frontend app shell, login as `admin/password`, login as `developer/password`, read the developer profile and S3 client config, create a scoped developer access key, create a bucket, upload/list an object, read dashboard summary, and stop the processes.
- Expected: Mock API reports `MOCK` storage/database status, ADMIN login succeeds with role `ADMIN`, developer login succeeds with role `USER`, developer S3 config exposes S3-compatible endpoint/signature data, access key creation returns one-time credentials and list responses redact the secret, bucket/object flow works, dashboard summary returns review readiness, and the verifier stops the demo ports after completion. This test proves UI/demo smoke only and does not replace Spring Boot, MariaDB, MinIO, Docker, backend tests, or real S3 client gates.
- Priority: P1
- Automated: `npm run mock:api:self-test`, `scripts/verify-frontend-mock-demo.ps1`, `scripts/verify-local.ps1 -SkipDocker -SkipBackend`

### TC-DEMO-001

- Feature: Current-machine MVP demo readiness report.
- Preconditions: PowerShell and Node/npm are available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-demo-readiness.ps1 [-JavaHome <jdk17>] [-S3Client <auto|aws|mc|docker-mc|all>]`.
- Steps: Run the readiness script on a clean local shell. Confirm it runs Node prerequisite checks, static/frontend checks, mock API self-test, frontend mock demo smoke, mock Browser E2E, durable demo preflight, Java readiness detection, and durable gate availability checks. When `-JavaHome` or `JAVA_HOME` provides JDK 17+, confirm it attempts backend-backed prototype Browser E2E. When Docker daemon is available, confirm it attempts the durable Docker/MariaDB/MinIO/Browser/S3 client gate unless `-SkipDockerFullStackE2E` is set.
- Expected: The script exits successfully when the currently available demo path passes, writes `.osmu-run/latest-demo-readiness.json` and `.osmu-run/latest-demo-readiness.md`, marks current demo status as `mock-demo-verified`, `mock-browser-demo-verified`, `backend-prototype-browser-demo-verified`, `docker-full-stack-browser-demo-verified`, or `docker-durable-demo-verified` according to passed evidence, and lists durable demo preflight, Docker/MariaDB/MinIO full-stack smoke, Docker-backed Browser E2E, durable MVP demo gate, and real S3 client smoke as `READY`, `PASS`, or `PENDING` instead of silently treating them as complete.
- Priority: P1
- Automated: `scripts/verify-mvp-demo-readiness.ps1`

### TC-DEMO-002

- Feature: Backend-backed lightweight Browser E2E prototype.
- Preconditions: PowerShell, Node/npm, Playwright CLI, and JDK 17+ are available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-prototype.ps1 -JavaHome <jdk17>`.
- Steps: Start the Spring Boot in-memory backend and Vite frontend, run `verify-lightweight-prototype.ps1` against the backend API, run Playwright Browser E2E against the frontend, and stop the started processes.
- Expected: Backend health and system health are `UP`, API smoke passes through auth, bucket, object, quota, permission, lifecycle, dashboard layout, and audit paths, Browser E2E passes the stale session redirect, developer console, and admin storage portal click path, and the verifier stops the prototype ports after completion. This test proves the Java in-memory prototype path and does not replace Docker/MariaDB/MinIO or real S3 client gates.
- Priority: P1
- Automated: `scripts/verify-browser-e2e-prototype.ps1`

### TC-DEMO-003

- Feature: Docker-backed full local demo Browser E2E.
- Preconditions: Docker Desktop, PowerShell, Node/npm, and Playwright CLI are available; local ports for Backend, Frontend, MariaDB, and MinIO are free.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-local-demo.ps1`.
- Steps: Start the Docker Compose stack, seed demo data, verify REST portal smoke, verify seeded S3 access-key smoke unless skipped, run Playwright Browser E2E against the Docker frontend, and stop the Docker stack unless `-KeepRunning` is set.
- Expected: MariaDB, MinIO, Backend, and Frontend become healthy; demo organization/users/buckets/objects/lifecycle/access key are created and verified; S3 SigV4 seeded access-key read/write/permission-boundary smoke passes; Browser E2E passes stale session redirect, developer console, operations readiness convergence dashboard visibility through the backend `.osmu-run` report mount, and admin storage portal click path against the Docker-served frontend.
- Priority: P0
- Automated: `scripts/verify-browser-e2e-local-demo.ps1`, `scripts/verify-mvp-demo-readiness.ps1` when Docker daemon is available.

### TC-DEMO-004

- Feature: Durable Docker MVP demo gate.
- Preconditions: Docker Desktop, PowerShell, Node/npm, Playwright CLI, and at least one real S3 client path are available. Dockerized MinIO Client through `-Client docker-mc` is acceptable when Docker daemon is running.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-gate.ps1`.
- Steps: Prepare `infra/local/.env` from `.env.example` when missing, run required Node/Docker/S3 client prerequisites, start the full Docker local demo, run Browser E2E, run Docker integration smoke, run real S3 client smoke, write the durable gate report, and stop the Docker stack unless `-KeepRunning` is set.
- Expected: The gate exits successfully only when MariaDB, MinIO, Backend, Frontend, Browser E2E, Docker integration smoke, and real S3 client smoke all pass. It writes `.osmu-run/latest-durable-demo-gate.json` and `.osmu-run/latest-durable-demo-gate.md`, marks current demo status as `docker-durable-demo-verified`, and estimates MVP demo completion at `90-95%`.
- Priority: P0
- Automated: `scripts/verify-durable-demo-gate.ps1`, `scripts/verify-mvp-demo-readiness.ps1` when Docker daemon is available.

### TC-DEMO-005

- Feature: Best-available MVP demo start/stop wrapper.
- Preconditions: PowerShell and Node/npm are available. JDK 17+ enables prototype mode; Docker daemon enables Docker mode.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\start-mvp-demo.ps1 -Mode <auto|docker|prototype|mock> -Verify -ForcePorts`, then `powershell -ExecutionPolicy Bypass -File .\scripts\stop-mvp-demo.ps1 -ForcePorts`.
- Steps: Run mock mode and confirm mock API plus frontend start, verification passes, `.osmu-run/mvp-demo/latest-mvp-demo.json` records `selectedMode=mock`, and stop removes listeners. Run prototype mode when JDK 17+ is available and confirm Spring Boot in-memory backend, Vite frontend, and lightweight API smoke pass before stop. Run auto mode and confirm it chooses Docker, prototype, or mock according to current machine capabilities.
- Expected: The wrapper starts exactly one usable demo mode, prints frontend/API URLs and credentials, writes mode metadata, and `stop-mvp-demo.ps1` stops the recorded mode. Prototype/mock wrapper tests do not replace Docker/MariaDB/MinIO or real S3 client gates.
- Priority: P1
- Automated: `scripts/start-mvp-demo.ps1`, `scripts/stop-mvp-demo.ps1`

### TC-DEMO-006

- Feature: Durable demo prerequisite preflight.
- Preconditions: PowerShell is available. Docker Desktop may be either running or stopped.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-preflight.ps1 -AllowNotReady`.
- Steps: Check local env source, Docker Compose file, Node/npm, Docker CLI, Docker daemon, Docker Compose config, host AWS CLI, host MinIO Client, Dockerized MinIO Client availability, and the selected real S3 client path.
- Expected: The script writes `.osmu-run/latest-durable-demo-preflight.json` and `.osmu-run/latest-durable-demo-preflight.md`. When Docker daemon and a selected S3 client path are available, result is `ready`; otherwise result is `pending` with required failure names such as `Docker daemon` or `Selected real S3 client path`.
- Priority: P0
- Automated: `scripts/verify-durable-demo-preflight.ps1`, `scripts/verify-durable-demo-gate.ps1`

### TC-DEMO-007

- Feature: Durable MVP finalize orchestration.
- Preconditions: PowerShell is available. Full execution requires Docker Desktop, JDK 17+, Node/npm, Docker Compose, and the selected real S3 client path. `-PlanOnly` can run without Docker daemon.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -S3Client docker-mc`; plan-only input: `powershell -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -S3Client docker-mc -PlanOnly`.
- Steps: In plan-only mode, write the planned durable finalization commands. In full mode, run durable preflight, backend Gradle tests, durable demo gate, durable release artifact generation, and hard MVP readiness verification with durable pending gates treated as failure.
- Expected: Plan-only mode writes `.osmu-run/latest-durable-mvp-finalize.json` and `.osmu-run/latest-durable-mvp-finalize.md` with ordered commands. Full mode exits successfully only after preflight, backend tests, Docker/MariaDB/MinIO/Browser/S3 durable gate, synchronized release artifacts, and readiness hard gate all pass.
- Priority: P0
- Automated: `scripts/finalize-durable-mvp-demo.ps1`

### TC-DEMO-008

- Feature: MVP completion report.
- Preconditions: Durable MVP evidence artifacts exist under `.osmu-run`, including latest demo readiness, durable demo gate, durable finalizer, release report, audit, decision, and release notes.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-completion.ps1 -FailIfLocalMvpNotReady`.
- Steps: Read the latest durable MVP evidence, release artifacts, and status documents. Verify they agree on `result=ready`, `currentDemoStatus=docker-durable-demo-verified`, no pending durable checks, durable MVP pilot `GO`, no stale Browser E2E pending text, and current status documents that separate local durable MVP readiness from production/B2B readiness.
- Expected: The script writes `.osmu-run/latest-mvp-completion.json` and `.osmu-run/latest-mvp-completion.md` with `classification=local-durable-mvp-ready`, `localDurableMvpReady=true`, zero local pending checks, and production operations readiness tracked separately.
- Priority: P0
- Automated: `scripts/verify-mvp-completion.ps1`

### TC-DOC-001

- Feature: Machine-readable MVP API contract.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-openapi-contract.ps1`
- Steps: Parse `dev-docs/openapi-mvp.json`, verify required REST and S3-compatible operation IDs, verify auth schemes, verify unique operation IDs, and verify frontend API client functions used by the portal still exist.
- Expected: OpenAPI JSON parses, core prototype paths are present, operation IDs are unique, and frontend API wrapper coverage matches the documented MVP control-plane surface.
- Priority: P1
- Automated: `scripts/verify-openapi-contract.ps1`

### TC-FE-030

- Feature: Frontend stable E2E selector contract.
- Preconditions: Node dependencies are installed.
- Input: `npm run test:unit`
- Steps: Run frontend unit tests that inspect `HomeView.vue` and split components for stable `data-testid` selectors covering login, status, dashboard palette grouped catalog chips, drag/size controls, section controls, section order/collapse controls, catalog-driven widget option controls, access key/identity/lifecycle/execution-retention/storage-expansion catalog widgets, bucket list, object upload, object detail, bucket lifecycle, bucket tags, audit, and confirm modal flows.
- Expected: All required selectors exist so future Browser/Chrome E2E can target stable UI hooks instead of brittle text or layout selectors, including dashboard widget section bands, section move/toggle buttons, category groups, catalog chip buttons, drag handles, dynamic option selects, execution log retention panel controls, Storage Expansion dashboard summary controls, operations readiness summary/filter/remediation command and workflow-command copy controls, and dashboard catalog widgets.
- Priority: P1
- Automated: `npm run test:unit`

### TC-FE-031

- Feature: Dashboard layout preset select, apply, create, update, single/bundle export, single/bundle import, default assignment, and delete.
- Preconditions: Authenticated user is logged in.
- Input: `GET /api/dashboard/layout/widgets`, `GET /api/dashboard/layout/presets`, `POST /api/dashboard/layout/presets`, `PUT /api/dashboard/layout/presets/{presetId}`, `PATCH /api/dashboard/layout/presets/{presetId}`, `GET /api/dashboard/layout/presets/{presetId}/export`, `POST /api/dashboard/layout/presets/import`, `GET /api/dashboard/layout/preset-bundle/export`, `POST /api/dashboard/layout/preset-bundle/import`, `GET /api/dashboard/layout/defaults`, `PUT /api/dashboard/layout/defaults`, `DELETE /api/dashboard/layout/defaults/{targetType}/{targetId}`, `DELETE /api/dashboard/layout/presets/{presetId}`.
- Steps: Load dashboard widget catalog and preset options, choose `compact`, apply the preset, create a custom preset from current widgets as ADMIN, update that custom preset with the current widget layout including `schemaVersion`, `section`, `sections[].collapsed`, and `options.tone`, export it as JSON, import the exported payload as a new custom preset, export all custom presets as bundle JSON, import that bundle as new custom presets, assign a ROLE or ORGANIZATION default preset, verify a user without a saved layout receives `source = DEFAULT_PRESET`, attempt to save an unknown widget id, invalid section, invalid schema version, invalid bundle format version, and invalid tone option, delete the default assignment, delete created custom presets, then refresh dashboard layout.
- Expected: Widget catalog metadata contains `access-keys`, `identity`, `lifecycle`, `execution-retention`, `storage-expansion`, category/adminOnly fields, and `tone` config option schema. Preset select/apply/save/update/export/import/default assignment controls are visible, including bundle export/import controls for ADMIN. Applying preset stores the preset widgets, section collapse state, and `schemaVersion = osmu.dashboard-layout.v1` as the current user's dashboard layout and later `GET /api/dashboard/layout` returns `source = SAVED`. ADMIN can create/update/export/import/delete custom presets, move custom preset bundles between environments, and assign/delete role or organization defaults, all users can export readable single presets, built-in presets cannot be updated or deleted, unknown widget ids, invalid sections, invalid schema versions, invalid bundle format versions, and invalid widget options are rejected with HTTP 400, and personal saved layouts override defaults.
- Priority: P1
- Automated: `DashboardLayoutControllerTest.userCanReadAndApplyDashboardLayoutPreset`, `DashboardLayoutControllerTest.adminCanCreateApplyAndDeleteCustomDashboardLayoutPreset`, `DashboardLayoutControllerTest.adminCanAssignRoleDefaultDashboardLayoutPreset`, `npm run test:unit`, `verify-local-demo.ps1` dashboard widget catalog/preset CRUD/default smoke, lightweight browser spec selector coverage.

### TC-FE-032

- Server dry-run runner 추가 검증: `POST /api/admin/storage-expansion/requests/{requestId}/dry-run-runner` 호출 후 기본 비활성 설정에서는 `KUBECTL_DIFF / SKIPPED`, `timedOut=false`, `exitCode=null`, runner disabled output, history 표시를 확인한다. runner 활성 설정에서는 `kubectl diff` 또는 `helm diff`의 `exitCode/timedOut/output` 저장을 확인한다.
- Server apply runner 추가 검증: `POST /api/admin/storage-expansion/requests/{requestId}/apply-runner` 호출 후 기본 비활성 설정에서는 `APPLY / SKIPPED`, `timedOut=false`, `exitCode=null`, apply runner disabled output, request status `APPROVED`, history 표시를 확인한다. runner 활성 설정에서 성공하면 `APPLY / SUCCESS` 기록과 request status `APPLIED` 자동 전환을 확인한다.
- Server rollback runner 추가 검증: `POST /api/admin/storage-expansion/requests/{requestId}/rollback-runner`는 `APPLIED` 요청에서만 허용한다. 기본 비활성 설정에서는 `ROLLBACK / SKIPPED`, `timedOut=false`, `exitCode=null`, rollback runner disabled output, request status `APPLIED`, history 표시를 확인한다.
- GitOps PR runner 추가 검증: `POST /api/admin/storage-expansion/requests/{requestId}/gitops-pr-runner`는 `APPROVED` 요청에서만 허용한다. 기본 비활성 설정에서는 `GITOPS_PR / SKIPPED`, `timedOut=false`, `exitCode=null`, GitOps PR runner disabled output, branch/commit/push/PR command, history 표시를 확인한다. runner 활성 설정에서는 configured repository에 artifact 파일을 쓰고 `git checkout -B`, `git add`, `git commit`, `git push -u origin`, `gh pr create` 결과와 PR URL 저장을 확인한다. 단위테스트는 fake `git`/`gh`로 enabled runner 성공 흐름, artifact path repository escape 차단, branch protection 실패 시 notes와 response field의 `failureReason=BRANCH_PROTECTION` 기록, 실패 후 `gh pr create` 미실행을 검증한다. Frontend selector test는 `storage-expansion-execution-failure-reason` badge와 failure reason parsing helper를 확인한다.
- Runner preflight 추가 검증: `GET /api/admin/storage-expansion/runner-preflight`는 기본 비활성 설정에서 `DISABLED`, `ready=false`, dry-run/apply/rollback/GitOps PR check와 `remediation` 힌트를 반환하고, runner 활성 설정에서는 `kubectl`, `helm`, `helm diff`, `git`, `gh`, `gh auth status`, GitOps repository `.git` metadata, `git -C {repositoryPath} status --short` readiness를 짧은 timeout으로 확인한다. UI selector `storage-expansion-runner-preflight-remediation`은 각 check의 다음 조치를 표시한다.
- Helm chart 추가 검증: `verify-helm-chart.ps1`는 기본 StatefulSet mode와 함께 `minio.tenant.enabled`, `minio.pools`, `volumesPerServer`, `volumeClaimTemplate`, `requestAutoCert`가 chart draft에 포함되는지 확인한다. 실제 cluster apply 전에는 MinIO Operator CRD schema validation을 별도로 수행한다.
- Execution log sanitizer 추가 검증: runner/manual/GitOps execution의 `command`, `output`, `notes`에 password/secret/token/access key/authorization/S3 signature/URL password가 포함되어도 API 응답과 저장 이력에는 `[masked]`로 표시되고 raw secret은 노출되지 않는다. output은 retention limit 안으로 잘린다.
- Execution output retention 추가 검증: retention cutoff보다 오래된 Storage Expansion execution output은 scheduler 또는 `POST /api/admin/storage-expansion/execution-log-retention/run`으로 redaction marker로 교체된다. 최신 output과 이미 redacted output은 유지되고, status API는 pending/redacted/failure count를 반환한다.
- Dashboard summary 추가 검증: `GET /api/admin/storage-expansion/summary`는 request status별 count, open capacity, execution result별 count, latest request/execution, recent executions를 반환하고 ADMIN dashboard `storage-expansion` widget은 이 aggregate를 우선 사용한다.

- Feature: Storage expansion request planning and status management.
- Preconditions: ADMIN user is logged in.
- Input: `GET /api/admin/storage-expansion/requests`, `GET /api/admin/storage-expansion/runner-preflight`, `POST /api/admin/storage-expansion/requests`, `GET /api/admin/storage-expansion/requests/{requestId}/manifest`, `GET /api/admin/storage-expansion/requests/{requestId}/manifest/{artifact}`, `POST /api/admin/storage-expansion/requests/{requestId}/execution-plan`, `POST /api/admin/storage-expansion/requests/{requestId}/dry-run-execution`, `POST /api/admin/storage-expansion/requests/{requestId}/gitops-plan`, `GET /api/admin/storage-expansion/requests/{requestId}/gitops-artifacts/bundle`, `POST /api/admin/storage-expansion/requests/{requestId}/gitops-pr-runner`, `POST /api/admin/storage-expansion/requests/{requestId}/gitops-pr-execution`, `GET/POST /api/admin/storage-expansion/requests/{requestId}/executions`, `POST /api/admin/storage-expansion/requests/{requestId}/executions/{executionId}/apply`, `PATCH /api/admin/storage-expansion/requests/{requestId}/status`.
- Steps: Open Admin page, enter requested capacity, server count, PV per server, and reason, submit a storage expansion request, list requests, preview the request manifest, download tenant/helm/bundle YAML artifacts, approve the request, generate a dry-run execution plan, record `KUBECTL_DIFF` or `HELM_DIFF` output as dry-run evidence, generate a GitOps PR draft, run the GitOps PR runner in disabled mode, enter GitOps PR URL/merge SHA/pipeline URL, record GitOps PR evidence, download the GitOps ZIP bundle, record a Helm diff or kubectl diff execution result, list execution history, record a successful `APPLY` execution, apply the request from that execution record, confirm preflight checklist/commands/checksum/branch/changed files/PR body/ZIP entries/history entries, then attempt invalid status and invalid execution apply flows.
- Expected: UI exposes stable storage expansion selectors, runner preflight panel/list/refresh/remediation controls, applied evidence input, manifest preview textareas, YAML download buttons, execution dry-run panel and dry-run evidence inputs/button, GitOps draft panel, GitOps PR runner/evidence buttons, GitOps ZIP download button, execution history form/list, GitOps runner `failureReason` badge, and execution apply button. Backend returns a MinIO pool plan with `poolName`, `serverCount`, `volumesPerServer`, `volumeSizeBytes`, `estimatedRawCapacityBytes`, `estimatedUsableCapacityBytes`, `status`, reason, actor, and applied evidence fields. Runner preflight returns `DISABLED` by default and reports tool/config readiness plus remediation hints only when runners are enabled, including `gh auth status`, repository `.git` metadata, and `git -C {repositoryPath} status --short` for enabled GitOps PR runner. Summary returns request status/capacity aggregate plus execution count/result/timedOut/recent values without requiring full request list or per-request history calls; MariaDB implementation uses aggregate/recent queries backed by status/result/timedOut indexes. Manifest preview returns `referenceOnly = true`, MinIO Tenant YAML, and Helm values YAML. Manifest artifact download returns `application/x-yaml` for `tenant`, `helm`, and `bundle`. Execution plan requires `APPROVED`, returns artifact SHA-256, preflight checks, suggested kubectl/helm diff/dry-run commands, and evidence template. Dry-run execution requires `APPROVED`, `KUBECTL_DIFF` or `HELM_DIFF`, valid result, output unless skipped, and records command/output/current artifact SHA-256. GitOps plan requires `APPROVED`, returns branch name, `[Feat][I]` commit message, PR title/body, changed files, review checklist, and artifact SHA-256. GitOps artifact bundle requires `APPROVED`, returns `application/zip` with tenant patch, Helm values, and README entries. GitOps PR runner requires `APPROVED`, writes configured repo artifacts when enabled, records `GITOPS_PR / SKIPPED` by default, records external PR URL when `gh pr create` returns one, and records notes plus response `failureReason` for fail-fast failures. GitOps PR execution requires `APPROVED`, valid HTTP(S) PR URL, optional valid merge SHA, then records `GITOPS_PR / SUCCESS` with generated command, output, artifact SHA-256, and notes. Execution history requires `APPROVED` or `APPLIED`, records `DRY_RUN/GITOPS_PR/HELM_DIFF/KUBECTL_DIFF/APPLY/ROLLBACK` results with command/output/external URL/checksum/notes/failureReason. Apply-from-execution requires `APPROVED` request, matching execution request id, `SUCCESS` result, and `APPLY` or `GITOPS_PR` execution type, then auto-generates `appliedEvidence`. Invalid capacity, server count, volume count, status, direct `PLANNED -> APPLIED`, invalid artifact, non-approved execution plan, non-approved dry-run execution, non-approved GitOps plan, non-approved GitOps bundle, non-approved GitOps PR runner, non-approved GitOps PR execution, non-approved execution history, invalid execution type/result/checksum, or invalid execution apply is rejected with HTTP 400. Audit logs include create/status/manifest/download/execution-plan/dry-run-execution/gitops-plan/gitops-artifact-download/gitops-pr-runner/gitops-pr-execution/execution-record/execution-apply events.
- Priority: P1
- Automated: `AdminStorageExpansionControllerTest.adminCanPlanAndApproveStorageExpansionRequest`, `api-quota-policy.test.js`, `HomeView.test.js`, `verify-local-demo.ps1` storage expansion smoke.

### TC-S3-AUTH-002

- Feature: Docker integration S3 SigV4 smoke.
- Preconditions: Docker Desktop is running and local ports are available.
- Input: `.\scripts\verify-docker-integration.ps1`
- Steps: Run the Docker integration smoke script. The script creates a bucket, creates an OSMU access key, signs S3-style requests with AWS SigV4, calls root `HEAD /api/s3`, root `GET /api/s3`, checksum object `PUT/HEAD/GET /api/s3/{bucketName}/sigv4-smoke.txt`, bucket sync plus another checksum `HEAD`, S3 multipart checksum initiate/upload parts/complete/head, S3 multi-delete Quiet/Content-MD5 with mismatch guard, presigned-query `GET /api/s3/{bucketName}/sigv4-smoke.txt`, mismatched payload-hash `PUT /api/s3/{bucketName}/sigv4-bad-payload.txt`, mismatched checksum `PUT /api/s3/{bucketName}/sigv4-bad-checksum.txt`, and virtual-hosted-style `PUT/GET /api/s3/sigv4-vhost-smoke.txt` with `Host: {bucketName}.localhost` without `X-OSMU-Secret-Key`.
- Expected: SigV4 root HEAD succeeds, root listing includes the smoke bucket, checksum object PUT echoes `x-amz-checksum-sha256`, object HEAD/GET expose stored checksum, bucket sync preserves the checksum header, S3 multipart checksum complete returns checksum header/XML and later HEAD exposes it, multi-delete Quiet suppresses `Deleted` entries, mismatched multi-delete `Content-MD5` returns `BadDigest` without deleting the protected object, presigned-query GET returns the uploaded body, mismatched payload hash and mismatched checksum return S3 XML `BadDigest`, virtual-hosted-style object PUT/GET round-trips, and cleanup removes created smoke objects and bucket.
- Priority: P1
- Automated: `scripts/verify-docker-integration.ps1`

### TC-S3-AUTH-003

- Feature: Real S3 client smoke.
- Preconditions: Backend API is running and reachable. AWS CLI (`aws`) or MinIO Client (`mc`) is installed on PATH, or Docker Desktop is running for Dockerized MinIO Client. Admin login is available.
- Input: `.\scripts\verify-s3-client-smoke.ps1 -Client auto`, `.\scripts\verify-s3-client-smoke.ps1 -Client docker-mc -RequireClient`, or `.\scripts\verify-s3-client-smoke.ps1 -Client all -RequireClient`. Optional: `-SkipManualSigV4`, `-SkipVirtualHostedSmoke`.
- Steps: Script logs in through OSMU REST API, creates a smoke bucket and scoped access key, runs built-in SigV4 probes for root `HEAD`, root list, checksum object PUT/HEAD/GET, bucket sync plus another checksum `HEAD`, S3 multipart checksum complete, S3 multi-delete Quiet/Content-MD5 with mismatch guard, mismatched payload hash `BadDigest`, mismatched checksum `BadDigest`, and virtual-hosted-style object PUT/GET. Then it uses host or Dockerized real S3 clients against `http://localhost:8080/api/s3` to list buckets, upload, head/stat, list objects, download/cat, delete object, and cleanup bucket. Dockerized `mc` connects to the host backend through `host.docker.internal`.
- Expected: Built-in SigV4 probes pass without `X-OSMU-Secret-Key`; checksum PUT echoes `x-amz-checksum-sha256`; object HEAD/GET expose stored checksum; bucket sync preserves the checksum header; multipart checksum complete returns checksum header/XML and later HEAD exposes it; multi-delete Quiet suppresses `Deleted` entries; mismatched multi-delete `Content-MD5` returns `BadDigest` without deleting the protected object; mismatched payload hash and mismatched checksum return `BadDigest`. Host or Dockerized clients complete all operations using S3 SigV4. If no real client path is available and `-RequireClient` is not set, the script skips external client checks with a clear warning.
- Priority: P1
- Automated: `scripts/verify-s3-client-smoke.ps1`
# OSMU Test Cases

이 문서는 OSMU 기능별 테스트 케이스를 정의한다.

`test-strategy.md`가 테스트 방향과 우선순위를 설명한다면, 이 문서는 실제로 확인해야 할 구체적인 테스트 항목을 기록한다.

## 1. 테스트 케이스 형식

각 테스트 케이스는 다음 형식을 따른다.

```text
ID:
기능:
조건:
입력:
절차:
기대 결과:
우선순위:
자동화 여부:
```

우선순위:

- P0: MVP 필수
- P1: MVP 안정화
- P2: 제품화
- P3: 장기 확장

자동화 여부:

- Manual
- Automated
- Later

## 2. Health API

### TC-HEALTH-001

- 기능: Backend Health
- 조건: Backend가 실행 중이다.
- 입력: `GET /api/health`
- 절차: Health API를 호출한다.
- 기대 결과: HTTP 200, `status = UP` 응답.
- 우선순위: P0
- 자동화 여부: Automated

### TC-HEALTH-002

- 기능: MariaDB Health
- 조건: Backend와 MariaDB가 실행 중이다.
- 입력: `GET /api/database/health`
- 절차: Database Health API를 호출한다.
- 기대 결과: HTTP 200, `engine = mariadb`, `status = UP`.
- 우선순위: P0
- 자동화 여부: Automated

### TC-HEALTH-003

- 기능: MinIO Health
- 조건: Backend와 MinIO가 실행 중이다.
- 입력: `GET /api/storage/health`
- 절차: Storage Health API를 호출한다.
- 기대 결과: HTTP 200, `engine = minio`, `status = UP`.
- 우선순위: P0
- 자동화 여부: Automated

## 3. Auth

### TC-AUTH-001

- 기능: 로그인 성공
- 조건: 활성 사용자 계정이 존재한다.
- 입력: 정상 `loginId`, 정상 `password`
- 절차: `POST /api/auth/login` 호출.
- 기대 결과: HTTP 200, accessToken 반환.
- 우선순위: P1
- 자동화 여부: Automated

### TC-AUTH-002

- 기능: 로그인 실패
- 조건: 사용자 계정이 존재한다.
- 입력: 정상 `loginId`, 잘못된 `password`
- 절차: `POST /api/auth/login` 호출.
- 기대 결과: HTTP 401 또는 인증 실패 에러.
- 우선순위: P1
- 자동화 여부: Automated

### TC-AUTH-003

- 기능: 비활성 사용자 로그인 차단
- 조건: `INACTIVE` 상태 사용자 계정이 존재한다.
- 입력: 비활성 사용자 `loginId`, 정상 `password`
- 절차: `POST /api/auth/login` 호출.
- 기대 결과: 로그인 실패.
- 우선순위: P1
- 자동화 여부: Automated

### TC-AUTH-004

- 기능: 로그아웃 refresh token 폐기
- 조건: 활성 사용자가 로그인되어 있고 access token과 refresh token을 보유한다.
- 입력: `POST /api/auth/logout`, 이후 동일 refresh token으로 `POST /api/auth/refresh`
- 절차: 로그아웃 API 호출 후 기존 refresh token 재사용을 시도한다.
- 기대 결과: 로그아웃은 HTTP 200과 `success = true`를 반환하고, 기존 refresh token 재사용은 HTTP 401과 `AUTHENTICATION_REQUIRED`로 차단된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-AUTH-005

- 기능: `/login` 전용 로그인 화면
- 조건: 인증되지 않은 사용자가 portal에 접근한다.
- 입력: `/dashboard`, `/storage`, `/objects`, `/admin`, `/audit` 직접 접근.
- 절차: 보호 route에 접근한다.
- 기대 결과: `/login?redirect=...`로 이동하고 login form, 관리자/개발자 mode, 비밀번호 보기, 자동 로그인, 아이디 저장 control이 표시된다. 관리자 mode는 RAID/JBOD, 용량 증설, IAM User 발급, 권한 부여 목적을 표시하고 개발자 mode는 API Key 기반 S3 호환 저장 목적을 표시한다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` selector contract, `verify-lightweight-demo.ps1` /login direct URL smoke, Browser E2E spec covers developer mode login; successful Browser runtime execution pending)

### TC-AUTH-006

- 기능: 자동 로그인과 아이디 저장
- 조건: 활성 사용자 계정이 존재한다.
- 입력: `loginId`, `password`, 자동 로그인 checkbox, 아이디 저장 checkbox.
- 절차: 자동 로그인을 켜고 로그인한 뒤 새 browser session에서 route guard가 session을 복원하는지 확인한다. 아이디 저장은 loginId만 저장되는지 확인한다.
- 기대 결과: 자동 로그인 token은 `localStorage`, 일반 session token은 `sessionStorage`, 저장 아이디는 별도 key에 저장된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` authStore)

### TC-AUTH-007

- 기능: 관리자/개발자 route와 navigation 분리
- 조건: `ADMIN`, `ORG_ADMIN`, `USER` 계정이 각각 존재한다.
- 입력: `/admin`, `/audit`, `/developer`, `/objects` 직접 접근과 sidebar navigation.
- 절차: 각 role로 로그인한 뒤 보호 route에 접근하고 sidebar 표시 메뉴를 확인한다.
- 기대 결과: 관리자 mode로 로그인한 `ADMIN`, `ORG_ADMIN`은 `/admin`으로 이동하고 `/admin` 접근 가능. `ADMIN`은 `/audit`도 접근 가능하며 `ORG_ADMIN`은 `/audit` 접근 불가. `ADMIN`, `ORG_ADMIN`은 Developer navigation도 볼 수 있어 API Key 작업이 가능하다. `USER`는 `/admin`, `/audit` 접근 불가이며 개발자 작업 화면(`/developer`)으로 이동하고 Admin/Audit navigation이 보이지 않는다. `/developer`에서는 Access Key 발급 form과 S3 endpoint summary가 보인다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` route/static selector contract, Browser E2E spec verifies USER `/developer` landing, Admin nav hiding, S3 endpoint/snippet display, and Access Key create UI through mocked API; successful Browser runtime execution pending)

## 4. Organization

### TC-ORG-001

- 기능: 조직 생성과 목록 조회
- 조건: admin 사용자가 로그인되어 있다.
- 입력: `POST /api/admin/organizations`
- 절차: 조직 생성 후 `GET /api/admin/organizations`를 호출한다.
- 기대 결과: 생성한 조직 이름, 설명, 기본 쿼터가 목록에 표시된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-ORG-002

- 기능: 중복 조직명 차단
- 조건: 동일 이름의 조직이 이미 존재한다.
- 입력: 같은 `name`으로 `POST /api/admin/organizations`
- 절차: 두 번째 조직 생성 API를 호출한다.
- 기대 결과: HTTP 409, `CONFLICT`.
- 우선순위: P1
- 자동화 여부: Automated

### TC-ORG-003

- 기능: 사용자 생성 시 조직 연결
- 조건: 조직이 존재한다.
- 입력: `POST /api/admin/users` with `organizationId`
- 절차: 사용자 생성 응답과 사용자 목록을 확인한다.
- 기대 결과: 사용자 profile에 `organizationId`가 포함된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-ORG-004

- 기능: 조직별 usage 집계
- 조건: 조직 소유 bucket과 object가 존재한다.
- 입력: `GET /api/admin/organizations/usage`
- 절차: 조직 bucket에 object를 업로드한 뒤 organization usage API를 호출한다.
- 기대 결과: 해당 조직의 `bucketCount`, `objectCount`, `usedBytes`, `bucketQuotaBytes`가 bucket metadata 기준으로 집계된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-ORG-005

- 기능: 조직 quota 초과 업로드 차단
- 조건: 조직 default quota가 작고, 해당 조직 소유 bucket이 존재한다.
- 입력: 조직 잔여 용량보다 큰 파일 upload
- 절차: 조직 bucket에 파일 업로드 API를 호출한다.
- 기대 결과: HTTP 413, `QUOTA_EXCEEDED`.
- 우선순위: P1
- 자동화 여부: Automated

### TC-ORG-005A

- Feature: Empty organization delete
- Condition: Organization exists and has no assigned users or ORG-owned buckets.
- Input: `DELETE /api/admin/organizations/{organizationId}`
- Steps: Create organization, assign an `ORGANIZATION` dashboard default preset, `ORGANIZATION` quota policy, and `ORGANIZATION` bucket permission subject to it, delete it, list organizations/dashboard defaults/quota policies/quota history/bucket permissions.
- Expected: HTTP 204, organization disappears from list, related dashboard default preset assignment disappears, related organization quota policy disappears, quota policy `DELETE` history is recorded, related bucket permission subject entries disappear, `ORGANIZATION_DELETE` audit event is recorded.
- Priority: P1
- Automation: `AdminOrganizationControllerTest.adminCanDeleteEmptyOrganization`, `verify-local-demo.ps1`

### TC-ORG-005B

- Feature: Non-empty organization delete guard
- Condition: Organization has assigned users or ORG-owned buckets.
- Input: `DELETE /api/admin/organizations/{organizationId}`
- Steps: Try deleting an organization with an assigned user, then try deleting one with an ORG-owned bucket.
- Expected: HTTP 409, `CONFLICT`.
- Priority: P1
- Automation: Automated

### TC-ORG-006

- 기능: ORG_ADMIN 자기 조직 사용자 관리
- 조건: ORG_ADMIN과 같은 조직 USER, 다른 조직 USER가 존재한다.
- 입력: `GET/POST/PATCH /api/admin/users`
- 절차: ORG_ADMIN이 사용자 목록 조회, 자기 조직 USER 생성, 자기 조직 USER 비활성화, 다른 조직 USER 비활성화를 시도한다.
- 기대 결과: 자기 조직 사용자만 조회/생성/비활성화 가능하고 다른 조직 사용자는 `403 AUTHORIZATION_FAILED`.
- 우선순위: P1
- 자동화 여부: Automated

### TC-ORG-007

- 기능: ORG_ADMIN global admin API 차단
- 조건: ORG_ADMIN token이 존재한다.
- 입력: `GET /api/admin/audit-logs`
- 절차: ORG_ADMIN으로 global admin API를 호출한다.
- 기대 결과: `403 AUTHORIZATION_FAILED`.
- 우선순위: P1
- 자동화 여부: Automated

## 5. Bucket

### TC-BUCKET-001

- 기능: 버킷 생성 성공
- 조건: MinIO와 MariaDB가 정상이다.
- 입력: `name = project-data`
- 절차: `POST /api/buckets` 호출.
- 기대 결과: HTTP 200 또는 201, MinIO 버킷 생성, MariaDB 메타데이터 저장.
- 우선순위: P0
- 자동화 여부: Automated

### TC-BUCKET-002

- 기능: 중복 버킷 생성 차단
- 조건: `project-data` 버킷이 이미 존재한다.
- 입력: `name = project-data`
- 절차: `POST /api/buckets` 호출.
- 기대 결과: HTTP 409, `CONFLICT` 에러.
- 우선순위: P0
- 자동화 여부: Automated

### TC-BUCKET-003

- 기능: 잘못된 버킷 이름 차단
- 조건: Backend가 실행 중이다.
- 입력: `name = Project_Data`
- 절차: `POST /api/buckets` 호출.
- 기대 결과: HTTP 400, `VALIDATION_ERROR`.
- 우선순위: P0
- 자동화 여부: Automated

### TC-BUCKET-004

- 기능: 버킷 목록 조회
- 조건: 접근 가능한 버킷이 1개 이상 존재한다.
- 입력: `GET /api/buckets`
- 절차: 버킷 목록 API 호출.
- 기대 결과: 접근 가능한 버킷 목록 반환.
- 우선순위: P0
- 자동화 여부: Automated

### TC-BUCKET-005

- 기능: 빈 버킷 삭제 성공
- 조건: 빈 버킷이 존재한다.
- 입력: `DELETE /api/buckets/{bucketName}`
- 절차: 버킷 삭제 API 호출.
- 기대 결과: MinIO 버킷 삭제, MariaDB 상태 반영, 감사 로그 기록.
- 우선순위: P0
- 자동화 여부: Automated

### TC-BUCKET-006

- 기능: 비어있지 않은 버킷 삭제 차단
- 조건: 버킷 안에 오브젝트가 존재한다.
- 입력: `DELETE /api/buckets/{bucketName}`
- 절차: 버킷 삭제 API 호출.
- 기대 결과: 삭제 실패, 적절한 에러 반환.
- 우선순위: P1
- 자동화 여부: Automated

### TC-BUCKET-007

- 기능: S3 직접 업로드 이후 사용량 동기화
- 조건: Backend metadata를 거치지 않고 storage에 object가 생성됐다.
- 입력: `POST /api/buckets/{bucketName}/sync`
- 절차: sync API 호출.
- 기대 결과: storage 실제 object 기준으로 `usedBytes`, `objectCount`가 갱신되고 object 목록 API에서 sync된 object가 조회된다. 기존 index object와 storage ETag가 같으면 checksum metadata는 보존되고, ETag가 달라지면 stale checksum metadata는 제거된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-BUCKET-008

- 기능: 조직 소유 bucket 생성과 조직원 접근
- 조건: 조직, ORG_ADMIN, 같은 조직 USER, 외부 USER가 존재한다.
- 입력: `POST /api/buckets` with `ownerType = ORG`
- 절차: ORG_ADMIN이 조직 bucket을 만들고 같은 조직 USER가 object 업로드/목록 조회를 수행한다.
- 기대 결과: 같은 조직 USER는 접근 가능하고 외부 USER는 `403 AUTHORIZATION_FAILED`를 받는다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-BUCKET-009

- 기능: 조직 bucket 관리 권한 제한
- 조건: 조직 bucket이 존재한다.
- 입력: 같은 조직 일반 USER의 `DELETE /api/buckets/{bucketName}`
- 절차: 일반 USER가 조직 bucket 삭제를 시도한다.
- 기대 결과: `403 AUTHORIZATION_FAILED`.
- 우선순위: P1
- 자동화 여부: Automated

### TC-BUCKET-010

- 기능: bucket permission으로 object action 제어
- 조건: user bucket owner와 target user가 존재한다.
- 입력: `POST /api/buckets/{bucketName}/permissions` with `READ`, `WRITE`, `DELETE`
- 절차: owner가 target user에게 `READ`를 부여하면 object 목록 조회와 read-only Access Key 생성이 가능하고 upload는 차단된다. `READ`를 회수하면 목록 조회가 차단되고 기존 read-only Access Key가 `INACTIVE`가 된다. `WRITE`, `DELETE`를 부여하면 업로드와 삭제가 가능하다.
- 기대 결과: permission별로 `READ`, `WRITE`, `DELETE` object action이 분리되어 동작하고, target user는 permission 목록 관리 API에 접근할 수 없다. 권한 회수 후 기존 Access Key도 stale policy를 유지하지 않는다.
- 우선순위: P1
- 자동화 여부: Automated

## 5.1 Storage Profile

### TC-STORAGE-PROFILE-001

- Feature: Bucket owner requests and admin applies Storage Profile.
- Preconditions: A normal user owns a bucket. Admin user exists.
- Input: `POST /api/buckets/{bucketName}/storage-profile-requests`, `PATCH /api/admin/storage-profile-requests/{requestId}/status`, `POST /api/admin/storage-profile-requests/{requestId}/apply`.
- Steps: User requests `PERFORMANCE` with a reason. Admin lists requests, approves it, then applies it. User reads the bucket current profile.
- Expected: Request starts as `PENDING`, moves to `APPROVED`, then `APPLIED`. Bucket assignment changes from default `STANDARD` to `PERFORMANCE`. Audit events are written.
- Priority: P1
- Automated: `StorageProfileControllerTest.bucketOwnerCanRequestAndAdminCanApplyStorageProfile`, `api-storage-profile.test.js`

### TC-STORAGE-PROFILE-002

- Feature: Storage Profile validation and authorization.
- Preconditions: User has a bucket and another non-admin user exists.
- Input: `POST /api/buckets/{bucketName}/storage-profile-requests`, `PATCH /api/admin/storage-profile-requests/{requestId}/status`.
- Steps: Request `PERFORMANCE` without a reason, request the currently active profile, and attempt admin status update as non-admin.
- Expected: Missing Performance reason returns `400 VALIDATION_ERROR`. Same active profile returns `400 VALIDATION_ERROR`. Non-admin admin route returns `403 AUTHORIZATION_FAILED`.
- Priority: P1
- Automated: `StorageProfileControllerTest.bucketOwnerCanRequestAndAdminCanApplyStorageProfile`

### TC-STORAGE-PROFILE-003

- Feature: Storage Profile UI.
- Preconditions: Frontend is logged in and has buckets loaded.
- Input: Storage page profile panel and Admin page profile approval queue.
- Steps: Select a bucket, verify active profile details, submit a profile request, open Admin page, approve/reject/apply request.
- Expected: User UI shows active profile, alias, risk, MinIO binding, and recent requests. Admin UI shows request queue with note input and approve/reject/apply actions.
- Priority: P1
- Automated: Pending browser E2E. API wrapper coverage exists in `api-storage-profile.test.js`; mock API supports frontend-only demo.

## 6. Object

### TC-OBJECT-001

- 기능: 파일 업로드 성공
- 조건: 버킷이 존재하고 사용자에게 쓰기 권한이 있다.
- 입력: 파일 1개, `objectKey = images/sample.png`
- 절차: `POST /api/buckets/{bucketName}/objects` 호출.
- 기대 결과: HTTP 200 또는 201, MinIO에 object 저장, 감사 로그 기록.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-002

- 기능: 파일 목록 조회
- 조건: 버킷에 파일이 1개 이상 존재한다.
- 입력: `GET /api/buckets/{bucketName}/objects`
- 절차: 오브젝트 목록 API 호출.
- 기대 결과: 파일 key, size, contentType, lastModified 반환.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-003

- 기능: 파일 다운로드 성공
- 조건: 파일이 존재하고 사용자에게 읽기 권한이 있다.
- 입력: `GET /api/buckets/{bucketName}/objects/{objectKey}`
- 절차: 다운로드 API 호출.
- 기대 결과: 파일 stream 또는 presigned URL 반환.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-004

- 기능: 파일 soft delete 성공
- 조건: 파일이 존재하고 사용자에게 삭제 권한이 있다.
- 입력: `DELETE /api/buckets/{bucketName}/objects/{objectKey}`
- 절차: 삭제 API 호출.
- 기대 결과: MinIO object는 즉시 삭제하지 않고 `object_metadata.deleted_at`이 기록된다. active 목록과 다운로드에서는 숨겨지고 `deleted=true` 목록에서 조회된다. 감사 로그 `OBJECT_DELETE`가 기록된다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-004A

- 기능: soft-deleted 파일 복구와 영구 삭제
- 조건: `DELETE /api/buckets/{bucketName}/objects/{objectKey}`로 trash에 이동한 파일이 있다.
- 입력: `GET /api/buckets/{bucketName}/objects?deleted=true`, `POST /api/buckets/{bucketName}/objects/restore/{objectKey}`, `POST /api/buckets/{bucketName}/objects/purge/{objectKey}`
- 절차: deleted 목록에서 파일을 확인하고 restore 후 active 목록/다운로드 가능 여부를 확인한다. 다시 delete 후 purge를 실행한다.
- 기대 결과: deleted 목록에는 `deletedAt`이 표시된다. restore 후 active 목록에 다시 표시되고 다운로드 가능하다. purge 후 MinIO object와 metadata가 삭제되고 quota/objectCount가 감소한다. 감사 로그 `OBJECT_RESTORE`, `OBJECT_PURGE`가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-OBJECT-004B

- 기능: retention 기간 지난 soft-deleted 파일 자동 purge
- 조건: `deletedAt`이 `osmu.object.retention.days`보다 오래된 trash object가 있다.
- 입력: retention purge scheduler 실행 시점의 현재 시간
- 절차: soft-deleted object metadata와 storage object를 준비하고 `ObjectRetentionPurgeJob`을 실행한다.
- 기대 결과: Backend가 MinIO object와 metadata를 삭제하고 bucket quota/objectCount를 감소시킨다. purge 성공/실패는 `OBJECT_RETENTION_PURGE` 감사 로그와 `osmu.object.retention.purge.objects` metric으로 기록된다. retention 기간이 지나지 않은 trash object는 유지된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-OBJECT-004B-2

- 기능: retention 기간 지난 object version 자동 purge
- 조건: `createdAt`이 `versionRetentionDays`보다 오래된 object version snapshot이 있다.
- 입력: version retention purge scheduler 실행 시점의 현재 시간
- 절차: hidden version storage object와 `object_versions` metadata를 준비하고 `ObjectVersionRetentionPurgeJob`을 실행한다.
- 기대 결과: Backend가 old version storage와 metadata만 삭제하고 active object는 유지한다. bucket quota/objectCount를 version size/count만큼 감소시킨다. purge 성공/실패는 `OBJECT_VERSION_RETENTION_PURGE` 감사 로그와 `osmu.object.version.retention.purge.versions` metric으로 기록된다. retention 기간이 지나지 않은 version은 유지된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-OBJECT-004C

- 기능: Admin retention 상태 조회와 수동 purge 실행
- 조건: ADMIN 사용자가 로그인되어 있다.
- 입력: `GET /api/admin/object-retention/status`, `POST /api/admin/object-retention/purge`
- 절차: Admin dashboard에서 retention 상태를 조회하고 `Run purge`를 실행한다.
- 기대 결과: API는 enabled, retentionDays, batchSize, versionRetentionDays, versionBatchSize, object/version purge success/failure metric을 반환한다. 수동 purge 실행 응답은 purgedCount, purgedVersionCount와 갱신된 status를 반환한다. ADMIN이 아닌 사용자는 접근할 수 없다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-OBJECT-004D

- 기능: Admin retention policy 변경
- 조건: ADMIN 사용자가 로그인되어 있다.
- 입력: `PUT /api/admin/object-retention/policy`
- 절차: retention enabled, retentionDays, batchSize, versionRetentionDays, versionBatchSize를 변경한 뒤 status를 다시 조회한다.
- 기대 결과: API는 변경된 enabled, retentionDays, batchSize, versionRetentionDays, versionBatchSize를 반환하고 `OBJECT_RETENTION_POLICY_UPDATE` 감사 로그를 기록한다. `enabled=false`이면 수동 purge는 conflict를 반환하고 scheduler `runNow`는 object/version purge를 수행하지 않는다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-OBJECT-004E

- 기능: object overwrite version snapshot과 version restore
- 조건: 같은 bucket/key에 기존 active object가 있다.
- 입력: REST upload overwrite, `GET /api/buckets/{bucketName}/objects/versions/{objectKey}`, `POST /api/buckets/{bucketName}/objects/versions/{versionId}/restore/{objectKey}`
- 절차: 기존 object를 업로드한 뒤 같은 key로 다시 업로드한다. version 목록에서 이전 snapshot을 확인하고 restore API를 호출한다.
- 기대 결과: 이전 active object가 version으로 저장되고 active object는 새 content로 교체된다. version restore 후 이전 content/tags가 active object로 복구되고 복구 직전 active object도 새 version으로 저장된다. purge/retention purge는 version snapshot도 함께 삭제한다.
- 우선순위: P1
- 자동화 여부: Automated

- Version download/delete extension:
- Input: `GET /api/buckets/{bucketName}/objects/versions/{versionId}/download/{objectKey}`, `DELETE /api/buckets/{bucketName}/objects/versions/{versionId}/delete/{objectKey}`
- Expected: saved version downloads with original bytes and filename; deleting one version removes only that version, decrements bucket usage, and leaves active object unchanged.
- Automated coverage: `BucketObjectFlowTest.bucketAndObjectFlowWorks`
- Presigned/multipart overwrite extension:
- Input: same-key presigned upload complete and same-key multipart upload complete.
- Expected: previous active object is saved as a version before replacement; presigned upload uses `.osmu/uploads/` staging so active object remains unchanged until complete; multipart quota failure aborts upload before active replacement.
- Automated coverage: `ObjectServiceMultipartRefreshTest.presignedOverwriteUploadsToStagingKeyAndSnapshotsOnComplete`, `ObjectServiceMultipartRefreshTest.multipartOverwriteSnapshotsPreviousObjectBeforeComplete`

### TC-OBJECT-004F

- Feature: temporary object share link.
- Preconditions: User has `READ` permission for the target bucket and an active object exists in storage.
- Input: `POST /api/buckets/{bucketName}/objects/share-links`, public `GET /api/public/share-links/{token}`, `GET /api/buckets/{bucketName}/objects/share-links`, `POST /api/buckets/{bucketName}/objects/share-links/cleanup`, `DELETE /api/buckets/{bucketName}/objects/share-links/{linkId}`.
- Steps: Create a password-protected and IP-restricted share link with note, expiry, and max downloads, verify missing/wrong password and blocked IP public download return `404 NOT_FOUND`, download the object through the public URL with the share password and allowed client IP without Bearer token, list share links for the object, verify password-protected/IP-restricted flags/download count/last access, run cleanup, revoke the link, then retry public download.
- Expected: Create returns one-time token/url, `passwordProtected=true`, and `ipRestricted=true`; public download with correct password and allowed IP returns original bytes; list hides token/url and shows password-protected/IP-restricted/max/download count/last access; cleanup reports expired count; revoke returns 204; missing-password, wrong-password, blocked-IP, and revoked token return `404 NOT_FOUND`; create/download/cleanup/revoke audit events are recorded.
- Priority: P1
- Automated: `BucketObjectFlowTest.bucketAndObjectFlowWorks`, `verify-lightweight-prototype.ps1`

### TC-OBJECT-004G

- Feature: scheduled temporary object share link cleanup.
- Preconditions: Expired active share links and non-expired/revoked share links exist.
- Input: `ObjectShareLinkCleanupJob` scheduled run.
- Steps: Run cleanup at a fixed time, then inspect share link status, audit log, and Micrometer counters.
- Expected: Expired active links become `EXPIRED`; future active and revoked links remain unchanged; `OBJECT_SHARE_LINK_CLEANUP` audit is recorded for cleaned links; `osmu.object.share.cleanup.links{result=success}` increases; scheduler run failures increase `osmu.object.share.cleanup.runs{result=failure}`.
- Priority: P1
- Automated: `ObjectShareLinkCleanupJobTest`

### TC-OBJECT-004H

- Feature: admin global object share policy.
- Preconditions: ADMIN user is logged in and an active object exists in storage.
- Input: `GET /api/admin/object-share-policy`, `PUT /api/admin/object-share-policy`, `POST /api/buckets/{bucketName}/objects/share-links`.
- Steps: Enable required password, required IP allowlist, max expiry, and max download cap. Attempt to create a share link without required password/IP, attempt to exceed max downloads, then create a valid link while omitting `maxDownloads`.
- Expected: Policy read/write round-trips; invalid share link creates return `400 VALIDATION_ERROR`; valid link gets required password/IP metadata and policy default `maxDownloadsLimit`; `OBJECT_SHARE_POLICY_SAVE` audit event is recorded.
- Priority: P1
- Automated: `AdminObjectSharePolicyControllerTest.adminCanManageObjectSharePolicyAndPolicyIsEnforced`, `verify-lightweight-prototype.ps1`

### TC-OBJECT-004I

- Feature: admin object share analytics.
- Preconditions: ADMIN user is logged in and one or more object share links exist.
- Input: `GET /api/admin/object-share-analytics?limit=10&bucketName={bucketName}&status=ACTIVE`.
- Steps: Create a password/IP-restricted share link, download it once through the public URL, then query analytics with bucket/status filters.
- Expected: Analytics includes filtered total/status/protection/download counters, `lastAccessedAt`, and recent links without raw token or public URL.
- Priority: P1
- Automated: `AdminObjectSharePolicyControllerTest.adminCanManageObjectSharePolicyAndPolicyIsEnforced`, `verify-lightweight-prototype.ps1`

### TC-OBJECT-005

- 기능: 존재하지 않는 파일 다운로드
- 조건: 버킷은 존재하지만 objectKey가 없다.
- 입력: 없는 objectKey
- 절차: 다운로드 API 호출.
- 기대 결과: HTTP 404, `NOT_FOUND`.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-006

- 기능: 권한 없는 파일 접근 차단
- 조건: 사용자에게 해당 버킷 읽기 권한이 없다.
- 입력: 다운로드 요청
- 절차: Object download API 호출.
- 기대 결과: HTTP 403, `AUTHORIZATION_FAILED`.
- 우선순위: P1
- 자동화 여부: Automated

### TC-OBJECT-007

- 기능: prefix 기반 파일 목록 조회
- 조건: 같은 버킷에 `docs/sample.txt`, `images/sample.png`가 존재한다.
- 입력: `GET /api/buckets/{bucketName}/objects?prefix=docs/`
- 절차: 오브젝트 목록 API를 prefix query와 함께 호출하고 Web Portal ObjectExplorer에서 prefix 검색을 실행한다.
- 기대 결과: API와 화면 목록에 `docs/` prefix와 일치하는 object만 표시되고 `images/sample.png`는 제외된다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-008

- 기능: object 목록 cursor pagination
- 조건: 같은 버킷에 key 정렬 기준으로 2개 이상의 object가 존재한다.
- 입력: `GET /api/buckets/{bucketName}/objects?limit=1`, 이후 `cursor = nextCursor`
- 절차: 첫 페이지 응답의 `nextCursor`를 사용해 다음 페이지를 조회하고, Web Portal에서 `다음 파일` 버튼을 클릭한다.
- 기대 결과: 첫 페이지는 limit 수만 반환하고 `nextCursor`를 포함한다. 다음 페이지는 이전 마지막 key 이후 object부터 반환하고 화면 목록 뒤에 추가된다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-009

- 기능: delimiter 기반 폴더형 prefix 탐색
- 조건: 같은 버킷에 `docs/sample.txt`, `docs/2026/report.txt`가 존재한다.
- 입력: `GET /api/buckets/{bucketName}/objects?prefix=docs/&delimiter=/`
- 절차: Object API를 delimiter query와 함께 호출하고 Web Portal에서 하위 prefix를 열고 상위로 이동한다.
- 기대 결과: 응답 `prefixes`에 `docs/2026/`가 포함되고, 현재 prefix 바로 아래 object인 `docs/sample.txt`만 `items`에 표시된다. 하위 prefix를 열면 `docs/2026/report.txt`가 표시된다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-010

- 기능: object key 검색
- 조건: 같은 버킷에 `docs/sample.txt`, `docs/2026/report.txt`가 존재한다.
- 입력: `GET /api/buckets/{bucketName}/objects?prefix=docs/&delimiter=/&search=report`
- 절차: Object API를 search query와 함께 호출하고 Web Portal ObjectExplorer에서 검색어를 입력해 조회한다.
- 기대 결과: 현재 prefix 아래 object key 중 `report`를 포함한 `docs/2026/report.txt`만 `items`에 표시되고 `prefixes`는 비어 있다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-011

- 기능: object tag 저장과 tag filter 조회
- 조건: 버킷이 존재하고 사용자에게 쓰기/읽기 권한이 있다.
- 입력: `POST /api/buckets/{bucketName}/objects` with `tags = project=osmu,stage=raw`, 이후 `GET /api/buckets/{bucketName}/objects?tag=project=osmu`
- 절차: tag가 포함된 object를 업로드하고 tag filter로 목록을 조회한다.
- 기대 결과: 업로드 응답과 목록 응답에 object tags가 포함되고, tag exact match object만 반환된다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-012

- 기능: object tag 수정
- 조건: tag가 포함된 object가 존재하고 사용자에게 쓰기 권한이 있다.
- 입력: `PUT /api/buckets/{bucketName}/objects/tags` with `key`, `tags = project=archive,stage=curated`
- 절차: object tag 수정 API를 호출하고 변경된 tag로 object 목록을 조회한다.
- 기대 결과: 수정 응답에 새 tags가 포함되고, 새 tag filter에서 object가 조회되며 감사 로그 `OBJECT_TAG_UPDATE`가 기록된다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-013

- 기능: presigned upload object tag 적용
- 조건: MinIO storage mode이고 사용자에게 쓰기 권한이 있다.
- 입력: `POST /api/buckets/{bucketName}/objects/presigned-upload` with `tags = project=osmu,stage=raw`, PUT 업로드, `presigned-upload/complete`
- 절차: tag가 포함된 presigned upload URL을 발급받고 object 업로드 후 complete API를 호출한다.
- 기대 결과: complete 응답과 목록 응답에 session tags가 object tags로 포함되고, `GET /objects?tag=project=osmu`에서 조회된다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-014

- 기능: object metadata index 갱신
- 조건: Backend upload/delete/tag update를 수행할 수 있는 bucket이 존재한다.
- 입력: object upload, `GET /objects`, `PUT /objects/tags`, `DELETE /objects/{key}`
- 절차: 업로드 후 목록에서 object를 조회하고, tag 수정 후 tag filter로 조회한 뒤 삭제 후 목록에서 제외되는지 확인한다.
- 기대 결과: object metadata index가 쓰기 작업과 동기화되어 목록/search/tag filter 결과가 즉시 반영된다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-015

- 기능: object tag inverted index 갱신
- 조건: MariaDB metadata mode이고 tag가 포함된 object가 존재한다.
- 입력: upload tags `project=osmu,stage=raw`, tag update `project=archive,stage=curated`, tag filter query
- 절차: tag upload/update/sync 이후 `GET /api/buckets/{bucketName}/objects?tag=...`를 호출한다.
- 기대 결과: `object_metadata_tags` lookup index 기준 후보 object가 조회되고, tag 변경 전 값으로는 조회되지 않으며 변경 후 값으로 조회된다.
- 우선순위: P1
- 자동화 여부: Automated (`scripts/verify-docker-integration.ps1` MariaDB object tag index smoke; requires Docker/MariaDB gate).

### TC-OBJECT-016

- 기능: object metadata 상세 조회
- 조건: tag가 포함된 object가 존재하고 사용자에게 읽기 권한이 있다.
- 입력: `GET /api/buckets/{bucketName}/objects/metadata/{objectKey}`
- 절차: object upload 후 metadata 상세 API를 호출하고, tag 수정 후 다시 상세 API를 호출한다.
- 기대 결과: key, sizeBytes, contentType, etag, checksums, lastModifiedAt, tags가 반환되고 tag 수정 이후 상세 응답도 갱신된다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-017

- 기능: object tag validation
- 조건: 버킷이 존재하고 사용자에게 쓰기 권한이 있다.
- 입력: invalid tag key `bad key=value`, 257자 tag value
- 절차: invalid tags로 object upload 또는 tag update를 호출한다.
- 기대 결과: HTTP 400, `VALIDATION_ERROR`. tag key는 128자 이하와 허용 문자 정책을 따르고 tag value는 256자 이하이며 제어 문자를 허용하지 않는다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-018

- 기능: object metadata drift status
- 조건: Backend upload로 index에 반영된 object를 storage 경로에서 직접 덮어쓴다.
- 입력: `GET /api/buckets/{bucketName}/objects/metadata/{objectKey}`, 이후 `POST /api/buckets/{bucketName}/sync`
- 절차: 직접 덮어쓰기 전후 상세 API를 호출하고 sync 후 다시 상세 API를 호출한다.
- 기대 결과: index와 storage actual이 다르면 `syncStatus = STALE`, sync 후에는 `SYNCED`가 반환된다. storage actual fields가 함께 반환된다. sync 시 ETag가 바뀐 object의 stale checksum metadata는 보존되지 않는다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-019

- 기능: direct upload stream 처리
- 조건: Backend direct upload API와 storage adapter가 실행 중이다.
- 입력: multipart upload file
- 절차: `POST /api/buckets/{bucketName}/objects` 업로드 요청을 수행한다.
- 기대 결과: Controller가 multipart file stream과 size를 service/storage adapter로 전달하고 MinIO mode에서는 전체 파일을 JVM byte array로 복사하지 않는다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-020

- 기능: direct download stream 처리
- 조건: Backend download API와 storage adapter가 실행 중이고 object가 존재한다.
- 입력: `GET /api/buckets/{bucketName}/objects/{objectKey}`
- 절차: 다운로드 API를 호출한다.
- 기대 결과: Controller가 `StreamingResponseBody`로 object stream을 응답하고 MinIO mode에서는 전체 파일을 JVM byte array로 복사하지 않는다. 응답은 object content type, content length, attachment filename을 포함한다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-021

- 기능: multipart upload presigned URL 발급과 complete
- 조건: MinIO storage mode이고 사용자가 `WRITE` 권한을 가진다.
- 입력: `POST /api/buckets/{bucketName}/objects/multipart-upload`, part PUT ETag 목록, `multipart-upload/complete`
- 절차: multipart upload URL을 발급받고 각 part를 presigned PUT URL로 업로드한 뒤 complete API를 호출한다.
- 기대 결과: MinIO multipart object가 완성되고 object metadata index, bucket usage, object tag가 갱신된다. in-memory mode에서는 `STORAGE_ERROR`, 권한 없는 사용자는 `403 AUTHORIZATION_FAILED`를 반환한다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-OBJECT-022

- 기능: multipart upload abort
- 조건: ACTIVE multipart upload session이 존재한다.
- 입력: `POST /api/buckets/{bucketName}/objects/multipart-upload/abort`
- 절차: multipart upload 중 취소 또는 실패 시 abort API를 호출한다.
- 기대 결과: MinIO multipart upload가 abort되고 upload session 상태가 `ABORTED`가 되며, 감사 로그 `OBJECT_MULTIPART_UPLOAD_ABORT`가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-OBJECT-023

- 기능: 만료 multipart upload 자동 정리
- 조건: `ACTIVE` multipart upload session이 만료되었고 storage upload id가 존재한다.
- 입력: cleanup scheduler 실행 시점의 현재 시간
- 절차: 만료된 multipart upload session을 생성한 뒤 `MultipartUploadCleanupJob`이 실행되도록 한다.
- 기대 결과: Backend가 MinIO multipart upload를 abort하고 upload session 상태를 `EXPIRED`로 변경한다. cleanup 성공/실패는 `OBJECT_MULTIPART_UPLOAD_CLEANUP` 감사 로그와 `osmu.multipart.cleanup.sessions` metric으로 기록된다. abort 실패 시 session은 `ACTIVE`로 유지되어 다음 cleanup 주기에 재시도할 수 있다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-OBJECT-024

- 기능: multipart upload part URL 재발급
- 조건: `ACTIVE` multipart upload session이 있고 session에 `partSizeBytes`, `partCount`, storage upload id가 저장되어 있다.
- 입력: `POST /api/buckets/{bucketName}/objects/multipart-upload/refresh`
- 절차: multipart upload create 후 같은 `uploadId`, `key`로 refresh API를 호출한다.
- 기대 결과: Backend가 기존 storage upload id로 새 part presigned PUT URL 목록을 반환하고, 응답의 byte range는 원래 part plan과 일치한다. 성공 시 `OBJECT_MULTIPART_UPLOAD_REFRESH` 감사 로그가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-OBJECT-025

- 기능: multipart upload uploaded part 조회
- 조건: `ACTIVE` multipart upload session이 있고 일부 part가 MinIO에 업로드되어 있다.
- 입력: `POST /api/buckets/{bucketName}/objects/multipart-upload/parts`
- 절차: multipart upload create 후 일부 part를 업로드한 상태에서 parts API를 호출한다.
- 기대 결과: Backend가 MinIO `listParts` 결과의 partNumber, ETag, sizeBytes를 반환한다. 성공 시 `OBJECT_MULTIPART_UPLOAD_PARTS_LIST` 감사 로그가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

## 7. Access Key

### TC-KEY-001

- 기능: Access Key 생성
- 조건: 로그인한 사용자가 있다.
- 입력: key name, optional `expiresAt`
- 절차: `POST /api/access-keys` 호출.
- 기대 결과: accessKey와 secretKey 반환. secretKey는 1회만 표시되며 화면은 재조회 불가와 분실 시 rotate 필요를 안내한다. `expiresAt`이 지정되면 목록에 표시되고 과거 시각은 validation error로 거부된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-KEY-002

- 기능: Secret Key 재조회 차단
- 조건: Access Key가 이미 생성되어 있다.
- 입력: Access Key 목록 조회.
- 절차: `GET /api/access-keys` 호출.
- 기대 결과: secretKey 원문은 반환되지 않는다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-KEY-003

- 기능: Access Key 비활성화
- 조건: 활성 Access Key가 존재한다.
- 입력: `DELETE /api/access-keys/{keyId}`
- 절차: Access Key 삭제 API 호출.
- 기대 결과: 상태가 비활성화되고 감사 로그가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-KEY-004

- 기능: Access Key bucket scope와 permission 생성
- 조건: 로그인한 사용자가 접근 가능한 bucket이 있다.
- 입력: `allowedBuckets`, `permissions` 또는 `bucketScopes`
- 절차: `POST /api/access-keys` 호출 후 `GET /api/access-keys` 조회.
- 기대 결과: 지정한 bucket별 scope와 사용자가 가진 범위 안의 `READ`, `WRITE`, `DELETE` permission이 저장/조회되고 S3 policy document가 생성된다. scope가 없으면 발급 버튼은 비활성화되고 화면은 최소 1개 bucket scope와 permission이 필요하다고 안내한다. 사용자가 가진 권한을 초과한 permission은 `403 AUTHORIZATION_FAILED`로 차단된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-KEY-005

- 기능: 타인 bucket scope 차단
- 조건: 일반 사용자가 타인 bucket 이름을 알고 있다.
- 입력: 타인 bucket이 포함된 `allowedBuckets`
- 절차: `POST /api/access-keys` 호출.
- 기대 결과: `403 AUTHORIZATION_FAILED`.
- 우선순위: P1
- 자동화 여부: Automated

### TC-KEY-006

- 기능: Access Key provisioning 실패 보상
- 조건: MinIO provisioning command가 실패한다.
- 입력: access key 생성 요청.
- 절차: `POST /api/access-keys` 실패 후 `GET /api/access-keys` 조회.
- 기대 결과: `502 STORAGE_ERROR`가 반환되고 사용할 수 없는 access key metadata가 남지 않는다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-KEY-007

- 기능: 사용자 비활성화 시 Access Key 자동 비활성화
- 조건: 활성 사용자와 해당 사용자가 생성한 활성 Access Key가 존재한다.
- 입력: `PATCH /api/admin/users/{userId}/status` with `INACTIVE`
- 절차: admin이 사용자를 비활성화한 뒤 Access Key 목록을 조회한다.
- 기대 결과: 해당 사용자의 활성 Access Key가 `INACTIVE`로 변경되고 S3 provisioner 비활성화가 호출된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-KEY-007B

- Feature: User deactivation blocks existing access tokens
- Condition: Active user/admin has an issued access token.
- Input: `PATCH /api/admin/users/{userId}/status` with `INACTIVE`, then call an authenticated API with the old access token.
- Steps: Login as the target user, deactivate that user as admin, call `/api/users/me` or an admin endpoint with the old access token.
- Expected: Request returns HTTP 401, `AUTHENTICATION_REQUIRED`.
- Priority: P1
- Automation: `AdminUserControllerTest.adminCanCreateListAndDisableUser`, `AdminUserControllerTest.inactiveAdminAccessTokenCannotUseClaimOnlyAdminEndpoint`

### TC-KEY-008

- Feature: Access Key last used tracking
- Condition: Active Access Key exists with `READ` or `WRITE` scope for a bucket.
- Input: S3-style request with `X-OSMU-Access-Key` and `X-OSMU-Secret-Key`.
- Steps: Create an Access Key, use it for `PUT /api/s3/{bucketName}/{objectKey}` or `GET /api/s3`, then call `GET /api/access-keys`.
- Expected: The matching Access Key record has non-empty `lastUsedAt`; secret values are still omitted from the list response.
- Priority: P1
- Automated: `AccessKeyControllerTest.accessKeyListShowsLastUsedAtAfterS3Request`

### TC-KEY-009

- Feature: Access Key secret rotation
- Condition: Active Access Key exists with `READ` and `WRITE` scope for a bucket.
- Input: `POST /api/access-keys/{keyId}/rotate`.
- Steps: Create an Access Key, rotate it, use the old secret for `PUT /api/s3/{bucketName}/{objectKey}`, then use the rotated secret for the same S3-style path.
- Expected: Rotation response returns a one-time `secretKey` with the same `id` and `accessKey`; the old secret returns HTTP 401; the rotated secret succeeds; list responses still omit secret values.
- Priority: P1
- Automated: `AccessKeyControllerTest.rotateAccessKeyReturnsNewSecretAndInvalidatesOldSecret`, `api-access-key.test.js`, `HomeView.test.js`

### TC-KEY-010

- Feature: Access Key expiration UX
- Condition: User is logged in and can create an Access Key for at least one bucket.
- Input: `access-key-expires-at-input` datetime-local value.
- Steps: Enter key name, expiration datetime, bucket scope, submit Access Key creation, then list Access Keys.
- Expected: Frontend sends ISO `expiresAt` or `null` when blank; list displays `Expires`; backend rejects past expiration via request validation; expired keys cannot authenticate or rotate.
- Priority: P1
- Automated: `HomeView.test.js`, `api-access-key.test.js`; backend validation execution pending local Java fix.

### TC-KEY-011

- Feature: Access Key operational dashboard summary
- Condition: Dashboard has Access Key widget enabled and Access Key list contains active, inactive, expired, expiring, never-used, and stale-used keys.
- Input: Access Key list with `status`, `expiresAt`, and `lastUsedAt`.
- Steps: Load Dashboard and inspect the `access-keys` widget.
- Expected: Widget shows active count, total count, provisioner health, expired active key count, keys expiring within 7 days, and unused count where unused means never used or last used more than 30 days ago.
- Priority: P1
- Automated: `accessKeys.test.js`, `HomeView.test.js`

### TC-KEY-012

- Feature: Access Key operational list filters
- Condition: Access Key list contains active, inactive, expired, expiring, never-used, and stale-used keys.
- Input: Access Key filter buttons `All`, `Active`, `Expired`, `Expiring`, `Unused`, `Inactive`.
- Steps: Open Admin or Developer Access Key panel and select each filter.
- Expected: List shows only keys matching the selected filter. `Expired` and `Expiring` are based on active key `expiresAt`; `Unused` includes active keys never used or last used more than 30 days ago; `Inactive` shows non-active keys.
- Priority: P1
- Automated: `accessKeys.test.js`, `HomeView.test.js`. Browser click E2E pending.

### TC-KEY-013

- Feature: Access Key operational action hints
- Condition: Access Key list contains active expired, active expiring, never-used, stale-used, healthy active, and inactive keys.
- Input: Access Key list with `status`, `expiresAt`, and `lastUsedAt`.
- Steps: Open Admin or Developer Access Key panel and inspect each row action hint.
- Expected: Expired active keys show a disable cleanup hint, expiring keys show a rotate-soon hint, never-used and stale-used keys show review/disable hints, healthy active keys show no immediate action, and inactive keys are marked as already blocked.
- Priority: P1
- Automated: `accessKeys.test.js`, `HomeView.test.js`. Browser row render E2E pending.

### TC-KEY-014

- Feature: Access Key bulk cleanup workflow
- Condition: Access Key list contains active expired, never-used, stale-used, expiring, healthy active, and inactive keys.
- Input: Access Key cleanup candidate summary, candidate checkboxes, preview list, `Export preview`, and `Bulk disable` button.
- Steps: Open Admin or Developer Access Key panel, verify cleanup candidate count, inspect candidate names/reasons, exclude one candidate with its checkbox, export the preview JSON, click bulk disable, confirm the dialog.
- Expected: Candidate ids include expired active keys and unused active keys only. The preview list shows each candidate key name, id, action label, and reason before execution. Exported JSON uses `schemaVersion = osmu.access-key-cleanup-preview.v1`, includes generated time, candidate count, selected/excluded counts, selected/excluded ids, labels, and reasons, and excludes secret values. Expiring-but-recent, healthy active, and inactive keys are excluded. Confirming calls `POST /api/access-keys/bulk-disable` with selected ids only, refreshes the dashboard/access key list, and shows disabled/skipped counts.
- Priority: P1
- Automated: `AccessKeyControllerTest.bulkDisableAccessKeysDisablesActiveKeysAndSkipsInactiveKeys`, `api-access-key.test.js`, `accessKeys.test.js`, `HomeView.test.js`. Browser confirm E2E pending.

## 8. Quota

### TC-KEY-007A

- Feature: User deactivation revokes refresh tokens
- Condition: Active user has an active login session and refresh token.
- Input: `PATCH /api/admin/users/{userId}/status` with `INACTIVE`, then `POST /api/auth/refresh`
- Steps: Login as the user, deactivate the user as admin, try refreshing with the old refresh token.
- Expected: Refresh returns HTTP 401, `AUTHENTICATION_REQUIRED`.
- Priority: P1
- Automation: Automated

### TC-QUOTA-001

- 기능: 쿼터 이내 업로드 허용
- 조건: 버킷 쿼터가 남아 있다.
- 입력: 쿼터보다 작은 파일.
- 절차: 파일 업로드 API 호출.
- 기대 결과: 업로드 성공.
- 우선순위: P1
- 자동화 여부: Automated

### TC-QUOTA-002

- 기능: 쿼터 초과 업로드 차단
- 조건: 버킷 쿼터가 거의 다 찼다.
- 입력: 남은 용량보다 큰 파일.
- 절차: 파일 업로드 API 호출.
- 기대 결과: HTTP 413 또는 `QUOTA_EXCEEDED`.
- 우선순위: P1
- 자동화 여부: Automated

### TC-QUOTA-003

- 기능: 사용자 quota policy 초과 업로드 차단
- 조건: admin이 `USER` target quota policy를 설정했고, 해당 user가 소유한 bucket이 존재한다.
- 입력: `PUT /api/admin/quota-policies/USER/{userId}`, 이후 quota보다 큰 파일 업로드.
- 절차: admin이 user quota policy를 저장하고, 해당 user token으로 bucket object upload API를 호출한다.
- 기대 결과: 업로드가 HTTP 413, `QUOTA_EXCEEDED`로 차단된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-QUOTA-004

- 기능: quota policy 관리 API
- 조건: admin token과 존재하는 user target이 있다.
- 입력: `GET/PUT/DELETE /api/admin/quota-policies`.
- 절차: user quota policy를 생성하고 목록에서 확인한 뒤 삭제한다.
- 기대 결과: 생성 응답에 `targetType`, `targetId`, `quotaBytes`, `usedBytes`, `remainingBytes`가 포함되고, 삭제 후 목록에서 제거된다. `QUOTA_POLICY_SAVE`/`QUOTA_POLICY_DELETE` 감사 로그와 quota policy history가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-QUOTA-005

- 기능: 버킷 quota policy 초과 업로드 차단
- 조건: admin이 `BUCKET` target quota policy를 설정했고, 해당 bucket의 기본 quota는 더 크게 설정되어 있다.
- 입력: `PUT /api/admin/quota-policies/BUCKET/{bucketId}`, 이후 policy quota보다 큰 파일 업로드.
- 절차: bucket 생성 후 bucket quota policy를 저장하고, bucket object upload API를 호출한다.
- 기대 결과: bucket metadata quota가 남아 있어도 업로드가 HTTP 413, `QUOTA_EXCEEDED`로 차단된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-QUOTA-006

- 기능: 조직 quota policy 초과 업로드 차단
- 조건: admin이 `ORGANIZATION` target quota policy를 설정했고, 해당 organization의 default quota는 더 크게 설정되어 있다.
- 입력: `PUT /api/admin/quota-policies/ORGANIZATION/{organizationId}`, 이후 policy quota보다 큰 파일 업로드.
- 절차: organization bucket 생성 후 organization quota policy를 저장하고, org bucket object upload API를 호출한다.
- 기대 결과: organization default quota가 남아 있어도 업로드가 HTTP 413, `QUOTA_EXCEEDED`로 차단된다.
- 우선순위: P1
- 자동화 여부: Automated

## 9. Audit Log

### TC-AUDIT-001

- 기능: 버킷 생성 감사 로그
- 조건: 사용자가 버킷을 생성한다.
- 입력: Bucket create request
- 절차: 버킷 생성 후 감사 로그 조회.
- 기대 결과: `BUCKET_CREATED` 이벤트가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-AUDIT-002

- 기능: 파일 삭제 감사 로그
- 조건: 사용자가 파일을 삭제한다.
- 입력: Object delete request
- 절차: 파일 삭제 후 감사 로그 조회.
- 기대 결과: `OBJECT_DELETED` 이벤트가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-AUDIT-003

- 기능: 로그인 실패 감사 로그
- 조건: 잘못된 비밀번호로 로그인 시도.
- 입력: 잘못된 password
- 절차: 로그인 API 호출 후 감사 로그 조회.
- 기대 결과: `LOGIN_FAILED` 이벤트가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-AUDIT-004

- 기능: 감사 로그 필터 조회
- 조건: 서로 다른 eventType, actorId, requestId, targetType, targetId, result의 감사 로그가 존재한다.
- 입력: `eventType`, `actorId`, `requestId`, `targetType`, `targetId`, `result`, `from`, `to`, `limit`, `cursor` query
- 절차: `GET /api/admin/audit-logs`를 filter query와 함께 호출하고 `nextCursor`가 있으면 같은 filter와 cursor로 다음 페이지를 호출한다.
- 기대 결과: 조건에 맞는 감사 로그만 최신순으로 반환하고 `requestId`, `targetId`, `result` 정확 일치와 `limit` 범위를 적용한다. 다음 페이지는 이전 페이지 마지막 id보다 작은 로그부터 반환한다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-AUDIT-005

- 기능: request id 응답 전파와 감사 로그 기록
- 조건: 로그인 API를 호출할 수 있다.
- 입력: `X-Request-Id`가 있거나 없는 로그인 요청, 인증 없는 보호 API 요청.
- 절차: 로그인 응답의 `X-Request-Id` header를 확인하고 감사 로그를 조회한다. 인증 실패 응답 body를 확인한다.
- 기대 결과: 요청에 `X-Request-Id`가 있으면 같은 값이 응답 header에 기록되고 오류 응답이면 error body에도 포함된다. 로그인 감사 로그도 같은 request id를 기록한다. 없으면 Backend가 새 request id를 생성해 같은 규칙을 적용한다.
- 우선순위: P1
- 자동화 여부: Automated

### TC-AUDIT-006

- 기능: 파일 다운로드 감사 로그
- 조건: 다운로드 가능한 object가 존재하고 사용자가 `READ` 권한을 가진다.
- 입력: `GET /api/buckets/{bucketName}/objects/{objectKey}`
- 절차: 파일 다운로드 후 감사 로그를 조회한다.
- 기대 결과: `OBJECT_DOWNLOAD`, targetType `OBJECT`, targetId `{bucketName}/{objectKey}`, result `SUCCESS` 감사 로그가 기록된다.
- 우선순위: P1
- 자동화 여부: Automated

## 10. Frontend

### TC-FE-001

- 기능: 버킷 목록 화면
- 조건: Backend가 실행 중이고 버킷이 존재한다.
- 입력: `/buckets` 접근.
- 절차: 브라우저에서 버킷 목록 화면 진입.
- 기대 결과: 버킷 목록이 표시된다.
- 우선순위: P1
- 자동화 여부: Automated (`scripts/verify-docker-integration.ps1` MariaDB object tag index smoke; requires Docker/MariaDB gate).

### TC-FE-002

- 기능: 파일 업로드 화면
- 조건: 버킷이 존재한다.
- 입력: 파일 선택 후 업로드.
- 절차: ObjectExplorer에서 업로드 실행.
- 기대 결과: 업로드 중 진행률과 전송 bytes가 표시되고 중복 업로드가 차단되며, 완료 후 목록에 파일이 나타난다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` object metadata drift status/detail row helpers). Browser panel render E2E pending.

### TC-FE-003

- 기능: 삭제 확인 모달
- 조건: 삭제 가능한 버킷, 파일 또는 권한이 존재한다.
- 입력: 삭제/회수 버튼 클릭.
- 절차: 확인 모달에서 취소 후 재시도하고 확인한다.
- 기대 결과: 취소 전에는 API가 호출되지 않고, 확인 후 삭제/회수 API가 호출된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` confirm dialog state helper; cancel does not run action, confirm runs action once, false result keeps modal open, pending blocks close). Browser click E2E pending.

### TC-FE-004

- 기능: Access Key multi bucket scope 생성 화면
- 조건: 접근 가능한 bucket이 2개 이상 존재한다.
- 입력: bucket A `READ`, bucket B `WRITE`
- 절차: Access Key form에서 bucket별 permission scope를 추가하고 발급한다.
- 기대 결과: 요청 payload가 `bucketScopes` 배열로 전송되고, 생성된 Access Key 목록에 bucket별 scope가 표시된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` access key scope helper and API wrapper payload). Browser click/list render E2E pending.

### TC-FE-005

- 기능: Access Key 비활성화 화면
- 조건: 활성 Access Key가 존재한다.
- 입력: Access Key 목록의 `비활성화` 버튼 클릭.
- 절차: 확인 모달에서 비활성화를 확정하고 목록을 새로고침한다.
- 기대 결과: 확인 전에는 API가 호출되지 않고, 확정 후 `DELETE /api/access-keys/{keyId}`가 호출되며 해당 key 상태가 `INACTIVE`로 표시된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` access key delete API wrapper). Confirm modal/browser refresh E2E pending.

### TC-FE-006

- 기능: 파일 다운로드 401 refresh retry
- 조건: access token은 만료되었고 refresh token은 유효하다.
- 입력: 다운로드 버튼 클릭.
- 절차: Web Portal에서 파일 다운로드를 요청한다.
- 기대 결과: 최초 다운로드 요청이 401이면 refresh API를 1회 호출하고 새 access token으로 다운로드를 재시도한다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` API client unit). Browser click E2E pending.

### TC-FE-007

- 기능: refresh 실패 시 session state 정리
- 조건: access token과 refresh token이 모두 만료되었거나 폐기되었다.
- 입력: 인증이 필요한 API 요청.
- 절차: Web Portal에서 API 요청 후 refresh API 실패 응답을 받는다.
- 기대 결과: API client token과 화면 session이 모두 정리되고 dashboard/bucket/object/access key/admin 목록이 비워진다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` authStore/API client unit). Browser click E2E pending.

### TC-FE-008

- 기능: authStore session/token 동기화
- 조건: login, refresh, logout 흐름이 가능하다.
- 입력: 로그인 성공, refresh 성공, logout 실행.
- 절차: API client token 변경 이벤트를 authStore가 수신한다.
- 기대 결과: authStore의 access token, refresh token, role computed가 화면 권한 제어와 일관되게 반영된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` authStore unit). Browser click E2E pending.

### TC-FE-009

- 기능: 새로고침 후 session 복구
- 조건: 로그인 성공 후 같은 browser tab의 sessionStorage에 token이 저장되어 있다.
- 입력: Web Portal 새로고침.
- 절차: authStore가 저장된 token을 API client에 적용하고 `/api/users/me`를 호출한다.
- 기대 결과: user 정보와 role computed가 복구되고 dashboard가 자동 로드된다. `/api/users/me` 실패 시 token과 화면 데이터가 정리된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` authStore restore unit). Browser reload E2E pending.

### TC-FE-010

- 기능: 감사 로그 필터 화면
- 조건: ADMIN으로 로그인했고 감사 로그가 존재한다.
- 입력: eventType, actorId, requestId, targetType, targetId, result, 기간, limit 입력 후 필터 클릭, 다음 로그 클릭.
- 절차: AdminAuditLogView에서 감사 로그 필터를 적용하고 `nextCursor`가 있으면 다음 로그를 로드한다.
- 기대 결과: `/api/admin/audit-logs`에 filter query가 전송되고 결과 목록이 갱신된다. 다음 로그 클릭 시 같은 filter와 cursor query가 전송되고 결과가 목록 뒤에 추가된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` API filter/export wrapper). Browser click E2E pending.

### TC-FE-011

- 기능: 파일 업로드 취소/재시도
- 조건: 버킷이 존재하고 대용량 파일 업로드가 진행 중이다.
- 입력: 업로드 중 취소 클릭, 이후 재시도 클릭.
- 절차: ObjectExplorer에서 업로드를 시작한 뒤 취소하고, 같은 파일을 재시도한다.
- 기대 결과: 취소 시 진행 중인 XHR 요청이 abort되고 중복 업로드가 풀린다. 재시도 시 마지막 bucket/key/file로 업로드가 다시 실행되고 성공 후 object 목록이 갱신된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` single-object XHR abort and same-file retry API path). Browser button/list refresh E2E pending.

### TC-FE-012

- 기능: 오류 alert request id 표시
- 조건: Backend가 `error.requestId` 또는 `X-Request-Id`를 포함한 오류 응답을 반환한다.
- 입력: 권한 없는 API 요청 또는 validation error.
- 절차: Web Portal에서 오류가 발생하는 작업을 수행한다.
- 기대 결과: alert에 사용자용 오류 메시지와 `Request ID`가 함께 표시된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` API client `error.requestId`, `X-Request-Id`, S3 XML `RequestId` extraction). Browser alert E2E는 pending.

### TC-FE-013

- 기능: Object Explorer page size 선택
- 조건: object list API가 `limit` query를 지원하고 버킷에 여러 object 또는 prefix가 존재한다.
- 입력: page size select에서 `50`, `100`, `250`, `500`, `1000` 중 하나 선택.
- 절차: ObjectExplorer에서 page size를 변경하고 목록을 조회한 뒤 `다음 항목`을 클릭한다.
- 기대 결과: 첫 목록 조회와 다음 항목 조회 모두 선택한 `limit` 값으로 API를 호출하고, page size 변경 시 cursor 없이 첫 페이지부터 다시 조회한다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` object list query wrapper). Browser click E2E pending.

### TC-FE-014

- 기능: Object Explorer prefix breadcrumb 이동
- 조건: 현재 prefix가 `docs/2026/`이고 상위 prefix가 존재한다.
- 입력: breadcrumb `/`, `docs` 버튼 클릭.
- 절차: ObjectExplorer에서 breadcrumb 버튼을 클릭한다.
- 기대 결과: 선택한 breadcrumb prefix로 `objectPrefix`가 변경되고 cursor 없이 해당 prefix의 첫 페이지를 조회한다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` object explorer breadcrumb utility). Browser click E2E pending.

### TC-FE-015

- 기능: Object Explorer 검색어 highlight
- 조건: object key 검색 결과가 존재한다.
- 입력: 검색어 `report`
- 절차: ObjectExplorer에서 검색어를 입력하고 조회한다.
- 기대 결과: 검색 결과 object key 안의 `report` 문자열이 강조 표시되고, 원본 key 문자열은 손상되지 않는다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` object key search highlight utility). Browser render E2E pending.

### TC-FE-016

- 기능: Object Explorer object tag 입력/표시/filter
- 조건: 버킷이 존재하고 object 업로드가 가능하다.
- 입력: upload tags `project=osmu,stage=raw`, filter tag `project=osmu`
- 절차: ObjectExplorer에서 tag와 함께 업로드하고 tag filter로 조회한다.
- 기대 결과: 업로드 요청에 `tags` form field가 포함되고 목록 태그 열에 `project=osmu, stage=raw`가 표시된다. tag filter 조회 시 `tag=project=osmu` query가 전송된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` tag parser and object list tag query wrapper). Browser upload/filter E2E pending.

### TC-FE-017

- 기능: Object Explorer object tag 수정
- 조건: tag가 있는 object가 목록에 표시된다.
- 입력: 목록의 `태그` 버튼, tags `project=archive,stage=curated`
- 절차: ObjectExplorer에서 object의 `태그` 버튼을 눌러 tag form을 채우고 저장한다.
- 기대 결과: `PUT /api/buckets/{bucketName}/objects/tags` 요청이 전송되고, 목록 tag 열이 새 tag로 갱신된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` object tag update API wrapper). Browser click E2E pending.

### TC-FE-018

- 기능: Object Explorer presigned upload tag 전달
- 조건: presigned upload URL 발급이 가능한 bucket과 object key/tag 입력값이 있다.
- 입력: key `videos/input.mp4`, tags `project=osmu,stage=raw`, presigned upload 버튼
- 절차: ObjectExplorer에서 tag 입력 후 presigned upload URL을 생성하고 complete를 수행한다.
- 기대 결과: URL 발급 요청 body에 `tags`가 포함되고, complete 이후 목록 태그 열에 동일한 tags가 표시된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` presigned upload API wrapper). Browser/MinIO E2E pending.

### TC-FE-019

- 기능: Object Explorer object metadata 상세 패널
- 조건: object 목록에 파일이 표시된다.
- 입력: 목록 row의 `상세` 버튼
- 절차: ObjectExplorer에서 object 상세 버튼을 클릭한다.
- 기대 결과: `GET /api/buckets/{bucketName}/objects/metadata/{objectKey}` 요청이 전송되고 key, size, contentType, ETag, checksums, lastModifiedAt, tags가 패널에 표시된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` object metadata API wrapper). Browser panel E2E pending.

### TC-FE-020

- 기능: Object Explorer object tag 사전 검증
- 조건: object tag 입력 필드가 표시된다.
- 입력: invalid tag key `bad key=value`, 257자 tag value
- 절차: upload/tag update/presigned upload/tag filter 실행 전에 invalid tag를 입력한다.
- 기대 결과: API 요청 전에 오류 메시지가 표시되고 요청이 전송되지 않는다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` tag utility and API client preflight validation; invalid upload/tag update/presigned/multipart/filter blocks network calls). Browser UI error display E2E pending.

### TC-FE-021

- 기능: Object Explorer object metadata drift 표시
- 조건: object metadata 상세 API가 `syncStatus`와 storage actual fields를 반환한다.
- 입력: object 상세 버튼
- 절차: ObjectExplorer에서 object 상세를 열고 sync status badge와 index/storage 값을 확인한다.
- 기대 결과: `SYNCED`, `STALE`, `MISSING_IN_STORAGE` 상태가 각각 다른 badge 색으로 표시되고 index/storage size/type/tag/ETag/checksum이 비교 가능하다.
- 우선순위: P1
- 자동화 여부: Later

### TC-FE-022

- 기능: Object Explorer multipart upload 자동 전환
- 조건: 128 MiB 이상 파일을 업로드할 수 있고 MinIO storage mode가 활성화되어 있다.
- 입력: 128 MiB 이상 파일 선택 후 업로드.
- 절차: ObjectExplorer에서 업로드를 실행한다.
- 기대 결과: Frontend가 multipart upload create API를 호출하고 part별 presigned PUT을 제한된 동시성으로 병렬 수행하며 ETag 목록으로 complete API를 호출한다. 진행률은 전체 파일 기준으로 표시된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` multipart create/part PUT/complete wrapper flow). Browser/MinIO E2E pending.

### TC-FE-023

- 기능: multipart upload 실패/취소 정리
- 조건: multipart upload session이 생성된 뒤 part upload가 실패하거나 사용자가 업로드를 취소한다.
- 입력: 업로드 중 취소 또는 network error.
- 절차: ObjectExplorer에서 multipart upload 중 취소하거나 part PUT 실패를 유발한다.
- 기대 결과: Frontend가 best-effort로 `multipart-upload/abort` API를 호출하고, 사용자는 같은 파일을 재시도할 수 있다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` user cancel abort API/local cleanup). Browser cancel E2E pending.

### TC-FE-027

TC-FE-023 보강: 사용자가 취소한 경우에는 abort API를 호출한다. 네트워크/서버 오류로 실패했지만 사용자가 재시도할 수 있는 경우에는 sessionStorage resume 정보를 보존하고 TC-FE-025 흐름으로 이어간다.

- 기능: multipart part upload 일시 실패 재시도
- 조건: multipart upload session이 생성되고 part PUT 중 network error, 408, 429, 5xx 응답이 발생한다.
- 입력: 대용량 파일 업로드 중 일시적인 part PUT 실패
- 절차: ObjectExplorer에서 multipart upload를 실행하고 특정 part PUT을 일시 실패시킨 뒤 다음 시도에서 성공하게 한다.
- 기대 결과: Frontend가 해당 part PUT을 jitter가 적용된 exponential backoff로 재시도하고 성공 후 ETag 목록에 포함해 complete API를 호출한다. abort, 4xx, ETag 미노출 오류는 재시도하지 않고 업로드 실패로 처리한다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` transient 5xx part retry). Browser/MinIO E2E pending.

### TC-FE-025

- 기능: multipart upload retry resume
- 조건: multipart upload 중 일부 part가 성공했고 이후 part PUT 또는 complete 전 단계에서 실패했다.
- 입력: 같은 bucket/key/file/tags로 재시도.
- 절차: 실패 후 Retry 버튼을 누른다.
- 기대 결과: Frontend가 `sessionStorage`에 저장된 `uploadId`와 completed part ETag를 읽고 parts list API로 storage-side 완료 part를 병합한다. 이후 refresh API로 part URL을 재발급받는다. 이미 완료된 part는 다시 업로드하지 않고 남은 part만 업로드한 뒤 complete API를 호출한다. 사용자가 취소한 경우에는 abort API를 호출하고 저장된 resume session을 삭제한다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` failed upload session save, refresh/parts merge, completed part skip, complete cleanup). Browser/MinIO E2E pending.

### TC-FE-026

- 기능: tab reload 후 multipart resume session 복구
- 조건: multipart upload 실패 후 같은 browser tab의 sessionStorage에 resume session이 남아 있다.
- 입력: 페이지 reload, 같은 bucket/key/tags/file 선택.
- 절차: Object Explorer에서 pending multipart 목록을 확인하고 같은 파일을 선택한 뒤 Resume을 실행한다.
- 기대 결과: Frontend가 pending multipart session을 표시하고 file fingerprint가 일치할 때 resume을 허용한다. session `expiresAt`이 지났으면 Expired 상태를 표시하고 Resume을 막는다. Resume 실행 시 parts list API와 refresh API를 호출하고, 완료된 part를 skip한 뒤 남은 part만 업로드한다. Delete 실행 시 해당 resume session이 sessionStorage에서 삭제된다. 만료 후 24시간이 지난 local session은 자동 정리된다.
- 우선순위: P1
- 자동화 여부: Automated (`npm run test:unit` local session list/expired/prune/delete). Browser resume E2E pending.

## 11. Security

### TC-SEC-001

- 기능: 토큰 없는 관리 API 접근 차단
- 조건: 인증 토큰이 없다.
- 입력: Admin API 호출.
- 절차: `GET /api/admin/users` 호출.
- 기대 결과: HTTP 401.
- 우선순위: P1
- 자동화 여부: Automated

### TC-SEC-002

- 기능: 일반 사용자의 관리자 API 접근 차단
- 조건: USER role 토큰이 있다.
- 입력: Admin API 호출.
- 절차: `GET /api/admin/users` 호출.
- 기대 결과: HTTP 403.
- 우선순위: P1
- 자동화 여부: Automated

### TC-SEC-003

- 기능: Secret 로그 노출 방지
- 조건: Access Key 생성 요청 수행.
- 입력: Access Key 생성.
- 절차: 로그 확인.
- 기대 결과: secretKey 원문이 로그에 남지 않는다.
- 우선순위: P1
- 자동화 여부: Automated (`AccessKeyControllerTest.accessKeySecretIsRedactedFromAuditOutputsAndToString`, `verify-local-demo.ps1`/`verify-lightweight-demo.ps1` access key secret redaction smoke). `-BackendLogPath`를 넘기면 실제 backend log file도 생성된 secret 원문 scan 대상에 포함한다.

## 12. Backup and Recovery

### TC-BACKUP-000

- Feature: Backup readiness status API and admin dashboard panel.
- Preconditions: Backend is running. User has `ADMIN` role.
- Input: `GET /api/admin/backup/status`
- Steps: Login as admin, call backup status API, and open admin portal dashboard.
- Expected: API returns `status`, `metadataStore`, `objectStore`, RPO/RTO targets, runbook availability, restore drill execution flag, and pending gates. Lightweight demo returns `DRILL_PENDING` and does not claim durable restore was executed. Admin portal exposes `data-testid="backup-status-panel"`.
- Priority: P1
- Automated: `AdminBackupStatusControllerTest.adminCanReadBackupStatus`, `npm run test:unit` selector contract.

### TC-BACKUP-001

- 기능: MariaDB 백업 가능 여부
- 조건: MariaDB에 기본 데이터가 있다.
- 입력: dump 명령.
- 절차: MariaDB dump 실행.
- 기대 결과: dump 파일 생성.
- 우선순위: P2
- 자동화 여부: Manual

### TC-BACKUP-002

- 기능: MinIO bucket mirror 가능 여부
- 조건: MinIO 버킷에 파일이 있다.
- 입력: `mc mirror`
- 절차: 대상 저장소로 mirror 실행.
- 기대 결과: 대상 저장소에 동일 파일 생성.
- 우선순위: P2
- 자동화 여부: Manual

## 13. Infrastructure

### TC-INFRA-001

- 기능: Docker Compose 통합 smoke test
- 조건: Docker Desktop이 실행 중이고 로컬 포트가 사용 가능하다.
- 입력: `.\scripts\verify-docker-integration.ps1`
- 절차: Compose config 검증, `up -d --build`, Backend health, storage/database health, admin login, bucket 생성, object upload/list, multipart upload, parts list API, refresh API, MinIO CORS `ETag` expose, Frontend HTTP 200 확인을 수행한다.
- 기대 결과: 모든 단계가 통과하고 smoke bucket/object가 정리된다. Multipart part PUT 응답은 browser origin 요청에서 `ETag`를 반환하고 `Access-Control-Expose-Headers`에 `ETag`를 포함한다. 일부 part 업로드 후 parts list API가 uploaded part ETag를 반환하고, refresh API로 재발급된 URL로 남은 part를 업로드해 complete가 성공한다. `-KeepRunning`이 없으면 검증 후 Compose stack이 내려간다.
- 우선순위: P0
- 자동화 여부: Automated

### TC-INFRA-001A

- 기능: Storage Expansion post-run verifier gate
- 조건: apply/rollback runner가 활성화되어 있고 command result가 `SUCCESS`이다.
- 입력: `POST /api/admin/storage-expansion/requests/{requestId}/apply-runner` 또는 `POST /api/admin/storage-expansion/requests/{requestId}/rollback-runner`
- 절차: runner 성공 후 database health, object storage health, S3 put/get/list smoke가 자동 실행되는지 확인한다.
- 기대 결과: execution output/notes에 `postRun=SUCCESS` 또는 `postRun=FAILED`가 기록된다. verifier 실패 시 apply runner는 request를 `APPLIED`로 전환하지 않는다.
- 우선순위: P0
- 자동화 여부: Backend unit test, integration smoke candidate

### TC-INFRA-002

- Feature: Kubernetes manifest draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1`
- Steps: Verify `infra/k8s` contains namespace, configmap, secret example, MariaDB, MinIO, backend, frontend, ingress, kustomization, and README files. Check expected kinds, service/deployment/statefulset names, probes, storage images, secret references, ingress routing, operations readiness convergence report env/mount, optional `osmu-operations-reports` ConfigMap reference, and that `secret.example.yaml` is not included in `kustomization.yaml`.
- Expected: Manifest draft is complete enough for Kubernetes productization work to start, while real secrets remain outside the kustomize resource list and deployed backend Pods can read an operator-provided operations convergence report.
- Priority: P2
- Automated: `scripts/verify-k8s-manifests.ps1`

### TC-INFRA-003

- Feature: Helm chart draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-chart.ps1`
- Steps: Verify `infra/helm/osmu` contains Chart.yaml, values.yaml, README, helper templates, configmap, guarded secret template, MariaDB, MinIO, backend, frontend, and ingress templates. Check expected chart metadata, image value indirection, secret creation guard, probes, service names, ingress routing, required config keys, operations readiness convergence report env/mount values, and ConfigMap/PVC-backed operations report options.
- Expected: Helm chart draft is complete enough for customer/environment value separation work to start, while rendered Secret creation remains disabled by default and customer installs can choose ConfigMap or PVC delivery for operations convergence evidence.
- Priority: P2
- Automated: `scripts/verify-helm-chart.ps1`

### TC-INFRA-004

- Feature: Deployment resource profile draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1` and `powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-chart.ps1`
- Steps: Verify backend, frontend, MariaDB, and MinIO deployment templates/manifests define `resources.requests` and `resources.limits` for CPU and memory.
- Expected: Every runtime container has a starter resource profile so Kubernetes scheduling and customer sizing work can start from explicit values instead of unlimited containers.
- Priority: P2
- Automated: `scripts/verify-k8s-manifests.ps1`, `scripts/verify-helm-chart.ps1`

### TC-INFRA-013

- Feature: Kubernetes operations report ConfigMap sync helper.
- Preconditions: PowerShell is available and the repository contains `scripts/sync-kubernetes-operations-reports.ps1`.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-sync.ps1`
- Steps: Generate a fixture operations readiness convergence report, run the sync helper in plan-only mode, run it with fake `kubectl` in server dry-run mode, and run it with fake `kubectl` in apply mode. Verify the evidence report records the ConfigMap name/key, sync evidence ConfigMap key, source report format, source byte count, SHA256, server dry-run command, apply command, publish-evidence apply command, safety policy, and zero failed checks. In apply mode, verify the helper renders and applies a second ConfigMap manifest that includes `latest-kubernetes-operations-report-sync.json`.
- Expected: Operators can validate and refresh the deployed dashboard operations convergence report and its sync evidence through a repeatable helper, while the default path does not execute `kubectl` and live writes require explicit `-Apply`.
- Priority: P2
- Automated: `scripts/verify-kubernetes-operations-report-sync.ps1`

### TC-INFRA-014

- Feature: Kubernetes operations report sync live dashboard verification.
- Preconditions: PowerShell is available. For fixture mode, the repository contains `scripts/verify-kubernetes-operations-report-sync-live-self-test.ps1`. For deployed mode, the backend API is reachable and an admin login is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-sync-live-self-test.ps1`; deployed mode uses `powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-sync-live.ps1 -ApiBase <api-base> -AdminLoginId <admin> -AdminPassword <secret>`.
- Steps: Validate applied sync evidence, load the dashboard readiness response from a fixture or the deployed API, and verify `operationsReadinessConvergence.kubernetesReportSyncReady`, `operationsReadinessConvergence.kubernetesReportSyncResult`, `kubernetesOperationsReportSync.result`, failed count, and ConfigMap metadata match the applied sync evidence. In API mode, poll dashboard readiness up to `DashboardRetryCount` times with `DashboardRetryDelaySeconds` between attempts so ConfigMap volume refresh latency is tolerated.
- Expected: Operators can prove that a Kubernetes report sync did not merely apply a ConfigMap, but is also visible from the running admin dashboard readiness API. Credentials and bearer tokens are not written to the evidence file, and the evidence records retry count, attempt count, match status, and non-secret polling summaries.
- Priority: P2
- Automated: `scripts/verify-kubernetes-operations-report-sync-live-self-test.ps1`

### TC-INFRA-015

- Feature: Kubernetes operations report ConfigMap and backend Pod mount verification.
- Preconditions: PowerShell is available. For fixture mode, the repository contains `scripts/verify-kubernetes-operations-report-mount-self-test.ps1`. For deployed mode, the target namespace has the OSMU backend Deployment and the `osmu-operations-reports` ConfigMap after report sync apply.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-mount-self-test.ps1`; deployed mode uses `powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-mount.ps1 -Namespace <namespace>`.
- Steps: Verify the ConfigMap contains `latest-operations-readiness-convergence.json` and `latest-kubernetes-operations-report-sync.json`, parse both JSON documents, compare expected result/configMap metadata with local evidence when present, select a ready backend Pod by `app.kubernetes.io/name=osmu-backend`, and read the mounted files through `kubectl exec cat`.
- Expected: Operators can prove the report sync evidence is not only present in the ConfigMap, but also visible inside the running backend Pod mount before checking the dashboard API. The verifier is read-only and does not inspect Kubernetes Secret values.
- Priority: P2
- Automated: `scripts/verify-kubernetes-operations-report-mount-self-test.ps1`

### TC-CI-011

- Feature: Kubernetes operations report sync CI workflow draft.
- Preconditions: PowerShell is available and `.github/workflows/kubernetes-operations-report-sync-ci.yml` exists.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-ci-workflow.ps1`
- Steps: Verify the workflow is manual-only, runs on Ubuntu with `pwsh`, writes the operations readiness convergence report, runs `sync-kubernetes-operations-reports.ps1 -PlanOnly` by default, prepares kubeconfig only when `run_live=true`, runs `-ServerDryRunOnly` before live apply, requires `run_live=true` when `apply=true`, and uploads convergence/sync evidence artifacts.
- Expected: Operators can collect repeatable GitHub Actions evidence for report-to-ConfigMap sync without touching a cluster by default, while live ConfigMap writes require kubeconfig and explicit apply confirmation.
- Priority: P2
- Automated: `scripts/verify-ci-workflow.ps1`

### TC-INFRA-006

- Feature: Backend/frontend container hardening draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-container-hardening.ps1`
- Steps: Verify backend Dockerfile creates UID/GID 10001, copies the app jar with non-root ownership, sets `HOME`, and runs with `USER 10001`. Verify frontend nginx uses a full config with `pid /tmp/nginx.pid`, listens on port 8080, owns writable temp paths, and runs with `USER 101:101`. Verify Kubernetes and Helm backend/frontend specs define `runAsNonRoot`, matching UID/GID, `RuntimeDefault` seccomp, `allowPrivilegeEscalation: false`, and dropped capabilities.
- Expected: Backend and frontend runtimes no longer depend on root execution, and Kubernetes/Helm deployment drafts carry matching security contexts.
- Priority: P2
- Automated: `scripts/verify-container-hardening.ps1`

### TC-INFRA-007

- Feature: TLS ingress draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-tls-ingress.ps1`
- Steps: Verify Kubernetes and Helm ingress drafts reference `osmu-tls`, include `osmu.local` TLS host config, and enable NGINX SSL redirect annotations.
- Expected: Pilot deployment drafts have an explicit HTTPS entry point and certificate Secret contract, while real certificate issuance/rotation remains environment-specific.
- Priority: P2
- Automated: `scripts/verify-tls-ingress.ps1`

### TC-INFRA-008

- Feature: Secret and certificate rotation policy draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-secret-rotation-policy.ps1`
- Steps: Verify the rotation policy covers admin, JWT, access-key encryption, MariaDB, MinIO, TLS, and user access key secrets; verify no-git storage rules, rotation triggers, runbook, JWT invalidation behavior, access key encryption key behavior, and TLS certificate handling.
- Expected: Pilot operators have a documented secret/certificate rotation contract before durable environment handoff, without storing secret values in the repository.
- Priority: P2
- Automated: `scripts/verify-secret-rotation-policy.ps1`

### TC-INFRA-009

- Feature: Backup restore drill draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-backup-restore-drill.ps1`
- Steps: Verify the drill covers MariaDB metadata restore, MinIO object restore, RPO/RTO, no-secret evidence rules, restore runbook, S3 smoke verification, and acceptance criteria.
- Expected: Pilot operators have a documented backup/restore drill contract before durable environment handoff, while actual restore execution remains tied to Docker/MariaDB/MinIO or target Kubernetes availability.
- Priority: P2
- Automated: `scripts/verify-backup-restore-drill.ps1`

### TC-INFRA-010

- Feature: Prometheus observability draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-prometheus-observability.ps1`
- Steps: Verify backend includes the Prometheus Micrometer registry, Actuator exposes `prometheus`, Kubernetes backend Service has Prometheus scrape annotations, and Helm values/template expose the same metrics path and port.
- Expected: Operators can scrape backend metrics from `/actuator/prometheus` in local runtime and Kubernetes/Helm draft deployments without changing application code.
- Priority: P2
- Automated: `scripts/verify-prometheus-observability.ps1`

### TC-INFRA-011

- Feature: Monitoring artifacts draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-monitoring-artifacts.ps1`
- Steps: Verify `infra/monitoring` contains the Prometheus alert rule draft and Grafana dashboard draft, validate key alert names, parse the dashboard JSON, check required metric expressions, and ensure the operation monitoring document references the artifacts.
- Expected: Pilot operators have a starter alert/dashboard contract for backend availability, error rate, latency, retention purge failures, multipart cleanup failures, and backup readiness handoff.
- Priority: P2
- Automated: `scripts/verify-monitoring-artifacts.ps1`

### TC-INFRA-012

- Feature: Prometheus Operator draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-prometheus-operator-draft.ps1`
- Steps: Verify the optional Kubernetes `monitoring-operator.yaml` and Helm `monitoring-operator.yaml` template define `ServiceMonitor` and `PrometheusRule` resources, check scrape path/interval labels, confirm starter backend alerts exist, and ensure the plain kustomization does not apply CRD resources by default.
- Expected: Pilot operators can enable Prometheus Operator integration in clusters with `monitoring.coreos.com/v1` CRDs, while default Kubernetes apply remains safe in clusters without those CRDs.
- Priority: P2
- Automated: `scripts/verify-prometheus-operator-draft.ps1`

### TC-MON-001

- Feature: Admin data flow monitoring API and dashboard.
- Preconditions: Admin user is authenticated. Backend object APIs are reachable.
- Input: `GET /api/admin/monitoring/data-flow?from=...&to=...&bucketName=...&actorId=...&source=...&operation=...&status=...&limit=50`, `GET /api/admin/monitoring/data-flow/export.csv?...`, `GET /api/admin/dashboard/summary`, then render the admin dashboard.
- Steps: Upload or seed at least one object, list objects, download an object, optionally abort a multipart upload or trigger a failed download. Verify the focused monitoring endpoint returns `traffic`, `operations`, `topBuckets`, `recentEvents`, and `generatedAt`, and that bucket/actor/source/operation/status/time filters narrow the result. Verify CSV export returns `text/csv`, `osmu-data-flow.csv`, and the same filtered newest-first event window. Verify dashboard summary includes the same unfiltered `dataFlow` object. Verify the admin dashboard renders `dashboard-widget-io`, `data-flow-monitoring-panel`, `data-flow-filter-form`, `data-flow-export-button`, `data-flow-total-bytes`, `data-flow-failed-cancelled`, `data-flow-top-buckets`, and `data-flow-recent-events`.
- Expected: Operators can see, filter, and export total upload/download traffic, I/O operation counts, failed/cancelled transfer counts, top bucket flow, and recent data-flow events from both focused API and dashboard summary. MariaDB mode persists the event history in `data_flow_events`.
- Priority: P1
- Automated: Backend `AdminDashboardSummaryControllerTest`, backend `DataFlowMonitoringServiceTest`, frontend unit/build, and mock API self-test cover the MVP contract.

### TC-INFRA-005

- Feature: NetworkPolicy draft verification.
- Preconditions: PowerShell is available.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1` and `powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-chart.ps1`
- Steps: Verify Kubernetes and Helm deployment drafts define NetworkPolicies for backend egress to MariaDB, MinIO, and DNS, plus MariaDB/MinIO ingress from backend only.
- Expected: Sensitive metadata/storage services have an explicit network boundary draft that can be reviewed and tuned for a target cluster before pilot deployment.
- Priority: P2
- Automated: `scripts/verify-k8s-manifests.ps1`, `scripts/verify-helm-chart.ps1`

### TC-OPS-001

- Feature: Operations readiness pending evidence remediation metadata.
- Preconditions: PowerShell is available and the repository contains the operations readiness scripts/workflows.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness.ps1`
- Steps: Regenerate `.osmu-run/latest-operations-readiness.json` and `.osmu-run/latest-operations-readiness.md`, then verify the required live/security pending checks exist for storage expansion, Kubernetes HA/DR readiness, Kubernetes DR finalizer, security evidence finalizer, image signing, and container scan/SBOM evidence. Confirm each of those checks includes remediation command/workflow/workflow-command metadata and the Markdown report includes remediation command, workflow, and workflow command lines.
- Expected: The report remains honest about missing live/CI evidence, but every remaining production/B2B operations gap points to an executable script command and a `gh workflow run` template so operators know the next evidence run to perform.
- Priority: P1
- Automated: `scripts/verify-operations-readiness.ps1`

### TC-OPS-002

- Feature: Dashboard operations readiness remediation visibility.
- Preconditions: Admin user is authenticated and `.osmu-run/latest-operations-readiness.json` contains pending checks with remediation metadata.
- Input: `GET /api/admin/dashboard/readiness`, then render the admin dashboard readiness panel.
- Steps: Verify backend readiness items with `code=OPERATIONS_READINESS_CHECK` include `evidencePath`, `remediationCommand`, `remediationWorkflow`, `remediationWorkflowCommand`, and `remediationNote` when the source report provides them. Verify `OPERATIONS_EVIDENCE_PLAN` appears when `.osmu-run/latest-operations-evidence-plan.json` exists, including plan path and regeneration command, and verify `operationsEvidencePlan.actions` carries ordered action detail, recommended command, operator inputs, approval flag, and kubeconfig flag. Verify `OPERATIONS_EVIDENCE_PLAN_INVOCATION` appears when `.osmu-run/latest-operations-evidence-plan-invocation.json` exists, including invocation path, regeneration command, planned/blocked counts, action command, block reasons, unresolved placeholders, and status. Verify `OPERATIONS_INVOCATION_UNBLOCK_PLAN` appears when `.osmu-run/latest-operations-invocation-unblock-plan.json` exists, including required confirmation flags, placeholder input mapping, repeated-placeholder warning counts, blocked/planned action order lists, confirmed plan command, blocked-only command, and per-action plan command detail. Verify `OPERATIONS_DISPATCH_PREFLIGHT` appears when `.osmu-run/latest-operations-dispatch-preflight.json` exists, including failed check count, missing input count, required GitHub secret names, workflow file detail, preflight checks, required inputs, ready plan command, and execute command when ready. Verify `OPERATIONS_WORKFLOW_RUN_ID_PLAN` appears when `.osmu-run/latest-operations-workflow-run-ids.json` exists, including workflow count, missing run count, artifact collection follow-up command, security evidence finalizer command, Kubernetes operations report sync run-id handoff when present, and workflow query command detail. Verify `OPERATIONS_ARTIFACT_COLLECTION_PLAN` appears when `.osmu-run/latest-operations-artifact-collection-plan.json` exists, including artifact count, missing required count, finalizer command, local import command, artifact download command detail, and optional Kubernetes operations report sync artifact detail. Verify `OPERATIONS_READINESS_ARTIFACT_IMPORT` appears when `.osmu-run/latest-operations-readiness-artifact-import.json` exists, including import status, imported/failed counts, no-secret import policy, entry file names, source paths, destination paths, Kubernetes operations report sync import entries when selected, and failure details. Verify `OPERATIONS_READINESS_FINALIZER` appears when `.osmu-run/latest-operations-readiness-finalize.json` exists, including result, readiness result, failed count, selected steps, command list, step results, gaps, and secret masking policy. Verify `OPERATIONS_EVIDENCE_HANDOFF` appears when `.osmu-run/latest-operations-evidence-handoff.json` exists, including current bottleneck, next command, stage count, blocked action count, missing run count, missing artifact count, finalizer failed count, finalizer gap count, and stage summary detail. Verify `OPERATIONS_READINESS_CONVERGENCE` appears when `.osmu-run/latest-operations-readiness-convergence.json` exists, including ready/action-required result, current bottleneck, recommended commands, finalizer status, stage counts, Kubernetes report sync ready/result/failed count/ConfigMap target, and no-execute safety policy. Verify `KUBERNETES_OPERATIONS_REPORT_SYNC` appears when `.osmu-run/latest-kubernetes-operations-report-sync.json` exists, including namespace, ConfigMap name/key, source report hash, check results, failed count, server dry-run command, apply command, workflow path, and safety policy. Verify the frontend readiness panel renders a compact remediation block with local command, workflow path, workflow command, evidence path, note, copy controls, a plan summary line, an invocation summary line, an invocation unblock summary line, a dispatch preflight summary line, a workflow run id summary line, an artifact collection summary line, an artifact import summary line, a finalizer summary line, a handoff summary line, a convergence summary line, a Kubernetes report sync summary line, a plan action list, an invocation action list, unblock action input rows, dispatch preflight check/input/workflow rows, workflow query command rows, artifact download command rows, artifact import entry rows, finalizer command rows, finalizer step rows, handoff stage rows, convergence command rows, and Kubernetes report sync check rows under the related operations readiness warning.
- Expected: Operators can see and copy the next evidence collection script command, GitHub Actions dispatch command, invocation unblock command, dispatch preflight command, workflow run query command, artifact download command, artifact finalizer command, local import command, operations finalizer command, handoff-selected next command, convergence-selected recommended command, or Kubernetes report sync server dry-run/apply command from the dashboard without opening CLI-generated Markdown files, and they can see the ordered evidence plan, guarded planned/blocked invocation action list, blocker-unblock input handoff, dispatch preflight no-execute gate, workflow run id handoff, artifact collection handoff, artifact import result handoff, operations finalizer handoff, current bottleneck handoff, final operations convergence handoff, convergence-level deployed-report sync gate, and deployed-report sync handoff before live Kubernetes/security workflow execution while non-operations readiness items remain unchanged.
- Priority: P1
- Automated: `AdminDashboardSummaryControllerTest.dashboardReadinessIncludesOperationsEvidenceReportWarnings`, `npm run test:unit`, `scripts/verify-browser-e2e-mock-demo.ps1` covers the mock dashboard convergence fixture and command rows, and `scripts/verify-browser-e2e-prototype.ps1` seeds a real Spring Boot convergence fixture through `OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH`.

### TC-OPS-003

- Feature: Operations evidence execution plan.
- Preconditions: PowerShell is available and the repository contains the operations readiness scripts.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-evidence-plan.ps1`
- Steps: Generate a fixture operations readiness report with passed, remediable pending, and unplanned pending checks. Run `scripts/write-operations-evidence-plan.ps1`, then verify the JSON and Markdown plan include ordered remediation actions, local commands, workflow paths, `gh workflow run` commands, placeholder inputs, operator approval flags, kubeconfig-secret requirements, and an unplanned-check section.
- Expected: Operators get a deterministic evidence execution plan from readiness gaps before touching a live cluster or GitHub Actions, and the plan does not hide pending checks that lack remediation metadata.
- Priority: P1
- Automated: `scripts/verify-operations-evidence-plan.ps1`

### TC-OPS-004

- Feature: Operations evidence plan guarded invocation.
- Preconditions: PowerShell is available and the repository contains `scripts/invoke-operations-evidence-plan.ps1`.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-evidence-plan-invocation.ps1`
- Steps: Generate a fixture operations evidence plan with Kubernetes live, DR restore, and security workflow actions. Run the invocation helper in default plan-only mode and verify actions that require kubeconfig confirmation, operator approval, or placeholder replacement are blocked. Rerun with `-KubeconfigSecretConfirmed`, `-ConfirmOperatorApproval`, and `-BackupTimestamp`, then verify all selected workflow commands are planned without unresolved placeholders. Rerun with `-ActionOrder 2` and verify only the selected DR action appears.
- Expected: Operators cannot accidentally dispatch live Kubernetes/restore/security workflows from an incomplete plan, but can produce deterministic `gh workflow run` commands once required confirmations and replacements are present.
- Priority: P1
- Automated: `scripts/verify-operations-evidence-plan-invocation.ps1`

### TC-OPS-005

- Feature: Operations workflow artifact collection plan.
- Preconditions: PowerShell is available and the repository contains `scripts/write-operations-artifact-collection-plan.ps1`.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-artifact-collection-plan.ps1`
- Steps: Generate a fixture invocation report containing storage expansion, Kubernetes HA/DR readiness, Kubernetes DR finalizer, image signing, container security, security evidence finalizer, and Kubernetes operations report sync workflow commands. Run the collection plan helper without run ids and verify required readiness/convergence artifacts are marked missing while artifact names and download/import/finalizer commands use placeholders. Rerun with concrete run ids, image signing version, and commit SHA, then verify expected artifact names, `gh run download` commands, Security Evidence Finalizer command, Operations Readiness Artifact Finalizer command, Kubernetes operations report sync artifact inputs, and local import command are concrete.
- Expected: Operators can move from workflow invocation to artifact import without manually deriving artifact names, and missing run ids remain explicit before readiness/convergence evidence import is attempted.
- Priority: P1
- Automated: `scripts/verify-operations-artifact-collection-plan.ps1`

### TC-OPS-006

- Feature: Operations workflow run id plan.
- Preconditions: PowerShell is available and the repository contains `scripts/write-operations-workflow-run-id-plan.ps1`.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-workflow-run-id-plan.ps1`
- Steps: Generate a fixture invocation report containing storage expansion, Kubernetes HA/DR readiness, Kubernetes DR finalizer, image signing, container security, security evidence finalizer, and Kubernetes operations report sync workflow commands. Run the helper in plan-only mode and verify it emits `gh run list --workflow ... --json ...` commands for every workflow and marks run ids as query-required. Rerun with fixture `gh run list` JSON for successful workflow runs and verify recommended run ids, commit SHA, Security Evidence Finalizer command, Kubernetes operations report sync run id, and `write-operations-artifact-collection-plan.ps1` command are concrete.
- Expected: Operators can move from workflow invocation to run id discovery without manually reconstructing `gh run list` commands, and the artifact collection plan command is generated from latest successful workflow runs only after run evidence is available, including the optional deployed-report sync workflow.
- Priority: P1
- Automated: `scripts/verify-operations-workflow-run-id-plan.ps1`

### TC-OPS-007

- Feature: Operations evidence handoff report.
- Preconditions: PowerShell is available and the repository contains `scripts/write-operations-evidence-handoff.ps1`.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-evidence-handoff.ps1`
- Steps: Generate fixture report sets for a missing readiness report, a blocked invocation report, a state where workflow run ids plus artifact collection are ready but artifact import is missing, a state where artifact import has passed but operations readiness finalizer is missing, and a state where the operations readiness finalizer is pending. Run the handoff writer for each set, then verify the JSON and Markdown report select the correct next step, command, blocked count, missing workflow run count, missing artifact count, finalizer gap count, and stage count.
- Expected: Operators can open one handoff report and immediately see whether to generate readiness, resolve invocation blockers, collect run ids/artifacts, run the Operations Readiness Artifact Finalizer, fix import, run or fix the Operations Readiness Finalizer, or regenerate readiness.
- Priority: P1
- Automated: `scripts/verify-operations-evidence-handoff.ps1`

### TC-OPS-007A

- Feature: Operations readiness convergence report.
- Preconditions: PowerShell is available and the repository contains `scripts/write-operations-readiness-convergence.ps1`.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-readiness-convergence.ps1`
- Steps: Generate fixture report sets for missing handoff, action-required handoff, fully ready handoff/readiness/finalizer but missing Kubernetes report sync evidence, and fully ready handoff/readiness/finalizer/sync states. Run the convergence writer for each set, then verify the JSON and Markdown report select the current bottleneck, ready/action-required result, recommended command chain, stage counts, finalizer result, finalizer readiness result, Kubernetes report sync result/readiness, and no-execute safety policy.
- Expected: Operators can open one convergence report and see whether the operations workflow has reached ready or which single command chain remains, including the final ConfigMap sync gate, without executing `kubectl`, `gh`, workflow dispatch, finalizer, or ConfigMap sync commands from the report writer itself.
- Priority: P1
- Automated: `scripts/verify-operations-readiness-convergence.ps1`

### TC-OPS-008

- Feature: Operations invocation unblock plan.
- Preconditions: PowerShell is available and the repository contains `scripts/write-operations-invocation-unblock-plan.ps1`.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-invocation-unblock-plan.ps1`
- Steps: Generate a blocked invocation fixture with kubeconfig-secret, operator-approval, normal placeholder, repeated generic placeholder, and already planned action cases. Run the unblock planner and verify it emits required confirmation flags, named placeholder parameters, repeated-placeholder warnings, blocked/planned action order lists, per-action plan commands, and a planned-only command. Generate a ready invocation fixture and verify the result is ready with no required placeholders.
- Expected: Operators can convert a blocked invocation report into a concrete list of values and confirmations to collect before rerunning `invoke-operations-evidence-plan.ps1`, while actions that are already planned can be handled separately and repeated run-id/artifact placeholders remain clearly marked for workflow run id/artifact collection helpers.
- Priority: P1
- Automated: `scripts/verify-operations-invocation-unblock-plan.ps1`

### TC-OPS-009

- Feature: Operations dispatch preflight.
- Preconditions: PowerShell is available and the repository contains `scripts/write-operations-dispatch-preflight.ps1`.
- Input: `powershell -ExecutionPolicy Bypass -File .\scripts\verify-operations-dispatch-preflight.ps1`
- Steps: Generate an invocation unblock plan fixture with actions that require kubeconfig-secret confirmation, operator approval, a backup timestamp placeholder, and GitHub workflow files. Run the dispatch preflight without required inputs and verify it returns `action-required`, records failed checks, lists required GitHub secrets, and leaves execute commands blank. Run it again with `-KubeconfigSecretConfirmed`, `-ConfirmOperatorApproval`, and `-BackupTimestamp`, then verify it returns `ready`, records zero failed checks, verifies workflow files, and emits both a plan-only command and an `-Execute` preview.
- Expected: Operators get a deterministic no-execute gate before live workflow dispatch, and the script never emits an execute command while confirmations or placeholder values are missing.
- Priority: P1
- Automated: `scripts/verify-operations-dispatch-preflight.ps1`

## 14. MVP 완료 기준 테스트

MVP 완료 전 다음 테스트는 반드시 통과해야 한다.

- TC-INFRA-001
- TC-INFRA-002
- TC-INFRA-003
- TC-INFRA-004
- TC-INFRA-005
- TC-INFRA-006
- TC-INFRA-007
- TC-INFRA-008
- TC-INFRA-009
- TC-INFRA-010
- TC-INFRA-011
- TC-INFRA-012
- TC-INFRA-013
- TC-CI-001
- TC-CI-002
- TC-BACKUP-000
- TC-HEALTH-001
- TC-HEALTH-002
- TC-HEALTH-003
- TC-ORG-001
- TC-ORG-003
- TC-ORG-004
- TC-ORG-005
- TC-ORG-006
- TC-ORG-007
- TC-BUCKET-001
- TC-BUCKET-002
- TC-BUCKET-003
- TC-BUCKET-004
- TC-BUCKET-005
- TC-BUCKET-007
- TC-BUCKET-008
- TC-BUCKET-009
- TC-BUCKET-010
- TC-STORAGE-PROFILE-001
- TC-STORAGE-PROFILE-002
- TC-STORAGE-PROFILE-003
- TC-OBJECT-001
- TC-OBJECT-002
- TC-OBJECT-003
- TC-OBJECT-004
- TC-OBJECT-004A
- TC-OBJECT-004B
- TC-OBJECT-004C
- TC-OBJECT-005
- TC-OBJECT-007
- TC-OBJECT-008
- TC-OBJECT-009
- TC-OBJECT-010
- TC-OBJECT-011
- TC-OBJECT-012
- TC-OBJECT-013
- TC-OBJECT-014
- TC-OBJECT-015
- TC-OBJECT-016
- TC-OBJECT-017
- TC-OBJECT-018
- TC-OBJECT-019
- TC-OBJECT-020
- TC-OBJECT-021
- TC-OBJECT-022
- TC-KEY-001
- TC-KEY-002
- TC-KEY-004
- TC-KEY-005
- TC-KEY-006
- TC-KEY-007
- TC-AUDIT-004
- TC-AUDIT-005
- TC-AUDIT-006
- TC-FE-004
- TC-FE-005
- TC-FE-006
- TC-FE-007
- TC-FE-008
- TC-FE-009
- TC-FE-010
- TC-FE-011
- TC-FE-012
- TC-FE-013
- TC-FE-014
- TC-FE-015
- TC-FE-016
- TC-FE-017
- TC-FE-018
- TC-FE-019
- TC-FE-020
- TC-FE-021
- TC-FE-022
- TC-FE-023
- TC-FE-033
- TC-DEMO-001
- TC-DEMO-002
- TC-DEMO-003
- TC-DEMO-004
