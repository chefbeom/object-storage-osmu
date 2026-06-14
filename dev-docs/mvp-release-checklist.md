# OSMU MVP v0.1 Release Checklist

This checklist turns the current prototype evidence into a repeatable MVP release decision.

## Release Target

- Product: OSMU private object storage prototype.
- Version target: MVP v0.1.
- Current candidate type: lightweight demo candidate.
- Durable pilot status: not ready until Docker/MariaDB/MinIO, real S3 client, and Browser E2E gates pass.

## Current Evidence Snapshot

- Latest release report: `.osmu-run/latest-release.json`
- Latest audit report: `.osmu-run/latest-mvp-audit.md`
- Latest decision report: `.osmu-run/latest-release-decision.md`
- Latest release notes: `.osmu-run/latest-release-notes.md`
- Latest known release gate: passed on 2026-06-14 05:14 KST.
- CI workflow draft: `.github/workflows/prototype-ci.yml` verified, release report `scope.ciWorkflow=included`.
- Durable Docker CI workflow draft: `.github/workflows/durable-docker-ci.yml` verified, release report `scope.durableDockerCiWorkflow=included`.
- Real S3 client CI workflow draft: `.github/workflows/real-s3-client-ci.yml` verified, release report `scope.realS3ClientCiWorkflow=included`.
- Container security CI workflow draft: `.github/workflows/container-security-ci.yml` verified, release report `scope.containerSecurityCiWorkflow=included`.
- Browser E2E CI workflow draft: `.github/workflows/browser-e2e-ci.yml` verified, release report `scope.browserE2ECiWorkflow=included`.
- Image signing policy/workflow draft: `dev-docs/image-signing-policy.md` and `.github/workflows/image-publish-sign-ci.yml` verified, release report `scope.imageSigningPolicy=included`.
- Release notes generation: `.osmu-run/latest-release-notes.md` generated, release report `scope.releaseNotes=included`.
- Commercial readiness draft: `dev-docs/commercial-readiness.md` verified, release report `scope.commercialReadiness=included`.
- OpenAPI MVP contract: 90 operations verified, 70 frontend API functions checked, release report `scope.openApiContract=included`.
- Kubernetes manifest draft: `infra/k8s` verified, release report `scope.kubernetesManifests=included`.
- Helm chart draft: `infra/helm/osmu` verified, release report `scope.helmChart=included`.
- Deployment resource profiles: backend, frontend, MariaDB, and MinIO requests/limits verified through Kubernetes and Helm checks.
- NetworkPolicy draft: backend egress to MariaDB/MinIO/DNS and MariaDB/MinIO ingress from backend verified, release report `scope.networkPolicies=included`.
- Container hardening draft: backend image non-root UID 10001, frontend nginx non-root UID 101 on port 8080, and Kubernetes/Helm security contexts verified, release report `scope.containerHardening=included`.
- TLS ingress draft: `osmu-tls` secret reference and NGINX SSL redirect annotations verified, release report `scope.tlsIngress=included`.
- Secret rotation policy draft: admin/JWT/access-key/DB/MinIO/TLS rotation inventory and runbook verified, release report `scope.secretRotationPolicy=included`.
- Backup restore drill draft: MariaDB/MinIO restore runbook and acceptance criteria verified, release report `scope.backupRestoreDrill=included`.
- Backup readiness API/UI: admin status endpoint and dashboard panel expose durable restore pending gates.
- Prometheus observability draft: `/actuator/prometheus` and backend scrape annotations verified, release report `scope.prometheusObservability=included`.
- Monitoring artifacts draft: Prometheus alert rules and Grafana overview dashboard verified, release report `scope.monitoringArtifacts=included`.
- Prometheus Operator draft: optional ServiceMonitor and PrometheusRule resources verified, release report `scope.prometheusOperatorDraft=included`.
- Frontend unit coverage: 56 passing tests.
- Backend tests: included in release gate.
- Runtime smoke: backend, frontend, health, lightweight API, seeded demo, built-in SigV4 smoke.
- Object share link smoke/tests: global share policy save/enforcement, password/IP-restricted create, missing/wrong password denial, blocked-IP denial, public download, list, password-protected/IP-restricted flags, download count/last access, admin analytics, manual cleanup, scheduled cleanup, revoke, and revoked-token denial.
- External pending gates: Docker daemon, real S3 client, Browser/Chrome E2E.

## Lightweight Demo Candidate Gate

Required before calling the current prototype demo-ready:

- [x] Java 17+, Node.js, npm available.
- [x] Backend runtime health returns HTTP 200.
- [x] Frontend runtime returns HTTP 200.
- [x] Flyway migration version check passes.
- [x] Local static/unit/build verification passes.
- [x] CI workflow draft verifier passes.
- [x] Durable Docker CI workflow draft verifier passes.
- [x] Real S3 client CI workflow draft verifier passes.
- [x] Container security CI workflow draft verifier passes.
- [x] Browser E2E CI workflow draft verifier passes.
- [x] Image signing policy/workflow draft verifier passes.
- [x] Release notes generation passes.
- [x] Commercial readiness draft verifier passes.
- [x] OpenAPI MVP contract verifier passes.
- [x] Kubernetes manifest draft verifier passes.
- [x] Helm chart draft verifier passes.
- [x] Deployment resource profile checks pass.
- [x] NetworkPolicy draft verifier passes.
- [x] Container hardening draft verifier passes.
- [x] TLS ingress draft verifier passes.
- [x] Secret rotation policy draft verifier passes.
- [x] Backup restore drill draft verifier passes.
- [x] Prometheus observability draft verifier passes.
- [x] Monitoring artifacts draft verifier passes.
- [x] Prometheus Operator draft verifier passes.
- [x] Backup readiness status API test and admin dashboard selector contract pass.
- [x] Frontend unit tests pass.
- [x] Frontend stable selector contract test passes.
- [x] Backend Gradle tests pass.
- [x] Lightweight API smoke passes.
- [x] Seeded demo smoke passes.
- [x] Built-in manual SigV4 probes pass.
- [x] MVP audit report generated.
- [x] MVP release decision script self-test passes.
- [x] MVP release artifact consistency check passes.
- [x] Test case evidence map separates PASS, PARTIAL, and PENDING items.

Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-release.ps1 -JavaHome "<jdk17>"
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-audit.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-release-decision.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-release-notes.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-decision.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-artifacts.ps1
```

Decision: GO for local lightweight demo only.

## Durable MVP Pilot Gate

Required before calling MVP v0.1 durable/pilot-ready:

- [ ] Docker Desktop daemon running.
- [ ] MariaDB + MinIO docker compose starts cleanly.
- [ ] Docker integration smoke passes.
- [ ] MariaDB object tag index smoke passes.
- [ ] MinIO-backed multipart checksum smoke passes.
- [ ] Real S3 client smoke passes with AWS CLI or MinIO Client.
- [ ] Real S3 client CI workflow has a successful GitHub-hosted run.
- [ ] Browser/Chrome UI click-path E2E passes.
- [ ] Browser E2E CI workflow has a successful GitHub-hosted run.
- [ ] Image publish/sign workflow has a successful GitHub-hosted run with `publish=true`.
- [ ] Release report records Docker integration as included.
- [ ] Durable Docker CI workflow has a successful GitHub-hosted run.
- [ ] Release report records Browser E2E as verified.
- [ ] MVP audit report has no PENDING gate for Docker, real S3 client, or Browser E2E.

Commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-release.ps1 -RunDockerIntegration -RequireDocker -RequireS3Client -BrowserE2EVerified -JavaHome "<jdk17>"
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-audit.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-release-decision.ps1 -FailIfDurablePilotNoGo
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-artifacts.ps1
```

Decision: NO-GO until every durable gate above passes.

## Browser E2E Checklist

Run when Browser/Chrome automation works again:

- [x] Manual Browser E2E CI workflow draft exists and is checked by `scripts/verify-ci-workflow.ps1`.
- [ ] Login as seeded admin/demo user.
- [ ] Bucket list renders names, usage, and object counts.
- [ ] Object upload shows progress and prevents duplicate submit.
- [ ] Object list refreshes after upload.
- [ ] Confirm modal cancel does not call destructive API.
- [ ] Confirm modal confirm calls destructive/revoke API once.
- [ ] Access key scope create/revoke UI paths work.
- [ ] Object prefix breadcrumb navigation works.
- [ ] Object search highlight renders.
- [ ] Object tag edit, filter, and invalid-input UI paths work.
- [ ] Object metadata detail panel shows sync status, index fields, storage fields, drift, and missing values.
- [ ] Bucket lifecycle XML load/save/delete panel works.
- [ ] Bucket tags load/save/delete panel works.
- [ ] Audit log filter, pagination, and CSV export UI paths work.

## Real S3 Client Checklist

Run with AWS CLI or MinIO Client on `PATH`:

- [ ] List buckets with real client.
- [ ] Upload object with real client.
- [ ] Head/stat object with real client.
- [ ] List objects with real client.
- [ ] Download/cat object with real client.
- [ ] Delete object with real client.
- [ ] Cleanup bucket with real client.
- [ ] Built-in SigV4 checksum, tagging, range, conditional, CopyObject, multi-delete, and digest mismatch probes still pass.

## Container Security Checklist

Run in GitHub Actions before pilot/customer distribution:

- [ ] Backend container image builds successfully.
- [ ] Frontend container image builds successfully.
- [ ] Trivy high/critical vulnerability scan passes for backend image.
- [ ] Trivy high/critical vulnerability scan passes for frontend image.
- [ ] Backend SPDX SBOM artifact is uploaded.
- [ ] Frontend SPDX SBOM artifact is uploaded.
- [x] Image signing policy and registry target are decided before production/B2B sale.
- [ ] Backend and frontend image signatures verify with Cosign.
- [x] Commercial positioning, pilot package, license model, and pricing tier draft exist.
- [ ] Final pricing, terms, support SLA, and license agreement are approved.
- [x] Commercial positioning, pilot package, license model, and pricing tier draft exist.
- [ ] Final pricing, terms, support SLA, and license agreement are approved.

## Go/No-Go Rules

- Lightweight demo: GO when required lightweight gate and audit pass.
- Durable pilot: NO-GO while Docker, real S3 client, or Browser E2E remain pending.
- Production/B2B sale: NO-GO until durable pilot passes plus certificate issuance/rotation, backup/restore drill, secret rotation, monitoring alerts, SSO/LDAP or enterprise auth, deployment hardening, container vulnerability/SBOM evidence, image signing, final pricing/licensing/legal approval, and support SLA work are complete.

## Release Notes Template

```md
## OSMU MVP v0.1

- Candidate:
- Release report:
- MVP audit:
- Backend:
- Frontend:
- S3 compatibility:
- Known blockers:
- Go/No-Go decision:
```
