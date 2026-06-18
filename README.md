# OSMU - 사설 오브젝트 스토리지 관리 플랫폼

OSMU(Object Storage Management Utility)는 기업 내부망 또는 전용 인프라에서 대용량 파일, 이미지, 영상, 로그, AI 데이터셋을 버킷 단위로 관리하기 위한 사설 오브젝트 스토리지 관리 플랫폼입니다. MinIO를 실제 오브젝트 저장소로 사용하고, Spring Boot 백엔드가 인증, 권한, 메타데이터, 감사 로그, quota, 운영 readiness, data-flow monitoring을 담당합니다. Vue 기반 웹 포털은 관리자와 개발자가 브라우저에서 버킷, 오브젝트, Access Key, 운영 상태를 다룰 수 있게 합니다.

현재 저장소는 로컬 durable MVP 데모를 검증 가능한 상태로 유지하면서, Kubernetes/Helm, 백업/복구, HA/DR, 보안 evidence, 운영 readiness 자동화까지 제품화 범위를 확장하는 중입니다.

## 핵심 목표

- AWS S3와 호환되는 REST/S3 API를 제공하되, 기업 내부에서 자체 운영 가능한 storage control plane을 제공한다.
- MariaDB에는 사용자, 조직, 버킷, 오브젝트 인덱스, 권한, 감사 로그, quota, readiness evidence 같은 metadata를 저장한다.
- MinIO에는 실제 오브젝트 binary와 multipart payload를 저장한다.
- 웹 포털에서 관리자 콘솔, 개발자 콘솔, bucket/object 탐색, Access Key, quota, audit, lifecycle, 공유, dashboard, data-flow monitoring을 제공한다.
- Docker Compose 로컬 MVP에서 시작해 Kubernetes/Helm 운영 배포, 백업/복구, HA/DR, 보안 evidence, storage expansion workflow까지 확장한다.

## 현재 상태

- 로컬 durable MVP 데모: Docker Compose 기반 MariaDB + MinIO + Backend + Frontend 조합으로 검증 가능.
- Web Portal: 로그인, dashboard, bucket/object, admin/developer, audit, lifecycle, share, quota, storage expansion, operations readiness, data-flow monitoring 화면 제공.
- Backend: REST API, S3 호환 API, SigV4, bucket/object, multipart, CopyObject, multi-delete, Access Key, dashboard/readiness, monitoring API 제공.
- Operations: Kubernetes/Helm draft, monitoring artifact, backup/restore drill, storage expansion runner, security evidence writer/finalizer, operations readiness finalizer와 verifier 제공.
- 남은 큰 축: 실제 운영 클러스터 evidence, GitHub-hosted durable gate evidence, host `aws`/`mc` smoke, 장기 analytics/time-series, 고급 S3 parity.

## 아키텍처 개요

OSMU는 다섯 plane으로 나누어 이해하면 쉽습니다.

- **Web/API Plane**: 사용자가 접근하는 Vue Web Portal, REST API, S3 compatible API.
- **Control Plane**: Spring Boot backend. 인증, RBAC, bucket/object 정책, quota, lifecycle, Access Key, readiness, monitoring 흐름을 조정한다.
- **Metadata Plane**: MariaDB. 사용자, 조직, 버킷, 오브젝트 인덱스, audit, data-flow event, 운영 evidence를 저장한다.
- **Data Plane**: MinIO. 실제 오브젝트 byte, multipart part, bucket payload를 저장한다.
- **Operations Plane**: scripts, CI, Docker, Kubernetes, Helm. 배포, 검증, 백업/복구, HA/DR, security evidence를 자동화한다.

```mermaid
flowchart LR
    User["관리자 / 개발자"] --> Portal["Vue Web Portal"]
    App["업무 시스템"] --> Rest["REST API"]
    S3Client["AWS CLI / SDK / mc / s3fs"] --> S3API["S3 Compatible API"]

    Portal --> Backend["Spring Boot Backend<br/>Control Plane"]
    Rest --> Backend
    S3API --> Backend

    Backend --> Auth["Auth / RBAC"]
    Backend --> Bucket["Bucket Service"]
    Backend --> Object["Object Service"]
    Backend --> AccessKey["Access Key Service"]
    Backend --> Dashboard["Dashboard / Readiness"]
    Backend --> Monitoring["Data-flow Monitoring"]

    Auth --> MariaDB["MariaDB<br/>Metadata Plane"]
    Bucket --> MariaDB
    Object --> MariaDB
    AccessKey --> MariaDB
    Dashboard --> MariaDB
    Monitoring --> MariaDB

    Bucket --> Adapter["ObjectStorageAdapter"]
    Object --> Adapter
    Adapter --> MinIO["MinIO<br/>Data Plane"]
    MinIO --> Volume["Disk / Volume / Erasure Coding"]

    Backend --> Metrics["Actuator / Prometheus / Evidence API"]
    Metrics --> Ops["Scripts / CI / Kubernetes / Helm"]
    Ops --> Reports[".osmu-run evidence reports"]
```

## 구성 요소 관계

| 구성 요소 | 책임 | 직접 의존 |
| --- | --- | --- |
| `osmu-frontend` | Vue 웹 포털, mock API, E2E 진입점 | Backend REST API |
| `osmu-backend` | REST/S3 API, 인증/RBAC, 정책, metadata orchestration | MariaDB, MinIO, Actuator |
| MariaDB | metadata source of truth, audit, readiness, data-flow event | Backend repository |
| MinIO | 실제 오브젝트 binary 저장 | `ObjectStorageAdapter` |
| `infra/local` | Docker Compose durable demo | Backend, Frontend, MariaDB, MinIO |
| `infra/k8s` | Kubernetes manifest draft | Backend, Frontend, MariaDB, MinIO, CronJob |
| `infra/helm/osmu` | Helm chart draft | Kubernetes 리소스 |
| `infra/monitoring` | Prometheus rule, Grafana dashboard draft | Actuator metrics |
| `scripts` | 로컬 검증, release gate, operations evidence 자동화 | Docker, Java, Node, kubectl, gh |
| `dev-docs` | 요구사항, API, DB, frontend/backend, 운영 설계 | 구현 기준 문서 |

Frontend는 MariaDB나 MinIO에 직접 접근하지 않습니다. Backend API만 호출합니다. Backend는 control plane 판단을 MariaDB metadata와 권한 정책으로 수행하고, 실제 object byte 처리는 `ObjectStorageAdapter`를 통해 MinIO 또는 in-memory adapter에 위임합니다. Operations plane은 런타임을 직접 대체하지 않고, 배포와 evidence 생성을 자동화해 readiness 판단의 입력을 만듭니다.

## 주요 기능

- 인증/세션: JWT login, refresh/logout, route guard.
- 사용자/조직: 사용자 상태, 조직, 조직별 버킷 관리.
- 버킷: 생성, 목록, 상세, 삭제, quota, tag, permission.
- 오브젝트: 업로드, 다운로드, 목록, 검색, prefix 탐색, tag, soft delete, restore, purge.
- S3 호환 API: SigV4, bucket/object 기본 동작, range/conditional GET, CopyObject, multipart, multi-delete, checksum 일부, aws-chunked body decode 지원. 전체 지원/부분지원/미지원 범위는 `dev-docs/s3-compatibility.md`에 정리한다.
- Access Key: one-time secret, bucket scope, 권한 분리, revoke/bulk disable, MinIO policy 연동 초안.
- Lifecycle/Retention: rule dry-run, conflict report, S3 lifecycle XML import/export, version/trash retention cleanup.
- 공유/보안: object share link, password/IP 제한, usage limit, cleanup, analytics.
- Dashboard: widget catalog, layout preset, system/backup/quota/share/readiness/data-flow 요약.
- Monitoring: data-flow event 저장, filter, CSV export, source/operation trend chart, Prometheus/Grafana starter artifact.
- Storage Expansion: 증설 요청, dry-run/apply/rollback runner, GitOps artifact, execution history.
- Operations Readiness: evidence plan, invocation unblock, dispatch preflight, workflow run id, artifact import/finalizer, convergence report.

## 저장소 구조

```text
object-storage-osmu
├─ osmu-backend/             Spring Boot API, S3 compatibility, metadata repositories
├─ osmu-frontend/            Vue portal, mock API, Playwright E2E
├─ infra/local/              Docker Compose local durable demo
├─ infra/k8s/                Kubernetes manifests
├─ infra/helm/osmu/          Helm chart
├─ infra/monitoring/         Prometheus rules and Grafana dashboard draft
├─ scripts/                  Local verification, release gates, operations evidence automation
├─ dev-docs/                 Product, API, DB, frontend/backend, operations documents
├─ PRODUCT_REQUIREMENTS.md   Product requirements
└─ README.md                 Korean project entry point
```

## 실행 모드

### 1. 자동 선택 MVP 데모

현재 머신에서 가능한 가장 강한 데모 모드를 자동 선택합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-mvp-demo.ps1 -Verify -ForcePorts
```

선택 순서:

1. Docker 사용 가능: MariaDB + MinIO + Backend + Frontend durable demo.
2. JDK 17+ 사용 가능: Spring Boot in-memory prototype + Vite frontend.
3. 그 외: frontend mock demo.

중지:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stop-mvp-demo.ps1 -ForcePorts
```

### 2. Docker durable demo

MariaDB, MinIO, Backend, Frontend를 Docker Compose로 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local-demo.ps1 -SeedDemo -VerifyDemo
```

접속 정보:

- Frontend: `http://localhost:5173`
- Backend API: `http://localhost:8080/api`
- MinIO Console: `http://localhost:9001`
- OSMU login: `admin` / `password`
- MinIO login: `minioadmin` / `minioadmin`

중지:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stop-local-demo.ps1
```

데이터까지 초기화:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stop-local-demo.ps1 -ResetData
```

### 3. Frontend mock demo

Java나 Docker 없이 UI와 mock API를 확인할 때 사용합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-frontend-mock-demo.ps1
```

Mock login:

- Admin: `admin` / `password`
- Developer: `developer` / `password`

Mock API self-test:

```powershell
cd .\osmu-frontend
npm run mock:api:self-test
```

## 검증 명령

사전 조건 확인:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-prerequisites.ps1 -RequireNode
```

로컬 통합 검증:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1 -JavaHome C:\jdk-17
```

프론트엔드 unit test:

```powershell
cd .\osmu-frontend
npm run test:unit
```

백엔드 Gradle test:

```powershell
cd .\osmu-backend
$env:JAVA_HOME="C:\jdk-17"
$env:Path="$env:JAVA_HOME\bin;$env:Path"
.\gradlew.bat test --no-daemon
```

MVP readiness report:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-demo-readiness.ps1
```

Durable MVP gate:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-preflight.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-gate.ps1
```

최종 durable MVP 흐름:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -S3Client docker-mc
```

Browser E2E:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-mock-demo.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-prototype.ps1 -JavaHome C:\jdk-17
powershell -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-local-demo.ps1
```

S3 client smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client auto -RequireClient
powershell -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client docker-mc -RequireClient
```

## 문서 진입점

- `dev-docs/document-index.md`: 전체 문서 색인.
- `PRODUCT_REQUIREMENTS.md`: 제품 목표, MVP 범위, 최종 제품 범위.
- `dev-docs/feature-inventory.md`: 현재 구현 상태, gap, 다음 개발 방향.
- `dev-docs/system-architecture.md`: 시스템 아키텍처.
- `dev-docs/api-spec.md`: REST/S3 API 설계.
- `dev-docs/database-design.md`: MariaDB schema와 metadata 설계.
- `dev-docs/backend-design.md`: Spring Boot backend 설계.
- `dev-docs/frontend-design.md`: Vue portal 설계.
- `dev-docs/operation-monitoring.md`: health, metrics, backup readiness, data-flow monitoring.
- `dev-docs/mvp-release-checklist.md`: MVP release gate와 go/no-go 기준.

## 운영 evidence와 `.osmu-run`

검증 script는 실행 결과를 `.osmu-run` 아래 JSON/Markdown evidence로 저장합니다. 이 디렉터리는 로컬 실행 산출물이며 git에 포함하지 않습니다. Dashboard readiness API는 일부 evidence 파일을 읽어 운영자가 현재 blocker, 다음 명령, finalizer 상태를 웹 포털에서 볼 수 있게 합니다.

## 개발 기준

- 구현 기준은 `dev-docs`와 `PRODUCT_REQUIREMENTS.md`입니다.
- Backend 변경은 관련 service/controller/repository test 또는 focused Gradle test로 검증합니다.
- Frontend 변경은 `npm run test:unit`, mock API self-test, 필요 시 Playwright E2E로 검증합니다.
- 배포/운영 script 변경은 해당 `scripts/verify-*.ps1` self-test로 검증합니다.
- API contract 변경은 `dev-docs/api-spec.md`, `dev-docs/openapi-mvp.json`, `dev-docs/test-cases.md`를 함께 갱신합니다.

## 다음 개발 축

- 실제 Kubernetes cluster와 GitHub-hosted workflow evidence 수집.
- host-installed `aws` 또는 `mc` 기반 S3 smoke 검증.
- data-flow 장기 analytics를 위한 partition 또는 time-series 저장소 연동.
- tenant billing/chargeback을 위한 요금 정책, 비용 리포트, 임계치 모델링.
- S3 parity 확대: per-chunk streaming signature 검증, trailer checksum, checksum aggregation, exact AWS error schema.
- 운영 패키징: demo notes, release notes, troubleshooting, runbook 보강.
