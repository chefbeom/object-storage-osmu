# OSMU Backup And Restore Drill Draft

This document defines the MVP pilot backup/restore drill contract for OSMU metadata and object data.

## Scope

The drill covers:

- MariaDB metadata backup and restore.
- MinIO bucket/object backup and restore.
- Runtime configuration inventory.
- Kubernetes Secret and TLS Secret inventory names only; secret values are never copied into drill evidence.
- Post-restore API and S3 smoke verification.

## Recovery Targets

- MVP pilot RPO: 24 hours.
- MVP pilot RTO: 4 hours for a documented manual restore.
- Product target RPO: 1 hour or less.
- Product target RTO: 1 hour or less.

## Backup Inputs

Required before running a drill:

- MariaDB dump from the target environment.
- MinIO bucket mirror, replication target, or object export.
- OSMU application image tags.
- Helm values or Kubernetes manifest version.
- Secret inventory names:
  - `osmu-secret`
  - `osmu-tls`
- Release evidence report from the source environment.

Do not copy secret values into this document, worklogs, release reports, or screenshots.

## Drill Runbook

1. Freeze writes or choose a maintenance window.
2. Record source environment, release version, image tags, and backup timestamp.
3. Provision a clean restore target using Docker Compose, Kubernetes, or Helm.
4. Restore MariaDB metadata.
5. Restore MinIO bucket/object data.
6. Apply runtime config and recreate Secrets from the environment secret manager.
7. Start backend and frontend.
8. Run health checks.
9. Run login, bucket list, object list, object download, and audit log checks.
10. Run S3 smoke with `scripts\verify-s3-client-smoke.ps1` when `aws`, Python+boto3, AWS SDK JavaScript, or `mc` is available.
11. Compare restored object count, total bytes, bucket names, user count, and recent audit events against the backup manifest.
12. Record drill result, gaps, restore duration, and next action. Do not record secret values.

## Validation Commands

After restore, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-prerequisites.ps1 -RequireRuntime
powershell -ExecutionPolicy Bypass -File .\scripts\verify-lightweight-prototype.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client auto
```

## Evidence API

After a drill, record the operational evidence through the admin API:

```http
POST /api/admin/backup/restore-drill-evidence
```

The request must include environment, operator, result, restore start/end time, backup timestamp, metadata row count, object count, object bytes, optional backup manifest SHA-256, optional evidence URI, and known gaps.

The API rejects fields that look like raw password, token, access key, secret, or private key values. Evidence should reference where protected artifacts are stored, not copy protected values into OSMU.

Successful evidence updates `GET /api/admin/backup/status` by setting `restoreDrillExecuted=true`, filling `lastRestoreDrillAt`, and exposing `latestRestoreDrillEvidence`. The backend stores the same payload in `backup_restore_drill_evidence` and keeps the audit log event for traceability. `GET /api/admin/backup/restore-drill-evidence?result=SUCCESS&limit=20` returns recent detailed drill evidence. The admin dashboard summary and readiness endpoints use the same stored evidence, so a submitted Kubernetes DR finalizer result is visible in the dashboard backup panel and no longer leaves the restore-drill readiness warning behind.

## Local Demo Automation

The local Docker demo has executable backup/restore drill scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\backup-local-demo.ps1
```

This writes a timestamped backup under `.osmu-run\backups\` with:

- `metadata.sql`: MariaDB metadata dump.
- `objects\minio`: MinIO bucket/object mirror.
- `backup-manifest.json`: secret-free backup manifest with metadata row count, object count, byte totals, and checksums.

Restore is intentionally guarded because it can overwrite local demo state:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\restore-local-demo.ps1 -BackupDir ".osmu-run\backups\local-demo-YYYYMMDDTHHMMSSZ" -ConfirmRestore -RestartBackend -RecordEvidence
```

For a single local drill command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-local-backup-restore-drill.ps1 -ConfirmRestore -RestartBackend -RecordEvidence
```

`restore-local-demo.ps1` records a restore evidence JSON file under `.osmu-run\restore-drills\`. With `-RecordEvidence`, it also posts the evidence to `POST /api/admin/backup/restore-drill-evidence`.

## Kubernetes Automation

The Kubernetes draft manifests include:

- `infra\k8s\backup.yaml`: `osmu-backup-data` PVC, MariaDB dump CronJob, and MinIO mirror CronJob.
- `infra\k8s\examples\restore-from-backup.example.yaml`: restore Job example guarded by an editable `BACKUP_TIMESTAMP` placeholder.
- `infra\helm\osmu\templates\backup.yaml`: Helm equivalent controlled by `backup.enabled`.
- `scripts\verify-kubernetes-ha-dr-readiness.ps1`: live target-cluster HA/DR readiness helper that checks Deployment replicas/topology spread, StatefulSets, PDBs, backup PVC/CronJobs, restore Job server-side dry-run, and writes `.osmu-run\latest-kubernetes-ha-dr-readiness.json`.
- `.github\workflows\kubernetes-ha-dr-readiness-ci.yml`: manual CI workflow for the same HA/DR readiness check. It runs plan-only by default and requires `OSMU_KUBECONFIG_BASE64` only when `run_live=true`.
- `scripts\run-kubernetes-backup-drill.ps1`: live target-cluster backup drill helper that creates one-off Jobs from the MariaDB and MinIO backup CronJobs, waits for completion, collects Job/Pod/log evidence, and writes `.osmu-run\latest-kubernetes-backup-drill.json`.
- `scripts\prepare-kubernetes-restore-namespace.ps1`: isolated restore namespace helper that renders/applies a restore-target core stack, suspends restore-target backup CronJobs, checks only secret names, and writes `.osmu-run\latest-kubernetes-restore-namespace.json`.
- `scripts\verify-kubernetes-backup-artifacts.ps1`: read-only restore-target PVC preflight helper that checks `metadata.sql`, optional `metadata.sql.sha256`, MinIO mirror file count/bytes, and writes `.osmu-run\latest-kubernetes-backup-artifacts.json`.
- `scripts\run-kubernetes-restore-drill.ps1`: isolated restore-target helper that renders the restore Job from `restore-from-backup.example.yaml`, checks restore namespace prerequisites, supports API server dry-run evidence, and writes `.osmu-run\latest-kubernetes-restore-drill.json`.
- `scripts\run-kubernetes-dr-drill.ps1`: orchestration helper that runs the backup drill, optional DR bucket bootstrap, restore namespace preparation, optional DR bucket immutability preflight, backup artifact preflight, and restore drill sequence in order and writes `.osmu-run\latest-kubernetes-dr-drill.json`.
- `scripts\bootstrap-kubernetes-dr-bucket.ps1`: external S3-compatible DR bucket bootstrap helper that creates or reuses the DR bucket with object locking, enables versioning, sets default object-lock retention, verifies the result, and writes `.osmu-run\latest-kubernetes-dr-bucket-bootstrap.json`.
- `scripts\verify-kubernetes-dr-bucket-immutability.ps1`: external S3-compatible DR bucket preflight helper that checks bucket reachability, versioning, and default object-lock retention mode through `osmu-dr-transfer-secret`, writing `.osmu-run\latest-kubernetes-dr-bucket-immutability.json`.
- `scripts\transfer-kubernetes-backup-artifacts.ps1`: external S3-compatible DR transfer helper that exports the selected timestamp from the source backup PVC and imports it into the restore namespace backup PVC, writing `.osmu-run\latest-kubernetes-backup-artifact-transfer.json`.
- `scripts\verify-kubernetes-restore-smoke.ps1`: post-restore smoke helper that checks restored API health, admin login, backup status, optional restored bucket/object download, optional real S3 client smoke, and writes `.osmu-run\latest-kubernetes-restore-smoke.json`.
- `scripts\write-kubernetes-dr-evidence-request.ps1`: converts Kubernetes DR drill evidence plus backup artifact preflight logs into the admin restore evidence API request shape and writes `.osmu-run\latest-kubernetes-dr-evidence-request.json`. With `-Submit`, it posts to `POST /api/admin/backup/restore-drill-evidence`.
- `scripts\finalize-kubernetes-dr-drill.ps1`: one-command Kubernetes DR finalization wrapper that runs the DR drill wrapper, post-restore smoke, and evidence request generation/submission sequence and writes `.osmu-run\latest-kubernetes-dr-finalize.json` plus `.osmu-run\latest-kubernetes-dr-finalize.md`. Displayed commands mask `-AdminPassword`.
- `.github\workflows\kubernetes-dr-finalizer-ci.yml`: manual CI workflow for the same finalizer. It is plan-only by default, requires `OSMU_KUBECONFIG_BASE64` for live Kubernetes evidence, and requires explicit `confirm_restore=true` before confirmed restore or evidence submit can run.

The backup Pods use a dedicated ServiceAccount with token automount disabled and a restricted NetworkPolicy path to MariaDB, MinIO, and DNS. The default backup target is an in-cluster PVC. This is enough for pilot restore drills, but production DR must copy or snapshot backup artifacts to external/offsite storage.

Run a Kubernetes backup drill after the manifests or Helm chart are applied:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-backup-drill.ps1 -Namespace osmu
```

For local command review without creating Jobs:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-backup-drill.ps1 -PlanOnly
```

Run a Kubernetes restore drill only against an isolated target namespace such as `osmu-restore-drill`. The restore namespace must contain a clean OSMU stack, `osmu-config`, `osmu-secret`, `osmu-backup` ServiceAccount, `osmu-mariadb` and `osmu-minio` Services, and an `osmu-backup-data` PVC that already contains:

- `/backup/mariadb/<BACKUP_TIMESTAMP>/metadata.sql`
- `/backup/minio/<BACKUP_TIMESTAMP>`

Prepare or validate the restore namespace in stages:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-kubernetes-restore-namespace.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-kubernetes-restore-namespace.ps1 -ServerDryRunOnly
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-kubernetes-restore-namespace.ps1 -Apply -Wait
```

The preparation script does not create or copy secret values. Create `osmu-secret` in the restore namespace through the target environment secret manager before running the actual restore drill. It also suspends the restore-target backup CronJobs so the disposable target does not start producing its own scheduled backups during the drill.

Before artifact preflight, make the selected backup timestamp available in the restore namespace. For production-like drills, prefer an external/offsite S3-compatible DR bucket over direct PVC copying. Create `osmu-dr-transfer-secret` in each active namespace with these keys:

- `DR_S3_ENDPOINT`
- `DR_S3_ACCESS_KEY`
- `DR_S3_SECRET_KEY`
- `DR_S3_BUCKET`

Do not put DR credential values in git, worklogs, screenshots, or evidence files. If NetworkPolicy is enforced, pass `-DrEgressCidr <cidr>` so the helper renders an egress NetworkPolicy for the bootstrap, immutability preflight, and transfer Jobs. The export Job mounts the source backup PVC read-only, while the import Job mounts the restore backup PVC read-write. These Jobs run with a read-only root filesystem and use an `emptyDir` mounted at `/tmp` for `MC_CONFIG_DIR=/tmp/.mc`. Transfer and bootstrap Jobs also set resource requests/limits, `activeDeadlineSeconds`, and `ttlSecondsAfterFinished`; tune `-CpuRequest`, `-MemoryRequest`, `-CpuLimit`, `-MemoryLimit`, `-ActiveDeadlineSeconds`, and `-TtlSecondsAfterFinished` for large backups.

Before the first production-like transfer, bootstrap the external DR bucket. The helper uses `mc mb --with-lock`, `mc version enable`, and `mc retention set --default` through the secret above, then writes secret-free evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-kubernetes-dr-bucket.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-kubernetes-dr-bucket.ps1 -ServerDryRunOnly -DrEgressCidr 203.0.113.10/32
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-kubernetes-dr-bucket.ps1 -RetentionMode COMPLIANCE -RetentionDuration 1y -DrEgressCidr 203.0.113.10/32 -CleanupJob
```

Before exporting artifacts, verify that the external DR bucket is reachable, versioning is enabled, and default object-lock retention is configured. Use `-RequiredRetentionMode COMPLIANCE` when the target environment requires compliance-mode retention instead of either governance or compliance:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-dr-bucket-immutability.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-dr-bucket-immutability.ps1 -ServerDryRunOnly -DrEgressCidr 203.0.113.10/32
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-dr-bucket-immutability.ps1 -RequiredRetentionMode COMPLIANCE -DrEgressCidr 203.0.113.10/32 -CleanupJob
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\transfer-kubernetes-backup-artifacts.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\transfer-kubernetes-backup-artifacts.ps1 -BackupTimestamp 20260615T010203Z -ServerDryRunOnly -DrEgressCidr 203.0.113.10/32
powershell -ExecutionPolicy Bypass -File .\scripts\transfer-kubernetes-backup-artifacts.ps1 -BackupTimestamp 20260615T010203Z -DrEgressCidr 203.0.113.10/32 -CleanupJobs
```

After backup artifacts are transferred, copied, or snapshotted into the restore namespace's `osmu-backup-data` PVC, verify artifact presence and checksums before running the restore Job:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-backup-artifacts.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-backup-artifacts.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp 20260615T010203Z -ServerDryRunOnly
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-backup-artifacts.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp 20260615T010203Z -CleanupJob
```

The artifact preflight Job mounts `osmu-backup-data` read-only, checks that MariaDB `metadata.sql` is non-empty, validates `metadata.sql.sha256` when present, counts MinIO mirror files and bytes, and emits `OSMU_BACKUP_ARTIFACT_PREFLIGHT_RESULT=passed` in Pod logs. Use `-AllowEmptyMinio` only when an empty object store is an intentional test case.

To review or execute the ordered Kubernetes DR drill flow from one command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -BackupTimestamp 20260615T010203Z -ServerDryRunOnly
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -BackupTimestamp 20260615T010203Z -ConfirmRestore -CleanupJobs
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-dr-drill.ps1 -BackupTimestamp 20260615T010203Z -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -DrEgressCidr 203.0.113.10/32 -ConfirmRestore -CleanupJobs
```

`run-kubernetes-dr-drill.ps1` does not copy backup artifacts by default. Copy/snapshot the selected backup timestamp into the restore namespace PVC, or add `-TransferArtifacts` to export/import through the external S3-compatible DR bucket before artifact preflight. Add `-BootstrapDrBucket` before the first production DR transfer or when the bucket policy must be reconciled, and add `-VerifyDrBucketImmutability` before transfer when the drill must prove the DR bucket versioning and object-lock retention posture. `-RunBackupDrill` can be added to create fresh one-off source backup Jobs before the restore-side checks, but the operator must still choose the timestamp that will be transferred or preflighted.

After the wrapper finishes and the restored backend is reachable, collect post-restore smoke evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-restore-smoke.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-restore-smoke.ps1 -ApiBase http://osmu-restore.example/api -AdminLoginId admin -AdminPassword "<secret>" -ExpectedBucketName media -ExpectedObjectKey sample.txt
powershell -ExecutionPolicy Bypass -File .\scripts\verify-kubernetes-restore-smoke.ps1 -ApiBase http://osmu-restore.example/api -AdminLoginId admin -AdminPassword "<secret>" -RunS3ClientSmoke -RequireS3Client
```

Then create a secret-free backend API evidence request. When the DR wrapper used `-BootstrapDrBucket`, external artifact transfer, or `-VerifyDrBucketImmutability`, the evidence request helper treats `.osmu-run/latest-kubernetes-dr-bucket-bootstrap.json` and `.osmu-run/latest-kubernetes-dr-bucket-immutability.json` as required success evidence as applicable:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\write-kubernetes-dr-evidence-request.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\write-kubernetes-dr-evidence-request.ps1 -MetadataRowCount 42
powershell -ExecutionPolicy Bypass -File .\scripts\write-kubernetes-dr-evidence-request.ps1 -Submit -ApiBase http://osmu.example/api -AdminLoginId admin -AdminPassword "<secret>"
```

`AUTO` result mode writes `FAILED` when the wrapper failed, `SUCCESS` only when `-ConfirmSuccessfulRestore`, live confirmed restore evidence, explicit `-MetadataRowCount`, object evidence, required DR bucket bootstrap/immutability evidence, and either `-PostRestoreSmokeVerified` or a passed `.osmu-run\latest-kubernetes-restore-smoke.json` with API and S3 smoke are present, and otherwise `PARTIAL`. Use `-Result SUCCESS` only after the same proof exists. The generated request records known gaps instead of hiding missing restore or smoke evidence.

For the full operator path, use the finalization wrapper. `-PlanOnly` writes the planned command sequence and expected artifact paths without changing the cluster. A confirmed run executes the DR wrapper, verifies the restored API/S3 path, then writes or submits the evidence request:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -PlanOnly
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -BackupTimestamp 20260615T010203Z -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -DrEgressCidr 203.0.113.10/32 -ApiBase http://osmu-restore.example/api -AdminLoginId admin -AdminPassword "<secret>" -MetadataRowCount 42 -RunS3ClientSmoke -ConfirmRestore -CleanupJobs
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-kubernetes-dr-drill.ps1 -BackupTimestamp 20260615T010203Z -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -DrEgressCidr 203.0.113.10/32 -ApiBase http://osmu-restore.example/api -AdminLoginId admin -AdminPassword "<secret>" -MetadataRowCount 42 -RunS3ClientSmoke -ConfirmRestore -SubmitEvidence -CleanupJobs
```

The finalize report intentionally stores only whether an admin password was provided, not the password value. Use `-SkipRestoreSmoke` or `-SkipEvidenceRequest` only for partial rehearsals; those runs should remain `partial`, not successful DR proof.

Review the restore plan without touching the cluster:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-restore-drill.ps1 -PlanOnly
```

Collect API server validation evidence without creating the restore Job:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-restore-drill.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp 20260615T010203Z -ServerDryRunOnly
```

After confirming the target namespace is isolated and disposable, run the restore Job and collect evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-kubernetes-restore-drill.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp 20260615T010203Z -ConfirmRestore -CleanupJob
```

The script refuses to run against the source namespace unless `-AllowSourceNamespaceRestore` is explicitly provided. That flag should require manual approval because the restore Job can overwrite MariaDB metadata and MinIO objects.

Prometheus Operator drafts include `OsmuBackupCronJobFailed` and `OsmuBackupCronJobStale` alerts when kube-state-metrics exposes Job/CronJob status metrics.

For Docker-backed durable verification, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-release.ps1 -RunDockerIntegration -RequireDocker -RequireS3Client -JavaHome "<jdk17>"
```

## Acceptance Criteria

A pilot restore drill passes when:

- Backend health returns HTTP 200.
- Frontend returns HTTP 200.
- Admin login succeeds.
- Bucket list matches expected bucket names.
- Object list and download succeed for sampled objects.
- MariaDB row counts for users, organizations, buckets, access keys, and audit logs are within expected backup manifest values.
- MinIO object count and byte totals are within expected backup manifest values.
- Built-in S3 SigV4 smoke passes.
- Real `aws` or `mc` smoke passes when the client is available.
- Drill evidence records RPO, RTO, restore duration, operator, environment, and gaps.
- Admin dashboard backup readiness shows the latest restore drill evidence result, environment, and recorded time after evidence submission.
- No secret values appear in drill evidence.
- Kubernetes restore drills run against an isolated restore namespace such as `osmu-restore-drill`, not the production source namespace.
- Kubernetes backup artifact preflight confirms the restore target PVC contains the selected timestamp before restore.

## Current Prototype Limit

The runbook draft, evidence API, local Docker demo backup/restore scripts, Kubernetes backup drill helper, restore namespace helper, external DR bucket bootstrap helper, external DR artifact transfer helper, backup artifact preflight helper, Kubernetes isolated restore drill helper, Kubernetes DR drill orchestration helper, Kubernetes restore smoke helper, Kubernetes DR evidence API request helper, Kubernetes DR finalization wrapper, Kubernetes DR finalizer CI workflow, and dashboard evidence visibility are implemented. Full production durable restore execution still requires Docker/MariaDB/MinIO or a target Kubernetes cluster with real backup storage.
