# OSMU Coding Convention

이 문서는 OSMU 프로젝트의 기본 코딩 컨벤션이다.

프로젝트 초기에는 기술 스택이 완전히 확정되지 않았으므로, 특정 언어보다 제품 전체에 적용되는 공통 원칙을 먼저 정의한다. Backend, Frontend, Infra, 문서 작업 모두 이 기준을 따른다.

## 1. 기본 원칙

- 코드는 읽기 쉬워야 한다.
- 기능보다 의도가 먼저 보이게 작성한다.
- 같은 문제는 같은 방식으로 해결한다.
- 불필요한 추상화는 만들지 않는다.
- 동작 변경과 리팩터링은 가능하면 분리한다.
- 보안, 권한, 데이터 삭제, 키 관리 코드는 명시적으로 작성한다.
- 대용량 파일 처리 코드는 메모리 사용량을 항상 고려한다.
- 제품 목표는 `PROJECT_MEMORY.md`를 기준으로 한다.
- 상세 요구사항은 `PRODUCT_REQUIREMENTS.md`를 기준으로 한다.

## 2. 네이밍

### 2.1 공통

- 이름은 축약보다 명확성을 우선한다.
- 널리 쓰이는 약어만 허용한다.
  - 허용: `API`, `HTTP`, `URL`, `DB`, `S3`, `JWT`, `TLS`
  - 지양: 팀 내부에서만 아는 임의 약어
- Boolean 값은 의미가 바로 보이게 작성한다.
  - `isActive`
  - `hasPermission`
  - `canUpload`
  - `shouldDelete`

### 2.2 도메인 용어

OSMU에서는 다음 용어를 일관되게 사용한다.

| 용어 | 의미 |
| --- | --- |
| `User` | 시스템 사용자 |
| `Organization` | 회사, 부서, 팀, 프로젝트 단위 |
| `Bucket` | S3 호환 저장 단위 |
| `Object` | 버킷 안에 저장된 파일 |
| `AccessKey` | S3 API 접근 키 |
| `SecretKey` | S3 API 비밀 키 |
| `Quota` | 사용량 제한 |
| `AuditLog` | 감사 로그 |
| `StorageEngine` | MinIO 같은 실제 저장 엔진 |
| `ControlPlane` | 사용자, 권한, 정책, 운영 관리 계층 |
| `DataPlane` | 실제 파일 업로드/다운로드 경로 |

## 3. 파일과 디렉터리

### 3.1 문서

- 제품 목표 문서: `PROJECT_MEMORY.md`
- 기획/요구사항 문서: `PRODUCT_REQUIREMENTS.md`
- 코딩 컨벤션 문서: `codingcovention.md`
- 문서는 Markdown으로 작성한다.
- 큰 결정은 문서에 남긴다.

### 3.2 코드 구조

기술 스택 확정 전 기본 구조는 다음 방향을 따른다.

```text
backend/
frontend/
infra/
docs/
scripts/
```

권장 책임:

- `backend/`: REST API, 인증, 권한, MinIO 연동, DB 연동
- `frontend/`: Web Portal
- `infra/`: Docker Compose, Kubernetes, Helm, 모니터링 설정
- `docs/`: 사용자/관리자/설치/API 문서
- `scripts/`: 개발, 설치, 운영 보조 스크립트

## 4. Backend 컨벤션

### 4.1 계층 분리

Backend는 다음 책임을 분리한다.

- Controller 또는 Handler: 요청/응답 처리
- Service: 비즈니스 로직
- Repository: DB 접근
- Storage Adapter: MinIO/S3 연동
- Auth/RBAC: 인증과 권한 검사
- DTO 또는 Schema: 외부 입출력 형식

### 4.2 금지 패턴

- Controller에서 DB 직접 접근 금지
- Controller에서 MinIO 직접 호출 금지
- Service에서 HTTP request 객체에 과도하게 의존 금지
- Secret Key 평문 저장 금지
- 권한 검사 생략 금지
- 파일 전체를 메모리에 올리는 대용량 처리 금지

### 4.3 에러 처리

- 사용자에게 내부 에러 상세를 노출하지 않는다.
- 로그에는 원인 추적 가능한 정보를 남긴다.
- 권한 에러와 존재하지 않는 리소스 에러를 구분한다.
- 외부 저장소 장애와 내부 DB 장애를 구분한다.

권장 에러 분류:

- `ValidationError`
- `AuthenticationError`
- `AuthorizationError`
- `NotFoundError`
- `ConflictError`
- `QuotaExceededError`
- `StorageError`
- `InternalError`

## 5. API 컨벤션

### 5.1 REST API

- 리소스 중심 URL을 사용한다.
- 응답 형식은 일관되게 유지한다.
- 목록 API는 페이지네이션을 지원한다.
- 삭제 API는 감사 로그를 남긴다.
- 파일 다운로드는 스트리밍 또는 presigned URL을 우선 고려한다.

예시:

```text
GET    /api/buckets
POST   /api/buckets
GET    /api/buckets/{bucketName}
DELETE /api/buckets/{bucketName}
GET    /api/buckets/{bucketName}/objects
POST   /api/buckets/{bucketName}/objects
DELETE /api/buckets/{bucketName}/objects/{objectKey}
```

### 5.2 응답 형식

성공 응답:

```json
{
  "data": {},
  "meta": {}
}
```

목록 응답:

```json
{
  "items": [],
  "nextCursor": null
}
```

에러 응답:

```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Bucket quota exceeded."
  }
}
```

## 6. 보안 컨벤션

- 기본 버킷 정책은 private이다.
- 모든 관리 API는 인증이 필요하다.
- 모든 파일 API는 권한 검사가 필요하다.
- 비밀번호는 해시로 저장한다.
- Secret Key 원문은 생성 시 1회만 노출한다.
- 토큰과 키는 로그에 남기지 않는다.
- 감사 로그에는 누가, 언제, 무엇을, 어떤 결과로 수행했는지 남긴다.
- 삭제, 권한 변경, 키 생성/폐기는 감사 로그 필수다.
- TLS 적용을 운영 기본값으로 본다.

## 7. 대용량 파일 처리

- 대용량 파일은 streaming 방식으로 처리한다.
- 가능하면 multipart upload를 사용한다.
- Backend가 파일 전송 병목이 되지 않게 한다.
- 다운로드는 presigned URL 방식을 우선 검토한다.
- 업로드 전 quota를 확인한다.
- 업로드 실패 시 부분 업로드 정리 전략을 둔다.
- 파일 크기 제한은 설정값으로 관리한다.

## 8. DB 컨벤션

- MVP 기본 DB는 MariaDB를 사용한다.
- 실제 파일 데이터는 DB에 저장하지 않고 MinIO에 저장한다.
- DB에는 사용자, 조직, 버킷 메타데이터, 권한, 쿼터, 감사 로그, 설정 정보를 저장한다.
- PK는 일관된 형식을 사용한다.
- 생성/수정 시간 컬럼을 둔다.
  - `createdAt`
  - `updatedAt`
- 상태값은 enum 또는 명확한 상수로 관리한다.
- Soft delete가 필요한 리소스는 `deletedAt`을 둔다.
- 마이그레이션 파일은 직접 수정하지 않고 새 마이그레이션으로 변경한다.
- 감사 로그는 수정하지 않는 append-only 성격으로 다룬다.

## 9. Frontend 컨벤션

- 관리자 도구 UI는 조용하고 실용적으로 만든다.
- 랜딩 페이지보다 실제 관리 화면을 우선한다.
- 표, 필터, 검색, 상태 배지를 적극 사용한다.
- 파괴적 작업은 확인 단계를 둔다.
- 권한 없는 기능은 숨기거나 비활성화한다.
- 긴 파일명과 큰 숫자가 깨지지 않게 처리한다.
- 업로드 진행률과 실패 상태를 표시한다.
- 용량은 사람이 읽기 쉬운 단위로 표시한다.

## 10. Infra 컨벤션

- 로컬 개발은 Docker Compose를 우선 지원한다.
- 운영 배포는 Kubernetes와 Helm을 목표로 한다.
- 설정값은 환경변수 또는 설정 파일로 분리한다.
- Secret은 코드에 커밋하지 않는다.
- 샘플 설정은 `.example` 파일로 제공한다.
- 모니터링 지표와 로그 출력은 운영 기본 요구사항으로 본다.

## 11. 테스트 컨벤션

우선순위:

1. 인증/권한 테스트
2. 버킷 생성/삭제 테스트
3. 파일 업로드/다운로드/삭제 테스트
4. quota 테스트
5. 감사 로그 테스트
6. MinIO 연동 테스트

테스트 원칙:

- 핵심 도메인 로직은 단위 테스트를 작성한다.
- 외부 시스템 연동은 통합 테스트로 분리한다.
- 테스트 데이터는 서로 격리한다.
- 삭제 테스트는 실제 운영 리소스와 분리된 환경에서만 실행한다.

## 12. 로그 컨벤션

- 로그에는 요청 추적 ID를 포함한다.
- 사용자 ID, 버킷 이름, 작업 종류를 남긴다.
- Secret Key, 비밀번호, 토큰은 절대 로그에 남기지 않는다.
- 실패 원인은 운영자가 추적 가능해야 한다.
- 감사 로그와 애플리케이션 로그를 구분한다.

## 13. Git 컨벤션

### 13.1 브랜치

권장 형식:

```text
feat/<short-name>
fix/<short-name>
docs/<short-name>
infra/<short-name>
refactor/<short-name>
```

Codex 작업 브랜치는 기본적으로 다음 prefix를 사용한다.

```text
codex/<short-name>
```

### 13.2 커밋 메시지

커밋 메시지는 한국어로 작성한다.

기본 형식:

```text
[영역] 변경 내용
```

영역 태그:

| 태그 | 영역 | 적용 대상 |
| --- | --- | --- |
| `[B]` | Backend | Spring Boot API, DB 연동, MinIO/S3 Adapter, 인증/권한 |
| `[F]` | Frontend | Vue 화면, 라우터, 상태 관리, API 호출 UI |
| `[I]` | Infra | Docker Compose, Kubernetes, Helm, CI/CD, 배포 설정 |
| `[D]` | Docs | 기획서, 요구사항, API 문서, 설계서, Worklog |
| `[T]` | Test | 테스트 코드, 테스트 케이스, 테스트 환경 |
| `[S]` | Security | 인증, 권한, 키 관리, 암호화, 보안 정책 |
| `[O]` | Operation | 모니터링, 백업, 복구, 운영 자동화 |

새로운 작업 영역이 추가되면 커밋하기 전에 이 표에 `[알파벳]` 태그를 먼저 추가한다.

예시:

```text
[D] 개발 문서 세트 추가
[B] 버킷 생성 API 구현
[F] 버킷 목록 화면 구현
[I] MariaDB와 MinIO 로컬 환경 추가
[T] 버킷 API 테스트 케이스 추가
[S] Access Key 노출 방지 처리
```

여러 영역을 함께 수정한 경우, 변경의 중심이 되는 대표 태그를 앞에 쓰고 커밋 본문 또는 worklog에 나머지 영향을 기록한다.

나쁜 예:

```text
update
fix
docs update
```

## 14. 문서 컨벤션

- 기능 추가 시 관련 문서를 함께 갱신한다.
- 설치 방법이 바뀌면 설치 문서를 반드시 갱신한다.
- API 변경 시 API 문서를 갱신한다.
- 제품 방향 변경은 `PROJECT_MEMORY.md`에 반영한다.
- 요구사항 변경은 `PRODUCT_REQUIREMENTS.md`에 반영한다.

## 15. 리뷰 체크리스트

코드 리뷰 시 다음을 확인한다.

- 권한 검사가 빠지지 않았는가?
- Secret, Token, Password가 로그나 DB에 평문으로 남지 않는가?
- 대용량 파일을 메모리에 통째로 올리지 않는가?
- API 응답 형식이 일관적인가?
- 에러 메시지가 내부 정보를 과하게 노출하지 않는가?
- 감사 로그가 필요한 작업에 남는가?
- 테스트가 위험도에 맞게 작성되었는가?
- 문서 변경이 필요한데 빠지지 않았는가?

## 16. 미정 항목

다음 항목은 기술 스택 확정 후 보강한다.

- Backend 언어별 formatter/linter
- Frontend formatter/linter
- DB migration 도구
- API 문서 생성 도구
- 테스트 프레임워크
- CI 파이프라인
- Helm Chart 구조

## 17. 현재 기준

아직 구현 전 단계에서는 이 문서를 기본 규칙으로 사용한다.

기술 스택이 확정되면 언어별 세부 컨벤션을 추가한다.
