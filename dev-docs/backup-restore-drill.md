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
10. Run S3 smoke with `scripts\verify-s3-client-smoke.ps1` when `aws` or `mc` is available.
11. Compare restored object count, total bytes, bucket names, user count, and recent audit events against the backup manifest.
12. Record drill result, gaps, restore duration, and next action. Do not record secret values.

## Validation Commands

After restore, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-prerequisites.ps1 -RequireRuntime
powershell -ExecutionPolicy Bypass -File .\scripts\verify-lightweight-prototype.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client auto
```

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
- No secret values appear in drill evidence.

## Current Prototype Limit

This draft is verified as documentation and release evidence only. Actual durable restore execution requires Docker/MariaDB/MinIO or a target Kubernetes cluster.
