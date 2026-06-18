# S3 Compatibility Matrix

이 문서는 현재 OSMU S3-compatible API의 지원 범위와 명시적 미지원 범위를 한 곳에 고정한다. 제품 설명, 테스트 계획, real client smoke는 이 문서를 기준으로 맞춘다.

## Compatibility Level

| Area | Status | Notes | Automated evidence |
| --- | --- | --- | --- |
| Path-style endpoint | Supported | `/api/s3/{bucketName}` and root `/{bucketName}` mappings. | `S3ObjectControllerTest`, `S3BucketControllerTest`, `verify-s3-client-smoke.ps1` |
| Virtual-hosted-style endpoint | MVP supported | Configured suffix such as `{bucket}.localhost`; original URI is preserved for SigV4 canonical request. | `S3ObjectControllerTest`, `verify-s3-client-smoke.ps1` |
| Access key header auth | Supported | `X-OSMU-Access-Key` + `X-OSMU-Secret-Key`. | backend controller tests |
| S3 XML error envelope | MVP supported | Global `/api/s3/**` errors include `Code`, `Message`, `Resource`, `RequestId`, and `HostId`; MVP `HostId` mirrors the request id. | `S3ObjectControllerTest.missingS3MultipartUploadReturnsNoSuchUploadXml` |
| AWS SigV4 header auth | Supported | Canonical request, signed headers, clock skew, encrypted signing secret, bucket scope. | `S3ObjectControllerTest`, `S3BucketControllerTest` |
| AWS SigV4 presigned query auth | Supported | `X-Amz-*` parameters and expiry validation. | `S3ObjectControllerTest` |
| Non-streaming payload hash | Supported | Signed `x-amz-content-sha256` is validated against object and multipart-part request bodies. | `S3ObjectControllerTest`, `S3ObjectControllerMultipartTest` |
| `UNSIGNED-PAYLOAD` | Supported | Accepted without body hash validation, matching common S3 client behavior. | `S3ObjectControllerTest` |
| `aws-chunked` body decoding | MVP supported | Decodes AWS chunked transfer bodies and stores the decoded object. Requires `x-amz-decoded-content-length`, rejects decoded length mismatch, and requires 64-character lowercase hex `chunk-signature` on `STREAMING-AWS4-HMAC-SHA256-PAYLOAD` chunks. | `S3ObjectControllerTest.accessKeyCanUploadAwsChunkedStreamingPayload` |
| Chunk signature chain | Supported for header auth | SigV4 header-auth `STREAMING-AWS4-HMAC-SHA256-PAYLOAD` chunks are cryptographically chained from the Authorization seed signature. Presigned streaming and trailer-signature parity are not in scope yet. | `S3ObjectControllerTest.awsSigV4HeaderAuthVerifiesAwsChunkedStreamingSignatureChain` |
| Trailer checksum | MVP supported | `x-amz-trailer` supports one trailing SHA256, SHA1, CRC32, CRC32C, or CRC64NVME checksum on aws-chunked uploads. | `S3ObjectControllerTest.accessKeyCanUploadAwsChunkedStreamingPayload` |

## Bucket API

| Operation | Status | Notes |
| --- | --- | --- |
| `PUT Bucket` | MVP supported | Reuses `BucketService.create`; Bearer JWT path is the primary create path. AWS general-purpose bucket name rules return `InvalidBucketName`; optional `CreateBucketConfiguration/LocationConstraint` XML is accepted when it matches the configured storage region. Malformed XML, unexpected root XML, duplicate `LocationConstraint` elements, unsupported ACL/grant headers, object lock enabled, non-default object ownership, and account-regional bucket namespace return `InvalidRequest` without creating the bucket. Safe no-op defaults (`x-amz-acl: private`, object lock false, `BucketOwnerEnforced`, `global`) are accepted. Duplicate creates return `BucketAlreadyOwnedByYou` or `BucketAlreadyExists`. |
| `HEAD Bucket` | Supported | Auth/readiness probe. |
| `GET Bucket location` | Supported | Region-compatible response. |
| `DELETE Bucket` | MVP supported | Requires empty bucket and `ADMIN` scope. Invalid names return `InvalidBucketName`; active objects or retained object versions return S3 XML `BucketNotEmpty`; other exact AWS error parity is not guaranteed. |
| `GET/PUT/DELETE Bucket tagging` | Supported | S3 XML `Tagging/TagSet` subset with XXE-safe parser. |
| `GET/PUT/DELETE Bucket lifecycle` | MVP supported | S3 XML lifecycle subset mapped to OSMU lifecycle rules. |
| Bucket policy, ACL, public access block, object lock | Not supported | OSMU uses internal RBAC, Access Key scopes, retention/lifecycle policy, and admin console instead. |

## Object API

| Operation | Status | Notes |
| --- | --- | --- |
| `PUT Object` | Supported | Tags, content type, user metadata, ETag, checksum headers, destination `If-Match`/`If-None-Match` overwrite guards, quota, version snapshot on overwrite. |
| `HEAD Object` | Supported | ETag, checksum headers, content metadata, user metadata, conditional headers. |
| `GET Object` | Supported | Single range request with `If-Range`, ETag/checksum/user-metadata headers, conditional headers, and AWS-documented combined conditional precedence. Multi-range is rejected because AWS S3 does not support multiple ranges per GET. |
| `DELETE Object` | Supported | OSMU soft-delete semantics; purge is handled by REST/admin lifecycle paths. |
| `CopyObject` | MVP supported | Source object copy, OSMU-retained source `versionId`, content type/user-metadata/tag directives, stored checksum copy, `x-amz-checksum-algorithm` recalculation for supported algorithms, source preconditions with AWS-documented ETag/date precedence, and destination `If-Match`/`If-None-Match` guards. Full AWS versioning parity and remaining conditional edge parity are not implemented. |
| Object tagging | Supported | S3 XML tag subset backed by OSMU object tags. |
| ListObjects V1/V2 | Supported | Prefix, delimiter, marker/continuation token, max keys, URL encoding, owner field. |
| Multi-object delete | MVP supported | Uses soft-delete; quiet mode and per-key errors supported. |
| Multipart initiate/upload/list/complete/abort | MVP supported | S3 initiate accepts AWS-style unknown-size sessions when the OSMU expected-size header is omitted; these sessions have no precomputed part URL/byte plan and quota is checked on complete using actual completed object size. Initiate validates, persists, and echoes supported `x-amz-checksum-algorithm`/`x-amz-checksum-type` checksum negotiation headers, rejects unsupported ACL/grant/Object Lock/SSE/non-standard storage class/website redirect/requester-pays controls, and accepts safe no-op `private` ACL plus `STANDARD` storage class. Missing uploads return `NoSuchUpload`. ListParts supports `max-parts`/`part-number-marker` pagination. Complete XML validates destination `If-Match`/`If-None-Match`, non-empty ascending unique part numbers, 1~10000 range, required ETag, stored initiate checksum algorithm/type match, uploaded part existence, ETag match, and optional `x-amz-mp-object-size` actual-size match before metadata commit. MinIO-backed complete preserves the AWS-style multipart ETag (`md5-of-part-md5s-partCount`) and smoke scripts verify it in complete response XML/header and later `HEAD`. |

## Checksum Support

| Checksum | Status | Notes |
| --- | --- | --- |
| `Content-MD5` | Supported | Validates request body and maps failures to S3 XML digest errors. |
| `x-amz-checksum-sha256` | Supported | PUT header/trailer, multipart part header/trailer, final object metadata/header/XML. |
| `x-amz-checksum-sha1` | Supported | PUT header/trailer, multipart part header/trailer, final object metadata/header/XML. |
| `x-amz-checksum-crc32` | Supported | PUT header/trailer, multipart part header/trailer, final object metadata/header/XML. |
| `x-amz-checksum-crc32c` | Supported | PUT header/trailer, multipart part header/trailer, final object metadata/header/XML. |
| `x-amz-checksum-crc64nvme` | Supported | PUT header/trailer, multipart part header/trailer, final object metadata/header/XML. |
| CopyObject `x-amz-checksum-algorithm` | MVP supported | Recalculates target checksum metadata/XML/header for `SHA256`, `SHA1`, `CRC32`, `CRC32C`, and `CRC64NVME`; unsupported algorithm names return `InvalidRequest`. |
| Multipart checksum aggregation parity | Partial | Initiate validates, stores, and echoes supported checksum algorithm/type negotiation headers. Final object checksum can be supplied and validated. SHA1/SHA256 and CRC32/CRC32C composite checksums are derived from ordered per-part checksum bytes when every completed part supplies the same algorithm. `x-amz-checksum-type` accepts `FULL_OBJECT` for final checksum headers and `COMPOSITE` for supported SHA1/SHA256/CRC32/CRC32C per-part composites. Complete returns `BadDigest` before storage completion when stored initiate algorithm/type conflicts with final or per-part checksum shape. CRC64NVME is full-object only. UploadPart auto checksum persistence and exact AWS response propagation are not fully reproduced. |

## Client Matrix

| Client | Current target | Required settings | Notes |
| --- | --- | --- | --- |
| AWS CLI | Supported smoke target | `--endpoint-url`, path-style when needed, OSMU Access Key | Host CLI smoke remains optional when CLI is absent. |
| MinIO Client `mc` | Supported smoke target | Alias to OSMU endpoint and OSMU Access Key | Dockerized `mc` is the strongest current local evidence. |
| boto3 | Supported config target | endpoint URL, region, SigV4, path-style | Matrix/snippet exposed in developer console. |
| AWS SDK JavaScript/Java | Supported config target | endpoint URL, region, SigV4, path-style | Matrix/snippet exposed in developer console. |
| s3cmd | Supported config target | endpoint URL, access/secret key, path-style | Real smoke may depend on local client availability. |
| s3fs/goofys | Partial target | endpoint URL, path-style, credentials | Mount behavior is not part of default local gate yet. |

## Verification Rule

- Backend unit/controller tests prove API contract behavior.
- `scripts/verify-s3-client-smoke.ps1` proves built-in SigV4 and optional host/Docker real-client smoke.
- `scripts/verify-docker-integration.ps1` is stronger because it exercises MariaDB + MinIO + backend container networking.
- Any newly claimed S3 operation must update this matrix, `api-spec.md`, `test-cases.md`, and at least one automated backend or smoke test.
