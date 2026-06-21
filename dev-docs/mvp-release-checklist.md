# OSMU MVP v0.1 Release Checklist

This checklist turns the current prototype evidence into a repeatable MVP release decision.

## Release Target

- Product: OSMU private object storage prototype.
- Version target: MVP v0.1.
- Current candidate type: durable local MVP demo candidate.
- Durable pilot status: local durable evidence ready from `.osmu-run/latest-durable-demo-gate.json` and `.osmu-run/latest-demo-readiness.json`; GitHub-hosted and production/B2B evidence remain separate gates.

## Current Evidence Snapshot

- Latest release report: `.osmu-run/latest-release.json`
- Latest audit report: `.osmu-run/latest-mvp-audit.md`
- Latest decision report: `.osmu-run/latest-release-decision.md`
- Latest release notes: `.osmu-run/latest-release-notes.md`
- Latest demo package notes: `.osmu-run/latest-demo-package-notes.md`
- Latest MVP completion report: `.osmu-run/latest-mvp-completion.json` and `.osmu-run/latest-mvp-completion.md`
- Latest operations readiness report: `.osmu-run/latest-operations-readiness.json` and `.osmu-run/latest-operations-readiness.md`
- Latest operations evidence plan: `.osmu-run/latest-operations-evidence-plan.json` and `.osmu-run/latest-operations-evidence-plan.md`
- Latest operations readiness finalizer report: `.osmu-run/latest-operations-readiness-finalize.json` and `.osmu-run/latest-operations-readiness-finalize.md`
- Latest operations readiness artifact import report: `.osmu-run/latest-operations-readiness-artifact-import.json` and `.osmu-run/latest-operations-readiness-artifact-import.md`
- Latest operations evidence handoff report: `.osmu-run/latest-operations-evidence-handoff.json` and `.osmu-run/latest-operations-evidence-handoff.md`
- Latest operations readiness convergence report: `.osmu-run/latest-operations-readiness-convergence.json` and `.osmu-run/latest-operations-readiness-convergence.md`
- Latest Kubernetes operations report sync evidence: `.osmu-run/latest-kubernetes-operations-report-sync.json`
- Latest operations invocation unblock plan: `.osmu-run/latest-operations-invocation-unblock-plan.json` and `.osmu-run/latest-operations-invocation-unblock-plan.md`
- Latest operations dispatch preflight: `.osmu-run/latest-operations-dispatch-preflight.json` and `.osmu-run/latest-operations-dispatch-preflight.md`
- Latest IAM/RBAC finalizer report: `.osmu-run/latest-iam-rbac-finalize.json` and `.osmu-run/latest-iam-rbac-finalize.md`
- Latest storage expansion finalizer report: `.osmu-run/latest-storage-expansion-finalize.json` when live Kubernetes expansion evidence has been collected.
- Latest Kubernetes DR finalizer report: `.osmu-run/latest-kubernetes-dr-finalize.json` when live Kubernetes DR evidence has been collected.
- Latest security evidence finalizer report: `.osmu-run/latest-security-evidence-finalize.json` when signed image and container scan/SBOM CI evidence has been collected and promoted.
- Latest durable demo gate report: `.osmu-run/latest-durable-demo-gate.json`
- Latest demo readiness report: `.osmu-run/latest-demo-readiness.json`
- Latest current-machine demo readiness: `docker-durable-demo-verified` on 2026-06-15 22:12 KST.
- Latest known release gate: passed on 2026-06-14 05:14 KST.
- CI workflow draft: `.github/workflows/prototype-ci.yml` verified, release report `scope.ciWorkflow=included`.
- Durable Docker CI workflow draft: `.github/workflows/durable-docker-ci.yml` verified. The manual workflow runs `finalize-durable-mvp-demo.ps1`, uploads durable reports/release artifacts/finalize/readiness reports, and release report records `scope.durableDockerCiWorkflow=included`.
- Real S3 client CI workflow draft: `.github/workflows/real-s3-client-ci.yml` verified, release report `scope.realS3ClientCiWorkflow=included`.
- Container security CI workflow draft: `.github/workflows/container-security-ci.yml` verified, release report `scope.containerSecurityCiWorkflow=included`.
- Browser E2E CI workflow draft: `.github/workflows/browser-e2e-ci.yml` verified, release report `scope.browserE2ECiWorkflow=included`.
- Storage Expansion Finalizer CI workflow draft: `.github/workflows/storage-expansion-finalizer-ci.yml` verified. The manual workflow runs the finalizer in plan-only mode by default and can collect live Kubernetes evidence only when `run_live=true` and `OSMU_KUBECONFIG_BASE64` is provided.
- Kubernetes HA/DR Readiness CI workflow draft: `.github/workflows/kubernetes-ha-dr-readiness-ci.yml` verified. The manual workflow runs the readiness checker in plan-only mode by default and can collect live target-cluster HA/DR evidence only when `run_live=true` and `OSMU_KUBECONFIG_BASE64` is provided.
- Kubernetes DR Finalizer CI workflow draft: `.github/workflows/kubernetes-dr-finalizer-ci.yml` verified. The manual workflow runs the DR finalizer in plan-only mode by default, supports server-side dry-run live evidence, and requires explicit `confirm_restore=true` before a confirmed restore or evidence submit path can run.
- Kubernetes Operations Report Sync CI workflow draft: `.github/workflows/kubernetes-operations-report-sync-ci.yml` verified. The manual workflow writes the convergence report, emits ConfigMap sync plan evidence by default, uses `OSMU_KUBECONFIG_BASE64` only when `run_live=true`, and requires `apply=true` before it updates `osmu-operations-reports`.
- Operations Readiness Finalizer CI workflow draft: `.github/workflows/operations-readiness-finalizer-ci.yml` verified. The manual workflow plans or runs the selected storage expansion, HA/DR, DR, IAM/RBAC, and security evidence finalizers, then uploads the combined readiness artifact set.
- Operations Readiness Artifact Finalizer CI workflow draft: `.github/workflows/operations-readiness-artifact-finalizer-ci.yml` verified. The manual workflow downloads previous evidence artifacts by run id and artifact name, including manual secret rotation, manual commercial integration, manual commercial approval, enterprise auth smoke, manual operations handoff package, and optional Kubernetes operations report sync evidence, imports only passing evidence to standard latest paths, writes operations readiness, and uploads the combined artifact set.
- IAM/RBAC Finalizer CI workflow draft: `.github/workflows/iam-rbac-finalizer-ci.yml` verified. The manual workflow runs static IAM/RBAC finalizer evidence, can add focused backend RBAC tests with Java 17, and collects live `kubectl auth can-i` evidence only when `run_live=true` and `OSMU_KUBECONFIG_BASE64` is provided.
- Security Evidence Finalizer CI workflow draft: `.github/workflows/security-evidence-finalizer-ci.yml` verified. The manual workflow downloads successful image signing and container security artifacts from previous workflow runs, promotes them through `scripts/finalize-security-evidence.ps1`, and uploads the finalized evidence bundle.
- Image signing policy/workflow draft: `dev-docs/image-signing-policy.md` and `.github/workflows/image-publish-sign-ci.yml` verified, release report `scope.imageSigningPolicy=included`.
- Release notes generation: `.osmu-run/latest-release-notes.md` generated, release report `scope.releaseNotes=included`.
- Demo package notes generation: `.osmu-run/latest-demo-package-notes.md` generated by `scripts/write-mvp-demo-package-notes.ps1`, preserving local durable evidence paths, pilot attachment checklist, and the S3 replacement-use boundary.
- Commercial readiness draft: `dev-docs/commercial-readiness.md` verified, release report `scope.commercialReadiness=included`.
- OpenAPI MVP contract: current local verifier reports 193 operations and 150 frontend API functions checked.
- Kubernetes manifest draft: `infra/k8s` verified, release report `scope.kubernetesManifests=included`.
- Helm chart draft: `infra/helm/osmu` verified, release report `scope.helmChart=included`.
- Deployment resource profiles: backend, frontend, MariaDB, and MinIO requests/limits verified through Kubernetes and Helm checks.
- Kubernetes HA safety rails: backend/frontend two-replica defaults, topology spread constraints, and PodDisruptionBudget drafts are covered by Kubernetes/Helm static verification.
- Kubernetes HA/DR live evidence path: `scripts/verify-kubernetes-ha-dr-readiness.ps1` can record target-cluster Deployment, StatefulSet, PDB, backup PVC/CronJob, and restore Job server-side dry-run evidence.
- Kubernetes HA/DR Readiness CI uploads `.osmu-run/latest-kubernetes-ha-dr-readiness.json` as `kubernetes-ha-dr-readiness-<run_id>` when live evidence is collected.
- Kubernetes backup drill evidence path: `scripts/run-kubernetes-backup-drill.ps1` can create one-off Jobs from the MariaDB/MinIO backup CronJobs and record completion/log evidence.
- Kubernetes restore target preparation evidence path: `scripts/prepare-kubernetes-restore-namespace.ps1` can dry-run or apply a disposable restore namespace and verify core resources without reading secret values.
- Kubernetes backup artifact preflight evidence path: `scripts/verify-kubernetes-backup-artifacts.ps1` can run a read-only Job to verify `metadata.sql`, optional checksum, and MinIO mirror count/bytes before restore.
- Kubernetes isolated restore drill evidence path: `scripts/run-kubernetes-restore-drill.ps1` can validate the restore Job with `-ServerDryRunOnly` and execute it only in an explicitly confirmed restore namespace.
- Kubernetes DR drill orchestration evidence path: `scripts/run-kubernetes-dr-drill.ps1` can run the ordered backup/restore validation or confirmed restore sequence and write a wrapper evidence report.
- Kubernetes DR bucket bootstrap evidence path: `scripts/bootstrap-kubernetes-dr-bucket.ps1` can create or reuse the external DR bucket with object locking, enable versioning, set default retention, verify the result, and write `.osmu-run/latest-kubernetes-dr-bucket-bootstrap.json`.
- Kubernetes DR bucket immutability evidence path: `scripts/verify-kubernetes-dr-bucket-immutability.ps1` can verify external DR bucket reachability, versioning, and default object-lock retention through `osmu-dr-transfer-secret` and write `.osmu-run/latest-kubernetes-dr-bucket-immutability.json`.
- Kubernetes backup artifact transfer evidence path: `scripts/transfer-kubernetes-backup-artifacts.ps1` can export/import a selected timestamp through external S3-compatible DR storage using `osmu-dr-transfer-secret` and write `.osmu-run/latest-kubernetes-backup-artifact-transfer.json`.
- Kubernetes restore smoke evidence path: `scripts/verify-kubernetes-restore-smoke.ps1` can verify restored API health/login/bucket/object access plus optional real S3 client smoke and write `.osmu-run/latest-kubernetes-restore-smoke.json`.
- Kubernetes DR evidence API request path: `scripts/write-kubernetes-dr-evidence-request.ps1` can convert wrapper/artifact evidence into `.osmu-run/latest-kubernetes-dr-evidence-request.json` and optionally submit it to `POST /api/admin/backup/restore-drill-evidence`.
- Kubernetes DR finalize evidence path: `scripts/finalize-kubernetes-dr-drill.ps1` can run the DR wrapper, restore smoke, and evidence request sequence in one operator command and write `.osmu-run/latest-kubernetes-dr-finalize.json` plus `.md`. It accepts `-PowerShellCommand` for Linux CI runners and records the selected command in the evidence report.
- Kubernetes storage expansion finalize evidence path: `scripts/finalize-storage-expansion.ps1` can run storage expansion runner RBAC authorization evidence, MinIO Tenant server-side dry-run evidence, and optional backend dry-run/apply runner calls in one operator command. The apply path requires explicit `-RunBackendApply -ConfirmApply`, refuses to run if RBAC/server-side dry-run evidence is skipped in the same command, records the selected PowerShell command, and writes `.osmu-run/latest-storage-expansion-finalize.json` plus `.md`.
- Storage Expansion Finalizer CI uploads `.osmu-run/latest-storage-expansion-finalize.*`, RBAC auth evidence, and server-side dry-run evidence as `storage-expansion-finalizer-<run_id>` artifacts for operator review.
- Kubernetes DR Finalizer CI uploads `.osmu-run/latest-kubernetes-dr-finalize.*`, DR drill, restore smoke, evidence request, backup drill, restore namespace, artifact preflight, restore drill, DR bucket, immutability, and artifact transfer evidence as `kubernetes-dr-finalizer-<run_id>` artifacts for operator review.
- MVP audit, release decision, and release notes read `.osmu-run/latest-storage-expansion-finalize.json` and `.osmu-run/latest-kubernetes-dr-finalize.json`, then mark storage expansion and Kubernetes DR finalizer evidence as PASS or PENDING without changing the lightweight/durable MVP demo decision.
- Operations readiness gate: `scripts/write-operations-readiness.ps1` writes a separate production/B2B operations readiness report. It stays `pending` until IAM/RBAC finalizer, storage expansion finalizer, Kubernetes HA/DR readiness, Kubernetes DR finalizer, signed image, container scan/SBOM, secret/certificate rotation target evidence, commercial integration target evidence, commercial approval target evidence, enterprise auth target smoke evidence, and operations handoff package target evidence are all present and passing. Pending checks include `remediation` command/workflow/workflow-command metadata so operators can move directly from the report to the needed evidence run.
- Operations evidence plan: `scripts/write-operations-evidence-plan.ps1` converts pending operations readiness checks into an ordered operator plan with local commands, `gh workflow run` commands, placeholder inputs, operator approval flags, and kubeconfig-secret requirements. `scripts/verify-operations-evidence-plan.ps1` covers the schema and fixture behavior.
- Operations evidence plan invocation: `scripts/invoke-operations-evidence-plan.ps1` converts the ordered evidence plan into a guarded plan-only or explicit `-Execute` run list. It blocks unresolved placeholders, missing operator approval, missing kubeconfig-secret confirmation, and commands outside the allowlist, then writes `.osmu-run/latest-operations-evidence-plan-invocation.json` plus `.md`. `scripts/verify-operations-evidence-plan-invocation.ps1` covers blocked, confirmed, and selected-action plan-only behavior.
- Operations invocation unblock plan: `scripts/write-operations-invocation-unblock-plan.ps1` converts a blocked guarded invocation report into required confirmations, placeholder values, per-action plan commands, currently planned action commands, and repeated-placeholder warnings before any live workflow dispatch. `scripts/verify-operations-invocation-unblock-plan.ps1` covers blocked and ready invocation fixtures.
- Operations dispatch preflight: `scripts/write-operations-dispatch-preflight.ps1` converts the unblock plan into a final no-execute readiness check for live workflow dispatch. It checks selected action orders, confirmation flags, placeholder values, workflow file presence, required GitHub secret names, optional GitHub CLI availability, and emits ready plan/execute command previews only when required checks pass. `scripts/verify-operations-dispatch-preflight.ps1` covers missing-input and ready fixtures.
- Operations workflow run id plan: `scripts/write-operations-workflow-run-id-plan.ps1` converts the invocation report into `gh run list` query commands and, when run list JSON is available or `-Execute` is used, recommends latest successful run ids plus the next Security Evidence Finalizer and artifact collection plan commands, including manual secret rotation, manual commercial integration, manual commercial approval, manual operations handoff package, and optional Kubernetes operations report sync run ids. `scripts/verify-operations-workflow-run-id-plan.ps1` covers plan-only and fixture-backed ready behavior.
- Operations artifact collection plan: `scripts/write-operations-artifact-collection-plan.ps1` converts an invocation report plus GitHub workflow run ids into expected artifact names, `gh run download` commands, Security Evidence Finalizer dispatch input, Operations Readiness Artifact Finalizer dispatch input, manual secret rotation, manual commercial integration, manual commercial approval, manual operations handoff package, and optional Kubernetes operations report sync artifact input, and a local import command. `scripts/verify-operations-artifact-collection-plan.ps1` covers missing-run-id and ready collection behavior.
- Operations readiness finalizer: `scripts/finalize-operations-readiness.ps1` is the combined operator wrapper that plans or runs the selected evidence finalizers and writes `.osmu-run/latest-operations-readiness-finalize.json` plus `.md`. GitHub Actions passes `-PowerShellCommand pwsh`, and the wrapper propagates that command to child finalizers.
- Operations readiness artifact importer: `scripts/import-operations-readiness-artifacts.ps1` promotes previously collected workflow or manual evidence, including secret rotation, commercial integration, commercial approval, and operations handoff package evidence, only when required JSON results are passing, ready, or applied as expected, then writes `.osmu-run/latest-operations-readiness-artifact-import.json` plus `.md`.
- Operations evidence handoff: `scripts/write-operations-evidence-handoff.ps1` stitches the latest readiness, evidence plan, invocation, workflow run id, artifact collection, artifact import, and operations readiness finalizer reports into one current bottleneck plus next operator command. `scripts/verify-operations-evidence-handoff.ps1` covers missing-report, blocked-invocation, artifact-finalizer-ready, operations-finalizer-missing, and operations-finalizer-pending states.
- Operations readiness convergence: `scripts/write-operations-readiness-convergence.ps1` summarizes the latest handoff, readiness, operations readiness finalizer, and Kubernetes operations report sync reports into a no-execute ready/action-required decision with current bottleneck, stage counts, finalizer gap counts, Kubernetes report sync readiness/result, and recommended command chain. The final result is `ready` only when sync evidence is `applied` with zero failed checks. `scripts/verify-operations-readiness-convergence.ps1` covers missing-handoff, finalizer-required, sync-required, and ready states.
- Operations readiness dashboard visibility: `GET /api/admin/dashboard/readiness` surfaces pending operations readiness report checks, the operations evidence plan, the guarded operations evidence invocation report, the invocation unblock plan, the dispatch preflight report, the workflow run id plan, the operations artifact collection plan, the operations readiness artifact import report, the operations readiness finalizer report, the operations evidence handoff, the operations readiness convergence report, Kubernetes operations report sync evidence, artifact import failures, pending finalizer status, action-required convergence status, convergence-level sync-required status, and planned/server-dry-run sync status as `OPERATIONS` items for the dashboard readiness panel, including evidence path and remediation command/workflow/workflow-command metadata for individual pending checks plus structured `operationsEvidencePlan.actions`, `operationsEvidenceInvocation.actions`, `operationsInvocationUnblockPlan.actions`, `operationsDispatchPreflight.checks`, `operationsDispatchPreflight.requiredInputs`, `operationsDispatchPreflight.workflowFiles`, `operationsWorkflowRunIdPlan.workflows`, `operationsArtifactCollectionPlan.artifacts`, `operationsReadinessArtifactImport.entries`, `operationsReadinessFinalize.commands`, `operationsReadinessFinalize.steps`, `operationsReadinessFinalize.gaps`, `operationsEvidenceHandoff.stages`, `operationsReadinessConvergence.recommendedCommands`, `operationsReadinessConvergence.kubernetesReportSyncReady`, and `kubernetesOperationsReportSync.checks`. Post-deploy validation should run `scripts/verify-kubernetes-operations-report-sync-live.ps1` against the deployed API to prove those ConfigMap-backed fields are visible from the running dashboard service.
- Operations readiness frontend visibility: the readiness panel shows an operations evidence gaps summary, evidence plan summary line, invocation summary line, invocation unblock summary line, dispatch preflight summary line, workflow run id summary line, artifact collection summary line, artifact import summary line, operations finalizer summary line, evidence handoff summary line, convergence summary line, Kubernetes report sync summary line, ordered evidence plan actions, invocation planned/blocked action rows, unblock action input rows, dispatch preflight check/input/workflow rows, workflow query command rows, artifact download command rows, artifact import entry rows, finalizer command rows, finalizer step rows, handoff stage rows, convergence command rows, Kubernetes report sync check rows, quick `Operations` filter, inline remediation command/workflow-command/evidence details, and command copy controls when those items are present.
- Docker local demo operations report mount: backend container mounts project `.osmu-run` read-only at `/app/.osmu-run`, and `verify-browser-e2e-local-demo.ps1` can seed a Docker-local convergence fixture plus enable the Browser E2E convergence dashboard check through `OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH`.
- Kubernetes/Helm operations report mount: backend Pods mount an optional read-only `osmu-operations-reports` ConfigMap at `/app/.osmu-run`, set `OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH` and `OSMU_OPERATIONS_READINESS_KUBERNETES_REPORT_SYNC_REPORT_PATH`, and can switch the Helm mount to a PVC for larger evidence sets. `scripts/verify-kubernetes-operations-report-mount.ps1` verifies both ConfigMap keys and backend Pod mounted file visibility after apply.
- Kubernetes operations report sync: `scripts/sync-kubernetes-operations-reports.ps1` validates `.osmu-run/latest-operations-readiness-convergence.json`, records byte count/SHA256, emits plan/server-dry-run/apply commands, and requires explicit `-Apply` before updating the `osmu-operations-reports` ConfigMap. `scripts/verify-kubernetes-operations-report-sync.ps1` covers plan, fake server dry-run, and fake apply behavior.
- Kubernetes Operations Report Sync CI uploads `.osmu-run/latest-operations-readiness-convergence.*`, `.osmu-run/latest-kubernetes-operations-report-sync-plan.json`, optional server dry-run evidence, and optional apply evidence as `kubernetes-operations-report-sync-<run_id>` artifacts.
- IAM/RBAC finalizer: `scripts/finalize-iam-rbac-readiness.ps1` runs the application IAM/RBAC matrix verifier and Kubernetes RBAC matrix verifier by default, with optional backend focused RBAC tests and live `kubectl auth can-i` evidence.
- IAM/RBAC Finalizer CI uploads `.osmu-run/latest-iam-rbac-finalize.*`, optional storage expansion RBAC auth evidence, and backend RBAC JUnit test reports as `iam-rbac-finalizer-<run_id>` artifacts for operator review.
- Container security evidence writer: `scripts/write-container-security-evidence.ps1` records successful Trivy high/critical scan flags plus backend/frontend SPDX SBOM metadata, byte sizes, and SHA256 hashes into `.osmu-run/latest-container-security-evidence.json`.
- Image signing evidence writer: `scripts/write-image-signing-evidence.ps1` records Cosign verification for backend/frontend version and commit-SHA tags plus backend/frontend image manifest digests into `.osmu-run/latest-image-signing-evidence.json`.
- Security evidence finalizer: `scripts/finalize-security-evidence.ps1` validates those two CI evidence files, rejects synthetic/self-test evidence by default, requires image digests and SBOM hashes, promotes passing files to the standard latest evidence paths, and writes `.osmu-run/latest-security-evidence-finalize.json` plus `.md`.
- Security Evidence Finalizer CI uploads `.osmu-run/latest-security-evidence-finalize.*`, promoted image signing evidence, promoted container security evidence, and the downloaded source evidence bundle as `security-evidence-finalizer-<run_id>` artifacts for operator review.
- NetworkPolicy draft: backend egress to MariaDB/MinIO/DNS and MariaDB/MinIO ingress from backend verified, release report `scope.networkPolicies=included`.
- Container hardening draft: backend image non-root UID 10001, frontend nginx non-root UID 101 on port 8080, and Kubernetes/Helm security contexts verified, release report `scope.containerHardening=included`.
- TLS ingress draft: `osmu-tls` secret reference and NGINX SSL redirect annotations verified, release report `scope.tlsIngress=included`.
- Secret rotation policy draft: admin/JWT/access-key/DB/MinIO/TLS rotation inventory and runbook verified, release report `scope.secretRotationPolicy=included`.
- Backup restore drill draft: MariaDB/MinIO restore runbook and acceptance criteria verified, release report `scope.backupRestoreDrill=included`.
- Backup readiness API/UI: admin status endpoint and dashboard panel expose durable restore pending gates.
- Storage backend status API/UI: `GET /api/admin/storage/backend-status`, mock API, frontend API wrapper, dashboard health widget line, RBAC matrix, and OpenAPI contract expose object storage health, access-key provisioner health, and bucket metadata usage with `minioAdminMetricsEnabled=false`.
- Admin data-flow monitoring API/UI: `GET /api/admin/monitoring/data-flow`, `GET /api/admin/monitoring/data-flow/daily-rollup`, `POST /api/admin/monitoring/data-flow/daily-rollup/materialize`, `GET /api/admin/monitoring/data-flow/daily-rollup/materialized`, `GET /api/admin/monitoring/data-flow/monthly-rollup`, `POST /api/admin/monitoring/data-flow/monthly-rollup/materialize`, `GET /api/admin/monitoring/data-flow/monthly-rollup/materialized`, `GET /api/admin/monitoring/data-flow/storage-status`, `GET /api/admin/monitoring/data-flow/export.csv`, `GET /api/admin/monitoring/data-flow/daily-rollup/export.csv`, `GET /api/admin/monitoring/data-flow/daily-rollup/materialized/export.csv`, `GET /api/admin/monitoring/data-flow/monthly-rollup/export.csv`, `GET /api/admin/monitoring/data-flow/monthly-rollup/materialized/export.csv`, dashboard summary `dataFlow`, and admin data flow panel expose upload/download/internal-copy traffic, operation counts, failure/cancel counts, source/operation trend chart, daily/monthly rollup rows, daily/monthly store refresh/read/export, storage readiness/row counts with `partitionedOrTimeSeriesStoreEnabled=false`, detailed CSV export, daily/monthly rollup CSV export, top buckets, recent flow events, filter controls, MariaDB `data_flow_events` persistence, MariaDB `data_flow_daily_rollups` aggregate storage with actor/status filter dimensions, MariaDB `data_flow_monthly_rollups` aggregate storage with actor/status filter dimensions, detailed event scheduled retention cleanup, and materialized daily/monthly rollup scheduled retention cleanup.
- Prometheus observability draft: `/actuator/prometheus` and backend scrape annotations verified, release report `scope.prometheusObservability=included`.
- Monitoring artifacts draft: Prometheus alert rules and Grafana overview dashboard verified, including data-flow failure/cancel/egress/bucket anomaly and retention failure starter alerts; release report `scope.monitoringArtifacts=included`.
- Prometheus Operator draft: optional ServiceMonitor and PrometheusRule resources verified, release report `scope.prometheusOperatorDraft=included`.
- Frontend unit coverage: current local run reports 113 passing tests.
- Frontend multipart upload tuning: `VITE_MULTIPART_UPLOAD_THRESHOLD_BYTES`, `VITE_MULTIPART_UPLOAD_PART_SIZE_BYTES`, `VITE_MULTIPART_UPLOAD_CONCURRENCY`, `VITE_MULTIPART_UPLOAD_PART_RETRIES`, `VITE_MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS`, and `VITE_MULTIPART_UPLOAD_RETRY_JITTER_RATIO` keep production defaults while allowing small Browser/CI multipart resume fixtures.
- Backend tests: included in release gate when JDK 17+ is available through `-JavaHome`, `JAVA_HOME`, `PATH`, or a known local JDK install path.
- Backend-backed Browser E2E: current local Java prototype path passed with 3 Playwright scenarios on 2026-06-15 19:49 KST.
- Runtime smoke: backend, frontend, health, lightweight API, seeded demo, built-in SigV4 smoke.
- Object share link smoke/tests: global share policy save/enforcement, password/IP-restricted create, missing/wrong password denial, blocked-IP denial, public download, list, password-protected/IP-restricted flags, download count/last access, admin analytics, manual cleanup, scheduled cleanup, revoke, and revoked-token denial.
- External pending gates: GitHub-hosted durable Docker, real S3 client, Browser/Chrome E2E, image signing, and container security evidence. Host `aws`/`mc` S3 smoke remains optional because Dockerized MinIO Client already passed.

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
- [x] Kubernetes DR Finalizer CI workflow draft verifier passes.
- [x] Kubernetes Operations Report Sync CI workflow draft verifier passes.
- [x] Image signing policy/workflow draft verifier passes.
- [x] Security evidence writer self-test passes.
- [x] Security evidence finalizer self-test passes.
- [x] IAM/RBAC finalizer self-test passes.
- [x] Release notes generation passes.
- [x] Demo package notes generation passes.
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
- [x] Backend-backed Browser E2E prototype passes.
- [x] Mock and backend-backed Browser E2E cover operations readiness convergence dashboard summary and recommended command rows.
- [x] Kubernetes/Helm backend Pods mount the operations readiness convergence report path for deployed dashboard checks.
- [x] Lightweight API smoke passes.
- [x] Seeded demo smoke passes.
- [x] Built-in manual SigV4 probes pass.
- [x] MVP audit report generated.
- [x] MVP release decision script self-test passes.
- [x] MVP release artifact consistency check passes.
- [x] Operations readiness artifact shape verifier passes.
- [x] Operations evidence plan verifier passes.
- [x] Operations invocation unblock plan verifier passes.
- [x] Operations dispatch preflight verifier passes.
- [x] Operations workflow run id plan verifier passes.
- [x] Operations artifact collection plan verifier passes.
- [x] Operations evidence handoff verifier passes.
- [x] Operations readiness convergence verifier passes.
- [x] Kubernetes operations report sync verifier passes.
- [x] Operations readiness finalizer plan self-test passes.
- [x] Operations readiness dashboard API visibility test passes.
- [x] Operations readiness frontend selector visibility test passes.
- [x] Durable release artifact generator synthetic test passes.
- [x] Test case evidence map separates PASS, PARTIAL, and PENDING items.

Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-release.ps1 -JavaHome "<jdk17>"
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-audit.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-release-decision.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-release-notes.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-demo-package-notes.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-decision.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-artifacts.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-demo-package-notes.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-completion.ps1 -FailIfLocalMvpNotReady
```

Decision: GO for local lightweight demo. Local durable MVP evidence is also ready when `.osmu-run/latest-durable-demo-gate.json` and `.osmu-run/latest-demo-readiness.json` both show `result=ready`.

## Durable MVP Pilot Gate

Required before calling MVP v0.1 durable/pilot-ready:

- [x] Docker Desktop daemon running.
- [x] MariaDB + MinIO docker compose starts cleanly.
- [x] Docker integration smoke passes.
- [x] MariaDB object tag index smoke passes.
- [x] MinIO-backed multipart checksum smoke passes.
- [x] Real S3 client smoke passes with Dockerized MinIO Client.
- [x] Durable demo gate `scripts/verify-durable-demo-gate.ps1` passes and records `docker-durable-demo-verified`.
- [ ] Real S3 client CI workflow has a successful GitHub-hosted run.
- [ ] Browser/Chrome UI click-path E2E passes.
- [ ] Browser E2E CI workflow has a successful GitHub-hosted run.
- [ ] Image publish/sign workflow has a successful GitHub-hosted run with `publish=true`.
- [ ] Release report records Docker integration as included.
- [ ] Durable Docker CI workflow has a successful GitHub-hosted run.
- [ ] Release report records Browser E2E as verified.
- [x] Durable release artifacts are generated by `scripts/write-durable-release-artifacts.ps1` from a ready durable gate report and backend test evidence, preserving the gate report's selected S3 client and durable preflight report path.
- [x] Durable release artifacts include demo package notes through `scripts/write-mvp-demo-package-notes.ps1`.
- [x] Durable finalize wrapper `scripts/finalize-durable-mvp-demo.ps1` passes on a Docker-ready machine and writes `.osmu-run/latest-durable-mvp-finalize.json` plus `.md`.
- [ ] Operations readiness finalizer workflow has a successful live run with selected Kubernetes/security evidence steps.
- [ ] MVP audit report has no PENDING durable gate. This can be satisfied by `latest-durable-demo-gate.json` with `result=ready` and `currentDemoStatus=docker-durable-demo-verified`, or by the legacy release report fields for Docker, real S3 client, and Browser E2E.

Commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-gate.ps1
Push-Location .\osmu-backend
.\gradlew test
Pop-Location
powershell -ExecutionPolicy Bypass -File .\scripts\write-durable-release-artifacts.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json -BackendTestsIncluded
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -S3Client docker-mc
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-completion.ps1 -FailIfLocalMvpNotReady
```

Decision: GO for local durable MVP demo when using the latest local evidence. NO-GO for hosted/production pilot until GitHub-hosted workflow evidence and operations readiness finalizers pass.

## Browser E2E Checklist

Run when Browser/Chrome automation works again:

- [x] Manual Browser E2E CI workflow draft exists and is checked by `scripts/verify-ci-workflow.ps1`.
- [x] Browser E2E spec includes developer mode login to `/developer`, S3 endpoint/snippet visibility, Admin nav hiding, and Access Key create UI contract.
- [x] Browser E2E spec includes stored session restore without login plus stale stored session redirect cleanup.
- [x] Browser E2E spec includes auth refresh retry on object download, refresh failure session cleanup, and logout token cleanup.
- [x] Browser E2E spec includes Access Key scope add/remove, disabled create without scope, cancel revoke, and confirmed revoke state.
- [x] Browser E2E spec includes Access Key operational filters, cleanup candidate count, and action hint render paths.
- [x] Browser E2E spec includes Access Key cleanup preview export, candidate exclusion, and bulk disable confirm paths.
- [x] Browser E2E spec includes Admin security/audit policy panel render and Audit link navigation.
- [x] Browser E2E spec includes Admin approval workflow profile approve/apply and storage expansion approve/dry-run/apply paths.
- [x] Browser E2E spec includes Admin role-based panel visibility for ADMIN, ORG_ADMIN, and USER redirect paths.
- [x] Browser E2E spec includes Admin action failure remediation for 401, 403, 400, 404, and 409 responses.
- [x] Browser E2E spec includes error alert Request ID visibility for admin API failures.
- [x] Browser E2E spec includes destructive confirm cancel/confirm paths for bucket delete.
- [x] Browser E2E spec includes operations readiness convergence summary and recommended command row visibility.
- [x] Browser E2E spec includes bucket list name, usage, and object count cell assertions.
- [x] Browser E2E spec includes bucket-side storage profile request and request status row assertions.
- [x] Browser E2E spec includes admin storage profile approve/apply status transitions.
- [x] Browser E2E spec includes object upload followed by prefix/list refresh and object detail render.
- [x] Browser E2E spec includes single-object upload cancel/retry button flow and list refresh after retry.
- [x] Browser E2E spec includes pending multipart resume panel, matching Resume enable, Expired disable, and delete confirm paths.
- [x] Browser E2E spec includes object metadata drift fixture with sync-status badge and index/storage row comparison.
- [x] Browser E2E spec includes object prefix open/root breadcrumb navigation, search highlight, tag filter, tag edit, and invalid tag error paths.
- [x] Browser E2E spec includes Object Explorer page size select, first-page cursor reset, and next-page limit retention paths.
- [x] Browser E2E spec includes bucket lifecycle XML save/load/delete and bucket tags save/load/delete click paths.
- [x] Browser E2E spec includes audit filter, next-page click, CSV download filename, and reset click paths.
- [x] Backend-backed Browser E2E prototype passes locally.
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
- [x] Object metadata detail panel shows sync status, index fields, storage fields, drift, and missing values.
- [ ] Bucket lifecycle XML load/save/delete panel works.
- [ ] Bucket tags load/save/delete panel works.
- [ ] Audit log filter, pagination, and CSV export UI paths work.

## Real S3 Client Checklist

Run with AWS CLI, Python+boto3, Node.js with `@aws-sdk/client-s3`, or host MinIO Client available, or Dockerized MinIO Client when Docker Desktop is running:

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
- [ ] Backend and frontend SBOM SHA256 hashes are recorded in container security evidence.
- [ ] `.osmu-run/latest-container-security-evidence.json` is generated from the successful workflow and attached to operations readiness evidence.
- [x] Image signing policy and registry target are decided before production/B2B sale.
- [ ] Backend and frontend image signatures verify with Cosign.
- [ ] Backend and frontend image manifest digests are recorded in image signing evidence.
- [ ] `.osmu-run/latest-image-signing-evidence.json` is generated from the successful publish/sign workflow and attached to operations readiness evidence.
- [ ] `scripts/finalize-security-evidence.ps1` passes with non-synthetic CI artifacts and writes `.osmu-run/latest-security-evidence-finalize.json`.
- [x] Commercial positioning, pilot package, license model, and pricing tier draft exist.
- [ ] `.osmu-run/latest-commercial-approval-evidence.json` is generated with `result=passed` for final pricing, terms, support SLA, license agreement, legal approval, and pilot contract boundary references.
- [x] Commercial positioning, pilot package, license model, and pricing tier draft exist.
- [ ] `.osmu-run/latest-commercial-approval-evidence.json` is generated with `result=passed` for final pricing, terms, support SLA, license agreement, legal approval, and pilot contract boundary references.

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
