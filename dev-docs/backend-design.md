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

### 4.2 Service

역할:

- 도메인 로직
- 권한 검사
- 트랜잭션 관리
- Repository와 StorageAdapter 조합

### 4.3 Repository

역할:

- MariaDB 접근
- JPA Entity 조회/저장

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
- MinIO 버킷 생성
- MariaDB 버킷 메타데이터 저장
- 버킷 삭제 전 empty 확인
- 감사 로그 기록

### 5.2 ObjectService

책임:

- 파일 업로드 권한 확인
- 쿼터 확인
- MinIO object 업로드
- 파일 목록 조회
- 다운로드 stream 또는 presigned URL 반환
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
- Access Key 비활성화
- MinIO 계정/정책 연동

### 5.5 AuditLogService

책임:

- 주요 이벤트 기록
- 실패 이벤트 기록
- 조회 API 제공

## 6. MinIO 연동 설계

### 6.1 설정값

```yaml
osmu:
  storage:
    endpoint: http://localhost:9000
    access-key: minioadmin
    secret-key: minioadmin
    region: us-east-1
```

### 6.2 Adapter 인터페이스

```java
public interface ObjectStorageAdapter {
    boolean isHealthy();
    void createBucket(String bucketName);
    void deleteBucket(String bucketName);
    boolean bucketExists(String bucketName);
    List<StoredObject> listObjects(String bucketName, String prefix, int limit, String cursor);
    void uploadObject(String bucketName, String objectKey, InputStream stream, long size, String contentType);
    InputStream downloadObject(String bucketName, String objectKey);
    void deleteObject(String bucketName, String objectKey);
}
```

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

