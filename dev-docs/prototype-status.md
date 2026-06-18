# OSMU Prototype Status

Last updated: 2026-06-18 10:35 KST

This document freezes the current prototype state so the project direction is not lost between sessions.

## Current Goal

Build a B2B-ready private object storage platform that companies can deploy for large file storage, management, sharing, reuse, and S3-compatible access without depending only on public cloud storage.

## Current Prototype Result

The current durable local prototype is usable as an MVP demonstration stack.

- Backend runs at `http://localhost:8080/api`.
- Frontend runs at `http://localhost:5173`.
- Lightweight mode still exists for fast in-memory checks, but the stronger local MVP proof is now the Docker durable demo with MariaDB and MinIO.
- Latest durable MVP evidence passed Docker preflight, backend Gradle tests, Docker Compose MariaDB/MinIO/backend/frontend Browser E2E, Docker integration smoke, Dockerized real S3 client smoke, durable release artifact generation, and the hard readiness gate on 2026-06-15 at 22:12 KST. It wrote `.osmu-run/latest-durable-demo-gate.json`, `.osmu-run/latest-durable-mvp-finalize.json`, and `.osmu-run/latest-demo-readiness.json` with `currentDemoStatus=docker-durable-demo-verified`.
- Latest current-machine MVP readiness is `result=ready`, `currentDemoStatus=docker-durable-demo-verified`, `completionEstimate.mvpDemo=90-95%`, and `pendingDurableChecks=[]`.
- Latest MVP release gate passed on 2026-06-14 at 05:14 KST with runtime smoke, demo smoke, built-in S3 SigV4 smoke, CI workflow verification, durable Docker CI workflow verification, real S3 client CI workflow verification, container security CI workflow verification, Browser E2E CI workflow draft verification, image signing policy/workflow draft verification, release notes generation, commercial readiness draft verification, OpenAPI MVP contract verification, Kubernetes manifest draft verification, Helm chart draft verification, deployment resource profile verification, NetworkPolicy draft verification, container hardening verification, TLS ingress verification, secret rotation policy verification, backup restore drill verification, Prometheus observability verification, monitoring artifacts verification, Prometheus Operator draft verification, backup readiness API test, global object share policy save/enforcement, password/IP-restricted object share link create/public download/list/download count/last access/manual cleanup/scheduled cleanup/revoke/analytics smoke and tests, user/bucket/organization quota policy API/enforcement/history reason smoke, frontend unit/build, stable E2E selector contract including object share link cleanup/password/IP/share-policy/analytics inputs and quota policy search/edit/reason/history controls, backend Gradle tests, MVP release decision self-test, and release artifact consistency verification. Docker integration, real S3 clients, Browser click E2E, actual signed image evidence, and final commercial/legal approval are still external optional gates.
- Release gate evidence is written locally to `.osmu-run/latest-release.json`; failed required gates also record `result=failed` and `errorMessage`. The report records CI workflow verification as `scope.ciWorkflow=included`, durable Docker CI workflow verification as `scope.durableDockerCiWorkflow=included`, real S3 client CI workflow verification as `scope.realS3ClientCiWorkflow=included`, container security CI workflow verification as `scope.containerSecurityCiWorkflow=included`, Browser E2E CI workflow draft verification as `scope.browserE2ECiWorkflow=included`, image signing policy/workflow draft verification as `scope.imageSigningPolicy=included`, release notes generation as `scope.releaseNotes=included`, commercial readiness draft verification as `scope.commercialReadiness=included`, OpenAPI verification as `scope.openApiContract=included`, Kubernetes draft verification as `scope.kubernetesManifests=included`, Helm chart verification as `scope.helmChart=included`, NetworkPolicy verification as `scope.networkPolicies=included`, container hardening verification as `scope.containerHardening=included`, TLS ingress verification as `scope.tlsIngress=included`, secret rotation policy verification as `scope.secretRotationPolicy=included`, backup restore drill verification as `scope.backupRestoreDrill=included`, Prometheus observability verification as `scope.prometheusObservability=included`, monitoring artifacts verification as `scope.monitoringArtifacts=included`, and Prometheus Operator draft verification as `scope.prometheusOperatorDraft=included`. `.osmu-run/` is ignored by git.
- Browser E2E is tracked in readiness evidence. Mock, Java backend prototype, and Docker-backed local demo Browser E2E paths have passed locally.
- A human-readable MVP audit can be generated from release evidence with `scripts/write-mvp-audit.ps1`; the default output is `.osmu-run/latest-mvp-audit.md`.
- The MVP audit includes a test-case evidence map that separates PASS, PARTIAL, and PENDING areas.

## Implemented Feature Groups

- Auth: login, refresh, logout, current user, JWT guard.
- User management: admin create/list/status update, inactive user login/token blocking, refresh token revocation.
- Organization management: create/list, quota, safe empty organization delete with conflict guard and audit.
- Bucket management: create/list/detail/delete, owner type, bucket quota, quota policy override/history, user quota policy, organization quota, permissions.
- Object management: upload, list/search, prefix browse, download, temporary password/IP-restricted share links with admin policy caps, usage limits, analytics, manual cleanup, and scheduled cleanup, soft delete, restore, purge.
- Metadata: object tags, bucket tags, checksum metadata, ETag, object versions.
- Access keys: one-time secret display, masked list, scoped permissions, status enforcement.
- Audit/operations: core event logging, filters, request metadata, CSV export, backup readiness API, Actuator Prometheus endpoint, share policy save audit, share analytics, share link cleanup metrics.
- Lifecycle: retention rules, conflict report, dry run, delete, bucket lifecycle XML import/export.
- S3 compatibility: manual SigV4 auth, bucket list, object PUT/HEAD/GET/DELETE, tagging, range GET, conditional requests, CopyObject, multipart path, multi-delete, virtual-hosted-style route support.
- Frontend portal: login, dashboard, bucket/object/admin panels, backup readiness panel, object share link create/list/revoke/cleanup controls with optional password and IP allowlist inputs, admin share policy controls, share analytics, password-protected/IP-restricted flags, usage count, and last-access visibility, quota policy panel with target search/edit prefill, reason input, and change history, stable E2E selector contract, bucket list summaries, upload state/progress guards, confirm dialog state, access key scope/revoke helpers, bucket lifecycle/tag wrappers, user/org controls, audit CSV export, organization delete control, object explorer prefix/highlight helpers, object metadata drift helpers, auth/session, API filter wrapper, object tag preflight validation, error/requestId handling, single upload abort/retry, multipart upload/retry/abort/resume flow, and multipart local resume unit coverage.
- Local/CI operations: start/stop lightweight prototype, local verification, GitHub Actions lightweight CI workflow, manual durable Docker CI workflow, manual real S3 client CI workflow, manual container security/SBOM CI workflow, manual Browser E2E CI workflow, manual GHCR/Cosign image publish/sign workflow, migration check, prototype gate, Docker compose files.
- Commercial readiness: B2B positioning, pilot packaging, licensing, and pricing draft with final approval still pending.
- Commercial readiness: B2B positioning, pilot packaging, licensing, and pricing draft with final approval still pending.
- Deployment draft: Kubernetes manifests and Helm chart draft for namespace/config, MariaDB, MinIO, backend, frontend, TLS ingress, starter resource requests/limits, NetworkPolicy draft, backend/frontend non-root security contexts, Prometheus scrape annotations, monitoring alert/dashboard artifacts, optional ServiceMonitor/PrometheusRule drafts, secret/certificate rotation policy draft, and backup/restore drill draft.
- Deployment draft: Kubernetes manifests and Helm chart draft for namespace/config, MariaDB, MinIO, backend, frontend, ingress, and starter resource requests/limits.
- Deployment draft: Kubernetes manifests and Helm chart draft for namespace/config, MariaDB, MinIO, backend, frontend, and ingress.

## Verified Commands

Ran successfully:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-prerequisites.ps1 -JavaHome "C:\Users\kjs99\AppData\Local\Temp\temurin-jdk17\jdk-17.0.19+10"
```

The prerequisite check returned success with optional warnings for Docker daemon, AWS CLI, and MinIO Client.

Passed:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-lightweight-prototype.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-lightweight-demo.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client auto
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-gate.ps1 -IncludeBuildVerify -IncludeBackendTests -JavaHome "C:\Users\kjs99\AppData\Local\Temp\temurin-jdk17\jdk-17.0.19+10"
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-release.ps1 -JavaHome "C:\Users\kjs99\AppData\Local\Temp\temurin-jdk17\jdk-17.0.19+10"
```

The final gate included:

- runtime health checks
- prototype prerequisite check
- Flyway migration version check
- lightweight API smoke
- seeded demo smoke
- built-in S3 SigV4 smoke
- frontend unit tests for stable E2E selector contract, object share link password/IP/usage/cleanup/share-policy/analytics selectors/API wrappers, bucket list summaries, upload state/progress guards, confirm dialog state, access key scope/revoke helpers, bucket lifecycle/tag wrappers, tag parsing/validation, object explorer prefix/highlight helpers, object metadata drift helpers, object tag preflight validation, auth session flows, API filter wrappers, error/requestId handling, single upload abort/retry, multipart upload/retry/abort/resume flow, and multipart local resume sessions
- frontend production build
- backend Gradle tests
- MVP release gate wrapper
- local release evidence report
- local MVP audit report
- local MVP go/no-go decision report
- local MVP release notes report
- commercial readiness draft verification in local verification
- MVP release decision self-test in local verification
- CI workflow draft verification in local verification
- Durable Docker CI workflow draft verification in local verification
- Real S3 client CI workflow draft verification in local verification
- Container security CI workflow draft verification in local verification
- Browser E2E CI workflow draft verification in local verification
- Image signing policy/workflow draft verification in local verification
- OpenAPI MVP contract verification in local verification
- Kubernetes manifest draft verification in local verification
- Helm chart draft verification in local verification
- Container hardening draft verification in local verification
- TLS ingress draft verification in local verification
- Secret rotation policy draft verification in local verification
- Backup restore drill draft verification in local verification
- Prometheus observability draft verification in local verification
- Monitoring artifacts draft verification in local verification
- Prometheus Operator draft verification in local verification
- MVP release artifact consistency verifier

## Known External Blockers

- Host `aws` CLI is not on `PATH`, so host AWS CLI S3 compatibility smoke is still optional pending.
- Host `mc` MinIO Client is not on `PATH`, so host MinIO client smoke is still optional pending.
- Dockerized MinIO Client smoke passed through `docker-mc`.
- GitHub-hosted durable Docker, real S3 client, Browser E2E, and image signing workflow runs are still external evidence gaps.

## Not Production Ready Yet

- Lightweight mode is demo/runtime smoke mode, not durable storage.
- MariaDB/MinIO local durable mode is verified for MVP demo, but production deployment still needs target-environment evidence.
- Real S3 client compatibility has Dockerized MinIO Client evidence; host `aws` or host `mc` verification remains useful but no longer blocks the local durable MVP demo.
- Kubernetes manifest draft exists under `infra/k8s`, and Helm chart draft exists under `infra/helm/osmu`, including starter resource requests/limits, NetworkPolicy draft, backend/frontend non-root security contexts, TLS ingress draft, secret/certificate rotation policy draft, backup/restore drill draft, and monitoring artifact draft. Production hardening is not completed.
- Backup/replication, production monitoring/alert validation, SSO/LDAP, final billing/licensing approval, actual signed image run evidence, and media-specific processing remain later phases.
- Security hardening still needs actual certificate/secret rotation execution in a target environment, cluster-specific network access review, and broader threat review.

## Next Best Work

1. Keep the durable MVP evidence reproducible by rerunning `finalize-durable-mvp-demo.ps1 -S3Client docker-mc` before tagging a release candidate.
2. Install or expose host `aws` CLI or `mc`, then run host real S3 client smoke as an optional compatibility proof.
3. Collect GitHub-hosted durable Docker, real S3 client, Browser E2E, image signing, and container security artifacts.
4. Continue production readiness work: Kubernetes storage expansion live evidence, backup/restore drill, HA/DR, and security evidence finalizers.

