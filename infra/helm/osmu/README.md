# OSMU Helm Chart Draft

This chart is a productization draft for the OSMU prototype. It mirrors the
plain Kubernetes manifests under `infra/k8s` and keeps customer/env-specific
values in `values.yaml`.

## ServiceAccount And RBAC

- `templates/serviceaccount.yaml` defines dedicated ServiceAccounts for backend, frontend, MariaDB, and MinIO with token automount disabled.
- `templates/backup.yaml` defines the backup ServiceAccount with token automount disabled.
- Workload templates set explicit `serviceAccountName` and `automountServiceAccountToken: false`.
- `templates/storage-expansion-rbac.yaml` can render the optional `osmu-storage-expansion-runner` ServiceAccount, Role, and RoleBinding when `storageExpansion.runner.rbac.enabled=true`. The role is namespace-scoped to `Tenant/osmu-minio` and legacy `StatefulSet/osmu-minio`; it does not grant Secret read, Pod exec, create, delete, or cluster-scoped permissions.
- The default chart keeps `storageExpansion.runner.rbac.enabled=false`, so normal application workloads do not receive Kubernetes API permissions.
- See `../../../dev-docs/kubernetes-rbac-matrix.md`.

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-chart.ps1
```

## Render Example

```powershell
helm template osmu .\infra\helm\osmu --namespace osmu
```

## Operations Reports Mount

The backend can surface operations readiness convergence evidence in the admin
dashboard when the report file is available inside the container. By default,
the chart mounts an optional read-only ConfigMap named
`osmu-operations-reports` at `/app/.osmu-run` and sets
`OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH` to
`.osmu-run/latest-operations-readiness-convergence.json` and
`OSMU_OPERATIONS_READINESS_KUBERNETES_REPORT_SYNC_REPORT_PATH` to
`.osmu-run/latest-kubernetes-operations-report-sync.json`. It also sets
`OSMU_OPERATIONS_READINESS_DATA_FLOW_STORAGE_PLAN_REPORT_PATH` to
`.osmu-run/latest-data-flow-storage-plan.json` so the same mount can expose the
data-flow analytics storage transition plan when that evidence exists.

Create or refresh the ConfigMap after running the operations readiness
convergence writer:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-kubernetes-operations-reports.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\sync-kubernetes-operations-reports.ps1 -Namespace osmu -ServerDryRunOnly
powershell -ExecutionPolicy Bypass -File .\scripts\sync-kubernetes-operations-reports.ps1 -Namespace osmu -Apply
```

The apply path refreshes the convergence report and then republishes the same
ConfigMap with the generated `latest-kubernetes-operations-report-sync.json`
evidence included. When `.osmu-run/latest-data-flow-storage-plan.json` exists,
the helper includes it in both the initial and republished ConfigMap. That keeps
`OSMU_OPERATIONS_READINESS_KUBERNETES_REPORT_SYNC_REPORT_PATH` readable from the
running backend mount and keeps
`OSMU_OPERATIONS_READINESS_DATA_FLOW_STORAGE_PLAN_REPORT_PATH` visible for
readiness plan checks. Use `-SkipEvidenceConfigMapPublish` only when a separate
PVC or GitOps delivery path publishes sync evidence; use
`-SkipDataFlowStoragePlanConfigMapPublish` only when another path owns the
data-flow storage plan file.

The same flow is available through the manual
`kubernetes-operations-report-sync-ci.yml` workflow. Keep `run_live=false` for a
no-cluster plan, set `run_live=true` for API-server dry-run evidence, and set
`apply=true` only when the target namespace should receive the ConfigMap update.
When the sync evidence JSON is present in the mounted report directory, the
admin dashboard shows its plan/server-dry-run/apply result and copyable
follow-up commands.

After apply, verify the deployed dashboard API has observed the mounted files:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-mount.ps1 -Namespace osmu
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-sync-live.ps1 -ApiBase <api-base> -AdminLoginId <admin> -AdminPassword <secret> -DashboardRetryCount 12 -DashboardRetryDelaySeconds 10
```

The ConfigMap is optional so a fresh install can still start before evidence is
collected. For larger or frequently refreshed report sets, switch the chart to a
PVC-backed mount with `backend.operationsReports.type=persistentVolumeClaim` and
`backend.operationsReports.claimName=<claim-name>`.

## MinIO Pool Mode

The default chart still renders the MVP single MinIO StatefulSet.

For product-style pool expansion, install MinIO Operator first, validate the
target Tenant CRD version, then render with:

```powershell
helm template osmu .\infra\helm\osmu --namespace osmu --set minio.tenant.enabled=true
```

`values.yaml` includes `minio.pools` so GitOps expansion plans can append a new
pool with `servers`, `volumesPerServer`, PVC size, and optional
`storageClassName`.

For an explicitly approved in-cluster kubectl runner path, enable only the
least-privilege RBAC template:

```powershell
helm template osmu .\infra\helm\osmu --namespace osmu --set storageExpansion.runner.rbac.enabled=true
```

Helm upgrade/rollback and GitOps PR runners should still use an external
GitOps/CI identity unless a separate, reviewed chart-admin role is added.

After installing the RBAC template, collect live authorization evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-rbac-auth.ps1 -Namespace osmu
```

After MinIO Operator CRDs and the target Tenant exist, collect server-side dry-run evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-server-dry-run.ps1 -Namespace osmu -ImpersonateRunner
```

## HA And Disruption Control

The chart includes minimal HA safety rails:

- `backend.replicas` and `frontend.replicas` default to `2`.
- `ha.topologySpread.enabled=true` adds hostname-based topology spread constraints to backend and frontend Pods.
- `templates/ha.yaml` renders PodDisruptionBudgets when `ha.podDisruptionBudgets.enabled=true`.
- MariaDB and the legacy MinIO StatefulSet PDBs prevent voluntary eviction from removing the only Pod, but they are not a substitute for MariaDB clustering or MinIO Operator Tenant pool HA.
- When `minio.tenant.enabled=true`, the chart does not render the legacy MinIO PDB because Operator-managed Tenant Pod labels and disruption handling must be validated against the installed Operator version.

After installing the chart to a target cluster, collect live HA/DR readiness evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-ha-dr-readiness.ps1 -Namespace osmu
```

For storage expansion readiness, use the finalizer after the chart has rendered the storage expansion runner RBAC and the target cluster has the MinIO Operator Tenant CRD:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -Namespace osmu -ImpersonateRunner
```

Backend runner calls can be included with `-RunBackendDryRunRunner -ApiBase <api-base> -AdminLoginId <admin> -AdminPassword <secret> -RequestId <id>`. Actual backend apply also requires `-RunBackendApply -ConfirmApply` and refuses to run if RBAC/server-side dry-run evidence is skipped in the same command.

## Secret Handling

`secrets.create` defaults to `false`. Provide a Kubernetes Secret named
`osmu-secret`, or enable secret rendering only after replacing every placeholder
value.

Required secret keys:

- `MARIADB_USER`
- `MARIADB_PASSWORD`
- `MARIADB_ROOT_PASSWORD`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`
- `OSMU_ADMIN_PASSWORD`
- `OSMU_JWT_SECRET`
- `OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY`

## Frontend Image Note

When deploying through the included ingress split, build the frontend image with:

```powershell
npm.cmd run build -- --mode production
```

The runtime expects API calls to go through `/api` on the same host.

## S3 Client Endpoint

Set `config.s3PublicEndpoint` and `config.s3Region` for the Developer page and
S3-compatible clients. The default endpoint is `https://osmu.local/api/s3`;
customer installs should set this to the real ingress URL.

## Backup And Restore

`backup.enabled=true` renders:

- `osmu-backup-data` PVC.
- Dedicated backup ServiceAccount with token automount disabled.
- MariaDB backup `CronJob` using `mariadb-dump`.
- MinIO backup `CronJob` using `mc mirror`.

The chart stores backup artifacts in the backup PVC and keeps secret values in
Kubernetes Secret references. The network policy allows backup Pods to reach
MariaDB, MinIO, and DNS only. For production DR, connect that PVC to external
snapshot/offsite backup storage and run restore drills against a separate
namespace before promoting the process. Prometheus Operator alerts for backup
CronJob failure/stale success render when `monitoring.operator.enabled=true`.

After installing the chart, run the non-destructive backup half of the drill:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-backup-drill.ps1 -Namespace osmu
```

For restore validation, install a clean copy of the chart into an isolated namespace such as `osmu-restore-drill`, make the selected backup artifacts available through that namespace's `osmu-backup-data` PVC, then run API server validation without creating the Job:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-kubernetes-restore-namespace.ps1 -RestoreNamespace osmu-restore-drill -ServerDryRunOnly
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-kubernetes-restore-namespace.ps1 -RestoreNamespace osmu-restore-drill -Apply -Wait
```

The preparation helper uses the Kubernetes manifest core stack as a disposable restore target and does not create or copy `osmu-secret`; create that Secret through the target environment secret manager before the restore Job. The helper suspends backup CronJobs in the restore namespace.

To move the selected timestamp through external/offsite S3-compatible DR storage, create `osmu-dr-transfer-secret` in the source and restore namespaces with `DR_S3_ENDPOINT`, `DR_S3_ACCESS_KEY`, `DR_S3_SECRET_KEY`, and `DR_S3_BUCKET`. Then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-kubernetes-dr-bucket.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-kubernetes-dr-bucket.ps1 -ServerDryRunOnly -DrEgressCidr 203.0.113.10/32
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-dr-bucket-immutability.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-dr-bucket-immutability.ps1 -ServerDryRunOnly -DrEgressCidr 203.0.113.10/32
powershell -ExecutionPolicy Bypass -File .\scripts\transfer-kubernetes-backup-artifacts.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\transfer-kubernetes-backup-artifacts.ps1 -BackupTimestamp 20260615T010203Z -ServerDryRunOnly -DrEgressCidr 203.0.113.10/32
powershell -ExecutionPolicy Bypass -File .\scripts\transfer-kubernetes-backup-artifacts.ps1 -BackupTimestamp 20260615T010203Z -DrEgressCidr 203.0.113.10/32 -CleanupJobs
```

The bootstrap helper creates or reuses the DR bucket with object locking, enables versioning, sets default object-lock retention, and verifies the result. The immutability preflight verifies DR bucket reachability, bucket versioning, and default object-lock retention mode before artifact transfer. These helpers render optional egress NetworkPolicies when `-DrEgressCidr` is supplied and never copy DR secret values into generated evidence. The export Job mounts the source backup PVC read-only, the import Job mounts the restore backup PVC read-write, and Jobs run with a read-only root filesystem plus `MC_CONFIG_DIR=/tmp/.mc` on an `emptyDir` `/tmp` mount. Transfer and bootstrap Jobs also set bounded CPU/memory requests/limits, `activeDeadlineSeconds`, and `ttlSecondsAfterFinished`; tune the corresponding script parameters for large backups.

After backup artifacts are copied or snapshotted into the restore namespace PVC, run the read-only artifact preflight:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-backup-artifacts.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp 20260615T010203Z -ServerDryRunOnly
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-backup-artifacts.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp 20260615T010203Z -CleanupJob
```

Then validate the restore Job:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-restore-drill.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp 20260615T010203Z -ServerDryRunOnly
```

To execute the restore Job, explicitly confirm the isolated target:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-restore-drill.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp 20260615T010203Z -ConfirmRestore -CleanupJob
```

The ordered flow can also be reviewed or executed through the wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -BackupTimestamp 20260615T010203Z -ServerDryRunOnly
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -BackupTimestamp 20260615T010203Z -ConfirmRestore -CleanupJobs
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -BackupTimestamp 20260615T010203Z -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -DrEgressCidr 203.0.113.10/32 -ConfirmRestore -CleanupJobs
```

After the restored backend is reachable, collect post-restore smoke evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-restore-smoke.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-restore-smoke.ps1 -ApiBase http://osmu-restore.example/api -AdminLoginId admin -AdminPassword <secret> -RunS3ClientSmoke
```

After the wrapper writes `.osmu-run\latest-kubernetes-dr-drill.json`, build the admin API evidence request:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\write-kubernetes-dr-evidence-request.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\write-kubernetes-dr-evidence-request.ps1 -MetadataRowCount 42
```

Use `-Submit -ApiBase <api-base> -AdminLoginId <admin> -AdminPassword <secret>` only when the target backend is reachable and the operator intends to record the restore evidence through `POST /api/admin/backup/restore-drill-evidence`.

For a single operator sequence that runs the DR wrapper, restore smoke, and evidence request generation, use the finalizer:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -BackupTimestamp 20260615T010203Z -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -DrEgressCidr 203.0.113.10/32 -ApiBase http://osmu-restore.example/api -AdminLoginId admin -AdminPassword <secret> -MetadataRowCount 42 -RunS3ClientSmoke -ConfirmRestore -CleanupJobs
```

## Production Gaps

Before real pilot use, add TLS, StorageClass selection, resource requests/limits,
offsite backup storage, restore automation, secret rotation, cluster-specific
NetworkPolicy review, image build/scanning for the non-root backend/frontend
images, monitoring, MariaDB HA or managed DB, and MinIO Operator pool HA
validation.

