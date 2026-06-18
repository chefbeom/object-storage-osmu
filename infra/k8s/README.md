# OSMU Kubernetes Draft Manifests

This directory contains a draft Kubernetes deployment shape for the current OSMU prototype. It is meant as an MVP/productization starting point, not a hardened production chart.

## ServiceAccount And RBAC

- `serviceaccount.yaml` defines dedicated `osmu-backend`, `osmu-frontend`, `osmu-mariadb`, and `osmu-minio` ServiceAccounts with token automount disabled.
- `backup.yaml` defines the dedicated `osmu-backup` ServiceAccount with token automount disabled.
- Workload Pod specs set explicit `serviceAccountName` and `automountServiceAccountToken: false`.
- `storage-expansion-rbac.yaml` defines the only namespace `Role`/`RoleBinding` in the base draft. It is bound to `osmu-storage-expansion-runner`, is scoped to `Tenant/osmu-minio` and legacy `StatefulSet/osmu-minio`, and does not grant Secret read, Pod exec, create, delete, or cluster-scoped permissions.
- Normal application workloads keep their own ServiceAccounts and do not use the storage expansion runner ServiceAccount.
- See `../../dev-docs/kubernetes-rbac-matrix.md`.

After applying the manifests to a cluster, collect live RBAC evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-rbac-auth.ps1 -Namespace osmu
```

For local review without cluster access:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-rbac-auth.ps1 -PlanOnly
```

After MinIO Operator CRDs and the target Tenant exist, collect server-side dry-run evidence for the expansion manifest:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-server-dry-run.ps1 -Namespace osmu -ImpersonateRunner
```

For local dry-run command review without cluster access:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-storage-expansion-server-dry-run.ps1 -PlanOnly
```

## Files

- `namespace.yaml` - `osmu` namespace.
- `serviceaccount.yaml` - workload ServiceAccounts with token automount disabled.
- `storage-expansion-rbac.yaml` - least-privilege ServiceAccount, Role, and RoleBinding for the optional in-cluster storage expansion kubectl runner.
- `configmap.yaml` - non-secret runtime configuration.
- `secret.example.yaml` - required secret names with placeholder values. Copy it outside git-managed secrets handling before use.
- `mariadb.yaml` - MariaDB `Service` and `StatefulSet` with persistent storage.
- `minio.yaml` - MinIO `Service` and `StatefulSet` with persistent storage.
- `backup.yaml` - backup PVC plus MariaDB dump and MinIO mirror `CronJob` drafts.
- `ha.yaml` - PodDisruptionBudget drafts for backend, frontend, MariaDB, and legacy MinIO.
- `backend.yaml` - backend `Service` and `Deployment` with non-root security context and Prometheus scrape annotations.
- `frontend.yaml` - frontend `Service` and `Deployment`.
- `ingress.yaml` - TLS ingress draft for frontend and backend API paths.
- `networkpolicy.yaml` - backend egress and MariaDB/MinIO ingress policy draft.
- `monitoring-operator.yaml` - optional Prometheus Operator `ServiceMonitor` and `PrometheusRule` draft. Apply only after CRDs exist.
- `examples/minio-tenant-pool-expansion.example.yaml` - reference-only MinIO Operator Tenant pool expansion shape. Apply only after installing MinIO Operator and validating the schema for the target version.
- `examples/restore-from-backup.example.yaml` - destructive restore Job example. Edit `BACKUP_TIMESTAMP` and apply only to a restore target.
- `kustomization.yaml` - resource list for non-secret manifests.
- `../k8s-overlays/osmu-dev` - development cluster overlay for namespace `osmu-dev`, static local PVs and HTTP ingress on `osmu-dev.192.168.35.60.nip.io`.

## Operations Reports Mount

`backend.yaml` mounts an optional read-only ConfigMap named
`osmu-operations-reports` at `/app/.osmu-run`. `configmap.yaml` sets
`OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH` to
`.osmu-run/latest-operations-readiness-convergence.json` and
`OSMU_OPERATIONS_READINESS_KUBERNETES_REPORT_SYNC_REPORT_PATH` to
`.osmu-run/latest-kubernetes-operations-report-sync.json`, so the backend can
read the same convergence and report-sync evidence that the local demo and
prototype Browser E2E use for the admin dashboard.

After running `scripts/write-operations-readiness-convergence.ps1`, create or
refresh the ConfigMap in the target namespace:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-kubernetes-operations-reports.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\sync-kubernetes-operations-reports.ps1 -Namespace osmu -ServerDryRunOnly
powershell -ExecutionPolicy Bypass -File .\scripts\sync-kubernetes-operations-reports.ps1 -Namespace osmu -Apply
```

The apply path first refreshes the convergence report key, writes
`latest-kubernetes-operations-report-sync.json`, and then republishes the
ConfigMap with both `latest-operations-readiness-convergence.json` and
`latest-kubernetes-operations-report-sync.json` so the running backend can read
the same sync evidence from its mounted report directory. Use
`-SkipEvidenceConfigMapPublish` only when another delivery path, such as a PVC,
publishes sync evidence separately.

The same flow is available through the manual
`kubernetes-operations-report-sync-ci.yml` workflow. Keep `run_live=false` for a
no-cluster plan, set `run_live=true` for API-server dry-run evidence, and set
`apply=true` only when the target namespace should receive the ConfigMap update.
When the sync evidence JSON is available in the mounted report directory, the
dashboard exposes its ConfigMap target, source hash, check result, and
copyable server dry-run/apply commands.

After apply, verify the running dashboard API has observed the mounted files:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-mount.ps1 -Namespace osmu
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-operations-report-sync-live.ps1 -ApiBase <api-base> -AdminLoginId <admin> -AdminPassword <secret> -DashboardRetryCount 12 -DashboardRetryDelaySeconds 10
```

The ConfigMap is optional so the backend Pod can start before operations
evidence exists. Production installs that refresh many report files can replace
this with a read-only PVC or a GitOps-managed generated ConfigMap.

## Apply Draft

1. Build and push `osmu-backend:local` and `osmu-frontend:local`, or edit image names in the manifests.
2. Build the frontend image with a Kubernetes-appropriate API base URL, for example `VITE_API_BASE_URL=/api` when using the included ingress path split.
3. Create a real Kubernetes Secret from `secret.example.yaml` values through your secret manager.
4. Create the TLS Secret referenced by ingress, for example `osmu-tls`, through cert-manager or your cluster certificate flow.
5. Apply manifests:

```powershell
kubectl apply -f .\infra\k8s\secret.example.yaml
kubectl apply -k .\infra\k8s
```

For production, replace example secrets, connect `osmu-tls` to a real certificate issuer and rotation process, follow `dev-docs/secret-rotation-policy.md`, configure storage classes, tune resource requests/limits from load tests, confirm NetworkPolicy compatibility with the cluster CNI/ingress controller, connect Prometheus to `/actuator/prometheus` through annotations or the optional `monitoring-operator.yaml`, import the starter rules/dashboard from `infra/monitoring`, run image build/scanning for the non-root backend/frontend images, and use managed MariaDB/MinIO or an operator-backed storage deployment where appropriate.

## MinIO Capacity Expansion

The current `minio.yaml` is a single-node MVP StatefulSet and must not be scaled by only increasing `replicas`.

The selected product direction is pool-based expansion:

- Start production-like MinIO as distributed pools.
- Attach one or more PVCs to each MinIO server Pod.
- Add capacity by adding a new server pool with new Pods and PVs.
- Keep PV sizes consistent inside the same pool.
- Prefer MinIO Operator Tenant or a validated Helm chart for pool topology management.

See `dev-docs/minio-pool-expansion.md` for the OSMU storage expansion design.

After applying `storage-expansion-rbac.yaml` and installing the MinIO Operator Tenant CRD, collect storage expansion readiness evidence with the finalizer:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-storage-expansion.ps1 -Namespace osmu -ImpersonateRunner
```

To call the backend dry-run runner after the Kubernetes evidence steps, add `-RunBackendDryRunRunner -ApiBase <api-base> -AdminLoginId <admin> -AdminPassword <secret> -RequestId <id>`. The backend apply runner requires both `-RunBackendApply` and `-ConfirmApply`, and it refuses to run if RBAC/server-side dry-run evidence is skipped in the same command.

## HA And Disruption Control

The base draft now includes minimal Kubernetes HA safety rails:

- `backend.yaml` and `frontend.yaml` run two replicas by default.
- Backend and frontend Pods include `topologySpreadConstraints` across `kubernetes.io/hostname` with `ScheduleAnyway` so single-node dev clusters are not blocked.
- `ha.yaml` adds PodDisruptionBudgets for backend, frontend, MariaDB, and the legacy MinIO StatefulSet.
- MariaDB and legacy MinIO remain single StatefulSets in this draft, so their PDBs protect against voluntary eviction but do not provide full database/object-storage HA.

Production HA still requires a target-specific decision for MariaDB clustering or managed DB, MinIO Operator Tenant pool topology, multi-zone StorageClass behavior, backup/offsite replication, and restore drill evidence.

After applying the manifests to a target cluster, collect live HA/DR readiness evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-ha-dr-readiness.ps1 -Namespace osmu
```

For local command review without cluster access:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-ha-dr-readiness.ps1 -PlanOnly
```

## Backup And Restore

The base manifests create `osmu-backup-data` and two scheduled backup jobs:

- `osmu-mariadb-backup`: daily MariaDB `mariadb-dump` into `/backup/mariadb/{timestamp}`.
- `osmu-minio-backup`: daily MinIO `mc mirror` into `/backup/minio/{timestamp}`.

Both jobs use a dedicated `osmu-backup` ServiceAccount with token automount disabled, use `osmu-secret` for credentials, and keep secret values out of backup artifacts. NetworkPolicy allows the backup Pods to reach only MariaDB, MinIO, and DNS. The current draft writes to an in-cluster PVC, which is useful for pilot drills but not enough for production DR by itself. Product deployments must mirror or snapshot this backup PVC to external/offsite storage.

Restore is not part of the default kustomization because it can overwrite data. To run a restore drill, copy `examples/restore-from-backup.example.yaml`, replace `BACKUP_TIMESTAMP`, review the target namespace, and apply only to an isolated restore target.

To run the non-destructive backup half of the drill in a live cluster, create one-off Jobs from the scheduled CronJobs and collect evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-backup-drill.ps1 -Namespace osmu
```

To validate the restore Job against the API server without creating it, prepare an isolated restore namespace such as `osmu-restore-drill` with a clean OSMU stack and an `osmu-backup-data` PVC containing the selected backup timestamp, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-kubernetes-restore-namespace.ps1 -RestoreNamespace osmu-restore-drill -ServerDryRunOnly
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-kubernetes-restore-namespace.ps1 -RestoreNamespace osmu-restore-drill -Apply -Wait
```

The restore namespace preparation script does not create or copy `osmu-secret`; create the restore target Secret through the target environment secret manager before running the restore Job. The generated restore target overlay suspends backup CronJobs in the disposable namespace.

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

When Prometheus Operator and kube-state-metrics are available, `monitoring-operator.yaml` includes backup CronJob failure and stale-success alerts.

## Apply `osmu-dev`

The `osmu-dev` overlay is for the `192.168.35.60` development cluster. It creates static PVs with `Retain` reclaim policy, host paths under `/var/lib/osmu-dev`, node affinity to `slave01`, schedules backend/frontend on `slave01`, adds a backup PV at `/var/lib/osmu-dev/backup`, and exposes HTTP ingress at `http://osmu-dev.192.168.35.60.nip.io:30080`.

The base manifest publishes S3-compatible clients through `OSMU_S3_PUBLIC_ENDPOINT=https://osmu.local/api/s3` and `OSMU_S3_REGION=us-east-1`. The `osmu-dev` overlay replaces the endpoint with `http://osmu-dev.192.168.35.60.nip.io:30080/api/s3`.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-osmu-dev-k8s.ps1
```

The helper creates `osmu-secret` with generated values if the secret is missing, then applies `infra/k8s-overlays/osmu-dev`. Backend and frontend images still need to exist on the cluster node or be replaced with registry images through the script parameters.
