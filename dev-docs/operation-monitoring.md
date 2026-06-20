# OSMU Operation and Monitoring

This document defines the current operation and monitoring baseline for the OSMU prototype.

## 1. Goals

- Detect backend, metadata, and object storage health issues quickly.
- Trace role-based access and important storage changes.
- Watch quota, bucket, and object growth.
- Expose backup/restore readiness honestly to operators.
- Detect security and authentication failure spikes.
- Monitor object data flow, including upload/download traffic, I/O volume, failed transfer, cancelled transfer, delete, and recent flow events.

## 2. Health And Readiness APIs

Required endpoints:

- `GET /api/health`
- `GET /api/database/health`
- `GET /api/storage/health`
- `GET /api/admin/system/status`
- `GET /api/admin/backup/status`
- `GET /actuator/prometheus`

`/api/admin/backup/status` returns `DRILL_PENDING` in lightweight demo mode and lists durable pilot gaps in `pendingGates`.
`/actuator/prometheus` is the Prometheus scrape endpoint.

## 3. Logs

Application logs should include:

- requestId
- method
- path
- status
- latency
- userId
- errorCode

Application logs must not include:

- password
- secretKey
- token
- Authorization header

## 4. Audit Log

Audit targets:

- login success/failure
- user create/status update
- organization create/delete
- bucket create/delete/permission/tag/lifecycle changes
- object upload/download/delete/restore/purge
- access key create/revoke
- retention/lifecycle policy changes
- major S3-compatible API operations

## 5. Metrics

Backend:

- request count
- request latency
- error count
- JVM memory/GC metrics
- bucket/object operation count
- multipart cleanup success/failure count
- object retention purge success/failure count
- object version retention purge success/failure count
- data flow operation count by operation/status/source/bucket via `osmu.data.flow.operations`
- data flow byte count by direction/source/bucket via `osmu.data.flow.bytes`

MariaDB:

- connection count
- query latency
- storage usage
- replication status optional

MinIO:

- disk usage
- bucket usage
- object count
- request count
- error count
- node health

## 6. Dashboard

MVP dashboard areas:

- backend up/down
- MariaDB metadata up/down
- MinIO object storage up/down
- total quota/used/bucket/object count
- admin quota policy list with target used/quota/remaining bytes
- admin quota policy change history with create/update/delete actor, quota delta, and optional reason
- password/IP-restricted object share link create/public download/revoke/manual cleanup/scheduled cleanup audit trail with global share policy save events, admin share analytics, download count, last-access visibility, and cleanup failure metric
- object retention status
- lifecycle policy/conflict/dry-run
- backup readiness status
- data flow monitoring with total traffic, upload/download bytes, failed/cancelled transfer count, top buckets, and recent upload/download/delete/failure/cancel events
- audit log filter/export

Product dashboard areas:

- organization usage
- bucket usage
- user traffic
- API latency p95/p99
- error trend
- backup job history
- restore drill history
- certificate/secret rotation history

## 6.1 Admin Data Flow Monitoring

MVP implementation:

- `GET /api/admin/monitoring/data-flow` exposes an admin-only data flow snapshot.
- The focused endpoint supports `from`, `to`, `bucketName`, `actorId`, `source`, `operation`, `status`, and `limit` filters.
- `GET /api/admin/monitoring/data-flow/daily-rollup` exposes an admin-only UTC-day rollup grouped by bucket, source, and operation for longer analytics windows and chargeback planning.
- `POST /api/admin/monitoring/data-flow/daily-rollup/materialize` refreshes the same aggregate rows into `data_flow_daily_rollups` in MariaDB mode so query-time rollups can later move toward partitioned or time-series storage.
- `GET /api/admin/monitoring/data-flow/daily-rollup/materialized` reads refreshed aggregate rows from `data_flow_daily_rollups` without re-scanning detailed event rows.
- `GET /api/admin/monitoring/data-flow/export.csv` exports the same filtered event window as newest-first CSV for audit handoff or offline analysis.
- `GET /api/admin/monitoring/data-flow/daily-rollup/export.csv` exports the same filtered daily rollup as CSV without object keys or raw event messages for operations handoff and offline analytics.
- `GET /api/admin/dashboard/summary` includes the same snapshot as `dataFlow` so the dashboard can render it without extra round trips.
- REST object APIs record list, upload, presigned/multipart completion, download, delete, and multipart abort events.
- S3-compatible APIs record list, put, multipart complete, copy, get, delete, multi-delete, and multipart abort events. CopyObject is counted as internal copy traffic, separate from external ingress and egress.
- MariaDB mode stores detailed events in `data_flow_events` and materialized UTC-day aggregates in `data_flow_daily_rollups`; in-memory mode keeps events and refreshed rollup rows in process for local/demo execution.
- The admin dashboard shows a compact data I/O widget plus a detailed Data Flow Monitoring panel with upload/download/copy traffic, operations, source/operation trend chart, daily rollup rows, top buckets, recent events, filters, detailed CSV export, daily rollup CSV export, daily rollup store refresh, and materialized rollup load.
- Prometheus/Grafana starter artifacts include `OsmuDataFlowFailureSpike`, `OsmuDataFlowCancelSpike`, `OsmuDataFlowAbnormalEgress`, `OsmuDataFlowBucketTrafficAnomaly`, and `OsmuDataFlowRetentionFailures` backed by `osmu_data_flow_operations_total`, `osmu_data_flow_bytes_total`, and `osmu_data_flow_retention_runs_total`.
- `DataFlowEventRetentionJob` deletes events older than the configured retention window and records `DATA_FLOW_EVENT_RETENTION` audit plus `osmu.data.flow.retention.events` and `osmu.data.flow.retention.runs` metrics.

MVP limitations:

- The MVP summary scans up to the latest 10,000 matching event rows when building the aggregate response.
- In-memory mode still resets event history when the backend process restarts.
- Micrometer counters are exposed for Prometheus and stay independent from the API event repository.
- Streaming download failure is recorded when the response body throws, but bytes are counted when the download response starts.

Retention configuration:

- `OSMU_DATA_FLOW_RETENTION_ENABLED=true`
- `OSMU_DATA_FLOW_RETENTION_DAYS=90`
- `OSMU_DATA_FLOW_RETENTION_BATCH_SIZE=1000`
- `OSMU_DATA_FLOW_RETENTION_INITIAL_DELAY_MS=300000`
- `OSMU_DATA_FLOW_RETENTION_FIXED_DELAY_MS=21600000`

Production follow-up:

- Add table partitioning or move the materialized daily rollup repository to a time-series store when the cleanup batch job, `data_flow_daily_rollups`, and query-time aggregation are not enough for target volume.
- Tune data-flow alert thresholds and Alertmanager routes against target tenant baselines.

## 7. Alerts

Alert conditions:

- backend down
- MariaDB down
- MinIO down
- disk usage >= 80 percent
- disk usage >= 90 percent
- API 5xx error spike
- API latency p95 above threshold
- backup failure
- backup CronJob has no recent successful run
- restore drill failure
- data-flow failure spike
- data-flow cancel spike
- data-flow abnormal egress
- data-flow bucket traffic anomaly
- data-flow retention cleanup failure
- authentication failure spike
- certificate expiry threshold reached

## 8. Tools

MVP:

- Spring Boot Actuator
- Actuator Prometheus endpoint
- Prometheus rule draft under `infra/monitoring`
- Grafana dashboard draft under `infra/monitoring`
- Optional Prometheus Operator draft under `infra/k8s` and `infra/helm/osmu`
- MinIO Console
- Application logs
- Admin dashboard

Product:

- Prometheus
- Grafana
- AlertManager
- Loki optional
- Secret manager audit logs

## 8.1 Operations Readiness Gate

- `scripts/write-operations-readiness.ps1` writes `.osmu-run/latest-operations-readiness.json` and `.osmu-run/latest-operations-readiness.md`.
- This gate is separate from the MVP demo release decision. It summarizes production/B2B operations readiness across Kubernetes/Helm static controls, NetworkPolicy, container hardening, TLS, secret rotation policy, target secret/certificate rotation evidence, target commercial integration evidence, target operations handoff package evidence, IAM/RBAC matrices and finalizer evidence, storage expansion finalizer evidence, Kubernetes HA/DR readiness evidence, Kubernetes DR finalizer evidence, image signing evidence, and container scan/SBOM evidence.
- Result is `ready` only when every listed check is PASS. Missing or plan-only live evidence remains `pending`, even when the durable demo release gate is GO.
- Pending live/security/commercial/package evidence checks include structured `remediation` metadata in the JSON report and remediation command/workflow/workflow-command lines in the Markdown report. Operators can use those entries to run the exact storage expansion, HA/DR, DR, image signing, container security, secret rotation evidence, commercial integration evidence, operations handoff package evidence, or security finalizer path needed to close each gap.
- `scripts/write-operations-evidence-plan.ps1` reads `.osmu-run/latest-operations-readiness.json` and writes `.osmu-run/latest-operations-evidence-plan.json` plus `.md`. The plan orders every pending remediation action, carries local and `gh workflow run` commands, lists operator placeholders, flags operator-approval steps, and identifies whether live workflow/cluster evidence needs `OSMU_KUBECONFIG_BASE64`.
- `scripts/invoke-operations-evidence-plan.ps1` reads the generated evidence plan and writes `.osmu-run/latest-operations-evidence-plan-invocation.json` plus `.md`. It is plan-only by default, can select workflow/local/recommended commands, substitutes operator placeholders such as backup timestamp and restore API base, and blocks actions until required placeholders, operator approval, kubeconfig-secret confirmation, and command allowlist checks are satisfied. Use `-Execute` only after reviewing the generated invocation report.
- `scripts/write-operations-invocation-unblock-plan.ps1` reads `.osmu-run/latest-operations-evidence-plan-invocation.json` and writes `.osmu-run/latest-operations-invocation-unblock-plan.json` plus `.md`. It summarizes blocked action orders, currently planned action orders, required `-KubeconfigSecretConfirmed`/`-ConfirmOperatorApproval` flags, unresolved placeholder parameters such as `-BackupTimestamp`, `-RestoreApiBase`, `-AdminLoginId`, `-ExpectedObjectCount`, and repeated generic placeholders that should usually be handled by the workflow run id/artifact collection helpers instead of one shared replacement value.
- `scripts/write-operations-dispatch-preflight.ps1` reads `.osmu-run/latest-operations-invocation-unblock-plan.json` and writes `.osmu-run/latest-operations-dispatch-preflight.json` plus `.md`. It does not execute workflows. It checks whether selected actions have required operator confirmations, placeholder values, local workflow files, required GitHub secret names extracted from workflow files, and optionally `gh` CLI availability. A `ready` result emits both a plan-only command and an `-Execute` command preview; `action-required` leaves execution commands blank.
- `scripts/write-operations-workflow-run-id-plan.ps1` reads `.osmu-run/latest-operations-evidence-plan-invocation.json` and writes `.osmu-run/latest-operations-workflow-run-ids.json` plus `.md`. In plan-only mode it emits the exact `gh run list --workflow ... --json ...` commands operators need after workflow dispatch. With fixture JSON or `-Execute`, it selects latest successful run ids, derives image/container security artifact names from run `headSha`, and emits follow-up commands for `security-evidence-finalizer-ci.yml` and `write-operations-artifact-collection-plan.ps1`. When `kubernetes-operations-report-sync-ci.yml` is present in the invocation, the generated artifact collection command also carries `-KubernetesOperationsReportSyncRunId`.
- `scripts/write-operations-artifact-collection-plan.ps1` reads `.osmu-run/latest-operations-evidence-plan-invocation.json` and writes `.osmu-run/latest-operations-artifact-collection-plan.json` plus `.md`. Operators fill in GitHub workflow run ids to derive expected artifact names, `gh run download` commands, the Security Evidence Finalizer dispatch command, the Operations Readiness Artifact Finalizer dispatch command, and the equivalent local `import-operations-readiness-artifacts.ps1` command. The plan can also carry Kubernetes operations report sync artifacts so the convergence-level deployed dashboard sync evidence is promoted with the rest of the operations bundle.
- `scripts/finalize-operations-readiness.ps1` is the operator wrapper for this gate. It can plan or run the selected storage expansion finalizer, Kubernetes HA/DR readiness check, Kubernetes DR finalizer, IAM/RBAC finalizer, security evidence finalizer, and final operations readiness report, then writes `.osmu-run/latest-operations-readiness-finalize.json` plus `.md`.
- Finalizer wrappers accept `-PowerShellCommand` and propagate it to child PowerShell scripts. The default is `powershell` on Windows and `pwsh` on non-Windows runners; GitHub Actions workflows pass `pwsh` explicitly so Linux CI evidence collection does not depend on Windows-only command names.
- `.github/workflows/operations-readiness-finalizer-ci.yml` exposes the same wrapper as a manual workflow. It runs plan-only by default and requires `OSMU_KUBECONFIG_BASE64` for live Kubernetes evidence.
- `scripts/import-operations-readiness-artifacts.ps1` imports previously collected workflow artifacts into standard `.osmu-run/latest-*` readiness paths only after their expected result values pass. It also validates selected Kubernetes operations report sync artifacts with `result=applied` before promoting `.osmu-run/latest-kubernetes-operations-report-sync.json`. It writes `.osmu-run/latest-operations-readiness-artifact-import.json` plus `.md`.
- `scripts/write-operations-evidence-handoff.ps1` reads the latest readiness, evidence plan, guarded invocation, workflow run id plan, artifact collection plan, artifact import report, and operations readiness finalizer report, then writes `.osmu-run/latest-operations-evidence-handoff.json` plus `.md` with the current bottleneck and the next operator command to run. When the invocation report is blocked, the next command points to `write-operations-invocation-unblock-plan.ps1`; when artifact import has passed but finalizer evidence is missing or pending, the next command points to `finalize-operations-readiness.ps1`.
- `scripts/write-operations-handoff-package.ps1` records the pilot or production handoff package as `.osmu-run/latest-operations-handoff-package.json` plus `.md`. It wraps already-collected readiness, convergence, secret rotation, commercial integration, enterprise auth, backup/restore, HA/DR, monitoring, security, IAM/RBAC, runbook, troubleshooting, support escalation, and known-gap references into one target evidence file without executing `kubectl`, `gh`, provider APIs, or notification/payment adapters.
- `scripts/write-operations-readiness-convergence.ps1` reads the latest handoff, operations readiness, operations readiness finalizer, and Kubernetes operations report sync reports, then writes `.osmu-run/latest-operations-readiness-convergence.json` plus `.md`. It does not execute `kubectl`, `gh`, workflow dispatch, finalizer, or ConfigMap sync commands; it summarizes the current bottleneck, ready decision, stage counts, finalizer gap counts, Kubernetes report sync result/readiness, and recommended command chain so operators can see whether the workflow has converged to ready. The convergence result is `ready` only after the Kubernetes report sync evidence is `applied` with zero failed checks.
- `.github/workflows/operations-readiness-artifact-finalizer-ci.yml` is the artifact aggregation workflow for this gate. Operators provide run ids and artifact names from the storage expansion, HA/DR readiness, Kubernetes DR, IAM/RBAC, security evidence, and optional Kubernetes operations report sync workflows; it downloads available artifacts, imports passing evidence, writes the operations readiness report, and uploads the combined artifact set.
- The admin dashboard readiness API reads `.osmu-run/latest-operations-readiness.json`, `.osmu-run/latest-operations-evidence-plan.json`, `.osmu-run/latest-operations-evidence-plan-invocation.json`, `.osmu-run/latest-operations-invocation-unblock-plan.json`, `.osmu-run/latest-operations-dispatch-preflight.json`, `.osmu-run/latest-operations-workflow-run-ids.json`, `.osmu-run/latest-operations-artifact-collection-plan.json`, `.osmu-run/latest-operations-readiness-artifact-import.json`, `.osmu-run/latest-operations-readiness-finalize.json`, `.osmu-run/latest-operations-evidence-handoff.json`, `.osmu-run/latest-operations-handoff-package.json`, `.osmu-run/latest-operations-readiness-convergence.json`, and `.osmu-run/latest-kubernetes-operations-report-sync.json` when they exist. Pending checks are surfaced as `OPERATIONS` readiness items targeting `dashboard-readiness-panel`, including evidence path and remediation command/workflow/workflow-command metadata when the source check provides it. The evidence plan is surfaced as `OPERATIONS_EVIDENCE_PLAN` with the plan path and regeneration command, and as structured `operationsEvidencePlan.actions` entries for UI execution ordering. The guarded invocation report is surfaced as `OPERATIONS_EVIDENCE_PLAN_INVOCATION` with its invocation path and command, and as `operationsEvidenceInvocation.actions` entries showing planned/blocked status, block reasons, unresolved placeholders, and dispatch commands. The invocation unblock plan is surfaced as `OPERATIONS_INVOCATION_UNBLOCK_PLAN` and as `operationsInvocationUnblockPlan`, including required confirmation flags, placeholder input mapping, repeated-placeholder warnings, blocked/planned action order lists, and copyable follow-up plan commands. The dispatch preflight report is surfaced as `OPERATIONS_DISPATCH_PREFLIGHT` and as `operationsDispatchPreflight`, including failed/warning check counts, missing required inputs, required GitHub secret names, workflow file presence, preflight checks, required input rows, and plan/execute command previews when ready. The workflow run id plan is surfaced as `OPERATIONS_WORKFLOW_RUN_ID_PLAN` and as `operationsWorkflowRunIdPlan`, including workflow query commands, missing run counts, recommended run id state, artifact collection follow-up command, and security evidence finalizer command. The artifact collection plan is surfaced as `OPERATIONS_ARTIFACT_COLLECTION_PLAN` and as `operationsArtifactCollectionPlan`, including expected artifact names, `gh run download` commands, finalizer commands, missing required artifact counts, and local import command. The readiness artifact import report is surfaced as `OPERATIONS_READINESS_ARTIFACT_IMPORT` and as `operationsReadinessArtifactImport`, including import status, selected group count, imported/failed counts, entry-level source/destination paths, and the no-secret import policy. The readiness finalizer report is surfaced as `OPERATIONS_READINESS_FINALIZER` and as `operationsReadinessFinalize`, including selected finalizer steps, final readiness result, gaps, commands, step results, and secret masking policy. The evidence handoff is surfaced as `OPERATIONS_EVIDENCE_HANDOFF` and as `operationsEvidenceHandoff`, including current bottleneck, next step command, stage summaries, blocked action count, missing workflow run count, missing required artifact count, finalizer failed count, and finalizer gap count. The handoff package is surfaced as `OPERATIONS_HANDOFF_PACKAGE` and as `operationsHandoffPackage`, including target environment/cluster/operator, confirmation flags, failed/planned/check counts, top check rows, and no-secret policy. The convergence report is surfaced as `OPERATIONS_READINESS_CONVERGENCE` and as `operationsReadinessConvergence`, including ready/action-required decision, current bottleneck, recommended commands, stage counts, finalizer status, Kubernetes report sync ready/result/failed count/ConfigMap target, and no-execute safety policy. Kubernetes report sync evidence is surfaced as `KUBERNETES_OPERATIONS_REPORT_SYNC` and as `kubernetesOperationsReportSync`, including namespace, ConfigMap name/key, source report hash, plan/server-dry-run/apply commands, checks, failed count, and write-safety policy.
- The frontend readiness panel highlights those `OPERATIONS` items with an operations evidence gaps summary, evidence plan summary line, invocation summary line, invocation unblock summary line, dispatch preflight summary line, workflow run id summary line, artifact collection summary line, artifact import summary line, operations finalizer summary line, evidence handoff summary line, handoff package summary line, convergence summary line, Kubernetes report sync summary line, evidence plan action list, invocation action list, unblock action/input list, dispatch preflight check/input/workflow rows, workflow query command list, artifact download command list, artifact import entry rows, finalizer command/step rows, handoff stage list, handoff package check list, convergence command list, Kubernetes report sync check list, a quick `Operations` filter, and inline remediation command/workflow command/evidence details with copy controls, keeping production/B2B pending evidence visible even when the dashboard also has runtime, backup, quota, or sharing warnings.
- `scripts/verify-browser-e2e-prototype.ps1` writes a local convergence fixture and passes it to the Spring Boot prototype with `OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH`, so the backend-backed Browser E2E covers the same convergence summary and recommended command rows that the mock demo covers.
- The Docker local demo mounts project `.osmu-run` into the backend container read-only. `scripts/verify-browser-e2e-local-demo.ps1` writes a Docker-local convergence fixture, passes the mounted container-relative path through `OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH`, and enables the same Browser E2E convergence check when Docker is available.
- Kubernetes manifests and the Helm chart mount operations report files into the backend container at `/app/.osmu-run`. The default contract is an optional read-only `osmu-operations-reports` ConfigMap containing `latest-operations-readiness-convergence.json` and, when promoted by the operator, `latest-kubernetes-operations-report-sync.json`; Helm can switch the same mount to a PVC with `backend.operationsReports.type=persistentVolumeClaim` for larger or frequently refreshed evidence sets.
- `scripts/sync-kubernetes-operations-reports.ps1` validates the local convergence report, records source byte count and SHA256, and creates refresh commands/evidence for the `osmu-operations-reports` ConfigMap. Default/`-PlanOnly` mode does not execute `kubectl`, `-ServerDryRunOnly` validates with the API server without persisting changes, and `-Apply` is required to update the ConfigMap. After a successful apply, the script writes `latest-kubernetes-operations-report-sync.json` and republishes the ConfigMap with both the convergence report and sync evidence unless `-SkipEvidenceConfigMapPublish` is supplied.
- `scripts/verify-kubernetes-operations-report-mount.ps1 -Namespace <namespace>` is the read-only post-apply verifier for that delivery path. It checks the `osmu-operations-reports` ConfigMap contains both expected keys, compares the JSON contract with local evidence when available, selects a ready backend Pod by `app.kubernetes.io/name=osmu-backend`, and reads `/app/.osmu-run/latest-operations-readiness-convergence.json` plus `/app/.osmu-run/latest-kubernetes-operations-report-sync.json` through `kubectl exec cat` without reading Kubernetes Secrets.
- `.github/workflows/kubernetes-operations-report-sync-ci.yml` exposes the same sync helper as a manual workflow. It writes the convergence report, creates plan evidence by default, uses `OSMU_KUBECONFIG_BASE64` only when `run_live=true`, runs server dry-run before any apply, and requires both `run_live=true` and `apply=true` before the ConfigMap is updated.
- `.github/workflows/kubernetes-ha-dr-readiness-ci.yml` is the dedicated HA/DR readiness evidence workflow. It runs plan-only by default and, with `run_live=true`, uses `OSMU_KUBECONFIG_BASE64` to collect `.osmu-run/latest-kubernetes-ha-dr-readiness.json` from the target namespace.
- `scripts/finalize-iam-rbac-readiness.ps1` writes `.osmu-run/latest-iam-rbac-finalize.json` plus `.md`. The default run verifies the application IAM/RBAC matrix and Kubernetes RBAC matrix. Operators can add `-RunBackendPolicyTests` for focused backend RBAC tests and `-RunKubernetesLiveAuth` for live `kubectl auth can-i` evidence against the storage expansion runner ServiceAccount.
- `.github/workflows/iam-rbac-finalizer-ci.yml` is the dedicated IAM/RBAC evidence workflow. It sets up Java 17 for focused backend RBAC tests and requires `OSMU_KUBECONFIG_BASE64` only when live Kubernetes auth evidence is requested.
- `scripts/write-container-security-evidence.ps1` converts a successful Trivy high/critical scan plus backend/frontend SPDX SBOM artifacts into `.osmu-run/latest-container-security-evidence.json`, including SBOM byte size and SHA256 hashes.
- `scripts/write-image-signing-evidence.ps1` converts successful Cosign verification for backend/frontend version and commit-SHA tags into `.osmu-run/latest-image-signing-evidence.json`, including backend/frontend image manifest digests.
- `scripts/finalize-security-evidence.ps1` validates those two CI evidence files, rejects synthetic/self-test evidence by default, requires image digests and SBOM hashes, promotes passing files to the standard latest paths, and writes `.osmu-run/latest-security-evidence-finalize.json` plus `.md`.
- `.github/workflows/security-evidence-finalizer-ci.yml` is the dedicated promotion workflow for those artifacts. Operators provide the successful image signing run/artifact and container security run/artifact, then the workflow downloads both artifacts, finalizes evidence, and uploads the promoted evidence bundle.
- Use `scripts/verify-operations-readiness.ps1` in local verification to ensure the readiness artifact keeps the required check list and does not silently drop an operations gate. Use `scripts/verify-secret-rotation-evidence.ps1` to verify the target secret/certificate rotation evidence writer and secret-like reference rejection. Use `scripts/verify-commercial-integration-evidence.ps1` to verify the target commercial integration evidence writer and credential-like reference rejection. Use `scripts/verify-operations-handoff-package.ps1` to verify the target operations handoff package writer and credential-like reference rejection. Use `scripts/verify-operations-evidence-plan.ps1` to keep the executable evidence plan schema, placeholder extraction, approval flags, and unplanned-check handling covered. Use `scripts/verify-operations-evidence-plan-invocation.ps1` to verify that the invocation helper blocks unsafe or incomplete actions and produces planned workflow commands only after required confirmations and replacements are supplied. Use `scripts/verify-operations-invocation-unblock-plan.ps1` to verify the blocked invocation to operator-input handoff. Use `scripts/verify-operations-dispatch-preflight.ps1` to verify the dispatch-ready gate before adding `-Execute`. Use `scripts/verify-operations-workflow-run-id-plan.ps1` to cover the workflow run id query/recommendation handoff, including optional Kubernetes operations report sync run ids. Use `scripts/verify-operations-artifact-collection-plan.ps1` to verify the workflow run id to artifact name mapping and import/finalizer command generation. Use `scripts/verify-operations-evidence-handoff.ps1` to verify the top-level next-action handoff across missing, blocked, artifact-finalizer-ready, operations-finalizer-missing, and operations-finalizer-pending states. Use `scripts/verify-operations-readiness-convergence.ps1` to verify the final no-execute convergence summary for missing handoff, action-required, sync-required, and ready states. Use `scripts/verify-kubernetes-operations-report-sync.ps1` to verify the ConfigMap sync helper in plan, server dry-run, and apply paths with a fake kubectl. Use `scripts/verify-kubernetes-operations-report-mount.ps1 -Namespace <namespace>` after apply to prove the ConfigMap data and backend Pod mounted files match. Use `scripts/verify-kubernetes-operations-report-sync-live.ps1 -ApiBase <api-base> -AdminLoginId <admin> -AdminPassword <secret>` after deployment to confirm the dashboard readiness API is actually reading the applied sync evidence; this live verifier masks credentials and stores only status, result, ConfigMap metadata, retry count, and non-secret polling summaries. The default dashboard poll is 6 attempts with 10 seconds between attempts; tune it with `-DashboardRetryCount` and `-DashboardRetryDelaySeconds` for slower ConfigMap volume refresh windows.

## 9. Object Lifecycle Operations

- Admin dashboard lists prefix/tag lifecycle rules and supports save/delete.
- Lower priority number runs first; use distinct priorities for overlapping rule scopes.
- Conflict Report should be checked after adding rules with broad prefixes or partial tag filters.
- Use Dry run before enabling or tightening a rule to preview candidate count and bytes.
- S3 Lifecycle XML import should be reviewed with Conflict Report and Dry run before enabling aggressive retention.
- Bucket lifecycle API should be used for S3-compatible bucket-scoped policies; confirm imported rules carry the expected `bucketName`.
- Operators should monitor purge counters after rule changes to confirm rule scope.
- MariaDB mode requires `object_lifecycle_rules` migration before rules persist across restart.

## 10. Backup Restore Operations

- `dev-docs/backup-restore-drill.md` is the current runbook.
- MVP pilot targets RPO 24h and RTO 4h.
- Lightweight demo mode does not prove durable backup/restore.
- Durable pilot requires MariaDB dump restore, MinIO object restore, object count/byte reconciliation, API smoke, and S3 client smoke.
- `GET /api/admin/backup/status` exposes current readiness and pending gates in the admin portal. `POST /api/admin/backup/restore-drill-evidence` writes both an audit event and the `backup_restore_drill_evidence` detail row. `GET /api/admin/backup/restore-drill-evidence` returns recent evidence history, while `GET /api/admin/dashboard/summary` and `GET /api/admin/dashboard/readiness` reflect the same stored successful restore drill evidence so the dashboard backup panel and readiness warnings stay aligned.
- `scripts/verify-kubernetes-ha-dr-readiness.ps1 -Namespace <namespace>` writes live Kubernetes HA/DR readiness evidence for Deployments, StatefulSets, PDBs, backup PVC, backup CronJobs, and restore Job server-side dry-run.
- `.github/workflows/kubernetes-ha-dr-readiness-ci.yml` runs the same readiness check from GitHub Actions and uploads the HA/DR readiness evidence artifact for operator review.
- `scripts/run-kubernetes-backup-drill.ps1 -Namespace <namespace>` writes live backup Job evidence by creating one-off Jobs from the MariaDB and MinIO backup CronJobs.
- `scripts/prepare-kubernetes-restore-namespace.ps1 -RestoreNamespace osmu-restore-drill -ServerDryRunOnly` writes restore target namespace API validation evidence.
- `scripts/prepare-kubernetes-restore-namespace.ps1 -RestoreNamespace osmu-restore-drill -Apply -Wait` creates and checks the disposable restore target core stack without copying secret values.
- `scripts/verify-kubernetes-backup-artifacts.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp <timestamp> -ServerDryRunOnly` writes read-only backup artifact preflight API validation evidence.
- `scripts/verify-kubernetes-backup-artifacts.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp <timestamp> -CleanupJob` checks selected timestamp artifacts and records Pod log evidence before restore.
- `scripts/run-kubernetes-restore-drill.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp <timestamp> -ServerDryRunOnly` writes isolated restore Job API validation evidence without creating the Job.
- `scripts/run-kubernetes-restore-drill.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp <timestamp> -ConfirmRestore` creates the restore Job only after explicit operator confirmation.
- `scripts/bootstrap-kubernetes-dr-bucket.ps1 -DrEgressCidr <cidr>` writes external DR bucket bootstrap evidence after creating or reusing the bucket with object locking, enabling versioning, and setting default object-lock retention without copying DR secret values.
- `scripts/verify-kubernetes-dr-bucket-immutability.ps1 -DrEgressCidr <cidr>` writes external DR bucket versioning/default object-lock retention evidence without copying DR secret values.
- `scripts/transfer-kubernetes-backup-artifacts.ps1 -BackupTimestamp <timestamp> -DrEgressCidr <cidr>` writes external DR artifact export/import evidence without copying DR secret values. Transfer Jobs use read-only root filesystems, a writable `/tmp` `emptyDir` for `MC_CONFIG_DIR`, read-only source PVC mounts during export, bounded CPU/memory resources, active deadline, and TTL cleanup.
- `scripts/run-kubernetes-dr-drill.ps1 -BackupTimestamp <timestamp> -ServerDryRunOnly` runs the ordered DR validation sequence and writes wrapper evidence.
- `scripts/run-kubernetes-dr-drill.ps1 -BackupTimestamp <timestamp> -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -ConfirmRestore` runs the ordered restore sequence with external DR bucket bootstrap, immutability preflight, and artifact transfer after explicit operator confirmation.
- `scripts/verify-kubernetes-restore-smoke.ps1 -ApiBase <restore-api> -RunS3ClientSmoke` writes post-restore API and S3 smoke evidence for the restored target.
- `scripts/write-kubernetes-dr-evidence-request.ps1 -MetadataRowCount <count>` writes the admin restore evidence API request body from the Kubernetes DR wrapper, DR bucket bootstrap/immutability evidence, artifact preflight evidence, and restore smoke evidence.
- `scripts/write-kubernetes-dr-evidence-request.ps1 -Submit -ApiBase <api-base> -AdminLoginId <admin>` records that evidence through `POST /api/admin/backup/restore-drill-evidence` after the operator provides credentials outside the evidence files.
- `scripts/finalize-kubernetes-dr-drill.ps1 -ConfirmRestore -RunS3ClientSmoke -MetadataRowCount <count>` runs the DR wrapper, restore smoke, and evidence request sequence together, masks `-AdminPassword` in its report, records the selected PowerShell command, and writes `.osmu-run/latest-kubernetes-dr-finalize.json`.
- `.github/workflows/kubernetes-dr-finalizer-ci.yml` provides the same Kubernetes DR finalizer path as a manual workflow. It runs plan-only by default, requires `OSMU_KUBECONFIG_BASE64` for live Kubernetes evidence, supports a guarded `server_dry_run_only` live validation path, and requires explicit `confirm_restore=true` before confirmed restore or evidence submit can run.

## 11. Storage Expansion Operations

- `scripts/verify-storage-expansion-rbac-auth.ps1 -Namespace <namespace>` writes live `kubectl auth can-i` evidence for the `osmu-storage-expansion-runner` ServiceAccount.
- `scripts/verify-storage-expansion-server-dry-run.ps1 -Namespace <namespace> -ImpersonateRunner` writes MinIO Tenant CRD, existing Tenant, and server-side dry-run evidence for the expansion manifest as the runner identity.
- `scripts/finalize-storage-expansion.ps1 -Namespace <namespace> -ImpersonateRunner` runs the RBAC and server-side dry-run evidence sequence together, records the selected PowerShell command, and writes `.osmu-run/latest-storage-expansion-finalize.json` plus `.md`.
- `scripts/finalize-storage-expansion.ps1 -RunBackendDryRunRunner -ApiBase <api-base> -AdminLoginId <admin> -AdminPassword <secret> -RequestId <id>` can also call the backend dry-run runner after evidence collection.
- `scripts/finalize-storage-expansion.ps1 -RunBackendApply -ConfirmApply -ApiBase <api-base> -AdminLoginId <admin> -AdminPassword <secret> -RequestId <id>` is the explicit guarded path for the backend apply runner. Without `-ConfirmApply`, or when RBAC/server-side dry-run evidence is skipped in the same run, apply fails before any apply request is sent.
- The finalizer report masks admin password values and does not write bearer tokens or secret values to evidence files.
- `.github/workflows/storage-expansion-finalizer-ci.yml` provides the same path as a manual workflow. It runs plan-only by default, requires `OSMU_KUBECONFIG_BASE64` for live Kubernetes evidence, and uploads finalizer/RBAC/dry-run evidence artifacts for review.

## 12. Prometheus And Grafana

- Backend exposes `/actuator/prometheus`.
- Kubernetes backend Service includes `prometheus.io/scrape=true`, `prometheus.io/path=/actuator/prometheus`, and `prometheus.io/port=8080`.
- Helm enables the same scrape annotations through `backend.metrics`.
- `infra/monitoring/prometheus-rules.yaml` defines starter alerts, including data-flow failure/cancel/egress/bucket anomaly and retention cleanup failure alerts.
- Backup CronJob alerts require kube-state-metrics metrics such as `kube_job_status_failed` and `kube_cronjob_status_last_successful_time`.
- `infra/monitoring/grafana-dashboard-osmu.json` defines a starter overview dashboard.
- `infra/k8s/monitoring-operator.yaml` defines optional `ServiceMonitor` and `PrometheusRule` resources.
- `infra/helm/osmu/templates/monitoring-operator.yaml` renders the same optional resources when `monitoring.operator.enabled=true`.
- Product deployment can replace annotations with `ServiceMonitor` when Prometheus Operator is used, but only after `monitoring.coreos.com/v1` CRDs are installed.
