## Admin Lifecycle Rule UI

- Admin dashboard has a lifecycle rule form for `OBJECT_VERSION` and `TRASH_OBJECT`.
- Operators can set rule name, enabled flag, priority, prefix, tag filter, retention days, and batch size.
- Rule list supports edit/delete and shows target, retention, batch, prefix, and tags.
- UI calls `GET/POST/DELETE /api/admin/object-lifecycle/rules`.
- Rule list has Dry run action to preview matched candidates, bytes, cutoff, and truncation state before purge.
- Conflict report shows overlapping enabled rules and refreshes after rule save/delete.
- S3 Lifecycle XML area exports current rules and imports compatible lifecycle XML into OSMU rules.
- Bucket detail area has a Bucket Lifecycle panel for selected bucket S3 XML load/save/delete.
- Bucket Lifecycle panel uses `getBucketLifecycleS3Xml`, `putBucketLifecycleS3Xml`, `deleteBucketLifecycleS3Xml`.
- Bucket detail area has a Bucket Tags panel for selected bucket S3 tagging load/save/delete.
- Bucket Tags panel accepts `key=value,key2=value2`, validates the same 50 bucket tag limit as Backend, converts input to a JSON tag map, and uses `GET/PUT/DELETE /api/buckets/{bucketName}/tags`.
- Tag parsing/formatting validation lives in `src/utils/tags.js` and is covered by `npm run test:unit`.
# OSMU Frontend Design

## Multipart Refresh Note

- `refreshMultipartUpload(bucketName, payload)` API wrapper를 제공한다.
- multipart 실패 시 `sessionStorage`에 `uploadId`, file fingerprint, completed part ETag를 저장한다.
- retry 시 parts list API로 MinIO에 이미 올라간 part ETag를 조회하고, refresh API로 만료된 part URL을 재발급받는다.
- sessionStorage ETag와 server-side part ETag를 병합한 뒤 완료된 part는 skip하고 남은 part만 업로드한다.
- tab reload 후에도 pending multipart 목록을 sessionStorage에서 복구하고, 같은 bucket/key/tags/file fingerprint가 선택되면 Resume 버튼으로 이어 올린다.
- Backend가 반환한 session `expiresAt`으로 pending multipart 만료 여부를 표시하고, 만료 후 24시간이 지난 local resume session은 자동 정리한다.
- 사용자 취소는 abort API를 호출하고 resume session을 삭제한다.

이 문서는 Vue 기반 OSMU Web Portal 설계를 정의한다.

## 1. Frontend 역할

Web Portal은 관리자와 사용자가 OSMU를 브라우저에서 사용할 수 있게 하는 관리 도구다.

주요 기능:

- 로그인
- 대시보드
- 버킷 목록
- 파일 탐색기
- 파일 업로드/다운로드/삭제
- Access Key 관리
- 사용자 관리
- 조직 관리
- 감사 로그 조회
- 시스템 상태 확인

## 2. 기술 스택

- Vue 3
- Vite
- Vue Router
- Pinia
- Fetch API 또는 Axios

## 3. 화면 구조

```text
/login
/dashboard
/buckets
/buckets/:bucketName
/access-keys
/admin/users
/admin/organizations
/admin/audit-logs
/admin/system
```

## 4. 레이아웃

관리 도구이므로 실용적이고 조용한 UI를 우선한다.

구성:

- 좌측 사이드바
- 상단 상태바
- 메인 컨텐츠 영역
- 표 기반 목록
- 모달 기반 생성/삭제 확인

## 5. 주요 화면

### 5.1 LoginView

기능:

- loginId 입력
- password 입력
- 로그인 요청
- 실패 메시지 표시

### 5.2 DashboardView

표시:

- 내 사용량
- 버킷 수
- 최근 파일 작업
- 시스템 상태

관리자 표시:

- 전체 사용자 수
- 전체 버킷 수
- 전체 사용량
- 최근 감사 로그

### 5.3 BucketListView

기능:

- 버킷 목록 조회
- 버킷 생성
- user/organization bucket owner 선택
- 버킷 삭제
- 사용량 표시
- S3 직접 업로드 이후 사용량 동기화
- 권한 표시
- 관리 가능한 bucket의 `READ`, `WRITE`, `DELETE`, `ADMIN` 권한 부여/회수

### 5.4 ObjectExplorerView

기능:

- prefix 기반 탐색
- prefix 입력/초기화
- object key 검색
- 검색어 match highlight
- object tag 입력/수정/표시/filter
- object tag 형식/길이 사전 검증
- object metadata 상세 패널
- object metadata index/storage drift 상태 표시
- object metadata ETag/checksum index/storage 비교 표시
- object version 목록 패널과 version restore 버튼
- object version 목록 패널과 version restore 버튼
- presigned upload URL 생성 시 object tag 전달
- delimiter 기반 폴더형 prefix 이동
- prefix breadcrumb 버튼 이동
- `nextCursor` 기반 다음 파일 로드
- object list page size 선택
- 파일 목록
- 파일 업로드
- 128 MiB 이상 파일은 multipart upload API를 자동 사용
- 파일 다운로드
- 파일 삭제
- 업로드 진행률/전송 bytes 표시와 중복 업로드 방지
- 업로드 취소와 마지막 업로드 재시도
- 빈 상태 표시

Soft delete UI:

- Object Explorer는 `Active`/`Trash` segmented control을 제공한다.
- `Active` 목록의 Delete는 object를 trash로 이동한다.
- `Trash` 목록은 deleted object와 `deletedAt`을 표시한다.
- `Trash` 목록에서 Restore와 Purge를 실행할 수 있다.
- Admin dashboard는 trash retention days, batch size, purge success/failure metric을 표시하고 수동 `Run purge`를 실행할 수 있다.
- Admin dashboard lifecycle 영역에서 retention enabled, retention days, batch size를 변경하고 `Save`로 저장할 수 있다.
- Admin dashboard lifecycle 영역은 version retention days, version batch size, purged version count도 함께 표시/저장한다.
- Admin dashboard lifecycle 영역에서 retention enabled, retention days, batch size를 변경하고 `Save`로 저장할 수 있다.

Version UI:

- Object version panel provides version Download/Restore/Delete actions.
- Download saves the selected historical bytes without changing active object.
- Delete removes only the selected historical version and refreshes dashboard usage.

### 5.5 AccessKeyView

기능:

- Access Key 목록
- Access Key 생성
- Bucket scope 선택
- `READ`, `WRITE`, `DELETE` permission 선택
- 여러 bucket scope를 누적해 하나의 Access Key 발급
- bucket별 scope/permission 표시
- 생성된 policy 이름 표시
- Secret Key 1회 표시
- Access Key 비활성화 버튼

- Access Key scope builder exposes `READ`, `WRITE`, `DELETE`, and `ADMIN` permission checkboxes.

### 5.6 AdminUserView

기능:

- 사용자 목록
- 사용자 생성
- 사용자 생성 시 조직 선택
- ORG_ADMIN에게 자기 조직 사용자 관리 화면 표시
- 사용자 비활성화
- 역할 변경

### 5.7 AdminOrganizationView

기능:

- 조직 목록
- 조직 생성
- 기본 쿼터 표시
- 조직별 사용량, bucket count, object count 표시
- ORG_ADMIN에게 자기 조직 usage 표시
- 사용자 생성 화면과 조직 선택 연동

- Admin can delete empty organizations with a confirm dialog.

### 5.8 AdminQuotaPolicyView

기능:

- `USER`, `ORGANIZATION`, `BUCKET` target quota policy 목록 표시
- target type 선택 후 users/organizations/buckets 목록에서 target 선택
- target 검색 입력으로 긴 user/organization/bucket 목록 필터링
- quota GiB 입력 후 정책 저장
- quota policy 변경 사유 reason 입력
- 기존 quota policy의 Edit 버튼으로 target과 quota를 form에 prefill하고 quota만 빠르게 수정
- target별 used bytes, quota bytes, remaining bytes 표시
- quota policy 변경 history에서 create/update/delete, 이전 quota, 신규 quota, actor, reason, 시각 표시
- quota policy 삭제 confirm dialog 연동

### 5.9 AdminAuditLogView

기능:

- 감사 로그 목록
- eventType 필터
- actor 필터
- requestId 필터
- targetType/targetId 필터
- result 필터
- 기간 필터
- limit 필터
- nextCursor 기반 다음 로그 로드

## 6. 상태 관리

MVP는 Vue `reactive` 기반 lightweight store를 사용한다.

```text
authStore: session/user/token, role computed, API token sync, sessionStorage token restore
```

확장 시 Pinia store로 분리한다.

```text
bucketStore
objectStore
accessKeyStore
adminStore
systemStore
```

## 7. API 클라이언트

공통 처리:

- baseURL
- JWT header
- JSON API, 파일 다운로드, 파일 업로드 401 refresh retry 처리
- refresh 실패 시 token/session state와 화면 데이터를 정리
- 새로고침 시 sessionStorage token을 복구하고 `/api/users/me`로 사용자 정보를 재확인
- 에러 응답 변환
- 에러 응답의 `requestId`를 alert에 표시해 운영 문의와 감사 로그 추적에 사용
- 파일 업로드 progress
- 파일 업로드 abort signal과 재시도 상태
- multipart upload part PUT 병렬 전송, ETag 수집, complete API 호출
- Browser는 CORS에 노출된 `ETag` header만 읽을 수 있으므로 MinIO bucket CORS `ExposeHeaders`에 `ETag`가 필요하다.
- multipart upload 실패/취소 시 abort API best-effort 호출

## 8. MVP 구현 순서

1. 기존 Vue 예제 화면 제거
2. 기본 레이아웃 생성
3. API client 생성
4. DashboardView
5. BucketListView
6. ObjectExplorerView
7. LoginView
8. AccessKeyView
9. Admin 화면

## 9. UX 원칙

- 대용량 파일 업로드 상태를 표시한다.
- 128 MiB 이상 파일은 part별 presigned URL을 받아 제한된 동시성으로 병렬 업로드한다.
- 기본 multipart part 동시 업로드 수는 `VITE_MULTIPART_UPLOAD_CONCURRENCY=4`이며 client에서 1~8 범위로 제한한다.
- multipart part upload는 network error, 408, 429, 5xx 응답에 대해 jitter가 적용된 exponential backoff로 재시도한다. 기본값은 `VITE_MULTIPART_UPLOAD_PART_RETRIES=2`, `VITE_MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS=500`, `VITE_MULTIPART_UPLOAD_RETRY_JITTER_RATIO=0.25`이다.
- MinIO CORS가 `ETag`를 expose하지 않으면 multipart complete에 필요한 part ETag를 수집할 수 없으므로 업로드 실패로 처리한다.
- 대용량 파일 업로드 중 취소할 수 있고, 실패 또는 취소된 마지막 업로드는 같은 bucket/key/file로 재시도할 수 있다.
- multipart upload 실패/취소 시 미완료 part를 abort하도록 Backend에 정리 요청을 보낸다.
- tab close나 네트워크 완전 단절로 abort 요청이 전송되지 못하면 Backend cleanup scheduler가 만료 session을 `EXPIRED`로 전환하고 MinIO multipart upload를 abort한다.
- 버킷 삭제, 파일 삭제, 권한 회수, Access Key/사용자 비활성화는 확인 모달을 사용한다.
- 권한 없는 작업은 숨기거나 비활성화한다.
- 긴 파일명은 줄임 처리와 tooltip을 사용한다.
- 용량은 사람이 읽기 쉬운 단위로 표시한다.
- 오류 메시지는 짧고 원인 중심으로 표시한다.
- 서버 오류에는 `Request ID`를 함께 표시한다.

