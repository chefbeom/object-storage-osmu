# OSMU Feature Inventory

## Current Completion Correction

- MVP demo current estimate: 90-95% after the durable Docker/MariaDB/MinIO/Browser/real S3 client gate and hard readiness gate wrote `currentDemoStatus=docker-durable-demo-verified`.
- Full B2B product current estimate: about 45% after Kubernetes HA safety rails, HA/DR live evidence script, dedicated Kubernetes HA/DR Readiness CI workflow, Kubernetes backup/restore namespace/backup artifact/isolated restore drill scripts, external DR bucket bootstrap and immutability preflight, bounded and hardened external DR artifact transfer helper, DR drill orchestration wrapper, restore smoke helper, DR evidence API request helper, Kubernetes DR finalization wrapper, Kubernetes DR Finalizer CI workflow, persisted restore drill evidence history, dashboard restore evidence visibility, admin dashboard operations readiness evidence API and frontend summary/remediation/evidence-plan/invocation/invocation-unblock/dispatch-preflight/workflow-run-id/artifact-collection/artifact-import/finalizer/evidence-handoff/convergence/Kubernetes report sync visibility, convergence-level Kubernetes report sync ready gate, Kubernetes report sync artifact collection/import support, Kubernetes report sync live dashboard polling verifier, Kubernetes operations report ConfigMap/backend Pod mount verifier, Kubernetes/Helm operations report mount plus ConfigMap sync helper that republishes sync evidence for dashboard visibility, CI workflow, storage expansion runner RBAC, dry-run evidence scripts, storage expansion finalization wrapper, Storage Expansion Finalizer CI workflow, operations readiness artifact gate, operations evidence plan helper, guarded operations evidence plan invocation helper, operations invocation unblock plan helper, operations dispatch preflight helper, operations workflow run id plan helper, operations artifact collection plan helper, operations evidence handoff helper with finalizer-missing/pending routing, no-execute operations readiness convergence helper, Operations Readiness Finalizer CI workflow, Operations Readiness Artifact Finalizer CI workflow, IAM/RBAC finalizer evidence and dedicated IAM/RBAC Finalizer CI workflow, security evidence writer scripts for image signing plus container scan/SBOM evidence, a security evidence finalizer that promotes non-synthetic CI artifacts, Security Evidence Finalizer CI workflow, image digest capture, SBOM SHA256 hash evidence, cross-platform PowerShell command propagation for finalizer CI workflows, and operations readiness remediation metadata for remaining live/security evidence gaps.
- Durable MVP demo evidence: `.osmu-run/latest-durable-demo-gate.json`, `.osmu-run/latest-durable-mvp-finalize.json`, and `.osmu-run/latest-demo-readiness.json` show `result=ready` / `currentDemoStatus=docker-durable-demo-verified` from 2026-06-15 22:12 KST.
- Remaining MVP polish blockers: GitHub-hosted durable/real S3/Browser/image-signing evidence, host-installed `aws` or `mc` client smoke outside Docker, and final demo packaging notes.

작성일: 2026-06-18

이 문서는 OSMU 프로젝트의 현재 구현 상태, 남은 목표, MVP 데모 가능성, 다음 개발 순서를 한 곳에서 확인하기 위한 기능 인벤토리입니다.

## 1. 제품 정의

OSMU는 기업 내부에서 대용량 파일, 이미지, 영상, 로그, 비정형 데이터를 중앙 저장소로 관리하고, REST API와 S3 호환 API를 함께 제공하는 private object storage management platform입니다.

최종 목표는 다음과 같습니다.

- 스트리밍 플랫폼, 클라우드 스토리지 플랫폼, 자체 스토리지 플랫폼이 필요한 기업에 B2B 제품으로 제공
- AWS S3를 쓰지 않고 자체 스토리지를 운영하려는 조직에 S3 호환 접근 제공
- MariaDB 기반 control plane metadata 관리
- MinIO 기반 object binary 저장
- 관리자 콘솔, 개발자 콘솔, IAM/API Key, 권한, quota, audit, backup, data-flow monitoring 제공
- MinIO pod + PV pool 증설 방식의 capacity expansion workflow 제공
- 장기적으로 RAID/JBOD, 고급 백업, 비용/사용량 분석, 운영 자동화까지 확장

## 2. 전체 완료율

현재 상태는 "로컬 durable MVP 데모는 검증됐고, 상용 B2B 제품으로 가는 운영/보안 증적을 닫는 단계"입니다.

| 영역 | 추정 완료율 | 상태 |
| --- | ---: | --- |
| 기획/요구사항/문서 | 70% | 목표, API, DB, 배포, 보안, 테스트 문서가 있음 |
| 프론트엔드 콘솔 | 55% | 로그인, 페이지 분리, 대시보드 palette, data-flow monitoring 패널, operations readiness 요약/remediation/evidence plan/invocation/invocation unblock/dispatch preflight/workflow run id/artifact collection/artifact import/finalizer/evidence handoff action 표시, admin/developer 화면 뼈대가 있음 |
| 백엔드 REST API | 50% | auth, bucket, object, access key, admin, dashboard, data-flow monitoring, storage expansion, restore drill evidence history, operations readiness dashboard evidence/remediation/evidence plan/invocation/invocation unblock/dispatch preflight/workflow run id/artifact collection/artifact import/finalizer/evidence handoff API가 있음 |
| MariaDB metadata | 35% | Flyway migration 39개와 repository 구현이 있음 |
| MinIO/S3 호환 | 35% | S3 API 일부, SigV4, MinIO adapter, smoke script가 있음 |
| Docker/local demo | 90% | Docker/MariaDB/MinIO/backend/frontend durable gate, Browser E2E, Docker integration smoke, Dockerized real S3 client smoke가 `docker-mc` 기준 통과 |
| Kubernetes/Helm | 75% | Draft manifests/Helm chart, ServiceAccount hardening, storage expansion RBAC, backup CronJobs, backup drill evidence script, restore namespace preparation helper, external DR bucket bootstrap, external DR bucket immutability preflight, bounded and hardened external DR artifact transfer helper, backup artifact preflight helper, isolated restore drill helper, DR drill orchestration wrapper, restore smoke helper, DR evidence API request helper, Kubernetes DR finalization wrapper, Kubernetes DR Finalizer CI workflow, storage expansion finalization wrapper, Storage Expansion Finalizer CI workflow, dedicated Kubernetes HA/DR Readiness CI workflow, Operations Readiness Finalizer CI workflow, Operations Readiness Artifact Finalizer CI workflow, operations readiness artifact gate, PDB, topology spread, and live HA/DR evidence script exist; actual cluster verification is still needed |
| 테스트/검증 자동화 | 78% | 프론트/문서/manifest/static gate, backend Gradle tests, Docker durable gate, Browser E2E, Docker integration smoke, Dockerized real S3 client smoke, operations readiness, operations evidence plan verifier, guarded operations evidence plan invocation verifier, operations invocation unblock plan verifier, operations dispatch preflight verifier, operations workflow run id plan verifier, operations artifact collection plan verifier, operations evidence handoff verifier with finalizer-missing/pending fixtures, operations readiness convergence verifier, Kubernetes report sync live dashboard polling verifier, Kubernetes report ConfigMap/backend Pod mount verifier, pending evidence remediation metadata, operations readiness finalizer plan self-test, cross-platform finalizer `pwsh` command propagation check, operations readiness artifact importer self-test, operations readiness dashboard API/frontend invocation unblock, dispatch preflight, workflow run id, artifact collection, artifact import, finalizer, evidence handoff, convergence visibility test, Operations Readiness Artifact Finalizer CI draft, Kubernetes HA/DR Readiness CI draft, IAM/RBAC finalizer self-test와 전용 IAM/RBAC Finalizer CI draft, security evidence writer/finalizer self-test, Security Evidence Finalizer CI draft, digest/hash evidence 검증은 통과, live Kubernetes/security CI evidence는 환경 필요 |
| 상용화 기능 | 15% | 운영/보안/확장 기능의 설계와 일부 초안만 있음 |

전체 B2B 제품 기준 완료율은 약 45%입니다.
MVP 데모 기준 완료율은 약 90~95%입니다.

## 3. 현재 검증된 것

최근 로컬에서 다음 검증은 통과했습니다.

- `scripts/verify-local.ps1 -SkipDocker -SkipBackend`
- Git whitespace check
- `.env` ignore check
- PowerShell script parse check
- MVP release decision self-test
- CI workflow draft check
- image signing policy draft check
- commercial readiness draft check
- OpenAPI MVP contract check
- Kubernetes manifest draft check
- Helm chart draft check
- container hardening draft check
- TLS ingress draft check
- secret rotation policy draft check
- backup restore drill draft check
- Prometheus observability draft check
- monitoring artifacts draft check
- Prometheus Operator draft check
- Flyway migration version check: 39 migrations
- frontend unit tests: 69 passed
- frontend production build
- backend Gradle tests
- Docker/MariaDB/MinIO local demo Browser E2E
- Docker integration smoke
- Dockerized real S3 client smoke with `docker-mc`
- durable MVP finalize hard gate

아직 검증하지 못한 핵심 항목은 다음과 같습니다.

- host-installed `aws` CLI or `mc` S3 client smoke outside Docker
- GitHub-hosted durable Docker, real S3 client, Browser E2E, and image signing workflow runs
- 실제 Kubernetes/Helm render/apply
- 실제 MinIO Operator Tenant/Pool 증설 dry-run/apply

## 4. 기능별 현재 상태

### 4.1 로그인과 권한

구현된 것:

- `/login` 페이지
- 관리자/개발자 로그인 모드 선택
- 자동 로그인
- 아이디 저장
- 비밀번호 보기/숨김
- JWT session store
- route guard
- role 기반 admin/audit 접근 제한
- `AdminRbacPolicy` 기반 관리자 API allowlist
- `ORG_ADMIN` 조직 스코프 사용자/조직 조회와 global admin API 차단 테스트
- `iam-rbac-matrix.md` 기반 role/endpoint/dashboard panel 권한 표와 verifier
- `kubernetes-rbac-matrix.md` 기반 ServiceAccount/token automount/cluster RBAC hardening 표와 verifier
- Storage Expansion runner 전용 namespace-scoped ServiceAccount/Role/RoleBinding 초안. `Tenant/osmu-minio` patch/update와 legacy `StatefulSet/osmu-minio` rollback에 필요한 최소 권한만 허용하며 Secret read, Pod exec, create/delete, cluster-scoped RBAC는 차단
- `verify-storage-expansion-rbac-auth.ps1` 기반 live `kubectl auth can-i` evidence 수집 스크립트. cluster 없이 `-PlanOnly`로 실행 계획 확인 가능
- `verify-storage-expansion-server-dry-run.ps1` 기반 MinIO Operator Tenant CRD, 기존 Tenant, server-side dry-run evidence 수집 스크립트. `-ImpersonateRunner`와 `-PlanOnly` 지원
- `finalize-storage-expansion.ps1` 기반 storage expansion finalization wrapper. RBAC auth, server-side dry-run, optional backend dry-run/apply runner 호출을 하나의 증거 JSON/Markdown으로 묶고, 실제 apply는 `-RunBackendApply -ConfirmApply`가 있을 때만 수행
- `.github/workflows/storage-expansion-finalizer-ci.yml` 기반 수동 CI workflow. plan-only가 기본이며, live evidence는 `run_live=true`와 `OSMU_KUBECONFIG_BASE64` secret이 있을 때만 수행
- 관리자 계정도 작업 가능하도록 admin route 구성

남은 것:

- refresh token/session 만료 UX 정리
- SSO/OIDC 검토
- 부서/team 단위 RBAC
- read-only auditor 역할
- 실제 운영용 계정 bootstrap 정책

### 4.2 개발자 콘솔

구현된 것:

- 개발자 페이지 분리
- S3 client config 조회
- Access Key 생성/목록/삭제/회전
- bucket scope 기반 권한 표현
- secret key 1회 표시 방향
- API Key 기반 S3 사용 흐름 초안

남은 것:

- 개발자용 onboarding flow
- SDK 예제 자동 생성
- access key 사용량/마지막 사용 시각 분석
- key 만료/rotation grace period
- real S3 client compatibility matrix

### 4.3 관리자 콘솔

구현된 것:

- admin page 분리
- 조직/사용자 생성
- 사용자 활성/비활성
- bucket permission
- quota policy
- object share policy
- lifecycle/retention
- storage expansion request
- runner preflight

남은 것:

- 관리자 작업 실패 시 remediation UX
- 승인 workflow
- 감사/보안 정책 화면 정리
- 운영자용 기본 preset
- 권한별 panel 표시 제한

### 4.4 대시보드와 panel palette

구현된 것:

- dashboard page 분리
- widget catalog
- palette에서 widget 추가
- section order
- drag reorder
- collapse
- widget option schema
- custom preset CRUD
- preset export/import
- bundle export/import
- role/organization default preset
- adminOnly dashboard panel role filtering
- backup readiness panel의 latest restore drill evidence result/environment/recordedAt 표시

남은 것:

- 기본 dashboard preset 3종: executive, storage ops, security/audit
- 조회 mode와 편집 mode 구분
- widget별 refresh interval
- panel별 세부 권한 matrix와 read-only role 적용
- 빈 상태, 오류 상태, loading 상태 polish

### 4.5 bucket/object 저장

구현된 것:

- bucket 생성/조회/삭제
- object upload/download/list/delete
- object metadata
- tag
- prefix browse/search
- presigned URL
- multipart upload/resume 초안
- trash/restore/purge
- versioning/retention/lifecycle 일부

남은 것:

- 대용량 업로드 중단/재개 E2E
- 실제 MinIO multipart resume 검증
- S3 직접 업로드 이후 metadata drift sync
- 대량 object search/filter
- versioning + multipart overwrite edge case

### 4.6 S3 호환 API

구현된 것:

- path-style S3 API 초안
- virtual-hosted-style routing 초안
- SigV4 header auth
- presigned auth
- bucket/object 기본 동작
- range GET
- conditional request
- copy object
- tagging
- multi-delete 일부
- S3 XML error response

남은 것:

- AWS CLI/boto3/s3cmd/s3fs/goofys 호환 matrix
- streaming payload signature
- multipart edge case
- S3 compatibility 문서화
- 지원/미지원 API 명확화

### 4.7 MariaDB metadata

구현된 것:

- Flyway migration V1~V39
- bucket/object/access key/audit/quota/dashboard/storage expansion/restore drill evidence repository
- in-memory repository와 MariaDB repository 병행 구조

남은 것:

- 실제 MariaDB integration test
- migration rollback 전략
- index/slow query 검증
- metadata drift reconciliation
- backup/restore drill 실검증

### 4.8 MinIO와 storage backend

구현된 것:

- MinIO adapter
- in-memory adapter
- local Docker MinIO compose
- access policy provisioner 초안
- storage health endpoint

남은 것:

- MinIO user/policy provisioning 실패 복구
- bucket CORS/versioning/lifecycle 실제 동기화
- object storage 장애 시 UX/API error 정리
- MinIO admin API 기반 capacity/health 수집

### 4.9 용량 증설

구현된 것:

- storage expansion request
- expansion plan
- manifest preview/download
- dry-run/apply/rollback runner 초안
- storage expansion finalization wrapper
- execution history
- output masking
- log retention
- GitOps artifact bundle
- GitOps PR runner 초안
- summary/dashboard 연동

목표 구조:

- 기본 MinIO pod set은 4개 pod + 각 pod별 PV 구조
- 증설 요청 시 요청 용량에 맞춰 MinIO pod + PV pool 추가
- GitOps/Helm/MinIO Operator 기반으로 안전하게 dry-run, 승인, apply, rollback

남은 것:

- 실제 Kubernetes cluster에서 finalizer 기반 dry-run/apply 검증
- 실제 MinIO Operator Tenant CRD 검증
- 증설 승인 workflow
- 증설 후 capacity/health evidence 자동 수집
- 실패 원인별 rollback/remediation UX

### 4.10 배포와 운영

구현된 것:

- Docker Compose draft
- local demo start/seed/verify/stop script
- Docker config helper
- Kubernetes draft manifest
- Helm chart draft
- TLS ingress draft
- network policy draft
- container hardening draft
- monitoring artifacts
- Prometheus Operator draft
- release report/audit/decision/notes script

남은 것:

- Docker daemon 환경에서 full smoke
- backend image build/run 검증
- frontend nginx image 검증
- 실제 remote deployment 반복 검증
- GitHub Actions release gate 실제 green check
- image signing 실제 적용

## 5. 당장 필요한 개발 순서

1. 로컬 실행 환경 정리
   - JDK 17+ 경로 확보
   - Docker Desktop 실행
   - `scripts/verify-prototype-prerequisites.ps1 -RequireJava -RequireNode -RequireDocker -RequireRuntime` 통과

2. full demo smoke
   - `scripts/start-local-demo.ps1 -SeedDemo -VerifyDemo`
   - MariaDB, MinIO, backend, frontend health 확인
   - `/login`부터 admin/developer 화면까지 브라우저 확인

3. backend test 확정
   - `osmu-backend/gradlew.bat test`
   - 실패 테스트 수정
   - auth/access key/storage expansion/dashboard test 우선

4. S3 client smoke
   - built-in SigV4 smoke
   - AWS CLI 또는 MinIO Client `mc`
   - bucket create, object put/get, range, tag, copy, delete 검증

5. 화면 polish
   - 로그인 다음 첫 화면 정리
   - dashboard 조회/편집 mode 분리
   - admin/developer 각각의 핵심 workflow를 버튼 순서대로 연결

6. MVP release gate
   - `scripts/verify-prototype-release.ps1`
   - release report, audit, decision, notes 동기화
   - blocker 목록을 release checklist에 반영

## 6. 현재 결론

OSMU는 현재 "상용 제품"은 아니지만, "MVP 데모 가능한 웹/백엔드"를 만들기 위한 핵심 재료는 이미 많이 들어와 있습니다.

가장 가까운 목표는 기능을 더 벌리는 것이 아니라, 다음 세 가지를 실제로 통과시키는 것입니다.

- `/login` → 관리자/개발자 콘솔 → bucket/object/access key/storage expansion 기본 flow
- MariaDB + MinIO + backend + frontend full demo
- release gate script가 만든 report/audit/decision/notes

이 세 가지가 통과하면 MVP 데모 완료율은 약 70% 이상으로 올라갑니다.
