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

## 4. Bucket

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

## 5. Object

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

- 기능: 파일 삭제 성공
- 조건: 파일이 존재하고 사용자에게 삭제 권한이 있다.
- 입력: `DELETE /api/buckets/{bucketName}/objects/{objectKey}`
- 절차: 삭제 API 호출.
- 기대 결과: MinIO object 삭제, 감사 로그 기록.
- 우선순위: P0
- 자동화 여부: Automated

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

## 6. Access Key

### TC-KEY-001

- 기능: Access Key 생성
- 조건: 로그인한 사용자가 있다.
- 입력: key name
- 절차: `POST /api/access-keys` 호출.
- 기대 결과: accessKey와 secretKey 반환. secretKey는 1회만 표시.
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

## 7. Quota

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

## 8. Audit Log

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

## 9. Frontend

### TC-FE-001

- 기능: 버킷 목록 화면
- 조건: Backend가 실행 중이고 버킷이 존재한다.
- 입력: `/buckets` 접근.
- 절차: 브라우저에서 버킷 목록 화면 진입.
- 기대 결과: 버킷 목록이 표시된다.
- 우선순위: P1
- 자동화 여부: Later

### TC-FE-002

- 기능: 파일 업로드 화면
- 조건: 버킷이 존재한다.
- 입력: 파일 선택 후 업로드.
- 절차: ObjectExplorer에서 업로드 실행.
- 기대 결과: 업로드 진행률 표시 후 목록에 파일이 나타난다.
- 우선순위: P1
- 자동화 여부: Later

### TC-FE-003

- 기능: 삭제 확인 모달
- 조건: 삭제 가능한 파일이 존재한다.
- 입력: 삭제 버튼 클릭.
- 절차: 삭제 확인 모달 확인.
- 기대 결과: 확인 전에는 삭제되지 않고, 확인 후 삭제된다.
- 우선순위: P1
- 자동화 여부: Later

## 10. Security

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
- 자동화 여부: Manual

## 11. Backup and Recovery

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

## 12. MVP 완료 기준 테스트

MVP 완료 전 다음 테스트는 반드시 통과해야 한다.

- TC-HEALTH-001
- TC-HEALTH-002
- TC-HEALTH-003
- TC-BUCKET-001
- TC-BUCKET-002
- TC-BUCKET-003
- TC-BUCKET-004
- TC-BUCKET-005
- TC-OBJECT-001
- TC-OBJECT-002
- TC-OBJECT-003
- TC-OBJECT-004
- TC-OBJECT-005

