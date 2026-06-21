# OSMU Development Roadmap

작성일: 2026-06-21 KST

이 문서는 OSMU를 로컬 MVP 데모에서 B2B 운영형 제품으로 끌어올리기 위한 개발 순서를 고정한다. 현재 제품 방향은 AWS S3 전체 복제가 아니라, 주요 S3 클라이언트가 자체 스토리지로 전환할 수 있는 대체 호환 계층과 운영 가능한 control plane을 완성하는 것이다.

## 1. 제품 목표

OSMU는 기업 내부 또는 고객이 통제하는 인프라에서 대용량 파일, 이미지, 영상, 로그, 비정형 데이터를 저장하고 관리하는 private object storage platform이다.

핵심 제품 축:

- MariaDB 기반 control plane metadata
- MinIO 기반 object binary storage
- 관리자 콘솔과 개발자용 API
- 사용자, 조직, 팀, 권한, Access Key, quota, audit 관리
- 백업/복구, HA/DR, 모니터링, 운영 evidence
- Kubernetes/Helm 배포와 운영 handoff
- S3-compatible replacement layer

S3 호환성은 제품 차별화의 중심이 아니라 전환 호환성이다. 새 S3 세부 동작은 지원 대상 클라이언트 smoke 실패, 고객 전환 blocker, 또는 OSMU control-plane 기능에 필요한 경우에만 roadmap에 넣는다.

## 2. 현재 기준선

- 로컬 durable MVP demo는 Docker/MariaDB/MinIO/backend/frontend/Browser E2E/Dockerized MinIO Client 기준 `docker-durable-demo-verified` 상태다.
- MVP demo 완성도는 `90-95%`이며, 로컬 demo GO와 production/B2B readiness는 분리한다.
- B2B 제품 완성도는 약 `45%`다. 운영 evidence, target 환경 검증, commercial/legal approval, live security evidence가 아직 남아 있다.
- Data-flow analytics는 상세 이벤트, daily rollup, materialized daily rollup, monthly rollup, stored monthly aggregate, retention job까지 구현되어 있다.
- Chargeback은 내부 비용 preview, pricing policy/proposal approval, invoice draft/final invoice/payment state, notification/payment handoff outbox, adapter retry worker, webhook/SMTP/payment handoff send boundary까지 구현되어 있다.
- Enterprise auth는 local password login을 유지한 상태에서 OIDC start/callback, LDAP bind/search, claim preview, admin-approved JIT provisioning, smoke evidence helper를 제공한다.

## 3. Phase 1 - Local MVP 유지

목표: 로컬에서 반복 가능한 demo와 회귀 검증 유지.

완료 기준:

- `scripts/verify-mvp-completion.ps1` 결과 `ready`
- Docker durable demo evidence 최신화
- Browser E2E와 Dockerized real S3 client smoke 유지
- README, release notes, demo package notes가 현재 상태와 일치

주요 후속:

- release candidate 전 `finalize-durable-mvp-demo.ps1 -S3Client docker-mc` 재실행
- host `aws` 또는 `mc` client smoke는 선택 증거로 유지

## 4. Phase 2 - Production Operations Evidence

목표: B2B 판매 전 target 환경에서 운영 가능성을 증명.

필수 evidence:

- storage backend telemetry `result=passed`
- secret/certificate rotation `result=passed`
- Kubernetes HA/DR readiness `result=passed`
- Kubernetes DR finalizer `result=ready`
- security evidence finalizer `result=passed`
- IAM/RBAC finalizer `result=passed`
- enterprise auth smoke `result=passed` 또는 계약상 `scope-out`
- commercial integration evidence `result=passed`
- commercial approval evidence `result=passed`
- operations handoff package `result=passed`
- operations readiness finalizer `result=ready`
- operations readiness convergence `result=ready`
- Kubernetes operations report sync `result=applied` 및 failed count `0`

우선순위:

1. `write-operations-evidence-plan.ps1`로 pending evidence 순서 확인
2. `invoke-operations-evidence-plan.ps1`를 plan-only로 실행해 placeholder와 승인 플래그 확인
3. workflow run id, artifact collection, artifact import, finalizer, convergence 순서로 evidence를 닫기
4. target cluster에서는 ConfigMap sync와 live dashboard polling verifier로 dashboard 노출까지 확인

## 5. Phase 3 - Analytics And Chargeback Scale

목표: 운영자가 tenant 사용량, 장기 트렌드, 내부 비용 모델을 안정적으로 볼 수 있게 한다.

현재 완료:

- detailed data-flow event view/export
- daily rollup JSON/CSV
- materialized daily rollup refresh/read/export
- monthly rollup JSON/CSV
- stored monthly aggregate refresh/read/export
- event/daily/monthly retention job
- MariaDB query-plan evidence, data-flow storage transition plan, manual data-flow storage plan evidence workflow/artifact import path, and Alertmanager/Grafana threshold target contract

남은 범위:

- target 규모 기준 table partitioning 또는 external time-series repository 선택
- backfill/dual-write/rollback runbook 검증
- target query latency와 retention budget evidence `result=passed` workflow artifact
- target tenant baseline 기반 Alertmanager/Grafana threshold value/receiver 튜닝 evidence

## 6. Phase 4 - Commercial Readiness

목표: paid pilot와 production sale에 필요한 상업/운영 문서를 evidence로 고정.

현재 완료:

- commercial readiness draft
- internal chargeback calculation
- pricing policy proposal/internal approval
- commercial price-list approval reference
- final invoice/payment state workflow
- notification/payment adapter send boundary와 retry state
- native payment provider adapter SPI/composite dispatch
- commercial integration/approval evidence writers and workflows
- operations handoff package writer/workflow

남은 범위:

- target commercial integration evidence
- target commercial approval evidence
- final legal/commercial approval
- 실제 card/bank/tax/ERP native provider adapter는 구체 고객 요구 전까지 out of scope

## 7. Phase 5 - Enterprise Auth Pilot

목표: local password login을 유지하면서 고객 IdP/directory 전환 가능성을 증명.

현재 완료:

- enterprise auth plan/readiness API
- OIDC authorization start
- OIDC callback/token/JWKS validation for existing local users
- LDAP bind/search login for existing local users
- OIDC claim preview and audit
- admin-approved JIT provisioning
- smoke evidence helper and CI workflow

남은 범위:

- target IdP OIDC callback smoke
- target LDAP bind/search smoke
- admin-approved JIT rollback/runbook evidence
- 계약상 enterprise auth 지연 시 `scope-out` evidence

## 8. Phase 6 - Product Hardening

목표: 장기 운영에 필요한 보안, 백업, 배포 안정성 강화.

주요 작업:

- target restore drill과 object count/byte reconciliation
- signed image evidence와 SBOM hash evidence
- secret rotation runbook 실제 실행
- cluster network access review
- storage expansion live evidence
- Helm values hardening
- runbook, troubleshooting, support escalation handoff

## 9. 다음 구현 우선순위

1. Production operations evidence chain 닫기
2. Data-flow storage transition plan을 target query-plan evidence와 연결
3. Commercial integration/approval target evidence 수집
4. Enterprise auth target smoke 또는 명시적 scope-out evidence 수집
5. Operations handoff package와 convergence를 finalizer-ready 상태로 유지
6. 주요 S3 client smoke 실패가 확인될 때만 S3 replacement layer 보강

## 10. 변경 규칙

- roadmap에서 새 production gate를 추가하면 `operation-monitoring.md`, `mvp-release-checklist.md`, 관련 verifier를 함께 갱신한다.
- 새 API나 role scope를 추가하면 `api-spec.md`, `openapi-mvp.json`, `iam-rbac-matrix.md`, `security-design.md`, backend/frontend tests를 함께 갱신한다.
- 새 DB table 또는 index를 추가하면 `database-design.md`, migration, rollback plan, metadata index verifier를 함께 갱신한다.
- 새 S3 동작을 추가할 때는 `s3-compatibility.md`에 replacement-use 근거를 남긴다.
