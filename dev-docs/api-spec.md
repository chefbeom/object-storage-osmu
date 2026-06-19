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

관리자 API인 `/api/admin/**`는 기본적으로 `ADMIN` role이 필요하다.
예외적으로 `ORG_ADMIN`은 조직 스코프가 적용된 사용자/조직 조회 API만 접근할 수 있다.
현재 허용 route는 `GET/POST /api/admin/users`, `PATCH /api/admin/users/{userId}/status`, `GET /api/admin/organizations`, `GET /api/admin/organizations/usage`이다.

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

## 4. Developer API

### GET /api/developer/s3-client-config

로그인한 사용자가 S3 호환 클라이언트를 설정할 때 필요한 공개 접속 정보를 조회한다. Secret Key나 내부 MinIO credential은 반환하지 않는다.

응답:

```json
{
  "data": {
    "endpoint": "https://storage.example.com/api/s3",
    "region": "ap-northeast-2",
    "signatureVersion": "AWS4-HMAC-SHA256",
    "service": "s3",
    "pathStyleSupported": true,
    "virtualHostedStyleEnabled": true,
    "virtualHostedStyleDomainSuffixes": ["storage.example.com", "localhost"]
  }
}
```

비고:

- `endpoint`는 `OSMU_S3_PUBLIC_ENDPOINT`가 설정되면 해당 값을 사용한다.
- 설정이 없으면 현재 요청 URL 기준으로 `/api/s3` endpoint를 계산한다.
- `region`은 `OSMU_S3_REGION`을 사용하며 기본값은 `us-east-1`이다.

- DeveloperPage uses this response to generate AWS CLI, s3fs-fuse, goofys, AWS SDK JavaScript, boto3 Python, and AWS SDK Java examples without embedding secrets. It also renders a real S3 client compatibility matrix for AWS CLI, MinIO Client, boto3, AWS SDK JavaScript, AWS SDK Java, s3fs-fuse/goofys, and s3cmd using endpoint, region, signature, path-style, and virtual-hosted-style settings.

## 5. Dashboard API

### GET /api/dashboard/layout

현재 로그인 사용자의 대시보드 패널 구성을 조회한다. `scope`를 생략하면 `main`을 사용한다.

Query:

| 이름 | 필수 | 설명 |
| --- | --- | --- |
| `scope` | N | layout scope. 기본값 `main` |

응답:

```json
{
  "data": {
    "scope": "main",
    "source": "SAVED",
    "schemaVersion": "osmu.dashboard-layout.v1",
    "updatedAt": "2026-06-15T01:55:00Z",
    "widgets": [
      { "id": "capacity", "enabled": true, "size": "wide", "section": "overview", "options": { "tone": "focus" } },
      { "id": "readiness", "enabled": true, "size": "normal", "section": "operations", "options": { "tone": "default" } }
    ],
    "sections": [
      { "id": "overview", "collapsed": false },
      { "id": "operations", "collapsed": true },
      { "id": "governance", "collapsed": false }
    ]
  }
}
```

저장된 구성이 없으면 `source`는 `DEFAULT`, `widgets`는 빈 배열이다. Frontend는 이 경우 기본 catalog 구성을 적용한다.

저장 시 widget id는 서버 catalog에 등록되어 있고 현재 role이 사용할 수 있는 id만 허용한다. `adminOnly=true` widget을 `USER` 또는 `ORG_ADMIN`이 직접 저장 요청에 넣으면 `403 AUTHORIZATION_FAILED`를 반환한다.

### GET /api/dashboard/layout/widgets

현재 로그인 사용자가 조회할 수 있는 dashboard widget catalog metadata를 조회한다. Frontend는 이 응답을 기준으로 palette 추가/숨김/삭제/크기 변경 UI를 구성하고, 서버 응답이 없을 때만 내장 fallback catalog를 사용한다.

응답:

```json
{
  "data": [
    {
      "id": "access-keys",
      "title": "Access Key 운영",
      "description": "Active S3-compatible access key inventory and provisioner state.",
      "category": "SECURITY",
      "adminOnly": false,
      "allowedRoles": ["ADMIN", "ORG_ADMIN", "USER"],
      "accessMode": "read-only",
      "configOptions": [
        {
          "key": "tone",
          "label": "Tone",
          "type": "select",
          "values": ["default", "focus", "muted"],
          "defaultValue": "default"
        },
        {
          "key": "refreshInterval",
          "label": "Refresh",
          "type": "select",
          "values": ["manual", "30s", "60s", "5m", "15m"],
          "defaultValue": "manual"
        }
      ]
    },
    {
      "id": "identity",
      "title": "사용자/조직 현황",
      "description": "User and organization inventory for operators.",
      "category": "IDENTITY",
      "adminOnly": true,
      "allowedRoles": ["ADMIN"],
      "accessMode": "admin-only",
      "configOptions": [
        {
          "key": "tone",
          "label": "Tone",
          "type": "select",
          "values": ["default", "focus", "muted"],
          "defaultValue": "default"
        },
        {
          "key": "refreshInterval",
          "label": "Refresh",
          "type": "select",
          "values": ["manual", "30s", "60s", "5m", "15m"],
          "defaultValue": "manual"
        }
      ]
    }
  ]
}
```

현재 dashboard widget catalog id는 `capacity`, `remaining`, `buckets`, `objects`, `health`, `runtime`, `readiness`, `backup`, `io`, `requests`, `sharing`, `quota`, `access-keys`, `identity`, `lifecycle`, `selected`, `retention`, `execution-retention`, `storage-expansion`이다.
현재 widget option schema는 `tone`(`default`, `focus`, `muted`)과 `refreshInterval`(`manual`, `30s`, `60s`, `5m`, `15m`)을 제공한다.
`allowedRoles`는 panel별 허용 role matrix를 나타내고 `accessMode=read-only` panel은 dashboard에서 요약 조회 중심으로 표시한다. `accessMode=admin-only` panel은 `ADMIN`에게만 노출된다.
`ADMIN`은 전체 catalog를 받는다. `USER`와 `ORG_ADMIN`은 `adminOnly=true` widget을 응답에서 받지 않으며, 저장된 layout이나 preset에 해당 widget이 남아 있어도 조회/적용 응답에서 제거된다.

### GET /api/dashboard/layout/presets

Built-in preset ids: `operations`, `compact`, `admin`, `operator`, `executive`, `storage-ops`, `security-audit`.

현재 로그인 사용자가 적용할 수 있는 내장 대시보드 layout preset 목록을 조회한다. 응답의 `widgets`는 현재 role 기준으로 필터링된다.

응답:

```json
{
  "data": [
    {
      "id": "operations",
      "name": "Operations",
      "description": "General storage operations view with capacity, health, activity, sharing, quota, and selected workspace.",
      "schemaVersion": "osmu.dashboard-layout.v1",
      "custom": false,
      "widgets": [
        { "id": "capacity", "enabled": true, "size": "wide" },
        { "id": "readiness", "enabled": true, "size": "wide" }
      ],
      "sections": [
        { "id": "overview", "collapsed": false },
        { "id": "operations", "collapsed": false },
        { "id": "governance", "collapsed": false }
      ]
    }
  ]
}
```

ADMIN은 custom preset을 생성할 수 있고, 모든 로그인 사용자는 built-in/custom preset을 조회/적용할 수 있다.

### GET /api/dashboard/layout/defaults

ROLE 또는 ORGANIZATION 기준으로 지정된 dashboard 기본 preset 목록을 조회한다. ADMIN 전용.

응답:

```json
{
  "data": [
    {
      "targetType": "ROLE",
      "targetId": "ADMIN",
      "presetId": "compact",
      "presetName": "Compact",
      "presetCustom": false,
      "updatedAt": "2026-06-15T03:30:00Z"
    }
  ]
}
```

### PUT /api/dashboard/layout/defaults

특정 ROLE 또는 ORGANIZATION에 dashboard 기본 preset을 지정한다. ADMIN 전용.
사용자가 저장한 개인 dashboard layout이 없으면 `GET /api/dashboard/layout` 응답의 `source`가 `DEFAULT_PRESET`으로 내려가며, 조직 기본값이 역할 기본값보다 우선한다.

요청:

```json
{
  "targetType": "ROLE",
  "targetId": "USER",
  "presetId": "operations"
}
```

검증:

- `targetType`은 `ROLE`, `ORGANIZATION`만 허용한다.
- `ROLE` target은 `ADMIN`, `ORG_ADMIN`, `USER`만 허용한다.
- `presetId`는 built-in 또는 custom preset 중 존재해야 한다.
- 개인 저장 layout이 있으면 개인 layout이 기본 preset보다 우선한다.

### DELETE /api/dashboard/layout/defaults/{targetType}/{targetId}

ROLE 또는 ORGANIZATION 기준 dashboard 기본 preset 지정을 삭제한다. ADMIN 전용.

응답:

```http
204 No Content
```

### POST /api/dashboard/layout/presets

현재 dashboard widget 구성을 재사용 가능한 custom preset으로 저장한다. ADMIN 전용.

요청:

```json
{
  "schemaVersion": "osmu.dashboard-layout.v1",
  "name": "Executive Console",
  "description": "Board room dashboard layout",
  "widgets": [
    { "id": "capacity", "enabled": true, "size": "wide" },
    { "id": "sharing", "enabled": true, "size": "normal" }
  ],
  "sections": [
    { "id": "governance", "collapsed": true }
  ]
}
```

응답:

```json
{
  "data": {
    "id": "custom-executive-console",
    "name": "Executive Console",
    "description": "Board room dashboard layout",
    "schemaVersion": "osmu.dashboard-layout.v1",
    "custom": true,
    "widgets": [
      { "id": "capacity", "enabled": true, "size": "wide" },
      { "id": "sharing", "enabled": true, "size": "normal" }
    ],
    "sections": [
      { "id": "overview", "collapsed": false },
      { "id": "operations", "collapsed": false },
      { "id": "governance", "collapsed": true }
    ]
  }
}
```

### PUT /api/dashboard/layout

현재 로그인 사용자의 대시보드 패널 구성을 저장한다.

요청:

```json
{
  "schemaVersion": "osmu.dashboard-layout.v1",
  "widgets": [
    { "id": "capacity", "enabled": true, "size": "wide", "section": "overview", "options": { "tone": "focus" } },
    { "id": "remaining", "enabled": false, "size": "compact", "section": "operations" }
  ],
  "sections": [
    { "id": "overview", "collapsed": false },
    { "id": "operations", "collapsed": true },
    { "id": "governance", "collapsed": false }
  ]
}
```

검증:

- widget은 최대 30개다.
- widget id는 중복될 수 없다.
- widget id는 영문 소문자로 시작하고 영문 소문자, 숫자, `-`만 사용할 수 있다.
- widget size는 `compact`, `normal`, `wide` 중 하나다. 생략하면 `normal`이다.
- widget section은 `overview`, `operations`, `governance` 중 하나다. 생략하면 `overview`다.
- widget options는 현재 `tone`만 허용하고 값은 `default`, `focus`, `muted` 중 하나다. 생략하면 `default`다.

응답은 `GET /api/dashboard/layout`과 같다.

Section layout:

- `sections[].id`: `overview`, `operations`, `governance`
- `sections[].collapsed`: boolean
- `schemaVersion`: 현재 `osmu.dashboard-layout.v1`만 허용한다. 생략 시 v1로 보정된다.
- 누락된 section은 `collapsed: false`로 보정된다.

### PUT /api/dashboard/layout/presets/{presetId}

현재 로그인 사용자의 대시보드 layout을 지정한 preset으로 저장한다. `scope`를 생략하면 `main`을 사용한다.

Path:

| 이름 | 필수 | 설명 |
| --- | --- | --- |
| `presetId` | Y | 내장 preset id. 현재 `operations`, `compact`, `admin`, `operator`, `executive`, `storage-ops`, `security-audit` 지원 |

Query:

| 이름 | 필수 | 설명 |
| --- | --- | --- |
| `scope` | N | layout scope. 기본값 `main` |

응답은 `GET /api/dashboard/layout`과 같다.

### PATCH /api/dashboard/layout/presets/{presetId}

custom dashboard layout preset을 현재 요청 본문으로 갱신한다. ADMIN 전용. Built-in preset은 갱신할 수 없다.

요청:

```json
{
  "schemaVersion": "osmu.dashboard-layout.v1",
  "name": "Executive Console Updated",
  "description": "Updated board room dashboard layout",
  "widgets": [
    { "id": "capacity", "enabled": true, "size": "wide" },
    { "id": "quota", "enabled": true, "size": "compact" }
  ],
  "sections": [
    { "id": "operations", "collapsed": true }
  ]
}
```

응답은 `POST /api/dashboard/layout/presets`와 같다.

### GET /api/dashboard/layout/presets/{presetId}/export

dashboard layout preset을 다른 환경으로 옮길 수 있는 JSON payload로 내보낸다. 로그인 사용자 접근 가능.

응답:

```json
{
  "data": {
    "formatVersion": "osmu.dashboard-preset.v1",
    "exportedAt": "2026-06-15T03:10:00Z",
    "preset": {
      "id": "custom-executive-console",
      "name": "Executive Console Updated",
      "description": "Updated board room dashboard layout",
      "schemaVersion": "osmu.dashboard-layout.v1",
      "custom": true,
      "widgets": [
        { "id": "capacity", "enabled": true, "size": "wide" },
        { "id": "quota", "enabled": true, "size": "compact" }
      ],
      "sections": [
        { "id": "overview", "collapsed": false },
        { "id": "operations", "collapsed": true },
        { "id": "governance", "collapsed": false }
      ]
    }
  }
}
```

### POST /api/dashboard/layout/presets/import

export된 dashboard layout preset JSON을 custom preset으로 가져온다. ADMIN 전용. 가져온 preset은 새 custom id로 저장된다.

요청:

```json
{
  "formatVersion": "osmu.dashboard-preset.v1",
  "preset": {
    "name": "Imported Executive Console",
    "description": "Imported dashboard layout",
    "schemaVersion": "osmu.dashboard-layout.v1",
    "widgets": [
      { "id": "readiness", "enabled": true, "size": "wide" },
      { "id": "backup", "enabled": true, "size": "normal" }
    ],
    "sections": [
      { "id": "overview", "collapsed": true }
    ]
  }
}
```

응답은 `POST /api/dashboard/layout/presets`와 같다.

### GET /api/dashboard/layout/preset-bundle/export

ADMIN custom dashboard layout preset 전체를 고객사/환경 간 이동 가능한 bundle JSON으로 내보낸다. Built-in preset은 대상 환경에도 기본 제공되므로 bundle에서 제외한다. ADMIN 전용.

응답:

```json
{
  "data": {
    "formatVersion": "osmu.dashboard-preset-bundle.v1",
    "exportedAt": "2026-06-15T03:20:00Z",
    "presets": [
      {
        "id": "custom-executive-console",
        "name": "Executive Console Updated",
        "description": "Updated board room dashboard layout",
        "schemaVersion": "osmu.dashboard-layout.v1",
        "custom": true,
        "widgets": [
          { "id": "capacity", "enabled": true, "size": "wide" }
        ],
        "sections": [
          { "id": "overview", "collapsed": false },
          { "id": "operations", "collapsed": false },
          { "id": "governance", "collapsed": true }
        ]
      }
    ]
  }
}
```

### POST /api/dashboard/layout/preset-bundle/import

`osmu.dashboard-preset-bundle.v1` bundle을 custom preset 여러 개로 가져온다. ADMIN 전용. 가져온 preset은 각각 새 custom id로 저장된다.

요청:

```json
{
  "formatVersion": "osmu.dashboard-preset-bundle.v1",
  "presets": [
    {
      "name": "Executive Console",
      "description": "Customer dashboard layout",
      "schemaVersion": "osmu.dashboard-layout.v1",
      "widgets": [
        { "id": "capacity", "enabled": true, "size": "wide" }
      ],
      "sections": [
        { "id": "governance", "collapsed": true }
      ]
    }
  ]
}
```

응답:

```json
{
  "data": {
    "importedCount": 1,
    "presets": [
      {
        "id": "custom-executive-console",
        "name": "Executive Console",
        "description": "Customer dashboard layout",
        "schemaVersion": "osmu.dashboard-layout.v1",
        "custom": true,
        "widgets": [
          { "id": "capacity", "enabled": true, "size": "wide" }
        ],
        "sections": [
          { "id": "overview", "collapsed": false },
          { "id": "operations", "collapsed": false },
          { "id": "governance", "collapsed": true }
        ]
      }
    ]
  }
}
```

### DELETE /api/dashboard/layout/presets/{presetId}

custom dashboard layout preset을 삭제한다. ADMIN 전용. Built-in preset은 삭제할 수 없다.

응답:

```http
204 No Content
```

### DELETE /api/dashboard/layout

현재 로그인 사용자의 저장된 대시보드 패널 구성을 삭제하고 기본 구성으로 되돌린다.

응답:

```http
204 No Content
```

## 6. User API

### GET /api/admin/users

사용자 목록 조회. `ADMIN` 또는 `ORG_ADMIN` 권한 필요.

정책:

- `ADMIN`은 전체 사용자를 조회한다.
- `ORG_ADMIN`은 본인 조직 사용자만 조회한다.

목표 Query:

- `keyword`: case-insensitive partial match against `loginId`, `email`, or `name`.
- `status`: exact status filter, case-insensitive. Example: `ACTIVE`, `INACTIVE`.
- `limit`: page size from `1` to `200`. Default `200`.
- `cursor`: previous `nextCursor`; uses descending user id pagination.

Response is newest-first by user id and includes `nextCursor` when another page exists.

### POST /api/admin/users

사용자 생성. `ADMIN` 또는 `ORG_ADMIN` 권한 필요.

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

정책:

- `ADMIN`은 `ADMIN`, `ORG_ADMIN`, `USER`를 생성할 수 있다.
- `ORG_ADMIN`은 본인 조직의 일반 `USER`만 생성할 수 있다.
- `ORG_ADMIN`이 `organizationId`를 생략하면 본인 조직으로 자동 지정된다.
- `ORG_ADMIN`이 다른 조직 또는 관리자 role을 지정하면 `403 AUTHORIZATION_FAILED`를 반환한다.

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
- 기존 access token은 매 요청마다 DB 사용자 상태를 재확인하므로 `INACTIVE` 또는 `LOCKED` 변경 직후 `401 AUTHENTICATION_REQUIRED`로 차단된다.
- `INACTIVE` or `LOCKED` also revokes active refresh tokens for that user.

## 7. Organization API

### GET /api/admin/organizations

조직 목록 조회. `ADMIN` 또는 `ORG_ADMIN` 권한 필요.

정책:

- `ADMIN`은 전체 조직을 조회한다.
- `ORG_ADMIN`은 본인 조직만 조회한다.

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
- Removes any `ORGANIZATION:{organizationId}` dashboard default preset assignment with the organization.
- Removes any `ORGANIZATION:{organizationId}` quota policy with the organization and records quota policy `DELETE` history.
- Removes any bucket permissions whose subject is `ORGANIZATION:{organizationId}`.
- Records `ORGANIZATION_DELETE` audit event on success.

### GET /api/admin/organizations/usage

조직별 bucket usage 집계. `ADMIN` 또는 `ORG_ADMIN` 권한 필요.

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
- `ADMIN`은 전체 조직 usage를 조회한다.
- `ORG_ADMIN`은 본인 조직 usage만 조회한다.
- `usedBytes`, `objectCount`, `bucketQuotaBytes`는 bucket metadata 기준이다.
- S3 직접 업로드 이후 값이 어긋난 경우 bucket sync API로 보정한다.
- 조직 quota 차단은 Backend upload와 presigned upload complete 경로에서 적용한다.
- 조직 quota 차단은 Backend upload와 presigned upload complete 경로에서 적용한다.

## 8. Bucket API

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
    "objectCount": 12,
    "previousUsedBytes": 524288,
    "previousObjectCount": 10,
    "storageObjectCount": 14,
    "visibleStorageObjectCount": 12,
    "internalStorageObjectCount": 2,
    "stagingStorageObjectCount": 0,
    "metadataObjectCountBefore": 11,
    "metadataObjectCountAfter": 12,
    "metadataAddedCount": 2,
    "metadataUpdatedCount": 1,
    "metadataRemovedCount": 1,
    "deletedObjectMetadataRetainedCount": 0
  }
}
```

정책:

- MVP에서는 빈 버킷만 삭제 가능.
- 삭제 성공/실패 모두 감사 로그 대상.
- S3 직접 접근으로 생긴 metadata drift는 sync API로 보정한다.
- 응답은 기존 bucket 필드와 함께 storage scan, metadata add/update/remove, 내부 object, staging object count를 반환해 어떤 drift가 보정됐는지 운영자가 확인할 수 있게 한다.
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

### GET /api/storage-profiles

Returns the built-in bucket Storage Profile catalog. Logged-in users can call it.

Response:

```json
{
  "items": [
    {
      "code": "PERFORMANCE",
      "name": "Performance",
      "alias": "RAID0-like",
      "strategy": "Speed first, shard across performance pool",
      "riskLevel": "HIGH",
      "minioStorageClassHint": "PERFORMANCE",
      "parityHint": "Lowest allowed parity or dedicated low-parity pool",
      "poolSelector": "osmu.storage-profile=performance",
      "description": "Large sequential writes, temp media, render cache.",
      "useCase": "Video ingest, temporary processing, cache buckets"
    }
  ]
}
```

### GET /api/storage-profile-requests

Returns Storage Profile requests visible to the current user. `ADMIN` receives all requests. Normal users receive requests for buckets they can access.

### GET /api/buckets/{bucketName}/storage-profile

Returns the active Storage Profile assignment and latest request for one bucket. Bucket access permission is required. If no assignment exists, the active profile is returned as default `STANDARD`.

Response:

```json
{
  "data": {
    "bucketName": "media",
    "assignment": {
      "bucketName": "media",
      "profile": { "code": "STANDARD", "name": "Standard", "alias": "Erasure Coding" },
      "appliedBy": "system",
      "appliedAt": null,
      "updatedAt": null,
      "defaultProfile": true
    },
    "latestRequest": null
  }
}
```

### POST /api/buckets/{bucketName}/storage-profile-requests

Creates a bucket-level Storage Profile change request. Bucket management permission is required.

Request:

```json
{
  "requestedProfile": "PERFORMANCE",
  "reason": "video ingest needs RAID0-like throughput"
}
```

Validation:

- `requestedProfile` must be `PERFORMANCE`, `STANDARD`, or `DURABLE`.
- Requesting the currently active profile returns `400 VALIDATION_ERROR`.
- `PERFORMANCE` requires a non-empty reason.
- `reason` max length is 512 characters.

### GET /api/admin/storage-profile-requests

Returns all Storage Profile requests. `ADMIN` only.

### PATCH /api/admin/storage-profile-requests/{requestId}/status

Approves or rejects a Storage Profile request. `ADMIN` only.

Request:

```json
{
  "status": "APPROVED",
  "adminNote": "approved for temporary media pool"
}
```

Validation:

- `status` must be `APPROVED` or `REJECTED`.
- Status can change only from `PENDING`.
- `adminNote` max length is 512 characters.

### POST /api/admin/storage-profile-requests/{requestId}/apply

Applies an approved Storage Profile request to the target bucket. `ADMIN` only. On success, OSMU writes `bucket_storage_profile_assignments` and changes the request status to `APPLIED`.

Validation:

- Request status must be `APPROVED`.
- Target bucket must still exist.
- MVP applies metadata/control-plane assignment only. Live MinIO pool movement and object rewrite are follow-up runner work.

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
- Exported lifecycle XML emits each rule in AWS example-friendly child order: `ID`, `Filter`, `Status`, then the selected lifecycle action.
- Lifecycle XML can contain at most 1000 `Rule` elements, matching the S3 lifecycle configuration limit.
- `Rule/ID` is optional, but when present it must be at most 255 characters.
- XML root must be `LifecycleConfiguration`; `LifeCycleConfiguration` is accepted for compatibility with AWS example casing.
- `Rule/Status` is required and must be exactly `Enabled` or `Disabled`; missing or unsupported status values are rejected as invalid lifecycle XML.
- `Filter` may be empty or contain exactly one direct predicate. Supported direct predicates are `Prefix`, `Tag`, and `And`; multiple direct predicates or unknown predicate elements are rejected as invalid lifecycle XML.
- AWS object-size filter predicates (`ObjectSizeGreaterThan`, `ObjectSizeLessThan`) are recognized but not supported by the OSMU lifecycle subset and return `InvalidRequest`.
- Lifecycle tag filters use OSMU tag restrictions: up to 10 unique tag keys, key length 1~128, value length 1~256, key characters limited to letters, digits, `.`, `_`, `:`, `/`, `@`, `+`, and `-`, and values cannot contain control characters. Violations return `InvalidRequest`.
- Each rule must contain exactly one OSMU-supported lifecycle action: `Expiration/Days` or `NoncurrentVersionExpiration/NoncurrentDays`. AWS transition and abort-incomplete-multipart-upload actions, or a combination of multiple target actions in one rule, return `InvalidRequest`.
- Supported XML subset: `Rule`, `ID`, `Status`, `Filter/Prefix`, `Filter/Tag`, `Filter/And`, `Expiration/Days`, `NoncurrentVersionExpiration/NoncurrentDays`.
- Success writes `BUCKET_LIFECYCLE_PUT` audit log.

### DELETE /api/buckets/{bucketName}/lifecycle

해당 bucket에 연결된 lifecycle rule을 모두 삭제한다. bucket 관리 권한이 필요하다. Success returns `204 No Content` and writes `BUCKET_LIFECYCLE_DELETE` audit log.

### S3-style alias: /api/s3/{bucketName}?lifecycle

OSMU REST 인증을 사용하지만, path-style S3 lifecycle 문법에 가까운 raw XML alias를 제공한다. bucket 관리 권한이 필요하다.

- `GET /api/s3/{bucketName}?lifecycle` with `Accept: application/xml`; missing bucket lifecycle configuration returns S3 XML `NoSuchLifecycleConfiguration` with HTTP `404`
- `PUT /api/s3/{bucketName}?lifecycle` with `Content-Type: application/xml`; missing or blank XML returns S3 XML `MissingRequestBodyError`; unexpected lifecycle XML roots, invalid `Rule/Status` values, or invalid filter shapes return S3 XML `MalformedXML`; too many lifecycle rules, overlong `Rule/ID`, unsupported object-size filters, unsupported lifecycle actions, multiple target actions in one rule, or lifecycle tag restriction violations return S3 XML `InvalidRequest`
- `PUT /api/s3/{bucketName}?lifecycle` validates optional `Content-MD5` and one explicit `x-amz-checksum-sha256`, `x-amz-checksum-sha1`, `x-amz-checksum-crc32`, `x-amz-checksum-crc32c`, or `x-amz-checksum-crc64nvme` header against the raw lifecycle XML body before configuration replacement. `x-amz-sdk-checksum-algorithm` must match the explicit checksum value header. Invalid checksum syntax returns `InvalidDigest`; mismatched checksum values or SDK/header algorithm shape return `BadDigest`.
- Because OSMU does not support S3 Transition lifecycle actions, `x-amz-transition-default-minimum-object-size` on `PUT /api/s3/{bucketName}?lifecycle` is rejected as S3 XML `InvalidRequest` before configuration replacement.
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
- `PUT /api/s3/{bucketName}` creates a bucket through the S3-style path. MVP creation uses Bearer JWT auth because an access key cannot be scoped to a bucket that does not exist yet. General-purpose S3 bucket name rules are enforced; invalid names return S3 XML `InvalidBucketName`. Optional `CreateBucketConfiguration/LocationConstraint` XML is accepted when it matches the configured storage region; malformed XML, an unexpected root element, or duplicate `LocationConstraint` elements return S3 XML `MalformedXML` and do not create the bucket. Unsupported CreateBucket controls return S3 XML `InvalidRequest` before bucket creation: `x-amz-acl` values other than `private`, any `x-amz-grant-*` ACL header, `x-amz-bucket-object-lock-enabled: true`, `x-amz-object-ownership` values other than `BucketOwnerEnforced`, and `x-amz-bucket-namespace` values other than `global`. Duplicate creates return S3 XML `BucketAlreadyOwnedByYou` for the same owner and `BucketAlreadyExists` for another owner.
- `HEAD /api/s3/{bucketName}` checks bucket existence/access and returns `x-amz-bucket-region`.
- `GET /api/s3/{bucketName}?location` returns S3-compatible `LocationConstraint` XML.
- `GET /api/s3/{bucketName}?tagging` returns S3-compatible bucket tagging XML.
- `PUT /api/s3/{bucketName}?tagging` replaces bucket tags from S3-compatible tagging XML. Missing or blank XML returns S3 XML `MissingRequestBodyError`.
- `DELETE /api/s3/{bucketName}?tagging` clears bucket tags.
- `DELETE /api/s3/{bucketName}` deletes an empty bucket through the S3-style path.
- `GET /api/s3/{bucketName}` returns basic S3 `ListObjects` V1 XML.
- `GET /api/s3/{bucketName}?list-type=2` returns basic S3 `ListObjectsV2` XML.
- `GET /api/s3/{bucketName}?uploads` returns active S3-style multipart upload sessions.
- `POST /api/s3/{bucketName}?delete` deletes multiple objects from S3-compatible delete XML. Missing or blank XML returns S3 XML `MissingRequestBodyError`.
- `PUT /api/s3/{bucketName}/{objectKey}` uploads a raw request body.
- `PUT /api/s3/{bucketName}/{objectKey}` with `x-amz-copy-source: /sourceBucket/sourceKey` or `/sourceBucket/sourceKey?versionId={versionId}` copies an existing object or retained OSMU object version.
- `POST /api/s3/{bucketName}/{objectKey}?uploads` initiates an S3-style multipart upload.
- `PUT /api/s3/{bucketName}/{objectKey}?partNumber={n}&uploadId={uploadId}` uploads one multipart part through the backend.
- `GET /api/s3/{bucketName}/{objectKey}?uploadId={uploadId}` lists uploaded multipart parts and supports `max-parts` 1~1000 plus `part-number-marker` 0~10000 pagination.
- `POST /api/s3/{bucketName}/{objectKey}?uploadId={uploadId}` completes multipart upload from S3 `CompleteMultipartUpload` XML. Missing or blank XML returns S3 XML `MissingRequestBodyError`.
- `DELETE /api/s3/{bucketName}/{objectKey}?uploadId={uploadId}` aborts multipart upload.
- `HEAD /api/s3/{bucketName}/{objectKey}` returns object metadata headers.
- `GET /api/s3/{bucketName}/{objectKey}` streams the object body.
- `HEAD` and `GET` support basic conditional headers `If-Match`, `If-None-Match`, `If-Modified-Since`, and `If-Unmodified-Since`.
- `GET /api/s3/{bucketName}/{objectKey}` supports one `Range: bytes=start-end`, `bytes=start-`, or `bytes=-suffixLength` request.
- `GET /api/s3/{bucketName}/{objectKey}?tagging` returns S3-compatible object tagging XML.
- `PUT /api/s3/{bucketName}/{objectKey}?tagging` replaces object tags from S3-compatible tagging XML. Missing or blank XML returns S3 XML `MissingRequestBodyError`.
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
- For non-streaming S3 object `PUT` and multipart part `PUT`, a signed `x-amz-content-sha256` hex payload hash is validated against the actual request body. `UNSIGNED-PAYLOAD` skips body hash validation. AWS `aws-chunked` request bodies are decoded when `x-amz-decoded-content-length` is present, decoded length mismatch is rejected as S3 XML `InvalidRequest`, and `STREAMING-AWS4-HMAC-SHA256-PAYLOAD` chunks require a 64-character lowercase hex `chunk-signature`. With SigV4 header auth, each chunk signature is cryptographically chained from the Authorization seed signature and rejected as S3 XML `AccessDenied` on mismatch.
- AWS `aws-chunked` uploads support `x-amz-trailer` for one trailing checksum among `x-amz-checksum-sha256`, `x-amz-checksum-sha1`, `x-amz-checksum-crc32`, `x-amz-checksum-crc32c`, and `x-amz-checksum-crc64nvme`. The trailing checksum is validated against the decoded body, returned as the matching response header, and stored in object metadata for later `HEAD`/`GET`.
- Virtual-hosted-style routing is supported for configured suffixes. With `osmu.s3.virtual-hosted-style.domain-suffixes=localhost`, `Host: {bucket}.localhost` and path `/api/s3/{objectKey}` are routed as `/api/s3/{bucket}/{objectKey}` while SigV4 canonical URI remains the client-signed virtual-hosted path.
- `Content-Length` is required for non-streaming `PUT`; missing it returns S3 XML `MissingContentLength` with HTTP `411`, and a body length that does not match the declared `Content-Length` returns S3 XML `IncompleteBody` with HTTP `400`. AWS `aws-chunked` uploads require `x-amz-decoded-content-length`.
- `Content-Type` is stored as object content type. Missing value defaults to `application/octet-stream`.
- S3 object `PUT` stores `x-amz-meta-*` user metadata and returns those headers on S3 `HEAD`/`GET`.
- `Content-MD5` is accepted on S3 object `PUT`; invalid base64 MD5 returns `InvalidDigest`, and mismatched body checksum returns `BadDigest`. Content-MD5 digest errors use AWS-style `InvalidDigest`/`BadDigest` messages.
- S3 object `PUT` validates one optional checksum value header among `x-amz-checksum-sha256`, `x-amz-checksum-sha1`, `x-amz-checksum-crc32`, `x-amz-checksum-crc32c`, and `x-amz-checksum-crc64nvme`. If `x-amz-sdk-checksum-algorithm` is present without an explicit checksum value, OSMU computes and stores the requested checksum while streaming the object body, matching AWS CLI `--checksum-algorithm` behavior for supported algorithms. Invalid base64/length returns `InvalidDigest`; unsupported SDK algorithms return `InvalidRequest`; mismatched body checksum or SDK/value header algorithm shape returns `BadDigest`; matching checksum is stored in object metadata and returns the same `x-amz-checksum-*` response header.
- S3 object `PUT` supports destination `If-Match` and `If-None-Match: *` overwrite guards against the current target object ETag. Failed preconditions return `412 PreconditionFailed` before request body storage.
- `x-amz-copy-source` copies source object body, content type, user metadata, tags, and stored checksum metadata into the target object and returns `CopyObjectResult` XML. `x-amz-checksum-algorithm` overrides the copied checksum metadata by recalculating the target checksum for `SHA256`, `SHA1`, `CRC32`, `CRC32C`, or `CRC64NVME`; unsupported algorithms return S3 XML `InvalidRequest`. Stored checksums are emitted as `ChecksumSHA256`, `ChecksumSHA1`, `ChecksumCRC32`, `ChecksumCRC32C`, or `ChecksumCRC64NVME` elements when the copied target metadata has them. `?versionId={versionId}` can copy an OSMU-retained source version body/content type/tags/user metadata.
- `x-amz-metadata-directive: COPY|REPLACE` is supported for CopyObject content type and user metadata handling. `COPY` preserves source `x-amz-meta-*` headers; `REPLACE` uses the request `Content-Type` and request `x-amz-meta-*` headers.
- `x-amz-tagging-directive: COPY|REPLACE` is supported for CopyObject tag handling. `REPLACE` uses `x-amz-tagging` or `X-OSMU-Tags`.
- CopyObject supports source preconditions: `x-amz-copy-source-if-match`, `x-amz-copy-source-if-none-match`, `x-amz-copy-source-if-modified-since`, and `x-amz-copy-source-if-unmodified-since`, including AWS-documented combined-header precedence for ETag/date source conditions. It also supports destination `If-Match` and `If-None-Match: *` target overwrite guards. Failed preconditions return `412 PreconditionFailed`.
- `X-OSMU-Tags: key=value,stage=raw` stores tags using OSMU tag syntax.
- `x-amz-tagging: key=value&stage=raw` is also accepted and converted to OSMU tag syntax.
- `PUT` returns an MD5-based `ETag` for prototype compatibility.
- S3 multipart initiate accepts optional `X-OSMU-Multipart-Size-Bytes` or `x-amz-meta-osmu-size-bytes`. When omitted, the backend creates an AWS-style plan-less multipart session without precomputed part URLs/byte ranges and checks quota on complete against the actual completed object size.
- S3 multipart initiate accepts `x-amz-checksum-algorithm` for `SHA256`, `SHA1`, `CRC32`, `CRC32C`, and `CRC64NVME`, validates optional `x-amz-checksum-type: COMPOSITE|FULL_OBJECT` combinations, rejects unsupported checksum negotiation as S3 XML `InvalidRequest`, persists accepted checksum algorithm/type on the upload session, and echoes accepted `x-amz-checksum-algorithm`/`x-amz-checksum-type` response headers.
- S3 multipart initiate rejects unsupported CreateMultipartUpload controls as S3 XML `InvalidRequest` before session creation: non-private `x-amz-acl`, any `x-amz-grant-*`, Object Lock headers, server-side encryption headers, non-`STANDARD` `x-amz-storage-class`, `x-amz-website-redirect-location`, and `x-amz-request-payer`. Safe no-op defaults `x-amz-acl: private` and `x-amz-storage-class: STANDARD` are accepted.
- S3 multipart initiate optionally accepts `X-OSMU-Multipart-Part-Size-Bytes` or `x-amz-meta-osmu-part-size-bytes` when expected size is supplied; otherwise the REST multipart default part size is used. Multipart refresh still requires a planned session with expected size and part count.
- S3 multipart initiate optionally accepts `X-OSMU-Multipart-Expires-In-Seconds` for session expiry.
- S3 multipart upload part requires `Content-Length`, returns S3 XML `MissingContentLength` with HTTP `411` when omitted, and returns S3 XML `IncompleteBody` with HTTP `400` when the body length does not match the declared length. It validates optional `Content-MD5`, signed `x-amz-content-sha256`, and one optional `x-amz-checksum-*` value header, and returns part `ETag`. Matching checksum returns the same `x-amz-checksum-*` response header. If the multipart session was initiated with `x-amz-checksum-algorithm`, or the part request sends `x-amz-sdk-checksum-algorithm`, the backend computes the matching part checksum when no explicit checksum header/trailer is supplied, stores it by upload id and part number, and returns it as the response checksum header. SDK checksum algorithm headers and explicit part checksum headers must match any initiated checksum algorithm or the request returns S3 XML `BadDigest`.
- S3 multipart list parts returns `PartNumberMarker`, optional `NextPartNumberMarker`, `MaxParts`, `IsTruncated`, and a page of uploaded parts sorted by `PartNumber`. Stored part checksums are emitted as `ChecksumSHA256`, `ChecksumSHA1`, `ChecksumCRC32`, `ChecksumCRC32C`, or `ChecksumCRC64NVME` elements.
- S3 multipart complete accepts one optional final object `x-amz-checksum-*` value header, validates it against the completed object body, validates optional `x-amz-mp-object-size` against the actual completed object size and returns S3 XML `InvalidRequest` on mismatch, accepts `x-amz-checksum-type: FULL_OBJECT` when a final object checksum header is present, requires the final checksum algorithm to match any stored initiate `FULL_OBJECT` negotiation and returns S3 XML `BadDigest` before storage completion on mismatch, stores matching checksum metadata, returns the same checksum response header, emits complete-result XML `Location`, `Bucket`, `Key`, `ETag`, matching checksum element plus `ChecksumType` when requested, persisted on initiate, or inferable from the returned checksum shape, and preserves the MinIO-backed S3 multipart ETag (`md5-of-part-md5s-partCount`) in the response XML/header and later `HEAD`.
- S3 multipart complete rejects unsupported CompleteMultipartUpload control headers before storage completion: `x-amz-request-payer`, `x-amz-expected-bucket-owner`, `x-amz-server-side-encryption-customer-algorithm`, `x-amz-server-side-encryption-customer-key`, and `x-amz-server-side-encryption-customer-key-MD5`.
- Missing or inactive S3 multipart upload IDs return S3 XML `NoSuchUpload`.
- S3 multipart complete request XML requires 1~10000 `Part` entries, strictly ascending unique `PartNumber` values, and a non-blank `ETag` for every part. Out-of-order or duplicate part numbers return S3 XML `InvalidPartOrder` before storage complete. Uploaded non-last parts smaller than 5 MiB return S3 XML `EntityTooSmall` before storage complete.
- S3 multipart complete verifies every requested part was uploaded and its ETag matches the uploaded part before storage complete; missing parts or stale ETags return S3 XML `InvalidPart` without completing the upload.
- S3 multipart complete request XML must use a `CompleteMultipartUpload` root; unexpected roots return S3 XML `MalformedXML` before storage completion. The XML accepts optional per-part `ChecksumSHA256`, `ChecksumSHA1`, `ChecksumCRC32`, `ChecksumCRC32C`, and `ChecksumCRC64NVME` elements and validates their checksum syntax before completing storage upload. When XML omits per-part checksums, stored UploadPart checksum metadata for the same upload id and part number is merged before checksum negotiation validation and composite checksum aggregation. If no final object checksum header is supplied and every completed part has the same `ChecksumSHA256`, `ChecksumSHA1`, `ChecksumCRC32`, or `ChecksumCRC32C`, the response stores and emits the AWS-style composite checksum calculated from ordered part checksum bytes and accepts `x-amz-checksum-type: COMPOSITE`; this includes requests whose per-part checksum evidence comes from stored UploadPart metadata rather than CompleteMultipartUpload XML. If initiate stored `COMPOSITE`, every completed part must include a supported composite checksum with the same algorithm as the initiate request; mismatches return S3 XML `BadDigest` before storage completion, and complete-result XML emits the initiated `ChecksumType` even when the complete request omits `x-amz-checksum-type`. If neither request nor initiate supplied a checksum type, complete-result XML infers `ChecksumType=FULL_OBJECT` when a final checksum header is accepted and `ChecksumType=COMPOSITE` when returned checksum metadata came from stored per-part composite aggregation. `CRC64NVME` is accepted as a full-object checksum only. Invalid checksum type values or mismatched request checksum type/header shape return S3 XML `InvalidRequest` before storage completion. Broader AWS multipart checksum negotiation parity and real-client option coverage remain future work.
- S3 multipart complete supports destination `If-Match` and `If-None-Match: *` overwrite guards against the current target object ETag. Failed preconditions return `412 PreconditionFailed` before storage completion.
- `HEAD`, `GET`, `ListObjects`, and `ListObjectsV2` include `ETag` when object metadata has an ETag.
- `HEAD` and `GET` return stored `x-amz-checksum-*` headers for S3 uploads that supplied or auto-computed checksum values. `ListObjects` and `ListObjectsV2` emit `ChecksumAlgorithm` entries for stored checksums.
- `If-None-Match` returns `304 Not Modified` when it matches the current ETag; `If-Match` returns `412 Precondition Failed` when it does not match.
- `If-Modified-Since` returns `304 Not Modified` when the object has not changed after the requested timestamp; `If-Unmodified-Since` returns `412 Precondition Failed` when the object changed after the requested timestamp.
- Range GET honors `If-Range` with an ETag or HTTP date: matching validators return the requested range, while stale validators ignore `Range` and return the full object.
- Bucket-level responses return `x-amz-bucket-region`; default MVP region is `us-east-1`.
- Bucket create returns `200 OK`, `Location: /{bucketName}`, and `x-amz-bucket-region`. Invalid S3 bucket names return `400 InvalidBucketName`; invalid CreateBucket XML returns `400 MalformedXML`; unsupported CreateBucket control headers return `400 InvalidRequest`. Bucket delete returns `204 No Content`; deleting a bucket that still has active objects or retained object versions returns `409 BucketNotEmpty`.
- Bucket tagging uses `Tagging/TagSet/Tag/Key/Value` XML, requires the `Tagging` root element, stores up to 50 bucket metadata tags, returns `MissingRequestBodyError` for missing/blank XML, returns `MalformedXML` for unexpected roots, and disables DOCTYPE/external entity loading while parsing.
- Range GET returns `206 Partial Content`, `Accept-Ranges: bytes`, and `Content-Range` for one byte range. Multi-range requests are rejected with `416 RANGE_NOT_SATISFIABLE`, matching AWS S3's documented one-range behavior.
- `ListObjectsV2` supports `prefix`, `delimiter`, `max-keys` from `1` to `1000`, `continuation-token`, `encoding-type=url`, and `fetch-owner=true|false`.
- `ListObjectsV2` returns `Contents`, `CommonPrefixes`, `IsTruncated`, `NextContinuationToken`, and optional `Owner`.
- `ListObjects` V1 supports `prefix`, `delimiter`, `max-keys` from `1` to `1000`, `marker`, `encoding-type=url`, and `fetch-owner=true|false`.
- `ListObjects` V1 returns `Contents`, `CommonPrefixes`, `IsTruncated`, `NextMarker`, and optional `Owner`.
- `encoding-type=url` returns `EncodingType` and percent-encodes list key-like XML values such as `Prefix`, `Delimiter`, `Key`, `CommonPrefixes`, and pagination markers.
- `fetch-owner=true` adds `Owner/ID` and `Owner/DisplayName` under each `Contents` item using the authenticated OSMU user.
- Multi-object delete uses `Delete/Object/Key` XML, requires the `Delete` root element, accepts up to 1000 objects, and returns `DeleteResult/Deleted`. Unexpected XML roots return S3 XML `MalformedXML` before delete execution. If `Delete/Quiet` is `true`, successful `Deleted` entries are suppressed.
- Multi-object delete uses the same OSMU soft-delete behavior as single object delete. Missing object keys are reported as deleted for S3 compatibility.
- Key-specific failures return `DeleteResult/Error` entries with `Key`, S3-style `Code`, and `Message`. `Quiet=true` only suppresses successful `Deleted` entries, not `Error` entries.
- Multi-object delete validates optional `Content-MD5`; invalid base64 MD5 returns `InvalidDigest`, and mismatched body checksum returns `BadDigest`. Content-MD5 digest errors use AWS-style `InvalidDigest`/`BadDigest` messages.
- Object tagging uses `Tagging/TagSet/Tag/Key/Value` XML, requires the `Tagging` root element, rejects unexpected roots as `MalformedXML`, and reuses the same tag metadata used by the REST object API.
- `PUT ?tagging` rejects missing/blank XML as `MissingRequestBodyError`, rejects invalid XML as `MalformedXML` or `InvalidRequest` depending on parser/schema shape, and disables DOCTYPE/external entity loading.
- S3 responses expose AWS-style trace headers: `x-amz-request-id` mirrors the normalized `X-Request-Id`, and `x-amz-id-2` is an opaque deterministic value derived from request id plus resource. These headers are exposed through backend CORS for browser clients.
- Errors under `/api/s3/**` return AWS-style XML `<Error><Code>...</Code><Message>...</Message><Resource>...</Resource><RequestId>...</RequestId><HostId>...</HostId></Error>`; when derivable, per-error details such as `BucketName`, `Key`, and `UploadId` are emitted between `Message` and `Resource`. XML `RequestId` and `HostId` match the S3 trace headers.
- S3 XML error code mapping includes `AccessDenied`, `NoSuchBucket`, `NoSuchKey`, `NoSuchUpload`, `NoSuchLifecycleConfiguration`, `BucketAlreadyOwnedByYou`, `BucketAlreadyExists`, `BucketNotEmpty`, `InvalidBucketName`, `InvalidRange`, `InvalidRequest`, `MalformedXML`, `MissingRequestBodyError`, `InvalidPart`, `InvalidPartOrder`, `InvalidDigest`, `BadDigest`, `PreconditionFailed`, `EntityTooSmall`, `EntityTooLarge`, `OperationAborted`, `MissingContentLength`, `IncompleteBody`, and `InternalError`.
- S3 XML `AccessDenied` responses use HTTP `403` and message `Access Denied` for AWS client compatibility even when the underlying REST auth failure category is `AUTHENTICATION_REQUIRED`; normal REST JSON auth failures still use HTTP `401` and retain detailed JSON messages.
- S3 XML `BadDigest`/`InvalidDigest` responses for Content-MD5 use AWS-style messages while non-MD5 checksum failures retain the more specific failing checksum message.
- S3 XML `EntityTooLarge`, `OperationAborted`, and `InternalError` responses use AWS-style generic messages for S3 client compatibility.
- S3 XML `InvalidRange` responses use HTTP `416` and message `The requested range cannot be satisfied.` for AWS client compatibility.
- S3 XML `NoSuchBucket`, `NoSuchKey`, `NoSuchUpload`, and `NoSuchLifecycleConfiguration` responses use AWS-style messages for bucket, object key, multipart upload, and bucket lifecycle configuration misses.
- S3 XML `PreconditionFailed` responses use HTTP `412` and message `At least one of the preconditions you specified did not hold.`
- S3 XML `InvalidBucketName`, `BucketAlreadyOwnedByYou`, `BucketAlreadyExists`, and `BucketNotEmpty` responses use AWS-style bucket error messages instead of internal validation/conflict text.
- S3 XML `InvalidPart`, `InvalidPartOrder`, and `EntityTooSmall` responses use AWS-style CompleteMultipartUpload special-error messages.
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

CreateBucket XML:

```xml
<CreateBucketConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <LocationConstraint>us-east-1</LocationConstraint>
</CreateBucketConfiguration>
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

`Part` entries must be non-empty, sorted by ascending `PartNumber`, unique, within 1~10000, and include non-blank `ETag`.

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
- AWS `aws-chunked` body decoding is implemented for object and multipart part uploads with exact decoded length validation, `STREAMING-AWS4-HMAC-SHA256-PAYLOAD` chunk-signature presence/format validation, SigV4 header-auth per-chunk cryptographic signature chaining, and trailing checksum validation for SHA256/SHA1/CRC32/CRC32C/CRC64NVME.
- S3 multipart upload path is MVP-level but no longer requires OSMU expected-size headers at initiate time; when size is omitted, quota is checked against the completed object size.
- S3 multipart uploads listing is backed by OSMU active multipart sessions, not a raw MinIO bucket scan.
- Virtual-hosted-style routing currently extracts the bucket from the left side of a configured domain suffix. Production deployments must configure DNS/proxy hosts such as `{bucket}.storage.example.com` and set `osmu.s3.virtual-hosted-style.domain-suffixes=storage.example.com`.
- Remaining conditional request edge parity beyond documented object `PUT` destination ETag guards, `HEAD`/`GET` `If-Match`/`If-Unmodified-Since`, `If-None-Match`/`If-Modified-Since`, CopyObject source ETag/date combinations, CopyObject destination ETag guards, and multipart complete destination ETag guards, CopyObject full AWS versioning/remaining conditional edge parity, remaining CreateBucket/DeleteBucket/CreateMultipartUpload edge error parity beyond covered control headers/name/duplicate/active-or-retained non-empty/unsupported-create-control cases, full AWS multipart checksum negotiation parity beyond stored UploadPart checksum metadata and complete-time matching guards, and full AWS error behavior parity are not implemented yet. See `s3-compatibility.md` for the supported/partial/unsupported matrix.

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

## 9. Object API

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

## 10. Access Key API

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
      "expiresAt": null,
      "lastUsedAt": "2026-06-15T14:08:00+09:00",
      "usageCount": 12,
      "rotationGraceExpiresAt": "2026-06-15T14:13:00+09:00"
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
- `expiresAt`은 선택값이며, 지정하면 미래 시각이어야 한다.
- 만료된 Access Key는 S3 호환 인증과 rotation 대상에서 제외된다.
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
- S3 호환 API에서 Access Key 인증이 성공하면 해당 key의 `lastUsedAt`을 갱신하고 `usageCount`를 1 증가시킨다.
- Secret rotation 직후에는 `osmu.access-key.rotation-grace-seconds` 동안 이전 Secret을 OSMU S3-compatible API에서 임시 허용하고 `rotationGraceExpiresAt`으로 만료 시각을 노출한다.

- Access key `permissions` supports `READ`, `WRITE`, `DELETE`, and `ADMIN`.
- `ADMIN` access key scope is required for bucket lifecycle alias operations.

### POST /api/access-keys/{keyId}/rotate

기존 Access Key의 Secret Key를 재발급한다.

MVP 동작:

- `accessKey`, `id`, bucket scope, policy name은 유지한다.
- 새 `secretKey`는 응답에서 1회만 노출한다.
- 기존 Secret Key는 기본 300초 grace period 동안 OSMU S3-compatible API에서 계속 허용되며 grace 만료 뒤 인증 실패 처리된다.
- `ACTIVE` 상태의 Access Key만 회전할 수 있다.
- 일반 사용자는 본인이 소유한 Access Key만 회전할 수 있고, `ADMIN`은 전체 Access Key를 회전할 수 있다.
- `ACCESS_KEY_ROTATE` 감사 로그를 기록하되 새 secret 원문은 기록하지 않는다.
- MinIO provisioning mode에서는 기존 MinIO user의 secret을 갱신한 뒤 metadata의 `secret_key_hash`, `secret_key_ciphertext`를 갱신한다.

응답은 `POST /api/access-keys`와 같은 one-time secret response 구조를 사용한다.

### DELETE /api/access-keys/{keyId}

Access Key 비활성화.

### POST /api/access-keys/bulk-disable

Access Key 여러 개를 한 번에 비활성화한다.

요청:

```json
{
  "keyIds": [1, 2, 3]
}
```

응답:

```json
{
  "success": true,
  "data": {
    "requestedCount": 3,
    "disabledCount": 2,
    "skippedCount": 1,
    "disabledKeyIds": [1, 3],
    "skippedKeyIds": [2]
  }
}
```

동작:

- 일반 사용자는 본인 소유 Access Key만 bulk disable할 수 있다.
- `ADMIN`은 전체 Access Key를 bulk disable할 수 있다.
- 이미 `INACTIVE`인 key는 실패가 아니라 `skippedKeyIds`에 포함한다.
- 존재하지 않는 key 또는 접근 권한이 없는 key가 포함되면 요청은 실패한다.
- 성공 시 `ACCESS_KEY_BULK_DISABLE` audit log를 기록한다.

## 11. Admin API

### GET /api/admin/usage

전체 사용량 조회.

### GET /api/admin/monitoring/data-flow

관리자 데이터 흐름 감시 요약을 조회한다. `ADMIN` 권한 필요.

용도:

- 현재까지 관측된 업로드/다운로드 트래픽 byte 합계 확인
- 업로드, 다운로드, 목록 조회, 삭제, 취소, 실패 건수 확인
- 버킷별 상위 데이터 흐름 확인
- 최근 데이터 흐름 이벤트 확인

Query parameters:

- `from`: ISO-8601 offset datetime. Includes events created at or after this timestamp.
- `to`: ISO-8601 offset datetime. Includes events created at or before this timestamp.
- `bucketName`: exact bucket name filter.
- `actorId`: exact login/user id filter.
- `source`: event source filter, for example `rest`, `s3`, `s3-copy`.
- `operation`: event operation filter, for example `upload`, `download`, `copy`, `list`, `delete`.
- `status`: event status filter, for example `SUCCESS`, `FAILED`, `CANCELLED`.
- `limit`: recent event response limit. Default `50`, maximum `500`.

Trend response:

- `trendPoints`: latest 24 UTC hourly buckets grouped by `source` and `operation`.
- S3 CopyObject is recorded as `eventType=COPY`, `operation=copy`, `direction=INTERNAL`; copied bytes are exposed as `copiedBytes` and `internalBytes`, not as external ingress.

Response:

```json
{
  "data": {
    "traffic": {
      "uploadedBytes": 1048576,
      "downloadedBytes": 524288,
      "copiedBytes": 262144,
      "totalBytes": 1835008,
      "ingressBytes": 1048576,
      "egressBytes": 524288,
      "internalBytes": 262144
    },
    "operations": {
      "uploadCount": 12,
      "downloadCount": 8,
      "copyCount": 3,
      "listCount": 30,
      "deleteCount": 1,
      "cancelCount": 1,
      "failureCount": 2,
      "totalCount": 54
    },
    "topBuckets": [
      {
        "bucketName": "media",
        "uploadedBytes": 1048576,
        "downloadedBytes": 524288,
        "copiedBytes": 262144,
        "totalBytes": 1835008,
        "uploadCount": 12,
        "downloadCount": 8,
        "copyCount": 3,
        "listCount": 30,
        "deleteCount": 1,
        "cancelCount": 1,
        "failureCount": 2,
        "lastEventAt": "2026-06-18T10:20:00+09:00"
      }
    ],
    "trendPoints": [
      {
        "bucketStartAt": "2026-06-18T01:00:00Z",
        "source": "s3",
        "operation": "download",
        "successCount": 8,
        "failureCount": 1,
        "cancelCount": 0,
        "totalCount": 9,
        "bytes": 524288
      }
    ],
    "recentEvents": [
      {
        "eventType": "DOWNLOAD",
        "operation": "download",
        "direction": "EGRESS",
        "bucketName": "media",
        "objectKey": "videos/raw/input.mp4",
        "actorId": "developer",
        "status": "SUCCESS",
        "sizeBytes": 524288,
        "message": "Download started",
        "source": "s3",
        "createdAt": "2026-06-18T10:20:00+09:00"
      }
    ],
    "generatedAt": "2026-06-18T10:20:00+09:00"
  }
}
```

Notes:

- MVP 구현은 backend process 안의 in-memory 집계와 Micrometer counter를 함께 사용한다.
- production 단계에서는 MariaDB event table 또는 time-series storage에 영구 저장하고 Prometheus/Grafana alert와 연결해야 한다.
- `GET /api/admin/dashboard/summary` 응답에도 같은 `dataFlow` 객체가 포함된다.

Persistence:

- MariaDB mode persists events in `data_flow_events`; in-memory mode keeps runtime events only for local/demo execution.
- The response is aggregated from persisted event rows matching the requested filters. The MVP summary scans up to the latest 10,000 matching events.
- Micrometer counters are still emitted for Prometheus via `osmu.data.flow.operations` and `osmu.data.flow.bytes` with source/status/direction/bucket labels for starter alerting.
- Scheduled retention deletes old data-flow event rows with `DATA_FLOW_EVENT_RETENTION` audit and `osmu.data.flow.retention.*` metrics. Defaults: enabled, 90 days, batch size 1000, fixed delay 6 hours.

### GET /api/admin/monitoring/data-flow/export.csv

Exports the same administrator data-flow event window as CSV. `ADMIN` role required.

Query parameters are identical to `GET /api/admin/monitoring/data-flow`: `from`, `to`, `bucketName`, `actorId`, `source`, `operation`, `status`, and `limit`.

Response:

- `Content-Type: text/csv`
- `Content-Disposition: attachment; filename="osmu-data-flow.csv"`
- Columns: `createdAt,eventType,operation,direction,bucketName,objectKey,actorId,status,sizeBytes,source,message`
- Rows are newest-first and capped by `limit` with default `50` and maximum `500`.

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

### GET /api/admin/storage-expansion/requests

ADMIN이 MinIO pool 단위 storage expansion 요청과 계획을 조회한다. 현재 MVP는 Kubernetes 실행 전 단계로 요청/계획/상태 기록을 제공한다.

응답:

```json
{
  "items": [
    {
      "id": 1,
      "poolName": "pool-1",
      "requestedCapacityBytes": 107374182400,
      "serverCount": 4,
      "volumesPerServer": 1,
      "volumeSizeBytes": 53687091200,
      "estimatedRawCapacityBytes": 214748364800,
      "estimatedUsableCapacityBytes": 107374182400,
      "status": "PLANNED",
      "reason": "media archive growth",
      "createdBy": "admin",
      "appliedBy": null,
      "appliedAt": null,
      "appliedEvidence": null,
      "createdAt": "2026-06-15T06:00:00Z",
      "updatedAt": "2026-06-15T06:00:00Z"
    }
  ]
}
```

### GET /api/admin/storage-expansion/summary

ADMIN dashboard에서 Storage Expansion 전체 요청/실행 현황을 빠르게 표시하기 위한 aggregate summary를 조회한다. 요청 목록과 request별 execution history를 각각 모두 조회하지 않아도 open/applied/rejected 요청 수, 총 실행 수, 최근 요청/실행을 확인할 수 있다. MariaDB 구현은 request status/capacity aggregate와 execution count/result/timedOut/recent 값을 aggregate query와 index로 조회해 전체 request/execution row scan을 application layer로 끌어오지 않는다.

응답:

```json
{
  "data": {
    "requestCount": 1,
    "openRequestCount": 1,
    "plannedRequestCount": 1,
    "approvedRequestCount": 0,
    "appliedRequestCount": 0,
    "rejectedRequestCount": 0,
    "totalRequestedCapacityBytes": 107374182400,
    "openRequestedCapacityBytes": 107374182400,
    "totalEstimatedUsableCapacityBytes": 107374182400,
    "openEstimatedUsableCapacityBytes": 107374182400,
    "executionCount": 0,
    "successExecutionCount": 0,
    "failedExecutionCount": 0,
    "skippedExecutionCount": 0,
    "timedOutExecutionCount": 0,
    "latestRequest": {
      "id": 1,
      "poolName": "pool-1",
      "status": "PLANNED"
    },
    "latestExecution": null,
    "recentExecutions": []
  }
}
```

### GET /api/admin/storage-expansion/runner-preflight

Storage Expansion server runner의 enablement와 실행 도구 준비 상태를 조회한다. 기본 disabled 설정에서는 실제 CLI를 실행하지 않고 `DISABLED` 상태를 반환한다. runner가 enabled인 경우에만 `kubectl`, `helm`, `helm diff`, `git`, `gh`, `gh auth status`, GitOps repository `.git` metadata, `git -C {repositoryPath} status --short`를 짧은 timeout으로 probe한다. 각 check는 운영자가 다음 조치를 바로 알 수 있도록 `remediation`을 포함한다.

Kubernetes in-cluster kubectl runner를 활성화하는 경우에는 `osmu-storage-expansion-runner` ServiceAccount/Role/RoleBinding을 사용한다. 이 권한은 `Tenant/osmu-minio`와 legacy `StatefulSet/osmu-minio`에 대한 namespace-scoped 최소 권한만 제공한다. Helm upgrade/rollback과 GitOps PR runner는 기본적으로 외부 GitOps/CI identity를 사용해야 한다.

응답:

```json
{
  "data": {
    "status": "DISABLED",
    "ready": false,
    "enabledRunnerCount": 0,
    "failedCheckCount": 0,
    "checks": [
      {
        "id": "dry-run",
        "label": "Dry-run runner",
        "enabled": false,
        "status": "DISABLED",
        "detail": "Set OSMU_STORAGE_EXPANSION_RUNNER_ENABLED=true to execute kubectl/helm dry-runs.",
        "remediation": "Set OSMU_STORAGE_EXPANSION_RUNNER_ENABLED=true to execute kubectl/helm dry-runs.",
        "commands": []
      }
    ]
  }
}
```

### POST /api/admin/storage-expansion/requests

MinIO pool 증설 요청을 생성한다. 기본 계획은 `4 servers x 1 PV/server`이며 요청 usable capacity를 만족하도록 PV size를 GiB 단위로 반올림한다. Erasure coding overhead는 MVP 계획에서 raw 대비 usable 50%로 계산한다. ADMIN 전용.

요청:

```json
{
  "requestedCapacityBytes": 107374182400,
  "serverCount": 4,
  "volumesPerServer": 1,
  "reason": "media archive growth"
}
```

응답은 단일 `storage expansion request` 객체를 `data`에 담아 반환한다.

검증:

- `requestedCapacityBytes`는 양수이며 최대 1 PiB까지 허용한다.
- `serverCount`는 4..32 범위.
- `volumesPerServer`는 1..16 범위.
- `reason`은 최대 512자.

### PATCH /api/admin/storage-expansion/requests/{requestId}/status

증설 요청 상태를 변경한다. 실제 Kubernetes/MinIO Operator 적용은 후속 실행기에서 처리하며, 현재 MVP는 운영 계획과 이력 상태를 남긴다. ADMIN 전용.

요청:

```json
{
  "status": "APPLIED",
  "appliedEvidence": "helm upgrade osmu-minio --values pool-1.yaml"
}
```

허용 상태:

- `PLANNED`
- `APPROVED`
- `REJECTED`
- `APPLIED`

전이 규칙:

- `PLANNED -> APPROVED`
- `PLANNED -> REJECTED`
- `APPROVED -> APPLIED`
- `APPROVED -> REJECTED`
- `APPLIED`로 변경할 때는 `appliedEvidence`가 필수다.
- `appliedEvidence`는 적용 명령, GitOps PR URL, 배포 로그 URL, 운영 티켓 ID 같은 증거 문자열이다.

### GET /api/admin/storage-expansion/execution-log-retention/status

Storage Expansion execution output retention 상태를 조회한다. ADMIN 전용.

응답:

```json
{
  "data": {
    "enabled": true,
    "retentionDays": 90,
    "batchSize": 100,
    "pendingOutputCount": 0,
    "redactedOutputCount": 3,
    "failedRunCount": 0
  }
}
```

### POST /api/admin/storage-expansion/execution-log-retention/run

Storage Expansion execution output retention을 수동 실행한다. ADMIN 전용. `createdAt`이 retention cutoff보다 오래된 execution output만 redaction marker로 교체하고 execution record, result, command, artifact SHA-256, audit trail은 유지한다.

응답:

```json
{
  "data": {
    "redactedOutputCount": 1,
    "status": {
      "enabled": true,
      "retentionDays": 90,
      "batchSize": 100,
      "pendingOutputCount": 0,
      "redactedOutputCount": 4,
      "failedRunCount": 0
    }
  }
}
```

설정:

- `OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_ENABLED=true`
- `OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_DAYS=90`
- `OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_BATCH_SIZE=100`
- `OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_INITIAL_DELAY_MS=180000`
- `OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_FIXED_DELAY_MS=3600000`

### GET /api/admin/storage-expansion/requests/{requestId}/manifest

ADMIN이 증설 요청에서 생성될 MinIO Operator Tenant patch와 Helm values patch 초안을 미리 확인한다. 현재 MVP는 실제 Kubernetes 적용 전 검토용 `referenceOnly = true` 응답을 반환한다.

응답:

```json
{
  "data": {
    "requestId": 1,
    "poolName": "pool-1",
    "status": "APPROVED",
    "referenceOnly": true,
    "tenantPatchYaml": "apiVersion: minio.min.io/v2\nkind: Tenant\n...",
    "helmValuesPatchYaml": "minio:\n  pools:\n    - name: pool-1\n..."
  }
}
```

검증:

- 존재하지 않는 `requestId`는 404.
- ADMIN 전용.
- YAML은 운영 적용용 명령이 아니라, 증설 승인 후 검토/배포 파이프라인 연결을 위한 초안이다.

### GET /api/admin/storage-expansion/requests/{requestId}/manifest/{artifact}

ADMIN이 증설 요청 manifest를 YAML 파일로 내려받는다. GitOps PR, Helm values patch, 운영 티켓 첨부를 위한 export 용도다.

Path:

| 이름 | 필수 | 설명 |
| --- | --- | --- |
| `requestId` | Y | Storage Expansion request ID |
| `artifact` | Y | `tenant`, `helm`, `bundle` 중 하나 |

응답:

- `Content-Type: application/x-yaml`
- `Content-Disposition: attachment; filename="osmu-storage-expansion-pool-1-tenant.yaml"`
- body는 YAML text

`artifact` 값:

- `tenant`: MinIO Operator Tenant patch 초안.
- `helm`: Helm chart `minio.pools` values patch 초안. `infra/helm/osmu`는 기본 단일 StatefulSet을 유지하고, `minio.tenant.enabled=true`일 때 MinIO Operator Tenant와 pool topology를 렌더링한다.
- `bundle`: tenant와 helm 산출물을 함께 담은 multi-document YAML.

### POST /api/admin/storage-expansion/requests/{requestId}/execution-plan

승인된 증설 요청의 dry-run 실행 계획을 생성한다. 현재 MVP는 실제 Kubernetes/Helm 적용을 하지 않고, 적용 전 체크리스트, artifact SHA-256, 추천 명령, 적용 증거 템플릿을 반환한다.

조건:

- ADMIN 전용.
- request status가 `APPROVED`여야 한다.
- `PLANNED`, `REJECTED`, `APPLIED` 요청은 400.

응답:

```json
{
  "data": {
    "requestId": 1,
    "poolName": "pool-1",
    "status": "APPROVED",
    "ready": true,
    "referenceOnly": true,
    "artifactSha256": "64-char-sha256",
    "evidenceTemplate": "dry-run bundle osmu-storage-expansion-pool-1-bundle.yaml sha256:...",
    "preflightChecks": [
      "Confirm StorageClass osmu-storage exists and supports requested PV size."
    ],
    "suggestedCommands": [
      "kubectl -n osmu diff -f osmu-storage-expansion-pool-1-bundle.yaml",
      "kubectl -n osmu apply --server-side --dry-run=server -f osmu-storage-expansion-pool-1-bundle.yaml",
      "helm diff upgrade osmu-minio ./infra/helm/osmu -f osmu-storage-expansion-pool-1-bundle.yaml",
      "helm upgrade osmu-minio ./infra/helm/osmu -f osmu-storage-expansion-pool-1-bundle.yaml --dry-run"
    ]
  }
}
```

### POST /api/admin/storage-expansion/requests/{requestId}/dry-run-execution

승인된 Storage Expansion 요청에 대해 `kubectl diff` 또는 `helm diff` dry-run evidence를 표준 실행 이력으로 기록한다. 서버는 현재 manifest bundle SHA-256과 추천 명령을 다시 계산해 저장하므로, 수동 execution record보다 artifact 연결이 명확하다.

요청:

```json
{
  "executionType": "KUBECTL_DIFF",
  "result": "SUCCESS",
  "output": "server-side diff clean",
  "externalUrl": "https://ci.example/osmu/storage-expansion/pool-1/dry-run",
  "notes": "operator checked diff"
}
```

규칙:

- request status는 `APPROVED`여야 한다.
- `executionType`은 `KUBECTL_DIFF` 또는 `HELM_DIFF`만 허용한다.
- `result`는 `SUCCESS`, `FAILED`, `SKIPPED` 중 하나다.
- `SUCCESS` 또는 `FAILED`는 dry-run `output`이 필요하다. `SKIPPED`는 output 없이 기록 가능하다.
- 응답은 선택한 diff 명령, artifact SHA-256, operator output을 포함하는 execution record를 반환한다.

응답:

```json
{
  "data": {
    "id": 4,
    "requestId": 1,
    "executionType": "KUBECTL_DIFF",
    "result": "SUCCESS",
    "command": "kubectl -n osmu diff -f osmu-storage-expansion-pool-1-bundle.yaml",
    "output": "Storage expansion dry-run evidence...",
    "externalUrl": "https://ci.example/osmu/storage-expansion/pool-1/dry-run",
    "artifactSha256": "64-char-sha256",
    "exitCode": null,
    "timedOut": false
  }
}
```

### POST /api/admin/storage-expansion/requests/{requestId}/dry-run-runner

승인된 Storage Expansion 요청의 현재 manifest bundle을 임시 파일로 만들고 서버에서 `kubectl diff` 또는 `helm diff`를 실행한다. 기본값은 비활성(`OSMU_STORAGE_EXPANSION_RUNNER_ENABLED=false`)이며, 이 경우 실제 command를 실행하지 않고 `SKIPPED` 실행 이력을 남긴다.

요청:

```json
{
  "executionType": "KUBECTL_DIFF"
}
```

규칙:

- request status는 `APPROVED`여야 한다.
- `executionType`은 `KUBECTL_DIFF` 또는 `HELM_DIFF`만 허용한다.
- runner 활성화 환경 변수:
  - `OSMU_STORAGE_EXPANSION_RUNNER_ENABLED=true`
  - `OSMU_STORAGE_EXPANSION_KUBECTL_PATH=kubectl`
  - `OSMU_STORAGE_EXPANSION_HELM_PATH=helm`
  - `OSMU_STORAGE_EXPANSION_HELM_CHART_PATH=./infra/helm/osmu`
  - `OSMU_STORAGE_EXPANSION_NAMESPACE=osmu`
  - `OSMU_STORAGE_EXPANSION_RUNNER_TIMEOUT_SECONDS=30`
- 결과는 `SUCCESS`, `FAILED`, `SKIPPED` 중 하나이며 `exitCode`, `timedOut`, command output, artifact SHA-256을 저장한다.
- 저장되는 runner `command`, `output`, `notes`는 secret masking과 output retention limit을 적용한다.

응답:

```json
{
  "data": {
    "id": 5,
    "requestId": 1,
    "executionType": "KUBECTL_DIFF",
    "result": "SKIPPED",
    "command": "kubectl -n osmu diff -f ...",
    "output": "Storage expansion dry-run runner disabled...",
    "artifactSha256": "64-char-sha256",
    "exitCode": null,
    "timedOut": false,
    "notes": "runner=SKIPPED, exitCode=-, timedOut=false"
  }
}
```

### POST /api/admin/storage-expansion/requests/{requestId}/apply-runner

승인된 Storage Expansion 요청의 현재 manifest bundle을 서버에서 실제 적용 명령으로 실행한다. 기본값은 비활성(`OSMU_STORAGE_EXPANSION_APPLY_RUNNER_ENABLED=false`)이며, 이 경우 command를 실행하지 않고 `APPLY / SKIPPED` 실행 이력을 남기며 request 상태는 `APPROVED`로 유지한다. runner 활성 상태에서 command가 `SUCCESS`이면 같은 실행 이력을 근거로 request를 `APPLIED`로 자동 전환한다.

요청:

```json
{
  "applyType": "KUBECTL_APPLY"
}
```

규칙:

- request status는 `APPROVED`여야 한다.
- `applyType`은 `KUBECTL_APPLY` 또는 `HELM_UPGRADE`만 허용한다.
- 안전 gate:
  - `OSMU_STORAGE_EXPANSION_APPLY_RUNNER_ENABLED=true`
  - `OSMU_STORAGE_EXPANSION_POST_RUN_VERIFIER_ENABLED=true`
  - `OSMU_STORAGE_EXPANSION_POST_RUN_BUCKET_PREFIX=osmu-expansion-smoke`
  - command path, namespace, timeout은 dry-run runner와 같은 `OSMU_STORAGE_EXPANSION_KUBECTL_PATH`, `OSMU_STORAGE_EXPANSION_HELM_PATH`, `OSMU_STORAGE_EXPANSION_HELM_CHART_PATH`, `OSMU_STORAGE_EXPANSION_NAMESPACE`, `OSMU_STORAGE_EXPANSION_RUNNER_TIMEOUT_SECONDS`를 사용한다.
- apply command가 `SUCCESS`이면 post-run verifier가 database health, object storage health, S3 put/get/list smoke를 자동 실행한다.
- post-run verifier가 실패하면 execution result는 `FAILED`로 기록되고 request 상태는 `APPLIED`로 자동 전환되지 않는다.
- 저장되는 apply runner `command`, `output`, `notes`는 secret masking과 output retention limit을 적용한다.
- 결과는 `execution`과 현재 `request`를 함께 반환한다.

응답:

```json
{
  "data": {
    "execution": {
      "id": 6,
      "requestId": 1,
      "executionType": "APPLY",
      "result": "SKIPPED",
      "command": "kubectl -n osmu apply --server-side -f ...",
      "output": "Storage expansion apply runner disabled...",
      "artifactSha256": "64-char-sha256",
      "exitCode": null,
      "timedOut": false,
      "notes": "applyType=KUBECTL_APPLY, runner=SKIPPED, exitCode=-, timedOut=false"
    },
    "request": {
      "id": 1,
      "status": "APPROVED"
    }
  }
}
```

### POST /api/admin/storage-expansion/requests/{requestId}/rollback-runner

`APPLIED` 상태 Storage Expansion 요청에 대해 서버에서 rollback 명령을 실행하고 `ROLLBACK` 실행 이력을 기록한다. 기본값은 비활성(`OSMU_STORAGE_EXPANSION_ROLLBACK_RUNNER_ENABLED=false`)이며, 이 경우 command를 실행하지 않고 `ROLLBACK / SKIPPED`만 기록한다. rollback은 상태를 자동으로 되돌리지 않고, 운영 evidence 추적용으로 남긴다.

요청:

```json
{
  "rollbackType": "HELM_ROLLBACK",
  "helmRevision": 1
}
```

규칙:

- request status는 `APPLIED`여야 한다.
- `rollbackType`은 `HELM_ROLLBACK` 또는 `KUBECTL_ROLLOUT_UNDO`만 허용한다.
- `HELM_ROLLBACK`은 `helm rollback osmu-minio [revision]`을 실행한다.
- `KUBECTL_ROLLOUT_UNDO`는 `kubectl -n {namespace} rollout undo {target}`을 실행하며 기본 target은 `statefulset/osmu-minio`다.
- 안전 gate: `OSMU_STORAGE_EXPANSION_ROLLBACK_RUNNER_ENABLED=true`, `OSMU_STORAGE_EXPANSION_POST_RUN_VERIFIER_ENABLED=true`.
- rollback command가 `SUCCESS`이면 post-run verifier가 database health, object storage health, S3 put/get/list smoke를 자동 실행하고 결과를 execution output/notes에 남긴다.
- 저장되는 rollback runner `command`, `output`, `notes`는 secret masking과 output retention limit을 적용한다.

응답:

```json
{
  "data": {
    "execution": {
      "id": 7,
      "requestId": 1,
      "executionType": "ROLLBACK",
      "result": "SKIPPED",
      "command": "helm rollback osmu-minio 1",
      "output": "Storage expansion rollback runner disabled...",
      "artifactSha256": "64-char-sha256",
      "exitCode": null,
      "timedOut": false,
      "notes": "rollbackType=HELM_ROLLBACK, helmRevision=1, runner=SKIPPED, exitCode=-, timedOut=false"
    },
    "request": {
      "id": 1,
      "status": "APPLIED"
    }
  }
}
```

### POST /api/admin/storage-expansion/requests/{requestId}/gitops-plan

승인된 증설 요청을 실제 GitOps PR로 옮기기 전에 필요한 초안 정보를 생성한다. 현재 MVP는 GitHub push/PR 생성은 하지 않고, 브랜치명, 커밋 메시지, PR 제목/본문, 변경 파일 경로, review checklist, manifest bundle SHA-256을 반환한다.

조건:

- ADMIN 전용.
- request status가 `APPROVED`여야 한다.
- `PLANNED`, `REJECTED`, `APPLIED` 요청은 400.

응답:

```json
{
  "data": {
    "requestId": 1,
    "poolName": "pool-1",
    "status": "APPROVED",
    "ready": true,
    "referenceOnly": true,
    "branchName": "storage-expansion/pool-1",
    "commitMessage": "[Feat][I] : storage expansion pool-1 GitOps manifest draft",
    "pullRequestTitle": "[I] Storage expansion pool-1 GitOps draft",
    "pullRequestBody": "Storage expansion GitOps draft...",
    "manifestPath": "infra/gitops/storage-expansion/pool-1/tenant-patch.yaml",
    "valuesPath": "infra/gitops/storage-expansion/pool-1/helm-values.yaml",
    "artifactSha256": "64-char-sha256",
    "changedFiles": [
      "infra/gitops/storage-expansion/pool-1/tenant-patch.yaml",
      "infra/gitops/storage-expansion/pool-1/helm-values.yaml",
      "infra/gitops/storage-expansion/pool-1/README.md"
    ],
    "reviewChecklist": [
      "Run helm diff or helm upgrade --dry-run with helm-values.yaml."
    ]
  }
}
```

### GET /api/admin/storage-expansion/requests/{requestId}/gitops-artifacts/bundle

승인된 증설 요청의 GitOps 초안 파일을 ZIP으로 내려받는다. ZIP에는 `tenant-patch.yaml`, `helm-values.yaml`, `README.md`가 `infra/gitops/storage-expansion/{poolName}/` 경로로 포함된다. 실제 PR 자동 생성 전 수동 GitOps 적용, 운영 티켓 첨부, review 자료로 사용한다.

조건:

- ADMIN 전용.
- request status가 `APPROVED`여야 한다.
- 응답 content type은 `application/zip`.

### POST /api/admin/storage-expansion/requests/{requestId}/gitops-pr-runner

승인된 Storage Expansion 요청의 GitOps artifact를 설정된 repository에 쓰고 branch/commit/PR 생성을 실행한다. 기본값은 비활성(`OSMU_STORAGE_EXPANSION_GITOPS_PR_RUNNER_ENABLED=false`)이며, 비활성 상태에서는 실제 git/gh 명령을 실행하지 않고 `GITOPS_PR / SKIPPED` execution record를 남긴다.

응답:

```json
{
  "data": {
    "requestId": 1,
    "executionType": "GITOPS_PR",
    "result": "SKIPPED",
    "command": "git checkout -B storage-expansion/pool-1 && git add ... && gh pr create ...",
    "output": "Storage expansion GitOps PR runner disabled...",
    "externalUrl": null,
    "artifactSha256": "64-char-sha256",
    "timedOut": false,
    "notes": "gitOpsPrRunner=SKIPPED, exitCode=-, timedOut=false, externalUrl=-, failureReason=-"
  }
}
```

설정:

- `OSMU_STORAGE_EXPANSION_GITOPS_PR_RUNNER_ENABLED=false`
- `OSMU_STORAGE_EXPANSION_GITOPS_REPOSITORY_PATH=`
- `OSMU_STORAGE_EXPANSION_GIT_PATH=git`
- `OSMU_STORAGE_EXPANSION_GH_PATH=gh`
- `OSMU_STORAGE_EXPANSION_GITOPS_BASE_BRANCH=main`
- `OSMU_STORAGE_EXPANSION_GITOPS_PR_RUNNER_TIMEOUT_SECONDS=60`

활성화 시 runner는 shell을 거치지 않고 `git checkout -B`를 먼저 실행한 뒤 repository 내부 경로에만 artifact를 쓰고, `git add`, `git commit`, `git push -u origin {branch}`, `gh pr create`를 순차 실행한다. 각 command는 fail-fast로 처리되어 실패 이후 command는 실행하지 않는다. artifact path가 repository 밖으로 벗어나면 실패한다. `gh pr create` 출력에서 첫 HTTP(S) URL을 찾아 execution `externalUrl`로 저장한다. 실패 시 notes에는 `failureReason`을 저장하고 execution response의 `failureReason` 필드로도 내려준다. 값은 `TIMEOUT`, `AUTHENTICATION`, `AUTHORIZATION`, `BRANCH_PROTECTION`, `NO_CHANGES`, `DIRTY_WORKTREE`, `TOOL_MISSING`, `REPOSITORY_CONFIG`, `UNKNOWN` 중 하나다.

### GET /api/admin/storage-expansion/requests/{requestId}/executions

증설 요청의 dry-run, GitOps PR, Helm diff, kubectl diff, apply, rollback 실행 이력을 조회한다. 실제 executor가 붙기 전에는 운영자가 수동으로 수행한 결과를 기록하고 검토하는 용도로 사용한다.

응답:

```json
{
  "items": [
    {
      "id": 1,
      "requestId": 1,
      "executionType": "HELM_DIFF",
      "result": "SUCCESS",
      "command": "helm diff upgrade osmu-minio ./infra/helm/osmu -f helm-values.yaml",
      "output": "No drift detected",
      "externalUrl": "https://git.example/osmu/pull/42",
      "artifactSha256": "64-char-sha256",
      "notes": "operator approved dry-run",
      "failureReason": null,
      "createdBy": "admin",
      "createdAt": "2026-06-15T06:30:00+09:00"
    }
  ]
}
```

### POST /api/admin/storage-expansion/requests/{requestId}/gitops-pr-execution

승인된 Storage Expansion 요청에 대해 GitOps PR evidence를 표준 실행 이력으로 기록한다. 실제 GitHub/GitLab API 호출은 아직 수행하지 않고, 외부에서 생성한 PR URL과 선택 evidence를 검증해 `GITOPS_PR / SUCCESS` record로 남긴다.

요청:

```json
{
  "externalUrl": "https://git.example/osmu/pull/42",
  "mergeSha": "abcdef1234567890",
  "pipelineUrl": "https://ci.example/osmu/storage-expansion/pool-1",
  "notes": "operator approved GitOps PR"
}
```

규칙:

- request status는 `APPROVED`여야 한다.
- `externalUrl`은 필수이고 `http://` 또는 `https://` URL이어야 한다.
- `mergeSha`는 선택이며 7~64자 Git SHA 형식이어야 한다.
- 응답은 `executionType = GITOPS_PR`, `result = SUCCESS`, current GitOps artifact SHA-256, PR 생성 명령 초안, changed files/checklist output을 포함한다.
- 이 record는 `POST /api/admin/storage-expansion/requests/{requestId}/executions/{executionId}/apply`의 APPLIED evidence로 사용할 수 있다.

응답:

```json
{
  "data": {
    "id": 5,
    "requestId": 1,
    "executionType": "GITOPS_PR",
    "result": "SUCCESS",
    "command": "git checkout -b storage-expansion/pool-1 && ...",
    "externalUrl": "https://git.example/osmu/pull/42",
    "artifactSha256": "64-char-sha256",
    "notes": "mergeSha=abcdef1234567890"
  }
}
```

### POST /api/admin/storage-expansion/requests/{requestId}/executions

증설 요청의 실행 결과를 기록한다. `APPROVED` 또는 `APPLIED` 요청에만 기록할 수 있다.

허용값:

- `executionType`: `DRY_RUN`, `GITOPS_PR`, `HELM_DIFF`, `KUBECTL_DIFF`, `APPLY`, `ROLLBACK`
- `result`: `SUCCESS`, `FAILED`, `SKIPPED`
- `artifactSha256`: 선택값이며 있으면 64자 SHA-256 hex 문자열

### POST /api/admin/storage-expansion/requests/{requestId}/executions/{executionId}/apply

Approved storage expansion request를 성공한 실행 기록 기준으로 `APPLIED` 처리한다. 수동 evidence 입력 대신 실행 기록의 `externalUrl`, `command`, `artifactSha256`, `notes` 중 사용 가능한 값을 `appliedEvidence`로 자동 연결한다.

규칙:

- request status는 `APPROVED`여야 한다.
- execution record는 같은 request에 속해야 한다.
- execution `result`는 `SUCCESS`여야 한다.
- execution `executionType`은 `APPLY` 또는 `GITOPS_PR`이어야 한다.
- 성공 시 request status는 `APPLIED`, `appliedBy`는 현재 admin, `appliedEvidence`는 실행 기록 기반 문자열로 저장된다.

응답:

```json
{
  "data": {
    "id": 1,
    "poolName": "pool-1",
    "status": "APPLIED",
    "appliedBy": "admin",
    "appliedEvidence": "execution APPLY #5: https://ci.example/osmu/storage-expansion/pool-1"
  }
}
```

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

### GET /api/admin/dashboard/readiness

Admin dashboard readiness snapshot. `ADMIN` required.

The response combines runtime, backup, quota, sharing, and operations-readiness gates. When the configured files exist, the backend reads `.osmu-run/latest-operations-readiness.json`, `.osmu-run/latest-operations-evidence-plan.json`, `.osmu-run/latest-operations-evidence-plan-invocation.json`, `.osmu-run/latest-operations-invocation-unblock-plan.json`, `.osmu-run/latest-operations-dispatch-preflight.json`, `.osmu-run/latest-operations-workflow-run-ids.json`, `.osmu-run/latest-operations-artifact-collection-plan.json`, `.osmu-run/latest-operations-readiness-artifact-import.json`, `.osmu-run/latest-operations-readiness-finalize.json`, `.osmu-run/latest-operations-evidence-handoff.json`, `.osmu-run/latest-operations-readiness-convergence.json`, and `.osmu-run/latest-kubernetes-operations-report-sync.json`. Non-ready operations evidence is returned as `OPERATIONS` items, usually targeting `dashboard-readiness-panel`. Individual pending operations checks can include optional `evidencePath`, `remediationCommand`, `remediationWorkflow`, `remediationWorkflowCommand`, and `remediationNote` fields copied from the operations readiness report. The generated operations evidence plan is exposed as an `OPERATIONS_EVIDENCE_PLAN` item with its plan path and regeneration command, and as a structured `operationsEvidencePlan` object with ordered executable actions. The guarded invocation report is exposed as an `OPERATIONS_EVIDENCE_PLAN_INVOCATION` item and as `operationsEvidenceInvocation`, showing planned/blocked/executed counts plus action block reasons before live workflow dispatch. The invocation unblock plan is exposed as an `OPERATIONS_INVOCATION_UNBLOCK_PLAN` item and as `operationsInvocationUnblockPlan`, showing required confirmations, placeholders, ambiguous repeated placeholders, action order lists, and copyable follow-up plan commands before live dispatch. The dispatch preflight is exposed as an `OPERATIONS_DISPATCH_PREFLIGHT` item and as `operationsDispatchPreflight`, showing failed checks, missing inputs, required GitHub secrets, workflow file presence, and plan/execute command previews when ready. The workflow run id plan is exposed as an `OPERATIONS_WORKFLOW_RUN_ID_PLAN` item and as `operationsWorkflowRunIdPlan`, showing query commands and recommended run-id handoff state after workflow dispatch. The artifact collection plan is exposed as an `OPERATIONS_ARTIFACT_COLLECTION_PLAN` item and as `operationsArtifactCollectionPlan`, showing missing run ids, expected artifact names, `gh run download` commands, finalizer dispatch commands, and the local import command before readiness artifact import. The readiness artifact import report is exposed as an `OPERATIONS_READINESS_ARTIFACT_IMPORT` item and as `operationsReadinessArtifactImport`, showing import status, imported/failed counts, source/destination paths, and the no-secret import policy. The readiness finalizer report is exposed as an `OPERATIONS_READINESS_FINALIZER` item and as `operationsReadinessFinalize`, showing selected finalizer steps, final readiness result, gaps, commands, step results, and the secret masking policy. The evidence handoff is exposed as an `OPERATIONS_EVIDENCE_HANDOFF` item and as `operationsEvidenceHandoff`, showing the current bottleneck, next command, stage readiness, missing evidence counts, and finalizer failed/gap counts. The convergence report is exposed as an `OPERATIONS_READINESS_CONVERGENCE` item and as `operationsReadinessConvergence`, showing the final ready/action-required decision, current bottleneck, recommended command chain, stage counts, Kubernetes report sync readiness/result/failure count, and no-execute safety policy.

Response:

```json
{
  "data": {
    "status": "REVIEW",
    "runtimeProfile": "Local demo runtime",
    "blockerCount": 0,
    "warningCount": 12,
    "blockers": [],
    "warnings": [
      "Operations readiness remains pending: passed=36 pending=6."
    ],
    "severitySummaries": [
      { "severity": "WARNING", "count": 12 }
    ],
    "categorySummaries": [
      { "category": "OPERATIONS", "totalCount": 12, "blockerCount": 0, "warningCount": 12 }
    ],
    "items": [
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_READINESS_PENDING",
        "message": "Operations readiness remains pending: passed=36 pending=6.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Operations readiness"
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_READINESS_CHECK",
        "message": "Operations readiness pending: Kubernetes DR finalizer live evidence / ha-dr - report not found.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Evidence",
        "evidencePath": ".osmu-run/latest-kubernetes-dr-finalize.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\finalize-kubernetes-dr-drill.ps1 -BackupTimestamp <YYYYMMDDTHHMMSSZ> -ConfirmRestore",
        "remediationWorkflow": ".github/workflows/kubernetes-dr-finalizer-ci.yml",
        "remediationWorkflowCommand": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true",
        "remediationNote": "Use a real backup timestamp and confirmed restore only after operator approval."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_EVIDENCE_PLAN",
        "message": "Operations evidence plan is action-required: actionCount=6, unplannedCount=0.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Evidence plan",
        "evidencePath": ".osmu-run/latest-operations-evidence-plan.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-evidence-plan.ps1",
        "remediationNote": "Review the ordered evidence plan before running live Kubernetes or security evidence workflows."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_EVIDENCE_PLAN_INVOCATION",
        "message": "Operations evidence invocation is blocked: selectedActionCount=6, plannedCount=1, blockedCount=5.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Evidence invocation",
        "evidencePath": ".osmu-run/latest-operations-evidence-plan-invocation.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1",
        "remediationNote": "Review blocked/planned invocation actions before dispatching live Kubernetes or security evidence workflows."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_INVOCATION_UNBLOCK_PLAN",
        "message": "Operations invocation unblock plan is action-required: blockedActions=5, requiredPlaceholders=6, ambiguousPlaceholders=2.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Invocation unblock",
        "evidencePath": ".osmu-run/latest-operations-invocation-unblock-plan.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1",
        "remediationWorkflowCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,3,4,5,6 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>",
        "remediationNote": "Resolve placeholders, confirm operator approval when required, confirm OSMU_KUBECONFIG_BASE64 readiness when required, then rerun invoke-operations-evidence-plan.ps1 in plan-only mode before using -Execute."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_DISPATCH_PREFLIGHT",
        "message": "Operations dispatch preflight is action-required: failedChecks=3, missingInputs=6, warnings=2.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Dispatch preflight",
        "evidencePath": ".osmu-run/latest-operations-dispatch-preflight.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-dispatch-preflight.ps1",
        "remediationNote": "Run the ready plan command first without -Execute."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_WORKFLOW_RUN_ID_PLAN",
        "message": "Operations workflow run id plan is query-required: workflows=6, missingRuns=6.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Workflow run ids",
        "evidencePath": ".osmu-run/latest-operations-workflow-run-ids.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1",
        "remediationNote": "Use the generated gh run list commands after workflow dispatch, then regenerate the artifact collection plan with recommended run ids."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_ARTIFACT_COLLECTION_PLAN",
        "message": "Operations artifact collection plan is action-required: artifacts=6, missingRequired=4.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Artifact collection",
        "evidencePath": ".osmu-run/latest-operations-artifact-collection-plan.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1",
        "remediationWorkflow": ".github/workflows/operations-readiness-artifact-finalizer-ci.yml",
        "remediationWorkflowCommand": "gh workflow run operations-readiness-artifact-finalizer-ci.yml -f storage_expansion_run_id=<storage-expansion-run-id>",
        "remediationNote": "Fill workflow run ids after evidence workflow dispatch, then import artifacts locally or through the operations artifact finalizer workflow."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_READINESS_ARTIFACT_IMPORT",
        "message": "Operations readiness artifact import is failed: status=artifact-import-failed, failedCount=2.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Evidence artifacts",
        "evidencePath": ".osmu-run/latest-operations-readiness-artifact-import.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\import-operations-readiness-artifacts.ps1",
        "remediationWorkflow": ".github/workflows/operations-readiness-artifact-finalizer-ci.yml",
        "remediationNote": "Artifact import copies only JSON/Markdown evidence files and does not read kubeconfig, registry tokens, DR secrets, or bearer tokens."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_READINESS_FINALIZER",
        "message": "Operations readiness finalizer is pending: readinessResult=pending, failedCount=0.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Operations finalizer",
        "evidencePath": ".osmu-run/latest-operations-readiness-finalize.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\finalize-operations-readiness.ps1",
        "remediationWorkflow": ".github/workflows/operations-readiness-finalizer-ci.yml",
        "remediationNote": "Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_EVIDENCE_HANDOFF",
        "message": "Operations evidence handoff is blocked: next=resolve-invocation-blockers, blockedActions=5, missingRuns=6, missingArtifacts=4, finalizerGaps=1.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Evidence handoff",
        "evidencePath": ".osmu-run/latest-operations-evidence-handoff.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1",
        "remediationNote": "The invocation report still has blocked actions. Generate the unblock plan, fill placeholders, confirm operator approvals, and confirm kubeconfig-secret readiness before dispatch."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "OPERATIONS_READINESS_CONVERGENCE",
        "message": "Operations readiness convergence is action-required: bottleneck=resolve-invocation-blockers, stages=1/7, finalizerGaps=1.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Convergence",
        "evidencePath": ".osmu-run/latest-operations-readiness-convergence.json",
        "remediationCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1",
        "remediationNote": "The invocation report still has blocked actions. This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance."
      },
      {
        "severity": "WARNING",
        "category": "OPERATIONS",
        "code": "KUBERNETES_OPERATIONS_REPORT_SYNC",
        "message": "Kubernetes operations report sync is planned: namespace=osmu, configMap=osmu-operations-reports, failedCount=0.",
        "targetPage": "dashboard",
        "targetPanel": "dashboard-readiness-panel",
        "actionLabel": "Kubernetes sync",
        "evidencePath": ".osmu-run/latest-kubernetes-operations-report-sync.json",
        "remediationCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=server -o yaml",
        "remediationWorkflow": ".github/workflows/kubernetes-operations-report-sync-ci.yml",
        "remediationWorkflowCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=client -o yaml | kubectl apply -f -",
        "remediationNote": "This script writes to Kubernetes only when -Apply is supplied. -ServerDryRunOnly talks to the API server without persisting changes. The default and -PlanOnly modes do not execute kubectl."
      }
    ],
    "operationsEvidencePlan": {
      "result": "action-required",
      "sourceSummary": "passed=36 pending=6",
      "pendingCount": 6,
      "actionCount": 6,
      "unplannedCount": 0,
      "actions": [
        {
          "order": 1,
          "name": "Kubernetes DR finalizer live evidence",
          "category": "ha-dr",
          "actionType": "kubernetes-live",
          "evidencePath": ".osmu-run/latest-kubernetes-dr-finalize.json",
          "requiredEvidence": "finalizer result=ready from target cluster restore drill",
          "workflowCommand": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true",
          "recommendedCommand": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true",
          "operatorInputs": ["<YYYYMMDDTHHMMSSZ>"],
          "hasPlaceholders": true,
          "requiresOperatorApproval": true,
          "requiresKubeconfigSecret": true
        }
      ]
    },
    "operationsEvidenceInvocation": {
      "result": "blocked",
      "sourceSummary": "passed=36 pending=6",
      "sourcePlan": ".osmu-run/latest-operations-evidence-plan.json",
      "commandMode": "Workflow",
      "executionMode": "plan-only",
      "selectedActionCount": 6,
      "plannedCount": 1,
      "blockedCount": 5,
      "executedCount": 0,
      "failedCount": 0,
      "actions": [
        {
          "order": 1,
          "name": "Kubernetes DR finalizer live evidence",
          "category": "ha-dr",
          "actionType": "kubernetes-live",
          "evidencePath": ".osmu-run/latest-kubernetes-dr-finalize.json",
          "commandMode": "Workflow",
          "command": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true",
          "status": "blocked",
          "blockReasons": ["unresolved placeholders: <YYYYMMDDTHHMMSSZ>", "operator approval not confirmed"],
          "unresolvedPlaceholders": ["<YYYYMMDDTHHMMSSZ>"],
          "requiresOperatorApproval": true,
          "requiresKubeconfigSecret": true
        }
      ]
    },
    "operationsInvocationUnblockPlan": {
      "result": "action-required",
      "sourceInvocationReport": ".osmu-run/latest-operations-evidence-plan-invocation.json",
      "sourceResult": "blocked",
      "sourceSummary": "passed=36 pending=6",
      "selectedActionCount": 6,
      "plannedCount": 1,
      "blockedCount": 5,
      "failedCount": 0,
      "needsKubeconfigSecretConfirmation": true,
      "needsOperatorApprovalConfirmation": true,
      "requiredPlaceholderCount": 6,
      "ambiguousRepeatedPlaceholderCount": 2,
      "blockedActionOrders": [1, 2, 3, 4, 5],
      "plannedActionOrders": [6],
      "confirmedPlanCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,3,4,5,6 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>",
      "blockedOnlyPlanCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,3,4,5 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>",
      "plannedOnlyCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
      "decisionRule": "Resolve placeholders and confirmations before execution.",
      "actions": [
        {
          "order": 1,
          "name": "Kubernetes DR finalizer live evidence",
          "category": "ha-dr",
          "actionType": "kubernetes-live",
          "evidencePath": ".osmu-run/latest-kubernetes-dr-finalize.json",
          "status": "blocked",
          "commandMode": "Workflow",
          "command": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f backup_timestamp=<YYYYMMDDTHHMMSSZ> -f confirm_restore=true",
          "blockReasons": ["unresolved placeholders: <YYYYMMDDTHHMMSSZ>", "operator approval not confirmed"],
          "unresolvedPlaceholders": ["<YYYYMMDDTHHMMSSZ>"],
          "needsOperatorApprovalConfirmation": true,
          "needsKubeconfigSecretConfirmation": true,
          "requiredInputs": [
            {
              "placeholder": "<YYYYMMDDTHHMMSSZ>",
              "parameter": "BackupTimestamp",
              "valueTemplate": "<YYYYMMDDTHHMMSSZ>",
              "occurrenceCount": 1,
              "ambiguousRepeatedPlaceholder": false
            }
          ],
          "planCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"
        }
      ]
    },
    "operationsDispatchPreflight": {
      "result": "action-required",
      "sourceUnblockPlan": ".osmu-run/latest-operations-invocation-unblock-plan.json",
      "sourceResult": "action-required",
      "selectedActionCount": 6,
      "selectedActionOrders": [1, 2, 3, 4, 5, 6],
      "needsKubeconfigSecretConfirmation": true,
      "needsOperatorApprovalConfirmation": true,
      "requiredInputCount": 6,
      "missingInputCount": 6,
      "ambiguousInputCount": 2,
      "failedCheckCount": 3,
      "warningCheckCount": 2,
      "requiredGitHubSecrets": ["OSMU_KUBECONFIG_BASE64", "OSMU_ADMIN_PASSWORD", "GITHUB_TOKEN"],
      "workflowFiles": [
        {
          "actionOrder": 1,
          "workflow": "storage-expansion-finalizer-ci.yml",
          "path": ".github/workflows/storage-expansion-finalizer-ci.yml",
          "exists": true,
          "requiredSecrets": ["OSMU_KUBECONFIG_BASE64", "OSMU_ADMIN_PASSWORD"]
        }
      ],
      "checks": [
        {
          "code": "KUBECONFIG_SECRET_CONFIRMED",
          "status": "fail",
          "message": "Selected actions require OSMU_KUBECONFIG_BASE64 readiness confirmation."
        }
      ],
      "requiredInputs": [
        {
          "actionOrder": 3,
          "placeholder": "<YYYYMMDDTHHMMSSZ>",
          "parameter": "BackupTimestamp",
          "supplied": false,
          "ambiguousRepeatedPlaceholder": false
        }
      ],
      "decisionRule": "Run the ready plan command first without -Execute."
    },
    "operationsWorkflowRunIdPlan": {
      "result": "query-required",
      "sourceInvocationReport": ".osmu-run/latest-operations-evidence-plan-invocation.json",
      "invocationResult": "blocked",
      "branch": "main",
      "queryMode": "plan-only",
      "workflowCount": 7,
      "readyWorkflowCount": 0,
      "missingWorkflowCount": 7,
      "artifactCollectionPlanCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha abc123",
      "securityEvidenceFinalizerCommand": "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id>",
      "workflows": [
        {
          "workflow": "storage-expansion-finalizer-ci.yml",
          "group": "storage-expansion",
          "queryCommand": "gh run list --workflow storage-expansion-finalizer-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
          "candidateCount": 0,
          "runIdParameter": "StorageExpansionRunId",
          "artifactName": "storage-expansion-finalizer-<run-id>",
          "readyForArtifactDownload": false
        }
      ]
    },
    "operationsArtifactCollectionPlan": {
      "result": "action-required",
      "sourceInvocationReport": ".osmu-run/latest-operations-evidence-plan-invocation.json",
      "invocationResult": "blocked",
      "invocationSummary": "selected=6 planned=1 blocked=5 executed=0 failed=0",
      "artifactCount": 7,
      "requiredArtifactCount": 5,
      "readyArtifactCount": 0,
      "missingRequiredArtifactCount": 5,
      "operationsArtifactFinalizerCommand": "gh workflow run operations-readiness-artifact-finalizer-ci.yml -f storage_expansion_run_id=<storage-expansion-run-id> -f kubernetes_operations_report_sync_run_id=<kubernetes-operations-report-sync-run-id>",
      "localImportCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\import-operations-readiness-artifacts.ps1 -StorageExpansionArtifactPath .\\.osmu-run\\operations-readiness-artifacts\\storage-expansion -KubernetesOperationsReportSyncArtifactPath .\\.osmu-run\\operations-readiness-artifacts\\kubernetes-operations-report-sync",
      "artifacts": [
        {
          "group": "storage-expansion",
          "workflow": "storage-expansion-finalizer-ci.yml",
          "runId": "<storage-expansion-run-id>",
          "artifactName": "storage-expansion-finalizer-<storage-expansion-run-id>",
          "downloadCommand": "gh run download <storage-expansion-run-id> -n storage-expansion-finalizer-<storage-expansion-run-id> -D .osmu-run/operations-readiness-artifacts/storage-expansion",
          "requiredForReadiness": true,
          "ready": false
        },
        {
          "group": "kubernetes-operations-report-sync",
          "workflow": "kubernetes-operations-report-sync-ci.yml",
          "runId": "<kubernetes-operations-report-sync-run-id>",
          "artifactName": "kubernetes-operations-report-sync-<kubernetes-operations-report-sync-run-id>",
          "downloadCommand": "gh run download <kubernetes-operations-report-sync-run-id> -n kubernetes-operations-report-sync-<kubernetes-operations-report-sync-run-id> -D .osmu-run/operations-readiness-artifacts/kubernetes-operations-report-sync",
          "requiredForReadiness": true,
          "ready": false
        }
      ]
    },
    "operationsReadinessArtifactImport": {
      "result": "failed",
      "status": "artifact-import-failed",
      "selectedGroupCount": 2,
      "importedCount": 1,
      "failedCount": 2,
      "outputDirectory": ".osmu-run",
      "secretPolicy": "Artifact import copies only JSON/Markdown evidence files and does not read kubeconfig, registry tokens, DR secrets, or bearer tokens.",
      "entries": [
        {
          "group": "ha-dr-readiness",
          "fileName": "latest-kubernetes-ha-dr-readiness.json",
          "status": "failed",
          "passed": false,
          "detail": "result=failed expected=passed",
          "sourcePath": ".osmu-run/operations-readiness-artifacts/ha-dr/latest-kubernetes-ha-dr-readiness.json"
        },
        {
          "group": "iam-rbac",
          "fileName": "latest-iam-rbac-finalize.json",
          "status": "imported",
          "passed": true,
          "detail": "promoted to standard operations readiness path",
          "sourcePath": ".osmu-run/operations-readiness-artifacts/iam/latest-iam-rbac-finalize.json",
          "destinationPath": ".osmu-run/latest-iam-rbac-finalize.json"
        }
      ]
    },
    "operationsReadinessFinalize": {
      "result": "pending",
      "status": "operations-readiness-finalize-pending",
      "readinessResult": "pending",
      "readinessSummary": "passed=36 pending=6",
      "namespace": "osmu",
      "sourceNamespace": "osmu",
      "restoreNamespace": "osmu-restore-drill",
      "backupTimestamp": "20260616T010203Z",
      "powerShellCommand": "pwsh",
      "failedCount": 0,
      "selectedSteps": {
        "storageExpansionFinalizer": true,
        "haDrReadiness": true,
        "kubernetesDrFinalizer": false,
        "iamRbacFinalizer": true,
        "securityEvidenceFinalizer": true
      },
      "paths": {
        "operationsReadinessJson": ".osmu-run/latest-operations-readiness.json",
        "operationsReadinessMarkdown": ".osmu-run/latest-operations-readiness.md",
        "report": ".osmu-run/latest-operations-readiness-finalize.json",
        "summary": ".osmu-run/latest-operations-readiness-finalize.md"
      },
      "commands": [
        {
          "name": "Operations readiness report",
          "script": ".\\scripts\\write-operations-readiness.ps1",
          "arguments": ["-JsonOutputPath", ".osmu-run/latest-operations-readiness.json"],
          "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-readiness.ps1"
        }
      ],
      "steps": [
        {
          "name": "Operations readiness report",
          "script": ".\\scripts\\write-operations-readiness.ps1",
          "result": "passed",
          "exitCode": 0
        }
      ],
      "gaps": ["Operations readiness result is pending: passed=36 pending=6."],
      "secretPolicy": "Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens."
    },
    "operationsEvidenceHandoff": {
      "result": "blocked",
      "generatedAt": "2026-06-16T07:15:09+09:00",
      "nextStep": {
        "code": "resolve-invocation-blockers",
        "title": "Resolve invocation blockers",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1",
        "reason": "The invocation report still has blocked actions.",
        "note": "Generate the unblock plan, fill placeholders, confirm operator approvals, and confirm kubeconfig-secret readiness before dispatch."
      },
      "stageCount": 7,
      "readyStageCount": 1,
      "blockedActionCount": 5,
      "missingWorkflowRunCount": 6,
      "missingRequiredArtifactCount": 4,
      "failedImportCount": 0,
      "finalizerFailedCount": 0,
      "finalizerGapCount": 1,
      "stages": [
        {
          "name": "evidence-invocation",
          "reportPath": ".osmu-run/latest-operations-evidence-plan-invocation.json",
          "exists": true,
          "result": "blocked",
          "summary": "selected=6 planned=1 blocked=5 failed=0",
          "ready": false,
          "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1"
        }
      ]
    },
    "operationsReadinessConvergence": {
      "result": "action-required",
      "generatedAt": "2026-06-16T08:45:40+09:00",
      "handoffReportPath": ".osmu-run/latest-operations-evidence-handoff.json",
      "readinessReportPath": ".osmu-run/latest-operations-readiness.json",
      "operationsReadinessFinalizeReportPath": ".osmu-run/latest-operations-readiness-finalize.json",
      "kubernetesOperationsReportSyncReportPath": ".osmu-run/latest-kubernetes-operations-report-sync.json",
      "handoffExists": true,
      "handoffResult": "blocked",
      "readinessExists": true,
      "readinessResult": "pending",
      "readinessSummary": "passed=36 pending=6",
      "finalizerExists": true,
      "finalizerResult": "pending",
      "finalizerReadinessResult": "pending",
      "finalizerFailedCount": 0,
      "kubernetesReportSyncExists": true,
      "kubernetesReportSyncResult": "planned",
      "kubernetesReportSyncFailedCount": 0,
      "kubernetesReportSyncConfigMapName": "osmu-operations-reports",
      "kubernetesReportSyncConfigMapKey": "latest-operations-readiness-convergence.json",
      "kubernetesReportSyncSourceReportResult": "action-required",
      "kubernetesReportSyncReady": false,
      "finalizerGapCount": 1,
      "stageCount": 7,
      "readyStageCount": 1,
      "blockedActionCount": 5,
      "missingWorkflowRunCount": 6,
      "missingRequiredArtifactCount": 4,
      "failedImportCount": 0,
      "currentBottleneck": {
        "code": "resolve-invocation-blockers",
        "title": "Resolve invocation blockers",
        "reason": "The invocation report still has blocked actions.",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1"
      },
      "recommendedCommands": [
        {
          "order": 1,
          "name": "Resolve invocation blockers",
          "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1",
          "reason": "The invocation report still has blocked actions."
        }
      ],
      "decisionRule": "Operations readiness convergence is ready only when the handoff result is ready/none, the readiness report is ready, any finalizer report confirms readinessResult=ready, and the Kubernetes operations report sync evidence confirms result=applied with zero failed checks.",
      "safetyPolicy": "This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance."
    },
    "kubernetesOperationsReportSync": {
      "result": "planned",
      "generatedAt": "2026-06-16T08:50:40+09:00",
      "namespace": "osmu",
      "configMapName": "osmu-operations-reports",
      "configMapKey": "latest-operations-readiness-convergence.json",
      "sourceReportPath": ".osmu-run/latest-operations-readiness-convergence.json",
      "sourceReportFormatVersion": "osmu.operations-readiness-convergence.v1",
      "sourceReportResult": "action-required",
      "sourceReportBytes": 5249,
      "sourceReportSha256": "abc123",
      "clientDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=client -o yaml",
      "serverDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=server -o yaml",
      "applyCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=client -o yaml | kubectl apply -f -",
      "checkCount": 3,
      "failedCount": 0,
      "checks": [
        {
          "name": "report-file-exists",
          "passed": true,
          "summary": "Report file exists.",
          "exitCode": 0
        }
      ],
      "safetyPolicy": "This script writes to Kubernetes only when -Apply is supplied. -ServerDryRunOnly talks to the API server without persisting changes. The default and -PlanOnly modes do not execute kubectl."
    },
    "generatedAt": "2026-06-16T04:50:00+09:00"
  }
}
```

### GET /api/admin/backup/status

백업/복구 운영 준비 상태 조회. `ADMIN` 권한 필요.

MariaDB/MinIO 모드, 저장소 health, 복구 드릴 증거 기록 여부를 함께 확인한다. `POST /api/admin/backup/restore-drill-evidence`로 성공 증거를 기록하면 `restoreDrillExecuted`, `lastRestoreDrillAt`, `latestRestoreDrillEvidence`에 반영된다.

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
    "latestRestoreDrillEvidence": null,
    "pendingGates": [
      "MariaDB metadata mode is not enabled.",
      "MinIO object storage mode is not enabled.",
      "Successful restore drill evidence has not been recorded."
    ]
  }
}
```

### POST /api/admin/backup/restore-drill-evidence

백업/복구 드릴 실행 증거를 기록한다. `ADMIN` 권한 필요.

이 API는 실제 백업 파일이나 secret 값을 업로드하지 않는다. 운영자가 별도 보관한 backup manifest/evidence 경로, row/object count, restore 시작/종료 시각, backup timestamp를 남기고 audit log에 `BACKUP_RESTORE_DRILL_EVIDENCE` 이벤트를 기록한다. 비밀번호, access key, token, private key처럼 보이는 값은 요청에서 거부한다.
성공한 요청은 audit log와 `backup_restore_drill_evidence` 상세 이력 저장소에 함께 기록된다.

요청:

```json
{
  "environment": "local-demo",
  "operator": "admin",
  "result": "SUCCESS",
  "startedAt": "2026-06-15T10:00:00+09:00",
  "completedAt": "2026-06-15T11:00:00+09:00",
  "backupTimestamp": "2026-06-15T00:00:00+09:00",
  "metadataRowCount": 42,
  "objectCount": 7,
  "objectBytes": 8192,
  "backupManifestSha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "evidenceUri": "osmu-run/backup-drills/local-demo-20260615.json",
  "gaps": []
}
```

응답:

```json
{
  "data": {
    "auditLogId": 12,
    "environment": "local-demo",
    "operator": "admin",
    "result": "SUCCESS",
    "restoreDurationMinutes": 60,
    "observedRpoHours": 11,
    "rpoTargetMet": true,
    "rtoTargetMet": true,
    "metadataRowCount": 42,
    "objectCount": 7,
    "objectBytes": 8192,
    "statusImpact": "READY_GATE_SATISFIED",
    "recordedAt": "2026-06-15T11:01:00+09:00"
  }
}
```

### GET /api/admin/backup/restore-drill-evidence

최근 백업/복구 드릴 evidence 이력을 조회한다. `ADMIN` 권한 필요.

Query:

- `result`: optional, `SUCCESS`, `FAILED`, `PARTIAL`
- `limit`: optional, 1~100, default `20`

응답:

```json
{
  "items": [
    {
      "auditLogId": 12,
      "environment": "kubernetes-drill",
      "operator": "admin",
      "result": "SUCCESS",
      "startedAt": "2026-06-15T10:00:00+09:00",
      "completedAt": "2026-06-15T10:30:00+09:00",
      "backupTimestamp": "2026-06-15T00:00:00+09:00",
      "restoreDurationMinutes": 30,
      "observedRpoHours": 10,
      "metadataRowCount": 42,
      "objectCount": 7,
      "objectBytes": 8192,
      "evidenceUri": "osmu-run/latest-kubernetes-dr-finalize.json",
      "gaps": [],
      "statusImpact": "READY_GATE_SATISFIED",
      "recordedAt": "2026-06-15T10:31:00+09:00"
    }
  ],
  "nextCursor": null
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

## 12. API 구현 순서

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

Export lifecycle rules as an AWS S3 LifecycleConfiguration-compatible XML subset. `ADMIN` required. Exported rules use `ID`, `Filter`, `Status`, lifecycle action child ordering.

Mapping:

- `OBJECT_VERSION` -> `NoncurrentVersionExpiration/NoncurrentDays`
- `TRASH_OBJECT` -> `Expiration/Days`
- `prefix` and `tags` -> `Filter` with `Prefix`, `Tag`, or `And`
- `priority`, `batchSize`, and `bucketName` are OSMU-only fields and are not represented in S3 XML.
- Admin export includes all lifecycle rules. Use bucket lifecycle API for bucket-scoped XML.

### POST /api/admin/object-lifecycle/s3-xml

Import AWS S3 LifecycleConfiguration XML subset. `ADMIN` required. Imported rules get generated rule ids, priority based on XML order (`10`, `20`, ...), and batch size `100`. The import accepts up to 1000 `Rule` elements, and `Rule/ID` can be at most 255 characters. Each `Rule/Status` is required and must be `Enabled` or `Disabled`. `Filter` may be empty or contain exactly one supported direct predicate (`Prefix`, `Tag`, or `And`); object-size filters are not part of the OSMU subset. Lifecycle tag filters follow the same OSMU tag key/value restrictions as object lifecycle rules. Each rule must map to exactly one OSMU target action: `Expiration/Days` or `NoncurrentVersionExpiration/NoncurrentDays`.

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

