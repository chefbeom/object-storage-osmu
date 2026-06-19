## Object Lifecycle Rules

- `ObjectLifecycleRuleRepository` stores admin-managed prefix/tag scoped retention rules.
- Rule target is `TRASH_OBJECT` or `OBJECT_VERSION`.
- Optional `bucketName` scopes a rule to one bucket. Empty `bucketName` means global rule.
- Rules are sorted by `priority`, then `createdAt`, then `ruleId`; lower priority number runs first.
- `ObjectRetentionPurgeJob` applies enabled `TRASH_OBJECT` rules after global policy purge.
- `ObjectVersionRetentionPurgeJob` applies enabled `OBJECT_VERSION` rules after global version purge.
- MariaDB mode persists rules in `object_lifecycle_rules`; in-memory mode keeps runtime rules only.
- Save/delete writes `OBJECT_LIFECYCLE_RULE_SAVE` and `OBJECT_LIFECYCLE_RULE_DELETE` audit events.
- `GET /api/admin/object-lifecycle/rules/{ruleId}/dry-run` previews matched candidates without deleting data.
- `GET /api/admin/object-lifecycle/conflicts` reports enabled rules with overlapping bucket/target/prefix/tag scopes.
- `ObjectLifecycleS3XmlService` exports/imports AWS S3 LifecycleConfiguration XML subset for lifecycle rule interoperability, emits exported rule children in `ID`/`Filter`/`Status`/action order, and validates the lifecycle root, 1000-rule limit, 255-character `Rule/ID` limit, required `Rule/Status` values (`Enabled` or `Disabled`), direct `Filter` predicate shape, lifecycle tag restrictions, unsupported object-size predicates, and unsupported lifecycle action combinations.
- `BucketLifecycleController` exposes `GET/PUT/DELETE /api/buckets/{bucketName}/lifecycle`; PUT replaces only rules scoped to that bucket and stores imported XML rules with `bucketName`.
- Bucket lifecycle GET supports JSON wrapper by default and raw XML when `Accept` is `application/xml` or `text/xml`.
- Bucket lifecycle PUT supports JSON wrapper and raw XML bodies via `Content-Type: application/xml` or `text/xml`.
- `S3BucketLifecycleController` validates lifecycle PUT single `Content-MD5`, one explicit `x-amz-checksum-*` value header, and matching single `x-amz-sdk-checksum-algorithm` against the raw lifecycle XML body before replacing the bucket configuration; duplicate checksum value headers are rejected before replacement.
- `S3BucketLifecycleController` rejects `x-amz-transition-default-minimum-object-size` before replacement because the OSMU lifecycle subset does not support S3 Transition actions.
- `S3BucketLifecycleController` exposes `/api/s3/{bucketName}?lifecycle` as a path-style S3 lifecycle alias backed by the same bucket lifecycle service, maps missing/blank lifecycle XML to S3 `MissingRequestBodyError`, invalid lifecycle XML to `MalformedXML`, and a missing bucket lifecycle configuration to S3 `NoSuchLifecycleConfiguration`.
- `S3RequestAuthService` resolves JWT auth, OSMU access key headers (`X-OSMU-Access-Key`, `X-OSMU-Secret-Key`), or AWS SigV4 header auth for S3-style aliases.
- `S3SignatureV4Verifier` validates `AWS4-HMAC-SHA256` Authorization headers and query/presigned URL parameters using canonical request, signed headers, `x-amz-date` or `X-Amz-Date`, `x-amz-content-sha256` or `UNSIGNED-PAYLOAD`, and encrypted access key signing secret material.
- SigV4 verification enforces request time within configurable `osmu.s3.sigv4.clock-skew-seconds`; presigned URL auth also enforces `X-Amz-Expires`.
- New access keys store `secret_key_hash` for OSMU header-secret checks and `secret_key_ciphertext` for SigV4 verification. Existing keys without ciphertext still work with `X-OSMU-Secret-Key` but cannot use SigV4 until re-created.
- `VirtualHostedStyleS3RequestFilter` supports MVP virtual-hosted-style S3 routing by extracting `{bucket}` from configured host suffixes such as `{bucket}.localhost` and internally routing to the existing path-style controllers.
- For virtual-hosted-style SigV4 requests, the filter preserves the original client URI so `S3SignatureV4Verifier` validates the canonical URI that the client signed.
- `S3RootController` exposes `GET /api/s3` as S3 `ListAllMyBucketsResult` XML and filters Access Key requests by current bucket scopes.
- `S3RootController` also exposes explicit `HEAD /api/s3` as a service-level auth probe for S3 clients. It reuses root bucket-list auth but returns no body.
- `S3BucketController` exposes bucket-level S3 compatibility operations: `PUT /api/s3/{bucketName}`, `HEAD /api/s3/{bucketName}`, `GET /api/s3/{bucketName}?location`, and `DELETE /api/s3/{bucketName}`.
- S3-style endpoints target replacement compatibility for common S3 clients, not AWS S3 behavioral cloning. New S3 work should be driven by real client smoke failures or OSMU product needs before AWS edge-case matching.
- S3-style bucket create reuses `BucketService.create`, currently requires Bearer JWT auth, validates AWS general-purpose bucket name rules, accepts S3 `CreateBucketConfiguration/LocationConstraint` XML when it matches the configured storage region, rejects malformed/unexpected CreateBucket XML and unsupported ACL/grant/object-lock/object-ownership/bucket-namespace controls, and maps invalid names, invalid XML, unsupported control headers, or duplicate creates to S3 XML `InvalidBucketName`, `MalformedXML`, `InvalidRequest`, `BucketAlreadyOwnedByYou`, or `BucketAlreadyExists`. S3-style bucket delete reuses `BucketService.delete`, requires target bucket `ADMIN` scope through JWT or Access Key auth, only succeeds when active objects and retained object versions are gone, validates bucket names, and maps invalid/non-empty buckets to S3 XML `InvalidBucketName` or `BucketNotEmpty`.
- `S3BucketTaggingController` exposes `GET/PUT/DELETE /api/s3/{bucketName}?tagging`, stores bucket metadata tags through `BucketTagRepository`, maps missing/blank tagging XML to S3 `MissingRequestBodyError`, and requires bucket `ADMIN` scope.
- `S3TaggingXmlMapper` parses and renders S3-compatible `Tagging/TagSet/Tag/Key/Value` XML for bucket tagging with XXE protections.
- `BucketController` exposes REST bucket tag management through `GET/PUT/DELETE /api/buckets/{bucketName}/tags`, reusing `BucketTagService` validation and repository storage.
- `S3ObjectController` exposes prototype path-style object operations: `PUT/HEAD/GET/DELETE /api/s3/{bucketName}/{objectKey}`.
- S3 object `PUT` validates non-streaming signed `x-amz-content-sha256` against the actual request body. `UNSIGNED-PAYLOAD` is accepted without body hash validation. AWS `aws-chunked` request bodies are decoded when `x-amz-decoded-content-length` is present, mismatched decoded length is rejected, and `STREAMING-AWS4-HMAC-SHA256-PAYLOAD` chunk headers must carry a 64-character lowercase hex `chunk-signature`. For SigV4 header auth, `S3SignatureV4Verifier` attaches the Authorization seed signature and signing key to the request so `AwsChunkedInputStream` can cryptographically verify the per-chunk signature chain while streaming.
- S3 object `PUT` validates optional `Content-MD5` and one optional `x-amz-checksum-sha256`, `x-amz-checksum-sha1`, `x-amz-checksum-crc32`, `x-amz-checksum-crc32c`, or `x-amz-checksum-crc64nvme` header before accepting the upload. If a single `x-amz-sdk-checksum-algorithm` is present without an explicit checksum value, the controller computes the requested checksum while streaming the body, stores it, and echoes the matching response header; duplicate SDK checksum algorithm headers are rejected as `InvalidRequest`. For aws-chunked uploads, `x-amz-trailer` can declare one trailing checksum from the same supported set; the decoded body checksum is validated after the final chunk, then stored in object metadata and echoed as the matching response header. Digest failures return S3 XML `InvalidDigest` or `BadDigest`; Content-MD5 failures use AWS-style messages while non-MD5 checksum failures retain specific checksum context.
- S3 object `PUT` evaluates destination `If-Match` and `If-None-Match` overwrite guards before request body storage; failed guards return S3 XML `PreconditionFailed`.
- `S3ObjectController` supports S3 CopyObject prototype via `x-amz-copy-source` on object `PUT`, including `?versionId=` for OSMU-retained source versions. It reuses the existing upload/version/quota path for the target object and preserves user metadata and stored checksum metadata when the selected source metadata has them. A single `x-amz-checksum-algorithm` recalculates target checksum metadata for supported algorithms (`SHA256`, `SHA1`, `CRC32`, `CRC32C`, `CRC64NVME`), while duplicate or unsupported values are rejected as `InvalidRequest`. Copy result XML emits stored checksum result elements such as `ChecksumSHA256`.
- CopyObject supports `x-amz-metadata-directive` and `x-amz-tagging-directive` for MVP content type/user-metadata/tag replacement.
- CopyObject supports source preconditions using source ETag and source Last-Modified headers plus destination `If-Match` and `If-None-Match` overwrite guards. AWS-documented source combinations keep `x-amz-copy-source-if-match` success dominant over stale `x-amz-copy-source-if-unmodified-since` and keep matching `x-amz-copy-source-if-none-match` dominant over modified `x-amz-copy-source-if-modified-since`; failed conditions return S3 XML `PreconditionFailed`.
- `S3ObjectController` exposes MVP S3 multipart path operations: initiate, upload part, list parts, complete, and abort. It reuses `ObjectService` multipart sessions and adds `ObjectStorageAdapter.uploadMultipartUploadPart` for direct part body upload.
- S3 multipart part upload validates optional `Content-MD5`, signed `x-amz-content-sha256`, and `x-amz-checksum-*` value headers with the same `InvalidDigest`/`BadDigest` S3 XML errors as single `PUT`, including AWS-style Content-MD5 messages, and echoes the matching checksum response header. When an initiated checksum algorithm or a single `x-amz-sdk-checksum-algorithm` is present and no explicit checksum header/trailer is supplied, `S3ObjectController` computes the part checksum while streaming the body, stores it through `MultipartUploadPartChecksumRepository`, and returns the checksum response header. Duplicate SDK checksum algorithm headers are rejected as `InvalidRequest`; SDK, explicit part, and initiated checksum algorithms must agree.
- S3 multipart complete accepts one supported final object checksum value header (`x-amz-checksum-sha256`, `x-amz-checksum-sha1`, `x-amz-checksum-crc32`, `x-amz-checksum-crc32c`, or `x-amz-checksum-crc64nvme`), validates it against the completed storage object before metadata commit, validates a single optional `x-amz-mp-object-size` against the actual completed object size, accepts a single `x-amz-checksum-type: FULL_OBJECT` with final object checksum headers, stores the checksum metadata, echoes the checksum response header, and writes complete-result XML `Location`, `Bucket`, `Key`, `ETag`, matching checksum elements, and `ChecksumType` when explicitly requested, persisted on initiate, or inferable from the returned checksum shape. It rejects multiple final checksum value headers, unsupported `x-amz-checksum-*` value headers, duplicate `x-amz-checksum-type`/`x-amz-mp-object-size` headers, and unsupported complete control headers (`x-amz-checksum-algorithm`, `x-amz-request-payer`, `x-amz-expected-bucket-owner`, and SSE-C customer headers) before storage completion. When no final object checksum header is supplied and every completed part has the same `ChecksumSHA256`, `ChecksumSHA1`, `ChecksumCRC32`, or `ChecksumCRC32C`, `ObjectService` stores the AWS-style composite checksum by digesting/checksumming the ordered part checksum bytes and the S3 controller accepts `x-amz-checksum-type: COMPOSITE`. `ObjectService` exposes the initiated checksum type to the S3 controller before completion so response XML can echo stored `ChecksumType` even when the complete request omits the header. If request and initiate both omit checksum type, the controller emits `ChecksumType=FULL_OBJECT` for accepted final checksum headers and `ChecksumType=COMPOSITE` for returned composite checksum metadata. `ObjectService` merges stored UploadPart checksum metadata when CompleteMultipartUpload XML omits per-part checksum elements, validates requested checksum type shape after that merge rather than in the controller's XML parser, compares persisted initiate checksum algorithm/type against complete-time final or per-part checksum shape, and returns `BadDigest` before storage completion when they diverge. `CRC64NVME` remains full-object only, matching AWS support.
- MinIO-backed S3 multipart complete preserves the storage-computed AWS-style multipart ETag (`md5-of-part-md5s-partCount`) through object metadata, complete response XML/header, and later `HEAD`; Docker/client smoke scripts recompute the expected ETag from uploaded part ETags.
- S3 multipart complete supports destination `If-Match` and `If-None-Match` overwrite guards before XML parsing/storage completion; failed preconditions return S3 XML `PreconditionFailed`.
- S3 multipart complete request XML requires a non-empty, direct-child, strictly ascending, unique part list with exactly one direct `PartNumber` in 1~10000 and exactly one non-blank direct `ETag`, parses at most one non-blank supported per-part checksum direct child into `CompletedMultipartUploadPart.checksums()`, rejects non-`Part` root children, nested required part fields, or duplicate direct `PartNumber`/`ETag` fields as `MalformedXML`, rejects multiple supported checksum XML elements or unsupported per-part checksum XML elements (`ChecksumMD5`, `ChecksumSHA512`, `ChecksumXXHASH*`) as `InvalidDigest`, falls back to stored UploadPart checksum metadata when XML omits a part checksum, validates checksum syntax, derives SHA1/SHA256/CRC32/CRC32C composite metadata when every part supplies the same algorithm, enforces any stored initiate composite negotiation against those per-part checksum algorithms, maps out-of-order/duplicate part numbers to `InvalidPartOrder`, maps missing uploaded parts or stale part ETags to `InvalidPart`, maps uploaded non-last parts smaller than 5 MiB to `EntityTooSmall`, and checks uploaded part existence, ETag match, plus non-last part size before delegating to storage. The MinIO completion call still uses part number and ETag only in the MVP.
- `S3ObjectController` exposes `GET /api/s3/{bucketName}?uploads` as an S3 ListMultipartUploads MVP backed by active `PresignedUploadSession` rows.
- S3 multipart initiate accepts optional OSMU expected-size headers. When omitted, S3 sessions are created without a precomputed part plan and quota is checked on complete using the completed object size. A single `x-amz-checksum-algorithm` is accepted for the supported checksum algorithms (`SHA256`, `SHA1`, `CRC32`, `CRC32C`, `CRC64NVME`), a single `x-amz-checksum-type` is validated as `COMPOSITE` or `FULL_OBJECT`, duplicate or unsupported algorithm/type combinations are rejected before session creation, and accepted checksum negotiation headers are persisted on `PresignedUploadSession` and echoed in the initiate response. Unsupported CreateMultipartUpload control headers for ACL grants, Object Lock, server-side encryption, non-standard storage class, website redirects, and requester-pays are rejected before session creation; safe no-op defaults `x-amz-acl: private` and `x-amz-storage-class: STANDARD` are accepted.
- S3 multipart ListParts supports `max-parts` and `part-number-marker`, returns S3-style `PartNumberMarker`, `NextPartNumberMarker`, `MaxParts`, and `IsTruncated`, pages the uploaded parts returned by storage by ascending part number, and emits stored part checksum XML elements when present.
- Missing multipart upload sessions map to S3 XML `NoSuchUpload` instead of object-style `NoSuchKey`.
- `S3ObjectController` exposes basic `GET /api/s3/{bucketName}` ListObjects V1 XML with prefix, delimiter, max-keys, marker, `encoding-type=url`, and `fetch-owner=true` support.
- `S3ObjectController` also exposes basic `GET /api/s3/{bucketName}?list-type=2` ListObjectsV2 XML with prefix, delimiter, max-keys, continuation-token, `encoding-type=url`, and `fetch-owner=true` support.
- `S3ObjectController` exposes `POST /api/s3/{bucketName}?delete` multi-object delete XML and delegates each key to the existing soft-delete object flow. The S3 `Quiet=true` flag suppresses successful `Deleted` result entries, key-specific failures are returned as `DeleteResult/Error` entries, and optional `Content-MD5` validates the XML body before delete execution.
- `S3ObjectController` supports one HTTP byte range per GET for object preview/resume flows, returns `206 Partial Content`, rejects multi-range requests because AWS S3 does not retrieve multiple ranges in one GET, and honors `If-Range` by falling back to a full-object `200` response when the validator is stale.
- `S3ObjectController` supports S3-style object tagging XML through `GET/PUT/DELETE /api/s3/{bucketName}/{objectKey}?tagging`, maps missing/blank tagging XML to S3 `MissingRequestBodyError`, and delegates storage to `ObjectService.updateTags`.
- `StoredObjectRecord` carries object `etag` and checksum metadata. S3 `HEAD`, `GET`, `ListObjects`, and `ListObjectsV2` expose `ETag`; `HEAD`/`GET` expose stored `x-amz-checksum-*` headers and list XML exposes `ChecksumAlgorithm`.
- `BucketService.syncUsage` rebuilds the metadata index from storage actuals and preserves existing checksum and user metadata only when the storage ETag still matches the indexed ETag. If the object changed in storage, stale indexed checksum/user metadata is discarded.
- S3 object `HEAD` and `GET` evaluate conditional headers: matching `If-None-Match` or not-modified `If-Modified-Since` returns `304`; non-matching `If-Match` or stale `If-Unmodified-Since` returns `412`; AWS-documented combinations keep `If-Match` success dominant over stale `If-Unmodified-Since` and `If-None-Match` match dominant over modified `If-Modified-Since`; GET range requests use `If-Range` to decide whether to serve the range or full object.
- S3-style object alias reuses `ObjectService`, bucket quota, object metadata, soft delete, audit log, and Access Key permission checks.
- `S3ErrorCodeMapper` centralizes OSMU `ApiErrorCode` to S3 XML error code mapping so global `/api/s3/**` error responses and multi-delete per-key `Error` entries stay consistent, including multipart `NoSuchUpload`, missing bucket lifecycle `NoSuchLifecycleConfiguration`, and non-empty bucket `BucketNotEmpty`.
- `GlobalExceptionHandler` returns AWS-style XML error bodies for `/api/s3/**` with `Code`, `Message`, per-error details such as `BucketName`, `Key`, and `UploadId`, `Resource`, `RequestId`, and an opaque deterministic `HostId` derived from request id plus resource while normal REST API errors stay JSON. `Resource` uses the request path plus query string.
- `S3ErrorCodeMapper` normalizes generic non-bucket S3 XML messages for `BadDigest`/`InvalidDigest` Content-MD5 failures, `EntityTooLarge`, `OperationAborted`, `InternalError`, missing content length, incomplete body length, and missing/blank XML request bodies; non-MD5 checksum failures keep checksum-specific detail. `MissingContentLength` uses HTTP `411`, while `IncompleteBody` and `MissingRequestBodyError` remain HTTP `400`.
- `RequestIdFilter` adds AWS-style trace headers to S3 responses: `x-amz-request-id` mirrors the normalized request id, and `x-amz-id-2` is an opaque deterministic host id derived from request id plus resource. The same values are reused in S3 XML error `RequestId`/`HostId`, and backend CORS exposes them with `X-Request-Id`.
- S3 XML `AccessDenied` responses are normalized to HTTP `403` and message `Access Denied` even when the underlying REST error category is `AUTHENTICATION_REQUIRED`; non-S3 JSON auth failures continue to return HTTP `401` with detailed JSON messages.
- S3 XML `InvalidRange` responses are normalized to HTTP `416` and message `The requested range cannot be satisfied.`.
- S3 XML `NoSuchBucket`, `NoSuchKey`, `NoSuchUpload`, and `NoSuchLifecycleConfiguration` messages are normalized to AWS-style not-found text instead of leaking internal repository/storage messages.
- S3 XML `PreconditionFailed` responses are normalized to HTTP `412` and AWS-style precondition failure text across object, CopyObject, and multipart destination guards.
- S3 XML `InvalidBucketName`, `BucketAlreadyOwnedByYou`, `BucketAlreadyExists`, and `BucketNotEmpty` responses are normalized to AWS-style bucket error messages.
- S3 XML `InvalidPart`, `InvalidPartOrder`, and `EntityTooSmall` responses are normalized to AWS-style CompleteMultipartUpload special-error messages.
- Current S3-style alias intentionally leaves out AWS edge behavior that is not required for replacement use: presigned streaming/trailer-signature parity, automatic DNS/proxy provisioning for virtual-hosted-style domains, AWS versioning semantics, exhaustive conditional/header combinations, and detailed AWS error nuances. `s3-compatibility.md` is the authoritative matrix for supported, partial, and unsupported S3 behavior.
# OSMU Backend Design

이 문서는 Spring Boot 기반 OSMU Backend 설계를 정의한다.

## 1. Backend 역할

Backend는 OSMU의 Control Plane이다.

책임:

- REST API 제공
- 인증/권한 처리
- MariaDB 메타데이터 관리
- MinIO 연동
- 버킷 관리
- 파일 관리
- Access Key 관리
- 쿼터 관리
- 감사 로그 기록
- 운영 상태 제공

## 2. 기술 스택

- Java 17
- Spring Boot
- Spring Web
- Spring Validation
- Spring Data JPA
- MariaDB JDBC Driver
- MinIO Java SDK
- Flyway
- JUnit 5

## 3. 패키지 구조

```text
com.example.osmu
├── common
│   ├── api
│   ├── error
│   ├── logging
│   └── time
├── config
├── auth
├── user
├── organization
├── bucket
├── object
├── accesskey
├── quota
├── audit
├── storage
│   ├── minio
│   └── model
└── system
```

## 4. 계층 구조

```text
Controller -> Service -> Repository
Controller -> Service -> StorageAdapter
```

### 4.1 Controller

역할:

- HTTP 요청/응답 처리
- DTO validation
- 인증 사용자 전달
- 비즈니스 로직 직접 구현 금지
- `AdminEnterpriseAuthPlanController` exposes `GET /api/admin/security/enterprise-auth-plan` as a read-only enterprise auth plan endpoint. It does not enable OIDC/LDAP login; it reports local-only login, OIDC/LDAP configuration readiness, role/organization/team claim mapping, and cutover gates through `EnterpriseAuthPlanService`.
- `AdminEnterpriseAuthPlanController` exposes `POST /api/admin/security/enterprise-auth/claim-preview` as an admin-only claim mapping preview. `OidcClaimPreviewService` maps sample OIDC claims to OSMU role/organization/team/domain/user-match outcomes and the controller records `OIDC_CLAIM_PREVIEW` audit evidence without storing the raw claim payload.
- `AdminEnterpriseAuthPlanController` exposes `POST /api/admin/security/enterprise-auth/jit-provision` as an admin-only JIT apply endpoint. `OidcJitProvisioningService` reuses the preview result, rejects disallowed domains and missing required claims, requires explicit approval for privileged roles, validates organization assignment, creates an `ACTIVE` local user with a random non-disclosed password hash, and records `OIDC_JIT_PROVISION` audit evidence without storing raw claims.
- `AuthController` exposes `GET /api/auth/oidc/authorize` as a public OIDC authorization-code start endpoint. `OidcAuthorizationService` validates explicit enablement and required OIDC properties, generates `state`, `nonce`, and PKCE `S256` challenge, and stores the `code_verifier` server-side for the later callback step.
- `AuthController` also exposes `GET /api/auth/oidc/callback` as a public callback endpoint. `OidcLoginService` consumes state, exchanges the authorization code through `OidcTokenClient`, validates RS256 `id_token` signatures and issuer/audience/nonce through `OidcIdTokenVerifier`, then issues normal OSMU access/refresh tokens only for an existing `ACTIVE` local user matched by email.
- `AuthController` exposes `POST /api/auth/ldap/login` as a public LDAP bind/search login adapter. `LdapLoginService` validates explicit enablement, searches the target directory through `LdapClient`, binds the found user DN with the submitted password, applies the same allowed-domain and existing `ACTIVE` local user email boundary, then issues normal OSMU access/refresh tokens. `JndiLdapClient` uses JNDI only at runtime and stores no LDAP password.

### 4.2 Service

역할:

- 도메인 로직
- 권한 검사
- 트랜잭션 관리
- Repository와 StorageAdapter 조합

### 4.3 Repository

역할:

- MariaDB 접근
- metadata record 조회/저장
- object list/search/tag index 조회
- object tag inverted index 갱신/조회

### 4.4 StorageAdapter

역할:

- MinIO 연동 캡슐화
- 버킷 생성/삭제
- 오브젝트 업로드/다운로드/삭제
- presigned URL 생성

## 5. 주요 컴포넌트

### 5.1 BucketService

책임:

- 버킷 이름 검증
- 버킷 중복 확인
- USER/ORG owner 검증
- ADMIN/ORG_ADMIN/user bucket 생성 권한 검증
- ORG bucket 접근/관리 권한 분리
- bucket permission 부여/회수와 `READ`, `WRITE`, `DELETE`, `ADMIN` 검사
- ORG bucket object 변경 시 organization default quota 초과 차단
- MinIO 버킷 생성
- MariaDB 버킷 메타데이터 저장
- 버킷 삭제 전 empty 확인
- 감사 로그 기록

### 5.2 ObjectService

책임:

- object action별 `READ`, `WRITE`, `DELETE` 권한 확인
- 파일 업로드 권한 확인
- 쿼터 확인
- request stream 기반 MinIO object 업로드
- object metadata index 갱신
- object metadata index 기반 파일 목록 조회
- tag update/presigned complete 후 index 반영
- object metadata detail에서 index/storage actual drift status 계산
- 다운로드 stream 또는 presigned URL 반환
- 만료된 multipart upload session cleanup, MinIO incomplete multipart abort, cleanup 감사 로그 기록
- 삭제 감사 로그 기록

### 5.3 AuthService

책임:

- 로그인
- 비밀번호 검증
- JWT 발급
- 사용자 상태 확인

### 5.4 AccessKeyService

책임:

- Access Key 생성
- Secret Key 1회 반환
- Secret Key hash 저장
- 기존 `allowedBuckets + permissions` 요청과 bucket별 `bucketScopes` 요청 지원
- 요청 permission이 bucket permission을 초과하지 않는지 검증
- bucket permission 회수 후 active key scope/policy 재동기화
- Access Key 비활성화
- S3 호환 인증 성공 시 `lastUsedAt` 갱신과 `usageCount` 증가
- Secret rotation 이후 설정된 grace period 동안 이전 secret hash/ciphertext를 임시 인증 재료로 유지
- 사용자 비활성화/잠금 시 사용자 소유 Access Key 일괄 비활성화
- MinIO 계정/정책 연동

- Access Key authentication for S3-style aliases uses SHA-256 secret hash verification and active key scope checks.
- Access Key permission values are `READ`, `WRITE`, `DELETE`, and `ADMIN`; bucket lifecycle alias requires `ADMIN`.

### 5.5 OrganizationRepository/AdminOrganizationController

책임:

- 조직 생성
- 조직 목록 조회
- 조직별 bucket usage 집계
- 조직 이름 중복 차단
- 사용자 생성 시 organizationId 유효성 검증
- ORG_ADMIN의 자기 조직 사용자 조회/생성/상태 변경 scope 제한
- ORG_ADMIN은 USER role만 생성 가능
- 조직 생성 감사 로그 기록

### 5.5.1 AdminTeamController / TeamRepository

책임:

- 조직 안의 팀/부서 권한 그룹 생성, 조회, 멤버 교체, 삭제.
- `ADMIN`은 전체 조직 팀을 관리하고, `ORG_ADMIN`은 자기 조직 팀만 관리한다.
- 팀 멤버는 같은 조직 사용자로 제한한다. `ORG_ADMIN`은 `ADMIN`/`AUDITOR` 계정을 팀 멤버로 지정할 수 없다.
- 팀 삭제 시 `TEAM:{teamId}` bucket permission을 함께 정리한다.
- 팀 멤버 변경 또는 팀 삭제 후 영향을 받는 사용자의 활성 Access Key를 현재 bucket scope 기준으로 재동기화한다.

### 5.6 AuditLogService

책임:

- 주요 이벤트 기록
- 실패 이벤트 기록
- 조회 API 제공

### 5.7 BucketPermissionRepository

책임:

- `bucket_permissions` metadata 저장
- bucket별 권한 목록 조회
- user, organization, team subject 권한 중복 차단
- bucket 삭제 시 permission metadata 정리

### 5.8 ObjectMetadataRepository

책임:

- `object_metadata` 저장/삭제/재생성
- object list cursor pagination
- prefix/delimiter 기반 folder-like 탐색
- object key search
- object tag exact filter
- object metadata detail 조회
- MariaDB mode에서는 긴 object key를 SHA-256 hash로 식별하고 tags를 JSON 문자열로 저장
- MariaDB mode에서는 `object_metadata_tags` inverted index로 tag filter 후보를 먼저 줄인다.

## 6. MinIO 연동 설계

### 6.1 설정값

```yaml
osmu:
  storage:
    endpoint: http://localhost:9000
    access-key: minioadmin
    secret-key: minioadmin
    region: us-east-1
    cors:
      enabled: true
      allowed-origins: http://localhost:5173,http://127.0.0.1:5173
  upload:
    cleanup:
      enabled: true
      initial-delay-ms: 60000
      fixed-delay-ms: 300000
      batch-size: 100
```

### 6.2 Adapter 인터페이스

```java
public interface ObjectStorageAdapter {
    boolean isHealthy();
    void createBucket(String bucketName);
    void deleteBucket(String bucketName);
    StoredObjectPage listObjects(String bucketName, String prefix, String delimiter, String search, Map<String, String> tagFilter, String cursor, int limit);
    Optional<StoredObjectRecord> statObject(String bucketName, String objectKey);
    StoredObjectData getObject(String bucketName, String objectKey);
    StoredObjectStream openObject(String bucketName, String objectKey);
    StoredObjectRecord putObject(String bucketName, String objectKey, InputStream stream, long sizeBytes, String contentType, Map<String, String> tags);
    StoredObjectRecord setObjectTags(String bucketName, String objectKey, Map<String, String> tags);
    StoredObjectRecord deleteObject(String bucketName, String objectKey);
    StorageMultipartUpload createMultipartUpload(String bucketName, String objectKey, String contentType, int expiresInSeconds, List<Integer> partNumbers);
    StorageMultipartUpload refreshMultipartUploadParts(String bucketName, String objectKey, String storageUploadId, int expiresInSeconds, List<Integer> partNumbers);
    List<MultipartUploadUploadedPart> listMultipartUploadParts(String bucketName, String objectKey, String storageUploadId);
    StoredObjectRecord completeMultipartUpload(String bucketName, String objectKey, String storageUploadId, List<CompletedMultipartUploadPart> parts);
    void abortMultipartUpload(String bucketName, String objectKey, String storageUploadId);
}
```

정책:

- Direct upload는 `MultipartFile.getInputStream()`을 사용해 service/storage adapter에 stream을 넘긴다.
- MinIO mode는 `PutObjectArgs.stream(inputStream, sizeBytes, -1)`로 업로드해 JVM heap에 전체 파일을 복사하지 않는다.
- REST download는 `openObject`가 반환한 `StoredObjectStream`을 `StreamingResponseBody`로 client에 전달한다.
- MinIO mode의 REST download main path는 `GetObjectResponse` stream을 닫기 전까지 response로 복사하며, 전체 파일을 JVM byte array로 적재하지 않는다.
- `ObjectSharePolicyService` stores the global admin share policy. It can require password/IP allowlists and cap expiry/download limits for all new object share links.
- `ObjectShareLinkService` issues temporary object share links after `READ` permission and storage-presence checks, then applies the global share policy before persisting optional password hashes and IP/CIDR allowlist metadata.
- `GET /api/admin/object-share-analytics` summarizes share link status, protection, download totals, last access, and recent links without exposing raw token or public URL. Admins can filter analytics by bucket and link status.
- Share link tokens are generated as opaque random URL-safe tokens; only SHA-256 token hashes are persisted.
- `GET /api/public/share-links/{token}` is public, validates active/non-expired/non-limit-reached token state, optional share password, and optional IP allowlist, records download count and last-access time, then streams the object through the same storage adapter without requiring a Bearer token.
- Share link cleanup marks expired active links as `EXPIRED` for a bucket and requires bucket manage permission.
- `ObjectShareLinkCleanupJob` automatically marks expired active share links as `EXPIRED` and records `osmu.object.share.cleanup.links{result=success}` plus `osmu.object.share.cleanup.runs{result=failure}` metrics.
- `DataFlowEventRetentionJob` deletes old `data_flow_events` rows in bounded batches and records `DATA_FLOW_EVENT_RETENTION` audit plus `osmu.data.flow.retention.events{result=success}` and `osmu.data.flow.retention.runs{result=failure}` metrics.
- `BillingPricingPolicyService` owns the internal chargeback pricing policy and ADMIN-only pricing proposal workflow. Proposals start as `PENDING_APPROVAL`; approving them changes the active internal calculation policy as `APPROVED_APPLIED`, but still does not create an approved external commercial price list.
- `ChargebackPreviewService` builds an API-first tenant cost pre-model from current organization-owned bucket usage plus bounded `data_flow_events`. `ADMIN` receives every organization; `ORG_ADMIN` receives only the caller organization. It can export preview CSV, draft invoice CSV, persist internal draft invoice review records, approve those records as `APPROVED_INTERNAL`, build no-send threshold notification payload previews, and record scoped notification outbox/history rows with `PENDING_DELIVERY_ADAPTER`, but it does not create legal final invoices, payment requests, or external notification deliveries.
- Share link create/download/revoke/cleanup writes `OBJECT_SHARE_LINK_CREATE`, `OBJECT_SHARE_LINK_DOWNLOAD`, `OBJECT_SHARE_LINK_REVOKE`, and `OBJECT_SHARE_LINK_CLEANUP` audit events. Global policy saves write `OBJECT_SHARE_POLICY_SAVE`.
- Multipart upload는 MinIO multipart upload id와 part별 presigned PUT URL을 발급하고, complete 시 ETag 목록으로 object를 확정한다.
- Multipart refresh는 저장된 `partSizeBytes`, `partCount`, storage upload id를 사용해 기존 multipart upload에 대한 part별 presigned PUT URL을 재발급한다.
- Multipart parts list는 MinIO `listParts`를 사용해 이미 업로드된 partNumber/ETag/size를 반환하고 frontend resume이 완료된 part를 skip할 수 있게 한다.
- Presigned upload uses `.osmu/uploads/` staging keys and copies staged content to the active key on complete.
- Presigned/multipart overwrite snapshots the previous active object into `.osmu/versions/` before active replacement.
- Browser multipart upload는 part PUT 응답의 `ETag`를 읽어야 하므로 `MinioBucketCorsProvisioner`와 local Compose CORS JSON이 `ExposeHeaders`에 `ETag`를 포함한다.
- `MultipartUploadCleanupJob`은 만료된 `ACTIVE` multipart session을 주기적으로 찾아 MinIO multipart upload를 abort하고 session 상태를 `EXPIRED`로 변경한다. cleanup 성공/실패는 `OBJECT_MULTIPART_UPLOAD_CLEANUP` 감사 로그와 `osmu.multipart.cleanup.sessions{result=success|skipped|failure}` metric으로 기록한다.
- in-memory mode는 테스트/개발 편의를 위해 stream을 byte array로 저장한다.

## 7. 에러 처리

공통 예외:

- `ValidationException`
- `AuthenticationException`
- `AuthorizationException`
- `ResourceNotFoundException`
- `ConflictException`
- `QuotaExceededException`
- `StorageException`
- `InternalServerException`

예외는 `@ControllerAdvice`로 공통 응답 변환한다.

## 8. 인증/권한

MVP 단계:

- JWT 기반 로그인
- Role 기반 권한
- 버킷 소유자 권한

역할:

- `ADMIN`
- `ORG_ADMIN`
- `USER`

권한 검사 위치:

- Controller가 아니라 Service에서 수행한다.

## 9. 트랜잭션 원칙

- MariaDB 변경은 Service 단위 트랜잭션.
- MinIO와 MariaDB는 분산 트랜잭션으로 묶지 않는다.
- MinIO 성공 후 DB 실패, DB 성공 후 MinIO 실패 보상 전략 필요.

MVP 보상 전략:

- 버킷 생성: MinIO 생성 후 DB 저장 실패 시 MinIO 버킷 삭제 시도.
- 파일 업로드: MinIO 업로드 성공 후 감사 로그 실패는 파일 업로드 성공으로 처리하고 로그 에러만 기록.
- object metadata index: Backend upload/delete/tag/complete 성공 후 갱신한다. Backend를 거치지 않은 S3 직접 변경은 bucket sync로 재생성한다.
- object tag index: object metadata와 같은 transaction에서 tag row를 replace해 JSON tag와 inverted index drift를 줄인다.
- object delete는 soft delete로 `object_metadata.deleted_at`을 기록한다. restore는 `deleted_at`을 제거하고, purge는 MinIO object와 metadata를 영구 삭제하며 quota/objectCount를 감소시킨다.
- object versioning MVP는 REST upload overwrite와 version restore 전에 기존 active object를 `.osmu/versions/` hidden key로 snapshot한다.
- `ObjectVersionRepository`는 version metadata를 저장하고, purge/retention purge 시 active object와 version snapshot을 함께 정리한다.
- `ObjectRetentionPurgeJob`은 retention 기간이 지난 soft-deleted object를 주기적으로 purge한다. 결과는 `OBJECT_RETENTION_PURGE` 감사 로그와 `osmu.object.retention.purge.objects{result=success|failure}` metric으로 기록한다.
- `ObjectVersionRetentionPurgeJob`은 version retention 기간이 지난 historical object version을 active object와 별개로 purge한다. 결과는 `OBJECT_VERSION_RETENTION_PURGE` 감사 로그와 `osmu.object.version.retention.purge.versions{result=success|failure}` metric으로 기록한다.
- Admin API는 object retention status 조회와 manual purge 실행 endpoint를 제공한다.

## 10. 구현 순서

1. Spring Web 추가
2. 공통 응답/에러 구조
3. Health API
4. MariaDB datasource
5. MinIO config
6. StorageAdapter
7. Bucket API
8. Object API
9. AuditLog
10. Auth/User
11. AccessKey/Permission/Quota

## Object Version Operations

- `ObjectService.downloadVersion` streams hidden version content through REST without loading full file into memory.
- `ObjectService.deleteVersion` removes one version binary/metadata and decrements bucket usage by version size/count.
- Presigned and multipart overwrite paths reuse the same version snapshot contract as direct REST upload.
- `.osmu/uploads/` staging keys are internal temporary storage keys and are excluded from visible object metadata sync.
- Controller audit events: `OBJECT_VERSION_DOWNLOAD`, `OBJECT_VERSION_DELETE`, `OBJECT_VERSION_RESTORE`.
- Active object delete/purge remains separate: version delete never changes active object bytes.

## Object Retention Policy Runtime Update

- `ObjectRetentionPolicyRepository`는 retention enabled/days/batch size를 저장한다.
- in-memory 모드는 런타임 메모리에, `mariadb` 모드는 `object_retention_policy` singleton row에 저장한다.
- policy는 trash retention days/batch와 version retention days/batch를 함께 관리한다.
- `PUT /api/admin/object-retention/policy`로 운영 중 retention 기간과 purge batch size를 변경할 수 있다.
- scheduler global kill switch인 `osmu.object.retention.enabled=false`는 DB policy보다 우선한다.
- policy 변경 성공 시 `OBJECT_RETENTION_POLICY_UPDATE` 감사 로그를 기록한다.

## Bootstrap Admin Runtime Policy

- `BootstrapAdminProperties`가 초기 관리자 계정 정책을 중앙화한다. in-memory와 MariaDB metadata mode는 같은 정책을 사용한다.
- `osmu.bootstrap.admin.enabled=false`이면 초기 admin 자동 생성을 건너뛴다.
- `osmu.bootstrap.admin.allow-default-credentials=false`이면 로컬 기본 비밀번호 `password`를 차단한다.
- bootstrap이 켜져 있을 때 login id, password, email, name이 비어 있으면 backend 시작을 실패시킨다.
- 운영 배포는 기본 credential 허용을 끄고 Secret 기반 admin 비밀번호를 주입한다.

