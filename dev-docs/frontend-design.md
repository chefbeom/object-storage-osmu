# OSMU Frontend Design

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
- 버킷 삭제
- 사용량 표시
- 권한 표시

### 5.4 ObjectExplorerView

기능:

- prefix 기반 탐색
- 파일 목록
- 파일 업로드
- 파일 다운로드
- 파일 삭제
- 업로드 진행률
- 빈 상태 표시

### 5.5 AccessKeyView

기능:

- Access Key 목록
- Access Key 생성
- Secret Key 1회 표시
- Access Key 비활성화

### 5.6 AdminUserView

기능:

- 사용자 목록
- 사용자 생성
- 사용자 비활성화
- 역할 변경

### 5.7 AdminAuditLogView

기능:

- 감사 로그 목록
- eventType 필터
- actor 필터
- 기간 필터

## 6. 상태 관리

Pinia store:

```text
authStore
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
- 401 처리
- 에러 응답 변환
- 파일 업로드 progress

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
- 삭제 작업은 확인 모달을 사용한다.
- 권한 없는 작업은 숨기거나 비활성화한다.
- 긴 파일명은 줄임 처리와 tooltip을 사용한다.
- 용량은 사람이 읽기 쉬운 단위로 표시한다.
- 오류 메시지는 짧고 원인 중심으로 표시한다.

