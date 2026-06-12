# OSMU API Specification

이 문서는 OSMU MVP REST API 명세 초안이다.

S3 호환 API는 MinIO가 제공한다. 이 문서는 OSMU Backend가 제공하는 관리용 REST API를 정의한다.

## 1. 공통 규칙

### 1.1 Base URL

```text
/api
```

### 1.2 인증

MVP 최종 기준:

```http
Authorization: Bearer <accessToken>
```

초기 PoC에서는 Health, Storage Health, Bucket/Object API를 인증 없이 먼저 구현할 수 있다. 단, 코드 구조는 인증 추가를 전제로 둔다.

### 1.3 성공 응답

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
    "message": "Human readable message."
  }
}
```

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
    "engine": "minio"
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

응답:

```json
{
  "data": {
    "success": true
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

Query:

- `keyword`
- `status`
- `limit`
- `cursor`

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

## 5. Organization API

### GET /api/admin/organizations

조직 목록 조회.

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
  "quotaBytes": 1099511627776
}
```

응답:

```json
{
  "data": {
    "id": 1,
    "name": "project-data"
  }
}
```

### GET /api/buckets/{bucketName}

버킷 상세 조회.

### DELETE /api/buckets/{bucketName}

버킷 삭제.

정책:

- MVP에서는 빈 버킷만 삭제 가능.
- 삭제 성공/실패 모두 감사 로그 대상.

## 7. Object API

### GET /api/buckets/{bucketName}/objects

오브젝트 목록 조회.

Query:

- `prefix`
- `limit`
- `cursor`

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
  "nextCursor": null
}
```

### POST /api/buckets/{bucketName}/objects

파일 업로드.

Form Data:

- `key`
- `file`

정책:

- 업로드 전 권한 확인.
- 업로드 전 quota 확인.
- 대용량 파일은 multipart upload 또는 presigned URL로 확장.

### GET /api/buckets/{bucketName}/objects/{objectKey}

파일 다운로드.

정책:

- MVP는 stream download 또는 presigned URL 중 하나로 시작.
- 대용량 파일은 presigned URL 우선.

### DELETE /api/buckets/{bucketName}/objects/{objectKey}

파일 삭제.

## 8. Access Key API

### GET /api/access-keys

내 Access Key 목록 조회.

### POST /api/access-keys

Access Key 생성.

요청:

```json
{
  "name": "local-dev-key",
  "expiresAt": null
}
```

응답:

```json
{
  "data": {
    "id": 1,
    "accessKey": "osmu-access-key",
    "secretKey": "secret-visible-once"
  }
}
```

정책:

- Secret Key는 생성 응답에서 1회만 노출.
- 서버에는 해시 또는 안전한 형태로 저장.

### DELETE /api/access-keys/{keyId}

Access Key 비활성화.

## 9. Admin API

### GET /api/admin/usage

전체 사용량 조회.

### GET /api/admin/audit-logs

감사 로그 조회.

Query:

- `eventType`
- `actorId`
- `from`
- `to`
- `limit`
- `cursor`

### GET /api/admin/system/status

시스템 상태 조회.

응답:

```json
{
  "data": {
    "backend": "UP",
    "database": "UP",
    "storage": "UP"
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

