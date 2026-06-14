# OSMU API Specification

이 문서는 OSMU MVP REST API 명세 초안이다.

S3 호환 API는 MinIO가 제공한다. 이 문서는 OSMU Backend가 제공하는 관리용 REST API를 정의한다.

## 1. 공통 규칙

### 1.1 Base URL

```text
/api
```

### 1.2 인증

MVP 기준:

```http
Authorization: Bearer <accessToken>
```

현재 구현은 Health, Storage Health, Database Health, Login, Refresh만 public으로 둔다. 그 외 `/api/**`는 Bearer access token이 필요하다.

관리자 API인 `/api/admin/**`는 `ADMIN` role이 필요하다.

일반 사용자는 본인이 소유한 bucket, object, access key만 접근할 수 있다. `ADMIN`은 전체 리소스에 접근할 수 있다.

### 1.3 성공 응답

공통 응답 헤더:

```http
X-Request-Id: <request id>
```

클라이언트가 `X-Request-Id` 또는 `X-Correlation-Id`를 보내면 해당 값을 `X-Request-Id` 응답 헤더로 돌려준다. 둘 다 없으면 Backend가 새 request id를 생성한다. 감사 로그의 `requestId`도 같은 값을 사용한다.

단건:

```json
{
  "data": {}
}
```

목록:

```json
{
  "items": [],
  "nextCursor": null
}
```

### 1.4 에러 응답

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message.",
    "requestId": "request-id"
  }
}
```

`requestId`는 응답 header `X-Request-Id`와 같은 값이다.

### 1.5 공통 에러 코드

| Code | HTTP | 의미 |
| --- | --- | --- |
| `VALIDATION_ERROR` | 400 | 요청값 오류 |
| `AUTHENTICATION_REQUIRED` | 401 | 인증 필요 |
| `AUTHORIZATION_FAILED` | 403 | 권한 없음 |
| `NOT_FOUND` | 404 | 리소스 없음 |
| `CONFLICT` | 409 | 중복 또는 상태 충돌 |
| `QUOTA_EXCEEDED` | 413 | 용량 제한 초과 |
| `STORAGE_ERROR` | 502 | MinIO 연동 오류 |
| `INTERNAL_ERROR` | 500 | 내부 서버 오류 |

## 2. Health API

### GET /api/health

Backend 상태 확인.

응답:

```json
{
  "data": {
    "status": "UP",
    "service": "osmu-backend"
  }
}
```

### GET /api/storage/health

MinIO 연결 상태 확인.

응답:

```json
{
  "data": {
    "status": "UP",
    "engine": "minio",
    "accessKeyProvisioner": "UP"
  }
}
```

### GET /api/database/health

MariaDB 연결 상태 확인.

응답:

```json
{
  "data": {
    "status": "UP",
    "engine": "mariadb"
  }
}
```

## 3. Auth API

### POST /api/auth/login

로그인.

요청:

```json
{
  "loginId": "admin",
  "password": "password"
}
```

응답:

```json
{
  "data": {
    "accessToken": "jwt",
    "refreshToken": "refresh-token",
    "user": {
      "id": 1,
      "loginId": "admin",
      "name": "Admin",
      "role": "ADMIN"
    }
  }
}
```

### POST /api/auth/logout

로그아웃.

요청:

```json
{
  "refreshToken": "refresh-token"
}
```

응답:

```json
{
  "data": {
    "success": true
  }
}
```

### POST /api/auth/refresh

refresh token으로 access token을 재발급한다. 사용된 refresh token은 폐기되고 새 refresh token이 발급된다.

요청:

```json
{
  "refreshToken": "refresh-token"
}
```

응답:

```json
{
  "data": {
    "accessToken": "jwt",
    "refreshToken": "new-refresh-token",
    "user": {
      "id": 1,
      "loginId": "admin",
      "name": "Admin",
      "role": "ADMIN"
    }
  }
}
```

### GET /api/users/me

현재 사용자 조회.

응답:

```json
{
  "data": {
    "id": 1,
    "loginId": "admin",
    "email": "admin@example.com",
    "name": "Admin",
    "role": "ADMIN",
    "status": "ACTIVE"
  }
}
```

## 4. User API

### GET /api/admin/users

사용자 목록 조회. ADMIN 전용.

목표 Query:

- `keyword`
- `status`
- `limit`
- `cursor`

현재 MVP는 최신 200건을 반환하며 query filter는 후속 구현이다.

### POST /api/admin/users

사용자 생성. ADMIN 전용.

요청:

```json
{
  "loginId": "user1",
  "email": "user1@example.com",
  "name": "User One",
  "password": "temporary-password",
  "role": "USER",
  "organizationId": 1
}
```

### PATCH /api/admin/users/{userId}/status

사용자 상태 변경.

요청:

```json
{
  "status": "INACTIVE"
}
```

정책:

- `INACTIVE` 또는 `LOCKED`로 변경하면 해당 사용자의 활성 Access Key도 `INACTIVE`로 전환한다.
- Access Key 비활성화는 S3 provisioner에도 반영한다.
- 다시 `ACTIVE`로 변경해도 기존 비활성 Access Key는 자동 복구하지 않는다.

- `INACTIVE` or `LOCKED` also revokes active refresh tokens for that user.

## 5. Organization API

### GET /api/admin/organizations

조직 목록 조회.

응답:

```json
{
  "items": [
    {
      "id": 1,
      "name": "AI Research Team",
      "description": "AI dataset storage team",
      "defaultQuotaBytes": 1099511627776,
      "createdAt": "2026-06-13T04:45:00+09:00"
    }
  ]
}
```

### POST /api/admin/organizations

조직 생성.

요청:

```json
{
  "name": "AI Research Team",
  "description": "AI dataset storage team",
  "defaultQuotaBytes": 1099511627776
}
```

정책:

- ADMIN 전용 API다.
- 조직 이름은 중복될 수 없다.
- 사용자 생성 시 `organizationId`를 지정하면 존재하는 조직인지 검증한다.
- 현재 MVP 구현은 조직 생성/조회, 사용자 연결, 조직 소유 bucket, 조직별 usage 집계를 제공한다.

### DELETE /api/admin/organizations/{organizationId}

Empty organization delete. `ADMIN` required.

Response:

```http
204 No Content
```

Rules:

- Returns `404 NOT_FOUND` when the organization does not exist.
- Returns `409 CONFLICT` when users are assigned to the organization.
- Returns `409 CONFLICT` when `ownerType = ORG` buckets still belong to the organization.
- Records `ORGANIZATION_DELETE` audit event on success.

### GET /api/admin/organizations/usage

조직별 bucket usage 집계. ADMIN 전용.

응답:

```json
{
  "items": [
    {
      "id": 1,
      "name": "AI Research Team",
      "defaultQuotaBytes": 1099511627776,
      "bucketQuotaBytes": 536870912000,
      "usedBytes": 10485760,
      "remainingBytes": 1099501142016,
      "bucketCount": 2,
      "objectCount": 128
    }
  ],
  "nextCursor": null
}
```

정책:

- `ownerType = ORG` bucket만 조직 usage에 합산한다.
- `usedBytes`, `objectCount`, `bucketQuotaBytes`는 bucket metadata 기준이다.
- S3 직접 업로드 이후 값이 어긋난 경우 bucket sync API로 보정한다.
- 조직 quota 차단은 Backend upload와 presigned upload complete 경로에서 적용한다.
- 조직 quota 차단은 Backend upload와 presigned upload complete 경로에서 적용한다.

## 6. Bucket API

### GET /api/buckets

접근 가능한 버킷 목록 조회.

응답:

```json
{
  "items": [
    {
      "id": 1,
      "name": "project-data",
      "ownerType": "USER",
      "ownerId": 1,
      "quotaBytes": 1099511627776,
      "usedBytes": 1048576,
      "createdAt": "2026-06-13T00:00:00+09:00"
    }
  ],
  "nextCursor": null
}
```

### POST /api/buckets

버킷 생성.

요청:

```json
{
  "name": "project-data",
  "quotaBytes": 1099511627776,
  "ownerType": "USER",
  "ownerId": 1
}
```

응답:

```json
{
  "data": {
    "id": 1,
    "name": "project-data",
    "ownerType": "USER",
    "ownerId": 1
  }
}
```

정책:

- `ownerType`은 `USER` 또는 `ORG`를 지원한다.
- `ownerType`을 생략하면 현재 사용자 소유 `USER` bucket으로 생성한다.
- 일반 `USER`는 자기 user bucket만 생성할 수 있다.
- `ORG_ADMIN`은 본인 조직의 `ORG` bucket을 생성할 수 있다.
- `ADMIN`은 존재하는 user 또는 organization을 owner로 지정할 수 있다.
- `ORG` bucket은 같은 조직 사용자가 object 접근 가능하고, bucket 삭제/관리 작업은 `ADMIN` 또는 같은 조직 `ORG_ADMIN`만 가능하다.
- `ORG` bucket object 업로드/완료 시 organization `defaultQuotaBytes`를 초과하면 `QUOTA_EXCEEDED`를 반환한다.

### GET /api/buckets/{bucketName}

버킷 상세 조회.

### DELETE /api/buckets/{bucketName}

버킷 삭제.

### POST /api/buckets/{bucketName}/sync

S3 직접 업로드, presigned upload, 외부 client 작업 이후 bucket 사용량과 object count를 실제 storage 기준으로 동기화한다.

응답:

```json
{
  "data": {
    "id": 1,
    "name": "project-data",
    "quotaBytes": 1099511627776,
    "usedBytes": 1048576,
    "objectCount": 12
  }
}
```

정책:

- MVP에서는 빈 버킷만 삭제 가능.
- 삭제 성공/실패 모두 감사 로그 대상.
- S3 직접 접근으로 생긴 metadata drift는 sync API로 보정한다.
- sync는 bucket 관리 권한이 있는 사용자만 실행한다.

### GET /api/buckets/{bucketName}/tags

Bucket metadata tags are returned as JSON. Bucket manage permission is required.

Response:

```json
{
  "data": {
    "bucketName": "media-archive",
    "tags": {
      "project": "osmu",
      "stage": "raw"
    },
    "tagCount": 2
  }
}
```

### PUT /api/buckets/{bucketName}/tags

Replaces all bucket metadata tags. Bucket manage permission is required.

Request:

```json
{
  "tags": {
    "project": "osmu",
    "stage": "raw"
  }
}
```

Response is the same shape as `GET /api/buckets/{bucketName}/tags`.

Policy:

- Bucket tags can contain at most 50 pairs.
- Tag keys can be at most 128 characters and may contain letters, digits, `.`, `_`, `:`, `/`, `@`, `+`, `-`.
- Tag values can be at most 256 characters and cannot contain control characters.
- Empty `tags` clears existing bucket tags.
- Success writes `BUCKET_TAGS_PUT` audit log.

### DELETE /api/buckets/{bucketName}/tags

Clears all bucket metadata tags. Bucket manage permission is required.

Policy:

- Success returns `204 No Content`.
- Success writes `BUCKET_TAGS_DELETE` audit log.

### GET /api/buckets/{bucketName}/lifecycle

버킷에 직접 연결된 S3 LifecycleConfiguration XML subset을 조회한다. bucket 관리 권한이 필요하다.

Headers:

- `Accept: application/json` or default: JSON wrapper response.
- `Accept: application/xml` or `text/xml`: raw LifecycleConfiguration XML response.

Response:

```json
{
  "data": {
    "ruleCount": 1,
    "xml": "<?xml version=\"1.0\" encoding=\"UTF-8\"?>..."
  }
}
```

### PUT /api/buckets/{bucketName}/lifecycle

버킷 lifecycle 설정을 XML로 교체한다. S3 `PutBucketLifecycleConfiguration`처럼 기존 해당 bucket rule을 삭제하고 새 rule을 저장한다. bucket 관리 권한이 필요하다.

Content types:

- `application/json`: JSON wrapper with `xml` field, returns imported rule summary.
- `application/xml` or `text/xml`: raw LifecycleConfiguration XML body, returns `200 OK` with empty body.

Request:

```json
{
  "xml": "<LifecycleConfiguration>...</LifecycleConfiguration>"
}
```

Rules:

- Imported rules get `bucketName = {bucketName}`.
- Imported rules get generated rule ids, priority `10`, `20`, ... and batch size `100`.
- Supported XML subset: `Rule`, `ID`, `Status`, `Filter/Prefix`, `Filter/Tag`, `Filter/And`, `Expiration/Days`, `NoncurrentVersionExpiration/NoncurrentDays`.
- Success writes `BUCKET_LIFECYCLE_PUT` audit log.

### DELETE /api/buckets/{bucketName}/lifecycle

해당 bucket에 연결된 lifecycle rule을 모두 삭제한다. bucket 관리 권한이 필요하다. Success returns `204 No Content` and writes `BUCKET_LIFECYCLE_DELETE` audit log.

### S3-style alias: /api/s3/{bucketName}?lifecycle

OSMU REST 인증을 사용하지만, path-style S3 lifecycle 문법에 가까운 raw XML alias를 제공한다. bucket 관리 권한이 필요하다.

- `GET /api/s3/{bucketName}?lifecycle` with `Accept: application/xml`
- `PUT /api/s3/{bucketName}?lifecycle` with `Content-Type: application/xml`
- `DELETE /api/s3/{bucketName}?lifecycle`

This alias uses the same bucket-scoped lifecycle rules as `/api/buckets/{bucketName}/lifecycle`.
Auth supports normal Bearer auth, OSMU access key headers, or AWS SigV4 header auth:

- `X-OSMU-Access-Key: <accessKey>`
- `X-OSMU-Secret-Key: <secretKey>`
- `Authorization: AWS4-HMAC-SHA256 Credential=<accessKey>/...`

Access key auth requires an active key scoped to the target bucket with `ADMIN` permission. SigV4 auth verifies the canonical request signature against the encrypted access key secret stored when the key was created.

### S3-style bucket/object alias: /api/s3/{bucketName}

Prototype path-style bucket/object API for S3 client interoperability.

- `GET /api/s3` returns S3-compatible `ListAllMyBucketsResult` XML.
- `HEAD /api/s3` validates the same credentials as root bucket listing and returns `200 OK` with no body.
- `PUT /api/s3/{bucketName}` creates a bucket through the S3-style path. MVP creation uses Bearer JWT auth because an access key cannot be scoped to a bucket that does not exist yet.
- `HEAD /api/s3/{bucketName}` checks bucket existence/access and returns `x-amz-bucket-region`.
- `GET /api/s3/{bucketName}?location` returns S3-compatible `LocationConstraint` XML.
- `GET /api/s3/{bucketName}?tagging` returns S3-compatible bucket tagging XML.
- `PUT /api/s3/{bucketName}?tagging` replaces bucket tags from S3-compatible tagging XML.
- `DELETE /api/s3/{bucketName}?tagging` clears bucket tags.
- `DELETE /api/s3/{bucketName}` deletes an empty bucket through the S3-style path.
- `GET /api/s3/{bucketName}` returns basic S3 `ListObjects` V1 XML.
- `GET /api/s3/{bucketName}?list-type=2` returns basic S3 `ListObjectsV2` XML.
- `GET /api/s3/{bucketName}?uploads` returns active S3-style multipart upload sessions.
- `POST /api/s3/{bucketName}?delete` deletes multiple objects from S3-compatible delete XML.
- `PUT /api/s3/{bucketName}/{objectKey}` uploads a raw request body.
- `PUT /api/s3/{bucketName}/{objectKey}` with `x-amz-copy-source: /sourceBucket/sourceKey` copies an existing object.
- `POST /api/s3/{bucketName}/{objectKey}?uploads` initiates an S3-style multipart upload.
- `PUT /api/s3/{bucketName}/{objectKey}?partNumber={n}&uploadId={uploadId}` uploads one multipart part through the backend.
- `GET /api/s3/{bucketName}/{objectKey}?uploadId={uploadId}` lists uploaded multipart parts.
- `POST /api/s3/{bucketName}/{objectKey}?uploadId={uploadId}` completes multipart upload from S3 `CompleteMultipartUpload` XML.
- `DELETE /api/s3/{bucketName}/{objectKey}?uploadId={uploadId}` aborts multipart upload.
- `HEAD /api/s3/{bucketName}/{objectKey}` returns object metadata headers.
- `GET /api/s3/{bucketName}/{objectKey}` streams the object body.
- `HEAD` and `GET` support basic conditional headers `If-Match`, `If-None-Match`, `If-Modified-Since`, and `If-Unmodified-Since`.
- `GET /api/s3/{bucketName}/{objectKey}` supports one `Range: bytes=start-end`, `bytes=start-`, or `bytes=-suffixLength` request.
- `GET /api/s3/{bucketName}/{objectKey}?tagging` returns S3-compatible object tagging XML.
- `PUT /api/s3/{bucketName}/{objectKey}?tagging` replaces object tags from S3-compatible tagging XML.
- `DELETE /api/s3/{bucketName}/{objectKey}?tagging` clears object tags.
- `DELETE /api/s3/{bucketName}/{objectKey}` moves the object to trash using the same soft-delete behavior as the REST object API.

Auth supports normal Bearer auth, OSMU access key headers, or AWS SigV4 header auth:

- `X-OSMU-Access-Key: <accessKey>`
- `X-OSMU-Secret-Key: <secretKey>`
- `Authorization: AWS4-HMAC-SHA256 Credential=<accessKey>/<date>/<region>/s3/aws4_request, SignedHeaders=..., Signature=...`

Access key permission mapping:

- `GET /api/s3` returns buckets allowed by the active access key bucket scopes.
- `PUT /api/s3/{bucketName}` currently requires Bearer JWT auth.
- `HEAD bucket` and `GET ?location` require any of `READ`, `WRITE`, `DELETE`, or `ADMIN`.
- Bucket-level `GET/PUT/DELETE ?tagging` requires `ADMIN`.
- `DELETE /api/s3/{bucketName}` requires `ADMIN` and the bucket must be empty.
- `POST ?delete` requires `DELETE`.
- `PUT` requires `WRITE`.
- `PUT` with `x-amz-copy-source` requires `WRITE` on the target bucket and `READ` on the source bucket.
- Multipart uploads list, initiate, upload part, list parts, complete, and abort require `WRITE`.
- `GET bucket` object listing requires `READ`.
- `GET ?list-type=2` requires `READ`.
- `HEAD` and `GET` require `READ`.
- Object-level `GET {objectKey}?tagging` requires `READ`.
- Object-level `PUT {objectKey}?tagging` and `DELETE {objectKey}?tagging` require `WRITE`.
- `DELETE` requires `DELETE`.
- `ADMIN` scope also satisfies these object operations.

Headers:

- JWT `GET /api/s3` returns buckets visible to the authenticated user.
- Access Key `GET /api/s3` returns only buckets included in the access key's still-valid scopes.
- `HEAD /api/s3` validates root service access through the same JWT, Access Key, or SigV4 authentication paths.
- AWS SigV4 header auth can be used without `X-OSMU-Secret-Key` for access keys created after `secret_key_ciphertext` support was added.
- AWS SigV4 query/presigned URL auth can be used with `X-Amz-Algorithm`, `X-Amz-Credential`, `X-Amz-Date`, `X-Amz-Expires`, `X-Amz-SignedHeaders`, and `X-Amz-Signature`.
- SigV4 verification supports `AWS4-HMAC-SHA256`, `x-amz-date`, `x-amz-content-sha256`, canonical query string, canonical signed headers, and S3 service scope.
- For non-streaming S3 object `PUT` and multipart part `PUT`, a signed `x-amz-content-sha256` hex payload hash is validated against the actual request body. `UNSIGNED-PAYLOAD` skips body hash validation. `STREAMING-*` payload signatures are rejected as unsupported in the MVP.
- Virtual-hosted-style routing is supported for configured suffixes. With `osmu.s3.virtual-hosted-style.domain-suffixes=localhost`, `Host: {bucket}.localhost` and path `/api/s3/{objectKey}` are routed as `/api/s3/{bucket}/{objectKey}` while SigV4 canonical URI remains the client-signed virtual-hosted path.
- `Content-Length` is required for `PUT`.
- `Content-Type` is stored as object content type. Missing value defaults to `application/octet-stream`.
- `Content-MD5` is accepted on S3 object `PUT`; invalid base64 MD5 returns `InvalidDigest`, and mismatched body checksum returns `BadDigest`.
- S3 object `PUT` validates one optional checksum value header among `x-amz-checksum-sha256`, `x-amz-checksum-sha1`, `x-amz-checksum-crc32`, and `x-amz-checksum-crc32c`. Invalid base64/length returns `InvalidDigest`; mismatched body checksum returns `BadDigest`; matching checksum is stored in object metadata and returns the same `x-amz-checksum-*` response header.
- `x-amz-copy-source` copies source object body, content type, tags, and stored checksum metadata into the target object and returns `CopyObjectResult` XML. Stored checksums are emitted as `ChecksumSHA256`, `ChecksumSHA1`, `ChecksumCRC32`, or `ChecksumCRC32C` elements.
- `x-amz-metadata-directive: COPY|REPLACE` is supported for CopyObject content type handling. `REPLACE` uses the request `Content-Type`.
- `x-amz-tagging-directive: COPY|REPLACE` is supported for CopyObject tag handling. `REPLACE` uses `x-amz-tagging` or `X-OSMU-Tags`.
- CopyObject supports basic source preconditions: `x-amz-copy-source-if-match`, `x-amz-copy-source-if-none-match`, `x-amz-copy-source-if-modified-since`, and `x-amz-copy-source-if-unmodified-since`. Failed preconditions return `412 PreconditionFailed`.
- `X-OSMU-Tags: key=value,stage=raw` stores tags using OSMU tag syntax.
- `x-amz-tagging: key=value&stage=raw` is also accepted and converted to OSMU tag syntax.
- `PUT` returns an MD5-based `ETag` for prototype compatibility.
- S3 multipart initiate requires `X-OSMU-Multipart-Size-Bytes` or `x-amz-meta-osmu-size-bytes` because the current OSMU quota/session model needs expected size before upload.
- S3 multipart initiate optionally accepts `X-OSMU-Multipart-Part-Size-Bytes` or `x-amz-meta-osmu-part-size-bytes`; otherwise the REST multipart default part size is used.
- S3 multipart initiate optionally accepts `X-OSMU-Multipart-Expires-In-Seconds` for session expiry.
- S3 multipart upload part requires `Content-Length`, validates optional `Content-MD5`, signed `x-amz-content-sha256`, and one optional `x-amz-checksum-*` value header, and returns part `ETag`. Matching checksum returns the same `x-amz-checksum-*` response header.
- S3 multipart complete accepts one optional final object `x-amz-checksum-*` value header, validates it against the completed object body, stores matching checksum metadata, returns the same checksum response header, and emits matching complete-result XML checksum element.
- S3 multipart complete request XML accepts optional per-part `ChecksumSHA256`, `ChecksumSHA1`, `ChecksumCRC32`, and `ChecksumCRC32C` elements and validates their checksum syntax before completing storage upload. Full AWS multipart checksum aggregation parity remains future work.
- `HEAD`, `GET`, `ListObjects`, and `ListObjectsV2` include `ETag` when object metadata has an ETag.
- `HEAD` and `GET` return stored `x-amz-checksum-*` headers for S3 uploads that supplied checksum value headers. `ListObjects` and `ListObjectsV2` emit `ChecksumAlgorithm` entries for stored checksums.
- `If-None-Match` returns `304 Not Modified` when it matches the current ETag; `If-Match` returns `412 Precondition Failed` when it does not match.
- `If-Modified-Since` returns `304 Not Modified` when the object has not changed after the requested timestamp; `If-Unmodified-Since` returns `412 Precondition Failed` when the object changed after the requested timestamp.
- Bucket-level responses return `x-amz-bucket-region`; default MVP region is `us-east-1`.
- Bucket create returns `200 OK`, `Location: /{bucketName}`, and `x-amz-bucket-region`. Bucket delete returns `204 No Content`.
- Bucket tagging uses `Tagging/TagSet/Tag/Key/Value` XML, stores up to 50 bucket metadata tags, and disables DOCTYPE/external entity loading while parsing.
- Range GET returns `206 Partial Content`, `Accept-Ranges: bytes`, and `Content-Range`. Invalid ranges return `416 RANGE_NOT_SATISFIABLE`.
- `ListObjectsV2` supports `prefix`, `delimiter`, `max-keys` from `1` to `1000`, `continuation-token`, `encoding-type=url`, and `fetch-owner=true|false`.
- `ListObjectsV2` returns `Contents`, `CommonPrefixes`, `IsTruncated`, `NextContinuationToken`, and optional `Owner`.
- `ListObjects` V1 supports `prefix`, `delimiter`, `max-keys` from `1` to `1000`, `marker`, `encoding-type=url`, and `fetch-owner=true|false`.
- `ListObjects` V1 returns `Contents`, `CommonPrefixes`, `IsTruncated`, `NextMarker`, and optional `Owner`.
- `encoding-type=url` returns `EncodingType` and percent-encodes list key-like XML values such as `Prefix`, `Delimiter`, `Key`, `CommonPrefixes`, and pagination markers.
- `fetch-owner=true` adds `Owner/ID` and `Owner/DisplayName` under each `Contents` item using the authenticated OSMU user.
- Multi-object delete uses `Delete/Object/Key` XML, accepts up to 1000 objects, and returns `DeleteResult/Deleted`. If `Delete/Quiet` is `true`, successful `Deleted` entries are suppressed.
- Multi-object delete uses the same OSMU soft-delete behavior as single object delete. Missing object keys are reported as deleted for S3 compatibility.
- Key-specific failures return `DeleteResult/Error` entries with `Key`, S3-style `Code`, and `Message`. `Quiet=true` only suppresses successful `Deleted` entries, not `Error` entries.
- Multi-object delete validates optional `Content-MD5`; invalid base64 MD5 returns `InvalidDigest`, and mismatched body checksum returns `BadDigest`.
- Object tagging uses `Tagging/TagSet/Tag/Key/Value` XML and reuses the same tag metadata used by the REST object API.
- `PUT ?tagging` rejects blank or invalid XML and the parser disables DOCTYPE/external entity loading.
- Errors under `/api/s3/**` return AWS-style XML `<Error><Code>...</Code><Message>...</Message><RequestId>...</RequestId></Error>`.
- S3 XML error code mapping includes `AccessDenied`, `NoSuchBucket`, `NoSuchKey`, `InvalidRange`, `InvalidRequest`, `InvalidDigest`, `BadDigest`, `PreconditionFailed`, `EntityTooLarge`, `OperationAborted`, and `InternalError`.
- The same S3 error code mapping is used for global `/api/s3/**` error XML and multi-object delete `DeleteResult/Error` entries.

Object tagging XML:

```xml
<Tagging xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <TagSet>
    <Tag>
      <Key>project</Key>
      <Value>osmu</Value>
    </Tag>
  </TagSet>
</Tagging>
```

Bucket location XML:

```xml
<LocationConstraint xmlns="http://s3.amazonaws.com/doc/2006-03-01/">us-east-1</LocationConstraint>
```

Multi-object delete XML:

```xml
<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Quiet>true</Quiet>
  <Object>
    <Key>docs/a.txt</Key>
  </Object>
  <Object>
    <Key>.osmu/versions/reserved.txt</Key>
  </Object>
</Delete>
```

Multi-object delete response with per-key error:

```xml
<DeleteResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Error>
    <Key>.osmu/versions/reserved.txt</Key>
    <Code>InvalidRequest</Code>
    <Message>Object key prefix is reserved.</Message>
  </Error>
</DeleteResult>
```

Copy object response XML:

```xml
<CopyObjectResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <LastModified>2026-06-13T00:00:00Z</LastModified>
  <ETag>"md5"</ETag>
  <ChecksumSHA256>base64-checksum</ChecksumSHA256>
</CopyObjectResult>
```

Multipart initiate response XML:

```xml
<InitiateMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Bucket>project-data</Bucket>
  <Key>videos/input.mp4</Key>
  <UploadId>upload-id</UploadId>
</InitiateMultipartUploadResult>
```

Multipart complete request XML:

```xml
<CompleteMultipartUpload xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Part>
    <PartNumber>1</PartNumber>
    <ETag>"part-etag"</ETag>
    <ChecksumSHA256>base64-part-checksum</ChecksumSHA256>
  </Part>
</CompleteMultipartUpload>
```

Multipart complete response XML:

```xml
<CompleteMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Location>/api/s3/project-data/videos/input.mp4</Location>
  <Bucket>project-data</Bucket>
  <Key>videos/input.mp4</Key>
  <ETag>"multipart-etag"</ETag>
  <ChecksumSHA256>base64-checksum</ChecksumSHA256>
</CompleteMultipartUploadResult>
```

Limitations:

- SigV4 presigned URL authentication uses `UNSIGNED-PAYLOAD` in the MVP. Header-auth and presigned URL auth enforce request time within `osmu.s3.sigv4.clock-skew-seconds`; presigned URLs also enforce `X-Amz-Expires`.
- Streaming/chunked payload signatures are not implemented yet. Non-streaming `x-amz-content-sha256` payload hash enforcement is supported for object and multipart part uploads.
- S3 multipart upload path is MVP-level and currently requires OSMU expected-size headers at initiate time.
- S3 multipart uploads listing is backed by OSMU active multipart sessions, not a raw MinIO bucket scan.
- Virtual-hosted-style routing currently extracts the bucket from the left side of a configured domain suffix. Production deployments must configure DNS/proxy hosts such as `{bucket}.storage.example.com` and set `osmu.s3.virtual-hosted-style.domain-suffixes=storage.example.com`.
- Multi-range GET, full conditional request parity, CopyObject user-metadata/versioning/full-conditional parity, exact CreateBucket/DeleteBucket parity, SigV4 chunked streaming parity, checksum trailer/CRC64NVME/full AWS checksum parity, full multipart ETag parity, and exact AWS error schema parity are not implemented yet.

### GET /api/buckets/{bucketName}/permissions

버킷 권한 목록 조회.

응답:

```json
{
  "items": [
    {
      "id": 1,
      "bucketId": 1,
      "subjectType": "USER",
      "subjectId": 2,
      "permission": "READ",
      "createdAt": "2026-06-13T00:00:00+09:00",
      "updatedAt": "2026-06-13T00:00:00+09:00"
    }
  ],
  "nextCursor": null
}
```

정책:

- `ADMIN`, bucket owner, 같은 조직 `ORG_ADMIN`, `ADMIN` bucket permission을 가진 사용자만 조회 가능하다.

### POST /api/buckets/{bucketName}/permissions

버킷 권한 부여.

요청:

```json
{
  "subjectType": "USER",
  "subjectId": 2,
  "permissions": ["READ", "WRITE"]
}
```

정책:

- `subjectType`은 `USER`, `ORGANIZATION`을 지원한다.
- `permissions`는 `READ`, `WRITE`, `DELETE`, `ADMIN`을 지원한다.
- `READ`는 object 목록/다운로드/presigned download 권한이다.
- `WRITE`는 object upload/presigned upload/complete 권한이다.
- `DELETE`는 object 삭제 권한이다.
- `ADMIN`은 bucket permission 관리 권한이며 object 작업 권한도 포함한다.
- `ORG_ADMIN`은 자기 조직 user 또는 자기 조직 subject에만 권한을 부여할 수 있다.
- 권한 부여는 감사 로그 대상이다.

### DELETE /api/buckets/{bucketName}/permissions/{permissionId}

버킷 권한 회수.

정책:

- bucket 관리 권한이 있는 사용자만 가능하다.
- 권한 회수는 감사 로그 대상이다.
- 권한 회수 후 영향을 받는 활성 Access Key는 현재 권한으로 policy를 재동기화한다.
- 남은 bucket/permission scope가 없으면 해당 Access Key를 `INACTIVE`로 전환한다.

## 7. Object API

### GET /api/buckets/{bucketName}/objects

오브젝트 목록 조회. `READ` 권한이 필요하다.

Query:

- `prefix`
- `delimiter`: 폴더형 탐색 시 `/`
- `limit`: 기본 100, 최대 1000
- `cursor`: 이전 응답의 `nextCursor`

응답:

```json
{
  "items": [
    {
      "key": "images/sample.png",
      "sizeBytes": 2048,
      "contentType": "image/png",
      "lastModifiedAt": "2026-06-13T00:00:00+09:00"
    }
  ],
  "prefixes": [
    "images/raw/"
  ],
  "prefixes": [
    "images/raw/"
  ],
  "nextCursor": null
}
```

정책:

- `cursor`는 마지막으로 반환된 object key다.
- 다음 페이지는 같은 `prefix` 조건에서 cursor key보다 뒤의 object부터 조회한다.
- `prefix`가 바뀌면 cursor는 새로 발급받아야 한다.
- `delimiter=/`를 사용하면 현재 prefix 바로 아래의 object와 하위 prefix를 분리해 반환한다.
- `delimiter=/`를 사용하면 현재 prefix 바로 아래의 object와 하위 prefix를 분리해 반환한다.

Deleted object 조회:

- `GET /api/buckets/{bucketName}/objects?deleted=true`
- soft-deleted object trash 목록을 반환한다.
- active 목록에는 deleted object가 표시되지 않는다.
- trash 목록은 `delimiter` grouping을 사용하지 않는다.

### POST /api/buckets/{bucketName}/objects

파일 업로드.

Form Data:

- `key`
- `file`

정책:

- 업로드 전 `WRITE` 권한 확인.
- 업로드 전 quota 확인.
- 대용량 파일은 multipart upload 또는 presigned URL로 확장.

### PUT /api/buckets/{bucketName}/objects/tags

Object tag 수정. `WRITE` 권한이 필요하다.

요청:

```json
{
  "key": "images/sample.png",
  "tags": "project=osmu,stage=raw"
}
```

응답:

```json
{
  "data": {
    "key": "images/sample.png",
    "sizeBytes": 2048,
    "contentType": "image/png",
    "lastModifiedAt": "2026-06-13T00:00:00+09:00",
    "tags": {
      "project": "osmu",
      "stage": "raw"
    }
  }
}
```

정책:

- `tags`는 `key=value` comma-separated 형식이며 최대 10쌍이다.
- 빈 `tags`는 기존 tag를 제거한다.
- 감사 로그 `OBJECT_TAG_UPDATE`를 기록한다.

### POST /api/buckets/{bucketName}/objects/presigned-upload

MinIO 직접 업로드용 presigned PUT URL 발급.

요청:

```json
{
  "key": "videos/input.mp4",
  "contentType": "video/mp4",
  "expiresInSeconds": 900,
  "tags": "project=osmu,stage=raw"
}
```

응답:

```json
{
  "data": {
    "url": "http://localhost:9000/bucket/.osmu/uploads/{hash}/{uploadId}?...",
    "method": "PUT",
    "expiresInSeconds": 900,
    "uploadId": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

현재 MVP 제약:

- `osmu.storage.mode=minio`에서 지원한다.
- `in-memory` storage mode에서는 `STORAGE_ERROR`를 반환한다.
- Same-key upload is staged under `.osmu/uploads/` and completed into the active key. If the active object exists, complete snapshots the previous active object into `.osmu/versions/` before replacement.
- URL 발급 전 `WRITE` 권한을 확인한다.
- `tags`는 `key=value` comma-separated 형식이며 최대 10쌍이다. 발급 시 upload session에 저장되고 complete 시 object tag로 적용된다.
- 업로드 완료 후 `presigned-upload/complete`로 object metadata/quota를 확정한다.

### POST /api/buckets/{bucketName}/objects/presigned-upload/complete

Overwrite/versioning notes:

- The presigned PUT URL writes to an internal staging key, not directly to the active object key.
- `complete` copies staging content to the active key, deletes the staging object, and saves object metadata/tags.
- If the active object existed when the upload session was created, `complete` stores the previous active object as an object version and increments bucket usage by the new active size plus one version object.
- If quota validation fails, the staging object is deleted and the active object remains unchanged.

presigned PUT 완료 후 object metadata와 quota를 확정한다.
`WRITE` 권한이 필요하다.

요청:

```json
{
  "uploadId": "550e8400-e29b-41d4-a716-446655440000",
  "key": "videos/input.mp4"
}
```

응답:

```json
{
  "data": {
    "key": "videos/input.mp4",
    "sizeBytes": 10485760,
    "contentType": "video/mp4",
    "lastModifiedAt": "2026-06-13T04:15:00+09:00",
    "tags": {
      "project": "osmu",
      "stage": "raw"
    }
  }
}
```

정책:

- upload session에 저장된 `tags`가 있으면 quota 검증 후 object tag를 적용하고 완료 응답에 포함한다.

### POST /api/buckets/{bucketName}/objects/multipart-upload

대용량 파일용 MinIO multipart upload를 시작하고 part별 presigned PUT URL을 발급한다.
`WRITE` 권한이 필요하다.

요청:

```json
{
  "key": "videos/input.mp4",
  "contentType": "video/mp4",
  "sizeBytes": 1073741824,
  "partSizeBytes": 67108864,
  "expiresInSeconds": 900,
  "tags": "project=osmu,stage=raw"
}
```

응답:

```json
{
  "data": {
    "uploadId": "550e8400-e29b-41d4-a716-446655440000",
    "key": "videos/input.mp4",
    "sizeBytes": 1073741824,
    "partSizeBytes": 67108864,
    "partCount": 16,
    "expiresInSeconds": 900,
    "expiresAt": "2026-06-13T10:30:00Z",
    "parts": [
      {
        "partNumber": 1,
        "url": "http://localhost:9000/bucket/videos/input.mp4?partNumber=1&uploadId=...",
        "method": "PUT",
        "expiresInSeconds": 900,
        "startByte": 0,
        "endByte": 67108863
      }
    ]
  }
}
```

정책:

- `osmu.storage.mode=minio`에서 지원한다.
- `in-memory` storage mode에서는 `STORAGE_ERROR`를 반환한다.
- Same-key multipart complete is supported. If the active object exists, complete snapshots the previous active object into `.osmu/versions/` before replacing it.
- URL 발급 전 `WRITE` 권한과 quota를 확인한다.
- `partSizeBytes` 기본값은 64 MiB이며 5 MiB보다 큰 파일의 part size는 최소 5 MiB다.
- 최대 part 수는 10000개다.
- client는 각 part PUT 응답의 `ETag`를 수집해 complete API로 전달해야 한다.
- Browser client가 `ETag`를 읽으려면 MinIO bucket CORS `ExposeHeaders`에 `ETag`가 포함되어야 한다.
- Multipart overwrite checks quota before completing storage upload. On quota failure, the multipart upload is aborted and the active object remains unchanged.
- 만료된 ACTIVE multipart upload session은 cleanup scheduler가 MinIO abort 후 `EXPIRED`로 변경하고 `OBJECT_MULTIPART_UPLOAD_CLEANUP` 감사 로그를 기록한다.

### POST /api/buckets/{bucketName}/objects/multipart-upload/refresh

기존 ACTIVE multipart upload session의 part별 presigned PUT URL을 재발급한다.
브라우저 재시도/재개 시 만료된 URL을 새 URL로 교체하기 위한 API다.
`WRITE` 권한이 필요하다.

요청:

```json
{
  "uploadId": "550e8400-e29b-41d4-a716-446655440000",
  "key": "videos/input.mp4",
  "expiresInSeconds": 300
}
```

응답:

```json
{
  "data": {
    "uploadId": "550e8400-e29b-41d4-a716-446655440000",
    "key": "videos/input.mp4",
    "sizeBytes": 1073741824,
    "partSizeBytes": 67108864,
    "partCount": 16,
    "expiresInSeconds": 300,
    "expiresAt": "2026-06-13T10:30:00Z",
    "parts": [
      {
        "partNumber": 1,
        "url": "http://localhost:9000/bucket/videos/input.mp4?partNumber=1&uploadId=...",
        "method": "PUT",
        "expiresInSeconds": 300,
        "startByte": 0,
        "endByte": 67108863
      }
    ]
  }
}
```

정책:

- `uploadId`, `key`, user, bucket이 session과 일치해야 한다.
- `ACTIVE` multipart session만 refresh 가능하다.
- Backend는 session에 저장된 `sizeBytes`, `partSizeBytes`, `partCount`, storage upload id를 사용해 part URL만 새로 만든다.
- `expiresAt`은 upload session 만료 시각이며 refresh URL 만료 시간과 별개로 늘어나지 않는다.
- 성공 시 `OBJECT_MULTIPART_UPLOAD_REFRESH` 감사 로그를 기록한다.

### POST /api/buckets/{bucketName}/objects/multipart-upload/parts

기존 ACTIVE multipart upload session에 이미 업로드된 part 목록을 조회한다.
Frontend resume은 이 API로 storage-side completed part ETag를 복구한 뒤 완료된 part를 skip한다.
`WRITE` 권한이 필요하다.

요청:

```json
{
  "uploadId": "550e8400-e29b-41d4-a716-446655440000",
  "key": "videos/input.mp4"
}
```

응답:

```json
{
  "data": {
    "uploadId": "550e8400-e29b-41d4-a716-446655440000",
    "key": "videos/input.mp4",
    "sizeBytes": 1073741824,
    "partSizeBytes": 67108864,
    "partCount": 16,
    "parts": [
      {
        "partNumber": 1,
        "etag": "\"part-etag\"",
        "sizeBytes": 67108864
      }
    ]
  }
}
```

정책:

- `uploadId`, `key`, user, bucket이 session과 일치해야 한다.
- `ACTIVE` multipart session만 조회 가능하다.
- Backend는 MinIO `listParts` 결과를 반환한다.
- 성공 시 `OBJECT_MULTIPART_UPLOAD_PARTS_LIST` 감사 로그를 기록한다.

### POST /api/buckets/{bucketName}/objects/multipart-upload/complete

multipart upload 완료 후 object metadata와 quota를 확정한다.
`WRITE` 권한이 필요하다.

요청:

```json
{
  "uploadId": "550e8400-e29b-41d4-a716-446655440000",
  "key": "videos/input.mp4",
  "parts": [
    {
      "partNumber": 1,
      "etag": "\"part-etag\""
    }
  ]
}
```

정책:

- part 번호는 중복될 수 없으며 1~10000 범위여야 한다.
- 완료 후 object metadata index와 bucket usage를 갱신한다.
- upload session에 저장된 `tags`가 있으면 object tag로 적용한다.

### POST /api/buckets/{bucketName}/objects/multipart-upload/abort

진행 중인 multipart upload를 중단하고 storage multipart upload를 abort한다.
`WRITE` 권한이 필요하다.

요청:

```json
{
  "uploadId": "550e8400-e29b-41d4-a716-446655440000",
  "key": "videos/input.mp4"
}
```

정책:

- ACTIVE 상태의 multipart upload session만 abort할 수 있다.
- 성공 시 upload session 상태는 `ABORTED`가 된다.
- storage에 업로드된 미완료 part는 MinIO abort API로 정리한다.

### POST /api/buckets/{bucketName}/objects/presigned-download

MinIO 직접 다운로드용 presigned GET URL 발급.
`READ` 권한이 필요하다.

요청:

```json
{
  "key": "videos/input.mp4",
  "expiresInSeconds": 900
}
```

### POST /api/buckets/{bucketName}/objects/share-links

로그인 사용자가 object를 임시 공유할 수 있는 public download link를 발급한다.
`READ` 권한이 필요하다.

요청:

```json
{
  "key": "videos/input.mp4",
  "expiresInSeconds": 3600,
  "note": "department reuse",
  "maxDownloads": 100,
  "password": "optional-share-password",
  "allowedIpCidrs": "203.0.113.0/24,2001:db8::/32"
}
```

정책:

- `expiresInSeconds`는 60초 이상 604800초 이하만 허용한다.
- `note`는 512자 이하이며 선택값이다.
- token 원문은 create 응답에서만 반환하고 DB에는 SHA-256 hash만 저장한다.
- 대상 object가 soft-deleted 상태이거나 storage에 없으면 공유 링크를 만들 수 없다.

응답:

```json
{
  "data": {
    "id": 1,
    "bucketName": "media",
    "key": "videos/input.mp4",
    "status": "ACTIVE",
    "expiresAt": "2026-06-14T04:30:00+09:00",
    "note": "department reuse",
    "maxDownloads": 100,
    "downloadCount": 0,
    "lastAccessedAt": null,
    "passwordProtected": true,
    "allowedIpCidrs": "203.0.113.0/24,2001:db8:0:0:0:0:0:0/32",
    "ipRestricted": true,
    "createdByUserId": 1,
    "createdAt": "2026-06-14T03:30:00+09:00",
    "token": "opaque-token",
    "url": "http://localhost:8080/api/public/share-links/opaque-token"
  }
}
```

### GET /api/buckets/{bucketName}/objects/share-links

bucket 또는 특정 object key의 share link 목록을 조회한다.
`READ` 권한이 필요하다.

Query:

- `key`: 선택. 특정 object key만 조회.
- `limit`: 선택. 1~200, 기본 50.

응답 목록은 `token`과 `url`을 노출하지 않는다.

### POST /api/buckets/{bucketName}/objects/share-links/cleanup

Marks expired active share links in the bucket as `EXPIRED`.
Requires bucket manage permission.
The scheduler also performs global expired-link cleanup with the same `OBJECT_SHARE_LINK_CLEANUP` audit event and `osmu.object.share.cleanup.*` metrics.

Response:

```json
{
  "data": {
    "bucketName": "media",
    "expiredCount": 3
  }
}
```

### DELETE /api/buckets/{bucketName}/objects/share-links/{linkId}

share link를 취소한다.
link 생성자 또는 bucket 관리 권한 사용자가 실행할 수 있다.
성공 시 `204 No Content`를 반환한다.

### GET /api/public/share-links/{token}

Bearer token 없이 share token으로 object를 다운로드한다.

정책:

- `ACTIVE`이고 만료되지 않은 token만 허용한다.
- 만료 또는 취소된 link는 `404 NOT_FOUND`를 반환한다.
- 성공 시 `OBJECT_SHARE_LINK_DOWNLOAD` audit log를 `actorId=anonymous`로 기록한다.

Additional share-link download policy:

- Global admin policy can require password/IP allowlist and cap expiry/download limits for all new share links.
- Successful public downloads increment `downloadCount` and update `lastAccessedAt`.
- Optional password-protected links accept `X-OSMU-Share-Password` header or `password` query parameter.
- Raw share passwords are never stored; only a SHA-256 hash bound to the link token hash is stored.
- Optional `allowedIpCidrs` accepts up to 20 IPv4/IPv6 literal IP or CIDR entries. Hostnames are rejected.
- IP-restricted links use the first `X-Forwarded-For` IP when present, otherwise the request remote address.
- Expired, revoked, max-download-reached, missing-password, wrong-password, blocked-IP, or invalid-client-IP links return `404 NOT_FOUND`.

### GET /api/buckets/{bucketName}/objects/versions/{objectKey}

object version 목록 조회. `READ` 권한 필요.

정책:

- REST upload, presigned upload complete, multipart upload complete, and version restore snapshot the previous active object into hidden version storage before replacing the active key.
- version storage key는 `.osmu/versions/` prefix를 사용하며 일반 object list에는 노출하지 않는다.
- 응답은 최신 version snapshot부터 반환한다.

응답:

```json
{
  "data": [
    {
      "versionId": "550e8400-e29b-41d4-a716-446655440000",
      "key": "docs/report.txt",
      "storageKey": ".osmu/versions/hash/550e8400-e29b-41d4-a716-446655440000",
      "sizeBytes": 1024,
      "contentType": "text/plain",
      "objectLastModifiedAt": "2026-06-13T10:10:00+09:00",
      "createdAt": "2026-06-13T10:20:00+09:00",
      "tags": {
        "project": "osmu"
      }
    }
  ]
}
```

### POST /api/buckets/{bucketName}/objects/versions/{versionId}/restore/{objectKey}

object version을 active object로 복구한다. `WRITE` 권한 필요.

정책:

- 현재 active object를 먼저 새 version으로 snapshot한 뒤 선택한 version content/tags를 active key에 복구한다.
- 성공 시 `OBJECT_VERSION_RESTORE` 감사 로그를 기록한다.
- soft-deleted object는 먼저 trash restore 후 version restore를 수행해야 한다.

### GET /api/buckets/{bucketName}/objects/versions/{objectKey}

object version 목록 조회. `READ` 권한 필요.

정책:

- REST upload로 같은 key를 overwrite하면 기존 active object가 hidden version storage key로 snapshot된다.
- version storage key는 `.osmu/versions/` prefix를 사용하며 일반 object list에는 노출하지 않는다.
- 응답은 최신 version snapshot부터 반환한다.

응답:

```json
{
  "data": [
    {
      "versionId": "550e8400-e29b-41d4-a716-446655440000",
      "key": "docs/report.txt",
      "storageKey": ".osmu/versions/hash/550e8400-e29b-41d4-a716-446655440000",
      "sizeBytes": 1024,
      "contentType": "text/plain",
      "objectLastModifiedAt": "2026-06-13T10:10:00+09:00",
      "createdAt": "2026-06-13T10:20:00+09:00",
      "tags": {
        "project": "osmu"
      }
    }
  ]
}
```

### POST /api/buckets/{bucketName}/objects/versions/{versionId}/restore/{objectKey}

object version을 active object로 복구한다. `WRITE` 권한 필요.

정책:

- 현재 active object를 먼저 새 version으로 snapshot한 뒤 선택한 version content/tags를 active key에 복구한다.
- 성공 시 `OBJECT_VERSION_RESTORE` 감사 로그를 기록한다.
- soft-deleted object는 먼저 trash restore 후 version restore를 수행해야 한다.

### GET /api/buckets/{bucketName}/objects/versions/{versionId}/download/{objectKey}

Downloads one saved object version. Requires `READ`.

Notes:

- Streams hidden version binary from `.osmu/versions/{hash}/{versionId}`.
- Response uses original object key filename in `Content-Disposition`.
- Success audit event: `OBJECT_VERSION_DOWNLOAD`.
- Downloading a version does not modify active object metadata or bucket usage.

### DELETE /api/buckets/{bucketName}/objects/versions/{versionId}/delete/{objectKey}

Deletes one saved object version. Requires `DELETE`.

Notes:

- Deletes version binary if present and removes `object_versions` metadata.
- Decrements bucket usage by version `sizeBytes` and object count by `1`.
- Success audit event: `OBJECT_VERSION_DELETE`.
- Active object content is not changed.

### GET /api/buckets/{bucketName}/objects/{objectKey}

파일 다운로드.

정책:

- 다운로드 전 `READ` 권한을 확인한다.
- Backend REST 다운로드는 `StreamingResponseBody`로 storage stream을 client response에 전달한다.
- MinIO mode의 REST 다운로드 main path는 파일 전체를 JVM byte array로 읽지 않는다.
- stream open 성공 후 감사 로그 `OBJECT_DOWNLOAD`을 기록한다.
- 대용량 파일은 presigned URL 우선.

### DELETE /api/buckets/{bucketName}/objects/{objectKey}

파일 삭제.

정책:

- 삭제 전 `DELETE` 권한을 확인한다.
- 삭제는 soft delete로 처리한다. object data는 즉시 MinIO에서 지우지 않고 `object_metadata.deleted_at`을 기록해 active 목록/다운로드에서 숨긴다.
- soft-deleted object는 quota/objectCount를 계속 점유한다.
- 성공 시 감사 로그 `OBJECT_DELETE`를 기록한다.

### POST /api/buckets/{bucketName}/objects/restore/{objectKey}

soft-deleted 파일 복구.

정책:

- `DELETE` 권한을 확인한다.
- `deleted_at`을 제거하고 active 목록/다운로드에 다시 표시한다.
- 성공 시 감사 로그 `OBJECT_RESTORE`를 기록한다.

### POST /api/buckets/{bucketName}/objects/purge/{objectKey}

soft-deleted 파일 영구 삭제.

정책:

- `DELETE` 권한을 확인한다.
- soft-deleted object만 purge할 수 있다.
- MinIO object를 삭제하고 metadata index를 제거하며 quota/objectCount를 감소시킨다.
- 성공 시 감사 로그 `OBJECT_PURGE`를 기록한다.
- `osmu.object.retention.enabled=true`이면 `deleted_at`이 retention 기간을 지난 object는 scheduler가 자동 purge하고 `OBJECT_RETENTION_PURGE` 감사 로그를 기록한다.

## 8. Access Key API

### GET /api/access-keys

내 Access Key 목록 조회.

응답에는 `secretKey`와 `secretKeyHash`를 포함하지 않는다.

```json
{
  "items": [
    {
      "id": 1,
      "ownerId": 1,
      "name": "local-dev-key",
      "accessKey": "osmu-access-key",
      "policyName": "osmu-access-key-1",
      "allowedBuckets": ["media-archive"],
      "permissions": ["READ", "WRITE", "DELETE"],
      "bucketScopes": [
        {
          "bucketName": "media-archive",
          "permissions": ["READ", "WRITE", "DELETE"]
        }
      ],
      "status": "ACTIVE",
      "createdAt": "2026-06-13T04:10:00+09:00",
      "expiresAt": null
    }
  ],
  "nextCursor": null
}
```

### POST /api/access-keys

Access Key 생성.

요청:

```json
{
  "name": "local-dev-key",
  "allowedBuckets": ["media-archive"],
  "permissions": ["READ", "WRITE", "DELETE"],
  "bucketScopes": [
    {
      "bucketName": "media-archive",
      "permissions": ["READ", "WRITE"]
    },
    {
      "bucketName": "backup-target",
      "permissions": ["WRITE"]
    }
  ],
  "expiresAt": null
}
```

응답:

```json
{
  "data": {
    "id": 1,
    "name": "local-dev-key",
    "accessKey": "osmu-access-key",
    "secretKey": "secret-visible-once",
    "policyName": "osmu-access-key-1",
    "policyDocument": "{\"Version\":\"2012-10-17\",\"Statement\":[...]}",
    "allowedBuckets": ["media-archive"],
    "permissions": ["READ", "WRITE", "DELETE"],
    "bucketScopes": [
      {
        "bucketName": "media-archive",
        "permissions": ["READ", "WRITE"]
      }
    ]
  }
}
```

정책:

- Secret Key는 생성 응답에서 1회만 노출.
- 서버에는 SHA-256 hash만 저장.
- 기존 방식은 `allowedBuckets`와 전역 `permissions`를 사용한다.
- 새 방식은 `bucketScopes`로 bucket별 permission을 지정한다.
- `bucketScopes`가 있으면 `allowedBuckets`와 전역 `permissions`보다 우선한다.
- `allowedBuckets`는 사용자가 접근 가능한 bucket만 지정할 수 있다.
- `permissions`는 `READ`, `WRITE`, `DELETE`를 지원한다.
- 요청한 permission은 사용자가 해당 bucket에서 가진 권한을 초과할 수 없다.
- Backend는 bucket별 scope로 S3 IAM 호환 policy document를 생성한다.
- `policyDocument`는 생성 응답에서 운영/디버깅용으로 반환한다. Secret 값은 포함하지 않는다.
- MinIO provisioning mode에서는 user/policy 적용이 성공한 뒤 access key metadata를 저장한다.
- provisioning 실패 시 access key와 secret key는 발급되지 않는다.
- bucket permission 회수 시 기존 active key의 `bucketScopes`를 현재 권한 범위로 축소하고 S3 policy를 다시 적용한다.
- `allowedBuckets`와 `permissions`는 `bucketScopes`에서 파생한 호환 필드다.
- 더 이상 허용 가능한 scope가 없는 key는 `INACTIVE`로 변경하고 S3 user/policy를 제거한다.
- `osmu.metadata.mode=mariadb`에서는 `access_keys` table에 저장한다.

- Access key `permissions` supports `READ`, `WRITE`, `DELETE`, and `ADMIN`.
- `ADMIN` access key scope is required for bucket lifecycle alias operations.

### DELETE /api/access-keys/{keyId}

Access Key 비활성화.

## 9. Admin API

### GET /api/admin/usage

전체 사용량 조회.

### GET /api/admin/object-share-policy

Global object share link policy를 조회한다. `ADMIN` 권한 필요.

Response:

```json
{
  "data": {
    "requirePassword": false,
    "requireIpAllowlist": false,
    "maxExpiresSeconds": 604800,
    "maxDownloadsLimit": null,
    "updatedAt": "2026-06-14T05:00:00+09:00"
  }
}
```

### PUT /api/admin/object-share-policy

Global object share link policy를 저장한다. `ADMIN` 권한 필요.

Request:

```json
{
  "requirePassword": true,
  "requireIpAllowlist": true,
  "maxExpiresSeconds": 3600,
  "maxDownloadsLimit": 100,
  "reason": "secure pilot"
}
```

Policy:

- `requirePassword=true`면 share link 생성 요청에 `password`가 필요하다.
- `requireIpAllowlist=true`면 share link 생성 요청에 `allowedIpCidrs`가 필요하다.
- `maxExpiresSeconds`는 60~604800초 범위이며 link 생성 `expiresInSeconds` 상한으로 적용된다.
- `maxDownloadsLimit`는 `null` 또는 1~100000이며 link 생성 `maxDownloads` 상한으로 적용된다. 값이 있으면 link 생성 요청이 `maxDownloads`를 생략해도 해당 제한이 기본 적용된다.
- 저장 성공 시 `OBJECT_SHARE_POLICY_SAVE` audit log를 기록한다.

### GET /api/admin/object-share-analytics

Global object share link 운영 집계를 조회한다. `ADMIN` 권한 필요.

Query:

- `limit`: 최근 링크 목록 개수. 1~50, default 10.
- `bucketName`: 선택. 특정 bucket의 share link만 집계한다.
- `status`: 선택. `ACTIVE`, `EXPIRED`, `REVOKED`, `LIMIT_REACHED` 중 하나.

Response:

```json
{
  "data": {
    "totalLinks": 24,
    "activeLinks": 10,
    "expiredLinks": 8,
    "revokedLinks": 4,
    "limitReachedLinks": 2,
    "passwordProtectedLinks": 20,
    "ipRestrictedLinks": 18,
    "totalDownloads": 130,
    "lastAccessedAt": "2026-06-14T05:10:00+09:00",
    "recentLinks": [
      {
        "id": 24,
        "bucketName": "media",
        "key": "videos/input.mp4",
        "status": "ACTIVE",
        "maxDownloads": 100,
        "downloadCount": 7,
        "passwordProtected": true,
        "ipRestricted": true
      }
    ]
  }
}
```

`recentLinks`는 admin 운영 리뷰용이며 raw token과 public URL은 포함하지 않는다.

### GET /api/admin/quota-policies

사용자, 조직, 버킷 단위 quota 정책 목록을 조회한다. `ADMIN` 권한 필요.

응답:

```json
{
  "items": [
    {
      "id": 1,
      "targetType": "USER",
      "targetId": 7,
      "quotaBytes": 107374182400,
      "usedBytes": 1048576,
      "remainingBytes": 107373133824,
      "createdAt": "2026-06-14T03:00:00+09:00",
      "updatedAt": "2026-06-14T03:00:00+09:00"
    }
  ]
}
```

정책:

- `targetType`은 `USER`, `ORGANIZATION`, `BUCKET`을 지원한다.
- `USER` quota는 해당 user가 소유한 모든 `USER` bucket 사용량 합계에 적용한다.
- `ORGANIZATION` quota policy가 있으면 organization `defaultQuotaBytes` 대신 적용한다.
- `BUCKET` quota policy가 있으면 bucket metadata의 `quotaBytes` 대신 적용한다.

### GET /api/admin/quota-policies/history

quota 정책 변경 이력을 최신순으로 조회한다. `ADMIN` 권한 필요.

Query:

- `limit`: 1-200, default 50

응답:

```json
{
  "items": [
    {
      "id": 3,
      "targetType": "USER",
      "targetId": 7,
      "action": "UPDATE",
      "previousQuotaBytes": 107374182400,
      "newQuotaBytes": 214748364800,
      "actorId": "admin",
      "reason": "increase for media ingest pilot",
      "createdAt": "2026-06-14T03:00:00+09:00"
    }
  ]
}
```

정책:

- `action`은 `CREATE`, `UPDATE`, `DELETE`를 사용한다.
- `CREATE`의 `previousQuotaBytes`와 `DELETE`의 `newQuotaBytes`는 `null`이다.
- release/audit 검토에서 quota 변경 사유 확인은 `reason`과 audit log를 함께 사용한다.

### PUT /api/admin/quota-policies/{targetType}/{targetId}

quota 정책을 생성하거나 갱신한다. `ADMIN` 권한 필요.

요청:

```json
{
  "quotaBytes": 107374182400,
  "reason": "initial pilot quota"
}
```

응답:

```json
{
  "data": {
    "id": 1,
    "targetType": "USER",
    "targetId": 7,
    "quotaBytes": 107374182400,
    "usedBytes": 0,
    "remainingBytes": 107374182400
  }
}
```

정책:

- `quotaBytes`는 양수여야 한다.
- `reason`은 선택값이며 512자 이하여야 한다.
- 대상 user, organization, bucket이 존재해야 한다.
- 저장 성공 시 `QUOTA_POLICY_SAVE` 감사 로그를 기록한다.
- 저장 성공 시 quota policy history에 `CREATE` 또는 `UPDATE` 이력을 기록한다.

### DELETE /api/admin/quota-policies/{targetType}/{targetId}

quota 정책을 삭제한다. `ADMIN` 권한 필요.

Query:

- `reason`: 선택값, 512자 이하

정책:

- 정책이 없으면 `NOT_FOUND`를 반환한다.
- 삭제 성공 시 `QUOTA_POLICY_DELETE` 감사 로그를 기록한다.
- 삭제 성공 시 quota policy history에 `DELETE` 이력을 기록한다.

### GET /api/admin/audit-logs

감사 로그 조회.

Query:

- `eventType`
- `actorId`
- `requestId`
- `targetType`
- `targetId`
- `result`
- `from`
- `to`
- `limit`
- `cursor`

현재 MVP 응답 항목:

```json
{
  "items": [
    {
      "id": 1,
      "eventType": "LOGIN",
      "actorId": "admin",
      "targetType": "USER",
      "targetId": "admin",
      "result": "SUCCESS",
      "message": "User login",
      "ipAddress": "203.0.113.10",
      "userAgent": "OSMU-Test-Agent",
      "requestId": "req-auth-meta-1",
      "createdAt": "2026-06-13T03:55:00+09:00"
    }
  ],
  "nextCursor": null
}
```

### GET /api/admin/audit-logs/export.csv

Audit log CSV export. `ADMIN` required. Uses same filter query as `GET /api/admin/audit-logs`:

- `eventType`
- `actorId`
- `requestId`
- `targetType`
- `targetId`
- `result`
- `from`
- `to`
- `limit`
- `cursor`

Response:

- `Content-Type: text/csv`
- `Content-Disposition: attachment; filename="osmu-audit-logs.csv"`
- Header row: `id,eventType,actorId,targetType,targetId,result,message,ipAddress,userAgent,requestId,createdAt`
- CSV fields are RFC 4180 style escaped when values contain comma, quote, or newline.

### GET /api/admin/system/status

시스템 상태 조회.

응답:

```json
{
  "data": {
    "backend": "UP",
    "database": "UP",
    "storage": "UP",
    "accessKeyProvisioner": "UP"
  }
}
```

### GET /api/admin/backup/status

백업/복구 운영 준비 상태 조회. `ADMIN` 권한 필요.

현재 lightweight demo에서는 실제 백업이 실행되지 않았음을 명확히 표시하고, durable pilot 전 필요한 gate를 `pendingGates`로 반환한다.

응답:

```json
{
  "data": {
    "status": "DRILL_PENDING",
    "metadataStore": "in-memory",
    "objectStore": "in-memory",
    "databaseHealthy": true,
    "storageHealthy": true,
    "rpoTarget": "24h",
    "rtoTarget": "4h",
    "runbookAvailable": true,
    "restoreDrillExecuted": false,
    "lastBackupAt": null,
    "lastRestoreDrillAt": null,
    "pendingGates": [
      "MariaDB metadata mode is not enabled.",
      "MinIO object storage mode is not enabled.",
      "Restore drill has not been executed in this runtime."
    ]
  }
}
```

### GET /api/admin/object-retention/status

object trash retention 정책과 purge metric 요약 조회. `ADMIN` 권한 필요.

응답:

```json
{
  "data": {
    "enabled": true,
    "retentionDays": 30,
    "batchSize": 100,
    "versionRetentionDays": 90,
    "versionBatchSize": 100,
    "purgedObjectCount": 12,
    "failedObjectCount": 0,
    "failedRunCount": 0,
    "purgedVersionCount": 20,
    "failedVersionCount": 0,
    "failedVersionRunCount": 0
  }
}
```

### PUT /api/admin/object-retention/policy

성공 시 `OBJECT_RETENTION_POLICY_UPDATE` 감사 로그를 기록한다.

성공 시 `OBJECT_RETENTION_POLICY_UPDATE` 감사 로그를 기록한다.

object trash retention policy를 운영 중 변경한다. `ADMIN` 권한 필요.

요청:

```json
{
  "enabled": true,
  "retentionDays": 14,
  "batchSize": 200,
  "versionRetentionDays": 90,
  "versionBatchSize": 200
}
```

정책:

- `enabled`는 runtime retention purge 정책 on/off 값이다.
- `retentionDays`는 1~3650 범위여야 한다.
- `batchSize`는 1~10000 범위여야 한다.
- `versionRetentionDays`는 historical object version 보존 기간이며 1~3650 범위여야 한다.
- `versionBatchSize`는 1회 version purge 최대 개수이며 1~10000 범위여야 한다.
- 누락된 필드는 기존 정책 값을 유지한다.
- `osmu.object.retention.enabled=false`로 scheduler bean 자체가 비활성화된 경우 저장된 policy가 enabled여도 status `enabled=false`가 될 수 있다.

응답:

```json
{
  "data": {
    "enabled": true,
    "retentionDays": 14,
    "batchSize": 200,
    "versionRetentionDays": 90,
    "versionBatchSize": 200,
    "purgedObjectCount": 12,
    "failedObjectCount": 0,
    "failedRunCount": 0,
    "purgedVersionCount": 20,
    "failedVersionCount": 0,
    "failedVersionRunCount": 0
  }
}
```

### POST /api/admin/object-retention/purge

retention 기간이 지난 soft-deleted object purge를 수동 실행한다. `ADMIN` 권한 필요.

응답:

```json
{
  "data": {
    "purgedCount": 3,
    "purgedVersionCount": 4,
    "status": {
      "enabled": true,
      "retentionDays": 30,
      "batchSize": 100,
      "versionRetentionDays": 90,
      "versionBatchSize": 100,
      "purgedObjectCount": 15,
      "failedObjectCount": 0,
      "failedRunCount": 0,
      "purgedVersionCount": 24,
      "failedVersionCount": 0,
      "failedVersionRunCount": 0
    }
  }
}
```

## 10. API 구현 순서

1. `GET /api/health`
2. `GET /api/storage/health`
3. `GET /api/database/health`
4. Bucket API
5. Object API
6. Auth API
7. User API
8. Access Key API
9. Admin API

## Admin Object Lifecycle Rule API

### GET /api/admin/object-lifecycle/rules

List object lifecycle rules. `ADMIN` required.

Response:

```json
{
  "data": [
    {
      "ruleId": "b4c5...",
      "name": "raw-video-version-retention",
      "enabled": true,
      "priority": 100,
      "bucketName": "",
      "targetType": "OBJECT_VERSION",
      "prefix": "videos/raw/",
      "tags": {
        "stage": "raw"
      },
      "retentionDays": 30,
      "batchSize": 100,
      "createdAt": "2026-06-13T11:45:00Z",
      "updatedAt": "2026-06-13T11:45:00Z"
    }
  ]
}
```

### GET /api/admin/object-lifecycle/conflicts

Analyze enabled lifecycle rules for overlapping scopes. `ADMIN` required.

Overlap rules:

- Same `targetType`.
- Bucket scopes overlap. Empty `bucketName` means global and overlaps any bucket. Different non-empty bucket names do not conflict.
- Prefix scopes overlap, meaning one prefix starts with the other.
- Tag filters are compatible, meaning shared tag keys do not require different values.

Response:

```json
{
  "data": {
    "ruleCount": 2,
    "conflictCount": 1,
    "conflicts": [
      {
        "conflictType": "OVERLAPPING_SCOPE",
        "severity": "WARNING",
        "targetType": "OBJECT_VERSION",
        "firstRule": {
          "ruleId": "rule-a",
          "name": "All raw videos",
          "priority": 10
        },
        "secondRule": {
          "ruleId": "rule-b",
          "name": "Raw stage videos",
          "priority": 20
        },
        "reason": "Earlier priority rule can purge shared candidates before later rule."
      }
    ]
  }
}
```

### GET /api/admin/object-lifecycle/s3-xml

Export lifecycle rules as an AWS S3 LifecycleConfiguration-compatible XML subset. `ADMIN` required.

Mapping:

- `OBJECT_VERSION` -> `NoncurrentVersionExpiration/NoncurrentDays`
- `TRASH_OBJECT` -> `Expiration/Days`
- `prefix` and `tags` -> `Filter` with `Prefix`, `Tag`, or `And`
- `priority`, `batchSize`, and `bucketName` are OSMU-only fields and are not represented in S3 XML.
- Admin export includes all lifecycle rules. Use bucket lifecycle API for bucket-scoped XML.

### POST /api/admin/object-lifecycle/s3-xml

Import AWS S3 LifecycleConfiguration XML subset. `ADMIN` required. Imported rules get generated rule ids, priority based on XML order (`10`, `20`, ...), and batch size `100`.

Request:

```json
{
  "xml": "<LifecycleConfiguration>...</LifecycleConfiguration>"
}
```

Response:

```json
{
  "data": {
    "importedCount": 2,
    "rules": []
  }
}
```

### POST /api/admin/object-lifecycle/rules

Create or update a prefix/tag scoped lifecycle rule. `ADMIN` required.

Request:

```json
{
  "ruleId": "",
  "name": "raw-video-version-retention",
  "enabled": true,
  "priority": 100,
  "bucketName": "",
  "targetType": "OBJECT_VERSION",
  "prefix": "videos/raw/",
  "tags": "stage=raw,project=osmu",
  "retentionDays": 30,
  "batchSize": 100
}
```

Rules:

- `targetType` must be `OBJECT_VERSION` or `TRASH_OBJECT`.
- `priority` range: 1..10000. Lower number runs first. Default 100.
- `bucketName` is optional. Empty means global rule; non-empty value scopes the rule to one bucket and must reference an existing bucket.
- `prefix` is optional and matches object keys by starts-with.
- `tags` is optional comma-separated `key=value`; all pairs must match.
- `retentionDays` range: 1..3650.
- `batchSize` range: 1..10000.
- Success writes `OBJECT_LIFECYCLE_RULE_SAVE` audit log.

### DELETE /api/admin/object-lifecycle/rules/{ruleId}

Delete one lifecycle rule. `ADMIN` required. Success returns `204 No Content` and writes `OBJECT_LIFECYCLE_RULE_DELETE` audit log.

### GET /api/admin/object-lifecycle/rules/{ruleId}/dry-run

Preview objects or object versions that would be purged by one lifecycle rule. `ADMIN` required. No data is deleted.

Query:

- `limit`: preview candidate count, 1..500, default 50.

Response:

```json
{
  "data": {
    "rule": {
      "ruleId": "b4c5...",
      "name": "raw-video-version-retention",
      "priority": 100,
      "targetType": "OBJECT_VERSION",
      "prefix": "videos/raw/",
      "tags": {
        "stage": "raw"
      },
      "retentionDays": 30,
      "batchSize": 100
    },
    "cutoff": "2026-05-14T11:45:00Z",
    "previewLimit": 50,
    "purgeBatchSize": 100,
    "candidateCount": 1,
    "candidateBytes": 734003200,
    "truncated": false,
    "candidates": [
      {
        "targetId": "media/videos/raw/input.mp4#v1",
        "bucketName": "media",
        "objectKey": "videos/raw/input.mp4",
        "versionId": "v1",
        "sizeBytes": 734003200,
        "matchedAt": "2026-05-01T10:00:00Z"
      }
    ]
  }
}
```

