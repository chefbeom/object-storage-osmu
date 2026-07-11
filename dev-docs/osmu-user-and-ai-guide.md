# OSMU User and AI Guide

이 문서는 OSMU를 처음 사용하는 사람과 저장소에서 작업하는 AI 에이전트를 위한 기준 문서다.

- 사람은 역할별 화면 흐름과 안전한 운영 절차를 따른다.
- AI는 현재 코드, API 계약, 상태 전이, 테스트 결과를 근거로 작업한다.
- 화면의 `APPLIED`, `APPROVED`, `PASS`만으로 실제 인프라 적용 완료를 추론하지 않는다.

## 1. 제품 목적

OSMU는 기업 내부 파일을 S3 호환 API와 웹 포털로 관리하는 private object storage 운영 도구다.

주요 기능:

- 버킷 생성, 조회, 동기화, 삭제
- 객체 업로드, 검색, 태그, 버전, 공유 링크
- S3 Access Key와 버킷별 scope 관리
- 사용자, 조직, 팀, 버킷 권한 관리
- 쿼터, 수명주기, 보존, 공유 정책
- Storage Profile 요청과 승인
- Kubernetes PVC 기반 Storage Layout 계획과 시뮬레이션
- 감사 로그, 백업, 운영 준비도, 데이터 흐름 모니터링

## 2. 시스템 구조

```text
사용자 또는 SDK
      |
      v
OSMU Backend
  - 인증과 역할 검사
  - 버킷 권한과 쿼터
  - 정책과 감사 로그
      |
      +------------------> Metadata Repository
      |
      v
S3-compatible Object Storage
      |
      v
MinIO Pool / Kubernetes PVC
```

### 반드시 구분할 상태

| 상태 | 의미 | 의미하지 않는 것 |
|---|---|---|
| `PLANNED` | 제어 계층에 계획이 기록됨 | Kubernetes 리소스 생성 |
| `UNVERIFIED` | 대상 환경에서 확인이 필요함 | 실패 또는 통과 |
| `APPROVED` | 관리자가 계획을 승인함 | 실제 apply 성공 |
| `APPLIED` | Profile assignment와 Layout 참조가 기록됨 | 기존 객체의 물리적 재배치 완료 |
| `SIMULATED` | preview와 정적 검사가 실행됨 | 실제 클러스터 변경 |

현재 Storage Layout의 `clusterMutation`은 `disabled`다. PVC 생성과 MinIO Tenant 변경은 수행하지 않는다.

## 3. 역할

### USER

일반 사용자는 자신의 업무 데이터를 저장하고 애플리케이션을 연결한다.

- Dashboard 조회
- 접근 가능한 버킷 생성 및 사용
- 객체 업로드, 다운로드, 검색, 태그, 공유
- Storage Profile 변경 요청
- 자신의 권한 범위에서 Access Key 생성

할 수 없는 일:

- 전역 Storage Layout 승인
- 다른 조직의 사용자와 정책 관리
- 관리자 API 호출

### ADMIN

관리자는 전체 스토리지 시스템과 전역 정책을 운영한다.

- 모든 운영 상태와 승인 대기열 확인
- 사용자, 조직, 팀, 버킷 권한 관리
- Profile 요청 승인과 Layout 연결
- Storage Layout 계획, 시뮬레이션, 승인
- 쿼터, 수명주기, 공유, 보존 정책
- 감사, 백업, 복구, 운영 준비도 관리

### ORG_ADMIN

조직 관리자는 조직 범위의 사용자, 팀, 버킷을 관리한다.

- 조직 사용자와 팀 관리
- 조직 버킷과 권한 관리
- 조직 범위 운영 요청 조정

전역 인프라, 감사, Storage Layout 변경은 ADMIN에게 요청한다.

### AUDITOR

감사자는 변경 이력과 운영 증거를 읽는다.

- Audit 검색과 CSV export
- Request ID 기반 변경 추적
- 승인, 거절, 적용 이력 비교
- Operations Readiness 증거 검토

감사자는 운영 변경을 직접 실행하지 않는다.

## 4. 처음 10분

1. 로그인 화면에서 실제 역할에 맞는 콘솔을 선택한다.
2. 좌측 `Backend`, `Storage`, `Database` 상태를 확인한다.
3. Dashboard에서 용량과 운영 경고를 확인한다.
4. Storage에서 접근 가능한 버킷을 선택한다.
5. Objects에서 객체 목록을 확인한다.
6. 작업 후 성공 메시지 또는 오류와 Request ID를 확인한다.

USER가 관리자 모드로 로그인하거나 `/admin`에 접근하면 `/developer`로 이동하며 권한 안내가 표시된다.

## 5. USER 사용법

### 5.1 버킷 만들기

1. 좌측 `Storage`를 연다.
2. 버킷 이름을 입력한다.
3. 초기 쿼터를 GiB 단위로 입력한다.
4. 필요한 경우 소유 조직을 선택한다.
5. `Create`를 누른다.
6. 목록에 버킷이 표시되는지 확인한다.
7. 버킷 행을 눌러 현재 버킷으로 선택한다.

좋은 이름:

```text
media-ingest-prod
team-a-archive
service-assets
```

피해야 할 이름:

```text
test
bucket1
My Files
```

버킷 이름은 소문자, 숫자, 점, 하이픈 중심으로 구성한다.

### 5.2 객체 업로드

1. Storage에서 버킷을 선택한다.
2. `Objects`를 연다.
3. 파일과 object key를 확인한다.
4. 업로드를 시작한다.
5. 큰 파일은 multipart 진행률과 재시도 상태를 확인한다.
6. 업로드 완료 후 목록, 크기, 수정 시간을 확인한다.

object key 예시:

```text
videos/raw/2026/intro.mp4
datasets/images/manifest.json
backups/service-a/2026-07-11.tar
```

### 5.3 검색과 태그

- prefix는 폴더처럼 객체 범위를 좁힌다.
- 검색은 object key 일부를 찾는다.
- 태그는 업무 속성으로 객체를 분류한다.

태그 예시:

```text
project=osmu
stage=raw
owner=media-team
retention=90d
```

### 5.4 다운로드, 공유, 버전

- 다운로드 전 올바른 버킷과 object key인지 확인한다.
- 공유 링크는 만료, 비밀번호, IP 제한, 다운로드 횟수를 설정한다.
- 버전 복원 전 현재 버전을 확인한다.
- 삭제와 복원 후 Audit 또는 상태 메시지를 확인한다.

### 5.5 Storage Profile 요청

| Profile | Layout 호환 | 사용 예 | 주의 |
|---|---|---|---|
| Performance | JBOD, RAID0-like | 임시 처리, 영상 ingest, cache | 장애 허용성 낮음 |
| Standard | RAID5, RAID10-like | 일반 파일, 서비스 자산 | 균형형 |
| Durable | RAID1, RAID6-like | 원본, 백업, 보존 데이터 | usable capacity 감소 |

절차:

1. Storage에서 대상 버킷을 선택한다.
2. Profile을 선택한다.
3. 변경 사유와 예상 사용 기간을 입력한다.
4. 요청 후 `PENDING`을 확인한다.
5. 관리자가 적용한 뒤 `APPLIED`와 Layout 참조를 확인한다.

`APPLIED`는 데이터 재배치 완료를 의미하지 않는다.

## 6. Developer와 S3 API

### 6.1 Access Key 발급

1. `Developer`를 연다.
2. 키 이름과 만료일을 입력한다.
3. 허용 버킷을 선택한다.
4. `READ`, `WRITE` 중 필요한 권한만 선택한다.
5. 발급 직후 Secret Key를 비밀 저장소에 기록한다.
6. 작은 객체로 연결을 테스트한다.

Secret Key를 다음 위치에 남기지 않는다.

- Git 저장소
- 이슈 또는 PR 본문
- 로그
- 화면 캡처
- 공유 문서

### 6.2 AWS CLI 예시

```bash
export AWS_ACCESS_KEY_ID="<issued-access-key>"
export AWS_SECRET_ACCESS_KEY="<issued-secret>"
export AWS_ENDPOINT_URL="http://localhost:9000"

aws --endpoint-url "$AWS_ENDPOINT_URL" s3 ls s3://my-bucket
aws --endpoint-url "$AWS_ENDPOINT_URL" s3 cp ./sample.txt s3://my-bucket/examples/sample.txt
```

### 6.3 오류 판독

| HTTP | 먼저 확인할 내용 |
|---|---|
| 400 | 입력값, 현재 상태, 허용된 상태 전이 |
| 401 | 로그인, 토큰 만료, Authorization header |
| 403 | 사용자 역할, 버킷 scope, 관리자 API 여부 |
| 404 | 버킷, 객체, 요청 또는 plan ID |
| 409 | 중복 이름 또는 충돌 상태 |
| 500 | Request ID와 backend 로그 |

## 7. ADMIN 사용법

### 7.1 일일 점검

1. Backend, Storage, Database 상태
2. 전체 용량과 임계치
3. Operations Readiness blocker와 warning
4. 백업 상태와 최근 복구 훈련
5. Profile, 확장, Layout 승인 대기열
6. 실패 Audit 이벤트와 반복 Request ID

### 7.2 사용자와 조직

1. 조직을 만든다.
2. 조직 내부 팀을 만든다.
3. 사용자를 최소 역할로 생성한다.
4. 팀 구성원을 관리한다.
5. 버킷 권한을 사용자 또는 팀에 부여한다.
6. 퇴사, 이동, 종료 시 계정과 Access Key를 함께 정리한다.

### 7.3 Storage Layout 생성

입력:

- Layout code
- StorageClass name
- server count
- volumes per server
- volume size GiB
- reason

지원 범위:

- JBOD
- RAID0-like
- RAID1-like
- RAID5-like
- RAID6-like
- RAID10-like

RAID2, RAID3, RAID4, RAID7, RAID8, RAID9은 지원하지 않는다.

### 7.4 Layout 시뮬레이션과 승인

1. plan을 만든다.
2. PVC 수와 topology 조건을 확인한다.
3. `Simulate`를 실행한다.
4. manifest preview를 확인한다.
5. `STORAGE_CLASS = UNVERIFIED`를 확인한다.
6. `MINIO_POOL = PLANNED`를 확인한다.
7. `CLUSTER_MUTATION = SIMULATED`와 `clusterMutation: disabled`를 확인한다.
8. 시뮬레이션 후 활성화된 `Approve`를 누른다.

시뮬레이션 전 승인은 API와 UI 모두 차단된다.

### 7.5 Profile 승인과 Layout 연결

1. 버킷과 요청자를 확인한다.
2. 현재 Profile과 요청 Profile을 비교한다.
3. 사유, 기간, 데이터 중요도를 검토한다.
4. 승인 또는 거절한다.
5. 승인된 요청에서 호환 Layout을 선택한다.
6. Apply한다.
7. 다음 필드를 확인한다.

```json
{
  "status": "APPLIED",
  "storageLayoutPlanId": 7,
  "storagePoolName": "storage-layout-7",
  "storageLayoutCode": "RAID0"
}
```

선택 목록에는 다음 조건을 모두 만족하는 plan만 표시된다.

- `status = APPROVED`
- `simulatedAt` 존재
- Profile과 Layout 호환

## 8. ORG_ADMIN 사용법

1. 조직의 사용자와 팀을 검토한다.
2. 조직 버킷 소유권과 쿼터를 관리한다.
3. 팀 권한을 최소 범위로 유지한다.
4. Profile 요청의 업무 사유와 기간을 정리한다.
5. 전역 Layout, 백업, 인증 변경은 ADMIN에게 요청한다.
6. 조직 이동과 종료 시 데이터 인계와 키 폐기를 확인한다.

## 9. AUDITOR 사용법

1. 기간을 선택한다.
2. 이벤트 유형과 결과를 필터링한다.
3. 행위자와 대상을 확인한다.
4. Request ID로 backend 로그와 연결한다.
5. 승인, 거절, 적용 시간을 비교한다.
6. CSV와 조회 조건을 함께 보관한다.
7. 증거의 생성 시각, 환경, 버전을 확인한다.

스크린샷만으로 운영 완료를 판정하지 않는다.

## 10. 문제 해결

### 공통 순서

1. 오류 메시지, code, HTTP status, Request ID, 발생 시간을 기록한다.
2. 사용자 역할과 대상 권한을 확인한다.
3. 입력값을 확인한다.
4. 대상의 현재 상태를 확인한다.
5. Backend, Storage, Database 상태를 확인한다.
6. 관리자 또는 AI는 같은 Request ID로 로그와 Audit를 찾는다.
7. 기대 결과와 실제 결과를 비교한다.

### 자주 발생하는 상황

#### 관리자 화면으로 이동하지 못함

- USER 계정인지 확인한다.
- USER는 `/developer`로 이동하는 것이 정상이다.
- 화면 상단 권한 안내를 확인한다.

#### Layout Approve가 비활성화됨

- 먼저 Simulate를 실행한다.
- `simulatedAt`이 기록됐는지 확인한다.
- plan 상태가 `PLANNED`인지 확인한다.

#### Profile Apply 선택 목록이 비어 있음

- 요청 Profile과 호환되는 Layout인지 확인한다.
- Layout이 `APPROVED`인지 확인한다.
- Layout simulation이 완료됐는지 확인한다.

#### StorageClass가 UNVERIFIED임

- 개발 환경의 정상 상태다.
- 실제 Kubernetes에서 StorageClass 존재와 provisioner를 확인해야 한다.
- 확인 전 PASS로 바꾸지 않는다.

## 11. AI 작업 계약

### 11.1 읽기 순서

1. 현재 사용자 요청과 active goal
2. `PROJECT_MEMORY.md`
3. `PRODUCT_REQUIREMENTS.md`
4. `dev-docs/document-index.md`
5. 관련 API와 서비스 코드
6. 관련 테스트
7. `git status`와 현재 diff

### 11.2 작업 원칙

- 현재 worktree를 권위 있는 상태로 사용한다.
- 사용자가 만든 기존 변경을 되돌리지 않는다.
- 추측보다 코드, 실행 결과, API 응답을 사용한다.
- 역할과 권한 경계를 보존한다.
- 상태 전이를 우회하지 않는다.
- DB model, repository, migration, response를 함께 변경한다.
- UI 성공 표시는 backend의 실제 계약과 일치시킨다.
- simulation과 실제 cluster mutation을 구분한다.

### 11.3 Storage Layout 불변식

```text
PLANNED
  -> SIMULATE
  -> simulatedAt 기록
  -> APPROVED 또는 REJECTED

Profile request
  PENDING
  -> APPROVED
  -> compatible approved+simulated Layout 선택
  -> APPLIED
```

다음은 허용하지 않는다.

- 시뮬레이션 전 Layout 승인
- 미검증 StorageClass를 PASS로 표시
- Layout 참조 없는 Profile Apply
- 호환되지 않는 Profile과 Layout 연결
- USER의 관리자 API 접근

### 11.4 최소 검증

Windows PowerShell:

```powershell
cd osmu-backend
$env:JAVA_HOME='C:\jdk-17'
$env:Path="$env:JAVA_HOME\bin;$env:Path"
.\gradlew.bat test --no-daemon

cd ..\osmu-frontend
npm.cmd run test:unit
npm.cmd run build

cd ..
.\scripts\verify-openapi-contract.ps1

cd osmu-frontend
npx.cmd playwright test ./e2e/storage-layout-scenarios.spec.js --config=playwright.storage-layout.config.js

cd ..
git diff --check
```

### 11.5 완료 보고

AI는 다음을 구분해 보고한다.

- 구현한 내용
- 실제 실행한 테스트
- 예상 실패를 포함한 E2E 결과
- 실행하지 못한 검증
- 실제 Kubernetes에서 남은 확인
- 커밋과 push 여부

## 12. API 예시

### Layout 목록

```bash
curl "http://localhost:8080/api/admin/storage-layouts/plans?status=ALL&limit=50" \
  -H "Authorization: Bearer $OSMU_TOKEN"
```

### Layout simulation

```bash
curl -X POST "http://localhost:8080/api/admin/storage-layouts/plans/7/simulate" \
  -H "Authorization: Bearer $OSMU_TOKEN"
```

### Layout 승인

```bash
curl -X PATCH "http://localhost:8080/api/admin/storage-layouts/plans/7/status" \
  -H "Authorization: Bearer $OSMU_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"APPROVED","adminNote":"simulation reviewed"}'
```

### Profile 적용

```bash
curl -X POST "http://localhost:8080/api/admin/storage-profile-requests/42/apply" \
  -H "Authorization: Bearer $OSMU_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"storageLayoutPlanId":7}'
```

## 13. 운영 배포 전 체크리스트

- [ ] MariaDB V65 migration 검증
- [ ] MariaDB V66 migration 검증
- [ ] Kubernetes StorageClass 실재 확인
- [ ] PVC provisioner 확인
- [ ] MinIO Operator와 Tenant 버전 확인
- [ ] 실제 cluster preflight 구현 및 실행
- [ ] server-side dry-run 증거 보관
- [ ] PVC/Pool apply 실패 재시도 검증
- [ ] rollback 검증
- [ ] 기존 객체 재배치 정책 결정
- [ ] 백업과 복구 훈련
- [ ] PVC 또는 노드 장애 시나리오
- [ ] Operations Readiness pending 항목 종료

## 14. 관련 원본

- `dev-docs/openapi-mvp.json`: API 계약
- `dev-docs/storage-layout.md`: Layout 설계
- `dev-docs/database-design.md`: metadata schema
- `dev-docs/test-cases.md`: 테스트 시나리오
- `PROJECT_MEMORY.md`: 현재 개발 상태
- `PRODUCT_REQUIREMENTS.md`: 제품 요구사항
