# OSMU Test Strategy

이 문서는 OSMU 테스트 전략을 정의한다.

구체적인 기능별 테스트 케이스는 `test-cases.md`를 기준으로 한다.

## 1. 테스트 목표

- 핵심 파일 저장 흐름을 안전하게 검증한다.
- 권한과 보안 실수를 줄인다.
- MariaDB와 MinIO 연동을 검증한다.
- MVP 기능을 반복적으로 확인 가능하게 한다.

## 2. 테스트 종류

### 2.1 Unit Test

대상:

- 도메인 validation
- 권한 판단
- bucket name validation
- quota 계산
- error mapping

### 2.2 Integration Test

대상:

- MariaDB repository
- MinIO adapter
- BucketService
- ObjectService

### 2.3 API Test

대상:

- Health API
- Bucket API
- Object API
- Auth API
- Access Key API

### 2.4 E2E Test

대상:

- 로그인
- 버킷 생성
- 파일 업로드
- 파일 다운로드
- 파일 삭제

## 3. MVP 테스트 우선순위

P0:

- Backend 실행 테스트
- MariaDB 연결 테스트
- MinIO 연결 테스트
- 버킷 생성/조회/삭제
- 파일 업로드/다운로드/삭제

P1:

- 로그인
- 사용자 생성
- 권한 검사
- Access Key 생성
- 감사 로그 기록

P2:

- 쿼터
- 모니터링
- 백업 설정

## 4. 테스트 데이터

기본:

- admin user
- normal user
- default organization
- sample bucket
- sample file

## 5. 검증 명령

Backend:

```text
./gradlew test
```

Frontend:

```text
npm run build
```

API:

```text
GET /api/health
GET /api/storage/health
POST /api/buckets
POST /api/buckets/{bucketName}/objects
```

## 6. 완료 기준

MVP 완료 전 최소 기준:

- Backend test 통과
- Frontend build 통과
- MariaDB 연결 확인
- MinIO 연결 확인
- Bucket API 수동 검증
- Object API 수동 검증
- Worklog 기록 완료
