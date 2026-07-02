# OSMU Prototype Status

Last updated: 2026-06-30 KST

이 문서는 세션 사이에서 현재 구현 상태와 다음 개발 방향이 흐려지지 않게 고정하는 상태 문서다. 실행 증거는 `.osmu-run/`에 남고, 이 파일은 그 증거를 해석하는 기준이다.

## Status Summary

- Local durable MVP: ready for demo/pilot handoff on local Docker durable path; latest completion report remains pending until the plan-only durable finalizer artifact is refreshed by a Docker-ready finalize run.
- Current demo status: `docker-durable-demo-verified`.
- MVP demo estimate: 90-95%.
- Production/B2B readiness: pending target evidence, not blocked by local MVP demo status.
- S3 compatibility role: replacement layer, not AWS edge parity.
- S3-compatible replacement layer means common S3 clients can replace basic bucket/object flows, while AWS-specific edge behavior remains out of scope unless real client smoke fails.

## Latest Verification Snapshot

- Snapshot date: 2026-06-30 KST.
- MVP completion latest verification: result=pending, classification=local-durable-mvp-pending, localDurableMvpReady=false.
- Durable preflight latest handoff: result=pending, blockingActions=Docker daemon/Selected real S3 client path, nextAction=Start Docker Desktop and wait until docker info succeeds, then rerun durable preflight.
- Operations readiness latest verification: result=pending, passed=83, pending=19, total=102.
- Operations readiness pending categories: chargeback-closeout=1, commercial-approval=1, commercial-integration=1, data-flow=3, enterprise-auth=2, ha-dr=2, monitoring=1, operations-handoff-package=1, security-hardening=5, storage-backend=1, storage-expansion=1.
- Operations readiness pending remediation entries: 19.
- Operations evidence plan remediation coverage: source=19, entries=19, actions=19, missing=0, ready=true.
- Operations workflow run-id security finalizer hints: count=2, inputs=ImageSigningRunId/ContainerSecurityRunId, supplemental=ContainerSecurityRunId.
- Operations artifact collection latest verification: result=action-required, selectedActions=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19, securityEvidenceFinalizerReady=false, securityFinalizerInputRows=2, missingSecurityFinalizerInputs=ImageSigningRunId/ContainerSecurityRunId.
- Operations evidence handoff latest verification: result=blocked, bottleneck=confirm-input-free-blockers, missingWorkflowRunCount=19.
- Operations evidence handoff browser dispatch checklist: count=0, actionOrders=none, workflows=none, runIdParameters=none.
- Operations readiness convergence latest verification: result=action-required, readinessResult=pending, bottleneck=confirm-input-free-blockers, missingWorkflowRunCount=19, kubernetesReportSyncStale=false.
- S3 boundary latest verification: verify-s3-compatibility-boundary.ps1 passed.
- Prototype status verifier output: `.osmu-run/latest-prototype-status.json` records the reduced snapshot, durable preflight handoff, total/check counts, source readiness pending category summary/counts, pending remediation count, workflow run-id security finalizer hint summary, artifact collection security finalizer input checklist, handoff browser dispatch checklist, convergence, and evidence cross-check.
- B2B product estimate remains about 45% because the remaining work is target evidence, not local feature wiring.
- Current direction: keep closing target operations evidence; do not expand AWS S3 parity unless a supported replacement-client smoke or migration blocker proves product impact.

## Current Goal

기업이 퍼블릭 클라우드 저장소에만 의존하지 않고 대용량 파일을 저장, 관리, 공유, 재사용할 수 있는 B2B private object storage 플랫폼을 만든다. S3 호환성은 제품 핵심이 아니라 전환 비용을 낮추는 대체 레이어다.

## Verified Local State

- Backend runs at `http://localhost:8080/api`.
- Frontend runs at `http://localhost:5173`.
- Lightweight mode remains useful for fast in-memory smoke checks.
- Strongest local proof is Docker durable demo with MariaDB, MinIO, backend, frontend, Browser E2E, and Dockerized MinIO Client.
- Latest durable MVP evidence writes `.osmu-run/latest-durable-demo-gate.json`, `.osmu-run/latest-durable-mvp-finalize.json`, and `.osmu-run/latest-demo-readiness.json`.
- The current latest finalizer file is plan-only (`result=planned`), so the completion report stays pending until Docker is available for a full finalizer refresh.
- Current-machine readiness is `result=ready`, `currentDemoStatus=docker-durable-demo-verified`, `completionEstimate.mvpDemo=90-95%`, and `pendingDurableChecks=[]`.

## Implemented Local Scope

- Auth/user/org: login, refresh, logout, current user, JWT guard, admin user lifecycle, inactive-user blocking, organization create/list/quota/delete conflict guard.
- Bucket/object: bucket create/list/detail/delete, owner type, quotas, object upload/list/search/prefix browse/download, soft delete/restore/purge, tags, versions, checksum/ETag metadata.
- Sharing: temporary password/IP-restricted object share links, usage limits, admin policy caps, analytics, revoke, manual cleanup, scheduled cleanup.
- Access/audit/ops: access keys with scoped permission/status enforcement, audit filters/request metadata/CSV export, backup readiness API, Actuator Prometheus endpoint, share cleanup metrics.
- Lifecycle: retention rules, conflict report, dry run, delete, bucket lifecycle XML import/export.
- Frontend portal: login, dashboard, bucket/object/admin panels, share controls, quota policy panel, audit export, org delete, object explorer helpers, stable E2E selector contract, upload retry/abort and multipart resume coverage.
- S3-compatible replacement layer: manual SigV4 auth, bucket list, object PUT/HEAD/GET/DELETE, tagging, range GET, conditional requests, CopyObject, multipart path, multi-delete, virtual-hosted-style route support.
- Enterprise auth implemented locally: enterprise auth plan, OIDC callback, LDAP bind/search, claim preview, admin-approved JIT, and scope-out evidence path.
- Data-flow analytics implemented locally: detailed/daily/materialized/monthly/stored monthly flows, chargeback rollup, retention/run controls, and data-flow storage transition plan with target query-plan evidence contract.
- Commercial workflow implemented locally: pricing policy proposal, internal chargeback preview, payment-provider handoff outbox/history, adapter retry state, webhook/Slack/EMAIL SMTP relay safeguards, commercial integration evidence writer, and commercial approval evidence writer.
- Operations evidence chain implemented locally: storage backend telemetry, monitoring threshold evidence, secret rotation, commercial integration, commercial approval, enterprise auth smoke or scope-out, operations handoff package, support escalation handoff workflow/import, readiness artifact import, evidence plan, guarded invocation, workflow run id plan with saved JSON/GitHub REST API run-id collection, artifact collection plan, dispatch preflight, readiness convergence, Kubernetes operations report sync, and finalizer handoff.
- Deployment draft: Docker Compose, Kubernetes manifests, Helm chart, NetworkPolicy, non-root security contexts, TLS ingress, Prometheus scrape/dashboards/alerts, ServiceMonitor/PrometheusRule drafts, secret/certificate rotation policy, and backup/restore drill draft.

## Known External Blockers

- Target-environment storage backend telemetry evidence must be collected from the real MinIO/Kubernetes environment.
- Target monitoring threshold evidence must be collected after Prometheus rules, Grafana dashboards, Alertmanager routes, incident routing, and tenant baselines are reviewed.
- Target secret/certificate rotation evidence must be collected from the real environment.
- Target commercial integration and commercial approval evidence must be collected before production/B2B readiness can be claimed.
- Enterprise auth target smoke evidence must pass, or an approved scope-out must be recorded.
- Operations handoff package evidence must be completed against target readiness/convergence snapshots and reviewed support escalation handoff references.
- GitHub-hosted durable Docker, real S3 client, Browser E2E, image signing, container security, and security/operations finalizer artifacts remain external evidence gaps.

## Not Production Ready Yet

- Lightweight mode is demo/runtime smoke mode, not durable storage.
- Local MariaDB/MinIO durable mode is verified for MVP demo, but production deployment still needs target-environment evidence.
- Real S3 client compatibility has Dockerized MinIO Client evidence; host `aws` or host `mc` evidence is useful but optional unless a client smoke failure appears.
- Kubernetes and Helm assets are drafts until target cluster storage, networking, security, backup/restore, HA/DR, and monitoring evidence pass.
- Commercial/legal approval is not complete until target commercial approval evidence records final pricing, terms, support SLA, license agreement, legal approval, and pilot contract boundary references.
- Vendor-specific fixed SDK/schema card/bank/tax/ERP provider adapters and raw provider response storage remain out of scope; configurable native API bridge readiness is implemented and tracked through sanitized payment-provider adapter readiness snapshots.
- Media-specific processing remains later product work.

## Next Best Work

1. Production operations evidence chain: close storage backend telemetry, monitoring threshold, secret rotation, commercial integration, commercial approval, enterprise auth smoke or scope-out, operations handoff package, convergence, and Kubernetes operations report sync.
2. Data-flow storage transition plan: connect MariaDB partition or dual-write candidate decisions to target query-plan evidence, without storing raw SQL, raw EXPLAIN, credentials, or customer data.
3. Commercial integration/approval target evidence: collect sanitized target snapshots and final approval references.
4. Enterprise auth target smoke: collect target IdP/directory smoke evidence or explicit approved scope-out.
5. Operations handoff package: keep runbook, troubleshooting, rollback, escalation, support SLA, known gaps, commercial approval, and target evidence references finalizer-ready.
6. S3 replacement layer: improve only when common S3 client smoke reveals a real replacement blocker.